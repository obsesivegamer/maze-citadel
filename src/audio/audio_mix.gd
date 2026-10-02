class_name AudioMix
extends RefCounted
## The mix table and the rules around it (GDD §13): which cue each sim event
## plays, how loud, how varied, how often and how many at once, so a 24-creep
## wave under 30 towers stays readable. Pure logic with an explicit clock; one
## instance books the voices of one player pool. AudioDirector does the
## playing. Levels are dB on top of AudioTrims, which evens out the sources.

enum Prio { DETAIL, NORMAL, KEY }

## Every key a cue may override. sound: manifest event · db: level · pitch:
## base pitch · jitter: ± random pitch fraction · gap: min seconds between
## starts · voices: max at once · group: shared cap in GROUPS · prio: KEY is
## never refused for load or stolen, DETAIL never steals · at: world (3D at
## the event), flat (2D), or a fixed place (gate, village) · max_len: fade out
## after this many seconds · duck: lowers the music while it plays.
const DEFAULT := {
	"sound": &"",
	"db": -10.0,
	"pitch": 1.0,
	"jitter": 0.05,
	"gap": 0.1,
	"voices": 2,
	"group": &"",
	"prio": Prio.NORMAL,
	"at": &"world",
	"bus": &"SFX",
	"max_len": 0.0,
	"duck": false,
}
const CUES := {
	# Tower fire
	&"arrow_fire": {"db": -13.0, "jitter": 0.08, "gap": 0.11, "voices": 3, "group": &"fire"},
	&"ballista_fire": {"db": -9.0, "gap": 0.15, "group": &"fire"},
	&"cannon_fire": {"db": -9.0, "gap": 0.15, "group": &"fire", "max_len": 1.0},
	&"demolisher_fire":
	{"sound": &"cannon_fire", "pitch": 0.82, "db": -7.0, "gap": 0.25, "group": &"fire"},
	&"doom_fire":
	{"sound": &"cannon_fire", "pitch": 0.68, "db": -5.0, "gap": 0.3, "voices": 1, "group": &"fire"},
	&"frost_cast": {"db": -13.0, "gap": 0.12, "group": &"fire", "max_len": 0.9},
	&"poison_lob": {"db": -12.0, "jitter": 0.08, "gap": 0.12, "group": &"fire"},
	&"rune_hammer": {"db": -12.0, "gap": 0.15, "group": &"fire", "max_len": 0.8},
	&"sunfire_fire":
	{
		"sound": &"ballista_fire",
		"pitch": 0.72,
		"db": -5.0,
		"gap": 0.3,
		"voices": 1,
		"group": &"fire"
	},
	&"necropolis_lob":
	{"sound": &"poison_lob", "pitch": 0.8, "db": -10.0, "gap": 0.15, "group": &"fire"},
	# Impacts and blasts
	&"arrow_hit": {"db": -16.0, "jitter": 0.1, "gap": 0.12, "group": &"impact"},
	&"frost_hit": {"db": -15.0, "gap": 0.15, "group": &"impact", "max_len": 0.7},
	&"poison_bubble": {"db": -16.0, "jitter": 0.1, "gap": 0.15, "group": &"impact", "max_len": 0.8},
	&"cannon_explode": {"db": -8.0, "gap": 0.12, "voices": 3, "group": &"blast"},
	&"demolisher_explode": {"db": -6.0, "gap": 0.2, "group": &"blast", "max_len": 2.2},
	&"epic_doom_blast": {"db": -4.0, "gap": 0.3, "voices": 1, "group": &"blast"},
	# Spells
	&"roots_nova": {"db": -9.0, "gap": 0.3, "group": &"spell", "max_len": 1.8},
	&"shadow_cloud": {"db": -12.0, "gap": 0.3, "group": &"spell", "max_len": 1.6},
	&"epic_frost_breath": {"db": -8.0, "gap": 0.3, "voices": 1, "group": &"spell"},
	&"plague_burst":
	{
		"sound": &"shadow_cloud",
		"pitch": 1.25,
		"db": -11.0,
		"gap": 0.25,
		"group": &"spell",
		"max_len": 1.2,
	},
	&"frost_ring":
	{"sound": &"frost_hit", "pitch": 0.8, "db": -10.0, "gap": 0.3, "voices": 1, "group": &"spell"},
	# Creeps
	&"grunt_death": {"db": -10.0, "group": &"death", "max_len": 1.4},
	&"wolf_death": {"db": -10.0, "group": &"death", "max_len": 1.4},
	&"footman_death": {"db": -10.0, "group": &"death", "max_len": 1.4},
	&"priestess_death": {"db": -10.0, "group": &"death", "max_len": 1.4},
	&"harpy_death": {"db": -10.0, "group": &"death", "max_len": 1.4},
	&"ghoul_death": {"db": -10.0, "group": &"death", "max_len": 1.4},
	&"tank_death": {"db": -9.0, "group": &"death"},
	&"felhound_death": {"db": -11.0, "group": &"death", "max_len": 1.0},
	&"ogre_death": {"db": -3.0, "voices": 1, "prio": Prio.KEY},
	&"dreadlord_death": {"db": -2.0, "voices": 1, "prio": Prio.KEY, "duck": true},
	&"ghoul_down": {"sound": &"ghoul_death", "db": -13.0, "group": &"death", "max_len": 1.0},
	&"ghoul_revive": {"db": -12.0, "gap": 0.2, "max_len": 1.4},
	&"tank_steam": {"db": -15.0, "gap": 0.4, "max_len": 0.8},
	&"dot_tick":
	{
		"sound": &"poison_bubble",
		"db": -22.0,
		"jitter": 0.15,
		"gap": 0.35,
		"voices": 1,
		"max_len": 0.5,
		"prio": Prio.DETAIL
	},
	&"ogre_roar": {"db": 0.0, "gap": 1.0, "voices": 1, "prio": Prio.KEY, "duck": true},
	&"dreadlord_arrives":
	{"sound": &"dreadlord_laugh", "db": -1.0, "voices": 1, "prio": Prio.KEY, "duck": true},
	&"dreadlord_summon":
	{"sound": &"dreadlord_laugh", "db": -7.0, "gap": 12.0, "voices": 1, "max_len": 3.5},
	# Player actions
	&"build_thump": {"db": -5.0, "gap": 0.05, "voices": 3, "prio": Prio.KEY},
	&"sell": {"db": -6.0, "prio": Prio.KEY, "max_len": 1.2},
	&"upgrade": {"db": -6.0, "prio": Prio.KEY, "max_len": 1.6},
	&"fuse": {"db": -4.0, "voices": 1, "prio": Prio.KEY},
	&"invalid_thunk": {"db": -6.0, "voices": 1, "at": &"flat", "bus": &"UI"},
	&"coin": {"db": -12.0, "gap": 0.2, "voices": 1, "at": &"flat", "bus": &"UI"},
	&"ui_click": {"db": -8.0, "jitter": 0.03, "gap": 0.03, "at": &"flat", "bus": &"UI"},
	&"ui_hover":
	{"db": -14.0, "jitter": 0.03, "gap": 0.04, "voices": 1, "at": &"flat", "bus": &"UI"},
	# Match
	&"leak_horn":
	{"db": -2.0, "gap": 1.5, "voices": 1, "prio": Prio.KEY, "at": &"flat", "duck": true},
	&"gate_flash": {"db": -4.0, "gap": 0.3, "prio": Prio.KEY, "at": &"gate"},
	&"wave_horn":
	{"db": -5.0, "gap": 1.0, "voices": 1, "prio": Prio.KEY, "at": &"flat", "max_len": 3.0},
	&"boss_horn":
	{
		"sound": &"boss_incoming",
		"db": -3.0,
		"gap": 2.0,
		"voices": 1,
		"prio": Prio.KEY,
		"at": &"flat",
		"max_len": 5.0,
		"duck": true
	},
	&"victory_stinger": {"db": -2.0, "voices": 1, "prio": Prio.KEY, "at": &"flat"},
	&"defeat_stinger": {"db": -2.0, "voices": 1, "prio": Prio.KEY, "at": &"flat"},
	&"village_cheer":
	{"db": -4.0, "gap": 4.0, "voices": 1, "at": &"village", "bus": &"Ambience", "max_len": 6.0},
}
## Shared caps so one kind of sound can't fill the pool.
const GROUPS := {&"fire": 8, &"impact": 4, &"blast": 4, &"spell": 4, &"death": 4}

## Tower id → cue. Impacts only for homing shots, whose target is known.
const FIRE := {
	&"archer": &"arrow_fire",
	&"ballista": &"ballista_fire",
	&"cannon": &"cannon_fire",
	&"demolisher": &"demolisher_fire",
	&"doom_cannon": &"doom_fire",
	&"frost": &"frost_cast",
	&"plague": &"poison_lob",
	&"runesmith": &"rune_hammer",
	&"sunfire_ballista": &"sunfire_fire",
	&"plague_necropolis": &"necropolis_lob",
}
const IMPACT := {
	&"archer": &"arrow_hit",
	&"frost": &"frost_hit",
	&"plague": &"poison_bubble",
	&"plague_necropolis": &"poison_bubble",
}
const LANDING := {
	&"cannon": &"cannon_explode",
	&"demolisher": &"demolisher_explode",
	&"doom_cannon": &"epic_doom_blast",
}
## Creep type → cue.
const DEATH := {
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
const ARRIVAL := {&"ogre": &"ogre_roar", &"dreadlord": &"dreadlord_arrives"}
## Events whose cue doesn't depend on who caused them.
const EVENT_CUES := {
	&"nova": &"roots_nova",
	&"cloud": &"shadow_cloud",
	&"breath": &"epic_frost_breath",
	&"contagion": &"plague_burst",
	&"frost_ring": &"frost_ring",
	&"downed": &"ghoul_down",
	&"revived": &"ghoul_revive",
	&"immune": &"tank_steam",
	&"summoned": &"dreadlord_summon",
	&"dot": &"dot_tick",
	&"built": &"build_thump",
	&"sold": &"sell",
	&"upgraded": &"upgrade",
	&"fused": &"fuse",
	&"build_refused": &"invalid_thunk",
	&"interest": &"coin",
	&"wave_cleared": &"village_cheer",
	&"victory": &"victory_stinger",
	&"defeat": &"defeat_stinger",
}
## Sim events that are deliberately quiet. `heal` has no fitting sound yet.
const SILENT: Array[StringName] = [&"path_changed", &"heal"]

## Music state → manifest event. Resumable themes continue where they were
## left; looping ones move to their next variant when a non-seamless take ends.
const MUSIC := {
	&"build": {"event": &"build_theme", "resume": true, "loop": true},
	&"battle": {"event": &"battle_theme", "resume": true, "loop": true},
	&"boss": {"event": &"boss_theme", "resume": false, "loop": true},
	&"victory": {"event": &"victory_theme", "resume": false, "loop": false},
	&"defeat": {"event": &"defeat_theme", "resume": false, "loop": false},
}
## Ambience loops by file name → level. Wind is everywhere; the rest sit at
## points around the citadel.
const BEDS := {
	&"wind": -12.0,
	&"forest": -6.0,
	&"birds": -10.0,
	&"river": -4.0,
	&"village": -8.0,
	&"fire": -4.0,
}

static var _specs := {}

var _cue: Array[StringName] = []
var _group: Array[StringName] = []
var _prio := PackedInt32Array()
var _start := PackedFloat64Array()
var _end := PackedFloat64Array()
var _last := {}


func _init(slots: int) -> void:
	_cue.resize(slots)
	_group.resize(slots)
	_prio.resize(slots)
	_start.resize(slots)
	_end.resize(slots)


## A cue's full settings: DEFAULT overlaid with its CUES entry. Unknown ids
## play the manifest event of the same name with default settings.
static func spec(cue: StringName) -> Dictionary:
	if not _specs.has(cue):
		var s := DEFAULT.duplicate()
		s.merge(CUES.get(cue, {}), true)
		if s.sound == &"":
			s.sound = cue
		_specs[cue] = s
	return _specs[cue]


## The cues one sim event plays. `tower` is the tower behind it (fired, hit,
## shell_landed) and `creep` the creep type (died, spawned), or &"".
static func cues_for(e: Dictionary, tower: StringName, creep: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	match e.type:
		&"fired":
			if FIRE.has(tower):
				out.append(FIRE[tower])
		&"hit":
			if IMPACT.has(tower):
				out.append(IMPACT[tower])
		&"shell_landed":
			out.append(LANDING.get(e.tower, &"cannon_explode"))
		&"died":
			out.append(DEATH.get(creep, &"grunt_death"))
		&"spawned":
			if ARRIVAL.has(creep):
				out.append(ARRIVAL[creep])
		&"wave_started":
			out.append(&"boss_horn" if WaveDefs.has_boss(e.wave) else &"wave_horn")
		&"leaked":
			out.append(&"leak_horn")
			out.append(&"gate_flash")
		_:
			if EVENT_CUES.has(e.type):
				out.append(EVENT_CUES[e.type])
	return out


## Music state after a sim event. `boss` is true while a boss wave runs;
## early-called waves keep the boss theme until the field is clear.
static func music_for(current: StringName, event: StringName, boss: bool) -> StringName:
	if current == &"victory" or current == &"defeat":
		return current
	match event:
		&"wave_started":
			return &"boss" if boss else &"battle"
		&"wave_cleared":
			return &"build"
		&"victory", &"defeat":
			return event
	return current


## Announcer lines (voice file names) for a wave start. The voice set counts
## to ten, so later waves alternate the two generic calls.
static func wave_lines(wave: int, final: bool, boss: bool) -> Array[StringName]:
	var lines: Array[StringName] = []
	if final:
		lines.append(&"final_wave")
	elif wave <= 10:
		lines.append(&"wave")
		lines.append(StringName("number_%d" % wave))
	elif not boss:
		lines.append(&"wave_start" if wave % 2 == 1 else &"new_enemy")
	if boss:
		var odd := wave % 20 >= 10
		lines.append(&"warning" if odd else &"warning_2")
		lines.append(&"boss_incoming" if odd or final else &"boss_incoming_2")
	return lines


## Where the ambience beds sit when World doesn't say (world space).
static func default_bed_points() -> Dictionary:
	return {
		&"forest": [Vector3(48, 3, -6), Vector3(-42, 3, -52)],
		&"birds": [Vector3(40, 8, 34)],
		&"river": [Vector3(-50, 0.5, -22), Vector3(-50, 0.5, 22)],
		&"village": [Vector3(6, 1.5, 50)],
		&"fire": [Coords.portal() + Vector3(0, 2, 0)],
	}


## Books a voice for `cue` at time `now` lasting `length` seconds and returns
## its slot, or -1 when the mix says no: still inside the cue's gap, at its
## voice or group cap, or every slot busy with something at least as
## important. A busy slot is reused oldest-first among the least important.
func claim(cue: StringName, now: float, length: float) -> int:
	var s := spec(cue)
	if now - float(_last.get(cue, -INF)) < s.gap:
		return -1
	var same := 0
	var grouped := 0
	for i in _end.size():
		if _end[i] > now:
			same += int(_cue[i] == cue)
			grouped += int(s.group != &"" and _group[i] == s.group)
	if same >= s.voices or (s.prio < Prio.KEY and grouped >= GROUPS.get(s.group, INF)):
		return -1
	var slot := _free_slot(now, s.prio)
	if slot >= 0:
		_last[cue] = now
		_cue[slot] = cue
		_group[slot] = s.group
		_prio[slot] = s.prio
		_start[slot] = now
		_end[slot] = now + length
	return slot


## Voices of `cue` still sounding at `now`.
func playing(cue: StringName, now: float) -> int:
	var n := 0
	for i in _end.size():
		n += int(_end[i] > now and _cue[i] == cue)
	return n


## Voices of a GROUPS group still sounding at `now`.
func playing_group(group: StringName, now: float) -> int:
	var n := 0
	for i in _end.size():
		n += int(_end[i] > now and _group[i] == group)
	return n


func busy(now: float) -> int:
	var n := 0
	for e in _end:
		n += int(e > now)
	return n


func _free_slot(now: float, prio: int) -> int:
	var best := -1
	for i in _end.size():
		if _end[i] <= now:
			return i
		if _prio[i] == Prio.KEY or _prio[i] > prio or (prio == Prio.DETAIL):
			continue
		if (
			best < 0
			or _prio[i] < _prio[best]
			or (_prio[i] == _prio[best] and _start[i] < _start[best])
		):
			best = i
	return best
