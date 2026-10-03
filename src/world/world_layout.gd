class_name WorldLayout
extends RefCounted
## The map around the plateau in one place: heights, river, roads, village
## plots, fields and keep-out zones (GDD §1). World space: x east, z south
## (gate side), y up; the plateau's centre is the origin. Every builder reads
## from here so trees never grow in the river and sheep stay in their field.
##
## The default camera (78 m, pitch 56°) sees roughly x ±45 m around the
## plateau, so the watermill sits on the west flank and the farms on the east
## flank; the main village lies south of the river, in the gate close-up.

const LOWLAND_Y := -2.4
## Plateau footprint (x, z), wider than the 40 × 56 m grid so walls fit on
## the rim and the portal and gate have aprons.
const PLATEAU_MIN := Vector2(-24.0, -37.0)
const PLATEAU_MAX := Vector2(24.0, 35.0)
const PLATEAU_CORNER := 4.0
## How far the cliff skirt flares out from the rim to its foot.
const CLIFF_RUN := 3.2

const RAMP_HALF_WIDTH := 3.6
const RAMP_END_Z := 47.0

const WATER_Y := LOWLAND_Y - 0.55
const RIVER_BED_Y := LOWLAND_Y - 1.8
const RIVER_HALF_WIDTH := 4.6
const RIVER_BANK := 3.0
const RIVER_CONTROL := [
	Vector2(-70, -260),
	Vector2(-58, -150),
	Vector2(-47, -80),
	Vector2(-42, -35),
	Vector2(-43, 0),
	Vector2(-41, 28),
	Vector2(-33, 46),
	Vector2(-16, 57),
	Vector2(0, 60),
	Vector2(16, 59),
	Vector2(36, 64),
	Vector2(62, 76),
	Vector2(110, 86),
	Vector2(260, 104),
]
const BRIDGE := Vector2(0, 60)
const BRIDGE_LENGTH := 14.0

const ROAD_HALF_WIDTH := 2.4
const ROADS := [
	# Gate ramp foot → bridge → village → south.
	[
		Vector2(0, 40),
		Vector2(0, 50),
		Vector2(0, 70),
		Vector2(1, 84),
		Vector2(-3, 104),
		Vector2(-10, 150),
		Vector2(-18, 260),
	],
	# East farm lane, north of the river.
	[
		Vector2(0, 49),
		Vector2(14, 49),
		Vector2(26, 45),
		Vector2(31, 34),
		Vector2(31, 14),
		Vector2(33, -8),
		Vector2(37, -36),
		Vector2(44, -80),
	],
	# West path to the watermill.
	[
		Vector2(0, 49),
		Vector2(-14, 47),
		Vector2(-26, 40),
		Vector2(-31, 26),
		Vector2(-32, 12),
	],
	# Village loop lane.
	[
		Vector2(1, 84),
		Vector2(-16, 80),
		Vector2(-24, 90),
	],
]

## Village buildings: [model key, position, yaw degrees, scale].
const BUILDINGS := [
	[&"tavern", Vector2(-11, 72), 20.0, 5.0],
	[&"home_a", Vector2(10, 71), -30.0, 5.0],
	[&"home_b", Vector2(-9, 92), 150.0, 5.0],
	[&"church", Vector2(15, 92), -160.0, 5.0],
	[&"home_a", Vector2(-24, 74), 70.0, 4.6],
	[&"home_b", Vector2(22, 80), -80.0, 4.8],
	[&"lumbermill", Vector2(-27, 96), 120.0, 4.6],
	[&"home_a", Vector2(7, 104), 200.0, 4.6],
	[&"market", Vector2(-6, 84), 10.0, 4.4],
	# East farmstead (visible at the right of the default frame).
	[&"home_b", Vector2(37.5, 24), -95.0, 4.6],
	[&"home_a", Vector2(37.5, 10), -80.0, 4.4],
	[&"barracks", Vector2(48, 25), -120.0, 4.4],
]
const WELL := Vector2(5, 80)
const WATERMILL := Vector2(-37.6, 13.0)
const WINDMILL := Vector2(38.5, -2.0)
const STALLS := [
	[Vector2(-1.5, 76), 90.0],
	[Vector2(9, 86), -100.0],
]
## Fenced sheep pastures and crop fields as Rect2(x, z, width, depth).
const PASTURES := [Rect2(38, -34, 16, 24), Rect2(14, 108, 18, 14)]
const FIELDS := [Rect2(43, 3, 11, 22), Rect2(-36, 102, 16, 12), Rect2(-41, 66, 10, 9)]
## Peasant walking loops (closed).
const WALKS := [
	[Vector2(-2, 74), Vector2(6, 76), Vector2(8, 84), Vector2(-2, 88), Vector2(-8, 80)],
	[Vector2(-14, 66), Vector2(2, 66), Vector2(3, 96), Vector2(-14, 98), Vector2(-20, 84)],
	[Vector2(31, 32), Vector2(31, 14), Vector2(33, -6), Vector2(34, 4), Vector2(33.5, 24)],
	[Vector2(-30, 26), Vector2(-32, 10), Vector2(-33, 18)],
	[Vector2(33.5, -9), Vector2(36.5, -33), Vector2(35, -30), Vector2(33, -14)],
]
const VILLAGE_CENTER := Vector2(0, 80)
## Corrupted ground around the portal (blight_center()): dead trees, red
## rocks, no pines.
const BLIGHT_Z := -44.0
const BLIGHT_RADIUS := 17.0

const ROLL_AMP := 0.7
const HILL_START := 150.0
const HILL_END := 300.0
const HILL_HEIGHT := 34.0

static var _river: WorldPath
static var _roads: Array[WorldPath] = []
static var _roads_map: StringName = &""
static var _noise: FastNoiseLite
static var _hill_noise: FastNoiseLite


static func river() -> WorldPath:
	if _river == null:
		_river = WorldPath.new(PackedVector2Array(RIVER_CONTROL), 2.0, 16.0)
	return _river


## The main road starts at the foot of the gate ramp; on a map whose gate is
## off-centre it bends back to the bridge before the river.
static func roads() -> Array[WorldPath]:
	if _roads_map != Coords.map:
		_roads_map = Coords.map
		_roads.clear()
		for i in ROADS.size():
			var pts := PackedVector2Array(ROADS[i])
			var gx := gate_x()
			if i == 0 and gx != 0.0:
				pts = PackedVector2Array([Vector2(gx, 40), Vector2(gx, 47), Vector2(0, 54)])
				pts.append_array(PackedVector2Array(ROADS[0].slice(2)))
			_roads.append(WorldPath.new(pts, 2.0, 10.0))
	return _roads


## World x of the gate (and its ramp) and of the portal on the current map.
static func gate_x() -> float:
	return Coords.gate().x


static func blight_center() -> Vector2:
	return Vector2(Coords.portal().x, BLIGHT_Z)


static func _ensure_noise() -> void:
	if _noise != null:
		return
	_noise = FastNoiseLite.new()
	_noise.seed = 11
	_noise.frequency = 0.018
	_noise.fractal_octaves = 3
	_hill_noise = FastNoiseLite.new()
	_hill_noise.seed = 5
	_hill_noise.frequency = 0.008


## Signed distance from `p` to the plateau footprint (negative inside).
static func plateau_sdf(p: Vector2) -> float:
	var c := (PLATEAU_MIN + PLATEAU_MAX) * 0.5
	var half := (PLATEAU_MAX - PLATEAU_MIN) * 0.5 - Vector2.ONE * PLATEAU_CORNER
	var q := (p - c).abs() - half
	return q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0) - PLATEAU_CORNER


static func road_distance(p: Vector2) -> float:
	var best := 1e6
	for r in roads():
		best = minf(best, r.distance_to(p))
	return best


## Lowland ground height (the plateau and ramp are separate meshes on top).
static func ground_y(x: float, z: float) -> float:
	_ensure_noise()
	var p := Vector2(x, z)
	var near := clampf((plateau_sdf(p) - CLIFF_RUN) / 14.0, 0.0, 1.0)
	var h := LOWLAND_Y + _noise.get_noise_2d(x, z) * ROLL_AMP * near
	var r := p.length()
	if r > HILL_START:
		var k := smoothstep(HILL_START, HILL_END, r)
		h += k * k * HILL_HEIGHT * (0.55 + 0.45 * _hill_noise.get_noise_2d(x, z))
	var d := river().distance_to(p)
	if d < RIVER_HALF_WIDTH + RIVER_BANK:
		var bank := smoothstep(RIVER_HALF_WIDTH * 0.55, RIVER_HALF_WIDTH + RIVER_BANK, d)
		h = lerpf(RIVER_BED_Y, h, bank)
	return h


static func ground_point(p: Vector2) -> Vector3:
	return Vector3(p.x, ground_y(p.x, p.y), p.y)


static func in_rects(p: Vector2, rects: Array, margin: float) -> bool:
	for r: Rect2 in rects:
		if r.grow(margin).has_point(p):
			return true
	return false


## True where scenery may stand: off the plateau and cliffs, out of the river,
## roads, buildings, fields and pastures. `margin` is the prop's radius.
static func is_open(p: Vector2, margin: float) -> bool:
	if plateau_sdf(p) < CLIFF_RUN + margin:
		return false
	var ramp := absf(p.x - gate_x()) < RAMP_HALF_WIDTH + 2.0 + margin
	if ramp and p.y > PLATEAU_MAX.y and p.y < RAMP_END_Z:
		return false
	if river().distance_to(p) < RIVER_HALF_WIDTH + 1.0 + margin:
		return false
	if road_distance(p) < ROAD_HALF_WIDTH + 0.6 + margin:
		return false
	if in_rects(p, PASTURES, margin + 1.0) or in_rects(p, FIELDS, margin + 1.0):
		return false
	for b in BUILDINGS:
		if p.distance_to(b[1]) < b[3] * 0.75 + margin:
			return false
	for q: Vector2 in [WELL, WATERMILL, WINDMILL, BRIDGE]:
		if p.distance_to(q) < 6.0 + margin:
			return false
	for s in STALLS:
		if p.distance_to(s[0]) < 3.0 + margin:
			return false
	return true
