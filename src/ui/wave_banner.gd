class_name WaveBanner
extends Control
## The pre-wave announcement (GDD §3): 3 s before a wave spawns, a band across
## the top with the wave number, creep icons and counts, element, armor class,
## a skull for bosses, and the wave's twist (Twists mode) and Bulky shape
## (eletd) on lines of their own. Also shows a short "wave cleared" note, and
## under eletd the Guardian and element-level notices.

## Sits below the portal (fraction of screen height) so spawning creeps stay
## visible, as a centred plate rather than a full-width band.
const TOP_FRACTION := 0.3
const WIDTH := 860.0
const HEIGHT := 112.0
const BAND_ALPHA := 0.5
const FADE_IN := 0.25
const HOLD := 3.0
const CLEARED_HOLD := 1.4
const FADE_OUT := 0.7
const SLIDE := 14.0
const ICON_PX := 30.0
## Extra band height per twist or Bulky line.
const TWIST_HEIGHT := 28.0
## Height and hold of a small notice (an element level gained).
const NOTICE_HEIGHT := 80.0
const NOTICE_HOLD := 2.2

var _title := UiKit.label("", &"Title", UiTheme.SIZE_BANNER)
var _skull_l := UiIcon.new(&"skull", 38.0)
var _skull_r := UiIcon.new(&"skull", 38.0)
var _icons := WaveIcons.new(ICON_PX, 18)
var _detail := UiKit.rich(UiTheme.SIZE_BODY)
var _twist := UiKit.rich(UiTheme.SIZE_BODY)
var _tween: Tween


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_left = -WIDTH / 2.0
	offset_right = WIDTH / 2.0
	offset_bottom = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var box := UiKit.vbox(2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	_icons.tags = false
	var row := UiKit.hbox(14)
	row.add_child(_skull_l)
	_title.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02))
	_title.add_theme_constant_override("outline_size", 10)
	row.add_child(_title)
	row.add_child(_skull_r)
	box.add_child(row)
	box.add_child(_icons)
	_detail.fit_content = true
	_detail.autowrap_mode = TextServer.AUTOWRAP_OFF
	_detail.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_detail)
	_twist.fit_content = true
	_twist.autowrap_mode = TextServer.AUTOWRAP_OFF
	_twist.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_twist.visible = false
	box.add_child(_twist)


func announce(wave: int, twist: StringName = &"", rules: StringName = &"classic") -> void:
	var boss := WaveDefs.has_boss(wave)
	_unnotice()
	_title.text = "Wave %d" % wave
	_title.add_theme_color_override("font_color", UiTheme.BAD if boss else UiTheme.GOLD_BRIGHT)
	_skull_l.visible = boss
	_skull_r.visible = boss
	_icons.visible = true
	_icons.show_wave(wave, &"", rules)
	var parts := PackedStringArray()
	for e in WaveDefs.elements(wave, rules):
		var c := UiTheme.element_color(e)
		parts.append("[color=#%s]%s[/color]" % [UiTheme.hex(c), TowerInfo.ELEMENT_NAMES[e]])
	var classes := PackedStringArray()
	for c in TowerInfo.wave_classes(wave):
		classes.append(TowerInfo.CLASS_NAMES[c])
	var text := " + ".join(parts) + "   ·   " + "/".join(classes) + " armor"
	if boss:
		text += "   ·   [color=#%s]BOSS — leaks cost 2 lives[/color]" % UiTheme.hex(UiTheme.BAD)
	_detail.text = "[center]%s[/center]" % text
	_detail.visible = true
	var lines := PackedStringArray()
	if twist != &"":
		lines.append(
			(
				"[color=#%s]Twist: [b]%s[/b]. %s[/color]"
				% [
					UiTheme.hex(UiGlyphs.TWIST),
					WaveTwists.display_name(twist),
					WaveTwists.text(twist)
				]
			)
		)
	if WaveDefs.bulky(wave, rules):
		lines.append(
			(
				"[color=#%s][b]Bulky[/b]. %s[/color]"
				% [UiTheme.hex(UiGlyphs.BULKY), TowerInfo.bulky_text()]
			)
		)
	_twist.visible = not lines.is_empty()
	_twist.text = "[center]%s[/center]" % "\n".join(lines)
	size = Vector2(WIDTH, HEIGHT + TWIST_HEIGHT * lines.size())
	_play(HOLD)


## A short notice in the banner's place (eletd's Guardians and element
## levels): the title in the element's colour between two of its glyphs and
## a line under it. `small` makes it a smaller, shorter one.
func notice(title: String, detail: String, element: StringName, small := false) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", UiTheme.element_color(element))
	_title.add_theme_font_size_override(
		"font_size", UiTheme.SIZE_TITLE if small else UiTheme.SIZE_BANNER
	)
	for s in [_skull_l, _skull_r]:
		s.glyph = UiGlyphs.element(element)
		s.visible = true
	_icons.visible = false
	_detail.text = "[center]%s[/center]" % detail
	_detail.visible = true
	_twist.visible = false
	size = Vector2(WIDTH, NOTICE_HEIGHT if small else HEIGHT)
	_play(NOTICE_HOLD if small else HOLD)


## Back to the wave look after a notice.
func _unnotice() -> void:
	_title.add_theme_font_size_override("font_size", UiTheme.SIZE_BANNER)
	_skull_l.glyph = &"skull"
	_skull_r.glyph = &"skull"


func cleared(wave: int) -> void:
	_unnotice()
	_title.text = "Wave %d cleared" % wave
	_title.add_theme_color_override("font_color", UiTheme.GOOD)
	_skull_l.visible = false
	_skull_r.visible = false
	_icons.visible = false
	_detail.visible = false
	_twist.visible = false
	size = Vector2(WIDTH, HEIGHT)
	_play(CLEARED_HOLD)


func _play(hold: float) -> void:
	if _tween != null:
		_tween.kill()
	visible = true
	modulate.a = 0.0
	var top := get_viewport_rect().size.y * TOP_FRACTION
	position.y = top - SLIDE
	queue_redraw()
	_tween = create_tween()
	_tween.set_parallel()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tween.tween_property(self, "position:y", top, FADE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.chain().tween_interval(hold - FADE_IN)
	_tween.chain().tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.chain().tween_callback(hide)


## A dark band that fades out toward the screen edges, with gold hairlines,
## as one draw call.
func _draw() -> void:
	UiMesh.cached([&"banner_band", size], _build_band.bind(size)).submit(self)


static func _build_band(mesh: UiMesh, size: Vector2) -> void:
	var w := size.x
	var h := size.y
	var clear := Color(0, 0, 0, 0)
	var dark := Color(0.03, 0.025, 0.02, BAND_ALPHA)
	var mid := w / 2.0
	var edge := w * 0.18
	for side in [-1.0, 1.0]:
		var outer: float = mid + side * (mid - edge * 0.2)
		var inner: float = mid + side * edge
		var core := PackedVector2Array(
			[Vector2(mid, 0), Vector2(inner, 0), Vector2(inner, h), Vector2(mid, h)]
		)
		mesh.draw_polygon(core, PackedColorArray([dark, dark, dark, dark]))
		var fade := PackedVector2Array(
			[Vector2(inner, 0), Vector2(outer, 0), Vector2(outer, h), Vector2(inner, h)]
		)
		mesh.draw_polygon(fade, PackedColorArray([dark, clear, clear, dark]))
		var line_colors := PackedColorArray([UiTheme.GOLD, UiTheme.GOLD, Color(UiTheme.GOLD, 0.0)])
		for y in [1.0, h - 1.0]:
			mesh.draw_polyline_colors(
				PackedVector2Array([Vector2(mid, y), Vector2(inner, y), Vector2(outer, y)]),
				line_colors,
				1.5,
				true
			)
