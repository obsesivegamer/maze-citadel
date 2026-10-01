# Balance log

Bots play full games headless: `godot --headless --path . --script res://tests/bots/run_balance.gd` (about 2 minutes for all runs).

| Bot | Plays like |
|---|---|
| smart | Serpentine maze of six 1-tile walls built where creeps walk; reads the next wave and buys its element and armor counters; upgrades with surplus gold; fuses Epics |
| archers | Same maze, archers only, upgrades archers |
| no_air | Ground-only towers (cannon, roots, shadow) |

## Targets (PLAN M6 gate)

| Target | Status |
|---|---|
| smart clears Normal with ≥ 10 lives | **Not yet: wins with 6.** Lives go on waves 3, 7 (armor lessons), 30 and 40 (bosses). Further boss nerfs didn't move it, which points at the bot's simple choices; revisit after real playtests. |
| archers-only fails without counters | Met: dies at wave 38 |
| no-anti-air dies at the Harpy waves | Met: dies at wave 5 |
| Hard is beatable but tight | Partly: smart wins Hard with 6. The +20% Hard bounty mostly cancels the +30% HP once the maze is complete. |

## Latest run (2026-10-01)

| Strategy | Mode | Result | Lives | Kills | Gold earned | Towers | Route m | Game time |
|---|---|---|---|---|---|---|---|---|
| smart | normal | victory | 6 | 748 | 11618 | 114 | 268 | 40:04 |
| smart | hard | victory | 6 | 754 | 14411 | 114 | 268 | 38:28 |
| archers | normal | lost at wave 38 | 0 | 642 | 9383 | 114 | 268 | 34:45 |
| no_air | normal | lost at wave 5 | 0 | 45 | 204 | 5 | 63 | 3:18 |

Lives lost per wave: smart/normal {3: 3, 7: 2, 30: 4, 40: 5} · smart/hard {3: 5, 7: 1, 30: 4, 38: 2, 40: 2} · archers {7: 1, 26: 2, 30: 9, 33: 4, 38: 4} · no_air {1: 8, 2: 6, 4: 2, 5: 4}

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
