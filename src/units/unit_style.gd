class_name UnitStyle
extends RefCounted
## Shared look for units and effects: family accent colours, the recoloured
## tower atlas, creep outlines and status washes, glow and additive materials.
## Everything is cached so thousands of nodes share a handful of materials.
## No custom shaders: built-in materials only (they can't fail to compile).

const FAMILY_COLORS := {
	&"alliance": Color(0.22, 0.48, 1.0),
	&"horde": Color(0.92, 0.2, 0.1),
	&"elven": Color(0.15, 0.85, 0.75),
	&"forsaken": Color(0.62, 0.28, 0.9),
	&"support": Color(1.0, 0.78, 0.22),
}
## Enemy team colour for creep silhouettes; bosses get their own.
const TEAM_OUTLINE := Color(1.0, 0.18, 0.08)
const BOSS_OUTLINE := Color(1.0, 0.72, 0.12)
## Outline width in screen pixels, converted to metres from camera distance.
const OUTLINE_PX := 2.2
const OUTLINE_MIN := 0.012
const OUTLINE_MAX := 0.09
const RIM_AMOUNT := 0.45
const RIM_TINT := 0.35
## Additive washes over a creep (GDD §6.4 statuses), strength is the alpha.
const STATUS_COLORS := {
	&"slow": Color(0.3, 0.62, 1.0, 0.45),
	&"poison": Color(0.3, 1.0, 0.15, 0.35),
	&"slow_poison": Color(0.2, 0.9, 0.8, 0.45),
	&"root": Color(0.45, 0.85, 0.15, 0.3),
	&"immune": Color(0.85, 0.9, 1.0, 0.5),
	&"flash": Color(1.0, 1.0, 1.0, 0.75),
}
## Kenney Tower Defense atlas: which palette cells take the family colour.
const ATLAS_HINT := "kenney_tower_defense_kit"
const ATLAS_STEP := 8
## Flat-coloured kit materials that take the family colour outright (tents).
const FLAT_ACCENTS: Array[String] = ["colorRed"]

static var _atlas := {}
static var _family_mats := {}
static var _creep_mats := {}
static var _outlined: Array[BaseMaterial3D] = []
static var _outline_scale: Array[float] = []
static var _cache := {}


static func family_color(family: StringName) -> Color:
	return FAMILY_COLORS.get(family, Color.WHITE)


## Flat lit material (cached by colour).
static func flat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var key := "flat%s%f%f" % [color, roughness, metallic]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		m.metallic = metallic
		_cache[key] = m
	return _cache[key]


## Lit material that also glows (HDR emission feeds the bloom).
static func glow(color: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "glow%s%f" % [color, energy]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.35
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		_cache[key] = m
	return _cache[key]


## Unshaded additive material; `tex` is optional (soft dots, rings).
static func additive(color: Color, tex: Texture2D = null, billboard := false) -> StandardMaterial3D:
	var key := "add%s%d%s" % [color, tex.get_instance_id() if tex else 0, billboard]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = color
		m.albedo_texture = tex
		m.disable_receive_shadows = true
		if billboard:
			m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			m.billboard_keep_scale = true
		_cache[key] = m
	return _cache[key]


## Unshaded alpha-blended material (smoke, HP bars, decal-like discs).
static func translucent(
	color: Color, tex: Texture2D = null, billboard := false, on_top := false
) -> StandardMaterial3D:
	var key := "tr%s%d%s%s" % [color, tex.get_instance_id() if tex else 0, billboard, on_top]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = color
		m.albedo_texture = tex
		m.disable_receive_shadows = true
		m.no_depth_test = on_top
		if billboard:
			m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			m.billboard_keep_scale = true
		_cache[key] = m
	return _cache[key]


## Particle quad material: unshaded, billboarded, coloured by the particle.
static func particle(tex: Texture2D, add := true, energy := 1.0) -> StandardMaterial3D:
	var key := "pt%d%s%f" % [tex.get_instance_id(), add, energy]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(energy, energy, energy)
		m.albedo_texture = tex
		m.disable_receive_shadows = true
		_cache[key] = m
	return _cache[key]


## Soft round dot (radial falloff), the base of most particles.
static func soft_dot() -> Texture2D:
	if not _cache.has("dot"):
		_cache["dot"] = _radial(
			PackedFloat32Array([0.0, 0.35, 1.0]),
			PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		)
	return _cache["dot"]


## A thin bright ring on transparent, for auras and shock rings.
static func ring_texture() -> Texture2D:
	if not _cache.has("ring"):
		_cache["ring"] = _radial(
			PackedFloat32Array([0.0, 0.55, 0.82, 0.92, 1.0]),
			PackedColorArray(
				[
					Color(1, 1, 1, 0),
					Color(1, 1, 1, 0.06),
					Color(1, 1, 1, 0.55),
					Color(1, 1, 1, 1),
					Color(1, 1, 1, 0)
				]
			)
		)
	return _cache["ring"]


static func _radial(offsets: PackedFloat32Array, colors: PackedColorArray) -> Texture2D:
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


# --- Towers -----------------------------------------------------------------


## The tower-kit atlas material recoloured to a family; other materials pass
## through unchanged.
static func family_material(src: Material, family: StringName) -> Material:
	var sm := src as StandardMaterial3D
	if sm == null:
		return src
	if sm.resource_name in FLAT_ACCENTS:
		return flat(family_color(family), sm.roughness)
	if sm.albedo_texture == null:
		return src
	if not sm.albedo_texture.resource_path.contains(ATLAS_HINT):
		return src
	var key := "%d:%s" % [src.get_instance_id(), family]
	if not _family_mats.has(key):
		var m := sm.duplicate() as StandardMaterial3D
		m.albedo_texture = _family_atlas(sm.albedo_texture, family)
		_family_mats[key] = m
	return _family_mats[key]


## Accent cells (red on round parts, purple on square ones) take the family
## hue; stone, wood and greenery keep theirs. The atlas is vertical gradient
## stripes, so one sample per ATLAS_STEP columns per row is exact enough.
static func _family_atlas(src: Texture2D, family: StringName) -> Texture2D:
	var key := "%d:%s" % [src.get_instance_id(), family]
	if _atlas.has(key):
		return _atlas[key]
	var img := src.get_image()
	if img == null or img.is_empty():
		return src
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	var target := family_color(family)
	for x in range(0, img.get_width(), ATLAS_STEP):
		var sx := mini(x + ATLAS_STEP / 2, img.get_width() - 1)
		for y in img.get_height():
			var c := img.get_pixel(sx, y)
			if _is_accent(c):
				var s := clampf(target.s * c.s / 0.65, 0.0, 1.0)
				var v := clampf(c.v * (0.75 + 0.35 * target.v), 0.0, 1.0)
				img.fill_rect(Rect2i(x, y, ATLAS_STEP, 1), Color.from_hsv(target.h, s, v))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_atlas[key] = tex
	return tex


static func _is_accent(c: Color) -> bool:
	var red := (c.h < 0.05 or c.h > 0.95) and c.s > 0.5 and c.g < c.r * 0.47
	var purple := c.h > 0.68 and c.h < 0.84 and c.s > 0.3
	return red or purple


# --- Creeps -----------------------------------------------------------------


## A creep material: the model's own look (optionally tinted) plus a stencil
## silhouette outline in team colour and a rim to separate it from the grass.
## `model_scale` lets the outline width stay constant in metres.
static func creep_material(
	src: Material, type: StringName, tint: Color, boss: bool, model_scale: float
) -> Material:
	var sm := src as StandardMaterial3D
	if sm == null:
		return src
	var key := "%s:%d" % [type, src.get_instance_id()]
	if not _creep_mats.has(key):
		var m := sm.duplicate() as StandardMaterial3D
		m.albedo_color = sm.albedo_color * tint
		m.rim_enabled = true
		m.rim = RIM_AMOUNT
		m.rim_tint = RIM_TINT
		m.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
		m.stencil_color = BOSS_OUTLINE if boss else TEAM_OUTLINE
		m.stencil_outline_thickness = 0.04 / model_scale
		_creep_mats[key] = m
		_outlined.append(m)
		_outline_scale.append(model_scale)
	return _creep_mats[key]


## The same material without outline, for creeps fading out after death.
static func plain_material(src: Material, type: StringName, tint: Color) -> Material:
	var sm := src as StandardMaterial3D
	if sm == null or tint == Color.WHITE:
		return src
	var key := "plain%s:%d" % [type, src.get_instance_id()]
	if not _creep_mats.has(key):
		var m := sm.duplicate() as StandardMaterial3D
		m.albedo_color = sm.albedo_color * tint
		_creep_mats[key] = m
	return _creep_mats[key]


## Keeps outlines about OUTLINE_PX wide whatever the zoom.
static func update_outlines(camera_distance: float, fov_deg: float, viewport_h: float) -> void:
	var px := 2.0 * camera_distance * tan(deg_to_rad(fov_deg) * 0.5) / maxf(viewport_h, 1.0)
	var world := clampf(OUTLINE_PX * px, OUTLINE_MIN, OUTLINE_MAX)
	for i in _outlined.size():
		_outlined[i].stencil_outline_thickness = world / _outline_scale[i]


static func status_overlay(kind: StringName) -> Material:
	if kind == &"":
		return null
	var c: Color = STATUS_COLORS[kind]
	return additive(Color(c.r * c.a, c.g * c.a, c.b * c.a, 1.0))
