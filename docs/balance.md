# Balance log

This is the record of how Maze Citadel's numbers were tuned. Six bots play full games with no window and report how far they got. This page keeps their results, the targets they're measured against, and the reasoning behind each change. After the targets come the Element TD rules' sections, in the order the work was done, and then the classic game's history. The rules and numbers as they are now are in [GDD.md](GDD.md).

The game has two rule sets. The Element TD rules (`eletd` in the code) are the default a player gets, and every section headed "Element TD rules" tuned them. The classic rules are the game as released in 0.3.1; the sections without that heading tuned them, and they no longer change. Every change under the Element TD rules is checked against the classic game, which must still play exactly as released: the smart bot on Normal, seed 0, wins with 20 lives, 2 close calls and 12,110 gold at 34:09.

## Running the bots

```sh
godot --headless --path . --script res://tests/bots/run_balance.gd
```

It plays the Element TD rules, the game's default, on the Citadel Plateau. Every table on this page that isn't under an "Element TD rules" heading was measured on the classic rules, and `-- --rules=classic` reproduces it. A full run plays 4 seeds of every row. On the classic rules that takes about 8 minutes on one core; an Element TD game takes 40 to 70 seconds, so the full Element TD table is best run as a few processes side by side, each with its own `--only`. Options go after a `--`:

| Option | What it does |
|---|---|
| `--only=smart:hard` | Runs a single row, or several separated by commas. The difficulty can also be `easy` or `very_hard`, except under `--rules=classic`. The rows the latest tables use are `smart:normal,smart:hard,smart:easy,smart:very_hard,archers:normal,no_air:normal,novice:normal,novice:easy,camper:normal,idle:normal,camper:very_hard,idle:very_hard` |
| `--seeds=N` | Sets how many games each row plays |
| `--per-wave` | Prints how far each wave got, the unspent gold at each wave's start and the first wave without a boss that leaked |
| `--twists` | Plays Twists mode, with bot seed n on twist schedule n + 1 |
| `--map=rampart` | Plays on Fallen Rampart; `--map=causeway` plays on the Winding Causeway, under the Element TD rules only |
| `--rules=classic` | Plays the classic rule set instead of the Element TD one |
| `--picks=aqua,dark,dark,interest` | Under the Element TD rules, starts every game with these element levels and Interest picks already taken, with no Guardians, on top of the picks the bots spend themselves |

## The bots

| Bot | Plays like |
|---|---|
| smart | Serpentine maze of six 1-tile walls built where creeps walk; reads the next wave and buys its element and armor counters; saves up for a siege, anti-air or anti-boss tower when one of the next two waves needs it and it owns fewer than two; upgrades with surplus gold, but saves for Runesmith, Demolisher and Cannon upgrades when the next wave has a boss; fuses Epics of all four families between waves, only with gold to rebuild the freed wall tile; ignores twists |
| smart, `eletd` rules | Prices every build, upgrade and fusion by the damage it adds to the creeps in the wave preview on their way past, and buys the best per gold ([below](#element-td-rules-a-smart-bot-that-lines-the-route-2026-10-04)). Weighs its element picks once per breather against the wave table, and summons a Guardian only when its route can kill it ([below](#element-td-rules-the-smart-bot-plays-its-picks-2026-10-04)) |
| archers | Same maze, archers only, upgrades archers |
| no_air | Ground-only towers (cannon, roots, shadow) |
| novice | Same maze, built one tower every 4 seconds; archers, cannons and frost in a fixed order with no thought for the next wave; never fuses |
| camper | The owner's recorded 0.4.1 game on the Citadel: Archer walls as close under the portal as the board allows, its first wall closed to the east edge where the band by the portal takes his corner tower, all gold spent as it comes, his sell-and-swap habit, his five picks and no upgrades before wave 21 ([below](#element-td-rules-two-human-yardsticks-2026-10-05), [closing the wall](#element-td-rules-a-harder-opening-for-a-person-2026-10-05)) |
| idle | The camper's opening from the starting gold, then nothing at all |

Each row is 4 games. Seed 0 is the bot's plain plan; seeds 1–3 jitter its decision timing, which wall tile it fills next and which counter it prefers, so one lucky or unlucky trajectory doesn't decide a target. Columns:

- **Close calls:** waves (per game) where some creep walked at least 80% of its route, leaks included. It shows pressure that lives alone hide.
- **Walked w1–5:** how far creeps got on the first five waves, averaged. A low number means they died at the portal.
- **Walked, non-boss median:** the middle value of how far each non-boss wave got.
- **Boss walked:** how far the boss got on each boss wave, averaged; 100% means it leaked.

## Targets

### Element TD rules

The default rules are tuned to be harder than classic and to make the element picks matter. The status is from the final table of [a harder opening for a person](#element-td-rules-a-harder-opening-for-a-person-2026-10-05), 4 seeds per row on the Citadel Plateau unless a row names another map.

| Target | Status |
|---|---|
| The smart bot wins Normal with about 12 lives, losing them across the game rather than all at once | Met, a little lower: 4/4 with 9.2 lives (8–10) on the Citadel, 12.2 (9–16) on the Rampart and 8.8 (5–13) on the Causeway, lost to the Ogre waves 10, 20 and 30 and once to waves 25 and 26 |
| Hard is beatable but tight | Met: 2/4 with 3.0 lives; the lost games end on waves 23 and 30 |
| Very Hard: a good player gets well into the game, and the last waves are the wall | Partly met: 1 game won with 2 lives, the others lost on waves 21, 25 and 38. All but one get to wave 25 |
| Easy is comfortable | Met: 4/4 with 19.5 lives |
| The picks matter: elemental towers do most of the damage | Met: they deal 81% to 88% of all damage in the smart bot's Normal games |
| Guardians are a fair price for a level | Met: none of the 24 smart games' Guardians got through |
| The novice, with no thought for the next wave, loses on Normal but can win on Easy | Met: it loses on wave 6 on Normal and wins on Easy with 15.8 lives |
| The archers-only bot fails without counters | Met: it loses on wave 35 |
| The ground-only bot dies at the Harpy waves | Met: it loses on wave 5 |
| The Winding Causeway plays about as hard as the Citadel on Normal | Met: 4/4 with 8.8 lives against 9.2 on the Citadel |

**Targets for a person's opening (issue #33, 0.4.2).** The owner's first recorded game found the opening far too easy for a person: his creeps died within the first tenth of the route on every wave before the wave-10 boss. These targets measure the opening with the camper and idle bots, which play his habits.

| Target | Status |
|---|---|
| T1: against the camper on Normal, waves 1 to 5 walk at least 35% of the route on average | Not met as meant: 22, 26, 32, 26 and 100% (41% on average), but only because wave 5 leaks 3 lives; waves 1 to 4 average 26%. Where creeps first meet the wall sets this, not their HP ([below](#what-hp-can-and-cant-do)) |
| T2: the idle bot's first leak outside a boss wave comes on wave 3 to 5 | Met: wave 3 (9 lives), lost on wave 6 |
| T3: Very Hard has at least 1.5 times Normal's HP on waves 1 to 5, and the camper fares clearly worse there | Met: 1.5 times, and the camper loses on wave 3 against wave 28 to 34 on Normal |
| T4: the smart bot wins Normal 4 games in 4, losing 5 to 12 lives | Met: 4/4, 10.8 lives lost (10 to 12) |
| T5: the smart bot loses most Very Hard games, but at wave 25 or later; it wins about half its Hard games | Partly met: Very Hard as in the table above, one loss on wave 21; Hard 2/4 |
| T6: the starting gold can't close a whole row under the band | Met: 400 gold buys 16 Archers, and a row with a gap needs 19 |
| T7: the novice survives Easy to wave 15 or later, and the archers-only bot loses Normal | Met: the novice wins Easy 4/4; the archers bot loses on wave 35 |
| T8: the smart bot wins Normal on the Rampart and the Causeway, losing at least 3 lives | Met: 4/4 on both, 7.8 and 11.2 lives lost |
| T9: wave 5, the first Harpies, needs about four level-1 Archers beside the flight line on Normal | Met: one, two or three Archers let 14 to 18 leaks through, four hold it |

**Known gap: weak elements.** Aqua, Stone and Verdant are weak picks. Their towers, the Frost Spire, the Runesmith Forge and the Ancient of Roots, pay about a third of a Ballista's damage per gold or less, and their slows, shred and roots, which the smart bot's price model counts only as a flat bonus, don't make up the difference. So the smart bot builds every game around Dark, Flame and Light, takes Aqua at most as a late extra pick and never takes Stone or Verdant. A later release addresses it.

### Classic rules (PLAN M6 gate)

These were the targets of the game as released, and the classic rules still meet them.

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

## Element TD rules: the interest lock and four difficulties (2026-10-04)

Two Element TD rules arrived together. A leak now stops interest until the field is clear, and there are four difficulties instead of two: Easy (creeps at 75% HP), Normal, Hard (the ramp above) and Very Hard (1.12 on wave 1 rising to 1.3 on wave 40, a first guess). Neither was tuned here.

The lock costs the smart bot almost nothing, because it spends its gold as it comes and earns very little interest. Its Normal games on the Citadel went from 11.5 lives (11 and 12) to 11.0 (10 and 12) over the same two seeds, with the same waves leaking.

Citadel, 2 seeds per row:

| Strategy | Mode | Wins | Lives (mean, min–max) | Close calls | Walked w1–5 | Walked, non-boss median | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|---|---|
| smart | easy | 2/2 | 20.0, 20–20 | 3.0 | 22% | 34% | 98% / 90% / 94% / 37% | – |
| smart | normal | 2/2 | 11.0, 10–12 | 7.0 | 21% | 41% | 100% / 100% / 100% / 56% | – |
| smart | hard | 1/2 | 5.0, 0–10 | 9.0 | 21% | 40% | 100% / 100% / 100% / 72% | w33 |
| smart | very_hard | 0/2 | 0.0, 0–0 | 8.5 | 19% | 40% | 100% / 100% / 100% / 92% | w38, w40 |

Lives lost per wave, both seeds: hard {10: 4, 20: 4, 23: 2, 29: 3, 30: 12, 33: 4, 40: 1} · very_hard {10: 4, 20: 4, 30: 10, 33: 2, 35: 8, 36: 1, 38: 7, 40: 4}

Easy never leaks, and Very Hard is lost late in both games, on the armored waves 35 and 38 and the Dreadlord. Both are where a later retune starts.

## Element TD rules: wave shapes (2026-10-04)

Element TD sends long, tight streams, so how much of the lane a maze covers matters more than any one tower. Under `eletd` every group except a boss now has one and a half times the creeps, 0.6 s apart instead of 0.9 (fast creeps 0.35 s instead of 0.5). Each creep carries the matching share of the HP and the bounty, so a wave's total HP and gold are unchanged. Waves 14, 27 and 34 are now composite (every element deals 90%), and waves 12, 18, 25 and 37 are Bulky (half the creeps, each with 2.5 times the HP and twice the bounty, 2 lives a leak). None of this was tuned here.

It barely moves the smart bot on Normal. Over the same two Citadel seeds it went from 11.0 lives (10 and 12) to 12.0 (12 in both), with 9.0 close calls a game against 7.0 before. It still loses lives only to the wave-10, 20 and 30 bosses: {10: 4, 20: 4, 30: 8}. The composite and Bulky waves cost it nothing, even though a Bulky wave carries about a quarter more HP than the wave it replaces. They are left for the retune.

## Element TD rules: element picks and Guardians (2026-10-04)

Under `eletd` a tower now needs its element: one pick at the start and one after each of waves 5, 10, 15, 20, 25, 30 and 35, spent on an element level or on Interest. The first element pick is granted at once; every later one summons a Guardian, a boss that grants the level only when it dies and costs 3 lives a leak. The Archer and the Cannon need no element and now deal composite damage, the same to every element. The rules are in [GDD.md](GDD.md#50-rule-sets). Nothing was tuned here: the Guardian's HP is a first guess.

The bots spend each pick as soon as they have it. The archers-only bot takes Interest three times. The ground-only bot takes Dark, then Verdant, then levels both, and builds Cannons where its pattern wants a tower it can't have yet. The novice takes Aqua, then Light, Dark, Flame, Stone and Verdant at level 1, then Interest. The smart bot only buys what its elements allow, and gives each pick to the element of the best purchase it is locked out of. Playing the picks well is left for later.

Citadel, 2 seeds per row:

| Strategy | Mode | Wins | Lives (mean, min–max) | Close calls | Walked w1–5 | Walked, non-boss median | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|---|---|
| smart | normal | 1/2 | 3.0, 0–6 | 9.5 | 31% | 43% | 100% / 100% / 100% / 98% | w40 |
| smart | hard | 1/2 | 0.5, 0–1 | 7.0 | 30% | 43% | 100% / 100% / 100% / 99% | w40 |
| archers | normal | 0/2 | 0.0, 0–0 | 8.0 | 26% | 26% | 100% / 100% / 100% / – | w38, w38 |
| no_air | normal | 0/2 | 0.0, 0–0 | 2.0 | 51% | 23% | – / – / – / – | w5, w5 |
| novice | normal | 0/2 | 0.0, 0–0 | 2.0 | 34% | 22% | – / – / – / – | w6, w6 |

Lives lost per wave, both seeds: smart/normal {10: 4, 20: 4, 25: 4, 30: 7, 35: 3, 40: 12} · smart/hard {10: 4, 20: 4, 25: 4, 30: 9, 35: 6, 40: 12} · archers {10: 4, 20: 4, 25: 4, 30: 4, 35: 11, 38: 13} · no_air {2: 9, 5: 31} · novice {3: 22, 5: 6, 6: 12}

What it shows:

- The smart bot on Normal fell from 12.0 lives (12 in both games, the section above) to 3.0, and lost one game on the Dreadlord. It spent its picks on Light, Dark and Flame, and once on Aqua, never on Interest. It now loses lives on the Bulky wave 25 and, in one game, to the wave-35 Guardian, and the Dreadlord takes 3 to 9.
- The novice now dies on wave 6, where it used to live to wave 20 or later. Its Cannons no longer deal double to the Verdant Footmen of wave 3, nor its Archers to the Dark Ghouls of wave 6, and its first Guardian leaks.
- The archers-only bot lives longer, to wave 38 against 33: composite arrows lose nothing to the Stone waves that used to halve them, and three Interest picks pay more.
- The ground-only bot still dies on wave 5, the first Harpies.

## Element TD rules: the smart bot plays its picks (2026-10-04)

The smart bot spent each pick the moment it had it, on the element of the best purchase it was locked out of, and summoned every Guardian as soon as the pick came. About one Guardian in seven got through, at 3 lives each. It now plays its picks the way a player who knows the wave table would, so that it stays a fair yardstick for these rules. Nothing in the game's numbers changed.

Once in each breather, and once before wave 1, it weighs every pick against the creeps of the next ten waves, reading further waves for less. Those are the waves the Field Guide lists for anyone to read. An element is worth what the purchases it unlocks add for the gold the bot will have before the next pick, counting only purchases worth at least half as much per gold as the best one open now, since it would never get round to the rest. A level that lets every Plague Cauldron climb a step can be worth more than a new element's best tower. Interest is worth the gold it would add by the next pick, and it wins only when no element is worth more.

A Guardian is treated as a lone boss the route must kill, and its damage is summed the way the bot already sums it for its lone brute. The bot summons one only when its route would deal one and a half times the Guardian's HP in one pass. It also waits for a breather that comes before a wave without a boss, and never summons a second Guardian while one is walking. Otherwise it keeps the pick in hand, but it never takes more than two picks into a wave with no Guardian walking. A third goes on whatever costs the fewest lives, which is Interest when that is still open. It builds from at most four elements. The balance runner now prints each game's picks (`picks: dark@0, dark@5, ...`, the wave being the last one started) and how many Guardians were summoned, got through and cost lives.

Smart bot, 4 seeds per row, before (the bot of the section above) and after:

| Map | Bot | Mode | Wins | Lives (mean, min–max) | Close calls | Walked w1–5 | Walked, non-boss median | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|---|---|---|
| Citadel | before | normal | 3/4 | 3.8, 0–8 | 8.8 | 31% | 43% | 100% / 100% / 100% / 98% | w40 |
| Citadel | after | normal | 4/4 | 6.2, 3–8 | 8.8 | 37% | 44% | 100% / 100% / 100% / 96% | – |
| Citadel | before | hard | 1/4 | 0.2, 0–1 | 6.8 | 31% | 41% | 100% / 100% / 100% / 99% | w40, w30, w36 |
| Citadel | after | hard | 1/4 | 1.0, 0–4 | 7.5 | 36% | 42% | 100% / 100% / 100% / 96% | w40, w40, w30 |
| Rampart | before | normal | 2/4 | 1.5, 0–4 | 9.8 | 28% | 41% | 100% / 100% / 100% / 93% | w36, w36 |
| Rampart | after | normal | 3/4 | 5.0, 0–9 | 8.8 | 25% | 40% | 100% / 100% / 100% / 92% | w40 |
| Rampart | before | hard | 0/4 | 0.0, 0–0 | 9.0 | 28% | 39% | 100% / 100% / 100% / 96% | w36, w40, w40, w35 |
| Rampart | after | hard | 0/4 | 0.0, 0–0 | 9.8 | 26% | 39% | 100% / 100% / 100% / 97% | w40, w40, w40, w30 |

Guardians, all 4 seeds: before, 16 of 109 got through (3 to 5 in each row) and cost 48 lives; after, none of 73 did. Lives lost per wave after: Citadel normal {10: 8, 20: 8, 25: 6, 30: 10, 40: 23}, hard {10: 8, 20: 8, 25: 20, 28: 1, 29: 1, 30: 15, 35: 6, 40: 18}; Rampart normal {10: 8, 20: 8, 25: 16, 29: 2, 30: 10, 40: 16}, hard {10: 8, 20: 8, 23: 5, 25: 26, 29: 2, 30: 12, 35: 6, 39: 1, 40: 13}.

Three games, read as a player would:

- **Citadel, Normal, seed 0** (won, 8 lives): `dark@0, dark@5, dark@10, interest@15, flame@20, interest@25, flame@30, interest@36`. Dark first because the Plague Cauldron's poison ignores armor, reaches flyers and does double to Aqua creeps, and the first ten waves bring armored Footmen and Tanks on 3, 7 and 9, Harpies on 5 and Aqua on 4 and 9. The next two Dark levels let all its Cauldrons climb a step (in the games traced it had about fifteen by wave 5). At wave 15 nothing a new element unlocks is worth half as much per gold as the best purchase open, so it takes Interest. Flame comes at 20, for Demolishers to use siege on the armored stretch of waves 21 to 25. It holds the wave-35 pick for one breather, because no Guardian it could summon would die on its first pass. Then it takes Interest, since too few waves are left for a level to pay.
- **Fallen Rampart, Normal, seed 1** (won, 9 lives): `dark@0, dark@5, dark@10, flame@15, light@20, light@25, flame@30, interest@38`. It goes three deep in Dark as above and ends with 26 level-3 Cauldrons. Then come Flame for the armored waves, Light at 20 and 25 for Ballistas (Light does double to the Dark creeps of waves 25 and 32, and the Ballista hits Harpies), and a second Flame level at 30 for the armored waves 33, 35 and 38. It holds the wave-35 pick through three breathers, because no Guardian it could summon then would die on its first pass, and at wave 38 it takes the gold.
- **Fallen Rampart, Normal, seed 2** (won, 5 lives): `dark@0, dark@5, dark@10, interest@15, flame@20, interest@25, light@30, flame@35`. It is the same build, with Interest where no element paid, and every Guardian, including the one summoned at 35, died on its first pass.

What it shows:

- Mean lives rise on both maps on Normal (3.8 to 6.2 on the Citadel, 1.5 to 5.0 on the Rampart) and on the Citadel on Hard. Rampart Hard stays at 0, though three of its four games now last until wave 40. The gain is about what the Guardians used to cost, 2 to 4 lives a game.
- Every game builds the same core: Dark to level 3 by wave 10, then Flame, and Light in most games. That is three or four elements, with Interest when nothing else pays.
- A new element's towers come slowly. The Demolishers from a wave-15 or wave-20 Flame pick first appear around wave 30, because Archer upgrades stay cheaper per gold until then. That comes from the composite starters' strength and the per-gold buyer, not from the picks, and is left for the retune.
- The losses are where they were: the Bulky wave 25, the boss waves and the Dreadlord.

Tried on the way (mean lives, Citadel Normal / Citadel Hard / Rampart Normal / Rampart Hard, 4 seeds unless a row says otherwise):

| Pick valuation | Result |
|---|---|
| Best purchase an element unlocks, against the best one open | Took Interest with the free first pick, because the starters are the best value per gold early on. Scaled by the coming bounty instead, it took Dark first but lost both Citadel Normal games it played. Dropped |
| Unlocked purchases within the budget, all counted, ten waves fading by 0.85 | 4.8 / 0.8 / 1.8 / 1.2. Picks sat unused for 10 to 15 waves: Aqua at 25 and no Frost Spire ever built |
| The same, at most three elements | 3.5 / 0.0 / 4.5 / 1.2 |
| Unlocked purchases counted only for what they add over the last purchase the budget buys anyway | Took Interest with the free first pick in 3 of 4 games; 5.5 on Citadel Normal with one game lost. Dropped |
| **Ten waves fading by 0.6, purchases counted at half the best one's value per gold or more** | **6.2 / 1.0 / 5.0 / 0.0, the bot above** |

## Element TD rules: the smart bot's last picks (2026-10-04)

The bot used to hold a pick for as long as an element it could not yet summon safely was worth more than Interest. A Guardian's HP grows with the wave, so that element often never became safe, and after wave 35 no third pick ever arrived to force the held one out. The bot now takes Interest at once when the wave-35 pick is in. It also never lets a forced third pick summon a Guardian just before a boss wave; Interest goes then instead.

Smart bot, Normal, Citadel, 2 seeds: the results are unchanged (won with 8 and 6 lives). The last Interest pick now comes at wave 35 instead of 36 or 38, which adds 18 gold to one game. On Fallen Rampart, Very Hard, seed 1 still loses on wave 35 holding the picks of waves 25 and 30. Before wave 35 is cleared, the bot keeps up to two picks in hand by design.

## Element TD rules: retune after element picks (2026-10-04)

Element picks, Guardians, the interest lock, four difficulties and the new wave shapes all arrived untuned. Before this retune the smart bot won every Normal game on the Citadel with 6.2 lives, 3 of 4 on the Rampart with 5.0, 1 of 4 and 0 of 4 on Hard, kept all 20 lives on Easy and lost both Very Hard games. It took Dark three times, then Interest wherever nothing else paid, built its new element's towers late and leaned on upgraded Archers. This section makes the elemental towers the better buy once their element is picked, then retunes the HP numbers around that. Every change is under `eletd` only; classic play is unchanged, and the classic check still ends with 20 lives, 2 close calls and 12,110 gold at 34:09.

The balance runner now prints a line per `eletd` game with the share of all damage dealt by towers that need an element and by Epics, and each tower type's share, from the towers' own damage counters (sold and fused-away towers included): `elemental damage 60% (archer 40%, plague 30%, demolisher 22%, ballista 7%)`. Before the retune it read 42% and 48% on the Citadel and 30% and 37% on the Rampart (2 seeds each), with Archers dealing 49% to 63% of all damage.

### Why the bot preferred upgraded Archers

The smart bot buys whatever adds the most damage per gold to the creeps in the preview, and an element is worth a pick only if the purchases it unlocks come within half of the best buy open now. So the question is damage per gold per second under adjacent reach. The table is what the bot reckons for a creep in a stream (splash, pierce and slows counted by its `KIND_BONUS`), against each wave's creeps weighted by their HP, averaged over each third of the wave table. "Added" is what the level adds per gold of its own cost.

| Tower, level | Before: per gold, waves 1–13 / 14–26 / 27–40 | Before: added | After: per gold | After: added |
|---|---|---|---|---|
| Archer 1 | 0.72 / 0.58 / 0.56 | – | 0.72 / 0.58 / 0.56 | – |
| Archer 2 | 0.82 / 0.66 / 0.63 | **0.98 / 0.79 / 0.76** | 0.70 / 0.56 / 0.54 | 0.65 / 0.53 / 0.51 |
| Archer 3 | 0.77 / 0.62 / 0.60 | 0.71 / 0.57 / 0.55 | 0.61 / 0.50 / 0.48 | 0.52 / 0.42 / 0.40 |
| Cannon 3 | 0.50 / 0.56 / 0.57 | 0.55 / 0.61 / 0.62 | unchanged | unchanged |
| Plague Cauldron 2 | 0.58 / 0.48 / 0.48 | 0.63 / 0.53 / 0.52 | unchanged | unchanged |
| Ballista 1 | 1.12 / 0.79 / 0.72 | – | 1.56 / 1.11 / 1.00 | – |
| Demolisher 1 | 0.56 / 0.66 / 0.72 | – | 0.78 / 0.92 / 1.01 | – |
| Demolisher 3 | 0.66 / 0.78 / 0.85 | 0.78 / 0.91 / 1.00 | 0.93 / 1.09 / 1.19 | 1.09 / 1.28 / 1.40 |
| Frost Spire 1 | 0.27 / 0.24 / 0.23 | – | 0.37 / 0.34 / 0.33 | – |
| Shadow Obelisk 1 | 0.30 / 0.26 / 0.27 | – | 0.42 / 0.36 / 0.38 | – |
| Runesmith Forge 1 | 0.18 / 0.19 / 0.19 | – | 0.25 / 0.27 / 0.26 | – |
| Ancient of Roots 1 | 0.09 / 0.11 / 0.11 | – | 0.12 / 0.15 / 0.16 | – |

The Archer's level 2, +67% damage for 15 gold, added more per gold than any other tower level but the Ballista's and, from wave 14 on, the Demolisher's level 3 (Epic fusions aside), and it is open from wave 1 with no pick and no Guardian. The elemental towers were priced for range: the Ballista and Demolisher reached 12 and 15 m against the Archer's 9, and under adjacent reach every tower sees the same 3×3 tiles. A Demolisher, the bot's Flame tower, paid less per gold than an Archer's level-2 upgrade in every third of the game. Tracing the bot's picks showed the rest: at waves 15 and 25 the best open buy was usually a serpentine step or an Archer upgrade, no unlocked purchase came within half of it, every element was worth nothing and Interest won by default.

### What changed, and why

| Number | Was | Now | Why |
|---|---|---|---|
| Archer damage per level (`ARCHER_POWER`) | 100% | 100% / 85% / 80% | Level 2 and 3 Archers stop being the best buy per gold; level 1 is untouched, so the opening and the novice's maze are the same |
| Elemental tower damage (`ELEMENTAL_POWER`) | 100% | 140%, every tower that needs an element but the Plague Cauldron, clouds and craters included | Gives back what adjacent reach took from the long-range towers. The Cauldron keeps 100%: its poison works on after the creep walks on, and it was already the bot's first pick. Epics keep theirs |
| Guardian HP, level 1 | 0.5 of a lone Ogre | 0.35 | A level-1 Guardian of a new element walks into a maze built for the others: a Light Guardian takes half damage from a Dark maze. At 0.5 the bot often never dared summon its third element's Guardian and spent the pick on Interest |
| Creep HP line (`HP_FROM` → `HP_TO`) | 0.15 → 0.6 | 0.10 → 0.68 | With composite starters the novice has no counters in the opening and lost on wave 6 at 0.15 and at 0.11; 0.10 takes it to wave 30. The stronger elemental towers need a steeper end: at 0.6 the smart bot kept 18 lives on the Rampart |
| Armored HP to | 0.62 | 0.7 | Kept a little above the line, so armored creeps are never the easier ones at the end |
| Wave-10 Ogre | 1.7× | 2.1× | At 1.7 it got through on the Citadel but seldom on the Rampart, which then kept 15 lives on Normal; 2.1 also makes up for the lower line |
| Dreadlord | 0.33× | 0.3× | It took 9 lives and the game in one Normal game at 0.33. At 0.3 it dies on its first pass in every game of the final table, though it took 10 and 11 lives in two Normal games on the way there |
| Bulky HP (`BULKY_HP`) | 2.5× | 2.0× | A Bulky wave now carries the HP of the wave it replaces, in half the creeps. Wave 25 cost up to 6 lives on Normal at 2.5, and at 2.2 up to 10 on Very Hard, ending games before wave 30 |
| Easy | 0.75× | 0.7× | At 0.75 the wave-10 Ogre still got through on the Citadel, which kept 14.8 lives on Easy |
| Hard | 1.03 → 1.12 | 1.06 → 1.28 | To 1.12 Hard won as often as Normal once the elemental towers hit harder; to 1.3 it won 1 game in 4 on each map |
| Very Hard | 1.12 → 1.3, straight | 1.1 → 1.55, squared | On straight lines from 1.05 to 1.12 up to 1.5 to 1.65, some games ended on waves 28 to 30 at the Bulky wave 25 or the Tanks of wave 28. On the squared curve it stays close to Hard until about wave 25 and climbs steeply after, so wave 39 is the wall. It stays above Hard at every wave |

The bot's price model reads the new damage (`SimElements.power`) the way it already read composite damage, so it prices towers as the rules play them; nothing else in the bots changed. The tower cards, tooltips and upgrade preview show the damage these rules deal ("Dmg 9 → 12.75" for an Archer's level 2).

### Final results

4 seeds per row. The archers, ground-only and novice bots play the same game on every seed.

| Map | Strategy | Mode | Wins | Lives (mean, min–max) | Close calls | Walked w1–5 | Walked, non-boss median | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|---|---|---|
| Citadel | smart | easy | 4/4 | 15.2, 14–16 | 3.5 | 30% | 43% | 100% / 100% / 93% / 68% | – |
| Citadel | smart | normal | 4/4 | 12.0, 12–12 | 6.2 | 26% | 46% | 100% / 100% / 100% / 69% | – |
| Citadel | smart | hard | 2/4 | 4.0, 0–9 | 6.8 | 27% | 48% | 100% / 100% / 100% / 90% | w39, w40 |
| Citadel | smart | very_hard | 0/4 | 0.0, 0–0 | 7.5 | 27% | 50% | 100% / 100% / 100% / – | w39, w38, w39, w39 |
| Citadel | archers | normal | 0/4 | 0.0, 0–0 | 7.5 | 32% | 25% | 100% / 100% / 100% / – | w35, w35, w35, w35 |
| Citadel | no_air | normal | 0/4 | 0.0, 0–0 | 2.0 | 51% | 23% | – / – / – / – | w5, w5, w5, w5 |
| Citadel | novice | normal | 0/4 | 0.0, 0–0 | 4.0 | 35% | 24% | 100% / 100% / 100% / – | w30, w30, w30, w30 |
| Citadel | novice | easy | 4/4 | 14.2, 14–15 | 3.0 | 19% | 23% | 44% / 79% / 70% / 87% | – |
| Rampart | smart | easy | 4/4 | 18.5, 16–20 | 5.0 | 21% | 37% | 93% / 99% / 89% / 52% | – |
| Rampart | smart | normal | 4/4 | 13.0, 12–14 | 6.8 | 22% | 43% | 100% / 100% / 100% / 72% | – |
| Rampart | smart | hard | 2/4 | 3.2, 0–11 | 10.2 | 22% | 49% | 100% / 100% / 100% / 84% | w40, w39 |
| Rampart | smart | very_hard | 0/4 | 0.0, 0–0 | 8.8 | 22% | 46% | 100% / 100% / 100% / 99% | w39, w40, w39, w39 |
| Rampart | archers | normal | 0/4 | 0.0, 0–0 | 4.0 | 26% | 26% | 100% / 100% / – / – | w28, w28, w28, w28 |
| Rampart | no_air | normal | 0/4 | 0.0, 0–0 | 2.0 | 51% | 20% | – / – / – / – | w5, w5, w5, w5 |
| Rampart | novice | normal | 0/4 | 0.0, 0–0 | 5.0 | 50% | 31% | 100% / 100% / 100% / – | w30, w30, w30, w30 |
| Rampart | novice | easy | 0/4 | 0.0, 0–0 | 4.0 | 34% | 26% | 50% / 100% / 91% / 99% | w40, w40, w40, w40 |

Lives lost per wave, all 4 seeds:

| Row | Citadel | Rampart |
|---|---|---|
| smart, easy | {10: 4, 20: 8, 30: 4, 40: 3} | {20: 4, 30: 2} |
| smart, normal | {10: 8, 20: 8, 30: 16} | {10: 8, 20: 8, 29: 1, 30: 11} |
| smart, hard | {10: 8, 20: 16, 25: 2, 30: 16, 39: 15, 40: 7} | {10: 8, 20: 8, 30: 16, 33: 1, 38: 1, 39: 32, 40: 1} |
| smart, very hard | {10: 8, 20: 16, 23: 4, 25: 4, 29: 1, 30: 18, 38: 4, 39: 25} | {10: 8, 20: 10, 25: 16, 28: 4, 29: 2, 30: 24, 36: 1, 39: 13, 40: 2} |
| archers | {2: 6, 10: 8, 20: 8, 30: 12, 33: 20, 35: 26} | {10: 8, 20: 8, 25: 16, 28: 48} |
| no_air | {2: 20, 5: 60} | {2: 16, 5: 64} |
| novice, normal | {3: 36, 5: 12, 10: 8, 20: 8, 30: 16} | {2: 36, 3: 5, 5: 12, 10: 8, 20: 8, 30: 14} |
| novice, easy | {39: 19, 40: 4} | {2: 36, 5: 12, 20: 8, 40: 24} |

Smart bot on Normal, game by game:

| Map, seed | Lives | Picks | Elements at the end | Elemental damage | Guardians |
|---|---|---|---|---|---|
| Citadel 0 | 12 | `dark@0, dark@5, dark@10, flame@15, light@20, flame@25, interest@35, interest@36` | Light 1, Dark 3, Flame 2 | 60% (archer 40%, plague 30%, demolisher 22%, ballista 7%) | 5 summoned, none got through |
| Citadel 1 | 12 | the same | the same | 59% (archer 41%, plague 29%, demolisher 19%, ballista 11%) | 5, none |
| Citadel 2 | 12 | the same | the same | 57% (archer 43%, plague 33%, demolisher 13%, ballista 11%) | 5, none |
| Citadel 3 | 12 | the same | the same | 55% (archer 45%, plague 31%, demolisher 14%, ballista 10%) | 5, none |
| Rampart 0 | 14 | the same | the same | 64% (plague 35%, archer 30%, demolisher 21%, ballista 8%, cannon 5%) | 5, none |
| Rampart 1 | 12 | `dark@0, dark@5, dark@10, light@15, flame@20, flame@25, interest@35, interest@36` | Light 1, Dark 3, Flame 2 | 58% (archer 31%, plague 31%, demolisher 15%, ballista 12%, cannon 10%) | 5, none |
| Rampart 2 | 12 | `dark@0, dark@5, dark@10, flame@15, light@20, flame@25, aqua@32, interest@35` | Light 1, Dark 3, Aqua 1, Flame 2 | 62% (archer 38%, plague 29%, demolisher 25%, ballista 8%) | 6, none |
| Rampart 3 | 14 | as seed 0 | Light 1, Dark 3, Flame 2 | 65% (archer 35%, plague 31%, demolisher 24%, ballista 10%) | 5, none |

What it shows:

- **Normal** is won in every game with 12 to 14 lives, against 6.2 and 5.0 before. Lives go to the three Ogre waves, 2 to 4 each, and once to wave 29; no other wave costs a life. The Dreadlord dies on its first pass in all eight games.
- **The picks matter now.** Every Normal game takes 6 or 7 element picks and ends with three or four elements: Dark to level 3 by wave 10, Flame at 15 and 25 for Demolishers, Light at 20 for Ballistas, then Interest when only Guardians too strong to summon are left. Elemental towers deal 55% to 65% of all damage, against 30% to 48% before; Archers fall to 30% to 45%. No Guardian got through in any of the 32 smart games in the table.
- **Hard** wins 2 of 4 on each map, and is lost on waves 39 (the Light Harpies, which the Dark Cauldrons hit for half) and 40. **Easy** keeps 14 to 20 lives, though two of the four Rampart games keep all 20. **Very Hard** is lost in every game, all of them on waves 38 to 40, after the bot has played the whole game.
- **The novice** loses on wave 30 on both maps and survives to wave 40 on Easy (winning on the Citadel). **The archers-only bot** loses on wave 35 on the Citadel and 28 on the Rampart, and **the ground-only bot** on wave 5, the first Harpies, on both.
- The Frost Spire, Runesmith Forge, Shadow Obelisk and Ancient of Roots still pay about a third of a Ballista's damage per gold or less, so the bot takes Aqua only as a late extra pick and never Stone or Verdant. They are utility towers whose slows and shred its price model counts only as a flat bonus.

Tried on the way, with the smart bot on Normal unless a row says otherwise (mean lives Citadel / Rampart; each row adds to the one above):

| Change | Seeds | Result |
|---|---|---|
| None: the bot of the section above, measured | 2 | 7.5 / 7.0; elemental damage 45% / 34% |
| Archer damage 100% / 85% / 80% alone | 2 | 12.5 / 9.5; elemental damage 41% / 48%. Three Interest picks in 3 of 4 games and 2.25 elements a game: nothing else got cheaper |
| Elemental towers at 140%, the Cauldron excepted | 4 | 8.5 (one game lost to the Dreadlord) / 13.5; Hard 4/4 on both maps; 2.75 / 3.25 elements; elemental damage 48% / 60%. On 2 seeds, Easy 17.0 / 20.0, Very Hard won 2/2 on both, the novice lost on wave 6 |
| HP line from 0.11, Bulky 2.2, Dreadlord 0.3, Hard 1.06 → 1.22, Very Hard 1.15 → 1.45, Easy 0.85 | 2 | 14.0 / 18.0; Hard won all four; Easy 13.0 / 17.0; Very Hard 1/2 and 2/2 |
| HP line to 0.66, armored 0.68, Hard to 1.3, Very Hard 1.12 → 1.65, Easy 0.8 | 4 | 10.0 / 12.0; Hard 2/4 and 3/4; one Rampart game without Light lost 7 lives to wave 39. Easy 14.5 / 16.5; Very Hard 0/4, but Rampart games ended on waves 28 to 30 |
| Very Hard 1.1 → 1.55, Easy 0.75 | 4 | Easy 15.5 / 18.5; Very Hard 0/4, every game to wave 30 |
| Guardian level 1 at 0.35 | 4 | 12.5 / 14.5; every game took Light, 3.25 / 3.0 elements, no wave but a boss over 3 lives |
| HP line to 0.68, armored 0.7 | 4 | 12.0 / 15.2; Hard 1/4 on both maps; a Very Hard Rampart game lost on wave 28 |
| Wave-10 Ogre 2.0, Bulky 2.0, Hard to 1.26, Very Hard from 1.05 | 4 | 9.2 / 13.5; Hard 3/4 and 4/4; Easy 14.8 / 18.0; Very Hard 0/4, games ending on waves 30 to 39 |
| Easy 0.7, Hard to 1.28 | 4 | Hard 3/4 on both; Easy 15.5 / 19.0 |
| The same, novice and the other bots | 4 | Novice lost on wave 6 on both maps, 8 lives to the wave-6 Ghouls |
| HP line from 0.10, wave-10 Ogre 2.1 | 4 | Novice to wave 30; Normal, Hard and Easy as in the final table; Very Hard (1.05 → 1.55) lost a Citadel game on wave 28 |
| Very Hard 1.07 → 1.5 | 4 | Won 1 of 4 on the Citadel; a Rampart game lost on wave 29 |
| Very Hard 1.07 → 1.55, squared | 4 | 0/4, every game to wave 35 or later, but below Hard around wave 10 |
| **Very Hard 1.1 → 1.55, squared** | 4 | **The final table** |

### Shots land as the tower that fired them

Measuring the retune turned up a bug older than it. A shot's damage came from the level its tower had when it fired, but everything else was read when it landed: the tower's id, its attack and element, and, with these rules, its power. An arrow loosed at level 1 that landed after an upgrade was scaled as a level-2 arrow, and a shell, bolt or arrow in flight when its tower fused into an Epic landed with the Epic's damage at the old tower's level, its crater burned as the Epic's, and a Cauldron stack laid just before a fusion spread as a Necropolis stack. Now every shot, and the poison stacks, craters and clouds it leaves, keeps the id and level of its tower when it fired (GDD §7). Under classic, where the tower's power is always 1, only a fusion with shots in flight plays differently, and the classic check still ends with 20 lives, 2 close calls and 12,110 gold at 34:09.

All sixteen rows of the final table were run again with 4 seeds, on top of the default-rules switch and the fixed-lane map below and with the fix. Every row matches the table to the life, the per-wave losses and the Normal games' picks and elemental damage included. The one difference is a Rampart Easy game (seed 2) that fuses a Sunfire Ballista: with shots in flight at the fusion landing as the tower that fired them, it ends with 6 close calls instead of 8 and 3 gold less, so the row reads 4.5 close calls and the wave-30 boss walks 91% of the maze instead of 89%. Its lives and picks are the same. Without the fix the row matches the table exactly.

## Element TD rules: the fixed-lane map (2026-10-04)

The Winding Causeway ([maps.md](maps.md#winding-causeway)) gives the creeps a fixed road of 119 tiles, about 240 m, from wave 1. Nothing can block or lengthen it, so the bots spend nothing on walls. The smart bot weighs every tile in reach of the road or the flyers' line; the other bots build beside the road in the order the creeps pass it. At the rules' HP the map played much easier than the Citadel for the smart bot: on Normal it lost lives only to the wave-40 Dreadlord, and the median wave got a fifth of the way along the road. No global number changed. The map has HP numbers of its own instead: its creeps, Guardians included, get more HP than the rules and the difficulty give them. That was first a flat 1.4 times; after the retune above it is 1.8 times on wave 1, falling in a straight line to 1.15 times on wave 40 (`hp` and `hp_40` in its `MapDefs` entry), for the reasons [below](#re-set-after-the-retune).

4 seeds per row, measured before the retune above, at its HP numbers then:

| Map | Creep HP | Bot | Mode | Wins | Lives (mean, min–max) | Close calls | Walked w1–5 | Walked, non-boss median | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|---|---|---|---|
| Citadel | rules | smart | normal | 4/4 | 7.0, 6–8 | 8.8 | 37% | 44% | 100% / 100% / 100% / 94% | – |
| Citadel | rules | smart | hard | 1/4 | 0.8, 0–3 | 7.5 | 36% | 42% | 100% / 100% / 100% / 95% | w40, w40, w30 |
| Citadel | rules | novice | normal | 0/4 | 0.0, 0–0 | 2.0 | 35% | 22% | – / – / – / – | w6, w6, w6, w6 |
| Citadel | rules | archers | normal | 0/4 | 0.0, 0–0 | 8.5 | 32% | 26% | 100% / 100% / 100% / – | w38, w38, w38, w38 |
| Causeway | × 1 | smart | normal | 4/4 | 11.5, 11–12 | 1.8 | 19% | 20% | 36% / 83% / 56% / 100% | – |
| Causeway | × 1 | smart | hard | 4/4 | 8.8, 5–11 | 3.0 | 22% | 18% | 35% / 95% / 87% / 100% | – |
| Causeway | × 1.3 | smart | normal | 4/4 | 8.5, 3–11 | 3.5 | 18% | 25% | 67% / 100% / 100% / 100% | – |
| Causeway | **× 1.4** | smart | normal | 4/4 | 5.8, 3–9 | 3.8 | 17% | 20% | 76% / 100% / 100% / 100% | – |
| Causeway | **× 1.4** | smart | hard | 4/4 | 4.0, 2–6 | 5.8 | 21% | 24% | 84% / 100% / 100% / 100% | – |
| Causeway | **× 1.4** | novice | normal | 0/4 | 0.0, 0–0 | 5.5 | 1% | 4% | 100% / 100% / 100% / – | w30, w30, w38, w28 |
| Causeway | **× 1.4** | archers | normal | 0/4 | 0.0, 0–0 | 5.0 | 1% | 7% | 100% / 100% / – / – | w25, w25, w25, w25 |

Lives lost per wave at × 1.4, all seeds: smart normal {20: 8, 30: 14, 40: 35}, hard {20: 8, 30: 16, 35: 1, 38: 2, 40: 37}. On the Citadel: smart normal {10: 8, 20: 8, 25: 6, 30: 10, 40: 20}, hard {10: 8, 20: 8, 25: 20, 28: 1, 29: 1, 30: 15, 35: 6, 40: 19}.

What it shows:

- At × 1.4 the smart bot on Normal ends with about as many lives as on the Citadel (5.8 against 7.0, the ranges overlapping), which was the aim. × 1.3 left it 1.5 lives better off.
- The pressure comes differently. On the Causeway the ordinary waves die early (the median wave walks a fifth of the road, against 44% of the Citadel's maze), and nearly every life is lost to the bosses of waves 20, 30 and 40. On the Citadel the maze is short early and the losses spread over the boss waves and the Bulky wave 25.
- Hard is gentler here than on the Citadel: 4/4 wins with 4.0 lives, against 1/4 with 0.8. The single map number was set for Normal; making Hard match too would need a second one, and Hard is the other team's to retune.
- The novice, who builds one tower every four seconds, does far better: it reaches waves 28 to 38 instead of dying on wave 6, since the road is long from the start and needs no maze. The archers-only bot does worse (wave 25 against 38), since a single row of Archers beside a 240 m road meets less of each wave than the Citadel's 500 m maze, where every tower borders two corridors.
- By wave 8 the smart bot has filled the hairpin row, the tiles that reach two stretches of road, with Plague Cauldrons and Archers, and has only a handful of towers anywhere else.

### Re-set after the retune

The retune above made the elemental towers stronger and reshaped the HP curve, the bosses and the difficulties, so the flat 1.4 was measured against numbers that no longer exist. Played again on the retuned rules, it left the smart bot on Normal with 10.0 lives (2 seeds), in the Citadel's band, but in the wrong shape. The wave-10 Ogre never got through (it walked 89% of the road), so nothing was lost in the first third of the game, while the Dreadlord leaked in both games for 5 lives each. Hard lost both games, on waves 38 and 40, against 2 of 4 won on the Citadel.

The cause is the map itself, not the number. On the mazing maps the maze is short early and grows to 440–510 m by the late game, so the creeps meet more towers as the game goes on. The Causeway's road is 240 m from wave 1 and never longer, so it is the easier map early and the harder one late, and no single multiplier fixes both ends: one high enough to make the wave-10 Ogre a test leaves the Dreadlord unbeatable, and one low enough for the Dreadlord makes the first twenty waves free. So the map's HP now runs in a straight line, from `hp` on wave 1 to `hp_40` on wave 40. That is the one number added, and it has a plain meaning for a player: the Causeway starts harder than the mazing maps and ends easier, because its road is long from the start.

Tried on the way, 2 seeds, smart bot (lives, Normal / Hard):

| Causeway HP, wave 1 → wave 40 | Normal | Hard |
|---|---|---|
| 1.4, flat | 2/2, 10.0; {20: 4, 30: 6, 40: 10} | 0/2, lost on wave 40 both times; {20: 4, 23: 1, 30: 8, 38: 20, 40: 8} |
| 1.6 → 1.2 | 2/2, 16.0; {20: 4, 30: 4} | 2/2, 5.5 |
| 1.8 → 1.25 | 2/2, 5.0; the Dreadlord took 6 and 8 lives | 2/2, 3.5 |
| **1.8 → 1.15** | 2/2, 11.5 | 2/2, 4.0 |

The Dreadlord is the knife edge: between 1.15 and 1.25 at wave 40 it goes from dying on its first pass in most games to taking 6 to 8 lives in every one.

All eight rows, 4 seeds each, at 1.8 → 1.15. The Citadel and Rampart rows were run alongside and match the [retune's final table](#final-results) to the life.

| Map | Bot | Mode | Wins | Lives (mean, min–max) | Close calls | Walked w1–5 | Walked, non-boss median | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|---|---|---|
| Causeway | smart | easy | 4/4 | 19.5, 18–20 | 1.2 | 18% | 22% | 72% / 91% / 48% / 51% | – |
| Causeway | smart | normal | 4/4 | 11.2, 9–14 | 4.8 | 14% | 22% | 100% / 100% / 100% / 98% | – |
| Causeway | smart | hard | 4/4 | 4.2, 2–7 | 5.2 | 16% | 28% | 100% / 100% / 100% / 100% | – |
| Causeway | smart | very_hard | 0/4 | 0.0, 0–0 | 5.8 | 14% | 28% | 100% / 100% / 100% / 100% | w40, w40, w40, w38 |
| Causeway | archers | normal | 0/4 | 0.0, 0–0 | 4.0 | 1% | 6% | 100% / 100% / – / – | w23, w23, w23, w23 |
| Causeway | no_air | normal | 0/4 | 0.0, 0–0 | 1.0 | 22% | 2% | – / – / – / – | w5, w5, w5, w5 |
| Causeway | novice | normal | 0/4 | 0.0, 0–0 | 5.0 | 1% | 8% | 100% / 100% / 100% / – | w36, w34, w34, w36 |
| Causeway | novice | easy | 0/4 | 0.0, 0–0 | 5.2 | 1% | 8% | 100% / 100% / 100% / 100% | w40, w40, w40, w40 |

Lives lost per wave, all 4 seeds:

| Row | Causeway |
|---|---|
| smart, easy | {20: 2} |
| smart, normal | {10: 8, 20: 8, 23: 1, 30: 10, 40: 8} |
| smart, hard | {10: 8, 20: 8, 30: 16, 35: 1, 38: 4, 40: 26} |
| smart, very hard | {10: 8, 20: 8, 30: 16, 35: 8, 38: 18, 40: 22} |
| archers | {10: 16, 20: 24, 21: 20, 23: 20} |
| no_air | {5: 80} |
| novice, normal | {10: 14, 20: 16, 28: 7, 30: 32, 34: 6, 36: 5} |
| novice, easy | {10: 8, 20: 8, 30: 16, 40: 49} |

Smart bot on Normal, game by game:

| Seed | Lives | Picks | Elements at the end | Elemental damage | Guardians |
|---|---|---|---|---|---|
| 0 | 9 | `dark@0, dark@5, light@10, flame@15, dark@20, light@25, flame@30, interest@35` | Light 2, Dark 3, Flame 2 | 86% (ballista 39%, plague 38%, archer 14%, demolisher 10%) | 6 summoned, none got through |
| 1 | 14 | `dark@0, dark@5, light@10, flame@15, dark@20, flame@25, interest@35, interest@36` | Light 1, Dark 3, Flame 2 | 83% (demolisher 37%, plague 25%, ballista 21%, archer 17%) | 5, none |
| 2 | 10 | the same | the same | 84% (demolisher 35%, plague 28%, ballista 21%, archer 16%) | 5, none |
| 3 | 12 | the same | the same | 89% (demolisher 38%, ballista 29%, plague 22%, archer 11%) | 5, none |

What it shows:

- **Normal** is won in every game with 9 to 14 lives, against 12 to 14 on the mazing maps, and lives now go in every third of the game: the Ogres of waves 10, 20 and 30 take 2 to 4 each, and the Dreadlord gets through in three games of four for 1 to 5. The one ordinary wave to cost a life is wave 23, once. The bot takes Light at wave 10 here, against 15 or 20 on the mazing maps, and its elemental towers deal 83% to 89% of all damage, against 55% to 65% there: with no walls to buy, its gold goes on Cauldrons, Ballistas and Demolishers along the road.
- **Hard** wins all four games with 2 to 7 lives, against 2 of 4 on each mazing map, so it misses its target of 2 or 3 wins. Its lives are no higher than the Citadel's (4.2 against 4.0); the difference is that on the Causeway it loses them in the same places in every game, the bosses and the Dreadlord, without the late collapse that ends half the Hard games on the mazing maps on waves 39 and 40. A second map number for Hard alone would close the gap, but the map's two numbers are already spent on the shape of the curve, so Hard is left where it falls.
- **Easy** keeps 18 to 20 lives, three games of four keeping all 20, half a life above its target band of 15 to 19. **Very Hard** is lost in every game, on waves 38 and 40, after the whole game has been played.
- **The novice** does better here than on the mazing maps, as before the re-set: it loses on waves 34 to 36 on Normal and plays all 40 waves on Easy, though it loses on wave 40, where it wins on the Citadel. **The archers-only bot** loses on wave 23, earlier than on the Citadel (35) and the Rampart (28), since a row of Archers beside the road meets less of each wave than a maze does. **The ground-only bot** loses on wave 5, the first Harpies, on every map.

## Element TD rules: two human yardsticks (2026-10-05)

The 0.4.x opening was tuned against the novice bot, and no bot played it the way a person does. The owner's first recorded game ([playtests.md](playtests.md), issue #33) showed the gap. He spent his 400 starting gold on 16 Archers in two serpentine rows right under the portal, where every creep, ground or air, passes first. The creeps of waves 1 to 9 died within the first tenth of the route. The smart bot never builds there, because its plan starts with the wall on row 3. So two bots now measure what a human gets out of the early game.

- **camper** replays his habits rather than his moves. It builds on the 137 tiles he built on, in the order he first built there, putting down whatever he first put on each tile. That means Archers, with a Cannon, Frost, Plague or Bard where he chose one, and an Archer instead while that tower's element isn't picked. It spends every coin as it arrives, and builds nothing but Archers before wave 1. It repeats his 36 sell-and-rebuild swaps on the waves he made them, starting with Frost on the portal wall at wave 2. It takes his five picks (Aqua, Dark, Interest, Interest, Flame) as they come and leaves the other three unspent. It upgrades nothing before wave 21, and after that it upgrades Cannons, Bards and Archers with all its gold. If the top of the board is reserved, it moves his whole pattern down so that his first row lands on the first row free of reserved tiles. Any tile that is still reserved or refused, it skips.
- **idle** builds the camper's opening from the starting gold and never acts again: no picks, no upgrades, no more towers. It shows how long a wave-1 build left alone holds.

Off the Citadel both bots put Archers along the other bots' maze plan. Their seeds vary only the timing of their decisions, so the idle bot plays the same game on every seed. The camper matches his game closely through wave 20. After that it drifts, because he stopped building and banked over 3,000 gold, while the camper keeps spending. Read it for the first half of the game.

Measured on 0.4.1's numbers, 2 seeds each, on the Citadel:

| Bot | Mode | Walked %, waves 1–10 | First leak | First non-boss leak | Result |
|---|---|---|---|---|---|
| camper | normal | 2, 5, 4, 2, 3, 4, 9, 4, 7, 56 | w20 (Ogre, 2 lives) | w31 | lost on w34 and w36 |
| camper | very_hard | 2, 5, 4, 2, 3, 4, 9, 4, 7, 100 | w10 (2 lives) | w25 | lost on w30 and w28 |
| idle | normal | 2, 5, 2, 2, 1, 5, 28, 5, 12, 100 | w10 (10 lives) | w16 | lost on w18 |
| idle | very_hard | 2, 5, 2, 2, 1, 5, 30, 5, 14, 100 | w10 (10 lives) | w16 | lost on w16 |

His own game walked 2, 5, 7, 2, 3, 4, 9, 4, 7 and 52% on waves 1 to 10 and was lost on wave 36, so the camper stands in for him. Both seeds of each row agree on waves 1 to 10. What the table says about the early game:

- Against the camper, no wave before the wave-10 boss gets past the first tenth of the route. Sixteen level-1 Archers left alone let wave 7 walk under a third of it, and hold every ordinary wave up to wave 15.
- Very Hard plays the same as Normal for the first nine waves. It only shows from the wave-10 boss on.

`--only=camper:normal,idle:very_hard --per-wave` runs them.

## Element TD rules: the band by the portal (2026-10-05)

0.4.3 replaced the band with a ring of the six tiles touching the portal ([below](#element-td-rules-four-arrows-and-a-ring-by-the-portal-2026-10-07)).

In the owner's game the creeps of the opening waves died within 3 m of the portal. His Archers stood on five of the six tiles touching the two portal tiles, which every creep and every flyer passes first, and one arrow kills a wave-1 creep. Under the Element TD rules the top three rows of every map, along the portal edge, now take no towers (`EletdRules.PORTAL_ROWS`, [GDD §2](GDD.md#2-pathing-rules)). No tower can reach a creep, on the ground or in the air, until it is at least 5.5 m from the portal. The bots' first Citadel wall already stood on row 3, just below the band, so their plans still fit there. Two rows would leave about 3.5 m, and four would take 80 build tiles. The plateau shows the band as a faint red strip, and a build there is refused with "Too close to the portal". Classic has no band.

The band only moves where the one-shot kills happen. The investigation behind it found that an opening built on row 3 kills waves 1 to 4 about 14 m along the route with or without the band. So the band takes away the ring round the portal, but it can't make the opening waves hard on its own. That is the HP and gold retune's job.

The Rampart's first two walls moved from rows 2 and 4 to rows 3 and 5. On the Causeway the band takes 11 of the 226 tiles beside the road. The bots were run again with the band and the numbers otherwise unchanged, on Normal:

| Map | Bot | Seeds | Before the band | With the band |
|---|---|---|---|---|
| Citadel | smart | 2 | Won with 12 lives, 11,322 and 11,248 gold | The same games |
| Citadel | novice | 2 | Lost on wave 30, leaks {3: 9, 5: 3, 10: 2, 20: 2, 30: 4} | The same game |
| Citadel | camper | 2 | Lost on waves 34 and 36; first leak wave 20 | Lost on wave 3 in both games: 7 lives on wave 2, 13 on wave 3 |
| Citadel | idle | 2 | Lost on wave 18 | Lost on wave 3, the same as the camper |
| Rampart | smart | 4 | 13.0 lives (12–14) | 4/4, 14.0 lives (14–14), 2 lives on each Ogre wave |
| Rampart | archers | 1 | Lost on wave 28 | The same: lost on wave 28 with the same leaks |
| Rampart | novice | 1 | Lost on wave 30, 9 lives on wave 2 | Lost on wave 36, 2 lives on wave 2 |
| Causeway | smart | 4 | 11.2 lives (9–14) | 4/4, 12.2 lives (7–14); seed 0 lost 5 lives to the Dreadlord |

The camper and idle rows aren't a fair yardstick under the band. The owner's opening used the board's north edge: an Archer at (11, 0), beside the portal, and a wall along row 1 from column 1 to 11 sent every creep west along row 0, down the west edge, and back along row 2, an 89.5 m route past all sixteen towers. The camper moves that pattern down to row 3. That puts the (11, 0) Archer in the band, so it is dropped, and the edge is no longer there to lean on. Creeps now walk east round the end of the row-3 wall and straight down column 12. That route is 62.7 m long and passes only one Archer. A person would close the end of the wall instead. So the band breaks the owner's shape, not the opening as such. The rows above were measured before the camper learned to do that. It now builds the rest of his first row out to the east edge where the band takes his corner tile, so its 16 starting Archers stand on columns 4 to 19 of row 3 and creeps go round the west end, past the whole wall ([next section](#element-td-rules-a-harder-opening-for-a-person-2026-10-05)).

Records made before the band don't replay as the same game. Replaying the owner's 0.4.1 record refuses 14 of the first 19 of its 271 actions, starting with his first builds, and loses all 20 lives on wave 1, so the other 252 are never reached.

## Element TD rules: a harder opening for a person (2026-10-05)

This is the 0.4.2 retune for issue #33. With the [band by the portal](#element-td-rules-the-band-by-the-portal-2026-10-05) in place, one Archer arrow still killed every creep of the opening, Very Hard played the same as Normal until the wave-10 boss, and one Archer anywhere on the flight line held the first Harpies. Three tuning runs tried different levers: creep HP first, starting gold first, and the shape of the difficulty curves. The numbers below take the HP-first run's set, checked against what the other two found.

### Closing the camper's wall

The band took the owner's corner Archer at (11, 0), so the camper's first wall on row 3 stopped at column 11 and creeps walked round its open east end past one Archer. The camper now closes that end, as a person would: where the band takes the corner tile, it builds the rest of his row out to the east edge instead, and the 16 starting Archers stand on columns 4 to 19, with the gap at the west end. Creeps then walk the length of the wall. On the numbers before this retune, with the band (4 seeds; the open-wall row is the band section's, 2 seeds):

| Bot | Mode | Walked %, waves 1–5 | First non-boss leak | Result |
|---|---|---|---|---|
| camper, wall open | normal | 13, 100, 100 | w2 | lost on w3 |
| camper, wall closed | normal | 22, 26, 32, 26, 10 | w25, w28, w3, w31 | lost on w34, w34, w30, w34 |
| idle, wall closed | normal | 22, 22, 100, 22, 10 | w3 (9 lives) | lost on w7 |
| camper, wall closed | very_hard | 22, 26, 32, 26, 10 | w25, w23, w3, w23 | lost on w28 in all four |
| idle, wall closed | very_hard | 22, 22, 100, 22, 10 | w3 | lost on w6 |

Very Hard and Normal walked almost exactly the same through wave 9.

### What changed

| Number | Before | Now | Why |
|---|---|---|---|
| Plain creeps' HP share (`HP_FLOOR`) | 0.10 on wave 1, rising in a line to 0.68 | The same line, never below 0.35; the line passes the floor on wave 18 | A Normal Grunt of the opening now takes two Archer arrows (14 HP against 12.7 per arrow); the Wolf Riders of wave 2 still take one |
| Armored creeps' share | A squared curve to 0.70, never below the plain line | A straight line from 0.10 to 0.70, without the floor | The Footmen of wave 3 and the Steam Tanks of wave 7 keep their HP (within 3% on every wave); on the floor the novice lost to the Footmen even on Easy |
| Wave-10 Ogre (`BOSS_HP`) | 2.1 × its share | 1.4 × | The same HP as before: 1,906 against 1,911 |
| Guardians | The plain share | The share's line, without the floor | On the floor the Guardians of waves 5 to 10 had 1.5 to 2.2 times the HP they were tuned with |
| Wave-5 Harpies (`HARPY_HP`) | × 1 | × 2.7, Harpies only | Four level-1 Archers beside the flight line now hold wave 5 on Normal, where one did before; Easy needs two, Hard four, Very Hard five |
| Easy | 0.7 × Normal's HP | 0.4 on wave 1 rising to 0.7 on wave 40 | Keeps the raised opening gentle: at a flat 0.7 the novice lost to the Ghouls of wave 6 |
| Hard | 1.06 rising to 1.28 | 1.25 on waves 1 to 5, easing onto the old ramp by wave 11, then the old ramp | Harder from the first wave without moving the late game |
| Very Hard | 1.1 rising to 1.55, squared | 1.5 on waves 1 to 5, easing onto the old ramp by wave 11, then the old ramp | The same; Very Hard's opening had about Normal's HP |
| Starting gold | 400 | 400 | Unchanged: under the band a whole row with a gap takes 19 Archers, more than 400 buys |

The difficulty chips' tooltips read these numbers from `EletdRules`, so they say, for example, "Very Hard: creeps have 50% more HP to wave 5, easing to 13% more by wave 11, then rising to 55% more by wave 40, score ×1.6".

### Final results

4 seeds per row. The camper, idle and novice bots play the same game on every seed but for timing.

| Map | Strategy | Mode | Wins | Lives (mean, min–max) | Close calls | Walked w1–5 | Walked, non-boss median | Boss walked w10 / w20 / w30 / w40 | Losses |
|---|---|---|---|---|---|---|---|---|---|
| Citadel | smart | easy | 4/4 | 19.5, 19–20 | 1.5 | 29% | 37% | 72% / 92% / 69% / 65% | – |
| Citadel | smart | normal | 4/4 | 9.2, 8–10 | 4.8 | 20% | 31% | 100% / 100% / 100% / 43% | – |
| Citadel | smart | hard | 2/4 | 3.0, 0–8 | 4.5 | 22% | 31% | 100% / 100% / 100% / 69% | w30, w23 |
| Citadel | smart | very_hard | 1/4 | 0.5, 0–2 | 5.8 | 26% | 32% | 100% / 100% / 100% / 79% | w21, w25, w38 |
| Citadel | archers | normal | 0/4 | 0.0, 0–0 | 7.8 | 35% | 26% | 100% / 100% / 100% / – | w35, w35, w35, w35 |
| Citadel | no_air | normal | 0/4 | 0.0, 0–0 | 3.0 | 67% | 100% | – / – / – / – | w5, w5, w5, w5 |
| Citadel | novice | normal | 0/4 | 0.0, 0–0 | 2.0 | 35% | 24% | – / – / – / – | w6, w6, w6, w6 |
| Citadel | novice | easy | 4/4 | 15.8, 15–16 | 2.0 | 19% | 22% | 36% / 62% / 62% / 86% | – |
| Citadel | camper | normal | 0/4 | 0.0, 0–0 | 6.8 | 45% | 26% | 100% / 100% / 100% / – | w34, w31, w28, w34 |
| Citadel | idle | normal | 0/4 | 0.0, 0–0 | 2.0 | 35% | 22% | – / – / – / – | w6, w6, w6, w6 |
| Citadel | camper | very_hard | 0/4 | 0.0, 0–0 | 2.0 | 74% | 100% | – / – / – / – | w3, w3, w3, w3 |
| Citadel | idle | very_hard | 0/4 | 0.0, 0–0 | 2.0 | 74% | 100% | – / – / – / – | w3, w3, w3, w3 |
| Rampart | smart | normal | 4/4 | 12.2, 9–16 | 5.2 | 21% | 34% | 100% / 100% / 92% / 66% | – |
| Rampart | camper | normal | 0/4 | 0.0, 0–0 | 2.0 | 43% | 35% | – / – / – / – | w6, w6, w6, w6 |
| Causeway | smart | normal | 4/4 | 8.8, 5–13 | 4.5 | 19% | 24% | 100% / 100% / 100% / 100% | – |
| Causeway | camper | normal | 0/4 | 0.0, 0–0 | 4.0 | 5% | 13% | 100% / 100% / – / – | w23, w23, w23, w23 |

The classic check is unchanged: seed 0 wins with 20 lives, 2 close calls and 12,110 gold at 34:09.

Lives lost per wave, all 4 seeds:

| Row | Lives lost per wave |
|---|---|
| Citadel smart, easy | {40: 2} |
| Citadel smart, normal | {10: 8, 20: 16, 25: 2, 26: 1, 30: 16} |
| Citadel smart, hard | {10: 10, 20: 18, 21: 9, 23: 9, 25: 10, 30: 12} |
| Citadel smart, very hard | {10: 12, 20: 18, 21: 27, 23: 2, 25: 8, 30: 8, 38: 2, 40: 1} |
| Citadel archers | {2: 11, 10: 8, 20: 8, 30: 12, 33: 24, 35: 17} |
| Citadel no_air | {2: 19, 4: 4, 5: 57} |
| Citadel novice, normal | {3: 36, 5: 12, 6: 32} |
| Citadel novice, easy | {39: 13, 40: 4} |
| Citadel camper, normal | {3: 9, 5: 12, 10: 8, 20: 8, 25: 2, 28: 10, 30: 12, 31: 13, 34: 6} |
| Citadel idle, normal | {3: 36, 6: 44} |
| Citadel camper and idle, very hard | {2: 44, 3: 36} |
| Rampart smart, normal | {10: 8, 20: 8, 30: 15} |
| Rampart camper, normal | {3: 36, 5: 12, 6: 32} |
| Causeway smart, normal | {10: 8, 20: 8, 30: 14, 40: 15} |
| Causeway camper, normal | {10: 16, 20: 24, 21: 32, 23: 8} |

What it shows:

- **The camper on Normal** walks exactly as far on waves 1 to 4 as before (22, 26, 32 and 26%) and still loses between waves 28 and 34. The new cost is wave 5: after his wave-2 and wave-3 swaps of wall Archers for Frost Spires too few Archers stand by the flight line, and three Harpies get through in every game. **The idle bot** first leaks on wave 3, 9 lives to the Footmen, and loses to the Ghouls of wave 6 instead of the Steam Tanks of wave 7.
- **Very Hard** is now clearly harder from wave 1. The camper and the idle bot lose on wave 3: the Wolf Riders of wave 2 have 15 HP there, two arrows, and they take 11 lives. The smart bot's opening holds (26% walked on waves 1 to 5).
- **The smart bot** opens with Light now, for Ballistas against the tougher wave-5 Harpies, where it opened with Dark before; elemental towers deal 81% to 88% of its damage on Normal. On Hard and Very Hard, games where it holds back its picks on waves 15 and 20 (one taken late, or none) lose 3 to 10 lives to the Steam Tanks of wave 21, armored and Aqua. Before this retune, with the band, the same bot lost Hard on waves 39 and 40 (2/4) and every Very Hard game on waves 38 and 39.
- **The novice** loses Normal on wave 6, where it reached wave 30 before: the Ghouls of wave 6, on the floor, have twice the HP they had. On Easy it wins every game.
- **Off the Citadel** the camper plays Archers along the smart bot's plan rather than the owner's tiles, so its Rampart and Causeway rows measure that plan left mostly to Archers, not a person.

### What HP can and can't do

All three tuning runs found the same limit. How far creeps walk on waves 1 to 4 is set by where they first meet a tower, about a quarter of the route below the band, and not by their HP. More HP moves the point where they start to leak, not how far the survivors get: on the camper, every HP set from 0.30 to 0.43 walked 22 to 34%. So T1 can't be met with numbers. It would take an opening a person builds further down the board, or towers that reach further.

### Tried on the way

| Change | Seeds | Result |
|---|---|---|
| A straight line from 0.35 or 0.45 to 0.68 | 2–4 | Waves 20 to 30 a quarter harder; the smart bot lost Normal games on waves 21 to 30. With armored creeps from 0.2, the novice lost to the wave-3 Footmen even on Easy |
| A floor of 0.42 | 4 | Wolf Riders take two arrows too, but the smart bot lost one Normal game in four (20 lives on wave 30) and the novice leaked on Easy |
| Starting gold 350, 300 or 275 | 2–4 | Broke the camper and the novice (leaks from wave 3) and bought nothing measurable |
| Very Hard from 3.5 times on wave 1, falling to a straight 1.5 to 1.6 ramp by wave 10 (the curve-shape run) | 4 | Smart lost every game, on waves 25 to 40. Not taken: 3.5 times is far past the 1.5 the targets ask for, and the new ramp moves the late game |
| Harpies × 6 on the line alone, without the floor | – | Also four Archers on the flight line; on the floor 2.7 is enough |
| Guardians on the floor | 4 | Hard and Very Hard games identical to the final ones; Normal 9.8 lives. Kept off the floor so they keep their tuned HP |

### The owner's record

Replaying `tests/playtests/owner_0.4.1_citadel_normal.json` on these numbers parts from the record on wave 1, as it already did with the band: 14 of the first 19 of its 271 actions are refused, his first builds by the portal among them, and wave 1 takes all 20 lives, so the other 252 are never reached. It can't judge these numbers. A fresh game on Normal and one on Very Hard can.

### Known gaps

- **T1 is out of reach for HP**, as above.
- **Very Hard may be too hard for a person's opening.** A single wall of 16 Archers, the owner's shape, loses on wave 3. The smart bot's opening holds, so a stronger first build is possible, but no person has played it yet.
- **One Very Hard game in four ends on wave 21**, and Hard loses on waves 23 and 30. In those games the bot skipped its picks on waves 15 and 20. Bot seeds swing widely from wave 21 on, so 4 seeds are weak evidence either way.
- **Weak elements**: unchanged ([Targets](#element-td-rules)). The bot now opens with Light and still never takes Stone or Verdant.

## Element TD rules: four arrows and a ring by the portal (2026-10-07)

This is 0.4.3, for issue #36. Playing 0.4.2, the owner saw early creeps drop to what looked like a single Archer hit: two arrows 0.6 s apart from several towers read as one. He also found the three blocked rows too much, when only the tiles beside the portal let towers shoot creeps as they appear. He asked for every early creep to take at least four arrows and for the no-build zone to shrink to the tiles touching the portal. He playtests this round himself, so no bot tuning or balance table was run; the classic check is unchanged.

### Arrows per creep

Every plain creep (neither armored nor a boss, flyers included) of waves 1 to 10 now takes at least `EARLY_ARROWS` level-1 Archer arrows: two on Easy, four on Normal, five on Hard, six on Very Hard. A level-2 or level-3 Archer needs at least two on Normal. HP below is a creep as its wave sends it, after Element TD's split of each group into 1.5 times the creeps (the issue's 21 HP for a wave-1 Grunt was the table HP before that split). Normal, level-1 Archer:

| Wave | Creep | 0.4.2 HP | 0.4.2 arrows | 0.4.3 HP | 0.4.3 arrows |
|---|---|---|---|---|---|
| 1 | Grunt | 14 | 2 | 43 | 4 |
| 2 | Wolf Rider | 10 | 1 | 46 | 4 |
| 4 | Grunt / Priestess | 19 / 15 | 2 / 2 | 50 / 46 | 4 / 4 |
| 5 | Harpy | 45 | 4 | 51 | 4 |
| 6 | Ghoul | 23 | 2 | 43 | 4 |
| 7 | Grunt | 25 | 3 | 56 | 5 |
| 8 | Wolf Rider / Grunt | 18 / 28 | 2 / 3 | 53 / 58 | 4 / 5 |
| 9 | Priestess | 28 | 3 | 59 | 5 |
| 10 | Grunt | 34 | 3 | 60 | 5 |

The fewest arrows any plain creep of waves 1 to 10 takes went from 1 to 2 on Easy, 1 to 4 on Normal, 1 to 5 on Hard and 2 to 6 on Very Hard. The Footmen of waves 3 and 9, the Steam Tanks of wave 7, the wave-10 Ogre and the Guardians keep their HP, and no bounty changed.

How: each plain creep type gets its own multiplier on wave 1, on top of the share line and its floor, falling in a straight line to 1.0 on wave 15 (`EletdRules.early_hp`). It is worked out, not typed in: the least that gives every creep of that type in waves 1 to 10 its arrows at every difficulty, from the Archer's damage and the creep's armor and HP, with a tenth of an arrow to spare (`early_from`). Very Hard's six arrows set it for every type, each on its first wave in the opening: six arrows need more than 1.5 times Normal's four. The multipliers on wave 1: Grunt 3.1, Wolf Rider 4.8, Priestess 3.5, Harpy 3.8, Ghoul 2.3. One multiplier for all would have had to be the Wolf Riders' 4.8 (no armor, 0.65 of a Grunt's HP): wave-1 Grunts would have taken six arrows on Normal and the Bulky Ghouls of wave 12 nearly double their HP. `EletdRules.arrows()` answers "how many arrows" for the tests.

Side effects, accepted with the spec:

- **Waves 11 to 14** are tougher than in 0.4.2 while the multiplier fades: the Bulky Ghouls of wave 12 have 108 HP against 84, its Priestesses 105 against 68. Waves 15 and later are unchanged.
- **Wave-5 Harpies.** `HARPY_HP` (× 2.7 on wave 5) is gone: the Harpies' own early multiplier gives them × 3.0 on wave 5, 51 HP against 45. Four level-1 Archers beside the flight line still hold wave 5 on Normal and one does not, as the test asserts. The air-cover rating reads the HP from the rules and needed no change.

### The ring by the portal

The band of rows 0 to 2 is now a ring of the six tiles that touch a portal tile, side or corner (`EletdRules.portal_ring`, `Grid.near_portal`): on the Citadel row 0 at columns 8 and 11 and row 1 at columns 8 to 11, the same shape on every map. The ring is tinted red on the ground and refused with "Too close to the portal". The other 52 tiles of rows 0 to 2 build again (two more are the portal). A flyer is first in reach 3.5 m from the portal (5.5 m with the band, under 1 m with nothing). Tiles that reach the flight line: 102 on the Citadel, 94 on the Rampart, 77 on the Causeway (98, 89 and 75 with the band). The Rampart bot walls stay on rows 3 and 5; nothing measured whether rows 2 and 4 would be better.

### The camper under the ring

The owner's opening was a row-1 wall from column 1 to 11 with a hook at (11, 0), sending creeps west along row 0 past the whole wall. The ring takes five of those tiles. Where it does, the camper now builds the ring's edge one tile further out instead (`Camper.RING_EDGE`): row 2 at columns 8 to 11 under the ring, and (12, 0) and (12, 1) in place of the hook. Creeps leave the ring west along row 0, past his row-1 wall, as in his game.

Moving his pattern down to row 2 instead, as the camper did under the band, left his wall out of reach of creeps walking row 0, and the idle bot lost every life on wave 1. Leaving his row 1 as it was with the ring tiles skipped left a four-tile hole under the portal.

The idle bot (that opening, never touched again), one game each on the Citadel:

| Mode | First leak | Result |
|---|---|---|
| Easy | wave 10 (the Ogre) | 14 lives left at wave 12 |
| Normal | wave 10 (the Ogre) | 6 lives left at wave 12 |
| Very Hard | wave 5 | lost on wave 7 |

Under 0.4.2's band the same bot leaked on wave 3 and lost on wave 6 on Normal, and lost on wave 3 on Very Hard. The ring hands back the north edge that his opening leans on, so on Normal a build left alone holds to the wave-10 boss again even with four-arrow creeps. That is the owner's call to judge in play.

The owner's 0.4.1 record still can't judge these numbers: 7 of the first 19 actions are refused (builds on ring tiles among them) and wave 1 takes all 20 lives. A fresh 0.4.3 record is the one to keep in `tests/playtests`.

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
