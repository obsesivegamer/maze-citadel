class_name PerfRender
extends RefCounted
## Renderer experiment switches for the screen-slot matrix
## (tools/perf_matrix.sh), applied by Quality.apply on top of the preset. Each
## is a `--pf-<name>=<value>` flag (see PerfFlags) and only touches the
## renderer when given, so a run without flags renders exactly like the
## shipped game. Preset keys (render_scale, upscaler, ssao, ssao_quality, fog,
## fog_size, fog_depth, shadow_size, shadow_splits) already have their own
## `--<key>=` overrides. Startup-only settings (depth prepass, rendering
## method, frame queue) can't change at runtime: the matrix runner passes
## engine arguments or writes a temporary override.cfg for those.
##
## Sun shadows (current values in brackets):
##   shadow-filter=0..5        soft-shadow filter: 0 hard .. 5 ultra [3, soft medium]
##   sun-angular=<deg>         sun size; > 0 is PCSS (blocker search), 0 plain PCF [0.8]
##   shadow-blur=<f>           PCF filter radius scale [1.2]
##   shadow-distance=<m>       shadow max distance from the camera [150]
##   shadow-splits=a,b,c       cascade split ratios [0.1,0.2,0.5]
##   shadow-blend=<bool>       blend between cascades [false]
##   shadow-fade=<f>           fade-out start as a fraction of the distance [0.8]
##   shadow-bias=<f>, shadow-normal-bias=<f>, shadow-pancake=<m>   [0.1, 2.0, 20]
##   sun-shadow=<bool>         diagnostic: sun shadows at all [true]
## Glow:
##   glow=<bool> [true] · glow-levels=l1,..,l7 [0,0.8,0.4,0.1,0,0,0]
##   glow-bloom=<f> [0.04] · glow-bicubic=<bool> upscale filter [true]
## SSAO (when the preset enables it):
##   ssao-radius=<m> [1.0] · ssao-intensity=<f> [2.0]
##   ssao-half=<bool> half-resolution buffers [true] · ssao-blur=0..6 passes [2]
## Volumetric fog (when the preset enables it):
##   fog-reprojection=<bool> [true] · fog-filter=<bool> 3D blur [true]
##   fog-length=<m> froxel depth range [90]
## Viewport:
##   lod-threshold=<px> mesh LOD aggressiveness [1.0]
##   msaa=0|2|4|8 [0] · ssaa=none|fxaa|smaa [none] · taa=<bool> [false]
##   debanding=<bool> [true] · aniso=1|2|4|8|16 [4]
##   mip-bias=<f> added to the engine's log2(render scale) bias [0]
##   roughness-limiter=<bool> [true]

const MSAA := {
	"0": Viewport.MSAA_DISABLED,
	"2": Viewport.MSAA_2X,
	"4": Viewport.MSAA_4X,
	"8": Viewport.MSAA_8X,
}
const SSAA := {
	"none": Viewport.SCREEN_SPACE_AA_DISABLED,
	"fxaa": Viewport.SCREEN_SPACE_AA_FXAA,
	"smaa": Viewport.SCREEN_SPACE_AA_SMAA,
}
const ANISO := {
	"0": Viewport.ANISOTROPY_DISABLED,
	"1": Viewport.ANISOTROPY_DISABLED,
	"2": Viewport.ANISOTROPY_2X,
	"4": Viewport.ANISOTROPY_4X,
	"8": Viewport.ANISOTROPY_8X,
	"16": Viewport.ANISOTROPY_16X,
}
## The SSAO buffer settings Quality.apply passes, for flags that change one.
const SSAO_HALF := true
const SSAO_BLUR := 2
const TRUE_WORDS := ["true", "1", "on", "yes"]


## Applies this run's `--pf-*` renderer flags.
static func apply(
	viewport: Viewport, env: Environment, sun: DirectionalLight3D, settings: Dictionary
) -> Dictionary:
	return apply_flags(viewport, env, sun, settings, PerfFlags.active())


## Applies the renderer flags in `flags` (names without the `pf-` prefix,
## string values) and returns the parsed values it applied. Unknown names are
## left for other code; a bad value is skipped with a warning.
static func apply_flags(
	viewport: Viewport,
	env: Environment,
	sun: DirectionalLight3D,
	settings: Dictionary,
	flags: Dictionary,
) -> Dictionary:
	var f := Reader.new(flags)
	_apply_shadows(f, sun)
	_apply_glow(f, env)
	_apply_ssao(f, env, settings)
	_apply_fog(f, env)
	_apply_viewport(f, viewport)
	return f.applied


static func _apply_shadows(f: Reader, sun: DirectionalLight3D) -> void:
	if f.has("shadow-filter"):
		var quality := clampi(f.whole("shadow-filter"), 0, RenderingServer.SHADOW_QUALITY_MAX - 1)
		f.applied["shadow-filter"] = quality
		RenderingServer.directional_soft_shadow_filter_set_quality(
			quality as RenderingServer.ShadowQuality
		)
	if f.has("sun-angular"):
		sun.light_angular_distance = f.num("sun-angular")
	if f.has("shadow-blur"):
		sun.shadow_blur = f.num("shadow-blur")
	if f.has("shadow-distance"):
		sun.directional_shadow_max_distance = f.num("shadow-distance")
	if f.has("shadow-splits"):
		var splits := f.nums("shadow-splits")
		var params := [
			Light3D.PARAM_SHADOW_SPLIT_1_OFFSET,
			Light3D.PARAM_SHADOW_SPLIT_2_OFFSET,
			Light3D.PARAM_SHADOW_SPLIT_3_OFFSET,
		]
		for i in mini(splits.size(), params.size()):
			sun.set_param(params[i], splits[i])
	if f.has("shadow-blend"):
		sun.directional_shadow_blend_splits = f.on("shadow-blend")
	if f.has("shadow-fade"):
		sun.directional_shadow_fade_start = f.num("shadow-fade")
	if f.has("shadow-bias"):
		sun.shadow_bias = f.num("shadow-bias")
	if f.has("shadow-normal-bias"):
		sun.shadow_normal_bias = f.num("shadow-normal-bias")
	if f.has("shadow-pancake"):
		sun.directional_shadow_pancake_size = f.num("shadow-pancake")
	if f.has("sun-shadow"):
		sun.shadow_enabled = f.on("sun-shadow")


static func _apply_glow(f: Reader, env: Environment) -> void:
	if f.has("glow"):
		env.glow_enabled = f.on("glow")
	if f.has("glow-levels"):
		var levels := f.nums("glow-levels")
		for i in mini(levels.size(), 7):
			env.set_glow_level(i, levels[i])
	if f.has("glow-bloom"):
		env.glow_bloom = f.num("glow-bloom")
	if f.has("glow-bicubic"):
		RenderingServer.environment_glow_set_use_bicubic_upscale(f.on("glow-bicubic"))


static func _apply_ssao(f: Reader, env: Environment, settings: Dictionary) -> void:
	if f.has("ssao-radius"):
		env.ssao_radius = f.num("ssao-radius")
	if f.has("ssao-intensity"):
		env.ssao_intensity = f.num("ssao-intensity")
	if f.has("ssao-half") or f.has("ssao-blur"):
		var half := f.on("ssao-half") if f.has("ssao-half") else SSAO_HALF
		var blur := SSAO_BLUR
		if f.has("ssao-blur"):
			blur = clampi(f.whole("ssao-blur"), 0, 6)
			f.applied["ssao-blur"] = blur
		RenderingServer.environment_set_ssao_quality(
			settings.get("ssao_quality", RenderingServer.ENV_SSAO_QUALITY_MEDIUM),
			half,
			0.5,
			blur,
			50.0,
			300.0
		)


static func _apply_fog(f: Reader, env: Environment) -> void:
	if f.has("fog-reprojection"):
		env.volumetric_fog_temporal_reprojection_enabled = f.on("fog-reprojection")
	if f.has("fog-filter"):
		RenderingServer.environment_set_volumetric_fog_filter_active(f.on("fog-filter"))
	if f.has("fog-length"):
		env.volumetric_fog_length = f.num("fog-length")


static func _apply_viewport(f: Reader, viewport: Viewport) -> void:
	if f.has("lod-threshold"):
		viewport.mesh_lod_threshold = f.num("lod-threshold")
	var msaa := f.choice("msaa", MSAA)
	if msaa != -1:
		viewport.msaa_3d = msaa as Viewport.MSAA
	var ssaa := f.choice("ssaa", SSAA)
	if ssaa != -1:
		viewport.screen_space_aa = ssaa as Viewport.ScreenSpaceAA
	if f.has("taa"):
		viewport.use_taa = f.on("taa")
	if f.has("debanding"):
		viewport.use_debanding = f.on("debanding")
	var aniso := f.choice("aniso", ANISO)
	if aniso != -1:
		viewport.anisotropic_filtering_level = aniso as Viewport.AnisotropicFiltering
	if f.has("mip-bias"):
		viewport.texture_mipmap_bias = f.num("mip-bias")
	if f.has("roughness-limiter"):
		RenderingServer.screen_space_roughness_limiter_set_active(
			f.on("roughness-limiter"),
			ProjectSettings.get_setting(
				"rendering/anti_aliasing/screen_space_roughness_limiter/amount", 0.25
			),
			ProjectSettings.get_setting(
				"rendering/anti_aliasing/screen_space_roughness_limiter/limit", 0.18
			)
		)


## Reads flag values and records each parsed value in `applied`.
class Reader:
	var applied := {}
	var _flags: Dictionary

	func _init(flags: Dictionary) -> void:
		_flags = flags

	func has(key: String) -> bool:
		return _flags.has(key)

	func num(key: String) -> float:
		var text := String(_flags[key])
		if not text.is_valid_float():
			push_warning("PerfRender: --pf-%s=%s is not a number, using 0" % [key, text])
		var value := text.to_float()
		applied[key] = value
		return value

	func whole(key: String) -> int:
		return int(num(key))

	func on(key: String) -> bool:
		var value := String(_flags[key]).to_lower() in TRUE_WORDS
		applied[key] = value
		return value

	func nums(key: String) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		for part in String(_flags[key]).split(",", false):
			out.append(part.strip_edges().to_float())
		applied[key] = out
		return out

	## The value of `key` in `choices`; -1 if the flag is absent, or (with a
	## warning) if its value isn't one of them.
	func choice(key: String, choices: Dictionary) -> int:
		if not has(key):
			return -1
		var text := String(_flags[key]).to_lower()
		if not choices.has(text):
			push_warning(
				"PerfRender: --pf-%s=%s is not one of %s" % [key, text, ", ".join(choices.keys())]
			)
			return -1
		applied[key] = text
		return choices[text]
