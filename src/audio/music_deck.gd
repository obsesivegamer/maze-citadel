class_name MusicDeck
extends Node
## Two music players with an equal-power crossfade between them. Remembers
## where resumable tracks stopped, signals when a non-looping take is about
## to end, and ducks under the announcer and boss roars.

signal ending

const FADE := 1.5
const DUCK_DB := -9.0
const DUCK_RATE := 30.0
const SILENT_DB := -80.0

var _decks: Array[AudioStreamPlayer] = []
var _gain := PackedFloat32Array([0.0, 0.0])
var _level := PackedFloat32Array([0.0, 0.0])
var _resumable: Array[bool] = [false, false]
var _active := -1
var _ending_sent := false
var _next := {}
var _resume := {}
var _duck := 0.0
var _duck_until := 0.0
## Frame time in seconds; see AudioDirector._clock.
var _clock := 0.0


func _init() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		p.volume_db = SILENT_DB
		add_child(p)
		_decks.append(p)


## Fades out whatever plays now and fades `stream` in after `delay` seconds.
## A newer call before then replaces this one.
func play(stream: AudioStream, level_db: float, resume := false, delay := 0.0) -> void:
	_next = {"stream": stream, "db": level_db, "resume": resume, "at": _clock + delay}
	_active = -1


func duck(seconds: float) -> void:
	_duck_until = maxf(_duck_until, _clock + seconds)


func _process(delta: float) -> void:
	_clock += delta
	var now := _clock
	if not _next.is_empty() and now >= _next.at:
		_start(_next)
		_next = {}
	_duck = move_toward(_duck, DUCK_DB if now < _duck_until else 0.0, DUCK_RATE * delta)
	for i in 2:
		var p := _decks[i]
		_gain[i] = move_toward(_gain[i], 1.0 if i == _active else 0.0, delta / FADE)
		if _gain[i] <= 0.0 and i != _active and p.playing:
			_park(i)
		var amp := sin(_gain[i] * PI / 2.0)
		p.volume_db = maxf(_level[i] + linear_to_db(amp) + _duck, SILENT_DB)
	_check_ending()


func _start(n: Dictionary) -> void:
	var i := 0 if _gain[0] <= _gain[1] else 1
	_park(i)
	var p := _decks[i]
	p.stream = n.stream
	_level[i] = n.db
	_resumable[i] = n.resume
	var from: float = _resume.get(p.stream.resource_path, 0.0) if n.resume else 0.0
	p.play(from)
	_active = i
	_ending_sent = false


## Stops a deck, remembering where a resumable track was.
func _park(i: int) -> void:
	var p := _decks[i]
	if p.playing and _resumable[i]:
		_resume[p.stream.resource_path] = p.get_playback_position()
	p.stop()
	p.stream = null
	_gain[i] = 0.0


func _check_ending() -> void:
	if _active < 0 or _ending_sent:
		return
	var p := _decks[_active]
	var ogg := p.stream as AudioStreamOggVorbis
	if ogg == null or ogg.loop or not p.playing:
		return
	if ogg.get_length() - p.get_playback_position() <= FADE:
		_ending_sent = true
		_resumable[_active] = false
		_resume.erase(ogg.resource_path)
		ending.emit()


func _exit_tree() -> void:
	for p in _decks:
		p.stop()
		p.stream = null
