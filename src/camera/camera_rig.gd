class_name CameraRig
extends Node3D

signal boss_tracking_changed(on: bool)
## RTS camera (GDD §10): damped orbit, pan and zoom around a ground target.
## Mouse wheel / pinch zoom, WASD / arrows / two-finger trackpad pan,
## middle-drag or Option-drag orbit, Q/E rotate. Presets: full board (R),
## portal, gate; C cycles them, B follows the boss.

const PRESETS := {
	## Fits portal arch to gate front between the HUD bars (16:10 window).
	&"full": {"target": Vector3(0, 0, 4), "yaw": 0.0, "pitch": 58.0, "distance": 106.0},
	&"portal": {"target": Vector3(0, 2, -27), "yaw": -18.0, "pitch": 38.0, "distance": 30.0},
	&"gate": {"target": Vector3(0, 2, 26), "yaw": 160.0, "pitch": 36.0, "distance": 30.0},
}
const PRESET_ORDER: Array[StringName] = [&"full", &"portal", &"gate"]
const MIN_DISTANCE := 14.0
const MAX_DISTANCE := 130.0
const MIN_PITCH := 22.0
const MAX_PITCH := 82.0
const DAMPING := 9.0
const PAN_SPEED := 0.9
const ORBIT_SPEED := 0.25
const ROTATE_SPEED := 70.0
const BOUNDS := Vector2(40.0, 48.0)

var camera := Camera3D.new()
var boss_tracking := false

var _game: Game
var _target := Vector3.ZERO
var _yaw := 0.0
var _pitch := 58.0
var _distance := 106.0
var _cur_target := Vector3.ZERO
var _cur_yaw := 0.0
var _cur_pitch := 56.0
var _cur_distance := 78.0
var _shake := 0.0
var _preset_index := 0
var _orbiting := false


func setup(game: Game) -> void:
	_game = game
	camera.fov = 40.0
	camera.near = 0.3
	camera.far = 600.0
	add_child(camera)
	camera.make_current()
	preset(&"full", true)


func preset(preset_name: StringName, snap := false) -> void:
	var p: Dictionary = PRESETS[preset_name]
	_target = p.target
	# The portal and gate views follow the map's portal and gate.
	match preset_name:
		&"portal":
			_target.x += Coords.portal().x
		&"gate":
			_target.x += Coords.gate().x
	_yaw = p.yaw
	_pitch = p.pitch
	_distance = p.distance
	_preset_index = PRESET_ORDER.find(preset_name)
	if snap:
		_cur_target = _target
		_cur_yaw = _yaw
		_cur_pitch = _pitch
		_cur_distance = _distance
		_apply()


## Fx decides when to shake; the rig only renders it, unless the player turned
## shake off in settings.
func add_shake(amount: float) -> void:
	if Save.setting("camera_shake", true):
		_shake = minf(_shake + amount, 1.5)


func set_boss_tracking(on: bool) -> void:
	if on != boss_tracking:
		boss_tracking = on
		boss_tracking_changed.emit(on)


## The point on the plateau under a screen position, or null when the ray
## points at the sky.
func screen_to_ground(screen_pos: Vector2) -> Variant:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	return Plane(Vector3.UP, Coords.PLATEAU_TOP).intersects_ray(origin, dir)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_distance *= 0.9
			MOUSE_BUTTON_WHEEL_DOWN:
				_distance *= 1.1
			MOUSE_BUTTON_MIDDLE:
				_orbiting = mb.pressed
			MOUSE_BUTTON_LEFT:
				_orbiting = mb.pressed and mb.alt_pressed
	elif event is InputEventMouseMotion and _orbiting:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * ORBIT_SPEED
		_pitch += mm.relative.y * ORBIT_SPEED
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		_pan((event as InputEventPanGesture).delta * PAN_SPEED * _distance * 0.02)
	elif event is InputEventMagnifyGesture:
		_distance /= (event as InputEventMagnifyGesture).factor
	elif event.is_action_pressed(&"hero_view"):
		set_boss_tracking(false)
		preset(&"full")
	elif event.is_action_pressed(&"camera_preset"):
		set_boss_tracking(false)
		preset(PRESET_ORDER[(_preset_index + 1) % PRESET_ORDER.size()])
	elif event.is_action_pressed(&"boss_track"):
		set_boss_tracking(not boss_tracking)
	_distance = clampf(_distance, MIN_DISTANCE, MAX_DISTANCE)
	_pitch = clampf(_pitch, MIN_PITCH, MAX_PITCH)


func _pan(screen_delta: Vector2) -> void:
	var right := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(_yaw))
	var forward := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(_yaw))
	_target += right * screen_delta.x - forward * screen_delta.y
	_target.x = clampf(_target.x, -BOUNDS.x, BOUNDS.x)
	_target.z = clampf(_target.z, -BOUNDS.y, BOUNDS.y)


func _process(delta: float) -> void:
	var move := Input.get_vector(&"cam_left", &"cam_right", &"cam_back", &"cam_forward")
	if move != Vector2.ZERO:
		_pan(Vector2(move.x, -move.y) * delta * _distance * 0.9)
	var rot := Input.get_axis(&"cam_rotate_left", &"cam_rotate_right")
	_yaw += rot * ROTATE_SPEED * delta
	if boss_tracking:
		var boss: Variant = _boss_position()
		if boss != null:
			_target = boss
	var k := 1.0 - exp(-DAMPING * delta)
	_cur_target = _cur_target.lerp(_target, k)
	_cur_yaw = lerpf(_cur_yaw, _yaw, k)
	_cur_pitch = lerpf(_cur_pitch, _pitch, k)
	_cur_distance = lerpf(_cur_distance, _distance, k)
	_shake = maxf(_shake - delta * 2.5, 0.0)
	_apply()


func _boss_position() -> Variant:
	for c in _game.sim.creeps:
		if c.boss and c.alive:
			return Coords.to_world(c.prev_pos.lerp(c.pos, _game.alpha()))
	return null


func _apply() -> void:
	var offset := Vector3(0, 0, _cur_distance)
	offset = offset.rotated(Vector3.RIGHT, -deg_to_rad(_cur_pitch))
	offset = offset.rotated(Vector3.UP, deg_to_rad(_cur_yaw))
	var jitter := Vector3.ZERO
	if _shake > 0.0:
		var t := Time.get_ticks_msec() * 0.05
		jitter = Vector3(sin(t * 1.7), sin(t * 2.3), cos(t * 1.9)) * _shake * _shake * 0.6
	camera.global_position = _cur_target + offset + jitter
	camera.look_at(_cur_target + jitter * 0.5, Vector3.UP)
