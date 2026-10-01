class_name Units
extends Node3D
## Draws what the sim holds: creeps (interpolated between sim steps), towers,
## projectiles and ground zones (GDD §7, §8). Skeleton version: primitive
## shapes coloured by type; models and animation come later.

const FAMILY_COLORS := {
	&"alliance": Color(0.25, 0.5, 1.0),
	&"horde": Color(0.9, 0.25, 0.12),
	&"elven": Color(0.35, 0.9, 0.7),
	&"forsaken": Color(0.55, 0.25, 0.75),
	&"support": Color(0.95, 0.8, 0.3),
}
const CREEP_COLORS := {
	&"grunt": Color(0.35, 0.6, 0.2),
	&"wolf_rider": Color(0.5, 0.45, 0.4),
	&"footman": Color(0.65, 0.65, 0.75),
	&"priestess": Color(0.95, 0.9, 0.6),
	&"harpy": Color(0.7, 0.4, 0.6),
	&"ghoul": Color(0.55, 0.6, 0.5),
	&"steam_tank": Color(0.45, 0.4, 0.35),
	&"ogre": Color(0.6, 0.45, 0.3),
	&"dreadlord": Color(0.4, 0.15, 0.4),
	&"felhound": Color(0.3, 0.7, 0.2),
}

var _game: Game
var _creeps := {}
var _towers := {}
var _projectiles := {}
var _zones := {}
var _creep_mesh := CapsuleMesh.new()
var _shot_mesh := SphereMesh.new()


func setup(game: Game) -> void:
	_game = game
	_creep_mesh.radius = 0.4
	_creep_mesh.height = 1.4
	_shot_mesh.radius = 0.15
	_shot_mesh.height = 0.3
	game.sim_event.connect(_on_sim_event)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	return m


func _on_sim_event(e: Dictionary) -> void:
	match e.type:
		&"built", &"upgraded", &"fused":
			_place_tower(e.tile)
			if e.type == &"fused":
				_remove_tower(e.freed)
		&"sold":
			_remove_tower(e.tile)


func _place_tower(tile: Vector2i) -> void:
	_remove_tower(tile)
	var t := _game.sim.tower_at(tile)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.85
	cyl.height = 2.0 + t.level * 0.6 + (1.0 if t.is_epic() else 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = _mat(FAMILY_COLORS.get(t.family(), Color.WHITE))
	mi.position = Coords.tile_to_world(tile, Coords.PLATEAU_TOP + cyl.height / 2)
	add_child(mi)
	_towers[tile] = mi


func _remove_tower(tile: Vector2i) -> void:
	if _towers.has(tile):
		_towers[tile].queue_free()
		_towers.erase(tile)


## Called every frame with the interpolation factor between sim steps.
func sync(alpha: float) -> void:
	var seen := {}
	for c in _game.sim.creeps:
		seen[c.id] = true
		var node: MeshInstance3D = _creeps.get(c.id)
		if node == null:
			node = MeshInstance3D.new()
			node.mesh = _creep_mesh
			node.material_override = _mat(CREEP_COLORS.get(c.type, Color.WHITE))
			node.scale = Vector3.ONE * (2.0 if c.boss else 1.0)
			add_child(node)
			_creeps[c.id] = node
		var height := 4.0 if c.flying else 0.7 * node.scale.y
		node.position = Coords.to_world(c.prev_pos.lerp(c.pos, alpha), Coords.PLATEAU_TOP + height)
		node.visible = c.revive_time <= 0.0
	for id in _creeps.keys():
		if not seen.has(id):
			_creeps[id].queue_free()
			_creeps.erase(id)
	_sync_projectiles()


func _sync_projectiles() -> void:
	var seen := {}
	for p in _game.sim.projectiles:
		seen[p] = true
		var node: MeshInstance3D = _projectiles.get(p)
		if node == null:
			node = MeshInstance3D.new()
			node.mesh = _shot_mesh
			node.material_override = _mat(FAMILY_COLORS.get(p.tower.family(), Color.WHITE))
			add_child(node)
			_projectiles[p] = node
		var y := Coords.PLATEAU_TOP + 3.0
		if p.kind == &"shell":
			var k := 1.0 - p.time_left / maxf(p.flight_time, 0.001)
			y += sin(k * PI) * 6.0 - k * 2.5
		node.position = Coords.to_world(p.pos, y)
	for p in _projectiles.keys():
		if not seen.has(p):
			_projectiles[p].queue_free()
			_projectiles.erase(p)
