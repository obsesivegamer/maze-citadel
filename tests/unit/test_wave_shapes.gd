extends "res://tests/test_case.gd"
## Element TD's wave shapes under eletd (GDD §5.0): bigger, tighter waves that
## keep each wave's HP and gold, composite armor, and Bulky waves. Classic
## waves stay exactly as released.

## The classic spawn lists as released, one run of "count type element" per
## group, captured before the eletd shapes existed.
const CLASSIC := [
	"10 grunt flame",
	"14 wolf_rider dark",
	"8 footman verdant",
	"10 grunt aqua, 3 priestess aqua",
	"12 harpy light",
	"14 ghoul dark",
	"4 grunt flame, 6 steam_tank flame",
	"12 wolf_rider flame, 8 grunt flame",
	"12 footman aqua, 4 priestess aqua",
	"8 grunt flame, 1 ogre flame",
	"10 harpy verdant, 4 priestess verdant",
	"12 ghoul dark, 3 priestess dark",
	"16 harpy aqua",
	"16 wolf_rider light, 4 priestess light",
	"14 ghoul verdant, 6 harpy verdant",
	"10 footman light, 6 priestess light",
	"18 harpy dark",
	"14 ghoul flame, 5 priestess flame",
	"14 wolf_rider stone, 8 harpy stone",
	"8 harpy dark, 1 ogre dark",
	"8 steam_tank aqua, 4 priestess aqua",
	"16 footman verdant",
	"10 steam_tank light, 6 footman light",
	"12 grunt flame, 12 footman flame",
	"8 steam_tank dark, 10 ghoul dark",
	"12 harpy stone, 6 steam_tank stone",
	"14 footman aqua, 6 priestess aqua",
	"12 steam_tank verdant, 4 priestess verdant",
	"16 wolf_rider light, 6 steam_tank light",
	"6 steam_tank stone, 2 ogre stone",
	"10 grunt aqua, 10 harpy flame",
	"12 ghoul verdant, 6 priestess verdant, 6 wolf_rider dark",
	"12 footman light, 8 steam_tank stone",
	"14 harpy dark, 10 wolf_rider aqua",
	"10 steam_tank flame, 12 ghoul light",
	"12 footman verdant, 10 harpy stone, 2 priestess verdant",
	"16 wolf_rider flame, 8 ghoul dark",
	"12 steam_tank aqua, 12 footman verdant",
	"12 harpy light, 8 ghoul stone, 4 priestess light",
	"10 ghoul dark, 1 dreadlord dark",
]
const COMPOSITE: Array[int] = [14, 27, 34]
const BULKY: Array[int] = [12, 18, 25, 37]


## "count type element" runs of a spawn list, joined like CLASSIC.
func _runs(list: Array) -> String:
	var parts := PackedStringArray()
	var last := ""
	var n := 0
	for e in list:
		var k := "%s %s" % [e[0], e[1]]
		if k != last and n > 0:
			parts.append("%d %s" % [n, last])
			n = 0
		last = k
		n += 1
	parts.append("%d %s" % [n, last])
	return ", ".join(parts)


## {type: count} of the classic table's wave `w`.
func _classic_counts(w: int) -> Dictionary:
	var out := {}
	for e in WaveDefs.spawn_list(w):
		out[e[0]] = out.get(e[0], 0) + 1
	return out


## The gold a creep paid before the eletd shapes: bosses ten creeps' worth,
## the Dreadlord twenty-five.
func _old_bounty(type: StringName, w: int) -> int:
	var mult := 25 if type == &"dreadlord" else (10 if CreepDefs.is_boss(type) else 1)
	return CreepDefs.bounty(w) * mult


## Starts wave `w` and steps until every creep of it has entered; returns
## them in spawn order (summons left out).
func _spawned(sim: GameSim, w: int) -> Array[SimCreep]:
	sim.lives = 100_000
	sim.wave = w - 1
	sim.start_next_wave()
	var out: Array[SimCreep] = []
	while sim.spawning():
		sim.step()
		for e in sim.drain_events():
			if e.type == &"spawned" and e.creep != &"felhound":
				out.append(sim.creep(e.id))
	return out


func _eletd() -> GameSim:
	var sim := GameSim.new()
	sim.rules = &"eletd"
	sim.countdown = -1.0
	return sim


func test_classic_spawn_lists_are_as_released() -> void:
	for w in range(1, WaveDefs.count() + 1):
		for list in [WaveDefs.spawn_list(w), WaveDefs.spawn_list(w, &"classic")]:
			check_eq(_runs(list), CLASSIC[w - 1], "classic wave %d" % w)
			check(list.all(func(e: Array) -> bool: return e.size() == 2), "pairs on %d" % w)
		check(not WaveDefs.bulky(w), "classic wave %d is never Bulky" % w)
		check(not &"composite" in WaveDefs.elements(w), "classic wave %d has no composite" % w)


func test_eletd_groups_are_half_again_as_big() -> void:
	for w in range(1, WaveDefs.count() + 1):
		var got := {}
		for e in WaveDefs.spawn_list(w, &"eletd"):
			got[e[0]] = got.get(e[0], 0) + 1
		var want := _classic_counts(w)
		for type: StringName in want:
			var n: int = want[type]
			if not CreepDefs.is_boss(type):
				n = ceili(n * 1.5)
				if w in BULKY:
					n = ceili(n / 2.0)
			check_eq(got.get(type, 0), n, "wave %d %s" % [w, type])
		check_eq(got.size(), want.size(), "wave %d types" % w)


func test_eletd_keeps_each_waves_hp_and_gold() -> void:
	for w in range(1, WaveDefs.count() + 1):
		if w in BULKY:
			continue
		var hp := 0.0
		var gold := 0
		for e in WaveDefs.spawn_list(w, &"eletd"):
			hp += CreepDefs.max_hp(e[0], w) * WaveDefs.hp_share(e)
			gold += e[3]
		var old_hp := 0.0
		var old_gold := 0
		for e in WaveDefs.spawn_list(w):
			old_hp += CreepDefs.max_hp(e[0], w)
			old_gold += _old_bounty(e[0], w)
		check_near(hp, old_hp, old_hp * 1e-6, "wave %d HP" % w)
		check(absi(gold - old_gold) <= 1, "wave %d gold %d, was %d" % [w, gold, old_gold])


## The same through the sim: the creeps that actually enter, at their HP under
## eletd's share and with the bounty they pay.
func test_spawned_creeps_carry_the_waves_totals() -> void:
	for w in [1, 4, 10, 14, 31, 40]:
		var creeps := _spawned(_eletd(), w)
		var hp := 0.0
		var gold := 0
		for c in creeps:
			hp += c.max_hp
			gold += c.bounty
		var old_hp := 0.0
		var old_gold := 0
		for e in WaveDefs.spawn_list(w):
			var mult := EletdRules.hp_mult(e[0], w, &"normal")
			old_hp += CreepDefs.max_hp(e[0], w, mult)
			old_gold += _old_bounty(e[0], w)
		check_eq(creeps.size(), WaveDefs.spawn_list(w, &"eletd").size(), "wave %d count" % w)
		check_near(hp, old_hp, old_hp * 1e-5, "wave %d HP" % w)
		check(absi(gold - old_gold) <= 1, "wave %d gold %d, was %d" % [w, gold, old_gold])


func test_creeps_of_a_group_differ_by_at_most_a_coin() -> void:
	for w in range(1, WaveDefs.count() + 1):
		var by_type := {}
		for e in WaveDefs.spawn_list(w, &"eletd"):
			by_type[e[0]] = by_type.get(e[0], []) + [e[3]]
		for type: StringName in by_type:
			var coins: Array = by_type[type]
			var step := EletdRules.BULKY_BOUNTY if w in BULKY else 1
			check(coins.max() - coins.min() <= step, "wave %d %s: %s" % [w, type, coins])


func test_eletd_spawn_gaps() -> void:
	for case in [[1, 0.6], [2, 0.35]]:
		var times: Array[float] = []
		var sim := _eletd()
		sim.wave = case[0] - 1
		sim.start_next_wave()
		while sim.spawning():
			sim.step()
			for e in sim.drain_events():
				if e.type == &"spawned":
					times.append(sim.time)
		check_near(times[2] - times[1], case[1], GameSim.DT + 1e-4, "wave %d gap" % case[0])
	check_eq(WaveDefs.spawn_interval(&"grunt"), GameSim.SPAWN_INTERVAL, "classic gap")
	check_eq(WaveDefs.spawn_interval(&"wolf_rider"), GameSim.FAST_SPAWN_INTERVAL, "classic fast")


func test_stampede_still_halves_the_eletd_gap() -> void:
	var found := [0, 0]
	for s in range(1, 300):
		var p := WaveTwists.plan(s, 39)
		for w in p:
			if p[w] == &"stampede" and found[1] == 0:
				found = [s, w]
	var sim := _eletd()
	sim.twists = true
	sim.twist_seed = found[0]
	sim.wave = found[1] - 1
	sim.start_next_wave()
	var times: Array[float] = []
	for _i in 200:
		sim.step()
		for e in sim.drain_events():
			if e.type == &"spawned":
				times.append(sim.time)
	var type: StringName = WaveDefs.spawn_list(found[1], &"eletd")[1][0]
	var want := WaveDefs.spawn_interval(type, &"eletd") * WaveTwists.STAMPEDE_SPAWN
	check_near(times[2] - times[1], want, GameSim.DT + 1e-4, "stampede gap")


func test_composite_takes_ninety_percent_from_every_element() -> void:
	for id: StringName in TowerDefs.TOWERS:
		var def: Dictionary = TowerDefs.TOWERS[id]
		if not def.has("attack"):
			continue
		check_near(Damage.element_mult(def.element, &"composite"), 0.9, 1e-6, "%s" % id)
		check_eq(Damage.counter(def.element, &"composite"), &"neutral", "%s counter" % id)
	for w in range(1, WaveDefs.count() + 1):
		var elements := WaveDefs.elements(w, &"eletd")
		if w in COMPOSITE:
			check_eq(elements, [&"composite"] as Array[StringName], "wave %d all composite" % w)
		else:
			check(not &"composite" in elements, "wave %d not composite" % w)
	check_eq(WaveDefs.elements(44, &"eletd"), [&"composite"] as Array[StringName], "infinite 34")


func test_composite_creep_takes_ninety_percent_in_the_sim() -> void:
	var sim := _eletd()
	var t := SimTower.new()
	t.id = &"ballista"
	var dealt := []
	for element in [&"flame", &"composite"]:
		var c := sim.spawn_creep(&"grunt", element, 14, Vector2(20, 20))
		c.armor = 0.0
		dealt.append(sim.hit(c, 10.0, t, 0.0))
	check_near(dealt[1], dealt[0] * 0.9, 1e-4, "ballista (light) on composite vs neutral flame")


func test_bulky_waves() -> void:
	for w in range(1, WaveDefs.count() + 1):
		check_eq(WaveDefs.bulky(w, &"eletd"), w in BULKY, "wave %d bulky" % w)
	check(WaveDefs.bulky(47, &"eletd"), "infinite 37 is Bulky too")
	for w in BULKY:
		var plain := {}
		for g in WaveDefs.row(w).groups:
			var m := ceili(g[1] * 1.5)
			plain[g[0]] = [
				CreepDefs.max_hp(g[0], w) * g[1] / m, g[1] * CreepDefs.bounty(w) / float(m)
			]
		for e in WaveDefs.spawn_list(w, &"eletd"):
			var per: Array = plain[e[0]]
			var hp: float = CreepDefs.max_hp(e[0], w) * WaveDefs.hp_share(e)
			check_near(hp, per[0] * 1.75, 1e-3, "wave %d %s HP" % [w, e[0]])
			check(e[3] in [2 * floori(per[1]), 2 * ceili(per[1])], "wave %d bounty %d" % [w, e[3]])


func test_bulky_creep_leaks_for_two_lives_and_pays_double() -> void:
	var sim := _eletd()
	var creeps := _spawned(sim, 12)
	check(creeps.all(func(c: SimCreep) -> bool: return c.bulky), "every creep is Bulky")
	var lives := sim.lives
	var leaked := {}
	for _i in 3000:
		sim.step()
		for e in sim.drain_events():
			if e.type == &"leaked":
				leaked = e
		if not leaked.is_empty():
			break
	check_eq(leaked.get("cost"), 2, "a Bulky leak costs 2")
	check_eq(sim.lives, lives - 2, "two lives gone")
	var plain := _spawned(_eletd(), 13)
	check(not plain.any(func(c: SimCreep) -> bool: return c.bulky), "wave 13 is not Bulky")
	var c := creeps.back() as SimCreep
	var gold := sim.gold
	sim.kill(c)
	check_eq(sim.gold, gold + c.bounty, "bounty paid")
	var share := 3.0 * CreepDefs.bounty(12) / 5.0
	check(c.bounty in [2 * floori(share), 2 * ceili(share)], "priestess pays %d" % c.bounty)


func test_wave_text_agrees_with_the_list() -> void:
	for w in range(1, WaveDefs.count() + 1):
		var n := WaveDefs.spawn_list(w, &"eletd").size()
		var chips := 0
		for g in TowerInfo.wave_groups(w, &"eletd"):
			chips += g[1]
		check_eq(chips, n, "wave %d chips" % w)
		var counsel := 0
		var share := 0.0
		for g in Counsel.groups(w, &"eletd"):
			counsel += g.count
			share += g.share
		check_eq(counsel, n, "wave %d counsel" % w)
		check_near(share, 1.0, 1e-6, "wave %d shares" % w)
	check_eq(TowerInfo.wave_summary(12, &"eletd"), "9 Ghoul, 3 Priestess")
	check_eq(TowerInfo.wave_summary(12), "12 Ghoul, 3 Priestess", "classic summary")
	check_eq(
		Counsel.plain(Counsel.element_lines(14, &"eletd")[0]), "Composite: every element does 90%."
	)
	check(TowerInfo.bulky_text().split(" ").size() < 12, "Bulky text under 12 words")
