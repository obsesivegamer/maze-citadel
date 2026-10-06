class_name PathPreview
extends Node3D
## Glowing dots along the current portal-to-gate route, drifting toward the
## gate (GDD §2). Redrawn on every path change; hidden while a wave runs if
## the player prefers (always shown for now). Under rules where towers reach
## only the tiles around them, the straight line flyers take is drawn too
## (GDD §10), since only towers beside it can hit them: a strip on the
## ground under arrows that drift toward the gate at flying height, bright
## while the next or the running wave has flyers and flashing once when one
## leaks. While a wing-icon tower is chosen to build, the tiles that reach
## the line are tinted (AirCover).

const SPACING := 1.6
const SPEED := 2.4
const MAX_DOTS := 600
const FLIGHT_COLOR := Color(0.6, 0.85, 1.0)
## Metres above the plateau the arrows fly at: a Harpy's hover height.
const FLIGHT_LIFT := 4.3
const ARROW_SPACING := 3.0
## A Harpy's speed, so the arrows move as flyers do.
const ARROW_SPEED := 3.4
## Alpha of the arrows, the ground strip and the tinted tiles: dim, lit.
const ARROW_ALPHA := Vector2(0.3, 0.85)
const STRIP_ALPHA := Vector2(0.18, 0.45)
const TILE_ALPHA := 0.26
## Seconds a leak's flash takes, and how much brighter it peaks.
const FLASH_TIME := 1.6
const FLASH_GAIN := 1.4

var _game: Game
var _mm := MultiMesh.new()
var _points := PackedVector3Array()
var _length := 0.0
var _offset := 0.0
var _arrows: MultiMesh
var _arrow_mat: StandardMaterial3D
var _strip_mat: StandardMaterial3D
var _tiles: MultiMeshInstance3D
var _tile_mat: StandardMaterial3D
var _flight_from := Vector3.ZERO
var _flight_dir := Vector3.ZERO
var _flight_length := 0.0
var _arrow_offset := 0.0
var _lit := false
var _flash := 0.0


func setup(game: Game) -> void:
	_game = game
	var dot := SphereMesh.new()
	dot.radius = 0.24
	dot.height = 0.48
	dot.radial_segments = 8
	dot.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.3)
	mat.emission_energy_multiplier = 2.0
	dot.material = mat
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = dot
	_mm.instance_count = MAX_DOTS
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	game.sim_event.connect(_on_sim_event)
	refresh()
	if game.sim.adjacent_reach():
		_add_flight_line()


func _add_flight_line() -> void:
	var grid := _game.sim.grid
	_flight_from = Coords.to_world(grid.spawn_point, Coords.PLATEAU_TOP + FLIGHT_LIFT)
	var to := Coords.to_world(grid.gate_point, Coords.PLATEAU_TOP + FLIGHT_LIFT)
	_flight_length = _flight_from.distance_to(to)
	_flight_dir = (to - _flight_from) / _flight_length
	_arrow_mat = _flat_material(FLIGHT_COLOR)
	var arrow := PrismMesh.new()
	arrow.size = Vector3(1.1, 0.8, 0.08)
	arrow.material = _arrow_mat
	_arrows = MultiMesh.new()
	_arrows.transform_format = MultiMesh.TRANSFORM_3D
	_arrows.mesh = arrow
	_arrows.instance_count = ceili(_flight_length / ARROW_SPACING)
	_add_multimesh(_arrows)
	_strip_mat = _flat_material(FLIGHT_COLOR)
	var strip := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.04, _flight_length)
	strip.mesh = box
	strip.material_override = _strip_mat
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ground := Vector3(0, FLIGHT_LIFT - 0.08, 0)
	strip.transform = Transform3D(Basis.looking_at(_flight_dir), (_flight_from + to) / 2.0 - ground)
	add_child(strip)
	_tile_mat = _flat_material(Color(FLIGHT_COLOR, TILE_ALPHA))
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (Grid.TILE - 0.2)
	plane.material = _tile_mat
	var tiles := MultiMesh.new()
	tiles.transform_format = MultiMesh.TRANSFORM_3D
	tiles.mesh = plane
	var reach := AirCover.reach_tiles(grid)
	tiles.instance_count = reach.size()
	for i in reach.size():
		var at := Coords.tile_to_world(reach[i], Coords.PLATEAU_TOP + 0.05)
		tiles.set_instance_transform(i, Transform3D(Basis(), at))
	_tiles = _add_multimesh(tiles)
	_game.build_choice_changed.connect(_on_build_choice)
	_on_build_choice(_game.build_choice)
	_set_lit(AirCover.lane_lit(_game.sim))


static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	return mat


func _add_multimesh(mm: MultiMesh) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _on_build_choice(id: StringName) -> void:
	_tiles.visible = AirCover.tints_for(id) or _flash > 0.0


func _set_lit(lit: bool) -> void:
	_lit = lit
	_tint_lane(1.0)


## The lane's alphas, `gain` times brighter (a leak's flash).
func _tint_lane(gain: float) -> void:
	var k := 1 if _lit else 0
	_arrow_mat.albedo_color.a = minf(ARROW_ALPHA[k] * gain, 1.0)
	_strip_mat.albedo_color.a = minf(STRIP_ALPHA[k] * gain, 1.0)
	_tile_mat.albedo_color.a = minf(TILE_ALPHA * gain, 1.0)


func _on_sim_event(e: Dictionary) -> void:
	if e.type == &"path_changed":
		refresh()
	elif _arrows == null:
		return
	elif e.type == &"wave_started" or e.type == &"wave_cleared":
		_set_lit(AirCover.lane_lit(_game.sim))
	elif AirCover.air_leak(e) and _flash <= 0.0:
		_flash = FLASH_TIME
		_tiles.visible = true


func refresh() -> void:
	_points.clear()
	for p in _game.sim.field.route():
		_points.append(Coords.to_world(p, Coords.PLATEAU_TOP + 0.25))
	_length = 0.0
	for i in range(1, _points.size()):
		_length += _points[i - 1].distance_to(_points[i])


func _process(delta: float) -> void:
	Prof.begin(&"path")
	_offset = fmod(_offset + delta * SPEED, SPACING)
	var count := mini(int(_length / SPACING), MAX_DOTS)
	_mm.visible_instance_count = count
	var seg := 0
	var seg_start := 0.0
	for i in count:
		var d := _offset + i * SPACING
		while (
			seg < _points.size() - 2 and d > seg_start + _points[seg].distance_to(_points[seg + 1])
		):
			seg_start += _points[seg].distance_to(_points[seg + 1])
			seg += 1
		var seg_len := maxf(_points[seg].distance_to(_points[seg + 1]), 0.001)
		var p := _points[seg].lerp(_points[seg + 1], clampf((d - seg_start) / seg_len, 0.0, 1.0))
		var pulse := 0.6 + 0.4 * sin(d * 0.8 - Time.get_ticks_msec() * 0.004)
		_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * pulse), p))
	if _arrows != null:
		_move_arrows(delta)
	Prof.end(&"path")


func _move_arrows(delta: float) -> void:
	_arrow_offset = fmod(_arrow_offset + delta * ARROW_SPEED, ARROW_SPACING)
	var side := _flight_dir.cross(Vector3.UP)
	var size := 1.0 if _lit else 0.75
	var basis := Basis(side, _flight_dir, Vector3.UP).scaled(Vector3.ONE * size)
	for i in _arrows.instance_count:
		var d := fmod(_arrow_offset + i * ARROW_SPACING, _flight_length)
		_arrows.set_instance_transform(i, Transform3D(basis, _flight_from + _flight_dir * d))
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		_tint_lane(1.0 + FLASH_GAIN * sin(PI * (1.0 - _flash / FLASH_TIME)))
		if _flash == 0.0:
			_on_build_choice(_game.build_choice)
