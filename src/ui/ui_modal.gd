class_name UiModal
extends Control
## A centred stone panel over a dimmed screen that takes every click: the
## frame shared by the tutorial's welcome card and the Field Guide. Opening it
## pauses the game; closing resumes only if opening paused it, so a game
## paused beforehand stays paused. The HUD routes keys to whichever is up
## (Hud.modal_action()).

## A click on the dimmed screen around the panel (not the scroll wheel).
signal dim_pressed

const DIM := Color(0, 0, 0, 0.45)
const CLICKS: Array[MouseButton] = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]

var _game: Game
var _paused_here := false


## Builds the dim and a panel at least `width` wide with `title` centred on
## top, and returns the column under the title for the content. Starts closed.
func build_frame(game: Game, title: String, width: float, separation := 10) -> VBoxContainer:
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
	panel.custom_minimum_size.x = width
	center.add_child(panel)
	var box := UiKit.vbox(separation)
	panel.add_child(box)
	var heading := UiKit.label(title, &"Title")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	return box


func open_modal() -> void:
	visible = true
	if not _game.paused:
		_game.toggle_pause()
		_paused_here = true


func close_modal() -> void:
	if not visible:
		return
	visible = false
	if _paused_here and _game.paused:
		_game.toggle_pause()
	_paused_here = false


func _on_dim_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index in CLICKS:
		dim_pressed.emit()
