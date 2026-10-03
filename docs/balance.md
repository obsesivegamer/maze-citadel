# Balance log

Bots play full games headless: `godot --headless --path . --script res://tests/bots/run_balance.gd` (about 15 minutes for 4 seeds of every run on one core; `-- --only=smart:hard` runs one row, `--seeds=N` sets the sample, `--per-wave` prints how far each wave got, `--twists` plays Twists mode with bot seed n on twist schedule n + 1).

| Bot | Plays like |
|---|---|
| smart | Serpentine maze of six 1-tile walls built where creeps walk; reads the next wave and buys its element and armor counters; saves up for a siege, anti-air or anti-boss tower when one of the next two waves needs it and it owns fewer than two; upgrades with surplus gold, but saves for Runesmith, Demolisher and Cannon upgrades when the next wave has a boss; fuses Epics of all four families between waves, only with gold to rebuild the freed wall tile; ignores twists |
| archers | Same maze, archers only, upgrades archers |
| no_air | Ground-only towers (cannon, roots, shadow) |

Each row is 4 games. Seed 0 is the bot's plain plan; seeds 1–3 jitter its decision timing, which wall tile it fills next and which counter it prefers, so one lucky or unlucky trajectory doesn't decide a target. Columns:

- **Close calls:** waves (per game) where some creep walked at least 80% of its route, leaks included. It shows pressure that lives alone hide.
- **Boss walked:** how far the boss got on each boss wave, averaged; 100% means it leaked.

## Targets (PLAN M6 gate)

| Target | Status |
|---|---|
| smart clears Normal with ≥ 10 lives | Met: 4/4 wins, 19.0 lives on average (18–20) |
| archers-only fails without counters | Met: dies at wave 38 |
| no-anti-air dies at the Harpy waves | Met: dies at wave 5 |
| Hard is beatable but tight | Met: 4/4 wins with 5.5 lives (4–8) and 8.2 close calls per game, against 19.0 lives and 2 close calls on Normal |
| Boss waves are the peak of their stretch, not a sure leak | Normal: met, every boss dies on its first pass in almost every game, the late ones near the gate. Hard: the wave-30 and wave-40 bosses still leak against the bot in most games, with far less HP left than before ([Late bosses](#late-bosses-2026-10-02)) |

## Latest run (2026-10-02)

| Strategy | Mode | Wins | Lives (mean, min–max) | Close calls | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|
| smart | normal | 4/4 | 19.0, 18–20 | 2.0 | 54% / 60% / 98% / 88% | – |
| smart | hard | 4/4 | 5.5, 4–8 | 8.2 | 100% / 75% / 100% / 100% | – |
| archers | normal | 0/4 | 0.0, 0–0 | 7.0 | 100% / 54% / 100% / – | w38, w38, w38, w38 |
| no_air | normal | 0/4 | 0.0, 0–0 | 4.0 | – / – / – / – | w5, w5, w5, w5 |

The smart rows are from the Epics and Twists run below; archers and no_air don't fuse, so their rows stand.

Lives lost per wave (seed 0): smart/normal {} · smart/hard {7: 1, 10: 2, 30: 4, 38: 4, 40: 3} · archers {7: 1, 10: 2, 26: 1, 28: 1, 30: 6, 33: 4, 38: 5} · no_air {1: 8, 2: 6, 4: 2, 5: 4}

Seeds barely change the archers and no_air games: those bots have one tower to pick, so only timing and wall order vary.

## Epics and Twists (2026-10-02)

The Alliance and Forsaken Epics (Sunfire Ballista, Plague Necropolis) and Twists mode came in together.

**Fusions.** The smart bot used to fuse only Elven and Horde Epics, as soon as two level-3 towers were ready, mid-wave included. With four families it fused archer walls during wave 40 on Hard, and the freed wall tiles opened the maze while the Dreadlord walked it (in a run before the Hard rework, Hard fell from 6 to 3 lives). It now fuses only between waves and only with gold to rebuild the freed tile at once. In that earlier run it then fused Frost Wyrms, Doom Cannons, Sunfire Ballistas and a Necropolis between waves 37 and 39, and the Sunfires got 66 kills. On today's Hard it goes from 5.0 to 5.5 lives on the same seeds. On Normal the bot never fuses (it spends all its gold on upgrades), so Normal is unchanged.

**Twists.** Same 4 seeds per row, each on its own twist schedule:

| Strategy | Mode | Wins | Lives (mean, min–max) | Close calls | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|
| smart | normal | 4/4 | 19.0, 18–20 | 2.0 | 54% / 60% / 98% / 88% | – |
| smart | normal twists | 4/4 | 18.0, 18–18 | 2.8 | 54% / 62% / 100% / 89% | – |
| smart | hard | 4/4 | 5.5, 4–8 | 8.2 | 100% / 75% / 100% / 100% | – |
| smart | hard twists | 1/4 | 1.2, 0–5 | 11.2 | 100% / 80% / 100% / 99% | w40, w40, w38 |

- **Normal:** no twisted wave leaked. Twists add close calls, and a wave-30 Ogre slips through in every game instead of in two of four.
- **Hard:** Hard already runs about 5 lives from the edge, so twists tip it. Twisted waves leaked 23 lives across the 4 games: wave 21 in all of them, 26–28 in three. Undying caused 15 of those 23: it is +33% effective HP and is barred from the many Ghoul and Harpy waves, so the weighted schedule makes it the likeliest twist on waves 21 and 27, which are already close on Hard.
- The bot doesn't read twists. A player sees each one a wave ahead (for example, not leaning on slows before an Unstoppable wave), so these numbers are a floor. Hard + Twists is the hardest combination; its score bonus is ×1.3 × 1.1. Viv decided on 2026-10-02 to keep it as is, like Hard's late bosses: it takes a better build than the bot's, and players get each twist a wave ahead.

Seed 0 lives lost per wave on Hard + Twists: {7: 1, 10: 2, 21: 1, 27: 2, 30: 4, 38: 5, 40: 6}.

On the Fallen Rampart (second map, PR #5, run on a trial merge of both branches): Normal 17.5 lives, Normal + Twists 17.2 (13–20); Hard 3.8 (2–5), Hard + Twists 0/4 wins, two of them lost by wave 27–28. Wave 21 costs 3–8 lives in every game, and waves 26–28 up to 6 each.

Tried on both maps to soften Hard + Twists, and dropped:

| Change | Citadel: Normal + T / Hard + T | Rampart: Normal + T / Hard + T |
|---|---|---|
| None (above) | 18.0 / 1.2 lives, 1/4 wins | 17.2 / 0/4 wins |
| Undying rises at ¼ HP instead of ⅓ | 19.0 / 0.2, 1/4 wins | 17.5 / 0/4 wins |
| Twisted creeps pay +25% bounty | 19.5 / 10.0, 4/4 | 20.0 / 8.2, 4/4 |
| Twisted creeps pay +10% bounty | 20.0 / 7.2, 4/4 | 19.5 / 0.8, 2/4 |

A softer Undying moved nothing: waves 21 and 26–28 leaked as much as before. Bounty overshoots as it did for Hard itself: even +10% makes Twists easier than no twists on the Citadel, while Rampart Hard still loses half its games.

## Fallen Rampart (2026-10-02)

The second map ([maps.md](maps.md)), same bots and seeds, `-- --map=rampart`. The smart rows are with the between-waves fusion rule from [Epics and Twists](#epics-and-twists-2026-10-02) (before it, Hard ended with 4.2 lives). The smart bot walls the north half (rows 3, 7, 11), plugs the middle and east breaches, leaves the west breach open, and walls the south half (rows 17, 21, 25). Its opening wall grows from column 6.5, where the route from the north-west portal crosses it; growing it from the board's middle made the bot buy five Frost Spires in a row and lose at wave 2.

| Strategy | Mode | Wins | Lives (mean, min–max) | Close calls | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|
| smart | normal | 4/4 | 17.5, 16–18 | 2.0 | 57% / 64% / 100% / 92% | – |
| smart | hard | 4/4 | 3.8, 2–5 | 8.0 | 100% / 82% / 100% / 100% | – |
| archers | normal | 0/4 | 0.0, 0–0 | 7.0 | 100% / 57% / 100% / 100% | w40, w40, w40, w40 |
| no_air | normal | 0/4 | 0.0, 0–0 | 2.0 | – / – / – / – | w2, w2, w2, w2 |

Lives lost per wave (seed 0): smart/normal {30: 2} · smart/hard {10: 2, 21: 1, 26: 1, 30: 4, 38: 4, 40: 4} · archers {10: 2, 26: 1, 28: 1, 30: 6, 33: 3, 38: 3, 40: 4} · no_air {1: 7, 2: 13}

Against the Citadel Plateau: Normal and Hard play about the same (the twin Ogres on wave 30 now take one pass of 2 lives on Normal, and Hard ends with 3.8 lives instead of 5.5); archers-only lasts two waves longer, since every creep passes the same breach. The no-anti-air bot dies at wave 2 instead of wave 5: its three opening siege towers can't hold the first Wolf Riders on this map. That bot is a strawman for the Harpy waves, so the target row above still describes the Citadel.

## Late bosses (2026-10-02)

The twin Ogres on wave 30 and the Dreadlord on wave 40 leaked in every game on both modes, so the last two boss waves were a fixed toll rather than a fight. When they reached the gate on their first pass (seeds 0–3), the Ogres still had 10–48% of their HP on Normal and 46–63% on Hard, and the Dreadlord 5–10% on Normal and 37–40% on Hard. Three changes:

1. **The twin Ogres no longer buff each other.** The Ogre aura (+3 armor, +10% speed) is meant for escorts, but on wave 30 each Ogre walked inside the other's aura, so both had 11 armor instead of 8 and moved 10% faster. Bosses are now outside the aura. On its own this got the first Ogre killed at about 88% of the route on Normal.
2. **The smart bot saves for boss counters.** When the next wave has a boss it stops topping up archers and spends only on Runesmith, Demolisher and Cannon upgrades until those are maxed, as a player would after reading the boss banner. Before, it skipped any upgrade it couldn't afford yet, so cheap archer upgrades took every coin and its Runesmiths were still level 1 at wave 30.
3. **A little less boss HP:** the wave-30 Ogres take `boss_hp` ×0.9, and the Dreadlord goes from ×32 to ×27.

Result: on Normal the late bosses die on their first pass near the gate (the Ogres after 83–98% of the route, the Dreadlord after 87–90%). In two games of four one Ogre slipped through with 1–7% of its HP left. On Hard they mostly still leak, but with much less left: the Ogres with 12–56% of their HP (one died at 98% of the route) and the Dreadlord with 26–29%. Hard stays tight at 5.0 lives (it was 3.8), and the late bosses are still where it bites.

Tried and dropped:

- **Saving for boss counters two waves ahead instead of one.** It starved the wave-38 defence on Hard, which fell to 2.8 lives with one game won on its last life.
- **Selling archers for one Runesmith per wall before a boss wave.** It barely moved the Dreadlord (35% left on Hard instead of 38%). Towers fire at the creep nearest the gate, so the Runesmiths spent their shred on the Felhounds and Ghouls running ahead of the boss.
- **Fewer Felhound summons** (every 15 s instead of 10, or none while 6 are alive). The cap never triggered, and slower summons left Hard's Dreadlord where it was (34–37% left). On Hard the wall is the Dreadlord's own +40% HP: a maze that kills it near the gate on Normal can't stop it on Hard, and cutting it enough for Hard would make Normal's finale a walkover.

## How Hard was made harder (2026-10-02)

The smart bot used to finish Normal and Hard with the same 6 lives. Two causes:

1. **The +20% Hard bounty more than paid for the +30% HP.** Upgrades scale better than their price (an L3 archer costs 3× an L1 and does over 6× its damage per second), so 24% more gold bought more than 30% more damage. Mid-game, Hard waves came less close to leaking than the same waves on Normal. Hard now pays Normal bounty.
2. **Most lost lives came from the bot, not the mode.** It spent every coin on archer walls and couldn't afford a Cannon before the Footmen on wave 3 or the Steam Tanks on wave 7, on either mode. It now saves for the counter two waves ahead, which removed those leaks.

Flat +30% HP with no bounty bonus then made Hard unwinnable (6 lives gone on wave 3 alone), so Hard HP ramps instead: +10% on wave 1, rising to +40% on wave 40. The opening lessons stay fair and the late game is where Hard bites.

The lone Ogres on waves 10 and 20 were pushovers (they walked 35% and 24% of the route on Normal), so those boss waves now scale their Ogre: ×2.2 on wave 10 and ×3.2 on wave 20 (the `boss_hp` field in the wave table). On Normal they now walk about 55–60%; on Hard the wave-10 Ogre leaks and the wave-20 one gets to 75%. ×2.5 on wave 10 made it leak on Normal too.

## Changes from the GDD's starting numbers, and why

| Change | Why |
|---|---|
| Wave 3 element Stone → Verdant, 10 → 8 Footmen | Stone halved arrows on top of armor, so the 8-archer opener did ~2 damage per arrow. Verdant makes the Cannon (the lesson) the strong counter. |
| Wave 2 Verdant → Dark | Archers strong against the speed lesson |
| Wave 7 Stone → Flame; 8 Tanks → 4 Grunts + 6 Tanks | Same opener problem; spec needs ≥ 8 creeps per wave |
| Footman armor 6 → 4 | Wave 3 was a wall for any opener |
| HP growth 1.12 → 1.105 per wave | Late waves outscaled any income |
| Ogre ×20 → ×12 HP, Dreadlord ×60 → ×32, Steam Tank ×2.4 → ×2.1 | Boss waves cost most of the lives |
| Pierce vs Armored 60% → 50%, vs Boss 80% → 70% | Archer spam reached wave 38 with no counters at all |
| Archer damage 9/17/30 → 9/15/24; Cannon 30/55/95 → 30/60/110 | Upgraded archers were the most gold-efficient damage in the game |
| Hard bounty +20% → none; Hard HP +30% → +10% rising to +40% by wave 40 | The bounty bonus cancelled the HP; a flat +30% without it broke the opening |
| Ogre ×2.2 HP on wave 10, ×3.2 on wave 20 | The lone Ogres were the easiest waves of their stretch |
| Ogre aura no longer reaches other bosses | Wave 30's twin Ogres armored and hastened each other |
| Wave-30 Ogres ×0.9 HP; Dreadlord ×32 → ×27 | The last two bosses leaked in every game on both modes |
