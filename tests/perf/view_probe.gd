extends SceneTree
## Camera-aware estimate of world triangles drawn per camera view,
## emulating frustum culling, visibility ranges, mesh LOD selection and
## directional shadow cascade caster culling. World only; headless proxy for
## the screen-slot matrix. Usage:
##   godot --headless --path . --script res://tests/perf/view_probe.gd -- --pf-x=1

const VIEWS := {
	"full": [Vector3(0, 0, 4), 0.0, 58.0, 106.0],
	"portal": [Vector3(0, 2, -27), -18.0, 38.0, 30.0],
	"gate": [Vector3(0, 2, 26), 160.0, 36.0, 30.0],
	"low_n": [Vector3(0, 0, -48), 0.0, 22.0, 130.0],
	"low_e": [Vector3(40, 0, 0), -90.0, 22.0, 130.0],
}
const W := 2940.0
const H := 1782.0
const FOV := 40.0

var game: Game
var _mesh_info := {}


func _initialize() -> void:
	# The Citadel Plateau under classic rules, as docs/perf.md measured them,
	# unless --map or --rules says otherwise; never the player's last pick.
	Game._carry = {
		"map": Cli.get_str("map", MapDefs.DEFAULT), "rules": Cli.get_str("rules", "classic")
	}
	game = Game.new()
	root.add_child(game)
	process_frame.connect(_go, CONNECT_ONE_SHOT)


func _go() -> void:
	game.autoplay = AutoplayBot.new(game.sim, &"smart")
	game.warp_to_wave(24, 18.0)
	for i in 3:
		game._process(1.0 / 60.0)
	var items := []
	for n in game.world.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var it := _item(gi)
		if not it.is_empty():
			items.append(it)
	var sun: DirectionalLight3D = game.world.sun
	var only: String = Cli.get_str("view", "")
	for v: String in VIEWS:
		if only != "" and v != only:
			continue
		_view(v, VIEWS[v], items, sun)
	quit()


func _item(gi: GeometryInstance3D) -> Dictionary:
	var mesh: Mesh = null
	var xforms: Array[Transform3D] = []
	if gi is MeshInstance3D:
		mesh = (gi as MeshInstance3D).mesh
		xforms.append(gi.global_transform)
	elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh:
		var mm := (gi as MultiMeshInstance3D).multimesh
		mesh = mm.mesh
		var c := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		if c == 0 or not gi.has_meta(&"bounds"):
			if c > 0:
				print("NO BOUNDS ", gi.get_path())
			return {}
		for i in c:
			xforms.append(Transform3D())
	if mesh == null or xforms.is_empty() or not (mesh is ArrayMesh or mesh is PrimitiveMesh):
		return {}
	var box := AABB()
	if gi.has_meta(&"bounds"):
		box = gi.global_transform * (gi.get_meta(&"bounds") as AABB)
	else:
		box = xforms[0] * mesh.get_aabb()
	var nature := gi.get_parent() is WorldNature
	return {
		"gi": gi,
		"aabb": box,
		"count": xforms.size(),
		"surfs": _surfaces(mesh, gi),
		"nature": nature,
		"shadow": gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"visual": gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,
		"bias": gi.lod_bias,
		"vr_end": gi.visibility_range_end + gi.visibility_range_end_margin,
		"vr_begin": gi.visibility_range_begin,
		"fade": gi.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF,
		"end": gi.visibility_range_end,
		"margin": gi.visibility_range_end_margin,
	}


## Per surface: [base tris, [[edge, tris], ...], alpha-tested].
func _surfaces(mesh: Mesh, gi: GeometryInstance3D) -> Array:
	var out := []
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var idx: Variant = a[Mesh.ARRAY_INDEX]
		var base: int = (
			(idx as PackedInt32Array).size() / 3
			if idx != null
			else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		)
		var lods := []
		var d := RenderingServer.mesh_get_surface(mesh.get_rid(), s)
		if d.has("lods"):
			var bytes := 4 if int(d.get("vertex_count", 0)) > 65535 else 2
			for lod: Dictionary in d["lods"]:
				lods.append(
					[lod["edge_length"], (lod["index_data"] as PackedByteArray).size() / bytes / 3]
				)
		var m := mesh.surface_get_material(s)
		if gi.material_override:
			m = gi.material_override
		out.append([base, lods, _alpha(m)])
	return out


static func _alpha(m: Material) -> bool:
	if m is BaseMaterial3D:
		return (
			(m as BaseMaterial3D).transparency
			in [BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH]
		)
	if m is ShaderMaterial and (m as ShaderMaterial).shader:
		var code := (m as ShaderMaterial).shader.code
		return "ALPHA_SCISSOR" in code or "discard" in code
	return false


func _view(vname: String, v: Array, items: Array, sun: DirectionalLight3D) -> void:
	var target: Vector3 = v[0]
	var offset := Vector3(0, 0, v[3])
	offset = offset.rotated(Vector3.RIGHT, -deg_to_rad(v[2]))
	offset = offset.rotated(Vector3.UP, deg_to_rad(v[1]))
	var cam := Transform3D(Basis.IDENTITY, target + offset).looking_at(target, Vector3.UP)
	var proj := Projection.create_perspective(FOV, W / H, 0.3, 600.0)
	var lod_mult := proj.get_lod_multiplier()
	var thr := 1.0 / W
	var planes := _frustum(cam, 0.3, 600.0)
	var cascades := _cascades(cam, sun)
	var r := {
		"main": 0,
		"main_lod0": 0,
		"main_alpha": 0,
		"shadow": 0,
		"shadow_alpha": 0,
		"nat_main": 0,
		"nat_shadow": 0,
		"nat_inst": 0,
		"nat_shadow_inst": 0,
		"casc": [0, 0, 0, 0],
		"fading": 0,
	}
	for it: Dictionary in items:
		var box: AABB = it.aabb
		var depth := _lod_distance(cam, box)
		var tri := 0
		var tri0 := 0
		var alpha := 0
		for s: Array in it.surfs:
			var n: int = s[0]
			tri0 += n
			for lod: Array in s[1]:
				if lod[0] * it.bias / maxf(depth * lod_mult, 0.0001) > thr:
					break
				n = lod[1]
			tri += n
			if s[2]:
				alpha += n
		tri *= it.count
		tri0 *= it.count
		alpha *= it.count
		var dist := cam.origin.distance_to(box.get_center())
		var in_range: bool = (it.vr_end <= 0.0 or dist <= it.vr_end) and dist >= it.vr_begin
		if it.visual and in_range and _inside(planes, box):
			r.main += tri
			r.main_lod0 += tri0
			r.main_alpha += alpha
			if it.fade and absf(dist - it.end) < it.margin:
				r.fading += tri
			if it.nature:
				r.nat_main += tri
				r.nat_inst += it.count
		if it.shadow and in_range:
			for ci in cascades.size():
				var c: Array = cascades[ci]
				if _caster(c, box):
					r.casc[ci] += tri
					r.shadow += tri
					r.shadow_alpha += alpha
					if it.nature:
						r.nat_shadow += tri
						r.nat_shadow_inst += it.count
	print(
		(
			(
				"%-7s main %8d (lod0 %8d, alpha %7d) | shadow %8d (alpha %7d) cascades %s"
				+ " | nature main %8d / %5d inst, shadow %8d / %5d inst | fading %d"
			)
			% [
				vname,
				r.main,
				r.main_lod0,
				r.main_alpha,
				r.shadow,
				r.shadow_alpha,
				str(r.casc),
				r.nat_main,
				r.nat_inst,
				r.nat_shadow,
				r.nat_shadow_inst,
				r.fading
			]
		)
	)


static func _lod_distance(cam: Transform3D, box: AABB) -> float:
	var fwd := -cam.basis.z
	var lo := INF
	var hi := -INF
	for i in 8:
		var d := fwd.dot(box.get_endpoint(i) - cam.origin)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	if lo * hi < 0.0:
		return 0.0
	return lo if lo >= 0.0 else -hi


static func _frustum(cam: Transform3D, near: float, far: float) -> Array[Plane]:
	var v := deg_to_rad(FOV) * 0.5
	var h := atan(tan(v) * W / H)
	var local: Array[Plane] = [
		Plane(Vector3(0, 0, 1), -near),
		Plane(Vector3(0, 0, -1), far),
		Plane(Vector3(0, cos(v), sin(v)), 0.0),
		Plane(Vector3(0, -cos(v), sin(v)), 0.0),
		Plane(Vector3(cos(h), 0, sin(h)), 0.0),
		Plane(Vector3(-cos(h), 0, sin(h)), 0.0),
	]
	var out: Array[Plane] = []
	for p in local:
		out.append(cam * p)
	return out


static func _inside(planes: Array[Plane], box: AABB) -> bool:
	for p in planes:
		var q := box.position
		for a in 3:
			if p.normal[a] < 0.0:
				q[a] += box.size[a]
		if p.is_point_over(q):
			return false
	return true


## Each cascade: [x axis, y axis, z axis, center, radius].
static func _cascades(cam: Transform3D, sun: DirectionalLight3D) -> Array:
	var max_d := sun.directional_shadow_max_distance
	var splits := [
		0.0,
		sun.directional_shadow_split_1,
		sun.directional_shadow_split_2,
		sun.directional_shadow_split_3,
		1.0
	]
	if sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS:
		splits = [0.0, sun.directional_shadow_split_1, 1.0]
	elif sun.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL:
		splits = [0.0, 1.0]
	var lb := sun.global_transform.basis.orthonormalized()
	var v := deg_to_rad(FOV) * 0.5
	var ty := tan(v)
	var tx := ty * W / H
	var out := []
	for i in splits.size() - 1:
		var d0: float = maxf(0.3, max_d * splits[i])
		var d1: float = max_d * splits[i + 1]
		var pts: Array[Vector3] = []
		for d in [d0, d1]:
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					pts.append(cam * Vector3(sx * tx * d, sy * ty * d, -d))
		var c := Vector3.ZERO
		for p in pts:
			c += p
		c /= pts.size()
		var rad := 0.0
		for p in pts:
			rad = maxf(rad, p.distance_to(c))
		out.append([lb.x, lb.y, lb.z, c, rad])
	return out


static func _caster(c: Array, box: AABB) -> bool:
	var mn := Vector3(INF, INF, INF)
	var mx := -mn
	for i in 8:
		var p := box.get_endpoint(i) - (c[3] as Vector3)
		var q := Vector3(
			(c[0] as Vector3).dot(p), (c[1] as Vector3).dot(p), (c[2] as Vector3).dot(p)
		)
		mn = mn.min(q)
		mx = mx.max(q)
	var r: float = c[4]
	return mx.x >= -r and mn.x <= r and mx.y >= -r and mn.y <= r and mx.z >= -r
