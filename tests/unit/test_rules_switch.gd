extends "res://tests/test_case.gd"
## Element TD is the rule set a new player gets, and classic is one switch
## away before wave 1. The switch reloads the board the way a map switch does,
## so these tests drive the carry it leaves for the next Game rather than a
## scene reload. Games never enter the tree here.


## A Game whose reload only leaves the carry for the next Game.new().
class NoReload:
	extends Game

	func restart() -> void:
		pass


func test_rules_come_from_the_switch_then_the_flag_then_the_save() -> void:
	check_eq(Game.choose_rules(&"classic", "eletd", "eletd"), &"classic", "a switch beats all")
	check_eq(Game.choose_rules(&"eletd", "classic", "classic"), &"eletd", "either way")
	check_eq(Game.choose_rules(null, "classic", "eletd"), &"classic", "--rules beats the save")
	check_eq(Game.choose_rules(null, "", "classic"), &"classic", "the saved choice")
	check_eq(Game.choose_rules(null, "", ""), &"eletd", "a new player gets Element TD")
	check_eq(Game.choose_rules(null, "bogus", "classic"), &"classic", "unknown flag passed over")
	check_eq(Game.choose_rules(null, "", "bogus"), &"eletd", "unknown save passed over")
	check_eq(GameSim.new().rules, &"classic", "a bare sim still plays classic")


func test_a_carried_choice_sets_the_rules() -> void:
	for rules in GameSim.RULES:
		var game := _game({"rules": rules})
		check_eq(game.sim.rules, rules, "carried %s" % rules)
		check_eq(game.sim.gold, EletdRules.start_gold(rules), "%s starting gold" % rules)
		check(Game._carry.is_empty(), "the carry is spent")
		game.free()


func test_switch_waits_for_wave_one() -> void:
	var game := _game({"rules": &"eletd"})
	check(not game.change_rules(&"eletd"), "already playing them")
	check(not game.change_rules(&"bogus"), "no such rules")
	game.sim.wave = 1
	check(not game.change_rules(&"classic"), "refused once wave 1 has spawned")
	check_eq(game.sim.rules, &"eletd", "the rules stay")
	check(Game._carry.is_empty(), "nothing carried to a reload")
	game.free()


func test_switch_carries_the_board_setup() -> void:
	_use_test_save()
	var game := _game({"rules": &"eletd", "map": &"rampart"})
	check(game.set_mode(&"very_hard", true, true), "Very Hard, Infinite, Twists")
	Game._carry = game._carry_with({"rules": &"classic"})
	var classic := Game.new()
	check_eq(classic.sim.rules, &"classic")
	check_eq(classic.sim.difficulty, &"normal", "classic has no Very Hard: Normal")
	check(classic.sim.infinite and classic.sim.twists, "Infinite and Twists carry")
	check_eq(classic.sim.twist_seed, game.sim.twist_seed, "the same twist schedule")
	check_eq(classic.sim.grid.map, &"rampart", "the same map")
	for level: StringName in [&"easy", &"normal", &"hard", &"very_hard"]:
		game.set_mode(level, false)
		Game._carry = game._carry_with({"rules": &"classic"})
		var after := Game.new()
		var kept := level in [&"normal", &"hard"]
		check_eq(after.sim.difficulty, level if kept else &"normal", "%s into classic" % level)
		Game._carry = after._carry_with({"rules": &"eletd"})
		var back := Game.new()
		check_eq(back.sim.difficulty, after.sim.difficulty, "%s back into eletd" % level)
		after.free()
		back.free()
	game.free()
	classic.free()
	_restore_save()


## The Causeway is Element TD only, so a switch to classic plays the default
## map, and that is the map remembered: switching back and the next launch
## both stay on it rather than jumping back to the Causeway.
func test_switch_off_the_causeway_remembers_the_map_played() -> void:
	_use_test_save()
	Save.set_setting("rules", "eletd")
	Save.set_setting("map", "causeway")
	var game := NoReload.new()
	check_eq(game.sim.grid.map, &"causeway", "the saved pick")
	check(game.change_rules(&"classic"), "switched to classic")
	var classic := NoReload.new()
	check_eq(classic.sim.grid.map, MapDefs.DEFAULT, "classic plays the default map")
	check_eq(Save.setting("map", ""), String(MapDefs.DEFAULT), "and remembers it")
	check(classic.change_rules(&"eletd"), "switched back")
	var back := NoReload.new()
	check_eq(back.sim.grid.map, MapDefs.DEFAULT, "back on Element TD, same map")
	var again := NoReload.new()
	check_eq([again.sim.rules, again.sim.grid.map], [&"eletd", MapDefs.DEFAULT], "the next launch")
	check(again.change_rules(&"classic"), "a map classic offers")
	var stays := NoReload.new()
	check_eq(stays.sim.grid.map, MapDefs.DEFAULT, "stays")
	Save.set_setting("map", "rampart")
	var rampart := NoReload.new()
	check(rampart.change_rules(&"eletd"), "switched on the Rampart")
	check_eq(Save.setting("map", ""), "rampart", "a map both offer is kept")
	Game._carry = {}
	for g in [game, classic, back, again, stays, rampart]:
		g.free()
	_restore_save()


## Records already kept apart by rule set keep their names, so a classic best
## from 0.3 still counts once Element TD is the default.
func test_record_keys_are_unchanged() -> void:
	_use_test_save()
	var classic := _game({"rules": &"classic", "map": MapDefs.DEFAULT})
	check_eq(Save.sim_key(classic.sim), "normal", "classic keeps its 0.3 key")
	classic.set_mode(&"hard", true)
	check_eq(Save.sim_key(classic.sim), "hard_infinite")
	var eletd := _game({"rules": &"eletd", "map": MapDefs.DEFAULT})
	check_eq(Save.sim_key(eletd.sim), "normal_eletd", "Element TD keeps its own")
	var rampart := _game({"rules": &"classic", "map": &"rampart", "difficulty": &"hard"})
	check_eq(Save.sim_key(rampart.sim), "rampart_hard")
	for g in [classic, eletd, rampart]:
		g.free()
	_restore_save()


## Play again and the next launch keep the difficulty and the modes. A launch
## takes a switch's carry first, then --difficulty, then the last choice, but
## a headless or scripted run (a bot, a benchmark, a capture) never plays the
## saved mode.
func test_mode_comes_from_the_carry_then_the_flag_then_the_save() -> void:
	var saved := {"difficulty": "very_hard", "infinite": true, "twists": true}
	var none := {}
	var hard := {"difficulty": "hard"}
	var normal := {"difficulty": &"normal", "infinite": false, "twists": false, "twist_seed": 0}
	check_eq(Game.choose_mode({}, none, {}), normal, "a first launch")
	var last := Game.choose_mode({}, none, saved)
	check_eq(last, normal.merged(saved, true).merged({"difficulty": &"very_hard"}, true), "saved")
	check_eq(Game.choose_mode({}, hard, saved).difficulty, &"hard", "--difficulty beats the save")
	check(Game.choose_mode({}, hard, saved).twists, "and the modes stay saved")
	check_eq(Game.choose_mode({}, none, saved, true), normal, "a scripted run ignores the save")
	var carry := {"rules": &"eletd", "difficulty": &"easy", "twists": true, "twist_seed": 7}
	var carried := Game.choose_mode(carry, hard, saved)
	check_eq(
		[carried.difficulty, carried.infinite, carried.twists], [&"easy", false, true], "carry"
	)
	check_eq(carried.twist_seed, 7, "with its seed")
	var tool := Game.choose_mode({"rules": &"classic"}, hard, saved)
	check_eq(tool, normal.merged({"difficulty": &"hard"}, true), "a tool's carry: flag, not save")


func test_set_mode_is_remembered_for_the_next_launch() -> void:
	_use_test_save()
	var game := _game({"rules": &"eletd"})
	check(game.set_mode(&"very_hard", true, true), "Very Hard, Infinite, Twists")
	var saved := {}
	for key: String in Game.DEFAULT_MODE:
		saved[key] = Save.setting(key, null)
	check_eq(saved, {"difficulty": "very_hard", "infinite": true, "twists": true}, "saved")
	var next := Game.choose_mode({}, {}, saved)
	check_eq([next.difficulty, next.infinite, next.twists], [&"very_hard", true, true], "launch")
	check_eq(Game.offered_difficulty(next.difficulty, &"classic"), &"normal", "classic: Normal")
	check(game.set_mode(&"hard", false, false, false), "--twists sets the mode")
	check_eq(Save.setting("difficulty", ""), "very_hard", "without saving it")
	game.sim.wave = 1
	check(not game.set_mode(&"easy", false), "refused once wave 1 has spawned")
	check_eq(Save.setting("difficulty", ""), "very_hard", "and not saved")
	game.free()
	_restore_save()


func test_play_again_keeps_the_board_setup() -> void:
	_use_test_save()
	Game._carry = {"rules": &"eletd", "map": &"rampart"}
	var game := NoReload.new()
	check(game.set_mode(&"very_hard", true, true), "Very Hard, Infinite, Twists")
	game.sim.wave = 12
	game.play_again()
	var again := NoReload.new()
	var setup := [again.sim.rules, again.sim.grid.map, again.sim.difficulty]
	check_eq(setup, [&"eletd", &"rampart", &"very_hard"], "same rules, map and difficulty")
	check(again.sim.infinite and again.sim.twists, "Infinite and Twists")
	check(again.sim.twist_seed != 0, "a Twists schedule is dealt")
	check_eq(again.sim.wave, 0, "from the start")
	check(Game._carry.is_empty(), "the carry is spent")
	for g in [game, again]:
		g.free()
	_restore_save()


## set_mode and the switches save settings; tests keep theirs apart.
func _use_test_save() -> void:
	Save.path = "user://test_rules_switch.cfg"
	Save._cfg = ConfigFile.new()


func _restore_save() -> void:
	DirAccess.remove_absolute(Save.path)
	Save.path = Save.PATH
	Save._cfg = null


func _game(carry: Dictionary) -> Game:
	Game._carry = carry
	return Game.new()
