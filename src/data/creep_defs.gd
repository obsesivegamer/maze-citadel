class_name CreepDefs
extends RefCounted
## Creep table and scaling curves (GDD §8, §4).

const CREEPS := {
	&"grunt": {"name": "Grunt", "class": &"light", "armor": 1, "speed": 3.0, "hp": 1.0},
	&"wolf_rider": {"name": "Wolf Rider", "class": &"light", "armor": 0, "speed": 5.0, "hp": 0.65},
	&"footman":
	{"name": "Shield Footman", "class": &"armored", "armor": 4, "speed": 2.6, "hp": 1.3},
	&"priestess": {"name": "Priestess", "class": &"light", "armor": 0, "speed": 2.8, "hp": 0.9},
	&"harpy":
	{"name": "Harpy", "class": &"air", "armor": 1, "speed": 3.4, "hp": 0.8, "flying": true},
	&"ghoul": {"name": "Ghoul", "class": &"light", "armor": 2, "speed": 3.2, "hp": 1.0},
	&"steam_tank":
	{"name": "Steam Tank", "class": &"armored", "armor": 10, "speed": 2.2, "hp": 2.1},
	&"ogre": {"name": "Ogre Boss", "class": &"boss", "armor": 8, "speed": 2.0, "hp": 12.0},
	&"dreadlord": {"name": "Dreadlord", "class": &"boss", "armor": 12, "speed": 1.8, "hp": 27.0},
	&"felhound": {"name": "Felhound", "class": &"light", "armor": 2, "speed": 4.0, "hp": 0.6},
}

const BASE_HP := 60.0
const HP_GROWTH := 1.105


## Boss HP also takes the wave's own `boss_hp` scale (WaveDefs), so each boss
## wave can be tuned as the peak of its stretch.
static func max_hp(type: StringName, wave: int, mode_mult := 1.0) -> float:
	var hp: float = BASE_HP * pow(HP_GROWTH, wave - 1) * CREEPS[type].hp * mode_mult
	if is_boss(type):
		hp *= WaveDefs.row(wave).get("boss_hp", 1.0)
	return hp


static func bounty(wave: int) -> int:
	return roundi(6.0 + 16.0 * (clampi(wave, 1, 40) - 1) / 39.0)


## A bounty for one creep of `type`: bosses pay ten creeps' worth, the
## Dreadlord twenty-five.
static func creep_bounty(type: StringName, wave: int) -> int:
	return bounty(wave) * (25 if type == &"dreadlord" else (10 if is_boss(type) else 1))


static func is_boss(type: StringName) -> bool:
	return CREEPS[type].class == &"boss"
