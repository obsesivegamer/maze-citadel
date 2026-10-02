class_name ImpactFx
extends Node3D
## Impacts and flourishes driven by sim events (GDD §12): explosions, scorch
## craters, burning craters, frost rings, root novas, shadow clouds, frost
## breath, poison puffs, leak poofs, build dust, upgrade sparkle, sell coins
## and fuse flash. Emitters are pooled per effect and re-fired in place;
## lingering effects (fire, clouds, scorch) run on timers.

const POOL := {
	&"flash": 6,
	&"debris": 6,
	&"smoke": 6,
	&"frost_ring": 4,
	&"roots": 4,
	&"breath": 3,
	&"puff": 10,
	&"poof": 4,
	&"dust": 4,
	&"sparkle": 3,
	&"coins": 3,
	&"fuse": 2,
}
const LOOP_POOL := {&"fire": 6, &"cloud": 9}
## Radius each spec is authored at; emitters scale to the event's radius.
const BASE_RADIUS := 2.0
const SCORCH_POOL := 24
const SCORCH_TIME := 6.0
const SCORCH_FADE := 1.5
const SCORCH_COLOR := Color(0.08, 0.06, 0.05, 0.9)

const SPECS := {
	&"flash":
	{
		"key": "fx_flash",
		"amount": 4,
		"lifetime": 0.22,
		"one_shot": true,
		"vel": Vector2(0, 0.2),
		"scale": Vector2(2.6, 3.4),
		"color": Color(1.0, 0.65, 0.25),
		"energy": 5.0,
		"size": 1.6,
	},
	&"debris":
	{
		"key": "fx_debris",
		"amount": 18,
		"lifetime": 0.9,
		"one_shot": true,
		"spread": 55.0,
		"vel": Vector2(4.0, 9.0),
		"gravity": Vector3(0, -14, 0),
		"scale": Vector2(0.12, 0.28),
		"color": Color(0.35, 0.26, 0.16),
		"add": false,
		"size": 0.6,
	},
	&"smoke":
	{
		"key": "fx_smoke",
		"amount": 10,
		"lifetime": 1.6,
		"one_shot": true,
		"shape": "sphere",
		"radius": 0.8,
		"vel": Vector2(0.6, 1.6),
		"damping": Vector2(0.4, 0.8),
		"scale": Vector2(1.2, 2.0),
		"grow": true,
		"color": Color(0.32, 0.3, 0.28, 0.7),
		"add": false,
		"size": 1.4,
	},
	&"fire":
	{
		"key": "fx_fire",
		"amount": 28,
		"lifetime": 0.8,
		"shape": "ring",
		"radius": BASE_RADIUS * 0.8,
		"spread": 12.0,
		"vel": Vector2(0.8, 2.0),
		"scale": Vector2(0.5, 0.9),
		"color": Color(1.0, 0.55, 0.15),
		"energy": 2.5,
		"bounds": 8.0,
	},
	&"cloud":
	{
		"key": "fx_cloud",
		"amount": 22,
		"lifetime": 1.6,
		"shape": "box",
		"box": Vector3(BASE_RADIUS, 0.3, BASE_RADIUS),
		"spread": 40.0,
		"vel": Vector2(0.1, 0.4),
		"scale": Vector2(1.4, 2.2),
		"grow": true,
		"color": Color(0.32, 0.12, 0.42, 0.55),
		"add": false,
		"size": 1.6,
		"bounds": 8.0,
	},
	&"frost_ring":
	{
		"key": "fx_frost_ring",
		"amount": 48,
		"lifetime": 0.6,
		"one_shot": true,
		"shape": "ring",
		"radius": BASE_RADIUS * 0.3,
		"spread": 90.0,
		"dir": Vector3(0, 0.2, 0),
		"vel": Vector2(5.0, 6.0),
		"radial": Vector2(2.0, 3.0),
		"scale": Vector2(0.35, 0.6),
		"color": Color(0.6, 0.9, 1.0),
		"energy": 2.0,
	},
	&"roots":
	{
		"key": "fx_roots",
		"amount": 40,
		"lifetime": 0.8,
		"one_shot": true,
		"shape": "ring",
		"radius": BASE_RADIUS * 0.4,
		"spread": 70.0,
		"dir": Vector3(0, 0.4, 0),
		"vel": Vector2(4.0, 6.0),
		"gravity": Vector3(0, -4, 0),
		"scale": Vector2(0.3, 0.55),
		"color": Color(0.45, 0.9, 0.3),
		"hue": 0.04,
		"add": false,
		"size": 0.7,
	},
	&"breath":
	{
		"key": "fx_breath",
		"amount": 46,
		"lifetime": 0.6,
		"one_shot": true,
		"dir": Vector3(0, 0, -1),
		"spread": 28.0,
		"vel": Vector2(9.0, 13.0),
		"damping": Vector2(4.0, 6.0),
		"scale": Vector2(0.6, 1.1),
		"grow": true,
		"color": Color(0.75, 0.93, 1.0, 0.8),
		"energy": 1.5,
		"bounds": 10.0,
	},
	&"puff":
	{
		"key": "fx_puff",
		"amount": 6,
		"lifetime": 0.6,
		"one_shot": true,
		"shape": "sphere",
		"radius": 0.4,
		"vel": Vector2(0.3, 0.9),
		"scale": Vector2(0.4, 0.7),
		"grow": true,
		"color": Color(0.45, 0.95, 0.35, 0.7),
		"add": false,
	},
	&"poof":
	{
		"key": "fx_poof",
		"amount": 26,
		"lifetime": 0.7,
		"one_shot": true,
		"shape": "sphere",
		"radius": 0.8,
		"vel": Vector2(1.5, 3.5),
		"scale": Vector2(0.4, 0.8),
		"color": Color(0.7, 0.45, 1.0),
		"energy": 2.5,
	},
	&"dust":
	{
		"key": "fx_dust",
		"amount": 18,
		"lifetime": 0.8,
		"one_shot": true,
		"shape": "ring",
		"radius": 1.0,
		"spread": 80.0,
		"dir": Vector3(0, 0.3, 0),
		"vel": Vector2(1.5, 3.0),
		"damping": Vector2(2.0, 3.0),
		"scale": Vector2(0.7, 1.1),
		"grow": true,
		"color": Color(0.62, 0.52, 0.38, 0.65),
		"add": false,
		"size": 1.2,
	},
	&"sparkle":
	{
		"key": "fx_sparkle",
		"amount": 26,
		"lifetime": 0.9,
		"one_shot": true,
		"shape": "ring",
		"radius": 1.0,
		"vel": Vector2(1.5, 3.0),
		"gravity": Vector3(0, 1.5, 0),
		"scale": Vector2(0.15, 0.3),
		"color": Color(1.0, 0.85, 0.35),
		"energy": 3.0,
		"size": 0.5,
	},
	&"coins":
	{
		"key": "fx_coins",
		"amount": 14,
		"lifetime": 0.9,
		"one_shot": true,
		"spread": 35.0,
		"vel": Vector2(3.0, 6.0),
		"gravity": Vector3(0, -14, 0),
		"scale": Vector2(0.18, 0.26),
		"color": Color(1.0, 0.8, 0.2),
		"energy": 1.6,
		"size": 0.6,
	},
	&"fuse":
	{
		"key": "fx_fuse",
		"amount": 40,
		"lifetime": 1.0,
		"one_shot": true,
		"shape": "sphere",
		"radius": 1.2,
		"vel": Vector2(2.0, 5.0),
		"scale": Vector2(0.3, 0.6),
		"color": Color(0.75, 0.9, 1.0),
		"energy": 4.0,
	},
}

var _pools := {}
var _next := {}
var _loops := {}
var _scorch: Array[Decal] = []
var _scorch_age: PackedFloat32Array = []
var _scorch_life: PackedFloat32Array = []
var _scorch_next := 0
var _ratio := 1.0


func setup() -> void:
	for id in POOL:
		_pools[id] = _make_pool(id, POOL[id])
		_next[id] = 0
	for id in LOOP_POOL:
		var list: Array = []
		for p in _make_pool(id, LOOP_POOL[id]):
			p.emitting = false
			list.append({"p": p, "left": 0.0})
		_loops[id] = list
	var tex := _scorch_texture()
	for i in SCORCH_POOL:
		var d := Decal.new()
		d.texture_albedo = tex
		d.modulate = SCORCH_COLOR
		d.visible = false
		d.cull_mask = 1
		add_child(d)
		_scorch.append(d)
		_scorch_age.append(0.0)
		_scorch_life.append(0.0)


func set_quality_ratio(ratio: float) -> void:
	_ratio = ratio
	for id in _pools:
		for p in _pools[id]:
			ParticleKit.apply_quality(p, ratio)
	for id in _loops:
		for slot in _loops[id]:
			ParticleKit.apply_quality(slot.p, ratio)


func _make_pool(id: StringName, count: int) -> Array:
	var out := []
	for i in count:
		var p := ParticleKit.make(SPECS[id])
		add_child(p)
		ParticleKit.apply_quality(p, _ratio)
		out.append(p)
	return out


## Fires a pooled one-shot effect at a world position, scaled to `radius`.
func burst(id: StringName, pos: Vector3, radius := BASE_RADIUS, facing := Vector3.ZERO) -> void:
	var pool: Array = _pools[id]
	var p: GPUParticles3D = pool[_next[id]]
	_next[id] = (_next[id] + 1) % pool.size()
	p.global_position = pos
	p.basis = Basis.IDENTITY.scaled(Vector3.ONE * (radius / BASE_RADIUS))
	if facing != Vector3.ZERO:
		p.look_at(pos + facing, Vector3.UP)
	p.restart()


## Starts a lingering effect (burning crater, shadow cloud) for `seconds`.
func linger(id: StringName, pos: Vector3, radius: float, seconds: float) -> void:
	var best: Dictionary = _loops[id][0]
	for slot in _loops[id]:
		if slot.left < best.left:
			best = slot
	var p: GPUParticles3D = best.p
	p.global_position = pos
	p.scale = Vector3.ONE * (radius / BASE_RADIUS)
	p.emitting = true
	best.left = seconds


func scorch(pos: Vector3, radius: float, seconds := SCORCH_TIME) -> void:
	var i := _scorch_next
	_scorch_next = (_scorch_next + 1) % SCORCH_POOL
	var d := _scorch[i]
	d.global_position = pos
	d.size = Vector3(radius * 2.0, 2.0, radius * 2.0)
	d.rotation.y = randf() * TAU
	d.modulate.a = SCORCH_COLOR.a
	d.visible = true
	_scorch_age[i] = 0.0
	_scorch_life[i] = seconds


func _process(delta: float) -> void:
	for id in _loops:
		for slot in _loops[id]:
			if slot.left > 0.0:
				slot.left -= delta
				if slot.left <= 0.0:
					slot.p.emitting = false
	for i in SCORCH_POOL:
		var d := _scorch[i]
		if not d.visible:
			continue
		_scorch_age[i] += delta
		var left := _scorch_life[i] - _scorch_age[i]
		d.modulate.a = SCORCH_COLOR.a * clampf(left / SCORCH_FADE, 0.0, 1.0)
		d.visible = left > 0.0


static func _scorch_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t
