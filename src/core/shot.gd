class_name Shot
extends Node
## Renders a list of named views and saves one PNG per view, then quits.
## `set_view` is called with each view name; frames are given time to settle
## (temporal upscaling, SDFGI and fog all converge over several frames).
## With `frames` > 1 it saves that many consecutive frames per view
## (`<prefix>-<view>-000.png`, ...) for tests/perf/flicker.gd. `freeze` stops
## game time before them (Engine.time_scale 0 also stops shader TIME), so only
## the renderer can change the picture from one frame to the next.

var views: PackedStringArray = []
var prefix := ""
var settle_frames := 90
var frames := 1
var freeze := false
var set_view: Callable

var _index := -1
var _frames := 0
var _saved := 0


func _process(_delta: float) -> void:
	if _index == -1:
		_next()
		return
	_frames += 1
	if _frames < settle_frames:
		return
	if freeze and _frames == settle_frames:
		Engine.time_scale = 0.0
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	var path := "%s-%s.png" % [prefix, views[_index]]
	if frames > 1:
		path = "%s-%s-%03d.png" % [prefix, views[_index], _saved]
	get_viewport().get_texture().get_image().save_png(path)
	_saved += 1
	if _saved >= frames:
		print("shot: ", path)
		_next()
	set_process(true)


func _next() -> void:
	_index += 1
	_frames = 0
	_saved = 0
	Engine.time_scale = 1.0
	if _index >= views.size():
		get_tree().quit()
		return
	set_view.call(views[_index])
