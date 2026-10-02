extends "res://tests/test_case.gd"

const MANIFEST := "res://assets/audio/MANIFEST.json"
## A representative [event, tower, creep] per sim event whose cue depends on
## who caused it; every other event is tested as {"type": type}.
const SAMPLES := {
	&"fired": [{"type": &"fired", "kind": &"homing"}, &"archer", &""],
	&"hit": [{"type": &"hit"}, &"archer", &""],
	&"shell_landed": [{"type": &"shell_landed", "tower": &"cannon"}, &"", &""],
	&"died": [{"type": &"died"}, &"", &"grunt"],
	&"spawned": [{"type": &"spawned", "creep": &"ogre"}, &"", &"ogre"],
	&"wave_started": [{"type": &"wave_started", "wave": 1}, &"", &""],
}


func test_gap_blocks_rapid_retrigger() -> void:
	var mix := AudioMix.new(8)
	var gap: float = AudioMix.spec(&"cannon_fire").gap
	check(mix.claim(&"cannon_fire", 10.0, 1.0) >= 0, "first shot plays")
	check_eq(mix.claim(&"cannon_fire", 10.0 + gap * 0.5, 1.0), -1, "inside the gap")
	check(mix.claim(&"cannon_fire", 10.0 + gap, 1.0) >= 0, "after the gap")


func test_voice_cap_limits_concurrent_arrows() -> void:
	var mix := AudioMix.new(16)
	var s := AudioMix.spec(&"arrow_fire")
	check_eq(s.voices, 3, "arrow voices")
	var t := 0.0
	var admitted := 0
	for i in 20:
		admitted += int(mix.claim(&"arrow_fire", t, 5.0) >= 0)
		t += s.gap
	check_eq(admitted, 3, "admitted while all still sound")
	check_eq(mix.playing(&"arrow_fire", t), 3, "playing")
	check(mix.claim(&"arrow_fire", 6.0, 0.3) >= 0, "plays again once earlier voices end")


func test_group_cap_is_shared_between_towers() -> void:
	var mix := AudioMix.new(28)
	var cap: int = AudioMix.GROUPS[&"fire"]
	for i in 40:
		for cue: StringName in AudioMix.FIRE.values():
			mix.claim(cue, i * 0.5, 10.0)
		check(mix.playing_group(&"fire", i * 0.5) <= cap, "fire voices at %.1f s" % (i * 0.5))
	check_eq(mix.playing_group(&"fire", 19.5), cap, "fire voices fill the group")
	check_eq(mix.busy(19.5), cap, "nothing else plays")


func test_key_cues_steal_and_are_never_stolen() -> void:
	var mix := AudioMix.new(4)
	var normals: Array[StringName] = [&"ghoul_revive", &"tank_steam", &"dreadlord_summon", &"coin"]
	for i in 4:
		check_eq(mix.claim(normals[i], i * 1.0, 100.0), i, "fill")
	check_eq(mix.claim(&"ghoul_revive", 5.0, 100.0), 0, "normal reuses the oldest normal voice")
	check_eq(mix.claim(&"gate_flash", 5.0, 100.0), 1, "key takes the oldest normal voice")
	check_eq(mix.claim(&"build_thump", 5.0, 100.0), 2, "key")
	check_eq(mix.claim(&"ogre_roar", 5.0, 100.0), 3, "key")
	check_eq(mix.claim(&"fuse", 5.0, 100.0), 0, "key takes the last normal voice")
	check_eq(mix.claim(&"leak_horn", 5.0, 1.0), -1, "keys are never stolen")
	check_eq(mix.busy(5.0), 4, "busy")


func test_detail_cues_never_steal() -> void:
	var mix := AudioMix.new(2)
	mix.claim(&"ghoul_revive", 0.0, 10.0)
	mix.claim(&"tank_steam", 0.0, 10.0)
	check_eq(mix.claim(&"dot_tick", 1.0, 0.5), -1, "detail waits for a free voice")


## 30 towers and a 24-creep wave for 20 s at the sim rate: every cap holds,
## and leak horns still get through.
func test_busy_wave_stays_within_caps() -> void:
	var lengths := _lengths()
	var mix := AudioMix.new(28)
	var towers: Array[StringName] = []
	for i in 30:
		towers.append(TowerDefs.BUILD_ORDER[i % 8] if i % 10 != 9 else &"doom_cannon")
	var leaks := 0
	var t := 0.0
	for step in 600:
		t = step / 30.0
		for i in towers.size():
			if (step + i * 7) % 30 == 0:
				for e in [{"type": &"fired"}, {"type": &"hit"}]:
					for cue in AudioMix.cues_for(e, towers[i], &""):
						mix.claim(cue, t, _length(lengths, cue))
		if step % 25 == 0:
			var cue: StringName = AudioMix.DEATH.values()[step % 10]
			mix.claim(cue, t, _length(lengths, cue))
		if step % 90 == 45:
			leaks += int(mix.claim(&"gate_flash", t, 1.4) >= 0)
		check(mix.busy(t) <= 28, "pool")
		for cue: StringName in [&"arrow_fire", &"cannon_fire", &"frost_cast"]:
			check(mix.playing(cue, t) <= AudioMix.spec(cue).voices, "%s cap" % cue)
		for group: StringName in AudioMix.GROUPS:
			check(mix.playing_group(group, t) <= AudioMix.GROUPS[group], "%s cap" % group)
	check_eq(leaks, 7, "every leak is heard")


func test_every_sim_event_is_mapped_or_silent() -> void:
	var src := FileAccess.get_file_as_string("res://src/sim/game_sim.gd")
	var types := {}
	for m in RegEx.create_from_string('"type": &"(\\w+)"').search_all(src):
		types[StringName(m.get_string(1))] = true
	check(types.size() >= 25, "found the sim's events (%d)" % types.size())
	for type: StringName in types:
		var sample: Array = SAMPLES.get(type, [{"type": type}, &"", &""])
		var cues := AudioMix.cues_for(sample[0], sample[1], sample[2])
		if type in AudioMix.SILENT:
			check(cues.is_empty(), "%s is silent" % type)
		else:
			check(not cues.is_empty(), "%s makes a sound" % type)


func test_towers_and_creeps_have_sounds() -> void:
	for id: StringName in TowerDefs.TOWERS:
		var kind: StringName = TowerDefs.stat(id, "kind")
		if kind in [&"projectile", &"shell", &"bolt"]:
			check(AudioMix.FIRE.has(id), "%s fires with a sound" % id)
		if kind == &"shell":
			check(AudioMix.LANDING.has(id), "%s lands with a sound" % id)
	for type: StringName in CreepDefs.CREEPS:
		check(AudioMix.DEATH.has(type), "%s dies with a sound" % type)
		if CreepDefs.is_boss(type):
			check(AudioMix.ARRIVAL.has(type), "%s arrives with a sound" % type)


func test_every_cue_and_bed_has_files() -> void:
	var events := {}
	var files := {}
	for entry: Dictionary in _manifest():
		if not entry.file.contains("/voice/"):
			events[StringName(entry.event)] = true
		files[entry.file.get_file().get_basename()] = entry.file
	for cue: StringName in AudioMix.CUES:
		check(events.has(AudioMix.spec(cue).sound), "%s has a sound" % cue)
	for table: Dictionary in [
		AudioMix.FIRE,
		AudioMix.IMPACT,
		AudioMix.LANDING,
		AudioMix.DEATH,
		AudioMix.ARRIVAL,
		AudioMix.EVENT_CUES
	]:
		for cue: StringName in table.values():
			check(AudioMix.CUES.has(cue), "%s is in the mix table" % cue)
	for state: StringName in AudioMix.MUSIC:
		check(events.has(AudioMix.MUSIC[state].event), "%s music" % state)
	for bed: StringName in AudioMix.BEDS:
		check(files.has(String(bed)), "%s bed" % bed)


func test_wave_announcements() -> void:
	check_eq(AudioMix.wave_lines(1, false, false), [&"wave", &"number_1"] as Array[StringName])
	var ten := AudioMix.wave_lines(10, false, true)
	check_eq(ten.slice(0, 2), [&"wave", &"number_10"] as Array[StringName], "round ten")
	check(&"warning" in ten, "boss warning")
	check_eq(AudioMix.wave_lines(12, false, false).size(), 1, "generic call past ten")
	check_eq(AudioMix.wave_lines(40, true, true)[0], &"final_wave", "final")
	var voice := {}
	for entry: Dictionary in _manifest():
		if entry.file.contains("/voice/"):
			voice[StringName(entry.file.get_file().get_basename())] = true
	for wave in range(1, 61):
		var final := wave == WaveDefs.count()
		for line in AudioMix.wave_lines(wave, final, WaveDefs.has_boss(wave)):
			check(voice.has(line), "wave %d line %s has a recording" % [wave, line])


func test_music_follows_match_state() -> void:
	var m := &"build"
	m = AudioMix.music_for(m, &"wave_started", false)
	check_eq(m, &"battle", "wave")
	m = AudioMix.music_for(m, &"wave_cleared", false)
	check_eq(m, &"build", "cleared")
	m = AudioMix.music_for(m, &"wave_started", true)
	check_eq(m, &"boss", "boss wave")
	m = AudioMix.music_for(m, &"wave_started", true)
	check_eq(m, &"boss", "early call keeps the boss theme")
	m = AudioMix.music_for(m, &"victory", true)
	check_eq(m, &"victory", "victory")
	check_eq(AudioMix.music_for(m, &"wave_cleared", false), &"victory", "result is final")


func test_trims_cover_every_file() -> void:
	for entry: Dictionary in _manifest():
		var rel: String = entry.file.trim_prefix("assets/audio/")
		check(AudioTrims.DB.has(rel), "trim for %s (run src/audio/measure_trims.py)" % rel)
		check(absf(AudioTrims.DB.get(rel, 0.0)) <= 12.0, "trim range %s" % rel)


func _manifest() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))


## Longest variant per manifest event, in seconds.
func _lengths() -> Dictionary:
	var out := {}
	for entry: Dictionary in _manifest():
		var event := StringName(entry.event)
		out[event] = maxf(out.get(event, 0.0), entry.duration_s)
	return out


func _length(lengths: Dictionary, cue: StringName) -> float:
	var s := AudioMix.spec(cue)
	var length: float = lengths.get(s.sound, 1.0) / s.pitch
	return minf(length, s.max_len) if s.max_len > 0.0 else length
