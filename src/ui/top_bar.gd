class_name HudTopBar
extends Control
## Top of the HUD (GDD §11). Left: gold, lives, interest ring and next payout.
## Centre: wave n/40 and the next-wave chip with its countdown and a call
## button. Right: mode chip, speed, pause, camera presets, boss tracking and
## settings. refresh() runs every frame but only touches a node when the value
## it shows has changed.

signal settings_pressed

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

var center_panel: PanelContainer

var _game: Game
var _gold := UiKit.label("", &"Number")
var _lives := UiKit.label("", &"Number")
var _lives_box := UiKit.hbox(5)
var _gold_box := UiKit.hbox(5)
var _ring := InterestRing.new(RING_PX)
var _payout := UiKit.label("", &"Number", UiTheme.SIZE_LARGE)
var _wave := UiKit.label("", &"Title")
var _wave_total := UiKit.label("", &"Dim", UiTheme.SIZE_BODY)
var _wave_inf := UiIcon.new(&"infinity", 16.0, UiTheme.TEXT_DIM)
var _next_caption := UiKit.label("", &"Caption")
var _next := WaveIcons.new(NEXT_ICON_PX, 13)
var _call: Button
var _normal: Button
var _hard: Button
var _infinite: Button
var _lock := UiIcon.new(&"lock", 16.0)
var _speeds: Array[Button] = []
var _pause: Button
var _boss: Button
var _boss_chip := UiKit.panel(&"Chip", false)
var _boss_text := UiKit.label("", &"", UiTheme.SIZE_SMALL)
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
	var row := UiKit.hbox(GROUP_GAP)
	p.add_child(row)
	_gold_box.add_child(UiIcon.new(&"coin", ICON_PX))
	_gold_box.add_child(_gold)
	_gold_box.tooltip_text = "Gold"
	_gold_box.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_gold_box)
	_lives_box.add_child(UiIcon.new(&"heart", ICON_PX))
	_lives_box.add_child(_lives)
	_lives_box.tooltip_text = "Lives. A leak costs 1 (bosses 2) and the creep runs again."
	_lives_box.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_lives_box)
	var interest := UiKit.hbox(5)
	interest.add_child(_ring)
	_payout.add_theme_color_override("font_color", UiTheme.GOLD_BRIGHT)
	interest.add_child(_payout)
	interest.tooltip_text = (
		"Interest: every %d s you earn %d%% of unspent gold (max +%d). Next payout shown."
		% [GameSim.INTEREST_PERIOD, roundi(GameSim.INTEREST_RATE * 100), GameSim.INTEREST_CAP]
	)
	interest.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(interest)


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
	next_col.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(next_col)
	_call = UiKit.icon_button(_game, &"next", "Call the next wave now (N)", BUTTON_PX)
	_call.pressed.connect(_game.call_next_wave)
	UiKit.key_badge(_call, "N")
	row.add_child(_call)


func _build_right() -> void:
	var p := UiKit.panel()
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.offset_right = -MARGIN.x
	p.offset_top = MARGIN.y
	add_child(p)
	var row := UiKit.hbox(6)
	p.add_child(row)
	var group := ButtonGroup.new()
	_normal = _segment("Normal", "Normal: base creep HP and bounty", group)
	_hard = _segment("Hard", "Hard: creeps +10% HP rising to +40% by wave 40, score ×1.3", group)
	_infinite = UiKit.icon_button(
		_game, &"infinity", "Infinite: waves continue after 40", BUTTON_PX, true
	)
	for b in [_normal, _hard, _infinite]:
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
	if not _game.set_mode(_hard.button_pressed, _infinite.button_pressed):
		_sync_mode()


func _sync_mode() -> void:
	var sim := _game.sim
	_normal.set_pressed_no_signal(not sim.hard)
	_hard.set_pressed_no_signal(sim.hard)
	_infinite.set_pressed_no_signal(sim.infinite)
	var locked := sim.wave > 0
	for b in [_normal, _hard, _infinite]:
		b.disabled = locked
	_lock.visible = locked


## Polls the sim; only changed values reach the nodes.
func refresh() -> void:
	var sim := _game.sim
	if _changed(&"gold", sim.gold):
		_gold.text = str(sim.gold)
	if _changed(&"lives", sim.lives):
		_lives.text = str(sim.lives)
		_lives.add_theme_color_override(
			"font_color", UiTheme.BAD if sim.lives <= 5 else UiTheme.TEXT
		)
	var payout := mini(floori(sim.gold * GameSim.INTEREST_RATE), GameSim.INTEREST_CAP)
	if _changed(&"payout", payout):
		_payout.text = "+%d" % payout
	_ring.set_progress(1.0 - sim.interest_timer / GameSim.INTEREST_PERIOD)
	var wave_changed := _changed(&"wave", sim.wave)
	if _changed(&"infinite", sim.infinite) or wave_changed:
		_wave.text = str(sim.wave) if sim.wave > 0 else "–"
		_wave_total.text = "/" if sim.infinite else "/%d" % WaveDefs.count()
		_wave_inf.visible = sim.infinite
		_sync_mode()
	_refresh_next(sim)
	if _boss_chip.visible:
		var has_boss := false
		for c in sim.creeps:
			has_boss = has_boss or (c.boss and c.alive)
		if _changed(&"boss", has_boss):
			_boss_text.text = "Tracking the boss" if has_boss else "Boss tracking: no boss yet"
		_boss_chip.offset_top = center_panel.offset_top + center_panel.size.y + BOSS_CHIP_GAP


func _refresh_next(sim: GameSim) -> void:
	var next := sim.wave + 1
	var has_next := next <= sim.last_wave() and not _game.is_over()
	var secs := ceili(sim.countdown) if sim.countdown >= 0.0 else -1
	var dirty := _changed(&"next", next)
	dirty = _changed(&"has_next", has_next) or dirty
	dirty = _changed(&"secs", secs) or dirty
	if dirty:
		_next.show_wave(next if has_next else 0)
		_call.disabled = not has_next
		if not has_next:
			_next_caption.text = "FINAL WAVE" if not _game.is_over() else ""
		elif secs >= 0:
			_next_caption.text = "NEXT · WAVE %d · IN %ds" % [next, secs]
		else:
			_next_caption.text = "NEXT · WAVE %d · N TO CALL EARLY" % next
		_next.get_parent().tooltip_text = (
			"Wave %d: %s" % [next, TowerInfo.wave_summary(next)] if has_next else ""
		)


func _changed(key: StringName, value: Variant) -> bool:
	if _shown.get(key) == value:
		return false
	_shown[key] = value
	return true


func pulse_lives() -> void:
	UiKit.pulse(_lives_box, UiTheme.BAD, 1.35)


func pulse_gold() -> void:
	UiKit.pulse(_gold_box, UiTheme.GOLD_BRIGHT, 1.2)
