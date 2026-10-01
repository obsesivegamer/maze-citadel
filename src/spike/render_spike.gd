extends Node3D
## M1 render spike: a stand-in board that exercises every rendering feature the
## game relies on (soft shadows, SDFGI/SSIL, volumetric fog, SSR, decals, GPU
## particles, MultiMesh foliage, 24 moving creeps) so the quality presets can be
## measured on the target Mac. The real citadel replaces it in M3.

const TILE := 2.0
const COLS := 20
const ROWS := 28
const VIEWS := {
	"overview": [Vector3(0, 48, 46), Vector3(0, 0, 3)],
	"portal": [Vector3(10, 9, -20), Vector3(0, 4, -31)],
	"gate": [Vector3(-8, 9, 17), Vector3(0, 1.5, 29)],
}
const FAMILY_COLORS := [
	Color(0.2, 0.45, 0.95),
	Color(0.85, 0.22, 0.12),
	Color(0.35, 0.85, 0.95),
	Color(0.45, 0.85, 0.25),
]

var env: Environment
var sun: DirectionalLight3D
var camera: Camera3D

var _creeps: Array[Node3D] = []
var _path := Curve3D.new()
var _path_len := 1.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	_build_environment()
	_build_ground()
	var maze := _build_towers()
	_build_path(maze)
	_build_forest()
	_build_portal()
	_build_gate()
	_build_creeps()
	_build_decals()
	_build_smoke()
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.far = 400.0
	add_child(camera)
	set_view("overview")


func set_view(view_name: String) -> void:
	var v: Array = VIEWS.get(view_name, VIEWS.overview)
	camera.look_at_from_position(v[0], v[1])


func tile_to_world(col: int, row: int) -> Vector3:
	return Vector3((col - COLS / 2.0 + 0.5) * TILE, 1.5, (row - ROWS / 2.0 + 0.5) * TILE)


func _process(delta: float) -> void:
	_time += delta
	for i in _creeps.size():
		var c := _creeps[i]
		var d := fposmod(_time * 3.0 + i * 2.4, _path_len)
		var p := _path.sample_baked(d)
		var ahead := _path.sample_baked(fposmod(d + 0.6, _path_len))
		p.y += abs(sin(_time * 9.0 + i)) * 0.12
		c.position = p
		if p.distance_squared_to(ahead) > 0.01:
			c.look_at(Vector3(ahead.x, p.y, ahead.z), Vector3.UP)


func _mat(color: Color, roughness := 0.85, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(color, 0.4)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _mesh(mesh: Mesh, mat: Material, pos: Vector3, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _noise_texture(colors: PackedColorArray, freq: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.frequency = freq
	noise.seed = _rng.randi()
	var ramp := Gradient.new()
	ramp.colors = colors
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = ramp
	tex.seamless = true
	tex.width = 512
	tex.height = 512
	return tex


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.42, 0.8)
	sky_mat.sky_horizon_color = Color(0.7, 0.8, 0.92)
	sky_mat.ground_horizon_color = Color(0.55, 0.6, 0.62)
	sky_mat.ground_bottom_color = Color(0.25, 0.3, 0.25)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.25
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_albedo = Color(0.85, 0.88, 0.95)
	env.volumetric_fog_length = 90.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.5
	sun.light_angular_distance = 0.8
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)


func _build_ground() -> void:
	var grass := _mat(Color.WHITE, 0.95)
	grass.albedo_texture = _noise_texture(
		PackedColorArray([Color(0.24, 0.5, 0.16), Color(0.42, 0.68, 0.22)]), 0.02
	)
	grass.uv1_scale = Vector3(12, 12, 1)
	var plane := PlaneMesh.new()
	plane.size = Vector2(220, 220)
	_mesh(plane, grass, Vector3.ZERO)

	var stone := _mat(Color.WHITE, 0.9)
	stone.albedo_texture = _noise_texture(
		PackedColorArray([Color(0.48, 0.45, 0.4), Color(0.7, 0.66, 0.58)]), 0.05
	)
	stone.uv1_triplanar = true
	stone.uv1_scale = Vector3(0.15, 0.15, 0.15)
	var plateau := BoxMesh.new()
	plateau.size = Vector3(COLS * TILE + 4, 1.5, ROWS * TILE + 4)
	_mesh(plateau, stone, Vector3(0, 0.75, 0))

	var rock := _mat(Color(0.42, 0.38, 0.34), 0.95)
	for i in 26:
		var cliff := BoxMesh.new()
		cliff.size = Vector3(
			_rng.randf_range(4, 9), _rng.randf_range(4, 10), _rng.randf_range(4, 9)
		)
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := Vector3(
			side * _rng.randf_range(26, 34), cliff.size.y * 0.4, _rng.randf_range(-34, 34)
		)
		var mi := _mesh(cliff, rock, pos)
		mi.rotation.y = _rng.randf() * TAU

	var water := _mat(Color(0.12, 0.32, 0.5), 0.04)
	var river := PlaneMesh.new()
	river.size = Vector2(14, 220)
	_mesh(river, water, Vector3(-52, 0.05, 0))


## Lays towers in alternating walls with a gap at one end, the classic zig-zag.
## Returns the gap tile of each wall so the creep path can weave through them.
func _build_towers() -> Array[Vector2i]:
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.75
	base_mesh.bottom_radius = 0.9
	base_mesh.height = 2.4
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 1.05
	roof.height = 1.3
	var crystal := SphereMesh.new()
	crystal.radius = 0.28
	crystal.height = 0.56
	var stone := _mat(Color(0.62, 0.58, 0.52), 0.85)
	var gaps: Array[Vector2i] = []
	var placed := 0
	for wall in 4:
		var row := 5 + wall * 5
		var gap_col := COLS - 2 if wall % 2 == 0 else 1
		gaps.append(Vector2i(gap_col, row))
		for col in range(2, COLS - 2, 2):
			if placed >= 30 or abs(col - gap_col) < 2:
				continue
			var p := tile_to_world(col, row)
			var color: Color = FAMILY_COLORS[placed % FAMILY_COLORS.size()]
			_mesh(base_mesh, stone, p + Vector3(0, 1.2, 0))
			_mesh(roof, _mat(color, 0.6), p + Vector3(0, 3.05, 0))
			_mesh(crystal, _glow(color.lightened(0.3), 3.0), p + Vector3(0, 4.0, 0))
			placed += 1
	return gaps


func _build_path(gaps: Array[Vector2i]) -> void:
	_path.add_point(tile_to_world(COLS / 2, -1))
	for g in gaps:
		_path.add_point(tile_to_world(g.x, g.y - 2))
		_path.add_point(tile_to_world(g.x, g.y + 2))
	_path.add_point(tile_to_world(COLS / 2, ROWS))
	for i in _path.point_count:
		_path.set_point_position(i, _path.get_point_position(i) + Vector3(0, 0.65, 0))
	_path_len = _path.get_baked_length()


func _build_forest() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.4
	cone.height = 4.5
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
uniform vec3 albedo : source_color = vec3(0.1, 0.32, 0.15);
void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sway = sin(TIME * 1.4 + origin.x * 0.35 + origin.z * 0.2) * 0.12;
	VERTEX.x += sway * max(VERTEX.y + 2.25, 0.0) * 0.4;
}
void fragment() {
	ALBEDO = albedo * (0.8 + 0.2 * UV.y);
	ROUGHNESS = 0.9;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = 420
	for i in mm.instance_count:
		var x := _rng.randf_range(-90, 90)
		var z := _rng.randf_range(-90, 90)
		if abs(x) < 26 and abs(z) < 34:
			x = sign(x + 0.01) * _rng.randf_range(26, 90)
		var s := _rng.randf_range(0.7, 1.5)
		var t := Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(x, 2.25 * s, z))
		mm.set_instance_transform(i, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)


func _build_portal() -> void:
	var root := Node3D.new()
	root.position = Vector3(0, 0, -31)
	add_child(root)
	var ring := TorusMesh.new()
	ring.inner_radius = 3.0
	ring.outer_radius = 3.7
	var red := Color(1.0, 0.18, 0.08)
	var torus := _mesh(ring, _glow(red, 5.0), Vector3(0, 4.2, 0), root)
	torus.rotation_degrees.x = 90
	var core := QuadMesh.new()
	core.size = Vector2(6, 6)
	var swirl := _glow(Color(0.7, 0.05, 0.02), 2.5)
	swirl.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(core, swirl, Vector3(0, 4.2, 0), root)
	var light := OmniLight3D.new()
	light.light_color = red
	light.light_energy = 6.0
	light.omni_range = 16.0
	light.position = Vector3(0, 4, 3)
	light.light_volumetric_fog_energy = 3.0
	root.add_child(light)
	var fog_mat := FogMaterial.new()
	fog_mat.density = 0.35
	fog_mat.albedo = Color(1, 0.3, 0.2)
	fog_mat.emission = Color(0.6, 0.05, 0.02)
	var fog := FogVolume.new()
	fog.size = Vector3(10, 9, 6)
	fog.material = fog_mat
	fog.position = Vector3(0, 4, 0)
	root.add_child(fog)
	root.add_child(_sparks(red, Vector3(0, 4.2, 0), 260))


func _build_gate() -> void:
	var root := Node3D.new()
	root.position = Vector3(0, 0, 31)
	add_child(root)
	var stone := _mat(Color(0.66, 0.64, 0.6), 0.85)
	var tower := BoxMesh.new()
	tower.size = Vector3(3, 9, 3)
	_mesh(tower, stone, Vector3(-4.5, 4.5, 0), root)
	_mesh(tower, stone, Vector3(4.5, 4.5, 0), root)
	var arch := BoxMesh.new()
	arch.size = Vector3(12, 2.2, 3)
	_mesh(arch, stone, Vector3(0, 8, 0), root)
	var blue := Color(0.25, 0.55, 1.0)
	var veil := QuadMesh.new()
	veil.size = Vector2(6, 7)
	var veil_mat := _glow(blue, 1.6)
	veil_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(veil, veil_mat, Vector3(0, 3.5, 0), root)
	var light := OmniLight3D.new()
	light.light_color = blue
	light.light_energy = 4.0
	light.omni_range = 14.0
	light.position = Vector3(0, 4, -3)
	root.add_child(light)
	var banner := BoxMesh.new()
	banner.size = Vector3(1.2, 3.5, 0.08)
	for x in [-4.5, 4.5]:
		_mesh(banner, _mat(blue, 0.7), Vector3(x, 6, -1.6), root)


func _build_creeps() -> void:
	var body := CapsuleMesh.new()
	body.radius = 0.38
	body.height = 1.3
	var colors := [Color(0.3, 0.6, 0.2), Color(0.55, 0.42, 0.3), Color(0.6, 0.6, 0.7)]
	for i in 24:
		var c := Node3D.new()
		_mesh(body, _mat(colors[i % colors.size()], 0.7), Vector3(0, 0.65, 0), c)
		add_child(c)
		_creeps.append(c)


func _build_decals() -> void:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.05, 0.04, 0.03, 0.95), Color(0.1, 0.08, 0.05, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	for i in 12:
		var d := Decal.new()
		d.texture_albedo = tex
		d.size = Vector3(3, 2, 3)
		d.position = tile_to_world(_rng.randi_range(2, COLS - 3), _rng.randi_range(3, ROWS - 3))
		add_child(d)


func _build_smoke() -> void:
	for i in 5:
		var p := Vector3(_rng.randf_range(30, 44), 3, _rng.randf_range(-20, 20))
		var e := _sparks(Color(0.55, 0.55, 0.58, 0.5), p, 60)
		var pm: ParticleProcessMaterial = e.process_material
		pm.gravity = Vector3(0.3, 0.6, 0)
		pm.scale_min = 2.0
		pm.scale_max = 4.0
		e.lifetime = 5.0
		add_child(e)


func _sparks(color: Color, pos: Vector3, amount: int) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 2.5
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, 0.8, 0)
	pm.scale_min = 0.08
	pm.scale_max = 0.22
	pm.color = color
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(2.5, 2.5, 2.5) if color.a > 0.9 else Color.WHITE
	quad.material = m
	var e := GPUParticles3D.new()
	e.amount = amount
	e.lifetime = 2.5
	e.process_material = pm
	e.draw_pass_1 = quad
	e.position = pos
	e.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 16, 16))
	return e
