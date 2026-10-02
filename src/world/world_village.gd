class_name WorldVillage
extends Node3D
## The village and farms around the citadel (GDD §1, §12): KayKit blue-roofed
## huts, tavern and church south of the river, a farmstead on the east flank,
## the watermill on the west bank (its wheel turns), a windmill by the fields
## (its sails turn), a well, market stalls, fenced pastures and crop fields.
## Positions come from WorldLayout; this file decides looks.

const KK := "res://assets/environment/kaykit_medieval_hexagon/"
const KT := "res://assets/environment/kenney_fantasy_town_kit/"
const NK := "res://assets/environment/kenney_nature_kit/"
const GY := "res://assets/environment/kenney_graveyard_kit/"
const QP := "res://assets/environment/quaternius_fantasy_props/"
const HOUSES := {
	&"home_a": KK + "building_home_A_blue.glb",
	&"home_b": KK + "building_home_B_blue.glb",
	&"tavern": KK + "building_tavern_blue.glb",
	&"church": KK + "building_church_blue.glb",
	&"lumbermill": KK + "building_lumbermill_blue.glb",
	&"market": KK + "building_market_blue.glb",
	&"barracks": KK + "building_barracks_blue.glb",
}
const WATERMILL := KK + "building_watermill_blue.glb"
const WATERMILL_SCALE := 5.0
const WATERMILL_YAW := 90.0
const WHEEL_SPEED := 0.9
const WINDMILL := KK + "building_windmill_blue.glb"
const WINDMILL_SCALE := 6.0
const WINDMILL_YAW := -60.0
const SAIL_SPEED := 0.7
const WELL := KK + "building_well_blue.glb"
const WELL_SCALE := 4.2
const STALLS: Array[String] = [KT + "stall-red.glb", KT + "stall-green.glb"]
const STALL_SCALE := 2.8
const FENCE := NK + "fence_simple.glb"
const FENCE_SCALE := 2.6
const GRAIN := KK + "building_grain.glb"
const GRAIN_SCALE := Vector3(4.6, 2.6, 4.6)
const CROP := NK + "crops_wheatStageB.glb"
const CROP_SCALE := 2.4
const CROP_SPACING := 1.5
## Small props: [path, position, yaw°, scale].
const PROPS := [
	[KT + "cart.glb", Vector2(-4.5, 66), 30.0, 3.2],
	[KT + "cart.glb", Vector2(34.5, 18), 170.0, 3.0],
	[GY + "hay-bale.glb", Vector2(41, 18), 20.0, 3.2],
	[GY + "hay-bale.glb", Vector2(41.5, 16.4), -10.0, 3.2],
	[GY + "hay-bale-bundled.glb", Vector2(40.5, 20.5), 60.0, 3.0],
	[GY + "hay-bale.glb", Vector2(-30, 98), 80.0, 3.0],
	[QP + "Barrel.glb", Vector2(-7.5, 70), 0.0, 1.3],
	[QP + "Barrel.glb", Vector2(-6.4, 69.3), 40.0, 1.3],
	[QP + "Barrel_Apples.glb", Vector2(-0.5, 78.5), 10.0, 1.3],
	[QP + "Crate_Wooden.glb", Vector2(10.5, 88.5), 25.0, 1.2],
	[QP + "Crate_Wooden.glb", Vector2(-33.5, 16.5), 70.0, 1.2],
	[QP + "Bag.glb", Vector2(-33.2, 11.0), 0.0, 1.4],
	[KT + "lantern.glb", Vector2(3, 64), 0.0, 2.2],
	[KT + "lantern.glb", Vector2(-3, 64), 0.0, 2.2],
	[KT + "lantern.glb", Vector2(4.5, 46), 0.0, 2.2],
	["res://assets/environment/kenney_survival_kit/signpost.glb", Vector2(5, 51.5), -20.0, 4.5],
]

var _wheel := Node3D.new()
var _sails := Node3D.new()


func build() -> void:
	var entries := []
	for b in WorldLayout.BUILDINGS:
		var pos := _ground(b[1])
		entries.append([HOUSES[b[0]], WorldKit.placed(pos, deg_to_rad(b[2]), b[3])])
	entries.append([WELL, WorldKit.placed(_ground(WorldLayout.WELL), 0.3, WELL_SCALE)])
	for i in WorldLayout.STALLS.size():
		var s: Array = WorldLayout.STALLS[i]
		var t := WorldKit.placed(_ground(s[0]), deg_to_rad(s[1]), STALL_SCALE)
		entries.append([STALLS[i % STALLS.size()], t])
	for p in PROPS:
		entries.append([p[0], WorldKit.placed(_ground(p[1]), deg_to_rad(p[2]), p[3])])
	var mi := MeshInstance3D.new()
	mi.name = "Village"
	mi.mesh = WorldKit.bake(entries)
	add_child(mi)
	_build_watermill()
	_build_windmill()
	_build_fences()
	_build_fields()


func _process(delta: float) -> void:
	_wheel.rotate_object_local(Vector3.BACK, -WHEEL_SPEED * delta)
	_sails.rotate_object_local(Vector3.BACK, SAIL_SPEED * delta)


static func _ground(p: Vector2) -> Vector3:
	return WorldLayout.ground_point(p)


## The house is baked without its wheel; the wheel turns on its own pivot.
func _build_watermill() -> void:
	var root := Node3D.new()
	var p := WorldLayout.WATERMILL
	root.position = Vector3(p.x, WorldLayout.LOWLAND_Y, p.y)
	root.rotation.y = deg_to_rad(WATERMILL_YAW)
	root.scale = Vector3.ONE * WATERMILL_SCALE
	add_child(root)
	var house := MeshInstance3D.new()
	house.mesh = WorldKit.merged(WATERMILL, PackedStringArray(["wheel"]))
	root.add_child(house)
	var part := WorldKit.part(WATERMILL, "building_watermill_wheel_blue")
	if part.is_empty():
		return
	_wheel.transform = part[1]
	root.add_child(_wheel)
	var wheel := MeshInstance3D.new()
	wheel.mesh = part[0]
	_wheel.add_child(wheel)


func _build_windmill() -> void:
	var root := Node3D.new()
	root.position = _ground(WorldLayout.WINDMILL)
	root.rotation.y = deg_to_rad(WINDMILL_YAW)
	root.scale = Vector3.ONE * WINDMILL_SCALE
	add_child(root)
	var body := MeshInstance3D.new()
	body.mesh = WorldKit.merged(WINDMILL, PackedStringArray(["fan"]))
	root.add_child(body)
	var part := WorldKit.part(WINDMILL, "building_windmill_top_fan_blue")
	if part.is_empty():
		return
	_sails.transform = part[1]
	root.add_child(_sails)
	var fan := MeshInstance3D.new()
	fan.mesh = part[0]
	_sails.add_child(fan)


## Fence runs along each pasture's edges, with a gap facing the lane.
func _build_fences() -> void:
	var box := WorldKit.bounds(FENCE)
	var piece := box.size.x * FENCE_SCALE
	var center := box.get_center()
	var offset := Transform3D(Basis.IDENTITY, -Vector3(center.x, 0, center.z))
	var xforms: Array[Transform3D] = []
	for r: Rect2 in WorldLayout.PASTURES + WorldLayout.FIELDS.slice(0, 1):
		var c := [
			r.position,
			r.position + Vector2(r.size.x, 0),
			r.end,
			r.position + Vector2(0, r.size.y),
		]
		for side in 4:
			var a: Vector2 = c[side]
			var b: Vector2 = c[(side + 1) % 4]
			var n := maxi(1, roundi(a.distance_to(b) / piece))
			var dir := (b - a).normalized()
			var yaw := atan2(-dir.y, dir.x)
			for k in n:
				if side == 3 and k == n / 2:
					continue
				var mid := a + dir * (k + 0.5) * a.distance_to(b) / n
				var t := WorldKit.placed(_ground(mid), yaw, FENCE_SCALE) * offset
				xforms.append(t)
	add_child(WorldKit.multimesh(WorldKit.merged(FENCE), xforms))


## The east field (in the default frame) is KayKit grain tiles; the others
## are rows of swaying wheat.
func _build_fields() -> void:
	var grain: Array[Transform3D] = []
	var crops: Array[Transform3D] = []
	var gbox := WorldKit.bounds(GRAIN)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in WorldLayout.FIELDS.size():
		var r: Rect2 = WorldLayout.FIELDS[i]
		if i == 0:
			var w := gbox.size.x * GRAIN_SCALE.x
			var d := gbox.size.z * GRAIN_SCALE.z
			var nx := maxi(1, floori(r.size.x / w))
			var nz := maxi(1, floori(r.size.y / d))
			for gx in nx:
				for gz in nz:
					var p := (
						r.position + Vector2((gx + 0.5) * r.size.x / nx, (gz + 0.5) * r.size.y / nz)
					)
					var b := Basis.from_scale(
						GRAIN_SCALE * Vector3(r.size.x / nx / w, 1, r.size.y / nz / d)
					)
					grain.append(Transform3D(b, _ground(p)))
			continue
		var z := r.position.y + CROP_SPACING * 0.5
		while z < r.end.y:
			var x := r.position.x + CROP_SPACING * 0.5
			while x < r.end.x:
				var p := Vector2(x + rng.randf_range(-0.2, 0.2), z)
				crops.append(
					WorldKit.placed(
						_ground(p), rng.randf() * TAU, CROP_SCALE * rng.randf_range(0.85, 1.1)
					)
				)
				x += CROP_SPACING
			z += CROP_SPACING * 1.4
	add_child(WorldKit.multimesh(WorldKit.merged(GRAIN), grain))
	add_child(WorldKit.multimesh(WorldKit.swaying(CROP, 0.12), crops, false))
