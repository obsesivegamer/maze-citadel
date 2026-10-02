class_name Fx
extends Node3D
## Combat juice driven by sim events (GDD §12): floating damage numbers
## coloured by counter result, gold popups, camera shake, and the impacts and
## flourishes in ImpactFx.

const COUNTER_COLORS := {
	&"strong": Color(1.0, 0.8, 0.15),
	&"weak": Color(0.6, 0.7, 0.85),
	&"neutral": Color(1, 1, 1),
	&"immune": Color(0.7, 0.75, 0.8),
}
const POOL_SIZE := 64
const LIFE := 0.9

var _game: Game
var _impacts := ImpactFx.new()
var _labels: Array[Label3D] = []
var _ages: PackedFloat32Array = []
var _next := 0


func setup(game: Game) -> void:
	_game = game
	for i in POOL_SIZE:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 64
		l.outline_size = 12
		l.pixel_size = 0.01
		l.visible = false
		add_child(l)
		_labels.append(l)
		_ages.append(LIFE)
	add_child(_impacts)
	_impacts.setup()
	game.sim_event.connect(_on_sim_event)
	game.quality_changed.connect(
		func(p: Quality.Preset) -> void: _impacts.set_quality_ratio(Quality.settings(p).particles)
	)


func _on_sim_event(e: Dictionary) -> void:
	match e.type:
		&"hit":
			var c := _game.sim.creep(e.id)
			if c != null:
				var text := "IMMUNE" if e.counter == &"immune" else str(roundi(e.amount))
				if e.counter == &"strong":
					text += "!"
				_pop(
					Coords.to_world(c.pos, 3.2),
					text,
					COUNTER_COLORS[e.counter],
					e.counter == &"strong"
				)
		&"dot":
			var c := _game.sim.creep(e.id)
			if c != null and not c.poison.is_empty():
				_impacts.burst(&"puff", Coords.to_world(c.pos, Coords.PLATEAU_TOP + 1.2), 1.0)
			if c != null:
				_pop(
					Coords.to_world(c.pos, 3.0), str(roundi(e.amount)), Color(0.5, 1.0, 0.4), false
				)
		&"shell_landed":
			_game.camera.add_shake(0.08 if e.tower == &"cannon" else 0.25)
			_shell(e)
		&"leaked":
			_game.camera.add_shake(0.15)
			_impacts.burst(&"poof", Coords.gate() + Vector3(0, 1.5, 0), 2.5)
			_impacts.burst(&"poof", Coords.portal() + Vector3(0, 2.5, 0), 2.5)
		&"nova":
			_impacts.burst(&"roots", _tile(e.tile, 0.3), e.radius)
		&"frost_ring":
			_impacts.burst(
				&"frost_ring", Coords.to_world(e.pos, Coords.PLATEAU_TOP + 0.4), e.radius
			)
		&"cloud":
			var t: float = TowerDefs.stat(&"shadow", "cloud_time")
			_impacts.linger(&"cloud", Coords.to_world(e.pos, Coords.PLATEAU_TOP + 0.3), e.radius, t)
		&"contagion":
			_impacts.burst(&"contagion", Coords.to_world(e.pos, Coords.PLATEAU_TOP + 0.6), e.radius)
		&"breath":
			var aim := Vector3(e.aim.x, 0, e.aim.y)
			_impacts.burst(&"breath", _tile(e.tile, 3.5) + aim * 1.5, 2.0, aim)
		&"built":
			_impacts.burst(&"dust", _tile(e.tile, 0.2))
		&"upgraded":
			_impacts.burst(&"sparkle", _tile(e.tile, 1.0))
		&"sold":
			_impacts.burst(&"coins", _tile(e.tile, 1.5))
		&"fused":
			_impacts.burst(&"fuse", _tile(e.tile, 2.0))
			_impacts.burst(&"dust", _tile(e.freed, 0.2))
		&"died":
			if e.get("boss", false):
				_game.camera.add_shake(0.6)
			if e.bounty > 0:
				_pop(Coords.to_world(e.pos, 2.5), "+%d" % e.bounty, Color(1.0, 0.85, 0.2), true)


func _tile(tile: Vector2i, height: float) -> Vector3:
	return Coords.tile_to_world(tile, Coords.PLATEAU_TOP + height)


## Explosion at the landing point, then a lingering scorch; demolisher and
## doom-cannon craters also burn for the sim crater's lifetime.
func _shell(e: Dictionary) -> void:
	var at := Coords.to_world(e.pos, Coords.PLATEAU_TOP + 0.3)
	_impacts.burst(&"flash", at + Vector3(0, 0.6, 0), e.radius)
	_impacts.burst(&"debris", at, e.radius)
	_impacts.burst(&"smoke", at + Vector3(0, 0.4, 0), e.radius)
	var burn: float = TowerDefs.stat(e.tower, "crater_time", 1, 0.0)
	_impacts.scorch(at, e.radius * 0.8, maxf(ImpactFx.SCORCH_TIME, burn + 1.0))
	if burn > 0.0:
		var r: float = TowerDefs.stat(e.tower, "crater_radius", 1, 2.0)
		_impacts.linger(&"fire", at, r, burn)


func _pop(pos: Vector3, text: String, color: Color, big: bool) -> void:
	var l := _labels[_next]
	_ages[_next] = 0.0
	_next = (_next + 1) % POOL_SIZE
	l.text = text
	l.modulate = color
	l.position = pos + Vector3(randf_range(-0.4, 0.4), 0, 0)
	l.font_size = 88 if big else 56
	l.visible = true


func _process(delta: float) -> void:
	for i in POOL_SIZE:
		if _ages[i] >= LIFE:
			continue
		_ages[i] += delta
		var l := _labels[i]
		l.position.y += delta * 1.8
		l.modulate.a = clampf(1.5 - _ages[i] / LIFE * 1.5, 0.0, 1.0)
		l.visible = _ages[i] < LIFE
