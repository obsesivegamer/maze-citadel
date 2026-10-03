class_name WorldRuins
extends Node3D
## The map's ruins on the plateau (docs/maps.md): a broken stone rampart on
## its wall tiles, with a column and a rubble heap at each end of a run, and
## boulder heaps on its boulder tiles. Built from the grid, so the ruins stand
## exactly on the tiles they block. Everything is baked into one static mesh.

const DG := "res://assets/environment/kaykit_dungeon_remastered/"
const NK := "res://assets/environment/kenney_nature_kit/"
const QN := "res://assets/environment/quaternius_stylized_nature/"
const WALL := DG + "wall_broken.glb"
const COLUMN := DG + "column.glb"
const RUBBLE := DG + "rubble_half.glb"
const BOULDERS: Array[String] = [
	QN + "Rock_Medium_1.glb", QN + "Rock_Medium_2.glb", QN + "Rock_Medium_3.glb"
]
const STONES: Array[String] = [
	NK + "rock_smallA.glb", NK + "rock_smallC.glb", NK + "rock_tallA.glb"
]
## Wall pieces fill a tile's width; their height varies so the top reads as
## crumbled. Height in metres.
const WALL_HEIGHT := Vector2(1.7, 2.9)
const WALL_DEPTH := 1.1
const COLUMN_SCALE := 2.1
const RUBBLE_SCALE := 0.32
const STONE_SCALE := Vector2(1.4, 2.4)
const BOULDER_SCALE := Vector2(1.15, 1.35)

## The board being drawn.
var grid: Grid


func build() -> void:
	if grid == null or grid.obstacles.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var entries := []
	for t: Vector2i in grid.obstacles:
		match grid.obstacles[t]:
			&"wall":
				_wall_tile(t, rng, entries)
			&"boulder":
				if not _is_boulder(t + Vector2i.LEFT) and not _is_boulder(t + Vector2i.UP):
					_boulder_heap(t, rng, entries)
	var mi := MeshInstance3D.new()
	mi.name = "Ruins"
	mi.mesh = WorldKit.bake(entries)
	add_child(mi)


func _is_wall(t: Vector2i) -> bool:
	return grid.obstacles.get(t, &"") == &"wall"


func _is_boulder(t: Vector2i) -> bool:
	return grid.obstacles.get(t, &"") == &"boulder"


## One broken wall piece across the tile; a column and rubble where the run
## ends at a breach, and loose stones at its foot.
func _wall_tile(t: Vector2i, rng: RandomNumberGenerator, entries: Array) -> void:
	var c := Coords.tile_to_world(t)
	var box := WorldKit.bounds(WALL)
	var h := rng.randf_range(WALL_HEIGHT.x, WALL_HEIGHT.y)
	var scale := Vector3(Grid.TILE / box.size.x, h / box.size.y, WALL_DEPTH / box.size.z)
	var yaw := PI if rng.randf() < 0.5 else 0.0
	var b := Basis(Vector3.UP, yaw) * Basis.from_scale(scale)
	entries.append([WALL, Transform3D(b, c)])
	for side in [-1, 1]:
		var n := t + Vector2i(side, 0)
		if _is_wall(n):
			continue
		var edge := c + Vector3(side * Grid.TILE * 0.42, 0, 0)
		entries.append([COLUMN, WorldKit.placed(edge, rng.randf() * TAU, COLUMN_SCALE)])
		if Grid.in_bounds(n):
			# Rubble spills a little way into the breach.
			var spill := edge + Vector3(side * 0.35, 0, rng.randf_range(-0.5, 0.5))
			var yaw_r := rng.randf() * TAU
			entries.append([RUBBLE, WorldKit.placed(spill, yaw_r, RUBBLE_SCALE, 0.08)])
	if rng.randf() < 0.6:
		var foot := (
			c + Vector3(rng.randf_range(-0.7, 0.7), 0, rng.randf_range(0.7, 0.9) * _sign(rng))
		)
		var s := rng.randf_range(STONE_SCALE.x, STONE_SCALE.y)
		var path := STONES[rng.randi() % STONES.size()]
		entries.append([path, WorldKit.placed(foot, rng.randf() * TAU, s, 0.2)])


## A big boulder in the middle of a 2 × 2 heap (`t` is its north-west tile)
## with smaller ones leaning on it.
func _boulder_heap(t: Vector2i, rng: RandomNumberGenerator, entries: Array) -> void:
	var c := Coords.tile_to_world(t) + Vector3(Grid.TILE * 0.5, 0, Grid.TILE * 0.5)
	var big := BOULDERS[rng.randi() % BOULDERS.size()]
	var s := rng.randf_range(BOULDER_SCALE.x, BOULDER_SCALE.y)
	entries.append([big, WorldKit.placed(c - Vector3(0, 0.2, 0), rng.randf() * TAU, s, 0.1)])
	for i in 3:
		var a := TAU * (i + rng.randf_range(0.0, 0.5)) / 3.0
		var p := c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.2, 1.6)
		var path := BOULDERS[(i + 1) % BOULDERS.size()]
		var small := rng.randf_range(0.45, 0.6)
		entries.append(
			[path, WorldKit.placed(p - Vector3(0, 0.1, 0), rng.randf() * TAU, small, 0.2)]
		)


static func _sign(rng: RandomNumberGenerator) -> float:
	return -1.0 if rng.randf() < 0.5 else 1.0
