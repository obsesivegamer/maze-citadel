extends "res://tests/test_case.gd"
## The eletd interest lock and difficulty ladder (GDD §5.0).


## Wave 1 with no towers: every grunt walks to the gate and loops.
func _leaking_wave(rules: StringName) -> GameSim:
	var sim := GameSim.new()
	sim.rules = rules
	sim.countdown = -1.0
	sim.lives = 1000
	sim.start_next_wave()
	return sim


## Steps until `type` is among the events; returns all events seen.
func _until(sim: GameSim, type: StringName, seconds := 60.0) -> Array[Dictionary]:
	var seen: Array[Dictionary] = []
	for _i in int(seconds / GameSim.DT):
		sim.step()
		var got := sim.drain_events()
		seen.append_array(got)
		if got.any(func(e: Dictionary) -> bool: return e.type == type):
			break
	return seen


func _count(events: Array[Dictionary], type: StringName) -> int:
	return events.filter(func(e: Dictionary) -> bool: return e.type == type).size()


func _run(sim: GameSim, seconds: float) -> Array[Dictionary]:
	var seen: Array[Dictionary] = []
	for _i in int(seconds / GameSim.DT):
		sim.step()
		seen.append_array(sim.drain_events())
	return seen


func test_eletd_leak_holds_interest_until_the_field_is_clear() -> void:
	var sim := _leaking_wave(&"eletd")
	var before := _until(sim, &"leaked", 19.0)
	check_eq(_count(before, &"leaked"), 0, "no leak yet")
	var running := sim.interest_timer
	var t0 := sim.time
	before = _until(sim, &"leaked")
	check_eq(_count(before, &"interest_locked"), 1, "the first leak locks interest")
	var held := sim.interest_timer
	check_near(held, running - (sim.time - t0), 1e-3, "the lock keeps the timer, no reset")
	var gold := sim.gold
	var during := _run(sim, 40.0)
	check(_count(during, &"leaked") > 1, "creeps keep leaking")
	check_eq(_count(during, &"interest"), 0, "nothing paid while locked")
	check_eq(_count(during, &"interest_locked"), 0, "later leaks don't lock again")
	check_eq(sim.gold, gold, "no gold while locked")
	check_near(sim.interest_timer, held, 1e-6, "the timer stands still")
	for c: SimCreep in sim.creeps.duplicate():
		sim.kill(c)
	var cleared := _until(sim, &"wave_cleared", 1.0)
	check_eq(sim.phase, GameSim.Phase.BUILD, "field clear")
	check_eq(_count(cleared, &"interest_unlocked"), 1, "unlocked when the field is clear")
	check(not sim.interest_locked, "unlocked")
	var resumed := _run(sim, held - 0.1)
	check_eq(_count(resumed, &"interest"), 0, "the timer resumed where it stopped")
	resumed = _run(sim, 0.2)
	check_eq(_count(resumed, &"interest"), 1, "and pays when it runs out")


func test_classic_leaks_never_lock_interest() -> void:
	var sim := _leaking_wave(&"classic")
	_until(sim, &"leaked")
	var after := _run(sim, GameSim.INTEREST_PERIOD + 0.1)
	check_eq(_count(after, &"interest"), 1, "interest pays through leaks")
	check(not sim.interest_locked, "never locked")
	check_eq(_count(after, &"interest_locked"), 0, "no lock event")


func test_each_rule_set_offers_its_difficulties() -> void:
	check_eq(EletdRules.difficulties(&"classic"), [&"normal", &"hard"], "classic")
	check_eq(
		EletdRules.difficulties(&"eletd"), [&"easy", &"normal", &"hard", &"very_hard"], "eletd"
	)
	check_eq(TowerInfo.mode_name(&"very_hard", false, true), "Very Hard · Twists", "name")
	check_eq(TowerInfo.mode_name(&"hard", true), "Hard · Infinite", "classic name kept")


func test_eletd_difficulties_climb_in_creep_hp() -> void:
	var sims := {}
	for level: StringName in EletdRules.DIFFICULTIES:
		sims[level] = GameSim.new()
		sims[level].rules = &"eletd"
		sims[level].difficulty = level
	for w: int in [1, 10, 20, 30, 40]:
		var hp := {}
		for level: StringName in sims:
			for type: StringName in [&"grunt", &"footman"]:
				hp[[level, type]] = sims[level].spawn_creep(type, &"flame", w, Vector2.ZERO).max_hp
		for type: StringName in [&"grunt", &"footman"]:
			var normal: float = hp[[&"normal", type]]
			check_near(hp[[&"easy", type]], normal * 0.75, 1e-3, "Easy is 0.75, w%d" % w)
			var f := (w - 1) / 39.0
			var hard := lerpf(EletdRules.HARD_FROM, EletdRules.HARD_TO, f)
			check_near(hp[[&"hard", type]], normal * hard, 1e-3, "Hard ramp, w%d" % w)
			var very := lerpf(EletdRules.VERY_HARD_FROM, EletdRules.VERY_HARD_TO, f)
			check_near(hp[[&"very_hard", type]], normal * very, 1e-3, "Very Hard ramp, w%d" % w)
			check(hp[[&"very_hard", type]] > hp[[&"hard", type]], "Very Hard > Hard, w%d" % w)
			check(hp[[&"easy", type]] < normal, "Easy < Normal, w%d" % w)


func test_score_follows_the_difficulty() -> void:
	var want := {&"easy": 0.7, &"normal": 1.0, &"hard": 1.3, &"very_hard": 1.6}
	for level: StringName in want:
		var sim := GameSim.new()
		sim.rules = &"eletd"
		sim.difficulty = level
		sim.kills = 100
		sim.gold = 1000
		check_eq(sim.score(), roundi((1000 + 10_000 + 1000) * want[level]), "eletd %s" % level)
	var classic := GameSim.new()
	classic.kills = 100
	classic.gold = 1000
	classic.hard = true
	check_eq(classic.difficulty, &"hard", "setting hard picks Hard")
	check_eq(classic.score(), roundi(12_000 * 1.3), "classic Hard ×1.3")


## Released keys must never move, or players lose their records.
func test_each_difficulty_keeps_its_own_records() -> void:
	var kept := {
		["normal", false, false, &"classic"]: "normal",
		["hard", false, false, &"classic"]: "hard",
		["hard", true, true, &"classic"]: "hard_twists_infinite",
		["normal", false, false, &"eletd"]: "normal_eletd",
		["hard", false, false, &"eletd"]: "hard_eletd",
		["hard", true, false, &"eletd"]: "hard_infinite_eletd",
	}
	for k: Array in kept:
		var key := Save.mode_key(StringName(k[0]), k[1], k[2], MapDefs.DEFAULT, k[3])
		check_eq(key, kept[k], "kept")
	var keys := {}
	for level: StringName in EletdRules.DIFFICULTIES:
		var sim := GameSim.new(&"rampart")
		sim.rules = &"eletd"
		sim.difficulty = level
		keys[Save.sim_key(sim)] = level
	check_eq(keys.size(), 4, "four difficulties, four keys")
	check(keys.has("rampart_easy_eletd"), "Easy key")
	check(keys.has("rampart_very_hard_eletd"), "Very Hard key")
