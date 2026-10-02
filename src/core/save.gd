class_name Save
extends RefCounted
## Best results per map and mode, and player settings in user://save.cfg
## (~/Library/Application Support/Maze Citadel/save.cfg).

const PATH := "user://save.cfg"

static var _cfg: ConfigFile


static func _file() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(PATH)
	return _cfg


## Records are kept per map and mode; the default map keeps its original keys.
static func mode_key(hard: bool, infinite: bool, map := MapDefs.DEFAULT) -> String:
	var key := ("hard" if hard else "normal") + ("_infinite" if infinite else "")
	return key if map == MapDefs.DEFAULT else "%s_%s" % [map, key]


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
