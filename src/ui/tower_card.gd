class_name TowerCard
extends Button
## One bottom-bar card (GDD §11): icon, name, cost, hotkey, attack/element
## pips and an air icon. Draws itself and redraws only when its state changes;
## the shapes between two texts go out as one draw call (UiMesh).
## Dims when unaffordable; Epic cards pulse when a fusion is possible. A
## locked card says which pick opens it, in place of its cost, while one waits.

const SIZE := Vector2(88, 112)
const ICON_PX := 44.0
const ICON_TOP := 13.0
const NAME_Y := 75.0
const PIPS_Y := 81.0
const PIP_PX := 13.0
const COST_Y := 104.0
const COIN_PX := 12.0
const BADGE := Rect2(5, 5, 17, 15)
const AIR_PX := 15.0
const LOCK_PX := 22.0
const NAME_SIZE := 12
const COST_SIZE := 13
const DIM := Color(1, 1, 1, 0.42)
const GLOW_PERIOD := 0.7

static var _styles := {}

var id: StringName
var affordable := true:
	set = set_affordable
## True while this card's tower is the build choice.
var chosen := false:
	set = set_chosen
## Epic cards only: a fusion is possible right now.
var lit := false:
	set = set_lit
## eletd: the tower's element isn't picked yet. Dimmed with a lock.
var locked := false:
	set = set_locked
## eletd: shown in place of the cost while a pick that opens it waits
## (ElementPicks.card_hint), e.g. "Pick Aqua".
var hint := "":
	set = set_hint

var _hover := false
var _warm_size := -Vector2.ONE
var _glow := Control.new()
var _glow_tween: Tween


func _init(tower: StringName) -> void:
	id = tower
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = SIZE
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.visible = false
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


func set_affordable(value: bool) -> void:
	if value != affordable:
		affordable = value
		queue_redraw()


func set_chosen(value: bool) -> void:
	if value != chosen:
		chosen = value
		queue_redraw()


func set_locked(value: bool) -> void:
	if value != locked:
		locked = value
		queue_redraw()


func set_hint(value: String) -> void:
	if value != hint:
		hint = value
		queue_redraw()


func set_lit(value: bool) -> void:
	if value == lit:
		return
	lit = value
	_glow.visible = value
	if _glow_tween != null:
		_glow_tween.kill()
		_glow_tween = null
	if value and is_inside_tree():
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_property(_glow, "modulate:a", 0.3, GLOW_PERIOD)
		_glow_tween.tween_property(_glow, "modulate:a", 1.0, GLOW_PERIOD)
	queue_redraw()


func _set_hover(value: bool) -> void:
	_hover = value
	queue_redraw()


func _draw() -> void:
	var epic := TowerInfo.is_epic(id)
	draw_style_box(_frame(epic), Rect2(Vector2.ZERO, size))
	var usable := lit if epic else ((affordable or chosen) and not locked)
	var tint := Color.WHITE if usable else DIM
	var font := UiTheme.bold()
	var cost := ("+%d" if epic else "%d") % TowerInfo.card_cost(id)
	var tw := font.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1, COST_SIZE).x
	var cost_x := (size.x - tw - COIN_PX - 3.0) / 2.0
	if _warm_size != size:
		# Build the other look too, so turning affordable or not never builds
		# geometry mid-game (first draws happen behind the loading screen).
		_warm_size = size
		_meshes(DIM if usable else Color.WHITE, cost_x)
	var meshes := _meshes(tint, cost_x)
	meshes[0].submit(self)
	draw_style_box(_badge(), BADGE)
	draw_string(
		font,
		BADGE.position + Vector2(0, 12),
		"G" if epic else TowerDefs.hotkey(id),
		HORIZONTAL_ALIGNMENT_CENTER,
		BADGE.size.x,
		11,
		UiTheme.GOLD_BRIGHT * tint
	)
	meshes[1].submit(self)
	draw_string(
		UiTheme.body(),
		Vector2(0, NAME_Y),
		TowerInfo.short_name(id),
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		NAME_SIZE,
		(UiTheme.GOLD_BRIGHT if chosen else UiTheme.TEXT) * tint
	)
	meshes[2].submit(self)
	if locked:
		UiMesh.cached([&"card_lock", size], _build_lock).submit(self)
	if hint != "":
		var c := UiTheme.element_color(TowerInfo.element_of(id))
		draw_string(
			font, Vector2(0, COST_Y), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, NAME_SIZE, c
		)
		return
	var ok := lit if epic else (affordable and not locked)
	var color := UiTheme.GOLD_BRIGHT if ok else UiTheme.BAD
	draw_string(
		font,
		Vector2(cost_x + COIN_PX + 3.0, COST_Y),
		cost,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		COST_SIZE,
		Color(color, tint.a)
	)


## The shapes between the card's texts, one draw call each: icon disc and
## glyph; the air badge; attack/element pips and the cost coin.
func _meshes(tint: Color, cost_x: float) -> Array[UiMesh]:
	var key := [id, size, tint, cost_x, TowerInfo.element_of(id)]
	var coin := hint == ""
	return [
		UiMesh.cached([&"card_icon"] + key, _build_icon.bind(tint)),
		UiMesh.cached([&"card_air"] + key, _build_air.bind(tint)),
		UiMesh.cached([&"card_tail", coin] + key, _build_tail.bind(tint, cost_x, coin)),
	]


func _build_icon(mesh: UiMesh, tint: Color) -> void:
	var fam: Color = UiTheme.FAMILY_COLORS[TowerDefs.TOWERS[id].family]
	var icon_center := Vector2(size.x / 2.0, ICON_TOP + ICON_PX / 2.0)
	mesh.draw_circle(icon_center, ICON_PX * 0.56, Color(fam, 0.13 * tint.a), true, -1.0, true)
	var icon_rect := Rect2(Vector2((size.x - ICON_PX) / 2.0, ICON_TOP), Vector2(ICON_PX, ICON_PX))
	UiGlyphs.draw(mesh, id, icon_rect, tint)


## A lock on a dark disc over the icon's lower right.
func _build_lock(mesh: UiMesh) -> void:
	var c := Vector2(size.x / 2.0 + ICON_PX * 0.32, ICON_TOP + ICON_PX * 0.72)
	mesh.draw_circle(c, LOCK_PX * 0.62, Color(UiTheme.STONE_DEEP, 0.9), true, -1.0, true)
	UiGlyphs.draw(mesh, &"lock", Rect2(c - Vector2.ONE * LOCK_PX / 2.0, Vector2.ONE * LOCK_PX))


func _build_air(mesh: UiMesh, tint: Color) -> void:
	if TowerDefs.TOWERS[id].get("air", false):
		var air := Rect2(Vector2(size.x - AIR_PX - 5.0, 5.0), Vector2(AIR_PX, AIR_PX))
		UiGlyphs.draw(mesh, &"cls_air", air, tint)


func _build_tail(mesh: UiMesh, tint: Color, cost_x: float, coin: bool) -> void:
	var def: Dictionary = TowerDefs.TOWERS[id]
	var glyphs: Array[StringName] = []
	if def.has("attack"):
		glyphs.append(UiGlyphs.attack(def.attack))
		glyphs.append(UiGlyphs.element(TowerInfo.element_of(id)))
	else:
		glyphs.append(&"aura")
	var w := glyphs.size() * PIP_PX + (glyphs.size() - 1) * 4.0
	var x := (size.x - w) / 2.0
	for g in glyphs:
		UiGlyphs.draw(mesh, g, Rect2(Vector2(x, PIPS_Y), Vector2(PIP_PX, PIP_PX)), tint)
		x += PIP_PX + 4.0
	if coin:
		var rect := Rect2(Vector2(cost_x, COST_Y - COIN_PX + 1.0), Vector2(COIN_PX, COIN_PX))
		UiGlyphs.coin(mesh, rect, tint)


func _draw_glow() -> void:
	var r := Rect2(Vector2.ZERO, _glow.size).grow(-1.0)
	_glow.draw_style_box(_style(&"glow"), r)


func _frame(epic: bool) -> StyleBox:
	if chosen:
		return _style(&"chosen")
	if _hover and not disabled:
		return _style(&"hover")
	return _style(&"epic" if epic else &"normal")


func _badge() -> StyleBox:
	return _style(&"badge")


static func _style(key: StringName) -> StyleBox:
	if _styles.is_empty():
		_styles[&"normal"] = UiTheme.box(UiTheme.STONE_HI, UiTheme.GOLD_DIM, 1, 6, Vector2.ZERO, 4)
		_styles[&"epic"] = UiTheme.box(
			UiTheme.STONE_HI, Color(UiTheme.FUSE, 0.45), 1, 6, Vector2.ZERO, 4
		)
		_styles[&"hover"] = UiTheme.box(
			UiTheme.STONE_HI.lightened(0.07), UiTheme.GOLD, 2, 6, Vector2.ZERO, 6
		)
		var chosen_box := UiTheme.box(UiTheme.STONE_DEEP, UiTheme.GOLD_BRIGHT, 2, 6, Vector2.ZERO)
		chosen_box.shadow_color = Color(UiTheme.GOLD_BRIGHT, 0.4)
		chosen_box.shadow_size = 10
		chosen_box.shadow_offset = Vector2.ZERO
		_styles[&"chosen"] = chosen_box
		var glow := UiTheme.box(Color(0, 0, 0, 0), UiTheme.FUSE, 2, 6, Vector2.ZERO)
		glow.draw_center = false
		glow.shadow_color = Color(UiTheme.FUSE, 0.55)
		glow.shadow_size = 12
		glow.shadow_offset = Vector2.ZERO
		_styles[&"glow"] = glow
		_styles[&"badge"] = UiTheme.box(
			Color(0, 0, 0, 0.55), UiTheme.GOLD_DIM, 1, 4, Vector2.ZERO, 0
		)
	return _styles[key]
