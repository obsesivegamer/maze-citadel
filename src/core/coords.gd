class_name Coords
extends RefCounted
## Sim space (metres on the plateau, origin at its north-west corner) ↔ world
## space (origin at the plateau's centre, Y up, north = -Z).

const PLATEAU_TOP := 1.6

## The map being drawn (Game sets it before the world is built). Only the
## portal and gate move between maps; the plateau is the same everywhere.
static var map := MapDefs.DEFAULT


static func to_world(p: Vector2, y := PLATEAU_TOP) -> Vector3:
	return Vector3(p.x - Grid.WIDTH / 2.0, y, p.y - Grid.DEPTH / 2.0)


static func tile_to_world(t: Vector2i, y := PLATEAU_TOP) -> Vector3:
	return to_world(Grid.center(t), y)


static func to_sim(w: Vector3) -> Vector2:
	return Vector2(w.x + Grid.WIDTH / 2.0, w.z + Grid.DEPTH / 2.0)


static func world_to_tile(w: Vector3) -> Vector2i:
	return Grid.tile_at(to_sim(w))


## Portal and gate centres in world space.
static func portal() -> Vector3:
	return to_world(Vector2(MapDefs.portal_x(map), -3.0))


static func gate() -> Vector3:
	return to_world(Vector2(MapDefs.gate_x(map), Grid.DEPTH + 3.0))
