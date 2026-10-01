extends "res://tests/test_case.gd"


func test_cli_parses_flags_and_values() -> void:
	var a := Cli.parse(PackedStringArray(["--quality=cinematic", "--bench", "--shot=a=b"]))
	check_eq(a.get("quality"), "cinematic", "value")
	check_eq(a.get("bench"), "true", "bare flag")
	check_eq(a.get("shot"), "a=b", "only first = splits")


func test_quality_presets_scale_down_monotonically() -> void:
	var c := Quality.settings(Quality.Preset.CINEMATIC)
	var b := Quality.settings(Quality.Preset.BALANCED)
	var p := Quality.settings(Quality.Preset.PERFORMANCE)
	check(c.render_scale >= b.render_scale and b.render_scale >= p.render_scale, "render scale")
	check(c.shadow_size >= b.shadow_size and b.shadow_size >= p.shadow_size, "shadow size")
	for key in ["particles", "crowd", "foliage"]:
		check(c[key] >= b[key] and b[key] >= p[key], key)
	for s in [c, b, p]:
		check(Quality.UPSCALERS.has(s.upscaler), "known upscaler %s" % s.upscaler)


func test_quality_name_lookup_defaults_to_balanced() -> void:
	check_eq(Quality.from_name("PERFORMANCE"), Quality.Preset.PERFORMANCE)
	check_eq(Quality.from_name("nonsense"), Quality.Preset.BALANCED)


func test_bench_percentile() -> void:
	var v := PackedFloat32Array([5, 1, 4, 2, 3, 6, 7, 8, 9, 10])
	check_near(Bench.percentile(v, 0.5), 5.0)
	check_near(Bench.percentile(v, 0.99), 10.0)
	check_near(Bench.mean(v), 5.5)


func test_all_source_scripts_compile() -> void:
	for path in _scripts("res://src"):
		var s: GDScript = load(path)
		check(s != null and s.can_instantiate(), "compiles: %s" % path)


func _scripts(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	return out
