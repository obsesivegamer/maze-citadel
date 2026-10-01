extends "res://tests/test_case.gd"

const R := Placement.Result


func _field(grid: Grid) -> FlowField:
	var f := FlowField.new()
	f.compute(grid)
	return f


## Blocks a full row except the given gap columns.
func _wall(grid: Grid, row: int, gaps: Array) -> void:
	for col in Grid.COLS:
		if not col in gaps:
			grid.set_blocked(Vector2i(col, row), true)


func test_open_board_route_is_straight() -> void:
	var f := _field(Grid.new())
	check_eq(f.distance(Vector2i(9, 0)), float(Grid.ROWS - 1), "spawn distance")
	# The portal sits between the two middle columns, so the walk in and out
	# adds a small sideways step to the straight line.
	var straight := Grid.GATE_POINT.y - Grid.SPAWN_POINT.y
	check_near(f.route_length(), straight, 0.5, "route length")


func test_zigzag_maze_lengthens_route() -> void:
	var grid := Grid.new()
	for i in 4:
		_wall(grid, 5 + i * 5, [Grid.COLS - 1] if i % 2 == 0 else [0])
	var f := _field(grid)
	check(f.reachable(Vector2i(9, 0)), "still reachable")
	check(f.route_length() > 3.0 * (Grid.DEPTH + 3.0), "zig-zag ≥ 3× straight")


func test_no_squeezing_between_diagonal_towers() -> void:
	var grid := Grid.new()
	# Staircase wall: each row's towers touch the next only at a corner.
	for col in Grid.COLS:
		grid.set_blocked(Vector2i(col, 10 + (col % 2)), true)
	check(not _field(grid).reachable(Vector2i(9, 0)), "corner gaps must not leak")


func test_route_never_enters_blocked_tiles() -> void:
	var grid := Grid.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for _i in 120:
		var t := Vector2i(rng.randi_range(0, Grid.COLS - 1), rng.randi_range(1, Grid.ROWS - 2))
		if Placement.check(grid, t, []) == R.OK:
			grid.set_blocked(t, true)
	var f := _field(grid)
	var route := f.route()
	for i in range(1, route.size() - 1):
		check(not grid.is_blocked(Grid.tile_at(route[i])), "route tile %s open" % route[i])


func test_placement_refuses_reserved_and_occupied() -> void:
	var grid := Grid.new()
	check_eq(Placement.check(grid, Grid.SPAWN_TILES[0], []), R.RESERVED, "portal")
	check_eq(Placement.check(grid, Grid.GOAL_TILES[1], []), R.RESERVED, "gate")
	check_eq(Placement.check(grid, Vector2i(-1, 3), []), R.OUT_OF_BOUNDS, "outside")
	grid.set_blocked(Vector2i(3, 3), true)
	check_eq(Placement.check(grid, Vector2i(3, 3), []), R.OCCUPIED, "occupied")
	check_eq(Placement.check(grid, Vector2i(4, 4), [Vector2i(4, 4)]), R.CREEP_ON_TILE, "creep")


func test_placement_refuses_closing_the_last_gap() -> void:
	var grid := Grid.new()
	_wall(grid, 12, [7])
	check_eq(Placement.check(grid, Vector2i(6, 13), []), R.OK, "beside the gap is fine")
	check_eq(Placement.check(grid, Vector2i(7, 12), []), R.BLOCKS_PATH, "closing the gap")
	check(grid.is_walkable(Vector2i(7, 12)), "check leaves the grid unchanged")


func test_placement_refuses_trapping_a_creep() -> void:
	var grid := Grid.new()
	# Pocket on the west edge, open only at (1, 15).
	for t in [Vector2i(0, 14), Vector2i(1, 14), Vector2i(2, 15), Vector2i(0, 16), Vector2i(1, 16)]:
		grid.set_blocked(t, true)
	var creep: Array[Vector2i] = [Vector2i(0, 15)]
	check_eq(Placement.check(grid, Vector2i(1, 15), creep), R.TRAPS_CREEP, "sealing the pocket")
	check_eq(Placement.check(grid, Vector2i(1, 15), []), R.OK, "fine when empty")


func test_fuzz_never_disconnects_portal() -> void:
	var grid := Grid.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var accepted := 0
	var refused := 0
	for _i in 1000:
		var t := Vector2i(rng.randi_range(0, Grid.COLS - 1), rng.randi_range(0, Grid.ROWS - 1))
		var r := Placement.check(grid, t, [])
		if r == R.OK:
			grid.set_blocked(t, true)
			accepted += 1
			check(Grid.SPAWN_TILES.any(_field(grid).reachable), "connected after %s" % t)
		elif r == R.BLOCKS_PATH:
			refused += 1
			grid.set_blocked(t, true)
			check(not Grid.SPAWN_TILES.any(_field(grid).reachable), "refusal %s was real" % t)
			grid.set_blocked(t, false)
	check(accepted > 150 and refused > 20, "fuzz exercised both (%d/%d)" % [accepted, refused])
