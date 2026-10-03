# Maze Citadel — Build Plan

This is the plan the game was built from. It was written on 2026-10-01, before any code existed, and its checklists were updated as the work landed. It's kept as a record of what was decided and why. It is no longer the place to look for the current state of the game.

For that, use these instead:

- What the game is and how to install it: the [README](../README.md) and [INSTALL.md](INSTALL.md).
- What has shipped: the [release notes](https://github.com/obsesivegamer/maze-citadel/releases).
- The rules and numbers as they are now: [GDD.md](GDD.md).

## Where things stand (2026-10-03)

Version 0.2.0 is out. It has the full game described below, plus things that were added along the way: a second map, all four Epics, Twists mode, the tutorial and Field Guide, and the [website](https://obsesivegamer.github.io/maze-citadel/). The performance work for the default Balanced preset is done, and it now runs at 60 fps in heavy battles on the M3 MacBook Air ([perf.md](perf.md)).

Some details changed after the plan was written. The repository is public now, not private. The download is `MazeCitadel-<version>.dmg` from the website, not a file in `dist/`.

Still open:

1. Long sessions of late waves on a warm MacBook Air average about 57 fps on Balanced. The next step is to render the 3D view at the display's own resolution ([perf.md](perf.md#next)).
2. The plan's last milestones: M7, the final pass on effects and sound, and M9, the 1.0 release.
3. Removing the performance experiment switches that weren't adopted. Some of them, such as `--pf-hud-lite`, are still in the code.

Not every checkbox below was kept up to date, so an unticked box doesn't always mean the work is missing. The board in M3 and the quality presets in M8 are unticked, for example, and both are in the game.

---

## 1. The game in one paragraph

A single-player maze tower defense in the spirit of Warcraft III custom maps. You open straight into a finished 3D citadel: red demon portal in the north, blue town gate in the south, a buildable plateau in between. You wall the plateau with towers to force creeps down a long winding path. You can never fully block it. Forty waves of orcs, wolves, harpies, ghouls, steam tanks and ogre bosses end with a Dreadlord. Fourteen towers in four families (Alliance, Horde, Elven, Forsaken) plus support. Depth comes from three layers: where you place towers (maze length), attack type vs armor class, and a six-element counter wheel.

## 2. Technology

**Decision: Godot 4.7.2 (latest stable, released 2026-08-18), Forward+ renderer on native Metal, typed GDScript.**

| Option | Verdict |
|---|---|
| **Godot 4.7** | **Chosen.** Real-time GI, volumetric fog, SSR, decals, GPU particles and HDR output are built in. Everything is text and code, so every change can be written, tested headless and captured to screenshots without an editor. Exports a macOS `.app` / `.dmg` in one command. |
| Unreal 5 / Unity | Best raw fidelity, but content is built in a GUI editor. Builds can't be driven or checked reliably from the command line. |
| Three.js WebGPU + Electron | Fastest iteration (the Tower of Babel stack). Every effect (GI, fog volumes, decals, shadow quality) would be hand-built, and it ends at lower fidelity. |
| Bevy (Rust) | Good renderer, but the engine API changes each release, compiles are slow, and the UI tooling is thin. |
| Swift + RealityKit / Metal | Native and fast, but a custom renderer would cost more time than it buys in quality. |

**What Godot gives up:** no hardware ray tracing on Metal. Reflections and GI use SDFGI, SSIL and SSR instead. The spec says "where viable"; on this stack it isn't.

**Requirement → feature map**

| Spec | Godot feature |
|---|---|
| PBR, soft shadows | StandardMaterial3D / custom toon-PBR shader, soft directional shadows |
| GI, "ray-traced where viable" | SDFGI (Cinematic), SSIL (Balanced), reflection probes |
| Volumetrics | Volumetric fog + FogVolume (portal plume, valley haze) |
| HDR color | HDR rendering, AgX tonemap, HDR display output (new in 4.7, supported on macOS) |
| Craters | Decal nodes |
| Juice | GPUParticles3D (4.7 adds per-particle scale and rotation), pooled projectiles |
| Crowds and foliage | MultiMesh, LOD |
| Upscaling | FSR 2.2; MetalFX if 4.7 exposes it (checked in M1) |

## 3. How you'll install and run it

This is the install plan as written on 2026-10-01. The current instructions are in [INSTALL.md](INSTALL.md).

1. Open `dist/MazeCitadel.dmg` (or `dist/MazeCitadel.app` directly).
2. Drag it to Applications, or skip that step.
3. Double-click. The citadel loads straight into the build phase.

**Details:**
- **Apple Silicon (arm64) build**, all assets packed inside the app, no installs, no terminal.
- **Signing:** the build is ad-hoc signed. A build made on this Mac opens with a double-click.
- **Downloaded from GitHub:** a `.dmg` downloaded from a GitHub Release gets macOS's "unidentified developer" prompt once (right-click → Open). Accepted: no notarization (decision 3).
- **Every milestone from M1 on** publishes the `.dmg` to a GitHub Release, so the one-click build is proven continuously, not just at the end.

## 4. Requirements

### 4.1 Target and test machine

| | |
|---|---|
| Tested on | MacBook Air 13" M3 (Mac15,12), 8-core CPU, 8-core GPU, 16 GB, macOS 26.6.2 (25G83), 2560 × 1664 Retina |
| Supported | Apple Silicon Macs on recent macOS (exact minimum confirmed in M1) |
| Intel | Not built. The app targets this M3 only (decision 8). |

This is the entry-level M3 GPU in a fanless laptop. Performance is measured here, including a 10-minute soak to catch thermal throttling.

### 4.2 Performance targets

| Preset | Target |
|---|---|
| Balanced (default) | 60 fps average, 1% low ≥ 50, during the full 24-creep splash wave |
| Performance | 60 fps with headroom |
| Cinematic | Best effort, measured and reported honestly |
| Time to first frame | Under 5 s (shaders precompiled at export) |

### 4.3 Dev toolchain (on this Mac only; the player installs nothing)

- Godot 4.7.2 (Homebrew cask) + macOS export templates 4.7.2
- git-lfs for models, textures and audio
- `gh` (already signed in as `obsesivegamer`), Python 3 for asset scripts, `gdtoolkit` for GDScript lint and format

### 4.4 Assets and licensing

- Hive Workshop and WC3 maps are **style references only**. Their models are built for Warcraft III and mostly derive from Blizzard art, so they can't ship in a standalone game.
- Shipped art is **CC0** (free for any use): Quaternius (animated monsters, animals, nature), KayKit (characters, skeletons, medieval buildings), Kenney (castle, nature, tower defense kits, audio packs). All three sources were reachable on 2026-10-01.
- A custom stylized shader gives them a WC3 look: saturated colors, chunky rim light, team-color masks.
- Anything without a CC0 model gets built procedurally in code. Likely gaps: Steam Tank, gryphon, portal.
- `assets/CREDITS.md` lists every file's source and license. A check script fails the build if any asset is unlisted.

## 5. Architecture

```
project.godot
src/
  sim/      grid, flow field, anti-block, damage model, economy, waves   ← pure logic, fixed 30 Hz, headless-testable
  board/    terrain, plateau, portal, gate, walls, village
  towers/   tower base + one folder per family
  creeps/   creep base + one script per type
  fx/       pooled projectiles, particles, decals, damage numbers
  ui/       HUD, cards, announce banner, end screens
  camera/   RTS rig, presets, boss tracking
  world/    ambient life (wind, clouds, watermill, villagers, gryphons)
  audio/    event → sound mapping, music state, buses
data/       towers, creeps, waves, damage tables (Godot Resources)
assets/     models, textures, audio, fonts + CREDITS.md
tests/      unit tests + scripted scenarios
tools/      check.sh · capture.sh · bench.sh · export.sh · sim.sh
docs/       PLAN.md · GDD.md · balance.md · perf.md · screens/
```

- **Sim and presentation are separate.** The sim owns all rules and runs without rendering. Nodes only display it. The same code powers tests, balance bots and the game, and ×2/×3 speed stays exact.
- **Data-driven.** Towers, creeps and waves are tables, so balance changes don't touch code.

## 6. How the work gets validated

| Check | When | What it proves |
|---|---|---|
| `tools/check.sh` (the repo gate) | Before every commit | Project imports clean, lint passes, unit tests pass, a headless 40-wave smoke run finishes |
| Screenshot capture | Every milestone | Scripted camera shots rendered by Godot's Movie Maker. Reviewed against the milestone checklist; the best go in `docs/screens/`. |
| Balance bots | M6 onward | Headless bots play all 40 waves with different strategies. Results go to `docs/balance.md`. |
| Performance bench | M5 spot check, M8 onward | The 24-creep splash wave, 10-minute soak, per preset. Results go to `docs/perf.md`. |
| One-click smoke test | M1, M3, M6, M9 | Double-click the exported `.app` and play with real clicks via computer use: place, upgrade, sell, pause, speed. |
| Independent review | M3, M6, M9 | Up to 4 review agents (code + visuals) that don't share the builder's framing. Findings are fixed before the tag. |

**Parallel work:** where a milestone splits cleanly (asset sourcing, tower families, juice/world/audio), up to **4 workers** run in separate git worktrees, each owning its own files. One integrator merges and runs the gate.

## 7. Milestones

Every milestone ends with: gate green → commit(s) pushed → tag `mN` → (M1+) GitHub pre-release with the `.dmg`. Commits land per logical change throughout, not just at the end. Estimates are agent working time.

### M0 — Plan ✅
- [x] `docs/PLAN.md`, `docs/GDD.md`, README, private GitHub repo `maze-citadel`
- **Gate:** you approve the plan

### M1 — Toolchain and delivery spike (≈1.5 h)
- [x] Install Godot 4.7.2, export templates, git-lfs, gdtoolkit
- [x] Project skeleton, Forward+ on Metal
- [x] Test scene: terrain, sun, sky, SDFGI, volumetric fog, decals, particles, MultiMesh pines, 24 moving creeps
- [x] `tools/` scripts: check, capture, bench, export (arm64 `.app` + `.dmg`, 91 MB / 43 MB)
- [x] Confirmed: Metal driver, MetalFX temporal + spatial, HDR output API, macOS 13+ minimum; exported app boots headless
- [x] First Balanced ablation ([perf.md](perf.md)): SSIL dropped from Balanced, MetalFX chosen over FSR2
- [x] Screen slot 1: all presets benchmarked uncapped, launch via `open` (double-click path) works
- [ ] Shader precompile at export: not verified (headless export may skip the shader baker)
- **Gate:** check green · capture reviewed · exported app opens by double-click · test-scene fps logged per preset

### M2 — Art and audio sourcing (≈2–3 h · 4 workers: creeps / towers+props / environment / audio)
- [x] Download free packs (CC0, plus CC-BY audio with credits): 17 characters, 526 environment models, 47 textures, 137 sounds (85 MB)
- [x] `tools/check_assets.py` license gate in `check.sh`; `assets/CREDITS.md` generated
- [x] Headless import clean (775 files, 0 warnings); music and ambience loop
- [ ] Stylized WC3 material: saturated toon-PBR, rim light, team-color mask, distance outline for creeps
- [ ] Gallery scene: every creep with walk/hit/death, tower parts, props, under final lighting
- [x] Gap list: Steam Tank → mech + steam FX; Gryphon → scaled eagle; Wolf Rider → orc on wolf; Felhound → fel-tinted wolf; no free medieval horn or spoken "wave" (uses "Round")
- **Gate:** gallery capture reviewed · license check passes with zero unlisted files

### M3 — The citadel, first frame (≈3–4 h)
- [ ] Board: plateau, cliffs, outer walls, banners, pines, red portal (volumetric), blue gate, village, river, watermill (world worker)
- [x] RTS camera: damped orbit/pan/zoom, trackpad gestures, presets, `R` hero view, boss tracking
- [x] HUD shell: gold 220, lives 20, wave preview, 12 cards, builder selected at launch (styling: UI worker)
- [x] Dotted path portal → gate, redrawn live
- **Gate:** app opens directly into this frame · first frame under 5 s · preset screenshots match the GDD §1 checklist · Balanced ≥ 60 fps · **independent review #1**

### M4 — Mazing core (≈2–3 h)
- [x] Grid, flow field, anti-block (sim side, `src/sim/`)
- [x] Green/red ghost with refusal wobble + thunk sound (dust: FX worker)
- [x] Sell for 75% (sim side)
- [x] `X` / right-click sell, live dotted-path redraw
- [x] Fixed-step 30 Hz sim (×1/×2/×3 = steps per frame)
- [x] Speed ×1/×2/×3 and pause
- [x] Grunts walk the maze and reroute; leaks cost lives and loop back; defeat at 0 lives (sim side)
- [x] Horn and defeat screen with stats (gate flash: world worker)
- [x] Tests: flow field, anti-block (creep-occupied tiles, diagonal squeeze, trapping), refunds, leak loop, 1,000-placement fuzz
- **Gate:** tests green · scripted "8-archer zig-zag" scenario captured

### M5 — Towers and damage (≈4–5 h · 4 workers, one per family)
- [x] Tower data tables, L1→L3 upgrades, targeting, projectiles (sim)
- [x] Damage model: attack × armor class × element wheel × armor/shred × aura (tested cell by cell)
- [x] Bard aura, Runesmith shred, all tower kinds (sim); [ ] distinct models and attack FX (units worker)
- [x] Epic fusion: Frost Wyrm, Doom Cannon (sim + input); stretch Epics Sunfire Ballista and Plague Necropolis added 2026-10-02
- [x] Range ring only on ghost/hover/select; colored damage numbers
- **Gate:** a unit test for every damage-table cell · tower showcase capture · 30 towers vs 24 creeps ≥ 60 fps Balanced

### M6 — Creeps, 40 waves, economy, modes (≈3–4 h)
- [x] 9 creep types + Felhound summons with their mechanics (sim); [ ] models and HP bars (units worker)
- [x] 40-wave table, Infinite generator, 3 s announcement (class, element, skull)
- [x] Bounty 6–22, interest 2% per 15 s capped at 20, Normal/Hard/Infinite
- [x] Victory/defeat screens, score, best-wave save
- [x] Balance bots: smart mazer, archer-spam (no counters), no-anti-air ([balance.md](balance.md))
- **Gate:** smart bot clears Normal with ≥ 10 lives · no-anti-air bot dies at the Harpy waves · Hard is beatable but tight · mechanic tests (revive, immune, heal, aura, summons, interest cap) · **independent review #2** · tagged "feature complete"

### M7 — Juice, world life, audio (≈4–5 h · 4 workers: VFX / world / audio / UI polish)
- [ ] Every combat effect and ambient-life item in GDD §12
- [ ] Full audio: SFX per event, announcer, 3 music states, ambience, mixer + settings
- [ ] No-placeholder audit: every tower, creep and event has a model, animation, effect and sound
- **Gate:** capture reel (frames → video) reviewed · audit passes with zero gaps

### M8 — Fidelity and performance (≈2–3 h)
- [ ] Cinematic / Balanced / Performance selector wired to GDD §14
- [ ] HDR output, precompiled shaders, MultiMesh foliage, FX pooling, LOD
- [ ] Bench: 24-creep splash wave with 30 towers, 10-minute soak per preset
- **Gate:** Balanced meets §4.2 targets on the M3 Air · numbers in `docs/perf.md`

### M9 — Release v1.0 (≈1–2 h)
- [ ] App icon, version, README (how to run, controls, tested hardware), credits screen
- [ ] Bot plays to wave 40 at ×3 inside the exported app; 30-minute crash-free soak
- [ ] Computer-use smoke test of every control on the `.dmg` build
- **Gate:** all of the above · **independent review #3** · GitHub Release `v1.0.0`

**Total:** ≈ 23–31 agent hours across several sessions. The board state lives in this file: each milestone's boxes get checked as they land.

## 7a. Screen-time slots

Captures and benchmarks open a game window, and benchmarks need it frontmost: macOS throttles background windows, which makes their numbers meaningless. Jeremy uses this Mac, so all windowed work is batched into slots he hands over. `tools/capture.sh` and `tools/bench.sh` refuse to run without `ALLOW_WINDOW=1`.

| Slot | When | Length | What runs |
|---|---|---|---|
| A | Now (finishes M1) | 20 min | 3 presets, uncapped headroom, upscaler check, double-click launch of the `.dmg` |
| B | End of M3 | 25 min | First-frame captures from every preset camera, Balanced fps, launch test |
| C | End of M5 | 20 min | Tower showcase capture, 30 towers vs 24 creeps bench |
| D | M8 | 45 min | 10-minute thermal soak per preset, final tuning reruns |
| E | M9 | 30 min | Bot plays to wave 40 at ×3 in the exported app, computer-use smoke test of every control |

Between slots, all work is headless: logic, tests, balance bots, asset import, export.

## 8. Risks

| Risk | Plan |
|---|---|
| CC0 packs miss WC3-specific units (Steam Tank, gryphon, Dreadlord) | Gap list in M2; build missing ones procedurally; nothing ships as a placeholder |
| Fanless M3 Air throttles under sustained load | Balanced is the default; upscaling; 10-minute soak in the bench |
| Godot 4.7 APIs are newer than the coding agent's training data | M1 spike exercises every engine feature we rely on, checked against docs.godotengine.org/en/4.7 |
| The coding agent can't hear the audio | Automated checks: every event maps to a file, loudness normalized by script; you do one listening pass at M7 |
| Parallel workers collide | Each worker owns separate files in its own worktree; one integrator merges and runs the gate |

## 9. Decisions (confirmed 2026-10-01)

1. **Engine:** Godot 4.7.2 Forward+ on Metal, typed GDScript.
2. **Repo:** new private GitHub repo `maze-citadel`, nested in `3d/claude/towerdefense` and hidden from the `3d` repo via its local exclude file.
3. **Notarization:** none (ad-hoc signed). No Apple Developer account; the one-time unidentified-developer prompt is fine.
4. **12 towers** = 10 buildable + 2 Epic fusions (Frost Wyrm, Doom Cannon); 2 more Epics are stretch (built 2026-10-02: Sunfire Ballista, Plague Necropolis).
5. **Archer at 25 g** so 220 g buys an 8-tower opener (GDD §4).
6. **Leaked creeps loop** back to the portal, cost lives on every pass and pay no bounty.
7. **Pathing:** 1-tile towers on a 20 × 28 grid; 8-way movement, no corner squeezing.
8. **Target:** arm64 only, for this MacBook Air M3. No Intel or universal build.
9. **Agents:** workflows and subagents allowed, never more than 4 running at once combined.
