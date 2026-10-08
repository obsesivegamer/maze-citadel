class_name Grid
extends RefCounted
## The buildable plateau as a tile grid (GDD §1). Row 0 is the portal (north)
## edge and row ROWS - 1 the gate (south) edge. Sim space is metres on the XZ
## plane with the plateau's north-west corner at the origin. The map
## (MapDefs) decides where the portal and gate open, which tiles its ruins
## block from the start, and on a fixed-lane map which tiles are the lane.

const COLS := 20
const ROWS := 28
const TILE := 2.0
const WIDTH := COLS * TILE
const DEPTH := ROWS * TILE
## A tile's kind in blocked_cells(); creeps walk only OPEN tiles. A tower or a
## ruin makes a tile BLOCKED. On a fixed-lane map every tile off the lane is
## GROUND: towers may take it, creeps never enter it, so no build can block
## or bend the lane.
const OPEN := 0
const BLOCKED := 1
const GROUND := 2

var map: StringName
var spawn_tiles: Array[Vector2i] = []
var goal_tiles: Array[Vector2i] = []
## Where creeps appear (inside the portal) and where they count as leaked.
var spawn_point: Vector2
var gate_point: Vector2
## Ruin tiles → kind. Blocked from the start; nothing can be built there.
var obstacles := {}
## The fixed lane in walking order (MapDefs.lane); empty where the player
## builds the maze.
var lane: Array[Vector2i] = []
## Whether the tiles touching the portal are kept clear (EletdRules.portal_ring,
## set by GameSim.rules); false leaves the board open.
var portal_ring := false:
	set(value):
		portal_ring = value
		_ring.clear()
		if not value:
			return
		for s in spawn_tiles:
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					var t := s + Vector2i(dx, dy)
					if in_bounds(t) and not t in spawn_tiles:
						_ring[t] = true

var _blocked := PackedByteArray()
## The portal ring's tiles (near_portal), as a set.
var _ring := {}
## Each tile's kind with nothing built on it: OPEN, or GROUND beside a lane.
var _floor := PackedByteArray()


func _init(p_map := MapDefs.DEFAULT) -> void:
	map = p_map
	_blocked.resize(COLS * ROWS)
	_floor.resize(COLS * ROWS)
	spawn_tiles = MapDefs.spawn_tiles(map)
	goal_tiles = MapDefs.goal_tiles(map)
	spawn_point = Vector2(MapDefs.portal_x(map), -1.5)
	gate_point = Vector2(MapDefs.gate_x(map), DEPTH + 1.5)
	obstacles = MapDefs.obstacles(map)
	lane = MapDefs.lane(map)
	if not lane.is_empty():
		_floor.fill(GROUND)
		for t in lane:
			_floor[index(t)] = OPEN
		_blocked = _floor.duplicate()
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


## The portal, the gate or a tile of the ring round the portal: nothing is built here.
func is_reserved(t: Vector2i) -> bool:
	return near_portal(t) or t in spawn_tiles or t in goal_tiles


## A tile of the portal ring: one touching a portal tile, side or corner, that
## is not a portal tile itself.
func near_portal(t: Vector2i) -> bool:
	return _ring.has(t)


## The portal ring's tiles, in no set order.
func portal_ring_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(_ring.keys())
	return out


func is_obstacle(t: Vector2i) -> bool:
	return obstacles.has(t)


## A tile of a fixed lane: creeps walk it, nothing is built on it.
func is_lane(t: Vector2i) -> bool:
	return not lane.is_empty() and in_bounds(t) and _floor[index(t)] == OPEN


## Build ground beside a fixed lane, built on or not.
func is_ground(t: Vector2i) -> bool:
	return in_bounds(t) and _floor[index(t)] == GROUND


func is_blocked(t: Vector2i) -> bool:
	return in_bounds(t) and _blocked[index(t)] == BLOCKED


func is_walkable(t: Vector2i) -> bool:
	return in_bounds(t) and _blocked[index(t)] == OPEN


## Selling or freeing a tile returns it to its kind: open, or lane-side ground.
func set_blocked(t: Vector2i, blocked: bool) -> void:
	_blocked[index(t)] = BLOCKED if blocked else _floor[index(t)]


## `p`, or `fallback` where `p` is on the ground beside a fixed lane: a creep
## put down off the lane (a Dreadlord's summons) starts on it instead.
func on_lane(p: Vector2, fallback: Vector2) -> Vector2:
	return fallback if is_ground(tile_at(p)) else p


## Each tile's kind (OPEN, BLOCKED or GROUND), by index(). Read only.
func blocked_cells() -> PackedByteArray:
	return _blocked


## Tiles blocked by a tower or a ruin.
func blocked_count() -> int:
	return _blocked.count(BLOCKED)
