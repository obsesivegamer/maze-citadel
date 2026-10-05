class_name SettingsPanel
extends Control
## Settings (GDD §13–§15): quality preset, master/music/effects/ambience
## volume, camera shake, edge pan, the tutorial and the playtest records.
## Every change is saved at once through game.set_quality,
## game.audio.set_volume or Save.set_setting.

## A toggle changed (key from TOGGLES, HELP_TOGGLES or RECORD_TOGGLES).
signal setting_changed(key: String, on: bool)

const PANEL_WIDTH := 400.0
const SLIDER_WIDTH := 190.0
const LABEL_WIDTH := 92.0
const DIM := Color(0, 0, 0, 0.35)
const VOLUMES := [
	[&"Master", "Master"], [&"Music", "Music"], [&"SFX", "Effects"], [&"Ambience", "Ambience"]
]
const TOGGLES := [
	["camera_shake", "Camera shake", "Shake on big impacts and leaks"],
	["edge_pan", "Edge pan", "Move the camera when the mouse touches the window edge"],
]
const HELP_TOGGLES := [
	[
		"tutorial",
		"Tutorial",
		"Counsel cards on the element and armor counters for waves 1 to 10 (H opens the Field Guide)",
	],
]

const RECORD_TOGGLES := [
	[
		PlayLog.SETTING,
		"Game records",
		"Saves each game's moves and wave results to a file on this computer (nothing is sent)",
	],
]

var _game: Game
var _quality: Array[Button] = []
var _sliders := {}
var _values := {}
var _toggles := {}


func setup(game: Game) -> void:
	_game = game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := UiKit.panel()
	panel.custom_minimum_size.x = PANEL_WIDTH
	center.add_child(panel)
	var box := UiKit.vbox(10)
	panel.add_child(box)
	var title := UiKit.label("Settings", &"Title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UiKit.label("QUALITY", &"Caption"))
	box.add_child(_build_quality())
	box.add_child(UiKit.label("VOLUME", &"Caption"))
	for v in VOLUMES:
		box.add_child(_build_slider(v[0], v[1]))
	box.add_child(UiKit.label("CAMERA", &"Caption"))
	for t in TOGGLES:
		box.add_child(_build_toggle(t[0], t[1], t[2]))
	box.add_child(UiKit.label("HELP", &"Caption"))
	for t in HELP_TOGGLES:
		box.add_child(_build_toggle(t[0], t[1], t[2]))
	box.add_child(UiKit.label("PLAYTEST", &"Caption"))
	for t in RECORD_TOGGLES:
		box.add_child(_build_toggle(t[0], t[1], t[2]))
	var folder := UiKit.text_button(game, "Open the records folder", &"Segment")
	folder.tooltip_text = ProjectSettings.globalize_path(PlayLog.dir)
	folder.custom_minimum_size.y = 26
	folder.pressed.connect(_open_records)
	box.add_child(folder)
	var close := UiKit.text_button(game, "Close")
	close.custom_minimum_size = Vector2(140, 32)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_panel)
	box.add_child(close)
	game.quality_changed.connect(_on_quality)
	_apply_saved_volumes.call_deferred()


func _build_quality() -> Control:
	var row := UiKit.hbox(6)
	var group := ButtonGroup.new()
	for i in Quality.NAMES.size():
		var b := UiKit.text_button(_game, String(Quality.NAMES[i]).capitalize(), &"Segment")
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 30
		b.pressed.connect(func() -> void: _game.set_quality(i as Quality.Preset))
		_quality.append(b)
		row.add_child(b)
	return row


func _build_slider(bus: StringName, text: String) -> Control:
	var row := UiKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var l := UiKit.label(text)
	l.custom_minimum_size.x = LABEL_WIDTH
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(SLIDER_WIDTH, 22)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	row.add_child(s)
	var value := UiKit.label("", &"Number", UiTheme.SIZE_BODY)
	value.custom_minimum_size.x = 44
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	s.value_changed.connect(_on_volume.bind(bus))
	_sliders[bus] = s
	_values[bus] = value
	return row


func _build_toggle(key: String, text: String, tip: String) -> Control:
	var row := UiKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var l := UiKit.label(text)
	l.custom_minimum_size.x = LABEL_WIDTH + SLIDER_WIDTH + 10.0
	row.add_child(l)
	var b := UiKit.text_button(_game, "", &"Segment")
	b.toggle_mode = true
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(54, 26)
	b.toggled.connect(_on_toggle.bind(key, b))
	row.add_child(b)
	_toggles[key] = b
	return row


## AudioDirector saves volumes but doesn't restore them on launch, so the
## saved levels are re-applied here (deferred: its buses are created after the
## HUD's setup); untouched (full) buses are left alone.
func _apply_saved_volumes() -> void:
	for v in VOLUMES:
		var level: float = _game.audio.volume(v[0])
		if level < 0.999:
			_game.audio.set_volume(v[0], level)


func open() -> void:
	for v in VOLUMES:
		var s: HSlider = _sliders[v[0]]
		s.set_value_no_signal(_game.audio.volume(v[0]))
		_show_value(v[0], s.value)
	for t in TOGGLES + HELP_TOGGLES + RECORD_TOGGLES:
		var b: Button = _toggles[t[0]]
		var on: bool = Save.setting(t[0], true)
		b.set_pressed_no_signal(on)
		b.text = "On" if on else "Off"
	_on_quality(_game.quality)
	visible = true


func close_panel() -> void:
	visible = false


func toggle() -> void:
	if visible:
		close_panel()
	else:
		open()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close_panel()


func _on_quality(preset: Quality.Preset) -> void:
	for i in _quality.size():
		_quality[i].set_pressed_no_signal(i == preset)


func _on_volume(v: float, bus: StringName) -> void:
	_game.audio.set_volume(bus, v)
	_show_value(bus, v)


func _show_value(bus: StringName, v: float) -> void:
	(_values[bus] as Label).text = "%d%%" % roundi(v * 100.0)


## Shows the folder the game records are written to, with this game's so far.
func _open_records() -> void:
	_game.save_play_log()
	DirAccess.make_dir_recursive_absolute(PlayLog.dir)
	OS.shell_open(ProjectSettings.globalize_path(PlayLog.dir))


func _on_toggle(on: bool, key: String, b: Button) -> void:
	Save.set_setting(key, on)
	b.text = "On" if on else "Off"
	setting_changed.emit(key, on)
