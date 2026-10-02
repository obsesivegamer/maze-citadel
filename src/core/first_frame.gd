class_name FirstFrame
extends Node
## Launch-time probe (PLAN §4.2: first frame under 5 s). Records when the
## first frame is drawn, when frame 60 is drawn and the slowest of the first
## 120 frames (shader compiles show up as hitches), writes JSON and quits.

const FRAMES := 120
## Headless runs never draw; give up rather than hang a scripted slot.
const TIMEOUT_MS := 60000

var out_path := ""

var _frames := 0
var _first_ms := 0
var _frame60_ms := 0
var _worst_ms := 0.0
var _last := 0


func _ready() -> void:
	RenderingServer.frame_post_draw.connect(_on_drawn)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > TIMEOUT_MS and _frames < FRAMES:
		set_process(false)
		_finish()


func _on_drawn() -> void:
	var now := Time.get_ticks_msec()
	_frames += 1
	if _frames == 1:
		_first_ms = now
	elif _frames > 1:
		_worst_ms = maxf(_worst_ms, now - _last)
	if _frames == 60:
		_frame60_ms = now
	_last = now
	if _frames == FRAMES:
		RenderingServer.frame_post_draw.disconnect(_on_drawn)
		_finish()


func _finish() -> void:
	var report := {
		"first_frame_ms": _first_ms,
		"frame60_ms": _frame60_ms,
		"worst_frame_ms_first_120": _worst_ms,
		"frames_drawn": _frames,
		"godot": Engine.get_version_info().string,
	}
	var text := JSON.stringify(report, "  ")
	print(text)
	if out_path != "":
		FileAccess.open(out_path, FileAccess.WRITE).store_string(text + "\n")
	get_tree().quit()
