extends "res://tests/test_case.gd"
## The setup panel that holds the opening countdown until Start, on a Game
## that is never added to the tree: its reload only leaves the carry for the
## next Game.new(), and the save is a throwaway file because Start and the
## switches remember the choices.


class NoReload:
	extends Game
	var reloads := 0

	func restart() -> void:
		reloads += 1


func test_only_real_games_get_it() -> void:
	check(SetupPanel.wanted_for({}), "a player's launch")
	check(SetupPanel.wanted_for({"map": "rampart", "difficulty": "hard"}), "with a map or level")
	for flag in ["autoplay", "shot", "bench", "first-frame-out", "warp-wave", "no-tutorial"]:
		check(not SetupPanel.wanted_for({flag: "true"}), "--%s skips it" % flag)
	check(not SetupPanel.wanted_for({}, true), "headless tools, smoke runs and tests skip it")
	check(not SetupPanel.wanted_for({"tutorial": "true"}, true), "--tutorial doesn't force it")


func test_lines_beside_the_chips() -> void:
	check_eq(SetupPanel.line("Normal: base creep HP and bounty"), "Base creep HP and bounty")
	check_eq(SetupPanel.line(TowerInfo.infinite_tip()), "Waves continue after 40")
	check(SetupPanel.line(TowerInfo.difficulty_tip(&"easy", &"eletd")).begins_with("Creeps have"))
	check(SetupPanel.clock_text(45.0).begins_with("The 45 s build countdown"))
	var eletd := _panel(_game({"rules": &"eletd"}))
	check_eq(eletd._levels.keys(), [&"easy", &"normal", &"hard", &"very_hard"], "four levels")
	var classic := _panel(_game({"rules": &"classic"}))
	check_eq(classic._levels.keys(), [&"normal", &"hard"], "classic offers two")
	_free(eletd)
	_free(classic)


func test_open_holds_the_clock_and_start_applies_the_mode() -> void:
	_use_test_save()
	Save.set_setting("tutorial", true)
	var panel := _panel(_game({"rules": &"eletd"}))
	var game: NoReload = panel._game
	var countdown := game.sim.countdown
	panel.open()
	check(panel.visible and game.paused, "open pauses, so the countdown waits")
	check_eq(panel.choice()[&"difficulty"], &"normal", "the chips start from the board's mode")
	check(panel.choice()[&"tutorial"], "and the saved tutorial setting")
	panel.choose(&"difficulty", &"very_hard")
	panel.choose(&"infinite", true)
	panel.choose(&"tutorial", false)
	check(panel._levels[&"very_hard"].button_pressed, "the chip follows")
	check_eq(game.sim.difficulty, &"normal", "nothing changes before Start")
	var started := []
	panel.started.connect(func(tutorial: bool) -> void: started.append(tutorial))
	panel.start()
	check(not panel.visible and not game.paused, "Start unpauses")
	check_eq(game.sim.difficulty, &"very_hard", "and sets the mode")
	check(game.sim.infinite and not game.sim.twists)
	check_eq(game.sim.countdown, countdown, "the countdown starts from the top")
	check_eq(started, [false], "tutorial off: the HUD starts nothing")
	check_eq(Save.setting("difficulty", ""), "very_hard", "the mode is remembered")
	check(not Save.setting("tutorial", true), "and so is the tutorial chip")
	check(not SetupPanel.pending, "the next Play again skips the panel")
	_free(panel)
	SetupPanel.pending = true
	_restore_save()


func test_start_begins_the_tutorial_when_on() -> void:
	_use_test_save()
	Save.set_setting("tutorial", false)
	var panel := _panel(_game({"rules": &"classic"}))
	panel.open()
	check(not panel.choice()[&"tutorial"], "off as saved")
	panel.on_setting("tutorial", true)
	check(panel._toggles[&"tutorial"].button_pressed, "Settings → Tutorial moves the chip")
	var started := []
	panel.started.connect(func(tutorial: bool) -> void: started.append(tutorial))
	panel.start()
	check_eq(started, [true], "the HUD opens the welcome straight after")
	_free(panel)
	SetupPanel.pending = true
	_restore_save()


func test_a_game_paused_before_stays_paused() -> void:
	_use_test_save()
	var panel := _panel(_game({"rules": &"eletd"}))
	panel._game.toggle_pause()
	panel.open()
	panel.start()
	check(panel._game.paused, "Start resumes only what the panel paused")
	_free(panel)
	SetupPanel.pending = true
	_restore_save()


## A switch reloads the scene: the panel's choices so far go with it and it
## opens again over the new board.
func test_reopens_after_a_map_or_rules_switch() -> void:
	_use_test_save()
	var panel := _panel(_game({"rules": &"eletd", "map": &"citadel"}))
	panel.open()
	panel.choose(&"difficulty", &"hard")
	panel.choose(&"twists", true)
	panel.switch_map(&"rampart")
	check_eq((panel._game as NoReload).reloads, 1, "the board reloads")
	check(SetupPanel.pending and SetupPanel.wanted_for({}), "and the panel will open again")
	var next := _panel(NoReload.new())
	next.open()
	check_eq(next._game.sim.grid.map, &"rampart")
	check_eq(next.choice()[&"difficulty"], &"hard", "the chosen level came along")
	check(next.choice()[&"twists"], "and Twists")
	next.switch_rules(&"classic")
	var classic := _panel(NoReload.new())
	classic.open()
	check_eq(classic._game.sim.rules, &"classic")
	check_eq(classic.choice()[&"difficulty"], &"hard", "classic offers Hard too")
	check(SetupPanel.pending, "still open until Start")
	_free(panel)
	_free(next)
	_free(classic)
	Game._carry = {}
	_restore_save()


## Play again starts at once on the same setup; New game setup and Change
## setup come back to the panel.
func test_play_again_skips_it_and_change_setup_brings_it_back() -> void:
	var game := _game({"rules": &"eletd", "difficulty": &"hard"})
	SetupPanel.pending = false
	game.play_again()
	check(not SetupPanel.pending, "Play again starts the clock at once")
	check_eq(Game._carry.get("difficulty"), &"hard", "on the same setup")
	game.change_setup()
	check(SetupPanel.pending, "Change setup opens the panel")
	check_eq(Game._carry.get("difficulty"), &"hard", "with the setup as it was")
	check_eq(game.reloads, 2)
	Game._carry = {}
	game.free()


func _game(carry: Dictionary) -> NoReload:
	Game._carry = carry
	return NoReload.new()


func _panel(game: Game) -> SetupPanel:
	var panel := SetupPanel.new()
	panel.setup(game)
	return panel


func _free(panel: SetupPanel) -> void:
	var game := panel._game
	panel.free()
	game.free()


func _use_test_save() -> void:
	Save.path = "user://test_setup_panel.cfg"
	Save._cfg = ConfigFile.new()


func _restore_save() -> void:
	DirAccess.remove_absolute(Save.path)
	Save.path = Save.PATH
	Save._cfg = null
