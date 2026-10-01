class_name WaveDefs
extends RefCounted
## Wave table (GDD §9). Each wave lists spawn groups in order. Waves 11-40
## arrive in M6.

const WAVES: Array[Dictionary] = [
	{"element": &"flame", "groups": [[&"grunt", 10]]},
	{"element": &"verdant", "groups": [[&"wolf_rider", 14]]},
	{"element": &"stone", "groups": [[&"footman", 10]]},
	{"element": &"aqua", "groups": [[&"grunt", 10], [&"priestess", 3]]},
	{"element": &"light", "groups": [[&"harpy", 12]]},
	{"element": &"dark", "groups": [[&"ghoul", 14]]},
	{"element": &"stone", "groups": [[&"steam_tank", 8]]},
	{"element": &"flame", "groups": [[&"wolf_rider", 12], [&"grunt", 8]]},
	{"element": &"aqua", "groups": [[&"footman", 12], [&"priestess", 4]]},
	{"element": &"flame", "groups": [[&"grunt", 8], [&"ogre", 1]]},
]


static func count() -> int:
	return WAVES.size()


static func spawn_list(wave: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for group in WAVES[wave - 1].groups:
		for _i in group[1]:
			out.append(group[0])
	return out


static func element(wave: int) -> StringName:
	return WAVES[wave - 1].element
