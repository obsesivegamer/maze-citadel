extends "res://tests/test_case.gd"
## The rules a new player trips over under eletd, said where they bite: the
## first leak, flying and composite waves, what an element pick buys and that
## one waits, gold past the interest cap, and what was left unspent at the
## end. Nothing of it shows under classic. Expected wording is written out,
## not read back.

const FLYING := (
	"ignores your maze and flies straight from portal to gate;"
	+ " only wing-icon towers beside the flight line hit it"
)


func _eletd() -> GameSim:
	var sim := GameSim.new()
	sim.rules = &"eletd"
	sim.countdown = -1.0
	return sim


func _leak(creep: StringName) -> Dictionary:
	return {"type": &"leaked", "id": 1, "cost": 1, "lives": 19, "wave": 1, "creep": creep}


func _started(wave: int) -> Dictionary:
	return {"type": &"wave_started", "wave": wave}


## The interest GameSim pays on its next tick with `gold` in hand.
func _payout(sim: GameSim, gold: int) -> int:
	sim.gold = gold
	sim.interest_timer = GameSim.DT / 2.0
	sim.drain_events()
	sim.step()
	for e in sim.drain_events():
		if e.type == &"interest":
			return e.amount
	return 0


func test_every_flying_wave_says_where_flyers_go() -> void:
	var flyers: Array[int] = []
	for w in range(1, WaveDefs.count() + 1):
		if TowerInfo.flying(w, &"eletd"):
			flyers.append(w)
		check(not TowerInfo.flying(w, &"classic"), "classic wave %d keeps its banner" % w)
	check_eq(flyers, [5, 11, 13, 15, 17, 19, 20, 26, 31, 34, 36, 39], "every Harpy wave")
	check_eq(TowerInfo.flying_text(), FLYING)
	var chip := WaveIcons.new()
	chip.show_wave(5, &"", &"eletd")
	check(_labels(chip).has("Flying"), "the wave chip tags wave 5 Flying")
	chip.show_wave(31, &"", &"eletd")
	check(_labels(chip).has("Flying"), "and wave 31, not only the first")
	chip.show_wave(4, &"", &"eletd")
	check(not _labels(chip).has("Flying"), "no tag without flyers")
	chip.show_wave(5, &"", &"classic")
	check(not _labels(chip).has("Flying"), "classic's chip is as before")
	chip.free()
	var note := Counsel.creep_note(&"harpy")
	check(note.contains("fly straight from the portal to the gate"), note)


func test_composite_waves_say_elements_dont_matter() -> void:
	var waves: Array[int] = []
	for w in range(1, WaveDefs.count() + 1):
		if TowerInfo.composite_wave(w, &"eletd"):
			waves.append(w)
		check(not TowerInfo.composite_wave(w, &"classic"), "classic wave %d" % w)
	check_eq(waves, [14, 27, 34])
	check_eq(
		TowerInfo.composite_text(),
		(
			"elements don't matter this wave: Archers and Cannons hit at full strength,"
			+ " element towers 90%"
		)
	)


func test_first_leak_is_explained_once() -> void:
	var sim := _eletd()
	var notices := HudNotices.new()
	check_eq(notices.line_for(sim, _leak(&"guardian")), "", "a Guardian's leak has its own line")
	check_eq(
		notices.line_for(sim, _leak(&"grunt")),
		(
			"Leaked creeps cost lives and walk the maze again until killed.\n"
			+ "Interest stops until the board is clear."
		)
	)
	check_eq(notices.line_for(sim, _leak(&"harpy")), "", "once a game")


func test_rows_say_what_a_pick_does() -> void:
	var sim := _eletd()
	check_eq(ElementPicks.does(sim, &"aqua"), "Unlocks Frost Spire", "the first pick is free")
	check_eq(ElementPicks.does(sim, &"dark"), "Unlocks Plague Cauldron and Shadow Obelisk")
	check_eq(
		ElementPicks.does(sim, &"interest"),
		"Interest: +10 gold every 15 s once you hold 1,000 gold"
	)
	check_eq(ElementPicks.row(sim, &"aqua").unlocks, ElementPicks.does(sim, &"aqua"), "the row")
	sim.elements.pick(sim, &"dark")
	sim.elements.granted += 1
	sim.gold = 10_000
	for y in [10, 12]:
		check_eq(sim.build(Vector2i(5, y), &"plague"), Placement.Result.OK)
	check_eq(
		Counsel.plain(ElementPicks.does(sim, &"dark")),
		(
			"Lets your 2 Plague Cauldrons and any Shadow Obelisks upgrade to level 2\n"
			+ "Summons a Guardian: kill it to gain Dark level 2"
		)
	)
	check_eq(
		Counsel.plain(ElementPicks.does(sim, &"flame")),
		"Unlocks Demolisher\nSummons a Guardian: kill it to gain Flame"
	)
	sim.elements.apply_picks([&"aqua", &"aqua", &"verdant"])
	check_eq(sim.build(Vector2i(7, 10), &"frost"), Placement.Result.OK)
	for y in [12, 14]:
		check_eq(sim.build(Vector2i(7, y), &"roots"), Placement.Result.OK)
	check(
		ElementPicks.does(sim, &"aqua").begins_with(
			"Lets your Frost Spire upgrade to level 3; two at level 3 fuse into Epic Frost Wyrm"
		),
		"one tower, and the Epic at level 3"
	)
	check(
		ElementPicks.does(sim, &"verdant").begins_with("Lets your 2 Ancients of Roots upgrade"),
		"plural of Ancient of Roots"
	)


## Interest stops growing exactly where the sim stops paying more, with every
## number of Interest picks.
func test_interest_cap_gold_is_where_the_sim_stops_paying_more() -> void:
	for n in EletdRules.INTEREST_PICKS + 1:
		var sim := _eletd()
		sim.elements.interest_picks = n
		var at := ElementPicks.interest_cap_gold(sim)
		var cap := sim.elements.interest_cap()
		check_eq(_payout(sim, at), cap, "%d picks: the full payout at %d" % [n, at])
		check(_payout(sim, at - 1) < cap, "%d picks: less below it" % n)
		check_eq(_payout(sim, at * 3), cap, "%d picks: no more above it" % n)
		sim.gold = at
		check(ElementPicks.interest_maxed(sim), "maxed at %d" % at)
		check_eq(ElementPicks.gold_nudge(sim), "", "no nudge while nothing is idle")
		sim.gold = at - 1
		check(not ElementPicks.interest_maxed(sim), "not maxed below")
	var sim := _eletd()
	sim.gold = 1001
	check_eq(
		ElementPicks.gold_nudge(sim), "Gold above 1,000 earns no more interest: build or upgrade"
	)
	var classic := GameSim.new()
	classic.gold = 5000
	check(not ElementPicks.interest_maxed(classic), "classic's gold counter is as before")
	check_eq(ElementPicks.gold_nudge(classic), "")


func test_waiting_picks_are_announced_and_recalled() -> void:
	var sim := _eletd()
	check_eq(ElementPicks.unspent_reminder(sim), "1 element pick unspent: press E")
	sim.elements.granted += 2
	check_eq(ElementPicks.unspent_reminder(sim), "3 element picks unspent: press E")
	check_eq(
		ElementPicks.granted_text(sim),
		(
			"3 element picks ready: press E\n"
			+ "A pick unlocks an element's towers, lets them upgrade a level, or raises interest"
		)
	)
	sim.elements.granted -= 2
	check(ElementPicks.granted_text(sim).begins_with("Element pick ready: press E"), "one pick")
	sim.elements.pick(sim, &"interest")
	check_eq(ElementPicks.unspent_reminder(sim), "", "nothing to spend")
	var classic := GameSim.new()
	check_eq(ElementPicks.unspent_reminder(classic), "", "classic has no picks")


func test_wave_start_recalls_picks_and_nudges_idle_gold_every_few_waves() -> void:
	var sim := _eletd()
	var notices := HudNotices.new()
	check_eq(notices.line_for(sim, _started(1)), "1 element pick unspent: press E")
	sim.elements.pick(sim, &"aqua")
	check_eq(notices.line_for(sim, _started(2)), "", "nothing waits, the gold all earns")
	sim.gold = 1500
	var nudge := "Gold above 1,000 earns no more interest: build or upgrade"
	check_eq(notices.line_for(sim, _started(3)), nudge)
	for w in range(4, 3 + HudNotices.GOLD_NUDGE_WAVES):
		check_eq(notices.line_for(sim, _started(w)), "", "quiet on wave %d" % w)
	check_eq(notices.line_for(sim, _started(3 + HudNotices.GOLD_NUDGE_WAVES)), nudge, "again")
	sim.elements.granted += 1
	check_eq(
		notices.line_for(sim, _started(4 + HudNotices.GOLD_NUDGE_WAVES)),
		"1 element pick unspent: press E",
		"the pick every wave, the gold not yet"
	)


func test_locked_cards_name_the_pick_while_one_waits() -> void:
	var sim := _eletd()
	check_eq(ElementPicks.card_hint(sim, &"frost"), "Pick Aqua")
	check_eq(ElementPicks.card_hint(sim, &"shadow"), "Pick Dark")
	check_eq(ElementPicks.card_hint(sim, &"archer"), "", "open cards keep their cost")
	check_eq(ElementPicks.locked_reason(sim, &"frost"), "Needs Aqua: press E and take it")
	sim.elements.pick(sim, &"dark")
	check_eq(ElementPicks.card_hint(sim, &"frost"), "", "no pick waits")
	check_eq(ElementPicks.card_hint(sim, &"plague"), "", "Dark is open")
	check_eq(ElementPicks.locked_reason(sim, &"frost"), "Needs Aqua: pick an element (E)")
	sim.elements.granted += 1
	sim.elements.pick(sim, &"aqua")
	sim.elements.granted += 1
	check_eq(ElementPicks.card_hint(sim, &"frost"), "", "its Guardian walks")
	check_eq(ElementPicks.locked_reason(sim, &"frost"), "Needs Aqua: kill the Aqua Guardian")
	for id in TowerDefs.BUILD_ORDER:
		check_eq(ElementPicks.card_hint(GameSim.new(), id), "", "classic: %s" % id)


func test_end_screen_names_what_was_left_unspent() -> void:
	var sim := _eletd()
	sim.gold = 50
	check_eq(ElementPicks.unspent(sim), "1 pick · 50 gold")
	sim.elements.granted = 4
	sim.elements.spent = 1
	sim.gold = 3453
	check_eq(ElementPicks.unspent(sim), "3 picks · 3,453 gold")
	sim.elements.spent = 4
	check_eq(ElementPicks.unspent(sim), "0 picks · 3,453 gold", "idle gold alone is notable")
	sim.gold = 900
	check_eq(ElementPicks.unspent(sim), "", "nothing notable")
	check_eq(TowerInfo.fmt_gold(1_234_567), "1,234,567")
	check_eq(TowerInfo.fmt_gold(999), "999")


func _labels(node: Node) -> Array[String]:
	var out: Array[String] = []
	for c in node.find_children("*", "Label", true, false):
		out.append((c as Label).text)
	return out
