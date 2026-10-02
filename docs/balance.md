# Balance log

Bots play full games headless: `godot --headless --path . --script res://tests/bots/run_balance.gd` (about 15 minutes for 4 seeds of every run on one core; `-- --only=smart:hard` runs one row, `--seeds=N` sets the sample, `--per-wave` prints how far each wave got).

| Bot | Plays like |
|---|---|
| smart | Serpentine maze of six 1-tile walls built where creeps walk; reads the next wave and buys its element and armor counters; saves up for a siege, anti-air or anti-boss tower when one of the next two waves needs it and it owns fewer than two; upgrades with surplus gold; fuses Epics |
| archers | Same maze, archers only, upgrades archers |
| no_air | Ground-only towers (cannon, roots, shadow) |

Each row is 4 games. Seed 0 is the bot's plain plan; seeds 1–3 jitter its decision timing, which wall tile it fills next and which counter it prefers, so one lucky or unlucky trajectory doesn't decide a target. Columns:

- **Close calls:** waves (per game) where some creep walked at least 80% of its route, leaks included. It shows pressure that lives alone hide.
- **Boss walked:** how far the boss got on each boss wave, averaged; 100% means it leaked.

## Targets (PLAN M6 gate)

| Target | Status |
|---|---|
| smart clears Normal with ≥ 10 lives | Met: 4/4 wins, 11.8 lives on average (11–14) |
| archers-only fails without counters | Met: dies at wave 38 |
| no-anti-air dies at the Harpy waves | Met: dies at wave 5 |
| Hard is beatable but tight | Met: 4/4 wins with 3.8 lives (2–6) and 8 close calls per game, against 11.8 lives and 3 close calls on Normal |

## Latest run (2026-10-02)

| Strategy | Mode | Wins | Lives (mean, min–max) | Close calls | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|
| smart | normal | 4/4 | 11.8, 11–14 | 3.0 | 54% / 60% / 100% / 100% | – |
| smart | hard | 4/4 | 3.8, 2–6 | 8.0 | 100% / 75% / 100% / 100% | – |
| archers | normal | 0/4 | 0.0, 0–0 | 7.0 | 100% / 54% / 100% / – | w38, w38, w38, w38 |
| no_air | normal | 0/4 | 0.0, 0–0 | 4.0 | – / – / – / – | w5, w5, w5, w5 |

Lives lost per wave (seed 0): smart/normal {30: 4, 40: 5} · smart/hard {7: 1, 10: 2, 30: 4, 38: 6, 40: 5} · archers {7: 1, 10: 2, 26: 1, 28: 1, 30: 9, 33: 4, 38: 2} · no_air {1: 8, 2: 6, 4: 2, 5: 4}

Seeds barely change the archers and no_air games: those bots have one tower to pick, so only timing and wall order vary.

Still open: on both modes the twin Ogres (wave 30) and the Dreadlord (wave 40) always leak against the smart bot. Wave 30 is Stone, which halves the Light archers that make up most of its maze, so it is an element exam the bot can't adapt to once the maze is full (it never sells). Worth checking in a playtest before tuning further.

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
