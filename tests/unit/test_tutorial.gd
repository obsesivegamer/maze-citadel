extends "res://tests/test_case.gd"
## The tutorial's flow and the Field Guide, driven on a Game that is never
## added to the tree (no world, no rendering) with sim events emitted by hand.
## Games are pinned to a rule set so the player's saved choice can't leak in.


func test_scripted_runs_skip_the_tutorial() -> void:
	check(Tutorial.wanted_for({}, true), "first launch")
	check(not Tutorial.wanted_for({}, false), "finished or turned off")
	for flag in ["autoplay", "shot", "bench", "first-frame-out", "warp-wave", "no-tutorial"]:
		check(not Tutorial.wanted_for({flag: "true"}, true), "--%s skips it" % flag)
	check(not Tutorial.wanted_for({}, true, true), "headless tools and probes skip it")
	check(Tutorial.wanted_for({"tutorial": "true", "shot": "x"}, false), "--tutorial forces it")
	check(Tutorial.wanted_for({"tutorial": "true"}, false, true), "even headless")


func test_walks_waves_one_to_ten() -> void:
	var game := _classic()
	var tut := _tutorial(game)
	tut.start()
	check(tut.welcome_visible(), "welcome first")
	check(game.paused, "the opening countdown waits behind the welcome")
	tut._welcome._on_dim_input(_click())
	check(tut.welcome_visible(), "a click beside the welcome doesn't dismiss it")
	tut.begin()
	check(not tut.welcome_visible() and not game.paused, "begin resumes")
	check_eq(tut.counsel_wave(), 1)
	check_eq(tut.marked(), Counsel.best_towers(1), "picks glow on the card bar")
	for w in range(1, Counsel.TUTORIAL_WAVES):
		game.sim_event.emit({"type": &"wave_started", "wave": w})
		check_eq(tut.counsel_wave(), w + 1, "counsel for the wave after %d" % w)
	game.sim_event.emit({"type": &"wave_started", "wave": Counsel.TUTORIAL_WAVES})
	check_eq(tut.step, Tutorial.Step.GRADUATED)
	check(tut.card_visible() and tut.marked().is_empty(), "closing card, no glow")
	game.sim_event.emit({"type": &"wave_started", "wave": Counsel.TUTORIAL_WAVES + 1})
	check(not tut.card_visible(), "gone once the next wave starts")
	_free(tut, game)


func test_tips_show_once() -> void:
	var game := _classic()
	var tut := _tutorial(game)
	Tutorial._welcomed = true
	tut.start()
	check_eq(tut.counsel_wave(), 1, "welcome already seen this launch")
	game.sim_event.emit({"type": &"hit", "id": 1, "amount": 10.0, "counter": &"neutral"})
	check_eq(tut.tip_text(), "", "neutral hits teach nothing")
	game.sim_event.emit({"type": &"hit", "id": 1, "amount": 10.0, "counter": &"strong"})
	check(tut.tip_text().contains("counter hits"), "strong-hit tip")
	check(tut.tip_text().contains("200% damage"), "numbers come from the damage table")
	game.sim_event.emit({"type": &"hit", "id": 1, "amount": 2.0, "counter": &"weak"})
	check(tut.tip_text().contains("resisted"), "weak-hit tip replaces it")
	game.sim_event.emit({"type": &"hit", "id": 1, "amount": 10.0, "counter": &"strong"})
	check(tut.tip_text().contains("resisted"), "each tip only once")
	_free(tut, game)


func test_skip_and_settings() -> void:
	var game := _classic()
	var tut := _tutorial(game)
	tut.start()
	tut.finish()
	check(not tut.welcome_visible() and not tut.card_visible(), "skip hides everything")
	check(not game.paused, "skip resumes the countdown")
	tut.on_setting("tutorial", true)
	check_eq(tut.counsel_wave(), 1, "turned back on before wave 1")
	tut.on_setting("camera_shake", false)
	check_eq(tut.counsel_wave(), 1, "other settings ignored")
	tut.on_setting("tutorial", false)
	check_eq(tut.step, Tutorial.Step.OFF)
	_free(tut, game)
	# From Settings before wave 1 on a fresh launch: no welcome under the panel.
	game = _classic()
	tut = _tutorial(game)
	tut.on_setting("tutorial", true)
	check(not tut.welcome_visible() and not game.paused, "straight to the counsel card")
	check_eq(tut.counsel_wave(), 1)
	_free(tut, game)
	# After the tutorial waves: only the closing card.
	game = _classic()
	game.sim.wave = Counsel.TUTORIAL_WAVES + 2
	tut = _tutorial(game)
	tut.on_setting("tutorial", true)
	check_eq(tut.step, Tutorial.Step.GRADUATED)
	_free(tut, game)


func test_modals_keep_keys_from_the_game() -> void:
	InputSetup.register()
	var esc := _key(KEY_ESCAPE)
	var space := _key(KEY_SPACE)
	var enter := _key(KEY_ENTER)
	var h := _key(KEY_H)
	var n := _key(KEY_N)
	var one := _key(KEY_1)
	check_eq(Hud.modal_action(n, false, false), &"", "no modal: keys reach the game")
	check_eq(Hud.modal_action(esc, false, false), &"", "Esc still deselects")
	check_eq(Hud.modal_action(h, false, false), &"open_guide")
	for k in [space, n, one]:
		check_eq(Hud.modal_action(k, true, false), &"swallow", "guide blocks %s" % k.as_text())
		check_eq(Hud.modal_action(k, true, true), &"swallow", "guide over welcome")
	check_eq(Hud.modal_action(esc, true, false), &"close_guide")
	check_eq(Hud.modal_action(h, true, false), &"close_guide")
	check_eq(Hud.modal_action(esc, true, true), &"close_guide", "topmost first")
	for k in [esc, space, enter]:
		check_eq(Hud.modal_action(k, false, true), &"begin", "%s begins" % k.as_text())
	check_eq(Hud.modal_action(h, false, true), &"open_guide", "guide over the welcome")
	check_eq(Hud.modal_action(n, false, true), &"swallow", "no early wave")
	check_eq(Hud.modal_action(one, false, true), &"swallow", "no build pick")


func test_field_guide_pauses_and_shows_the_next_wave() -> void:
	var game := _classic()
	var guide := FieldGuide.new()
	guide.setup(game)
	guide.open()
	check(guide.visible and game.paused, "open pauses")
	check_eq(guide._counsel.wave, 1, "counsel for the next wave")
	guide.close_modal()
	check(not guide.visible and not game.paused, "close resumes")
	game.toggle_pause()
	guide.toggle()
	guide.toggle()
	check(game.paused, "a game paused before opening stays paused")
	game.toggle_pause()
	guide.open()
	guide._wheel.focus = &"flame"
	guide._on_dim_input(_click(MOUSE_BUTTON_WHEEL_DOWN))
	check(guide.visible, "scrolling over the dim keeps the guide open")
	guide._on_dim_input(_click())
	check(not guide.visible and not game.paused, "a click beside the guide closes it")
	check_eq(guide._wheel.focus, &"", "closing clears the wheel focus")
	check_eq(
		FieldGuide.towers_with("element", &"flame"),
		PackedStringArray(["Cannon", "Demolisher", "Doom Cannon"])
	)
	guide.free()
	game.free()


func test_guide_over_the_welcome() -> void:
	var game := _classic()
	var tut := _tutorial(game)
	var guide := FieldGuide.new()
	guide.setup(game)
	tut.start()
	guide.open()
	guide.close_modal()
	check(tut.welcome_visible() and game.paused, "closing the guide leaves the welcome paused")
	tut.begin()
	check(not game.paused, "Begin resumes")
	check_eq(tut.counsel_wave(), 1)
	guide.free()
	_free(tut, game)
	# A game the player paused stays paused through both.
	game = _classic()
	game.toggle_pause()
	tut = _tutorial(game)
	guide = FieldGuide.new()
	guide.setup(game)
	tut.start()
	guide.open()
	guide.close_modal()
	tut.begin()
	check(game.paused, "the player's pause outlasts the welcome and the guide")
	guide.free()
	_free(tut, game)


func test_wheel_focus() -> void:
	var wheel := ElementWheel.new(200.0)
	wheel.size = wheel.custom_minimum_size
	check_eq(wheel.element_at(wheel.node_center(3)), &"flame", "Flame at the bottom")
	check_eq(wheel.element_at(wheel.size / 2.0), &"", "nothing in the middle")
	wheel.free()


## The default rules teach what classic never needed: the short reach, and
## that locked towers wait on an element pick (E). Every lesson only marks
## towers the player can build, and an element picked mid-lesson can add one.
func test_element_td_tutorial() -> void:
	var game := _game(&"eletd")
	var tut := _tutorial(game)
	var text := _texts(tut._welcome)
	check(text.contains("eight tiles around it"), "the welcome teaches the reach")
	check(text.contains("Locked towers need their element"), "and that locked towers need one")
	check(text.contains("Press %s" % ElementPicks.KEY), "and the pick key")
	tut.start()
	tut.begin()
	var open := game.sim.elements.unlocked_towers()
	for w in range(1, Counsel.TUTORIAL_WAVES):
		for id in tut.marked():
			check(id in open, "lesson %d marks %s, which can be built" % [w, id])
		game.sim_event.emit({"type": &"wave_started", "wave": w})
	game.sim_event.emit({"type": &"wave_started", "wave": Counsel.TUTORIAL_WAVES})
	check_eq(tut.step, Tutorial.Step.GRADUATED, "the last lesson ends it, as in classic")
	_free(tut, game)
	var classic := _classic()
	var classic_tut := _tutorial(classic)
	check(not _texts(classic_tut._welcome).contains("eight tiles"), "classic keeps its welcome")
	_free(classic_tut, classic)


func _texts(node: Node) -> String:
	var out := ""
	for c in node.find_children("*", "RichTextLabel", true, false):
		out += (c as RichTextLabel).text + "\n"
	return out


## A Game under `rules` whatever the player's saved choice (Game._init).
func _game(rules: StringName) -> Game:
	Game._carry = {"rules": rules}
	return Game.new()


func _classic() -> Game:
	return _game(&"classic")


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func _click(button := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	return e


func _tutorial(game: Game) -> Tutorial:
	Tutorial._welcomed = false
	var tut := Tutorial.new()
	tut.persist = false
	tut.setup(game, {})
	return tut


func _free(tut: Tutorial, game: Game) -> void:
	tut.free()
	game.free()
