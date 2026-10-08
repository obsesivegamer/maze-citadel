class_name Hud
extends CanvasLayer
## The HUD (GDD §11): top bar, 12 tower cards with tooltips, the pre-wave
## banner, the plaque over the selected tower, a key-hint strip, the
## first-run tutorial, the setup panel, the Field Guide, settings, the pause
## menu and the end screen. Composes
## the components in src/ui/ and routes game signals to them; per-frame work
## is limited to values that changed.

const CARD_GAP := 6
const CARD_BOTTOM := 10.0
const TIP_GAP := 10.0
const HINT_MARGIN := Vector2(12, 12)
const ANNOUNCE_LEAD := 3.0
## The line above the cards (eletd): gap over the cards, seconds held, fade.
const SAY_GAP := 46.0
const SAY_HOLD := 2.2
const SAY_FADE := 0.6
## How long the line holds a rule it teaches (HudNotices).
const NOTICE_HOLD := 5.0
## The modals that take the keys, topmost first as setup() stacks them
## (modal_action): keys go to the one the player sees. The loading screen
## counts as one until the game has booted.
const MODALS: Array[StringName] = [
	&"loading", &"end", &"settings", &"guide", &"setup", &"menu", &"welcome"
]

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
var _menu := PauseMenu.new()
var _setup := SetupPanel.new()
var _guide := FieldGuide.new()
var _settings := SettingsPanel.new()
var _end := EndScreen.new()
## eletd only: the element pick panel and a line of text above the cards
## for refusals, Guardian leaks and the rules HudNotices teaches.
var _picks: PickPanel
var _notices := HudNotices.new()
var _say_line: Label
var _say_tween: Tween
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
	if game.sim.elements.enabled:
		_build_elements()
	# Under the Field Guide and Settings, which open over it.
	_root.add_child(_menu)
	_menu.setup(game)
	_menu.settings_requested.connect(_settings.open)
	_menu.guide_requested.connect(_guide.open)
	_root.add_child(_setup)
	_setup.setup(game)
	_setup.started.connect(_on_setup_started)
	_root.add_child(_guide)
	_guide.setup(game)
	_tutorial.guide_requested.connect(_guide.open)
	_top.guide_pressed.connect(_guide.toggle)
	_tooltip.visible = false
	_root.add_child(_tooltip)
	_root.add_child(_settings)
	_settings.setup(game)
	_settings.setting_changed.connect(_on_setting)
	_root.add_child(_end)
	_end.setup(game)
	_best_before = Save.best_wave(Save.sim_key(game.sim))
	game.sim_event.connect(_on_sim_event)
	game.build_choice_changed.connect(func(_id: StringName) -> void: _refresh_cards())
	game.selection_changed.connect(_plaque.show_tile)
	if SetupPanel.wanted():
		_open_setup.call_deferred()
	elif Tutorial.wanted():
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


func _build_elements() -> void:
	_picks = PickPanel.new()
	_root.add_child(_picks)
	_picks.setup(_game)
	_top.picks_pressed.connect(_picks.toggle)
	_say_line = UiKit.label("", &"", UiTheme.SIZE_LARGE)
	_say_line.add_theme_font_override("font", UiTheme.bold())
	_say_line.add_theme_color_override("font_color", UiTheme.GOLD_BRIGHT)
	_say_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_say_line.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_say_line.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_say_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say_line.offset_bottom = -(TowerCard.SIZE.y + CARD_BOTTOM + SAY_GAP)
	_say_line.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02))
	_say_line.add_theme_constant_override("outline_size", 6)
	_say_line.visible = false
	_root.add_child(_say_line)


## Shows `text` above the cards for a moment, like a Warcraft III error line.
func _say(text: String, hold := SAY_HOLD) -> void:
	if _say_line == null:
		return
	_say_line.text = text
	_say_line.visible = true
	_say_line.modulate.a = 1.0
	if _say_tween != null:
		_say_tween.kill()
	_say_tween = _say_line.create_tween()
	_say_tween.tween_interval(hold)
	_say_tween.tween_property(_say_line, "modulate:a", 0.0, SAY_FADE)
	_say_tween.tween_callback(_say_line.hide)


## Guardians, element levels, picks and eletd's refusals (a locked element, the
## ring by the portal), and the rules HudNotices teaches.
func _on_element_event(e: Dictionary) -> void:
	var line := _notices.line_for(_game.sim, e)
	if line != "":
		_say(line, NOTICE_HOLD)
	match e.type:
		&"pick_granted":
			_banner.cleared(e.wave, ElementPicks.granted_text(_game.sim))
		&"guardian_spawned":
			var detail := ElementPicks.guardian_detail(e.element, e.level)
			_banner.notice(ElementPicks.guardian_title(e.element), detail, e.element)
		&"element_gained":
			var text := ElementPicks.unlocks(e.element, e.level)
			_banner.notice(ElementPicks.gained_title(e.element, e.level), text, e.element, true)
		&"upgrade_refused":
			_say(e.needs)
		&"build_refused":
			if e.reason == Placement.Result.LOCKED:
				_say(ElementPicks.locked_reason(_game.sim, e.get("id", _game.build_choice)))
			elif e.reason == Placement.Result.NEAR_PORTAL:
				_say(Placement.describe(e.reason))
		&"leaked":
			for c in _game.sim.creeps:
				if c.id == e.id and c.type == &"guardian":
					_say(ElementPicks.guardian_leaked(c.element, e.cost))


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
			card.locked = sim.elements.needs(id) != ""
			card.hint = ElementPicks.card_hint(sim, id)


func _on_sim_event(e: Dictionary) -> void:
	if _picks != null:
		_on_element_event(e)
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
			# The pick panel leaves the game running, so a game can end under it.
			if _picks != null:
				_picks.close_modal()
			_end.show_result(e.type == &"victory", _best_before)
		&"built", &"sold", &"upgraded", &"fused", &"element_gained":
			_refresh_cards()
			_plaque.refresh()
		&"pick_granted", &"pick_spent", &"guardian_spawned":
			_refresh_cards()


func _announce(wave: int) -> void:
	_announced = wave
	_banner.announce(wave, _game.sim.twist_for(wave), _game.sim.rules)


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


## Once the loading screen is gone. Until then the HUD and the builder take
## no keys (the "loading" modal, BuildController), so nothing pressed while
## loading starts, pauses or opens anything under it.
func _open_setup() -> void:
	if not _game.is_booted:
		await _game.booted
	if _game.autoplay == null:
		_setup.open()


## Start on the setup panel: the welcome or the counsel follows at once if
## the tutorial is on, so the clock doesn't run in between.
func _on_setup_started(tutorial: bool) -> void:
	if tutorial:
		_start_tutorial()


## While the setup panel is up, Settings → Tutorial moves its chip instead;
## Start then begins the tutorial or not.
func _on_setting(key: String, on: bool) -> void:
	if _setup.visible:
		_setup.on_setting(key, on)
	else:
		_tutorial.on_setting(key, on)


## Opens a panel for a screenshot (main.gd's --open): "pick" (eletd),
## "guide", "elements" (the Field Guide's eletd page), "settings", "menu" or
## "setup".
func open_panel(which: String) -> void:
	match which:
		"pick":
			if _picks != null:
				_picks.open()
		"guide", "elements":
			_guide.open()
			_guide.show_page(which == "elements")
		"settings":
			_settings.open()
		"menu":
			_menu.open()
		"setup":
			_setup.open()


## The HUD gets input before the builder and camera, so keys stop here while
## a modal is up; under eletd E and the pick panel's keys stop here too.
func _unhandled_input(event: InputEvent) -> void:
	var top := _top_modal()
	match modal_action(event, top, _idle()):
		&"":
			if _picks != null and _picks.handle_key(event):
				get_viewport().set_input_as_handled()
			return
		&"close":
			_modal(top).close_modal()
		&"open_guide":
			_guide.open()
		&"settings":
			_settings.toggle()
		&"open_menu":
			_menu.open()
		&"begin":
			_tutorial.begin()
		&"start":
			_setup.start()
	get_viewport().set_input_as_handled()


## Whether a modal or the loading screen has the keys; the camera rig asks,
## since its WASD and Q/E polling never passes through _unhandled_input.
func modal_up() -> bool:
	return _top_modal() != &""


func _top_modal() -> StringName:
	return topmost(
		{
			&"loading": not _game.is_booted,
			&"guide": _guide.visible,
			&"settings": _settings.visible,
			&"menu": _menu.visible,
			&"setup": _setup.visible,
			&"welcome": _tutorial.welcome_visible(),
			&"end": _end.visible,
		}
	)


func _modal(m: StringName) -> UiModal:
	return {&"guide": _guide, &"settings": _settings, &"menu": _menu}[m]


## Nothing chosen, selected or being fused and no pick panel up: Esc has
## nothing to cancel, so it opens the pause menu.
func _idle() -> bool:
	if _picks != null and _picks.visible:
		return false
	return _game.build_choice == &"" and _game.selected == Game.NONE and not _fusing


## The first of MODALS that `shown` marks visible, or &"" when none is.
static func topmost(shown: Dictionary) -> StringName:
	for m in MODALS:
		if shown.get(m, false):
			return m
	return &""


## What a key does under the topmost modal `top` (MODALS, or &"" for none).
## No key reaches the game behind a modal (&"swallow"). Esc closes the
## Field Guide, Settings and the pause menu (&"close"), and so do H and F10
## their own panels; the menu opens either over itself. Esc, Space and Enter
## begin from the welcome, where H opens the guide; Space and Enter start
## from the setup panel, which opens the guide and Settings over itself but
## doesn't close on Esc (Start is the way on). The end screen and the
## loading screen keep every key. With no modal up, H opens the guide, F10
## Settings, and Esc the pause menu once `idle` (nothing to cancel);
## otherwise &"" passes the key on, so Esc deselects as before.
static func modal_action(event: InputEvent, top: StringName, idle: bool) -> StringName:
	var esc := event.is_action_pressed(&"deselect")
	var guide_key := event.is_action_pressed(&"field_guide")
	var settings_key := event.is_action_pressed(&"settings")
	match top:
		&"guide":
			return &"close" if esc or guide_key else &"swallow"
		&"settings":
			return &"close" if esc or settings_key else &"swallow"
		&"menu":
			if esc:
				return &"close"
			if guide_key:
				return &"open_guide"
			return &"settings" if settings_key else &"swallow"
		&"setup":
			if guide_key:
				return &"open_guide"
			if settings_key:
				return &"settings"
			for a in [&"pause", &"ui_accept"]:
				if event.is_action_pressed(a):
					return &"start"
			return &"swallow"
		&"welcome":
			if guide_key:
				return &"open_guide"
			for a in [&"deselect", &"pause", &"ui_accept"]:
				if event.is_action_pressed(a):
					return &"begin"
			return &"swallow"
		&"end", &"loading":
			return &"swallow"
	if guide_key:
		return &"open_guide"
	if settings_key:
		return &"settings"
	return &"open_menu" if esc and idle else &""


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
