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


func test_attack_vs_class_table_matches_gdd() -> void:
	var expected := {
		&"pierce": [1.5, 0.6, 1.75, 0.8],
		&"siege": [1.0, 1.75, 0.0, 1.0],
		&"magic": [1.0, 1.25, 1.0, 0.75],
		&"poison": [1.0, 1.0, 1.0, 1.0],
		&"rune": [1.0, 1.0, 1.0, 1.0],
	}
	for attack in expected:
		for i in CLASSES.size():
			check_near(Damage.class_mult(attack, CLASSES[i]), expected[attack][i], 1e-6, attack)


func test_element_wheel_has_one_strong_and_one_weak_each() -> void:
	for a in Damage.WHEEL:
		var strong := 0
		var weak := 0
		for d in Damage.WHEEL:
			var m := Damage.element_mult(a, d)
			strong += 1 if m == 2.0 else 0
			weak += 1 if m == 0.5 else 0
		check(strong == 1 and weak == 1, "%s: %d strong, %d weak" % [a, strong, weak])
	check_eq(Damage.element_mult(&"light", &"dark"), 2.0, "light beats dark")
	check_eq(Damage.element_mult(&"stone", &"light"), 2.0, "stone beats light")
	check_eq(Damage.element_mult(&"light", &"stone"), 0.5, "light weak vs stone")
	check_eq(Damage.element_mult(&"aqua", &"flame"), 2.0, "aqua beats flame")


func test_armor_curve() -> void:
	check_near(Damage.armor_factor(0.0), 1.0)
	check_near(Damage.armor_factor(6.0), 1.0 - 0.36 / 1.36)
	check_near(Damage.armor_factor(-10.0), 2.0 - pow(0.94, 10.0))


## Expected values come from GDD §6 written out by hand, not from Damage, so
## a wrong table or wheel in the code can't agree with itself.
func test_every_tower_counter_cell_is_applied() -> void:
	var class_table := {
		&"pierce": [1.5, 0.6, 1.75, 0.8],
		&"siege": [1.0, 1.75, 0.0, 1.0],
		&"magic": [1.0, 1.25, 1.0, 0.75],
		&"poison": [1.0, 1.0, 1.0, 1.0],
		&"rune": [1.0, 1.0, 1.0, 1.0],
	}
	var beats := {
		&"light": &"dark",
		&"dark": &"aqua",
		&"aqua": &"flame",
		&"flame": &"verdant",
		&"verdant": &"stone",
		&"stone": &"light",
	}
	for id in TowerDefs.BUILD_ORDER + TowerDefs.EPICS:
		if TowerDefs.stat(id, "kind") == &"aura":
			continue
		var attack: StringName = TowerDefs.stat(id, "attack")
		var element: StringName = TowerDefs.stat(id, "element")
		for i in CLASSES.size():
			for creep_element in beats:
				var c := SimCreep.new()
				c.armor_class = CLASSES[i]
				c.element = creep_element
				var elem := 1.0
				if beats[element] == creep_element:
					elem = 2.0
				elif beats[creep_element] == element:
					elem = 0.5
				var want: float = 100.0 * class_table[attack][i] * elem
				var got := Damage.amount(100.0, attack, element, c, 0.0, 0.0)
				check_near(got, want, 1e-3, "%s vs %s/%s" % [id, CLASSES[i], creep_element])


func test_archer_kills_and_pays_bounty() -> void:
	var sim := _sim_with(&"grunt", Grid.center(Vector2i(10, 10)))
	_place(sim, Vector2i(12, 10), &"archer")
	var gold := sim.gold
	_run(sim, 20.0)
	check_eq(sim.kills, 1, "grunt killed")
	check(sim.gold >= gold + CreepDefs.bounty(1), "bounty paid")


func test_siege_never_targets_air() -> void:
	var sim := _sim_with(&"harpy", Grid.center(Vector2i(10, 10)))
	var t := _place(sim, Vector2i(12, 10), &"cannon")
	_run(sim, 5.0)
	check_eq(t.shots, 0, "cannon held fire")
	var archer := _place(sim, Vector2i(12, 12), &"archer")
	_run(sim, 2.0)
	check(archer.shots > 0, "archer shoots air")


func test_frost_slows_and_bosses_shrug_half() -> void:
	var sim := _sim_with(&"grunt", Grid.center(Vector2i(10, 10)))
	_place(sim, Vector2i(12, 10), &"frost")
	_run(sim, 1.0)
	var c: SimCreep = sim.creeps[0]
	check_near(c.slow, 0.35, 1e-6, "35% slow")
	check(c.slow_time > 1.0, "lasts ~2 s")
	var boss := sim.spawn_creep(&"ogre", &"flame", 10, Grid.center(Vector2i(10, 11)))
	sim.apply_slow(boss, 0.35, 2.0)
	check_near(boss.slow_time, 1.0, 1e-6, "boss half duration")
	sim.apply_root(boss, 1.0)
	check_eq(boss.root_time, 0.0, "bosses can't be rooted")


func test_poison_stacks_to_five_and_ignores_armor() -> void:
	var sim := _sim_with(&"footman", Grid.center(Vector2i(10, 10)), &"verdant", 30)
	var c: SimCreep = sim.creeps[0]
	_place(sim, Vector2i(12, 10), &"plague")
	_run(sim, 12.0)
	check(c.poison.size() <= 5, "max 5 stacks, got %d" % c.poison.size())
	check(c.poison.size() >= 4, "stacks build up")
	var expected_per_s := 6.0 * c.poison.size()
	var before := c.hp
	sim.step()
	check_near((before - c.hp) / GameSim.DT, expected_per_s, 0.5, "full dps through 6 armor")


func test_runesmith_shred_caps_at_ten() -> void:
	var sim := _sim_with(&"steam_tank", Grid.center(Vector2i(10, 10)), &"flame", 30)
	_place(sim, Vector2i(12, 10), &"runesmith")
	_run(sim, 9.0)
	var c: SimCreep = sim.creeps[0]
	check_near(c.shred, 10.0, 1e-6, "shred capped")
	check(c.effective_armor() == 0.0, "10 armor fully stripped")


func test_bard_aura_is_highest_not_summed() -> void:
	var sim := GameSim.new()
	var archer := _place(sim, Vector2i(5, 5), &"archer")
	_place(sim, Vector2i(6, 5), &"bard")
	check_near(archer.aura, 0.15, 1e-6, "L1 aura")
	_place(sim, Vector2i(4, 5), &"bard", 3)
	check_near(archer.aura, 0.25, 1e-6, "strongest wins")
	check_near(archer.haste, 0.1, 1e-6, "L3 haste")
	sim.sell(Vector2i(4, 5))
	check_near(archer.aura, 0.15, 1e-6, "falls back after sell")


func test_upgrade_costs_and_refund() -> void:
	var sim := GameSim.new()
	sim.build(Vector2i(3, 3), &"archer")
	check(sim.upgrade(Vector2i(3, 3)), "to L2")
	check(sim.upgrade(Vector2i(3, 3)), "to L3")
	check(not sim.upgrade(Vector2i(3, 3)), "no L4")
	check_eq(sim.tower_at(Vector2i(3, 3)).invested, 75, "25 + 15 + 35")
	check_eq(sim.gold, 145, "paid")
	check_eq(sim.sell(Vector2i(3, 3)), 56, "75% of 75")


func test_fusion_rules() -> void:
	var sim := GameSim.new()
	_place(sim, Vector2i(3, 3), &"frost", 3)
	_place(sim, Vector2i(8, 3), &"roots", 3)
	_place(sim, Vector2i(3, 8), &"cannon", 3)
	_place(sim, Vector2i(8, 8), &"frost", 2)
	check_eq(sim.fusion_result(Vector2i(3, 3), Vector2i(3, 8)), &"", "mixed families")
	check_eq(sim.fusion_result(Vector2i(3, 3), Vector2i(8, 8)), &"", "not max level")
	check_eq(sim.fusion_result(Vector2i(3, 3), Vector2i(8, 3)), &"frost_wyrm", "elven pair")
	var invested: int = (
		sim.tower_at(Vector2i(3, 3)).invested + sim.tower_at(Vector2i(8, 3)).invested
	)
	sim.gold = 100
	check(sim.fuse(Vector2i(3, 3), Vector2i(8, 3)), "fused")
	check_eq(sim.gold, 0, "fuse cost 100")
	var epic := sim.tower_at(Vector2i(3, 3))
	check_eq(epic.id, &"frost_wyrm", "epic in place")
	check_eq(epic.invested, invested + 100, "investment carried")
	check(sim.grid.is_walkable(Vector2i(8, 3)), "second tile freed")


func test_ballista_bolt_pierces_three() -> void:
	var sim := GameSim.new()
	sim.countdown = -1.0
	for i in 5:
		var c := sim.spawn_creep(&"grunt", &"flame", 20, Grid.center(Vector2i(10, 6 + i)))
		c.speed = 0.0
	var t := _place(sim, Vector2i(10, 2), &"ballista")
	t.cooldown = 0.0
	_run(sim, 0.6)
	var damaged := sim.creeps.filter(func(c: SimCreep) -> bool: return c.hp < c.max_hp)
	check_eq(damaged.size(), 3, "one bolt, three creeps")


func test_cannon_splash_falls_off() -> void:
	var sim := GameSim.new()
	sim.countdown = -1.0
	var center := sim.spawn_creep(&"footman", &"flame", 30, Grid.center(Vector2i(10, 10)))
	var edge := sim.spawn_creep(
		&"footman", &"flame", 30, Grid.center(Vector2i(10, 10)) + Vector2(2.0, 0)
	)
	var outside := sim.spawn_creep(&"footman", &"flame", 30, Grid.center(Vector2i(10, 13)))
	for c in [center, edge, outside]:
		c.speed = 0.0
	_place(sim, Vector2i(10, 7), &"cannon")
	_run(sim, 0.8)
	var dc := center.max_hp - center.hp
	var de := edge.max_hp - edge.hp
	check(dc > 0.0, "centre hit")
	check(de > 0.0 and de < dc, "edge takes less (%.1f < %.1f)" % [de, dc])
	check_eq(outside.hp, outside.max_hp, "outside untouched")


func test_roots_nova_roots_ground_only() -> void:
	var sim := _sim_with(&"grunt", Grid.center(Vector2i(10, 10)))
	var harpy := sim.spawn_creep(&"harpy", &"flame", 1, Grid.center(Vector2i(11, 11)))
	harpy.speed = 0.0
	_place(sim, Vector2i(11, 10), &"roots")
	sim.step()
	var g: SimCreep = sim.creeps[0]
	check(g.root_time > 0.0 and g.slow > 0.0, "grunt rooted and slowed")
	check_eq(harpy.hp, harpy.max_hp, "harpy untouched")
