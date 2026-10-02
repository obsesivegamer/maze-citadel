class_name TowerView
extends Node3D
## A tower on the board: its TowerVisuals model, the head turning toward
## SimTower.aim, recoil on `fired`, build / upgrade / sell animations and
## idle effects (Bard aura and notes, Wyrm coil, glows) (GDD §7, §12).

const AIM_RATE := 12.0
const BUILD_TIME := 0.45
const BUILD_DROP := 1.4
const POP_TIME := 0.35
const POP_SCALE := 0.18
const SELL_TIME := 0.4
const RECOIL_TIME := 0.32
const RECOIL_PEAK := 0.12
## Recoil sizes in each moving part's own units (kit parts are ~1 unit).
const BARREL_KICK := 0.14
const ARM_SWING := 1.9
const BOLT_SLIDE := 0.35
const HAMMER_SWING := 1.4
const HEAD_KICK := 0.12
const BARD_RING := Color(1.0, 0.78, 0.3, 0.22)
const BARD_RING_SPIN := 0.25
const COIL_WAVE := 0.14
const COIL_SPEED := 2.4
const GLOW_PULSE := 0.1
const GLOW_SPEED := 3.0

var tile := Vector2i.ZERO
var id: StringName
var level := 1
## Set while the sell animation plays; Units frees the view when it ends.
var removing := false

var _pivot := Node3D.new()
var _model: Node3D
var _head: Node3D
var _recoil: Node3D
var _recoil_kind: StringName
var _recoil_rest := Transform3D.IDENTITY
var _recoil_t := 1.0
var _yaw := 0.0
var _anim := 0.0
var _anim_kind := &""
var _age := 0.0
var _spin: Array = []
var _coil: Array = []
var _glow: Array = []
var _idle: Array[GPUParticles3D] = []
var _ring: MeshInstance3D
var _quality := 1.0


func setup(t: SimTower, quality: float) -> void:
	tile = t.tile
	_quality = quality
	position = Coords.tile_to_world(tile, Coords.PLATEAU_TOP)
	add_child(_pivot)
	_age = randf() * 10.0
	_yaw = atan2(t.aim.x, t.aim.y)
	rebuild(t, &"build")


## Swaps in the model for the tower's current id and level, then plays
## `kind`: build (drop and scale in) or pop (upgrade and fusion).
func rebuild(t: SimTower, kind: StringName) -> void:
	id = t.id
	level = t.level
	if _model:
		_model.queue_free()
	for p in _idle:
		p.queue_free()
	_idle.clear()
	_model = TowerVisuals.build(id, level)
	_pivot.add_child(_model)
	_head = (_model.get_meta("head") if _model.has_meta("head") else null)
	_recoil = (_model.get_meta("recoil") if _model.has_meta("recoil") else null)
	_recoil_kind = _model.get_meta("recoil_kind", &"")
	if _recoil:
		_recoil_rest = _recoil.get_meta("rest", _recoil.transform)
	_recoil_t = 1.0
	_spin = _model.get_meta("spin", [])
	_coil = _model.get_meta("coil", [])
	_glow = _model.get_meta("glow", [])
	for g: Node3D in _glow:
		g.set_meta("base_scale", g.scale)
	var muzzle: float = _model.get_meta("muzzle_height", 2.5)
	for effect: StringName in _model.get_meta("idle", []):
		var p := ParticleKit.make(UnitFx.spec(effect))
		p.position.y = muzzle * UnitFx.IDLE_HEIGHT.get(effect, 1.0)
		ParticleKit.apply_quality(p, _quality)
		_pivot.add_child(p)
		_idle.append(p)
	_update_ring()
	_anim_kind = kind
	_anim = 0.0


func apply_quality(ratio: float) -> void:
	_quality = ratio
	for p in _idle:
		ParticleKit.apply_quality(p, ratio)


func on_fired() -> void:
	_recoil_t = 0.0


func start_sell() -> void:
	removing = true
	_anim_kind = &"sell"
	_anim = 0.0
	for p in _idle:
		p.emitting = false


## `dt` is game-scaled time; returns false once a sold tower has vanished.
func update(t: SimTower, dt: float) -> bool:
	_age += dt
	if t != null and _head:
		_yaw = lerp_angle(_yaw, atan2(t.aim.x, t.aim.y), 1.0 - exp(-AIM_RATE * dt))
		_head.rotation.y = _yaw
	if _recoil_t < 1.0:
		_recoil_t = minf(_recoil_t + dt / RECOIL_TIME, 1.0)
		_apply_recoil(_envelope(_recoil_t))
	for entry in _spin:
		(entry[0] as Node3D).rotation.y += float(entry[1]) * dt
	if not _coil.is_empty():
		_wave_coil()
	var pulse := 1.0 + GLOW_PULSE * sin(_age * GLOW_SPEED)
	for g: Node3D in _glow:
		g.scale = (g.get_meta("base_scale") as Vector3) * pulse
	if _ring:
		_ring.rotation.y += BARD_RING_SPIN * dt
		_ring.transparency = 0.5 + 0.15 * sin(_age * 1.6)
	return _animate(dt)


func _animate(dt: float) -> bool:
	if _anim_kind == &"":
		return true
	_anim += dt
	match _anim_kind:
		&"build":
			var k := clampf(_anim / BUILD_TIME, 0.0, 1.0)
			var s := _ease_out_back(k)
			_pivot.scale = Vector3(s, lerpf(0.4, 1.0, k) * s, s).max(Vector3.ONE * 0.01)
			_pivot.position.y = BUILD_DROP * (1.0 - k) * (1.0 - k)
			if k >= 1.0:
				_finish_anim()
		&"pop":
			var k := clampf(_anim / POP_TIME, 0.0, 1.0)
			_pivot.scale = Vector3.ONE * (1.0 + POP_SCALE * sin(k * PI) * (1.0 - k * 0.5))
			if k >= 1.0:
				_finish_anim()
		&"sell":
			var k := clampf(_anim / SELL_TIME, 0.0, 1.0)
			_pivot.scale = Vector3(1.0 - k * 0.6, 1.0 - k, 1.0 - k * 0.6).max(Vector3.ONE * 0.01)
			_pivot.position.y = -0.6 * k * k
			return k < 1.0
	return true


func _finish_anim() -> void:
	_anim_kind = &""
	_pivot.scale = Vector3.ONE
	_pivot.position = Vector3.ZERO


## Fast kick to the peak, slower settle back (0..1 over the recoil).
static func _envelope(t: float) -> float:
	if t < RECOIL_PEAK:
		return t / RECOIL_PEAK
	var k := 1.0 - (t - RECOIL_PEAK) / (1.0 - RECOIL_PEAK)
	return k * k


static func _ease_out_back(k: float) -> float:
	var c := 1.70158
	var x := k - 1.0
	return 1.0 + (c + 1.0) * x * x * x + c * x * x


func _apply_recoil(e: float) -> void:
	if _recoil == null:
		return
	var xf := _recoil_rest
	match _recoil_kind:
		&"barrel":
			xf.origin -= xf.basis.z.normalized() * BARREL_KICK * e
		&"arm":
			xf.basis = xf.basis * Basis(Vector3.RIGHT, ARM_SWING * e)
		&"bolt":
			_recoil.visible = _recoil_t > RECOIL_PEAK
			xf.origin -= xf.basis.z.normalized() * BOLT_SLIDE * e
		&"swing":
			xf.basis = xf.basis * Basis(Vector3.RIGHT, HAMMER_SWING * e)
		&"kick":
			xf.origin -= Basis(Vector3.UP, _yaw).z * HEAD_KICK * e
	_recoil.transform = xf
	if _recoil == _head:
		_head.rotation.y = _yaw


## The wyrm's segments ripple outward in a wave running up the coil.
func _wave_coil() -> void:
	for seg: Node3D in _coil:
		var base: Vector3 = seg.get_meta("base")
		var t: float = seg.get_meta("t")
		var w := sin(_age * COIL_SPEED - t * TAU * 1.5) * COIL_WAVE
		var out := Vector3(base.x, 0, base.z).normalized()
		seg.position = base + out * w + Vector3(0, w * 0.5, 0)


func _update_ring() -> void:
	if id != &"bard":
		if _ring:
			_ring.queue_free()
			_ring = null
		return
	if _ring == null:
		_ring = MeshInstance3D.new()
		_ring.mesh = UnitMeshes.disc()
		_ring.material_override = UnitStyle.additive(BARD_RING, UnitStyle.ring_texture())
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ring.position.y = 0.07
		add_child(_ring)
	var r: float = TowerDefs.stat(id, "range", level)
	_ring.scale = Vector3(r, 1, r)
