class_name RouteLiner
extends RefCounted
## The smart bot under the eletd rules, where a tower reaches only the tiles
## around it. It plays like a player who, before each purchase, counts how
## much damage the creeps in the wave preview would take on their way past:
## ground creeps along the route as it stands (or as the new tower would bend
## it), flyers along the straight portal-to-gate line. It buys the build,
## upgrade or fusion that adds the most per gold, saving up when the best one
## is out of reach, and builds only on the bot's serpentine plan. So it lines
## the straight route first and turns it into the serpentine a step at a time
## once a longer route pays more than upgrades (_add_step).

## Weight of the wave being planned for, the one after and the one after that.
const HORIZON: Array[float] = [1.0, 0.6, 0.35]
const BUILDS: Array[StringName] = [
	&"archer",
	&"cannon",
	&"frost",
	&"plague",
	&"runesmith",
	&"ballista",
	&"demolisher",
	&"roots",
	&"shadow",
	&"bard",
]
## A tower splits its fire among the creeps in reach, so in a stream each
## creep draws at most this many spawn intervals of one tower's fire.
const STREAM_SHARE := 1.8
## Damage a creep must be able to take on its way, in multiples of its HP,
## before more of it stops paying: value grows as 1 - exp(-damage / (HP × this)).
const MARGIN := 1.5
## Buy a cheaper action while saving only if it is worth this share of the
## best one per gold.
const SAVE_RATIO := 0.7
const MAX_ACTIONS := 8
## Per-kind extra worth on top of single-target damage: splash, pierce,
## slows, shred, several creeps in reach.
const KIND_BONUS := {
	&"cannon": 1.5,
	&"demolisher": 1.8,
	&"doom_cannon": 2.0,
	&"frost": 1.6,
	&"frost_wyrm": 2.6,
	&"plague": 0.8,
	&"plague_necropolis": 1.2,
	&"ballista": 1.5,
	&"sunfire_ballista": 2.5,
	&"roots": 2.0,
	&"shadow": 1.8,
	&"runesmith": 1.2,
}
const SHRED_CLASSES: Array[StringName] = [&"armored", &"boss"]
## A boss counts as this many creeps: a leak costs 2 lives, and it walks again.
const BOSS_STAKE := 6.0
## The unseen waves the bot plans for, as yardsticks (_add_yardsticks): how
## far ahead, their weight against a previewed wave's, and the brute's HP in
## plain creeps.
const FUTURE_AHEAD := 4
const FUTURE_WEIGHT := 0.5
const BRUTE_WEIGHT := 1.0
const BRUTE_HP := 25.0
## Serpentine steps valued together as one purchase, at most.
const STEPS_AHEAD := 3

var sim: GameSim
## The serpentine plan: every tile the bot may build on.
var plan: Array[Vector2i] = []
## Placement.Result → how many plan tiles were given up for that reason.
var skip_reasons := {}

## The plan's walls in build order, as [row, gap columns, ...].
var _walls: Array = []
var _skipped := {}
var _rng: RandomNumberGenerator
## Per plan tile, how many 2 m samples of the flight line it reaches.
var _air_contact := {}
var _foes: Array[Dictionary] = []
## Tower id → per level → per foe damage per second against that foe.
var _dps := {}
var _horizon_wave := -1
var _route := {}
var _route_shift := {}
## Per tower tile: Bard aura on it, damage per foe before aura, route contact.
var _aura_by := {}
var _raw_by := {}
var _ground_by := {}
## Per foe, the damage one creep takes from the whole board; poison from
## stacks after it, capped per foe by _poison_cap (a creep holds 5 stacks).
var _totals := PackedFloat32Array()
var _poison_cap := PackedFloat32Array()
var _actions: Array[Dictionary] = []
var _dirty := true


func _init(
	p_sim: GameSim, p_plan: Array[Vector2i], walls: Array, rng: RandomNumberGenerator
) -> void:
	sim = p_sim
	plan = p_plan
	_walls = walls
	_rng = rng
	var a := sim.grid.spawn_point
	var b := sim.grid.gate_point
	var samples := PackedVector2Array()
	var n := ceili(a.distance_to(b) / Grid.TILE)
	for i in n + 1:
		samples.append(a.lerp(b, float(i) / n))
	for tile in plan:
		var c := Grid.center(tile)
		var k := 0
		for p in samples:
			var d := (p - c).abs()
			if maxf(d.x, d.y) <= Grid.TILE * 1.5:
				k += 1
		if k > 0:
			_air_contact[tile] = k


func decide() -> void:
	# The top bar shows the next two waves: while one is still coming in, that
	# one and the two after it are all in view.
	var w := clampi(sim.wave + (0 if sim.spawning() else 1), 1, WaveDefs.count())
	var key := w * 10 + (3 if sim.spawning() else 2)
	if key != _horizon_wave:
		_horizon_wave = key
		_read_waves(w, 3 if sim.spawning() else 2)
		_dirty = true
	if sim.gold < TowerDefs.build_cost(&"archer") and not _dirty:
		return
	var blocked_now := {}
	for _i in MAX_ACTIONS:
		if _dirty:
			_evaluate()
		var a := _choose(blocked_now)
		if a.is_empty():
			return
		match a.kind:
			&"build":
				var r := sim.check_build(a.tile, a.id)
				if r == Placement.Result.CREEP_ON_TILE or r == Placement.Result.NO_GOLD:
					blocked_now[a.tile] = true
					continue
				if r == Placement.Result.OK:
					sim.build(a.tile, a.id)
				else:
					_skipped[a.tile] = true
					skip_reasons[r] = skip_reasons.get(r, 0) + 1
			&"upgrade":
				sim.upgrade(a.tile)
			&"fuse":
				_fuse(a)
		_dirty = true


## The best action per gold if affordable; else the best affordable one worth
## nearly as much; else nothing, saving up.
func _choose(blocked_now: Dictionary) -> Dictionary:
	var best_ratio := 0.0
	for a in _actions:
		if a.kind == &"build" and blocked_now.has(a.tile):
			continue
		if a.kind == &"fuse" and sim.phase != GameSim.Phase.BUILD:
			continue
		if best_ratio == 0.0:
			best_ratio = a.ratio
		if a.cost <= sim.gold:
			return a if a.ratio >= best_ratio * SAVE_RATIO else {}
	return {}


# --- Reading the waves ----------------------------------------------------


func _read_waves(w0: int, seen: int) -> void:
	_foes.clear()
	_add_yardsticks(w0)
	for k in seen:
		var w := w0 + k
		if w > WaveDefs.count():
			break
		var list := WaveDefs.spawn_list(w, sim.rules)
		var heals := list.any(func(e: Array) -> bool: return e[0] == &"priestess")
		var groups := {}
		var shares := {}
		for e in list:
			var key: String = "%s/%s" % [e[0], e[1]]
			groups[key] = groups.get(key, 0) + 1
			shares[key] = WaveDefs.hp_share(e)
		for key: String in groups:
			var parts := key.split("/")
			var type := StringName(parts[0])
			var def: Dictionary = CreepDefs.CREEPS[type]
			var hp: float = CreepDefs.max_hp(type, w, _hp_mult(type, w)) * shares[key]
			if type == &"steam_tank" or type == &"ghoul":
				hp *= 4.0 / 3.0
			if heals:
				hp *= 1.1
			var n: int = groups[key]
			var stake := BOSS_STAKE if CreepDefs.is_boss(type) else 1.0
			if WaveDefs.bulky(w, sim.rules):
				stake = EletdRules.BULKY_LIVES
			var spacing := WaveDefs.spawn_interval(type, sim.rules)
			(
				_foes
				. append(
					{
						"w": HORIZON[k] * n * stake / float(list.size()),
						"hp": hp,
						"speed": def.speed,
						"air": def.get("flying", false),
						"cap": INF if n == 1 else spacing * STREAM_SHARE,
						"class": def.class,
						"element": StringName(parts[1]),
						"armor": float(def.armor),
					}
				)
			)
	_dps.clear()
	for id: StringName in TowerDefs.TOWERS:
		var levels: Array[PackedFloat32Array] = []
		var top := 1 if id in TowerDefs.EPICS else TowerDefs.MAX_LEVEL
		for lvl in range(1, top + 1):
			var row := PackedFloat32Array()
			for f in _foes:
				row.append(_tower_dps(id, lvl, f))
			levels.append(row)
		_dps[id] = levels


## What a player knows without the preview: creeps keep getting tougher, and
## now and then a lone slow brute comes that only a long, well-armed route
## stops. A plain creep and such a brute FUTURE_AHEAD waves on, of no element.
func _add_yardsticks(w0: int) -> void:
	var w := w0 + FUTURE_AHEAD
	var hp := CreepDefs.max_hp(&"grunt", w, EletdRules.hp_mult(&"grunt", w, sim.difficulty))
	var plain := {
		"w": FUTURE_WEIGHT,
		"hp": hp,
		"speed": 3.0,
		"air": false,
		"cap": WaveDefs.spawn_interval(&"grunt", sim.rules) * STREAM_SHARE,
		"class": &"light",
		"element": &"",
		"armor": 2.0,
	}
	_foes.append(plain)
	var brute := plain.duplicate()
	brute.hp = hp * BRUTE_HP
	brute.w = BRUTE_WEIGHT
	brute.speed = 2.0
	brute.cap = INF
	brute.class = &"boss"
	brute.armor = 8.0
	_foes.append(brute)


## The creep HP multiplier GameSim.spawn_creep applies (mode and rule set).
func _hp_mult(type: StringName, w: int) -> float:
	return EletdRules.hp_mult(type, w, sim.difficulty)


## Damage per second a tower deals one foe while it is in reach, counting
## splash, pierce and slows as extra worth (KIND_BONUS).
func _tower_dps(id: StringName, lvl: int, foe: Dictionary) -> float:
	var def: Dictionary = TowerDefs.TOWERS[id]
	if def.kind == &"aura" or (foe.air and not def.get("air", false)):
		return 0.0
	var attack: StringName = def.attack
	var mult: float = (
		Damage.class_mult(attack, foe.class) * Damage.element_mult(def.element, foe.element)
	)
	if attack != &"poison":
		mult *= Damage.armor_factor(foe.armor)
	var cd: float = TowerDefs.stat(id, "cooldown", lvl, 1.0)
	var base := 0.0
	if def.kind == &"cloud":
		base = TowerDefs.stat(id, "cloud_dps", lvl)
	elif def.has("poison_dps"):
		var dot: float = TowerDefs.stat(id, "poison_dps", lvl)
		base = dot * float(TowerDefs.stat(id, "poison_time", lvl)) / cd
	else:
		base = float(TowerDefs.stat(id, "damage", lvl)) / cd
	var crater: float = TowerDefs.stat(id, "crater_dps", lvl, 0.0)
	# Splash, pierce and slows pay against a stream, hardly against a lone boss.
	if foe.cap < INF:
		base = base * KIND_BONUS.get(id, 1.0) + crater * 1.5
	if id == &"runesmith" and foe.class in SHRED_CLASSES:
		base *= 1.4
	return base * mult


# --- Valuing the board ----------------------------------------------------


func _route_of(field: FlowField) -> Dictionary:
	var out := {}
	var r := field.route()
	for i in range(1, r.size() - 1):
		out[Grid.tile_at(r[i])] = true
	return out


func _ground_contact(tile: Vector2i, route: Dictionary) -> int:
	var k := 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if route.has(tile + Vector2i(dx, dy)):
				k += 1
	return k


## Per foe, the damage one creep takes passing a tower with these contacts,
## before any Bard aura.
func _raw(id: StringName, lvl: int, ground: int, air: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_foes.size() * 2)
	if TowerDefs.TOWERS[id].kind == &"aura":
		return out
	var row: PackedFloat32Array = _dps[id][lvl - 1]
	var at := _foes.size() if TowerDefs.TOWERS[id].has("poison_dps") else 0
	for f in _foes.size():
		var foe := _foes[f]
		var contact := air if foe.air else ground
		if contact > 0:
			out[at + f] = row[f] * minf(contact * Grid.TILE / foe.speed, foe.cap)
	return out


func _value(totals: PackedFloat32Array) -> float:
	var v := 0.0
	for f in _foes.size():
		var foe := _foes[f]
		var dmg := totals[f] + minf(totals[_foes.size() + f], _poison_cap[f])
		v += foe.w * (1.0 - exp(-dmg / (foe.hp * MARGIN)))
	return v


## `totals` plus `raw` × `k`, as a new array.
func _plus(totals: PackedFloat32Array, raw: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var out := totals.duplicate()
	for f in out.size():
		out[f] += raw[f] * k
	return out


func _aura_gain(id: StringName, lvl: int) -> float:
	return TowerDefs.stat(id, "aura_damage", lvl) + TowerDefs.stat(id, "aura_haste", lvl)


## What a Bard of this gain and range on `tile` adds over `totals`.
func _bard_gain(tile: Vector2i, gain: float, r: float, totals: PackedFloat32Array) -> float:
	var t := totals.duplicate()
	var c := Grid.center(tile)
	var span := floori(r / Grid.TILE)
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var o := tile + Vector2i(dx, dy)
			if o == tile or not _raw_by.has(o) or Grid.center(o).distance_to(c) > r:
				continue
			var lift: float = gain - _aura_by.get(o, 0.0)
			if lift > 0.0:
				var raw: PackedFloat32Array = _raw_by[o]
				for f in t.size():
					t[f] += raw[f] * lift
	return _value(t) - _value(totals)


## Reads the board: route, auras, each tower's damage per foe, and the total.
func _read_board() -> void:
	_route = _route_of(sim.field)
	_route_shift = _shifting_tiles()
	_aura_by.clear()
	_raw_by.clear()
	_ground_by.clear()
	for b: Vector2i in sim.towers:
		var bard: SimTower = sim.towers[b]
		if bard.stat("kind") != &"aura":
			continue
		var gain := _aura_gain(bard.id, bard.level)
		var r: float = bard.stat("range")
		for t: Vector2i in sim.towers:
			if t != b and Grid.center(t).distance_to(Grid.center(b)) <= r:
				_aura_by[t] = maxf(_aura_by.get(t, 0.0), gain)
	_totals = PackedFloat32Array()
	_totals.resize(_foes.size() * 2)
	_poison_cap.resize(_foes.size())
	var fly := sim.grid.spawn_point.distance_to(sim.grid.gate_point)
	var dot: float = TowerDefs.stat(&"plague", "poison_dps", TowerDefs.MAX_LEVEL)
	for f in _foes.size():
		var foe := _foes[f]
		var walk: float = fly if foe.air else _route.size() * Grid.TILE
		var stacks: float = TowerDefs.stat(&"plague", "poison_stacks")
		_poison_cap[f] = (
			stacks * dot * Damage.element_mult(&"dark", foe.element) * walk / foe.speed
		)
	for tile: Vector2i in sim.towers:
		var t: SimTower = sim.towers[tile]
		if t.stat("kind") == &"aura":
			continue
		var g := _ground_contact(tile, _route)
		_ground_by[tile] = g
		var raw := _raw(t.id, t.level, g, _air_contact.get(tile, 0))
		_raw_by[tile] = raw
		_totals = _plus(_totals, raw, 1.0 + _aura_by.get(tile, 0.0))


## The totals if the route were `route`: only towers whose contact changes.
func _totals_on(route: Dictionary) -> PackedFloat32Array:
	var out := _totals.duplicate()
	for tile: Vector2i in _raw_by:
		var g := _ground_contact(tile, route)
		if g == _ground_by[tile]:
			continue
		var t: SimTower = sim.towers[tile]
		var k: float = 1.0 + _aura_by.get(tile, 0.0)
		var raw := _raw(t.id, t.level, g, _air_contact.get(tile, 0))
		var old: PackedFloat32Array = _raw_by[tile]
		for f in out.size():
			out[f] += (raw[f] - old[f]) * k
	return out


## Lists every action with its gain in value per gold, best first.
func _evaluate() -> void:
	_dirty = false
	_actions.clear()
	_read_board()
	var now := _value(_totals)
	for tile: Vector2i in sim.towers:
		var t: SimTower = sim.towers[tile]
		var cost := TowerDefs.upgrade_cost(t.id, t.level)
		if cost <= 0:
			continue
		var gain := 0.0
		if t.stat("kind") == &"aura":
			var r: float = TowerDefs.stat(t.id, "range", t.level + 1)
			gain = _bard_gain(tile, _aura_gain(t.id, t.level + 1), r, _totals)
		else:
			var g: int = _ground_by[tile]
			var up := _raw(t.id, t.level + 1, g, _air_contact.get(tile, 0))
			var old: PackedFloat32Array = _raw_by[tile]
			for f in up.size():
				up[f] -= old[f]
			gain = _value(_plus(_totals, up, 1.0 + _aura_by.get(tile, 0.0))) - now
		_push(&"upgrade", tile, t.id, cost, gain)
	for tile in plan:
		if not sim.towers.has(tile) and not _skipped.has(tile):
			_add_builds(tile, now)
	_add_step(now)
	_add_fusions(now)
	_actions.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.ratio > y.ratio)


## Every tower that could go on `tile`, valued with the route it would leave.
func _add_builds(tile: Vector2i, now: float) -> void:
	var route := _route
	var base := _totals
	if _route_shift.has(tile):
		var field := FlowField.new()
		sim.grid.set_blocked(tile, true)
		field.compute(sim.grid)
		sim.grid.set_blocked(tile, false)
		if not sim.grid.spawn_tiles.any(field.reachable):
			_skipped[tile] = true
			return
		route = _route_of(field)
		base = _totals_on(route)
	var base_value := _value(base)
	var g := _ground_contact(tile, route)
	var a: int = _air_contact.get(tile, 0)
	var aura := _aura_at(tile)
	for id in BUILDS:
		var gain := base_value - now
		if id == &"bard":
			var r: float = TowerDefs.stat(id, "range", 1)
			gain += _bard_gain(tile, _aura_gain(id, 1), r, base)
		elif g + a > 0:
			gain = _value(_plus(base, _raw(id, 1, g, a), 1.0 + aura)) - now
		_push(&"build", tile, id, TowerDefs.build_cost(id), gain)


func _push(kind: StringName, tile: Vector2i, id: StringName, cost: int, gain: float) -> void:
	if gain <= 0.0:
		return
	if _rng:
		gain *= _rng.randf_range(0.9, 1.1)
	_actions.append({"kind": kind, "tile": tile, "id": id, "cost": cost, "ratio": gain / cost})


## The strongest Bard aura that would cover a tower built on `tile`.
func _aura_at(tile: Vector2i) -> float:
	var best := 0.0
	for b: Vector2i in sim.towers:
		var bard: SimTower = sim.towers[b]
		if bard.stat("kind") != &"aura":
			continue
		if Grid.center(b).distance_to(Grid.center(tile)) <= float(bard.stat("range")):
			best = maxf(best, _aura_gain(bard.id, bard.level))
	return best


## Tiles whose tower would change the route: the route's own tiles and the
## side tiles of its diagonal steps (creeps never cut a corner past a tower).
func _shifting_tiles() -> Dictionary:
	var out := {}
	var r := sim.field.route()
	var prev := Vector2i(-99, -99)
	for i in range(1, r.size() - 1):
		var t := Grid.tile_at(r[i])
		out[t] = true
		if prev.x != -99 and prev.x != t.x and prev.y != t.y:
			out[Vector2i(prev.x, t.y)] = true
			out[Vector2i(t.x, prev.y)] = true
		prev = t
	return out


# --- Growing the serpentine -----------------------------------------------


## The serpentine grows a step at a time: close the first open wall, after
## first walling off the next wall between this wall's gap and where the route
## crosses it now, so the creeps walk the whole new lane and then rejoin the
## street. The next one to STEPS_AHEAD steps are each valued as one purchase,
## with the route they leave, per gold of all their towers; the best is bought
## a tower at a time.
func _add_step(now: float) -> void:
	var tiles: Array[Vector2i] = []
	var best := 0.0
	var first := Vector2i(-1, -1)
	var route := _route
	var best_route := _route
	for _s in STEPS_AHEAD:
		var more := _step_tiles(route)
		if more.is_empty():
			break
		for t in more:
			sim.grid.set_blocked(t, true)
		tiles.append_array(more)
		var field := FlowField.new()
		field.compute(sim.grid)
		if not sim.grid.spawn_tiles.any(field.reachable):
			break
		route = _route_of(field)
		var r := _step_ratio(tiles, route, now)
		if r > best:
			best = r
			first = tiles[0]
			best_route = route
	for t in tiles:
		sim.grid.set_blocked(t, false)
	if best <= 0.0:
		return
	var id := _best_build(first, best_route, _totals_on(best_route))
	(
		_actions
		. append(
			{
				"kind": &"build",
				"tile": first,
				"id": id,
				"cost": TowerDefs.build_cost(id),
				"ratio": best,
			}
		)
	)


## Value per gold of building `tiles` (each with its best tower) on `route`.
func _step_ratio(tiles: Array[Vector2i], route: Dictionary, now: float) -> float:
	var base := _totals_on(route)
	var total := 0
	for tile in tiles:
		var id := _best_build(tile, route, base)
		var a: int = _air_contact.get(tile, 0)
		base = _plus(base, _raw(id, 1, _ground_contact(tile, route), a), 1.0 + _aura_at(tile))
		total += TowerDefs.build_cost(id)
	return (_value(base) - now) / total


## The tower that adds most per gold on `tile` with this route and board.
func _best_build(tile: Vector2i, route: Dictionary, base: PackedFloat32Array) -> StringName:
	var g := _ground_contact(tile, route)
	var a: int = _air_contact.get(tile, 0)
	var aura := _aura_at(tile)
	var before := _value(base)
	var pick: StringName = &"archer"
	var best := -INF
	for id in BUILDS:
		if id == &"bard":
			continue
		var gain := _value(_plus(base, _raw(id, 1, g, a), 1.0 + aura)) - before
		if gain / TowerDefs.build_cost(id) > best:
			best = gain / TowerDefs.build_cost(id)
			pick = id
	return pick


## The open tiles of the next step on the grid as it stands (with any tiles
## of earlier steps marked blocked), for a board whose route is `route`.
func _step_tiles(route: Dictionary) -> Array[Vector2i]:
	for k in _walls.size():
		var rest := _open_in_row(_walls[k][0])
		if rest.is_empty():
			continue
		var out: Array[Vector2i] = []
		if k + 1 < _walls.size():
			var x := _crossing(_walls[k + 1][0], route)
			var gaps: Array = _walls[k][1]
			var gap: float = gaps.reduce(func(s: float, c: int) -> float: return s + c, 0.0)
			gap /= gaps.size()
			for t in _open_in_row(_walls[k + 1][0]):
				if x >= 0 and (t.x - x) * (gap - x) > 0:
					out.append(t)
		# Off-route tiles first: the tile the creeps walk through closes it.
		rest.sort_custom(
			func(a: Vector2i, b: Vector2i) -> bool: return not route.has(a) and route.has(b)
		)
		out.append_array(rest)
		return out
	return []


func _open_in_row(row: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t in plan:
		if t.y == row and not sim.grid.is_blocked(t) and not _skipped.has(t):
			out.append(t)
	return out


## The column where `route` crosses `row`, or -1.
func _crossing(row: int, route: Dictionary) -> int:
	for t: Vector2i in route:
		if t.y == row:
			return t.x
	return -1


# --- Fusions --------------------------------------------------------------


## Two level-3 towers of a family fuse into its Epic on the tile with more
## contact; the other tile is rebuilt with an Archer at once, so the maze
## keeps its length. Between waves only.
func _add_fusions(now: float) -> void:
	var refill := TowerDefs.build_cost(&"archer")
	for family: StringName in TowerDefs.FUSIONS:
		var epic: StringName = TowerDefs.FUSIONS[family]
		var ready: Array[Vector2i] = []
		for tile: Vector2i in _raw_by:
			var t: SimTower = sim.towers[tile]
			if not t.is_epic() and t.family() == family and t.level == TowerDefs.MAX_LEVEL:
				ready.append(tile)
		if ready.size() < 2:
			continue
		ready.sort_custom(func(x: Vector2i, y: Vector2i) -> bool: return _reach(x) > _reach(y))
		var keep := ready[0]
		var free := ready[ready.size() - 1]
		var t := _totals.duplicate()
		for tile in [keep, free]:
			t = _plus(t, _raw_by[tile], -1.0 - _aura_by.get(tile, 0.0))
		var ak: int = _air_contact.get(keep, 0)
		var af: int = _air_contact.get(free, 0)
		t = _plus(t, _raw(epic, 1, _ground_by[keep], ak), 1.0 + _aura_by.get(keep, 0.0))
		t = _plus(t, _raw(&"archer", 1, _ground_by[free], af), 1.0 + _aura_by.get(free, 0.0))
		var gain := _value(t) - now
		var cost: int = TowerDefs.TOWERS[epic].fuse_cost + refill
		if gain > 0.0:
			(
				_actions
				. append(
					{
						"kind": &"fuse",
						"tile": keep,
						"free": free,
						"id": epic,
						"cost": cost,
						"ratio": gain / cost,
					}
				)
			)


func _reach(tile: Vector2i) -> int:
	return _ground_by[tile] + _air_contact.get(tile, 0)


func _fuse(a: Dictionary) -> void:
	if sim.fuse(a.tile, a.free):
		sim.build(a.free, &"archer")
