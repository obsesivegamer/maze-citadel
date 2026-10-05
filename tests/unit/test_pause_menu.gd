extends "res://tests/test_case.gd"
## The pause menu (Esc) and Settings as a modal, on
## a Game that is never added to the tree: its reload and quit are stubbed
## and only noted, so a test never restarts or quits the runner.


class Stubbed:
	extends Game
	var reloads := 0
	var quits := 0

	func restart() -> void:
		reloads += 1

	func _quit_tree() -> void:
		quits += 1


func test_the_menu_pauses_and_resumes() -> void:
	var game := _game()
	var menu := _menu(game)
	menu.open()
	check(menu.visible and game.paused, "open pauses")
	menu.press(&"resume")
	check(not menu.visible and not game.paused, "Resume resumes")
	game.toggle_pause()
	menu.toggle()
	menu.toggle()
	check(game.paused, "a game paused before opening stays paused")
	menu.free()
	game.free()


func test_restart_asks_once() -> void:
	var game := _game()
	var menu := _menu(game)
	menu.open()
	check_eq(menu.button_text(&"restart"), "Restart")
	menu.press(&"restart")
	check_eq(game.reloads, 0, "the first click only asks")
	check_eq(menu.button_text(&"restart"), "Click again to restart")
	menu.press(&"settings")
	check_eq(menu.button_text(&"restart"), "Restart", "another button takes the question back")
	menu.press(&"restart")
	menu.close_modal()
	menu.open()
	check_eq(menu.button_text(&"restart"), "Restart", "and so does closing the menu")
	menu.press(&"restart")
	menu.press(&"restart")
	check_eq(game.reloads, 1, "the second click plays again")
	check_eq(Game._carry.get("difficulty"), &"very_hard", "on the same setup")
	Game._carry = {}
	menu.free()
	game.free()


func test_menu_buttons() -> void:
	var game := _game()
	var menu := _menu(game)
	var asked := []
	menu.settings_requested.connect(func() -> void: asked.append(&"settings"))
	menu.guide_requested.connect(func() -> void: asked.append(&"guide"))
	menu.open()
	menu.press(&"settings")
	menu.press(&"guide")
	check_eq(asked, [&"settings", &"guide"], "Settings and the Field Guide")
	check(menu.visible and game.paused, "open over the menu, which stays paused")
	menu.press(&"setup")
	check_eq(game.reloads, 1, "New game setup starts over (the setup screen will follow)")
	Game._carry = {}
	check_eq(game.quits, 0)
	menu.press(&"quit")
	check_eq(game.quits, 1, "Quit to desktop")
	menu.free()
	game.free()


func test_quit_keeps_the_record() -> void:
	PlayLog.dir = "user://test_playtests"
	Save.path = "user://test_pause_menu.cfg"
	Save._cfg = ConfigFile.new()
	var game := _game()
	game.play_log = PlayLog.new()
	game.build_choice = &"archer"
	game.build_at(Vector2i(4, 6))
	var path := game.play_log.file_path(game.sim)
	game.quit()
	check_eq(game.quits, 1)
	check_eq(Replayer.load_file(path).get("actions", []).size(), 1, "saved before quitting")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(PlayLog.dir)
	PlayLog.dir = PlayLog.DIR
	DirAccess.remove_absolute(Save.path)
	Save.path = Save.PATH
	Save._cfg = null
	game.free()


func test_settings_is_modal() -> void:
	var game := _game()
	var settings := SettingsPanel.new()
	settings.setup(game)
	check(settings is UiModal, "routed and paused like the other modals")
	# open() first reads the volumes from game.audio, which this Game lacks.
	settings.open_modal()
	check(settings.visible and game.paused, "open pauses")
	settings.toggle()
	check(not settings.visible and not game.paused, "F10 again resumes")
	settings.free()
	game.free()


## A Very Hard game under eletd whatever the player's saved choice.
func _game() -> Stubbed:
	Game._carry = {"rules": &"eletd", "difficulty": &"very_hard"}
	return Stubbed.new()


func _menu(game: Game) -> PauseMenu:
	var menu := PauseMenu.new()
	menu.setup(game)
	return menu
