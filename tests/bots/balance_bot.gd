extends RefCounted
## Plays a GameSim headless with a fixed strategy, the way a player would:
## a serpentine maze of 1-tile walls built from the portal side, then
## upgrades and fusions. Used by tests/bots/run_balance.gd.

const WALL_ROWS: Array[int] = [3, 7, 11, 15, 19, 23]
const DECIDE_EVERY := 1.0
const UPGRADE_RESERVE := 120

## Tower for the k-th wall slot, per strategy.
const PATTERNS := {
	&"smart":
	[
		&"archer",
		&"archer",
		&"frost",
		&"archer",
		&"cannon",
		&"archer",
		&"plague",
		&"archer",
		&"runesmith",
		&"archer",
		&"cannon",
		&"bard",
	],
	&"archers": [&"archer"],
	&"no_air": [&"cannon", &"cannon", &"roots", &"cannon", &"shadow"],
}
const ELEMENT_COUNTER := {
	&"dark": [&"ballista", &"archer"],
	&"aqua": [&"shadow", &"plague"],
	&"flame": [&"frost"],
	&"verdant": [&"demolisher", &"cannon"],
	&"stone": [&"roots"],
	&"light": [&"runesmith"],
}
const CLASS_COUNTER := {
	&"armored": [&"demolisher", &"cannon"],
	&"air": [&"ballista", &"archer"],
	&"light": [&"archer"],
	&"boss": [&"runesmith", &"cannon"],
}
const UPGRADE_PRIORITY := {
	&"smart":
	[
		&"demolisher",
		&"cannon",
		&"ballista",
		&"roots",
		&"frost",
		&"shadow",
		&"runesmith",
		&"plague",
		&"bard",
		&"archer",
	],
	&"archers": [&"archer"],
	&"no_air": [&"cannon", &"roots", &"shadow"],
}

var sim: GameSim
var strategy: StringName
var plan: Array[Vector2i] = []
## Placement.Result → how many planned tiles were given up for that reason.
var skip_reasons := {}
var _next_slot := 0
var _skipped: Array[Vector2i] = []
var _timer := 0.0


func _init(p_sim: GameSim, p_strategy: StringName) -> void:
	sim = p_sim
	strategy = p_strategy
	for i in WALL_ROWS.size():
		var gap := Grid.COLS - 1 if i % 2 == 0 else 0
		# Build each wall from the middle outwards: the opening towers sit on the
		# straight route, and the wall bends the path as it grows.
		var cols := range(Grid.COLS)
		cols.sort_custom(func(a: int, b: int) -> bool: return absf(a - 9.5) < absf(b - 9.5))
		for col in cols:
			if col != gap:
				plan.append(Vector2i(col, WALL_ROWS[i]))


func step() -> void:
	_timer -= GameSim.DT
	if _timer <= 0.0:
		_timer = DECIDE_EVERY
		_decide()
	sim.step()


func _decide() -> void:
	# Fill the maze first; when short of gold for the next wall slot, upgrade.
	while _next_slot < plan.size():
		if sim.tower_at(plan[_next_slot]) != null or plan[_next_slot] in _skipped:
			_next_slot += 1
			continue
		var tile := _slot_nearest_route()
		var id := _pattern_at(_next_slot)
		var r := sim.check_build(tile, id)
		if r == Placement.Result.NO_GOLD:
			break
		if r == Placement.Result.OK:
			sim.build(tile, id)
		elif r != Placement.Result.CREEP_ON_TILE:
			_skipped.append(tile)
			skip_reasons[r] = skip_reasons.get(r, 0) + 1
		else:
			break
	# Maze length is the best investment, so upgrades only take surplus gold
	# until the maze is finished.
	var reserve := 0 if _next_slot >= plan.size() else UPGRADE_RESERVE
	_upgrade_one(reserve)
	_try_fuse()


## Among the open slots of the wall being built, the one creeps pass closest
## to, so each new tower extends the wall where the creeps actually walk.
func _slot_nearest_route() -> Vector2i:
	var row := plan[_next_slot].y
	var route := sim.field.route()
	var best := plan[_next_slot]
	var best_d := INF
	for i in range(_next_slot, plan.size()):
		var tile := plan[i]
		if tile.y != row:
			break
		if sim.tower_at(tile) != null or tile in _skipped:
			continue
		var c := Grid.center(tile)
		var d := INF
		for p in route:
			d = minf(d, c.distance_squared_to(p))
		if d < best_d:
			best_d = d
			best = tile
	return best


func _pattern_at(slot: int) -> StringName:
	if strategy == &"smart":
		return _counter_pick(slot)
	var p: Array = PATTERNS[strategy]
	return p[slot % p.size()]


## Reads the upcoming wave like a player reading the preview: alternate the
## element counter and the armor-class counter, with cheap archers as filler
## and support towers once the economy allows.
func _counter_pick(slot: int) -> StringName:
	var w := clampi(sim.wave + (1 if sim.phase == GameSim.Phase.BUILD else 0), 1, 40)
	var entries := WaveDefs.spawn_list(w)
	var element: StringName = entries[0][1]
	var classes := {}
	for e in entries:
		var cls: StringName = CreepDefs.CREEPS[e[0]].class
		classes[cls] = classes.get(cls, 0) + 1
	var main_class: StringName = classes.keys().reduce(
		func(a: StringName, b: StringName) -> StringName:
			return a if classes[a] >= classes[b] else b
	)
	var heals := entries.any(func(e: Array) -> bool: return e[0] == &"priestess")
	var options: Array
	match slot % 4:
		0:
			options = ELEMENT_COUNTER[element]
		1:
			options = CLASS_COUNTER[main_class]
		2:
			options = [&"plague"] if heals else [&"archer"]
		_:
			var bard := sim.wave >= 8 and slot % 12 == 3
			options = [&"bard"] if bard else CLASS_COUNTER[main_class]
	if classes.has(&"air") and slot % 4 == 0:
		options = CLASS_COUNTER[&"air"]
	# The best option that's affordable now; otherwise save for the cheapest.
	for id in options:
		if sim.gold >= TowerDefs.build_cost(id):
			return id
	var cheapest: StringName = options[0]
	for id in options:
		if TowerDefs.build_cost(id) < TowerDefs.build_cost(cheapest):
			cheapest = id
	return cheapest


func _upgrade_one(reserve: int) -> void:
	for id in UPGRADE_PRIORITY[strategy]:
		for tile in plan:
			var t := sim.tower_at(tile)
			if t == null or t.id != id or t.level >= t.max_level():
				continue
			if sim.gold >= TowerDefs.upgrade_cost(t.id, t.level) + reserve:
				sim.upgrade(tile)
				return


func _try_fuse() -> void:
	if strategy != &"smart":
		return
	for family in [&"elven", &"horde"]:
		var ready: Array[Vector2i] = []
		for tile in plan:
			var t := sim.tower_at(tile)
			if t != null and not t.is_epic() and t.family() == family and t.level == 3:
				ready.append(tile)
		if ready.size() >= 2 and sim.fuse(ready[0], ready[1]):
			# Re-fill the freed wall tile so the maze stays long.
			_next_slot = mini(_next_slot, plan.find(ready[1]))
