class_name UiTheme
extends RefCounted
## The HUD look, built in code (GDD §11): dark carved-stone panels with gold
## trim, Cinzel for headings, Fira Sans for body text and numbers. Sizes are
## canvas units: the 1600×1000 base viewport stretches to the window
## (canvas_items), so on the 1470×891-pt Air one unit is about 0.9 pt.

const FONT_DIR := "res://assets/ui/fonts/"

const SIZE_TINY := 11
const SIZE_SMALL := 12
const SIZE_BODY := 14
const SIZE_LARGE := 17
const SIZE_NUMBER := 20
const SIZE_TITLE := 26
const SIZE_BANNER := 46
const SIZE_HUGE := 64

const RADIUS := 6
const TRIM_INSET := 4.0
const SHADOW_SIZE := 8
const PANEL_MARGIN := Vector2(12, 7)

const STONE := Color(0.094, 0.084, 0.074, 0.93)
const STONE_HI := Color(0.165, 0.148, 0.126, 0.97)
const STONE_DEEP := Color(0.05, 0.045, 0.04, 0.96)
const GOLD := Color(0.78, 0.62, 0.32)
const GOLD_BRIGHT := Color(1.0, 0.86, 0.48)
const GOLD_DIM := Color(0.44, 0.35, 0.19)
const TEXT := Color(0.95, 0.91, 0.82)
const TEXT_DIM := Color(0.67, 0.63, 0.55)
const GOOD := Color(0.55, 0.92, 0.45)
const BAD := Color(0.97, 0.4, 0.3)
const SHADOW := Color(0, 0, 0, 0.6)
const FUSE := Color(0.55, 0.88, 1.0)

const ELEMENT_COLORS := {
	&"light": Color(1.0, 0.93, 0.64),
	&"dark": Color(0.72, 0.5, 0.98),
	&"aqua": Color(0.38, 0.74, 1.0),
	&"flame": Color(1.0, 0.52, 0.22),
	&"verdant": Color(0.5, 0.88, 0.35),
	&"stone": Color(0.78, 0.68, 0.54),
}
const CLASS_COLORS := {
	&"light": Color(0.88, 0.8, 0.62),
	&"armored": Color(0.72, 0.78, 0.86),
	&"air": Color(0.62, 0.87, 1.0),
	&"boss": Color(0.97, 0.36, 0.28),
}
const ATTACK_COLORS := {
	&"pierce": Color(0.55, 0.74, 1.0),
	&"siege": Color(1.0, 0.5, 0.3),
	&"magic": Color(0.48, 0.96, 0.86),
	&"poison": Color(0.68, 0.96, 0.38),
	&"rune": Color(0.96, 0.8, 0.42),
}
const FAMILY_COLORS := {
	&"alliance": Color(0.48, 0.67, 1.0),
	&"horde": Color(1.0, 0.45, 0.28),
	&"elven": Color(0.42, 0.94, 0.78),
	&"forsaken": Color(0.74, 0.5, 0.96),
	&"support": Color(1.0, 0.84, 0.42),
}

## --pf-hud-lite: no text shadows, panel shadows or trim, to price them on
## the target Mac. A visible change, so off in the shipped look.
static var lite := PerfFlags.get_bool("hud-lite", false)
static var _theme: Theme
static var _fonts := {}


static func heading(weight := 700) -> Font:
	return _font("Cinzel-Variable.ttf", weight, false)


static func body() -> Font:
	return _font("FiraSans-Medium.ttf", 0, true)


static func bold() -> Font:
	return _font("FiraSans-Bold.ttf", 0, true)


## Fonts are FontVariations so headings can pick a weight on Cinzel's axis and
## numbers can use tabular figures (gold doesn't jitter as it counts).
static func _font(file: String, weight: int, tabular: bool) -> Font:
	var key := "%s:%d" % [file, weight]
	if _fonts.has(key):
		return _fonts[key]
	var ts := TextServerManager.get_primary_interface()
	var f := FontVariation.new()
	f.base_font = load(FONT_DIR + file)
	if weight > 0:
		f.variation_opentype = {ts.name_to_tag("wght"): weight}
	if tabular:
		f.opentype_features = {ts.name_to_tag("tnum"): 1}
	_fonts[key] = f
	if file.begins_with("Cinzel"):
		var fallback: Array[Font] = [body()]
		f.fallbacks = fallback
	return f


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body()
	t.default_font_size = SIZE_BODY
	_labels(t)
	_panels(t)
	_buttons(t)
	_slider(t)
	_theme = t
	return t


static func _labels(t: Theme) -> void:
	# A transparent shadow makes Label and RichTextLabel skip both shadow passes.
	var shadow := Color(SHADOW, 0.0) if lite else SHADOW
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", shadow)
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_constant("shadow_outline_size", "Label", 3)
	_label_variant(t, &"Heading", heading(700), SIZE_LARGE, GOLD_BRIGHT)
	_label_variant(t, &"Title", heading(800), SIZE_TITLE, GOLD_BRIGHT)
	_label_variant(t, &"Caption", heading(700), SIZE_TINY, GOLD)
	_label_variant(t, &"Number", bold(), SIZE_NUMBER, TEXT)
	_label_variant(t, &"Dim", body(), SIZE_SMALL, TEXT_DIM)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("font_shadow_color", "RichTextLabel", shadow)
	t.set_constant("shadow_offset_x", "RichTextLabel", 1)
	t.set_constant("shadow_offset_y", "RichTextLabel", 1)
	t.set_font("bold_font", "RichTextLabel", bold())
	t.set_font_size("normal_font_size", "RichTextLabel", SIZE_SMALL)
	t.set_font_size("bold_font_size", "RichTextLabel", SIZE_SMALL)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", SIZE_SMALL)


static func _label_variant(t: Theme, n: StringName, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(n, &"Label")
	t.set_font("font", n, font)
	t.set_font_size("font_size", n, size)
	t.set_color("font_color", n, color)


static func _panels(t: Theme) -> void:
	var stone := panel_box()
	t.set_stylebox("panel", "PanelContainer", stone)
	t.set_stylebox("panel", "Panel", stone)
	t.set_stylebox("panel", "TooltipPanel", tooltip_box())
	t.set_type_variation(&"Chip", &"PanelContainer")
	t.set_stylebox("panel", &"Chip", chip_box(GOLD_DIM))
	t.set_type_variation(&"TipPanel", &"PanelContainer")
	t.set_stylebox("panel", &"TipPanel", tooltip_box())
	t.set_type_variation(&"Plaque", &"PanelContainer")
	var plaque := panel_box()
	plaque.set_content_margin_all(10)
	t.set_stylebox("panel", &"Plaque", plaque)


static func _buttons(t: Theme) -> void:
	var normal := box(STONE_HI, GOLD_DIM, 1, 5, Vector2(10, 5), 0)
	var hover := box(STONE_HI.lightened(0.08), GOLD, 1, 5, Vector2(10, 5), 0)
	var pressed := box(STONE_DEEP, GOLD_BRIGHT, 2, 5, Vector2(10, 5), 0)
	var disabled := box(STONE, Color(GOLD_DIM, 0.5), 1, 5, Vector2(10, 5), 0)
	for type in [&"Button", &"IconButton", &"Segment"]:
		if type != &"Button":
			t.set_type_variation(type, &"Button")
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, GOLD_BRIGHT)
		t.set_color("font_pressed_color", type, GOLD_BRIGHT)
		t.set_color("font_hover_pressed_color", type, GOLD_BRIGHT)
		t.set_color("font_disabled_color", type, Color(TEXT_DIM, 0.6))
		t.set_color("font_focus_color", type, TEXT)
	var flat := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 5, Vector2(5, 4), 0)
	# Fully transparent anyway; without a centre StyleBoxFlat skips the draw call.
	flat.draw_center = false
	t.set_stylebox("normal", &"IconButton", flat)
	var icon_hover := box(Color(1, 1, 1, 0.06), GOLD, 1, 5, Vector2(5, 4), 0)
	t.set_stylebox("hover", &"IconButton", icon_hover)
	for type in [&"IconButton", &"Segment"]:
		t.set_stylebox("pressed", type, box(Color(GOLD, 0.22), GOLD_BRIGHT, 1, 5, Vector2(5, 4), 0))
		t.set_stylebox("hover_pressed", type, t.get_stylebox("pressed", type))
	t.set_font("font", &"Segment", bold())
	t.set_font_size("font_size", &"Segment", SIZE_BODY)
	t.set_stylebox("normal", &"Segment", box(STONE_DEEP, GOLD_DIM, 1, 5, Vector2(8, 3), 0))
	t.set_stylebox("disabled", &"IconButton", flat)


static func _slider(t: Theme) -> void:
	var track := box(STONE_DEEP, GOLD_DIM, 1, 4, Vector2(0, 3), 0)
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(Color(GOLD, 0.55), Color(0, 0, 0, 0), 0, 4, Vector2(0, 3), 0)
	t.set_stylebox("grabber_area", "HSlider", fill)
	var fill_hi := box(Color(GOLD_BRIGHT, 0.7), Color(0, 0, 0, 0), 0, 4, Vector2(0, 3), 0)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_hi)
	t.set_icon("grabber", "HSlider", _knob(GOLD))
	t.set_icon("grabber_highlight", "HSlider", _knob(GOLD_BRIGHT))
	t.set_icon("grabber_disabled", "HSlider", _knob(GOLD_DIM))


## A round slider knob, rendered once into a small texture.
static func _knob(color: Color) -> Texture2D:
	const PX := 18
	var img := Image.create_empty(PX, PX, false, Image.FORMAT_RGBA8)
	var c := Vector2(PX, PX) / 2.0
	for y in PX:
		for x in PX:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(PX / 2.0 - d, 0.0, 1.0)
			var rim := clampf(d - (PX / 2.0 - 2.5), 0.0, 1.0)
			img.set_pixel(x, y, Color(color.lerp(STONE_DEEP, rim * 0.8), a))
	return ImageTexture.create_from_image(img)


static func box(
	bg: Color,
	border: Color,
	border_width := 2,
	radius := RADIUS,
	margin := PANEL_MARGIN,
	shadow := SHADOW_SIZE,
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.corner_detail = 6
	s.anti_aliasing = true
	s.content_margin_left = margin.x
	s.content_margin_right = margin.x
	s.content_margin_top = margin.y
	s.content_margin_bottom = margin.y
	s.shadow_size = 0 if lite else shadow
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_offset = Vector2(0, 2)
	return s


static func panel_box() -> StyleBoxFlat:
	return box(STONE, GOLD, 2)


static func chip_box(border: Color) -> StyleBoxFlat:
	return box(STONE_DEEP, border, 1, 10, Vector2(9, 3), 0)


static func tooltip_box() -> StyleBoxFlat:
	var s := box(Color(0.07, 0.063, 0.055, 0.97), GOLD, 2, RADIUS, Vector2(12, 10), 10)
	return s


## Inner hairline and corner studs drawn over a panel's stylebox, for the
## carved-frame look StyleBoxFlat can't do on its own.
static func add_trim(c: Control) -> void:
	if lite:
		return
	c.draw.connect(func() -> void: draw_trim(c))


## One draw call. Not cached: panels resize as their text changes, and the
## trim is cheap to build.
static func draw_trim(c: Control) -> void:
	var size := c.size
	var r := Rect2(Vector2.ZERO, size).grow(-TRIM_INSET)
	if r.size.x < 12.0 or r.size.y < 12.0:
		return
	var mesh := UiMesh.new()
	mesh.draw_rect(r, Color(GOLD_DIM, 0.55), false, 1.0, true)
	mesh.draw_line(
		Vector2(RADIUS + 2.0, 2.5), Vector2(size.x - RADIUS - 2.0, 2.5), Color(1, 1, 1, 0.07), 1.0
	)
	for corner in [
		r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)
	]:
		UiGlyphs.diamond(mesh, corner, 2.6, GOLD)
	mesh.submit(c)


static func element_color(element: StringName) -> Color:
	return ELEMENT_COLORS.get(element, TEXT)


static func hex(c: Color) -> String:
	return c.to_html(false)
