class_name ProjectileViews
extends Node3D
## Shots in flight (GDD §12): arrow tracers, ballista bolt streaks, cannon
## shells, demolisher boulders and Doom shells on arcs with trails, frost
## bolts, plague lobs, spinning rune hammers, the Sunfire lance and the
## Necropolis's plague orbs. Each frame places every
## pooled visual from its SimProjectile (homing, shell or bolt timing).

const TD := TowerVisuals.TD
## Per tower id. mesh: arrow | cannonball | boulder | crystal | orb | hammer
## streak: tracer size (width, width, length) · arc: shell height factor
## lob: extra hump for homing shots · spin: radians per second
const LOOKS := {
	&"archer":
	{"mesh": "arrow", "scale": 1.6, "streak": Vector3(0.1, 0.1, 1.8), "tint": Color(1, 0.88, 0.6)},
	&"ballista":
	{
		"mesh": "arrow",
		"scale": 2.8,
		"streak": Vector3(0.24, 0.24, 3.8),
		"tint": Color(0.75, 0.9, 1)
	},
	&"cannon": {"mesh": "cannonball", "scale": 1.7, "trail": &"smoke_trail", "arc": 1.0},
	&"demolisher":
	{"mesh": "boulder", "scale": 2.4, "trail": &"dust_trail", "arc": 1.5, "spin": 9.0},
	&"doom_cannon":
	{
		"mesh": "cannonball",
		"scale": 3.0,
		"glow": Color(1, 0.45, 0.1),
		"trail": &"fire_trail",
		"arc": 1.4
	},
	&"frost":
	{
		"mesh": "crystal",
		"scale": 0.45,
		"glow": Color(0.55, 0.9, 1),
		"trail": &"frost_trail",
		"spin": 8.0,
		"streak": Vector3(0.3, 0.3, 1.2),
		"tint": Color(0.5, 0.85, 1),
	},
	&"plague":
	{"mesh": "orb", "scale": 0.5, "glow": Color(0.4, 1, 0.2), "trail": &"plague_trail", "lob": 1.8},
	&"plague_necropolis":
	{
		"mesh": "orb",
		"scale": 0.8,
		"glow": Color(0.62, 0.3, 1),
		"trail": &"plague_trail",
		"lob": 2.2
	},
	&"sunfire_ballista":
	{
		"mesh": "arrow",
		"scale": 3.4,
		"glow": Color(1, 0.8, 0.35),
		"trail": &"sun_trail",
		"streak": Vector3(0.4, 0.4, 6.0),
		"tint": Color(1, 0.85, 0.4),
	},
	&"runesmith":
	{"mesh": "hammer", "scale": 0.8, "trail": &"rune_trail", "spin": 14.0, "lob": 0.6},
}
## Shell arc height: metres per metre of range, clamped.
const ARC_PER_M := 0.32
const ARC_MIN := 2.0
const ARC_MAX := 7.5
const BOLT_HEIGHT := 1.1
## Flip if the arrow model turns out to fly tail-first.
const ARROW_FLIP := false
## Seconds a released shot keeps its trail before it can be reused.
const TRAIL_LINGER := 0.9

static var _orb: SphereMesh

var _game: Game
var _quality := 1.0
var _frame := 0
var _active := {}
var _free := {}
var _cooling: Array[Flight] = []
var _gone: Array = []


class Flight:
	extends RefCounted
	var look: StringName
	var node := Node3D.new()
	var body: MeshInstance3D
	var streak: MeshInstance3D
	var trail: GPUParticles3D
	var spin := 0.0
	var stamp := 0
	var muzzle := 3.0
	var dist0 := 1.0
	var height := 3.0
	var fresh := true
	var linger := 0.0


func setup(game: Game) -> void:
	_game = game


func apply_quality(ratio: float) -> void:
	_quality = ratio
	for look in _free:
		for s: Flight in _free[look]:
			if s.trail:
				ParticleKit.apply_quality(s.trail, ratio)
	for p in _active:
		var s: Flight = _active[p]
		if s.trail:
			ParticleKit.apply_quality(s.trail, ratio)


func sync(alpha: float, dt: float) -> void:
	_frame += 1
	for p in _game.sim.projectiles:
		var s: Flight = _active.get(p)
		if s == null:
			s = _acquire(_look_for(p))
			_start(s, p)
			_active[p] = s
		s.stamp = _frame
		_place(s, p, alpha, dt)
	_gone.clear()
	for p in _active:
		if (_active[p] as Flight).stamp != _frame:
			_gone.append(p)
	for p in _gone:
		_release(_active[p])
		_active.erase(p)
	for i in range(_cooling.size() - 1, -1, -1):
		var s := _cooling[i]
		s.linger -= dt
		if s.linger <= 0.0:
			s.node.visible = false
			(_free[s.look] as Array).append(s)
			_cooling.remove_at(i)


static func _look_for(p: SimProjectile) -> StringName:
	var id: StringName = p.tower.id if p.tower else &"archer"
	return id if LOOKS.has(id) else &"archer"


func _acquire(look: StringName) -> Flight:
	var pool: Array = _free.get(look, [])
	_free[look] = pool
	if not pool.is_empty():
		return pool.pop_back()
	var spec: Dictionary = LOOKS[look]
	var s := Flight.new()
	s.look = look
	s.spin = spec.get("spin", 0.0)
	add_child(s.node)
	s.body = MeshInstance3D.new()
	s.body.mesh = _mesh(spec.mesh)
	s.body.scale = Vector3.ONE * float(spec.scale)
	if spec.mesh == "arrow" and ARROW_FLIP:
		s.body.rotation.y = PI
	if spec.has("glow"):
		s.body.material_override = UnitStyle.glow(spec.glow, 3.0)
	s.body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.node.add_child(s.body)
	if spec.has("streak"):
		s.streak = MeshInstance3D.new()
		s.streak.mesh = UnitMeshes.streak()
		s.streak.scale = spec.streak
		s.streak.material_override = UnitStyle.additive(
			spec.get("tint", Color.WHITE) * 1.6, UnitMeshes.streak_texture()
		)
		s.streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.node.add_child(s.streak)
	if spec.has("trail"):
		s.trail = ParticleKit.make(UnitFx.spec(spec.trail))
		s.trail.interpolate = false
		s.trail.fixed_fps = 0
		s.trail.emitting = false
		ParticleKit.apply_quality(s.trail, _quality)
		s.node.add_child(s.trail)
	return s


func _start(s: Flight, p: SimProjectile) -> void:
	s.muzzle = TowerVisuals.muzzle_height(p.tower.id, p.level) if p.tower else 3.0
	s.height = s.muzzle
	s.fresh = true
	s.node.visible = true
	s.body.visible = true
	if s.streak:
		s.streak.visible = true
	var c := _game.sim.creep(p.target_id)
	s.dist0 = maxf(p.start.distance_to(c.pos if c else p.pos), 0.5)


func _release(s: Flight) -> void:
	s.body.visible = false
	if s.streak:
		s.streak.visible = false
	if s.trail:
		s.trail.emitting = false
		s.linger = TRAIL_LINGER
	else:
		s.linger = 0.0
	_cooling.append(s)


func _place(s: Flight, p: SimProjectile, alpha: float, dt: float) -> void:
	var spec: Dictionary = LOOKS[s.look]
	var flat := p.pos
	match p.kind:
		&"shell":
			var left := maxf(p.time_left - GameSim.DT * alpha, 0.0)
			var k := 1.0 - left / maxf(p.flight_time, 0.001)
			flat = p.start.lerp(p.target_point, k)
			var arc := clampf(p.start.distance_to(p.target_point) * ARC_PER_M, ARC_MIN, ARC_MAX)
			s.height = (
				lerpf(s.muzzle, 0.2, k) + arc * float(spec.get("arc", 1.0)) * 4.0 * k * (1.0 - k)
			)
		&"bolt":
			flat = p.pos + p.direction * p.speed * GameSim.DT * alpha
			s.height = lerpf(s.muzzle, BOLT_HEIGHT, clampf(p.travelled / 4.0, 0.0, 1.0))
		_:
			var c := _game.sim.creep(p.target_id)
			if c != null:
				var target := c.prev_pos.lerp(c.pos, alpha)
				flat = p.pos + (target - p.pos).limit_length(p.speed * GameSim.DT * alpha)
				var k := 1.0 - clampf(flat.distance_to(target) / s.dist0, 0.0, 1.0)
				var spec_c := CreepModels.spec(c.type)
				var aim_h: float = spec_c.height * 0.55 + float(spec_c.get("fly", 0.0))
				var lob: float = spec.get("lob", 0.0)
				s.height = lerpf(s.muzzle, aim_h, k) + lob * 4.0 * k * (1.0 - k)
	var world := Coords.to_world(flat, Coords.PLATEAU_TOP + s.height)
	var vel := world - s.node.position
	if s.fresh:
		vel = world - Coords.to_world(p.start, Coords.PLATEAU_TOP + s.muzzle)
	s.node.position = world
	if vel.length_squared() > 1e-6:
		var dir := vel.normalized()
		var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.BACK
		s.node.basis = Basis.looking_at(dir, up, true)
	if s.fresh:
		s.fresh = false
		if s.trail:
			s.trail.restart()
	if s.spin != 0.0:
		s.body.rotate_object_local(Vector3.RIGHT, s.spin * dt)


static func _mesh(kind: String) -> Mesh:
	match kind:
		"arrow":
			return TowerVisuals.part_meshes(TD + "weapon-ammo-arrow.glb")[0][0]
		"cannonball":
			return TowerVisuals.part_meshes(TD + "weapon-ammo-cannonball.glb")[0][0]
		"boulder":
			return TowerVisuals.part_meshes(TD + "weapon-ammo-boulder.glb")[0][0]
		"crystal":
			return UnitMeshes.crystal(0.0)
		"hammer":
			return UnitMeshes.hammer()
	if _orb == null:
		_orb = SphereMesh.new()
		_orb.radius = 0.5
		_orb.height = 1.0
		_orb.radial_segments = 12
		_orb.rings = 6
	return _orb
