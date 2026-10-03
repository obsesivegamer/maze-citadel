# Maps

Every map is the same 20 × 28 tile plateau (40 × 56 m) inside the same valley. Maps differ in where the portal and gate open on the north and south edges, and in ruins that block tiles from the start. The map is picked before wave 1, like the mode, and the last pick is remembered.

| Map | Portal | Gate | Ruins | How it plays |
|---|---|---|---|---|
| **Citadel Plateau** (default) | columns 9–10 | columns 9–10 | none | Open board, straight 28-tile start path. Serpentine walls across the full width. |
| **Fallen Rampart** | columns 5–6 | columns 13–14 | a broken wall across row 13 with three 2-tile breaches (columns 1–2, 9–10, 17–18); two 2 × 2 boulder heaps at (12, 5) and (6, 19) | The wall splits the board into a north and a south maze joined only at the breaches. Plug two breaches and every creep funnels through the third: a natural kill zone for splash and frost. Which breach you leave open decides how the two halves join. Flyers cross diagonally, portal to gate. |

Tiles are (column, row); row 0 is the portal (north) edge. The anti-block rule still holds: at least one breach always stays open.

## Code

- `src/data/map_defs.gd`: the map table (name, blurb, portal and gate columns, ruins).
- `Grid.new(map)`: spawn and goal tiles, spawn and gate points and the ruin tiles are per grid; ruins start blocked. `GameSim.new(map)` passes it through.
- `Placement.Result.OBSTACLE`: building on ruins is refused with "Ruins block this tile".
- `Coords.map` is the map the presentation draws (set by `Game`); `Coords.portal()` / `Coords.gate()` follow it, and the portal arch, citadel gatehouse, ramp, road, blight and camera presets follow those.
- `WorldRuins` builds the broken wall and boulders on the ruin tiles.
- The map picker is its own HUD panel (`src/ui/map_picker.gd`), shown until wave 1. Changing map reloads the scene with the new map and keeps the chosen mode.
- Best wave per mode is saved per map (the default map keeps its old keys).
- `--map=rampart` works for the game, `--autoplay`, captures, benchmarks and `tests/bots/run_balance.gd`.

## Resume here (handoff notes)

Work happens on branch `claude/second-map-sik2ej`, PR #5 "Second map: Fallen Rampart". Each step is pushed when it lands.

1. [x] Map table + map-aware sim (Grid, FlowField, Placement, GameSim), tests (`tests/unit/test_maps.gd`)
2. [x] Map picker before wave 1, per-map save keys (`Save.sim_key`), `--map` flag
3. [x] Presentation follows the map: portal, gate, ramp, road, blight, camera presets
4. [x] Ruins visuals (`WorldRuins`) and trodden dirt under ruins on the plateau
5. [x] Bot wall plan for the Rampart; balance runs on both maps ([balance.md](balance.md))
6. [x] Draw calls and triangles of the wave-24 battle on the Rampart vs the Citadel ([perf.md](perf.md)); a frame-time bench on the M3 Air is still to do
7. [x] GDD, README, ARCHITECTURE updated; `tools/check.sh` green (it now smoke-tests the Rampart too)

**Merging with the Epics + Twists branch (PR #7):** done in PR #7's branch (2026-10-03), as described here. Both add a third argument to `Save.mode_key` and a `Save.sim_key(sim)`; combine them as `mode_key(hard, infinite, twists, map)` with `sim_key` passing all four, and insert `false` as the third argument in the two `mode_key` calls in `tests/unit/test_maps.gd` that pass a map. `Game.change_map` carries `hard` and `infinite` across the reload in `_carry`; carry `twists` and `twist_seed` too. `run_balance.gd` and `GameSim._spawn` conflict on neighbouring lines; keep both changes.
