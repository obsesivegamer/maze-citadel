class_name UiGlyphs
extends RefCounted
## Procedural HUD icons, drawn with CanvasItem calls so they stay crisp at any
## UI scale and need no texture assets. Shapes are authored in a unit square
## (0..1, y down) mapped onto the target rect; `tint` multiplies every colour.
## Elements, armor classes and attack types use prefixed ids (see element(),
## armor(), attack()); towers and creeps are drawn by UiUnitGlyphs.
## `ci` is a CanvasItem in its draw pass or a UiMesh, which merges a glyph's
## shapes into a single draw call.

const IRON := Color(0.34, 0.33, 0.32)
const STEEL := Color(0.8, 0.82, 0.86)
const WOOD := Color(0.62, 0.43, 0.25)
const BONE := Color(0.95, 0.91, 0.81)
const INK := Color(0.1, 0.08, 0.07)
const COIN := Color(1.0, 0.8, 0.27)
const COIN_DARK := Color(0.6, 0.42, 0.1)
const BLOOD := Color(0.92, 0.2, 0.2)
const SKY := Color(0.62, 0.87, 1.0)
const FEL := Color(0.55, 1.0, 0.35)
## AA edge drawn around filled polygons (Godot polygons have no antialiasing).
const EDGE := 0.8

const SYMBOLS: Array[StringName] = [
	&"coin",
	&"heart",
	&"skull",
	&"interest",
	&"swords",
	&"burst",
	&"gear",
	&"pause",
	&"play",
	&"next",
	&"lock",
	&"infinity",
	&"upgrade",
	&"fuse",
	&"eye",
	&"cam_full",
	&"cam_portal",
	&"cam_gate",
	&"boss_track",
	&"aura",
]
const ELEMENT_IDS: Array[StringName] = [
	&"el_light", &"el_dark", &"el_aqua", &"el_flame", &"el_verdant", &"el_stone"
]
const CLASS_IDS: Array[StringName] = [&"cls_light", &"cls_armored", &"cls_air", &"cls_boss"]
const ATTACK_IDS: Array[StringName] = [
	&"atk_pierce", &"atk_siege", &"atk_magic", &"atk_poison", &"atk_rune"
]


static func element(e: StringName) -> StringName:
	return StringName("el_" + e)


static func armor(c: StringName) -> StringName:
	return StringName("cls_" + c)


static func attack(a: StringName) -> StringName:
	return StringName("atk_" + a)


static func has(id: StringName) -> bool:
	return (
		id in SYMBOLS
		or id in ELEMENT_IDS
		or id in CLASS_IDS
		or id in ATTACK_IDS
		or UiUnitGlyphs.has(id)
	)


## Draws glyph `id` into `r` on `ci`. Unknown ids draw nothing.
static func draw(ci: Object, id: StringName, r: Rect2, tint := Color.WHITE) -> void:
	if UiUnitGlyphs.has(id):
		UiUnitGlyphs.draw(ci, id, r, tint)
		return
	match id:
		&"coin":
			coin(ci, r, tint)
		&"heart":
			_heart(ci, r, tint)
		&"skull":
			_skull(ci, r, tint)
		&"interest":
			coin(ci, sub(r, 0.0, 0.18, 0.78), tint)
			poly(
				ci,
				r,
				[0.78, 0.04, 0.98, 0.3, 0.86, 0.3, 0.86, 0.5, 0.7, 0.5, 0.7, 0.3, 0.58, 0.3],
				Color(0.5, 0.95, 0.4) * tint
			)
		&"swords":
			_swords(ci, r, tint)
		&"burst":
			star(ci, r, Vector2(0.5, 0.5), 0.47, 0.2, 8, Color(1.0, 0.58, 0.2) * tint)
			star(ci, r, Vector2(0.5, 0.5), 0.26, 0.11, 8, Color(1.0, 0.9, 0.5) * tint, 0.2)
		&"gear":
			gear(ci, r, Color(0.84, 0.78, 0.66) * tint)
		&"pause":
			poly(ci, r, [0.26, 0.18, 0.43, 0.18, 0.43, 0.82, 0.26, 0.82], BONE * tint)
			poly(ci, r, [0.57, 0.18, 0.74, 0.18, 0.74, 0.82, 0.57, 0.82], BONE * tint)
		&"play":
			poly(ci, r, [0.28, 0.16, 0.82, 0.5, 0.28, 0.84], BONE * tint)
		&"next":
			poly(ci, r, [0.12, 0.2, 0.5, 0.5, 0.12, 0.8], BONE * tint)
			poly(ci, r, [0.48, 0.2, 0.86, 0.5, 0.48, 0.8], BONE * tint)
		&"lock":
			arc(ci, r, Vector2(0.5, 0.42), 0.2, PI, TAU, STEEL * tint, 0.09)
			line(ci, r, Vector2(0.3, 0.42), Vector2(0.3, 0.5), STEEL * tint, 0.09)
			line(ci, r, Vector2(0.7, 0.42), Vector2(0.7, 0.5), STEEL * tint, 0.09)
			poly(ci, r, [0.2, 0.48, 0.8, 0.48, 0.8, 0.88, 0.2, 0.88], COIN * tint)
			dot(ci, r, Vector2(0.5, 0.65), 0.07, INK * tint)
		&"infinity":
			ring(ci, r, Vector2(0.31, 0.5), 0.17, BONE * tint, 0.08)
			ring(ci, r, Vector2(0.69, 0.5), 0.17, BONE * tint, 0.08)
		&"upgrade":
			poly(
				ci,
				r,
				[0.5, 0.08, 0.88, 0.48, 0.64, 0.48, 0.64, 0.9, 0.36, 0.9, 0.36, 0.48, 0.12, 0.48],
				Color(0.55, 0.95, 0.45) * tint
			)
		&"fuse":
			star(ci, r, Vector2(0.5, 0.5), 0.46, 0.13, 4, Color(0.6, 0.9, 1.0) * tint)
			star(ci, r, Vector2(0.5, 0.5), 0.26, 0.08, 4, Color(1, 1, 1) * tint, PI / 4.0)
		&"eye":
			_eye(ci, r, Color(1.0, 0.4, 0.3) * tint)
		&"cam_full":
			_board(ci, r, tint)
		&"cam_portal":
			_arch(ci, r, Color(0.95, 0.3, 0.22) * tint, false)
		&"cam_gate":
			_arch(ci, r, Color(0.45, 0.68, 1.0) * tint, true)
		&"boss_track":
			ring(ci, r, Vector2(0.5, 0.5), 0.3, Color(1.0, 0.42, 0.32) * tint, 0.08)
			for d in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
				var c := Vector2(0.5, 0.5)
				line(ci, r, c + d * 0.2, c + d * 0.46, Color(1.0, 0.42, 0.32) * tint, 0.08)
			dot(ci, r, Vector2(0.5, 0.5), 0.08, Color(1.0, 0.8, 0.5) * tint)
		&"aura":
			ring(ci, r, Vector2(0.5, 0.5), 0.4, Color(1.0, 0.84, 0.42, 0.5) * tint, 0.06)
			ring(ci, r, Vector2(0.5, 0.5), 0.26, Color(1.0, 0.84, 0.42, 0.8) * tint, 0.07)
			dot(ci, r, Vector2(0.5, 0.5), 0.11, Color(1.0, 0.92, 0.6) * tint)
		&"el_light":
			_sun(ci, r, UiTheme.ELEMENT_COLORS[&"light"] * tint)
		&"el_dark":
			_moon(ci, r, UiTheme.ELEMENT_COLORS[&"dark"] * tint)
		&"el_aqua":
			_drop(ci, r, UiTheme.ELEMENT_COLORS[&"aqua"] * tint)
		&"el_flame":
			flame(ci, r, UiTheme.ELEMENT_COLORS[&"flame"] * tint, Color(1.0, 0.9, 0.45) * tint)
		&"el_verdant":
			_leaf(ci, r, UiTheme.ELEMENT_COLORS[&"verdant"] * tint)
		&"el_stone":
			_rock(ci, r, UiTheme.ELEMENT_COLORS[&"stone"] * tint)
		&"cls_light":
			ring(ci, r, Vector2(0.5, 0.5), 0.34, UiTheme.CLASS_COLORS[&"light"] * tint, 0.1)
			dot(ci, r, Vector2(0.5, 0.5), 0.11, UiTheme.CLASS_COLORS[&"light"] * tint)
		&"cls_armored":
			shield(ci, r, UiTheme.CLASS_COLORS[&"armored"] * tint, IRON * tint)
		&"cls_air":
			wing(ci, r, UiTheme.CLASS_COLORS[&"air"] * tint)
		&"cls_boss":
			_crown(ci, r, UiTheme.CLASS_COLORS[&"boss"] * tint)
		&"atk_pierce":
			_arrow(ci, r, UiTheme.ATTACK_COLORS[&"pierce"] * tint)
		&"atk_siege":
			_bomb(ci, r, tint)
		&"atk_magic":
			star(ci, r, Vector2(0.44, 0.56), 0.4, 0.11, 4, UiTheme.ATTACK_COLORS[&"magic"] * tint)
			star(ci, r, Vector2(0.8, 0.2), 0.16, 0.05, 4, UiTheme.ATTACK_COLORS[&"magic"] * tint)
		&"atk_poison":
			_flask(ci, r, UiTheme.ATTACK_COLORS[&"poison"] * tint, tint)
		&"atk_rune":
			_runestone(ci, r, UiTheme.ATTACK_COLORS[&"rune"] * tint, tint)


# --- Primitives (unit-square coordinates) -----------------------------------


static func pt(r: Rect2, p: Vector2) -> Vector2:
	return r.position + p * r.size


static func poly(ci: Object, r: Rect2, flat: Array, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		pts.append(r.position + Vector2(flat[i], flat[i + 1]) * r.size)
	poly_pts(ci, pts, color)


## Tiny glyphs can collapse into shapes the renderer can't triangulate (e.g.
## the crescent's tips at pip size); those keep their outline and skip the fill.
static func poly_pts(ci: Object, pts: PackedVector2Array, color: Color) -> void:
	if not Geometry2D.triangulate_polygon(pts).is_empty():
		ci.draw_colored_polygon(pts, color)
	var edge := pts.duplicate()
	edge.append(pts[0])
	ci.draw_polyline(edge, color, EDGE, true)


static func line(ci: Object, r: Rect2, a: Vector2, b: Vector2, color: Color, w: float) -> void:
	ci.draw_line(pt(r, a), pt(r, b), color, maxf(w * r.size.x, 1.0), true)


static func dot(ci: Object, r: Rect2, c: Vector2, rad: float, color: Color) -> void:
	ci.draw_circle(pt(r, c), rad * r.size.x, color, true, -1.0, true)


static func ring(ci: Object, r: Rect2, c: Vector2, rad: float, color: Color, w: float) -> void:
	ci.draw_arc(pt(r, c), rad * r.size.x, 0.0, TAU, 40, color, maxf(w * r.size.x, 1.0), true)


static func arc(
	ci: Object, r: Rect2, c: Vector2, rad: float, a0: float, a1: float, color: Color, w: float
) -> void:
	ci.draw_arc(pt(r, c), rad * r.size.x, a0, a1, 24, color, maxf(w * r.size.x, 1.0), true)


## A star (or burst) with `n` points; radii are in unit-square fractions.
static func star(
	ci: Object,
	r: Rect2,
	c: Vector2,
	outer: float,
	inner: float,
	n: int,
	color: Color,
	rot := 0.0,
) -> void:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := rot - PI / 2.0 + PI * i / n
		var rad := outer if i % 2 == 0 else inner
		pts.append(pt(r, c + Vector2(cos(a), sin(a)) * rad))
	poly_pts(ci, pts, color)


## A small filled diamond in canvas coordinates (trim studs, level pips).
static func diamond(ci: Object, c: Vector2, s: float, color: Color) -> void:
	var pts := PackedVector2Array(
		[c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]
	)
	poly_pts(ci, pts, color)


## Points along a circle arc in unit space, for building outlines.
static func arc_pts(
	out: PackedVector2Array, r: Rect2, c: Vector2, rad: Vector2, a0: float, a1: float, n: int
) -> void:
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		out.append(pt(r, c + Vector2(cos(a) * rad.x, sin(a) * rad.y)))


## A sub-rect of `r` at unit offset (x, y) with unit size `s`.
static func sub(r: Rect2, x: float, y: float, s: float) -> Rect2:
	return Rect2(pt(r, Vector2(x, y)), r.size * s)


# --- Shared shapes ----------------------------------------------------------


static func coin(ci: Object, r: Rect2, tint: Color) -> void:
	dot(ci, r, Vector2(0.5, 0.5), 0.45, COIN_DARK * tint)
	dot(ci, r, Vector2(0.5, 0.5), 0.38, COIN * tint)
	ring(ci, r, Vector2(0.5, 0.5), 0.27, COIN_DARK * tint, 0.05)
	poly(ci, r, [0.5, 0.33, 0.6, 0.5, 0.5, 0.67, 0.4, 0.5], COIN_DARK * tint)
	arc(ci, r, Vector2(0.5, 0.5), 0.33, PI * 1.1, PI * 1.5, Color(1, 1, 1, 0.55) * tint, 0.05)


static func gear(ci: Object, r: Rect2, color: Color) -> void:
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector2(cos(a), sin(a))
		var s := Vector2(-d.y, d.x) * 0.075
		var c := Vector2(0.5, 0.5)
		var pts := PackedVector2Array(
			[
				pt(r, c + d * 0.22 - s),
				pt(r, c + d * 0.46 - s * 0.8),
				pt(r, c + d * 0.46 + s * 0.8),
				pt(r, c + d * 0.22 + s),
			]
		)
		poly_pts(ci, pts, color)
	ring(ci, r, Vector2(0.5, 0.5), 0.25, color, 0.14)


static func shield(ci: Object, r: Rect2, color: Color, trim: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(pt(r, Vector2(0.17, 0.12)))
	pts.append(pt(r, Vector2(0.83, 0.12)))
	pts.append(pt(r, Vector2(0.83, 0.46)))
	arc_pts(pts, r, Vector2(0.5, 0.46), Vector2(0.33, 0.44), 0.15, PI - 0.15, 8)
	pts.append(pt(r, Vector2(0.17, 0.46)))
	poly_pts(ci, pts, color)
	line(ci, r, Vector2(0.5, 0.18), Vector2(0.5, 0.82), trim, 0.06)
	line(ci, r, Vector2(0.24, 0.4), Vector2(0.76, 0.4), trim, 0.06)


static func wing(ci: Object, r: Rect2, color: Color) -> void:
	var pts := [0.1, 0.66, 0.26, 0.38, 0.52, 0.22, 0.92, 0.12, 0.8, 0.31, 0.9, 0.36]
	pts.append_array([0.74, 0.48, 0.82, 0.55, 0.62, 0.64, 0.67, 0.71, 0.42, 0.74])
	poly(ci, r, pts, color)


static func flame(ci: Object, r: Rect2, outer: Color, inner: Color) -> void:
	var o := [0.52, 0.04, 0.66, 0.27, 0.79, 0.42, 0.83, 0.62, 0.75, 0.81, 0.56, 0.93]
	o.append_array([0.4, 0.92, 0.23, 0.8, 0.17, 0.6, 0.26, 0.38, 0.34, 0.5, 0.4, 0.28])
	poly(ci, r, o, outer)
	poly(ci, sub(r, 0.25, 0.4, 0.5), o, inner)


# --- Symbols ------------------------------------------------------------------


static func _heart(ci: Object, r: Rect2, tint: Color) -> void:
	var pts := PackedVector2Array()
	for i in 36:
		var t := TAU * i / 36.0
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
		pts.append(pt(r, Vector2(0.5 + x / 36.0, 0.47 - y / 36.0)))
	poly_pts(ci, pts, BLOOD * tint)
	dot(ci, r, Vector2(0.33, 0.34), 0.07, Color(1, 1, 1, 0.45) * tint)


static func _skull(ci: Object, r: Rect2, tint: Color) -> void:
	dot(ci, r, Vector2(0.5, 0.42), 0.33, BONE * tint)
	poly(ci, r, [0.31, 0.55, 0.69, 0.55, 0.66, 0.86, 0.34, 0.86], BONE * tint)
	dot(ci, r, Vector2(0.37, 0.45), 0.1, INK * tint)
	dot(ci, r, Vector2(0.63, 0.45), 0.1, INK * tint)
	poly(ci, r, [0.5, 0.56, 0.55, 0.66, 0.45, 0.66], INK * tint)
	for x in [0.42, 0.5, 0.58]:
		line(ci, r, Vector2(x, 0.74), Vector2(x, 0.86), INK * tint, 0.03)


static func _swords(ci: Object, r: Rect2, tint: Color) -> void:
	for flip in [false, true]:
		var a := Vector2(0.14, 0.86) if not flip else Vector2(0.86, 0.86)
		var b := Vector2(0.84, 0.14) if not flip else Vector2(0.16, 0.14)
		line(ci, r, a.lerp(b, 0.18), b, STEEL * tint, 0.08)
		line(ci, r, a, a.lerp(b, 0.18), WOOD * tint, 0.08)
		var g := a.lerp(b, 0.2)
		var n := Vector2(-(b - a).y, (b - a).x).normalized() * 0.12
		line(ci, r, g - n, g + n, COIN * tint, 0.07)


static func _eye(ci: Object, r: Rect2, color: Color) -> void:
	var pts := PackedVector2Array()
	arc_pts(pts, r, Vector2(0.5, 0.78), Vector2(0.52, 0.52), -PI * 0.82, -PI * 0.18, 10)
	for i in range(1, 10):
		var a := lerpf(PI * 0.18, PI * 0.82, i / 10.0)
		pts.append(pt(r, Vector2(0.5, 0.22) + Vector2(cos(a), sin(a)) * 0.52))
	poly_pts(ci, pts, Color(0.95, 0.92, 0.85) * Color(1, 1, 1, color.a))
	dot(ci, r, Vector2(0.5, 0.5), 0.17, color)
	dot(ci, r, Vector2(0.5, 0.5), 0.07, INK * Color(1, 1, 1, color.a))


static func _board(ci: Object, r: Rect2, tint: Color) -> void:
	var c := Color(0.86, 0.8, 0.64) * tint
	poly(ci, r, [0.16, 0.12, 0.84, 0.12, 0.84, 0.88, 0.16, 0.88], Color(0.3, 0.42, 0.24) * tint)
	ci.draw_rect(
		Rect2(pt(r, Vector2(0.16, 0.12)), r.size * Vector2(0.68, 0.76)), c, false, 1.5, true
	)
	for f in [0.37, 0.63]:
		line(ci, r, Vector2(f, 0.14), Vector2(f, 0.86), Color(c, 0.6), 0.03)
	line(ci, r, Vector2(0.18, 0.5), Vector2(0.82, 0.5), Color(c, 0.6), 0.03)
	dot(ci, r, Vector2(0.5, 0.12), 0.07, Color(0.95, 0.3, 0.22) * tint)
	dot(ci, r, Vector2(0.5, 0.88), 0.07, Color(0.45, 0.68, 1.0) * tint)


static func _arch(ci: Object, r: Rect2, color: Color, bars: bool) -> void:
	var pts := PackedVector2Array()
	pts.append(pt(r, Vector2(0.18, 0.9)))
	arc_pts(pts, r, Vector2(0.5, 0.42), Vector2(0.32, 0.32), PI, TAU, 12)
	pts.append(pt(r, Vector2(0.82, 0.9)))
	poly_pts(ci, pts, Color(0.55, 0.5, 0.45) * Color(1, 1, 1, color.a))
	var inner := PackedVector2Array()
	inner.append(pt(r, Vector2(0.3, 0.9)))
	arc_pts(inner, r, Vector2(0.5, 0.45), Vector2(0.2, 0.2), PI, TAU, 10)
	inner.append(pt(r, Vector2(0.7, 0.9)))
	poly_pts(ci, inner, color)
	if bars:
		for x in [0.38, 0.5, 0.62]:
			line(ci, r, Vector2(x, 0.3), Vector2(x, 0.9), INK, 0.035)
	else:
		dot(ci, r, Vector2(0.5, 0.58), 0.08, Color(1.0, 0.85, 0.5) * Color(1, 1, 1, color.a))


static func _sun(ci: Object, r: Rect2, color: Color) -> void:
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector2(cos(a), sin(a))
		line(ci, r, Vector2(0.5, 0.5) + d * 0.3, Vector2(0.5, 0.5) + d * 0.46, color, 0.08)
	dot(ci, r, Vector2(0.5, 0.5), 0.22, color)
	dot(ci, r, Vector2(0.45, 0.45), 0.07, Color(1, 1, 1, 0.5 * color.a))


static func _moon(ci: Object, r: Rect2, color: Color) -> void:
	var pts := PackedVector2Array()
	arc_pts(pts, r, Vector2(0.5, 0.5), Vector2(0.4, 0.4), PI * 1.5, PI * 0.5, 14)
	arc_pts(pts, r, Vector2(0.5, 0.5), Vector2(0.18, 0.4), PI * 0.5 + 0.1, PI * 1.5 - 0.1, 12)
	poly_pts(ci, pts, color)
	dot(ci, r, Vector2(0.76, 0.3), 0.05, color)


static func _drop(ci: Object, r: Rect2, color: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(pt(r, Vector2(0.5, 0.06)))
	arc_pts(pts, r, Vector2(0.5, 0.62), Vector2(0.28, 0.28), -0.7, PI + 0.7, 16)
	poly_pts(ci, pts, color)
	dot(ci, r, Vector2(0.4, 0.62), 0.06, Color(1, 1, 1, 0.55 * color.a))


static func _leaf(ci: Object, r: Rect2, color: Color) -> void:
	var a := Vector2(0.16, 0.84)
	var b := Vector2(0.86, 0.14)
	var n := Vector2(-(b - a).y, (b - a).x).normalized()
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(pt(r, a.lerp(b, t) + n * 0.24 * sin(PI * t)))
	for i in range(11, 0, -1):
		var t := i / 12.0
		pts.append(pt(r, a.lerp(b, t) - n * 0.24 * sin(PI * t)))
	poly_pts(ci, pts, color)
	line(ci, r, Vector2(0.1, 0.9), a.lerp(b, 0.8), color.darkened(0.45), 0.04)


static func _rock(ci: Object, r: Rect2, color: Color) -> void:
	poly(ci, r, [0.48, 0.08, 0.82, 0.3, 0.86, 0.68, 0.56, 0.92, 0.18, 0.76, 0.14, 0.36], color)
	poly(ci, r, [0.48, 0.08, 0.82, 0.3, 0.5, 0.46, 0.14, 0.36], color.lightened(0.25))
	line(ci, r, Vector2(0.5, 0.46), Vector2(0.56, 0.92), color.darkened(0.4), 0.035)
	line(ci, r, Vector2(0.5, 0.46), Vector2(0.86, 0.68), color.darkened(0.4), 0.035)


static func _crown(ci: Object, r: Rect2, color: Color) -> void:
	poly(
		ci,
		r,
		[0.14, 0.78, 0.14, 0.32, 0.33, 0.52, 0.5, 0.2, 0.67, 0.52, 0.86, 0.32, 0.86, 0.78],
		color
	)
	poly(ci, r, [0.14, 0.7, 0.86, 0.7, 0.86, 0.82, 0.14, 0.82], color.darkened(0.35))
	for p in [Vector2(0.14, 0.3), Vector2(0.5, 0.18), Vector2(0.86, 0.3)]:
		dot(ci, r, p, 0.06, COIN * Color(1, 1, 1, color.a))


static func _arrow(ci: Object, r: Rect2, color: Color) -> void:
	line(ci, r, Vector2(0.16, 0.84), Vector2(0.72, 0.28), color, 0.07)
	poly(ci, r, [0.88, 0.12, 0.8, 0.44, 0.56, 0.2], color)
	line(ci, r, Vector2(0.16, 0.84), Vector2(0.1, 0.66), color, 0.05)
	line(ci, r, Vector2(0.16, 0.84), Vector2(0.34, 0.9), color, 0.05)


static func _bomb(ci: Object, r: Rect2, tint: Color) -> void:
	dot(ci, r, Vector2(0.44, 0.6), 0.32, IRON * tint)
	dot(ci, r, Vector2(0.34, 0.5), 0.08, Color(1, 1, 1, 0.35) * tint)
	line(ci, r, Vector2(0.64, 0.36), Vector2(0.76, 0.2), WOOD * tint, 0.06)
	star(ci, r, Vector2(0.8, 0.15), 0.15, 0.05, 6, UiTheme.ATTACK_COLORS[&"siege"] * tint)


static func _flask(ci: Object, r: Rect2, color: Color, tint: Color) -> void:
	poly(ci, r, [0.4, 0.12, 0.6, 0.12, 0.6, 0.42, 0.4, 0.42], Color(0.75, 0.82, 0.8, 0.9) * tint)
	dot(ci, r, Vector2(0.5, 0.64), 0.29, color)
	dot(ci, r, Vector2(0.42, 0.58), 0.06, Color(1, 1, 1, 0.5) * tint)
	dot(ci, r, Vector2(0.62, 0.7), 0.05, color.lightened(0.4))
	line(ci, r, Vector2(0.36, 0.12), Vector2(0.64, 0.12), STEEL * tint, 0.06)


static func _runestone(ci: Object, r: Rect2, color: Color, tint: Color) -> void:
	poly(
		ci,
		r,
		[0.3, 0.1, 0.7, 0.1, 0.8, 0.3, 0.78, 0.9, 0.22, 0.9, 0.2, 0.3],
		Color(0.55, 0.52, 0.5) * tint
	)
	line(ci, r, Vector2(0.5, 0.24), Vector2(0.5, 0.78), color, 0.07)
	line(ci, r, Vector2(0.5, 0.46), Vector2(0.33, 0.28), color, 0.07)
	line(ci, r, Vector2(0.5, 0.46), Vector2(0.67, 0.28), color, 0.07)
