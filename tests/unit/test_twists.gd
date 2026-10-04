extends "res://tests/test_case.gd"
## Twists mode (WaveTwists): the seeded schedule and its fairness rules, and
## what each twist does to a creep. With the mode off nothing changes.

const SEEDS := 300
const LAST := 120


func _sim(seed_value: int) -> GameSim:
	var sim := GameSim.new()
	sim.countdown = -1.0
	sim.twists = true
	sim.twist_seed = seed_value
	return sim


## The first wave in the table that carries `twist` under some seed, and that seed.
func _wave_with(twist: StringName) -> Array:
	for s in range(1, SEEDS):
		var p := WaveTwists.plan(s, 39)
		for w in p:
			if p[w] == twist:
				return [s, w]
	return [0, 0]


func test_same_seed_same_schedule_and_seeds_differ() -> void:
	check_eq(WaveTwists.plan(42, LAST), WaveTwists.plan(42, LAST), "deterministic")
	var distinct := {}
	for s in range(1, 21):
		distinct[str(WaveTwists.plan(s, 39))] = true
	check(distinct.size() >= 15, "20 seeds give %d schedules" % distinct.size())


func test_schedule_follows_the_fairness_rules() -> void:
	var seen := {}
	for s in range(1, SEEDS):
		var p := WaveTwists.plan(s, LAST)
		var previous: StringName = &""
		for w in range(1, LAST + 1):
			var t: StringName = p.get(w, &"")
			if t == &"":
				continue
			seen[t] = seen.get(t, 0) + 1
			check(w >= WaveTwists.FIRST_WAVE, "seed %d: twist on wave %d" % [s, w])
			check(not WaveDefs.has_boss(w), "seed %d: twist on boss wave %d" % [s, w])
			check(WaveTwists.eligible(t, w), "seed %d: %s not allowed on wave %d" % [s, t, w])
			check(t != previous, "seed %d: %s twice in a row at wave %d" % [s, t, w])
			previous = t
	for t in WaveTwists.ORDER:
		check(seen.get(t, 0) > 0, "%s comes up" % t)
	for w in [22, 23, 33, 38]:
		check(not WaveTwists.wave_can_twist(w), "all-Armored wave %d stays clean" % w)
	check(not WaveTwists.eligible(&"undying", 6), "Undying never on Ghoul waves")
	check(not WaveTwists.eligible(&"stampede", 13), "Stampede never on Harpy waves")
	check(not WaveTwists.eligible(&"swift", 14), "Swift never on Wolf Rider waves")
	check(not WaveTwists.eligible(&"plated", 12), "Plated not before wave 15")


func test_most_waves_from_eleven_get_a_twist() -> void:
	var p := WaveTwists.plan(7, 39)
	var open := range(WaveTwists.FIRST_WAVE, 40).filter(
		func(w: int) -> bool: return WaveTwists.wave_can_twist(w)
	)
	check(p.size() >= open.size() - 2, "%d of %d open waves twisted" % [p.size(), open.size()])


func test_off_means_no_twists() -> void:
	var sim := GameSim.new()
	sim.twist_seed = 5
	for w in range(1, 60):
		check_eq(sim.twist_for(w), &"", "wave %d" % w)
	var c := sim.spawn_creep(&"grunt", &"flame", 15, Vector2(10, 10))
	check_eq(c.twist, &"", "no twist on creeps")
	check_eq(c.speed, 3.0, "base speed")


func test_swift_and_plated_change_stats() -> void:
	var found := _wave_with(&"swift")
	var sim := _sim(found[0])
	var c := sim.spawn_creep(
		WaveDefs.spawn_list(found[1])[0][0], &"flame", found[1], Vector2(10, 10)
	)
	var base: float = CreepDefs.CREEPS[c.type].speed
	check_near(c.speed, base * WaveTwists.SWIFT_SPEED, 1e-4, "swift speed")
	found = _wave_with(&"plated")
	sim = _sim(found[0])
	c = sim.spawn_creep(WaveDefs.spawn_list(found[1])[0][0], &"flame", found[1], Vector2(10, 10))
	check_near(c.armor, CreepDefs.CREEPS[c.type].armor + WaveTwists.PLATED_ARMOR, 1e-4, "plated")


func test_bosses_never_carry_twists() -> void:
	var found := _wave_with(&"plated")
	var sim := _sim(found[0])
	var ogre := sim.spawn_creep(&"ogre", &"flame", found[1], Vector2(10, 10))
	check_eq(ogre.twist, &"", "boss untouched")
	check_eq(ogre.armor, float(CreepDefs.CREEPS[&"ogre"].armor), "boss armor")


func test_stampede_halves_the_spawn_gap() -> void:
	var found := _wave_with(&"stampede")
	for twisted in [false, true]:
		var sim := GameSim.new()
		sim.twists = twisted
		sim.twist_seed = found[0]
		sim.wave = found[1] - 1
		sim.start_next_wave()
		var times: Array[float] = []
		for _i in 200:
			sim.step()
			for e in sim.drain_events():
				if e.type == &"spawned":
					times.append(sim.time)
		var gap := times[2] - times[1]
		var type: StringName = WaveDefs.spawn_list(found[1])[1][0]
		var fast: bool = CreepDefs.CREEPS[type].speed >= 4.5
		var want := GameSim.FAST_SPAWN_INTERVAL if fast else GameSim.SPAWN_INTERVAL
		if twisted:
			want *= WaveTwists.STAMPEDE_SPAWN
		check_near(gap, want, GameSim.DT + 1e-4, "gap with stampede=%s" % twisted)


func test_unstoppable_ignores_slows_and_roots() -> void:
	var found := _wave_with(&"unstoppable")
	var sim := _sim(found[0])
	var c := sim.spawn_creep(&"grunt", &"flame", found[1], Vector2(10, 10))
	check_eq(c.twist, &"unstoppable", "twisted")
	sim.apply_slow(c, 0.5, 3.0)
	sim.apply_root(c, 1.0)
	check_eq(c.slow, 0.0, "no slow")
	check_eq(c.root_time, 0.0, "no root")


func test_undying_rises_once_at_a_third() -> void:
	var found := _wave_with(&"undying")
	var sim := _sim(found[0])
	var c := sim.spawn_creep(&"grunt", &"flame", found[1], Grid.center(Vector2i(10, 10)))
	c.speed = 0.0
	sim.hit(c, c.max_hp * 10.0, _dummy_tower(), 0.0)
	check(c.alive and c.revive_time > 0.0, "down, not dead")
	check_eq(sim.kills, 0, "no kill yet")
	for _i in int(2.0 / GameSim.DT):
		sim.step()
	check_near(c.hp, c.max_hp / 3.0, 1e-3, "rose at a third")
	sim.hit(c, c.max_hp * 10.0, _dummy_tower(), 0.0)
	check(not c.alive, "second death is final")
	check_eq(sim.kills, 1, "one kill, one bounty")


func test_second_wind_heals_once_and_poison_halves_it() -> void:
	var found := _wave_with(&"second_wind")
	for poisoned in [false, true]:
		var sim := _sim(found[0])
		var c := sim.spawn_creep(&"grunt", &"flame", found[1], Grid.center(Vector2i(10, 10)))
		if poisoned:
			c.poison.append(Vector2(0.0, 10.0))
			c.poison_src.append(null)
		var t := _dummy_tower()
		var dmg := (
			c.max_hp * 0.6 / Damage.amount(1.0, &"rune", &"stone", c, 0.0, c.effective_armor())
		)
		sim.hit(c, dmg, t, 0.0)
		var heal := WaveTwists.SECOND_WIND_HEAL * (0.5 if poisoned else 1.0)
		check_near(c.hp / c.max_hp, 0.4 + heal, 1e-3, "healed (poisoned=%s)" % poisoned)
		var before := c.hp
		sim.hit(c, dmg * 0.2, t, 0.0)
		check(c.hp < before, "only once")


func test_score_and_save_keys() -> void:
	var sim := GameSim.new()
	sim.kills = 100
	var plain := sim.score()
	sim.twists = true
	check_eq(sim.score(), roundi(plain * WaveTwists.SCORE_MULT), "score ×1.1")
	check_eq(Save.mode_key(&"normal", false), "normal", "old key kept")
	check_eq(Save.mode_key(&"hard", true), "hard_infinite", "old key kept")
	check_eq(Save.mode_key(&"hard", true, true), "hard_twists_infinite", "twists key")
	check_eq(Save.sim_key(sim), "normal_twists", "sim key")


## A Runesmith (Rune attack: 100% against every class) to deal exact damage.
func _dummy_tower() -> SimTower:
	var t := SimTower.new()
	t.id = &"runesmith"
	t.tile = Vector2i(0, 0)
	t.pos = Grid.center(t.tile)
	return t
