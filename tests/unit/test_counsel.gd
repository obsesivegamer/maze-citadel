extends "res://tests/test_case.gd"
## Counter advice (Counsel): the matchups it names follow the damage tables,
## its picks can hit every wave, and its wording reads right.


func test_counter_elements_follow_the_wheel() -> void:
	for e in Damage.WHEEL:
		check_eq(Damage.element_mult(Counsel.counter_element(e), e), Damage.STRONG, "beats %s" % e)
		check_eq(
			Damage.element_mult(Counsel.resisted_element(e), e), Damage.WEAK, "resisted %s" % e
		)
	check_eq(Counsel.counter_element(&"flame"), &"aqua")
	check_eq(Counsel.counter_element(&"light"), &"stone")


func test_multiplier_stacks_attack_and_element() -> void:
	# Archer: Pierce · Light. Dark Wolf Riders (Light armor): 150% × 200%.
	check_near(Counsel.multiplier(&"archer", &"light", &"dark"), 3.0)
	# Cannon: Siege · Flame. Verdant Footmen (Armored): 175% × 200%.
	check_near(Counsel.multiplier(&"cannon", &"armored", &"verdant"), 3.5)
	check_eq(Counsel.multiplier(&"cannon", &"air", &"light", true), 0.0, "siege vs air")
	check_eq(Counsel.multiplier(&"roots", &"air", &"stone", true), 0.0, "ground-only vs fliers")
	check_eq(Counsel.multiplier(&"bard", &"light", &"flame"), 0.0, "bard doesn't attack")


func test_groups_split_the_wave_hp() -> void:
	for w in range(1, WaveDefs.count() + 1):
		var total := 0.0
		var count := 0
		for g in Counsel.groups(w):
			total += g.share
			count += g.count
		check_near(total, 1.0, 1e-4, "wave %d shares" % w)
		check_eq(count, WaveDefs.spawn_list(w).size(), "wave %d count" % w)
	# Wave 31: Aqua Grunts and Flame Harpies are separate groups.
	var g31 := Counsel.groups(31)
	check_eq(g31.size(), 2)
	check_eq(g31[1].element, &"flame")
	check(g31[1].flying, "harpies fly")


func test_picks_answer_the_tutorial_waves() -> void:
	var expected := {
		1: [&"frost", &"archer"],
		2: [&"archer", &"ballista"],
		3: [&"cannon", &"demolisher"],
		4: [&"plague", &"shadow"],
		5: [&"runesmith", &"archer"],
		10: [&"frost"],
	}
	for w in expected:
		check_eq(Counsel.best_towers(w), expected[w], "wave %d" % w)
	var p7 := Counsel.picks(7)
	check_eq(p7[0].id, &"frost")
	check_near(p7[0].mult, 2.5, 1e-4, "frost vs flame steam tanks")
	check_eq(p7[0].vs, "Steam Tank", "named: frost fares differently on the grunts")
	check_eq(Counsel.picks(2)[0].vs, "", "one group, nothing to name")


func test_picks_always_hit_and_cover_fliers() -> void:
	for w in range(1, WaveDefs.count() + 10):
		var picks := Counsel.picks(w)
		check(not picks.is_empty() and picks.size() <= 2, "wave %d has 1-2 picks" % w)
		var fliers := Counsel.groups(w).any(func(g: Dictionary) -> bool: return g.flying)
		var anti_air := false
		for p in picks:
			check(p.mult > 0.0, "wave %d: %s can hit what it was picked for" % [w, p.id])
			check(TowerDefs.TOWERS[p.id].has("attack"), "wave %d: %s attacks" % [w, p.id])
			anti_air = anti_air or TowerDefs.TOWERS[p.id].get("air", false)
		check(anti_air or not fliers, "wave %d: a pick hits its fliers" % w)


func test_wording() -> void:
	check_eq(
		Counsel.plain(Counsel.element_lines(1)[0]),
		"Flame creeps: Aqua towers deal 200%, Verdant towers only 50%."
	)
	check_eq(
		Counsel.plain(Counsel.armor_line(&"armored")),
		"Armored: Siege deals 175%, Magic 125%. Pierce only 50%."
	)
	check_eq(
		Counsel.plain(Counsel.armor_line(&"air")),
		"Air: Pierce deals 175%. Siege and ground-only towers can't hit it."
	)
	check_eq(
		Counsel.plain(Counsel.armor_line(&"boss")),
		"Boss armor: Pierce only 70%, Magic 75%. Everything else deals 100%."
	)
	check_eq(Counsel.plain(Counsel.armor_line(&"light")), "Light armor: Pierce deals 150%.")
	check_eq(Counsel.summary(3), "Counter: Cannon Tower 350%, Demolisher 350%")
	check_eq(Counsel.element_lines(31).size(), 2, "two elements, two lines")


func test_tower_vs_wave() -> void:
	check_eq(Counsel.plain(Counsel.tower_vs_wave(&"cannon", 5)), "can't hit Harpy")
	check_eq(
		Counsel.plain(Counsel.tower_vs_wave(&"archer", 31)), "150% vs Grunt · 175% vs Flame Harpy"
	)
	check_eq(Counsel.tower_vs_wave(&"bard", 3), "", "the Bard gets no line")


func test_creep_notes_on_first_appearance() -> void:
	check_eq(Counsel.creep_notes(4, true), [Counsel.CREEP_NOTES[&"priestess"]])
	check_eq(Counsel.creep_notes(9, true), [], "footmen and priestesses seen before")
	check_eq(Counsel.creep_notes(9).size(), 2, "all notes outside the tutorial")
	check_eq(Counsel.first_wave_of(&"harpy"), 5)
	check_eq(Counsel.first_wave_of(&"felhound"), 0, "summons never spawn from the table")
	for type in Counsel.CREEP_NOTES:
		check(CreepDefs.CREEPS.has(type), "note for a real creep: %s" % type)


func test_lessons_cover_the_tutorial() -> void:
	check_eq(Counsel.LESSONS.size(), Counsel.TUTORIAL_WAVES)
	check_eq(Counsel.lesson(1), "Read the wave")
	check_eq(Counsel.lesson(Counsel.TUTORIAL_WAVES + 1), "")
	check(WaveDefs.has_boss(Counsel.TUTORIAL_WAVES), "the tutorial ends on the first boss")
