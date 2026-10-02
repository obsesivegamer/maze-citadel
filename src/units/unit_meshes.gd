class_name UnitMeshes
extends RefCounted
## Small procedural meshes no asset pack covers: root vines, the rune hammer,
## music notes, tracer streaks, coins, ice shards and flat rings. Built once
## and shared.

const VINE_COLOR := Color(0.26, 0.62, 0.14)
const VINE_STRANDS := 4
const HAMMER_HEAD := Color(0.62, 0.6, 0.66)
const HAMMER_RUNE := Color(1.0, 0.8, 0.3)
const HAMMER_HANDLE := Color(0.45, 0.28, 0.14)

static var _cache := {}


## Vines coiling up a unit cylinder (radius 1, height 1); scale per creep.
static func vines() -> Mesh:
	if _cache.has("vines"):
		return _cache["vines"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in VINE_STRANDS:
		var pts := PackedVector3Array()
		var phase := TAU * s / VINE_STRANDS
		for i in 13:
			var k := i / 12.0
			var a := phase + k * TAU * 0.85 * (1.0 if s % 2 == 0 else -1.0)
			var r := 1.0 - 0.25 * k
			pts.append(Vector3(cos(a) * r, k * (0.8 + 0.25 * (s % 2)), sin(a) * r))
		_tube(st, pts, 0.11, 0.03, 5)
	st.generate_normals()
	var mesh := st.commit()
	var mat := UnitStyle.glow(VINE_COLOR, 0.35).duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	_cache["vines"] = mesh
	return mesh


## Runesmith projectile: stone head with a glowing rune band on a handle.
static func hammer() -> Mesh:
	if _cache.has("hammer"):
		return _cache["hammer"]
	var mesh := ArrayMesh.new()
	var head := BoxMesh.new()
	head.size = Vector3(0.55, 0.32, 0.32)
	var band := BoxMesh.new()
	band.size = Vector3(0.14, 0.36, 0.36)
	var handle := CylinderMesh.new()
	handle.top_radius = 0.05
	handle.bottom_radius = 0.06
	handle.height = 0.75
	handle.radial_segments = 6
	_append(mesh, head, Transform3D(Basis(), Vector3(0, 0.35, 0)), UnitStyle.flat(HAMMER_HEAD))
	_append(mesh, band, Transform3D(Basis(), Vector3(0, 0.35, 0)), UnitStyle.glow(HAMMER_RUNE, 3.0))
	_append(mesh, handle, Transform3D.IDENTITY, UnitStyle.flat(HAMMER_HANDLE))
	_cache["hammer"] = mesh
	return mesh


## A quaver in the XY plane, about 1 m tall (Bard notes).
static func note() -> Mesh:
	if _cache.has("note"):
		return _cache["note"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.BACK)
	var c := Vector3(-0.15, -0.35, 0)
	for i in 10:
		var a0 := TAU * i / 10.0
		var a1 := TAU * (i + 1) / 10.0
		st.add_vertex(c)
		st.add_vertex(c + Vector3(cos(a1) * 0.24, sin(a1) * 0.17, 0).rotated(Vector3.BACK, 0.4))
		st.add_vertex(c + Vector3(cos(a0) * 0.24, sin(a0) * 0.17, 0).rotated(Vector3.BACK, 0.4))
	_quad(st, Vector3(0.04, -0.33, 0), Vector3(0.1, -0.33, 0), Vector3(0.1, 0.5, 0), Vector3(0.04, 0.5, 0))
	_quad(st, Vector3(0.04, 0.5, 0), Vector3(0.1, 0.5, 0), Vector3(0.36, 0.18, 0), Vector3(0.3, 0.12, 0))
	var mesh := st.commit()
	_cache["note"] = mesh
	return mesh


## Two crossed quads from z = -1 (tail) to z = 0 (head), for tracers.
static func streak() -> Mesh:
	if _cache.has("streak"):
		return _cache["streak"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in [Vector3.RIGHT, Vector3.UP]:
		var w: Vector3 = axis * 0.5
		st.set_normal(axis.cross(Vector3.BACK))
		st.set_uv(Vector2(0, 0))
		st.add_vertex(-w)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(w)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(w + Vector3(0, 0, -1))
		st.set_uv(Vector2(0, 0))
		st.add_vertex(-w)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(w + Vector3(0, 0, -1))
		st.set_uv(Vector2(0, 1))
		st.add_vertex(-w + Vector3(0, 0, -1))
	var mesh := st.commit()
	_cache["streak"] = mesh
	return mesh


## Fades a streak from bright head (v = 0) to nothing at the tail (v = 1).
static func streak_texture() -> Texture2D:
	if _cache.has("streak_tex"):
		return _cache["streak_tex"]
	var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		var along := 1.0 - y / 63.0
		for x in 32:
			var across := 1.0 - absf(x / 31.0 - 0.5) * 2.0
			img.set_pixel(x, y, Color(1, 1, 1, across * along * along))
	var tex := ImageTexture.create_from_image(img)
	_cache["streak_tex"] = tex
	return tex


static func coin() -> Mesh:
	if _cache.has("coin"):
		return _cache["coin"]
	var m := CylinderMesh.new()
	m.top_radius = 0.16
	m.bottom_radius = 0.16
	m.height = 0.04
	m.radial_segments = 10
	m.rings = 1
	m.material = UnitStyle.glow(Color(1.0, 0.8, 0.25), 0.6)
	_cache["coin"] = m
	return m


## A tapered hexagonal crystal 1 m tall (frost wyrm coil, ice shards).
static func crystal(top := 0.35) -> Mesh:
	var key := "crystal%f" % top
	if _cache.has(key):
		return _cache[key]
	var m := CylinderMesh.new()
	m.top_radius = top * 0.5
	m.bottom_radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 1
	_cache[key] = m
	return m


## A flat 2 × 2 m plane (radius 1 ring once textured).
static func disc() -> Mesh:
	if _cache.has("disc"):
		return _cache["disc"]
	var m := PlaneMesh.new()
	m.size = Vector2(2, 2)
	_cache["disc"] = m
	return m


static func _append(mesh: ArrayMesh, part: Mesh, xf: Transform3D, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(part, 0, xf)
	st.set_material(mat)
	st.commit(mesh)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, c, b, a, d, c]:
		st.add_vertex(v)


## A tapered tube through `pts`, radius r0 at the start and r1 at the end.
static func _tube(st: SurfaceTool, pts: PackedVector3Array, r0: float, r1: float, sides: int) -> void:
	var rings: Array[PackedVector3Array] = []
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n := t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).normalized()
		var b := t.cross(n)
		var r := lerpf(r0, r1, float(i) / (pts.size() - 1))
		var ring := PackedVector3Array()
		for k in sides:
			var a := TAU * k / sides
			ring.append(pts[i] + (n * cos(a) + b * sin(a)) * r)
		rings.append(ring)
	for i in pts.size() - 1:
		for k in sides:
			var k2 := (k + 1) % sides
			_quad(st, rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k])
