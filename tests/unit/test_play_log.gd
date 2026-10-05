extends "res://tests/test_case.gd"
## A game's record (PlayLog) holds enough to play the game again: Replayer
## gets the same waves and the same end from the actions alone, for a bot's
## game and for a player's, through the JSON file the game writes.

const Bot := preload("res://src/bots/autoplay_bot.gd")
const WAVES := 6


## A bot's game up to the end of wave `waves`, as the record a file holds.
func _bot_game(rules: StringName, difficulty: StringName, waves := WAVES) -> Dictionary:
	var sim := GameSim.new()
	sim.rules = rules
	sim.difficulty = difficulty
	var bot := Bot.new(sim, &"smart", 3)
	var play := PlayLog.new()
	while sim.wave <= waves and sim.phase != GameSim.Phase.DEFEAT:
		var step := PlayLog.step_of(sim)
		bot.step()
		play.observe(sim, sim.drain_events(), step)
	return _through_json(play.to_dict(sim))


func _through_json(record: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(record))


func test_a_recorded_bot_game_replays_to_the_same_game() -> void:
	for rules in GameSim.RULES:
		var record := _bot_game(rules, &"hard")
		check(record.actions.size() > 10, "%s: the bot built a maze" % rules)
		check_eq(record.waves.size(), WAVES + 1, "%s: a row per wave started" % rules)
		var replay := Replayer.new(record)
		replay.run()
		check_eq(replay.difference(), "", "%s replay" % rules)
		check(replay.refused.is_empty(), "%s: every action was accepted" % rules)
		var again := _through_json(replay.result())
		check_eq(again.waves, record.waves, "%s: the same waves, row for row" % rules)
		check_eq(again.result, record.result, "%s: the same end and board" % rules)


func test_a_replay_under_other_numbers_says_where_it_parts() -> void:
	var record := _bot_game(&"eletd", &"normal")
	record.setup.difficulty = "very_hard"
	var replay := Replayer.new(record)
	replay.run()
	check(replay.difference() != "", "tougher creeps are not the same game")


func test_every_kind_of_action_is_recorded_and_replayed() -> void:
	var sim := GameSim.new()
	sim.rules = &"eletd"
	var play := PlayLog.new()
	var a := Vector2i(4, 6)
	var b := Vector2i(5, 6)
	var acts: Array[Callable] = [
		sim.build.bind(a, &"archer"),
		sim.build.bind(b, &"archer"),
		sim.build.bind(Vector2i(9, 9), &"cannon"),
		sim.build.bind(a, &"archer"),
		sim.sell.bind(Vector2i(9, 9)),
		sim.upgrade.bind(a),
		sim.upgrade.bind(b),
		sim.upgrade.bind(a),
		sim.upgrade.bind(b),
		sim.fuse.bind(a, b),
		sim.elements.pick.bind(sim, &"flame"),
	]
	for act in acts:
		act.call()
		play.observe(sim, sim.drain_events())
	sim.start_next_wave()
	play.called_wave(sim)
	play.observe(sim, sim.drain_events())
	for i in 300:
		sim.step()
		play.observe(sim, sim.drain_events())
	var record := _through_json(play.to_dict(sim))
	var kinds := {}
	for action: Dictionary in record.actions:
		kinds[action.do] = kinds.get(action.do, 0) + 1
	var expected := {"build": 3, "sell": 1, "upgrade": 4, "fuse": 1, "pick": 1, "call": 1}
	check_eq(kinds, expected, "a refused build is no action")
	check_eq(record.result.outcome, "unfinished", "left mid-wave")
	check_eq(record.result.towers.size(), 1, "the final board")
	var replay := Replayer.new(record)
	replay.run()
	check_eq(replay.difference(), "", "replay")
	check_eq(_through_json(replay.result()).actions, record.actions, "the same actions")
	check_eq(replay.sim.tower_at(a).id, sim.tower_at(a).id, "the Epic stands")
	check_eq(replay.sim.elements.level(&"flame"), 1, "the pick was spent")


func test_an_action_the_sim_turns_down_is_reported() -> void:
	var record := _bot_game(&"eletd", &"normal", 1)
	record.actions.push_front({"step": 0, "do": "upgrade", "tile": [0, 0]})
	var replay := Replayer.new(record)
	replay.run()
	check_eq(replay.refused.size(), 1, "no tower there")


func test_waves_report_how_far_creeps_walked() -> void:
	var sim := GameSim.new()
	sim.rules = &"eletd"
	var play := PlayLog.new()
	sim.start_next_wave()
	while sim.phase != GameSim.Phase.DEFEAT:
		sim.step()
		play.observe(sim, sim.drain_events())
	var record := play.to_dict(sim)
	var row: Dictionary = record.waves[0]
	check_eq(row.wave, 1, "wave 1")
	check_eq(row.towers, 0, "nothing built")
	check_near(row.walked, 1.0, 1e-4, "an undefended wave walks the whole route")
	check_eq(row.lives_lost, GameSim.START_LIVES, "and takes every life")
	check_eq(row.deaths, 0, "nothing died")
	check_eq(row.died_at, null, "so nowhere")
	check_eq(record.result.outcome, "defeat", "the game is lost")


func test_a_defended_wave_reports_where_its_creeps_died() -> void:
	var row: Dictionary = _bot_game(&"eletd", &"normal", 1).waves[0]
	check(row.deaths > 0, "the bot's maze kills wave 1")
	check(row.died_at > 0.0 and row.died_at <= row.walked, "somewhere short of the furthest")
	check(row.cleared_t > row.t, "and the wave ends")


func test_the_file_is_written_once_something_happened() -> void:
	PlayLog.dir = "user://test_playtests"
	var sim := GameSim.new()
	var play := PlayLog.new()
	check_eq(play.save(sim), "", "an untouched game writes nothing")
	sim.build(Vector2i(4, 6), &"archer")
	play.observe(sim, sim.drain_events())
	var path := play.save(sim)
	check(path.begins_with(PlayLog.dir), "saved under the playtests folder")
	var record := Replayer.load_file(path)
	check_eq(record.get("actions", []).size(), 1, "the file reads back")
	check_eq(record.setup.map, "citadel", "with its setup")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(PlayLog.dir)
	PlayLog.dir = PlayLog.DIR


## A booted Game's record, without the tree: the player's actions go through
## the Game the way the HUD sends them.
func _played_game() -> Game:
	Game._carry = {"rules": &"eletd", "difficulty": &"very_hard"}
	var game := Game.new()
	game.play_log = PlayLog.new()
	game.build_choice = &"archer"
	# Paused at the start: several actions on one step.
	for col in [3, 4, 5, 6]:
		game.build_at(Vector2i(col, 6))
	game.select(Vector2i(4, 6))
	game.upgrade_selected()
	game.pick_element(&"aqua")
	for i in 100:
		game.sim.step()
		game._flush()
	game.call_next_wave()
	game.select(Vector2i(3, 6))
	game.sell_selected()
	for i in 900:
		game.sim.step()
		game._flush()
	return game


func test_a_players_game_is_written_and_replays_action_for_action() -> void:
	PlayLog.dir = "user://test_playtests"
	Save.path = "user://test_play_log.cfg"
	Save._cfg = ConfigFile.new()
	var game := _played_game()
	var path := game.play_log.file_path(game.sim)
	check(FileAccess.file_exists(path), "written when the wave started, without being asked")
	check_eq(game.save_play_log(), path, "and again on request")
	var record := Replayer.load_file(path)
	check_eq(record.setup.difficulty, "very_hard", "the difficulty played")
	var does: Array = record.actions.map(func(a: Dictionary) -> String: return a.do)
	var expected := ["build", "build", "build", "build", "upgrade", "pick", "call", "sell"]
	check_eq(does, expected, "every action in order")
	check_eq(int(record.actions[6].step), 100, "on the step it was taken")
	var replay := Replayer.new(record)
	replay.run()
	check_eq(replay.difference(), "", "replay")
	check_eq(_through_json(replay.result()).actions, record.actions, "the same actions")
	check_eq(_through_json(replay.result()).waves, record.waves, "the same waves")
	DirAccess.remove_absolute(path)
	game.free()
	_restore()


func test_no_file_when_records_are_off_or_a_bot_plays() -> void:
	PlayLog.dir = "user://test_playtests"
	Save.path = "user://test_play_log.cfg"
	Save._cfg = ConfigFile.new()
	Save.set_setting(PlayLog.SETTING, false)
	var game := _played_game()
	check_eq(game.save_play_log(), "", "turned off in Settings")
	check(not FileAccess.file_exists(game.play_log.file_path(game.sim)), "nothing written")
	Save.set_setting(PlayLog.SETTING, true)
	game.autoplay = Bot.new(game.sim, &"smart")
	check_eq(game.save_play_log(), "", "a bot's game")
	game.free()
	_restore()


func _restore() -> void:
	DirAccess.remove_absolute(Save.path)
	DirAccess.remove_absolute(PlayLog.dir)
	Save.path = Save.PATH
	Save._cfg = null
	PlayLog.dir = PlayLog.DIR
