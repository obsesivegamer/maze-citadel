extends "res://tests/test_case.gd"

const R := Placement.Result


func _run(sim: GameSim, seconds: float) -> void:
	for _i in int(seconds / GameSim.DT):
		sim.step()


func test_first_frame_state() -> void:
	var sim := GameSim.new()
	check_eq(sim.gold, 220, "gold")
	check_eq(sim.lives, 20, "lives")
	check_eq(sim.phase, GameSim.Phase.BUILD, "phase")
	check_eq(WaveDefs.spawn_list(1).size(), 10, "wave 1 size")
	check(WaveDefs.spawn_list(1).all(func(e: Array) -> bool: return e[0] == &"grunt"), "grunts")


func test_opener_buys_eight_archers() -> void:
	var sim := GameSim.new()
	var built := 0
	for col in range(0, 20, 2):
		if sim.build(Vector2i(col, 6), &"archer") == R.OK:
			built += 1
	check_eq(built, 8, "archers from 220 gold")
	check_eq(sim.gold, 20, "change")
	check_eq(sim.build(Vector2i(1, 20), &"archer"), R.NO_GOLD, "ninth refused")


func test_sell_refunds_75_percent_and_reopens_tile() -> void:
	var sim := GameSim.new()
	sim.build(Vector2i(4, 4), &"cannon")
	check_eq(sim.gold, 160, "after build")
	check_eq(sim.sell(Vector2i(4, 4)), 45, "refund")
	check_eq(sim.gold, 205, "after sell")
	check(sim.grid.is_walkable(Vector2i(4, 4)), "tile open again")
	check_eq(sim.sell(Vector2i(4, 4)), 0, "nothing left to sell")


func test_opening_countdown_starts_wave_one() -> void:
	var sim := GameSim.new()
	_run(sim, GameSim.OPENING_BUILD_TIME - 1.0)
	check_eq(sim.wave, 0, "still building")
	_run(sim, 1.5)
	check_eq(sim.wave, 1, "wave 1 started")
	_run(sim, 10.0)
	var spawned := sim.drain_events().filter(func(e): return e.type == &"spawned").size()
	check_eq(spawned, 10, "all ten spawned within 10 s")


func test_leaks_cost_lives_and_loop_back() -> void:
	var sim := GameSim.new()
	sim.start_next_wave()
	_run(sim, 21.0)
	check(sim.lives < 20, "first grunt leaked")
	var leaked := sim.creeps.filter(func(c: SimCreep) -> bool: return c.leaked)
	check(not leaked.is_empty(), "leaked creep still on the board")
	check(leaked.all(func(c: SimCreep) -> bool: return c.pos.y < 20.0), "back near the portal")
	_run(sim, 120.0)
	check_eq(sim.phase, GameSim.Phase.DEFEAT, "endless leaking ends the game")
	check_eq(sim.lives, 0, "lives floor at 0")


func test_killing_pays_bounty_unless_leaked() -> void:
	var sim := GameSim.new()
	sim.start_next_wave()
	_run(sim, 1.0)
	var c: SimCreep = sim.creeps[0]
	sim.kill(c)
	check_eq(sim.gold, 220 + CreepDefs.bounty(1), "bounty paid")
	_run(sim, 21.0)
	var looped := sim.creeps.filter(func(x: SimCreep) -> bool: return x.leaked)
	var gold_before := sim.gold
	sim.kill(looped[0])
	check_eq(sim.gold, gold_before, "no bounty after a leak")


func test_creeps_walk_the_maze_and_reroute() -> void:
	var sim := GameSim.new()
	for i in 4:
		var gap := Grid.COLS - 1 if i % 2 == 0 else 0
		for col in Grid.COLS:
			if col != gap:
				sim.gold = 1000
				sim.build(Vector2i(col, 5 + i * 5), &"archer")
	sim.start_next_wave()
	var rerouted := false
	for frame in int(40.0 / GameSim.DT):
		sim.step()
		if frame == 300:
			sim.sell(Vector2i(10, 10))
			rerouted = true
		for c in sim.creeps:
			var t := Grid.tile_at(c.pos)
			if Grid.in_bounds(t) and sim.grid.is_blocked(t):
				failures.append("creep %d inside tower tile %s" % [c.id, t])
				return
	check(rerouted, "sold mid-wave")
	check_eq(sim.lives, 20, "the long maze delays every leak past 40 s")


func test_build_refused_on_creep() -> void:
	var sim := GameSim.new()
	sim.start_next_wave()
	_run(sim, 4.0)
	var t := Grid.tile_at(sim.creeps[0].pos)
	check_eq(sim.build(t, &"archer"), R.CREEP_ON_TILE, "creep tile refused")
	check_eq(sim.gold, 220, "nothing spent")


## Classic gives 5 s between waves; eletd gives 30 s to plan, and N still
## calls the next wave early.
func test_breather_follows_the_rules() -> void:
	for rules in GameSim.RULES:
		var sim := GameSim.new()
		sim.rules = rules
		sim.gold = 1000
		sim.elements.apply_picks([&"stone"])
		sim.build(Vector2i(2, 20), &"runesmith")
		sim.start_next_wave()
		_run(sim, 12.0)
		for c: SimCreep in sim.creeps.duplicate():
			sim.hit(c, 1e9, sim.tower_at(Vector2i(2, 20)), 0.0)
		sim.step()
		var want := 30.0 if rules == &"eletd" else 5.0
		check_eq(sim.phase, GameSim.Phase.BUILD, "%s: wave 1 cleared" % rules)
		check_near(sim.countdown, want, 0.1, "%s breather" % rules)
		_run(sim, want - 1.0)
		check_eq(sim.wave, 1, "%s: still waiting" % rules)
		_run(sim, 1.5)
		check_eq(sim.wave, 2, "%s: wave 2 starts on its own" % rules)
	var early := GameSim.new()
	early.rules = &"eletd"
	early.start_next_wave()
	early.start_next_wave()
	check_eq(early.wave, 2, "N calls the next wave during a wave")
