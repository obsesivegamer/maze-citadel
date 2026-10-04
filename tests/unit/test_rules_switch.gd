extends "res://tests/test_case.gd"
## Element TD is the rule set a new player gets, and classic is one switch
## away before wave 1. The switch reloads the board the way a map switch does,
## so these tests drive the carry it leaves for the next Game rather than a
## scene reload. Games never enter the tree here.


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


## Records already kept apart by rule set keep their names, so a classic best
## from 0.3 still counts once Element TD is the default.
func test_record_keys_are_unchanged() -> void:
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


func _game(carry: Dictionary) -> Game:
	Game._carry = carry
	return Game.new()
