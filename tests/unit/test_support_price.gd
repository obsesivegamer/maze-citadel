extends "res://tests/test_case.gd"
## How the smart bot prices slows and shred under eletd (SupportPrice): by the
## damage of the towers around them, not by the tower's own.

const Bot := preload("res://src/bots/autoplay_bot.gd")


func _foe(armor_class: StringName, armor: float, air := false) -> Dictionary:
	return {
		"w": 1.0,
		"hp": 100.0,
		"speed": 3.0,
		"air": air,
		"cap": INF if armor_class == &"boss" else 1.08,
		"class": armor_class,
		"element": &"",
		"armor": armor,
	}


func _near(dps: float, foes: int) -> Array[PackedFloat32Array]:
	var all := PackedFloat32Array()
	all.resize(foes)
	all.fill(dps)
	var none := PackedFloat32Array()
	none.resize(foes)
	var out: Array[PackedFloat32Array] = [all, all.duplicate(), none]
	return out


## A slow is worth the seconds it holds a creep times the damage per second
## of the towers around it: nothing on its own, more beside more towers.
func test_slow_pays_by_the_towers_around_it() -> void:
	var foes: Array[Dictionary] = [_foe(&"light", 0.0)]
	var alone := SupportPrice.added(&"frost", 1, foes, 3, 0, _near(0.0, 1))
	check_near(alone[0], 0.0, 1e-6, "no towers around, no worth")
	var beside := SupportPrice.added(&"frost", 1, foes, 3, 0, _near(40.0, 1))
	# Slowed by 0.35 for 2 s, so 0.7 s longer under 40 dps.
	check_near(beside[0], 0.7 * 40.0 * SupportPrice.SLOW_SHARE, 1e-4, "frost beside 40 dps")
	var more := SupportPrice.added(&"frost", 1, foes, 3, 0, _near(80.0, 1))
	check_near(more[0], beside[0] * 2.0, 1e-4, "twice the towers, twice the worth")
	var near := _near(40.0, 1)
	near[2][0] = 1.0
	var second := SupportPrice.added(&"frost", 1, foes, 3, 0, near)
	check_near(second[0], 0.0, 1e-6, "a second slow on a slowed stretch adds nothing")


## A boss shrugs off half a slow; the Ancient of Roots can't touch a flyer,
## and its root counts for nothing beyond its slow. It pulses every 3 s on a
## creep that is 2 s in its reach, so it touches two creeps in three.
func test_bosses_flyers_and_roots() -> void:
	var foes: Array[Dictionary] = [_foe(&"light", 0.0), _foe(&"boss", 0.0), _foe(&"air", 0.0, true)]
	var near := _near(40.0, 3)
	var frost := SupportPrice.added(&"frost", 1, foes, 3, 3, near)
	check_near(frost[1], frost[0] * 0.5, 1e-4, "half a slow on a boss")
	check(frost[2] > 0.0, "the Frost Spire slows flyers")
	var roots := SupportPrice.added(&"roots", 1, foes, 3, 3, near)
	check_near(roots[2], 0.0, 1e-6, "roots can't reach a flyer")
	var want := 0.7 * 40.0 * SupportPrice.SLOW_SHARE * 2.0 / 3.0
	check_near(roots[0], want, 1e-4, "the Ancient's slow on two creeps in three, no root")


## Shred lifts what armor cuts, below zero armor too, and adds nothing to
## poison; towers that don't slow or shred have no support worth.
func test_shred_pays_against_armor() -> void:
	var foes: Array[Dictionary] = [_foe(&"light", 0.0), _foe(&"armored", 10.0)]
	var near := _near(40.0, 2)
	var rune := SupportPrice.added(&"runesmith", 1, foes, 3, 0, near)
	check(rune[0] > 0.0 and rune[1] > 0.0, "shred pays against armor 0 and 10")
	near[1].fill(0.0)
	var poison := SupportPrice.added(&"runesmith", 1, foes, 3, 0, near)
	check_near(poison[1], 0.0, 1e-6, "shred adds nothing to poison, which armor doesn't cut")
	check(not SupportPrice.supports(&"ballista"), "a Ballista neither slows nor shreds")


## On the empty board before wave 1 the smart bot counts its plan's tiles as
## the Archers to come, so a slow has a worth there and Aqua is weighed with
## the rest; it was worth nothing, and the Light took every first pick.
func test_first_pick_weighs_slows_on_an_empty_board() -> void:
	var sim := GameSim.new()
	sim.rules = &"eletd"
	var bot := Bot.new(sim, &"smart")
	var liner: RouteLiner = bot._liner
	var worth := {}
	for o in liner._pick_options():
		worth[o.choice] = o.worth
	check(sim.towers.is_empty(), "nothing built yet")
	check(worth.get(&"aqua", 0.0) > 0.0, "Aqua has a worth before wave 1")
	check(worth.get(&"verdant", 0.0) > 0.0, "Verdant has a worth before wave 1")


## Two Frost Spires built on one stretch of road are worth one slow, not
## none: of the two, only the one on the lower tile sees the other's slow.
func test_two_slows_on_one_stretch_are_worth_one() -> void:
	var sim := GameSim.new()
	sim.rules = &"eletd"
	sim.gold = 100000
	sim.elements.apply_picks([&"aqua"])
	var route := {}
	for p in sim.field.route():
		route[Grid.tile_at(p)] = true
	var beside: Array[Vector2i] = []
	for r: Vector2i in route:
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var t: Vector2i = r + o
			if not route.has(t) and Grid.in_bounds(t) and not t in beside:
				beside.append(t)
	var pair: Array[Vector2i] = []
	for a in beside:
		for b in beside:
			if pair.is_empty() and a < b and maxi(absi(a.x - b.x), absi(a.y - b.y)) == 1:
				if sim.build(a, &"frost") == Placement.Result.OK:
					if sim.build(b, &"frost") == Placement.Result.OK:
						pair = [a, b]
					else:
						sim.sell(a)
	check_eq(pair.size(), 2, "two Frost Spires side by side beside the road")
	if pair.size() < 2:
		return
	route.clear()
	for p in sim.field.route():
		route[Grid.tile_at(p)] = true
	var foes: Array[Dictionary] = [_foe(&"light", 0.0)]
	var row := PackedFloat32Array([10.0])
	var dps := {&"frost": [row, row, row], &"archer": [row, row, row]}
	var slowed := []
	for t in pair:
		var near := SupportPrice.near_dps(t, sim.towers, {}, foes, dps, {}, route, sim.field, {})
		slowed.append(near[2][0])
	check_eq(slowed, [0.0, 1.0], "the lower tile keeps its slow's worth, the other doesn't")
