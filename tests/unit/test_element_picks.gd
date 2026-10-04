extends "res://tests/test_case.gd"
## The element picks as the player sees them under eletd (GDD §5.0): locked
## cards and upgrades say what they need, the pick panel offers exactly the
## picks the rules allow and shows the Guardian that will come, and nothing
## changes under classic. Expected wording is written out, not read back.

## Each tower's element, from GDD §6.2; Archer, Cannon and Bard need none.
const NEEDS := {
	&"frost": "Aqua",
	&"plague": "Dark",
	&"runesmith": "Stone",
	&"ballista": "Light",
	&"demolisher": "Flame",
	&"roots": "Verdant",
	&"shadow": "Dark",
}
const CHOICES: Array[StringName] = [
	&"light", &"dark", &"aqua", &"flame", &"verdant", &"stone", &"interest"
]


func _eletd() -> GameSim:
	var sim := GameSim.new()
	sim.rules = &"eletd"
	sim.countdown = -1.0
	return sim


func _eletd_game() -> Game:
	var game := Game.new()
	game.sim.rules = &"eletd"
	return game


## Plays waves up to `to`, killing every creep (Guardians too) as it enters.
func _clear_to(sim: GameSim, to: int) -> void:
	while sim.wave < to:
		sim.start_next_wave()
		while sim.phase == GameSim.Phase.WAVE:
			sim.step()
			for c: SimCreep in sim.creeps.duplicate():
				sim.kill(c)
	sim.drain_events()


func _guardian(sim: GameSim) -> SimCreep:
	for c in sim.creeps:
		if c.type == &"guardian":
			return c
	return null


## The panel offers a row exactly when the sim would take that pick, and says
## why when it doesn't.
func _check_rows_match_the_rules(sim: GameSim, when: String) -> void:
	for choice in CHOICES:
		var r := ElementPicks.row(sim, choice)
		check_eq(r.enabled, sim.elements.can_pick(choice), "%s %s offered" % [when, choice])
		check_eq(r.reason == "", r.enabled, "%s %s: a reason exactly when refused" % [when, choice])


func test_locked_cards_say_what_they_need() -> void:
	var sim := _eletd()
	for id: StringName in NEEDS:
		check_eq(
			ElementPicks.locked_reason(sim, id),
			"Needs %s: pick an element (E)" % NEEDS[id],
			"%s locked" % id
		)
	for id in [&"archer", &"cannon", &"bard"]:
		check_eq(ElementPicks.locked_reason(sim, id), "", "%s open" % id)
	sim.elements.apply_picks([&"aqua"])
	check_eq(ElementPicks.locked_reason(sim, &"frost"), "", "Aqua 1 opens the Frost Spire")
	var classic := GameSim.new()
	for id in TowerDefs.BUILD_ORDER:
		check_eq(ElementPicks.locked_reason(classic, id), "", "classic: %s open" % id)


func test_locked_card_cannot_be_chosen() -> void:
	var game := _eletd_game()
	var refused := []
	game.sim_event.connect(func(e: Dictionary) -> void: refused.append(e))
	game.choose_build(&"frost")
	check_eq(game.build_choice, &"archer", "the build choice stays")
	check_eq(refused.size(), 1, "one refusal")
	check_eq(refused[0].type, &"build_refused", "a build_refused (the thunk)")
	check_eq(refused[0].reason, Placement.Result.LOCKED, "for the lock")
	game.choose_build(&"cannon")
	check_eq(game.build_choice, &"cannon", "a starter can be chosen")
	game.sim.elements.apply_picks([&"aqua"])
	game.choose_build(&"frost")
	check_eq(game.build_choice, &"frost", "and the Frost Spire once Aqua is picked")
	game.free()
	var classic := Game.new()
	classic.choose_build(&"frost")
	check_eq(classic.build_choice, &"frost", "classic: nothing is locked")
	classic.free()


func test_plaque_upgrade_waits_on_the_element_level() -> void:
	var game := _eletd_game()
	game.sim.gold = 10_000
	game.sim.elements.apply_picks([&"aqua"])
	var tile := Vector2i(5, 10)
	check_eq(game.sim.build(tile, &"frost"), Placement.Result.OK, "Frost Spire built")
	var plaque := TowerPlaque.new()
	plaque.setup(game)
	plaque.show_tile(tile)
	check_eq(plaque._upgrade.text, "Needs Aqua level 2", "the button says what it needs")
	check(plaque._upgrade.disabled, "and is disabled")
	game.sim.elements.apply_picks([&"aqua"])
	plaque.refresh()
	check(not plaque._upgrade.disabled, "Aqua 2 opens it")
	check(plaque._upgrade.text.begins_with("Upgrade "), "with its price")
	plaque.free()
	game.free()


func test_first_pick_takes_and_later_ones_summon_the_hp_shown() -> void:
	var sim := _eletd()
	_check_rows_match_the_rules(sim, "start")
	for choice in CHOICES:
		var r := ElementPicks.row(sim, choice)
		check_eq(r.action, "Take", "the first pick takes %s" % choice)
		check_eq(r.hp, 0.0, "no Guardian for the first pick")
	check_eq(ElementPicks.row(sim, &"aqua").from_to, "Level 0 → 1")
	check_eq(ElementPicks.row(sim, &"aqua").unlocks, "Build Frost Spire")
	check_eq(ElementPicks.row(sim, &"interest").unlocks, "+1% interest, +10 cap")
	check_eq(ElementPicks.row(sim, &"interest").from_to, "2% → 3%")
	sim.elements.pick(sim, &"dark")
	_check_rows_match_the_rules(sim, "no pick left")
	check_eq(ElementPicks.reason(sim, &"aqua"), "No pick to spend")
	_clear_to(sim, 5)
	_check_rows_match_the_rules(sim, "wave-5 pick")
	var row := ElementPicks.row(sim, &"dark")
	check_eq(row.action, "Summon Guardian", "a later element pick summons")
	check_eq(row.from_to, "Level 1 → 2")
	check_eq(row.unlocks, "Plague Cauldron and Shadow Obelisk to level 2")
	check_eq(ElementPicks.row(sim, &"interest").action, "Take", "Interest never summons")
	check(sim.elements.pick(sim, &"dark"), "dark 2 taken")
	var g := _guardian(sim)
	check(g != null, "a Guardian walks")
	check_near(g.max_hp, row.hp, 1e-3, "the HP the row showed")
	check_eq(ElementPicks.reason(sim, &"dark"), "Its Guardian is walking")


func test_rows_follow_the_rules_through_a_game() -> void:
	var sim := _eletd()
	sim.elements.pick(sim, &"stone")
	for w in [5, 10, 15, 20]:
		_clear_to(sim, w)
		_check_rows_match_the_rules(sim, "after wave %d" % w)
		sim.elements.pick(sim, &"stone" if sim.elements.level(&"stone") < 3 else &"interest")
		_check_rows_match_the_rules(sim, "after the wave-%d pick" % w)
		var g := _guardian(sim)
		if g != null:
			sim.kill(g)
	check_eq(ElementPicks.reason(sim, &"stone"), "Level 3 reached")
	check_eq(ElementPicks.row(sim, &"stone").from_to, "Level 3")
	sim.elements.apply_picks([&"interest", &"interest"])
	check_eq(ElementPicks.reason(sim, &"interest"), "Taken 3 times")
	check_eq(ElementPicks.row(sim, &"interest").from_to, "5%")


func test_unlock_wording() -> void:
	check_eq(ElementPicks.unlocks(&"dark", 1), "Build Plague Cauldron and Shadow Obelisk")
	check_eq(ElementPicks.unlocks(&"aqua", 2), "Frost Spire to level 2")
	check_eq(
		ElementPicks.unlocks(&"aqua", 3), "Frost Spire to level 3; two fuse into Epic Frost Wyrm"
	)
	check_eq(ElementPicks.unlocks(&"stone", 3), "Runesmith Forge to level 3", "no Epic for Stone")


func test_coming_waves_read_the_wave_table() -> void:
	var sim := _eletd()
	# Waves 1–10 (GDD §9): Flame on 1, 7, 8, 10, Dark on 2 and 6. Aqua beats
	# Flame and loses to Dark.
	check_eq(
		Counsel.plain(ElementPicks.coming_waves(sim, &"aqua")),
		"Waves 1–10: 200% on 1, 7, 8, 10 · 50% on 2, 6"
	)
	sim.wave = 39
	check_eq(
		Counsel.plain(ElementPicks.coming_waves(sim, &"light")), "Wave 40: 200% on 40", "Dark 40"
	)
	sim.wave = 40
	check_eq(ElementPicks.coming_waves(sim, &"light"), "", "no wave left")


func test_header_and_chip() -> void:
	var sim := _eletd()
	check(ElementPicks.header(sim).begins_with("1 pick to spend."), ElementPicks.header(sim))
	check(ElementPicks.header(sim).contains("first element is free"), "says the first is free")
	sim.elements.pick(sim, &"aqua")
	check(ElementPicks.header(sim).contains("the next comes when wave 5 is cleared"), "next pick")
	_clear_to(sim, 10)
	check(ElementPicks.header(sim).begins_with("2 picks to spend."), ElementPicks.header(sim))
	check(ElementPicks.header(sim).contains("summons its Guardian"), "Guardians now")
	check_eq(ElementPicks.chip_text(2), "PICK ×2")


func test_guardian_and_end_screen_words() -> void:
	check_eq(ElementPicks.guardian_title(&"aqua"), "Aqua Guardian")
	check_eq(ElementPicks.guardian_detail(&"aqua", 2), "Kill it to learn Aqua level 2")
	check_eq(ElementPicks.gained_title(&"dark", 3), "Dark level 3")
	check_eq(
		ElementPicks.guardian_leaked(&"aqua", 3),
		"The Aqua Guardian got through: 3 lives lost. It walks again."
	)
	var sim := _eletd()
	check_eq(ElementPicks.reached(sim), "None")
	sim.elements.apply_picks([&"aqua", &"dark", &"dark", &"interest"])
	check_eq(ElementPicks.reached(sim), "Dark 2 · Aqua 1", "wheel order, levels reached")


func test_element_tooltips() -> void:
	var sim := _eletd()
	var tip := ElementPicks.element_tip(sim, &"aqua")
	check(tip.begins_with("Aqua · level 0 of 3"), tip)
	check(tip.contains("Towers: Frost Spire"), "its towers")
	check(tip.contains("Strong vs Flame (200%), weak vs Dark (50%)"), "its counters")
	check(tip.contains("Pick it to build its towers (E)"), "how to get it")


func test_pick_panel_keeps_the_game_running() -> void:
	InputSetup.register()
	var game := _eletd_game()
	var panel := PickPanel.new()
	panel.setup(game)
	panel.open()
	check(panel.visible and not game.paused, "the game keeps running behind it")
	check_eq(panel._focus, 0, "Enter takes the first open row")
	var three := _key(KEY_3)
	check_eq(PickPanel.key_row(three), 2, "3 is the third row")
	check_eq(PickPanel.key_row(_key(KEY_8)), -1, "8 is no row")
	check(panel.handle_key(_key(KEY_8)), "but it doesn't reach the builder")
	check(panel.handle_key(three), "3 takes Aqua")
	check_eq(game.sim.elements.level(&"aqua"), 1, "Aqua 1")
	check(not panel.visible, "closed once no pick is left")
	game.toggle_pause()
	game.sim.elements.granted += 1
	panel.open()
	panel.close_modal()
	check(game.paused, "a paused game stays paused")
	panel.free()
	game.free()


func test_e_opens_the_panel_only_while_a_pick_waits() -> void:
	InputSetup.register()
	var game := _eletd_game()
	var panel := PickPanel.new()
	panel.setup(game)
	check(panel.handle_key(_key(KEY_E)), "E opens it")
	check(panel.visible, "open")
	check(panel.handle_key(_key(KEY_ESCAPE)), "Esc closes it")
	check(not panel.visible, "closed")
	game.pick_element(&"aqua")
	check(not panel.handle_key(_key(KEY_E)), "no pick: E turns the camera as before")
	panel.free()
	game.free()


func test_composite_starters_say_so() -> void:
	TowerInfo.composite = true
	check_eq(TowerInfo.subtitle(&"archer"), "Alliance · Pierce · Composite")
	check_eq(TowerInfo.subtitle(&"cannon"), "Horde · Siege · Composite")
	check(TowerInfo.counters(&"archer").begins_with("100% against everything"), "archer")
	check(not TowerInfo.counters(&"cannon").contains("Strong vs"), "no wheel counter")
	check_eq(TowerInfo.subtitle(&"ballista"), "Alliance · Pierce · Light", "Ballista keeps Light")
	TowerInfo.composite = false
	check_eq(TowerInfo.subtitle(&"archer"), "Alliance · Pierce · Light", "classic")
	check(TowerInfo.counters(&"archer").begins_with("Strong vs Dark · Weak vs Stone"), "classic")


## The Field Guide's wheel lists under each element the towers that attack
## with it in the sim, so the composite starters are under none.
func test_guide_wheel_lists_the_towers_the_sim_gives_each_element() -> void:
	var sim := _eletd()
	TowerInfo.composite = true
	for e in Damage.WHEEL:
		var want := PackedStringArray()
		for id in TowerDefs.BUILD_ORDER + TowerDefs.EPICS:
			if sim.elements.attack_element(id) == e:
				want.append(TowerInfo.short_name(id))
		check_eq(FieldGuide.towers_with(&"element", e), want, "%s" % e)
	TowerInfo.composite = false


## The next-wave chip's "Counter:" line names only towers that can be built,
## and names more once a pick opens them.
func test_next_wave_counter_names_only_open_towers() -> void:
	var game := _eletd_game()
	game.camera = CameraRig.new()
	var bar := HudTopBar.new()
	bar.setup(game)
	var counter := func() -> String:
		bar.refresh()
		var tip: String = bar._next.get_parent().tooltip_text
		return tip.substr(tip.find("Counter:"))
	var before: String = counter.call()
	for id in TowerDefs.BUILD_ORDER:
		if game.sim.elements.needs(id) != "":
			check(not before.contains(TowerInfo.full_name(id)), "%s is locked" % id)
	game.pick_element(&"aqua")
	check(counter.call().contains(TowerInfo.full_name(&"frost")), "Frost Spire once Aqua is in")
	bar.free()
	game.camera.camera.free()
	game.camera.free()
	game.free()


func test_counsel_names_only_open_towers_and_composite_numbers() -> void:
	var sim := _eletd()
	var open := sim.elements.unlocked_towers()
	for w in range(1, WaveDefs.count() + 1):
		for id in Counsel.best_towers(w, &"eletd", 2, open):
			check(id in open, "wave %d names %s, which is locked" % [w, id])
	# Composite Archer on Dark Wolf Riders (Light armor): Pierce 150% only.
	check_near(Counsel.multiplier(&"archer", &"light", &"dark", false, &"eletd"), 1.5)
	check_near(Counsel.multiplier(&"archer", &"light", &"dark"), 3.0, 1e-4, "classic Light")


func test_tutorial_never_marks_a_locked_tower() -> void:
	var game := _eletd_game()
	Tutorial._welcomed = true
	var tut := Tutorial.new()
	tut.persist = false
	tut.setup(game, {})
	tut.start()
	for w in range(0, Counsel.TUTORIAL_WAVES):
		if w > 0:
			game.sim_event.emit({"type": &"wave_started", "wave": w})
		check(not tut.marked().is_empty(), "wave %d names a tower" % (w + 1))
		for id in tut.marked():
			check_eq(game.sim.elements.needs(id), "", "wave %d marks %s" % [w + 1, id])
	tut.free()
	game.free()


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e
