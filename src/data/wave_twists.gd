class_name WaveTwists
extends RefCounted
## Twists mode (GDD §5): from wave 11, most waves carry one random creep
## ability, Element TD style. The schedule comes from a seed, so a seed always
## gives the same twists, and the next wave's twist is known a full wave
## ahead. Off by default; the base game never reads this table.

const FIRST_WAVE := 11
## Score bonus for playing with twists on (stacks with Hard's ×1.3).
const SCORE_MULT := 1.1

const SWIFT_SPEED := 1.2
const PLATED_ARMOR := 3.0
const STAMPEDE_SPAWN := 0.5
const SECOND_WIND_AT := 0.5
const SECOND_WIND_HEAL := 0.25

## name · text (under 12 words, shown on the banner and chip) · from: first
## wave it may roll · not_with: creep types whose waves it skips.
const TWISTS := {
	&"swift": {"name": "Swift", "text": "Creeps move 20% faster.", "not_with": [&"wolf_rider"]},
	&"plated": {"name": "Plated", "text": "Creeps gain +3 armor.", "from": 15},
	&"stampede":
	{"name": "Stampede", "text": "Creeps arrive twice as tightly packed.", "not_with": [&"harpy"]},
	&"unstoppable": {"name": "Unstoppable", "text": "Creeps can't be slowed, rooted or frozen."},
	&"undying":
	{
		"name": "Undying",
		"text": "Creeps rise once at a third of their HP.",
		"not_with": [&"ghoul", &"harpy"],
	},
	&"second_wind": {"name": "Second Wind", "text": "At half HP, creeps heal 25% once."},
}
const ORDER: Array[StringName] = [
	&"swift", &"plated", &"stampede", &"unstoppable", &"undying", &"second_wind"
]
## Plated skips waves at least this armored (13-armor Steam Tanks).
const PLATED_MAX_ARMORED := 0.75


static func display_name(twist: StringName) -> String:
	return TWISTS[twist].name


static func text(twist: StringName) -> String:
	return TWISTS[twist].text


## Whether wave `w` can carry any twist: not before FIRST_WAVE, never on a
## boss wave, never on an all-Armored wave (already the hardest non-boss
## waves).
static func wave_can_twist(w: int) -> bool:
	if w < FIRST_WAVE or WaveDefs.has_boss(w):
		return false
	return _armored_share(w) < 1.0


static func eligible(twist: StringName, w: int) -> bool:
	var def: Dictionary = TWISTS[twist]
	if w < def.get("from", FIRST_WAVE):
		return false
	for e in WaveDefs.spawn_list(w):
		if e[0] in def.get("not_with", []):
			return false
	if twist == &"plated" and _armored_share(w) >= PLATED_MAX_ARMORED:
		return false
	return true


## The twist on each twisted wave up to `last`, as {wave: twist}. Each wave
## draws among the twists that fit it, never the previous wave's twist, and a
## twist that has come up less often so far is likelier (weight 1 / (1 + n)),
## so a run sees all of them without fixed waves for any one.
static func plan(seed_value: int, last: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := {}
	var counts := {}
	var previous: StringName = &""
	for w in range(FIRST_WAVE, last + 1):
		if not wave_can_twist(w):
			continue
		var options: Array[StringName] = []
		var weights: Array[float] = []
		var total := 0.0
		for t in ORDER:
			if t != previous and eligible(t, w):
				options.append(t)
				weights.append(1.0 / (1.0 + counts.get(t, 0)))
				total += weights[-1]
		if options.is_empty():
			continue
		var roll := rng.randf() * total
		var pick := options[-1]
		for i in options.size():
			roll -= weights[i]
			if roll < 0.0:
				pick = options[i]
				break
		out[w] = pick
		counts[pick] = counts.get(pick, 0) + 1
		previous = pick
	return out


static func _armored_share(w: int) -> float:
	var entries := WaveDefs.spawn_list(w)
	var armored := entries.filter(
		func(e: Array) -> bool: return CreepDefs.CREEPS[e[0]].class == &"armored"
	)
	return float(armored.size()) / maxf(entries.size(), 1.0)
