class_name TowerRecipes
extends RefCounted
## What each tower is made of, per level (GDD §7). L2 and L3 add tiers,
## ornaments and glow; Epics get unique animated parts. Distances in metres;
## kit pieces are scaled by TowerVisuals.KIT. Tune the look here.

const ENV := TowerVisuals.ENV
const KIT := TowerVisuals.KIT
const ICE := Color(0.55, 0.9, 1.0)
const MOLTEN := Color(1.0, 0.42, 0.08)
const PLAGUE := Color(0.4, 1.0, 0.18)
const SHADOW := Color(0.66, 0.3, 1.0)
const RUNE := Color(1.0, 0.8, 0.3)
const CAULDRON := ENV + "quaternius_fantasy_props/Cauldron.glb"
const ANVIL := ENV + "quaternius_fantasy_props/Anvil.glb"
const BRAZIER := ENV + "kenney_graveyard_kit/fire-basket.glb"
const TENT := ENV + "kenney_nature_kit/tent_detailedOpen.glb"
const TREE := ENV + "kenney_nature_kit/tree_detailed.glb"
const OBELISK := ENV + "kenney_graveyard_kit/pillar-obelisk.glb"
const PILLAR := ENV + "kenney_graveyard_kit/pillar-large.glb"
const SKULL := ENV + "kaykit_halloween_bits/skull.glb"
const SPIKE := ENV + "kenney_nature_kit/rock_tallE.glb"
const ROCK := ENV + "kenney_nature_kit/rock_smallA.glb"
const SHARD := TowerVisuals.TD + "detail-crystal.glb"
## Small ornaments (UnitPerf tower-shadow-parts=details casts no shadow).
const DETAILS: Array[String] = [SKULL, SPIKE, ROCK, SHARD]
## Weapon pivot heights (kit units) where the projectile leaves.
const BALLISTA_MUZZLE := 0.41
const CANNON_MUZZLE := 0.38
const CATAPULT_MUZZLE := 0.45
const BALLISTA_BASES: Array[String] = [
	"tower-square-bottom-a.glb", "tower-square-bottom-b.glb", "tower-square-bottom-c.glb"
]
const WYRM_SEGMENTS := 18
const WYRM_TURNS := 1.6
const DOOM_PITCH := -0.7


static func make(k: TowerVisuals.Kit, id: StringName, lvl: int) -> void:
	match id:
		&"archer":
			_archer(k, lvl)
		&"cannon":
			_cannon(k, lvl)
		&"frost":
			_frost(k, lvl)
		&"plague":
			_plague(k, lvl)
		&"bard":
			_bard(k, lvl)
		&"runesmith":
			_runesmith(k, lvl)
		&"ballista":
			_ballista(k, lvl)
		&"demolisher":
			_demolisher(k, lvl)
		&"roots":
			_roots(k, lvl)
		&"shadow":
			_shadow(k, lvl)
		&"frost_wyrm":
			_frost_wyrm(k)
		&"doom_cannon":
			_doom_cannon(k)


static func _archer(k: TowerVisuals.Kit, lvl: int) -> void:
	k.stack("tower-round-base.glb")
	if lvl >= 2:
		k.stack("tower-round-bottom-a.glb" if lvl == 2 else "tower-round-bottom-b.glb")
	if lvl >= 3:
		k.stack("tower-round-middle-a.glb")
	k.stack("wood-structure-high.glb", 0.9)
	var floor_off := (0.28 if lvl >= 3 else 0.3) * KIT
	var base := k.stack("tower-round-top-c.glb" if lvl >= 3 else "tower-round-top-a.glb")
	var s := 0.68 + 0.06 * lvl
	var h := TowerVisuals.head(k, base + floor_off, BALLISTA_MUZZLE * KIT * s)
	if lvl >= 3:
		for side in [-1.0, 1.0]:
			var w := TowerVisuals.weapon(k, "weapon-ballista.glb", 0.52)
			w.position.x = side * 0.34
			h.add_child(w)
		TowerVisuals.recoil(k, h, &"kick")
	else:
		var w := TowerVisuals.weapon(k, "weapon-ballista.glb", s)
		h.add_child(w)
		TowerVisuals.recoil(k, w.find_child("arrow") as Node3D, &"bolt")
	_pennants(k, lvl, 0.72, k.y - 0.2)
	if lvl >= 3:
		TowerVisuals.crystal_node(k.root, Vector3(0, k.y + 0.1, -0.78), 0.3, k.accent())


static func _cannon(k: TowerVisuals.Kit, lvl: int) -> void:
	k.stack("tower-square-bottom-a.glb")
	if lvl >= 2:
		k.stack("tower-square-middle-a.glb")
	if lvl >= 3:
		k.stack("tower-square-middle-b.glb")
	k.stack("tower-square-top-a.glb" if lvl < 3 else "tower-square-top-b.glb")
	k.stack("tower-round-base.glb", 0.95)
	var s := 1.0 + 0.12 * (lvl - 1)
	var h := TowerVisuals.head(k, k.y, CANNON_MUZZLE * KIT * s)
	var w := TowerVisuals.weapon(k, "weapon-cannon.glb", s)
	h.add_child(w)
	TowerVisuals.recoil(k, w.find_child("barrel") as Node3D, &"barrel")
	if lvl >= 2:
		_pennants(k, lvl, 0.85, k.y - 0.5)
	if lvl >= 3:
		_spikes(k, k.y - 0.36)


static func _frost(k: TowerVisuals.Kit, lvl: int) -> void:
	k.stack("tower-round-base.glb")
	k.stack("tower-round-bottom-c.glb")
	if lvl >= 2:
		k.stack("tower-round-middle-c.glb")
	if lvl >= 3:
		k.stack("tower-round-middle-b.glb")
	k.stack("tower-round-crystals.glb")
	var orb := _float(k, k.y + 0.55, 0.0)
	var big := TowerVisuals.crystal_node(orb, Vector3.ZERO, 0.62 + 0.14 * lvl, ICE)
	k.spin.append([orb, 0.9])
	k.glow.append(big)
	if lvl >= 2:
		var ring := Node3D.new()
		ring.position.y = k.y + 0.5
		k.root.add_child(ring)
		for i in lvl:
			var a := TAU * i / lvl
			TowerVisuals.crystal_node(ring, Vector3(cos(a), 0, sin(a)) * 0.62, 0.28, ICE)
		k.spin.append([ring, -1.6])
	k.idle.append(&"frost_sparkle")


static func _plague(k: TowerVisuals.Kit, lvl: int) -> void:
	k.stack("tower-square-bottom-c.glb")
	if lvl >= 2:
		k.stack("tower-square-middle-c.glb")
	if lvl >= 3:
		k.stack("tower-square-middle-b.glb")
	k.stack("tower-round-base.glb", 0.95)
	var s := 0.76 + 0.06 * lvl
	var cy := k.y
	k.place(CAULDRON, Vector3(0, cy, 0), s)
	var tall := 0.82 * KIT * s
	var liquid := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.37 * KIT * s
	disc.bottom_radius = disc.top_radius
	disc.height = 0.05
	disc.radial_segments = 16
	disc.rings = 1
	liquid.mesh = disc
	liquid.material_override = UnitStyle.glow(PLAGUE, 2.2)
	liquid.position.y = cy + tall * 0.8
	liquid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	k.root.add_child(liquid)
	k.glow.append(liquid)
	k.root.set_meta("muzzle_height", cy + tall)
	if lvl >= 2:
		var n := 2 if lvl == 2 else 4
		for i in n:
			var a := PI * 0.25 + TAU * i / 4
			k.place(SKULL, Vector3(cos(a), 0, sin(a)) * 0.78 + Vector3(0, cy, 0), 0.2, -a)
	k.idle.append(&"bubbles")
	if lvl >= 3:
		k.idle.append(&"plague_fumes")


static func _bard(k: TowerVisuals.Kit, lvl: int) -> void:
	k.stack("tower-round-base.glb", 1.05)
	if lvl >= 2:
		k.stack("tower-round-bottom-a.glb", 0.95)
	if lvl >= 3:
		k.stack("tower-round-base.glb", 1.08)
	var s := 1.18 + 0.05 * lvl
	k.place(TENT, Vector3(0, k.y, 0), s, PI)
	var top := k.y + 0.56 * KIT * s
	k.root.set_meta("muzzle_height", top)
	_pennants(k, lvl + 1, 0.8, k.y - 0.1)
	if lvl >= 3:
		var orb := _float(k, top + 0.35, 0.0)
		k.glow.append(TowerVisuals.crystal_node(orb, Vector3.ZERO, 0.4, RUNE))
		k.spin.append([orb, 1.2])
	k.idle.append(&"notes")


static func _runesmith(k: TowerVisuals.Kit, lvl: int) -> void:
	k.stack("tower-square-bottom-b.glb")
	if lvl >= 2:
		k.stack("tower-square-middle-c.glb")
	if lvl >= 3:
		k.stack("tower-square-middle-a.glb")
	k.stack("tower-round-base.glb", 0.95)
	var y := k.y
	k.place(ANVIL, Vector3(0.1, y, 0.15), 0.6, 0.3)
	k.place(BRAZIER, Vector3(-0.5, y, -0.5), 1.1)
	var coals := MeshInstance3D.new()
	var coal := SphereMesh.new()
	coal.radius = 0.22
	coal.height = 0.2
	if UnitPerf.tower_lod() > 0.0:
		# The default sphere is 4 k triangles for a 0.4 m ember.
		coal.radial_segments = 12
		coal.rings = 6
	coals.mesh = coal
	coals.set_meta("detail", true)
	coals.material_override = UnitStyle.glow(MOLTEN, 3.0)
	coals.position = Vector3(-0.5, y + 0.22, -0.5)
	k.root.add_child(coals)
	k.glow.append(coals)
	var h := TowerVisuals.head(k, y + 1.25, 0.2)
	var hammer := MeshInstance3D.new()
	hammer.mesh = UnitMeshes.hammer()
	hammer.scale = Vector3.ONE * (0.95 + 0.12 * lvl)
	hammer.rotation.x = 0.5
	h.add_child(hammer)
	TowerVisuals.recoil(k, hammer, &"swing")
	if lvl >= 2:
		for i in 2 * (lvl - 1):
			var a := PI * 0.25 + TAU * i / 4
			k.place(SHARD, Vector3(cos(a), 0, sin(a)) * 0.72 + Vector3(0, y, 0), 0.9, a)
	if lvl >= 3:
		var ring := Node3D.new()
		ring.position.y = y + 1.25
		k.root.add_child(ring)
		for i in 3:
			var a := TAU * i / 3
			TowerVisuals.crystal_node(ring, Vector3(cos(a), 0, sin(a)) * 0.75, 0.22, RUNE)
		k.spin.append([ring, 1.4])
	k.idle.append(&"forge_embers")


static func _ballista(k: TowerVisuals.Kit, lvl: int) -> void:
	k.stack(BALLISTA_BASES[lvl - 1])
	if lvl >= 2:
		k.stack("tower-square-middle-c.glb")
	if lvl >= 3:
		k.stack("tower-square-middle-a.glb")
	k.stack("tower-square-top-c.glb")
	k.stack("tower-round-base.glb", 0.95)
	var s := 1.2 + 0.1 * (lvl - 1)
	var h := TowerVisuals.head(k, k.y, BALLISTA_MUZZLE * KIT * s)
	var w := TowerVisuals.weapon(k, "weapon-ballista.glb", s)
	h.add_child(w)
	TowerVisuals.recoil(k, w.find_child("arrow") as Node3D, &"bolt")
	if lvl >= 2:
		_pennants(k, lvl, 0.85, k.y - 0.5)
	if lvl >= 3:
		TowerVisuals.crystal_node(k.root, Vector3(0, k.y - 0.6, 0.98), 0.32, k.accent())


static func _demolisher(k: TowerVisuals.Kit, lvl: int) -> void:
	k.stack("tower-square-bottom-c.glb")
	if lvl >= 2:
		k.stack("tower-square-middle-b.glb")
	if lvl >= 3:
		k.stack("tower-square-middle-a.glb")
	k.stack("tower-round-base.glb", 1.05)
	var s := 1.3 + 0.1 * (lvl - 1)
	var h := TowerVisuals.head(k, k.y, CATAPULT_MUZZLE * KIT * s)
	var w := TowerVisuals.weapon(k, "weapon-catapult.glb", s)
	h.add_child(w)
	TowerVisuals.recoil(k, w.find_child("catapult") as Node3D, &"arm")
	if lvl >= 2:
		_pennants(k, lvl, 0.85, k.y - 0.36)
	if lvl >= 3:
		_spikes(k, k.y - 0.36)


static func _roots(k: TowerVisuals.Kit, lvl: int) -> void:
	k.stack("tower-round-base.glb", 1.1)
	var s := 1.12 + 0.16 * (lvl - 1)
	k.place(TREE, Vector3(0, k.y - 0.05, 0), s, 0.4 * lvl)
	k.root.set_meta("muzzle_height", k.y + 1.0)
	var n := 3 + lvl
	for i in n:
		var a := TAU * i / n + 0.3
		k.place(SHARD, Vector3(cos(a), 0, sin(a)) * 0.78 + Vector3(0, k.y, 0), 0.75 + 0.1 * lvl, a)
	if lvl >= 2:
		for i in 3:
			var a := TAU * i / 3 + 1.0
			k.place(ROCK, Vector3(cos(a), 0, sin(a)) * 0.55 + Vector3(0, k.y, 0), 0.9, a)
	if lvl >= 3:
		var ring := Node3D.new()
		ring.position.y = k.y + 2.0
		k.root.add_child(ring)
		for i in 4:
			var a := TAU * i / 4
			k.glow.append(
				TowerVisuals.crystal_node(ring, Vector3(cos(a), 0, sin(a)) * 1.0, 0.22, k.accent())
			)
		k.spin.append([ring, 0.7])
	k.idle.append(&"leaves")


static func _shadow(k: TowerVisuals.Kit, lvl: int) -> void:
	k.stack("tower-square-bottom-b.glb")
	if lvl >= 2:
		k.stack("tower-square-middle-c.glb")
	if lvl >= 3:
		k.stack("tower-square-middle-b.glb")
	k.stack("tower-round-base.glb", 0.9)
	var s := 1.45 + 0.1 * lvl
	k.place(OBELISK, Vector3(0, k.y, 0), s)
	var top := k.y + 1.01 * KIT * s
	var orb := _float(k, top + 0.45, 0.0)
	k.glow.append(TowerVisuals.crystal_node(orb, Vector3.ZERO, 0.5 + 0.1 * lvl, SHADOW))
	k.spin.append([orb, 1.1])
	if lvl >= 2:
		var n := 2 if lvl == 2 else 4
		for i in n:
			var a := PI * 0.25 + TAU * i / 4
			k.place(PILLAR, Vector3(cos(a), 0, sin(a)) * 0.72 + Vector3(0, k.y, 0), 0.75)
	k.idle.append(&"shadow_wisps")


static func _frost_wyrm(k: TowerVisuals.Kit) -> void:
	k.stack("tower-round-base.glb")
	k.stack("tower-round-bottom-c.glb")
	k.stack("tower-round-middle-c.glb")
	k.stack("tower-round-middle-b.glb")
	k.stack("tower-round-crystals.glb")
	var top := k.y
	var coil := Node3D.new()
	coil.name = "Coil"
	k.root.add_child(coil)
	for i in WYRM_SEGMENTS:
		var t := float(i) / (WYRM_SEGMENTS - 1)
		var pos := _helix(t, top)
		var tangent := (_helix(t + 0.02, top) - pos).normalized()
		var seg := Node3D.new()
		seg.position = pos
		seg.basis = Basis(Quaternion(Vector3.UP, tangent))
		seg.set_meta("base", pos)
		seg.set_meta("t", t)
		var size := 0.55 - 0.22 * t
		var mi := TowerVisuals.crystal_node(seg, Vector3.ZERO, size, ICE)
		mi.scale = Vector3(size * 0.7, size * 1.25, size * 0.7)
		coil.add_child(seg)
		k.coil.append(seg)
	var h := TowerVisuals.head(k, top + 0.45, 0.0)
	var skull := TowerVisuals.crystal_node(h, Vector3(0, 0, 0.15), 0.8, ICE)
	skull.rotation.x = PI * 0.5
	for side in [-1.0, 1.0]:
		var horn := TowerVisuals.crystal_node(
			h, Vector3(side * 0.22, 0.25, -0.15), 0.5, Color.WHITE
		)
		horn.rotation = Vector3(-0.6, 0, side * -0.5)
	k.glow.append(skull)
	k.idle.append(&"frost_mist")
	k.idle.append(&"frost_sparkle")


## The wyrm's spiral up the spire: t = 0 at the base, 1 at the head.
static func _helix(t: float, top: float) -> Vector3:
	var a := t * TAU * WYRM_TURNS
	var r := 1.02 - 0.3 * t
	return Vector3(cos(a) * r, 0.35 + t * (top - 0.1), sin(a) * r)


static func _doom_cannon(k: TowerVisuals.Kit) -> void:
	k.stack("tower-square-bottom-a.glb")
	k.stack("tower-square-middle-a.glb")
	k.stack("tower-square-middle-b.glb")
	k.stack("tower-square-top-b.glb")
	var strip := BoxMesh.new()
	strip.size = Vector3(0.1, k.y * 0.7, 0.04)
	for i in 4:
		var b := Basis(Vector3.UP, TAU * i / 4)
		k.mesh(strip, Transform3D(b, b * Vector3(0, k.y * 0.45, 0.96)), UnitStyle.glow(MOLTEN, 2.5))
	k.stack("tower-round-base.glb", 1.08)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.72
	torus.outer_radius = 0.86
	torus.rings = 24
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = UnitStyle.glow(MOLTEN, 3.0)
	ring.position.y = k.y + 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	k.root.add_child(ring)
	k.glow.append(ring)
	var s := 1.75
	var h := TowerVisuals.head(k, k.y, CANNON_MUZZLE * KIT * s + 0.5)
	var w := TowerVisuals.weapon(k, "weapon-cannon.glb", s)
	h.add_child(w)
	var barrel := w.find_child("barrel") as Node3D
	if barrel:
		barrel.rotation.x = DOOM_PITCH
	TowerVisuals.recoil(k, barrel, &"barrel")
	_spikes(k, k.y - 0.36)
	k.idle.append(&"embers")


## A floating node (no aiming) that also sets the muzzle height.
static func _float(k: TowerVisuals.Kit, y: float, muzzle: float) -> Node3D:
	var n := Node3D.new()
	n.position.y = y
	k.root.add_child(n)
	k.root.set_meta("muzzle_height", y + muzzle)
	return n


static func _pennants(k: TowerVisuals.Kit, count: int, radius: float, y: float) -> void:
	for i in count:
		var a := PI * 0.25 + TAU * i / maxi(count, 1)
		TowerVisuals.pennant(k, Vector3(cos(a), 0, sin(a)) * radius + Vector3(0, y, 0), 1.2, -a)


static func _spikes(k: TowerVisuals.Kit, y: float) -> void:
	var dark := UnitStyle.flat(Color(0.18, 0.14, 0.12), 0.7)
	for i in 4:
		var a := PI * 0.25 + TAU * i / 4
		k.place(SPIKE, Vector3(cos(a), 0, sin(a)) * 0.95 + Vector3(0, y, 0), 0.32, a, dark)
