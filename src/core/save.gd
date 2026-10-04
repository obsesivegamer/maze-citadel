class_name Save
extends RefCounted
## Best results per map and mode, and player settings in user://save.cfg
## (~/Library/Application Support/Maze Citadel/save.cfg on Mac; GDD §15 has the
## Windows and Linux folders).

const PATH := "user://save.cfg"

static var _cfg: ConfigFile


static func _file() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(PATH)
	return _cfg


## "normal", "hard_twists", "normal_infinite", "hard_twists_infinite", ...; on
## other maps prefixed with the map, e.g. "rampart_hard". Runs on the default
## map without twists keep the keys they had before maps and Twists existed.
## Rule sets other than classic end with their name, e.g. "hard_eletd", so
## their records never mix with classic ones; their extra difficulties lead
## the same way, e.g. "very_hard_eletd".
static func mode_key(
	difficulty: StringName,
	infinite: bool,
	twists := false,
	map := MapDefs.DEFAULT,
	rules: StringName = &"classic"
) -> String:
	var key := (
		String(difficulty)
		+ ("_twists" if twists else "")
		+ ("_infinite" if infinite else "")
		+ ("" if rules == &"classic" else "_%s" % rules)
	)
	return key if map == MapDefs.DEFAULT else "%s_%s" % [map, key]


static func sim_key(sim: GameSim) -> String:
	return mode_key(sim.difficulty, sim.infinite, sim.twists, sim.grid.map, sim.rules)


static func best_wave(mode: String) -> int:
	return _file().get_value("best", mode + "_wave", 0)


static func best_score(mode: String) -> int:
	return _file().get_value("best", mode + "_score", 0)


## Records a finished run; returns true when it beat the previous best wave.
static func record(mode: String, wave: int, score: int) -> bool:
	var f := _file()
	var improved := wave > best_wave(mode)
	if improved:
		f.set_value("best", mode + "_wave", wave)
	if score > best_score(mode):
		f.set_value("best", mode + "_score", score)
	f.save(PATH)
	return improved


static func setting(key: String, fallback: Variant) -> Variant:
	return _file().get_value("settings", key, fallback)


static func set_setting(key: String, value: Variant) -> void:
	_file().set_value("settings", key, value)
	_file().save(PATH)
