class_name WorldCrowd
extends Node3D
## The living backdrop (GDD §12): peasants walking the village loops, who
## cheer when a wave is cleared and run when a boss leaks; sheep grazing and
## hopping in their pastures; birds wheeling over the village; and gryphons
## that circle the citadel on victory. Counts scale with the Quality crowd
## budget via set_density().

const PEASANTS := [
	"res://assets/characters/quaternius_ultimate_animated_characters/Worker_Male.glb",
	"res://assets/characters/quaternius_ultimate_animated_characters/Worker_Female.glb",
]
const SHEEP := "res://assets/characters/quaternius_farm_animals/Sheep.fbx"
const BIRD := "res://assets/characters/quaternius_ultimate_monsters/Pigeon.glb"
const GRYPHON := "res://assets/characters/quaternius_animal_pack_vol2/Eagle.fbx"
const PEASANT_HEIGHT := 1.7
const SHEEP_HEIGHT := 1.0
const BIRD_HEIGHT := 0.6
const GRYPHON_HEIGHT := 1.6
const PEASANTS_PER_LOOP := 2
const SHEEP_PER_PASTURE := 6
const BIRDS := 6
const GRYPHONS := 3
const WALK_SPEED := 1.3
const RUN_SPEED := 4.0
const CHEER_TIME := 2.6
const FLEE_TIME := 5.0
const SHEEP_STEP := 1.2
const BIRD_ALT := Vector2(16, 24)
const BIRD_RADIUS := Vector2(14, 30)
const GRYPHON_ALT := 22.0
const GRYPHON_RADIUS := 34.0

var _peasants: Array[Dictionary] = []
var _sheep: Array[Dictionary] = []
var _birds: Array[Dictionary] = []
var _gryphons: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _time := 0.0


func build() -> void:
	_rng.seed = 41
	var i := 0
	for loop in WorldLayout.WALKS:
		var path := _closed(loop)
		for k in PEASANTS_PER_LOOP:
			var n := _actor(PEASANTS[i % PEASANTS.size()], PEASANT_HEIGHT)
			(
				_peasants
				. append(
					{
						"node": n,
						"path": path,
						"length": _length(path),
						"s": _rng.randf() * _length(path),
						"state": &"walk",
						"timer": 0.0,
					}
				)
			)
			_play(n, &"Walk")
			i += 1
	for rect: Rect2 in WorldLayout.PASTURES:
		for k in SHEEP_PER_PASTURE:
			var n := _actor(SHEEP, SHEEP_HEIGHT)
			var p := rect.position + Vector2(_rng.randf(), _rng.randf()) * rect.size
			n.position = WorldLayout.ground_point(p)
			n.rotation.y = _rng.randf() * TAU
			_sheep.append({"node": n, "rect": rect, "target": p, "timer": _rng.randf() * 4.0})
			_play(n, &"Armature|Idle")
	for k in BIRDS:
		var n := _actor(BIRD, BIRD_HEIGHT)
		_play(n, &"Fast_Flying")
		(
			_birds
			. append(
				{
					"node": n,
					"center": WorldLayout.VILLAGE_CENTER + Vector2(_rng.randf_range(-30, 30), 0),
					"radius": _rng.randf_range(BIRD_RADIUS.x, BIRD_RADIUS.y),
					"alt": _rng.randf_range(BIRD_ALT.x, BIRD_ALT.y),
					"phase": _rng.randf() * TAU,
					"speed": _rng.randf_range(0.25, 0.4),
				}
			)
		)
	for k in GRYPHONS:
		var n := _actor(GRYPHON, GRYPHON_HEIGHT)
		n.visible = false
		_play(n, &"EagleArmature|Flying")
		_gryphons.append({"node": n, "phase": TAU * k / GRYPHONS})


func set_density(fraction: float) -> void:
	for list in [_peasants, _sheep, _birds]:
		var keep := ceili(list.size() * clampf(fraction, 0.0, 1.0))
		for k in list.size():
			list[k].node.visible = k < keep


## Wave cleared: everyone on the lanes stops and cheers.
func cheer() -> void:
	for p in _peasants:
		if p.state != &"flee":
			p.state = &"cheer"
			p.timer = CHEER_TIME + _rng.randf() * 0.6
			_play(p.node, &"Victory", false)


## A boss got through the gate: the village runs.
func flee() -> void:
	for p in _peasants:
		p.state = &"flee"
		p.timer = FLEE_TIME
		_play(p.node, &"Run")


## Victory: gryphons circle the citadel.
func celebrate() -> void:
	for g in _gryphons:
		g.node.visible = true
	cheer()


func _process(delta: float) -> void:
	Prof.begin(&"crowd")
	_time += delta
	for p in _peasants:
		_update_peasant(p, delta)
	for s in _sheep:
		_update_sheep(s, delta)
	for b in _birds:
		var a: float = b.phase + _time * b.speed
		var c: Vector2 = b.center
		var pos := Vector3(c.x + cos(a) * b.radius, b.alt, c.y + sin(a) * b.radius)
		b.node.position = pos
		b.node.rotation.y = -a
	for g in _gryphons:
		if not g.node.visible:
			continue
		var a: float = g.phase + _time * 0.35
		g.node.position = Vector3(
			cos(a) * GRYPHON_RADIUS, GRYPHON_ALT + sin(a * 2.0) * 2.0, sin(a) * GRYPHON_RADIUS
		)
		g.node.rotation.y = -a
	Prof.end(&"crowd")


func _update_peasant(p: Dictionary, delta: float) -> void:
	if p.state != &"walk":
		p.timer -= delta
		if p.timer <= 0.0:
			p.state = &"walk"
			_play(p.node, &"Walk")
	if p.state == &"cheer":
		return
	var speed := RUN_SPEED if p.state == &"flee" else WALK_SPEED
	p.s = fmod(p.s + speed * delta, p.length)
	var at := _sample(p.path, p.s)
	var ahead := _sample(p.path, fmod(p.s + 0.5, p.length))
	var n: Node3D = p.node
	n.position = WorldLayout.ground_point(at)
	n.rotation.y = atan2(ahead.x - at.x, ahead.y - at.y)


func _update_sheep(s: Dictionary, delta: float) -> void:
	s.timer -= delta
	var n: Node3D = s.node
	var here := Vector2(n.position.x, n.position.z)
	var to: Vector2 = s.target - here
	if to.length() > 0.2:
		var step := minf(SHEEP_STEP * delta, to.length())
		here += to.normalized() * step
		n.position = WorldLayout.ground_point(here)
		n.rotation.y = atan2(to.x, to.y)
	elif s.timer <= 0.0:
		var rect: Rect2 = s.rect
		var next := here + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4))
		s.target = next.clamp(rect.position + Vector2.ONE, rect.end - Vector2.ONE)
		s.timer = _rng.randf_range(3.0, 8.0)
		_play(n, &"Armature|Jump", false)


func _actor(path: String, height: float) -> Node3D:
	var root := Node3D.new()
	var model := WorldKit.instance(path)
	var h := _model_height(model)
	if h > 0.0:
		model.scale = Vector3.ONE * (height / h)
	root.add_child(model)
	add_child(root)
	return root


## Height of a (possibly skinned) model from its meshes' rest-pose bounds.
static func _model_height(n: Node) -> float:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		b = _to_root(mi, n) * b
		box = b if first else box.merge(b)
		first = false
	return box.size.y


static func _to_root(node: Node, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur := node
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func _play(n: Node3D, anim: StringName, loop := true) -> void:
	var player := WorldKit.anim_player(n)
	if player == null or not player.has_animation(anim):
		return
	player.play(WorldKit.loop_anim(player, anim) if loop else anim, 0.25)


static func _closed(loop: Array) -> PackedVector2Array:
	var out := PackedVector2Array(loop)
	out.append(loop[0])
	return out


static func _length(path: PackedVector2Array) -> float:
	var total := 0.0
	for k in range(1, path.size()):
		total += path[k - 1].distance_to(path[k])
	return total


static func _sample(path: PackedVector2Array, s: float) -> Vector2:
	for k in range(1, path.size()):
		var seg := path[k - 1].distance_to(path[k])
		if s <= seg:
			return path[k - 1].lerp(path[k], s / maxf(seg, 0.001))
		s -= seg
	return path[path.size() - 1]
