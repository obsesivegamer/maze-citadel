extends "res://tests/test_case.gd"
## The no-build band by the portal (EletdRules.PORTAL_ROWS): under the Element
## TD rules nothing is built on the board's top rows, so creeps walk a few
## metres before a tower can reach them. Classic keeps the board open.

const R := Placement.Result
const Bot := preload("res://src/bots/autoplay_bot.gd")
const BAND := EletdRules.PORTAL_ROWS
const STRATEGIES: Array[StringName] = [&"smart", &"archers", &"novice", &"camper", &"idle"]


func _sim(map: StringName, rules := &"eletd") -> GameSim:
	var sim := GameSim.new(map)
	sim.rules = rules
	sim.gold = 1_000_000
	return sim


func test_band_refuses_builds_under_eletd() -> void:
	for map in MapDefs.ORDER:
		var sim := _sim(map)
		check_eq(sim.grid.portal_rows, BAND, "%s: band rows" % map)
		for y in BAND:
			for x in Grid.COLS:
				var t := Vector2i(x, y)
				var want := R.RESERVED if t in sim.grid.spawn_tiles else R.NEAR_PORTAL
				check_eq(sim.check_build(t, &"archer"), want, "%s: %s" % [map, t])
		check_eq(Placement.describe(R.NEAR_PORTAL), "Too close to the portal", "message")
		var below := Vector2i(0, BAND)
		if not sim.grid.is_lane(below) and not sim.grid.is_obstacle(below):
			check_eq(sim.check_build(below, &"archer"), R.OK, "%s: the row below builds" % map)
		var at := Vector2i(Grid.COLS - 1, BAND - 1)
		check_eq(sim.build(at, &"archer"), R.NEAR_PORTAL, "%s: build refused" % map)
		var refused := sim.drain_events().filter(
			func(e: Dictionary) -> bool: return e.type == &"build_refused"
		)
		check_eq(refused.size(), 1, "%s: one refusal" % map)
		if refused.size() == 1:
			check_eq(refused[0].reason, R.NEAR_PORTAL, "%s: its reason" % map)
		check(sim.towers.is_empty(), "%s: nothing built" % map)


func test_classic_builds_next_to_the_portal() -> void:
	for map in [&"citadel", &"rampart"]:
		var sim := _sim(map, &"classic")
		check_eq(sim.grid.portal_rows, 0, "%s: no band" % map)
		var beside := sim.grid.spawn_tiles[0] + Vector2i(-1, 0)
		check_eq(sim.build(beside, &"archer"), R.OK, "%s: beside the portal" % map)
		check_eq(sim.build(Vector2i(0, 1), &"archer"), R.OK, "%s: row 1" % map)
		check_eq(sim.check_build(sim.grid.spawn_tiles[0], &"archer"), R.RESERVED, "portal")


## Every bot's plan, and what it builds while the opening waves run.
func test_bots_never_plan_the_band() -> void:
	for map in MapDefs.ORDER:
		for strategy in STRATEGIES:
			var sim := GameSim.new(map)
			sim.rules = &"eletd"
			var bot := Bot.new(sim, strategy)
			var at := "%s/%s" % [map, strategy]
			check(not bot.plan.is_empty(), "%s: a plan" % at)
			for t in bot.plan:
				if t.y < BAND:
					failures.append("%s plans %s in the band" % [at, t])
					break
			while sim.wave < 2 and sim.phase != GameSim.Phase.DEFEAT:
				bot.step()
				for e in sim.drain_events():
					if e.type == &"build_refused" and e.reason == R.NEAR_PORTAL:
						failures.append("%s tried %s in the band" % [at, e.tile])
			for t: Vector2i in sim.towers:
				check(t.y >= BAND, "%s: tower on %s" % [at, t])


## Flyers cross the band in a straight line: no tile a tower may stand on
## reaches them there, where with the band lifted one reaches them at once.
func test_flyers_first_metres_are_out_of_reach() -> void:
	for map in MapDefs.ORDER:
		var banded := _first_reach(_sim(map))
		check(banded >= 5.0, "%s: first reached after %.1f m" % [map, banded])
		check(banded < 10.0, "%s: reached soon after the band (%.1f m)" % [map, banded])
		var open := _sim(map)
		open.grid.portal_rows = 0
		check(_first_reach(open) < 1.0, "%s: reached at the portal with no band" % map)


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
