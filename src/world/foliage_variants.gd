class_name FoliageVariants
extends RefCounted
## Cheaper stand-ins for the swaying plant meshes, switched on by `--pf-*`
## performance experiments (PerfFlags). With no flags set, WorldKit uses the
## imported meshes and the stock foliage shaders and nothing here runs.
##   nature-bark-lod=N    bark of leafy plants starts at importer LOD N
##   nature-shadow-proxy  shadows come from a low-poly opaque hull
##   nature-proxy-fill=F  share of leaf vertices that hull encloses (0.8)
##   bark-cull=back       bark drops back faces (leaves stay two-sided)
##   foliage-filter=trilinear  plant textures skip anisotropic filtering
##   leaf-priority=N      render_priority of alpha-tested leaf materials

## Hull resolution: sides around the trunk, height bands.
const PROXY_SIDES := 8
const PROXY_BANDS := 6
## Share of a band's leaf vertices the hull encloses: all of them makes a
## blobby shadow from stray leaf-card corners, the median makes it too thin.
const PROXY_FILL := 0.8

const INCLUDE := preload("res://src/world/shaders/foliage.gdshaderinc")

static var _proxies := {}
static var _shaders := {}
static var _proxy_mat: StandardMaterial3D


## The importer's LODs of one surface, finest first, as [[edge_length,
## PackedInt32Array]]. Mesh doesn't expose them, the rendering server does.
static func surface_lods(mesh: Mesh, surface: int) -> Array:
	var d := RenderingServer.mesh_get_surface(mesh.get_rid(), surface)
	var out := []
	var count := int(d.get("index_count", 0))
	if count == 0:
		return out
	var wide := (d["index_data"] as PackedByteArray).size() / count == 4
	for lod: Dictionary in d.get("lods", []):
		var bytes: PackedByteArray = lod["index_data"]
		var idx := PackedInt32Array()
		if wide:
			idx = bytes.to_int32_array()
		else:
			idx.resize(bytes.size() / 2)
			for i in idx.size():
				idx[i] = bytes.decode_u16(i * 2)
		out.append([lod["edge_length"], idx])
	return out


## Copy of `src` whose surfaces flagged in `coarse` use importer LOD `level`
## as their full detail; coarser LODs stay for the engine to pick at range.
## Bark is mostly hidden under the leaves, so its detail is the cheapest to
## drop.
static func with_lod(src: ArrayMesh, level: int, coarse: Array[bool]) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var lods := surface_lods(src, s)
		var start := mini(level, lods.size()) if coarse[s] else 0
		if start > 0:
			arrays[Mesh.ARRAY_INDEX] = lods[start - 1][1]
		var rest := {}
		for i in range(start, lods.size()):
			rest[lods[i][0]] = lods[i][1]
		var flags := src.surface_get_format(s) & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], rest, flags)
		out.surface_set_material(s, src.surface_get_material(s))
	return out


## True when any surface of `mesh` is alpha-tested foliage.
static func has_leaves(mesh: Mesh) -> bool:
	for s in mesh.get_surface_count():
		if _is_leaf(mesh.surface_get_material(s)):
			return true
	return false


static func _is_leaf(mat: Material) -> bool:
	var m := mat as ShaderMaterial
	return m != null and m.shader != null and "ALPHA_SCISSOR" in m.shader.code


## A low-poly opaque shadow caster for a plant: a hull lathed around each
## height band's centre, as wide as the nature-proxy-fill share of the band's
## leaf vertices (bark where a band has no leaves, i.e. the trunk), closed at
## both ends. Opaque, unswayed and plain-materialled, it takes the renderer's
## depth-only shadow path instead of the swaying alpha-tested one.
static func shadow_proxy(src: Mesh) -> ArrayMesh:
	if _proxies.has(src):
		return _proxies[src]
	var fill := PerfFlags.get_float("nature-proxy-fill", PROXY_FILL)
	var box := src.get_aabb()
	var y0 := box.position.y
	var h := maxf(box.size.y, 0.01)
	var leaves: Array[Array] = []
	var bark: Array[Array] = []
	for b in PROXY_BANDS:
		leaves.append([])
		bark.append([])
	for s in src.get_surface_count():
		var into := leaves if _is_leaf(src.surface_get_material(s)) else bark
		for v: Vector3 in src.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			into[clampi(floori((v.y - y0) / h * PROXY_BANDS), 0, PROXY_BANDS - 1)].append(v)
	var rings := []
	for b in PROXY_BANDS:
		var pts: Array = leaves[b] if not leaves[b].is_empty() else bark[b]
		var ring := _band_ring(pts, fill, h * 0.03)
		if b == 0:
			rings.append([y0, ring[0], ring[1]])
		rings.append([y0 + (b + 0.5) * h / PROXY_BANDS, ring[0], ring[1]])
	rings.append([y0 + h, rings[-1][1], 0.0])
	var mesh := _lathe(rings)
	_proxies[src] = mesh
	return mesh


## [centre, radius] of one height band, in the xz plane.
static func _band_ring(pts: Array, fill: float, fallback: float) -> Array:
	if pts.is_empty():
		return [Vector2.ZERO, fallback]
	var c := Vector2.ZERO
	for v: Vector3 in pts:
		c += Vector2(v.x, v.z)
	c /= pts.size()
	var d := PackedFloat32Array()
	for v: Vector3 in pts:
		d.append(Vector2(v.x, v.z).distance_to(c))
	d.sort()
	return [c, maxf(d[clampi(int(d.size() * fill), 0, d.size() - 1)], fallback)]


## Closed surface through `rings` ([y, centre, radius], bottom to top), wound
## clockwise seen from outside (Godot's front faces).
static func _lathe(rings: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r: Array in rings:
		var c: Vector2 = r[1]
		for k in PROXY_SIDES:
			var a := TAU * k / PROXY_SIDES
			st.add_vertex(Vector3(c.x + cos(a) * r[2], r[0], c.y + sin(a) * r[2]))
	var bottom := rings.size() * PROXY_SIDES
	var c0: Vector2 = rings[0][1]
	st.add_vertex(Vector3(c0.x, rings[0][0], c0.y))
	for k in PROXY_SIDES:
		var k1 := (k + 1) % PROXY_SIDES
		for v in [bottom, k1, k]:
			st.add_index(v)
		for i in rings.size() - 1:
			var lo := i * PROXY_SIDES
			var hi := lo + PROXY_SIDES
			for v in [lo + k, lo + k1, hi + k1]:
				st.add_index(v)
			if rings[i + 1][2] > 0.0:
				for v in [lo + k, hi + k1, hi + k]:
					st.add_index(v)
	st.generate_normals()
	if _proxy_mat == null:
		_proxy_mat = StandardMaterial3D.new()
	st.set_material(_proxy_mat)
	return st.commit()


## `base` rewritten for the bark-cull (only when `bark`) and foliage-filter
## flags; `base` itself when neither applies.
static func shader(base: Shader, bark: bool) -> Shader:
	var code := base.code
	var cull := PerfFlags.get_str("bark-cull", "disabled")
	if bark and cull != "disabled":
		code = code.replace("cull_disabled", "cull_" + cull)
	if PerfFlags.get_str("foliage-filter", "aniso") == "trilinear":
		# The sampler lives in the include, so inline it with the hint changed.
		var inc := '#include "%s"' % INCLUDE.resource_path
		var plain := INCLUDE.code.replace(
			"filter_linear_mipmap_anisotropic", "filter_linear_mipmap"
		)
		code = code.replace(inc, plain)
	if code == base.code:
		return base
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]
