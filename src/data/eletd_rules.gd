class_name EletdRules
extends RefCounted
## Numbers of the &"eletd" rule set (GameSim.rules): the Element TD rules, the
## game's default. Classic numbers stay where they always were; docs/balance.md
## has the reasoning behind each value here.

## Creep HP as a share of classic, on a straight line from HP_FROM on wave 1
## to HP_TO on wave 40 (and after), so each wave is at least as tough as the
## one before. A tower that reaches only the tiles around it sees each creep
## for about 2 s, so the bot loses on wave 2 at full HP. Since the starters
## deal composite damage the novice bot has no counters for the opening: at
## 0.15, and at 0.11 with HP_TO at 0.68, it lost to the Ghouls of wave 6; at
## HP_FROM it holds to wave 30. HP_TO keeps the smart bot near 12 lives on
## Normal with the stronger elemental towers: at 0.6 it kept 18 on the Rampart.
const HP_FROM := 0.1
const HP_TO := 0.68
## Armored HP share: up to ARMORED_HP_TO on wave 40 on a squared curve, so
## waves 3 and 7 barely change and late armor needs siege. It sits a little
## above HP_TO, so armored creeps are never the easier ones at the end.
const ARMORED_HP_TO := 0.7
## Archer arrows per shot at every level: two at level 3 let a maze of
## archers alone win.
const ARCHER_MULTISHOT := 1
## Starting gold. Until the first wall row is whole, creeps walk round its
## end and only the towers there reach them; at 220 the novice bot loses on
## wave 2 whatever the creep HP.
const START_GOLD := 400
## Rows at the portal (north) edge where nothing may be built (Grid.portal_rows).
## With towers allowed beside the portal tiles, every creep passed a ring of
## Archers on its first step and the opening waves died within 3 m of the
## portal. Three rows keep every creep at least 5.5 m from the portal before
## a tower can reach it and match the bots' first Citadel wall; four would
## take 80 build tiles.
const PORTAL_ROWS := 3
## Pause between waves: time to read the next waves and rebuild.
const BREATHER := 30.0
## Hard creep HP multiplier, in place of classic's 1.1 to 1.4: HARD_FROM on
## wave 1 rising to HARD_TO on wave 40. These creeps already climb to four
## times their wave-1 share, and classic's ramp on top loses every game. To
## 1.12 Hard won as often as Normal once the elemental towers hit harder; to
## 1.3 it won 1 game in 4 on each map.
const HARD_FROM := 1.06
const HARD_TO := 1.28
## Element TD's four difficulties; classic offers only Normal and Hard.
const DIFFICULTIES: Array[StringName] = [&"easy", &"normal", &"hard", &"very_hard"]
## Easy takes a flat share off creep HP, so the opening is gentler too. At
## 0.75 the wave-10 Ogre still got through on the Citadel and Easy kept fewer
## than 15 lives there.
const EASY_HP := 0.7
## Very Hard's ramp, on a squared curve: just above Hard's until about wave
## 25, so a good player reaches wave 30, then steep, so the last ten waves are
## the wall. On a straight line (1.12 to 1.65, 1.05 to 1.55 or 1.07 to 1.5)
## the Bulky wave 25 or the Tanks of wave 28 ended some games before wave 30.
const VERY_HARD_FROM := 1.1
const VERY_HARD_TO := 1.55
## Score multiplier per difficulty; Normal and Hard match classic's.
const SCORE_MULT := {&"easy": 0.7, &"normal": 1.0, &"hard": 1.3, &"very_hard": 1.6}
## Boss HP per wave, on top of the wave table's boss_hp. The wave-10 Ogre is
## the opening's test: at 1.0 nothing leaks before wave 20, and at 1.7 it got
## through on the Citadel but seldom on the Rampart. The Dreadlord at full share
## outlasts any maze, walks round four or five times and takes 7 to 13 lives;
## at this share it mostly dies on its first pass.
const BOSS_HP := {10: 2.1, 40: 0.3}
## Element TD sends long streams, so coverage along the lane is what counts:
## every group but a boss has WAVE_SIZE times the creeps (rounded up), with
## HP and bounty shared out so the wave's totals stay the same (EletdWaves).
const WAVE_SIZE := 1.5
## Seconds between creeps entering, and between fast ones.
const SPAWN_INTERVAL := 0.6
const FAST_SPAWN_INTERVAL := 0.35
## Composite armor takes COMPOSITE_DAMAGE from every element: no counter
## pays double on these waves, and none pays half.
const COMPOSITE_WAVES: Array[int] = [14, 27, 34]
const COMPOSITE_DAMAGE := 0.9
## Bulky waves: BULKY_COUNT of the creeps, each with BULKY_HP times the HP and
## BULKY_BOUNTY times the bounty. A leak costs BULKY_LIVES, as a boss's does.
## BULKY_SCALE is only how much larger they are drawn. At BULKY_HP 2.0 a Bulky
## wave carries the HP of the wave it replaces in half the creeps. At 2.5 the
## Bulky wave 25 cost up to 6 lives on Normal, and at 2.2 up to 10 on Very
## Hard, ending games before wave 30.
const BULKY_WAVES: Array[int] = [12, 18, 25, 37]
const BULKY_COUNT := 0.5
const BULKY_HP := 2.0
const BULKY_BOUNTY := 2
const BULKY_LIVES := 2
const BULKY_SCALE := 1.3
## Element picks (SimElements): one at the start and one as each of these
## waves is cleared, 8 in all against 18 element levels, so no game can have
## everything.
const PICK_WAVES: Array[int] = [5, 10, 15, 20, 25, 30, 35]
const MAX_ELEMENT_LEVEL := 3
## The other use of a pick: INTEREST_PICK_RATE more interest and
## INTEREST_PICK_CAP more gold per tick, at most INTEREST_PICKS times.
const INTEREST_PICKS := 3
const INTEREST_PICK_RATE := 0.01
const INTEREST_PICK_CAP := 10
## The starter towers need no element and deal composite damage: the same to
## every creep element, composite armor included. The Bard needs none either.
const COMPOSITE_TOWERS: Array[StringName] = [&"archer", &"cannon"]
## A Guardian's HP for the element level it guards, as a share of a lone Ogre
## of the current wave (without any wave's own boss tuning). A level-1
## Guardian walks into a maze built for the other elements, and at 0.5 the
## smart bot often never dared summon its third element's, taking Interest.
const GUARDIAN_HP: Array[float] = [0.35, 0.8, 1.2]
const GUARDIAN_LIVES := 3
## The Archer's damage per level as a share of the tower table's. At full
## damage its level 2, +67% for 15 gold, was among the best buys per gold in
## the game, so upgraded Archers crowded out the elemental towers.
const ARCHER_POWER: Array[float] = [1.0, 0.85, 0.8]
## Elemental towers' damage as a share of the table's (Epics keep theirs). The
## table priced them for range, which adjacent reach took away: the Ballista
## and Demolisher reached 12 and 15 m against the Archer's 9 and now see the
## same tiles. At 1.0 the smart bot's elemental purchases rarely came within
## half of its best buy per gold, so it spent picks on Interest. The Plague
## Cauldron keeps 1.0: its poison works on after the creep walks on, so reach
## cost it little, and it was already the bot's first pick.
const ELEMENTAL_POWER := 1.4


## The difficulties rule set `rules` offers, easiest first.
static func difficulties(rules: StringName) -> Array[StringName]:
	if rules == &"eletd":
		return DIFFICULTIES
	return [&"normal", &"hard"]


## The HP multiplier GameSim.spawn_creep gives a creep of `type` on wave `w`
## under these rules at `difficulty`.
static func hp_mult(type: StringName, w: int, difficulty: StringName) -> float:
	var m := difficulty_hp(difficulty, w)
	match CreepDefs.CREEPS[type].class:
		&"armored":
			return m * armored_hp(w)
		&"boss":
			m *= BOSS_HP.get(w, 1.0)
	return m * hp(w)


static func difficulty_hp(difficulty: StringName, w: int) -> float:
	var f := clampf((w - 1) / float(WaveDefs.count() - 1), 0.0, 1.0)
	match difficulty:
		&"easy":
			return EASY_HP
		&"hard":
			return lerpf(HARD_FROM, HARD_TO, f)
		&"very_hard":
			return lerpf(VERY_HARD_FROM, VERY_HARD_TO, f * f)
	return 1.0


static func hp(w: int) -> float:
	var f := clampf((w - 1) / float(WaveDefs.count() - 1), 0.0, 1.0)
	return lerpf(HP_FROM, HP_TO, f)


## Never below hp(), so armored creeps are never the easier ones.
static func armored_hp(w: int) -> float:
	var f := clampf((w - 1) / float(WaveDefs.count() - 1), 0.0, 1.0)
	return maxf(hp(w), lerpf(HP_FROM, ARMORED_HP_TO, f * f))


## The share of its table damage a tower of `id` deals at `level` under these
## rules: every hit, poison stack, cloud and crater.
static func tower_power(id: StringName, level: int) -> float:
	if id == &"archer":
		return ARCHER_POWER[clampi(level - 1, 0, ARCHER_POWER.size() - 1)]
	if id == &"plague" or id in COMPOSITE_TOWERS or id in TowerDefs.EPICS:
		return 1.0
	return ELEMENTAL_POWER if TowerDefs.TOWERS[id].has("element") else 1.0


static func start_gold(rules: StringName) -> int:
	return START_GOLD if rules == &"eletd" else GameSim.START_GOLD


## A Grunt is the plain creep (HP × 1), so this is a lone Ogre of wave `w`,
## Infinite's growth past the last wave included: a kept pick can be spent
## there.
static func guardian_hp(level: int, w: int, difficulty: StringName) -> float:
	var ogre: float = CreepDefs.max_hp(&"grunt", w) * CreepDefs.CREEPS[&"ogre"].hp
	if w > WaveDefs.count():
		ogre *= pow(GameSim.INFINITE_HP_GROWTH, w - WaveDefs.count())
	return ogre * hp(w) * difficulty_hp(difficulty, w) * GUARDIAN_HP[level - 1]
