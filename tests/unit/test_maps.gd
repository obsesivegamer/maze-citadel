extends "res://tests/test_case.gd"

const R := Placement.Result
const Bot := preload("res://src/bots/autoplay_bot.gd")


func _field(grid: Grid) -> FlowField:
	var f := FlowField.new()
	f.compute(grid)
	return f


func test_every_map_opens_with_a_route() -> void:
	for id in MapDefs.ORDER:
		var grid := Grid.new(id)
		var f := _field(grid)
		check(grid.spawn_tiles.any(f.reachable), "%s: portal reaches gate" % id)
		for t: Vector2i in grid.obstacles:
			check(Grid.in_bounds(t), "%s: ruin %s on the board" % [id, t])
			check(not grid.is_reserved(t), "%s: ruin %s off the portal and gate" % [id, t])
			check(grid.is_blocked(t), "%s: ruin %s starts blocked" % [id, t])
		check_eq(MapDefs.ORDER.size(), MapDefs.MAPS.size(), "every map is pickable")


func test_citadel_keeps_the_original_board() -> void:
	var grid := Grid.new()
	check_eq(grid.map, MapDefs.DEFAULT, "default map")
	check_eq(grid.spawn_tiles, [Vector2i(9, 0), Vector2i(10, 0)] as Array[Vector2i], "portal")
	check_eq(grid.goal_tiles, [Vector2i(9, 27), Vector2i(10, 27)] as Array[Vector2i], "gate")
	check_eq(grid.spawn_point, Vector2(Grid.WIDTH / 2.0, -1.5), "spawn point")
	check_eq(grid.gate_point, Vector2(Grid.WIDTH / 2.0, Grid.DEPTH + 1.5), "gate point")
	check_eq(grid.blocked_count(), 0, "no ruins")


func test_rampart_layout() -> void:
	var grid := Grid.new(&"rampart")
	check_eq(grid.spawn_tiles[0], Vector2i(5, 0), "portal north-west")
	check_eq(grid.goal_tiles[0], Vector2i(13, 27), "gate south-east")
	check(grid.gate_point.x > grid.spawn_point.x + 10.0, "flyers cross diagonally")
	check_eq(grid.obstacles.size(), 14 + 8, "wall plus two boulder heaps")
	for col in Grid.COLS:
		var open := col in [1, 2, 9, 10, 17, 18]
		check_eq(grid.is_walkable(Vector2i(col, 13)), open, "wall column %d" % col)


func test_ruins_refuse_building() -> void:
	var grid := Grid.new(&"rampart")
	check_eq(Placement.check(grid, Vector2i(0, 13), []), R.OBSTACLE, "wall")
	check_eq(Placement.check(grid, Vector2i(13, 6), []), R.OBSTACLE, "boulder")
	check_eq(Placement.describe(R.OBSTACLE), "Ruins block this tile", "message")
	check_eq(Placement.check(grid, Vector2i(9, 13), []), R.OK, "a breach can be plugged")


func test_rampart_always_keeps_one_breach_open() -> void:
	var grid := Grid.new(&"rampart")
	for t in [Vector2i(9, 13), Vector2i(10, 13), Vector2i(17, 13), Vector2i(18, 13)]:
		check_eq(Placement.check(grid, t, []), R.OK, "plug %s" % t)
		grid.set_blocked(t, true)
	check_eq(Placement.check(grid, Vector2i(1, 13), []), R.OK, "half the last breach")
	grid.set_blocked(Vector2i(1, 13), true)
	check_eq(Placement.check(grid, Vector2i(2, 13), []), R.BLOCKS_PATH, "last breach tile")
	var crossing := false
	for p in _field(grid).route():
		crossing = crossing or Grid.tile_at(p) == Vector2i(2, 13)
	check(crossing, "the route runs through the open breach")


func test_rampart_wave_walks_from_portal_to_gate() -> void:
	var sim := GameSim.new(&"rampart")
	sim.start_next_wave()
	var leaked := 0
	for _frame in int(60.0 / GameSim.DT):
		sim.step()
		for e in sim.drain_events():
			if e.type == &"spawned":
				# Spawned this step, then took its first step out of the portal.
				var c := sim.creep(e.id)
				check(c.prev_pos.is_equal_approx(sim.grid.spawn_point), "spawns in the portal")
			elif e.type == &"leaked":
				leaked += 1
		for c in sim.creeps:
			var t := Grid.tile_at(c.pos)
			if Grid.in_bounds(t) and sim.grid.is_blocked(t):
				failures.append("creep %d on ruin tile %s" % [c.id, t])
				return
	check(leaked > 0, "an unguarded wave reaches the gate")


func test_bot_plan_fits_every_map() -> void:
	for id in MapDefs.ORDER:
		var sim := GameSim.new(id)
		var bot := Bot.new(sim, &"archers")
		check(bot.plan.size() > 90, "%s: a full serpentine (%d tiles)" % [id, bot.plan.size()])
		sim.gold = 1_000_000
		for t in bot.plan:
			check_eq(sim.build(t, &"archer"), R.OK, "%s: bot tile %s" % [id, t])
		check(sim.field.route_length() > 4.0 * Grid.DEPTH, "%s: the maze is long" % id)


func test_records_are_kept_per_map() -> void:
	check_eq(Save.mode_key(false, false), "normal", "default map keeps its keys")
	check_eq(Save.mode_key(true, true, false, MapDefs.DEFAULT), "hard_infinite", "default map")
	check_eq(Save.mode_key(true, false, false, &"rampart"), "rampart_hard", "other maps prefixed")
	check_eq(Save.mode_key(true, false, true, &"rampart"), "rampart_hard_twists", "map and twists")
	var sim := GameSim.new(&"rampart")
	sim.infinite = true
	check_eq(Save.sim_key(sim), "rampart_normal_infinite", "from a sim")
