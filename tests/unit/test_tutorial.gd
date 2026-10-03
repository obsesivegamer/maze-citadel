extends "res://tests/test_case.gd"
## The tutorial's flow and the Field Guide, driven on a Game that is never
## added to the tree (no world, no rendering) with sim events emitted by hand.


func test_scripted_runs_skip_the_tutorial() -> void:
	check(Tutorial.wanted_for({}, true), "first launch")
	check(not Tutorial.wanted_for({}, false), "finished or turned off")
	for flag in ["autoplay", "shot", "bench", "first-frame-out", "warp-wave", "no-tutorial"]:
		check(not Tutorial.wanted_for({flag: "true"}, true), "--%s skips it" % flag)
	check(Tutorial.wanted_for({"tutorial": "true", "shot": "x"}, false), "--tutorial forces it")


func test_walks_waves_one_to_ten() -> void:
	var game := Game.new()
	var tut := _tutorial(game)
	tut.start()
	check(tut.welcome_visible(), "welcome first")
	check(game.paused, "the opening countdown waits behind the welcome")
	tut._begin()
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
	var game := Game.new()
	var tut := _tutorial(game)
	Tutorial._welcomed = true
	tut.start()
	check_eq(tut.counsel_wave(), 1, "welcome already seen this launch")
	game.sim_event.emit({"type": &"hit", "id": 1, "amount": 10.0, "counter": &"neutral"})
	check_eq(tut.tip_text(), "", "neutral hits teach nothing")
	game.sim_event.emit({"type": &"hit", "id": 1, "amount": 10.0, "counter": &"strong"})
	check(tut.tip_text().contains("counter hits"), "strong-hit tip")
	game.sim_event.emit({"type": &"hit", "id": 1, "amount": 2.0, "counter": &"weak"})
	check(tut.tip_text().contains("resisted"), "weak-hit tip replaces it")
	game.sim_event.emit({"type": &"hit", "id": 1, "amount": 10.0, "counter": &"strong"})
	check(tut.tip_text().contains("resisted"), "each tip only once")
	_free(tut, game)


func test_skip_and_settings() -> void:
	var game := Game.new()
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


func test_field_guide_pauses_and_shows_the_next_wave() -> void:
	var game := Game.new()
	var guide := FieldGuide.new()
	guide.setup(game)
	guide.open()
	check(guide.visible and game.paused, "open pauses")
	check_eq(guide._counsel.wave, 1, "counsel for the next wave")
	guide.close_panel()
	check(not guide.visible and not game.paused, "close resumes")
	game.toggle_pause()
	guide.toggle()
	guide.toggle()
	check(game.paused, "a game paused before opening stays paused")
	check_eq(
		FieldGuide.towers_with("element", &"flame"),
		PackedStringArray(["Cannon", "Demolisher", "Doom Cannon"])
	)
	guide.free()
	game.free()


func test_wheel_focus() -> void:
	var wheel := ElementWheel.new(200.0)
	wheel.size = wheel.custom_minimum_size
	check_eq(wheel.element_at(wheel.node_center(3)), &"flame", "Flame at the bottom")
	check_eq(wheel.element_at(wheel.size / 2.0), &"", "nothing in the middle")
	wheel.free()


func _tutorial(game: Game) -> Tutorial:
	Tutorial._welcomed = false
	var tut := Tutorial.new()
	tut.persist = false
	tut.setup(game, {})
	return tut


func _free(tut: Tutorial, game: Game) -> void:
	tut.free()
	game.free()
