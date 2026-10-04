class_name EletdRules
extends RefCounted
## Numbers of the &"eletd" rule set (GameSim.rules): the harder Element TD
## rebalance. Classic numbers stay where they always were; docs/balance.md
## has the reasoning behind each value here.

## Creep HP as a share of classic, on a straight line from HP_FROM on wave 1
## to HP_TO on wave 40 (and after), so each wave is at least as tough as the
## one before. A tower that reaches only the tiles around it sees each creep
## for about 2 s, so the bot loses on wave 2 at full HP. HP_FROM is as high as
## the opening stands: at 0.17 the novice bot can lose on wave 7. HP_TO is
## about the steepest line the smart bot survives with lives to spare: at 0.63
## it loses some games on waves 38 to 40, at 0.75 most of them.
const HP_FROM := 0.15
const HP_TO := 0.6
## Armored HP share: up to ARMORED_HP_TO on wave 40 on a squared curve, so
## waves 3 and 7 barely change and late armor needs siege. At 0.7 the
## armored waves 35 and 38 cost the smart bot up to 7 lives each.
const ARMORED_HP_TO := 0.62
## Archer arrows per shot at every level: two at level 3 let a maze of
## archers alone win.
const ARCHER_MULTISHOT := 1
## Starting gold. Until the first wall row is whole, creeps walk round its
## end and only the towers there reach them; at 220 the novice bot loses on
## wave 2 whatever the creep HP.
const START_GOLD := 400
## Pause between waves: time to read the next waves and rebuild.
const BREATHER := 30.0
## Hard creep HP multiplier, in place of classic's 1.1 to 1.4: HARD_FROM on
## wave 1 rising to HARD_TO on wave 40. These creeps already climb to four
## times their wave-1 share, and classic's ramp on top loses every game.
const HARD_FROM := 1.03
const HARD_TO := 1.12
## Element TD's four difficulties; classic offers only Normal and Hard.
const DIFFICULTIES: Array[StringName] = [&"easy", &"normal", &"hard", &"very_hard"]
## Easy takes a flat share off creep HP, so the opening is gentler too.
const EASY_HP := 0.75
## Very Hard's ramp, steeper than Hard's from the first wave. Not yet tuned.
const VERY_HARD_FROM := 1.12
const VERY_HARD_TO := 1.3
## Score multiplier per difficulty; Normal and Hard match classic's.
const SCORE_MULT := {&"easy": 0.7, &"normal": 1.0, &"hard": 1.3, &"very_hard": 1.6}
## Boss HP per wave, on top of the wave table's boss_hp. The wave-10 Ogre is
## the opening's test: at 1.0 nothing leaks before wave 20. The Dreadlord at
## full share outlasts any maze, walks round four or five times and takes 7 to
## 13 lives; at this share it mostly dies on its first pass.
const BOSS_HP := {10: 1.7, 40: 0.33}
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
## BULKY_SCALE is only how much larger they are drawn.
const BULKY_WAVES: Array[int] = [12, 18, 25, 37]
const BULKY_COUNT := 0.5
const BULKY_HP := 2.5
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
## of the current wave (without any wave's own boss tuning). A first guess.
const GUARDIAN_HP: Array[float] = [0.5, 0.8, 1.2]
const GUARDIAN_LIVES := 3


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
			return lerpf(VERY_HARD_FROM, VERY_HARD_TO, f)
	return 1.0


static func hp(w: int) -> float:
	var f := clampf((w - 1) / float(WaveDefs.count() - 1), 0.0, 1.0)
	return lerpf(HP_FROM, HP_TO, f)


## Never below hp(), so armored creeps are never the easier ones.
static func armored_hp(w: int) -> float:
	var f := clampf((w - 1) / float(WaveDefs.count() - 1), 0.0, 1.0)
	return maxf(hp(w), lerpf(HP_FROM, ARMORED_HP_TO, f * f))


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
