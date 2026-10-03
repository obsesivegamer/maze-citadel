class_name WorldCitadel
extends Node3D
## Outer walls around the south end of the plateau (GDD §1, §12): KayKit
## blue-roofed towers, wall runs, the gatehouse at Coords.gate() with a
## glowing blue veil, Alliance-blue banners swaying in the wind and torches
## flickering at the gate. flash() lights the gate up when a creep leaks.

const KIT := "res://assets/environment/kaykit_medieval_hexagon/"
const DUNGEON := "res://assets/environment/kaykit_dungeon_remastered/"
const WALL := KIT + "wall_straight.glb"
const GATE := KIT + "wall_straight_gate.glb"
const TOWER := KIT + "building_tower_A_blue.glb"
const GATE_TOWER := KIT + "building_tower_B_blue.glb"
const TORCH := DUNGEON + "torch_mounted.glb"
const BANNERS: Array[String] = [
	DUNGEON + "banner_blue.glb",
	DUNGEON + "banner_patternA_blue.glb",
	DUNGEON + "banner_patternB_blue.glb",
]

const WALL_SCALE := 3.5
const GATE_SCALE := 5.0
const TOWER_SCALE := 4.2
const GATE_TOWER_SCALE := 4.6
const TORCH_SCALE := 2.0
const BANNER_SCALE := 1.25
## Wall line: the south wall runs through the gate (wherever the map puts it,
## Coords.gate()); side walls run north along the rim to SIDE_END_Z.
const WALL_Z := 31.0
const SIDE_X := 22.4
const SIDE_END_Z := 3.0
const GATE_TOWER_X := 6.6
const CORNER := Vector2(21.8, 30.6)
const SIDE_TOWER_Z := 17.0
const DOOR_OPEN_DEG := 105.0
const VEIL_SIZE := Vector2(4.3, 3.9)
const VEIL_COLOR := Color(0.3, 0.6, 1.0)
const GATE_LIGHT_COLOR := Color(0.35, 0.6, 1.0)
const GATE_LIGHT_ENERGY := 2.6
const FLASH_ENERGY := 12.0
const FLASH_TIME := 0.4
const TORCH_LIGHT_COLOR := Color(1.0, 0.62, 0.3)
const TORCH_LIGHT_ENERGY := 1.8
## Banners hang at these fractions of each south wall run, gate end first;
## runs shorter than BANNER_MIN_RUN carry none.
const BANNER_AT: Array[float] = [0.409, 0.75]
const BANNER_MIN_RUN := 8.0

var _top := Coords.PLATEAU_TOP
var _gx := Coords.gate().x
var _veil_mat := ShaderMaterial.new()
var _gate_light := OmniLight3D.new()
var _torch_lights: Array[OmniLight3D] = []
var _flash := 0.0
var _time := 0.0
var _noise := FastNoiseLite.new()
var _banner_xforms := {}
var _banner_count := 0


func build() -> void:
	_noise.frequency = 3.0
	for b in BANNERS:
		_banner_xforms[b] = [] as Array[Transform3D]
	_build_walls()
	_build_towers()
	_build_gate()
	_build_torches()
	for b in BANNERS:
		_add_banners(b, _banner_xforms[b])


func flash() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
	var f := _flash * _flash
	_veil_mat.set_shader_parameter(&"flash", f)
	_gate_light.light_energy = GATE_LIGHT_ENERGY + FLASH_ENERGY * f
	for i in _torch_lights.size():
		var n := _noise.get_noise_1d(_time + i * 17.0)
		_torch_lights[i].light_energy = TORCH_LIGHT_ENERGY * (0.82 + 0.3 * n)


func _wall_run(xforms: Array[Transform3D], from: Vector2, to: Vector2) -> void:
	var piece := WorldKit.bounds(WALL).size.x * WALL_SCALE
	var dir := (to - from).normalized()
	var count := maxi(1, roundi(from.distance_to(to) / piece))
	var step := from.distance_to(to) / count
	var yaw := atan2(-dir.y, dir.x)
	for i in count:
		var p := from + dir * step * (i + 0.5)
		var stretch := Vector3(step / piece, 1.0, 1.0) * WALL_SCALE
		var b := Basis(Vector3.UP, yaw) * Basis.from_scale(stretch)
		xforms.append(Transform3D(b, Vector3(p.x, _top, p.y)))


func _build_walls() -> void:
	var xforms: Array[Transform3D] = []
	var wall_h := WorldKit.bounds(WALL).size.y * WALL_SCALE
	var wall_d := WorldKit.bounds(WALL).size.z * WALL_SCALE * 0.5
	for sx in [-1.0, 1.0]:
		var from: float = _gx + sx * (GATE_TOWER_X + 2.0)
		var to: float = sx * CORNER.x
		if (to - from) * sx > 1.0:
			_wall_run(xforms, Vector2(from, WALL_Z), Vector2(to, WALL_Z))
		if absf(to - from) >= BANNER_MIN_RUN:
			for f in BANNER_AT:
				var x := lerpf(from, to, f)
				_banner_at(Vector3(x, _top + wall_h, WALL_Z + wall_d), 0.0, 0.8)
				_banner_at(Vector3(x, _top + wall_h, WALL_Z - wall_d), PI, 0.8)
		_wall_run(xforms, Vector2(sx * SIDE_X, CORNER.y - 1.5), Vector2(sx * SIDE_X, SIDE_END_Z))
		for z in [10.0, 24.0]:
			_banner_at(Vector3(sx * (SIDE_X + wall_d), _top + wall_h, z), sx * PI / 2, 0.8)
	add_child(WorldKit.multimesh(WorldKit.merged(WALL), xforms))


func _build_towers() -> void:
	var corners: Array[Transform3D] = []
	for sx in [-1.0, 1.0]:
		for p: Vector2 in [
			Vector2(sx * CORNER.x, CORNER.y),
			Vector2(sx * SIDE_X, SIDE_TOWER_Z),
			Vector2(sx * SIDE_X, SIDE_END_Z)
		]:
			corners.append(WorldKit.placed(Vector3(p.x, _top, p.y), 0.0, TOWER_SCALE))
	add_child(WorldKit.multimesh(WorldKit.merged(TOWER), corners))
	var gate_towers: Array[Transform3D] = []
	for sx in [-1.0, 1.0]:
		var c := Vector3(_gx + sx * GATE_TOWER_X, _top, WALL_Z)
		gate_towers.append(WorldKit.placed(c, 0.0, GATE_TOWER_SCALE))
		# Banners on the two hex faces toward the outside and the two inside.
		var apothem := WorldKit.bounds(TOWER).size.x * 0.5 * GATE_TOWER_SCALE + 0.05
		for deg in [60.0, 120.0, 240.0, 300.0]:
			var n := Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg)))
			var pos := c + Vector3(n.x, 0, n.y) * apothem
			_banner_at(pos + Vector3(0, 5.9, 0), atan2(n.x, n.y), BANNER_SCALE)
	add_child(WorldKit.multimesh(WorldKit.merged(GATE_TOWER), gate_towers))


## A banner whose top bar sits at `top_pos`, hanging along +Z rotated by yaw.
func _banner_at(top_pos: Vector3, yaw: float, scale: float) -> void:
	var path := BANNERS[_banner_count % BANNERS.size()]
	_banner_count += 1
	var top_y := WorldKit.bounds(path).end.y * scale
	var b := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	_banner_xforms[path].append(Transform3D(b, top_pos - Vector3(0, top_y, 0)))


func _add_banners(path: String, xforms: Array[Transform3D]) -> void:
	if xforms.is_empty():
		return
	var src: Mesh = WorldKit.merged(path)
	var mesh: ArrayMesh = src.duplicate()
	var base := src.surface_get_material(0) as BaseMaterial3D
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/world/shaders/banner.gdshader")
	if base != null and base.albedo_texture != null:
		m.set_shader_parameter(&"albedo_tex", WorldKit.mipmapped_texture(base.albedo_texture))
	mesh.surface_set_material(0, m)
	add_child(WorldKit.multimesh(mesh, xforms))


func _build_gate() -> void:
	var g := Coords.gate()
	var frame := MeshInstance3D.new()
	frame.mesh = WorldKit.merged(GATE, PackedStringArray(["door"]))
	frame.scale = Vector3.ONE * GATE_SCALE
	frame.position = Vector3(g.x, _top, WALL_Z)
	add_child(frame)
	for side in [&"wall_straight_gate_door_left", &"wall_straight_gate_door_right"]:
		var part := WorldKit.part(GATE, side)
		if part.is_empty():
			continue
		var door := MeshInstance3D.new()
		door.mesh = part[0]
		var hinge: Transform3D = part[1]
		var open := DOOR_OPEN_DEG if hinge.origin.x > 0 else -DOOR_OPEN_DEG
		door.transform = (
			Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * GATE_SCALE), frame.position)
			* hinge
			* Transform3D(Basis(Vector3.UP, deg_to_rad(open)), Vector3.ZERO)
		)
		add_child(door)
	var veil := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = VEIL_SIZE
	veil.mesh = quad
	veil.position = Vector3(g.x, _top + VEIL_SIZE.y * 0.5, WALL_Z - 0.3)
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_veil_mat.shader = preload("res://src/world/shaders/veil.gdshader")
	_veil_mat.set_shader_parameter(&"noise_tex", WorldKit.noise_texture(128, 0.05, 31))
	_veil_mat.set_shader_parameter(&"color", VEIL_COLOR)
	veil.material_override = _veil_mat
	add_child(veil)
	_gate_light.light_color = GATE_LIGHT_COLOR
	_gate_light.light_energy = GATE_LIGHT_ENERGY
	_gate_light.omni_range = 13.0
	_gate_light.position = Vector3(g.x, _top + 2.6, WALL_Z - 2.4)
	add_child(_gate_light)


func _build_torches() -> void:
	var noise := WorldKit.noise_texture(128, 0.06, 77)
	var flame_mat := ShaderMaterial.new()
	flame_mat.shader = preload("res://src/world/shaders/flame.gdshader")
	flame_mat.set_shader_parameter(&"noise_tex", noise)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.75, 1.3)
	quad.material = flame_mat
	var torch_mesh := WorldKit.merged(TORCH)
	var torch_box := WorldKit.bounds(TORCH)
	var gate_d := WorldKit.bounds(GATE).size.z * GATE_SCALE * 0.5
	var wall_d := WorldKit.bounds(WALL).size.z * WALL_SCALE * 0.5
	var xforms: Array[Transform3D] = []
	var flames: Array[Transform3D] = []
	var lit := 0
	for side in [-1.0, 1.0]:
		for x in [3.4, 9.8]:
			var d := gate_d if x < 5.0 else wall_d
			var inner := Vector3(_gx + side * x, _top + 3.3, WALL_Z - d)
			var outer := Vector3(_gx + side * x, _top + 3.3, WALL_Z + d)
			for pair in [[inner, PI], [outer, 0.0]]:
				var t := WorldKit.placed(pair[0], pair[1], TORCH_SCALE)
				xforms.append(t)
				var tip := t * Vector3(0, torch_box.end.y - 0.05, torch_box.get_center().z)
				flames.append(Transform3D(Basis.IDENTITY, tip + Vector3(0, 0.45, 0)))
				if pair[1] == PI and x < 5.0 and lit < 2:
					var light := OmniLight3D.new()
					light.light_color = TORCH_LIGHT_COLOR
					light.light_energy = TORCH_LIGHT_ENERGY
					light.omni_range = 8.0
					light.position = tip + Vector3(0, 0.6, -0.6)
					add_child(light)
					_torch_lights.append(light)
					lit += 1
	add_child(WorldKit.multimesh(torch_mesh, xforms))
	add_child(WorldKit.multimesh(quad, flames, false))
