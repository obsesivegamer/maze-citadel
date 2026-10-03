class_name TowerVisuals
extends RefCounted
## Tower models per type and level (GDD §7), kitbashed from the Kenney Tower
## Defense Kit and other environment parts with family accents. `build()` is
## pure (no game state), so the build ghost can show the same model.
##
## Static parts are merged into one mesh per material and cached per
## (id, level); moving parts stay separate nodes. The returned root carries:
##   meta "head"   Node3D that turns toward SimTower.aim (optional)
##   meta "recoil" Node3D kicked back on `fired`, "recoil_kind" barrel|arm|bolt
##   meta "muzzle_height" metres above the plateau where shots leave
##   meta "spin"   Array of [Node3D, radians per second]
##   meta "coil"   Array of Node3D (Frost Wyrm segments, see TowerView)
##   meta "glow"   Array of Node3D that pulse (molten / magic glows)
##   meta "idle"   particle spec names TowerView attaches (UnitFx)

const ENV := "res://assets/environment/"
const TD := ENV + "kenney_tower_defense_kit/"
## Kit parts are 1 m wide; a tile is 2 m. Everything is built at this scale.
const KIT := 1.7
const EPIC_SCALE := 1.4

static var _parts := {}
static var _heights := {}
static var _merged := {}
static var _muzzles := {}
static var _value_keys := {}


## One placed part: a scene path or a Mesh, its transform, an optional
## material that replaces every surface's, and whether it is a small ornament
## (UnitPerf tower-shadow-parts).
class Part:
	extends RefCounted
	var source: Variant
	var xf: Transform3D
	var mat: Material
	var detail: bool

	func _init(s: Variant, t: Transform3D, m: Material, d := false) -> void:
		source = s
		xf = t
		mat = m
		detail = d


## Collects parts for one tower and stacks kit pieces upward.
class Kit:
	extends RefCounted
	var root := Node3D.new()
	var family: StringName
	var parts: Array[Part] = []
	## Current top of the stack in metres.
	var y := 0.0
	var spin: Array = []
	var coil: Array = []
	var glow: Array = []
	var idle: Array[StringName] = []

	func _init(fam: StringName) -> void:
		family = fam

	## Puts a TD-kit piece on top of the stack; returns its base height.
	func stack(file: String, s := 1.0, rot := 0.0) -> float:
		var base := y
		place(TD + file, Vector3(0, y, 0), s, rot)
		y += TowerVisuals.height_of(TD + file) * KIT * s
		return base

	func place(path: String, pos: Vector3, s := 1.0, rot := 0.0, mat: Material = null) -> void:
		var b := Basis(Vector3.UP, rot).scaled(Vector3.ONE * KIT * s)
		parts.append(Part.new(path, Transform3D(b, pos), mat, path in TowerRecipes.DETAILS))

	func mesh(m: Mesh, xf: Transform3D, mat: Material, detail := false) -> void:
		parts.append(Part.new(m, xf, mat, detail))

	func accent() -> Color:
		return UnitStyle.family_color(family)


static func build(id: StringName, level: int) -> Node3D:
	var family: StringName = TowerDefs.TOWERS[id].family
	var k := Kit.new(family)
	k.root.name = "Tower_%s_%d" % [id, level]
	var lvl := clampi(level, 1, TowerDefs.MAX_LEVEL)
	TowerRecipes.make(k, id, lvl)
	var key := "%s:%d" % [id, lvl]
	if not _merged.has(key):
		_merged[key] = _merge_body(k.parts, family)
	var meshes: Array = _merged[key]
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = meshes[0]
	k.root.add_child(mi)
	k.root.move_child(mi, 0)
	if meshes[1] != null:
		var details := MeshInstance3D.new()
		details.name = "Details"
		details.mesh = meshes[1]
		details.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		k.root.add_child(details)
		k.root.move_child(details, 1)
	_apply_perf(k.root, mi)
	k.root.set_meta("spin", k.spin)
	k.root.set_meta("coil", k.coil)
	k.root.set_meta("glow", k.glow)
	k.root.set_meta("idle", k.idle)
	if not k.root.has_meta("muzzle_height"):
		k.root.set_meta("muzzle_height", k.y + 0.4)
	if id in TowerDefs.EPICS:
		k.root.scale = Vector3.ONE * EPIC_SCALE
		k.root.set_meta("muzzle_height", float(k.root.get_meta("muzzle_height")) * EPIC_SCALE)
	_muzzles[key] = k.root.get_meta("muzzle_height")
	return k.root


## Height above the plateau where this tower's shots start.
static func muzzle_height(id: StringName, level: int) -> float:
	var key := "%s:%d" % [id, clampi(level, 1, TowerDefs.MAX_LEVEL)]
	if not _muzzles.has(key):
		build(id, level).free()
	return _muzzles[key]


## Height of a part in kit units (its AABB top).
static func height_of(path: String) -> float:
	if not _heights.has(path):
		var top := 0.0
		for entry in part_meshes(path):
			var aabb: AABB = entry[1] * (entry[0] as Mesh).get_aabb()
			top = maxf(top, aabb.end.y)
		_heights[path] = top
	return _heights[path]


## A scene's meshes with transforms relative to its root, loaded once.
static func part_meshes(path: String) -> Array:
	if _parts.has(path):
		return _parts[path]
	var out := []
	var scene: PackedScene = load(path)
	var root := scene.instantiate()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		out.append([mi.mesh, CreepModels.rel_transform(mi, root as Node3D)])
	root.free()
	_parts[path] = out
	return out


## [body, details or null]: ornaments get their own shadowless mesh when
## UnitPerf tower-shadow-parts asks for it.
static func _merge_body(parts: Array[Part], family: StringName) -> Array:
	if UnitPerf.tower_shadow_parts() == "all":
		return [_merge(parts, family), null]
	var body: Array[Part] = []
	var details: Array[Part] = []
	for p in parts:
		(details if p.detail else body).append(p)
	return [_merge(body, family), _merge(details, family) if not details.is_empty() else null]


static func _merge(parts: Array[Part], family: StringName) -> ArrayMesh:
	var tools := {}
	var mats := {}
	var by_value := UnitPerf.tower_merge()
	for p in parts:
		var entries: Array = []
		if p.source is Mesh:
			entries = [[p.source, Transform3D.IDENTITY]]
		else:
			entries = part_meshes(p.source)
		for entry in entries:
			var mesh: Mesh = entry[0]
			for s in mesh.get_surface_count():
				var mat := p.mat if p.mat else mesh.surface_get_material(s)
				mat = UnitStyle.family_material(mat, family)
				var key: Variant = mat.get_instance_id() if mat else 0
				if by_value:
					key = _value_key(mat)
				if not tools.has(key):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					tools[key] = st
					mats[key] = mat
				(tools[key] as SurfaceTool).append_from(mesh, s, p.xf * (entry[1] as Transform3D))
	if UnitPerf.tower_lod() > 0.0:
		return _with_lods(tools, mats)
	var out := ArrayMesh.new()
	for key in tools:
		var st: SurfaceTool = tools[key]
		st.set_material(mats[key])
		st.commit(out)
	return out


## Kit pieces from different files each carry their own copy of the same
## atlas material; keyed by value they share one surface (one draw).
static func _value_key(mat: Material) -> Variant:
	if mat == null:
		return 0
	var id := mat.get_instance_id()
	if not _value_keys.has(id):
		var parts := PackedStringArray([mat.get_class()])
		for prop in mat.get_property_list():
			var pname: String = prop.name
			if prop.usage & PROPERTY_USAGE_STORAGE and not pname.begins_with("resource_"):
				var v: Variant = mat.get(pname)
				parts.append(
					"%s=%s" % [pname, (v as Object).get_instance_id() if v is Object else v]
				)
		_value_keys[id] = ",".join(parts)
	return _value_keys[id]


## Merging drops the imported LODs, so generate them again. The kit's
## atlas-mapped parts barely simplify (every face is a UV island); props
## such as the cauldron, tree, tent and pennant poles do.
static func _with_lods(tools: Dictionary, mats: Dictionary) -> ArrayMesh:
	var im := ImporterMesh.new()
	for key in tools:
		var arrays := (tools[key] as SurfaceTool).commit_to_arrays()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, mats[key])
	im.generate_lods(60.0, 0.0, [])
	return im.get_mesh()


## UnitPerf tower-shadow-parts and tower-lod on a finished model.
static func _apply_perf(root: Node3D, body: MeshInstance3D) -> void:
	var shadows := UnitPerf.tower_shadow_parts()
	var lod := UnitPerf.tower_lod()
	if shadows == "all" and lod <= 0.0:
		return
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if lod > 0.0:
			mi.lod_bias = lod
			if mi.name == "arrow":
				mi.visibility_range_end = UnitPerf.BOLT_RANGE * lod
		if mi == body:
			continue
		if shadows == "body" or (shadows == "details" and mi.has_meta("detail")):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A moving weapon from the kit, recoloured; returns its root.
static func weapon(k: Kit, file: String, s: float) -> Node3D:
	var w: Node3D = (load(TD + file) as PackedScene).instantiate()
	w.scale = Vector3.ONE * KIT * s
	for mi: MeshInstance3D in w.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat := UnitStyle.family_material(mi.mesh.surface_get_material(i), k.family)
			mi.set_surface_override_material(i, mat)
	return w


## Adds the turning head at `y` and records the muzzle height.
static func head(k: Kit, y: float, muzzle: float) -> Node3D:
	var h := Node3D.new()
	h.name = "Head"
	h.position.y = y
	k.root.add_child(h)
	k.root.set_meta("head", h)
	k.root.set_meta("muzzle_height", y + muzzle)
	return h


## Marks a node to kick back when the tower fires.
static func recoil(k: Kit, node: Node3D, kind: StringName) -> void:
	if node == null:
		return
	k.root.set_meta("recoil", node)
	k.root.set_meta("recoil_kind", kind)
	node.set_meta("rest", node.transform)


## A pennant: dark pole plus a family-coloured cloth, merged into the body.
static func pennant(k: Kit, pos: Vector3, height := 1.3, rot := 0.0) -> void:
	var pole := _cached_mesh("pole")
	var cloth := _cached_mesh("cloth")
	var b := Basis(Vector3.UP, rot)
	k.mesh(
		pole,
		Transform3D(b.scaled(Vector3(1, height, 1)), pos),
		UnitStyle.flat(Color(0.25, 0.17, 0.1)),
		true
	)
	var cloth_xf := Transform3D(b, pos + b * Vector3(0, height - 0.28, 0.27))
	k.mesh(cloth, cloth_xf, _cloth_mat(k.accent()), true)


## A glowing floating crystal (moving: added as a node, not merged).
static func crystal_node(parent: Node3D, pos: Vector3, size: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = UnitMeshes.crystal(0.0)
	mi.material_override = UnitStyle.glow(color, 1.8)
	mi.position = pos
	mi.scale = Vector3(size * 0.45, size, size * 0.45)
	mi.set_meta("detail", true)
	parent.add_child(mi)
	return mi


static func _cached_mesh(kind: String) -> Mesh:
	var key := "mesh_" + kind
	if _parts.has(key):
		return _parts[key]
	var m: Mesh
	if kind == "pole":
		var c := CylinderMesh.new()
		c.top_radius = 0.035
		c.bottom_radius = 0.045
		c.height = 1.0
		c.radial_segments = 6
		c.rings = 1
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(c, 0, Transform3D(Basis(), Vector3(0, 0.5, 0)))
		m = st.commit()
	else:
		var q := QuadMesh.new()
		q.size = Vector2(0.5, 0.42)
		q.orientation = PlaneMesh.FACE_X
		m = q
	_parts[key] = m
	return m


static func _cloth_mat(color: Color) -> StandardMaterial3D:
	var key := "cloth%s" % color
	if not _parts.has(key):
		var m := UnitStyle.flat(color, 0.9).duplicate() as StandardMaterial3D
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_parts[key] = m
	return _parts[key]
