class_name EletdRules
extends RefCounted
## Numbers of the &"eletd" rule set (GameSim.rules): the harder Element TD
## rebalance. Classic numbers stay where they always were; docs/balance.md
## has the reasoning behind each value here.

## Creep HP as a share of classic: HP_FROM on wave 1 rising to HP_TO on wave
## 40 (and after). A tower that reaches only the tiles around it sees each
## creep for about 2 s, so the bot loses on wave 2 at full HP.
const HP_FROM := 0.15
const HP_TO := 0.15
## Armored HP share: up to ARMORED_HP_TO on wave 40 on a squared curve, so
## waves 3 and 7 barely change and late armor needs siege.
const ARMORED_HP_TO := 0.5
## Archer arrows per shot at every level: two at level 3 let a maze of
## archers alone win.
const ARCHER_MULTISHOT := 1
## Starting gold. Until the first wall row is whole, creeps walk round its
## end and only the towers there reach them; at 220 the novice bot loses on
## wave 2 whatever the creep HP.
const START_GOLD := 400
## Pause between waves: time to read the next waves and rebuild.
const BREATHER := 30.0


static func hp(w: int) -> float:
	var f := clampf((w - 1) / float(WaveDefs.count() - 1), 0.0, 1.0)
	return lerpf(HP_FROM, HP_TO, f)


## Never below hp(), so armored creeps are never the easier ones.
static func armored_hp(w: int) -> float:
	var f := clampf((w - 1) / float(WaveDefs.count() - 1), 0.0, 1.0)
	return maxf(hp(w), lerpf(HP_FROM, ARMORED_HP_TO, f * f))
