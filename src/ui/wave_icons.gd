class_name WaveIcons
extends HBoxContainer
## One wave at a glance: creep icons with counts, element and armor-class
## glyphs, a skull for bosses, the wave's twist (Twists mode) and a Bulky tag
## (eletd). Used by the next-wave chip and the banner; nodes are rebuilt only
## when the wave or its twist changes.

var wave := -1
var twist: StringName = &""
var rules: StringName = &"classic"
## Twist and Bulky tags after the glyphs; the banner gives them lines instead.
var tags := true

var _icon_px := 18.0
var _font_size := 13


func _init(icon_px := 18.0, font_size := 13) -> void:
	_icon_px = icon_px
	_font_size = font_size
	add_theme_constant_override("separation", roundi(icon_px * 0.22))
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_wave(w: int, w_twist: StringName = &"", w_rules: StringName = &"classic") -> void:
	if w == wave and w_twist == twist and w_rules == rules:
		return
	wave = w
	twist = w_twist
	rules = w_rules
	for c in get_children():
		remove_child(c)
		c.queue_free()
	if w <= 0:
		return
	for g in TowerInfo.wave_groups(w, rules):
		add_child(UiIcon.new(g[0], _icon_px))
		var count := UiKit.label("×%d" % g[1], &"", _font_size)
		count.add_theme_font_override("font", UiTheme.bold())
		add_child(count)
	add_child(UiKit.divider(_icon_px))
	for e in WaveDefs.elements(w, rules):
		add_child(UiIcon.new(UiGlyphs.element(e), _icon_px))
	for c in TowerInfo.wave_classes(w):
		add_child(UiIcon.new(UiGlyphs.armor(c), _icon_px))
	if WaveDefs.has_boss(w):
		add_child(UiIcon.new(&"skull", _icon_px * 1.15))
	if not tags:
		return
	if twist != &"":
		_tag(&"twist", WaveTwists.display_name(twist), UiGlyphs.TWIST)
	if WaveDefs.bulky(w, rules):
		_tag(&"bulky", "Bulky", UiGlyphs.BULKY)


func _tag(glyph: StringName, text: String, color: Color) -> void:
	add_child(UiKit.divider(_icon_px))
	add_child(UiIcon.new(glyph, _icon_px))
	var label := UiKit.label(text, &"", _font_size)
	label.add_theme_font_override("font", UiTheme.bold())
	label.add_theme_color_override("font_color", color)
	add_child(label)
