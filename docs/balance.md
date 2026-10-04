# Balance log

This is the record of how Maze Citadel's numbers were tuned. Three bots play full games with no window and report how far they got. This page keeps their results, the targets they're measured against, and the reasoning behind each change. The rules and numbers as they are now are in [GDD.md](GDD.md).

## Running the bots

```sh
godot --headless --path . --script res://tests/bots/run_balance.gd
```

A full run plays 4 seeds of every row and takes about 8 minutes on one core. Options go after a `--`:

| Option | What it does |
|---|---|
| `--only=smart:hard` | Runs a single row |
| `--seeds=N` | Sets how many games each row plays |
| `--per-wave` | Prints how far each wave got and the unspent gold at each wave's start |
| `--twists` | Plays Twists mode, with bot seed n on twist schedule n + 1 |
| `--map=rampart` | Plays on Fallen Rampart |
| `--rules=eletd` | Plays the Element TD rule set instead of the classic one |

## The bots

| Bot | Plays like |
|---|---|
| smart | Serpentine maze of six 1-tile walls built where creeps walk; reads the next wave and buys its element and armor counters; saves up for a siege, anti-air or anti-boss tower when one of the next two waves needs it and it owns fewer than two; upgrades with surplus gold, but saves for Runesmith, Demolisher and Cannon upgrades when the next wave has a boss; fuses Epics of all four families between waves, only with gold to rebuild the freed wall tile; ignores twists |
| smart, `eletd` rules | Prices every build, upgrade and fusion by the damage it adds to the creeps in the wave preview on their way past, and buys the best per gold ([below](#element-td-rules-a-smart-bot-that-lines-the-route-2026-10-04)) |
| archers | Same maze, archers only, upgrades archers |
| no_air | Ground-only towers (cannon, roots, shadow) |
| novice | Same maze, built one tower every 4 seconds; archers, cannons and frost in a fixed order with no thought for the next wave; never fuses |

Each row is 4 games. Seed 0 is the bot's plain plan; seeds 1–3 jitter its decision timing, which wall tile it fills next and which counter it prefers, so one lucky or unlucky trajectory doesn't decide a target. Columns:

- **Close calls:** waves (per game) where some creep walked at least 80% of its route, leaks included. It shows pressure that lives alone hide.
- **Walked w1–5:** how far creeps got on the first five waves, averaged. A low number means they died at the portal.
- **Walked, non-boss median:** the middle value of how far each non-boss wave got.
- **Boss walked:** how far the boss got on each boss wave, averaged; 100% means it leaked.

## Targets (PLAN M6 gate)

| Target | Status |
|---|---|
| smart clears Normal with ≥ 10 lives | Met: 4/4 wins, 19.0 lives on average (18–20) |
| archers-only fails without counters | Met: dies at wave 38 |
| no-anti-air dies at the Harpy waves | Met: dies at wave 5 |
| Hard is beatable but tight | Met: 4/4 wins with 5.5 lives (4–8) and 8.2 close calls per game, against 19.0 lives and 2 close calls on Normal |
| Boss waves are the peak of their stretch, not a sure leak | Normal: met, every boss dies on its first pass in almost every game, the late ones near the gate. Hard: the wave-30 and wave-40 bosses still leak against the bot in most games, with far less HP left than before ([Late bosses](#late-bosses-2026-10-02)) |

## Baseline before the Element TD rules (2026-10-04)

The game plays too easily: creeps die within sight of the portal and the smart bot keeps 19 of 20 lives. A second rule set, `eletd`, is being tuned beside the classic one to fix that, and `--rules=eletd` plays it. This is the classic game measured with two new columns and a new bot, as the line the new rules are compared against. Until the first `eletd` rule lands, both rule sets play the same.

| Strategy | Mode | Wins | Lives (mean, min–max) | Close calls | Walked w1–5 | Walked, non-boss median | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|---|---|
| smart | normal | 4/4 | 19.0, 18–20 | 2.0 | 7% | 25% | 54% / 60% / 98% / 88% | – |
| smart | hard | 4/4 | 5.5, 4–8 | 8.2 | 10% | 29% | 100% / 75% / 100% / 100% | – |
| archers | normal | 0/4 | 0.0, 0–0 | 7.0 | 9% | 18% | 100% / 54% / 100% / – | w38, w38, w38, w38 |
| no_air | normal | 0/4 | 0.0, 0–0 | 4.0 | 83% | 100% | – / – / – / – | w5, w5, w5, w5 |
| novice | normal | 4/4 | 14.5, 14–15 | 2.0 | 3% | 17% | 100% / 71% / 77% / 100% | – |

Lives lost per wave, all 4 seeds: smart/normal {30: 4} · smart/hard {7: 4, 10: 8, 30: 14, 38: 17, 40: 15} · archers {7: 4, 10: 8, 26: 5, 28: 4, 30: 24, 33: 16, 38: 19} · no_air {1: 32, 2: 26, 4: 8, 5: 14} · novice {10: 8, 40: 14}

What it shows:

- On the first five waves creeps walk 7% of the route against the smart bot and 3% against the novice. Half of all non-boss waves are dead within a quarter of the route.
- The novice wins every game with 14.5 lives. It never reads the next wave and builds one tower every 4 seconds, and it loses lives only to the wave-10 and wave-40 bosses.
- The smart bot holds almost no gold: 0 to 69 unspent at each wave's start on seed 0, so interest pays it next to nothing.

## Element TD rules: adjacent reach (2026-10-04)

The first `eletd` rule: a tower attacks only creeps inside the 3×3 block of tiles around it. The reason is the portal. With ranges of 4 to 8 tiles and a maze that folds the route back on itself, an Archer saw about 14 tiles of route at once, and most waves died on the first stretch.

Tried alone, the rule ends the game on wave 2. A tower now sees each creep for about 2 seconds, nothing dies on wave 1, no bounty comes in, and the leaked creeps walk again. More gold doesn't rescue it (1,000 starting gold loses by wave 26). So under these rules creep HP is 15% of classic, the value at which the smart bot kept about half its lives in the trial runs. The bot also builds a different maze: corridors one tile wide, so every wall tower borders two lanes.

What stays as it was: splash, craters, clouds and contagion keep their radii, the Bard's aura keeps its range, and Ballista bolts and the Sunfire lance fly as far as before. The Demolisher loses its minimum range, which would leave it nothing to shoot.

| Map | Strategy | Mode | Wins | Lives (mean, min–max) | Close calls | Walked w1–5 | Walked, non-boss median | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|---|---|---|
| Citadel | smart | normal | 4/4 | 11.0, 5–19 | 3.2 | 34% | 19% | 39% / 31% / 46% / 39% | – |
| Citadel | smart | hard | 3/4 | 1.0, 0–2 | 4.8 | 53% | 23% | 42% / 35% / 59% / 61% | w7 |
| Citadel | archers | normal | 4/4 | 14.5, 14–15 | 2.0 | 35% | 16% | 39% / 27% / 64% / 25% | – |
| Citadel | no_air | normal | 0/4 | 0.0, 0–0 | 2.2 | 100% | 100% | – / – / – / – | w2, w3, w2, w2 |
| Citadel | novice | normal | 0/4 | 0.0, 0–0 | 2.0 | 100% | 100% | – / – / – / – | w2, w2, w2, w2 |
| Rampart | smart | normal | 4/4 | 19.0, 17–20 | 2.0 | 30% | 21% | 37% / 37% / 62% / 51% | – |
| Rampart | smart | hard | 4/4 | 18.0, 15–20 | 3.8 | 38% | 25% | 38% / 45% / 87% / 82% | – |
| Rampart | archers | normal | 4/4 | 14.2, 14–15 | 2.0 | 35% | 15% | 42% / 33% / 56% / 37% | – |
| Rampart | no_air | normal | 0/4 | 0.0, 0–0 | 3.2 | 72% | 100% | – / – / – / – | w5, w5, w5, w5 |
| Rampart | novice | normal | 1/4 | 3.8, 0–15 | 4.2 | 57% | 20% | 45% / 46% / 46% / 57% | w7, w7, w7 |

Lives lost per wave on the Citadel, all 4 seeds: smart/normal {2: 1, 3: 15, 6: 3, 7: 17} · smart/hard {2: 1, 3: 28, 4: 10, 6: 6, 7: 31} · archers {3: 22} · novice {1: 11, 2: 69}

What it shows:

- The portal kills are gone. Creeps walk 30% to 34% of the route on the first five waves, against 7% in the classic game.
- Every life is lost on waves 1 to 7. Wave 3 (Shield Footmen) and wave 7 (Steam Tanks) take nearly all of them, and from wave 8 on nothing leaks in any winning game: half the non-boss waves die inside the first fifth of the route. One flat HP share is too high for the opening and too low for the rest.
- The archers-only bot now wins, and the novice dies on wave 2. Both are the wrong way round and are the next things to tune.
- The Rampart is much easier than the Citadel under these rules (19 lives on Normal, 18 on Hard).

## Element TD rules: 30 seconds between waves (2026-10-04)

Under `eletd` the pause after a cleared wave is 30 seconds, up from 5, and the top bar shows the wave after next as well. The classic game gave no time to read a wave and rebuild for it. `N` still calls the next wave early.

Citadel, 4 seeds, against the adjacent-reach run above:

| Strategy | Mode | Wins | Lives (mean, min–max) | Close calls | Walked w1–5 | Walked, non-boss median | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|---|---|
| smart | normal | 4/4 | 15.0, 9–19 | 2.8 | 26% | 19% | 38% / 30% / 44% / 42% | – |
| smart | hard | 4/4 | 5.0, 1–9 | 4.0 | 49% | 22% | 39% / 35% / 57% / 60% | – |

The pause helps the bot more than expected: 15.0 lives on Normal against 11.0, and 4/4 on Hard against 3/4. It earns no more gold (about 11,900 either way). The extra seconds let it finish building before the early waves arrive, and those are the only waves that leak. A game the bot never hurries takes about 43 minutes, against 27.

## Element TD rules: starting gold, armor and the one-arrow Archer (2026-10-04)

With a flat 15% HP share every life was lost on waves 1 to 7 and waves 8 to 40 were a walkover. Four studies ran side by side, each with its own bot runs, and three numbers came out of them.

**Starting gold is 400.** Until the first wall is whole, creeps walk round its end and meet one tower; the other opening towers never fire. Waves 3 (Shield Footmen) and 7 (Steam Tanks) are armored, so the opening was decided by whether that one tower happened to be a Cannon, and results swung by up to 17 lives between seeds. Lower creep HP didn't help: at 220 gold the novice and the ground-only bot still lost on wave 2 with waves 1 to 9 at an 8% share. More gold did: at 400 the novice gets through the opening on both maps, the ground-only bot dies on wave 5 (the first Harpies) and not before, and no opening wave costs the smart bot more than 2 lives.

**Armored creeps climb to their own, higher HP share, and the Archer fires one arrow at every level.** Under adjacent reach the archers-only bot won every game with 14.5 lives, half a life behind the smart bot. Filling the maze is most of the game, 25-gold Archers fill it fastest, a level-3 Archer with two arrows is the best damage per gold on the board, and the flat share had erased the armored waves that used to stop Archers. Raising HP for everyone couldn't separate the two bots: at every value high enough to beat the Archers, the smart bot lost first. Either change alone still left the Archers winning; together they lose on wave 38 while the smart bot keeps 14 lives.

| Tried (Citadel, smart / archers on Normal) | Seeds | Result |
|---|---|---|
| HP share rising to 0.4, 0.6 or 0.8 by wave 40 | 2 | Smart loses on wave 7 or 36 to 40; Archers win at 0.4 and lose with it above |
| Pierce vs Armored 50% → 25–35% | 2 | Breaks the opening: waves 3 and 7 are armored |
| Level-3 Archer upgrade 35 → 90 or 120 gold | 2 | Archers still win with 12 lives |
| Armored share to 0.5 alone, or one arrow alone | 1 | Archers win with 9 and 15 lives |
| **Armored share to 0.5 and one arrow** | 4 | Smart 4/4 with 14.2 lives; Archers 0/4, all on wave 38 |

The fourth study found why the Rampart looked easier than the Citadel (18 lives on Hard against 5): not the map, but which tower the bot's build order left at the end of the first wall on waves 3 and 7. That, and the bot's habit of buying only level-1 towers and 16 Bards, led to the new bot below.

## Element TD rules: a smart bot that lines the route (2026-10-04)

Under `eletd` the smart bot used to play its classic plan: build the serpentine wall by wall from the middle outwards, level-1 towers until the maze was full, upgrades only after. That plays these rules badly. Until the first wall is whole, creeps walk round its end and meet one tower, so waves 3 and 7 came down to whether that tower was a Cannon. It put Cannons and Bards on the flight line, owned 16 Bards, never upgraded its Archers, and collapsed as soon as late creeps got tougher. It wasn't a fair yardstick for these rules.

Under `eletd` the smart strategy is now its own planner (`src/bots/route_liner.gd`). Before each purchase it counts, for every creep type in the wave preview, how much damage one creep would take on its way past: ground creeps along the route as it stands, or as the new tower would bend it, and flyers along the straight portal-to-gate line. Each tower counts by the tiles of route it reaches, its damage against that creep's class, element and armor, and any Bard aura on it. It then buys the build, upgrade or fusion that adds the most per gold, or saves up when the best one costs more than it has. What that looks like in a game:

- **It lines the straight route first.** The opening towers stand on both sides of the street from portal to gate, on the serpentine's wall rows, so every creep walks past all of them from wave 1. It bends that street into the serpentine a step at a time: wall off the next row on the side the creeps will come from, then close the current wall, so they walk the whole new lane and rejoin the street. Up to three such steps are priced as one purchase, and it buys one when a longer route pays more than upgrades do. On the Citadel the first wall closes between waves 18 and 30.
- **Counters go where the creeps walk.** Cannons and Plague Cauldrons for the Footmen and Tanks, Archers against Dark creeps, air-capable towers on the tiles that reach the flight line. It builds few Bards, and only where they cover towers that are in reach.
- **It upgrades what the creeps pass.** Upgrades and new towers compete on the same price per gold, so it upgrades early, and the towers in reach of the most route come first.
- **It plans past the preview.** It reads only the next two waves, as a player can, but also keeps two yardsticks four waves ahead: a plain creep and a lone brute with 25 times its HP. Without the brute it spent waves 10 to 18 on upgrades that only pile onto creeps that were already dying early, and every boss leaked. It also counts a boss as six creeps (a leak costs 2 lives, and the boss walks again), and caps poison at the 5 stacks a creep can hold.

Classic play is unchanged, and so are the archers, no_air and novice bots. The classic check still ends with 20 lives, 2 close calls and 12,110 gold at 34:09.

**Base settings** (a flat 15% HP share, before [the climbing curve below](#element-td-rules-an-hp-curve-that-climbs-2026-10-04)), 4 seeds each:

| Map | Strategy | Mode | Wins | Lives (mean, min–max) | Close calls | Walked w1–5 | Walked, non-boss median | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|---|---|---|
| Citadel | smart | normal | 4/4 | 20.0, 20–20 | 0.0 | 25% | 30% | 54% / 55% / 51% / 36% | – |
| Citadel | smart | hard | 4/4 | 20.0, 20–20 | 3.5 | 25% | 33% | 60% / 66% / 63% / 53% | – |
| Rampart | smart | normal | 4/4 | 20.0, 20–20 | 1.0 | 24% | 30% | 45% / 47% / 48% / 42% | – |
| Rampart | smart | hard | 4/4 | 20.0, 20–20 | 4.0 | 21% | 30% | 46% / 52% / 65% / 62% | – |

Nothing leaks in any of the 16 games, so no opening wave costs a life. The old bot on the same settings kept 15.0 lives on the Citadel (4 seeds, in the section above) and 14.5 on the Rampart (2 seeds), losing them on waves 2 and 3, and on the Rampart wave 38 as well.

**Stress settings**, a measuring device only: `HP_FROM` 0.22, `HP_TO` 0.45, `ARMORED_HP_TO` 0.7, so that the smart bot has something to lose. Smart, Normal, 4 seeds:

| Map | Bot | Wins | Lives (mean, min–max) | Close calls | Walked w1–5 | Walked, non-boss median | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|---|---|
| Citadel | old | 0/4 | 0.0, 0–0 | 8.2 | 63% | 28% | 46% / 54% / 100% / 96% | w38, w40, w40, w40 |
| Citadel | new | 4/4 | 11.5, 8–15 | 6.0 | 21% | 33% | 77% / 100% / 98% / 100% | – |
| Rampart | old | 0/4 | 0.0, 0–0 | 7.8 | 43% | 33% | 46% / 66% / 100% / – | w38, w38, w38, w38 |
| Rampart | new | 4/4 | 13.5, 12–15 | 7.0 | 23% | 35% | 65% / 92% / 97% / 100% | – |

Lives lost per wave, all 4 seeds: Citadel {20: 4, 30: 4, 40: 26} · Rampart {30: 4, 40: 22}. The old bot lost {2: 4, 3: 7, 4: 7, 30: 8, 36: 27, 38: 19, 40: 8} on the Citadel and {2: 1, 3: 10, 30: 16, 36: 32, 38: 22} on the Rampart. Every life the new bot loses is a boss, and the Dreadlord on wave 40 costs 5 to 8 a game. In the game traced it got through once with 21% of its HP left and four of its Felhounds, then died on its second pass. With the Dreadlord at the strength these settings give it (about 36,000 HP, armor 12), a maze that kills it on its first pass would need roughly 140 level-3 Archers' worth of fire on a full serpentine. That is most of a game's income, so wave 40 is where a stress tuning bites.

Tried and dropped, all at the stress settings (2 or 4 seeds, mean lives Citadel / Rampart):

| Change | Result |
|---|---|
| Lining the street only, never bending it into the serpentine | Lost at wave 38 even at base settings (one game, Citadel) |
| No yardsticks: plan for the preview only | 4.0 / 7.5 (2 seeds, before the poison cap). Every boss leaks |
| Brute at 12× a creep's HP, weight 0.5 | 7.5 / 10.0 (2 seeds); 25× at weight 1 gives 11.5 / 13.5 |
| Brute (12×) weighted 2 or 4 | 11.0 / 10.0 (2 seeds) and 5.5 / 7.5 |
| Brute at 40×, weight 1 | 10.0 / 13.5 |
| Serpentine steps priced 3× or 10× higher, to grow the maze early | 9.0 / 11.0 and 0.0 / 1.0 (2 seeds, brute at 12×): a long maze of level-1 towers loses waves 36 to 40 |
| Boss counted as 10 creeps instead of 6 | 10.8 / 13.8, the same within noise |
| Bosses need 1.6× or 2× the damage margin of other creeps | 8.5 / 13.0 and 9.5 / 8.5 (2 seeds) |
| Damage margin 1.2 or 2 instead of 1.5 | 9.0 / 12.0 and 10.0 / 9.0 |
| Runesmith priced for the armor its shred strips for the other towers | 6.2 / 12.0; weighted twice as much, 1.2 / 3.5 with four games lost on waves 33 to 40: it buys Runesmiths for every armored wave |
| Felhounds added to the Dreadlord's preview | No change: they die anyway |

## Element TD rules: an HP curve that climbs (2026-10-04)

With the bot above, a flat 15% creep HP share is far too easy: the smart bot keeps all 20 lives in every game on both maps, Normal and Hard. The share now climbs on a straight line, 15% on wave 1 to 60% on wave 40, so every wave is at least as tough as the one before and the late waves are the hard ones, as in Element TD. Armored creeps climb on their squared curve to 62%. Three things are set wave by wave or mode by mode, all in `src/data/eletd_rules.gd` and all only under `eletd`:

- **The wave-10 Ogre has 1.7 times its HP.** At 1.0 nothing leaks before wave 20, so the first third of the game never costs a life. At 1.7 it leaks once in most games.
- **The Dreadlord has a third of its HP.** At full share it outlasts any maze: it walks round four or five times and takes 7 to 13 lives, more than the rest of the game together. A 30% cut did nothing (it still took 7 to 11); at a third it mostly dies on its first pass, near the gate.
- **Hard has its own ramp, 1.03 to 1.12** instead of classic's 1.1 to 1.4. On top of a share that already quadruples, classic's ramp lost every game; 1.05 to 1.2 still lost all six.

Final settings, 4 seeds per row:

| Map | Strategy | Mode | Wins | Lives (mean, min–max) | Close calls | Walked w1–5 | Walked, non-boss median | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|---|---|---|
| Citadel | smart | normal | 4/4 | 11.8, 11–12 | 7.8 | 25% | 37% | 100% / 100% / 100% / 58% | – |
| Citadel | smart | hard | 3/4 | 7.8, 0–12 | 7.5 | 25% | 41% | 100% / 100% / 100% / 65% | w35 |
| Citadel | archers | normal | 0/4 | 0.0, 0–0 | 5.0 | 25% | 24% | 100% / 56% / 100% / – | w33, w33, w33, w33 |
| Citadel | no_air | normal | 0/4 | 0.0, 0–0 | 3.2 | 72% | 100% | – / – / – / – | w5, w5, w5, w5 |
| Citadel | novice | normal | 0/4 | 0.0, 0–0 | 6.0 | 43% | 27% | 100% / 75% / 100% / – | w36, w30, w30, w36 |
| Rampart | smart | normal | 4/4 | 12.2, 8–18 | 8.2 | 22% | 35% | 99% / 100% / 100% / 66% | – |
| Rampart | smart | hard | 3/4 | 9.0, 0–16 | 9.2 | 25% | 36% | 100% / 100% / 100% / 80% | w38 |
| Rampart | archers | normal | 0/4 | 0.0, 0–0 | 5.0 | 26% | 28% | 100% / 69% / 100% / – | w33, w33, w33, w33 |
| Rampart | no_air | normal | 0/4 | 0.0, 0–0 | 4.0 | 85% | 100% | – / – / – / – | w5, w5, w5, w5 |
| Rampart | novice | normal | 0/4 | 0.0, 0–0 | 6.5 | 49% | 29% | 100% / 100% / – / – | w26, w20, w26, w26 |

Lives lost per wave, all 4 seeds:

| Row | Citadel | Rampart |
|---|---|---|
| smart, normal | {10: 8, 20: 8, 30: 16, 33: 1} | {10: 4, 20: 6, 23: 2, 30: 12, 35: 5, 38: 1, 40: 1} |
| smart, hard | {10: 8, 20: 8, 29: 1, 30: 18, 33: 5, 35: 6, 38: 1, 40: 2} | {10: 4, 20: 6, 23: 5, 30: 12, 35: 11, 38: 4, 39: 1, 40: 1} |
| archers | {10: 8, 26: 4, 30: 40, 33: 28} | {10: 8, 26: 12, 30: 48, 33: 12} |
| no_air | {1: 10, 2: 3, 4: 4, 5: 63} | {1: 12, 2: 46, 4: 12, 5: 10} |
| novice | {3: 28, 4: 2, 7: 12, 10: 8, 26: 15, 30: 12, 36: 3} | {2: 29, 3: 12, 6: 2, 7: 12, 8: 3, 10: 8, 20: 8, 26: 7} |

What it shows:

- The smart bot wins every Normal game with 8 to 18 lives and loses them across the game: the wave-10, 20 and 30 bosses in nearly every game, and late on the armored waves 23, 33, 35 and 38. No wave other than a boss costs it more than 3 lives in a game.
- Hard wins 3 of 4 on each map. The lost games fall apart on the armored waves 33 to 38.
- The archers-only bot loses on wave 33 on both maps, after the twin Ogres on wave 30 take 10 to 12 lives. The ground-only bot loses on wave 5, the first Harpies, having lost 3 to 17 lives on waves 1 to 4.
- **The novice lives too long.** It loses on waves 20 to 36, mostly 26 and 30, where the aim was 10 to 25. It loses half its lives on waves 2 to 7, then plays the middle of the game better than the smart bot does: on the non-boss waves 11 to 25 the median creep walks 22 to 27% of the route against it, and 31 to 45% against the smart bot (the archers-only bot: 18 to 19%). Its long serpentine of upgraded Archers holds the mid-game while the smart bot is still lining the street and saving for later waves, so any HP that kills the novice there kills the smart bot first. It dies to its first element test, the stone Harpies and Tanks of wave 26, which its light Archers hit for half. A higher HP_FROM only moves it to the other cliff: at 0.17 it loses on wave 7 in some games.
- Creeps walk 22 to 25% of the route on waves 1 to 5. Raising that means a higher HP_FROM, which the novice and the ground-only bot can't stand.

Tried on the way, with the smart bot on Normal unless a row says otherwise (mean lives Citadel / Rampart):

| Line, armored to | Boss HP | Hard | Seeds | Result |
|---|---|---|---|---|
| 0.22 → 0.45, 0.7 | – | classic | 2 | Smart 14.0 / 13.5, every life on waves 30 and 40; Hard 0/2 on both maps; novice loses on wave 7, ground-only on wave 3 on the Rampart |
| 0.12 → 0.45, 0.7 | – | classic | 2 | Smart 12.5 / 14.5, every life on wave 40; Hard 0/2 on both; novice loses on waves 36 to 40 |
| 0.12 → 0.6, 0.7 | – | – | 2 | 7.0 / 6.0; the Dreadlord takes 7 to 13 lives a game |
| 0.12 → 0.75, 0.8 | – | – | 2 | 0/2 on both maps, lost on waves 35 to 40; novice loses on waves 26 to 31 |
| 0.12 → 0.45, 1.0 | – | – | 1 | Novice loses on waves 36 and 38, archers on 33 |
| 0.16 or 0.18 → 0.45, 0.7 | – | – | 1 | Novice: 39 and 36 at 0.16; 7 and 30 at 0.18 |
| 0.17 → 0.6, 0.7 | 40: 0.7 | – | 2 | 8.0 / 5.5; the Dreadlord still takes 7 to 11; novice loses on 7, 10 or 26 |
| 0.15 → 0.65, 0.75 | 10: 1.3, 40: 0.35 | – | 2 | 10.5 / 12.0, nothing lost before wave 20 |
| same | 10: 1.6, 20: 1.3, 40: 0.35 | 1.05 → 1.2 | 2 | 4.0 (one game lost) / 3.5; Hard 0/2 on both |
| 0.16 → 0.65, 0.7 | 10: 1.45, 20: 1.6, 40: 0.35 | – | 3 | 2.0 (one lost) / 10.7. A bigger wave-20 Ogre costs the smart bot more than the novice |
| 0.15 → 0.6, 0.7 | 10: 1.4, 40: 0.4 | 1.03 → 1.1 | 3 | 13.3 / 14.3; Hard 3/3 and 2/3 |
| 0.15 → 0.63, 0.7 | 10: 1.5, 40: 0.4 | 1.05 → 1.2 | 3 | 12.0 / 12.7; Hard 0/3 on both; novice loses on waves 20 to 36 |
| same, HP_FROM 0.165 or starting gold 360 | | | 3 | Novice and ground-only only: novice still loses on waves 26 to 36 |
| 0.15 → 0.63, 0.7 | 10: 1.7, 40: 0.4 | 1.03 → 1.1 | 4 | 6.8 / 2.5, three games lost on waves 38 to 40 |
| 0.15 → 0.6, 0.7 | 10: 1.6, 40: 0.4 | 1.03 → 1.12 | 4 | 8.5 / 8.2; wave 35 costs up to 7 lives; Hard 2/4 and 3/4 |
| 0.15 → 0.6, 0.62 | 10: 1.7, 40: 0.4 | 1.03 → 1.12 | 4 | 11.8 / 10.0 with one Rampart game lost on wave 40; Hard 3/4 on both |
| **0.15 → 0.6, 0.62** | **10: 1.7, 40: 0.33** | **1.03 → 1.12** | 4 | **The settings above** |

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
