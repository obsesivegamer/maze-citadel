extends "res://tests/test_case.gd"
## The Alliance and Forsaken Epics: Sunfire Ballista's board-crossing lance
## and Plague Necropolis's targeting and contagion (GDD §7).


func _place(sim: GameSim, tile: Vector2i, id: StringName, level := 1) -> SimTower:
	sim.gold = 100000
	sim.build(tile, id)
	while sim.tower_at(tile).level < level:
		sim.upgrade(tile)
	return sim.tower_at(tile)


## Builds an Epic on `tile` the way a player does: two level-3 family towers
## fused (the partner on a far corner tile, freed again by the fusion).
func _epic(sim: GameSim, tile: Vector2i, epic: StringName) -> SimTower:
	var members := {&"sunfire_ballista": &"ballista", &"plague_necropolis": &"plague"}
	var spare := Vector2i(19, 26)
	_place(sim, tile, members[epic], 3)
	_place(sim, spare, members[epic], 3)
	sim.fuse(tile, spare)
	return sim.tower_at(tile)


func _parked(sim: GameSim, type: StringName, tile: Vector2i, w := 30) -> SimCreep:
	var c := sim.spawn_creep(type, &"flame", w, Grid.center(tile))
	c.speed = 0.0
	return c


func _run(sim: GameSim, seconds: float) -> void:
	for _i in int(seconds / GameSim.DT):
		sim.step()


func test_every_family_fuses_into_its_epic() -> void:
	var pairs := {
		&"sunfire_ballista": [&"archer", &"ballista", 120],
		&"plague_necropolis": [&"plague", &"shadow", 100],
	}
	for epic: StringName in pairs:
		var sim := GameSim.new()
		var a := Vector2i(3, 3)
		var b := Vector2i(8, 3)
		_place(sim, a, pairs[epic][0], 3)
		_place(sim, b, pairs[epic][1], 3)
		check_eq(sim.fusion_result(a, b), epic, "%s pair" % epic)
		sim.gold = pairs[epic][2]
		check(sim.fuse(a, b), "%s fused" % epic)
		check_eq(sim.gold, 0, "%s fuse cost" % epic)
		check_eq(sim.tower_at(a).id, epic, "%s in place" % epic)
		check(sim.grid.is_walkable(b), "%s frees the second tile" % epic)
	for family in [&"alliance", &"horde", &"elven", &"forsaken"]:
		check(TowerDefs.FUSIONS.has(family), "%s has an Epic" % family)
	check_eq(TowerDefs.EPICS.size(), TowerDefs.FUSIONS.size(), "one Epic per family")


## The lance flies 40 m from the tower and hits every creep it passes once,
## with no pierce limit; creeps past its end are untouched.
func test_sunfire_lance_crosses_the_board() -> void:
	var sim := GameSim.new()
	sim.countdown = -1.0
	var line: Array[SimCreep] = []
	for y in range(4, 25):
		line.append(_parked(sim, &"footman", Vector2i(10, y), 20))
	var t := _epic(sim, Vector2i(10, 1), &"sunfire_ballista")
	t.cooldown = 0.0
	_run(sim, 1.2)
	check_eq(t.shots, 1, "one lance")
	var reach: float = TowerDefs.stat(&"sunfire_ballista", "lance_length")
	for c in line:
		var d := c.pos.distance_to(t.pos)
		if d <= reach:
			check(c.hp < c.max_hp, "hit at %.0f m" % d)
		elif d > reach + 2.0:
			check_eq(c.hp, c.max_hp, "untouched at %.0f m" % d)
	var hit := line.filter(func(c: SimCreep) -> bool: return c.hp < c.max_hp)
	check(hit.size() >= 18, "lance hit %d creeps" % hit.size())


func test_sunfire_hits_air_and_leads_moving_targets() -> void:
	var sim := GameSim.new()
	sim.countdown = -1.0
	var harpy := sim.spawn_creep(&"harpy", &"flame", 20, Grid.center(Vector2i(15, 8)))
	harpy.heading = Vector2(-1, 0)
	harpy.speed = 0.0
	var t := _epic(sim, Vector2i(10, 4), &"sunfire_ballista")
	t.cooldown = 0.0
	_run(sim, 0.5)
	check(harpy.hp < harpy.max_hp, "harpy hit")
	# A walking creep is hit where it will be when the lance arrives.
	var sim2 := GameSim.new()
	sim2.countdown = -1.0
	var runner := sim2.spawn_creep(&"grunt", &"flame", 20, Grid.center(Vector2i(6, 7)))
	var t2 := _epic(sim2, Vector2i(2, 2), &"sunfire_ballista")
	t2.cooldown = 0.0
	sim2.step()
	check_eq(t2.shots, 1, "fired at the walker")
	var eta := runner.pos.distance_to(t2.pos) / float(t2.stat("speed"))
	var ahead := runner.pos + runner.heading * runner.effective_speed() * eta
	var direct := (runner.pos - t2.pos).normalized()
	check_near(t2.aim.angle_to((ahead - t2.pos).normalized()), 0.0, 1e-4, "aims at the lead point")
	check(absf(t2.aim.angle_to(direct)) > 0.01, "lead differs from a straight aim")


func test_necropolis_plagues_uninfected_creeps_first() -> void:
	var sim := GameSim.new()
	sim.countdown = -1.0
	var lead := _parked(sim, &"grunt", Vector2i(10, 12))
	var back := _parked(sim, &"grunt", Vector2i(10, 8))
	_epic(sim, Vector2i(12, 10), &"plague_necropolis")
	_run(sim, 0.4)
	check(lead.carries(&"plague_necropolis"), "first lob on the lead creep")
	check(not back.carries(&"plague_necropolis"), "back creep still clean")
	_run(sim, 1.0)
	check(back.carries(&"plague_necropolis"), "second lob skips the infected lead")


func test_necropolis_contagion_spreads_on_death_and_down() -> void:
	var sim := GameSim.new()
	sim.countdown = -1.0
	var t := _epic(sim, Vector2i(0, 0), &"plague_necropolis")
	var dying := _parked(sim, &"grunt", Vector2i(12, 20))
	var near := _parked(sim, &"grunt", Vector2i(13, 20))
	var far := _parked(sim, &"grunt", Vector2i(15, 20))
	var shrouded := _parked(sim, &"steam_tank", Vector2i(12, 21))
	shrouded.immune_time = 1.0
	sim.add_poison(dying, t, 1, 0.0)
	sim.drain_events()
	sim.hit(dying, dying.hp + 1.0, t, 0.0)
	check(not dying.alive, "carrier died")
	check(near.carries(&"plague_necropolis"), "neighbour within 3 m infected")
	check(not far.carries(&"plague_necropolis"), "creep 6 m away untouched")
	check(not shrouded.carries(&"plague_necropolis"), "immune creep untouched")
	var spread := sim.drain_events().filter(
		func(e: Dictionary) -> bool: return e.type == &"contagion"
	)
	check_eq(spread.size(), 1, "one contagion event")
	if not spread.is_empty():
		check_eq(spread[0].count, 1, "one creep infected")
	# A Ghoul going down spreads it too, then rises clean.
	var ghoul := _parked(sim, &"ghoul", Vector2i(5, 15))
	var next := _parked(sim, &"grunt", Vector2i(5, 16))
	sim.add_poison(ghoul, t, 1, 0.0)
	sim.hit(ghoul, ghoul.hp + 1.0, t, 0.0)
	check(ghoul.alive and ghoul.revive_time > 0.0, "ghoul down")
	check(next.carries(&"plague_necropolis"), "ghoul's neighbour infected")
	check(not ghoul.carries(&"plague_necropolis"), "downed ghoul's stacks cleared")
	# A carrier with nobody in reach dies without a burst.
	var lone := _parked(sim, &"grunt", Vector2i(18, 3))
	sim.add_poison(lone, t, 1, 0.0)
	sim.drain_events()
	sim.hit(lone, lone.hp + 1.0, t, 0.0)
	var bursts := sim.drain_events().filter(
		func(e: Dictionary) -> bool: return e.type == &"contagion"
	)
	check(bursts.is_empty(), "no burst when nobody is in reach")


## Cauldron stacks don't spread; only the Necropolis's do.
func test_cauldron_poison_is_not_contagious() -> void:
	var sim := GameSim.new()
	sim.countdown = -1.0
	var cauldron := _place(sim, Vector2i(0, 0), &"plague", 3)
	var dying := _parked(sim, &"grunt", Vector2i(12, 20))
	var near := _parked(sim, &"grunt", Vector2i(13, 20))
	sim.add_poison(dying, cauldron, 3, 0.0)
	sim.hit(dying, dying.hp + 1.0, cauldron, 0.0)
	check(near.poison.is_empty(), "no spread from a Cauldron")


## A stack spreads as the tower that laid it was then: a Cauldron's stack laid
## just before the Cauldron fuses into a Necropolis still doesn't spread.
func test_stack_laid_before_a_fusion_spreads_as_it_was_laid() -> void:
	var sim := GameSim.new()
	sim.countdown = -1.0
	var t := _place(sim, Vector2i(0, 0), &"plague", 3)
	_place(sim, Vector2i(19, 26), &"plague", 3)
	var dying := _parked(sim, &"grunt", Vector2i(12, 20))
	var near := _parked(sim, &"grunt", Vector2i(13, 20))
	sim.add_poison(dying, t, 3, 0.0)
	check(sim.fuse(Vector2i(0, 0), Vector2i(19, 26)), "fused")
	sim.hit(dying, dying.hp + 1.0, t, 0.0)
	check(not dying.alive, "carrier died")
	check(near.poison.is_empty(), "the Cauldron's stack stays put")
