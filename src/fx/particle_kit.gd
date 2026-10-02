class_name ParticleKit
extends RefCounted
## Builds GPUParticles3D emitters from small spec dictionaries, sharing one
## process material and one draw mesh per spec `key`. Used by Fx (bursts,
## zones) and Units (trails, steam, notes). Keys a spec understands:
##
## amount, lifetime, one_shot, explosive, randomness, local
## shape: point | sphere | ring | box; radius, inner, box (Vector3), height
## dir, spread (degrees), vel (min, max), gravity, damping (min, max)
## radial (min, max), tangential (min, max), spin (deg/s min, max)
## scale (min, max), grow: scale curve rises (puffs) instead of shrinking
## color, colors (Gradient over life; default fades alpha out), hue (variation)
## add (additive blend), tex, size (quad metres), mesh (instead of a quad),
## mat (material for `mesh`), energy (HDR brightness for additive quads)

static var _process := {}
static var _draw := {}


static func make(spec: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(int(spec.get("amount", 16)), 1)
	p.lifetime = spec.get("lifetime", 1.0)
	p.one_shot = spec.get("one_shot", false)
	p.explosiveness = spec.get("explosive", 1.0 if p.one_shot else 0.0)
	p.randomness = spec.get("randomness", 0.3)
	p.local_coords = spec.get("local", false)
	p.emitting = not p.one_shot
	p.process_material = _process_material(spec)
	p.draw_pass_1 = _draw_mesh(spec)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r: float = spec.get("bounds", 6.0)
	p.visibility_aabb = AABB(Vector3(-r, -r, -r), Vector3(2 * r, 2 * r, 2 * r))
	p.set_meta("base_amount", p.amount)
	return p


## Scales an emitter for the Quality preset's particle budget (GDD §14).
static func apply_quality(p: GPUParticles3D, ratio: float) -> void:
	p.amount_ratio = clampf(ratio, 0.05, 1.0)


static func _process_material(spec: Dictionary) -> ParticleProcessMaterial:
	var key: String = spec.get("key", "")
	if key != "" and _process.has(key):
		return _process[key]
	var m := ParticleProcessMaterial.new()
	match spec.get("shape", "point"):
		"sphere":
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = spec.get("radius", 0.5)
		"ring":
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			m.emission_ring_axis = Vector3.UP
			m.emission_ring_radius = spec.get("radius", 1.0)
			m.emission_ring_inner_radius = spec.get("inner", 0.0)
			m.emission_ring_height = spec.get("height", 0.1)
		"box":
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			m.emission_box_extents = spec.get("box", Vector3.ONE * 0.5)
		_:
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	m.direction = spec.get("dir", Vector3.UP)
	m.spread = spec.get("spread", 180.0)
	var vel: Vector2 = spec.get("vel", Vector2(1, 2))
	m.initial_velocity_min = vel.x
	m.initial_velocity_max = vel.y
	m.gravity = spec.get("gravity", Vector3.ZERO)
	var damping: Vector2 = spec.get("damping", Vector2.ZERO)
	m.damping_min = damping.x
	m.damping_max = damping.y
	var radial: Vector2 = spec.get("radial", Vector2.ZERO)
	m.radial_accel_min = radial.x
	m.radial_accel_max = radial.y
	var tangential: Vector2 = spec.get("tangential", Vector2.ZERO)
	m.tangential_accel_min = tangential.x
	m.tangential_accel_max = tangential.y
	var spin: Vector2 = spec.get("spin", Vector2.ZERO)
	m.angular_velocity_min = spin.x
	m.angular_velocity_max = spin.y
	m.angle_min = 0.0
	m.angle_max = 360.0 if spin != Vector2.ZERO or spec.get("turn", false) else 0.0
	var sc: Vector2 = spec.get("scale", Vector2(0.5, 1.0))
	m.scale_min = sc.x
	m.scale_max = sc.y
	m.scale_curve = _scale_curve(spec.get("grow", false))
	m.color = spec.get("color", Color.WHITE)
	m.color_ramp = _ramp(spec.get("colors", null))
	m.hue_variation_min = -float(spec.get("hue", 0.0))
	m.hue_variation_max = float(spec.get("hue", 0.0))
	if spec.get("align", false):
		m.particle_flag_align_y = true
	if spec.get("rotate_y", false):
		m.particle_flag_rotate_y = true
	if key != "":
		_process[key] = m
	return m


static func _scale_curve(grow: bool) -> CurveTexture:
	var key := "_curve_grow" if grow else "_curve_shrink"
	if _process.has(key):
		return _process[key]
	var c := Curve.new()
	if grow:
		c.add_point(Vector2(0.0, 0.35))
		c.add_point(Vector2(0.4, 0.85))
		c.add_point(Vector2(1.0, 1.0))
	else:
		c.add_point(Vector2(0.0, 1.0))
		c.add_point(Vector2(0.7, 0.75))
		c.add_point(Vector2(1.0, 0.0))
	var t := CurveTexture.new()
	t.curve = c
	_process[key] = t
	return t


static func _ramp(g: Variant) -> GradientTexture1D:
	var grad: Gradient = g
	if grad == null:
		if _process.has("_fade"):
			return _process["_fade"]
		grad = Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
		grad.colors = PackedColorArray(
			[Color(1, 1, 1, 0.0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)]
		)
	var t := GradientTexture1D.new()
	t.gradient = grad
	if g == null:
		_process["_fade"] = t
	return t


static func _draw_mesh(spec: Dictionary) -> Mesh:
	var mesh: Mesh = spec.get("mesh", null)
	if mesh != null:
		var mat: Material = spec.get("mat", null)
		if mat == null:
			return mesh
		var mkey := "m%d:%d" % [mesh.get_instance_id(), mat.get_instance_id()]
		if not _draw.has(mkey):
			var dup := mesh.duplicate() as Mesh
			if dup is PrimitiveMesh:
				(dup as PrimitiveMesh).material = mat
			else:
				(dup as ArrayMesh).surface_set_material(0, mat)
			_draw[mkey] = dup
		return _draw[mkey]
	var tex: Texture2D = spec.get("tex", UnitStyle.soft_dot())
	var add: bool = spec.get("add", true)
	var size: float = spec.get("size", 1.0)
	var energy: float = spec.get("energy", 1.0)
	var key := "q%d:%s:%f:%f" % [tex.get_instance_id(), add, size, energy]
	if not _draw.has(key):
		var q := QuadMesh.new()
		q.size = Vector2(size, size)
		q.material = UnitStyle.particle(tex, add, energy)
		_draw[key] = q
	return _draw[key]


## A colour-over-life gradient from a list of colours spread evenly.
static func gradient(colors: Array[Color]) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / maxf(colors.size() - 1, 1))
		cols.append(colors[i])
	g.offsets = offsets
	g.colors = cols
	return g
