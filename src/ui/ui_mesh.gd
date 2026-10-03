class_name UiMesh
extends RefCounted
## Collects the triangles Godot would emit for a run of CanvasItem draw calls
## and submits them as one triangle array. The 2D renderer gives every
## polygon its own draw call (an antialiased polyline or arc costs three, a
## circle two, so one coin glyph was 14); merged, a whole icon is one. The
## vertices, colours and order follow the engine's own tessellation
## (RendererCanvasCull in Godot 4.7), so the picture is unchanged.
##
## Method names and arguments match CanvasItem's, so UiGlyphs draws into
## either. Only what the HUD uses is supported: filled circles, and widths
## >= 0 (thin line-strip lines can't join a triangle array).
##
## Building the triangles in GDScript costs far more than the engine's C++
## (about 0.5 ms for a tower card), so finished meshes are cached by what
## they depend on: a redraw that repeats (hover, a card turning affordable
## again, a creep icon seen before) costs no geometry work.

## The engine's antialiasing feather, in canvas units.
const FEATHER := 1.25
const CIRCLE_SEGMENTS := 64
## Plenty for the HUD's distinct glyph/size/tint combinations; a bound in
## case something keys on a value that keeps changing.
const CACHE_LIMIT := 256

static var _cache := {}

var points := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()
## Polygon draw calls the same calls would have cost on a CanvasItem.
var source_calls := 0


## The mesh `build` (called with a new UiMesh) draws, built once per `key`.
## The key must hold everything the drawing depends on (glyph, rect, tint).
static func cached(key: Array, build: Callable) -> UiMesh:
	var mesh: UiMesh = _cache.get(key)
	if mesh == null:
		if _cache.size() >= CACHE_LIMIT:
			_cache.clear()
		mesh = UiMesh.new()
		build.call(mesh)
		_cache[key] = mesh
	return mesh


func is_empty() -> bool:
	return indices.is_empty()


## Adds the triangles to `ci` (call from its draw pass) and keeps them.
func submit(ci: CanvasItem) -> void:
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(
			ci.get_canvas_item(), indices, points, colors
		)


## submit(), then starts over, for a draw pass that interleaves text.
func flush(ci: CanvasItem) -> void:
	submit(ci)
	points = PackedVector2Array()
	colors = PackedColorArray()
	indices = PackedInt32Array()


func draw_colored_polygon(pts: PackedVector2Array, color: Color) -> void:
	draw_polygon(pts, PackedColorArray([color]))


func draw_polygon(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	var tri := Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		return
	var base := points.size()
	points.append_array(pts)
	for i in pts.size():
		colors.append(cols[i] if cols.size() > 1 else cols[0])
	for t in tri:
		indices.append(base + t)
	source_calls += 1


## Engine: canvas_item_add_line (a quad, plus eight feather quads when
## antialiased). Drawn directly these batch, so they add no source calls.
func draw_line(
	from: Vector2, to: Vector2, color: Color, width := -1.0, antialiased := false
) -> void:
	assert(width >= 0.0, "UiMesh: thin lines can't be merged")
	var diff := from - to
	var dir := diff.orthogonal().normalized()
	if antialiased:
		width = compensated_width(width)
	var t := dir * width * 0.5
	var bl := from + t
	var br := from - t
	var el := to + t
	var er := to - t
	_quad(bl, br, er, el, color, color, color, color)
	if not antialiased:
		return
	var feather := FEATHER * width if width < 1.0 else FEATHER
	var b := dir * feather
	var b2 := diff.normalized() * feather
	var clear := Color(color, 0.0)
	_quad(bl, bl + b, el + b, el, color, clear, clear, color)
	_quad(br, br - b, er - b, er, color, clear, clear, color)
	_quad(bl, bl + b2, br + b2, br, color, clear, clear, color)
	_quad(el, el - b2, er - b2, er, color, clear, clear, color)
	_quad(bl, bl + b2, bl + b + b2, bl + b, color, clear, clear, clear)
	_quad(br, br + b2, br - b + b2, br - b, color, clear, clear, clear)
	_quad(el, el - b2, el + b - b2, el + b, color, clear, clear, clear)
	_quad(er, er - b2, er - b - b2, er - b, color, clear, clear, clear)


func draw_polyline(
	pts: PackedVector2Array, color: Color, width := -1.0, antialiased := false
) -> void:
	polyline(pts, PackedColorArray([color]), width, antialiased)


func draw_polyline_colors(
	pts: PackedVector2Array, cols: PackedColorArray, width := -1.0, antialiased := false
) -> void:
	polyline(pts, cols, width, antialiased)


## Engine: CanvasItem.draw_ellipse_arc, then a polyline.
func draw_arc(
	center: Vector2,
	radius: float,
	start: float,
	end: float,
	point_count: int,
	color: Color,
	width := -1.0,
	antialiased := false
) -> void:
	var pts := PackedVector2Array()
	pts.resize(point_count)
	var delta := clampf(end - start, -TAU, TAU)
	for i in point_count:
		var theta := (i / (point_count - 1.0)) * delta + start
		pts[i] = center + Vector2(radius * cos(theta), radius * sin(theta))
	polyline(pts, PackedColorArray([color]), width, antialiased)


## Engine: canvas_item_add_ellipse (a 64-segment fan, plus a feather strip).
func draw_circle(
	pos: Vector2, radius: float, color: Color, filled := true, _width := -1.0, antialiased := false
) -> void:
	assert(filled, "UiMesh: only filled circles")
	var r := maxf(0.0, radius - FEATHER * 0.25) if antialiased else radius
	var step := TAU / CIRCLE_SEGMENTS
	var base := points.size()
	for i in CIRCLE_SEGMENTS + 1:
		var a := i * step
		points.append(Vector2(cos(a) * r, sin(a) * r) + pos)
		colors.append(color)
	points.append(pos)
	colors.append(color)
	for i in CIRCLE_SEGMENTS:
		indices.append_array([base + CIRCLE_SEGMENTS + 1, base + i, base + i + 1])
	source_calls += 1
	if not antialiased:
		return
	var feather := FEATHER
	if r * 2.0 < 1.0:
		feather *= r
	var ring := PackedVector2Array()
	var ring_c := PackedColorArray()
	var clear := Color(color, 0.0)
	for i in CIRCLE_SEGMENTS + 1:
		var a := i * step
		var d := Vector2(cos(a), sin(a))
		ring.append(d * r + pos)
		ring.append(d * (r + feather) + pos)
		ring_c.append(color)
		ring_c.append(clear)
	_strip(ring, ring_c)
	source_calls += 1


## Engine: CanvasItem.draw_rect unfilled (a closed polyline).
func draw_rect(
	rect: Rect2, color: Color, filled := true, width := -1.0, antialiased := false
) -> void:
	var r := rect.abs()
	assert(not filled and width < r.size.x and width < r.size.y, "UiMesh: only outlines")
	var pts := PackedVector2Array(
		[r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]
	)
	pts.append(r.position)
	polyline(pts, PackedColorArray([color]), width, antialiased)


## Engine: canvas_item_get_compensated_antialiasing_width.
static func compensated_width(width: float) -> float:
	if width <= 0.0:
		return width
	if width <= FEATHER * 2.0 + 0.00001:
		return width * 0.5
	if width <= FEATHER * 4.0 + 0.00001:
		return remap(width, FEATHER * 2.0, FEATHER * 4.0, width * 0.5, width - FEATHER * 0.5)
	return width - FEATHER * 0.5


## Engine: canvas_item_add_polyline: a triangle strip, plus a feather strip on
## each side when antialiased (drawn after it, left then right).
func polyline(pts: PackedVector2Array, cols: PackedColorArray, width: float, aa: bool) -> void:
	if aa:
		width = compensated_width(width)
	assert(width >= 0.0, "UiMesh: thin polylines can't be merged")
	var n := pts.size()
	var count := n * 2
	var loop := pts[0].is_equal_approx(pts[n - 1])
	var first_dir := Vector2.ZERO
	for i in range(1, n):
		first_dir = (pts[i] - pts[i - 1]).normalized()
		if not first_dir.is_zero_approx():
			break
	var last_dir := Vector2.ZERO
	for i in range(n - 1, 0, -1):
		last_dir = (pts[i] - pts[i - 1]).normalized()
		if not last_dir.is_zero_approx():
			break
	var open := aa and not loop
	var mid := PackedVector2Array()
	var mid_c := PackedColorArray()
	mid.resize(count + (4 if open else 0))
	mid_c.resize(mid.size())
	var left := PackedVector2Array()
	var left_c := PackedColorArray()
	var right := PackedVector2Array()
	var right_c := PackedColorArray()
	if aa:
		left.resize(count + (0 if loop else 5))
		left_c.resize(left.size())
		right.resize(left.size())
		right_c.resize(left.size())
	var feather := FEATHER * width if width < 1.0 else FEATHER
	var color := Color(1, 1, 1, 1)
	var clear := Color(1, 1, 1, 0)
	var prev := Vector2.ZERO
	for i in n:
		var first := i == 0
		var last := i == n - 1
		var seg := _segment_dir(pts, i, prev)
		if first and loop:
			prev = last_dir
		elif last and loop:
			prev = first_dir
		var base: Vector2
		if first and not loop:
			base = first_dir.orthogonal()
		elif last and not loop:
			base = last_dir.orthogonal()
		else:
			base = _edge_offset(seg, prev)
		var edge := base * (width * 0.5)
		var pos := pts[i]
		if i < cols.size():
			color = cols[i]
			clear = Color(color, 0.0)
		var j := i * 2 + (2 if open else 0)
		mid[j] = pos + edge
		mid[j + 1] = pos - edge
		mid_c[j] = color
		mid_c[j + 1] = color
		if aa:
			var b := base * feather
			left[j] = pos + edge
			left[j + 1] = pos + edge + b
			right[j] = pos - edge
			right[j + 1] = pos - edge - b
			left_c[j] = color
			left_c[j + 1] = clear
			right_c[j] = color
			right_c[j + 1] = clear
			if first and not loop:
				var bb := -seg * feather
				mid[0] = pos + edge + bb
				mid[1] = pos - edge + bb
				left[0] = pos + edge + bb
				left[1] = pos + edge + bb + b
				right[0] = pos - edge + bb
				right[1] = pos - edge + bb - b
				mid_c[0] = clear
				mid_c[1] = clear
				left_c[0] = clear
				left_c[1] = clear
				right_c[0] = clear
				right_c[1] = clear
			if last and not loop:
				var eb := prev * feather
				var e := count + 2
				mid[e] = pos + edge + eb
				mid[e + 1] = pos - edge + eb
				mid_c[e] = clear
				mid_c[e + 1] = clear
				left[e] = pos + edge
				left[e + 1] = pos + edge + eb + b
				left[e + 2] = pos + edge + eb
				right[e] = pos - edge
				right[e + 1] = pos - edge + eb - b
				right[e + 2] = pos - edge + eb
				left_c[e] = color
				left_c[e + 1] = clear
				left_c[e + 2] = clear
				right_c[e] = color
				right_c[e + 1] = clear
				right_c[e + 2] = clear
		prev = seg
	_strip(mid, mid_c)
	source_calls += 1
	if aa:
		_strip(left, left_c)
		_strip(right, right_c)
		source_calls += 2


static func _segment_dir(pts: PackedVector2Array, i: int, prev: Vector2) -> Vector2:
	if i == pts.size() - 1:
		return prev
	var d := (pts[i + 1] - pts[i]).normalized()
	return prev if d.is_zero_approx() else d


static func _edge_offset(seg: Vector2, prev: Vector2) -> Vector2:
	var length := 1.0
	var bisector := (prev * seg.length() - seg * prev.length()).normalized()
	var s := sin(atan2(bisector.cross(prev), bisector.dot(prev)))
	if not is_zero_approx(s) and not seg.is_equal_approx(prev):
		length = clampf(1.0 / s, -3.0, 3.0)
	else:
		bisector = seg.orthogonal()
	if bisector.is_zero_approx():
		bisector = seg.orthogonal()
	return bisector * length


## A strip's triangles as a list: (k, k+1, k+2) for each k.
func _strip(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	var base := points.size()
	points.append_array(pts)
	colors.append_array(cols)
	for k in pts.size() - 2:
		indices.append_array([base + k, base + k + 1, base + k + 2])


## One draw_primitive quad: triangles (0, 1, 2) and (0, 2, 3).
func _quad(
	a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color
) -> void:
	var base := points.size()
	points.append_array([a, b, c, d])
	colors.append_array([ca, cb, cc, cd])
	indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
