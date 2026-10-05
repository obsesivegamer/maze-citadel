# Maps

Maze Citadel has three maps. This page describes how each one plays and how a map is put together in the code.

## Overview

Every map uses the same plateau, 20 tiles wide and 28 tiles long (40 × 56 m), in the same valley. What changes from map to map is where the portal and the gate open on the north and south edges, whether ruins block some tiles from the start, and who decides the road: on two maps you build the maze yourself, and on the Winding Causeway the road is laid down for you. Under the Element TD rules the top three rows, along the portal edge, take no towers on any map ([GDD §2](GDD.md#2-pathing-rules)); a faint red strip marks them.

You pick the map before wave 1 in the panel under the gold counter, beside the rules switch, and the game remembers your last choice. The Citadel Plateau and the Fallen Rampart are played under both rule sets, the default Element TD rules and the classic ones; the Winding Causeway only under the Element TD rules.

| Map | Portal | Gate | Ruins | How it plays |
|---|---|---|---|---|
| **Citadel Plateau** (default) | columns 9–10 | columns 9–10 | none | An open board with a straight 28-tile road to begin with. You build serpentine walls across the full width. |
| **Fallen Rampart** | columns 5–6 | columns 13–14 | a broken wall across row 13 with three 2-tile breaches (columns 1–2, 9–10, 17–18), and two 2 × 2 boulder heaps at (12, 5) and (6, 19) | The wall splits the board into a north maze and a south maze, joined only at the breaches. Plug two breaches and every creep funnels through the third, which makes a natural kill zone for splash and frost towers. Which breach you leave open decides how the two halves connect. Flyers ignore all of it and cross diagonally from portal to gate. |
| **Winding Causeway** (Element TD rules only) | columns 9–10 | columns 9–10 | none, but a fixed cobbled road | Creeps walk a fixed road 119 tiles long and never leave it. You can't block it or lengthen it, so the whole game is choosing where to build beside it. |

Tiles are written as (column, row), and row 0 is the portal edge on the north side, so the band by the portal is rows 0 to 2. The rule against blocking the road still applies on the Rampart, so at least one breach always stays open.

## Winding Causeway

This is the layout Element TD is known for. A cobbled road winds from the portal to the gate, and everything else on the plateau below the band by the portal is grass you can build on. Creeps keep to the road; no tower can block it, bend it or make it longer. Instead of building a maze you choose spots.

```
---------#P---------    row 0, portal
---------#----------
---#######----------
...#+...............
...#+...............
...##############...    row 5
.....xxxxxxxxxx+#...
......###########...    row 7
......#+............
......#+............
......###########...    row 10
...............+#...
...............+#...
..###############...    row 13
..#+................
..#.................
..#....######.......    row 16
..#....#+..+#.......
..#....#....#.......
..#....#....#.......
..#....#....#+......
..#....#....######..    row 21
..#....#........+#..
..#+..+#.........#..
..######........+#..    row 24
..........########..    row 25
..........#+........
.........G#.........    row 27, gate
```

`#` is the road, `.` is grass, `-` is grass in the band by the portal, where nothing is built, `P` and `G` are the second portal and gate tiles (kept clear, as on every map), `x` marks the tiles that reach two different stretches of road, and `+` the tiles tucked inside a bend.

**The road.** It is 119 tiles, about 240 m from the portal to the gate. That is about half of what the smart bot's finished maze measures on the other maps (437–510 m), but a maze is only finished late in the game, while this road is there in full from wave 1. It has six long straights (rows 5, 7, 10 and 13, and columns 2 and 7), and five of its stretches cross the line the flyers take straight down the middle, besides the road's first and last tiles, which run under it.

**Where to build.** Under the Element TD rules a tower reaches the 3 × 3 block of tiles around it, so a tile's worth is how much road falls in that block:

- A tile beside a straight reaches 3 road tiles. Most of the grass is like this, because two rows of grass lie between most stretches of road, and each row only reaches the stretch next to it.
- A tile inside a bend (`+`) reaches 5, the corner and both of its arms. The tile just inside the end of the hairpin on row 6 reaches 7.
- The hairpin on rows 5 and 7 leaves a single row of grass between two stretches. Each of those ten tiles (`x`) reaches both: every creep walks past it, leaves, and comes back past it a few seconds later. These are the prime spots, and there are only ten.
- A tile on the outside of a bend reaches no more road than one beside a straight, because the square reach doesn't follow the curve.
- Tiles two or more steps from the road reach nothing on the ground. Some of them still reach the flyers' line: the columns either side of the middle (columns 8 to 11) cover it from the band to the gate.

**How to play it.** Your first towers do more here than on the mazing maps, since the road is already long and every gold goes into damage rather than walls. To make up for that, every creep on the Causeway, Guardians included, has more HP than the rules and the difficulty give it: 1.8 times on wave 1, falling in a straight line to 1.15 times on wave 40, since a maze on the other maps only grows to its full length late in the game while this road never gets longer ([balance.md](balance.md#element-td-rules-the-fixed-lane-map-2026-10-04)). Put splash and frost on the hairpin row and inside the bends, where they meet the most of each wave, and fill the straights with cheap towers. Keep a few air-capable towers where the road crosses the middle, so the same tower covers the road and the flyers.

The Causeway is offered only under the Element TD rules. Under the classic rules most towers reach several stretches of the road from almost anywhere, so there would be no spots to choose between. The map picker shows it greyed out under classic, and switching to classic while it is picked moves you to the Citadel Plateau.

## How a map works in the code

The map table is `src/data/map_defs.gd`. Each entry has a name, a short description, the portal and gate columns, and any ruins. A fixed-lane map also lists its lane as the corners of a line along rows and columns (`MapDefs.lane()` fills in the tiles between them), and a map can name the rule sets it is played under (`MapDefs.offered()`).

**In the sim.** `Grid.new(map)` sets up everything that depends on the map: the spawn and goal tiles, the spawn and gate points, the ruin tiles, which start out blocked, and the lane. `GameSim.new(map)` passes the map through to its grid. Building on ruins is refused with `Placement.Result.OBSTACLE` and the message "Ruins block this tile". Under the Element TD rules `GameSim.rules` sets `grid.portal_rows` to `EletdRules.PORTAL_ROWS` (3), and `Grid.is_reserved()` covers those rows as well as the portal and gate tiles, so the bots' plans skip them like any reserved tile. Building there is refused with `Placement.Result.NEAR_PORTAL` and the message "Too close to the portal". On the Causeway the band takes 11 of the 226 tiles beside the road.

On a fixed-lane map every tile off the lane is a third kind of tile beside open and blocked, `Grid.GROUND`: a tower can go there, but the flow field treats it as closed, so creeps never step onto it and a tower on it can never block or bend the route. Selling a tower returns its tile to ground, not to open. Lane tiles are refused with `Placement.Result.LANE` and the message "Keep the road clear". A Dreadlord's summons that would land on the grass appear on the Dreadlord instead.

**On screen.** `Coords.map` is the map the presentation draws, and `Game` sets it. `Coords.portal()` and `Coords.gate()` follow it, and the portal arch, the citadel gatehouse, the ramp, the road, the blight and the camera presets all follow those two. `WorldRuins` builds the broken wall and the boulders on the ruin tiles. The plateau shader paves a fixed lane with the portal apron's cobbles and a darker kerb, from a mask with one texel per tile, the same way it darkens the ground under ruins. The path preview dots follow the route, so they follow the lane, and the path preview also lays the band by the portal's red strip over the plateau.

**Picking a map.** The map picker is its own HUD panel, `src/ui/map_picker.gd`, and it stays up until wave 1. Changing the map reloads the scene with the new map and keeps the mode you chose. A map the current rules don't offer is greyed out, and its tooltip says why.

**Bots.** The bots build their mazes from wall rows on the mazing maps. On a fixed-lane map the archers, no_air and novice bots build on the tiles beside the lane, in the order the creeps pass them (`AutoplayBot.lane_plan()`), and the smart bot weighs every tile that reaches the lane or the flyers' line with its usual damage-per-gold model.

**Saving.** The best wave for each mode is saved per map. The default map keeps the save keys it had before the second map existed, so older saves still count. Causeway records are kept under keys like `causeway_normal_eletd`.

**From the command line.** `--map=rampart` works for the game, for `--autoplay`, for screenshots and benchmarks, and for `tests/bots/run_balance.gd`, and so does `--map=causeway` except for the benchmarks, which pin the classic rules. The Causeway needs the Element TD rules: the game falls back to the Citadel Plateau with a warning under `--rules=classic`, and the balance tool refuses the pair.

How the Rampart changes the balance is in [balance.md](balance.md#fallen-rampart-2026-10-02), and its rendering cost is in [perf.md](perf.md#fallen-rampart-render-load-2026-10-02-cloud). How the Causeway's creep HP was set is in [balance.md](balance.md#element-td-rules-the-fixed-lane-map-2026-10-04).
