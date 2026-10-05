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
| Data | `src/data/` | The tower, creep, wave and map tables, with the numbers from the [design document](GDD.md), and the Element TD rules' own numbers in `EletdRules` and wave shapes in `EletdWaves`. Next to no logic. |
| Sim | `src/sim/` | Every rule of the game. Plain `RefCounted` objects on a fixed 30 Hz step, with no nodes and no rendering. It reports through `GameSim.events` and is tested without a window. |
| Game | `src/game/game.gd` | Runs one match. It owns a single `GameSim`, steps it at the game speed times 30 Hz, works out how far the current frame sits between two steps, and emits `sim_event(e)` for each event. It also holds the public API for everything a player can do. |
| Presentation | `src/world`, `src/camera`, `src/units`, `src/fx`, `src/ui`, `src/audio` | What you see and hear. Each subsystem is one root node with a `setup(game: Game)` method. It reads sim state, listens to `game.sim_event`, and calls only the Game API or its own children. |
| Bots | `src/bots/` | `AutoplayBot` plays a `GameSim` the way a player would. Under the Element TD rules its smart strategy hands over to `RouteLiner`, which prices every build, upgrade, fusion and element pick by the damage it adds to the creeps in the wave preview. The balance runs and the `--autoplay` option use them. `Replayer` plays a recorded game (`PlayLog`, in `src/core/`) again from its actions. |
| Core | `src/core/` | Shared helpers: coordinates, quality presets, the save file, command-line options, key bindings, and the benchmark and screenshot tools. |

Tests are in `tests/`, and the scripts for checking, building and measuring are in `tools/`.

## Rules the code follows

The subsystems stay independent because they all keep to a few agreements.

**Coordinates.** Sim positions are `Vector2` values in metres on the plateau, measured from its north-west corner. Convert them to 3D world positions with `Coords.to_world()` and `Coords.tile_to_world()`. The top of the plateau is `Coords.PLATEAU_TOP`. North is −Z, where the portal is, and south is +Z, where the gate is.

**Rule sets.** The sim plays one of two rule sets, `GameSim.rules`: `&"eletd"`, the Element TD rules, or `&"classic"`, the game as released in 0.3.1. `GameSim` itself defaults to classic, so tests and tools that build a bare sim get the released game; `Game` starts a match under `Game.DEFAULT_RULES`, which is `&"eletd"`, unless the player last picked classic or `--rules` says otherwise. Set the rules before wave 1. The Element TD numbers live in `EletdRules` and its wave shapes in `EletdWaves`, the interest lock in `InterestLock` and the element picks in `SimElements`; each checks the rule set itself, and classic code paths read the same numbers they always did, so classic play doesn't change. `EletdRules.difficulties(rules)` lists the difficulties a rule set offers. The player switches rules through `game.change_rules(rules)`, which works only before wave 1, rebuilds the board like `change_map`, and is remembered. `game.set_mode(difficulty, infinite, twists)` saves the mode as settings too, and `Game.choose_mode` reads it back on the next launch. `game.play_again()` reloads the scene with the same map, rules and mode; `game.change_setup()`, behind the pause menu's New game setup and the end screen's Change setup, does the same and sets `SetupPanel.pending`, so the new match opens on the setup panel. That panel holds only `game.paused` until Start and sets the mode through `set_mode`, so the sim, the records and the replays never see it. `game.quit()` saves the record and quits. All three reloads hand their setup to the next `Game` in `Game._carry`, which beats the command line and the saved settings. Records are saved per rule set (`Save.mode_key`).

**Maps.** `MapDefs` lists the maps as data. The sim reads its map from its `Grid` (`grid.spawn_tiles`, `grid.goal_tiles`, `grid.spawn_point`, `grid.gate_point`, `grid.obstacles`, and `grid.lane` on a fixed-lane map) and never from constants. Some maps are offered under some rule sets only; ask `MapDefs.offered(map, rules)`. The presentation reads `Coords.map`, which `Game` sets before anything is built. Place the portal, the gate and anything tied to them from `Coords.portal()` and `Coords.gate()`, and place ruins from `game.sim.grid`. `game.change_map(id)` only works before wave 1, and it reloads the scene. On a fixed-lane map the grid has a third tile kind beside open and blocked, `Grid.GROUND`: a tower can stand on it but the flow field treats it as closed, so creeps keep to the lane and no build can block or bend the route. There's more in [maps.md](maps.md).

**Waves.** Read a wave through `WaveDefs.spawn_list(wave, sim.rules)`, and its elements, Bulky tag and spawn gap through `WaveDefs.elements`, `WaveDefs.bulky` and `WaveDefs.spawn_interval` with the same rule set. Under the `eletd` rules the waves change shape (`EletdWaves`), and going through these keeps the sim, the HUD, the Counsel and the bots in agreement. Left out, the rule set defaults to classic.

**Smooth movement.** The sim steps 30 times a second but the screen draws more often than that, so creeps are drawn between their last two sim positions: `c.prev_pos.lerp(c.pos, game.alpha())`.

**Events.** The sim reports what happens by appending to `GameSim.events`, and `GameSim` is the place to look for nearly every `events.append({...})`; the interest lock's two come from `InterestLock`, and the element picks' from `SimElements`. The event types are `wave_started`, `wave_cleared`, `spawned`, `died`, `downed`, `revived`, `leaked`, `defeat`, `victory`, `built`, `sold`, `upgraded`, `fused`, `build_refused`, `upgrade_refused`, `path_changed`, `fired`, `hit`, `dot`, `shell_landed`, `nova`, `cloud`, `breath`, `frost_ring`, `immune`, `heal`, `summoned`, `interest`, `interest_locked`, `interest_unlocked`, `contagion`, `second_wind`, `pick_granted`, `pick_spent`, `guardian_spawned` and `element_gained`.

**Elements.** Under the `eletd` rules, `sim.elements` (`SimElements`) holds the element levels and the picks. Ask it before offering a build or an upgrade: `needs(id, level)` gives the reason a player reads ("Needs Aqua level 2"), or an empty string when nothing stands in the way, and `unlocked_towers()` lists what can be built. `pending_picks()`, `can_pick(choice)`, `level(e)`, `pending_level(e)` and `summons()` (whether the next element pick brings a Guardian) describe the picks, and `pick(sim, choice)` spends one, where a choice is an element or `&"interest"`. A refused build reports `Placement.Result.LOCKED`, and a refused upgrade sends `upgrade_refused` with its `needs` text. Under classic rules nothing is ever locked and no pick is offered. The player spends a pick through `game.pick_element(choice)`, and `game.choose_build(id)` refuses a locked tower with a `build_refused` event of its own. The HUD's words for all of this (locked reasons, the pick panel's rows, the Guardian banners, the reminders of unspent picks and of gold past the interest cap) come from `ElementPicks` in `src/ui/`, which has no nodes so it can be unit-tested, and `HudNotices` decides when the line above the cards teaches one of these rules; the HUD builds its element strip, pick panel and the line above the cards only under `eletd`, so the classic HUD has the same nodes as before.

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

`tools/check.sh` is the one command to run before every commit. It imports the project, checks the asset licenses, runs `gdlint` and `gdformat`, runs the unit tests, and plays short games with no window: the Citadel and the Rampart under both rule sets, and the Causeway under the Element TD rules.

The balance table comes from `godot --headless --path . --script res://tests/bots/run_balance.gd`, which plays the Element TD rules unless given `-- --rules=classic`. What the bots found is written up in [balance.md](balance.md). `tests/bots/replay.gd` replays the records the game writes of each player's game ([playtests.md](playtests.md)).

The tools that open a game window, `capture.sh` and `bench.sh`, refuse to run unless `ALLOW_WINDOW=1` is set. They take over the screen, so they only run when someone has set time aside for them.
