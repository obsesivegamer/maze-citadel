class_name AudioDirector
extends Node
## The match soundscape (GDD §13). Sim events become positional sounds through
## the mix table in AudioMix; music crossfades by match state (MusicDeck); the
## announcer calls waves, bosses and the result; ambience beds sit at points
## around the citadel. Sounds come from assets/audio/MANIFEST.json by event id,
## each levelled by AudioTrims. The current Camera3D is the listener.

const MANIFEST := "res://assets/audio/MANIFEST.json"
const AUDIO_DIR := "assets/audio/"
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"UI", &"Ambience"]
const WORLD_VOICES := 28
const FLAT_VOICES := 10
## Inverse-distance reference: about 0 dB at the full-board camera (65-100 m
## from the plateau), up to CLOSE_BOOST_DB louder from the close presets.
const WORLD_UNIT := 60.0
const BED_UNIT := 40.0
const CLOSE_BOOST_DB := 6.0
## Sources peak near -1 dBFS, so a voice never goes above this level.
const CEILING_DB := 0.0
const FADE_OUT := 0.25
const MUSIC_DB := -6.0
const VOICE_DB := 2.0
const WIND_ZOOM_DB := -6.0
const ANNOUNCE_DELAY := 0.7
const LINE_GAP := 0.05
const MAX_BED_POINTS := 3
const TOWER_HEIGHT := 3.0

var _game: Game
var _files := {}
var _length := {}
var _voice := {}
var _voice_events := {}
var _bed_files := {}
var _cache := {}
var _last_pick := {}
var _world: Array[AudioStreamPlayer3D] = []
var _flat: Array[AudioStreamPlayer] = []
var _beds: Array[AudioStreamPlayer3D] = []
var _fades := {}
var _mix_world := AudioMix.new(WORLD_VOICES)
var _mix_flat := AudioMix.new(FLAT_VOICES)
var _music := MusicDeck.new()
var _music_state: StringName = &"build"
var _music_entries := {}
var _boss_wave := false
var _announcer := AudioStreamPlayer.new()
var _lines: Array[StringName] = []
var _line_at := 0.0
var _wind := AudioStreamPlayer.new()
var _wind_db := 0.0
var _village := Vector3(6, 1.5, 50)
## Creep id → type, since dead creeps are gone from the sim before we hear of it.
var _creeps := {}
## Creep id → towers with a homing shot flying at it, oldest first.
var _shots := {}
## Seconds of frame time. Sounds play in real time whatever the game speed,
## so cooldowns and voice lengths follow frames, not the sim.
var _clock := 0.0


func setup(game: Game) -> void:
	_game = game
	_setup_buses()
	_load_manifest()
	for i in WORLD_VOICES:
		var p := AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = WORLD_UNIT
		p.attenuation_filter_db = 0.0
		add_child(p)
		_world.append(p)
	for i in FLAT_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_flat.append(p)
	_announcer.bus = &"SFX"
	add_child(_announcer)
	_wind.bus = &"Ambience"
	add_child(_wind)
	add_child(_music)
	_music.ending.connect(_on_music_ending)
	_start_ambience()
	game.sim_event.connect(_on_sim_event)
	_play_music(0.0)


## Plays a mix-table cue, or any manifest event, without a position;
## `volume_db` goes on top of its mix level.
func play(id: StringName, volume_db := 0.0) -> void:
	_play_cue(id, null, volume_db)


## UI feedback sounds (clicks, hovers) for the HUD.
func play_ui(id: StringName) -> void:
	_play_cue(id, null, 0.0, &"UI")


## Linear 0..1 volume for one of BUSES, saved as a setting.
func set_volume(bus: StringName, linear: float) -> void:
	_apply_volume(bus, linear)
	Save.set_setting("volume_" + String(bus).to_lower(), linear)


func volume(bus: StringName) -> float:
	return Save.setting("volume_" + String(bus).to_lower(), 1.0)


func _setup_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
		_apply_volume(bus, volume(bus))
	# Dense waves stack many voices; the limiter keeps the sum from clipping.
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			return
	AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())


func _apply_volume(bus: StringName, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.0001)


func _load_manifest() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if data == null:
		push_warning("audio manifest missing")
		return
	for entry: Dictionary in data:
		var file: String = entry.file
		var event := StringName(entry.event)
		var folder := file.get_base_dir().get_file()
		var base := StringName(file.get_file().get_basename())
		_length[file] = float(entry.duration_s)
		if folder == "voice":
			_voice[base] = file
			_voice_events.get_or_add(event, []).append(base)
			_stream(file)
			continue
		_files.get_or_add(event, []).append(file)
		# Music and beds too: loading a 3-5 MB Ogg on first play stalled the
		# frame when wave 1 (battle theme) or a boss wave began.
		_stream(file)
		if folder == "ambience":
			_bed_files[base] = file


func _stream(file: String) -> AudioStream:
	if not _cache.has(file):
		_cache[file] = load("res://" + file)
	return _cache[file]


func _trim(file: String) -> float:
	return AudioTrims.DB.get(file.trim_prefix(AUDIO_DIR), 0.0)


# --- Sound effects -----------------------------------------------------------


func _on_sim_event(e: Dictionary) -> void:
	var type: StringName = e.type
	if type == &"spawned":
		_creeps[e.id] = e.creep
	var cues := AudioMix.cues_for(e, _tower_of(e), _creeps.get(e.get("id", -1), &""))
	var at: Variant = _where(e) if not cues.is_empty() else null
	var longest := 0.0
	for cue in cues:
		if at == null and AudioMix.spec(cue).at == &"world":
			continue  # the creep is already gone; its death sound covers it
		longest = maxf(longest, _play_cue(cue, at))
	match type:
		&"died":
			_creeps.erase(e.id)
			_shots.erase(e.id)
		&"wave_started":
			_on_wave_started(e.wave)
		&"wave_cleared":
			_boss_wave = false
			_set_music(type)
		&"victory", &"defeat":
			var lines: Array = _voice_events.get(type, [])
			if not lines.is_empty():
				_say([lines.pick_random()], 0.4)
			_set_music(type, longest)


## The tower behind an event, remembering homing shots so the hit that
## follows can play that tower's impact.
func _tower_of(e: Dictionary) -> StringName:
	match e.type:
		&"fired":
			var t := _game.sim.tower_at(e.tile)
			if t == null:
				return &""
			if e.kind == &"homing" and AudioMix.IMPACT.has(t.id):
				_shots.get_or_add(e.target, []).append(t.id)
			return t.id
		&"hit":
			var queue: Array = _shots.get(e.id, [])
			return &"" if queue.is_empty() else queue.pop_front()
		&"shell_landed":
			return e.tower
	return &""


## World position of an event, or null when its creep is already gone.
func _where(e: Dictionary) -> Variant:
	if e.has("pos"):
		return Coords.to_world(e.pos, Coords.PLATEAU_TOP + 1.0)
	if e.has("tile"):
		return Coords.tile_to_world(e.tile, Coords.PLATEAU_TOP + TOWER_HEIGHT)
	var c := _game.sim.creep(e.get("id", -1))
	if c == null:
		return null
	return Coords.to_world(c.pos, Coords.PLATEAU_TOP + 1.0)


## Plays one cue at `at` (null: no position) and returns how long it lasts,
## or 0 when the mix turned it down.
func _play_cue(cue: StringName, at: Variant, offset_db := 0.0, bus := &"") -> float:
	var s := AudioMix.spec(cue)
	var files: Array = _files.get(s.sound, [])
	if files.is_empty():
		return 0.0
	var file := _pick(s.sound, files)
	var pitch: float = s.pitch * (1.0 + randf_range(-s.jitter, s.jitter))
	var length: float = _length.get(file, 1.0) / pitch
	if s.max_len > 0.0:
		length = minf(length, s.max_len + FADE_OUT)
	var flat: bool = s.at == &"flat" or (s.at == &"world" and at == null)
	var slot := (_mix_flat if flat else _mix_world).claim(cue, _clock, length)
	if slot < 0:
		return 0.0
	var db := minf(s.db + _trim(file) + offset_db, CEILING_DB)
	var p: Node
	if flat:
		var f := _flat[slot]
		f.stream = _stream(file)
		f.bus = bus if bus != &"" else s.bus
		f.pitch_scale = pitch
		f.volume_db = db
		f.play()
		p = f
	else:
		var w := _world[slot]
		w.stream = _stream(file)
		w.bus = bus if bus != &"" else s.bus
		w.pitch_scale = pitch
		w.volume_db = db
		w.max_db = db + CLOSE_BOOST_DB
		w.position = _anchor(s.at, at)
		w.play()
		p = w
	_fade_after(p, db, s.max_len)
	if s.duck:
		_music.duck(length + 0.3)
	return length


## A random variant, never the same one twice in a row.
func _pick(sound: StringName, files: Array) -> String:
	var n := files.size()
	var last: int = _last_pick.get(sound, -1)
	var i := randi() % n
	if n > 1 and last >= 0:
		i = (last + 1 + randi() % (n - 1)) % n
	_last_pick[sound] = i
	return files[i]


func _anchor(at: StringName, pos: Variant) -> Vector3:
	match at:
		&"gate":
			return Coords.gate() + Vector3(0, 3, 0)
		&"village":
			return _village
	return pos


## Long sounds that only need their attack fade out after `max_len`; a
## reused player drops the fade it had.
func _fade_after(p: Node, db: float, max_len: float) -> void:
	var old: Tween = _fades.get(p)
	if old != null:
		old.kill()
		_fades.erase(p)
	if max_len <= 0.0:
		return
	var tw := create_tween()
	tw.tween_interval(max_len)
	tw.tween_property(p, "volume_db", db - 40.0, FADE_OUT)
	tw.tween_callback(Callable(p, &"stop"))
	_fades[p] = tw


# --- Waves, announcer, music ---------------------------------------------------


func _on_wave_started(wave: int) -> void:
	var boss := WaveDefs.has_boss(wave)
	_boss_wave = _boss_wave or boss
	var final := not _game.sim.infinite and wave == WaveDefs.count()
	_say(AudioMix.wave_lines(wave, final, boss), ANNOUNCE_DELAY)
	_set_music(&"wave_started")


## Replaces anything still queued; a line already playing finishes first.
func _say(lines: Array[StringName], delay: float) -> void:
	_lines = lines.duplicate()
	_line_at = maxf(_line_at, _clock + delay)


func _process(delta: float) -> void:
	_clock += delta
	if not _lines.is_empty() and _clock >= _line_at:
		_speak(_lines.pop_front())
	var cam := get_viewport().get_camera_3d()
	if cam != null and _wind.stream != null:
		var k := clampf((cam.global_position.y - 15.0) / 50.0, 0.0, 1.0)
		_wind.volume_db = _wind_db + lerpf(WIND_ZOOM_DB, 0.0, k)


func _speak(line: StringName) -> void:
	var file: String = _voice.get(line, "")
	if file.is_empty():
		return
	var length: float = _length.get(file, 1.0)
	_announcer.stream = _stream(file)
	_announcer.volume_db = minf(VOICE_DB + _trim(file), CEILING_DB + 3.0)
	_announcer.play()
	_line_at = _clock + length + LINE_GAP
	_music.duck(length + 0.4)


## `delay` holds a theme back while a stinger plays.
func _set_music(event: StringName, delay := 0.0) -> void:
	var state := AudioMix.music_for(_music_state, event, _boss_wave)
	if state != _music_state:
		_music_state = state
		_play_music(delay)


## Each visit to a state takes its next variant (build_theme, build_theme_2...).
func _play_music(delay: float) -> void:
	var spec: Dictionary = AudioMix.MUSIC[_music_state]
	var files: Array = _files.get(spec.event, [])
	if files.is_empty():
		return
	var n: int = _music_entries.get(_music_state, 0)
	_music_entries[_music_state] = n + 1
	var file: String = files[n % files.size()]
	_music.play(_stream(file), MUSIC_DB + _trim(file), spec.resume, delay)


func _on_music_ending() -> void:
	if AudioMix.MUSIC[_music_state].loop:
		_play_music(0.0)


# --- Ambience -------------------------------------------------------------------


func _start_ambience() -> void:
	var points := AudioMix.default_bed_points()
	if _game.world != null and _game.world.has_method(&"ambience_points"):
		var custom: Dictionary = _game.world.call(&"ambience_points")
		for key: Variant in custom:
			var value: Variant = custom[key]
			points[StringName(key)] = value if value is Array else [value]
	if not points.get(&"village", []).is_empty():
		_village = points[&"village"][0]
	for key: StringName in AudioMix.BEDS:
		var file: String = _bed_files.get(key, "")
		if file.is_empty():
			continue
		var db: float = AudioMix.BEDS[key] + _trim(file)
		if key == &"wind":
			_wind_db = db
			_wind.stream = _stream(file)
			_wind.play()
			continue
		var list: Array = points.get(key, [])
		for i in mini(list.size(), MAX_BED_POINTS):
			_add_bed(file, db, list[i])


func _add_bed(file: String, db: float, at: Vector3) -> void:
	var p := AudioStreamPlayer3D.new()
	p.bus = &"Ambience"
	p.stream = _stream(file)
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.unit_size = BED_UNIT
	p.attenuation_filter_db = 0.0
	p.volume_db = db
	p.max_db = db + CLOSE_BOOST_DB
	p.position = at
	add_child(p)
	# Start loops at different points so beds sharing a file don't phase.
	p.play(randf() * _length.get(file, 0.0) * 0.9)
	_beds.append(p)


func _exit_tree() -> void:
	for tw: Tween in _fades.values():
		tw.kill()
	_fades.clear()
	for p in _world + _beds:
		p.stop()
		p.stream = null
	for p in _flat + [_announcer, _wind]:
		p.stop()
		p.stream = null
	_cache.clear()
