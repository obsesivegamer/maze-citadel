class_name TowerDefs
extends RefCounted
## Tower table (GDD §7). `cost` is [build, upgrade to L2, upgrade to L3].
## Stat values given as arrays are per level (L1, L2, L3); scalars apply to all
## levels. Epic towers have a single level and a `fuse_cost`.
##
## kind: projectile (homing) · shell (arcing splash) · bolt (piercing line)
##       nova (around the tower) · cloud (ground zone) · cone (breath) · aura

const BUILD_ORDER: Array[StringName] = [
	&"archer",
	&"cannon",
	&"frost",
	&"plague",
	&"bard",
	&"runesmith",
	&"ballista",
	&"demolisher",
	&"roots",
	&"shadow",
]
const EPICS: Array[StringName] = [&"frost_wyrm", &"doom_cannon"]
const FUSIONS := {&"elven": &"frost_wyrm", &"horde": &"doom_cannon"}
const MAX_LEVEL := 3

const TOWERS := {
	&"archer":
	{
		"name": "Archer Tower",
		"family": &"alliance",
		"cost": [25, 15, 35],
		"kind": &"projectile",
		"attack": &"pierce",
		"element": &"light",
		"air": true,
		"damage": [9, 15, 24],
		"cooldown": [0.6, 0.55, 0.5],
		"range": [9.0, 9.5, 10.0],
		"speed": 32.0,
		"multishot": [1, 1, 2],
	},
	&"cannon":
	{
		"name": "Cannon Tower",
		"family": &"horde",
		"cost": [60, 45, 80],
		"kind": &"shell",
		"attack": &"siege",
		"element": &"flame",
		"air": false,
		"damage": [30, 60, 110],
		"cooldown": [1.5, 1.45, 1.4],
		"range": [10.0, 10.5, 11.0],
		"splash": [2.2, 2.4, 2.6],
		"flight_time": 0.7,
	},
	&"frost":
	{
		"name": "Frost Spire",
		"family": &"elven",
		"cost": [50, 40, 70],
		"kind": &"projectile",
		"attack": &"magic",
		"element": &"aqua",
		"air": true,
		"damage": [8, 14, 24],
		"cooldown": [1.0, 0.95, 0.9],
		"range": [9.0, 9.5, 10.0],
		"speed": 24.0,
		"slow": 0.35,
		"slow_time": 2.0,
		"slow_splash": [0.0, 1.5, 1.5],
		"ring_every": [0, 0, 3],
		"ring_radius": 3.0,
	},
	&"plague":
	{
		"name": "Plague Cauldron",
		"family": &"forsaken",
		"cost": [45, 35, 65],
		"kind": &"projectile",
		"attack": &"poison",
		"element": &"dark",
		"air": true,
		"damage": [0, 0, 0],
		"cooldown": [1.2, 1.15, 1.1],
		"range": [8.5, 9.0, 9.5],
		"speed": 14.0,
		"poison_dps": [6.0, 11.0, 19.0],
		"poison_time": 5.0,
		"poison_stacks": 5,
	},
	&"bard":
	{
		"name": "Bard's Pavilion",
		"family": &"support",
		"cost": [80, 60, 90],
		"kind": &"aura",
		"air": false,
		"range": [7.0, 7.5, 8.0],
		"aura_damage": [0.15, 0.2, 0.25],
		"aura_haste": [0.0, 0.0, 0.1],
	},
	&"runesmith":
	{
		"name": "Runesmith Forge",
		"family": &"support",
		"cost": [75, 55, 90],
		"kind": &"projectile",
		"attack": &"rune",
		"element": &"stone",
		"air": true,
		"damage": [14, 24, 40],
		"cooldown": 1.2,
		"range": [9.0, 9.5, 10.0],
		"speed": 22.0,
		"shred": 2.0,
	},
	&"ballista":
	{
		"name": "Ballista",
		"family": &"alliance",
		"cost": [70, 60, 100],
		"kind": &"bolt",
		"attack": &"pierce",
		"element": &"light",
		"air": true,
		"damage": [55, 100, 175],
		"cooldown": [1.6, 1.55, 1.5],
		"range": [12.0, 12.5, 13.0],
		"speed": 40.0,
		"pierce": [3, 3, 4],
	},
	&"demolisher":
	{
		"name": "Demolisher",
		"family": &"horde",
		"cost": [120, 90, 120],
		"kind": &"shell",
		"attack": &"siege",
		"element": &"flame",
		"air": false,
		"damage": [110, 200, 340],
		"cooldown": [3.0, 2.9, 2.8],
		"range": [15.0, 15.5, 16.0],
		"min_range": 4.0,
		"splash": [3.0, 3.2, 3.4],
		"flight_time": 1.1,
		"crater_dps": [10.0, 18.0, 30.0],
		"crater_time": 3.0,
		"crater_radius": 2.0,
	},
	&"roots":
	{
		"name": "Ancient of Roots",
		"family": &"elven",
		"cost": [90, 70, 110],
		"kind": &"nova",
		"attack": &"magic",
		"element": &"verdant",
		"air": false,
		"damage": [20, 36, 60],
		"cooldown": [3.0, 2.8, 2.6],
		"range": [5.0, 5.25, 5.5],
		"slow": 0.35,
		"slow_time": 2.0,
		"root": 0.4,
	},
	&"shadow":
	{
		"name": "Shadow Obelisk",
		"family": &"forsaken",
		"cost": [100, 80, 110],
		"kind": &"cloud",
		"attack": &"poison",
		"element": &"dark",
		"air": false,
		"cooldown": [1.5, 1.45, 1.4],
		"range": [10.0, 10.5, 11.0],
		"cloud_dps": [18.0, 32.0, 55.0],
		"cloud_time": 4.0,
		"cloud_radius": 2.5,
		"max_clouds": 3,
	},
	&"frost_wyrm":
	{
		"name": "Epic Frost Wyrm",
		"family": &"elven",
		"fuse_cost": 100,
		"kind": &"cone",
		"attack": &"magic",
		"element": &"aqua",
		"air": true,
		"damage": 60,
		"cooldown": 1.2,
		"range": 7.0,
		"cone_degrees": 60.0,
		"slow": 0.5,
		"slow_time": 3.0,
		"freeze_every": 5,
		"freeze": 1.0,
	},
	&"doom_cannon":
	{
		"name": "Epic Doom Cannon",
		"family": &"horde",
		"fuse_cost": 120,
		"kind": &"shell",
		"attack": &"siege",
		"element": &"flame",
		"air": false,
		"damage": 300,
		"cooldown": 3.5,
		"range": 16.0,
		"splash": 4.0,
		"flight_time": 1.2,
		"crater_dps": 25.0,
		"crater_time": 5.0,
		"crater_radius": 2.5,
	},
}


static func build_cost(id: StringName) -> int:
	return TOWERS[id].cost[0]


## Gold to go from `level` to `level + 1`; -1 when already at max.
static func upgrade_cost(id: StringName, level: int) -> int:
	var costs: Array = TOWERS[id].get("cost", [])
	return costs[level] if level < costs.size() else -1


## A stat at a level; arrays are per level, scalars apply to every level.
static func stat(id: StringName, key: String, level := 1, fallback: Variant = 0) -> Variant:
	var v: Variant = TOWERS[id].get(key, fallback)
	if v is Array:
		return v[clampi(level - 1, 0, v.size() - 1)]
	return v


static func hotkey(id: StringName) -> String:
	var i := BUILD_ORDER.find(id)
	return "" if i == -1 else str((i + 1) % 10)
