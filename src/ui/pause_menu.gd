class_name PauseMenu
extends UiModal
## The pause menu (Esc with nothing open or selected, GDD §10): Resume,
## Restart (a second click confirms), New game setup, Settings, the Field
## Guide and Quit to desktop. It pauses the game while open; Settings and the
## Field Guide open over it and return to it.

signal settings_requested
signal guide_requested

const PANEL_WIDTH := 300.0
const BUTTON_SIZE := Vector2(240, 34)
## [action, label]: the buttons from the top.
const BUTTONS := [
	[&"resume", "Resume (Esc)"],
	[&"restart", "Restart"],
	[&"setup", "New game setup"],
	[&"settings", "Settings (F10)"],
	[&"guide", "Field Guide (H)"],
	[&"quit", "Quit to desktop"],
]

var _mode := UiKit.label("", &"Caption", UiTheme.SIZE_SMALL)
var _buttons := {}
var _confirming := false


func setup(game: Game) -> void:
	var box := build_frame(game, "Paused", PANEL_WIDTH)
	_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_mode)
	for b in BUTTONS:
		var button := UiKit.text_button(game, b[1])
		button.custom_minimum_size = BUTTON_SIZE
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(press.bind(b[0]))
		box.add_child(button)
		_buttons[b[0]] = button


## Restart's label: a first click asks before the game is thrown away.
static func restart_text(confirming: bool) -> String:
	return "Click again to restart" if confirming else "Restart"


func open() -> void:
	var sim := _game.sim
	_mode.text = (
		(
			TowerInfo.rules_name(sim.rules)
			+ TowerInfo.SEP
			+ TowerInfo.mode_name(sim.difficulty, sim.infinite, sim.twists)
			+ TowerInfo.SEP
			+ "Wave %d" % sim.wave
		)
		. to_upper()
	)
	_set_confirming(false)
	open_modal()


func toggle() -> void:
	if visible:
		close_modal()
	else:
		open()


func button_text(action: StringName) -> String:
	return (_buttons[action] as Button).text


## What each button does; the HUD's keys and the tests press them here.
func press(action: StringName) -> void:
	if action != &"restart":
		_set_confirming(false)
	match action:
		&"resume":
			close_modal()
		&"restart":
			if _confirming:
				_game.play_again()
			else:
				_set_confirming(true)
		&"setup":
			_game.change_setup()
		&"settings":
			settings_requested.emit()
		&"guide":
			guide_requested.emit()
		&"quit":
			_game.quit()


func _set_confirming(on: bool) -> void:
	_confirming = on
	(_buttons[&"restart"] as Button).text = restart_text(on)
