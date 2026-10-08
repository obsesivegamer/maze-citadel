extends "res://tests/test_case.gd"
## The Winding Causeway (docs/maps.md): creeps keep to a fixed lane and the
## player builds on the ground beside it.

const R := Placement.Result
const Bot := preload("res://src/bots/autoplay_bot.gd")
const MAP := &"causeway"


func _route_tiles(field: FlowField) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := field.route()
	for i in range(1, r.size() - 1):
		out.append(Grid.tile_at(r[i]))
	return out


func _eletd_sim() -> GameSim:
	var sim := GameSim.new(MAP)
	sim.rules = &"eletd"
	return sim


func test_lane_runs_unbroken_from_portal_to_gate() -> void:
	var grid := Grid.new(MAP)
	var lane := grid.lane
	check(lane[0] in grid.spawn_tiles, "starts in the portal")
	check(lane[lane.size() - 1] in grid.goal_tiles, "ends in the gate")
	for i in range(1, lane.size()):
		var step := lane[i] - lane[i - 1]
		check_eq(absi(step.x) + absi(step.y), 1, "%s to %s is one step" % [lane[i - 1], lane[i]])
	var seen := {}
	for t in lane:
		check(Grid.in_bounds(t), "%s on the board" % t)
		check(not seen.has(t), "%s walked once" % t)
		seen[t] = true
	var f := FlowField.new()
	f.compute(grid)
	check_eq(_route_tiles(f), lane, "creeps walk the whole lane, in order, no shortcut")


## The layout the map promises: a road of 220-300 m, long straights, spots
## that reach two stretches of it, and stretches that cross the flyers' line.
func test_lane_has_the_promised_shape() -> void:
	var grid := Grid.new(MAP)
	var f := FlowField.new()
	f.compute(grid)
	var metres := f.route_length()
	check(metres >= 220.0 and metres <= 300.0, "road length %.0f m" % metres)
	var corners: Array = MapDefs.MAPS[MAP].lane
	var straights := 0
	var crossings := 0
	var flight := Grid.tile_at(grid.spawn_point).x
	for i in range(1, corners.size()):
		var a: Vector2i = corners[i - 1]
		var b: Vector2i = corners[i]
		if absi(b.x - a.x) + absi(b.y - a.y) >= 8:
			straights += 1
		if a.y == b.y and mini(a.x, b.x) < flight and maxi(a.x, b.x) >= flight:
			crossings += 1
	check(straights >= 4, "%d long straights" % straights)
	check(crossings >= 2, "the road crosses the flyers' line %d times" % crossings)
	var at := {}
	for i in grid.lane.size():
		at[grid.lane[i]] = i
	var two_pass := 0
	for i in Grid.COLS * Grid.ROWS:
		var t := Grid.tile_of(i)
		if not grid.is_ground(t):
			continue
		var seen: Array[int] = []
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if at.has(t + Vector2i(dx, dy)):
					seen.append(at[t + Vector2i(dx, dy)])
		seen.sort()
		for k in range(1, seen.size()):
			if seen[k] - seen[k - 1] > 2:
				two_pass += 1
				break
	check(two_pass >= 6, "%d tiles reach two stretches" % two_pass)


func test_lane_tiles_refuse_builds() -> void:
	var sim := _eletd_sim()
	sim.gold = 1_000_000
	for t in sim.grid.lane:
		if sim.grid.near_portal(t) and not t in sim.grid.spawn_tiles:
			check_eq(sim.check_build(t, &"archer"), R.NEAR_PORTAL, "by the portal %s" % t)
		elif sim.grid.is_reserved(t):
			check_eq(sim.check_build(t, &"archer"), R.RESERVED, "portal or gate %s" % t)
		else:
			check_eq(sim.check_build(t, &"archer"), R.LANE, "lane %s" % t)
	check_eq(Placement.describe(R.LANE), "Keep the road clear", "message")
	check_eq(Placement.describe(R.NEAR_PORTAL), "Too close to the portal", "ring message")
	var road := sim.grid.lane.filter(func(t: Vector2i) -> bool: return not sim.grid.is_reserved(t))
	check_eq(sim.build(road[0], &"archer"), R.LANE, "build refused")
	check(sim.towers.is_empty(), "nothing built")


## Every tile off the lane takes a tower, and none of them, built or sold,
## moves the route or lets creeps step off the lane.
func test_off_lane_towers_never_change_the_route() -> void:
	var sim := _eletd_sim()
	sim.gold = 1_000_000
	var lane := sim.grid.lane
	for i in Grid.COLS * Grid.ROWS:
		var t := Grid.tile_of(i)
		if t in lane or sim.grid.is_reserved(t):
			continue
		check(not sim.grid.is_walkable(t), "%s is not walkable" % t)
		check_eq(sim.build(t, &"archer"), R.OK, "build on %s" % t)
	check_eq(_route_tiles(sim.field), lane, "the route with every tile built")
	for t: Vector2i in sim.towers.keys().slice(0, 40):
		sim.sell(t)
		check(not sim.grid.is_walkable(t), "%s stays off-limits once sold" % t)
	check_eq(_route_tiles(sim.field), lane, "the route after selling")


func test_no_creep_steps_off_the_lane() -> void:
	var sim := _eletd_sim()
	sim.start_next_wave()
	# A Dreadlord on a bend: its summons land beside it, on the grass.
	var bend := sim.grid.lane[sim.grid.lane.find(Vector2i(16, 5))]
	var lord := sim.spawn_creep(&"dreadlord", &"dark", 40, Grid.center(bend))
	lord.ability_timer = 0.5
	var leaked := 0
	var summoned := 0
	for _frame in int(60.0 / GameSim.DT):
		sim.step()
		for e in sim.drain_events():
			leaked += 1 if e.type == &"leaked" else 0
			summoned += 1 if e.type == &"summoned" else 0
		for c in sim.creeps:
			var t := Grid.tile_at(c.pos)
			if not c.flying and Grid.in_bounds(t) and not sim.grid.is_lane(t):
				failures.append("%s %d off the lane on %s" % [c.type, c.id, t])
				return
	check(leaked > 0, "an unguarded wave walks the lane to the gate")
	check(summoned > 0, "the Dreadlord summoned")


func test_bots_build_beside_the_lane() -> void:
	for strategy in [&"archers", &"no_air", &"novice"]:
		var sim := _eletd_sim()
		var bot := Bot.new(sim, strategy)
		check(bot.plan.size() > 100, "%s: plan of %d tiles" % [strategy, bot.plan.size()])
		check_eq(bot.plan, Bot.lane_plan(sim.grid), "%s plans along the lane" % strategy)
		sim.gold = 1_000_000
		for t in bot.plan:
			check_eq(sim.build(t, &"archer"), R.OK, "%s: bot tile %s" % [strategy, t])
	var grid := Grid.new(MAP)
	var plan := Bot.lane_plan(grid)
	var first := []
	for t in plan:
		var near := -1
		for i in grid.lane.size():
			var d := (grid.lane[i] - t).abs()
			if maxi(d.x, d.y) <= 1:
				near = i
				break
		check(near >= 0, "%s borders the lane" % t)
		first.append(near)
	var sorted := first.duplicate()
	sorted.sort()
	check_eq(first, sorted, "planned in the order creeps pass")


func test_smart_bot_weighs_tiles_in_reach_of_lane_or_flight_line() -> void:
	var sim := _eletd_sim()
	var bot := Bot.new(sim, &"smart")
	var a := sim.grid.spawn_point
	var b := sim.grid.gate_point
	for t in bot.plan:
		check(sim.grid.is_ground(t) and not sim.grid.is_reserved(t), "%s is build ground" % t)
		var near_lane := false
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				near_lane = near_lane or sim.grid.is_lane(t + Vector2i(dx, dy))
		# Under the flight line: within a tile and a half of it, square reach.
		var c := Grid.center(t)
		var under := absf(c.x - a.lerp(b, (c.y - a.y) / (b.y - a.y)).x) <= Grid.TILE * 1.5
		check(near_lane or under, "%s reaches the lane or the flyers" % t)
	for t in Bot.lane_plan(sim.grid):
		check(t in bot.plan, "every tile beside the lane is weighed (%s)" % t)
	check(bot.plan.size() > Bot.lane_plan(sim.grid).size(), "flight-line tiles added")


func test_offered_under_element_td_only() -> void:
	check(MapDefs.offered(MAP, &"eletd"), "Element TD")
	check(not MapDefs.offered(MAP, &"classic"), "not classic")
	for id in [&"citadel", &"rampart"]:
		for rules in GameSim.RULES:
			check(MapDefs.offered(id, rules), "%s under %s" % [id, rules])
	Game._carry = {"rules": &"classic", "map": MAP}
	var classic := Game.new()
	check_eq(classic.sim.grid.map, MapDefs.DEFAULT, "classic falls back to the default map")
	check(not classic.change_map(MAP), "and refuses a switch to it")
	check_eq(classic.sim.grid.map, MapDefs.DEFAULT, "the map stays")
	Game._carry = {"rules": &"eletd", "map": MAP}
	var eletd := Game.new()
	check_eq(eletd.sim.grid.map, MAP, "played under Element TD")
	Game._carry = eletd._carry_with({"rules": &"classic"})
	var switched := Game.new()
	check_eq(switched.sim.rules, &"classic", "switched to classic")
	check_eq(switched.sim.grid.map, MapDefs.DEFAULT, "onto the default map")
	for g in [classic, eletd, switched]:
		g.free()


## The map's own HP multiplier applies to every creep it sends, on top of the
## rules' curve and the difficulty, and to no other map.
func test_creeps_get_the_map_hp_multiplier() -> void:
	var k := MapDefs.hp_mult(MAP, 10)
	check_eq(MapDefs.hp_mult(&"citadel", 10), 1.0, "mazing maps keep the rules' HP")
	for level: StringName in [&"normal", &"very_hard"]:
		var lane := _eletd_sim()
		var open := GameSim.new()
		open.rules = &"eletd"
		lane.difficulty = level
		open.difficulty = level
		for type: StringName in [&"grunt", &"footman", &"ogre"]:
			var a := lane.spawn_creep(type, &"dark", 10, lane.grid.spawn_point)
			var b := open.spawn_creep(type, &"dark", 10, open.grid.spawn_point)
			check_near(a.max_hp, b.max_hp * k, 0.01, "%s %s" % [level, type])


func test_records_get_their_own_key() -> void:
	var sim := _eletd_sim()
	check_eq(Save.sim_key(sim), "causeway_normal_eletd", "map and rules")
	sim.difficulty = &"very_hard"
	sim.infinite = true
	check_eq(Save.sim_key(sim), "causeway_very_hard_infinite_eletd", "with mode")
