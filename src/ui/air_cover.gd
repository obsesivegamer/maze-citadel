class_name AirCover
extends RefCounted
## Flyers under rules where towers reach only the tiles around them (eletd,
## GDD §7.1): the straight line they fly from portal to gate, the tiles a
## tower reaches it from, and an estimate of how much of a flying wave the
## air-capable towers beside it can kill. Free of nodes so the geometry and
## the estimate are unit-tested (tests/unit/test_air_cover.gd).

## Half the side of the square a tower reaches (GameSim.reaches).
const REACH := Grid.TILE * 1.5
## estimate()'s ratio below WEAK reads "weak" (and warns as the wave
## starts), below HOLDING "thin", else "holding".
const WEAK := 1.0
const HOLDING := 1.25


## Metres of the flight line inside the square a tower on `tile` reaches: 0
## when it misses the line, 6 where a straight line runs past (more on a
## slant).
## The square's edges count, as they do in GameSim.reaches.
static func chord(grid: Grid, tile: Vector2i) -> float:
	var a := grid.spawn_point
	var d := grid.gate_point - a
	var lo := Grid.center(tile) - Vector2.ONE * REACH
	var hi := Grid.center(tile) + Vector2.ONE * REACH
	var t0 := 0.0
	var t1 := 1.0
	for axis in 2:
		if is_zero_approx(d[axis]):
			if a[axis] < lo[axis] or a[axis] > hi[axis]:
				return 0.0
			continue
		var u := (lo[axis] - a[axis]) / d[axis]
		var v := (hi[axis] - a[axis]) / d[axis]
		t0 = maxf(t0, minf(u, v))
		t1 = minf(t1, maxf(u, v))
	return maxf(t1 - t0, 0.0) * d.length()


## Every tile a tower may stand on (now or once freed) that reaches the
## flight line, in board order: columns 8–11 on the Citadel.
static func reach_tiles(grid: Grid) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in Grid.COLS * Grid.ROWS:
		var t := Grid.tile_of(i)
		if grid.is_reserved(t) or grid.is_obstacle(t) or grid.is_lane(t):
			continue
		if chord(grid, t) > 0.0:
			out.append(t)
	return out


## True when the next or the running wave sends flyers (eletd), so the flight
## line is drawn bright.
static func lane_lit(sim: GameSim) -> bool:
	if sim.phase == GameSim.Phase.WAVE and TowerInfo.flying(sim.wave, sim.rules):
		return true
	return sim.wave < sim.last_wave() and TowerInfo.flying(sim.wave + 1, sim.rules)


## True while choosing `id` to build shows the tiles that reach the flight
## line: it is a tower that hits air.
static func tints_for(id: StringName) -> bool:
	return id != &"" and TowerDefs.TOWERS[id].get("air", false)


## True for a leak event of a flyer: the lane flashes once.
static func air_leak(e: Dictionary) -> bool:
	return (
		e.type == &"leaked" and CreepDefs.CREEPS.get(e.get("creep", &""), {}).get("flying", false)
	)


## The first of the waves the top bar previews (the next one and, under
## eletd, the one after) that sends flyers, or 0.
static func upcoming(sim: GameSim) -> int:
	for w in [sim.wave + 1, sim.wave + 2]:
		if w <= sim.last_wave() and TowerInfo.flying(w, sim.rules):
			return w
	return 0


## A tower's damage per second against `foe` while it is in reach, or 0 for
## a tower that can't hit air, leaving out any Bard's aura (see estimate).
## Poison counts its stacks over their whole length, as many as the tower
## lands before the first runs out.
static func dps(sim: GameSim, t: SimTower, foe: SimCreep) -> float:
	if not t.stat("air", false) or t.stat("kind") == &"aura":
		return 0.0
	var rate: float = 1.0 / float(t.stat("cooldown"))
	var poison: float = t.stat("poison_dps", 0.0)
	if poison > 0.0:
		var stack: float = (
			poison
			* Damage.element_mult(t.stat("element"), foe.element)
			* sim.elements.power(t.id, t.level)
		)
		return stack * minf(float(t.stat("poison_time")) * rate, float(t.stat("poison_stacks")))
	var shots: int = t.stat("multishot", 1) if t.stat("kind") == &"projectile" else 1
	if sim.rules == &"eletd" and t.id == &"archer":
		shots = mini(shots, EletdRules.ARCHER_MULTISHOT)
	return sim.elements.hit_amount(float(t.stat("damage")), t.id, t.level, foe, 0.0) * shots * rate


## The flyers wave `w` sends on `sim`'s map, rules, difficulty and twists,
## made as GameSim makes them (HP, speed, element), and the seconds between
## the first and the last entering: {"flyers": Array[SimCreep], "span": float}.
static func wave_flyers(sim: GameSim, w: int) -> Dictionary:
	var scratch := GameSim.new(sim.grid.map)
	scratch.rules = sim.rules
	scratch.difficulty = sim.difficulty
	scratch.infinite = sim.infinite
	scratch.twists = sim.twists
	scratch.twist_seed = sim.twist_seed
	var flyers: Array[SimCreep] = []
	var at := 0.0
	var first := -1.0
	var last := 0.0
	for entry in WaveDefs.spawn_list(w, sim.rules):
		var c := scratch.spawn_creep(entry[0], entry[1], w, scratch.grid.spawn_point)
		if entry.size() > 2:
			c.reshape(entry[2], entry[3], entry[4])
		if c.flying:
			flyers.append(c)
			first = at if first < 0.0 else first
			last = at
		# GameSim._spawn counts the gap down a step at a time.
		var gap := WaveDefs.spawn_interval(c.type, sim.rules)
		gap *= WaveTwists.STAMPEDE_SPAWN if c.twist == &"stampede" else 1.0
		while gap > 0.0:
			gap -= GameSim.DT
			at += GameSim.DT
	return {"flyers": flyers, "span": maxf(last - first, 0.0)}


## An estimate, not a promise, of how much of wave `w`'s flyers the board's
## air-capable towers can kill: each tower beside the flight line fires for
## as long as flyers stream past it (the wave's flyer spawn span) plus the
## time one flyer spends in its reach, and that damage is set against the
## flyers' total HP. It leaves out slows, misses, overkill, stacks piling on
## one flyer, towers shooting ground creeps instead and leaked flyers coming
## round again, and it leaves out the Bard's aura too, since what it leaves
## out costs about as much. So measured, on the owner's 0.4.1 game
## (tests/playtests) it read 63% on wave 34, where 12 Harpies leaked, and 51%
## on wave 36 (6 leaked); with 5, 10 and 20 Archers added beside the line at
## wave 34, 80%, 96% and 130% (7, 1 and 0 leaked); 102% and 134% on waves 31
## and 26 (none leaked). With the aura counted wave 34 read 83%.
## {} when the wave has no flyers; else ratio, damage, hp, towers (how many
## air towers reach the line) and wave. `air` is wave_flyers(sim, w) when the
## caller kept it: making the flyers is most of the cost (about 1.6 ms), and
## they change only with the wave and the mode, not with the board.
static func estimate(sim: GameSim, w: int, air := {}) -> Dictionary:
	if air.is_empty():
		air = wave_flyers(sim, w)
	var flyers: Array[SimCreep] = air.flyers
	if flyers.is_empty():
		return {}
	var hp := 0.0
	var speed := 0.0
	for f in flyers:
		hp += f.max_hp
		speed += f.speed
	speed /= flyers.size()
	var damage := 0.0
	var towers := 0
	for t: SimTower in sim.towers.values():
		var length := chord(sim.grid, t.tile)
		if length <= 0.0:
			continue
		var per := 0.0
		for f in flyers:
			per += dps(sim, t, f)
		if per <= 0.0:
			continue
		towers += 1
		damage += per / flyers.size() * (air.span + length / speed)
	return {"ratio": damage / hp, "damage": damage, "hp": hp, "towers": towers, "wave": w}


static func verdict(ratio: float) -> String:
	if ratio < WEAK:
		return "weak"
	return "thin" if ratio < HOLDING else "holding"


## Red, gold or green for weak, thin or holding.
static func verdict_color(ratio: float) -> Color:
	return {"weak": UiTheme.BAD, "thin": UiTheme.GOLD_BRIGHT, "holding": UiTheme.GOOD}[verdict(
		ratio
	)]


## The readout under the wave preview, e.g. "Air cover, wave 5: weak".
static func readout(est: Dictionary) -> String:
	return "Air cover, wave %d: %s" % [est.wave, verdict(est.ratio)]


## The readout's tooltip, with the number behind the verdict.
static func tip(est: Dictionary) -> String:
	var hp := TowerInfo.fmt_gold(roundi(est.hp))
	var see := " Choose a wing-icon tower to see the tiles that reach the line."
	if est.towers == 0:
		return (
			(
				"No wing-icon tower stands beside the flight line, so none of wave %d's %s flyer HP"
				% [est.wave, hp]
			)
			+ " will be touched."
			+ see
		)
	return (
		(
			(
				"An estimate: %s beside the flight line can deal about %d%% of wave %d's %s flyer"
				+ " HP. Below %d%% some will get through."
			)
			% [
				"1 wing-icon tower" if est.towers == 1 else "%d wing-icon towers" % est.towers,
				roundi(est.ratio * 100.0),
				est.wave,
				hp,
				roundi(WEAK * 100.0),
			]
		)
		+ see
	)


## The line above the cards when a flying wave starts short of cover, or "".
static func warning(est: Dictionary) -> String:
	if est.is_empty() or est.ratio >= WEAK:
		return ""
	if est.towers == 0:
		return "Air cover weak: no wing-icon tower stands beside the flight line"
	return (
		"Air cover weak: the towers beside the flight line can deal about %d%% of these flyers' HP"
		% roundi(est.ratio * 100.0)
	)
