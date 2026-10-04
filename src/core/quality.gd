class_name Quality
extends RefCounted
## Presentation presets (GDD §14). They scale rendering cost only; gameplay
## values such as maze size, wave count and counters never read from here.

enum Preset { CINEMATIC, BALANCED, PERFORMANCE }

const NAMES := ["cinematic", "balanced", "performance"]

const UPSCALERS := {
	"metalfx_temporal": Viewport.SCALING_3D_MODE_METALFX_TEMPORAL,
	"metalfx_spatial": Viewport.SCALING_3D_MODE_METALFX_SPATIAL,
	"fsr2": Viewport.SCALING_3D_MODE_FSR2,
	"fsr": Viewport.SCALING_3D_MODE_FSR,
	"bilinear": Viewport.SCALING_3D_MODE_BILINEAR,
}
## MetalFX exists only on Apple's Metal driver. Godot falls back to these same
## upscalers elsewhere, but with a warning and a viewport that still says MetalFX.
const NON_METAL_UPSCALERS := {"metalfx_temporal": "fsr2", "metalfx_spatial": "fsr"}

## Re-fits the render scale when the window changes size (maximize, fullscreen,
## a move to another monitor). Off Metal only; replaced on every apply.
static var _refit := Callable()
static var _watched: Viewport


static func from_name(preset_name: String) -> Preset:
	var i := NAMES.find(preset_name.to_lower())
	return Preset.BALANCED if i == -1 else i as Preset


static func settings(preset: Preset) -> Dictionary:
	match preset:
		# SDFGI and SSR cost ~2x and barely show in this bright stylized scene
		# (slot 1), so Cinematic spends that budget on sharpness, AO and shadows.
		Preset.CINEMATIC:
			return {
				"render_scale": 0.7,
				"min_render_height": 720,
				"upscaler": "metalfx_temporal",
				"sdfgi": false,
				"ssil": false,
				"ssao": true,
				"ssao_quality": RenderingServer.ENV_SSAO_QUALITY_HIGH,
				"ssr": false,
				"fog": true,
				"fog_size": 128,
				"fog_depth": 96,
				"shadow_size": 4096,
				"shadow_splits": 4,
				"particles": 1.0,
				"crowd": 1.0,
				"foliage": 1.0,
				"leaf_flutter": 1.0,
			}
		Preset.PERFORMANCE:
			return {
				"render_scale": 0.5,
				"min_render_height": 0,
				"upscaler": "metalfx_spatial",
				"sdfgi": false,
				"ssil": false,
				"ssao": false,
				"ssao_quality": RenderingServer.ENV_SSAO_QUALITY_LOW,
				"ssr": false,
				"fog": false,
				"fog_size": 64,
				"fog_depth": 32,
				"shadow_size": 1024,
				"shadow_splits": 2,
				"particles": 0.4,
				"crowd": 0.35,
				"foliage": 0.5,
				# Spatial upscalers (MetalFX spatial, FSR 1) have no temporal
				# smoothing, and shivering leaf cards shimmer (issue #22).
				"leaf_flutter": 0.0,
			}
		_:
			return {
				"render_scale": 0.5,
				# Scale 0.5 was tuned on a Retina panel (~890 px tall inside);
				# a 1080p PC monitor would get 540 px, so keep at least 720.
				"min_render_height": 720,
				"upscaler": "metalfx_temporal",
				"sdfgi": false,
				"ssil": false,
				"ssao": true,
				# Low SSAO and a coarser fog grid look the same here and buy
				# headroom under 16.7 ms in the heaviest waves (docs/perf.md).
				"ssao_quality": RenderingServer.ENV_SSAO_QUALITY_LOW,
				"ssr": false,
				"fog": true,
				"fog_size": 48,
				"fog_depth": 32,
				"shadow_size": 2048,
				"shadow_splits": 4,
				"particles": 0.7,
				"crowd": 0.7,
				"foliage": 0.8,
				"leaf_flutter": 1.0,
			}


static func apply(
	preset: Preset,
	viewport: Viewport,
	env: Environment,
	sun: DirectionalLight3D,
	overrides := {},
) -> Dictionary:
	var s := settings(preset)
	s.merge(overrides, true)
	# An explicit scale (benchmarks, --render_scale) wins over the floor.
	if overrides.has("render_scale") and not overrides.has("min_render_height"):
		s.min_render_height = 0
	var driver := RenderingServer.get_current_rendering_driver_name()
	var preset_settings := s
	s = for_display(preset_settings, driver, DisplayServer.window_get_size().y)
	viewport.scaling_3d_mode = UPSCALERS[s.upscaler]
	viewport.scaling_3d_scale = s.render_scale
	_watch_window(viewport, preset_settings, driver)
	env.sdfgi_enabled = s.sdfgi
	env.ssil_enabled = s.ssil
	env.ssao_enabled = s.ssao
	env.ssr_enabled = s.ssr
	env.volumetric_fog_enabled = s.fog
	RenderingServer.environment_set_ssao_quality(s.ssao_quality, true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(s.fog_size, s.fog_depth)
	RenderingServer.directional_shadow_atlas_set_size(s.shadow_size, true)
	RenderingServer.global_shader_parameter_set(&"leaf_flutter", s.leaf_flutter)
	sun.directional_shadow_mode = (
		DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		if s.shadow_splits == 4
		else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	)
	PerfRender.apply(viewport, env, sun, s)
	return s


## Fits a preset to the GPU driver and window off Apple's Metal (Windows,
## Linux): FSR in place of MetalFX, and a render scale that keeps at least
## min_render_height pixels of 3D height, since the presets were tuned on a
## Retina panel. On Metal the preset passes through unchanged. Height 0
## (headless) leaves the scale. GPUs with neither Vulkan nor Direct3D 12 get
## Godot's OpenGL fallback (opengl3, opengl3_angle, opengl3_es), which only
## has bilinear upscaling.
static func for_display(s: Dictionary, driver: String, window_height: int) -> Dictionary:
	var out := s.duplicate()
	if driver == "metal":
		return out
	if driver.begins_with("opengl3"):
		out.upscaler = "bilinear"
	else:
		out.upscaler = NON_METAL_UPSCALERS.get(s.upscaler, s.upscaler)
	if window_height > 0 and s.min_render_height > 0:
		var floor_scale := minf(1.0, float(s.min_render_height) / window_height)
		out.render_scale = maxf(s.render_scale, floor_scale)
	return out


static func _watch_window(viewport: Viewport, s: Dictionary, driver: String) -> void:
	if is_instance_valid(_watched) and _watched.size_changed.is_connected(_refit):
		_watched.size_changed.disconnect(_refit)
	_refit = Callable()
	_watched = null
	if driver == "metal":
		return
	_refit = func() -> void:
		var fit: float = for_display(s, driver, DisplayServer.window_get_size().y).render_scale
		if not is_equal_approx(viewport.scaling_3d_scale, fit):
			viewport.scaling_3d_scale = fit
	viewport.size_changed.connect(_refit)
	_watched = viewport
