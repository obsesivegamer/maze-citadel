class_name EndScreen
extends Control
## Victory and defeat screens (GDD §3): wave reached, kills, time, gold
## earned, lives, score and best wave for the mode, then Play again.

const PANEL_WIDTH := 420.0
const DIM := Color(0.02, 0.015, 0.01, 0.6)
const FADE := 0.6

var _game: Game
var _panel := UiKit.panel()
var _title := UiKit.label("", &"Title", UiTheme.SIZE_HUGE)
var _mode := UiKit.label("", &"Caption", UiTheme.SIZE_SMALL)
var _grid := GridContainer.new()
var _best := UiKit.label("", &"Heading", UiTheme.SIZE_BODY)


func setup(game: Game) -> void:
	_game = game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel.custom_minimum_size.x = PANEL_WIDTH
	center.add_child(_panel)
	var box := UiKit.vbox(10)
	_panel.add_child(box)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02))
	_title.add_theme_constant_override("outline_size", 10)
	box.add_child(_title)
	_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_mode)
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 24)
	_grid.add_theme_constant_override("v_separation", 4)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_grid)
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_best)
	var again := UiKit.text_button(game, "Play again")
	again.add_theme_font_override("font", UiTheme.heading(700))
	again.add_theme_font_size_override("font_size", UiTheme.SIZE_LARGE)
	again.custom_minimum_size = Vector2(200, 40)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(game.restart)
	box.add_child(again)


## `best_before` is the mode's best wave from before this run (Save.record
## has already stored this run by the time the event arrives).
func show_result(won: bool, best_before: int) -> void:
	var sim := _game.sim
	_title.text = "Victory" if won else "Defeat"
	_title.add_theme_color_override("font_color", UiTheme.GOLD_BRIGHT if won else UiTheme.BAD)
	_mode.text = TowerInfo.mode_name(sim.hard, sim.infinite).to_upper()
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var rows := [
		["Wave reached", str(sim.wave)],
		["Kills", str(sim.kills)],
		["Time", TowerInfo.fmt_time(sim.time)],
		["Gold earned", str(sim.gold_earned)],
		["Lives left", str(sim.lives)],
		["Score", str(sim.score())],
	]
	for row in rows:
		_grid.add_child(UiKit.label(row[0], &"Dim", UiTheme.SIZE_BODY))
		var v := UiKit.label(row[1], &"Number", UiTheme.SIZE_LARGE)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_grid.add_child(v)
	var mode := Save.mode_key(sim.hard, sim.infinite)
	if sim.wave > best_before:
		_best.text = "New best wave!"
		_best.add_theme_color_override("font_color", UiTheme.GOOD)
	else:
		_best.text = "Best wave: %d" % Save.best_wave(mode)
		_best.add_theme_color_override("font_color", UiTheme.GOLD)
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)
