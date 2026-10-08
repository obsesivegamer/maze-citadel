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
	# Under eletd, the tower's element at full level, as --picks would set it.
	var e := SimElements.element_of(id)
	sim.elements.apply_picks([e, e, e])
	sim.build(tile, id)
	while sim.tower_at(tile).level < level:
		sim.upgrade(tile)
	return sim.tower_at(tile)


func test_attack_vs_class_table_matches_gdd() -> void:
	var expected := {
		&"pierce": [1.5, 0.5, 1.75, 0.7],
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
		&"pierce": [1.5, 0.5, 1.75, 0.7],
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


# --- eletd rules: towers reach only the tiles around them ----------------------


## An eletd sim with one creep parked on `tile`.
func _eletd_with(type: StringName, tile: Vector2i) -> GameSim:
	var sim := _sim_with(type, Grid.center(tile))
	sim.rules = &"eletd"
	return sim


func test_eletd_towers_reach_only_adjacent_tiles() -> void:
	# Every way of attacking: arrow, shell, slow bolt, poison, shred, bolt,
	# crater shell, nova, cloud, cone, lance, plague.
	var attackers: Array[StringName] = [
		&"archer",
		&"cannon",
		&"frost",
		&"plague",
		&"runesmith",
		&"ballista",
		&"demolisher",
		&"roots",
		&"shadow",
	]
	attackers.append_array(TowerDefs.EPICS)
	for id in attackers:
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
			var near := _eletd_with(&"ogre", Vector2i(10, 10))
			var t := _place_any(near, Vector2i(10, 10) + offset, id)
			_run(near, 4.0)
			check(t.shots > 0, "%s attacks a creep at %s" % [id, offset])
		for offset: Vector2i in [Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2), Vector2i(-2, 1)]:
			var far := _eletd_with(&"ogre", Vector2i(10, 10))
			var t := _place_any(far, Vector2i(10, 10) + offset, id)
			_run(far, 4.0)
			check_eq(t.shots, 0, "%s holds fire at %s" % [id, offset])
			check_eq(far.creeps[0].hp, far.creeps[0].max_hp, "%s: no damage at %s" % [id, offset])


func test_eletd_archer_multishot_stays_adjacent() -> void:
	var sim := _eletd_with(&"ogre", Vector2i(10, 10))
	var far := sim.spawn_creep(&"ogre", &"flame", 1, Grid.center(Vector2i(13, 10)))
	far.speed = 0.0
	_place(sim, Vector2i(11, 10), &"archer", 3)
	_run(sim, 3.0)
	check(sim.creeps[0].hp < sim.creeps[0].max_hp, "adjacent ogre hit")
	check_eq(far.hp, far.max_hp, "second arrow finds nothing two tiles away")


func test_eletd_air_needs_a_tower_under_the_flight() -> void:
	var sim := _eletd_with(&"harpy", Vector2i(10, 10))
	var off := _place(sim, Vector2i(12, 10), &"archer")
	var under := _place(sim, Vector2i(10, 11), &"archer")
	var siege := _place(sim, Vector2i(9, 10), &"cannon")
	_run(sim, 2.0)
	check_eq(off.shots, 0, "archer two tiles from the harpy can't reach it")
	check(under.shots > 0, "archer beside it can")
	check_eq(siege.shots, 0, "siege still never targets air")


func test_eletd_ballista_bolt_still_flies_down_the_lane() -> void:
	var sim := GameSim.new()
	sim.rules = &"eletd"
	sim.countdown = -1.0
	for i in 5:
		var c := sim.spawn_creep(&"ogre", &"flame", 20, Grid.center(Vector2i(10, 4 + i)))
		c.speed = 0.0
	var t := _place(sim, Vector2i(10, 3), &"ballista")
	t.cooldown = 0.0
	_run(sim, 0.6)
	var damaged := sim.creeps.filter(func(c: SimCreep) -> bool: return c.hp < c.max_hp)
	check_eq(damaged.size(), 3, "aimed at the adjacent creep, pierced two behind it")


func test_eletd_creeps_have_less_hp_and_bard_keeps_its_aura() -> void:
	var classic := GameSim.new()
	var sim := GameSim.new()
	sim.rules = &"eletd"
	var a := classic.spawn_creep(&"grunt", &"flame", 5, Vector2.ZERO)
	var b := sim.spawn_creep(&"grunt", &"flame", 5, Vector2.ZERO)
	check_near(b.max_hp, a.max_hp * EletdRules.hp_mult(&"grunt", 5, &"normal"), 1e-4, "HP share")
	var archer := _place(sim, Vector2i(13, 10), &"archer")
	_place(sim, Vector2i(10, 10), &"bard")
	sim.step()
	check(archer.aura > 0.0, "bard buffs a tower three tiles away")


func test_eletd_level3_archer_fires_one_arrow() -> void:
	for rules: StringName in [&"classic", &"eletd"]:
		var sim := _sim_with(&"ogre", Grid.center(Vector2i(10, 10)))
		sim.rules = rules
		sim.spawn_creep(&"ogre", &"flame", 1, Grid.center(Vector2i(12, 10))).speed = 0.0
		_place(sim, Vector2i(11, 10), &"archer", 3)
		_run(sim, 0.3)
		var hit := sim.creeps.filter(func(c: SimCreep) -> bool: return c.hp < c.max_hp)
		check_eq(hit.size(), 1 if rules == &"eletd" else 2, "%s: creeps hit by one volley" % rules)


func test_eletd_starting_gold() -> void:
	var sim := GameSim.new()
	check_eq(sim.gold, GameSim.START_GOLD, "classic")
	sim.rules = &"eletd"
	check_eq(sim.gold, EletdRules.START_GOLD, "eletd")
	sim.rules = &"classic"
	check_eq(sim.gold, GameSim.START_GOLD, "back to classic")


## Builds basic towers, and Epics by fusing two level-3 towers beside `tile`.
func _place_any(sim: GameSim, tile: Vector2i, id: StringName) -> SimTower:
	if not id in TowerDefs.EPICS:
		return _place(sim, tile, id)
	var member: StringName = &""
	for basic in TowerDefs.BUILD_ORDER:
		if TowerDefs.TOWERS[basic].family == TowerDefs.TOWERS[id].family:
			member = basic
			break
	var spare := Vector2i(tile.x, 20)
	_place(sim, tile, member, 3)
	_place(sim, spare, member, 3)
	sim.fuse(tile, spare)
	return sim.tower_at(tile)


## The reach is the 3×3 block of tiles, not a circle: a creep in the far corner
## of a diagonal tile is reached, one just past the block's edge is not.
func test_eletd_reach_is_a_square_of_tiles() -> void:
	var tile := Vector2i(10, 10)
	var cases := [
		[Vector2(23.9, 23.9), true, "far corner of the diagonal tile"],
		[Vector2(23.99, 21.0), true, "just inside the block"],
		[Vector2(24.01, 21.0), false, "just outside the block"],
	]
	for case: Array in cases:
		var sim := _sim_with(&"ogre", case[0])
		sim.rules = &"eletd"
		var t := _place(sim, tile, &"archer")
		_run(sim, 3.0)
		check_eq(t.shots > 0, case[1], case[2])


## Flyers on the Citadel fly the border between two columns; towers the same
## distance either side of it must be treated alike.
func test_eletd_flight_line_is_reached_from_both_sides() -> void:
	var sim := GameSim.new()
	sim.rules = &"eletd"
	sim.countdown = -1.0
	var x := sim.grid.spawn_point.x
	check_eq(x, sim.grid.gate_point.x, "citadel flyers fly straight down")
	var harpy := sim.spawn_creep(&"harpy", &"flame", 1, Vector2(x, Grid.center(Vector2i(0, 12)).y))
	harpy.speed = 0.0
	var col := int(x / Grid.TILE)
	for dx: int in [-2, 1]:
		check(sim.reaches(_place(sim, Vector2i(col + dx, 12), &"archer"), harpy), "column %+d" % dx)
	for dx: int in [-3, 2]:
		check(
			not sim.reaches(_place(sim, Vector2i(col + dx, 12), &"archer"), harpy),
			"column %+d" % dx
		)


func test_eletd_breath_stops_at_the_adjacent_tiles() -> void:
	var sim := _eletd_with(&"ogre", Vector2i(10, 10))
	var behind := sim.spawn_creep(&"ogre", &"flame", 1, Grid.center(Vector2i(10, 8)))
	behind.speed = 0.0
	_place_any(sim, Vector2i(10, 11), &"frost_wyrm")
	_run(sim, 3.0)
	check(sim.creeps[0].hp < sim.creeps[0].max_hp, "adjacent ogre breathed on")
	check_eq(behind.hp, behind.max_hp, "ogre in the cone but three tiles out is untouched")


## Splash is area damage, not targeting: it keeps its radius under eletd.
func test_eletd_splash_keeps_its_radius() -> void:
	var sim := _eletd_with(&"ogre", Vector2i(10, 10))
	var beyond := sim.spawn_creep(&"ogre", &"flame", 1, Grid.center(Vector2i(10, 9)))
	beyond.speed = 0.0
	_place(sim, Vector2i(10, 11), &"cannon")
	_run(sim, 4.0)
	check(beyond.hp < beyond.max_hp, "ogre two tiles from the cannon is splashed")


# --- classic rules keep their ranges -------------------------------------------


func test_classic_demolisher_keeps_its_minimum_range() -> void:
	var sim := _sim_with(&"ogre", Grid.center(Vector2i(10, 10)))
	var close := _place(sim, Vector2i(11, 10), &"demolisher")
	var far := _place(sim, Vector2i(14, 10), &"demolisher")
	_run(sim, 4.0)
	check_eq(close.shots, 0, "can't hit closer than 4 m")
	check(far.shots > 0, "fires from 8 m")


func test_classic_nova_and_cone_use_their_range() -> void:
	var sim := _sim_with(&"grunt", Grid.center(Vector2i(10, 10)))
	_place(sim, Vector2i(12, 10), &"roots")
	sim.step()
	check(sim.creeps[0].root_time > 0.0, "roots reach two tiles")
	var cone := _sim_with(&"ogre", Grid.center(Vector2i(10, 10)))
	var wyrm := _place_any(cone, Vector2i(13, 10), &"frost_wyrm")
	_run(cone, 3.0)
	check(wyrm.shots > 0 and cone.creeps[0].slow > 0.0, "breath reaches three tiles")
