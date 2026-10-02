extends "res://tests/test_case.gd"

const CLASSES: Array[StringName] = [&"light", &"armored", &"air", &"boss"]


## A sim with one creep parked at `pos` (speed 0) and nothing spawning.
func _sim_with(type: StringName, pos: Vector2, element := &"flame", w := 1) -> GameSim:
	var sim := GameSim.new()
	sim.countdown = -1.0
	var c := sim.spawn_creep(type, element, w, pos)
	c.speed = 0.0
	return sim


func _run(sim: GameSim, seconds: float) -> void:
	for _i in int(seconds / GameSim.DT):
		sim.step()


func _place(sim: GameSim, tile: Vector2i, id: StringName, level := 1) -> SimTower:
	sim.gold = 100000
	sim.build(tile, id)
	while sim.tower_at(tile).level < level:
		sim.upgrade(tile)
	return sim.tower_at(tile)


func test_interest_two_percent_capped() -> void:
	var sim := GameSim.new()
	sim.countdown = -1.0
	_run(sim, 15.05)
	check_eq(sim.gold, 224, "2% of 220")
	sim.gold = 5000
	_run(sim, 15.0)
	check_eq(sim.gold, 5020, "capped at 20")


func test_ghoul_revives_once_then_pays() -> void:
	var sim := _sim_with(&"ghoul", Grid.center(Vector2i(10, 10)))
	var c: SimCreep = sim.creeps[0]
	var t := _place(sim, Vector2i(12, 10), &"archer")
	sim.hit(c, 10000.0, t, 0.0)
	check(c.alive and c.revive_time > 0.0, "downed, not dead")
	check(not c.targetable(), "untargetable while down")
	var gold := sim.gold
	_run(sim, 1.6)
	check(c.targetable(), "back up")
	check(c.hp <= c.max_hp / 3.0 + 0.01 and c.hp > c.max_hp / 3.0 - 30.0, "a third of HP")
	sim.hit(c, 10000.0, t, 0.0)
	check(not c.alive, "stays dead")
	check_eq(sim.gold, gold + CreepDefs.bounty(1), "bounty on final death only")


func test_steam_tank_immunity_window() -> void:
	var sim := _sim_with(&"steam_tank", Grid.center(Vector2i(10, 10)), &"flame", 7)
	var c: SimCreep = sim.creeps[0]
	var t := _place(sim, Vector2i(2, 2), &"archer")
	_run(sim, 6.1)
	check(c.immune_time > 0.0, "immune after 6 s")
	var hp := c.hp
	sim.hit(c, 500.0, t, 0.0)
	sim.apply_slow(c, 0.35, 2.0)
	check_eq(c.hp, hp, "no damage while immune")
	check_eq(c.slow, 0.0, "no slow while immune")
	_run(sim, 1.6)
	check_eq(c.immune_time, 0.0, "window over")


func test_priestess_heals_and_poison_halves_it() -> void:
	var sim := _sim_with(&"priestess", Grid.center(Vector2i(10, 10)))
	var a := sim.spawn_creep(&"grunt", &"flame", 1, Grid.center(Vector2i(11, 10)))
	var b := sim.spawn_creep(&"grunt", &"flame", 1, Grid.center(Vector2i(10, 11)))
	for c in [a, b]:
		c.speed = 0.0
		c.hp = c.max_hp * 0.5
	b.poison.append(Vector2(0.0, 30.0))
	b.poison_src.append(null)
	_run(sim, 2.05)
	check_near(a.hp, a.max_hp * 0.54, 0.01, "4% heal")
	check_near(b.hp, b.max_hp * 0.52, 0.01, "2% heal when poisoned")


func test_ogre_aura_buffs_escorts() -> void:
	var sim := _sim_with(&"ogre", Grid.center(Vector2i(10, 10)), &"flame", 10)
	var near := sim.spawn_creep(&"grunt", &"flame", 10, Grid.center(Vector2i(11, 10)))
	var far := sim.spawn_creep(&"grunt", &"flame", 10, Grid.center(Vector2i(1, 25)))
	var twin := sim.spawn_creep(&"ogre", &"flame", 10, Grid.center(Vector2i(9, 10)))
	near.speed = 0.0
	far.speed = 0.0
	twin.speed = 0.0
	sim.step()
	check_eq(near.aura_armor, 3.0, "escort +3 armor")
	check_eq(far.aura_armor, 0.0, "out of range")
	check_eq(twin.aura_armor, 0.0, "bosses don't buff each other")
	check_eq(twin.aura_haste, 0.0, "no boss haste either")


func test_dreadlord_summons_felhounds() -> void:
	var sim := _sim_with(&"dreadlord", Grid.center(Vector2i(10, 14)), &"dark", 40)
	_run(sim, 10.1)
	var hounds := sim.creeps.filter(func(c: SimCreep) -> bool: return c.type == &"felhound")
	check_eq(hounds.size(), 3, "three felhounds")


func test_hard_and_infinite_scaling() -> void:
	var sim := GameSim.new()
	sim.hard = true
	var c := sim.spawn_creep(&"grunt", &"flame", 1, Vector2.ZERO)
	check_near(c.max_hp, 60.0 * 1.1, 1e-3, "hard HP +10% on wave 1")
	check_eq(c.bounty, 6, "no hard bounty bonus")
	var late := sim.spawn_creep(&"grunt", &"flame", 40, Vector2.ZERO)
	check_near(late.max_hp, CreepDefs.max_hp(&"grunt", 40) * 1.4, 1e-2, "hard HP +40% on wave 40")
	var mid := sim.spawn_creep(&"grunt", &"flame", 20, Vector2.ZERO)
	check(mid.max_hp > CreepDefs.max_hp(&"grunt", 20) * 1.2, "hard HP ramps")
	check(mid.max_hp < CreepDefs.max_hp(&"grunt", 20) * 1.3, "hard HP ramps")
	sim.hard = false
	var inf := sim.spawn_creep(&"grunt", &"flame", 42, Vector2.ZERO)
	check_near(inf.max_hp, CreepDefs.max_hp(&"grunt", 42) * pow(1.08, 2), 1e-2, "infinite HP")
	check(not WaveDefs.spawn_list(41).is_empty(), "wave 41 exists")


func test_wave_table_shape() -> void:
	check_eq(WaveDefs.count(), 40, "40 waves")
	for w in range(1, 41):
		var n := WaveDefs.spawn_list(w).size()
		check(n >= 8 and n <= 24, "wave %d has %d creeps" % [w, n])
		check_eq(WaveDefs.has_boss(w), w % 10 == 0, "boss on wave %d" % w)
	var harpy_waves := range(1, 41).filter(
		func(w: int) -> bool: return WaveDefs.spawn_list(w).any(func(e): return e[0] == &"harpy")
	)
	check(harpy_waves.size() >= 8, "plenty of air waves")


func test_poisoned_ghoul_going_down_mid_tick() -> void:
	var sim := _sim_with(&"ghoul", Grid.center(Vector2i(10, 10)))
	var c: SimCreep = sim.creeps[0]
	for i in 3:
		c.poison.append(Vector2(100000.0, 5.0))
		c.poison_src.append(null)
	sim.step()
	check(c.alive and c.revive_time > 0.0, "downed by poison, stacks cleared safely")
	check(c.poison.is_empty(), "no stacks left")


func test_boss_waves_scale_their_boss() -> void:
	var base := 60.0 * pow(CreepDefs.HP_GROWTH, 9) * CreepDefs.CREEPS[&"ogre"].hp
	check_near(CreepDefs.max_hp(&"ogre", 10), base * 2.2, 1e-2, "wave 10 Ogre ×2.2")
	check_near(CreepDefs.max_hp(&"grunt", 10), base / 12.0, 1e-2, "escorts unscaled")
	var ogre30 := 60.0 * pow(CreepDefs.HP_GROWTH, 29) * CreepDefs.CREEPS[&"ogre"].hp
	check_near(CreepDefs.max_hp(&"ogre", 30), ogre30 * 0.9, 1e-2, "wave 30 Ogres ×0.9")
	var dread := 60.0 * pow(CreepDefs.HP_GROWTH, 39) * CreepDefs.CREEPS[&"dreadlord"].hp
	check_near(CreepDefs.max_hp(&"dreadlord", 40), dread, 1e-2, "Dreadlord as listed")
