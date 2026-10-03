class_name World
extends Node3D
## The citadel around the plateau (GDD §1, §12): sky and sun, terrain and
## cliffs, outer walls and gate, the demon portal, forests, the village and
## its people, and the map's ruins on the plateau. Owns `env` and `sun`, which
## Quality tunes, and reacts to the match: the gate flashes on a leak,
## villagers cheer cleared waves and run from leaking bosses, gryphons circle
## on victory.

var env: Environment
var sun: DirectionalLight3D

var _game: Game
var _terrain := WorldTerrain.new()
var _nature := WorldNature.new()
var _village := WorldVillage.new()
var _citadel := WorldCitadel.new()
var _portal := WorldPortal.new()
var _crowd := WorldCrowd.new()
var _ruins := WorldRuins.new()


func setup(game: Game) -> void:
	for step in setup_steps(game):
		step[1].call()


## The build as [status text, callable] steps, so a loading screen can run
## one per frame.
func setup_steps(game: Game) -> Array:
	_game = game
	_terrain.grid = game.sim.grid
	_ruins.grid = game.sim.grid
	var steps: Array = [["Lighting the sky", _build_lighting]]
	var parts := [
		[_terrain, "Raising the plateau and cliffs"],
		[_nature, "Planting the forests"],
		[_village, "Building the village"],
		[_citadel, "Raising the citadel walls"],
		[_portal, "Opening the demon portal"],
		[_crowd, "Waking the villagers"],
		[_ruins, "Scattering the ruins"],
	]
	for entry in parts:
		steps.append([entry[1], _add_part.bind(entry[0])])
	steps.append(["Listening for the horde", _listen.bind(game)])
	return steps


func _add_part(part: Node) -> void:
	add_child(part)
	part.build()


func _listen(game: Game) -> void:
	game.sim_event.connect(_on_sim_event)
	game.quality_changed.connect(_on_quality_changed)


## World positions of the ambience beds, for the audio director.
func ambience_points() -> Dictionary:
	return {
		&"river": WorldLayout.ground_point(Vector2(-43, 0)),
		&"village": WorldLayout.ground_point(WorldLayout.VILLAGE_CENTER),
		&"forest": WorldLayout.ground_point(Vector2(55, -45)),
		&"portal": Coords.portal(),
	}


func _on_sim_event(e: Dictionary) -> void:
	match e.type:
		&"leaked":
			_citadel.flash()
			if e.cost >= 2:
				_crowd.flee()
		&"wave_cleared":
			_crowd.cheer()
		&"victory":
			_crowd.celebrate()


func _on_quality_changed(_preset: Quality.Preset) -> void:
	var s := _game.quality_settings
	_nature.set_density(s.foliage)
	_crowd.set_density(s.crowd)
	_portal.set_particle_scale(s.particles)


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
