class_name WorldPath
extends RefCounted
## A smoothed polyline on the ground plane (river, road) with fast distance
## queries. Segments are bucketed into a coarse hash so terrain generation can
## ask "how far from the river is this vertex?" thousands of times cheaply.

const CELL := 16.0

var points := PackedVector2Array()
## Arc length at each point.
var lengths := PackedFloat32Array()
var length := 0.0

var _reach := 0.0
var _cells := {}


## `control` points are smoothed with Catmull-Rom into roughly `step` metre
## segments. `reach` is the largest distance distance_to() needs to be exact
## for; beyond it the result is just "far".
func _init(control: PackedVector2Array, step: float, reach: float) -> void:
	_reach = reach
	for i in control.size() - 1:
		var p0 := control[maxi(i - 1, 0)]
		var p1 := control[i]
		var p2 := control[i + 1]
		var p3 := control[mini(i + 2, control.size() - 1)]
		var n := maxi(1, ceili(p1.distance_to(p2) / step))
		for k in n:
			var t := float(k) / n
			points.append(_catmull(p0, p1, p2, p3, t))
	points.append(control[control.size() - 1])
	lengths.resize(points.size())
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])
		lengths[i] = length
	for i in points.size() - 1:
		var lo := points[i].min(points[i + 1]) - Vector2(reach, reach)
		var hi := points[i].max(points[i + 1]) + Vector2(reach, reach)
		for cx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
			for cz in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
				var key := Vector2i(cx, cz)
				if not _cells.has(key):
					_cells[key] = PackedInt32Array()
				_cells[key].append(i)


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return (
		0.5
		* (
			2.0 * p1
			+ (p2 - p0) * t
			+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
			+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3
		)
	)


## Distance from `p` to the path, or a large number past `reach`.
func distance_to(p: Vector2) -> float:
	var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	if not _cells.has(key):
		return 1e6
	var best := 1e6
	for i in _cells[key]:
		var a := points[i]
		var ab := points[i + 1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## Point at arc length `s` (clamped).
func sample(s: float) -> Vector2:
	s = clampf(s, 0.0, length)
	var i := lengths.bsearch(s)
	if i <= 0:
		return points[0]
	var seg := lengths[i] - lengths[i - 1]
	return points[i - 1].lerp(points[i], (s - lengths[i - 1]) / maxf(seg, 1e-6))


## Unit direction of travel at arc length `s`.
func tangent(s: float) -> Vector2:
	var a := sample(s - 0.5)
	var b := sample(s + 0.5)
	return (b - a).normalized()
