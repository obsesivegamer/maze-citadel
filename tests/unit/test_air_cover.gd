extends "res://tests/test_case.gd"
## Where flyers cross the board under eletd and how well the towers beside
## their line cover them (AirCover): the reach geometry against
## GameSim.reaches on every map, the flyers against the ones the sim really
## spawns, each tower's damage rate against what it deals in a running sim,
## and the estimate's wording. Expected wording is written out, not read back.


func _eletd(map := MapDefs.DEFAULT) -> GameSim:
	var sim := GameSim.new(map)
	sim.rules = &"eletd"
	sim.countdown = -1.0
	sim.gold = 100_000
	return sim


func _leak(creep: StringName) -> Dictionary:
	return {"type": &"leaked", "id": 1, "cost": 1, "lives": 19, "wave": 5, "creep": creep}


## Whether a tower on `tile` reaches some point of the flight line, by the
## sim's own test on creeps put down along it every 0.25 m. A square that
## only touches the line's end (at the gate) doesn't count.
func _sim_reaches_line(sim: GameSim, tile: Vector2i) -> bool:
	var t := SimTower.new()
	t.tile = tile
	t.pos = Grid.center(tile)
	var c := SimCreep.new()
	var a := sim.grid.spawn_point
	var b := sim.grid.gate_point
	var n := ceili(a.distance_to(b) / 0.25)
	var hits := 0
	for i in n + 1:
		c.pos = a.lerp(b, float(i) / n)
		if sim.reaches(t, c):
			hits += 1
	return hits > 1


func test_the_tiles_that_reach_the_flight_line_are_the_ones_the_sim_reaches_from() -> void:
	var counts := {}
	for map in MapDefs.ORDER:
		var sim := _eletd(map)
		var tiles := AirCover.reach_tiles(sim.grid)
		counts[map] = tiles.size()
		for i in Grid.COLS * Grid.ROWS:
			var t := Grid.tile_of(i)
			var length := AirCover.chord(sim.grid, t)
			check(
				length <= Grid.TILE * 3.0 * sqrt(2.0) + 0.001, "%s %s: within the square" % [map, t]
			)
			var reached := _sim_reaches_line(sim, t)
			if length > 0.5:
				check(reached, "%s %s: %.2f m of line, so the sim reaches it" % [map, t, length])
			if reached and length < 0.001:
				failures.append("%s %s: the sim reaches the line but chord() says 0" % [map, t])
			if t in tiles:
				check(not sim.grid.is_reserved(t) and not sim.grid.is_lane(t), "%s %s" % [map, t])
				check(not sim.grid.is_obstacle(t), "%s %s: no ruin" % [map, t])
	check_eq(counts, {&"citadel": 108, &"rampart": 98, &"causeway": 82}, "buildable line tiles")


func test_on_the_citadel_columns_8_to_11_reach_the_line() -> void:
	var grid := Grid.new(&"citadel")
	var cols := []
	for t in AirCover.reach_tiles(grid):
		if not t.x in cols:
			cols.append(t.x)
	cols.sort()
	check_eq(cols, [8, 9, 10, 11])
	check_eq(AirCover.chord(grid, Vector2i(9, 10)), 6.0, "the line runs past column 9's edge")
	check_eq(AirCover.chord(grid, Vector2i(11, 10)), 6.0, "the square's edge counts")
	check_eq(AirCover.chord(grid, Vector2i(12, 10)), 0.0, "column 12 misses it")
	check_eq(AirCover.chord(grid, Vector2i(9, 0)), 5.5, "the line starts 1.5 m before row 0")


## The flyers AirCover counts are the ones the sim spawns: HP, speed and the
## time between the first and the last, on Very Hard with Twists.
func test_wave_flyers_are_the_ones_the_sim_spawns() -> void:
	for w in [5, 20, 31, 34, 39]:
		var sim := _eletd()
		sim.difficulty = &"very_hard"
		sim.twists = true
		sim.twist_seed = 7
		var air := AirCover.wave_flyers(sim, w)
		sim.wave = w - 1
		sim.start_next_wave()
		var hp := 0.0
		var speeds := []
		var times := []
		while sim.spawning():
			sim.step()
			for e in sim.drain_events():
				if e.type == &"spawned" and sim.creep(e.id).flying:
					hp += sim.creep(e.id).max_hp
					speeds.append(sim.creep(e.id).speed)
					times.append(sim.time)
		var flyers: Array[SimCreep] = air.flyers
		check_eq(flyers.size(), times.size(), "wave %d flyers" % w)
		var counted := 0.0
		for f in flyers:
			counted += f.max_hp
			check(f.speed in speeds, "wave %d speed %.2f" % [w, f.speed])
		check_near(counted, hp, 0.01, "wave %d flyer HP" % w)
		check_near(air.span, times[-1] - times[0], GameSim.DT * 1.5, "wave %d span" % w)
	check(AirCover.wave_flyers(_eletd(), 4).flyers.is_empty(), "wave 4 sends none")


## A tower's damage over the time a slow Harpy spends in its reach, poison
## running out afterwards included, against AirCover.dps.
func _measured(id: StringName, level: int, element: StringName, picks: Array[StringName]) -> Array:
	var sim := _eletd()
	sim.elements.apply_picks(picks)
	var tile := Vector2i(9, 10)
	check_eq(sim.build(tile, id), Placement.Result.OK, "%s builds" % id)
	for _i in level - 1:
		check(sim.upgrade(tile), "%s upgrades" % id)
	var t := sim.tower_at(tile)
	var c := sim.spawn_creep(&"harpy", element, 5, Vector2(20.0, 15.0))
	c.max_hp = 1e9
	c.hp = c.max_hp
	c.speed = 0.25
	var expected := AirCover.dps(sim, t, c)
	var steps := 0
	while c.pos.y < 30.0:
		if sim.reaches(t, c):
			steps += 1
		sim.step()
	for _i in roundi(6.0 / GameSim.DT):
		sim.step()
	return [expected, t.damage_dealt / (steps * GameSim.DT)]


func test_damage_rates_match_what_towers_deal_in_the_sim() -> void:
	var none: Array[StringName] = []
	for row in [
		[&"archer", 1, &"light", none],
		[&"archer", 3, &"dark", none],
		[&"frost", 1, &"flame", [&"aqua"] as Array[StringName]],
		[&"plague", 1, &"aqua", [&"dark"] as Array[StringName]],
		[&"ballista", 2, &"stone", [&"light", &"light"] as Array[StringName]],
	]:
		var r := _measured(row[0], row[1], row[2], row[3])
		check(r[0] > 0.0, "%s hits air" % row[0])
		check_near(
			r[1] / r[0], 1.0, 0.08, "%s L%d vs %s: measured %.1f/s" % [row[0], row[1], row[2], r[1]]
		)
	var sim := _eletd()
	sim.build(Vector2i(9, 10), &"cannon")
	var harpy := sim.spawn_creep(&"harpy", &"light", 5, Vector2(20.0, 15.0))
	check_eq(AirCover.dps(sim, sim.tower_at(Vector2i(9, 10)), harpy), 0.0, "a Cannon can't")


func test_estimate_counts_air_towers_beside_the_line() -> void:
	var sim := _eletd()
	check(AirCover.estimate(sim, 4).is_empty(), "no flyers on wave 4")
	var empty := AirCover.estimate(sim, 5)
	check_eq([empty.ratio, empty.towers, empty.wave], [0.0, 0, 5], "an empty board")
	check_eq(
		AirCover.warning(empty), "Air cover weak: no wing-icon tower stands beside the flight line"
	)
	sim.build(Vector2i(15, 10), &"archer")
	sim.build(Vector2i(10, 12), &"cannon")
	check_eq(AirCover.estimate(sim, 5).towers, 0, "off the line, or ground only")
	sim.build(Vector2i(9, 10), &"archer")
	var one := AirCover.estimate(sim, 5)
	check_eq(one.towers, 1)
	check(one.ratio > 0.0, "one Archer counts")
	sim.build(Vector2i(10, 16), &"archer")
	var two := AirCover.estimate(sim, 5)
	check_near(two.ratio, one.ratio * 2.0, 1e-6, "a second Archer beside the line doubles it")
	sim.build(Vector2i(8, 11), &"bard")
	var aura := sim.tower_at(Vector2i(9, 10)).aura
	check(aura > 0.0, "the Bard covers the first Archer")
	check_near(AirCover.estimate(sim, 5).ratio, two.ratio, 1e-6, "its aura is left out")
	check_near(AirCover.estimate(sim, 5).hp, empty.hp, 1e-6, "the flyers' HP stays")


## The estimate is the towers' damage while the flyers stream past, plus one
## flyer's time in reach, over their HP.
func test_estimate_is_rate_times_time_in_reach_over_hp() -> void:
	var sim := _eletd()
	sim.build(Vector2i(9, 10), &"archer")
	var air := AirCover.wave_flyers(sim, 5)
	var flyers: Array[SimCreep] = air.flyers
	var hp := 0.0
	for f in flyers:
		hp += f.max_hp
	var rate := AirCover.dps(sim, sim.tower_at(Vector2i(9, 10)), flyers[0])
	var est := AirCover.estimate(sim, 5)
	check_near(est.ratio, rate * (air.span + 6.0 / flyers[0].speed) / hp, 1e-6)
	check_near(est.hp, hp, 1e-6)


func test_verdicts_and_wording() -> void:
	check_eq(AirCover.verdict(0.63), "weak")
	check_eq(AirCover.verdict(0.99), "weak")
	check_eq(AirCover.verdict(1.0), "thin")
	check_eq(AirCover.verdict(1.11), "thin")
	check_eq(AirCover.verdict(1.25), "holding")
	var est := {"ratio": 0.634, "damage": 6790.0, "hp": 10709.0, "towers": 13, "wave": 34}
	check_eq(AirCover.readout(est), "Air cover, wave 34: weak")
	check_eq(
		AirCover.tip(est),
		(
			"An estimate: 13 wing-icon towers beside the flight line can deal about 63% of wave"
			+ " 34's 10,709 flyer HP. Below 100% some will get through. Choose a wing-icon tower"
			+ " to see the tiles that reach the line."
		)
	)
	check_eq(
		AirCover.warning(est),
		"Air cover weak: the towers beside the flight line can deal about 63% of these flyers' HP"
	)
	est.ratio = 1.04
	check_eq(AirCover.warning(est), "", "no warning at 100% or more")
	check_eq(AirCover.warning({}), "", "nor without flyers")
	est.towers = 1
	check(AirCover.tip(est).begins_with("An estimate: 1 wing-icon tower beside"), "one tower")
	check_eq(
		AirCover.tip({"ratio": 0.0, "damage": 0.0, "hp": 137.0, "towers": 0, "wave": 5}),
		(
			"No wing-icon tower stands beside the flight line, so none of wave 5's 137 flyer HP"
			+ " will be touched. Choose a wing-icon tower to see the tiles that reach the line."
		)
	)


func test_the_lane_lights_for_flying_waves_and_flashes_on_air_leaks() -> void:
	var sim := _eletd()
	sim.wave = 4
	check(AirCover.lane_lit(sim), "wave 5 is next and flies")
	check_eq(AirCover.upcoming(sim), 5)
	sim.wave = 5
	sim.phase = GameSim.Phase.WAVE
	check(AirCover.lane_lit(sim), "wave 5 is running")
	sim.phase = GameSim.Phase.BUILD
	check(not AirCover.lane_lit(sim), "wave 6 walks")
	check_eq(AirCover.upcoming(sim), 0, "neither 6 nor 7 flies")
	sim.wave = 9
	check(not AirCover.lane_lit(sim), "wave 10 walks")
	check_eq(AirCover.upcoming(sim), 11, "the wave after next")
	sim.wave = 39
	check(not AirCover.lane_lit(sim), "after the last flyers")
	check(AirCover.air_leak(_leak(&"harpy")), "a Harpy leak flashes the lane")
	check(not AirCover.air_leak(_leak(&"grunt")), "a Grunt's doesn't")
	check(not AirCover.air_leak({"type": &"died", "creep": &"harpy"}), "nor a death")
	var classic := GameSim.new()
	classic.wave = 4
	check(not AirCover.lane_lit(classic), "classic draws no flight line")
	check_eq(AirCover.upcoming(classic), 0)


func test_only_a_wing_icon_choice_tints_the_tiles() -> void:
	for id in [&"archer", &"frost", &"plague", &"runesmith", &"ballista"]:
		check(AirCover.tints_for(id), "%s hits air" % id)
	for id in [&"cannon", &"bard", &"demolisher", &"roots", &"shadow", &""]:
		check(not AirCover.tints_for(id), "%s doesn't" % id)
