class_name UiIcon
extends Control
## One procedural glyph (UiGlyphs) scaled to fit the control. Godot caches
## the draw commands, so it costs nothing per frame until glyph or tint change.

var glyph: StringName = &"":
	set = set_glyph
var tint := Color.WHITE:
	set = set_tint


func _init(id: StringName = &"", px := 20.0, color := Color.WHITE) -> void:
	glyph = id
	tint = color
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_glyph(value: StringName) -> void:
	if value != glyph:
		glyph = value
		queue_redraw()


func set_tint(value: Color) -> void:
	if value != tint:
		tint = value
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	UiGlyphs.draw(self, glyph, Rect2((size - Vector2(s, s)) / 2.0, Vector2(s, s)), tint)
