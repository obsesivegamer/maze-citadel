class_name TowerPlaque
extends Control
## The small plaque floating above the selected tower (GDD §11): level, kills,
## damage, counters, next-level preview, and upgrade / sell / fuse with their
## costs. Follows the tower on screen every frame (a position update only);
## text is rebuilt when the tower or the numbers it shows change.

const WIDTH := 292.0
## Metres above the plateau the plaque's pointer aims at.
const LIFT := 4.4
const POINTER := Vector2(18, 10)
const SAFE_TOP := 66.0
const SAFE_BOTTOM := 158.0
const SAFE_SIDE := 8.0
const REFRESH := 0.25
const ICON_PX := 30.0
const PIP := 4.5

var tile := Game.NONE

var _game: Game
var _panel := UiKit.panel(&"Plaque")
var _icon := UiIcon.new(&"", ICON_PX)
var _name := UiKit.label("", &"Heading", UiTheme.SIZE_LARGE - 1)
var _sub := UiKit.label("", &"Dim", UiTheme.SIZE_TINY)
var _pips := Control.new()
var _kills := UiKit.label("", &"", UiTheme.SIZE_SMALL)
var _damage := UiKit.label("", &"", UiTheme.SIZE_SMALL)
var _aura := UiKit.label("", &"", UiTheme.SIZE_SMALL)
var _counters := UiKit.rich(UiTheme.SIZE_TINY, WIDTH - 24.0)
var _next := UiKit.label("", &"Dim", UiTheme.SIZE_TINY)
var _upgrade: Button
var _sell: Button
var _fuse: Button
var _pointer := Control.new()
var _level := 0
var _epic := false
var _timer := 0.0
var _key := []


func setup(game: Game) -> void:
	_game = game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	add_child(_pointer)
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.custom_minimum_size = POINTER
	_pointer.size = POINTER
	_pointer.draw.connect(_draw_pointer)
	add_child(_panel)
	_panel.custom_minimum_size.x = WIDTH
	var box := UiKit.vbox(5)
	_panel.add_child(box)
	var head := UiKit.hbox(8)
	head.alignment = BoxContainer.ALIGNMENT_BEGIN
	head.add_child(_icon)
	var names := UiKit.vbox(-2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(_name)
	names.add_child(_sub)
	head.add_child(names)
	_pips.custom_minimum_size = Vector2(PIP * 7.0, ICON_PX)
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.draw.connect(_draw_pips)
	head.add_child(_pips)
	box.add_child(head)
	var stats := UiKit.hbox(6)
	stats.alignment = BoxContainer.ALIGNMENT_BEGIN
	stats.add_child(UiIcon.new(&"swords", 15.0))
	stats.add_child(_kills)
	stats.add_child(UiIcon.new(&"burst", 15.0))
	stats.add_child(_damage)
	stats.add_child(_aura)
	box.add_child(stats)
	box.add_child(_counters)
	_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next.custom_minimum_size.x = WIDTH - 24.0
	box.add_child(_next)
	var row := UiKit.hbox(6)
	_upgrade = _button("U", func() -> void: _game.upgrade_selected())
	_sell = _button("X", _game.sell_selected)
	_fuse = _button("G", _on_fuse)
	_fuse.toggle_mode = true
	for b in [_upgrade, _sell, _fuse]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	box.add_child(row)


func _button(key: String, action: Callable) -> Button:
	var b := UiKit.text_button(_game, "")
	b.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
	b.custom_minimum_size.y = 28
	b.pressed.connect(action)
	UiKit.key_badge(b, key)
	return b


func _on_fuse() -> void:
	if _game.builder.is_fusing():
		_game.builder.cancel_fuse()
	else:
		_game.builder.start_fuse()


func show_tile(t: Vector2i) -> void:
	tile = t
	_key = []
	_timer = 0.0
	visible = _game.sim.tower_at(t) != null
	if visible:
		refresh()


func set_fusing(on: bool) -> void:
	_fuse.set_pressed_no_signal(on)
	_fuse.text = "Pick partner" if on else "Fuse"


## Rebuilds the text when the tower or anything it shows has changed.
func refresh() -> void:
	var t := _game.sim.tower_at(tile)
	if t == null:
		visible = false
		return
	var gold := _game.sim.gold
	var partners := TowerInfo.fuse_partners(_game.sim, tile).size()
	var key := [t.id, t.level, t.kills, roundi(t.damage_dealt), gold, t.aura, partners]
	if key == _key:
		return
	var same_tower: bool = not _key.is_empty() and _key[0] == t.id and _key[1] == t.level
	_key = key
	_kills.text = "%d kills" % t.kills
	_damage.text = TowerInfo.fmt_big(t.damage_dealt) + " dmg"
	_aura.visible = t.aura > 0.0
	_aura.text = "+%d%% aura" % roundi(t.aura * 100.0)
	_aura.add_theme_color_override("font_color", UiTheme.FAMILY_COLORS[&"support"])
	var up := -1 if t.is_epic() else TowerDefs.upgrade_cost(t.id, t.level)
	_upgrade.disabled = up < 0 or gold < up
	_upgrade.text = "Max level" if up < 0 else "Upgrade %dg" % up
	_sell.text = "Sell +%dg" % TowerInfo.sell_value(t)
	var epic: StringName = TowerDefs.FUSIONS.get(t.family(), &"")
	_fuse.visible = epic != &"" and t.level == TowerDefs.MAX_LEVEL and not t.is_epic()
	if _fuse.visible:
		var cost: int = TowerDefs.TOWERS[epic].fuse_cost
		_fuse.disabled = partners == 0 or gold < cost
		_fuse.tooltip_text = (
			"Fuse into %s for %d gold: select a level-3 partner (%d on the board)"
			% [TowerInfo.full_name(epic), cost, partners]
		)
		if not _game.builder.is_fusing():
			_fuse.text = "Fuse %dg" % cost
	if same_tower:
		return
	_level = t.level
	_epic = t.is_epic()
	_icon.glyph = t.id
	_name.text = TowerInfo.full_name(t.id)
	_sub.text = TowerInfo.subtitle(t.id)
	_counters.text = _counter_bbcode(t.id)
	var preview := TowerInfo.next_level_preview(t.id, t.level)
	_next.text = preview if up < 0 else "Next level: " + preview
	_pips.queue_redraw()
	_panel.reset_size()


static func _counter_bbcode(id: StringName) -> String:
	var parts := PackedStringArray()
	for p in TowerInfo.counter_parts(id):
		if p[0] != &"note" or not TowerDefs.TOWERS[id].has("attack"):
			var c: Color = TowerTooltip.COUNTER_COLORS[p[0]]
			parts.append("[color=#%s]%s[/color]" % [UiTheme.hex(c), p[1]])
	return TowerInfo.SEP.join(parts)


## Called every frame while visible: keeps the plaque over its tower.
func follow(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH
		refresh()
		if not visible:
			return
	var cam := _game.camera.camera
	var anchor := Coords.tile_to_world(tile, Coords.PLATEAU_TOP + LIFT)
	if cam.is_position_behind(anchor):
		_panel.modulate.a = 0.0
		return
	_panel.modulate.a = 1.0
	var p := cam.unproject_position(anchor)
	var vp := get_viewport_rect().size
	var s := _panel.size
	var x := clampf(p.x - s.x / 2.0, SAFE_SIDE, vp.x - s.x - SAFE_SIDE)
	var y := clampf(p.y - s.y - POINTER.y, SAFE_TOP, vp.y - s.y - SAFE_BOTTOM)
	_panel.position = Vector2(x, y)
	_pointer.visible = absf(y - (p.y - s.y - POINTER.y)) < 1.0
	_pointer.position = Vector2(clampf(p.x, x + 16.0, x + s.x - 16.0) - POINTER.x / 2.0, y + s.y - 2.0)


func _draw_pointer() -> void:
	var pts := PackedVector2Array([Vector2.ZERO, Vector2(POINTER.x, 0), Vector2(POINTER.x / 2.0, POINTER.y)])
	_pointer.draw_colored_polygon(pts, UiTheme.STONE)
	_pointer.draw_polyline(PackedVector2Array([pts[0], pts[2], pts[1]]), UiTheme.GOLD, 2.0, true)


func _draw_pips() -> void:
	var c := Vector2(_pips.size.x - PIP * 1.5, _pips.size.y / 2.0)
	if _epic:
		UiGlyphs.star(_pips, Rect2(c - Vector2(9, 9), Vector2(18, 18)), Vector2(0.5, 0.5), 0.5, 0.2, 5, UiTheme.GOLD_BRIGHT)
		return
	for i in range(TowerDefs.MAX_LEVEL - 1, -1, -1):
		var color := UiTheme.GOLD_BRIGHT if i < _level else Color(UiTheme.GOLD_DIM, 0.7)
		UiGlyphs.diamond(_pips, c, PIP, color)
		c.x -= PIP * 2.3
