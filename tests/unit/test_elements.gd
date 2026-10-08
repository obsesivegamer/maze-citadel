extends "res://tests/test_case.gd"
## Element picks and Guardians under eletd (GDD §5.0). Expected values are
## written out from the rules, not read from SimElements.

## Each tower's element, from GDD §6.2; Archer, Cannon and Bard need none.
const NEEDS := {
	&"frost": &"aqua",
	&"plague": &"dark",
	&"runesmith": &"stone",
	&"ballista": &"light",
	&"demolisher": &"flame",
	&"roots": &"verdant",
	&"shadow": &"dark",
}
const FREE: Array[StringName] = [&"archer", &"cannon", &"bard"]
const R := Placement.Result
## A far corner for the partner of a fusion.
const SPARE := Vector2i(19, 26)


func _eletd() -> GameSim:
	var sim := GameSim.new()
	sim.rules = &"eletd"
	sim.countdown = -1.0
	return sim


func _count(events: Array[Dictionary], type: StringName) -> int:
	return events.filter(func(e: Dictionary) -> bool: return e.type == type).size()


## Plays waves up to `to`, killing every creep (Guardians too) the moment it
## enters, and returns the events.
func _clear_to(sim: GameSim, to: int) -> Array[Dictionary]:
	var seen: Array[Dictionary] = []
	while sim.wave < to and sim.phase != GameSim.Phase.VICTORY:
		sim.start_next_wave()
		seen.append_array(_play_out(sim))
	return seen


## Steps the waves running now to their end, killing every creep as it enters.
func _play_out(sim: GameSim) -> Array[Dictionary]:
	var seen: Array[Dictionary] = []
	while sim.phase == GameSim.Phase.WAVE:
		sim.step()
		for c: SimCreep in sim.creeps.duplicate():
			sim.kill(c)
		seen.append_array(sim.drain_events())
	return seen


func _guardian(sim: GameSim) -> SimCreep:
	for c in sim.creeps:
		if c.type == &"guardian":
			return c
	return null


## An eletd sim past wave 5 with its free pick spent on `first` and the
## wave-5 pick still to spend.
func _with_second_pick(first: StringName) -> GameSim:
	var sim := _eletd()
	sim.elements.pick(sim, first)
	_clear_to(sim, 5)
	sim.drain_events()
	sim.countdown = -1.0
	return sim


func test_towers_need_their_element_level() -> void:
	for id: StringName in NEEDS:
		var sim := _eletd()
		sim.gold = 100_000
		var e: StringName = NEEDS[id]
		var name := String(e).capitalize()
		var tile := Vector2i(4, 10)
		check_eq(sim.check_build(tile, id), R.LOCKED, "%s locked at level 0" % id)
		check_eq(sim.build(tile, id), R.LOCKED, "%s refused" % id)
		var refused := sim.drain_events().filter(
			func(ev: Dictionary) -> bool: return ev.type == &"build_refused"
		)
		check(refused.size() == 1 and refused[0].reason == R.LOCKED, "%s: refusal event" % id)
		check_eq(sim.elements.needs(id), "Needs %s" % name, "%s reason" % id)
		check(not id in sim.elements.unlocked_towers(), "%s not listed as unlocked" % id)
		for lvl in range(1, 4):
			sim.elements.apply_picks([e])
			if lvl == 1:
				check_eq(sim.build(tile, id), R.OK, "%s builds at %s 1" % [id, e])
				check(id in sim.elements.unlocked_towers(), "%s unlocked" % id)
			else:
				check(sim.upgrade(tile), "%s to level %d at %s %d" % [id, lvl, e, lvl])
			if lvl == 3:
				break
			sim.drain_events()
			check(not sim.upgrade(tile), "%s stays at level %d" % [id, lvl])
			check_eq(sim.tower_at(tile).level, lvl, "%s level" % id)
			var why := "Needs %s level %d" % [name, lvl + 1]
			check_eq(sim.elements.needs(id, lvl + 1), why, "%s upgrade reason" % id)
			var ev := sim.drain_events()
			check(
				ev.size() == 1 and ev[0].type == &"upgrade_refused" and ev[0].needs == why,
				"%s: upgrade_refused event %s" % [id, ev]
			)
		check_eq(sim.tower_at(tile).level, 3, "%s reaches level 3" % id)


func test_starters_bard_and_epics_need_nothing() -> void:
	var sim := _eletd()
	sim.gold = 100_000
	for i in FREE.size():
		var tile := Vector2i(2 + 3 * i, 10)
		check_eq(sim.build(tile, FREE[i]), R.OK, "%s builds" % FREE[i])
		check(sim.upgrade(tile) and sim.upgrade(tile), "%s upgrades to level 3" % FREE[i])
	sim.build(Vector2i(2, 14), &"archer")
	sim.upgrade(Vector2i(2, 14))
	sim.upgrade(Vector2i(2, 14))
	check(sim.fuse(Vector2i(2, 10), Vector2i(2, 14)), "two level-3 Archers fuse with no Light")
	check_eq(sim.tower_at(Vector2i(2, 10)).id, &"sunfire_ballista", "an Epic")


func test_picks_come_at_the_start_and_every_fifth_wave_to_35() -> void:
	var sim := _eletd()
	check_eq(sim.elements.pending_picks(), 1, "one pick at the start")
	var granted_on := []
	for e in _clear_to(sim, 40):
		if e.type == &"pick_granted":
			granted_on.append(e.wave)
	check_eq(granted_on, [5, 10, 15, 20, 25, 30, 35], "waves that grant a pick")
	check_eq(sim.elements.pending_picks(), 8, "eight in all")
	check_eq(sim.phase, GameSim.Phase.VICTORY, "won")
	check(not sim.elements.pick(sim, &"light"), "no pick once the game is over")
	check(sim.creeps.is_empty(), "and no Guardian after victory")
	var endless := _eletd()
	endless.infinite = true
	_clear_to(endless, 50)
	check_eq(endless.elements.pending_picks(), 8, "none after wave 35 in Infinite")


func test_waves_cleared_together_still_grant_their_pick() -> void:
	var sim := _eletd()
	_clear_to(sim, 4)
	sim.start_next_wave()
	sim.start_next_wave()
	var events := _play_out(sim)
	check_eq(sim.wave, 6, "waves 5 and 6 ran together")
	check_eq(_count(events, &"pick_granted"), 1, "wave 5's pick")
	check_eq(sim.elements.pending_picks(), 2, "start + wave 5")


func test_a_pick_comes_when_its_wave_is_cleared_not_when_it_starts() -> void:
	var sim := _eletd()
	_clear_to(sim, 4)
	sim.drain_events()
	sim.start_next_wave()
	sim.step()
	check_eq(_count(sim.drain_events(), &"pick_granted"), 0, "no pick as wave 5 starts")
	check_eq(sim.elements.pending_picks(), 1, "still only the start pick")
	var types := _play_out(sim).map(func(e: Dictionary) -> StringName: return e.type)
	check(types.find(&"wave_cleared") >= 0, "wave 5 cleared")
	check(types.find(&"pick_granted") > types.find(&"wave_cleared"), "its pick comes after")
	check_eq(sim.elements.pending_picks(), 2, "start + wave 5")


func test_first_element_pick_is_free_later_ones_summon() -> void:
	var sim := _eletd()
	check(sim.elements.pick(sim, &"interest"), "interest first")
	sim.drain_events()
	_clear_to(sim, 5)
	sim.drain_events()
	check(sim.elements.pick(sim, &"aqua"), "aqua picked")
	var ev := sim.drain_events()
	check_eq(sim.elements.level(&"aqua"), 1, "the first element pick is granted at once")
	check_eq(_count(ev, &"element_gained"), 1, "element_gained")
	check_eq(_count(ev, &"guardian_spawned"), 0, "no Guardian for it")
	check(sim.creeps.is_empty(), "nothing walks")
	_clear_to(sim, 10)
	sim.drain_events()
	var gold := sim.gold
	check(sim.elements.pick(sim, &"dark"), "dark picked")
	ev = sim.drain_events()
	check_eq(sim.elements.level(&"dark"), 0, "a later pick waits on its Guardian")
	check_eq(sim.elements.pending_level(&"dark"), 1, "dark 1 pending")
	check_eq(_count(ev, &"guardian_spawned"), 1, "guardian_spawned")
	var g := _guardian(sim)
	check(g != null, "a Guardian walks")
	check_eq(sim.phase, GameSim.Phase.BUILD, "summoned between waves")
	check_eq(g.element, &"dark", "of the element it guards")
	check_eq(g.armor_class, &"boss", "boss armor")
	check(g.pos.distance_to(sim.grid.spawn_point) < 0.01, "at the portal")
	var lone_ogre := 60.0 * pow(1.105, 9) * 12.0 * EletdRules.line_hp(10)
	check_near(g.max_hp, lone_ogre * 0.35, 1e-2, "0.35 of a lone wave-10 Ogre")
	sim.kill(g)
	ev = sim.drain_events()
	check_eq(sim.elements.level(&"dark"), 1, "its death grants the level")
	check_eq(sim.elements.pending_level(&"dark"), 0, "no longer pending")
	check_eq(_count(ev, &"element_gained"), 1, "element_gained on death")
	check_eq(sim.gold, gold, "no bounty")


func test_guardian_hp_climbs_with_the_level_it_guards() -> void:
	for lvl in range(1, 4):
		var share: float = [0.35, 0.8, 1.2][lvl - 1]
		var want := 60.0 * pow(1.105, 19) * 12.0 * EletdRules.line_hp(20) * share
		check_near(EletdRules.guardian_hp(lvl, 20, &"normal"), want, 1e-2, "level %d" % lvl)


## Picks are kept, so one can be spent past wave 40 in Infinite: its Guardian
## is still that share of a lone Ogre of the wave it enters on, as the sim
## would spawn the Ogre then (boss-wave tuning aside), at every difficulty.
## Guardians take the share's line without HP_FLOOR, so where the floor holds
## (wave 5) the lone Ogre has more.
func test_guardian_is_a_share_of_the_current_ogre_in_infinite_too() -> void:
	for difficulty in EletdRules.DIFFICULTIES:
		var sim := _eletd()
		sim.infinite = true
		sim.difficulty = difficulty
		for w in [5, 25, 41, 60]:
			sim.wave = w
			var ogre := sim.spawn_creep(&"ogre", &"", w, sim.grid.spawn_point).max_hp
			for lvl in range(1, 4):
				var share: float = [0.35, 0.8, 1.2][lvl - 1]
				var got := EletdRules.guardian_hp(lvl, w, difficulty)
				var unfloored := EletdRules.line_hp(w) / EletdRules.hp(w)
				var label := "%s wave %d level %d" % [difficulty, w, lvl]
				check_near(got / ogre, share * unfloored, 1e-4, label)
		sim.elements.pick(sim, &"aqua")
		sim.elements.granted += 1
		sim.elements.pick(sim, &"dark")
		var lone := sim.spawn_creep(&"ogre", &"", 60, sim.grid.spawn_point).max_hp
		check_near(_guardian(sim).max_hp / lone, 0.35, 1e-4, "%s: summoned on 60" % difficulty)


func test_guardian_leak_costs_three_and_it_walks_again() -> void:
	var sim := _with_second_pick(&"aqua")
	sim.elements.pick(sim, &"flame")
	var g := _guardian(sim)
	var lives := sim.lives
	var leaked := {}
	for _i in 6000:
		sim.step()
		for e in sim.drain_events():
			if e.type == &"leaked":
				leaked = e
		if not leaked.is_empty():
			break
	check_eq(leaked.get("id"), g.id, "the Guardian leaked")
	check_eq(leaked.get("cost"), 3, "a Guardian leak costs 3")
	check_eq(sim.lives, lives - 3, "three lives gone")
	check(g.alive and g in sim.creeps, "it walks again")
	check_eq(sim.elements.level(&"flame"), 0, "no level for a leak")
	sim.kill(g)
	check_eq(sim.elements.level(&"flame"), 1, "granted on its death")


func test_wave_waits_for_its_guardian() -> void:
	var sim := _with_second_pick(&"aqua")
	sim.start_next_wave()
	sim.elements.pick(sim, &"stone")
	var g := _guardian(sim)
	for _i in 1500:
		sim.step()
		for c: SimCreep in sim.creeps.duplicate():
			if c != g:
				sim.kill(c)
	check_eq(sim.phase, GameSim.Phase.WAVE, "wave 6 not cleared while the Guardian lives")
	sim.kill(g)
	sim.step()
	check_eq(sim.phase, GameSim.Phase.BUILD, "cleared once it dies")


func test_a_pending_level_blocks_a_second_pick_on_that_element() -> void:
	var sim := _with_second_pick(&"aqua")
	_clear_to(sim, 10)
	check_eq(sim.elements.pending_picks(), 2, "two picks in hand")
	check(sim.elements.pick(sim, &"aqua"), "aqua 2 summons a Guardian")
	check_eq(sim.elements.pending_level(&"aqua"), 2, "aqua 2 pending")
	check(not sim.elements.can_pick(&"aqua"), "no second pick on aqua")
	check(not sim.elements.pick(sim, &"aqua"), "refused")
	check_eq(sim.elements.pending_picks(), 1, "the pick is kept")
	check(sim.elements.can_pick(&"light"), "another element is fine")
	sim.kill(_guardian(sim))
	check_eq(sim.elements.level(&"aqua"), 2, "aqua 2")
	check(sim.elements.can_pick(&"aqua"), "aqua can be picked again")
	sim.elements.apply_picks([&"aqua"])
	check(not sim.elements.can_pick(&"aqua"), "not past level 3")


func test_interest_picks_raise_rate_and_cap() -> void:
	var sim := _eletd()
	sim.countdown = 1000.0
	sim.gold = 1000
	check(sim.elements.pick(sim, &"interest"), "interest picked")
	check_near(sim.elements.interest_rate(), 0.03, 1e-9, "3%")
	check_eq(sim.elements.interest_cap(), 30, "cap 30")
	var paid := []
	for _i in int(GameSim.INTEREST_PERIOD / GameSim.DT) + 2:
		sim.step()
		for e in sim.drain_events():
			if e.type == &"interest":
				paid.append(e.amount)
	check_eq(paid, [30], "3% of 1000, under the new cap of 30")
	sim.elements.apply_picks([&"interest", &"interest", &"interest"])
	check_near(sim.elements.interest_rate(), 0.05, 1e-9, "at most three: 5%")
	check_eq(sim.elements.interest_cap(), 50, "cap 50")
	_clear_to(sim, 5)
	check(not sim.elements.can_pick(&"interest"), "no fourth interest pick")
	check(sim.elements.can_pick(&"verdant"), "the pick can still go on an element")


func test_starters_deal_composite_damage() -> void:
	var elements: Array[StringName] = [&"composite"]
	elements.append_array(Damage.WHEEL)
	# Pierce on Light armor is 150%, Siege 100%; armor 0; no element multiplier.
	var want := {&"archer": 15.0, &"cannon": 10.0}
	for id: StringName in want:
		var t := SimTower.new()
		t.id = id
		for e in elements:
			var sim := _eletd()
			var c := sim.spawn_creep(&"grunt", e, 1, Vector2(20, 20))
			c.armor = 0.0
			check_near(sim.hit(c, 10.0, t, 0.0), want[id], 1e-4, "%s vs %s" % [id, e])
	var classic := GameSim.new()
	var archer := SimTower.new()
	archer.id = &"archer"
	var dark := classic.spawn_creep(&"grunt", &"dark", 1, Vector2(20, 20))
	dark.armor = 0.0
	check_near(classic.hit(dark, 10.0, archer, 0.0), 30.0, 1e-4, "classic Archer is Light")


## Under eletd upgraded Archers hit softer and elemental towers but the Plague
## Cauldron hit harder, the Runesmith Forge twice as hard again
## (EletdRules.ARCHER_POWER, ELEMENTAL_POWER, RUNESMITH_POWER); classic keeps
## the table's damage.
func test_tower_power_scales_hits_poison_and_clouds() -> void:
	var want := {
		[&"archer", 1]: 1.0,
		[&"archer", 2]: 0.85,
		[&"archer", 3]: 0.8,
		[&"cannon", 3]: 1.0,
		[&"ballista", 1]: 1.4,
		[&"demolisher", 3]: 1.4,
		[&"frost", 2]: 1.4,
		[&"roots", 1]: 1.4,
		[&"runesmith", 1]: 2.8,
		[&"runesmith", 3]: 2.8,
		[&"sunfire_ballista", 1]: 1.0,
	}
	for key: Array in want:
		var t := SimTower.new()
		t.id = key[0]
		t.level = key[1]
		var hits: Array[float] = []
		for rules: StringName in [&"classic", &"eletd"]:
			var sim := GameSim.new()
			sim.rules = rules
			# Light creeps: neutral to classic's Light Archer and Flame Cannon too.
			var c := sim.spawn_creep(&"grunt", &"light", 1, Vector2(20, 20))
			c.armor = 0.0
			c.max_hp = 1e6
			c.hp = c.max_hp
			hits.append(sim.hit(c, 10.0, t, 0.0))
		check_near(hits[1] / hits[0], want[key], 1e-4, "%s L%d" % key)
	for rules: StringName in [&"classic", &"eletd"]:
		var sim := GameSim.new()
		sim.rules = rules
		sim.countdown = -1.0
		sim.gold = 1000
		sim.elements.apply_picks([&"dark"])
		var c := sim.spawn_creep(&"grunt", &"flame", 1, Grid.center(Vector2i(12, 11)))
		var plague := SimTower.new()
		plague.id = &"plague"
		sim.add_poison(c, plague, 1, 0.0)
		check_near(c.poison[0].x, 6.0, 1e-4, "plague keeps its poison, %s" % rules)
		sim.build(Vector2i(12, 10), &"shadow")
		sim.step()
		var cloud: float = sim.zones[0].dps if not sim.zones.is_empty() else -1.0
		check_near(cloud, 18.0 * (1.4 if rules == &"eletd" else 1.0), 1e-4, "%s cloud" % rules)


func test_tower_cards_show_eletd_damage() -> void:
	TowerInfo.composite = true
	var eletd := TowerInfo.next_level_preview(&"archer", 1)
	var ballista := TowerInfo.next_level_preview(&"ballista", 1)
	TowerInfo.composite = false
	check("Dmg 9 → 12.75" in eletd, eletd)
	check("Dmg 77 → 140" in ballista, ballista)
	check("Dmg 9 → 15" in TowerInfo.next_level_preview(&"archer", 1), "classic")


## A shot does the damage of the tower that fired it, as that tower was when
## it fired: an arrow loosed at level 1 lands as a level-1 arrow after an
## upgrade, and a Demolisher's shell in flight when the tower fuses into a
## Doom Cannon lands, and leaves its crater, as a Demolisher's. Each landing
## is measured against the same shot landing with nothing in between.
func test_shots_land_as_the_tower_that_fired_them() -> void:
	var upgrade := func(sim: GameSim, tile: Vector2i) -> void: sim.upgrade(tile)
	var fuse := func(sim: GameSim, tile: Vector2i) -> void: sim.fuse(tile, SPARE)
	for case: Array in [[&"archer", 1, upgrade, 2], [&"demolisher", 3, fuse, 1]]:
		var plain := _landing(case[0], case[1], Callable())
		var across := _landing(case[0], case[1], case[2])
		check(plain.damage > 0.0, "%s shot landed" % case[0])
		check_eq(across.tower.level, case[3], "%s changed in flight" % case[0])
		check_near(across.damage, plain.damage, 1e-3, "%s shot across the change" % case[0])
		check_near(across.crater, plain.crater, 1e-4, "%s crater" % case[0])
	var fused := _landing(&"demolisher", 3, fuse)
	check_eq(fused.tower.id, &"doom_cannon", "fused in flight")
	check_near(fused.crater, 30.0 * 1.4, 1e-4, "a level-3 Demolisher's crater")


## Under eletd, builds `id` at `level` beside a parked creep (with a level-3
## Cannon on SPARE to fuse with), steps until its first shot is in flight,
## calls `between` (sim, tile) if given, and steps until the shot lands.
## Returns the HP that last step took, the dps of any crater and the tower.
func _landing(id: StringName, level: int, between: Callable) -> Dictionary:
	var sim := _eletd()
	sim.gold = 100000
	sim.elements.apply_picks([&"flame", &"flame", &"flame"])
	var tile := Vector2i(10, 10)
	for at: Vector2i in [tile, SPARE]:
		sim.build(at, id if at == tile else &"cannon")
		while sim.tower_at(at).level < level:
			sim.upgrade(at)
	var c := sim.spawn_creep(&"grunt", &"light", 20, Grid.center(tile + Vector2i(0, 1)))
	c.speed = 0.0
	c.max_hp = 1e7
	c.hp = c.max_hp
	while sim.projectiles.is_empty():
		sim.step()
	var shot: SimProjectile = sim.projectiles[0]
	if between.is_valid():
		between.call(sim, tile)
	sim.tower_at(tile).cooldown = 1e9
	var hp := c.hp
	while shot.alive:
		hp = c.hp
		sim.step()
	var crater: float = sim.zones[0].dps if not sim.zones.is_empty() else 0.0
	return {"damage": hp - c.hp, "crater": crater, "tower": sim.tower_at(tile)}


func test_cli_picks_apply_at_once_without_guardians() -> void:
	var sim := _eletd()
	var picks := SimElements.parse_picks("aqua,dark, dark,interest,stone,stone,stone,stone")
	check(picks.all(func(p: StringName) -> bool: return SimElements.is_choice(p)), "all known")
	check(not SimElements.is_choice(&"fire"), "an unknown name")
	sim.elements.apply_picks(picks)
	check_eq(sim.elements.level(&"aqua"), 1, "aqua 1")
	check_eq(sim.elements.level(&"dark"), 2, "dark 2")
	check_eq(sim.elements.level(&"stone"), 3, "stone capped at 3")
	check_eq(sim.elements.interest_picks, 1, "one interest pick")
	check(sim.creeps.is_empty(), "no Guardians")
	check_eq(sim.elements.pending_picks(), 1, "the game's own picks still come")
	check(sim.elements.pick(sim, &"light"), "light")
	check_eq(sim.elements.level(&"light"), 1, "and the first is still free")


func test_classic_builds_everything_at_wave_0_and_never_picks() -> void:
	var sim := GameSim.new()
	sim.gold = 100_000
	var col := 1
	for id in TowerDefs.BUILD_ORDER:
		var tile := Vector2i(col, 10)
		col += 2
		check_eq(sim.check_build(tile, id), R.OK, "%s can be built" % id)
		check_eq(sim.build(tile, id), R.OK, "%s built" % id)
		check(sim.upgrade(tile) and sim.upgrade(tile), "%s to level 3" % id)
		check_eq(sim.elements.needs(id, 3), "", "%s needs nothing" % id)
	check_eq(sim.elements.unlocked_towers(), TowerDefs.BUILD_ORDER, "all unlocked")
	check_eq(sim.elements.pending_picks(), 0, "no picks")
	check(not sim.elements.pick(sim, &"aqua"), "picking does nothing")
	check_eq(sim.elements.interest_rate(), GameSim.INTEREST_RATE, "interest rate as released")
	check_eq(sim.elements.interest_cap(), GameSim.INTEREST_CAP, "interest cap as released")
	var events := _clear_to(sim, 10)
	check_eq(_count(events, &"pick_granted"), 0, "no picks granted")
