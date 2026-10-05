class_name PathPreview
extends Node3D
## Glowing dots along the current portal-to-gate route, drifting toward the
## gate (GDD §2). Redrawn on every path change; hidden while a wave runs if
## the player prefers (always shown for now). Under rules where towers reach
## only the tiles around them, pale dots also mark the straight line flyers
## take, since only towers beside it can hit them, and a faint red strip with
## an edge line marks the rows by the portal where nothing may be built.

const SPACING := 1.6
const SPEED := 2.4
const MAX_DOTS := 600
const FLIGHT_SPACING := 2.0
const FLIGHT_COLOR := Color(0.6, 0.85, 1.0)
const BAND_COLOR := Color(0.85, 0.12, 0.08, 0.16)
const BAND_EDGE_COLOR := Color(1.0, 0.25, 0.15, 0.55)

var _game: Game
var _mm := MultiMesh.new()
var _points := PackedVector3Array()
var _length := 0.0
var _offset := 0.0


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
	if game.sim.grid.portal_rows > 0:
		_add_portal_band(game.sim.grid.portal_rows * Grid.TILE)


func _add_flight_line() -> void:
	var dot := SphereMesh.new()
	dot.radius = 0.16
	dot.height = 0.32
	dot.radial_segments = 8
	dot.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = FLIGHT_COLOR
	dot.material = mat
	var from := _game.sim.grid.spawn_point
	var to := _game.sim.grid.gate_point
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dot
	mm.instance_count = int(from.distance_to(to) / FLIGHT_SPACING) + 1
	for i in mm.instance_count:
		var p := from.move_toward(to, i * FLIGHT_SPACING)
		mm.set_instance_transform(
			i, Transform3D(Basis(), Coords.to_world(p, Coords.PLATEAU_TOP + 0.3))
		)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _add_portal_band(depth: float) -> void:
	for edge in [false, true]:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = BAND_EDGE_COLOR if edge else BAND_COLOR
		var quad := PlaneMesh.new()
		quad.size = Vector2(Grid.WIDTH, 0.14 if edge else depth)
		quad.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var centre := Vector2(Grid.WIDTH / 2.0, depth if edge else depth / 2.0)
		mi.position = Coords.to_world(centre, Coords.PLATEAU_TOP + (0.06 if edge else 0.04))
		add_child(mi)


func _on_sim_event(e: Dictionary) -> void:
	if e.type == &"path_changed":
		refresh()


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
	Prof.end(&"path")
