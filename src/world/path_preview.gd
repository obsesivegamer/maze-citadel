class_name PathPreview
extends Node3D
## Glowing dots along the current portal-to-gate route, drifting toward the
## gate (GDD §2). Redrawn on every path change; hidden while a wave runs if
## the player prefers (always shown for now).

const SPACING := 1.6
const SPEED := 2.4
const MAX_DOTS := 600

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
