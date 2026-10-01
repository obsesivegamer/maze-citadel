class_name Grid
extends RefCounted
## The buildable plateau as a tile grid (GDD §1). Row 0 is the portal (north)
## edge and row ROWS - 1 the gate (south) edge. Sim space is metres on the XZ
## plane with the plateau's north-west corner at the origin.

const COLS := 20
const ROWS := 28
const TILE := 2.0
const WIDTH := COLS * TILE
const DEPTH := ROWS * TILE
const SPAWN_TILES: Array[Vector2i] = [Vector2i(9, 0), Vector2i(10, 0)]
const GOAL_TILES: Array[Vector2i] = [Vector2i(9, ROWS - 1), Vector2i(10, ROWS - 1)]
## Where creeps appear (inside the portal) and where they count as leaked.
const SPAWN_POINT := Vector2(WIDTH / 2.0, -1.5)
const GATE_POINT := Vector2(WIDTH / 2.0, DEPTH + 1.5)

var _blocked := PackedByteArray()


func _init() -> void:
	_blocked.resize(COLS * ROWS)


static func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < COLS and t.y < ROWS


static func index(t: Vector2i) -> int:
	return t.y * COLS + t.x


static func tile_of(i: int) -> Vector2i:
	return Vector2i(i % COLS, i / COLS)


static func is_reserved(t: Vector2i) -> bool:
	return t in SPAWN_TILES or t in GOAL_TILES


static func center(t: Vector2i) -> Vector2:
	return Vector2((t.x + 0.5) * TILE, (t.y + 0.5) * TILE)


static func tile_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func is_blocked(t: Vector2i) -> bool:
	return in_bounds(t) and _blocked[index(t)] == 1


func is_walkable(t: Vector2i) -> bool:
	return in_bounds(t) and _blocked[index(t)] == 0


func set_blocked(t: Vector2i, blocked: bool) -> void:
	_blocked[index(t)] = 1 if blocked else 0


func blocked_count() -> int:
	return _blocked.count(1)
