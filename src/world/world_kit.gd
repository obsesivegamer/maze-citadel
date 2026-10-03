class_name WorldKit
extends RefCounted
## Model and texture plumbing shared by the world builders: cached loads,
## measured bounds (packs differ wildly in scale), meshes merged per material
## for MultiMesh, foliage materials that sway but keep the model's own
## textures, and looping copies of imported animations.

const ENV := "res://assets/environment/"
const CHARS := "res://assets/characters/"
const FOLIAGE_SHADER := preload("res://src/world/shaders/foliage.gdshader")
const FOLIAGE_CUTOUT_SHADER := preload("res://src/world/shaders/foliage_cutout.gdshader")
const WIND_DIR := Vector3(0.82, 0.0, -0.57)

static var _scenes := {}
static var _bounds := {}
static var _merged := {}
static var _trees := {}
static var _textures := {}
static var _mats := {}
static var _loops := {}


static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


static func instance(path: String) -> Node3D:
	return scene(path).instantiate() as Node3D


static func _local_xf(n: Node, root: Node) -> Transform3D:
	var t := Transform3D()
	var c := n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


static func _mesh_parts(path: String) -> Array:
	var root := scene(path).instantiate()
	var parts := []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh != null and mi.visible:
			parts.append([mi.mesh, _local_xf(mi, root), mi.name])
	root.free()
	return parts


## Bounds of a static model in its own space (unskinned meshes only).
static func bounds(path: String) -> AABB:
	if not _bounds.has(path):
		var box := AABB()
		var first := true
		for part in _mesh_parts(path):
			var b: AABB = part[1] * (part[0] as Mesh).get_aabb()
			box = b if first else box.merge(b)
			first = false
		_bounds[path] = box
	return _bounds[path]


## Uniform scale that makes the model `height` metres tall.
static func fit_height(path: String, height: float) -> float:
	return height / maxf(bounds(path).size.y, 0.001)


## Every surface of the model baked into one mesh, one surface per material,
## so a MultiMesh of it is one draw call per material. Nodes whose name
## contains a string in `skip` are left out (e.g. a wheel animated apart).
static func merged(path: String, skip: PackedStringArray = []) -> ArrayMesh:
	var key := path + str(skip)
	if not _merged.has(key):
		_merged[key] = bake([[path, Transform3D.IDENTITY]], skip)
	return _merged[key]


## Many placed models baked into one static mesh, one surface per material.
## Each entry is [path, transform] or [path, transform, material override].
static func bake(entries: Array, skip: PackedStringArray = []) -> ArrayMesh:
	var tools := {}
	for e in entries:
		for part in _mesh_parts(e[0]):
			var skipped := false
			for s in skip:
				skipped = skipped or String(part[2]).contains(s)
			if skipped:
				continue
			var mesh: Mesh = part[0]
			var xf: Transform3D = e[1] * part[1]
			for s in mesh.get_surface_count():
				var mat: Material = (
					e[2] if e.size() > 2 else mipmapped(mesh.surface_get_material(s))
				)
				if not tools.has(mat):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					tools[mat] = st
				(tools[mat] as SurfaceTool).append_from(mesh, s, xf)
	var out := ArrayMesh.new()
	for mat in tools:
		var st: SurfaceTool = tools[mat]
		st.set_material(mat)
		st.commit(out)
	return out


## The single mesh node at `node_name` inside a model, unmerged.
static func part(path: String, node_name: String) -> Array:
	for p in _mesh_parts(path):
		if p[2] == node_name:
			return p
	return []


## A tree or plant mesh whose materials sway in the wind. Keeps the source
## mesh's LODs, textures, colours and vertex colours. `flutter` adds leaf
## shiver on see-through (leaf) surfaces.
static func swaying(path: String, amp: float, flutter := 0.03) -> ArrayMesh:
	var key := "%s|%s|%s" % [path, amp, flutter]
	if _trees.has(key):
		return _trees[key]
	var src: ArrayMesh = _mesh_parts(path)[0][0]
	var mesh: ArrayMesh = src.duplicate()
	var height := maxf(src.get_aabb().end.y, 0.1)
	var cutouts: Array[bool] = []
	for s in src.get_surface_count():
		var base := src.surface_get_material(s) as BaseMaterial3D
		cutouts.append(base != null and base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED)
	# Bark = the opaque surfaces of a plant with leaf cards; grass and crops
	# are opaque single-sided blades and keep their detail and both faces.
	var bark: Array[bool] = []
	for c in cutouts:
		bark.append(not c and cutouts.has(true))
	var bark_lod := PerfFlags.get_int("nature-bark-lod", 0)
	if bark_lod > 0 and bark.has(true):
		mesh = FoliageVariants.with_lod(src, bark_lod, bark)
	var leaf_priority := PerfFlags.get_int("leaf-priority", 0)
	for s in mesh.get_surface_count():
		var base := src.surface_get_material(s) as BaseMaterial3D
		var cutout := cutouts[s]
		var m := ShaderMaterial.new()
		m.shader = FoliageVariants.shader(
			FOLIAGE_CUTOUT_SHADER if cutout else FOLIAGE_SHADER, bark[s]
		)
		if cutout and leaf_priority != 0:
			m.render_priority = leaf_priority
		if base != null:
			var tex := mipmapped_texture(base.albedo_texture)
			if tex != null:
				m.set_shader_parameter(&"albedo_tex", tex)
			m.set_shader_parameter(&"albedo", base.albedo_color)
			m.set_shader_parameter(&"use_vertex_color", base.vertex_color_use_as_albedo)
			m.set_shader_parameter(&"roughness", base.roughness)
			m.set_shader_parameter(&"scissor", base.alpha_scissor_threshold)
		m.set_shader_parameter(&"height", height)
		m.set_shader_parameter(&"amp", amp)
		m.set_shader_parameter(&"flutter", flutter if cutout else 0.0)
		m.set_shader_parameter(&"wind_dir", WIND_DIR)
		mesh.surface_set_material(s, m)
	_trees[key] = mesh
	return mesh


## The model's materials ship without mipmaps; distant foliage and roofs then
## shimmer. Rebuild the texture with mipmaps where the renderer allows it
## (no-op under the headless dummy renderer).
static func mipmapped_texture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _textures.has(tex):
		return _textures[tex]
	var out := tex
	var img := tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		if not img.has_mipmaps():
			img.generate_mipmaps()
			out = ImageTexture.create_from_image(img)
	_textures[tex] = out
	return out


static func mipmapped(mat: Material) -> Material:
	if not mat is BaseMaterial3D:
		return mat
	if _mats.has(mat):
		return _mats[mat]
	var bm := mat as BaseMaterial3D
	var out := bm
	var tex := mipmapped_texture(bm.albedo_texture)
	if tex != bm.albedo_texture:
		out = bm.duplicate()
		out.albedo_texture = tex
	_mats[mat] = out
	return out


static func texture(path: String) -> Texture2D:
	return mipmapped_texture(load(path) as Texture2D)


## Seamless greyscale noise (or a normal map from it) for shader detail.
static func noise_texture(
	size: int, frequency: float, seed_value: int, normal_map := false
) -> NoiseTexture2D:
	var key := "noise%d|%s|%d|%s" % [size, frequency, seed_value, normal_map]
	if _textures.has(key):
		return _textures[key]
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = size
	tex.height = size
	tex.seamless = true
	tex.noise = noise
	tex.as_normal_map = normal_map
	tex.bump_strength = 4.0
	_textures[key] = tex
	return tex


static func noise_texture_3d(size: int, frequency: float, seed_value: int) -> NoiseTexture3D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	var tex := NoiseTexture3D.new()
	tex.width = size
	tex.height = size
	tex.depth = size
	tex.seamless = true
	tex.noise = noise
	return tex


## One MultiMeshInstance3D for `xforms`. The list is shuffled first so that
## lowering visible_instance_count thins the set evenly (quality presets).
static func multimesh(
	mesh: Mesh, xforms: Array[Transform3D], shadows := true, seed_value := 1
) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(xforms.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := xforms[i]
		xforms[i] = xforms[j]
		xforms[j] = t
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	var box := AABB()
	var local := mesh.get_aabb()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		box = xforms[i] * local if i == 0 else box.merge(xforms[i] * local)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	# The headless dummy renderer can't read instance transforms back, so
	# headless perf probes cull and pick LODs from this instead.
	mmi.set_meta(&"bounds", box)
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


## Thins a MultiMesh to `fraction` of its instances.
static func thin(mmi: MultiMeshInstance3D, fraction: float) -> void:
	var mm := mmi.multimesh
	mm.visible_instance_count = roundi(mm.instance_count * clampf(fraction, 0.0, 1.0))


## Ground-standing transform: yaw, uniform scale, slight random tilt.
static func placed(pos: Vector3, yaw: float, scale: float, tilt := 0.0) -> Transform3D:
	var b := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	if tilt != 0.0:
		b = Basis(Vector3(cos(yaw), 0, sin(yaw)), tilt) * b
	return Transform3D(b, pos)


## A looping copy of `anim_name` added to `player` under the "world" library,
## so other users of the shared imported animation are unaffected.
static func loop_anim(player: AnimationPlayer, anim_name: StringName) -> StringName:
	var src := player.get_animation(anim_name)
	if src == null:
		return &""
	if not _loops.has(src):
		var copy: Animation = src.duplicate()
		copy.loop_mode = Animation.LOOP_LINEAR
		_loops[src] = copy
	if not player.has_animation_library(&"world"):
		player.add_animation_library(&"world", AnimationLibrary.new())
	var lib := player.get_animation_library(&"world")
	var clean := anim_name.replace("|", "_").replace("/", "_")
	if not lib.has_animation(clean):
		lib.add_animation(clean, _loops[src])
	return StringName("world/" + clean)


static func anim_player(n: Node) -> AnimationPlayer:
	var found := n.find_children("*", "AnimationPlayer", true, false)
	return found[0] if not found.is_empty() else null
