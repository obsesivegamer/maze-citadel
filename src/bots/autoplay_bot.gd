class_name AutoplayBot
extends RefCounted
## Plays a GameSim headless with a fixed strategy, the way a player would:
## a serpentine maze of 1-tile walls built from the portal side (on a
## fixed-lane map, towers along the lane: lane_plan), then upgrades and
## fusions. Used by the balance runs and by --autoplay.

## The serpentine per map as [row, gap columns, centre], built in order and
## each wall from its centre column outwards (default the board's middle).
## Map ruins count as wall already. On the Rampart the opening wall grows from
## where the route from the north-west portal crosses it; the bot leaves the
## west breach open and plugs the other two, so both halves run full width.
const WALLS := {
	&"citadel": [[3, [19]], [7, [0]], [11, [19]], [15, [0]], [19, [19]], [23, [0]]],
	&"rampart":
	[
		[3, [19], 6.5],
		[7, [0]],
		[11, [19]],
		[13, [1, 2]],
		[17, [19]],
		[21, [0]],
		[25, [19]],
	],
}
## The same per map for the eletd rules, where a tower reaches only the tiles
## around it: corridors one tile wide, so every wall tower borders two lanes.
## The Rampart's boulders sit in wider corridors, and its east breach stays open.
const WALLS_ELETD := {
	&"citadel":
	[
		[3, [19]],
		[5, [0]],
		[7, [19]],
		[9, [0]],
		[11, [19]],
		[13, [0]],
		[15, [19]],
		[17, [0]],
		[19, [19]],
		[21, [0]],
		[23, [19]],
		[25, [0]],
	],
	&"rampart":
	[
		[2, [19], 5.5],
		[4, [0]],
		[8, [19]],
		[10, [0]],
		[13, [17, 18]],
		[15, [0]],
		[17, [19]],
		[21, [0]],
		[23, [19]],
		[25, [0]],
	],
}
const WALL_CENTER := 9.5
const DECIDE_EVERY := 1.0
const UPGRADE_RESERVE := 120

## Tower for the k-th wall slot, per strategy. The camper and idle bots
## (Camper) build Archers wherever the owner's game has nothing else.
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
	&"novice": [&"archer", &"archer", &"cannon", &"archer", &"frost"],
	&"camper": [&"archer"],
	&"idle": [&"archer"],
}
## Element picks under the eletd rules (SimElements), spent as soon as they
## come: the first choice in the list not yet taken as often as it is listed.
## The smart strategy's RouteLiner picks for itself.
const PICKS := {
	&"archers": [&"interest", &"interest", &"interest"],
	&"no_air":
	[&"dark", &"verdant", &"dark", &"verdant", &"dark", &"verdant", &"interest", &"interest"],
	&"novice":
	[&"aqua", &"light", &"dark", &"flame", &"stone", &"verdant", &"interest", &"interest"],
}
## Seconds between decisions, for strategies slower than DECIDE_EVERY.
const DECIDE_SLOWLY := {&"novice": 4.0}
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
## What a player saves up for when a boss is coming: armor shred and siege.
const BOSS_PREP: Array[StringName] = [&"runesmith", &"demolisher", &"cannon"]
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
	&"novice": [&"archer", &"cannon", &"frost"],
}

var sim: GameSim
var strategy: StringName
var plan: Array[Vector2i] = []
## Placement.Result → how many planned tiles were given up for that reason.
var skip_reasons := {}
var _next_slot := 0
var _skipped: Array[Vector2i] = []
var _timer := 0.0
## Seed 0 plays the plain plan; other seeds jitter timing, wall order and
## tower picks so balance runs sample several players, not one trajectory.
var _rng: RandomNumberGenerator
## The smart strategy under the eletd rules (RouteLiner); null otherwise.
var _liner: RouteLiner
## The camper and idle strategies (Camper); null otherwise.
var _camper: Camper


func _init(p_sim: GameSim, p_strategy: StringName, p_seed := 0) -> void:
	sim = p_sim
	strategy = p_strategy
	if p_seed != 0:
		_rng = RandomNumberGenerator.new()
		_rng.seed = p_seed
		_timer = _rng.randf() * DECIDE_EVERY
	var grid := sim.grid
	var walls: Dictionary = WALLS_ELETD if sim.adjacent_reach() else WALLS
	if not grid.lane.is_empty():
		plan = lane_plan(grid)
	for wall: Array in walls.get(grid.map, []):
		# Build each wall from the middle outwards: the opening towers sit on the
		# straight route, and the wall bends the path as it grows.
		var mid: float = wall[2] if wall.size() > 2 else WALL_CENTER
		var cols := range(Grid.COLS)
		cols.sort_custom(func(a: int, b: int) -> bool: return absf(a - mid) < absf(b - mid))
		for col in cols:
			var tile := Vector2i(col, wall[0])
			if not col in wall[1] and not grid.is_blocked(tile) and not grid.is_reserved(tile):
				plan.append(tile)
	if strategy == &"smart" and sim.adjacent_reach():
		_liner = RouteLiner.new(sim, plan, walls.get(grid.map, []), _rng)
		skip_reasons = _liner.skip_reasons
	if strategy in [&"camper", &"idle"]:
		_camper = Camper.new(sim, strategy == &"idle", plan)
		plan = _camper.plan
		skip_reasons = _camper.skip_reasons


## On a fixed-lane map there is no maze to build: the plan is every tile
## beside the lane, in the order the creeps pass them, each tile's sides
## before its corners.
static func lane_plan(grid: Grid) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t in grid.lane:
		for dir in FlowField.DIRS:
			var n := t + dir
			if grid.is_ground(n) and not grid.is_reserved(n) and not n in out:
				out.append(n)
	return out


func step() -> void:
	_timer -= GameSim.DT
	if _timer <= 0.0:
		var every: float = DECIDE_SLOWLY.get(strategy, DECIDE_EVERY)
		_timer = every * (_rng.randf_range(0.6, 1.4) if _rng else 1.0)
		_decide()
	sim.step()


func _decide() -> void:
	if _liner:
		_liner.decide()
		return
	if _camper:
		_camper.decide()
		return
	_spend_picks()
	# Fill the maze first; when short of gold for the next wall slot, upgrade.
	# A novice adds one tower per decision, so its maze grows late.
	var builds_left := 1 if strategy == &"novice" else plan.size()
	while _next_slot < plan.size() and builds_left > 0:
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
			builds_left -= 1
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
		if _rng:
			d *= _rng.randf_range(1.0, 1.5)
		if d < best_d:
			best_d = d
			best = tile
	return best


func _pattern_at(slot: int) -> StringName:
	if strategy == &"smart":
		return _counter_pick(slot)
	var p: Array = PATTERNS[strategy]
	var id: StringName = p[slot % p.size()]
	# Under eletd, a tower whose element isn't picked yet gives way to the
	# pattern's first one that needs none.
	if sim.elements.needs(id) != "":
		id = p.filter(func(x: StringName) -> bool: return sim.elements.needs(x) == "")[0]
	return id


## Reads the upcoming wave like a player reading the preview: alternate the
## element counter and the armor-class counter, with cheap archers as filler
## and support towers once the economy allows.
func _counter_pick(slot: int) -> StringName:
	# Once the current wave is all on the field, the towers it meets are
	# mostly built; plan for the one after.
	var w := clampi(sim.wave + (0 if sim.spawning() else 1), 1, 40)
	var entries := WaveDefs.spawn_list(w, sim.rules)
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
			# Composite armor (eletd) has no element counter: answer its armor.
			options = ELEMENT_COUNTER.get(element, CLASS_COUNTER[main_class])
		1:
			options = CLASS_COUNTER[main_class]
		2:
			options = [&"plague"] if heals else [&"archer"]
		_:
			var bard := sim.wave >= 8 and slot % 12 == 3
			options = [&"bard"] if bard else CLASS_COUNTER[main_class]
	if classes.has(&"air") and slot % 4 == 0:
		options = CLASS_COUNTER[&"air"]
	# A player who sees armor, air or a boss in the next two waves and owns
	# almost nothing that answers it buys the answer first, saving up if need be.
	# Under eletd the top bar also shows the wave after next, so a player sees
	# two waves ahead even while the current one is still coming in.
	var seen := entries + WaveDefs.spawn_list(mini(w + 1, 40), sim.rules)
	if sim.adjacent_reach() and sim.spawning():
		seen += WaveDefs.spawn_list(mini(w + 2, 40), sim.rules)
	var threats := {}
	for e in seen:
		threats[CreepDefs.CREEPS[e[0]].class] = true
	for cls in [&"air", &"armored", &"boss"]:
		if threats.has(cls) and _count(CLASS_COUNTER[cls]) < 2:
			options = CLASS_COUNTER[cls]
			break
	if _rng and options.size() > 1 and _rng.randf() < 0.3:
		options = options.duplicate()
		options.reverse()
	# The best option that's affordable now; otherwise save for the cheapest.
	for id in options:
		if sim.gold >= TowerDefs.build_cost(id):
			return id
	var cheapest: StringName = options[0]
	for id in options:
		if TowerDefs.build_cost(id) < TowerDefs.build_cost(cheapest):
			cheapest = id
	return cheapest


func _count(ids: Array) -> int:
	var n := 0
	for t in sim.towers.values():
		if t.id in ids:
			n += 1
	return n


func _upgrade_one(reserve: int) -> void:
	var order: Array = UPGRADE_PRIORITY[strategy]
	# With a boss coming next, a player stops topping up archers and saves for
	# the boss counters until those are maxed.
	if strategy == &"smart" and _boss_ahead() and _upgradable(BOSS_PREP):
		order = BOSS_PREP
	for id in order:
		for tile in plan:
			var t := sim.tower_at(tile)
			if t == null or t.id != id or t.level >= t.max_level():
				continue
			if sim.elements.needs(t.id, t.level + 1) != "":
				continue
			if sim.gold >= TowerDefs.upgrade_cost(t.id, t.level) + reserve:
				sim.upgrade(tile)
				return


func _spend_picks() -> void:
	var counts := {}
	for choice: StringName in PICKS.get(strategy, []):
		counts[choice] = counts.get(choice, 0) + 1
		if sim.elements.taken(choice) < counts[choice] and sim.elements.pick(sim, choice):
			return


## Fuses between waves only, and only with gold to rebuild the freed wall
## tile at once, so a fusion never shortens the maze while creeps walk it.
func _try_fuse() -> void:
	if strategy != &"smart" or sim.phase != GameSim.Phase.BUILD:
		return
	for family in TowerDefs.FUSIONS:
		var ready: Array[Vector2i] = []
		for tile in plan:
			var t := sim.tower_at(tile)
			if t != null and not t.is_epic() and t.family() == family and t.level == 3:
				ready.append(tile)
		if ready.size() < 2:
			continue
		var refill := TowerDefs.build_cost(_pattern_at(plan.find(ready[1])))
		if sim.gold < int(TowerDefs.TOWERS[TowerDefs.FUSIONS[family]].fuse_cost) + refill:
			continue
		if sim.fuse(ready[0], ready[1]):
			# Re-fill the freed wall tile so the maze stays long.
			_next_slot = mini(_next_slot, plan.find(ready[1]))


## A boss in the wave being planned for (the next one, as in _counter_pick).
func _boss_ahead() -> bool:
	var w := maxi(sim.wave + (0 if sim.spawning() else 1), 1)
	return WaveDefs.has_boss(w)


func _upgradable(ids: Array) -> bool:
	for t in sim.towers.values():
		if t.id in ids and t.level < t.max_level():
			return true
	return false
