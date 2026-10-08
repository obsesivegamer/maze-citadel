extends "res://tests/test_case.gd"
## Creep HP under the Element TD rules (EletdRules, docs/balance.md): the plain
## share's floor and line, the early HP that makes every plain creep of the
## opening take several Archer arrows, armored creeps' own line and the bosses.


## The plain HP share's straight line, without HP_FLOOR.
func _line(w: int) -> float:
	return lerpf(EletdRules.HP_FROM, EletdRules.HP_TO, (w - 1) / 39.0)


## Armored creeps keep the line without the floor, so the Footmen of wave 3
## and the Tanks of wave 7 have the HP they had; once the line passes the
## floor they are never the easier ones.
func test_eletd_armored_creeps_climb_to_their_own_hp_share() -> void:
	check_near(EletdRules.armored_hp(1), EletdRules.HP_FROM, 1e-6, "wave 1")
	check_near(EletdRules.armored_hp(40), EletdRules.ARMORED_HP_TO, 1e-6, "wave 40")
	for w: int in [3, 7]:
		check(absf(EletdRules.armored_hp(w) / _line(w) - 1.0) < 0.02, "wave %d barely changes" % w)
	for w in range(1, 41):
		if _line(w) >= EletdRules.HP_FLOOR:
			check(EletdRules.armored_hp(w) >= EletdRules.hp(w), "never below the rest, w%d" % w)
	var classic := GameSim.new()
	var sim := GameSim.new()
	sim.rules = &"eletd"
	for type: StringName in [&"footman", &"steam_tank", &"grunt"]:
		var a := classic.spawn_creep(type, &"flame", 30, Vector2.ZERO)
		var b := sim.spawn_creep(type, &"flame", 30, Vector2.ZERO)
		var share := EletdRules.hp(30) if type == &"grunt" else EletdRules.armored_hp(30)
		check_near(b.max_hp, a.max_hp * share, 1e-3, "%s share" % type)


## The plain share never drops below HP_FLOOR and is the line once the line
## passes it, so the mid and late game keep their tuning.
func test_eletd_plain_share_has_a_floor_then_follows_the_line() -> void:
	for w in range(1, 41):
		var want := maxf(EletdRules.HP_FLOOR, _line(w))
		check_near(EletdRules.hp(w), want, 1e-6, "w%d" % w)
	check_near(EletdRules.hp(1), EletdRules.HP_FLOOR, 1e-6, "the floor on wave 1")
	check_near(EletdRules.hp(20), _line(20), 1e-6, "the line by wave 20")


## Arrows a level-`level` Archer lands on the creep of spawn_list entry `e`
## of wave `w` at `difficulty`, sent as its wave sends it, before it drops.
func _arrows_to_drop(e: Array, w: int, difficulty: StringName, level: int) -> int:
	var sim := GameSim.new(&"citadel")
	sim.rules = &"eletd"
	sim.difficulty = difficulty
	var c := sim.spawn_creep(e[0], e[1], w, sim.grid.spawn_point)
	c.reshape(e[2], e[3], e[4])
	var archer := SimTower.new()
	archer.id = &"archer"
	archer.level = level
	var base: float = TowerDefs.TOWERS[&"archer"].damage[level - 1]
	for n in range(1, 100):
		sim.hit(c, base, archer, 0.0)
		if c.hp <= 0.0:
			return n
	return 100


## The first creep of each plain type (neither armored nor a boss) on wave `w`.
func _plain_entries(w: int) -> Array:
	var out := []
	var seen := {}
	for e in WaveDefs.spawn_list(w, &"eletd"):
		if EletdRules.plain(e[0]) and not seen.has(e[0]):
			seen[e[0]] = true
			out.append(e)
	return out


## Every plain creep of the opening, flyers too, outlives all but the last of
## its EARLY_ARROWS level-1 Archer arrows at every difficulty: four on Normal,
## two on Easy, five on Hard, six on Very Hard.
func test_opening_creeps_take_their_arrows() -> void:
	check_eq(EletdRules.EARLY_ARROWS, {&"easy": 2, &"normal": 4, &"hard": 5, &"very_hard": 6}, "")
	for d: StringName in EletdRules.DIFFICULTIES:
		var want: int = EletdRules.EARLY_ARROWS[d]
		for w in range(1, EletdRules.EARLY_WAVES + 1):
			for e in _plain_entries(w):
				var n := _arrows_to_drop(e, w, d, 1)
				check(n >= want, "%s w%d %s: %d arrows, want %d" % [d, w, e[0], n, want])
				check_eq(EletdRules.arrows(1, e[0], w, d), n, "%s w%d %s: helper" % [d, w, e[0]])


## Upgrading brings no one-shot back: on Normal a level-2 or level-3 Archer
## needs two arrows for any plain creep of the opening.
func test_upgraded_archers_need_two_arrows_on_normal() -> void:
	for w in range(1, EletdRules.EARLY_WAVES + 1):
		for e in _plain_entries(w):
			for level in [2, 3]:
				var n := _arrows_to_drop(e, w, &"normal", level)
				check(n >= 2, "w%d %s: level %d Archer, %d arrows" % [w, e[0], level, n])
				check_eq(
					EletdRules.arrows(level, e[0], w, &"normal"), n, "helper, level %d" % level
				)


## The early HP is gone by EARLY_HP_UNTIL: from wave 15 every creep has the
## HP it had in 0.4.2, and armored creeps, bosses and Guardians never take it.
func test_early_hp_leaves_the_rest_as_it_was() -> void:
	check_eq(EletdRules.EARLY_HP_UNTIL, 15, "fades out by wave 15")
	for d: StringName in EletdRules.DIFFICULTIES:
		var sim := GameSim.new()
		sim.rules = &"eletd"
		sim.difficulty = d
		for w in range(1, 41):
			for type: StringName in [&"grunt", &"wolf_rider", &"priestess", &"harpy", &"ghoul"]:
				var c := sim.spawn_creep(type, &"flame", w, Vector2.ZERO)
				var before := CreepDefs.max_hp(
					type, w, EletdRules.difficulty_hp(d, w) * EletdRules.hp(w)
				)
				if w >= 15:
					check_near(c.max_hp, before, 1e-3, "%s w%d %s" % [d, w, type])
				else:
					check(c.max_hp > before, "%s w%d %s is tougher" % [d, w, type])
			for type: StringName in [&"footman", &"steam_tank"]:
				var c := sim.spawn_creep(type, &"flame", w, Vector2.ZERO)
				var before := CreepDefs.max_hp(
					type, w, EletdRules.difficulty_hp(d, w) * EletdRules.armored_hp(w)
				)
				check_near(c.max_hp, before, 1e-3, "%s w%d %s" % [d, w, type])
	for type: StringName in [&"footman", &"steam_tank", &"ogre", &"dreadlord", &"guardian"]:
		check_eq(EletdRules.early_from(type), 1.0, "%s takes no early HP" % type)


func test_eletd_hp_share_never_drops_and_has_its_own_hard_ramp() -> void:
	for w in range(2, 41):
		check(EletdRules.hp(w) >= EletdRules.hp(w - 1), "share never drops, w%d" % w)
		check(EletdRules.armored_hp(w) >= EletdRules.armored_hp(w - 1), "armored, w%d" % w)
	var classic := GameSim.new()
	var normal := GameSim.new()
	var hard := GameSim.new()
	normal.rules = &"eletd"
	hard.rules = &"eletd"
	classic.hard = true
	hard.hard = true
	for w: int in [1, 20, 40]:
		var c := classic.spawn_creep(&"grunt", &"flame", w, Vector2.ZERO)
		var n := normal.spawn_creep(&"grunt", &"flame", w, Vector2.ZERO)
		var h := hard.spawn_creep(&"grunt", &"flame", w, Vector2.ZERO)
		var ramp := lerpf(EletdRules.HARD_FROM, EletdRules.HARD_TO, (w - 1) / 39.0)
		if w <= EletdRules.EARLY_HOLD:
			ramp = EletdRules.HARD_EARLY
		check_near(h.max_hp, n.max_hp * ramp, 1e-3, "eletd Hard, w%d" % w)
		check_near(
			c.max_hp / GameSim.hard_hp(w),
			n.max_hp / EletdRules.hp_mult(&"grunt", w, &"normal"),
			1e-3,
			"classic"
		)
	for w: int in EletdRules.BOSS_HP:
		var type := WaveDefs.spawn_list(w).back()[0] as StringName
		var plain := CreepDefs.max_hp(type, w, EletdRules.hp(w))
		var boss := normal.spawn_creep(type, &"flame", w, Vector2.ZERO)
		check_near(boss.max_hp, plain * EletdRules.BOSS_HP[w], 1e-2, "boss on wave %d" % w)


## HP_FLOOR raised wave 10's share, and BOSS_HP took it back: the wave-10 Ogre
## has within 1% of the HP it had on the line at 2.1.
func test_eletd_wave_10_ogre_keeps_its_hp() -> void:
	var sim := GameSim.new()
	sim.rules = &"eletd"
	var ogre := sim.spawn_creep(&"ogre", &"flame", 10, Vector2.ZERO)
	var before := CreepDefs.max_hp(&"ogre", 10, _line(10) * 2.1)
	check(absf(ogre.max_hp / before - 1.0) < 0.01, "%.0f HP, was %.0f" % [ogre.max_hp, before])


## Buildable Citadel tiles whose reach covers at least 5 m of the flyers'
## portal-to-gate line, nearest the portal first, as a player would place them.
func _flight_line_tiles(sim: GameSim) -> Array[Vector2i]:
	var a := sim.grid.spawn_point
	var b := sim.grid.gate_point
	var out: Array[Vector2i] = []
	for i in Grid.COLS * Grid.ROWS:
		var t := Grid.tile_of(i)
		if sim.grid.is_reserved(t) or sim.grid.is_obstacle(t):
			continue
		var inside := 0
		for j in 201:
			var d := (a.lerp(b, j / 200.0) - Grid.center(t)).abs()
			inside += 1 if maxf(d.x, d.y) <= Grid.TILE * 1.5 else 0
		if inside * a.distance_to(b) / 200.0 >= 5.0:
			out.append(t)
	return out


## Lives the Harpies of wave 5 take on Normal past `archers` level-1 Archers
## beside the flight line.
func _wave_5_leaks(archers: int) -> int:
	var sim := GameSim.new(&"citadel")
	sim.rules = &"eletd"
	sim.gold = 100000
	sim.lives = 100000
	for t in _flight_line_tiles(sim).slice(0, archers):
		check_eq(sim.build(t, &"archer"), Placement.Result.OK, "Archer on %s" % t)
	sim.wave = 4
	sim.start_next_wave()
	var leaked := 0
	for _i in int(120.0 / GameSim.DT):
		sim.step()
		for e in sim.drain_events():
			leaked += 1 if e.type == &"leaked" else 0
		if sim.phase != GameSim.Phase.WAVE:
			break
	return leaked


## The early HP sizes the first flyers so one Archer on their line no longer
## holds them on Normal and four do (T9 in docs/balance.md).
func test_wave_5_harpies_need_four_archers_on_their_line() -> void:
	check(_wave_5_leaks(1) > 0, "one Archer leaks")
	check_eq(_wave_5_leaks(4), 0, "four Archers hold")
