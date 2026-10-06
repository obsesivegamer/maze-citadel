class_name PauseMenu
extends UiModal
## The pause menu (Esc with nothing open or selected, GDD §10): Resume,
## Restart, New game setup, Settings, the Field Guide and Quit to desktop.
## Restart, New game setup and Quit end the game, so each asks for a second
## click first. It pauses the game while open; Settings and the Field Guide
## open over it and return to it.

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
## What a button that ends the game reads while it waits for the second click.
const CONFIRM := {
	&"restart": "Click again to restart",
	&"setup": "Click again for a new setup",
	&"quit": "Click again to quit",
}

var _mode := UiKit.label("", &"Caption", UiTheme.SIZE_SMALL)
var _buttons := {}
## The button waiting for its second click, or &"".
var _confirming: StringName = &""


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
	_set_confirming(&"")
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
	if action in CONFIRM and _confirming != action:
		_set_confirming(action)
		return
	_set_confirming(&"")
	match action:
		&"resume":
			close_modal()
		&"restart":
			_game.play_again()
		&"setup":
			_game.change_setup()
		&"settings":
			settings_requested.emit()
		&"guide":
			guide_requested.emit()
		&"quit":
			_game.quit()


## A first click on a button that ends the game asks before it is thrown
## away; any other button, or closing the menu, takes the question back.
func _set_confirming(action: StringName) -> void:
	_confirming = action
	for b in BUTTONS:
		if b[0] in CONFIRM:
			(_buttons[b[0]] as Button).text = CONFIRM[b[0]] if b[0] == action else b[1]
