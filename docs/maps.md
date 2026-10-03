# Maps

Maze Citadel has two maps. This page describes how each one plays and how a map is put together in the code.

## Overview

Every map uses the same plateau, 20 tiles wide and 28 tiles long (40 × 56 m), in the same valley. What changes from map to map is where the portal and the gate open on the north and south edges, and whether ruins block some tiles from the start.

You pick the map before wave 1, the same way you pick the mode, and the game remembers your last choice.

| Map | Portal | Gate | Ruins | How it plays |
|---|---|---|---|---|
| **Citadel Plateau** (default) | columns 9–10 | columns 9–10 | none | An open board with a straight 28-tile road to begin with. You build serpentine walls across the full width. |
| **Fallen Rampart** | columns 5–6 | columns 13–14 | a broken wall across row 13 with three 2-tile breaches (columns 1–2, 9–10, 17–18), and two 2 × 2 boulder heaps at (12, 5) and (6, 19) | The wall splits the board into a north maze and a south maze, joined only at the breaches. Plug two breaches and every creep funnels through the third, which makes a natural kill zone for splash and frost towers. Which breach you leave open decides how the two halves connect. Flyers ignore all of it and cross diagonally from portal to gate. |

Tiles are written as (column, row), and row 0 is the portal edge on the north side. The rule against blocking the road still applies on the Rampart, so at least one breach always stays open.

## How a map works in the code

The map table is `src/data/map_defs.gd`. Each entry has a name, a short description, the portal and gate columns, and any ruins.

**In the sim.** `Grid.new(map)` sets up everything that depends on the map: the spawn and goal tiles, the spawn and gate points, and the ruin tiles, which start out blocked. `GameSim.new(map)` passes the map through to its grid. Building on ruins is refused with `Placement.Result.OBSTACLE` and the message "Ruins block this tile".

**On screen.** `Coords.map` is the map the presentation draws, and `Game` sets it. `Coords.portal()` and `Coords.gate()` follow it, and the portal arch, the citadel gatehouse, the ramp, the road, the blight and the camera presets all follow those two. `WorldRuins` builds the broken wall and the boulders on the ruin tiles.

**Picking a map.** The map picker is its own HUD panel, `src/ui/map_picker.gd`, and it stays up until wave 1. Changing the map reloads the scene with the new map and keeps the mode you chose.

**Saving.** The best wave for each mode is saved per map. The default map keeps the save keys it had before the second map existed, so older saves still count.

**From the command line.** `--map=rampart` works for the game, for `--autoplay`, for screenshots and benchmarks, and for `tests/bots/run_balance.gd`.

How the Rampart changes the balance is in [balance.md](balance.md#fallen-rampart-2026-10-02), and its rendering cost is in [perf.md](perf.md#fallen-rampart-render-load-2026-10-02-cloud).
