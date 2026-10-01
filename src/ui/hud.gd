class_name Hud
extends CanvasLayer
## Minimal HUD (GDD §11): top bar, 12 tower cards, wave announcement, the
## selected-tower plaque and the end screen. Skeleton version: functional
## controls with plain styling.

const ANNOUNCE_LEAD := 3.0
const CLASS_NAMES := {
	&"light": "Light armor", &"armored": "Armored", &"air": "Air", &"boss": "Boss"
}

var _game: Game
var _top := Label.new()
var _speed := Button.new()
var _pause := Button.new()
var _mode := OptionButton.new()
var _quality := OptionButton.new()
var _cards := {}
var _announce := Label.new()
var _plaque := PanelContainer.new()
var _plaque_text := Label.new()
var _upgrade := Button.new()
var _sell := Button.new()
var _fuse := Button.new()
var _end := PanelContainer.new()
var _end_text := Label.new()
var _announced := 0


func setup(game: Game) -> void:
	_game = game
	_build_top_bar()
	_build_cards()
	_build_announce()
	_build_plaque()
	_build_end()
	game.sim_event.connect(_on_sim_event)
	game.speed_changed.connect(func(s: int) -> void: _speed.text = "×%d" % s)
	game.pause_changed.connect(func(p: bool) -> void: _pause.text = "Resume" if p else "Pause")
	game.build_choice_changed.connect(func(_id: StringName) -> void: _refresh_cards())
	game.selection_changed.connect(func(_t: Vector2i) -> void: _refresh_plaque())


func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 12
	bar.offset_top = 8
	bar.add_theme_constant_override("separation", 14)
	add_child(bar)
	_top.add_theme_font_size_override("font_size", 20)
	_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_top)
	_mode.add_item("Normal")
	_mode.add_item("Hard")
	_mode.add_item("Normal + Infinite")
	_mode.add_item("Hard + Infinite")
	_mode.item_selected.connect(func(i: int) -> void: _game.set_mode(i % 2 == 1, i >= 2))
	bar.add_child(_mode)
	for n in Quality.NAMES:
		_quality.add_item(n.capitalize())
	_quality.selected = _game.quality
	_quality.item_selected.connect(func(i: int) -> void: _game.set_quality(i as Quality.Preset))
	bar.add_child(_quality)
	for p in CameraRig.PRESET_ORDER:
		var b := Button.new()
		b.text = String(p).capitalize()
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: _game.camera.preset(p))
		bar.add_child(b)
	var next := Button.new()
	next.text = "Next wave (N)"
	next.focus_mode = Control.FOCUS_NONE
	next.pressed.connect(_game.call_next_wave)
	bar.add_child(next)
	_speed.text = "×1"
	_speed.focus_mode = Control.FOCUS_NONE
	_speed.pressed.connect(_game.cycle_speed)
	bar.add_child(_speed)
	_pause.text = "Pause"
	_pause.focus_mode = Control.FOCUS_NONE
	_pause.pressed.connect(_game.toggle_pause)
	bar.add_child(_pause)


func _build_cards() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -10
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	for id in TowerDefs.BUILD_ORDER + TowerDefs.EPICS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(104, 64)
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		var def: Dictionary = TowerDefs.TOWERS[id]
		var cost: int = def.get("fuse_cost", 0) if id in TowerDefs.EPICS else def.cost[0]
		var key := "G" if id in TowerDefs.EPICS else TowerDefs.hotkey(id)
		b.text = "%s\n%dg  [%s]" % [def.name.replace("Epic ", "★ "), cost, key]
		b.add_theme_font_size_override("font_size", 12)
		if id in TowerDefs.EPICS:
			b.disabled = true
			b.tooltip_text = "Select a level-3 %s tower and press G" % def.family
		else:
			b.pressed.connect(func() -> void: _game.choose_build(id))
		bar.add_child(b)
		_cards[id] = b
	_refresh_cards()


func _build_announce() -> void:
	_announce.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_announce.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_announce.offset_top = 70
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.add_theme_font_size_override("font_size", 30)
	_announce.add_theme_constant_override("outline_size", 8)
	_announce.add_theme_color_override("font_outline_color", Color.BLACK)
	_announce.visible = false
	add_child(_announce)


func _build_plaque() -> void:
	var box := VBoxContainer.new()
	_plaque.add_child(box)
	box.add_child(_plaque_text)
	var row := HBoxContainer.new()
	box.add_child(row)
	for pair in [[_upgrade, "Upgrade (U)"], [_sell, "Sell (X)"], [_fuse, "Fuse (G)"]]:
		var b: Button = pair[0]
		b.text = pair[1]
		b.focus_mode = Control.FOCUS_NONE
		row.add_child(b)
	_upgrade.pressed.connect(func() -> void: _game.upgrade_selected())
	_sell.pressed.connect(_game.sell_selected)
	_fuse.pressed.connect(func() -> void: _game.builder.start_fuse())
	_plaque.visible = false
	add_child(_plaque)


func _build_end() -> void:
	_end.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_end.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	_end.add_child(box)
	_end_text.add_theme_font_size_override("font_size", 22)
	box.add_child(_end_text)
	var again := Button.new()
	again.text = "Play again"
	again.pressed.connect(_game.restart)
	box.add_child(again)
	_end.visible = false
	add_child(_end)


func _on_sim_event(e: Dictionary) -> void:
	match e.type:
		&"wave_started":
			_show_announce(e.wave)
			_mode.disabled = true
		&"victory", &"defeat":
			_show_end(e.type == &"victory")
		&"built", &"sold", &"upgraded", &"fused":
			_refresh_plaque()


func _show_announce(wave: int) -> void:
	_announced = wave
	var entries := WaveDefs.spawn_list(wave)
	var counts := {}
	var classes := {}
	for entry in entries:
		var def: Dictionary = CreepDefs.CREEPS[entry[0]]
		counts[def.name] = counts.get(def.name, 0) + 1
		classes[CLASS_NAMES[def.class]] = true
	var parts: PackedStringArray = []
	for n in counts:
		parts.append("%d %s" % [counts[n], n])
	var skull := "☠ BOSS ☠  " if WaveDefs.has_boss(wave) else ""
	var elements: PackedStringArray = []
	for el in WaveDefs.elements(wave):
		elements.append(String(el).capitalize())
	_announce.text = (
		"%sWave %d — %s\n%s · %s"
		% [skull, wave, ", ".join(parts), " / ".join(classes.keys()), " + ".join(elements)]
	)
	_announce.visible = true
	_announce.modulate.a = 1.0


func _show_end(won: bool) -> void:
	var sim := _game.sim
	var mode := Save.mode_key(sim.hard, sim.infinite)
	_end_text.text = (
		"%s\nWave %d · Kills %d · Time %d:%02d\nScore %d · Best wave %d"
		% [
			"VICTORY" if won else "DEFEAT",
			sim.wave,
			sim.kills,
			int(sim.time) / 60,
			int(sim.time) % 60,
			sim.score(),
			Save.best_wave(mode),
		]
	)
	_end.visible = true


func _refresh_cards() -> void:
	for id in _cards:
		var b: Button = _cards[id]
		b.set_pressed_no_signal(id == _game.build_choice)
		if id in TowerDefs.EPICS:
			continue
		b.modulate = (
			Color.WHITE if _game.sim.gold >= TowerDefs.build_cost(id) else Color(1, 1, 1, 0.45)
		)


func _refresh_plaque() -> void:
	var t := _game.sim.tower_at(_game.selected)
	_plaque.visible = t != null
	if t == null:
		return
	var def: Dictionary = TowerDefs.TOWERS[t.id]
	var up := TowerDefs.upgrade_cost(t.id, t.level) if not t.is_epic() else -1
	_plaque_text.text = (
		"%s  L%d\nKills %d · Damage %d" % [def.name, t.level, t.kills, roundi(t.damage_dealt)]
	)
	_upgrade.disabled = up < 0 or _game.sim.gold < up
	_upgrade.text = "Upgrade %dg (U)" % up if up >= 0 else "Max level"
	_sell.text = "Sell +%dg (X)" % floori(t.invested * GameSim.SELL_REFUND)
	var family_epic: StringName = TowerDefs.FUSIONS.get(t.family(), &"")
	_fuse.visible = family_epic != &"" and t.level == TowerDefs.MAX_LEVEL and not t.is_epic()


func _process(_delta: float) -> void:
	var sim := _game.sim
	var next := sim.wave + 1
	var timer := "  ·  next in %ds" % ceili(sim.countdown) if sim.countdown >= 0.0 else ""
	_top.text = (
		"Gold %d   Lives %d   Wave %d/%d%s   Interest +%d in %ds"
		% [
			sim.gold,
			sim.lives,
			sim.wave,
			WaveDefs.count(),
			timer,
			mini(floori(sim.gold * GameSim.INTEREST_RATE), GameSim.INTEREST_CAP),
			ceili(sim.interest_timer),
		]
	)
	if sim.countdown >= 0.0 and sim.countdown <= ANNOUNCE_LEAD and _announced < next:
		if next <= sim.last_wave():
			_show_announce(next)
	if _announce.visible:
		_announce.modulate.a = maxf(_announce.modulate.a - _delta * 0.25, 0.0)
		_announce.visible = _announce.modulate.a > 0.0
	_refresh_cards()
	if _plaque.visible:
		var t := sim.tower_at(_game.selected)
		if t != null:
			var p := _game.camera.camera.unproject_position(
				Coords.tile_to_world(t.tile, Coords.PLATEAU_TOP + 4.0)
			)
			_plaque.position = p - Vector2(_plaque.size.x / 2, _plaque.size.y)
