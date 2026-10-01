class_name WaveDefs
extends RefCounted
## Wave table (GDD §9). Groups spawn in order; a group may carry its own
## element (waves 31-39 mix two), otherwise the wave's element applies.
## Infinite mode repeats waves 31-39 with extra HP (see GameSim).

const WAVES: Array[Dictionary] = [
	# 1-9: one mechanic each
	{"element": &"flame", "groups": [[&"grunt", 10]]},
	{"element": &"dark", "groups": [[&"wolf_rider", 14]]},
	{"element": &"verdant", "groups": [[&"footman", 10]]},
	{"element": &"aqua", "groups": [[&"grunt", 10], [&"priestess", 3]]},
	{"element": &"light", "groups": [[&"harpy", 12]]},
	{"element": &"dark", "groups": [[&"ghoul", 14]]},
	{"element": &"flame", "groups": [[&"steam_tank", 8]]},
	{"element": &"flame", "groups": [[&"wolf_rider", 12], [&"grunt", 8]]},
	{"element": &"aqua", "groups": [[&"footman", 12], [&"priestess", 4]]},
	{"element": &"flame", "groups": [[&"grunt", 8], [&"ogre", 1]]},
	# 11-19: air, heal, revive
	{"element": &"verdant", "groups": [[&"harpy", 10], [&"priestess", 4]]},
	{"element": &"dark", "groups": [[&"ghoul", 12], [&"priestess", 3]]},
	{"element": &"aqua", "groups": [[&"harpy", 16]]},
	{"element": &"light", "groups": [[&"wolf_rider", 16], [&"priestess", 4]]},
	{"element": &"verdant", "groups": [[&"ghoul", 14], [&"harpy", 6]]},
	{"element": &"light", "groups": [[&"footman", 10], [&"priestess", 6]]},
	{"element": &"dark", "groups": [[&"harpy", 18]]},
	{"element": &"flame", "groups": [[&"ghoul", 14], [&"priestess", 5]]},
	{"element": &"stone", "groups": [[&"wolf_rider", 14], [&"harpy", 8]]},
	{"element": &"dark", "groups": [[&"harpy", 8], [&"ogre", 1]]},
	# 21-29: armor and immunity
	{"element": &"aqua", "groups": [[&"steam_tank", 8], [&"priestess", 4]]},
	{"element": &"verdant", "groups": [[&"footman", 16]]},
	{"element": &"light", "groups": [[&"steam_tank", 10], [&"footman", 6]]},
	{"element": &"flame", "groups": [[&"grunt", 12], [&"footman", 12]]},
	{"element": &"dark", "groups": [[&"steam_tank", 8], [&"ghoul", 10]]},
	{"element": &"stone", "groups": [[&"harpy", 12], [&"steam_tank", 6]]},
	{"element": &"aqua", "groups": [[&"footman", 14], [&"priestess", 6]]},
	{"element": &"verdant", "groups": [[&"steam_tank", 12], [&"priestess", 4]]},
	{"element": &"light", "groups": [[&"wolf_rider", 16], [&"steam_tank", 6]]},
	{"element": &"stone", "groups": [[&"steam_tank", 6], [&"ogre", 2]]},
	# 31-39: mixed pressure, two elements
	{"element": &"aqua", "groups": [[&"grunt", 10], [&"harpy", 10, &"flame"]]},
	{
		"element": &"verdant",
		"groups": [[&"ghoul", 12], [&"priestess", 6], [&"wolf_rider", 6, &"dark"]],
	},
	{"element": &"light", "groups": [[&"footman", 12], [&"steam_tank", 8, &"stone"]]},
	{"element": &"dark", "groups": [[&"harpy", 14], [&"wolf_rider", 10, &"aqua"]]},
	{"element": &"flame", "groups": [[&"steam_tank", 10], [&"ghoul", 12, &"light"]]},
	{
		"element": &"verdant",
		"groups": [[&"footman", 12], [&"harpy", 10, &"stone"], [&"priestess", 2]],
	},
	{"element": &"flame", "groups": [[&"wolf_rider", 16], [&"ghoul", 8, &"dark"]]},
	{"element": &"aqua", "groups": [[&"steam_tank", 12], [&"footman", 12, &"verdant"]]},
	{
		"element": &"light",
		"groups": [[&"harpy", 12], [&"ghoul", 8, &"stone"], [&"priestess", 4]],
	},
	# 40: final
	{"element": &"dark", "groups": [[&"ghoul", 10], [&"dreadlord", 1]]},
]
const INFINITE_FROM := 31
const INFINITE_TO := 39


static func count() -> int:
	return WAVES.size()


## The table row for any wave number, including infinite waves past 40.
static func row(wave: int) -> Dictionary:
	if wave <= WAVES.size():
		return WAVES[wave - 1]
	var span := INFINITE_TO - INFINITE_FROM + 1
	return WAVES[INFINITE_FROM - 1 + (wave - WAVES.size() - 1) % span]


## [type, element] pairs in spawn order.
static func spawn_list(wave: int) -> Array:
	var r := row(wave)
	var out := []
	for group in r.groups:
		var element: StringName = group[2] if group.size() > 2 else r.element
		for _i in group[1]:
			out.append([group[0], element])
	return out


static func elements(wave: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in spawn_list(wave):
		if not entry[1] in out:
			out.append(entry[1])
	return out


static func has_boss(wave: int) -> bool:
	return spawn_list(wave).any(func(e: Array) -> bool: return CreepDefs.is_boss(e[0]))
