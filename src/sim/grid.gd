class_name Grid
extends RefCounted
## The buildable plateau as a tile grid (GDD §1). Row 0 is the portal (north)
## edge and row ROWS - 1 the gate (south) edge. Sim space is metres on the XZ
## plane with the plateau's north-west corner at the origin. The map
## (MapDefs) decides where the portal and gate open and which tiles its ruins
## block from the start.

const COLS := 20
const ROWS := 28
const TILE := 2.0
const WIDTH := COLS * TILE
const DEPTH := ROWS * TILE

var map: StringName
var spawn_tiles: Array[Vector2i] = []
var goal_tiles: Array[Vector2i] = []
## Where creeps appear (inside the portal) and where they count as leaked.
var spawn_point: Vector2
var gate_point: Vector2
## Ruin tiles → kind. Blocked from the start; nothing can be built there.
var obstacles := {}

var _blocked := PackedByteArray()


func _init(p_map := MapDefs.DEFAULT) -> void:
	map = p_map
	_blocked.resize(COLS * ROWS)
	spawn_tiles = MapDefs.spawn_tiles(map)
	goal_tiles = MapDefs.goal_tiles(map)
	spawn_point = Vector2(MapDefs.portal_x(map), -1.5)
	gate_point = Vector2(MapDefs.gate_x(map), DEPTH + 1.5)
	obstacles = MapDefs.obstacles(map)
	for t: Vector2i in obstacles:
		set_blocked(t, true)


static func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < COLS and t.y < ROWS


static func index(t: Vector2i) -> int:
	return t.y * COLS + t.x


static func tile_of(i: int) -> Vector2i:
	return Vector2i(i % COLS, i / COLS)


static func center(t: Vector2i) -> Vector2:
	return Vector2((t.x + 0.5) * TILE, (t.y + 0.5) * TILE)


static func tile_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func is_reserved(t: Vector2i) -> bool:
	return t in spawn_tiles or t in goal_tiles


func is_obstacle(t: Vector2i) -> bool:
	return obstacles.has(t)


func is_blocked(t: Vector2i) -> bool:
	return in_bounds(t) and _blocked[index(t)] == 1


func is_walkable(t: Vector2i) -> bool:
	return in_bounds(t) and _blocked[index(t)] == 0


func set_blocked(t: Vector2i, blocked: bool) -> void:
	_blocked[index(t)] = 1 if blocked else 0


## 1 for each blocked tile, by index(). Read only.
func blocked_cells() -> PackedByteArray:
	return _blocked


func blocked_count() -> int:
	return _blocked.count(1)
