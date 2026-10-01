class_name TowerDefs
extends RefCounted
## Tower table (GDD §7). `cost` is [build, upgrade to L2, upgrade to L3].
## Combat stats are added in M5.

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

const TOWERS := {
	&"archer": {"name": "Archer Tower", "family": &"alliance", "cost": [25, 15, 35]},
	&"cannon": {"name": "Cannon Tower", "family": &"horde", "cost": [60, 45, 80]},
	&"frost": {"name": "Frost Spire", "family": &"elven", "cost": [50, 40, 70]},
	&"plague": {"name": "Plague Cauldron", "family": &"forsaken", "cost": [45, 35, 65]},
	&"bard": {"name": "Bard's Pavilion", "family": &"support", "cost": [80, 60, 90]},
	&"runesmith": {"name": "Runesmith Forge", "family": &"support", "cost": [75, 55, 90]},
	&"ballista": {"name": "Ballista", "family": &"alliance", "cost": [70, 60, 100]},
	&"demolisher": {"name": "Demolisher", "family": &"horde", "cost": [120, 90, 120]},
	&"roots": {"name": "Ancient of Roots", "family": &"elven", "cost": [90, 70, 110]},
	&"shadow": {"name": "Shadow Obelisk", "family": &"forsaken", "cost": [100, 80, 110]},
	&"frost_wyrm": {"name": "Epic Frost Wyrm", "family": &"elven", "fuse_cost": 100},
	&"doom_cannon": {"name": "Epic Doom Cannon", "family": &"horde", "fuse_cost": 120},
}

const MAX_LEVEL := 3


static func build_cost(id: StringName) -> int:
	return TOWERS[id].cost[0]


## Gold to go from `level` to `level + 1`; -1 when already at max.
static func upgrade_cost(id: StringName, level: int) -> int:
	var costs: Array = TOWERS[id].get("cost", [])
	return costs[level] if level < costs.size() else -1


static func hotkey(id: StringName) -> String:
	var i := BUILD_ORDER.find(id)
	return "" if i == -1 else str((i + 1) % 10)
