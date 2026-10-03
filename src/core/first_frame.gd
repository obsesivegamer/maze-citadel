class_name FirstFrame
extends Node
## Launch-time probe (PLAN §4.2: first frame under 5 s; no stalls when play
## starts). Records when the first frame is drawn (the loading screen), when
## the game is booted and playable, then starts wave 1 itself and records the
## slowest frames of the next WAVE_FRAMES frames: first-use shader compiles
## show up there as hitches. Writes JSON and quits.

const WAVE_FRAMES := 600
const HITCH_MS := 50.0
## Headless runs never draw; give up rather than hang a scripted slot.
const TIMEOUT_MS := 120000

var out_path := ""
var game: Game

var _frames := 0
var _first_ms := 0
var _boot_ms := 0
var _wave_frames := 0
var _worst_ms := 0.0
var _hitches := 0
var _last := 0


func _ready() -> void:
	RenderingServer.frame_post_draw.connect(_on_drawn)
	if game != null:
		game.booted.connect(_on_booted)


func _on_booted() -> void:
	_boot_ms = Time.get_ticks_msec()
	game.call_next_wave()


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > TIMEOUT_MS:
		set_process(false)
		_finish()


func _on_drawn() -> void:
	var now := Time.get_ticks_msec()
	_frames += 1
	if _frames == 1:
		_first_ms = now
	if _boot_ms > 0:
		if _wave_frames > 0:
			var dt := float(now - _last)
			_worst_ms = maxf(_worst_ms, dt)
			_hitches += 1 if dt > HITCH_MS else 0
		_wave_frames += 1
		if _wave_frames > WAVE_FRAMES:
			RenderingServer.frame_post_draw.disconnect(_on_drawn)
			_finish()
	_last = now


func _finish() -> void:
	var report := {
		"first_frame_ms": _first_ms,
		"boot_ms": _boot_ms,
		"wave1_frames": _wave_frames,
		"wave1_worst_frame_ms": _worst_ms,
		"wave1_hitches_over_50ms": _hitches,
		"frames_drawn": _frames,
		"async_boot": game != null and game.async_boot,
		"godot": Engine.get_version_info().string,
	}
	var text := JSON.stringify(report, "  ")
	print(text)
	if out_path != "":
		FileAccess.open(out_path, FileAccess.WRITE).store_string(text + "\n")
	get_tree().quit()
