# Architecture

This page explains how the code is organised, for anyone who wants to read it or change it. To get the project running first, see [INSTALL.md](INSTALL.md#part-2-build-from-source).

## Overview

Maze Citadel is a Godot 4.7 project written in typed GDScript. One idea shapes all of it: the rules of the game are kept apart from everything you see and hear.

The rules live in a simulation, called the sim, in `src/sim/`. It knows about tiles, towers, creeps, damage and gold, and nothing about 3D models, sound or the screen. It moves forward in fixed steps, 30 per second, and after each step it leaves a list of events describing what just happened: a tower fired, a creep died, a wave was cleared.

Everything else is presentation. The world, the units, the effects, the HUD and the audio read the sim's state and react to its events. They never change the rules.

That split pays for itself in three ways:

- **The same code runs everywhere.** The real game, the unit tests, the balance bots and the release checks all run the same sim. The tests and bots run it with no window at all.
- **Game speed is exact.** At ×2 and ×3 the game takes two or three steps per frame instead of one bigger step, so a fast game plays out the same as a slow one.
- **Looks can't break the rules.** Quality presets and visual effects have no way to change how a battle goes.

## Layers

| Layer | Folder | What it does |
|---|---|---|
| Data | `src/data/` | The tower, creep, wave and map tables, with the numbers from the [design document](GDD.md). No logic. |
| Sim | `src/sim/` | Every rule of the game. Plain `RefCounted` objects on a fixed 30 Hz step, with no nodes and no rendering. It reports through `GameSim.events` and is tested without a window. |
| Game | `src/game/game.gd` | Runs one match. It owns a single `GameSim`, steps it at the game speed times 30 Hz, works out how far the current frame sits between two steps, and emits `sim_event(e)` for each event. It also holds the public API for everything a player can do. |
| Presentation | `src/world`, `src/camera`, `src/units`, `src/fx`, `src/ui`, `src/audio` | What you see and hear. Each subsystem is one root node with a `setup(game: Game)` method. It reads sim state, listens to `game.sim_event`, and calls only the Game API or its own children. |
| Bots | `src/bots/` | `AutoplayBot` plays a `GameSim` the way a player would. The balance runs and the `--autoplay` option use it. |
| Core | `src/core/` | Shared helpers: coordinates, quality presets, the save file, command-line options, key bindings, and the benchmark and screenshot tools. |

Tests are in `tests/`, and the scripts for checking, building and measuring are in `tools/`.

## Rules the code follows

The subsystems stay independent because they all keep to a few agreements.

**Coordinates.** Sim positions are `Vector2` values in metres on the plateau, measured from its north-west corner. Convert them to 3D world positions with `Coords.to_world()` and `Coords.tile_to_world()`. The top of the plateau is `Coords.PLATEAU_TOP`. North is −Z, where the portal is, and south is +Z, where the gate is.

**Maps.** `MapDefs` lists the maps as data. The sim reads its map from its `Grid` (`grid.spawn_tiles`, `grid.goal_tiles`, `grid.spawn_point`, `grid.gate_point`, `grid.obstacles`) and never from constants. The presentation reads `Coords.map`, which `Game` sets before anything is built. Place the portal, the gate and anything tied to them from `Coords.portal()` and `Coords.gate()`, and place ruins from `game.sim.grid`. `game.change_map(id)` only works before wave 1, and it reloads the scene. There's more in [maps.md](maps.md).

**Waves.** Read a wave through `WaveDefs.spawn_list(wave, sim.rules)`, and its elements, Bulky tag and spawn gap through `WaveDefs.elements`, `WaveDefs.bulky` and `WaveDefs.spawn_interval` with the same rule set. Under the `eletd` rules the waves change shape (`EletdWaves`), and going through these keeps the sim, the HUD, the Counsel and the bots in agreement. Left out, the rule set defaults to classic.

**Smooth movement.** The sim steps 30 times a second but the screen draws more often than that, so creeps are drawn between their last two sim positions: `c.prev_pos.lerp(c.pos, game.alpha())`.

**Events.** The sim reports what happens by appending to `GameSim.events`, and `GameSim` is the place to look for nearly every `events.append({...})`; the interest lock's two come from `InterestLock`, and the element picks' from `SimElements`. The event types are `wave_started`, `wave_cleared`, `spawned`, `died`, `downed`, `revived`, `leaked`, `defeat`, `victory`, `built`, `sold`, `upgraded`, `fused`, `build_refused`, `upgrade_refused`, `path_changed`, `fired`, `hit`, `dot`, `shell_landed`, `nova`, `cloud`, `breath`, `frost_ring`, `immune`, `heal`, `summoned`, `interest`, `interest_locked`, `interest_unlocked`, `contagion`, `second_wind`, `pick_granted`, `pick_spent`, `guardian_spawned` and `element_gained`.

**Elements.** Under the `eletd` rules, `sim.elements` (`SimElements`) holds the element levels and the picks. Ask it before offering a build or an upgrade: `needs(id, level)` gives the reason a player reads ("Needs Aqua level 2"), or an empty string when nothing stands in the way, and `unlocked_towers()` lists what can be built. `pending_picks()`, `can_pick(choice)`, `level(e)`, `pending_level(e)` and `summons()` (whether the next element pick brings a Guardian) describe the picks, and `pick(sim, choice)` spends one, where a choice is an element or `&"interest"`. A refused build reports `Placement.Result.LOCKED`, and a refused upgrade sends `upgrade_refused` with its `needs` text. Under classic rules nothing is ever locked and no pick is offered. The player spends a pick through `game.pick_element(choice)`, and `game.choose_build(id)` refuses a locked tower with a `build_refused` event of its own. The HUD's words for all of this (locked reasons, the pick panel's rows, the Guardian banners) come from `ElementPicks` in `src/ui/`, which has no nodes so it can be unit-tested; the HUD builds its element strip, pick panel and the line above the cards only under `eletd`, so the classic HUD has the same nodes as before.

**Game signals.** `Game` emits `sim_event`, `build_choice_changed`, `selection_changed`, `speed_changed`, `pause_changed`, `quality_changed` and `booted`.

**Calls between subsystems.** Subsystems don't call each other, with a short list of exceptions. These are the only ones allowed:

- Effects shake the camera with `game.camera.add_shake(amount)`.
- Input and the HUD use `game.camera.screen_to_ground(pos)` and `game.camera.camera`.
- The HUD plays and adjusts sound with `game.audio.play_ui(id)`, `game.audio.set_volume(bus, linear)` and `game.audio.volume(bus)`.
- The HUD starts a fusion with `game.builder.start_fuse()` and checks on it with `game.builder.is_fusing()`.

**Quality.** To follow the quality preset, connect to `game.quality_changed` and read `Quality.settings(preset)`. Its `particles`, `crowd` and `foliage` values are scales from 0 to 1. Quality settings never change gameplay values.

**Settings.** Read and write player settings with `Save.setting(key, default)` and `Save.set_setting(key, value)`.

## Assets

Every file under `assets/` is listed in its folder's `MANIFEST.json` with one of the allowed licenses: CC0, CC-BY, OFL or generated. `tools/check_assets.py` enforces this as part of the checks, so an unlisted file fails them. The same script generates `assets/CREDITS.md` from the manifests, with the CC-BY and OFL entries that need attribution listed first.

Godot extracts the textures embedded in a model and saves them next to it as `<model>_<texture>.png`. Those files take the model's license.

## Checks

`tools/check.sh` is the one command to run before every commit. It imports the project, checks the asset licenses, runs `gdlint` and `gdformat`, runs the unit tests, and plays a short game with no window.

The balance table comes from `godot --headless --path . --script res://tests/bots/run_balance.gd`. What the bots found is written up in [balance.md](balance.md).

The tools that open a game window, `capture.sh` and `bench.sh`, refuse to run unless `ALLOW_WINDOW=1` is set. They take over the screen, so they only run when someone has set time aside for them.
