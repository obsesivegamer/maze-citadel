class_name CounselView
extends VBoxContainer
## One wave's counter advice (Counsel) as a panel body: the wave's creeps at a
## glance, a line per element and per armor class, notes on its creeps, and
## chips for the towers that hit it hardest. Clicking a chip picks that tower
## for building. Shared by the tutorial's counsel card and the Field Guide.

signal picked(id: StringName)

const ICON_PX := 18.0
const CHIP_ICON_PX := 22.0

var wave := 0

var _game: Game
## Notes only for creeps appearing for the first time (the tutorial's pace).
var _first_notes := false
var _twist: StringName = &""
var _icons := WaveIcons.new(ICON_PX, 13)
var _lines: RichTextLabel
var _caption := UiKit.label("BUILD", &"Caption")
var _picks := HFlowContainer.new()


func _init(game: Game, width: float, first_notes := false) -> void:
	_game = game
	_first_notes = first_notes
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_icons)
	_lines = UiKit.rich(UiTheme.SIZE_SMALL, width)
	add_child(_lines)
	add_child(_caption)
	_picks.add_theme_constant_override("h_separation", 6)
	_picks.add_theme_constant_override("v_separation", 6)
	_picks.custom_minimum_size.x = width
	_picks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picks)


## Shows wave `w` (0 hides everything); rebuilt only when the wave or its
## twist changes.
func show_wave(w: int, twist: StringName = &"") -> void:
	if w == wave and twist == _twist:
		return
	wave = w
	_twist = twist
	for c in _picks.get_children():
		_picks.remove_child(c)
		c.queue_free()
	_icons.show_wave(w, twist)
	_caption.visible = w > 0
	if w <= 0:
		_lines.text = ""
		return
	var parts := PackedStringArray()
	parts.append_array(Counsel.element_lines(w))
	parts.append_array(Counsel.armor_lines(w))
	if twist != &"":
		parts.append(
			(
				"[color=#%s]Twist: [b]%s[/b]. %s[/color]"
				% [
					UiTheme.hex(UiGlyphs.TWIST),
					WaveTwists.display_name(twist),
					WaveTwists.text(twist)
				]
			)
		)
	for note in Counsel.creep_notes(w, _first_notes):
		parts.append("[color=#%s]%s[/color]" % [UiTheme.hex(UiTheme.TEXT_DIM), note])
	_lines.text = "\n".join(parts)
	for p in Counsel.picks(w):
		_picks.add_child(_chip(p))


## Towers the chips name, best first.
func picks() -> Array[StringName]:
	var out: Array[StringName] = []
	if wave > 0:
		out = Counsel.best_towers(wave)
	return out


## Icon, name, hotkey and multiplier over an invisible full-size button.
func _chip(p: Dictionary) -> Control:
	var id: StringName = p.id
	var chip := UiKit.panel(&"Chip", false)
	var row := UiKit.hbox(5)
	row.add_child(UiIcon.new(id, CHIP_ICON_PX))
	row.add_child(UiKit.label(TowerDefs.hotkey(id), &"Caption"))
	row.add_child(UiKit.label(TowerInfo.short_name(id), &"", UiTheme.SIZE_SMALL))
	var pct := UiKit.label(Counsel.pct(p.mult, false), &"", UiTheme.SIZE_SMALL)
	pct.add_theme_font_override("font", UiTheme.bold())
	var good: bool = p.mult > 1.0
	pct.add_theme_color_override("font_color", UiTheme.GOOD if good else UiTheme.TEXT_DIM)
	row.add_child(pct)
	if p.vs != "":
		row.add_child(UiKit.label("vs " + p.vs, &"Dim", UiTheme.SIZE_TINY))
	chip.add_child(row)
	var hit := Button.new()
	hit.theme_type_variation = &"IconButton"
	hit.focus_mode = Control.FOCUS_NONE
	hit.tooltip_text = (
		"Build %s (%s)\n%s"
		% [
			TowerInfo.full_name(id),
			TowerDefs.hotkey(id),
			Counsel.plain(Counsel.tower_vs_wave(id, wave))
		]
	)
	hit.pressed.connect(_pick.bind(id))
	UiKit.wire(_game, hit)
	chip.add_child(hit)
	return chip


func _pick(id: StringName) -> void:
	_game.choose_build(id)
	picked.emit(id)
