class_name UiUnitGlyphs
extends RefCounted
## Procedural icons for the 14 towers and 10 creep types (tower cards, wave
## chips, banner, plaque). Same unit-square conventions as UiGlyphs. Tower
## icons use their family colour; creep icons their own palette.

const TOWERS: Array[StringName] = [
	&"archer",
	&"cannon",
	&"frost",
	&"plague",
	&"bard",
	&"runesmith",
	&"ballista",
	&"demolisher",
	&"roots",
	&"shadow",
	&"frost_wyrm",
	&"doom_cannon",
	&"sunfire_ballista",
	&"plague_necropolis",
]
const CREEPS: Array[StringName] = [
	&"grunt",
	&"wolf_rider",
	&"footman",
	&"priestess",
	&"harpy",
	&"ghoul",
	&"steam_tank",
	&"ogre",
	&"dreadlord",
	&"felhound",
]
const ICE := Color(0.72, 0.92, 1.0)
const LEAF := Color(0.42, 0.82, 0.32)
const PLAGUE := Color(0.62, 0.95, 0.32)
const SHADOW_STONE := Color(0.26, 0.2, 0.32)
const BRASS := Color(0.86, 0.66, 0.3)
const HIDE := Color(0.62, 0.48, 0.34)
const FUR := Color(0.62, 0.6, 0.58)
const SUN := Color(1.0, 0.8, 0.32)


static func has(id: StringName) -> bool:
	return id in TOWERS or id in CREEPS


static func draw(ci: Object, id: StringName, r: Rect2, tint: Color) -> void:
	match id:
		&"archer":
			UiGlyphs.arc(
				ci, r, Vector2(0.78, 0.5), 0.46, PI * 0.72, PI * 1.28, UiGlyphs.WOOD * tint, 0.08
			)
			UiGlyphs.line(
				ci, r, Vector2(0.43, 0.15), Vector2(0.43, 0.85), UiGlyphs.BONE * tint, 0.025
			)
			UiGlyphs.line(
				ci, r, Vector2(0.86, 0.5), Vector2(0.24, 0.5), UiGlyphs.STEEL * tint, 0.05
			)
			UiGlyphs.poly(ci, r, [0.1, 0.5, 0.26, 0.4, 0.26, 0.6], _fam(&"alliance", tint))
			UiGlyphs.poly(ci, r, [0.8, 0.5, 0.92, 0.4, 0.92, 0.6], _fam(&"alliance", tint))
		&"cannon":
			_cannon(ci, r, tint, 1.0)
		&"frost":
			_snowflake(ci, r, ICE * tint)
		&"plague":
			_cauldron(ci, r, tint)
		&"bard":
			_notes(ci, r, _fam(&"support", tint))
		&"runesmith":
			_hammer(ci, r, tint)
		&"ballista":
			_crossbow(ci, r, tint)
		&"demolisher":
			_catapult(ci, r, tint)
		&"roots":
			_tree(ci, r, tint)
		&"shadow":
			_obelisk(ci, r, tint)
		&"frost_wyrm":
			_wyrm(ci, r, tint)
		&"doom_cannon":
			UiGlyphs.flame(
				ci,
				UiGlyphs.sub(r, 0.48, 0.0, 0.52),
				Color(1.0, 0.4, 0.15) * tint,
				UiGlyphs.COIN * tint
			)
			_cannon(ci, r, tint, 1.15)
		&"sunfire_ballista":
			_sunburst(ci, r, SUN * tint)
			_crossbow(ci, r, tint)
		&"plague_necropolis":
			_necropolis(ci, r, tint)
		&"grunt":
			_axe(ci, r, tint)
		&"wolf_rider":
			_wolf(ci, r, FUR * tint, tint)
		&"footman":
			UiGlyphs.shield(ci, r, Color(0.42, 0.58, 0.9) * tint, UiGlyphs.BONE * tint)
		&"priestess":
			_staff(ci, r, tint)
		&"harpy":
			UiGlyphs.wing(ci, r, Color(0.86, 0.55, 0.78) * tint)
		&"ghoul":
			_claws(ci, r, Color(0.7, 0.82, 0.62) * tint)
		&"steam_tank":
			UiGlyphs.gear(ci, r, BRASS * tint)
			UiGlyphs.dot(ci, r, Vector2(0.78, 0.2), 0.1, Color(1, 1, 1, 0.75) * tint)
			UiGlyphs.dot(ci, r, Vector2(0.9, 0.08), 0.07, Color(1, 1, 1, 0.55) * tint)
		&"ogre":
			_club(ci, r, tint)
		&"dreadlord":
			_demon(ci, r, tint)
		&"felhound":
			_paw(ci, r, UiGlyphs.FEL * tint)


static func _fam(family: StringName, tint: Color) -> Color:
	return UiTheme.FAMILY_COLORS[family] * tint


# --- Towers ---------------------------------------------------------------------


static func _cannon(ci: Object, r: Rect2, tint: Color, scale: float) -> void:
	var rr := Rect2(r.position + r.size * (1.0 - scale) * Vector2(0.5, 0.9), r.size * scale)
	UiGlyphs.poly(
		ci,
		rr,
		[0.14, 0.6, 0.66, 0.26, 0.76, 0.42, 0.24, 0.76],
		UiGlyphs.IRON.lightened(0.15) * tint
	)
	UiGlyphs.ring(ci, rr, Vector2(0.71, 0.34), 0.09, _fam(&"horde", tint), 0.05)
	UiGlyphs.poly(
		ci, rr, [0.18, 0.84, 0.66, 0.84, 0.6, 0.92, 0.24, 0.92], UiGlyphs.WOOD.darkened(0.2) * tint
	)
	UiGlyphs.dot(ci, rr, Vector2(0.36, 0.72), 0.16, UiGlyphs.WOOD * tint)
	UiGlyphs.dot(ci, rr, Vector2(0.36, 0.72), 0.05, UiGlyphs.IRON * tint)


static func _snowflake(ci: Object, r: Rect2, color: Color) -> void:
	var c := Vector2(0.5, 0.5)
	for i in 6:
		var a := TAU * i / 6.0 - PI / 2.0
		var d := Vector2(cos(a), sin(a))
		UiGlyphs.line(ci, r, c, c + d * 0.44, color, 0.065)
		var b := c + d * 0.28
		for s in [-1.0, 1.0]:
			UiGlyphs.line(ci, r, b, b + d.rotated(s * 0.8) * 0.13, color, 0.05)
	UiGlyphs.dot(ci, r, c, 0.09, color)


static func _cauldron(ci: Object, r: Rect2, tint: Color) -> void:
	UiGlyphs.dot(ci, r, Vector2(0.5, 0.6), 0.3, UiGlyphs.IRON * tint)
	UiGlyphs.line(ci, r, Vector2(0.3, 0.84), Vector2(0.26, 0.94), UiGlyphs.IRON * tint, 0.06)
	UiGlyphs.line(ci, r, Vector2(0.7, 0.84), Vector2(0.74, 0.94), UiGlyphs.IRON * tint, 0.06)
	UiGlyphs.poly(
		ci, r, [0.14, 0.38, 0.86, 0.38, 0.86, 0.46, 0.14, 0.46], UiGlyphs.IRON.lightened(0.2) * tint
	)
	UiGlyphs.poly(ci, r, [0.2, 0.38, 0.8, 0.38, 0.74, 0.32, 0.26, 0.32], PLAGUE * tint)
	UiGlyphs.dot(ci, r, Vector2(0.42, 0.22), 0.07, PLAGUE * tint)
	UiGlyphs.dot(ci, r, Vector2(0.6, 0.12), 0.05, PLAGUE * tint)
	UiGlyphs.dot(ci, r, Vector2(0.66, 0.26), 0.045, PLAGUE * tint)


static func _notes(ci: Object, r: Rect2, color: Color) -> void:
	UiGlyphs.dot(ci, r, Vector2(0.28, 0.74), 0.12, color)
	UiGlyphs.dot(ci, r, Vector2(0.7, 0.66), 0.12, color)
	UiGlyphs.line(ci, r, Vector2(0.39, 0.74), Vector2(0.39, 0.2), color, 0.06)
	UiGlyphs.line(ci, r, Vector2(0.81, 0.66), Vector2(0.81, 0.12), color, 0.06)
	UiGlyphs.poly(ci, r, [0.36, 0.16, 0.84, 0.06, 0.84, 0.18, 0.36, 0.28], color)


static func _hammer(ci: Object, r: Rect2, tint: Color) -> void:
	UiGlyphs.line(ci, r, Vector2(0.22, 0.9), Vector2(0.6, 0.38), UiGlyphs.WOOD * tint, 0.09)
	UiGlyphs.poly(ci, r, [0.4, 0.26, 0.66, 0.06, 0.9, 0.36, 0.64, 0.56], UiGlyphs.STEEL * tint)
	UiGlyphs.line(ci, r, Vector2(0.53, 0.16), Vector2(0.77, 0.46), _fam(&"support", tint), 0.05)
	UiGlyphs.star(ci, r, Vector2(0.2, 0.22), 0.14, 0.04, 4, UiTheme.ATTACK_COLORS[&"rune"] * tint)


static func _crossbow(ci: Object, r: Rect2, tint: Color) -> void:
	UiGlyphs.arc(ci, r, Vector2(0.5, 0.78), 0.46, PI * 1.2, PI * 1.8, UiGlyphs.WOOD * tint, 0.08)
	UiGlyphs.line(ci, r, Vector2(0.13, 0.51), Vector2(0.87, 0.51), UiGlyphs.BONE * tint, 0.025)
	UiGlyphs.line(
		ci, r, Vector2(0.5, 0.3), Vector2(0.5, 0.94), UiGlyphs.WOOD.darkened(0.2) * tint, 0.1
	)
	UiGlyphs.line(ci, r, Vector2(0.5, 0.62), Vector2(0.5, 0.16), UiGlyphs.STEEL * tint, 0.045)
	UiGlyphs.poly(ci, r, [0.5, 0.04, 0.6, 0.2, 0.4, 0.2], _fam(&"alliance", tint))


static func _catapult(ci: Object, r: Rect2, tint: Color) -> void:
	UiGlyphs.poly(
		ci, r, [0.1, 0.72, 0.9, 0.72, 0.9, 0.82, 0.1, 0.82], UiGlyphs.WOOD.darkened(0.15) * tint
	)
	UiGlyphs.dot(ci, r, Vector2(0.25, 0.84), 0.09, UiGlyphs.WOOD * tint)
	UiGlyphs.dot(ci, r, Vector2(0.75, 0.84), 0.09, UiGlyphs.WOOD * tint)
	UiGlyphs.line(ci, r, Vector2(0.5, 0.72), Vector2(0.42, 0.42), UiGlyphs.WOOD * tint, 0.07)
	UiGlyphs.line(
		ci, r, Vector2(0.3, 0.72), Vector2(0.76, 0.24), UiGlyphs.WOOD.lightened(0.1) * tint, 0.07
	)
	UiGlyphs.dot(ci, r, Vector2(0.8, 0.18), 0.13, Color(0.6, 0.57, 0.52) * tint)
	UiGlyphs.star(ci, r, Vector2(0.82, 0.16), 0.08, 0.03, 5, _fam(&"horde", tint))


static func _tree(ci: Object, r: Rect2, tint: Color) -> void:
	UiGlyphs.poly(ci, r, [0.43, 0.9, 0.57, 0.9, 0.55, 0.5, 0.45, 0.5], UiGlyphs.WOOD * tint)
	UiGlyphs.line(ci, r, Vector2(0.46, 0.86), Vector2(0.24, 0.94), UiGlyphs.WOOD * tint, 0.05)
	UiGlyphs.line(ci, r, Vector2(0.54, 0.86), Vector2(0.78, 0.94), UiGlyphs.WOOD * tint, 0.05)
	UiGlyphs.dot(ci, r, Vector2(0.32, 0.44), 0.2, LEAF.darkened(0.15) * tint)
	UiGlyphs.dot(ci, r, Vector2(0.68, 0.44), 0.2, LEAF.darkened(0.15) * tint)
	UiGlyphs.dot(ci, r, Vector2(0.5, 0.28), 0.24, LEAF * tint)
	UiGlyphs.dot(ci, r, Vector2(0.42, 0.22), 0.06, Color(1, 1, 1, 0.3) * tint)


static func _obelisk(ci: Object, r: Rect2, tint: Color) -> void:
	UiGlyphs.poly(
		ci, r, [0.28, 0.84, 0.72, 0.84, 0.76, 0.94, 0.24, 0.94], SHADOW_STONE.lightened(0.15) * tint
	)
	UiGlyphs.poly(
		ci, r, [0.38, 0.84, 0.62, 0.84, 0.57, 0.2, 0.5, 0.05, 0.43, 0.2], SHADOW_STONE * tint
	)
	UiGlyphs.dot(ci, r, Vector2(0.5, 0.44), 0.1, _fam(&"forsaken", tint))
	UiGlyphs.dot(ci, r, Vector2(0.5, 0.44), 0.04, UiGlyphs.FEL * tint)


static func _wyrm(ci: Object, r: Rect2, tint: Color) -> void:
	var pts := [0.08, 0.72, 0.22, 0.32, 0.48, 0.1, 0.92, 0.16, 0.76, 0.32]
	pts.append_array([0.84, 0.46, 0.64, 0.46, 0.68, 0.62, 0.46, 0.58, 0.42, 0.78])
	UiGlyphs.poly(ci, r, pts, ICE.darkened(0.2) * tint)
	for p in [Vector2(0.76, 0.32), Vector2(0.64, 0.46), Vector2(0.46, 0.58)]:
		UiGlyphs.line(ci, r, Vector2(0.22, 0.32), p, Color(1, 1, 1, 0.45) * tint, 0.025)
	UiGlyphs.star(ci, r, Vector2(0.78, 0.76), 0.2, 0.06, 6, ICE * tint)


## Rays fanning out behind a tower icon, centred high on the glyph.
static func _sunburst(ci: Object, r: Rect2, color: Color) -> void:
	var c := Vector2(0.5, 0.36)
	for i in 12:
		var a := TAU * i / 12.0
		var d := Vector2(cos(a), sin(a))
		UiGlyphs.line(ci, r, c + d * 0.3, c + d * (0.46 if i % 2 == 0 else 0.4), color, 0.05)
	UiGlyphs.ring(ci, r, c, 0.26, color, 0.06)


static func _necropolis(ci: Object, r: Rect2, tint: Color) -> void:
	_obelisk(ci, r, tint)
	for x in [0.16, 0.84]:
		UiGlyphs.poly(
			ci,
			r,
			[x - 0.07, 0.94, x + 0.07, 0.94, x + 0.06, 0.5, x - 0.06, 0.5],
			SHADOW_STONE.lightened(0.25) * tint
		)
		UiGlyphs.dot(ci, r, Vector2(x, 0.44), 0.08, UiGlyphs.BONE * tint)
	UiGlyphs.dot(ci, r, Vector2(0.5, 0.14), 0.11, PLAGUE * tint)
	UiGlyphs.dot(ci, r, Vector2(0.32, 0.26), 0.05, PLAGUE * tint)
	UiGlyphs.dot(ci, r, Vector2(0.68, 0.22), 0.04, PLAGUE * tint)


# --- Creeps ---------------------------------------------------------------------


static func _axe(ci: Object, r: Rect2, tint: Color) -> void:
	UiGlyphs.line(ci, r, Vector2(0.28, 0.92), Vector2(0.6, 0.12), UiGlyphs.WOOD * tint, 0.08)
	UiGlyphs.poly(
		ci, r, [0.52, 0.16, 0.86, 0.06, 0.92, 0.32, 0.8, 0.5, 0.58, 0.36], UiGlyphs.STEEL * tint
	)
	UiGlyphs.line(ci, r, Vector2(0.84, 0.1), Vector2(0.86, 0.46), Color(1, 1, 1, 0.5) * tint, 0.03)


static func _wolf(ci: Object, r: Rect2, color: Color, tint: Color) -> void:
	var pts := [0.18, 0.08, 0.38, 0.32, 0.62, 0.32, 0.82, 0.08, 0.8, 0.5]
	pts.append_array([0.62, 0.72, 0.5, 0.92, 0.38, 0.72, 0.2, 0.5])
	UiGlyphs.poly(ci, r, pts, color)
	UiGlyphs.dot(ci, r, Vector2(0.38, 0.5), 0.05, Color(1.0, 0.85, 0.3) * tint)
	UiGlyphs.dot(ci, r, Vector2(0.62, 0.5), 0.05, Color(1.0, 0.85, 0.3) * tint)
	UiGlyphs.dot(ci, r, Vector2(0.5, 0.86), 0.05, UiGlyphs.INK * tint)


static func _staff(ci: Object, r: Rect2, tint: Color) -> void:
	UiGlyphs.line(ci, r, Vector2(0.5, 0.95), Vector2(0.5, 0.38), UiGlyphs.COIN * tint, 0.07)
	var moon := UiGlyphs.sub(r, 0.18, 0.02, 0.5)
	UiGlyphs.draw(ci, &"el_dark", moon, Color(1.6, 1.6, 1.2) * tint)
	UiGlyphs.star(ci, r, Vector2(0.72, 0.24), 0.12, 0.04, 4, Color(1.0, 0.96, 0.8) * tint)


static func _claws(ci: Object, r: Rect2, color: Color) -> void:
	for i in 3:
		var x := 0.18 + i * 0.22
		UiGlyphs.poly(ci, r, [x, 0.12, x + 0.1, 0.12, x + 0.3, 0.88, x + 0.24, 0.9], color)


static func _club(ci: Object, r: Rect2, tint: Color) -> void:
	UiGlyphs.poly(ci, r, [0.16, 0.84, 0.26, 0.94, 0.86, 0.38, 0.7, 0.1, 0.52, 0.26], HIDE * tint)
	for p in [Vector2(0.72, 0.16), Vector2(0.84, 0.34), Vector2(0.58, 0.26), Vector2(0.7, 0.42)]:
		UiGlyphs.dot(ci, r, p, 0.045, UiGlyphs.BONE * tint)


static func _demon(ci: Object, r: Rect2, tint: Color) -> void:
	var horn := Color(0.3, 0.22, 0.2) * tint
	UiGlyphs.poly(ci, r, [0.32, 0.5, 0.42, 0.42, 0.24, 0.24, 0.12, 0.06, 0.16, 0.3], horn)
	UiGlyphs.poly(ci, r, [0.68, 0.5, 0.58, 0.42, 0.76, 0.24, 0.88, 0.06, 0.84, 0.3], horn)
	UiGlyphs.dot(ci, r, Vector2(0.5, 0.6), 0.26, Color(0.48, 0.24, 0.52) * tint)
	UiGlyphs.poly(ci, r, [0.32, 0.56, 0.46, 0.6, 0.34, 0.64], UiGlyphs.FEL * tint)
	UiGlyphs.poly(ci, r, [0.68, 0.56, 0.54, 0.6, 0.66, 0.64], UiGlyphs.FEL * tint)
	UiGlyphs.line(ci, r, Vector2(0.4, 0.76), Vector2(0.6, 0.76), UiGlyphs.INK * tint, 0.04)


static func _paw(ci: Object, r: Rect2, color: Color) -> void:
	UiGlyphs.dot(ci, r, Vector2(0.5, 0.66), 0.21, color)
	UiGlyphs.dot(ci, r, Vector2(0.22, 0.42), 0.09, color)
	UiGlyphs.dot(ci, r, Vector2(0.38, 0.24), 0.1, color)
	UiGlyphs.dot(ci, r, Vector2(0.62, 0.24), 0.1, color)
	UiGlyphs.dot(ci, r, Vector2(0.78, 0.42), 0.09, color)
