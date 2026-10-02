# Architecture

## Layers

| Layer | Folder | Rule |
|---|---|---|
| Data | `src/data/` | Tower, creep and wave tables (GDD numbers). No logic. |
| Sim | `src/sim/` | All rules. Pure RefCounted, fixed 30 Hz step, no nodes, no rendering. Reports through `GameSim.events`. Tested headless. |
| Game | `src/game/game.gd` | Owns one `GameSim`, steps it (`speed` × 30 Hz), interpolates, emits `sim_event(e)`. Public API for player actions. |
| Presentation | `src/world`, `src/camera`, `src/units`, `src/fx`, `src/ui`, `src/audio` | Each subsystem is one root node with `setup(game: Game)`. Reads sim state, listens to `game.sim_event`, calls only the Game API or its own children. |
| Bots | `src/bots/` | `AutoplayBot` plays a GameSim like a player (balance runs, `--autoplay`). |

## Contracts

- **Coordinates:** sim positions are `Vector2` metres on the plateau (origin north-west corner). Convert with `Coords.to_world()` / `Coords.tile_to_world()`. Plateau top is `Coords.PLATEAU_TOP`; north is −Z (portal), south is +Z (gate).
- **Maps:** `MapDefs` (data) lists the maps. The sim reads the map from its `Grid` (`grid.spawn_tiles`, `grid.goal_tiles`, `grid.spawn_point`, `grid.gate_point`, `grid.obstacles`), never from constants. The presentation reads `Coords.map`, set by `Game` before anything is built: place the portal, gate and anything tied to them from `Coords.portal()` / `Coords.gate()`, and ruins from `game.sim.grid`. `game.change_map(id)` works only before wave 1 and reloads the scene.
- **Interpolation:** draw creeps at `c.prev_pos.lerp(c.pos, game.alpha())`.
- **Events:** see `GameSim` for every `events.append({...})`. Types: `wave_started, wave_cleared, spawned, died, downed, revived, leaked, defeat, victory, built, sold, upgraded, fused, build_refused, path_changed, fired, hit, dot, shell_landed, nova, cloud, breath, frost_ring, immune, heal, summoned, interest`.
- **Game signals:** `sim_event, build_choice_changed, selection_changed, speed_changed, pause_changed, quality_changed`.
- **Cross-subsystem calls** (the only ones allowed): `game.camera.add_shake(amount)` from Fx; `game.camera.screen_to_ground(pos)` / `game.camera.camera` from input and HUD; `game.audio.play_ui(id)`, `game.audio.set_volume(bus, linear)`, `game.audio.volume(bus)` from HUD; `game.builder.start_fuse()` / `game.builder.is_fusing()` from HUD.
- **Quality:** connect to `game.quality_changed` and read `Quality.settings(preset)` (`particles`, `crowd`, `foliage` scale 0..1). Never change gameplay values.
- **Settings:** `Save.setting(key, default)` / `Save.set_setting(key, value)`.

## Assets

- Every file under `assets/` is listed in that folder's `MANIFEST.json` with an allowed license (CC0, CC-BY, OFL, generated); `tools/check_assets.py` enforces it in the gate. CC-BY and OFL entries show up in `assets/CREDITS.md`.
- Godot extracts a model's embedded textures next to it (`<model>_<texture>.png`); they inherit its license.

## Checks

- `tools/check.sh`: import, asset licenses, gdlint, gdformat, unit tests, headless smoke game. Run before every commit.
- `godot --headless --path . --script res://tests/bots/run_balance.gd`: balance table.
- Window-opening tools (`capture.sh`, `bench.sh`) need `ALLOW_WINDOW=1` and only run in agreed screen slots.
