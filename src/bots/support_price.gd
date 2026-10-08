class_name SupportPrice
extends RefCounted
## What the smart bot (RouteLiner) counts a slow or a shred as worth: not the
## tower's own damage but what the towers around it add. A creep slowed by s
## for t seconds is s × t seconds later on its way, under the fire of the
## towers near the slow; a shredded creep takes more from every tower armor
## cuts while the shred lasts. A boss shrugs off half a slow.
##
## The shares are fitted to the sim with tests/bots/support_value.gd, on the
## smart bot's own boards after waves 8 and 20. Counted in full, the slows
## came out at 1.0 to 1.6 times what the sim measured and the shred at 3 to 6
## times. The Ancient of Roots' root is left out: counted, it doubled the
## Ancient's price, though the sim measured less support from the Ancient
## than from the Frost Spire.

## A slow or shred holds a creep in the reach of the towers up to this many
## tiles away, that line the road from where it meets this tower to HOLD
## tiles on: on the Winding Causeway the towers two tiles off often line
## another stretch of the lane, which the creep reaches long after the slow.
const SPAN := 2
const HOLD := 3.0
const SLOW_SHARE := 0.75
const SHRED_SHARE := 0.2
## On a fixed lane every tile beside it is one a damage tower could hold, and
## no maze grows more: there a slow at the full share took Aqua from the
## Dark of the bot's games on the Winding Causeway, and the Dreadlord got
## through.
const LANE_SHARE := 0.4


static func supports(id: StringName) -> bool:
	var def: Dictionary = TowerDefs.TOWERS[id]
	return def.has("slow") or def.has("shred")


## Per foe, the damage a tower of `id` at `lvl` with these route contacts
## adds through the towers around it, whose damage per second is `near`.
static func added(
	id: StringName,
	lvl: int,
	foes: Array[Dictionary],
	ground: int,
	air: int,
	near: Array[PackedFloat32Array],
	share := 1.0
) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(foes.size())
	var def: Dictionary = TowerDefs.TOWERS[id]
	var slow: float = TowerDefs.stat(id, "slow", lvl, 0.0)
	var slow_time: float = TowerDefs.stat(id, "slow_time", lvl, 0.0)
	var shred: float = TowerDefs.stat(id, "shred", lvl, 0.0)
	var cd: float = TowerDefs.stat(id, "cooldown", lvl, 1.0)
	for f in foes.size():
		var foe := foes[f]
		var contact := air if foe.air else ground
		if contact == 0 or (foe.air and not def.get("air", false)):
			continue
		# A stream shares out a single-target tower's shots, not a nova's.
		var seen: float = contact * Grid.TILE / foe.speed
		if def.kind != &"nova":
			seen = minf(seen, foe.cap)
		var hits := seen / cd
		var touched := minf(hits, 1.0)
		var later := slow * slow_time * (0.5 if foe.class == &"boss" else 1.0)
		var gain := touched * later * near[0][f] * SLOW_SHARE * (1.0 - near[2][f])
		if shred > 0.0:
			var left: float = foe.armor - minf(shred * maxf(hits, 1.0), GameSim.SHRED_MAX)
			var lift := Damage.armor_factor(left) / Damage.armor_factor(foe.armor) - 1.0
			gain += touched * lift * GameSim.SHRED_TIME * near[1][f] * SHRED_SHARE
		out[f] = gain * share
	return out


## Per foe, the damage per second the towers within SPAN of `tile` deal a
## creep in their reach, Bard auras included: [all of it, the part armor cuts,
## which is all but poison's, 1 where another of them slows it]. A creep
## already slowed gains nothing from a second slow of the same strength:
## priced as if slows added up, the Frost Spires the bot then built stopped
## next to nothing in the sim. An empty tile of the bot's plan counts as the
## level-1 Archer it will hold, as a player builds a slow among the towers to
## come: on the empty board before wave 1 a slow was otherwise worth nothing,
## and the first pick always went to the Light. `dps` and `aura_by` are
## RouteLiner's; `route` is the set of route tiles of `field`.
static func near_dps(
	tile: Vector2i,
	towers: Dictionary,
	planned: Dictionary,
	foes: Array[Dictionary],
	dps: Dictionary,
	aura_by: Dictionary,
	route: Dictionary,
	field: FlowField,
	air_contact: Dictionary
) -> Array[PackedFloat32Array]:
	# The stretch of road, in steps to the gate, a creep walks held by `tile`.
	var near := INF
	var far := -INF
	for r in _reached(tile, route):
		near = minf(near, field.distance(r) - HOLD)
		far = maxf(far, field.distance(r))
	var all := PackedFloat32Array()
	all.resize(foes.size())
	var cut := all.duplicate()
	for dy in range(-SPAN, SPAN + 1):
		for dx in range(-SPAN, SPAN + 1):
			var o := tile + Vector2i(dx, dy)
			var t: SimTower = towers.get(o)
			if o == tile or (t == null and not planned.has(o)):
				continue
			var id: StringName = t.id if t else &"archer"
			var levels: Array = dps[id]
			var row: PackedFloat32Array = levels[mini(t.level if t else 1, levels.size()) - 1]
			if TowerDefs.TOWERS[id].kind == &"aura":
				continue
			var k: float = 1.0 + aura_by.get(o, 0.0)
			var armored: bool = TowerDefs.stat(id, "attack") != &"poison"
			var g := 0
			for r in _reached(o, route):
				var d := field.distance(r)
				if d >= near and d <= far:
					g += 1
			var a: int = air_contact.get(o, 0)
			for f in foes.size():
				if (a if foes[f].air else g) > 0:
					all[f] += row[f] * k
					if armored:
						cut[f] += row[f] * k
	var slowed := _slowed(tile, towers, foes, route, field, near, far + HOLD, air_contact)
	var out: Array[PackedFloat32Array] = [all, cut, slowed]
	return out


## Per foe, 1 where a slow tower other than `tile` already holds the creep on
## the stretch from `near` to `far` steps from the gate: one up the road
## keeps it slowed for HOLD tiles after it, past the SPAN of a straight road.
static func _slowed(
	tile: Vector2i,
	towers: Dictionary,
	foes: Array[Dictionary],
	route: Dictionary,
	field: FlowField,
	near: float,
	far: float,
	air_contact: Dictionary
) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(foes.size())
	var span := SPAN + ceili(HOLD)
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var o := tile + Vector2i(dx, dy)
			var t: SimTower = towers.get(o)
			if o == tile or t == null or not TowerDefs.TOWERS[t.id].has("slow"):
				continue
			var g := _reached(o, route).any(
				func(r: Vector2i) -> bool:
					return field.distance(r) >= near and field.distance(r) <= far
			)
			var a: bool = t.stat("air", false) and air_contact.get(o, 0) > 0
			for f in foes.size():
				if a if foes[f].air else g:
					out[f] = 1.0
	return out


## The route tiles a tower on `tile` reaches.
static func _reached(tile: Vector2i, route: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if route.has(tile + Vector2i(dx, dy)):
				out.append(tile + Vector2i(dx, dy))
	return out
