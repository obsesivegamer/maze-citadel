class_name MapDefs
extends RefCounted
## Map table (docs/maps.md). Every map is the same 20 × 28 plateau in the same
## valley; maps differ in where the 2-tile portal and gate open on the north
## and south edges, and in ruins that block tiles from the start. Tiles are
## (column, row) with row 0 on the portal edge.

const DEFAULT := &"citadel"
const ORDER: Array[StringName] = [&"citadel", &"rampart"]
const MAPS := {
	&"citadel":
	{
		"name": "Citadel Plateau",
		"short": "Citadel",
		"blurb": "The open plateau. Portal and gate face each other across the middle.",
		"portal_col": 9,
		"gate_col": 9,
	},
	&"rampart":
	{
		"name": "Fallen Rampart",
		"short": "Rampart",
		"blurb":
		(
			"A broken wall splits the plateau. Every creep must pass one of its three"
			+ " breaches; portal and gate sit on opposite corners."
		),
		"portal_col": 5,
		"gate_col": 13,
		## The broken wall: every tile of this row except the breach columns.
		"wall_row": 13,
		"breaches": [1, 2, 9, 10, 17, 18],
		## Boulder heaps, 2 × 2 tiles each, by their north-west tile.
		"boulders": [Vector2i(12, 5), Vector2i(6, 19)],
	},
}


static func has(id: StringName) -> bool:
	return MAPS.has(id)


static func display_name(id: StringName) -> String:
	return MAPS[id].name


static func spawn_tiles(id: StringName) -> Array[Vector2i]:
	var c: int = MAPS[id].portal_col
	return [Vector2i(c, 0), Vector2i(c + 1, 0)]


static func goal_tiles(id: StringName) -> Array[Vector2i]:
	var c: int = MAPS[id].gate_col
	return [Vector2i(c, Grid.ROWS - 1), Vector2i(c + 1, Grid.ROWS - 1)]


## Portal and gate centres across the plateau, in sim metres from its west edge.
static func portal_x(id: StringName) -> float:
	return (MAPS[id].portal_col + 1) * Grid.TILE


static func gate_x(id: StringName) -> float:
	return (MAPS[id].gate_col + 1) * Grid.TILE


## Ruin tiles → kind (&"wall" or &"boulder").
static func obstacles(id: StringName) -> Dictionary:
	var m: Dictionary = MAPS[id]
	var out := {}
	if m.has("wall_row"):
		for col in Grid.COLS:
			if not col in m.breaches:
				out[Vector2i(col, m.wall_row)] = &"wall"
	for b: Vector2i in m.get("boulders", []):
		for dy in 2:
			for dx in 2:
				out[b + Vector2i(dx, dy)] = &"boulder"
	return out
