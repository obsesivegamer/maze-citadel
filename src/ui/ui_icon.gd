class_name UiIcon
extends Control
## One procedural glyph (UiGlyphs) scaled to fit the control. Godot caches
## the draw commands, so it costs nothing per frame until glyph or tint change;
## the glyph's shapes go out as a single draw call (UiMesh).

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
	var r := Rect2((size - Vector2(s, s)) / 2.0, Vector2(s, s))
	UiMesh.cached([&"icon", glyph, r, tint], _build.bind(r)).submit(self)


func _build(mesh: UiMesh, r: Rect2) -> void:
	UiGlyphs.draw(mesh, glyph, r, tint)
