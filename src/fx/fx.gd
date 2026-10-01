class_name Fx
extends Node3D
## Combat juice driven by sim events (GDD §12). Skeleton version: floating
## damage numbers coloured by counter result and gold popups.

const COUNTER_COLORS := {
	&"strong": Color(1.0, 0.8, 0.15),
	&"weak": Color(0.6, 0.7, 0.85),
	&"neutral": Color(1, 1, 1),
	&"immune": Color(0.7, 0.75, 0.8),
}
const POOL_SIZE := 64
const LIFE := 0.9

var _game: Game
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
	game.sim_event.connect(_on_sim_event)


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
			if c != null:
				_pop(
					Coords.to_world(c.pos, 3.0), str(roundi(e.amount)), Color(0.5, 1.0, 0.4), false
				)
		&"shell_landed":
			_game.camera.add_shake(0.08 if e.tower == &"cannon" else 0.25)
		&"leaked":
			_game.camera.add_shake(0.15)
		&"died":
			if e.bounty > 0:
				_pop(Coords.to_world(e.pos, 2.5), "+%d" % e.bounty, Color(1.0, 0.85, 0.2), true)


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
