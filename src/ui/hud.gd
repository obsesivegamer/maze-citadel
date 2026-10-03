class_name Hud
extends CanvasLayer
## The HUD (GDD §11): top bar, 12 tower cards with tooltips, the pre-wave
## banner, the plaque over the selected tower, a key-hint strip, the
## first-run tutorial, the Field Guide, settings and the end screen. Composes
## the components in src/ui/ and routes game signals to them; per-frame work
## is limited to values that changed.

const CARD_GAP := 6
const CARD_BOTTOM := 10.0
const TIP_GAP := 10.0
const HINT_MARGIN := Vector2(12, 12)
const ANNOUNCE_LEAD := 3.0

var _game: Game
var _root := Control.new()
var _top := HudTopBar.new()
var _map_picker := HudMapPicker.new()
var _cards := {}
var _tooltip := TowerTooltip.new()
var _banner := WaveBanner.new()
var _plaque := TowerPlaque.new()
var _hints := UiKit.label("", &"Dim", UiTheme.SIZE_TINY)
var _tutorial := Tutorial.new()
var _guide := FieldGuide.new()
var _settings := SettingsPanel.new()
var _end := EndScreen.new()
var _announced := 0
var _best_before := 0
var _gold := -1
var _fusing := false
var _hint_state: StringName = &"none"


func setup(game: Game) -> void:
	_game = game
	_root.theme = UiTheme.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.add_child(_top)
	_top.setup(game)
	_top.settings_pressed.connect(_settings.toggle)
	_root.add_child(_map_picker)
	_map_picker.setup(game, _top.left_panel)
	_build_cards()
	_root.add_child(_banner)
	_root.add_child(_plaque)
	_plaque.setup(game)
	_hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hints.offset_left = HINT_MARGIN.x
	# Above the card bar: at 16:10 the centred cards reach the left corner.
	_hints.offset_bottom = -(TowerCard.SIZE.y + CARD_BOTTOM + HINT_MARGIN.y)
	_root.add_child(_hints)
	_root.add_child(_tutorial)
	_tutorial.setup(game, _cards)
	_root.add_child(_guide)
	_guide.setup(game)
	_tutorial.guide_requested.connect(_guide.open)
	_top.guide_pressed.connect(_guide.toggle)
	_tooltip.visible = false
	_root.add_child(_tooltip)
	_root.add_child(_settings)
	_settings.setup(game)
	_settings.setting_changed.connect(_tutorial.on_setting)
	_root.add_child(_end)
	_end.setup(game)
	_best_before = Save.best_wave(Save.sim_key(game.sim))
	game.sim_event.connect(_on_sim_event)
	game.build_choice_changed.connect(func(_id: StringName) -> void: _refresh_cards())
	game.selection_changed.connect(_plaque.show_tile)
	if Tutorial.wanted():
		_start_tutorial.call_deferred()


func _build_cards() -> void:
	var bar := UiKit.hbox(CARD_GAP)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -CARD_BOTTOM
	_root.add_child(bar)
	for id in TowerDefs.BUILD_ORDER + TowerDefs.EPICS:
		var card := TowerCard.new(id)
		card.pressed.connect(_on_card.bind(id))
		card.mouse_entered.connect(_show_tip.bind(card))
		card.mouse_exited.connect(func() -> void: _tooltip.visible = false)
		UiKit.wire(_game, card)
		bar.add_child(card)
		_cards[id] = card
	_refresh_cards()


func _on_card(id: StringName) -> void:
	if id in TowerDefs.EPICS:
		var t := _game.sim.tower_at(_game.selected)
		if t != null and TowerDefs.FUSIONS.get(t.family(), &"") == id:
			_game.builder.start_fuse()
		return
	_game.choose_build(&"" if _game.build_choice == id else id)


func _show_tip(card: TowerCard) -> void:
	_tooltip.show_for(card.id, _game.sim)
	_tooltip.visible = true
	_tooltip.reset_size()
	var rect := card.get_global_rect()
	var vp := _root.get_viewport_rect().size
	var x := clampf(rect.get_center().x - _tooltip.size.x / 2.0, 8.0, vp.x - _tooltip.size.x - 8.0)
	_tooltip.position = Vector2(x, rect.position.y - _tooltip.size.y - TIP_GAP)


func _refresh_cards() -> void:
	var sim := _game.sim
	for id in _cards:
		var card: TowerCard = _cards[id]
		card.chosen = id == _game.build_choice
		if id in TowerDefs.EPICS:
			card.lit = TowerInfo.can_fuse(sim, id)
		else:
			card.affordable = sim.gold >= TowerDefs.build_cost(id)


func _on_sim_event(e: Dictionary) -> void:
	match e.type:
		&"wave_started":
			if e.wave == 1:
				_best_before = Save.best_wave(Save.sim_key(_game.sim))
			if _announced < e.wave:
				_announce(e.wave)
		&"wave_cleared":
			_banner.cleared(e.wave)
		&"leaked":
			_top.pulse_lives()
		&"interest":
			_top.pulse_gold()
		&"victory", &"defeat":
			_tooltip.visible = false
			_end.show_result(e.type == &"victory", _best_before)
		&"built", &"sold", &"upgraded", &"fused":
			_refresh_cards()
			_plaque.refresh()


func _announce(wave: int) -> void:
	_announced = wave
	_banner.announce(wave, _game.sim.twist_for(wave))


func _process(delta: float) -> void:
	Prof.begin(&"hud")
	var sim := _game.sim
	_top.refresh()
	if sim.gold != _gold:
		_gold = sim.gold
		_refresh_cards()
	var next := sim.wave + 1
	if sim.countdown >= 0.0 and sim.countdown <= ANNOUNCE_LEAD and _announced < next:
		if next <= sim.last_wave():
			_announce(next)
	if _plaque.visible:
		_plaque.follow(delta)
	var fusing := _game.builder.is_fusing()
	if fusing != _fusing:
		_fusing = fusing
		_plaque.set_fusing(fusing)
	_refresh_hints()
	Prof.end(&"hud")


## After the caller's own setup, so a bot attached right after the Game is
## added still keeps the welcome card away.
func _start_tutorial() -> void:
	if _game.autoplay == null:
		_tutorial.start()


## The HUD gets input before the builder and camera, so keys stop here while
## a modal is up.
func _unhandled_input(event: InputEvent) -> void:
	var action := modal_action(event, _guide.visible, _tutorial.welcome_visible())
	match action:
		&"":
			return
		&"close_guide":
			_guide.close_modal()
		&"open_guide":
			_guide.open()
		&"begin":
			_tutorial.begin()
	get_viewport().set_input_as_handled()


## What a key does with the Field Guide or the welcome card up. Both are
## modal: the topmost takes Esc and nothing else reaches the game behind
## (&"swallow"); Space and Enter also begin from the welcome. Without either,
## only H is the HUD's (&"" passes the key on).
static func modal_action(event: InputEvent, guide_open: bool, welcome_open: bool) -> StringName:
	var guide_key := event.is_action_pressed(&"field_guide")
	if guide_open:
		return &"close_guide" if guide_key or event.is_action_pressed(&"deselect") else &"swallow"
	if welcome_open:
		if guide_key:
			return &"open_guide"
		for a in [&"deselect", &"pause", &"ui_accept"]:
			if event.is_action_pressed(a):
				return &"begin"
		return &"swallow"
	return &"open_guide" if guide_key else &""


func _refresh_hints() -> void:
	var state: StringName = &"none"
	if _fusing:
		state = &"fuse"
	elif _game.build_choice != &"":
		state = &"build"
	elif _game.selected != Game.NONE:
		state = &"select"
	if state == _hint_state:
		return
	_hint_state = state
	var parts := PackedStringArray()
	for h in TowerInfo.hints(state):
		parts.append("%s %s" % [h[0], h[1]])
	_hints.text = "   ·   ".join(parts)
