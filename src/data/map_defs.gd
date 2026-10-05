class_name MapDefs
extends RefCounted
## Map table (docs/maps.md). Every map is the same 20 × 28 plateau in the same
## valley; maps differ in where the 2-tile portal and gate open on the north
## and south edges, in ruins that block tiles from the start, and in whether
## the player builds the maze or the creeps keep to a fixed lane. Tiles are
## (column, row) with row 0 on the portal edge.

const DEFAULT := &"citadel"
const ORDER: Array[StringName] = [&"citadel", &"rampart", &"causeway"]
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
	&"causeway":
	{
		"name": "Winding Causeway",
		"short": "Causeway",
		"blurb":
		(
			"A cobbled road winds from portal to gate and creeps never leave it. Build on"
			+ " the grass beside it, best where it doubles back."
		),
		"portal_col": 9,
		"gate_col": 9,
		## Under classic ranges a tower reaches several stretches of the road from
		## almost anywhere, so there would be no spots to choose between.
		"rules": [&"eletd"],
		## Creep HP multiplier on wave 1 and wave 40 (MapDefs.hp_mult). The road
		## is 240 m long from wave 1, while a maze reaches its length late, so
		## the map is easiest early and hardest late. At a flat 1.4 the wave-10
		## Ogre never got through and the Dreadlord always did, and Hard lost
		## every game on waves 38 to 40 (docs/balance.md).
		"hp": 1.8,
		"hp_40": 1.15,
		## The lane's corners, portal to gate, each pair joined along a row or a
		## column, one tile wide. Two tiles of grass lie between most stretches;
		## the hairpin on rows 5 and 7 leaves one, every tile of which reaches both.
		"lane":
		[
			Vector2i(9, 0),
			Vector2i(9, 2),
			Vector2i(3, 2),
			Vector2i(3, 5),
			Vector2i(16, 5),
			Vector2i(16, 7),
			Vector2i(6, 7),
			Vector2i(6, 10),
			Vector2i(16, 10),
			Vector2i(16, 13),
			Vector2i(2, 13),
			Vector2i(2, 24),
			Vector2i(7, 24),
			Vector2i(7, 16),
			Vector2i(12, 16),
			Vector2i(12, 21),
			Vector2i(17, 21),
			Vector2i(17, 25),
			Vector2i(10, 25),
			Vector2i(10, 27),
		],
	},
}


static func has(id: StringName) -> bool:
	return MAPS.has(id)


static func display_name(id: StringName) -> String:
	return MAPS[id].name


## Creep HP on map `id` on wave `w` under the Element TD rules, as a multiple
## of what the rules give (1 on the mazing maps); Guardians included. It runs
## in a straight line from "hp" on wave 1 to "hp_40" on wave 40.
static func hp_mult(id: StringName, w: int) -> float:
	var from: float = MAPS[id].get("hp", 1.0)
	var f := clampf((w - 1) / float(WaveDefs.count() - 1), 0.0, 1.0)
	return lerpf(from, MAPS[id].get("hp_40", from), f)


## Whether map `id` is played under rule set `rules` (GameSim.RULES).
static func offered(id: StringName, rules: StringName) -> bool:
	return not MAPS[id].has("rules") or rules in MAPS[id].rules


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


## Every tile of the map's fixed lane in walking order, portal to gate; empty
## on the maps where the player builds the maze.
static func lane(id: StringName) -> Array[Vector2i]:
	var corners: Array = MAPS[id].get("lane", [])
	var out: Array[Vector2i] = []
	if corners.is_empty():
		return out
	out.append(corners[0])
	for i in range(1, corners.size()):
		var t: Vector2i = corners[i - 1]
		var step: Vector2i = (corners[i] - t).sign()
		while t != corners[i]:
			t += step
			out.append(t)
	return out
