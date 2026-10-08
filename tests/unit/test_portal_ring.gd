extends "res://tests/test_case.gd"
## The ring round the portal (EletdRules.portal_ring): under the Element TD
## rules nothing is built on the six tiles touching the portal, so creeps step
## off it before a tower stands beside them. The rest of the top rows builds,
## and classic keeps the board open.

const R := Placement.Result
const Bot := preload("res://src/bots/autoplay_bot.gd")
const STRATEGIES: Array[StringName] = [&"smart", &"archers", &"novice", &"camper", &"idle"]


func _sim(map: StringName, rules := &"eletd") -> GameSim:
	var sim := GameSim.new(map)
	sim.rules = rules
	sim.gold = 1_000_000
	return sim


## The tiles touching a portal tile, side or corner, that are not portal tiles.
func _touching(sim: GameSim) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in 3:
		for x in Grid.COLS:
			var t := Vector2i(x, y)
			if t in sim.grid.spawn_tiles:
				continue
			for s in sim.grid.spawn_tiles:
				if absi(s.x - x) <= 1 and absi(s.y - y) <= 1 and not t in out:
					out.append(t)
	return out


func test_ring_tiles_refuse_builds_under_eletd() -> void:
	check_eq(
		_touching(_sim(&"citadel")),
		[
			Vector2i(8, 0),
			Vector2i(11, 0),
			Vector2i(8, 1),
			Vector2i(9, 1),
			Vector2i(10, 1),
			Vector2i(11, 1)
		],
		"the Citadel's ring"
	)
	for map in MapDefs.ORDER:
		var sim := _sim(map)
		var ring := _touching(sim)
		check_eq(ring.size(), 6, "%s: six tiles" % map)
		for t in ring:
			check_eq(sim.check_build(t, &"archer"), R.NEAR_PORTAL, "%s: %s" % [map, t])
		for t in sim.grid.spawn_tiles:
			check_eq(sim.check_build(t, &"archer"), R.RESERVED, "%s: portal %s" % [map, t])
		check_eq(Placement.describe(R.NEAR_PORTAL), "Too close to the portal", "message")
		var at := ring[ring.size() - 1]
		check_eq(sim.build(at, &"archer"), R.NEAR_PORTAL, "%s: build refused" % map)
		var refused := sim.drain_events().filter(
			func(e: Dictionary) -> bool: return e.type == &"build_refused"
		)
		check_eq(refused.size(), 1, "%s: one refusal" % map)
		if refused.size() == 1:
			check_eq(refused[0].reason, R.NEAR_PORTAL, "%s: its reason" % map)
		check(sim.towers.is_empty(), "%s: nothing built" % map)


## Every other tile of rows 0 to 2 takes a tower under Element TD rules, and
## every one of them, ring included, under classic.
func test_the_rest_of_the_top_rows_builds() -> void:
	for map in MapDefs.ORDER:
		for rules: StringName in [&"eletd", &"classic"]:
			if not MapDefs.offered(map, rules):
				continue
			var sim := _sim(map, rules)
			var ring: Array[Vector2i] = []
			if rules == &"eletd":
				ring = _touching(sim)
			for y in 3:
				for x in Grid.COLS:
					var t := Vector2i(x, y)
					if t in ring or t in sim.grid.spawn_tiles:
						continue
					var want := R.OK
					if sim.grid.is_obstacle(t):
						want = R.OBSTACLE
					elif sim.grid.is_lane(t):
						want = R.LANE
					check_eq(sim.check_build(t, &"archer"), want, "%s/%s: %s" % [map, rules, t])
			if rules == &"classic":
				for t in _touching(sim):
					check_eq(sim.check_build(t, &"archer"), R.OK, "%s classic: %s" % [map, t])


func test_classic_builds_next_to_the_portal() -> void:
	for map in [&"citadel", &"rampart"]:
		var sim := _sim(map, &"classic")
		check(not sim.grid.portal_ring, "%s: no ring" % map)
		var beside := sim.grid.spawn_tiles[0] + Vector2i(-1, 0)
		check_eq(sim.build(beside, &"archer"), R.OK, "%s: beside the portal" % map)
		check_eq(sim.build(Vector2i(0, 1), &"archer"), R.OK, "%s: row 1" % map)
		check_eq(sim.check_build(sim.grid.spawn_tiles[0], &"archer"), R.RESERVED, "portal")


## Every bot's plan, and what it builds while the opening waves run.
func test_bots_never_plan_the_ring() -> void:
	for map in MapDefs.ORDER:
		for strategy in STRATEGIES:
			var sim := GameSim.new(map)
			sim.rules = &"eletd"
			var bot := Bot.new(sim, strategy)
			var at := "%s/%s" % [map, strategy]
			check(not bot.plan.is_empty(), "%s: a plan" % at)
			for t in bot.plan:
				if sim.grid.near_portal(t):
					failures.append("%s plans %s in the ring" % [at, t])
					break
			while sim.wave < 2 and sim.phase != GameSim.Phase.DEFEAT:
				bot.step()
				for e in sim.drain_events():
					if e.type == &"build_refused" and e.reason == R.NEAR_PORTAL:
						failures.append("%s tried %s in the ring" % [at, e.tile])
			for t: Vector2i in sim.towers:
				check(not sim.grid.near_portal(t), "%s: tower on %s" % [at, t])


## Flyers leave the portal in a straight line: no tile a tower may stand on
## reaches them until they clear the ring, where with the ring lifted one
## reaches them at once.
func test_flyers_first_metres_are_out_of_reach() -> void:
	for map in MapDefs.ORDER:
		var ringed := _first_reach(_sim(map))
		check(ringed >= 1.5, "%s: first reached after %.1f m" % [map, ringed])
		check(ringed < 5.0, "%s: reached just past the ring (%.1f m)" % [map, ringed])
		var open := _sim(map)
		open.grid.portal_ring = false
		check(_first_reach(open) < 1.0, "%s: reached at the portal with no ring" % map)


## Metres a Harpy flies from the portal before a tower on some tile that takes
## one (reserved, ruin and lane tiles don't) would reach it.
func _first_reach(sim: GameSim) -> float:
	var stands: Array[SimTower] = []
	for i in Grid.COLS * Grid.ROWS:
		var t := Grid.tile_of(i)
		if not (sim.grid.is_reserved(t) or sim.grid.is_obstacle(t) or sim.grid.is_lane(t)):
			var stub := SimTower.new()
			stub.pos = Grid.center(t)
			stands.append(stub)
	sim.countdown = -1.0
	var c := sim.spawn_creep(&"harpy", &"flame", 1, sim.grid.spawn_point)
	for _i in int(30.0 / GameSim.DT):
		if stands.any(func(stub: SimTower) -> bool: return sim.reaches(stub, c)):
			return c.pos.distance_to(sim.grid.spawn_point)
		sim.step()
	return INF
