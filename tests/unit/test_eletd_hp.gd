extends "res://tests/test_case.gd"
## Creep HP under the Element TD rules (EletdRules, docs/balance.md): the plain
## share's floor and line, armored creeps' own line, the bosses and the
## wave-5 Harpies.


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


## At the floor a Normal Grunt of the opening outlives one level-1 Archer arrow.
func test_eletd_opening_grunts_take_two_arrows() -> void:
	var sim := GameSim.new()
	sim.rules = &"eletd"
	for w: int in [1, 4]:
		var share := 0.0
		for e in WaveDefs.spawn_list(w, &"eletd"):
			if e[0] == &"grunt":
				share = e[2]
		var c := sim.spawn_creep(&"grunt", &"light", w, Vector2.ZERO)
		var arrow := Damage.amount(
			TowerDefs.TOWERS[&"archer"].damage[0], &"pierce", &"light", c, 0.0, c.armor
		)
		check(
			c.max_hp * share > arrow, "wave %d: %.1f HP, arrow %.1f" % [w, c.max_hp * share, arrow]
		)


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
		check_near(c.max_hp / GameSim.hard_hp(w), n.max_hp / EletdRules.hp(w), 1e-3, "classic")
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


## HARPY_HP lands on Harpies only, on its own waves, at every difficulty.
func test_eletd_harpy_hp_is_per_wave_and_harpy_only() -> void:
	for d: StringName in EletdRules.DIFFICULTIES:
		for w in range(1, 41):
			var k := EletdRules.hp_mult(&"harpy", w, d) / EletdRules.hp_mult(&"grunt", w, d)
			check_near(k, EletdRules.HARPY_HP.get(w, 1.0), 1e-6, "%s w%d" % [d, w])
	check(EletdRules.HARPY_HP.get(5, 1.0) > 1.0, "the first flyers are tougher")


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


## HARPY_HP sizes the first flyers so one Archer on their line no longer holds
## them on Normal and four do (T9 in docs/balance.md).
func test_wave_5_harpies_need_four_archers_on_their_line() -> void:
	check(_wave_5_leaks(1) > 0, "one Archer leaks")
	check_eq(_wave_5_leaks(4), 0, "four Archers hold")
