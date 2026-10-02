extends "res://tests/test_case.gd"

const VIEWPORT_PROPS := [
	"msaa_3d",
	"screen_space_aa",
	"use_taa",
	"use_debanding",
	"anisotropic_filtering_level",
	"mesh_lod_threshold",
	"texture_mipmap_bias",
]
const ENV_PROPS := [
	"glow_enabled",
	"glow_bloom",
	"glow_levels/2",
	"ssao_radius",
	"ssao_intensity",
	"volumetric_fog_temporal_reprojection_enabled",
	"volumetric_fog_length",
]
const SUN_PROPS := [
	"light_angular_distance",
	"shadow_blur",
	"shadow_enabled",
	"shadow_bias",
	"shadow_normal_bias",
	"directional_shadow_max_distance",
	"directional_shadow_split_1",
	"directional_shadow_split_3",
	"directional_shadow_blend_splits",
	"directional_shadow_fade_start",
	"directional_shadow_pancake_size",
]

var _vp: SubViewport
var _env: Environment
var _sun: DirectionalLight3D


func test_no_flags_change_nothing() -> void:
	_setup()
	var before := _snapshot()
	var applied := _apply({"unrelated-flag": "1"})
	check_eq(applied, {}, "applied")
	check_eq(_snapshot(), before, "properties")
	_teardown()


func test_shadow_flags() -> void:
	_setup()
	var applied := _apply(
		{
			"sun-angular": "0",
			"shadow-distance": "120",
			"shadow-splits": "0.4, 0.6,0.8",
			"shadow-blend": "on",
			"sun-shadow": "false",
			"shadow-filter": "9",
			"shadow-pancake": "35",
		}
	)
	check_near(_sun.light_angular_distance, 0.0)
	check_near(_sun.directional_shadow_max_distance, 120.0)
	check_near(_sun.directional_shadow_split_1, 0.4)
	check_near(_sun.directional_shadow_split_2, 0.6)
	check_near(_sun.directional_shadow_split_3, 0.8)
	check_near(_sun.directional_shadow_pancake_size, 35.0)
	check(_sun.directional_shadow_blend_splits, "blend splits")
	check(not _sun.shadow_enabled, "sun shadow off")
	check_eq(applied.get("shadow-filter"), 5, "filter clamped to ultra")
	_teardown()


func test_viewport_flags_accept_sample_counts_and_names() -> void:
	_setup()
	_apply(
		{
			"msaa": "4",
			"ssaa": "SMAA",
			"aniso": "16",
			"lod-threshold": "4",
			"mip-bias": "0.5",
			"taa": "yes",
			"debanding": "0",
		}
	)
	check_eq(_vp.msaa_3d, Viewport.MSAA_4X, "msaa")
	check_eq(_vp.screen_space_aa, Viewport.SCREEN_SPACE_AA_SMAA, "ssaa")
	check_eq(_vp.anisotropic_filtering_level, Viewport.ANISOTROPY_16X, "aniso")
	check_near(_vp.mesh_lod_threshold, 4.0)
	check_near(_vp.texture_mipmap_bias, 0.5)
	check(_vp.use_taa, "taa")
	check(not _vp.use_debanding, "debanding")
	_teardown()


func test_bad_choice_is_skipped() -> void:
	_setup()
	var before := _snapshot()
	var applied := _apply({"ssaa": "smaaa", "msaa": "3"})
	check_eq(_snapshot(), before, "unchanged")
	check(not applied.has("ssaa") and not applied.has("msaa"), "not recorded")
	_teardown()


func test_environment_flags() -> void:
	_setup()
	var applied := _apply(
		{
			"glow": "off",
			"glow-levels": "0,1,0.5",
			"glow-bloom": "0",
			"ssao-radius": "2.5",
			"ssao-half": "false",
			"fog-reprojection": "false",
			"fog-length": "60",
		}
	)
	check(not _env.glow_enabled, "glow off")
	check_near(_env.get_glow_level(1), 1.0)
	check_near(_env.get_glow_level(2), 0.5)
	check_near(_env.get_glow_level(3), 0.1, 1e-4, "level 4 untouched")
	check_near(_env.glow_bloom, 0.0)
	check_near(_env.ssao_radius, 2.5)
	check(not _env.volumetric_fog_temporal_reprojection_enabled, "reprojection")
	check_near(_env.volumetric_fog_length, 60.0)
	check_eq(applied.get("ssao-half"), false, "ssao-half recorded")
	_teardown()


func test_bench_reads_no_overrides_without_file() -> void:
	check_eq(Bench.override_settings("res://does_not_exist.cfg"), {})


func _setup() -> void:
	_vp = SubViewport.new()
	_env = Environment.new()
	_env.glow_bloom = 0.04
	_sun = DirectionalLight3D.new()
	_sun.light_angular_distance = 0.8
	_sun.shadow_enabled = true


func _teardown() -> void:
	_vp.free()
	_sun.free()


func _apply(flags: Dictionary) -> Dictionary:
	var settings := Quality.settings(Quality.Preset.BALANCED)
	return PerfRender.apply_flags(_vp, _env, _sun, settings, flags)


func _snapshot() -> Dictionary:
	var out := {}
	for p in VIEWPORT_PROPS:
		out["vp." + p] = _vp.get(p)
	for p in ENV_PROPS:
		out["env." + p] = _env.get(p)
	for p in SUN_PROPS:
		out["sun." + p] = _sun.get(p)
	return out
