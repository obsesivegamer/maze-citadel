class_name SetupPanel
extends UiModal
## The setup before a match (GDD §5): map, rules, the difficulties with what
## each does, Infinite, Twists and the tutorial, then Start. It opens at the
## start of every fresh match in a real window and holds the game paused, so
## the opening build countdown waits for Start. Start sets the mode
## (game.set_mode, remembered for the next launch) and saves the tutorial
## choice; the HUD then begins the tutorial if it is on. A map or rules
## switch reloads the scene, and the panel opens again over the new board.
## Play again skips it; the pause menu's New game setup and the end screen's
## Change setup bring it back (game.change_setup). Headless and scripted runs
## never see it.

## Start was pressed; `tutorial` is the Tutorial chip.
signal started(tutorial: bool)

const PANEL_WIDTH := 620.0
const CHIP_WIDTH := 96.0
const LINE_WIDTH := 480.0
const START_SIZE := Vector2(200, 40)
## The choices the chips hold until Start, and the key of each toggle.
const TOGGLES: Array[StringName] = [&"infinite", &"twists", &"tutorial"]

## The next match opens on this panel: true at launch, still true after a
## switch made on the panel, cleared by Start and set again by
## game.change_setup. Static, so it survives the scene reload.
static var pending := true

var _choice := {}
var _levels := {}
var _toggles := {}
var _clock := UiKit.label("", &"Dim", UiTheme.SIZE_SMALL)


static func wanted() -> bool:
	return pending and wanted_for(Cli.args(), DisplayServer.get_name() == "headless")


## Never for a headless run or one with a flag in Tutorial.SCRIPTED_FLAGS
## (bots, captures, benchmarks, probes, warps): those play what their flags
## say from the first frame.
static func wanted_for(args: Dictionary, headless := false) -> bool:
	if headless:
		return false
	for flag in Tutorial.SCRIPTED_FLAGS:
		if args.has(flag):
			return false
	return true


## A chip's tooltip without its leading "Name: ", for the line beside it.
static func line(tip: String) -> String:
	var rest := tip.substr(tip.find(": ") + 2)
	return rest.left(1).to_upper() + rest.substr(1)


static func clock_text(seconds: float) -> String:
	return "The %d s build countdown before wave 1 starts when you press Start." % roundi(seconds)


func setup(game: Game) -> void:
	var box := build_frame(game, "New game", PANEL_WIDTH, 8)
	var sim := game.sim
	var map := sim.grid.map
	box.add_child(
		HudMapPicker.row(game, "MAP", HudMapPicker.map_choices(sim.rules), map, switch_map)
	)
	box.add_child(
		HudMapPicker.row(game, "RULES", HudMapPicker.rules_choices(map), sim.rules, switch_rules)
	)
	var blurb := UiKit.rich(UiTheme.SIZE_SMALL, PANEL_WIDTH - 30.0)
	blurb.text = HudMapPicker.blurb(map)
	blurb.add_theme_color_override("default_color", UiTheme.TEXT_DIM)
	box.add_child(blurb)
	box.add_child(UiKit.label("DIFFICULTY", &"Caption"))
	var group := ButtonGroup.new()
	for level in EletdRules.difficulties(sim.rules):
		var tip := TowerInfo.difficulty_tip(level, sim.rules)
		var chip := _chip(box, TowerInfo.difficulty_name(level), tip)
		chip.button_group = group
		chip.pressed.connect(choose.bind(&"difficulty", level))
		_levels[level] = chip
	box.add_child(UiKit.label("EXTRAS", &"Caption"))
	var tips := {
		&"infinite": TowerInfo.infinite_tip(),
		&"twists": TowerInfo.twists_tip(),
		&"tutorial": "Tutorial: " + SettingsPanel.HELP_TOGGLES[0][2],
	}
	for key in TOGGLES:
		var chip := _chip(box, String(key).capitalize(), tips[key])
		chip.toggled.connect(choose.bind(key))
		_toggles[key] = chip
	var start_button := UiKit.text_button(game, "Start")
	start_button.add_theme_font_override("font", UiTheme.heading(700))
	start_button.add_theme_font_size_override("font_size", UiTheme.SIZE_LARGE)
	start_button.custom_minimum_size = START_SIZE
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.pressed.connect(start)
	box.add_child(start_button)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_clock)


## A toggle chip with the line it explains beside it.
func _chip(box: VBoxContainer, text: String, tip: String) -> Button:
	var row := UiKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var b := UiKit.text_button(_game, text, &"Segment")
	b.toggle_mode = true
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(CHIP_WIDTH, HudTopBar.BUTTON_PX)
	row.add_child(b)
	var l := UiKit.rich(UiTheme.SIZE_SMALL, LINE_WIDTH)
	l.text = line(tip)
	l.add_theme_color_override("default_color", UiTheme.TEXT_DIM)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	box.add_child(row)
	return b


## The chips start from the board's mode (the carry or the saved one) and
## the saved tutorial setting; `--tutorial` turns that chip on.
func open() -> void:
	var sim := _game.sim
	_choice = {
		&"difficulty": sim.difficulty,
		&"infinite": sim.infinite,
		&"twists": sim.twists,
		&"tutorial": Cli.has("tutorial") or Save.setting("tutorial", true),
	}
	_sync()
	_clock.text = clock_text(sim.countdown)
	open_modal()


## What the chips hold until Start ({difficulty, infinite, twists, tutorial}).
func choice() -> Dictionary:
	return _choice


## Sets one choice (a key of choice()); the chips and the tests call it.
func choose(key: StringName, value: Variant) -> void:
	_choice[key] = value
	_sync()


## Settings → Tutorial, changed while the panel is up, moves its chip.
func on_setting(key: String, on: bool) -> void:
	if key == "tutorial":
		choose(&"tutorial", on)


func start() -> void:
	_apply()
	pending = false
	close_modal()
	started.emit(_choice[&"tutorial"])


## A switch reloads the scene. The choices so far go with it, remembered
## like the switch itself, and the panel opens again over the new board.
func switch_map(id: StringName) -> void:
	_apply()
	_game.change_map(id)


func switch_rules(rules: StringName) -> void:
	_apply()
	_game.change_rules(rules)


func _apply() -> void:
	_game.set_mode(_choice[&"difficulty"], _choice[&"infinite"], _choice[&"twists"])
	Save.set_setting("tutorial", _choice[&"tutorial"])


func _sync() -> void:
	for level: StringName in _levels:
		(_levels[level] as Button).set_pressed_no_signal(level == _choice[&"difficulty"])
	for key: StringName in _toggles:
		(_toggles[key] as Button).set_pressed_no_signal(_choice[key])
