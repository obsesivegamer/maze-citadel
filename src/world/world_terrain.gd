class_name WorldTerrain
extends Node3D
## Ground under everything (GDD §1): the lowland heightfield with painted
## roads, banks and fields; the raised plateau whose top shows the build grid;
## the rock cliff skirt around it; the gate ramp; the river with its bridge;
## and boulders heaped at the cliff foot. The portal paving, gate ramp and
## blight follow the map's portal and gate.

const TEX := "res://assets/environment/"
const GRASS_A := TEX + "tex_pamnawi_handpainted_grass/grass_48.jpg"
const GRASS_B := TEX + "tex_pamnawi_handpainted_grass/grass_49.jpg"
const DIRT := TEX + "tex_rubberduck_handpainted/hp_earth_ground.jpg"
const SAND := TEX + "tex_drummyfish_ground/sand_8.jpg"
const ROCK := TEX + "tex_rubberduck_handpainted/hp_rock.jpg"
const ROCK_NORMAL := TEX + "tex_rubberduck_handpainted/hp_rock_norm.jpg"
const COBBLE := TEX + "tex_melle_stoneway/stone_way.jpg"
const ROAD_STONE := TEX + "tex_melle_stoneway/stone_way2.jpg"
const BRIDGE_MODEL := TEX + "kaykit_medieval_hexagon/building_bridge_A.glb"
const STONE_FENCE := TEX + "kaykit_medieval_hexagon/fence_stone_straight.glb"
const CLIFF_ROCKS: Array[String] = [
	TEX + "quaternius_stylized_nature/Rock_Medium_1.glb",
	TEX + "quaternius_stylized_nature/Rock_Medium_2.glb",
	TEX + "quaternius_stylized_nature/Rock_Medium_3.glb",
]

## Lowland mesh: GRID_N² vertices over ±EXTENT m, denser near the middle.
const EXTENT := 340.0
const GRID_N := 150
const WARP := 0.3
const GRASS_TINT := Color(1.0, 1.04, 0.86)
const MEADOW_TINT := Color(1.12, 1.06, 0.72)
const PLATEAU_GRASS_TINT := Color(1.08, 1.12, 0.9)
const CLIFF_TINT := Color(0.98, 0.9, 0.8)
const CLIFF_UV := 3.6
## Skirt profile from rim to foot: (fraction of the drop, fraction of CLIFF_RUN).
const SKIRT_ROWS: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(0.07, 0.06),
	Vector2(0.28, 0.13),
	Vector2(0.52, 0.24),
	Vector2(0.74, 0.44),
	Vector2(0.9, 0.7),
	Vector2(1.0, 0.92),
	Vector2(1.35, 1.05),
]
const SKIRT_BULGE := 0.75
const CLIFF_ROCK_SPACING := 3.3
const BRIDGE_SCALE := 6.5
const WATER_HALF_WIDTH := 6.3

## The board being drawn; its ruins darken the plateau under them, and a
## fixed lane is cobbled like the portal apron.
var grid: Grid

var _macro: NoiseTexture2D
var _rng := RandomNumberGenerator.new()
## Terrain shader cost (PerfFlags `terrain-cheap`): 0 = every texture read;
## 1 (shipped) = ground and plateau shaders skip the reads their masks don't
## need (same look); 2 = also the lowland's coarse macro noise per vertex
## instead of per pixel (grass blend edges shift slightly); 3 = also trilinear
## instead of anisotropic filtering on ground, plateau and cliffs (softer far
## ground).
var _cheap := PerfFlags.get_int("terrain-cheap", 1)


func build() -> void:
	_rng.seed = 21
	_macro = WorldKit.noise_texture(256, 0.02, 3)
	_build_lowland()
	_build_plateau()
	_build_skirt()
	_build_ramp()
	_build_river()
	_build_bridge()
	_build_cliff_rocks()
	# Diagnostic: hide named parts to price them (--pf-terrain-hide=Lowland,River).
	for part in PerfFlags.get_str("terrain-hide", "").split(",", false):
		var node := get_node_or_null(NodePath(part)) as Node3D
		if node != null:
			node.visible = false


## The stock shader, or its terrain-cheap twin; from level 3 sampled trilinear.
func _shader(stock: Shader, cheap: Shader) -> Shader:
	if _cheap <= 0:
		return stock
	if _cheap < 3:
		return cheap
	var s := Shader.new()
	s.code = cheap.code.replace("filter_linear_mipmap_anisotropic", "filter_linear_mipmap")
	return s


func _ground_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(
		preload("res://src/world/shaders/ground.gdshader"),
		preload("res://src/world/shaders/ground_cheap.gdshader")
	)
	m.set_shader_parameter(&"grass_a", WorldKit.texture(GRASS_A))
	m.set_shader_parameter(&"grass_b", WorldKit.texture(GRASS_B))
	m.set_shader_parameter(&"dirt", WorldKit.texture(DIRT))
	m.set_shader_parameter(&"sand", WorldKit.texture(SAND))
	m.set_shader_parameter(&"rock", WorldKit.texture(ROCK))
	m.set_shader_parameter(&"macro", _macro)
	m.set_shader_parameter(&"grass_tint", GRASS_TINT)
	m.set_shader_parameter(&"meadow_tint", MEADOW_TINT)
	if _cheap >= 2:
		m.set_shader_parameter(&"macro_from_uv", true)
	return m


static func _warp(u: float) -> float:
	return EXTENT * u * (WARP + (1.0 - WARP) * u * u)


func _build_lowland() -> void:
	var n := GRID_N
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(n * n)
	colors.resize(n * n)
	var river := WorldLayout.river()
	var blight := WorldLayout.blight_center()
	for j in n:
		var z := _warp(j * 2.0 / (n - 1) - 1.0)
		for i in n:
			var x := _warp(i * 2.0 / (n - 1) - 1.0)
			var p := Vector2(x, z)
			verts[j * n + i] = Vector3(x, WorldLayout.ground_y(x, z), z)
			var rd := WorldLayout.road_distance(p)
			var wd := river.distance_to(p)
			var hw := WorldLayout.RIVER_HALF_WIDTH
			colors[j * n + i] = Color(
				(
					1.0
					- smoothstep(
						WorldLayout.ROAD_HALF_WIDTH - 0.5, WorldLayout.ROAD_HALF_WIDTH + 0.9, rd
					)
				),
				1.0 - smoothstep(hw + 0.8, hw + WorldLayout.RIVER_BANK + 2.2, wd),
				(
					1.0
					- smoothstep(
						WorldLayout.BLIGHT_RADIUS * 0.35,
						WorldLayout.BLIGHT_RADIUS,
						p.distance_to(blight)
					)
				),
				1.0 if WorldLayout.in_rects(p, WorldLayout.FIELDS, -0.5) else 0.0
			)
	var normals := PackedVector3Array()
	normals.resize(n * n)
	for j in n:
		for i in n:
			var dx := verts[j * n + mini(i + 1, n - 1)] - verts[j * n + maxi(i - 1, 0)]
			var dz := verts[mini(j + 1, n - 1) * n + i] - verts[maxi(j - 1, 0) * n + i]
			normals[j * n + i] = dz.cross(dx).normalized()
	var idx := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	if _cheap >= 2:
		arrays[Mesh.ARRAY_TEX_UV] = _macro_per_vertex(verts)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _ground_material())
	var mi := MeshInstance3D.new()
	mi.name = "Lowland"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## The ground shader's coarse macro noise (texture at p × 0.004, ~50 m
## blobs) sampled at each vertex into UV.x, for ground_cheap.gdshader. The
## texture's image comes later from a thread, so rebuild it the same way now.
func _macro_per_vertex(verts: PackedVector3Array) -> PackedVector2Array:
	var img := _macro.noise.get_seamless_image(
		_macro.width,
		_macro.height,
		_macro.invert,
		_macro.in_3d_space,
		_macro.seamless_blend_skirt,
		_macro.normalize
	)
	img.convert(Image.FORMAT_L8)
	var data := img.get_data()
	var size := img.get_width()
	var uvs := PackedVector2Array()
	uvs.resize(verts.size())
	for i in verts.size():
		# Bilinear with wrap, texel centres at (k + 0.5) / size like the GPU.
		var x := verts[i].x * 0.004 * size - 0.5
		var y := verts[i].z * 0.004 * size - 0.5
		var x0 := floori(x)
		var y0 := floori(y)
		var fx := x - x0
		var fy := y - y0
		var xa := posmod(x0, size)
		var xb := posmod(x0 + 1, size)
		var ya := posmod(y0, size) * size
		var yb := posmod(y0 + 1, size) * size
		var top := lerpf(data[ya + xa], data[ya + xb], fx)
		var bottom := lerpf(data[yb + xa], data[yb + xb], fx)
		uvs[i] = Vector2(lerpf(top, bottom, fy) / 255.0, 0.0)
	return uvs


## The plateau rim as a closed loop with outward normals, walked SE → SW →
## NW → NE (clockwise seen from above, Godot's front-face winding).
static func outline(step: float) -> Array:
	var lo := WorldLayout.PLATEAU_MIN
	var hi := WorldLayout.PLATEAU_MAX
	var r := WorldLayout.PLATEAU_CORNER
	var corners := [
		[Vector2(hi.x - r, hi.y - r), 0.0],
		[Vector2(lo.x + r, hi.y - r), PI / 2],
		[Vector2(lo.x + r, lo.y + r), PI],
		[Vector2(hi.x - r, lo.y + r), PI * 1.5],
	]
	var out := []
	for c in corners.size():
		var center: Vector2 = corners[c][0]
		var start: float = corners[c][1]
		var arc_steps := maxi(2, ceili(r * PI / 2 / step))
		for k in arc_steps:
			var a := start + k * (PI / 2) / arc_steps
			var nrm := Vector2(cos(a), sin(a))
			out.append([center + nrm * r, nrm])
		var next_center: Vector2 = corners[(c + 1) % corners.size()][0]
		var a_end := start + PI / 2
		var nrm_end := Vector2(cos(a_end), sin(a_end))
		var from := center + nrm_end * r
		var to := next_center + nrm_end * r
		var edge_steps := maxi(1, ceili(from.distance_to(to) / step))
		for k in edge_steps:
			out.append([from.lerp(to, float(k) / edge_steps), nrm_end])
	return out


func _build_plateau() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Coords.PLATEAU_TOP
	var c := (WorldLayout.PLATEAU_MIN + WorldLayout.PLATEAU_MAX) * 0.5
	var ring := outline(2.0)
	st.set_normal(Vector3.UP)
	for k in ring.size():
		var a: Vector2 = ring[k][0]
		var b: Vector2 = ring[(k + 1) % ring.size()][0]
		st.add_vertex(Vector3(c.x, top, c.y))
		st.add_vertex(Vector3(a.x, top, a.y))
		st.add_vertex(Vector3(b.x, top, b.y))
	var m := ShaderMaterial.new()
	m.shader = _shader(
		preload("res://src/world/shaders/plateau.gdshader"),
		preload("res://src/world/shaders/plateau_cheap.gdshader")
	)
	m.set_shader_parameter(&"grass_a", WorldKit.texture(GRASS_A))
	m.set_shader_parameter(&"grass_b", WorldKit.texture(GRASS_B))
	m.set_shader_parameter(&"dirt", WorldKit.texture(DIRT))
	m.set_shader_parameter(&"cobble", WorldKit.texture(COBBLE))
	m.set_shader_parameter(&"macro", _macro)
	m.set_shader_parameter(&"grid_half", Vector2(Grid.WIDTH, Grid.DEPTH) * 0.5)
	m.set_shader_parameter(&"tile", Grid.TILE)
	m.set_shader_parameter(&"grass_tint", PLATEAU_GRASS_TINT)
	var px := Coords.portal().x
	var gx := WorldLayout.gate_x()
	m.set_shader_parameter(&"blight_center", Vector2(px, WorldLayout.PLATEAU_MIN.y + 2.0))
	m.set_shader_parameter(&"paved_north", Vector4(px - 2.0, -40.0, px + 2.0, -26.0))
	m.set_shader_parameter(&"paved_south", Vector4(gx - 2.0, 26.0, gx + 2.0, 40.0))
	if not grid.obstacles.is_empty():
		m.set_shader_parameter(&"ruins", _tile_mask(grid.obstacles.keys()))
		if _cheap > 0:
			m.set_shader_parameter(&"has_ruins", true)
	if not grid.lane.is_empty():
		m.set_shader_parameter(&"lane", _tile_mask(grid.lane))
		if _cheap > 0:
			m.set_shader_parameter(&"has_lane", true)
	st.set_material(m)
	var mi := MeshInstance3D.new()
	mi.name = "Plateau"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## One texel per tile, white on `tiles` (ruins, or a fixed lane); the plateau
## shader samples it with linear filtering so the trodden dirt fades out
## around each ruin and the road's corners round off.
func _tile_mask(tiles: Array) -> ImageTexture:
	var img := Image.create(Grid.COLS, Grid.ROWS, false, Image.FORMAT_L8)
	for t: Vector2i in tiles:
		img.set_pixelv(t, Color.WHITE)
	return ImageTexture.create_from_image(img)


func _rock_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = WorldKit.texture(ROCK)
	m.albedo_color = CLIFF_TINT
	m.normal_enabled = true
	m.normal_texture = WorldKit.texture(ROCK_NORMAL)
	m.roughness = 0.95
	m.texture_filter = (
		BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if _cheap >= 3
		else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	)
	return m


func _build_skirt() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 4
	noise.frequency = 0.22
	var ring := outline(1.0)
	var rows := SKIRT_ROWS.size()
	var drop := Coords.PLATEAU_TOP - WorldLayout.LOWLAND_Y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := 0.0
	for k in ring.size() + 1:
		var p: Vector2 = ring[k % ring.size()][0]
		var nrm: Vector2 = ring[k % ring.size()][1]
		if k > 0:
			s += p.distance_to(ring[k - 1][0])
		for r in rows:
			var prof := SKIRT_ROWS[r]
			var bulge := 0.0
			if r > 0 and r < rows - 1:
				bulge = noise.get_noise_2d(s, r * 3.0) * SKIRT_BULGE
			var out := prof.y * WorldLayout.CLIFF_RUN + bulge
			var y := Coords.PLATEAU_TOP - prof.x * drop
			if r > 1 and r < rows - 2:
				y += noise.get_noise_2d(s * 0.7 + 40.0, r) * 0.25
			var q := p + nrm * out
			st.set_uv(Vector2(s / CLIFF_UV, (prof.x * drop + out) / CLIFF_UV))
			st.add_vertex(Vector3(q.x, y, q.y))
	for k in ring.size():
		for r in rows - 1:
			var a := k * rows + r
			var b := (k + 1) * rows + r
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(b + 1)
	st.generate_normals()
	st.generate_tangents()
	st.set_material(_rock_material())
	var mi := MeshInstance3D.new()
	mi.name = "Cliffs"
	mi.mesh = st.commit()
	add_child(mi)


## Sloped road from the gate apron down to the lowland, with rock sides and
## low stone parapets.
func _build_ramp() -> void:
	var hw := WorldLayout.RAMP_HALF_WIDTH
	var gx := WorldLayout.gate_x()
	var z0 := WorldLayout.PLATEAU_MAX.y - 0.4
	var z1 := WorldLayout.RAMP_END_Z
	var top := Coords.PLATEAU_TOP
	var low := WorldLayout.ground_y(gx, z1) - 0.05
	var base := WorldLayout.LOWLAND_Y - 1.5
	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [
		Vector3(gx - hw, top, z0),
		Vector3(gx + hw, top, z0),
		Vector3(gx + hw, low, z1),
		Vector3(gx - hw, low, z1),
	]
	for i in [0, 1, 2, 0, 2, 3]:
		var v: Vector3 = corners[i]
		road.set_uv(Vector2(v.x, v.z) * 0.3)
		road.add_vertex(v)
	road.generate_normals()
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_texture = WorldKit.texture(ROAD_STONE)
	road_mat.roughness = 0.9
	road.set_material(road_mat)
	var mi := MeshInstance3D.new()
	mi.name = "Ramp"
	mi.mesh = road.commit()
	add_child(mi)
	var sides := SurfaceTool.new()
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx in [-1.0, 1.0]:
		var x: float = gx + sx * hw
		var quad := [
			Vector3(x, top, z0), Vector3(x, low, z1), Vector3(x, base, z1), Vector3(x, base, z0)
		]
		var order := [0, 2, 1, 0, 3, 2] if sx > 0 else [0, 1, 2, 0, 2, 3]
		for i in order:
			var v: Vector3 = quad[i]
			sides.set_uv(Vector2(v.z, -v.y) / CLIFF_UV)
			sides.add_vertex(v)
	sides.generate_normals()
	sides.generate_tangents()
	sides.set_material(_rock_material())
	var smi := MeshInstance3D.new()
	smi.mesh = sides.commit()
	add_child(smi)
	var fence := WorldKit.merged(STONE_FENCE)
	var fs := 3.4
	var seg := WorldKit.bounds(STONE_FENCE).size.z * fs
	var slope := atan2(top - low, z1 - z0)
	var xforms: Array[Transform3D] = []
	for sx in [-1.0, 1.0]:
		var z := z0 + seg * 0.5
		while z < z1 - seg * 0.3:
			var y := lerpf(top, low, (z - z0) / (z1 - z0))
			var b := Basis(Vector3.RIGHT, slope).scaled(Vector3.ONE * fs)
			xforms.append(Transform3D(b, Vector3(gx + sx * (hw - 0.35), y - 0.1, z)))
			z += seg
	add_child(WorldKit.multimesh(fence, xforms))


func _build_river() -> void:
	var river := WorldLayout.river()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := river.points.size()
	for i in n:
		var c := river.points[i]
		var t := river.tangent(river.lengths[i])
		var side := Vector2(-t.y, t.x) * WATER_HALF_WIDTH
		for k in 2:
			var q := c - side if k == 0 else c + side
			st.set_uv(Vector2(k, river.lengths[i]))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(q.x, WorldLayout.WATER_Y, q.y))
	for i in n - 1:
		var a := i * 2
		for v in [a, a + 2, a + 1, a + 1, a + 2, a + 3]:
			st.add_index(v)
	st.generate_tangents()
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/world/shaders/water.gdshader")
	m.set_shader_parameter(&"ripple", WorldKit.noise_texture(256, 0.03, 9, true))
	m.set_shader_parameter(&"foam_noise", WorldKit.noise_texture(256, 0.025, 13))
	m.set_shader_parameter(&"width", WATER_HALF_WIDTH * 2.0)
	st.set_material(m)
	var mi := MeshInstance3D.new()
	mi.name = "River"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_bridge() -> void:
	var b := WorldKit.instance(BRIDGE_MODEL)
	var deck := WorldKit.bounds(BRIDGE_MODEL).end.y * BRIDGE_SCALE
	b.scale = Vector3.ONE * BRIDGE_SCALE
	b.position = Vector3(
		WorldLayout.BRIDGE.x, WorldLayout.LOWLAND_Y - deck + 0.2, WorldLayout.BRIDGE.y
	)
	add_child(b)


## Boulders along the cliff foot and a few jutting from the face, so the
## plateau edge reads as rock from the top-down camera.
func _build_cliff_rocks() -> void:
	var lists := {}
	for path in CLIFF_ROCKS:
		lists[path] = [] as Array[Transform3D]
	var ring := outline(CLIFF_ROCK_SPACING)
	for k in ring.size():
		var p: Vector2 = ring[k][0]
		var nrm: Vector2 = ring[k][1]
		if absf(p.x - WorldLayout.gate_x()) < WorldLayout.RAMP_HALF_WIDTH + 2.5 and p.y > 0:
			continue
		var path: String = CLIFF_ROCKS[_rng.randi() % CLIFF_ROCKS.size()]
		var foot := p + nrm * (WorldLayout.CLIFF_RUN + _rng.randf_range(-0.3, 1.2))
		var y := WorldLayout.LOWLAND_Y - 0.5
		var yaw := _rng.randf() * TAU
		var s := _rng.randf_range(0.7, 1.35)
		lists[path].append(WorldKit.placed(Vector3(foot.x, y, foot.y), yaw, s, 0.15))
		if _rng.randf() < 0.45:
			var mid := p + nrm * WorldLayout.CLIFF_RUN * 0.45
			var y2 := Coords.PLATEAU_TOP - 2.6
			path = CLIFF_ROCKS[_rng.randi() % CLIFF_ROCKS.size()]
			var t := WorldKit.placed(Vector3(mid.x, y2, mid.y), yaw + 1.3, s * 0.75, 0.3)
			lists[path].append(t)
	for path in lists:
		add_child(WorldKit.multimesh(WorldKit.merged(path), lists[path], true, path.hash()))
