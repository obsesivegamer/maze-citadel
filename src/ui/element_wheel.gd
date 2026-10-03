class_name ElementWheel
extends Control
## The element wheel (GDD §6.2) as a ring of the six element glyphs, with an
## arrow from each element to the one it deals double damage to. When an
## element is focused (hovered, or set from code) its 200% arrow turns green,
## the arrow from the element that beats it turns red and the rest dim.

signal focus_changed(element: StringName)

const NODE_FRACTION := 0.085
const LABEL_GAP := 14.0
const ARROW_WIDTH := 3.0
const HEAD := 9.0
const NAME_SIZE := 12
const TAG_SIZE := 11
const DIM := 0.28

## The highlighted element, or &"" for none.
var focus: StringName = &"":
	set = set_focus
## Hover picks the focus; off for the small wheel on the welcome card.
var interactive := true


func _init(px := 280.0, hover := true) -> void:
	custom_minimum_size = Vector2(px, px)
	interactive = hover
	mouse_filter = Control.MOUSE_FILTER_STOP if hover else Control.MOUSE_FILTER_IGNORE
	mouse_exited.connect(func() -> void: set_focus(&""))


func set_focus(value: StringName) -> void:
	if value != focus:
		focus = value
		queue_redraw()
		focus_changed.emit(value)


func node_radius() -> float:
	return minf(size.x, size.y) * NODE_FRACTION


func ring_radius() -> float:
	return minf(size.x, size.y) / 2.0 - node_radius() - LABEL_GAP - 4.0


## Centre of element `i` of Damage.WHEEL: Light on top, then clockwise.
func node_center(i: int) -> Vector2:
	var a := -PI / 2.0 + TAU * i / Damage.WHEEL.size()
	return size / 2.0 + Vector2(cos(a), sin(a)) * ring_radius()


func element_at(pos: Vector2) -> StringName:
	for i in Damage.WHEEL.size():
		if pos.distance_to(node_center(i)) <= node_radius() * 1.35:
			return Damage.WHEEL[i]
	return &""


func _gui_input(event: InputEvent) -> void:
	if interactive and event is InputEventMouseMotion:
		set_focus(element_at((event as InputEventMouseMotion).position))


func _draw() -> void:
	var n := Damage.WHEEL.size()
	var fi := Damage.WHEEL.find(focus)
	for i in n:
		var color := UiTheme.GOLD
		if fi != -1:
			if i == fi:
				color = UiTheme.GOOD
			elif (i + 1) % n == fi:
				color = UiTheme.BAD
			else:
				color = Color(UiTheme.GOLD_DIM, DIM + 0.3)
		_arrow(i, color)
	for i in n:
		_node(i, fi == -1 or i == fi or (i + 1) % n == fi or (fi + 1) % n == i)
	_legend(fi)


## Centre text: how to read an arrow, or what the focused element does.
func _legend(fi: int) -> void:
	var rows: Array = [["Each arrow", UiTheme.TEXT_DIM], ["deals 200%", UiTheme.GOLD_BRIGHT]]
	rows.append(["back: 50%", UiTheme.TEXT_DIM])
	if fi != -1:
		var e: StringName = Damage.WHEEL[fi]
		rows = [
			[TowerInfo.ELEMENT_NAMES[e], UiTheme.element_color(e)],
			["200% vs " + TowerInfo.ELEMENT_NAMES[TowerInfo.strong_against(e)], UiTheme.GOOD],
			["50% vs " + TowerInfo.ELEMENT_NAMES[TowerInfo.weak_against(e)], UiTheme.BAD],
		]
	var font := UiTheme.bold()
	var y := size.y / 2.0 - (rows.size() - 1) * 8.0 + 4.0
	for row in rows:
		var w := font.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE).x
		draw_string(
			font,
			Vector2(size.x / 2.0 - w / 2.0, y),
			row[0],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			TAG_SIZE,
			row[1]
		)
		y += 16.0


## A curved arrow along the ring from element `from` to the next one.
func _arrow(from: int, color: Color) -> void:
	var c := size / 2.0
	var r := ring_radius()
	var step := TAU / Damage.WHEEL.size()
	var gap := asin(clampf((node_radius() + 5.0) / r, 0.0, 1.0))
	var a0 := -PI / 2.0 + step * from + gap
	var a1 := -PI / 2.0 + step * from + step - gap
	var head := HEAD / r
	draw_arc(c, r, a0, a1 - head * 0.6, 16, color, ARROW_WIDTH, true)
	var tip := c + Vector2(cos(a1), sin(a1)) * r
	var tangent := Vector2(-sin(a1), cos(a1))
	var normal := Vector2(cos(a1), sin(a1))
	var back := tip - tangent * HEAD * 1.4
	var pts := PackedVector2Array([tip, back + normal * HEAD * 0.75, back - normal * HEAD * 0.75])
	draw_colored_polygon(pts, color)


func _node(i: int, lit: bool) -> void:
	var e: StringName = Damage.WHEEL[i]
	var p := node_center(i)
	var nr := node_radius()
	var color := UiTheme.element_color(e)
	var tint := Color.WHITE if lit else Color(1, 1, 1, DIM)
	draw_circle(p, nr, Color(UiTheme.STONE_DEEP, 0.95 * tint.a), true, -1.0, true)
	draw_arc(p, nr, 0.0, TAU, 32, Color(color, tint.a), 2.0 if e == focus else 1.5, true)
	var g := nr * 1.2
	UiGlyphs.draw(self, UiGlyphs.element(e), Rect2(p - Vector2(g, g) / 2.0, Vector2(g, g)), tint)
	var label: String = TowerInfo.ELEMENT_NAMES[e]
	var font := UiTheme.heading(700)
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
	var below := p.y >= size.y / 2.0 - 1.0
	var y := p.y + nr + LABEL_GAP if below else p.y - nr - 5.0
	draw_string(
		font,
		Vector2(p.x - w / 2.0, y),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		NAME_SIZE,
		Color(color, tint.a)
	)
