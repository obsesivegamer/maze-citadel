class_name Placement
extends RefCounted
## Anti-block validation (GDD §2). A tower may go on a tile only if, with it
## in place, the portal still reaches the gate and no ground creep is cut off.

enum Result {
	OK,
	OUT_OF_BOUNDS,
	RESERVED,
	OCCUPIED,
	CREEP_ON_TILE,
	BLOCKS_PATH,
	TRAPS_CREEP,
	NO_GOLD,
}


static func check(grid: Grid, tile: Vector2i, creep_tiles: Array[Vector2i]) -> Result:
	if not Grid.in_bounds(tile):
		return Result.OUT_OF_BOUNDS
	if Grid.is_reserved(tile):
		return Result.RESERVED
	if grid.is_blocked(tile):
		return Result.OCCUPIED
	if tile in creep_tiles:
		return Result.CREEP_ON_TILE
	grid.set_blocked(tile, true)
	var field := FlowField.new()
	field.compute(grid)
	grid.set_blocked(tile, false)
	if not Grid.SPAWN_TILES.any(field.reachable):
		return Result.BLOCKS_PATH
	for c in creep_tiles:
		if Grid.in_bounds(c) and not field.reachable(c):
			return Result.TRAPS_CREEP
	return Result.OK


static func describe(result: Result) -> String:
	match result:
		Result.OK:
			return ""
		Result.OUT_OF_BOUNDS:
			return "Outside the build area"
		Result.RESERVED:
			return "Keep the portal and gate clear"
		Result.OCCUPIED:
			return "Already built here"
		Result.CREEP_ON_TILE:
			return "A creep is in the way"
		Result.BLOCKS_PATH:
			return "That would block the path"
		Result.TRAPS_CREEP:
			return "That would trap a creep"
		Result.NO_GOLD:
			return "Not enough gold"
	return "Can't build here"
