# Maze Citadel

A single-player maze tower defense in the spirit of Warcraft III custom maps (Element TD, Gem TD, Wintermaul One). Wall the plateau with towers to stretch the creeps' path from the red demon portal to the blue town gate, then survive 40 waves. Built with Godot 4.7 for Apple Silicon Macs.

**Status:** playable end to end; first on-screen review done, performance tuning next. See [docs/PLAN.md](docs/PLAN.md).

## Run it

1. Build or download `MazeCitadel-<version>.dmg`, open it, and drag **Maze Citadel** to Applications (or run it from the disk image).
2. Double-click it. The game opens straight into the citadel with the builder ready.
3. A copy downloaded from GitHub shows macOS's "unidentified developer" prompt once: right-click the app → **Open**. The app is ad-hoc signed, not notarized.

Tested on a MacBook Air 13" M3 (8-core GPU, 16 GB), macOS 26.6.2. Apple Silicon only; macOS 13 or later.

## Play

- **Build:** pick a tower card (or `1`–`0`) and click a tile. `Shift`+click keeps placing. A red ghost means the spot would block the path; the game never lets you seal the portal off from the gate.
- **Manage:** click a tower for its plaque: `U` upgrade (two levels), `X` or right-click sell for 75%, `G` fuse two level-3 towers of one family into its Epic (Frost Wyrm, Doom Cannon, Sunfire Ballista, Plague Necropolis).
- **Waves:** they start on a timer; `N` calls the next one early. `Space` pauses, `F` cycles ×1/×2/×3.
- **Camera:** WASD/arrows or two-finger drag to pan, scroll or pinch to zoom, middle-drag or Option-drag to orbit, `Q`/`E` rotate, `R` reset, `C` cycle portal/gate views, `B` follow the boss.
- **Counters:** every wave carries an armor class and an element. Pierce beats Light armor and Air, Siege beats Armored, Poison ignores armor; each element deals double damage to the next one in Light → Dark → Aqua → Flame → Verdant → Stone → Light. The banner before each wave tells you what's coming.
- **Lives:** 20. A leak costs 1 (boss 2), and the creep loops back to the portal for another pass with no bounty. Clear wave 40 to win; Hard and Infinite modes are on the top bar before wave 1. Your best wave per mode is saved.

## Develop

Needs Godot 4.7.2 (`brew install --cask godot`), its macOS export templates, `git-lfs`, and `gdtoolkit` (`pipx install gdtoolkit`).

| Command | What it does |
|---|---|
| `tools/check.sh` | The gate: import, asset licenses, lint, format, unit tests, headless game smoke run |
| `tools/smoke.sh 18000` | The autoplay bot plays ~20 waves headless |
| `godot --headless --path . --script res://tests/bots/run_balance.gd` | Balance table ([docs/balance.md](docs/balance.md)) |
| `tools/export.sh` | `dist/MazeCitadel.app` and `.dmg` (arm64, ad-hoc signed) |
| `ALLOW_WINDOW=1 tools/slot.sh` | Captures, benchmarks and launch check; opens windows |

Design: [docs/GDD.md](docs/GDD.md) · Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · Performance: [docs/perf.md](docs/perf.md)

## Credits

Models and textures are CC0 (Quaternius, KayKit, Kenney and OpenGameArt artists); sound is CC0 and CC-BY; fonts (Cinzel, Fira Sans) are OFL. Full list with attribution: [assets/CREDITS.md](assets/CREDITS.md).
