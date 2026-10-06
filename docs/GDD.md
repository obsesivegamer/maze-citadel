# Maze Citadel — Game Design

This is the design reference for Maze Citadel: every rule, tower, creep and wave, with the numbers the game uses. If you only want to play, the [README](../README.md#how-to-play) covers what you need. Come here when you want to know exactly how something works.

## Overview

Maze Citadel is a single-player maze tower defense. Creeps walk from a portal at the north end of a plateau to a gate at the south end, and the player's towers are the maze they walk through. A tower reaches only the tiles around it, so a longer road that runs past more towers gives every tower more time to shoot. The player can bend the road as far as they like but can never close it. On the third map, the Winding Causeway, the road is fixed instead, and the game is choosing where to build beside it.

Two counter systems sit on top of the maze. Each tower has an attack type that is strong or weak against each armor class, and an element that is strong or weak around a ring of six. Every wave announces its armor and element ahead of time, so the game rewards reading what's coming and building for it. The forty waves start with one lesson each and build up to mixed pressure, with a boss every tenth wave.

Elements have to be earned. The game opens with three towers that need no element (Archer, Cannon and Bard), and eight element picks over the game unlock the rest a level at a time: eight picks against eighteen element levels, never enough to take all six elements to the top. The first pick is granted at once; every later one summons a Guardian, a boss of that element that grants the level only when it dies. Four difficulties run from Easy to Very Hard.

The design borrows from the Warcraft III custom maps it grew out of: the element picks, counters and looping leaks of Element TD, the fusion of Gem TD, the open mazing and anti-block rule of Wintermaul One, and the mix of cheap filler and tech towers from Poker TD and Cube Defense. It isn't a clone, and no Blizzard names, models or sounds ship with it.

The game has two rule sets. The Element TD rules are the default, and this page describes them. The classic rules, the game as released in 0.3.1, are one click away before wave 1; where they differ, a short note says so ("Classic: 220 gold"), and §5.0 sums up the differences.

The numbers on this page are the ones in the game. They began as estimates and were tuned by having bots play full games, and [balance.md](balance.md) records what changed and why. When a number changes in the game, this page changes in the same commit.

The section numbers below are stable, because comments in the code refer to them, for example "GDD §10".

---

## 1. Board and first frame

| Item | Value |
|---|---|
| Buildable plateau | 20 × 28 tiles, 1 tile = 2 m (40 × 56 m) |
| Tower footprint | 1 tile |
| Portal | Red demon portal, north edge, 2 tiles wide, unbuildable |
| Gate | Blue town gate, south edge, 2 tiles wide, unbuildable |
| Straight path | 28 tiles (≈19 s for a Grunt) |
| Camera at launch | 3/4 top-down, whole plateau in view, builder selected |
| HUD at launch | The setup panel (§5) over the board, the game paused until Start. Then: Gold 400 · Lives 20 · Wave 1 preview: 15 Grunts · 45 s build countdown · one element pick waiting. Classic: 220 gold, 10 Grunts, no picks |

Around the plateau: cliffs, outer walls with banners, pine forest, a river with a watermill, a village of huts, sheep fields, drifting clouds.

**Maps** ([maps.md](maps.md)). The table above is **Citadel Plateau**, the default. **Fallen Rampart** keeps the same plateau but opens the portal at columns 5–6 and the gate at columns 13–14, and a broken wall crosses row 13 with three 2-tile breaches, plus two 2 × 2 boulder heaps. Ruins can't be built on. **Winding Causeway**, played under the default rules only, lays a fixed cobbled road of 119 tiles (about 240 m) from the portal to the gate; creeps never leave it, and towers go on the grass beside it (§2). It has its own creep HP multiplier, Guardians included, set so the map plays about as hard as the Citadel ([balance.md](balance.md#element-td-rules-the-fixed-lane-map-2026-10-04)). Under classic rules the Causeway is greyed out.

The map and the rule set are picked on the setup panel before the clock starts (§5), or from the panel under the gold counter (its MAP and RULES rows) during the opening build phase; switching either clears the board, keeps the mode, and is remembered. Best waves are kept per map and per rule set.

The first frame is the game: the board is already drawn behind the setup panel. No title screen and no empty scene.

## 2. Pathing rules

- **Ground creeps** follow a flow field computed from the gate (Dijkstra over the tile grid, 8-way moves, diagonal cost 1.41).
- **No corner squeezing:** a diagonal move is allowed only if both side tiles are open.
- **Live updates:** every build or sell recomputes the field (560 tiles, well under 1 ms). Creeps already on the board re-route at once.
- **Anti-block (mandatory):** a placement is refused if, with the new tower in place:
  1. the portal can no longer reach the gate, or
  2. any ground creep's current tile can no longer reach the gate, or
  3. a creep is standing on that tile.
- **Refusal feedback:** red ghost, "thunk" sound, short shake of the ghost. Nothing is spent.
- **Dotted path:** glowing dots trace the current portal-to-gate route and flow toward the gate. It starts as a straight line and redraws on every change.
- **Air creeps** (Harpies) ignore the maze and fly the straight portal-to-gate line at 4 m altitude. Pale dots mark that line while a tower's reach is shown (§10).
- **Fixed lane** (Winding Causeway): every tile off the road is ground a tower can stand on but creeps never walk, so no tower can block, bend or lengthen the road. A tower on a road tile is refused ("Keep the road clear"), and selling a tower returns its tile to grass.

## 3. Rules: lives, leaks, waves, speed

| Rule | Value |
|---|---|
| Lives | 20 |
| Leak cost | Normal creep −1, boss and Bulky creep (§9.1) −2, Guardian (§7.3) −3. Classic: normal −1, boss −2 |
| Leak feedback | Gate flashes blue-white, war horn, lives counter pulses. The first leak of a game also puts a line above the cards: "Leaked creeps cost lives and walk the maze again until killed. Interest stops until the board is clear." Classic: no line |
| After a leak | Creep teleports back to the portal with its current HP and runs again. It no longer pays bounty. Each pass costs lives again. Interest stops until the field is clear (§4). |
| Defeat | Lives reach 0. Screen shows wave reached, kills, time, gold earned, best wave, the elements reached, and what was left unspent ("Unspent: 3 picks · 3,453 gold") when a pick was still waiting or the gold had passed the point where interest stops growing (§4). Its buttons are Play again, Change setup and Quit to desktop. |
| Victory | Clear wave 40. Screen shows score and stats, with the same buttons as defeat; gryphons circle the citadel. |
| Score | 10 × kills + 500 × lives left + gold on hand, × 0.7 on Easy, × 1.3 on Hard, × 1.6 on Very Hard |
| Opening build phase | 45 s countdown, from the moment Start is pressed on the setup panel (§5). `N` starts wave 1 now. |
| Wave announcement | 3 s before spawn: banner with creep icons, count, armor class, element and boss skull, and a line each for flyers ("FLYING: ignores your maze and flies straight from portal to gate; only wing-icon towers beside the flight line hit it", on every wave that has them), composite armor (§6.5) and the Bulky shape (§9.1). Classic: no flying or composite line |
| Spawn interval | 0.6 s (Wolf Riders 0.35 s; bosses enter alone after escorts). Classic: 0.9 s, Wolf Riders 0.5 s |
| Between waves | Wave cleared → 30 s breather → next wave auto-queues. A wave counts as cleared only once any Guardians walking with it are dead too. The top bar also shows the wave after next. `N` calls the next wave early (waves may overlap). Classic: 5 s breather, no wave-after-next preview |
| Speed | ×1 / ×2 / ×3 (`F` cycles). `Space` pauses. Building is allowed while paused. |

Simulation runs on a fixed 30 Hz step; ×2 and ×3 run 2 or 3 steps per frame. The same sim runs headless for tests and balance bots.

## 4. Economy

| Item | Value |
|---|---|
| Starting gold | 400. Classic: 220 |
| Kill bounty | `round(6 + 16 × (wave − 1) / 39)` → 6 gold at wave 1, 22 at wave 40, per creep of the wave table. The default rules send 1.5 times the creeps and share each group's gold out among them in whole coins, so a wave pays the same in total (§9.1). |
| Boss bounty | Ogre ×10, Dreadlord ×25. Guardians pay nothing. |
| Interest | Every 15 s of game time: +2% of unspent gold, max +20 per tick. Each element pick spent on Interest adds 1 point and 10 gold to the cap, up to three times (5%, max +50; §7.3). Pauses with the game. HUD shows a countdown ring and the next payout. |
| Interest lock | Once any creep leaks, the interest countdown stops where it is and nothing is paid until every creep on the board is dead; then it carries on from where it stopped. The ring dims and shows a lock meanwhile. Classic: interest keeps paying after a leak |
| Sell | 75% of everything invested in that tower (build + upgrades + fusion) |
| Opener check | 400 gold = 16 Archer Towers (25 g), or 8 Archers and 3 Cannons with 20 g left. Until the first wall row is whole, creeps walk round its end and only the towers there reach them. Classic: 220 gold = 8 Archers with 20 g left, or 6 Archers + 1 Frost Spire |

**Cost curve:** buildable towers cost 25–120 g; upgrades cost 15–120 g. Together they span the requested 15–120 g. The cheapest *tower* is 25 g, not 15 g: at 15 g, classic's 220 gold would buy 14 towers, which breaks its "6–8 cheap towers" opener. The default rules start with 400 because a tower reaches only its neighbours: at 220 the novice bot loses on wave 2 whatever the creep HP.

## 5. Modes

| Mode | Change |
|---|---|
| Easy | Creeps have 70% of their HP. Score × 0.7. |
| Normal | Base values |
| Hard | Creep HP × 1.06 on wave 1 rising in a straight line to × 1.28 on wave 40; no bounty bonus. Score × 1.3. Classic: +10% on wave 1 rising to +40% on wave 40 |
| Very Hard | Creep HP × 1.1 on wave 1 rising to × 1.55 on wave 40 on a squared curve, so it stays close to Hard until about wave 25 and climbs steeply after; the last ten waves are the wall. Score × 1.6. |
| Infinite | After wave 40, waves continue from mixed templates. HP × 1.08 per wave past 40, on top of the curve. No element picks come after wave 35's. |
| Twists | From wave 11, most waves carry one random creep ability (below). Combines with every difficulty and Infinite. Score × 1.1. |

Easy, Normal, Hard and Very Hard are the four difficulties, each with its own records; Infinite and Twists are switched on beside one. Classic offers only Normal and Hard. The difficulty and the extras are picked on the setup panel before the clock starts, or from chips in the top bar during the opening build phase, and lock when wave 1 spawns. Play again keeps them, along with the map and rules, and the next launch starts with the last ones picked (a difficulty the rules don't offer becomes Normal). `--difficulty=hard` on the command line picks a difficulty for one launch without changing the saved one. Bots, benchmarks and captures always start on Normal with no extras unless their flags say otherwise. Each new game deals a fresh Twists schedule; only a map or rules switch before wave 1 keeps the one dealt.

**The setup panel.** Every fresh match in a real window opens on a panel over the board, with the game paused, so the 45 s opening countdown waits until the player is ready. It holds the MAP and RULES rows, the difficulties the rules offer with a line each on what it does (the same as the top bar's chip tooltips, which read the creep HP each difficulty gives on wave 1 and on wave 40 and its score multiplier from the rules, so a retune rewrites them), Infinite and Twists with a line each, and the Tutorial chip (the same setting as Settings → Help → Tutorial). Nothing applies until **Start** (or `Space` or `Enter`), which sets the mode, remembers it with the tutorial choice, and starts the clock; with the tutorial on, the welcome card (§11.1) follows at once. A map or rules switch on the panel rebuilds the board and opens the panel again with the choices made so far. Play again and the pause menu's Restart skip it and start the clock at once on the same setup, because that setup has just been chosen; the pause menu's New game setup and the end screen's Change setup start over on the panel instead. A map switch from the panel under the gold counter, after Start, also starts at once. Headless tools, bots, captures, benchmarks, launch probes, warps and `--no-tutorial` never show it, and `--open=setup` opens it for a screenshot.

### 5.0 Rule sets

The game has two rule sets, and the RULES row (Element TD | Classic) switches between them, on the setup panel before the clock starts (§5) or in the panel under the gold counter during the opening build phase. Switching rebuilds the board, keeps the map and the difficulty where the other rules offer them (otherwise the Citadel Plateau and Normal), and is remembered for the next launch. On the command line, `--rules=classic` or `--rules=eletd` picks one; without it the game plays the rules last picked, and on a first launch the Element TD rules. The two keep separate records (§15).

- **Element TD** (`eletd` in the code) is the default and is what the rest of this page describes. It brings the game closer to Element TD and makes it harder: towers reach only the tiles around them, elements are earned with picks, and waves come as long, tight streams.
- **Classic** is the game as released in 0.3.1, kept exactly as it played there. Its numbers appear on this page as short "Classic:" notes.

| Rule | Element TD (default) | Classic |
|---|---|---|
| Tower reach (§7.1) | The 3×3 block of tiles around the tower | The range in metres from §7, shown as a ring |
| Starting gold (§4) | 400 | 220 |
| Creep HP (§8) | A share of classic's, from 10% on wave 1 to 68% on wave 40 | The full curve |
| Elements (§7.3) | Earned with 8 element picks; later picks summon Guardians | Every tower open from the start |
| Archer and Cannon (§6.2, §7.2) | Composite damage; the Archer fires one arrow at every level and its upgrades deal 85% and 80% | Light and Flame; the level-3 Archer fires two arrows |
| Elemental towers (§7.2) | 140% damage, the Plague Cauldron excepted | Table damage |
| Wave shapes (§9.1) | 1.5 times the creeps, 0.6 s apart; composite waves 14, 27, 34; Bulky waves 12, 18, 25, 37 | Table counts, 0.9 s apart |
| Between waves (§3) | 30 s, with the wave after next shown | 5 s |
| Interest (§4) | Locked after a leak until the field is clear; picks can raise it | Always paid |
| Difficulties (§5) | Easy, Normal, Hard, Very Hard | Normal, Hard |
| Maps (§1) | Citadel Plateau, Fallen Rampart, Winding Causeway | Citadel Plateau, Fallen Rampart |

### 5.1 Twists (random wave abilities)

In the spirit of Element TD's random creep abilities. The schedule comes from a seed (`--twists --seed=N` replays one), so it can't be rerolled by calling waves early. The next-wave chip shows the coming twist a full wave ahead, and the wave banner repeats it.

| Twist | Player text | Effect | Never on |
|---|---|---|---|
| Swift | Creeps move 20% faster. | speed × 1.2 | Wolf Rider waves |
| Plated | Creeps gain +3 armor. | armor + 3 (Poison ignores it, shred strips it) | before wave 15; waves ≥ 75% Armored |
| Stampede | Creeps arrive twice as tightly packed. | spawn gap × 0.5 | Harpy waves |
| Unstoppable | Creeps can't be slowed, rooted or frozen. | slows, roots and freezes do nothing | — |
| Undying | Creeps rise once at a third of their HP. | the Ghoul rule for every creep | Ghoul or Harpy waves |
| Second Wind | At half HP, creeps heal 25% once. | first time at ≤ 50% HP: +25% max HP (half while poisoned) | — |

- Waves 1–10 teach the basics and stay clean, as do boss waves and the all-Armored waves 22, 23, 33 and 38 (already the hardest regular waves). Bosses never carry a twist.
- One twist per wave, never the same twist two twisted waves in a row. A twist that has come up less often is likelier (weight 1 / (1 + times so far)), so a run sees all six without any fixed wave for one of them.
- Twists never change a wave's element, armor class, creep count, bounty or leak cost.

## 6. Damage model

```
damage = base × power[tower][level]         // §7.2; always 1 under classic
       × attack_vs_class[attack][class]
       × element_mult[tower_element][creep_element]
       × armor_factor(armor − shred)        // skipped for Poison
       × (1 + bard_aura)
```

`armor_factor(A) = 1 − 0.06A / (1 + 0.06A)` for A ≥ 0, and `2 − 0.94^(−A)` for A < 0 (shredded armor below zero amplifies damage).

The power factor applies to every hit, poison stack, cloud and crater, and a shot carries the power of its tower as it was when it fired (§7).

### 6.1 Attack type vs armor class

| Attack ↓ / Class → | Light | Armored | Air | Boss |
|---|---|---|---|---|
| Pierce (Alliance) | **150%** | 50% | **175%** | 70% |
| Siege (Horde) | 100% | **175%** | cannot hit | 100% |
| Magic (Elven) | 100% | 125% | 100% | 75% |
| Poison (Forsaken) | 100% | 100% | 100% | 100%, ignores armor |
| Rune (Runesmith) | 100% | 100% | 100% | 100% |

### 6.2 Element wheel (Element TD style)

`Light → Dark → Aqua → Flame → Verdant → Stone → Light`

Each element deals **200%** to the element it points at, **50%** to the element that points at it, **100%** to the rest.

| Tower element | Strong vs (200%) | Weak vs (50%) | Towers |
|---|---|---|---|
| Light | Dark | Stone | Ballista, Epic Sunfire Ballista (classic: also Archer) |
| Dark | Aqua | Light | Plague Cauldron, Shadow Obelisk, Epic Plague Necropolis |
| Aqua | Flame | Dark | Frost Spire, Epic Frost Wyrm |
| Flame | Verdant | Aqua | Demolisher, Epic Doom Cannon (classic: also Cannon) |
| Verdant | Stone | Flame | Ancient of Roots |
| Stone | Light | Verdant | Runesmith Forge |
| Composite | — | — | Archer, Cannon: 100% against every creep element, composite armor included. Their cards, tooltips and plaque say Composite and "100% against everything". |

Every creep element has exactly one counter family. Each wave announces its element 3 s before it spawns. The Bard's Pavilion has no element.

### 6.3 Damage numbers

| Result | Look |
|---|---|
| Strong counter | Gold, large, with "!" |
| Weak counter | Grey-blue, small |
| Neutral | White |
| Poison tick | Green, small |
| Immune | Steel "IMMUNE" |

### 6.4 Status rules

- **Slow:** strongest slow applies; slows don't stack. Bosses take half duration.
- **Root:** stops movement. Never applies to bosses.
- **Poison:** stacks up to 5. Halves healing received.
- **Armor shred:** −2 per Runesmith hit, up to −10, lasts 6 s, refreshes on hit.

### 6.5 Composite armor

Waves 14, 27 and 34 (and the Infinite waves that replay 34) wear composite armor: every element deals 90% to them, so no counter pays double and none pays half. The composite Archer and Cannon still deal 100%. The top bar and the banner show a grey plate glyph, the banner and the next-wave chip's tooltip add "Composite armor: elements don't matter this wave: Archers and Cannons hit at full strength, element towers 90%", and the Field Guide says "Composite: every element does 90%". Classic has no composite armor.

## 7. Towers (14)

10 buildable cards plus 4 Epic fusion cards, one per family. Upgrades: L1 → L2 → L3 (two upgrade levels). The damage figures are the tower table's; under the default rules each tower deals its power share of them (§7.2). The ranges in metres are classic's reach and the Bard's aura radius; under the default rules every attacking tower reaches the tiles around it instead (§7.1). Every tower but the Archer, the Cannon, the Bard and the Epics needs its element (§7.3).

| Key | Tower | Family | Cost L1 / +L2 / +L3 | Attack · Element | Air? | L1 stats | Signature |
|---|---|---|---|---|---|---|---|
| 1 | Archer Tower | Alliance | 25 / +15 / +35 | Pierce · Composite (classic: Light) | ✓ | 9 dmg, 0.6 s, 9 m (L2 15, L3 24) | Cheap maze filler, open from the start. One arrow at every level; classic's L3 fires 2. |
| 2 | Cannon Tower | Horde | 60 / +45 / +80 | Siege · Composite (classic: Flame) | — | 30 splash r2.2, 1.5 s, 10 m (L2 60, L3 110) | Arcing shells, scorch marks (6 s, look only), small shake |
| 3 | Frost Spire | Elven | 50 / +40 / +70 | Magic · Aqua | ✓ | 8 dmg, 1.0 s, 9 m | 35% slow for 2 s. L2 splash slow r1.5. L3 frost ring every 3rd shot. |
| 4 | Plague Cauldron | Forsaken | 45 / +35 / +65 | Poison · Dark | ✓ | 6 dps × 5 s per stack, 1.2 s, 8.5 m | Stacks ×5, ignores armor, halves healing |
| 5 | Bard's Pavilion | Support | 80 / +60 / +90 | — | — | Aura r7 m | +15% damage (L2 +20%, L3 +25% and +10% attack speed). Highest aura wins. |
| 6 | Runesmith Forge | Support | 75 / +55 / +90 | Rune · Stone | ✓ | 14 dmg, 1.2 s, 9 m | Shreds 2 armor per hit |
| 7 | Ballista | Alliance | 70 / +60 / +100 | Pierce · Light | ✓ | 55 dmg, 1.6 s, 12 m | Bolt pierces 3 creeps in a line |
| 8 | Demolisher | Horde | 120 / +90 / +120 | Siege · Flame | — | 110 splash r3, 3.0 s, 15 m (classic: min 4 m) | Burning crater 3 s at 10 dps, big shake |
| 9 | Ancient of Roots | Elven | 90 / +70 / +110 | Magic · Verdant | — | Nova every 3 s, r5 m, 20 dmg | 35% slow 2 s + 0.4 s root |
| 0 | Shadow Obelisk | Forsaken | 100 / +80 / +110 | Poison · Dark | — | Cloud r2.5 m for 4 s, 18 dps | Up to 3 clouds overlap, ignores armor |
| G | **Epic Frost Wyrm** | Elven | Fuse 2 × L3 Elven + 100 g | Magic · Aqua | ✓ | Breath cone 7 m, 60 dmg, 1.2 s | 50% slow 3 s; every 5th breath freezes 1 s. Wyrm coils the spire, 1.4× scale. |
| G | **Epic Doom Cannon** | Horde | Fuse 2 × L3 Horde + 120 g | Siege · Flame | — | 300 splash r4, 3.5 s, 16 m | Molten crater 5 s at 25 dps, heavy shake, 1.4× scale |
| G | **Epic Sunfire Ballista** | Alliance | Fuse 2 × L3 Alliance + 120 g | Pierce · Light | ✓ | Lance 150 dmg, 1.8 s, 14 m to aim | The lance flies on 40 m from the tower and hits every creep it passes once (no pierce limit, 1 m wide), so a maze that lines creeps up with it pays off. Leads moving targets. Sun disc on the bow, 1.4× scale. |
| G | **Epic Plague Necropolis** | Forsaken | Fuse 2 × L3 Forsaken + 100 g | Poison · Dark | ✓ | 25 dps × 4 s per stack, 0.8 s, 10 m | Targets the closest creep not yet carrying its plague. Contagion: a creep that dies (or a Ghoul that goes down) carrying a stack passes one to every creep within 3 m. Shares the 5-stack poison cap; Cauldron stacks don't spread. 1.4× scale. |

**Fusion:** select an L3 tower, press `G`, click a second L3 tower of the same family. The Epic appears on the first tile. The second tile is freed and the path updates (freeing a tile can only open the maze, never block it). A shot lands as the tower that fired it was when it fired: arrows, shells, bolts and lances already in flight, the poison stacks and craters they leave and the clouds already on the board keep that tower's damage, element and effects through an upgrade or a fusion.

**Targeting** is a fixed trait of each tower type; the player never aims. Every tower shoots the creep closest to the gate except the Plague Necropolis (closest uninfected creep first).

### 7.1 Reach

A tower attacks only creeps on the 3 × 3 block of tiles around it: its own tile and the eight next to it. The block's edges count, so a creep walking a tile border, as flyers do on the portal-to-gate line, is reached from both sides alike. This holds for every attack: the Ancient of Roots' nova and the Frost Wyrm's breath hit only creeps in the block, and the Demolisher has no minimum range. Splash, poison clouds, craters, frost rings and the Bard's aura keep their sizes, and the Ballista's bolt and the Sunfire Ballista's lance aim at a creep in reach and fly on along their line as far as before. Placing, hovering or selecting a tower shows its block as a square (§10).

Flyers ignore the maze and fly the straight line from portal to gate, so only the tiles whose block the line crosses can hit them: columns 8 to 11 on the Citadel, 98 tiles on the Rampart's diagonal and 82 on the Causeway, where the road takes many of the rest. On the Citadel a tile sees about 1.8 s of a Harpy's flight. The top bar rates the board's air cover for the next flying wave (§11.1).

A long road matters only where it runs past towers, so the maze is a matter of lining the road with them; a tile beside two corridors of the maze reaches both. Classic: each tower reaches the range in metres from the table above, shown as a ring.

### 7.2 Tower power

Under the default rules a tower deals a share of its table damage, set per tower and level, on every hit, poison stack, cloud and crater:

| Towers | Power |
|---|---|
| Ballista, Demolisher, Frost Spire, Ancient of Roots, Shadow Obelisk, Runesmith Forge (every tower that needs an element but the Plague Cauldron) | 140% |
| Archer | 100% at L1, 85% at L2, 80% at L3 (9, 12.75 and 19.2 damage) |
| Cannon, Bard's Pavilion, Plague Cauldron, every Epic | 100% |

The table priced the elemental towers for their range, which reaching only the tiles around them took away, and at full damage the Archer's upgrades were among the best buys per gold in the game ([balance.md](balance.md#element-td-rules-retune-after-element-picks-2026-10-04)). Cards, tooltips and the upgrade preview show the damage these rules deal. Classic: every tower deals its table damage.

### 7.3 Elements and picks

Each of the six elements has a level from 0 to 3, all 0 at the start. A tower of an element can be built only with that element at level 1, upgraded to L2 only at level 2, and to L3 only at level 3: Ballista needs Light, Demolisher Flame, Frost Spire Aqua, Plague Cauldron and Shadow Obelisk Dark, Ancient of Roots Verdant, Runesmith Forge Stone. A refused build or upgrade says why ("Needs Aqua", "Needs Aqua level 2"). Archer, Cannon and Bard need nothing, and an Epic needs only its two L3 parents.

| Rule | Value |
|---|---|
| Element picks | One at the start and one as each of waves 5, 10, 15, 20, 25, 30 and 35 is cleared: 8 in all, against 18 element levels, so no game has everything. Infinite mode adds none after wave 35. A pick is kept until the player spends it, on one level of an element or on Interest. |
| First pick | The first pick spent on an element grants its level at once. |
| Guardians | Every later element pick summons a Guardian of that element instead: a boss that enters at the portal at once, whatever the phase, and grants the level only when it dies. It has 0.35, 0.8 or 1.2 times the HP of a lone Ogre of the current wave for level 1, 2 or 3, taking the share, the difficulty and the map multiplier of §8 but no boss wave's own scaling, armor 8 and speed 2.0 m/s, pays no bounty, costs 3 lives when it leaks and walks again until killed. It is drawn as the Ogre, 15% larger. A wave counts as cleared only once its Guardians are dead too, and no second pick can go on an element while its Guardian walks. |
| Interest picks | A pick spent on Interest adds 1 point to the interest rate and 10 gold to the cap per tick, up to three times (5% and 50 gold). It summons no Guardian. |

The HUD for all of this is in §11.2. Classic: there are no element levels or picks, and every tower is open from the start.

## 8. Creeps

`HP(wave) = 60 × 1.105^(wave − 1) × type multiplier × share × difficulty multiplier × map multiplier` (Infinite adds its growth past wave 40, §5).

- **The curve** `60 × 1.105^(wave − 1)` is about 147 at wave 10, 400 at 20, 1086 at 30 and 2950 at 40, before the type multiplier.
- **The share** climbs in a straight line from 0.10 on wave 1 to 0.68 on wave 40. Armored creeps climb to 0.70 on a squared curve instead, never below the line, so waves 3 and 7 barely change and late armor needs siege. The wave-10 Ogre gets 2.1 times its share and the Dreadlord 0.3 of it, on top of the wave table's own boss scale below.
- **The difficulty multiplier** is in §5, and **the map multiplier** is 1 except on the Winding Causeway, which has its own ([balance.md](balance.md#element-td-rules-the-fixed-lane-map-2026-10-04)).
- A wave's groups are then split over 1.5 times the creeps (§9.1), each with its matching part of this HP: the 15 Grunts of wave 1 have 4 HP each.

Classic: `HP(wave) = 60 × 1.105^(wave − 1) × type multiplier × mode multiplier`, the full curve, with Hard's multiplier from §5 as the mode multiplier. Tuned by the balance bots; see [balance.md](balance.md).

| Creep | Class | Armor | Speed m/s | HP × | Mechanic |
|---|---|---|---|---|---|
| Grunt | Light | 1 | 3.0 | 1.0 | Baseline |
| Wolf Rider | Light | 0 | 5.0 | 0.65 | Fast |
| Shield Footman | Armored | 4 | 2.6 | 1.3 | High armor; raises shield when hit |
| Priestess | Light | 0 | 2.8 | 0.9 | Heals allies within 5 m for 4% max HP every 2 s |
| Harpy | Air | 1 | 3.4 | 0.8 | Flies straight, ignores maze; air-capable towers only |
| Ghoul | Light | 2 | 3.2 | 1.0 | Revives once after 1.5 s at ⅓ HP; bounty on final death |
| Steam Tank | Armored | 10 | 2.2 | 2.1 | Every 6 s: immune for 1.5 s (steam shroud) |
| Ogre Boss | Boss | 8 | 2.0 | 12 (×2.2 on wave 10, ×3.2 on wave 20, ×0.9 on wave 30) | Aura r6 m: escorts +3 armor, +10% speed (not other bosses). Leak −2. |
| Dreadlord | Boss | 12 | 1.8 | 27 | Summons 3 Felhounds every 10 s. Leak −2. |
| Felhound (summon) | Light | 2 | 4.0 | 0.6 | Dreadlord summon, Dark element |
| Guardian (element pick) | Boss | 8 | 2.0 | Set by the pick (§7.3) | Summoned by an element pick; grants that element's level when it dies. No bounty. Leak −3. |

Every creep has an HP bar, a team-color rim so its silhouette reads at full zoom-out, and walk / hit / death animations.

## 9. Wave pacing (40 waves, 8–24 creeps each)

| Waves | Theme |
|---|---|
| 1–9 | One new mechanic per wave (table below) |
| 10 | **Boss:** Ogre Chieftain + 8 Grunts |
| 11–19 | Air, heal and revive: Harpy flocks with Priestess ground escorts, Ghoul packs with healers, split air + ground waves |
| 20 | **Boss:** Ogre Warlord + Harpy escort |
| 21–29 | Armor and immunity combos: Steam Tanks + Footmen + Priestesses, Tanks + Ghouls |
| 30 | **Boss:** Twin Ogres + Steam Tank escort |
| 31–39 | Mixed pressure, 18–24 creeps, two elements per wave |
| 40 | **Final:** Dreadlord + Felhound summons + Ghoul escort (Dark) |

| Wave | Creeps | Element | Teaches |
|---|---|---|---|
| 1 | 10 Grunts | Flame | Mazing basics |
| 2 | 14 Wolf Riders | Dark | Speed |
| 3 | 8 Shield Footmen | Verdant | Armor, Siege bonus |
| 4 | 10 Grunts + 3 Priestesses | Aqua | Healers, Poison counter |
| 5 | 12 Harpies | Light | Air, anti-air towers |
| 6 | 14 Ghouls | Dark | Revive |
| 7 | 4 Grunts + 6 Steam Tanks | Flame | Immunity windows |
| 8 | 12 Wolf Riders + 8 Grunts | Flame | Mixed speeds |
| 9 | 12 Footmen + 4 Priestesses | Aqua | Armor + heal |
| 10 | Ogre Chieftain + 8 Grunts | Flame | Boss aura, −2 leak |

The full 40-row table is in `src/data/wave_defs.gd`. Elements rotate so each one appears 6–7 times. The counts above are the table's, which classic plays as written (8 to 24 creeps a wave); the default rules reshape every wave as below, to 11 to 36 creeps.

### 9.1 Wave shapes

Element TD sends long streams, so the default rules change each wave's shape but not its total HP or gold:

| Rule | Value |
|---|---|
| Wave size | Every group except a boss has 1.5 times the creeps, rounded up (wave 1: 15 Grunts), entering 0.6 s apart (Wolf Riders 0.35 s; Stampede still halves the gap). Each creep has the matching share of the group's HP and bounty, so a wave's totals stay what the table gives. |
| Composite waves | Waves 14, 27 and 34 wear composite armor (§6.5). |
| Bulky waves | Waves 12, 18, 25 and 37 send half as many creeps, rounded up, each with twice the HP and twice the bounty, so a Bulky wave carries the HP of the wave it replaces. A Bulky creep that leaks costs 2 lives, like a boss, and is drawn 1.3 times larger. The next-wave chip, its tooltip, the banner and the Field Guide tag the wave Bulky. |
| Preview | With 30 s between waves, the top bar shows the wave after next beside the next-wave chip. |

Infinite's replays of waves 34 and 37 keep their composite and Bulky shapes. Classic: the table's counts, 0.9 s apart (Wolf Riders 0.5 s), no composite or Bulky waves.

## 10. Controls and camera

| Input | Action |
|---|---|
| Left-click | Place tower (snaps to tile) / select tower |
| Shift + left-click | Keep placing the same tower |
| Right-click | Cancel the build ghost; on a selected tower, sell |
| `1`–`0` | Pick a tower card (spec's `1`–`6` cover Archer, Cannon, Frost, Poison, Bard, Runesmith) |
| `U` / `X` / `G` | Upgrade / sell / fuse the selected tower |
| `Esc` | Close the topmost panel; else deselect or cancel; else open the pause menu (§11) |
| `Space` / `F` | Pause / cycle speed ×1 ×2 ×3 |
| `N` | Start or call the next wave |
| `R` | Hero view (reset to the default 3/4 camera) |
| `C` / `B` | Cycle camera presets (full board, portal close-up, gate defense) / toggle boss tracking |
| `H` | Field Guide (§11.1) |
| `F10` | Settings, or the gear on the top bar |
| `E` | While an element pick waits: open the pick panel (§11.2). Otherwise it rotates the camera. |
| Camera | WASD or edge pan, scroll zoom, middle-drag or Option-drag (Alt-drag on PC) orbit, `Q`/`E` rotate (`Q` only while a pick waits), trackpad two-finger pan and pinch zoom on Mac. Windows and Linux touchpads zoom with a two-finger swipe, scaled to the swipe's size. All damped. On Windows and Linux, `F11` or `Alt`+`Enter` toggles fullscreen. |

A tower's reach shows only for the hovered or selected tower (and for the ghost while placing): a square around the 3 × 3 tiles it reaches. The straight line the flyers take is always drawn: a thin strip on the ground under pale blue arrows that drift from portal to gate at a Harpy's height and speed. It is bright while the next or the running wave has flyers and dim otherwise, and it flashes once when a flyer leaks. While a tower that hits air is chosen to build, the tiles that reach the line are tinted the same blue (§7.1). Classic: a range ring, and no flight line.

## 11. HUD

- **Top bar:** element levels and the pick chip (§11.2) · gold, with "Interest maxed" beside it once more gold earns no more interest (§11.2) · lives · wave n/40 with next-wave chip (icons, element, class, skull, Flying or Bulky tag; its tooltip repeats the banner's flying and composite lines), the wave after next and, when either has flyers, the air cover for it (§11.1) · interest ring + next payout · speed · pause · difficulty · quality · camera presets · Field Guide. Classic has no element group and no wave after next.
- **Setup panel:** over the board at the start of each fresh match until Start: map, rules, difficulty, Infinite, Twists and the tutorial (§5).
- **Map and rules panel:** under the gold counter until wave 1, the MAP and RULES rows (§1, §5.0).
- **Bottom bar:** 14 cards. Each shows icon, name, cost, hotkey, attack and element pips, air icon. Cards dim when unaffordable, and a card whose element is missing is dimmed with a lock and, while a pick that would open it waits, reads "Pick Aqua" in place of its cost. Epic cards light up when a fusion is possible.
- **Selected tower:** a small plaque floating above the tower: upgrade, sell, fuse, counters, kills and damage dealt, and under eletd the damage's share of all the towers' and, for a tower that hits air, whether it stands beside the flight line. No side panels.
- **World-space:** damage numbers, gold popups, HP bars.
- **Hint strip:** the keys that matter right now, above the cards.
- **Pause menu:** `Esc` with nothing open, chosen or selected. It pauses the game and offers Resume (`Esc`), Restart (a second click confirms; the map, rules and mode stay), New game setup (the same, but opening on the setup panel, §5), Settings, the Field Guide and Quit to desktop, which saves the game's record first. Settings and the Field Guide open over it and `Esc` returns to it.

### 11.1 Teaching the counters

In the spirit of a Warcraft III map's quest log and timed hints. All advice is computed from the damage tables (§6) and the wave table, never written per wave.

| Piece | What it does |
|---|---|
| Welcome card | First launch, straight after Start on the setup panel (the countdown waits): the maze, the element wheel, the three armor rules, how to read the next-wave chip. Begin or Skip. |
| Counsel card | Waves 1–10, top right, from the moment the previous wave starts: the next wave's lesson title, one line per element ("Verdant creeps: Flame towers deal 200%, Stone towers only 50%"), one per armor class, a note on any creep appearing for the first time, and up to two tower picks (the hardest hitter on each of the wave's groups) that glow on the card bar and can be clicked to build. |
| Tips | Once each, on the counsel card: the first counter hit (gold "!"), resisted hit (grey-blue) and IMMUNE. |
| Field Guide | `H` or the book on the top bar, any time; pauses while open. Interactive element wheel, attack vs armor chart, counsel for the next wave, damage-number key. |
| Next-wave ratings | Every tower card tooltip: "Next wave 3: 350% vs Shield Footman". The next-wave chip tooltip names the picks. Under eletd the cards of towers whose attack does more to Air say so first ("Strong vs Air: 175%"), and the Archer's blurb says to keep some beside the flight line. |
| Air cover | Under eletd, under the wave preview whenever the next wave or the one after has flyers: "Air cover, wave 34: weak", in red, gold or green for weak, thin or holding. It is an estimate: the damage per second the air-capable towers beside the flight line deal to the wave's flyers, times the seconds they stream past plus the time one spends in a tower's reach, over the flyers' total HP. It leaves out the Bard's aura, slows and overkill. Below 100% it reads weak, below 125% thin. Its tooltip gives the percentage. On the owner's 0.4.1 game it read 63% on wave 34, where 12 Harpies got through, and 96% and 130% with 10 and 20 Archers added beside the line (1 and 0 got through). When a flying wave starts below 100%, the line above the cards says so. |

The setup panel, the welcome card, the Field Guide, Settings, the pause menu and the end screen are modal: no key reaches the game behind them, `Esc` closes the topmost (`H` and `F10` close their own panels; the setup panel closes only on Start), and `Space` or `Enter` also start from the setup panel and begin from the welcome. All but the end screen pause the game while open. The tutorial turns itself off once wave 10 starts or on Skip; Settings → Help → Tutorial turns it back on (straight to the counsel card, or the closing card past wave 10). Headless tools, bots, captures, benchmarks, launch probes and warps never show it; `--tutorial` forces it. The counsel names only towers that can be built with the elements in hand, and the Field Guide has an Elements and picks page.

### 11.2 Element picks on the HUD

The top bar's left group shows the six element glyphs, each over three pips filled up to its level; the pip a walking Guardian will grant pulses, and hovering a glyph names its towers and counters. While picks wait, a pulsing chip (`PICK ×2`) sits beside them. It, or `E`, opens the pick panel: a row per element and one for Interest, each with the level it would reach, what taking it does in plain words, its counters, how it fares on the next ten waves and a Take or Summon Guardian button with the Guardian's HP. "What it does" is worked out from the board and the rules: "Unlocks Frost Spire", "Lets your 17 Frost Spires upgrade to level 2", "Summons a Guardian: kill it to gain Flame" for any pick after the first element, and "Interest: +10 gold every 15 s once you hold 1,000 gold". A row that can't be taken says why. Keys `1`–`7` take a row, `Enter` the highlighted one, `E` or `Esc` closes, and the game keeps running behind it unless it was paused.

Locked cards are dimmed with a lock and can't be chosen. Their tooltip says what opens them: "Needs Aqua: press E and take it" while a pick waits, "Needs Aqua: kill the Aqua Guardian" while its Guardian walks, otherwise "Needs Aqua: pick an element (E)". A blocked upgrade's button reads "Needs Aqua level 2". A Guardian's arrival and each element level gained get a banner, a Guardian leak a line above the cards, and the end screen lists the elements reached and any picks or idle gold left unspent.

A granted pick adds two lines to the "wave cleared" banner: that it waits (`E`) and what a pick buys. At each wave start the line above the cards first warns of a flying wave short of air cover (§11.1), then, while a pick waits and something can be bought with it, says so ("2 element picks unspent: press E"). Interest stops growing at the gold where the payout reaches its cap (1,000 gold with the starting numbers, whatever the Interest picks, since each raises the rate and the cap together). Past it, "Interest maxed" shows by the gold counter, and at a wave start, at most every third wave, the line says "Gold above 1,000 earns no more interest: build or upgrade". None of this appears under classic rules.

## 12. World life and juice (checklist)

**Living backdrop:** pines sway · clouds drift and cast moving shadows · watermill wheel turns in the river · banners flap · sheep graze · village huts cheer when a wave is cleared · peasants flee when a boss leaks · gryphons circle on victory · torches flicker at the gate · the portal swirls with red volumetric fog and sparks.

**Combat juice:** arrow tracers · shell arcs with smoke trails · frost rings · poison puffs and clouds · gold popups · placement dust and thump · upgrade sparkle · sell coin burst · gate flash and horn on leak · lingering craters · distance-scaled camera shake (toggle in settings) · hit flash · death animations.

## 13. Audio

Buses: Master, Music, SFX, UI, Ambience (sliders in settings).

- **SFX:** fire and impact per tower, death per creep type, leak horn, gate flash, coin, invalid-placement thunk, build thump, upgrade, sell, fuse, boss roar, wave horn, victory and defeat stingers.
- **Announcer:** wave start, boss incoming, victory, defeat.
- **Music:** calm build theme, battle theme, boss theme, crossfaded by state.
- **Ambience:** wind, birds, river, village.

## 14. Quality presets

Presets scale only presentation. They never change maze size, wave count, creep count or counter logic.

| Setting | Cinematic | Balanced (default) | Performance |
|---|---|---|---|
| 3D render scale (upscaled) | 0.7 (MetalFX temporal) | 0.5 (MetalFX temporal) | 0.5 (MetalFX spatial) |
| Global illumination | Off (SDFGI cost 2× for little visible gain) | Off | Off |
| Shadows | 4096, 4 cascades | 2048, 4 cascades | 1024, 2 cascades |
| Volumetric fog | High | Low (48 × 32 grid) | Off |
| Screen-space reflections | Off (little visible gain) | Off | Off |
| SSAO | High | Low | Off |
| Particles | 100% | 70% | 40% |
| Ambient crowd (villagers, sheep, birds) | 100% | 70% | 35% |
| Foliage density | 100% | 80% | 50% |
| Leaf flutter | On | On | Off (it shimmers under spatial upscaling) |

On Windows and Linux there is no MetalFX, so FSR 2 replaces MetalFX temporal and FSR 1 replaces MetalFX spatial. Cinematic and Balanced also render at least 720 px of the window's height (about 0.7 in a maximized window on a 1080p monitor, 0.67 fullscreen), because 0.5 was tuned on a Retina panel that already gets about 890 px. The scale is refit when the window changes size. Performance keeps 0.5. Grass, flowers and bushes fade out at their view range on the Mac but pop out where the fade would end on PCs, because FSR 2 makes fading leaves flicker (issue #22). PCs whose GPU has neither Vulkan nor Direct3D 12 fall back to Godot's OpenGL renderer, with bilinear upscaling and no fog or SSAO.

All presets: soft-shadow filter "low" with plain PCF (no PCSS blocker search), linear glow upscale, and terrain shaders that skip unused texture reads; from the RTS camera these look the same as the costlier versions (docs/perf.md, butter pass).

## 15. Save data

`user://save.cfg` (in `~/Library/Application Support/Maze Citadel/` on Mac, `%APPDATA%\Maze Citadel\` on Windows, `~/.local/share/Maze Citadel/` on Linux): best wave and best score per map, rule set and mode (default-rules runs end in `_eletd`, from `easy_eletd` to `very_hard_eletd`; classic runs keep the keys from before the rule sets existed, such as `normal` and `hard`; Twists runs keep their own, such as `normal_twists_eletd` or `hard_twists_infinite`; maps other than the Citadel Plateau prefix the map, as in `causeway_normal_eletd`), the last map, rule set, difficulty, Infinite and Twists picked, quality preset, volumes, camera-shake toggle. This is the native-app equivalent of browser local storage.

Next to it, `user://playtests/` holds one JSON record per game played: the setup, every action with the sim step it was taken on, and per wave how far the creeps walked, the leaks and the gold in hand. The sim is deterministic, so a record replays headless to the same game ([playtests.md](playtests.md)). The files stay on the player's computer; **Settings → Playtest → Game records** turns them off, and the same section opens the folder. Bot games are not recorded.
