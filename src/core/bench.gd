class_name Bench
extends Node
## Records frame pacing for a fixed window after a warm-up, writes a JSON
## report and quits. Run with vsync disabled to measure headroom.

var duration := 20.0
var warmup := 4.0
var out_path := ""
var label := ""
## Seconds per entry in the report's timeline, to spot thermal throttling.
var window := 30.0
## The quality values the run used, overrides included, echoed in the report.
var settings := {}
var max_wait_for_focus := 30.0

var _elapsed := 0.0
var _unfocused := 0.0
var _frame_ms := PackedFloat32Array()
var _cpu_ms := PackedFloat32Array()
var _timeline: Array[float] = []
var _window_start := 0
var _window_ms := 0.0
var _draw_calls := 0.0
var _primitives := 0.0


func _ready() -> void:
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func _process(delta: float) -> void:
	# macOS throttles windows that aren't frontmost, which makes numbers
	# meaningless. Only measure while focused; restart the window on focus loss.
	if not DisplayServer.window_is_focused():
		_unfocused += delta
		_elapsed = 0.0
		_frame_ms.clear()
		_cpu_ms.clear()
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
	}
	var text := JSON.stringify(report, "  ")
	print(text)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(text + "\n")
	get_tree().quit()
