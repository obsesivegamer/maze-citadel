class_name WorldPortal
extends Node3D
## The demon portal at Coords.portal() (GDD §1, §12): a ruined stone arch
## kitbashed from arch, broken walls, rubble, runestone pillars, skull posts
## and red rock spikes, filled with a swirling vortex, a red volumetric plume,
## rising sparks and one red light. Creeps step out of it onto the grid.

const ENV := "res://assets/environment/"
const HB := ENV + "kaykit_halloween_bits/"
const DG := ENV + "kaykit_dungeon_remastered/"
const NK := ENV + "kenney_nature_kit/"
const ROCK_TEX := ENV + "tex_rubberduck_handpainted/hp_rock.jpg"
const SPIKES: Array[String] = [
	NK + "rock_tallA.glb", NK + "rock_tallB.glb", NK + "rock_tallG.glb", NK + "rock_tallJ.glb"
]
## Kitbash pieces relative to the portal centre: [path, offset, yaw°, scale].
const PIECES := [
	[HB + "arch.glb", Vector3(0, 0, -0.6), 0.0, 1.9],
	[DG + "wall_broken.glb", Vector3(-6.6, 0, -1.8), 20.0, 0.9],
	[DG + "wall_broken.glb", Vector3(6.9, 0, -1.4), -24.0, 0.85],
	[DG + "rubble_large.glb", Vector3(0.4, 0, -4.4), 180.0, 0.72],
	[DG + "rubble_half.glb", Vector3(-4.9, 0, 0.9), 50.0, 0.45],
	[DG + "rubble_half.glb", Vector3(5.1, 0, 0.6), -35.0, 0.42],
	[HB + "pillar.glb", Vector3(-4.4, 0, -0.2), 12.0, 0.85],
	[HB + "pillar.glb", Vector3(4.5, 0, -0.1), -8.0, 0.78],
	[HB + "post_skull.glb", Vector3(-3.3, 0, 1.3), 10.0, 0.9],
	[HB + "post_skull.glb", Vector3(3.4, 0, 1.2), -15.0, 0.9],
	[HB + "skull_candle.glb", Vector3(-2.5, 0, -0.3), 25.0, 0.8],
	[HB + "skull_candle.glb", Vector3(2.7, 0, -0.5), -30.0, 0.75],
	[HB + "tree_dead_large.glb", Vector3(-10.5, 0, -2.5), 40.0, 1.7],
	[HB + "tree_dead_large.glb", Vector3(11.0, 0, -3.5), -120.0, 1.5],
	[HB + "tree_dead_medium.glb", Vector3(-15.0, 0, -4.0), 200.0, 1.6],
	[HB + "bone_A.glb", Vector3(-1.8, 0, 2.0), 70.0, 1.2],
	[HB + "ribcage.glb", Vector3(5.8, 0, 2.2), -40.0, 1.0],
]
const SPIKE_COUNT := 14
const SPIKE_RADIUS := Vector2(6.5, 10.0)
const SPIKE_TINT := Color(0.5, 0.2, 0.17)
const SWIRL_SIZE := Vector2(5.0, 6.2)
const SWIRL_HEIGHT := 3.3
const RED := Color(1.0, 0.16, 0.06)
const LIGHT_ENERGY := 5.5
const FOG_SIZE := Vector3(8.0, 13.0, 8.0)
const SPARKS := 110
const EMBERS := 40

var _sparks: GPUParticles3D
var _embers: GPUParticles3D
var _light := OmniLight3D.new()
var _time := 0.0


func build() -> void:
	var p := Coords.portal()
	var entries := []
	for piece in PIECES:
		var t := WorldKit.placed(p + piece[1], deg_to_rad(piece[2]), piece[3])
		entries.append([piece[0], t])
	var spike_mat := StandardMaterial3D.new()
	spike_mat.albedo_texture = WorldKit.texture(ROCK_TEX)
	spike_mat.albedo_color = SPIKE_TINT
	spike_mat.uv1_triplanar = true
	spike_mat.uv1_scale = Vector3.ONE * 0.6
	spike_mat.roughness = 0.9
	var rng := RandomNumberGenerator.new()
	rng.seed = 66
	for i in SPIKE_COUNT:
		# A crescent behind and beside the arch, opening toward the board.
		var a := lerpf(PI * 1.05, PI * 1.95, float(i) / (SPIKE_COUNT - 1)) + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(SPIKE_RADIUS.x, SPIKE_RADIUS.y)
		var pos := p + Vector3(cos(a) * r, -0.3, sin(a) * r * 0.7)
		var s := rng.randf_range(2.2, 4.2)
		var t := WorldKit.placed(pos, rng.randf() * TAU, s, rng.randf_range(-0.25, 0.25))
		entries.append([SPIKES[i % SPIKES.size()], t, spike_mat])
	var mi := MeshInstance3D.new()
	mi.name = "Ruins"
	mi.mesh = WorldKit.bake(entries)
	add_child(mi)
	_build_swirl(p)
	_build_fog(p)
	_sparks = _particles(p + Vector3(0, SWIRL_HEIGHT, 0.4), SPARKS, false)
	_embers = _particles(p + Vector3(0, 0.6, 0.5), EMBERS, true)
	_light.light_color = RED
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = 15.0
	_light.light_volumetric_fog_energy = 2.0
	_light.position = p + Vector3(0, SWIRL_HEIGHT, 2.2)
	add_child(_light)


func set_particle_scale(f: float) -> void:
	_sparks.amount = maxi(8, roundi(SPARKS * f))
	_embers.amount = maxi(4, roundi(EMBERS * f))


func _process(delta: float) -> void:
	_time += delta
	_light.light_energy = LIGHT_ENERGY * (0.85 + 0.15 * sin(_time * 2.3) * sin(_time * 3.7))


func _build_swirl(p: Vector3) -> void:
	var quad := QuadMesh.new()
	quad.size = SWIRL_SIZE
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/world/shaders/portal_swirl.gdshader")
	m.set_shader_parameter(&"noise_tex", WorldKit.noise_texture(256, 0.03, 19))
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = p + Vector3(0, SWIRL_HEIGHT, -0.5)
	add_child(mi)


func _build_fog(p: Vector3) -> void:
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/world/shaders/portal_fog.gdshader")
	m.set_shader_parameter(&"noise3d", WorldKit.noise_texture_3d(64, 0.08, 23))
	var fog := FogVolume.new()
	fog.size = FOG_SIZE
	fog.material = m
	fog.position = p + Vector3(0, FOG_SIZE.y * 0.5, -0.5)
	add_child(fog)


## Sparks spiral up out of the vortex; embers drift low across the apron.
func _particles(pos: Vector3, amount: int, ground: bool) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.2, 0.3, 0.4) if ground else Vector3(1.8, 2.4, 0.3)
	pm.direction = Vector3(0, 1, 0.3)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.4 if ground else 0.8
	pm.initial_velocity_max = 1.2 if ground else 2.6
	pm.gravity = Vector3(0, 0.4 if ground else 1.2, 0)
	pm.tangential_accel_min = -1.0
	pm.tangential_accel_max = 1.0
	pm.damping_min = 0.3
	pm.damping_max = 0.8
	pm.scale_min = 0.05
	pm.scale_max = 0.16 if ground else 0.22
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(3.0, 1.4, 0.4), Color(2.4, 0.3, 0.08), Color(0.6, 0.05, 0.02, 0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var quad := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _dot_texture()
	quad.material = m
	var e := GPUParticles3D.new()
	e.amount = amount
	e.lifetime = 3.0 if ground else 2.4
	e.preprocess = 2.0
	e.process_material = pm
	e.draw_pass_1 = quad
	e.position = pos
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 16, 16))
	add_child(e)
	return e


static func _dot_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t
