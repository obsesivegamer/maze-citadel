# Maze Citadel — Build Plan

**Status:** M0 (plan) done · **Next:** M1, toolchain and delivery spike (≈1.5 h)

Game rules, numbers and content: [GDD.md](GDD.md).

---

## 1. The game in one paragraph

A single-player maze tower defense in the spirit of Warcraft III custom maps. You open straight into a finished 3D citadel: red demon portal in the north, blue town gate in the south, a buildable plateau in between. You wall the plateau with towers to force creeps down a long winding path. You can never fully block it. Forty waves of orcs, wolves, harpies, ghouls, steam tanks and ogre bosses end with a Dreadlord. Twelve towers in four families (Alliance, Horde, Elven, Forsaken) plus support. Depth comes from three layers: where you place towers (maze length), attack type vs armor class, and a six-element counter wheel.

## 2. Technology

**Decision: Godot 4.7.2 (latest stable, released 2026-08-18), Forward+ renderer on native Metal, typed GDScript.**

| Option | Verdict |
|---|---|
| **Godot 4.7** | **Chosen.** Real-time GI, volumetric fog, SSR, decals, GPU particles and HDR output are built in. Everything is text and code, so every change can be written, tested headless and captured to screenshots without an editor. Exports a universal macOS `.app` / `.dmg` in one command. |
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

1. Open `dist/MazeCitadel.dmg` (or `dist/MazeCitadel.app` directly).
2. Drag it to Applications, or skip that step.
3. Double-click. The citadel loads straight into the build phase.

**Details:**
- **Universal binary** (Apple Silicon + Intel), all assets packed inside the app, no installs, no terminal.
- **Signing:** the build is ad-hoc signed. A build made on this Mac opens with a double-click.
- **Downloaded from GitHub:** a `.dmg` downloaded from a GitHub Release gets macOS's "unidentified developer" prompt once (right-click → Open). Removing that prompt needs Apple notarization, which needs a paid Apple Developer account (decision 3 below). The export script will notarize automatically if those credentials are ever added.
- **Every milestone from M1 on** publishes the `.dmg` to a GitHub Release, so the one-click build is proven continuously, not just at the end.

## 4. Requirements

### 4.1 Target and test machine

| | |
|---|---|
| Tested on | MacBook Air 13" M3 (Mac15,12), 8-core CPU, 8-core GPU, 16 GB, macOS 26.6.2 (25G83), 2560 × 1664 Retina |
| Supported | Apple Silicon Macs on recent macOS (exact minimum confirmed in M1) |
| Intel | The universal binary includes an Intel slice. It is **not tested**: no Intel Mac is available. |

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
| Independent review | M3, M6, M9 | Up to 4 review agents (code + visuals) that don't share my framing. Findings are fixed before the tag. |

**Parallel work:** where a milestone splits cleanly (asset sourcing, tower families, juice/world/audio), up to **4 workers** run in separate git worktrees, each owning its own files. I merge and run the gate.

## 7. Milestones

Every milestone ends with: gate green → commit(s) pushed → tag `mN` → (M1+) GitHub pre-release with the `.dmg`. Commits land per logical change throughout, not just at the end. Estimates are agent working time.

### M0 — Plan ✅
- [x] `docs/PLAN.md`, `docs/GDD.md`, README, private GitHub repo `maze-citadel`
- **Gate:** you approve the plan

### M1 — Toolchain and delivery spike (≈1.5 h)
- [ ] Install Godot 4.7.2, export templates, git-lfs, gdtoolkit
- [ ] Project skeleton (folders above), Forward+ on Metal
- [ ] Test scene: terrain, sun, sky, SDFGI, volumetric fog, a few CC0 props, 30 animated dummies
- [ ] `tools/` scripts: check, capture, bench, export (universal `.app` + `.dmg`)
- [ ] Confirm: Metal backend active, upscaler options, shader precompile at export, HDR output, macOS minimum
- **Gate:** check green · capture reviewed · exported app opens by double-click · test-scene fps logged per preset

### M2 — Art and audio sourcing (≈2–3 h · 4 workers: creeps / towers+props / environment / audio)
- [ ] Download CC0 packs; record every file in `assets/CREDITS.md`
- [ ] Stylized WC3 material: saturated toon-PBR, rim light, team-color mask, distance outline for creeps
- [ ] Gallery scene: every creep with walk/hit/death, tower parts, props, under final lighting
- [ ] Gap list, with a procedural build plan for each missing model
- **Gate:** gallery capture reviewed · license check passes with zero unlisted files

### M3 — The citadel, first frame (≈3–4 h)
- [ ] Board: plateau, cliffs, outer walls, banners, pines, red portal (volumetric), blue gate, village, river, watermill
- [ ] RTS camera: damped orbit/pan/zoom, trackpad gestures, presets, `R` hero view
- [ ] HUD shell: gold 220, lives 20, wave 1 preview (10 Grunts), 12 cards, builder selected
- [ ] Straight dotted path portal → gate
- **Gate:** app opens directly into this frame · first frame under 5 s · preset screenshots match the GDD §1 checklist · Balanced ≥ 60 fps · **independent review #1**

### M4 — Mazing core (≈2–3 h)
- [ ] Grid, flow field, anti-block, green/red ghost + thunk, placement dust
- [ ] Sell for 75% (`X` / right-click), live path redraw
- [ ] Fixed-step sim, ×1/×2/×3, pause
- [ ] Grunts walk the maze; leak → lives, gate flash, horn, loop back; defeat screen with stats
- [ ] Tests: flow field, anti-block (creep-occupied tiles, diagonal squeeze), refunds, leak loop; 1,000-placement fuzz never blocks
- **Gate:** tests green · scripted "8-archer zig-zag" scenario captured

### M5 — Towers and damage (≈4–5 h · 4 workers, one per family)
- [ ] Tower data tables, L1→L3 upgrades, targeting, pooled projectiles
- [ ] Damage model: attack × armor class × element wheel × armor/shred × aura
- [ ] 10 buildable towers with distinct models and attack FX; Bard aura; Runesmith shred
- [ ] Epic fusion: Frost Wyrm, Doom Cannon
- [ ] Range ring only on hover/select; colored damage numbers
- **Gate:** a unit test for every damage-table cell · tower showcase capture · 30 towers vs 24 creeps ≥ 60 fps Balanced

### M6 — Creeps, 40 waves, economy, modes (≈3–4 h)
- [ ] 9 creep types + Felhound summons, each with its mechanic and HP bar
- [ ] 40-wave table, Infinite generator, 3 s announcement (class, element, skull)
- [ ] Bounty 6–22, interest 2% per 15 s capped at 20, Normal/Hard/Infinite
- [ ] Victory/defeat screens, score, best-wave save
- [ ] Balance bots: smart mazer, archer-spam (no counters), no-anti-air
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

## 8. Risks

| Risk | Plan |
|---|---|
| CC0 packs miss WC3-specific units (Steam Tank, gryphon, Dreadlord) | Gap list in M2; build missing ones procedurally; nothing ships as a placeholder |
| Fanless M3 Air throttles under sustained load | Balanced is the default; upscaling; 10-minute soak in the bench |
| Godot 4.7 APIs newer than my training data | M1 spike exercises every engine feature we rely on, checked against docs.godotengine.org/en/4.7 |
| I can't hear the audio | Automated checks: every event maps to a file, loudness normalized by script; you do one listening pass at M7 |
| Parallel workers collide | Each worker owns separate files in its own worktree; one integrator merges and runs the gate |

## 9. Decisions made (change any before M1)

1. **Engine:** Godot 4.7.2 Forward+ on Metal, typed GDScript.
2. **Repo:** new private GitHub repo `maze-citadel`, nested in `3d/claude/towerdefense` and hidden from the `3d` repo via its local exclude file.
3. **Notarization:** skipped (ad-hoc signed). If you have an Apple Developer account, say so and the export script will notarize.
4. **12 towers** = 10 buildable + 2 Epic fusions (Frost Wyrm, Doom Cannon); 2 more Epics are stretch.
5. **Archer at 25 g** so 220 g buys an 8-tower opener (GDD §4).
6. **Leaked creeps loop** back to the portal, cost lives on every pass and pay no bounty.
7. **Pathing:** 1-tile towers on a 20 × 28 grid; 8-way movement, no corner squeezing.
