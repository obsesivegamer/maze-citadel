class_name WaveIcons
extends HBoxContainer
## One wave at a glance: creep icons with counts, element and armor-class
## glyphs and a skull for bosses. Used by the next-wave chip and the banner;
## nodes are rebuilt only when the wave changes.

var wave := -1

var _icon_px := 18.0
var _font_size := 13


func _init(icon_px := 18.0, font_size := 13) -> void:
	_icon_px = icon_px
	_font_size = font_size
	add_theme_constant_override("separation", roundi(icon_px * 0.22))
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_wave(w: int) -> void:
	if w == wave:
		return
	wave = w
	for c in get_children():
		remove_child(c)
		c.queue_free()
	if w <= 0:
		return
	for g in TowerInfo.wave_groups(w):
		add_child(UiIcon.new(g[0], _icon_px))
		var count := UiKit.label("×%d" % g[1], &"", _font_size)
		count.add_theme_font_override("font", UiTheme.bold())
		add_child(count)
	add_child(UiKit.divider(_icon_px))
	for e in WaveDefs.elements(w):
		add_child(UiIcon.new(UiGlyphs.element(e), _icon_px))
	for c in TowerInfo.wave_classes(w):
		add_child(UiIcon.new(UiGlyphs.armor(c), _icon_px))
	if WaveDefs.has_boss(w):
		add_child(UiIcon.new(&"skull", _icon_px * 1.15))
