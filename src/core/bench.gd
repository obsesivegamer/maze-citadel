class_name Bench
extends Node
## Records frame pacing for a fixed window after a warm-up, writes a JSON
## report and quits. Run with vsync disabled to measure headroom.

var duration := 20.0
var warmup := 4.0
var out_path := ""
var label := ""
## Keep vsync on and count frames that miss the display's refresh: what a
## player feels, rather than uncapped headroom.
var pacing := false
## Seconds per entry in the report's timeline, to spot thermal throttling.
var window := 30.0
## The quality values the run used, overrides included, echoed in the report.
var settings := {}
var max_wait_for_focus := 30.0

var _elapsed := 0.0
var _unfocused := 0.0
var _frame_ms := PackedFloat32Array()
var _cpu_ms := PackedFloat32Array()
var _prof := {}
var _missed := 0
var _worst_ms := 0.0
var _timeline: Array[float] = []
var _window_start := 0
var _window_ms := 0.0
var _draw_calls := 0.0
var _primitives := 0.0


func _ready() -> void:
	DisplayServer.window_move_to_foreground()
	if not pacing:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Prof.enabled = true
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func _process(delta: float) -> void:
	# macOS throttles windows that aren't frontmost, which makes numbers
	# meaningless. Only measure while focused; restart the window on focus loss.
	if not DisplayServer.window_is_focused():
		_unfocused += delta
		_elapsed = 0.0
		_frame_ms.clear()
		_cpu_ms.clear()
		_prof.clear()
		_missed = 0
		_worst_ms = 0.0
		Prof.take()
		_timeline.clear()
		_window_start = 0
		_window_ms = 0.0
		if _unfocused > max_wait_for_focus:
			_finish()
			set_process(false)
		return
	_elapsed += delta
	if _elapsed < warmup:
		return
	var vp := get_viewport().get_viewport_rid()
	_frame_ms.append(delta * 1000.0)
	_worst_ms = maxf(_worst_ms, delta * 1000.0)
	if delta * 1000.0 > _refresh_ms() * 1.25:
		_missed += 1
	var sections := Prof.take()
	for k in sections:
		_prof[k] = _prof.get(k, 0.0) + sections[k]
	_window_ms += delta * 1000.0
	if _window_ms >= window * 1000.0:
		var frames := _frame_ms.size() - _window_start
		_timeline.append(snappedf(frames * 1000.0 / _window_ms, 0.1))
		_window_start = _frame_ms.size()
		_window_ms = 0.0
	_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
	_draw_calls = max(
		_draw_calls, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	)
	_primitives = max(
		_primitives, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	)
	if _elapsed >= warmup + duration:
		_finish()
		set_process(false)


func _refresh_ms() -> float:
	var hz := DisplayServer.screen_get_refresh_rate()
	return 1000.0 / (hz if hz > 1.0 else 60.0)


func _per_frame(totals: Dictionary) -> Dictionary:
	var out := {}
	var n := maxf(_frame_ms.size(), 1)
	var sum := 0.0
	for k in totals:
		out[k] = snappedf(totals[k] / n, 0.01)
		sum += totals[k] / n
	out["total"] = snappedf(sum, 0.01)
	return out


static func percentile(values: PackedFloat32Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(ceil(p * sorted.size())) - 1, 0, sorted.size() - 1)]


static func mean(values: PackedFloat32Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / max(values.size(), 1)


## The engine's values for every setting in the project's override.cfg (the
## perf matrix writes one for startup-only settings), so a report shows the
## override took effect.
static func override_settings(path := "res://override.cfg") -> Dictionary:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(path) or cfg.load(path) != OK:
		return {}
	var out := {}
	for section in cfg.get_sections():
		for key in cfg.get_section_keys(section):
			var setting := section + "/" + key
			out[setting] = ProjectSettings.get_setting(setting)
	return out


func _finish() -> void:
	var avg := mean(_frame_ms)
	var vp := get_viewport()
	var report := {
		"label": label,
		"frames": _frame_ms.size(),
		"seconds": duration,
		"avg_fps": snappedf(1000.0 / avg, 0.1) if avg > 0 else 0.0,
		"low_1pct_fps": snappedf(1000.0 / max(percentile(_frame_ms, 0.99), 0.001), 0.1),
		"avg_frame_ms": snappedf(avg, 0.01),
		"avg_cpu_ms": snappedf(mean(_cpu_ms), 0.01),
		"timeline_fps": _timeline,
		"pacing": pacing,
		"refresh_hz": DisplayServer.screen_get_refresh_rate(),
		"missed_frames": _missed,
		"missed_pct": snappedf(100.0 * _missed / maxf(_frame_ms.size(), 1), 0.01),
		"worst_frame_ms": snappedf(_worst_ms, 0.1),
		"cpu_ms_per_frame": _per_frame(_prof),
		"flags": PerfFlags.active(),
		"max_draw_calls": _draw_calls,
		"max_primitives": _primitives,
		"video_mem_mb":
		snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1e6, 1),
		"window_px": str(DisplayServer.window_get_size()),
		"render_scale": vp.scaling_3d_scale,
		"scaling_mode": vp.scaling_3d_mode,
		"adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"hdr_supported": DisplayServer.window_is_hdr_output_supported(),
		"focused": not _frame_ms.is_empty(),
		"seconds_waiting_for_focus": snappedf(_unfocused, 0.1),
		"hdr_max_nits": DisplayServer.window_get_hdr_output_max_luminance(),
		"godot": Engine.get_version_info().string,
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"settings": settings,
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"project_overrides": override_settings(),
	}
	var text := JSON.stringify(report, "  ")
	print(text)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(text + "\n")
	get_tree().quit()
