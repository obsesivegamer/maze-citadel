class_name World
extends Node3D
## The citadel around the plateau: sky, light, terrain, portal, gate and the
## living backdrop (GDD §1, §12). Owns `env` and `sun`, which Quality tunes.
## Skeleton version: lighting, ground, plateau, portal and gate primitives.

var env: Environment
var sun: DirectionalLight3D

var _game: Game


func setup(game: Game) -> void:
	_game = game
	_build_lighting()
	_build_ground()
	_build_portal()
	_build_gate()


func _build_lighting() -> void:
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
	env.volumetric_fog_density = 0.006
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


func _mat(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _build_ground() -> void:
	var ground := PlaneMesh.new()
	ground.size = Vector2(260, 260)
	var mi := MeshInstance3D.new()
	mi.mesh = ground
	mi.material_override = _mat(Color(0.3, 0.55, 0.2))
	add_child(mi)
	var top := Coords.PLATEAU_TOP
	_box(
		Vector3(Grid.WIDTH + 2, top, Grid.DEPTH + 10),
		Vector3(0, top / 2, 0),
		_mat(Color(0.55, 0.52, 0.45))
	)
	var grid_mat := StandardMaterial3D.new()
	grid_mat.albedo_color = Color(0.4, 0.62, 0.25)
	grid_mat.roughness = 0.95
	_box(Vector3(Grid.WIDTH, 0.04, Grid.DEPTH), Vector3(0, top + 0.02, 0), grid_mat)


func _build_portal() -> void:
	var p := Coords.portal()
	var ring := TorusMesh.new()
	ring.inner_radius = 2.6
	ring.outer_radius = 3.2
	var red := Color(1.0, 0.18, 0.08)
	var glow := _mat(red, 0.4)
	glow.emission_enabled = true
	glow.emission = red
	glow.emission_energy_multiplier = 5.0
	var mi := MeshInstance3D.new()
	mi.mesh = ring
	mi.material_override = glow
	mi.position = p + Vector3(0, 3.2, 0)
	mi.rotation_degrees.x = 90
	add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = red
	light.light_energy = 5.0
	light.omni_range = 14.0
	light.position = p + Vector3(0, 3, 2)
	add_child(light)


func _build_gate() -> void:
	var g := Coords.gate()
	var stone := _mat(Color(0.66, 0.64, 0.6), 0.85)
	_box(Vector3(2.5, 8, 2.5), g + Vector3(-4, 4, 0), stone)
	_box(Vector3(2.5, 8, 2.5), g + Vector3(4, 4, 0), stone)
	_box(Vector3(10.5, 2, 2.5), g + Vector3(0, 7.5, 0), stone)
	var light := OmniLight3D.new()
	light.light_color = Color(0.25, 0.55, 1.0)
	light.light_energy = 4.0
	light.omni_range = 12.0
	light.position = g + Vector3(0, 3, -2)
	add_child(light)
