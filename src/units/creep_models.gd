class_name CreepModels
extends RefCounted
## Creep models (GDD §8) assembled from the character packs (see
## assets/characters/MANIFEST.json roles). Every model is scaled so its rest
## pose stands `height` metres tall, faces +Z and gets team-colour outlines.
##
## loop: run cycle · rate: its playback speed at the creep's base speed
## hit / hit_rate / hit_cooldown: flinch clip, limited so walking still reads
## death: clip played on `died` · fly: hover height in metres

const CHARS := "res://assets/characters/"
const MON := CHARS + "quaternius_ultimate_monsters/"
const KAY := CHARS + "kaykit_adventurers/"
const WOLF := CHARS + "quaternius_ultimate_animated_animals/Wolf.glb"
const RIDER := MON + "Orc_Blob.glb"
const STAFF := KAY + "staff.glb"

## Heights run ~25% above life size so creeps read at full zoom-out, the way
## Warcraft III units tower over their buildings.
const SPECS := {
	&"grunt":
	{
		"scene": MON + "Orc.glb",
		"height": 2.0,
		"loop": &"Run",
		"rate": 0.95,
		"death": &"Death",
		"hit": &"HitReact",
	},
	&"wolf_rider":
	{
		"scene": WOLF,
		"height": 1.62,
		"loop": &"Gallop",
		"rate": 1.0,
		"death": &"Death",
		"hit": &"Idle_HitReact1",
	},
	&"footman":
	{
		"scene": KAY + "Knight.glb",
		"height": 2.12,
		"loop": &"Running_A",
		"rate": 1.45,
		"death": &"Death_A",
		"hit": &"Block_Hit",
		"hit_rate": 2.2,
		"hit_cooldown": 1.0,
		"drop": ["1H_Sword_Offhand", "Badge_Shield", "Round_Shield", "Spike_Shield", "2H_Sword"],
	},
	&"priestess":
	{
		"scene": KAY + "Rogue.glb",
		"height": 2.0,
		"loop": &"Running_A",
		"rate": 1.35,
		"death": &"Death_A",
		"hit": &"Hit_A",
		"tint": Color(1.0, 0.96, 0.82),
		"drop": ["1H_Crossbow", "2H_Crossbow", "Knife", "Knife_Offhand", "Throwable"],
	},
	&"harpy":
	{
		"scene": MON + "Hywirl.glb",
		"height": 2.12,
		"loop": &"Fast_Flying",
		"rate": 1.0,
		"death": &"Death",
		"hit": &"HitReact",
		"fly": 4.0,
	},
	&"ghoul":
	{
		"scene": CHARS + "kaykit_skeletons/Skeleton_Minion.glb",
		"height": 1.94,
		"loop": &"Running_C",
		"rate": 1.5,
		"death": &"Death_C_Skeletons",
		"hit": &"Hit_A",
		"down": &"Death_C_Skeletons",
		"rise": &"Death_C_Skeletons_Resurrect",
	},
	&"steam_tank":
	{
		"scene": CHARS + "quaternius_animated_mech/Leela.glb",
		"height": 2.75,
		"loop": &"Walk",
		"rate": 1.3,
		"death": &"Death",
		"hit": &"HitRecieve_1",
		"hit_cooldown": 3.0,
	},
	&"ogre":
	{
		"scene": MON + "Yeti.glb",
		"height": 4.0,
		"loop": &"Walk",
		"rate": 1.15,
		"death": &"Death",
		"hit": &"HitReact",
		"hit_cooldown": 4.0,
		"tint": Color(1.0, 0.82, 0.66),
	},
	## The Ogre at 1.15×. Untinted by element: views are pooled and their
	## materials cached per creep type, so one tint per element would mean six
	## types' worth of both.
	&"guardian":
	{
		"scene": MON + "Yeti.glb",
		"height": 4.6,
		"loop": &"Walk",
		"rate": 1.15,
		"death": &"Death",
		"hit": &"HitReact",
		"hit_cooldown": 4.0,
		"tint": Color(1.0, 0.82, 0.66),
	},
	&"dreadlord":
	{
		"scene": MON + "Demon.glb",
		"height": 4.5,
		"loop": &"Walk",
		"rate": 1.0,
		"death": &"Death",
		"hit": &"HitReact",
		"hit_cooldown": 5.0,
		"cast": &"Weapon",
		"tint": Color(0.62, 0.36, 1.0),
	},
	&"felhound":
	{
		"scene": WOLF,
		"height": 1.44,
		"loop": &"Gallop",
		"rate": 0.9,
		"death": &"Death",
		"hit": &"Idle_HitReact1",
		"fel": true,
	},
}
const DEFAULT_HIT_RATE := 1.6
const DEFAULT_HIT_COOLDOWN := 2.2

## Wolf Rider: an Orc_Blob sits on the wolf's torso bone (wolf-model units).
const RIDER_BONE := "Torso"
const RIDER_HEIGHT := 0.85
const RIDER_OFFSET := Vector3(0.0, 0.22, -0.05)
## Felhound: fel-green hide with glowing eyes, by Wolf surface material name.
const FEL_COLORS := {
	"Main": Color(0.14, 0.28, 0.07),
	"Main_Light": Color(0.42, 0.95, 0.18),
	"Nose": Color(0.05, 0.08, 0.04),
	"Eyes_Black": Color(0.55, 1.0, 0.2),
}
const FEL_EYE_ENERGY := 6.0
const FEL_HIDE_ENERGY := 0.5
## Priestess staff: tip glow position in staff units, colour.
const STAFF_TIP := Vector3(0.03, 1.12, 0.0)
const STAFF_GLOW := Color(1.0, 0.85, 0.35)

static var _scenes := {}
static var _scales := {}
static var _looped := {}


class Rig:
	extends RefCounted
	var root: Node3D
	var ap: AnimationPlayer
	var rider_ap: AnimationPlayer
	var meshes: Array[MeshInstance3D] = []
	## Per mesh: outlined surface materials (alive) and plain ones (fading).
	var outlined: Array = []
	var plain: Array = []
	var height := 1.6
	var staff_glow: MeshInstance3D
	var type: StringName
	var tint := Color.WHITE
	var boss := false
	## Per mesh: source materials, model scale and outline flag, from which
	## status_set() builds emission-washed variants (UnitPerf creep-status).
	var sources: Array = []
	var scales: Array[float] = []
	var outline: Array[bool] = []
	var status_sets := {}


static func spec(type: StringName) -> Dictionary:
	return SPECS.get(type, SPECS[&"grunt"])


## Top of the creep above its feet, flying hover included.
static func top(type: StringName) -> float:
	var s := spec(type)
	return s.height + float(s.get("fly", 0.0))


static func build(type: StringName) -> Rig:
	var s := spec(type)
	var rig := Rig.new()
	rig.height = s.height
	var model: Node3D = _scene(s.scene).instantiate()
	for n in s.get("drop", []):
		var drop := model.find_child(n, true, false)
		if drop:
			drop.free()
	var sc := _scale_for(type, model)
	rig.root = Node3D.new()
	rig.root.name = String(type)
	model.scale = Vector3.ONE * sc
	rig.root.add_child(model)
	rig.ap = model.find_child("AnimationPlayer", true, false)
	_loop(rig.ap, s.loop)
	if type == &"wolf_rider":
		_add_rider(rig, model)
	elif type == &"priestess":
		_add_staff(rig, model)
	var boss := CreepDefs.is_boss(type)
	var tint: Color = s.get("tint", Color.WHITE)
	rig.type = type
	rig.tint = tint
	rig.boss = boss
	var outline_mode := UnitPerf.creep_outline()
	var shadow := UnitPerf.creep_shadow() == "mesh"
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi == rig.staff_glow:
			continue
		var outlined: Array[Material] = []
		var plain: Array[Material] = []
		var sources: Array[Material] = []
		var mesh_scale := sc * _rel_scale(mi, model)
		var outline := outline_mode == "stencil" or (outline_mode == "body" and mi.skin != null)
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if s.get("fel", false):
				src = _fel_material(src)
			sources.append(src)
			outlined.append(UnitStyle.creep_material(src, type, tint, boss, mesh_scale, outline))
			plain.append(UnitStyle.plain_material(src, type, tint))
			mi.set_surface_override_material(i, outlined[i])
		if not shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.meshes.append(mi)
		rig.outlined.append(outlined)
		rig.plain.append(plain)
		rig.sources.append(sources)
		rig.scales.append(mesh_scale)
		rig.outline.append(outline)
	return rig


## The rig's alive materials with `status` folded into their emission.
static func status_set(rig: Rig, status: StringName) -> Array:
	if not rig.status_sets.has(status):
		var sets := []
		for i in rig.meshes.size():
			var mats: Array[Material] = []
			for src: Material in rig.sources[i]:
				mats.append(
					UnitStyle.creep_material(
						src, rig.type, rig.tint, rig.boss, rig.scales[i], rig.outline[i], status
					)
				)
			sets.append(mats)
		rig.status_sets[status] = sets
	return rig.status_sets[status]


static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


## Rest-pose height of the meshes, measured once per type.
static func _scale_for(type: StringName, model: Node3D) -> float:
	if not _scales.has(type):
		var box := _bounds(model, model, Transform3D.IDENTITY)
		_scales[type] = spec(type).height / maxf(box.size.y, 0.01)
	return _scales[type]


static func _bounds(n: Node, root: Node3D, xf: Transform3D) -> AABB:
	var t := xf
	if n is Node3D and n != root:
		t = xf * (n as Node3D).transform
	var out := AABB()
	var first := true
	if n is MeshInstance3D:
		out = t * (n as MeshInstance3D).get_aabb()
		first = false
	for c in n.get_children():
		var b := _bounds(c, root, t)
		if b.size != Vector3.ZERO:
			out = b if first else out.merge(b)
			first = false
	return out


## Transform of `n` relative to `root` (works outside the scene tree).
static func rel_transform(n: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


static func _rel_scale(n: Node3D, root: Node3D) -> float:
	return rel_transform(n, root).basis.get_scale().y


## Run cycles ship as one-shot clips; loop them once per clip resource.
static func _loop(ap: AnimationPlayer, anim: StringName) -> void:
	if ap == null or not ap.has_animation(anim):
		return
	var a := ap.get_animation(anim)
	if not _looped.has(a):
		a.loop_mode = Animation.LOOP_LINEAR
		_looped[a] = true


static func _add_rider(rig: Rig, wolf: Node3D) -> void:
	var sk: Skeleton3D = wolf.find_children("*", "Skeleton3D", true, false)[0]
	var bone := sk.find_bone(RIDER_BONE)
	if bone < 0:
		return
	var attach := BoneAttachment3D.new()
	attach.bone_name = RIDER_BONE
	sk.add_child(attach)
	var rider: Node3D = _scene(RIDER).instantiate()
	var rider_h := _bounds(rider, rider, Transform3D.IDENTITY).size.y
	var wolf_scale := wolf.scale.y
	var s := RIDER_HEIGHT / maxf(rider_h, 0.01) / wolf_scale
	var rest := rel_transform(sk, wolf) * sk.get_bone_global_rest(bone)
	var want := Transform3D(Basis.from_scale(Vector3.ONE * s), rest.origin + RIDER_OFFSET)
	rider.transform = (rest.affine_inverse() * want).orthonormalized()
	rider.scale = Vector3.ONE * s
	attach.add_child(rider)
	rig.rider_ap = rider.find_child("AnimationPlayer", true, false)
	_loop(rig.rider_ap, &"Idle")


static func _add_staff(rig: Rig, rogue: Node3D) -> void:
	var slot: Node3D = rogue.find_child("handslot_r", true, false)
	if slot == null:
		return
	var staff: Node3D = _scene(STAFF).instantiate()
	slot.add_child(staff)
	var orb := SphereMesh.new()
	orb.radius = 0.13
	orb.height = 0.26
	orb.radial_segments = 12
	orb.rings = 6
	var glow := MeshInstance3D.new()
	glow.mesh = orb
	glow.material_override = UnitStyle.glow(STAFF_GLOW, 3.0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = STAFF_TIP
	staff.add_child(glow)
	rig.staff_glow = glow


static func _fel_material(src: Material) -> Material:
	var key := src.resource_name if src else ""
	if not FEL_COLORS.has(key):
		return src
	var c: Color = FEL_COLORS[key]
	if key == "Eyes_Black":
		return UnitStyle.glow(c, FEL_EYE_ENERGY)
	if key == "Main_Light":
		return UnitStyle.glow(c, FEL_HIDE_ENERGY)
	return UnitStyle.flat(c, 0.7)
