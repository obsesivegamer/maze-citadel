class_name WorldNature
extends Node3D
## Forests and ground cover around the citadel (GDD §1, §12): Quaternius
## pines and broadleaf trees swaying in the wind, dead trees in the portal's
## blight, bushes, grass tufts, flowers, rocks, lilies on the river and a ring
## of mountains on the horizon. Everything is MultiMesh, bucketed into
## CHUNK-metre cells so off-screen chunks are culled and far ones drop LOD.
## set_density() thins every set evenly for the quality presets.

const QN := "res://assets/environment/quaternius_stylized_nature/"
const KK := "res://assets/environment/kaykit_medieval_hexagon/"
const HB := "res://assets/environment/kaykit_halloween_bits/"
const NK := "res://assets/environment/kenney_nature_kit/"

const CHUNK := 64.0
const SEED := 99
## Each spec: models, sampling step (m), max radius, height range (m) or
## scale range, sway amplitude (m), casts shadows, max view distance (0 = any).
const PINES := {
	"models": [QN + "Pine_1.glb", QN + "Pine_2.glb", QN + "Pine_5.glb"],
	"step": 6.2,
	"radius": 185.0,
	"height": Vector2(6.5, 10.5),
	"sway": 0.22,
	"shadows": true,
	"view_range": 0.0,
}
const BROADLEAF := {
	"models": [QN + "CommonTree_3.glb", QN + "CommonTree_5.glb"],
	"step": 7.0,
	"radius": 150.0,
	"height": Vector2(6.0, 9.0),
	"sway": 0.28,
	"shadows": true,
	"view_range": 0.0,
}
const DEAD := {
	"models": [HB + "tree_dead_large.glb", HB + "tree_dead_medium.glb", HB + "tree_dead_small.glb"],
	"step": 5.0,
	"radius": 80.0,
	"height": Vector2(4.5, 8.5),
	"sway": 0.08,
	"shadows": true,
	"view_range": 0.0,
}
const BUSHES := {
	"models": [QN + "Bush_Common.glb", QN + "Bush_Common_Flowers.glb"],
	"step": 4.2,
	"radius": 120.0,
	"height": Vector2(1.1, 2.0),
	"sway": 0.07,
	"shadows": true,
	"view_range": 160.0,
}
const GRASS := {
	"models": [QN + "Grass_Common_Short.glb", QN + "Grass_Wispy_Short.glb"],
	"step": 2.3,
	"radius": 95.0,
	"height": Vector2(0.45, 0.85),
	"sway": 0.06,
	"shadows": false,
	"view_range": 120.0,
}
const FLOWERS := {
	"models": [QN + "Flower_3_Group.glb", QN + "Flower_4_Group.glb"],
	"step": 3.6,
	"radius": 95.0,
	"height": Vector2(0.7, 1.15),
	"sway": 0.07,
	"shadows": false,
	"view_range": 120.0,
}
const ROCKS := {
	"models": [QN + "Rock_Medium_1.glb", QN + "Rock_Medium_2.glb", QN + "Rock_Medium_3.glb"],
	"step": 9.0,
	"radius": 140.0,
	"height": Vector2(0.6, 1.8),
	"sway": 0.0,
	"shadows": true,
	"view_range": 0.0,
}
const LILY := NK + "lily_large.glb"
const LILY_COUNT := 26
const LILY_SCALE := Vector2(4.0, 7.0)
const MOUNTAINS: Array[String] = [
	KK + "mountain_A.glb", KK + "mountain_B.glb", KK + "mountain_C.glb"
]
const MOUNTAIN_COUNT := 26
const MOUNTAIN_RING := Vector2(270.0, 330.0)
const MOUNTAIN_SCALE := Vector2(30.0, 48.0)
## Lowland the default camera (106 m, pitch 58°, 40° fov) sees on a 16:9
## screen, plus ~6 m, for grass-offframe: a trapezoid from the near edge
## (z, half-width) to the far edge.
const VIEW_NEAR := Vector2(47.0, 63.0)
const VIEW_FAR := Vector2(-64.0, 97.0)

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _thinned: Array[MultiMeshInstance3D] = []
## Performance experiments (PerfFlags); the defaults are the shipped look.
## Chunk edge (m): smaller chunks cull and pick LODs closer to each tree.
var _chunk := PerfFlags.get_float("nature-chunk", CHUNK)
## Only plants this close to the plateau edge (m) cast shadows; 0 = all.
var _shadow_radius := PerfFlags.get_float("nature-shadow-radius", 0.0)
## Swaying leafy plants cast shadows from FoliageVariants.shadow_proxy hulls.
var _shadow_proxy := PerfFlags.get_bool("nature-shadow-proxy", false)
## Scales every set's planting radius; the random sequence is kept, so the
## nearer plants stay where they were.
var _radius_scale := PerfFlags.get_float("nature-radius-scale", 1.0)
## GeometryInstance3D.lod_bias for every set: < 1 drops to coarser LODs nearer.
var _lod_bias := PerfFlags.get_float("nature-lod-bias", 1.0)
## Visibility range (m) for the sets without one (trees, rocks); 0 = any.
var _tree_range := PerfFlags.get_float("nature-tree-range", 0.0)
## Small plants fade out at their range instead of popping. Off Metal they pop
## where the fade would end: a fading chunk draws in the transparent pass, which
## gives FSR 2 no depth or motion vectors, so its leaves flicker (issue #22).
var _fade := PerfFlags.get_bool(
	"nature-fade", RenderingServer.get_current_rendering_driver_name() == "metal"
)
## Share (0..1) of grass tufts and of flower clumps kept. Thinning drops the
## plants whose planting roll was highest, so the rest stay where they were.
var _grass_share := PerfFlags.get_float("grass-density", 1.0)
var _flower_share := PerfFlags.get_float("flower-density", 1.0)
## No grass or flowers beyond this distance (m) from the plateau's centre;
## 0 = the sets' own radius.
var _small_radius := PerfFlags.get_float("grass-radius", 0.0)
## Share (0..1) of grass and flowers kept outside the default camera's view.
var _offframe_share := PerfFlags.get_float("grass-offframe", 1.0)
## GeometryInstance3D.lod_bias for grass and flowers alone (< 1 = coarser
## LODs nearer); 0 = whatever nature-lod-bias gives every set.
var _small_lod_bias := PerfFlags.get_float("grass-lod-bias", 0.0)
## Visibility range (m) for grass and flowers; 0 = the sets' own.
var _small_range := PerfFlags.get_float("grass-range", 0.0)


func build() -> void:
	_rng.seed = SEED
	_noise.seed = SEED
	_noise.frequency = 0.035
	_scatter(PINES, _pine_density)
	_scatter(BROADLEAF, _broadleaf_density)
	_scatter(DEAD, _dead_density)
	_scatter(BUSHES, _bush_density)
	_scatter(GRASS, _grass_density, _small_keep.bind(_grass_share))
	_scatter(FLOWERS, _flower_density, _small_keep.bind(_flower_share))
	_scatter(ROCKS, _rock_density)
	_build_lilies()
	_build_mountains()


func set_density(fraction: float) -> void:
	for mmi in _thinned:
		WorldKit.thin(mmi, fraction)


## Probability (0..1) that a candidate point grows a pine.
func _pine_density(p: Vector2) -> float:
	if p.distance_to(WorldLayout.blight_center()) < WorldLayout.BLIGHT_RADIUS + 4.0:
		return 0.0
	var d := 0.12
	if p.y < -40.0:
		d = 0.95
	elif p.x < -50.0:
		d = 0.9
	elif p.x > 58.0:
		d = 0.85
	elif p.y > 120.0:
		d = 0.7
	elif p.x < -26.0:
		d = 0.25
	elif p.x > 26.0:
		d = 0.06
	if p.distance_to(WorldLayout.VILLAGE_CENTER) < 42.0:
		d *= 0.1
	var clump := smoothstep(-0.35, 0.3, _noise.get_noise_2d(p.x, p.y))
	return d * clump * (1.0 - 0.5 * smoothstep(120.0, 185.0, p.length()))


func _broadleaf_density(p: Vector2) -> float:
	var d := 0.03
	var v := p.distance_to(WorldLayout.VILLAGE_CENTER)
	if v > 16.0 and v < 48.0:
		d = 0.3
	var r := WorldLayout.river().distance_to(p)
	if r < 16.0:
		d = maxf(d, 0.28)
	if p.x > 26.0 and p.x < 60.0 and p.y > -45.0:
		d = maxf(d, 0.12)
	return d * smoothstep(-0.4, 0.2, -_noise.get_noise_2d(p.x * 0.7, p.y * 0.7))


func _dead_density(p: Vector2) -> float:
	var b := p.distance_to(WorldLayout.blight_center())
	return (
		0.55
		* (1.0 - smoothstep(WorldLayout.BLIGHT_RADIUS * 0.5, WorldLayout.BLIGHT_RADIUS + 6.0, b))
	)


func _bush_density(p: Vector2) -> float:
	var d := 0.05
	if WorldLayout.plateau_sdf(p) < WorldLayout.CLIFF_RUN + 7.0:
		d = 0.3
	if WorldLayout.river().distance_to(p) < 11.0:
		d = 0.35
	if WorldLayout.road_distance(p) < 6.0:
		d = maxf(d, 0.18)
	return d


func _grass_density(p: Vector2) -> float:
	return 0.55 * smoothstep(-0.5, 0.3, _noise.get_noise_2d(p.x * 2.0 + 50.0, p.y * 2.0))


func _flower_density(p: Vector2) -> float:
	var meadow := smoothstep(0.15, 0.55, _noise.get_noise_2d(p.x * 1.4 - 80.0, p.y * 1.4))
	if p.x > 26.0 and p.y > -45.0 and p.y < 40.0:
		meadow = maxf(meadow, 0.25)
	return 0.6 * meadow


func _rock_density(p: Vector2) -> float:
	var d := 0.12
	if p.distance_to(WorldLayout.blight_center()) < WorldLayout.BLIGHT_RADIUS + 6.0:
		d = 0.5
	return d


## Share (0..1) of a small-plant set kept at `p` by the grass-* experiments.
func _small_keep(p: Vector2, share: float) -> float:
	if _small_radius > 0.0 and p.length() > _small_radius:
		return 0.0
	if _offframe_share < 1.0:
		var t := (VIEW_NEAR.x - p.y) / (VIEW_NEAR.x - VIEW_FAR.x)
		if t < 0.0 or t > 1.0 or absf(p.x) > lerpf(VIEW_NEAR.y, VIEW_FAR.y, t):
			share *= _offframe_share
	return share


## Jittered-grid sampling of one set; points pass `density` and the layout's
## keep-out zones, then land in per-chunk, per-model MultiMeshes.
## `keep_share` (point → 0..1) marks a small-plant set for the grass-*
## experiments and thins it without moving the plants that stay.
func _scatter(spec: Dictionary, density: Callable, keep_share := Callable()) -> void:
	var models: Array = spec.models
	var step: float = spec.step
	var radius: float = spec.radius
	var size: Vector2 = spec.height
	var buckets := {}
	var margin := step * 0.35
	var cells := ceili(radius / step)
	var keep := radius * _radius_scale
	for gz in range(-cells, cells + 1):
		for gx in range(-cells, cells + 1):
			var p := Vector2(
				(gx + _rng.randf_range(-0.45, 0.45)) * step,
				(gz + _rng.randf_range(-0.45, 0.45)) * step
			)
			if p.length() > radius:
				continue
			var roll := _rng.randf()
			var chance: float = density.call(p)
			if roll >= chance or not WorldLayout.is_open(p, margin):
				continue
			var mi := _rng.randi() % models.size()
			var path: String = models[mi]
			var s := WorldKit.fit_height(path, _rng.randf_range(size.x, size.y))
			var pos := WorldLayout.ground_point(p) - Vector3(0, 0.1 * s, 0)
			var t := WorldKit.placed(pos, _rng.randf() * TAU, s, _rng.randf_range(-0.05, 0.05))
			if p.length() > keep:
				continue
			# A passing roll is uniform below `chance`, so this keeps the share.
			if keep_share.is_valid() and roll >= chance * keep_share.call(p):
				continue
			var cast: bool = (
				spec.shadows
				and (_shadow_radius <= 0.0 or WorldLayout.plateau_sdf(p) < _shadow_radius)
			)
			var key := Vector4i(mi, floori(p.x / _chunk), floori(p.y / _chunk), int(cast))
			if not buckets.has(key):
				buckets[key] = [] as Array[Transform3D]
			buckets[key].append(t)
	var sway: float = spec.sway
	for key: Vector4i in buckets:
		var path: String = models[key.x]
		var mesh: Mesh = WorldKit.swaying(path, sway) if sway > 0.0 else WorldKit.merged(path)
		var xforms: Array[Transform3D] = buckets[key]
		var seed_value := key.y * 31 + key.z
		var cast := key.w == 1
		if cast and _shadow_proxy and sway > 0.0 and FoliageVariants.has_leaves(mesh):
			# Same seed and starting order, so both shuffle alike and thin alike.
			var proxy := WorldKit.multimesh(
				FoliageVariants.shadow_proxy(mesh), xforms.duplicate(), true, seed_value
			)
			proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			add_child(proxy)
			_thinned.append(proxy)
			cast = false
		var mmi := WorldKit.multimesh(mesh, xforms, cast, seed_value)
		var small := keep_share.is_valid()
		var view_range: float = spec.view_range if spec.view_range > 0.0 else _tree_range
		if small and _small_range > 0.0:
			view_range = _small_range
		if view_range > 0.0:
			mmi.visibility_range_end = view_range
			mmi.visibility_range_end_margin = 20.0
			if spec.view_range > 0.0 and _fade:
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			elif spec.view_range > 0.0:
				mmi.visibility_range_end = view_range + 20.0
				mmi.visibility_range_end_margin = 0.0
		if _lod_bias != 1.0:
			mmi.lod_bias = _lod_bias
		if small and _small_lod_bias > 0.0:
			mmi.lod_bias = _small_lod_bias
		add_child(mmi)
		_thinned.append(mmi)


func _build_lilies() -> void:
	var river := WorldLayout.river()
	var xforms: Array[Transform3D] = []
	for i in LILY_COUNT:
		var s := _rng.randf_range(40.0, river.length * 0.45)
		var c := river.sample(s)
		var t := river.tangent(s)
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var off := Vector2(-t.y, t.x) * side * _rng.randf_range(3.2, 5.0)
		var pos := Vector3(c.x + off.x, WorldLayout.WATER_Y + 0.02, c.y + off.y)
		var sc := _rng.randf_range(LILY_SCALE.x, LILY_SCALE.y)
		xforms.append(WorldKit.placed(pos, _rng.randf() * TAU, sc))
	add_child(WorldKit.multimesh(WorldKit.merged(LILY), xforms, false))


func _build_mountains() -> void:
	var lists := {}
	for m in MOUNTAINS:
		lists[m] = [] as Array[Transform3D]
	for i in MOUNTAIN_COUNT:
		var a := TAU * i / MOUNTAIN_COUNT + _rng.randf_range(-0.08, 0.08)
		var r := _rng.randf_range(MOUNTAIN_RING.x, MOUNTAIN_RING.y)
		var p := Vector2(cos(a), sin(a)) * r
		var path: String = MOUNTAINS[_rng.randi() % MOUNTAINS.size()]
		var s := _rng.randf_range(MOUNTAIN_SCALE.x, MOUNTAIN_SCALE.y)
		var pos := WorldLayout.ground_point(p) - Vector3(0, 4.0, 0)
		lists[path].append(WorldKit.placed(pos, _rng.randf() * TAU, s))
	for path in lists:
		var mmi := WorldKit.multimesh(WorldKit.merged(path), lists[path], false)
		add_child(mmi)
