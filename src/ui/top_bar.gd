class_name HudTopBar
extends Control
## Top of the HUD (GDD §11). Left: gold, lives, interest ring and next payout,
## and under eletd "Interest maxed" by the gold once more earns nothing and
## the element levels with the Pick chip (ElementStrip).
## Centre: wave n/40 and the next-wave chip with its countdown and a call
## button, and under eletd the wave after next and the air cover for the
## first flying wave of the two (AirCover). Right: mode chip, speed, pause,
## camera presets, boss tracking, the Field Guide and settings. refresh() runs
## every frame but only touches a node when the value it shows has changed.

signal settings_pressed
signal guide_pressed
signal picks_pressed

const MARGIN := Vector2(10, 8)
const ICON_PX := 22.0
const BUTTON_PX := 30.0
const RING_PX := 28.0
const GROUP_GAP := 16
const NEXT_ICON_PX := 18.0
const BOSS_CHIP_GAP := 6.0
const CAMERA_TIPS := {
	&"full": "Full board (R)", &"portal": "Portal close-up (C)", &"gate": "Gate defense (C)"
}
const CAMERA_GLYPHS := {&"full": &"cam_full", &"portal": &"cam_portal", &"gate": &"cam_gate"}
const LOCKED_TIP := "Interest is locked until every creep on the board is dead"

var left_panel: PanelContainer
var center_panel: PanelContainer
var _right_panel: PanelContainer

var _game: Game
var _gold := UiKit.label("", &"Number")
var _lives := UiKit.label("", &"Number")
var _lives_box := UiKit.hbox(5)
var _gold_box := UiKit.hbox(5)
var _ring := InterestRing.new(RING_PX)
var _interest := UiKit.hbox(5)
var _interest_tip := ""
var _payout := UiKit.label("", &"Number", UiTheme.SIZE_LARGE)
var _wave := UiKit.label("", &"Title")
var _wave_total := UiKit.label("", &"Dim", UiTheme.SIZE_BODY)
var _wave_inf := UiIcon.new(&"infinity", 16.0, UiTheme.TEXT_DIM)
var _next_caption := UiKit.label("", &"Caption")
var _next := WaveIcons.new(NEXT_ICON_PX, 13)
## The wave after next, shown under rules with a long pause between waves.
var _after_caption := UiKit.label("", &"Caption")
var _after := WaveIcons.new(NEXT_ICON_PX * 0.8, 11)
## eletd: "Air cover, wave 5: weak", re-estimated when the board changes.
var _air := UiKit.label("", &"", UiTheme.SIZE_SMALL)
var _air_est := {}
## AirCover.wave_flyers for _air_wave, kept while only the board changes.
var _air_flyers := {}
var _air_wave := 0
var _air_dirty := true
var _call: Button
## Difficulty chip per difficulty the rule set offers.
var _levels := {}
var _infinite: Button
var _twists: Button
var _lock := UiIcon.new(&"lock", 16.0)
var _speeds: Array[Button] = []
var _pause: Button
var _boss: Button
var _boss_chip := UiKit.panel(&"Chip", false)
var _boss_text := UiKit.label("", &"", UiTheme.SIZE_SMALL)
## eletd only: the element levels and the Pick chip, and the note by the gold.
var _elements: ElementStrip
var _maxed: Label
var _shown := {}


func setup(game: Game) -> void:
	_game = game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_left()
	_build_center()
	_build_right()
	_build_boss_chip()
	game.speed_changed.connect(_on_speed)
	game.sim_event.connect(_on_sim_event)
	game.pause_changed.connect(_on_pause)
	game.camera.boss_tracking_changed.connect(_on_boss_tracking)
	_on_speed(game.speed)
	_on_pause(game.paused)
	_on_boss_tracking(game.camera.boss_tracking)
	_sync_mode()


func _build_left() -> void:
	var p := UiKit.panel()
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	p.position = MARGIN
	add_child(p)
	left_panel = p
	var row := UiKit.hbox(GROUP_GAP)
	p.add_child(row)
	_gold_box.add_child(UiIcon.new(&"coin", ICON_PX))
	_gold_box.add_child(_gold)
	if _game.sim.elements.enabled:
		_maxed = UiKit.label("INTEREST MAXED", &"Caption", UiTheme.SIZE_TINY)
		_maxed.add_theme_color_override("font_color", UiTheme.GOLD)
		_maxed.visible = false
		_gold_box.add_child(_maxed)
	_gold_box.tooltip_text = "Gold"
	_gold_box.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_gold_box)
	_lives_box.add_child(UiIcon.new(&"heart", ICON_PX))
	_lives_box.add_child(_lives)
	var costly := "bosses and Bulky creeps" if _game.sim.rules == &"eletd" else "bosses"
	_lives_box.tooltip_text = "Lives. A leak costs 1 (%s 2) and the creep runs again." % costly
	_lives_box.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_lives_box)
	_interest.add_child(_ring)
	_payout.add_theme_color_override("font_color", UiTheme.GOLD_BRIGHT)
	_interest.add_child(_payout)
	_interest.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_interest)
	if _game.sim.elements.enabled:
		row.add_child(UiKit.divider())
		_elements = ElementStrip.new(_game)
		_elements.pick_pressed.connect(picks_pressed.emit)
		row.add_child(_elements)


## Interest picks (eletd) raise the rate and the cap the tooltip quotes.
func _interest_text() -> String:
	var el := _game.sim.elements
	return (
		"Interest: every %d s you earn %d%% of unspent gold (max +%d). Next payout shown."
		% [GameSim.INTEREST_PERIOD, roundi(el.interest_rate() * 100), el.interest_cap()]
	)


func _build_center() -> void:
	center_panel = UiKit.panel()
	center_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	center_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_panel.offset_top = MARGIN.y
	add_child(center_panel)
	var row := UiKit.hbox(12)
	center_panel.add_child(row)
	var wave_col := UiKit.vbox(-4)
	wave_col.add_child(UiKit.label("WAVE", &"Caption"))
	var count := UiKit.hbox(2)
	count.alignment = BoxContainer.ALIGNMENT_BEGIN
	count.add_child(_wave)
	count.add_child(_wave_total)
	count.add_child(_wave_inf)
	wave_col.add_child(count)
	row.add_child(wave_col)
	row.add_child(UiKit.divider(36))
	var next_col := UiKit.vbox(1)
	next_col.add_child(_next_caption)
	next_col.add_child(_next)
	next_col.add_child(_after_caption)
	next_col.add_child(_after)
	_air.add_theme_font_override("font", UiTheme.bold())
	_air.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_air.mouse_filter = Control.MOUSE_FILTER_PASS
	_air.visible = false
	next_col.add_child(_air)
	next_col.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(next_col)
	_call = UiKit.icon_button(_game, &"next", "Call the next wave now (N)", BUTTON_PX)
	_call.pressed.connect(_game.call_next_wave)
	UiKit.key_badge(_call, "N")
	row.add_child(_call)


func _build_right() -> void:
	var p := UiKit.panel()
	_right_panel = p
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.offset_right = -MARGIN.x
	p.offset_top = MARGIN.y
	add_child(p)
	var row := UiKit.hbox(6)
	p.add_child(row)
	var group := ButtonGroup.new()
	for level in EletdRules.difficulties(_game.sim.rules):
		_levels[level] = _segment(
			TowerInfo.difficulty_name(level),
			TowerInfo.difficulty_tip(level, _game.sim.rules),
			group
		)
	_infinite = UiKit.icon_button(_game, &"infinity", TowerInfo.infinite_tip(), BUTTON_PX, true)
	_twists = UiKit.icon_button(_game, &"twist", TowerInfo.twists_tip(), BUTTON_PX, true)
	for b in _levels.values() + [_infinite, _twists]:
		b.toggled.connect(func(_on: bool) -> void: _apply_mode())
		row.add_child(b)
	_lock.tooltip_text = "Mode is locked once wave 1 spawns"
	_lock.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_lock)
	row.add_child(UiKit.divider())
	var speed_group := ButtonGroup.new()
	for s in [1, 2, 3]:
		var b := _segment("×%d" % s, "Game speed ×%d (F cycles)" % s, speed_group)
		b.pressed.connect(_set_speed.bind(s))
		_speeds.append(b)
		row.add_child(b)
	_pause = UiKit.icon_button(_game, &"pause", "Pause (Space). You can still build.", BUTTON_PX)
	_pause.pressed.connect(_game.toggle_pause)
	row.add_child(_pause)
	row.add_child(UiKit.divider())
	for preset in CameraRig.PRESET_ORDER:
		var b := UiKit.icon_button(_game, CAMERA_GLYPHS[preset], CAMERA_TIPS[preset], BUTTON_PX)
		b.pressed.connect(_camera_preset.bind(preset))
		row.add_child(b)
	_boss = UiKit.icon_button(_game, &"boss_track", "Follow the boss (B)", BUTTON_PX, true)
	_boss.toggled.connect(func(on: bool) -> void: _game.camera.set_boss_tracking(on))
	row.add_child(_boss)
	row.add_child(UiKit.divider())
	var guide := UiKit.icon_button(
		_game, &"book", "Field Guide: elements, armor and the next wave (H)", BUTTON_PX
	)
	guide.pressed.connect(guide_pressed.emit)
	row.add_child(guide)
	var gear := UiKit.icon_button(_game, &"gear", "Settings (F10)", BUTTON_PX)
	gear.pressed.connect(settings_pressed.emit)
	row.add_child(gear)


func _segment(text: String, tip: String, group: ButtonGroup) -> Button:
	var b := UiKit.text_button(_game, text, &"Segment")
	b.toggle_mode = true
	b.button_group = group
	b.tooltip_text = tip
	b.custom_minimum_size.y = BUTTON_PX
	return b


func _build_boss_chip() -> void:
	_boss_chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_chip.visible = false
	var row := UiKit.hbox(6)
	row.add_child(UiIcon.new(&"eye", 16.0))
	row.add_child(_boss_text)
	var key := UiKit.label("B", &"Caption")
	row.add_child(key)
	_boss_chip.add_child(row)
	_boss_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_chip)


func _camera_preset(preset: StringName) -> void:
	_game.camera.set_boss_tracking(false)
	_game.camera.preset(preset)


func _set_speed(s: int) -> void:
	while _game.speed != s:
		_game.cycle_speed()


func _on_speed(s: int) -> void:
	for i in _speeds.size():
		_speeds[i].set_pressed_no_signal(i + 1 == s)


func _on_pause(paused: bool) -> void:
	UiKit.button_icon(_pause).glyph = &"play" if paused else &"pause"
	_pause.tooltip_text = "Resume (Space)" if paused else "Pause (Space). You can still build."


func _on_boss_tracking(on: bool) -> void:
	_boss.set_pressed_no_signal(on)
	_boss_chip.visible = on


func _apply_mode() -> void:
	var level: StringName = &"normal"
	for l: StringName in _levels:
		if _levels[l].button_pressed:
			level = l
	if not _game.set_mode(level, _infinite.button_pressed, _twists.button_pressed):
		_sync_mode()


func _sync_mode() -> void:
	var sim := _game.sim
	for level: StringName in _levels:
		_levels[level].set_pressed_no_signal(level == sim.difficulty)
	_infinite.set_pressed_no_signal(sim.infinite)
	_twists.set_pressed_no_signal(sim.twists)
	var locked := sim.wave > 0
	for b in _levels.values() + [_infinite, _twists]:
		b.disabled = locked
	_lock.visible = locked


## Polls the sim; only changed values reach the nodes.
func refresh() -> void:
	var sim := _game.sim
	if _changed(&"gold", sim.gold):
		_gold.text = str(sim.gold)
	if _maxed != null and _changed(&"maxed", ElementPicks.interest_maxed(sim)):
		_maxed.visible = _shown[&"maxed"]
	if _changed(&"lives", sim.lives):
		_lives.text = str(sim.lives)
		_lives.add_theme_color_override(
			"font_color", UiTheme.BAD if sim.lives <= 5 else UiTheme.TEXT
		)
	var payout := mini(floori(sim.gold * sim.elements.interest_rate()), sim.elements.interest_cap())
	if _changed(&"payout", payout):
		_payout.text = "+%d" % payout
	_ring.set_progress(1.0 - sim.interest_timer / GameSim.INTEREST_PERIOD)
	var tip_changed := _changed(&"interest_picks", sim.elements.interest_picks)
	if tip_changed:
		_interest_tip = _interest_text()
		if _maxed != null:
			var at := TowerInfo.fmt_gold(ElementPicks.interest_cap_gold(sim))
			_gold_box.tooltip_text = "Gold. Above %s, interest earns no more." % at
	if _changed(&"interest_locked", sim.interest_locked) or tip_changed:
		_ring.locked = sim.interest_locked
		_interest.tooltip_text = LOCKED_TIP if sim.interest_locked else _interest_tip
		_payout.add_theme_color_override(
			"font_color", UiTheme.TEXT_DIM if sim.interest_locked else UiTheme.GOLD_BRIGHT
		)
	var wave_changed := _changed(&"wave", sim.wave)
	var infinite_changed := _changed(&"infinite", sim.infinite)
	if infinite_changed or wave_changed:
		_wave.text = str(sim.wave) if sim.wave > 0 else "–"
		_wave_total.text = "/" if sim.infinite else "/%d" % WaveDefs.count()
		_wave_inf.visible = sim.infinite
	# The setup panel sets the mode too.
	var level_changed := _changed(&"difficulty", sim.difficulty)
	if _changed(&"twists", sim.twists) or level_changed or infinite_changed or wave_changed:
		_sync_mode()
	_refresh_next(sim)
	if _elements != null:
		_elements.refresh()
		_fit_center()
	if _boss_chip.visible:
		if _changed(&"boss", _tracked(sim)):
			_boss_text.text = _shown[&"boss"]
		_boss_chip.offset_top = center_panel.offset_top + center_panel.size.y + BOSS_CHIP_GAP


## eletd's wider side panels (element levels, four difficulties) would cover
## the centred wave panel and its call button, so it sits centred in the gap
## between them instead.
func _fit_center() -> void:
	var left := left_panel.position.x + left_panel.size.x + GROUP_GAP
	var right := _right_panel.position.x - GROUP_GAP
	var x := maxf(left, (left + right - center_panel.size.x) / 2.0)
	if not is_equal_approx(center_panel.position.x, x):
		center_panel.position.x = x
	if _boss_chip.visible:
		_boss_chip.position.x = x + (center_panel.size.x - _boss_chip.size.x) / 2.0


## The boss chip's text for the boss the camera follows (CameraRig: the
## first boss alive), naming an eletd Guardian by its element.
func _tracked(sim: GameSim) -> String:
	for c in sim.creeps:
		if c.boss and c.alive:
			if c.type == &"guardian":
				return "Tracking the " + ElementPicks.guardian_title(c.element)
			return "Tracking the boss"
	return "Boss tracking: no boss yet"


func _on_sim_event(e: Dictionary) -> void:
	if e.type in [&"built", &"sold", &"upgraded", &"fused"]:
		_air_dirty = true


func _refresh_next(sim: GameSim) -> void:
	var next := sim.wave + 1
	var has_next := next <= sim.last_wave() and not _game.is_over()
	var secs := ceili(sim.countdown) if sim.countdown >= 0.0 else -1
	var twist := sim.twist_for(next) if has_next else &""
	var open := sim.elements.unlocked_towers()
	var dirty := _refresh_air(sim, has_next)
	dirty = _changed(&"next", next) or dirty
	dirty = _changed(&"open", open) or dirty
	dirty = _changed(&"twist", twist) or dirty
	dirty = _changed(&"has_next", has_next) or dirty
	dirty = _changed(&"secs", secs) or dirty
	if dirty:
		_next.show_wave(next if has_next else 0, twist, sim.rules)
		_call.disabled = not has_next
		if not has_next:
			_next_caption.text = "FINAL WAVE" if not _game.is_over() else ""
		elif secs >= 0:
			_next_caption.text = "NEXT · WAVE %d · IN %ds" % [next, secs]
		else:
			_next_caption.text = "NEXT · WAVE %d · N TO CALL EARLY" % next
		var tip := (
			"Wave %d: %s" % [next, TowerInfo.wave_summary(next, sim.rules)] if has_next else ""
		)
		if twist != &"":
			tip += "\nTwist: %s. %s" % [WaveTwists.display_name(twist), WaveTwists.text(twist)]
		if has_next and TowerInfo.flying(next, sim.rules):
			tip += "\nFLYING: %s" % TowerInfo.flying_text()
		if not _air_est.is_empty() and _air_est.wave == next:
			tip += "\n%s. %s" % [AirCover.readout(_air_est), AirCover.tip(_air_est)]
		if has_next and TowerInfo.composite_wave(next, sim.rules):
			tip += "\nComposite armor: %s" % TowerInfo.composite_text()
		if has_next and WaveDefs.bulky(next, sim.rules):
			tip += "\nBulky: %s" % TowerInfo.bulky_text()
		if has_next:
			tip += "\n%s. More in the Field Guide (H)." % Counsel.summary(next, sim.rules, open)
		_next.get_parent().tooltip_text = tip
	var after := next + 1
	var has_after := (
		has_next and sim.rules == &"eletd" and after <= sim.last_wave() and not _game.is_over()
	)
	var after_twist := sim.twist_for(after) if has_after else &""
	_after_caption.visible = has_after
	_after.visible = has_after
	if _changed(&"after", [after if has_after else 0, after_twist]):
		_after.show_wave(after if has_after else 0, after_twist, sim.rules)
		_after_caption.text = "THEN · WAVE %d" % after


## Re-estimates the air cover when the wave it is for, the mode or the board
## changes. True when it did.
func _refresh_air(sim: GameSim, has_next: bool) -> bool:
	if _changed(&"air_for", [sim.wave, has_next]):
		_air_wave = AirCover.upcoming(sim) if has_next and sim.adjacent_reach() else 0
	var w := _air_wave
	var key := [w, sim.difficulty, sim.twists, sim.twist_seed]
	var flyers_changed := _changed(&"air", key)
	if not flyers_changed and not _air_dirty:
		return false
	_air_dirty = false
	if flyers_changed:
		_air_flyers = AirCover.wave_flyers(sim, w) if w > 0 else {}
	_air_est = AirCover.estimate(sim, w, _air_flyers) if w > 0 else {}
	_air.visible = not _air_est.is_empty()
	if _air.visible:
		_air.text = AirCover.readout(_air_est)
		_air.tooltip_text = AirCover.tip(_air_est)
		_air.add_theme_color_override("font_color", AirCover.verdict_color(_air_est.ratio))
	return true


func _changed(key: StringName, value: Variant) -> bool:
	if _shown.get(key) == value:
		return false
	_shown[key] = value
	return true


func pulse_lives() -> void:
	UiKit.pulse(_lives_box, UiTheme.BAD, 1.35)


func pulse_gold() -> void:
	UiKit.pulse(_gold_box, UiTheme.GOLD_BRIGHT, 1.2)
