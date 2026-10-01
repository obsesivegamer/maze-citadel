class_name AudioDirector
extends Node
## Maps sim events to sounds and keeps music in step with the match (GDD §13).
## Sounds come from assets/audio/MANIFEST.json by event id; variants are
## picked at random and each event is rate-limited so 24-creep waves don't
## turn into noise.

const MANIFEST := "res://assets/audio/MANIFEST.json"
const BUSES: Array[StringName] = [&"Music", &"SFX", &"UI", &"Ambience"]
const VOICES := 24
const MIN_GAP := 0.06
const FIRE_SOUNDS := {
	&"archer": &"arrow_fire",
	&"ballista": &"ballista_fire",
	&"cannon": &"cannon_fire",
	&"demolisher": &"cannon_fire",
	&"doom_cannon": &"cannon_fire",
	&"frost": &"frost_cast",
	&"plague": &"poison_lob",
	&"runesmith": &"rune_hammer",
}
const LAND_SOUNDS := {
	&"cannon": &"cannon_explode",
	&"demolisher": &"demolisher_explode",
	&"doom_cannon": &"epic_doom_blast",
}
const DEATH_SOUNDS := {
	&"grunt": &"grunt_death",
	&"wolf_rider": &"wolf_death",
	&"footman": &"footman_death",
	&"priestess": &"priestess_death",
	&"harpy": &"harpy_death",
	&"ghoul": &"ghoul_death",
	&"steam_tank": &"tank_death",
	&"ogre": &"ogre_death",
	&"dreadlord": &"dreadlord_death",
	&"felhound": &"felhound_death",
}
const SIMPLE := {
	&"nova": &"roots_nova",
	&"cloud": &"shadow_cloud",
	&"breath": &"epic_frost_breath",
	&"frost_ring": &"frost_hit",
	&"downed": &"ghoul_death",
	&"revived": &"ghoul_revive",
	&"immune": &"tank_steam",
	&"summoned": &"dreadlord_laugh",
	&"leaked": &"leak_horn",
	&"built": &"build_thump",
	&"build_refused": &"invalid_thunk",
	&"sold": &"sell",
	&"upgraded": &"upgrade",
	&"fused": &"fuse",
	&"interest": &"coin",
	&"victory": &"victory_stinger",
	&"defeat": &"defeat_stinger",
}

var _game: Game
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}
var _music := AudioStreamPlayer.new()
var _music_id: StringName = &""


func setup(game: Game) -> void:
	_game = game
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	_load_manifest()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_music.bus = &"Music"
	_music.volume_db = -8.0
	add_child(_music)
	game.sim_event.connect(_on_sim_event)
	_set_music(&"build_theme")


func _load_manifest() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if data == null:
		push_warning("audio manifest missing")
		return
	for entry in data:
		var id := StringName(entry.event)
		if not _streams.has(id):
			_streams[id] = []
		_streams[id].append(entry.file)


func play(id: StringName, volume_db := 0.0) -> void:
	if not _streams.has(id):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last.get(id, -1.0) < MIN_GAP:
		return
	_last[id] = now
	var files: Array = _streams[id]
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = load("res://" + files[randi() % files.size()])
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.94, 1.06)
	p.play()


func _set_music(id: StringName) -> void:
	if id == _music_id or not _streams.has(id):
		return
	_music_id = id
	_music.stream = load("res://" + _streams[id][0])
	_music.play()


func _on_sim_event(e: Dictionary) -> void:
	match e.type:
		&"fired":
			var t := _game.sim.tower_at(e.tile)
			if t != null and FIRE_SOUNDS.has(t.id):
				play(FIRE_SOUNDS[t.id], -10.0)
		&"shell_landed":
			play(LAND_SOUNDS.get(e.tower, &"cannon_explode"), -4.0)
		&"died":
			var c := _game.sim.creep(e.id)
			if c != null:
				play(DEATH_SOUNDS.get(c.type, &"grunt_death"), -6.0)
		&"wave_started":
			var boss := WaveDefs.has_boss(e.wave)
			play(&"boss_incoming" if boss else &"wave_horn")
			_set_music(&"boss_theme" if boss else &"battle_theme")
		&"wave_cleared":
			_set_music(&"build_theme")
		&"victory":
			play(SIMPLE[e.type])
			_set_music(&"victory_theme")
		&"defeat":
			play(SIMPLE[e.type])
			_set_music(&"defeat_theme")
		_:
			if SIMPLE.has(e.type):
				play(SIMPLE[e.type], -4.0)


func _exit_tree() -> void:
	for p in _players + [_music]:
		p.stop()
		p.stream = null
