class_name UnitFx
extends RefCounted
## Particle specs (see ParticleKit) for effects that live on units: creep
## steam, projectile trails and tower idle effects. Amounts are at 100%
## quality; Units scales them with Quality's particle budget.

const SPECS := {
	&"steam":
	{
		"key": "steam",
		"amount": 10,
		"lifetime": 1.3,
		"shape": "sphere",
		"radius": 0.15,
		"spread": 18.0,
		"vel": Vector2(1.2, 2.2),
		"gravity": Vector3(0, 0.6, 0),
		"damping": Vector2(0.5, 1.0),
		"scale": Vector2(0.5, 0.9),
		"grow": true,
		"color": Color(1, 1, 1, 0.7),
		"add": false,
	},
	&"shroud":
	{
		"key": "shroud",
		"amount": 26,
		"lifetime": 0.9,
		"shape": "sphere",
		"radius": 1.1,
		"vel": Vector2(0.2, 0.6),
		"scale": Vector2(1.0, 1.7),
		"grow": true,
		"color": Color(0.95, 0.97, 1.0, 0.6),
		"add": false,
		"size": 1.2,
	},
	&"smoke_trail":
	{
		"key": "smoke_trail",
		"amount": 24,
		"lifetime": 0.8,
		"vel": Vector2(0.0, 0.3),
		"gravity": Vector3(0, 0.5, 0),
		"scale": Vector2(0.35, 0.6),
		"grow": true,
		"color": Color(0.5, 0.5, 0.5, 0.65),
		"add": false,
		"bounds": 30.0,
	},
	&"dust_trail":
	{
		"key": "dust_trail",
		"amount": 14,
		"lifetime": 0.6,
		"vel": Vector2(0.0, 0.3),
		"scale": Vector2(0.3, 0.5),
		"grow": true,
		"color": Color(0.62, 0.5, 0.38, 0.5),
		"add": false,
		"bounds": 30.0,
	},
	&"frost_trail":
	{
		"key": "frost_trail",
		"amount": 22,
		"lifetime": 0.35,
		"vel": Vector2(0.0, 0.4),
		"scale": Vector2(0.14, 0.26),
		"color": Color(0.5, 0.85, 1.0),
		"energy": 2.0,
		"bounds": 30.0,
	},
	&"sun_trail":
	{
		"key": "sun_trail",
		"amount": 28,
		"lifetime": 0.45,
		"vel": Vector2(0.0, 0.3),
		"scale": Vector2(0.18, 0.34),
		"color": Color(1.0, 0.82, 0.35),
		"energy": 3.0,
		"bounds": 60.0,
	},
	&"plague_trail":
	{
		"key": "plague_trail",
		"amount": 18,
		"lifetime": 0.5,
		"vel": Vector2(0.0, 0.2),
		"gravity": Vector3(0, -5, 0),
		"scale": Vector2(0.1, 0.22),
		"color": Color(0.45, 1.0, 0.2),
		"energy": 1.6,
		"bounds": 30.0,
	},
	&"rune_trail":
	{
		"key": "rune_trail",
		"amount": 16,
		"lifetime": 0.35,
		"vel": Vector2(0.0, 0.5),
		"scale": Vector2(0.1, 0.2),
		"color": Color(1.0, 0.8, 0.3),
		"energy": 2.2,
		"bounds": 30.0,
	},
	&"bubbles":
	{
		"key": "bubbles",
		"amount": 10,
		"lifetime": 1.1,
		"shape": "sphere",
		"radius": 0.35,
		"spread": 12.0,
		"vel": Vector2(0.4, 0.9),
		"scale": Vector2(0.15, 0.35),
		"color": Color(0.45, 1.0, 0.25),
		"energy": 2.0,
	},
	&"plague_fumes":
	{
		"key": "plague_fumes",
		"amount": 8,
		"lifetime": 2.2,
		"shape": "sphere",
		"radius": 0.3,
		"spread": 20.0,
		"vel": Vector2(0.4, 0.8),
		"scale": Vector2(0.6, 1.1),
		"grow": true,
		"color": Color(0.3, 0.7, 0.15, 0.4),
		"add": false,
	},
	&"frost_sparkle":
	{
		"key": "frost_sparkle",
		"amount": 8,
		"lifetime": 1.2,
		"shape": "sphere",
		"radius": 0.55,
		"vel": Vector2(0.1, 0.3),
		"scale": Vector2(0.08, 0.16),
		"color": Color(0.6, 0.9, 1.0),
		"energy": 2.5,
	},
	&"sun_motes":
	{
		"key": "sun_motes",
		"amount": 10,
		"lifetime": 1.4,
		"shape": "sphere",
		"radius": 0.7,
		"vel": Vector2(0.15, 0.4),
		"scale": Vector2(0.08, 0.18),
		"color": Color(1.0, 0.85, 0.4),
		"energy": 3.0,
	},
	&"frost_mist":
	{
		"key": "frost_mist",
		"amount": 18,
		"lifetime": 2.6,
		"shape": "ring",
		"radius": 1.6,
		"inner": 0.8,
		"spread": 60.0,
		"vel": Vector2(0.1, 0.3),
		"scale": Vector2(1.2, 2.2),
		"grow": true,
		"color": Color(0.75, 0.9, 1.0, 0.35),
		"add": false,
		"size": 1.4,
	},
	&"embers":
	{
		"key": "embers",
		"amount": 12,
		"lifetime": 1.3,
		"shape": "sphere",
		"radius": 0.4,
		"spread": 25.0,
		"vel": Vector2(0.6, 1.4),
		"gravity": Vector3(0, 0.4, 0),
		"scale": Vector2(0.06, 0.12),
		"color": Color(1.0, 0.5, 0.1),
		"energy": 3.0,
	},
	&"forge_embers":
	{
		"key": "forge_embers",
		"amount": 8,
		"lifetime": 1.0,
		"shape": "sphere",
		"radius": 0.15,
		"spread": 20.0,
		"vel": Vector2(0.8, 1.6),
		"scale": Vector2(0.05, 0.1),
		"color": Color(1.0, 0.6, 0.15),
		"energy": 3.0,
	},
	&"shadow_wisps":
	{
		"key": "shadow_wisps",
		"amount": 10,
		"lifetime": 1.8,
		"shape": "ring",
		"radius": 0.6,
		"spread": 15.0,
		"vel": Vector2(0.3, 0.6),
		"scale": Vector2(0.3, 0.5),
		"grow": true,
		"color": Color(0.55, 0.2, 0.85),
		"energy": 1.6,
	},
	&"leaves":
	{
		"key": "leaves",
		"amount": 6,
		"lifetime": 3.0,
		"shape": "sphere",
		"radius": 1.1,
		"vel": Vector2(0.0, 0.2),
		"gravity": Vector3(0, -0.35, 0),
		"scale": Vector2(0.12, 0.22),
		"color": Color(0.45, 0.95, 0.5),
		"energy": 1.3,
	},
}
## Where each idle effect sits on its tower, as a fraction of muzzle height.
const IDLE_HEIGHT := {
	&"bubbles": 1.0,
	&"plague_fumes": 1.0,
	&"frost_sparkle": 1.0,
	&"sun_motes": 1.0,
	&"frost_mist": 0.05,
	&"embers": 0.9,
	&"forge_embers": 0.62,
	&"shadow_wisps": 0.85,
	&"leaves": 1.4,
	&"notes": 0.7,
}

static var _specs := {}


static func spec(effect: StringName) -> Dictionary:
	if _specs.has(effect):
		return _specs[effect]
	var s: Dictionary
	if effect == &"notes":
		s = {
			"key": "notes",
			"amount": 6,
			"lifetime": 2.6,
			"shape": "ring",
			"radius": 1.0,
			"spread": 15.0,
			"vel": Vector2(0.5, 0.9),
			"tangential": Vector2(0.2, 0.5),
			"scale": Vector2(0.35, 0.55),
			"color": Color(1.0, 0.85, 0.3),
			"mesh": UnitMeshes.note(),
			"mat": _note_material(),
		}
	elif effect == &"fire_trail":
		s = {
			"key": "fire_trail",
			"amount": 32,
			"lifetime": 0.5,
			"vel": Vector2(0.0, 0.4),
			"scale": Vector2(0.5, 0.9),
			"colors":
			ParticleKit.gradient(
				[Color(1.0, 0.9, 0.4, 1), Color(1.0, 0.4, 0.05, 0.9), Color(0.15, 0.1, 0.08, 0)]
			),
			"energy": 2.0,
			"bounds": 30.0,
		}
	else:
		s = SPECS[effect]
	_specs[effect] = s
	return s


static func _note_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.6, 1.6, 1.6)
	return m
