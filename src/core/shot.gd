class_name Shot
extends Node
## Renders a list of named views and saves one PNG per view, then quits.
## `set_view` is called with each view name; frames are given time to settle
## (temporal upscaling, SDFGI and fog all converge over several frames).

var views: PackedStringArray = []
var prefix := ""
var settle_frames := 90
var set_view: Callable

var _index := -1
var _frames := 0


func _process(_delta: float) -> void:
	if _index == -1:
		_next()
		return
	_frames += 1
	if _frames < settle_frames:
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	var path := "%s-%s.png" % [prefix, views[_index]]
	get_viewport().get_texture().get_image().save_png(path)
	print("shot: ", path)
	_next()
	set_process(true)


func _next() -> void:
	_index += 1
	_frames = 0
	if _index >= views.size():
		get_tree().quit()
		return
	set_view.call(views[_index])
