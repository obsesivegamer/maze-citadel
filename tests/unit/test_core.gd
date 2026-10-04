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
	for key in ["particles", "crowd", "foliage", "leaf_flutter"]:
		check(c[key] >= b[key] and b[key] >= p[key], key)
	for s in [c, b, p]:
		check(Quality.UPSCALERS.has(s.upscaler), "known upscaler %s" % s.upscaler)


func test_quality_fits_driver_and_screen() -> void:
	var b := Quality.settings(Quality.Preset.BALANCED)
	var p := Quality.settings(Quality.Preset.PERFORMANCE)
	var c := Quality.settings(Quality.Preset.CINEMATIC)
	# Every Mac keeps the tuned preset exactly, Retina or not.
	for s in [b, p, c]:
		for h in [0, 1080, 1280, 1440, 1912]:
			check_eq(Quality.for_display(s, "metal", h), s, "Mac unchanged at %d px" % h)
	var pc := Quality.for_display(b, "vulkan", 1080)
	check_eq(pc.upscaler, "fsr2", "FSR 2 replaces MetalFX temporal")
	check_near(pc.render_scale, 720.0 / 1080.0, 1e-4, "1080p keeps 720 px of height")
	check_eq(Quality.for_display(p, "d3d12", 1080).upscaler, "fsr", "FSR 1 replaces spatial")
	check_near(
		Quality.for_display(p, "vulkan", 1080).render_scale, 0.5, 1e-4, "Performance stays fast"
	)
	check_near(
		Quality.for_display(b, "vulkan", 2160).render_scale, 0.5, 1e-4, "4K already has height"
	)
	check_near(
		Quality.for_display(c, "vulkan", 1080).render_scale, 0.7, 1e-4, "never lowers a scale"
	)
	check_near(Quality.for_display(b, "vulkan", 600).render_scale, 1.0, 1e-4, "never above native")
	check_near(Quality.for_display(b, "", 0).render_scale, 0.5, 1e-4, "headless leaves the scale")
	for driver in ["opengl3", "opengl3_angle", "opengl3_es"]:
		var gl := Quality.for_display(b, driver, 1080)
		check_eq(gl.upscaler, "bilinear", "%s upscales bilinearly" % driver)
		check_near(gl.render_scale, 720.0 / 1080.0, 1e-4, "%s keeps the floor" % driver)
	check_eq(b.upscaler, "metalfx_temporal", "the preset itself is not modified")


func test_wheel_zoom_matches_mac_per_notch_and_scales_touchpad_steps() -> void:
	var mb := InputEventMouseButton.new()
	mb.pressed = true
	mb.factor = 1.0
	check_near(CameraRig._wheel_zoom(mb, 0.9, true), 0.9, 1e-4, "Mac: every event zooms")
	check_near(CameraRig._wheel_zoom(mb, 0.9, false), 0.81, 1e-4, "PC notch = Mac press+release")
	mb.factor = 0.25
	check_near(CameraRig._wheel_zoom(mb, 0.9, false), pow(0.81, 0.25), 1e-4, "touchpad step")
	mb.factor = 0.0
	check_near(CameraRig._wheel_zoom(mb, 1.1, false), 1.21, 1e-4, "no factor counts as a notch")
	mb.pressed = false
	check_near(CameraRig._wheel_zoom(mb, 0.9, false), 1.0, 1e-4, "PC release does nothing")


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
