# Performance log

Machine: MacBook Air M3 (8-core GPU, 16 GB), macOS 26.6.2, Godot 4.7.2 on Metal, window 2940 × 1782 px.

## How to measure

`ALLOW_WINDOW=1 tools/bench.sh <seconds> "<presets>" [--setting=value ...]`

- Only runs inside an agreed screen-time slot: the bench window must be **frontmost**.
- macOS throttles unfocused windows. Unfocused runs reported 100–145 fps for the same scene that measures ~51 fps focused. The bench now only counts frames while the window has focus and records `focused` in its JSON.
- Metal's GPU timer query returns 0, so cost is measured by toggling one setting at a time.
- Vsync-off works: the 2026-10-02 pass ran with `vsync_mode` 0 and averaged 62.6–64.4 fps focused, above the 60 Hz refresh. 1% lows at exactly 60.0 suggest some frames are still paced to the display, so a 60.0 low means "at least 60".
- Every preset key can be overridden, including `--foliage`, `--crowd` and `--particles`. Before 2026-10-02 those three only reached the renderer's copy of the settings, not the world or units, so runs that changed them measured nothing. Each report now lists the values it ran with under `settings`.

## M1 render spike, Balanced preset (2026-10-01, preliminary)

10 s per run, focused, render scale 0.7, MetalFX temporal unless noted.

| Change from Balanced (SSIL on) | Avg fps | 1% low |
|---|---|---|
| none (SSIL + SSAO + fog) | 50.9 | 50.8 |
| SSIL off | **60.3 (capped)** | 59.9 |
| SSAO off | 52.5 | 52.5 |
| Volumetric fog off | 50.9 | 48.4 |
| FSR2 instead of MetalFX temporal | 42.7 | 41.6 |
| Render scale 0.6 | 57.4 | 55.4 |
| Shadow atlas 4096 | 48.4 | 48.0 |
| SDFGI instead of SSIL | 49.8 | 49.1 |

**Decisions taken:**
1. Balanced drops SSIL (≈3 ms; the only change that reaches 60).
2. MetalFX temporal is the upscaler. FSR2 costs ≈4 ms more here.
3. SDFGI stays Cinematic-only.

**Still to measure (needs a screen slot):** all three presets with SSIL off, uncapped headroom, 10-minute thermal soak, and the double-click launch test of the exported app.

## Screen slot 1: full game (2026-10-02)

`tools/slot.sh`, 20 s per run, focused window, vsync off. "Battle" = autoplay warped to wave 24 + 18 s (111-tower maze, wave of 12 Grunts + 12 Footmen); the warp is deterministic, so every preset sees the same battle.

| Preset | Idle fps | Battle avg fps | Battle 1% low | Max draw calls (battle) | Video memory |
|---|---|---|---|---|---|
| Cinematic | 28.4 | 20.4 | 14.0 | 2,481 | 1.7 GB |
| Balanced | 54.4 | 33.7 | 14.8 | 2,410 | 1.0 GB |
| Performance | 102.8 | 78.4 | 47.0 | 2,012 | 0.66 GB |

**Not yet meeting the §4.2 target** (Balanced 60 fps in the 24-creep wave).

Findings and caveats:
1. Rendering at 0.5 instead of 0.7 scale was the clearest gain (+24% in a quick 10 s rerun), so the GPU is a real limit at 2940 × 1782.
2. Repeat runs were unstable: the same Balanced battle measured 34 fps in the 20 s run and 55 fps in a 10 s rerun, and a lower-shadow run came out slower. Likely causes: the fanless Air heating up after ~10 minutes of continuous load, and the 20 s window catching heavier moments of the wave. M8 needs cool-machine runs, repeated 3×.
3. Render-thread CPU time is only 1-2 ms per frame, and draw calls (1.2-2.5 k) are not the bottleneck by that measure; triangle count (0.8 M idle, 1.6 M battle, shadow passes included) and fill are the suspects.
4. Cinematic looks almost the same as Balanced in this stylized scene (SDFGI and SSR add little) at twice the cost. Rebalance: spend Cinematic's budget on render scale and shadow resolution instead.
5. Launch: `open dist/MazeCitadel.app` (the double-click path) started the exported arm64 app; 156 MB app, 107 MB dmg.

## Balanced performance pass (2026-10-02)

Balanced only, 20 s per run, focused window (every run `focused=true`), vsync off, plugged in, 2 min rest between runs. Idle and battle runs interleaved so heat doesn't favour one scene. "Battle" is the same deterministic wave-24 warp as slot 1 (`--autoplay --warp-wave=24 --warp-into=18`). Raw JSON: [perf/pass-1002/](perf/pass-1002/).

**Baseline, render scale 0.7, 3 runs each:**

| Scene | Avg frame ms | Avg fps (range) | 1% low | Max draw calls | Max primitives | Video mem |
|---|---|---|---|---|---|---|
| Idle | 18.7 | 53.4 (53.0–53.6) | 51.3 | 1,420 | 0.65 M | 951 MB |
| Battle | 20.1 | 49.7 (49.6–49.8) | 48.9 | 2,313 | 1.37 M | 1,036 MB |

**One setting at a time against the battle, 2 runs each (interleaved, with an unchanged control in each round):**

| Change from Balanced | Avg frame ms | Avg fps (range) | 1% low | Δ ms vs control |
|---|---|---|---|---|
| none (control) | 20.1 | 49.7 (49.7–49.7) | 49.1 | — |
| render scale 0.6 | 17.7 | 56.5 (56.4–56.5) | 55.4 | −2.4 |
| **render scale 0.5** | **15.8** | **63.5 (62.7–64.3)** | **60.0** | **−4.3** |
| SSAO off | 18.7 | 53.3 (53.3–53.4) | 52.4 | −1.4 |
| volumetric fog off | 19.7 | 50.8 (50.7–50.8) | 50.0 | −0.4 |
| shadows 1024, 2 cascades | 20.0 | 49.9 (49.9–49.9) | 49.1 | −0.1 |
| foliage 0.5 | *not applied* | | | (override ignored, see note) |
| crowd 0.35 | *not applied* | | | (override ignored, see note) |

**Fix: Balanced render scale 0.7 → 0.5** (MetalFX temporal upscaling stays), confirmed with 3 more battle runs: 15.8 ms, **63.4 fps (62.6–64.4), 1% low 60.0**, 2,314 draw calls, 1.37 M primitives, 955 MB video memory. This meets the PLAN target (60 fps average, 1% low ≥ 50).

Findings:
1. Runs were stable this time: every repeat landed within ±1 fps. Slot 1's 33.7 fps battle did not reproduce. Battle primitives also dropped from 1.59 M to 1.37 M after the slot 1 fixes, but heat is the likelier cause of the old number.
2. The GPU is fill-bound at 2940 × 1782. Render scale is the only lever that reaches 60. Shadow resolution and fog are each worth ≤ 0.4 ms. SSAO is the next-biggest single cost (1.4 ms).
3. The foliage and crowd rows are not measurements: those runs stayed at the control's 1,369,181 primitives. `World._on_quality_changed` re-reads `Quality.settings(preset)` and drops the bench overrides, so Balanced kept foliage 0.8 and crowd 0.7. PR #3 makes the overrides apply and measures them headless (foliage 0.5 ≈ −2% triangles, crowd 0.35 ≈ −0.5%).
4. Each 1% low at render scale 0.5 is exactly 60.0, which suggests the display's frame pacing still caps some frames even with vsync off (see "How to measure").
5. On-screen check done (2026-10-02, maximized 2940 × 1782 window): 0.7 vs 0.5 side by side at native pixels ([gate](screens/m8-rs07-vs-rs05-battle-gate.jpg), [battle](screens/m8-rs07-vs-rs05-battle-full.jpg), [portal](screens/m8-rs07-vs-rs05-battle-portal.jpg), [start](screens/m8-rs07-vs-rs05-start-full.jpg)). 0.5 is very slightly softer on fine texture (cobblestones, tower trim); the HUD renders at full resolution either way. Balanced and Performance now share a render scale; they still differ in upscaler, SSAO, fog, shadows and density. Also still owed: the 10-minute thermal soak.

## Fallen Rampart render load (2026-10-02, cloud)

Frame times need the Mac, so this compares the load each map puts on the renderer: the same wave-24 battle warp (`--autoplay --warp-wave=24 --warp-into=18`), Balanced, 2940 × 1782, measured in a cloud container under Xvfb with Godot's OpenGL compatibility renderer. That renderer counts draw calls differently from Metal, but primitive counts match it closely (1.36 M there vs 1.37 M on Metal for this battle on main).

| Map | Max draw calls | Max primitives |
|---|---|---|
| Citadel Plateau | 3,392 | 1.34 M |
| Fallen Rampart | 3,499 (+3%) | 1.41 M (+5%) |

The ruins are one baked static mesh; the rest of the difference is the bot's maze and creeps on that map. The Balanced battle is limited by pixel count, not geometry (foliage at 0.5 cut 2% of primitives and changed nothing measurable), so the Rampart should hold the same ~63 fps. Confirm with one battle bench on the M3 Air: `ALLOW_WINDOW=1 BENCH_TAG=rampart tools/bench.sh 20 balanced --autoplay --warp-wave=24 --warp-into=18 --map=rampart`.

## Cinematic rebalance (2026-10-02, not yet measured)

Slot 1 showed Cinematic at about 2× Balanced's cost (20 fps in the battle) with SDFGI and SSR adding little to this bright, stylized scene. Cinematic is now render scale 0.7 (MetalFX temporal), SSAO high, fog high, 4096 shadows with 4 cascades, SDFGI and SSR off: in effect the old Balanced (49.7 fps in the battle at 0.7) plus stronger AO, fog and shadows. Expected 40-50 fps in the battle; `tools/slot_d.sh` measures it.

Also new: bench reports `timeline_fps` (average fps per 30 s) for thermal soaks, and `--first-frame-out` records launch time (first frame, frame 60, worst of the first 120 frames).

## Loading and first-use stalls (2026-10-02)

Reported on v0.1.0: a long spinning cursor at launch (music already playing) and a freeze when wave 1 starts.

Cause: the Godot shader baker only runs when a real RenderingDevice renderer is active (`ShaderBakerExportPlugin::_is_active` checks `RendererSceneRenderRD`), so `--headless` exports, local and CI alike, ship without baked shaders. Metal then compiles every shader on first use: the whole world in the first frames (one long main-thread stall, so macOS shows the spinning cursor) and creeps, projectiles and effects when wave 1 brings them on screen.

Fix (works with or without baked shaders):
1. `Game.async_boot`: a loading screen first, then the camera, each world part and each subsystem one per frame, so the window keeps answering and each frame compiles only what was just added.
2. `WarmupStage`: behind the loading screen, a throwaway sim with every tower at every level and every creep type fights for 75 frames, drawn by its own Units/Fx, so every combat shader compiles before play. Sound, HUD and the real board never see it; the opening countdown doesn't tick until boot ends.
3. `--first-frame-out` now records the first frame, when the game is playable, and the worst frame plus hitch count (> 50 ms) in the 10 s after it starts wave 1.

Measured on screen (M3 Air, maximized, `--first-frame-out --autoplay`; "cold" = shader cache moved aside, i.e. a first launch):

| Run | First frame | Playable | Worst frame in the 10 s after wave 1 | Hitches > 50 ms |
|---|---|---|---|---|
| Old one-frame boot, cold | **8.3 s** (spinning cursor until then) | 3.1 s* | 150 ms | 1 |
| New loading screen, cold (first launch) | 1.1 s | 20.5 s | 114 ms | 1 |
| New loading screen, warm (later launches) | 0.65 s | 4.2 s | 116 ms | 1 |

\* setup finished before the first frame could be drawn; the window showed nothing until 8.3 s.

Findings:
1. The spinning cursor is gone: the loading screen shows within ~1 s and keeps updating.
2. A first launch takes ~20 s on the loading screen because every shader compiles up front; later launches take ~4 s (Godot's shader cache in `~/Library/Application Support/Maze Citadel/shader_cache`). Next: time each boot step to see what dominates the cold 20 s.
3. One ~115 ms hitch remains after wave 1 starts, new path or old; to investigate.
4. **Shader baking crashes the app.** A windowed export does run the baker, but without full Xcode it logs "Metal shader baking limited to SPIR-V", and the exported app then aborts at launch ("Not enough bytes for uniform in shader container" → "Failed to parse shader container from binary" → FATAL index out of bounds). The baker is now disabled in `export_presets.cfg` and `tools/export.sh` always exports headless; the warm-up does the job instead. Revisit with full Xcode or a later Godot.

## Butter pass (2026-10-03, in progress)

Goal: every frame under 16.7 ms with margin on Balanced (the default) in heavy battles, and no hitches in real play.

### Measuring
1. `--bench-any-focus`: the bench window is always-on-top and maximized, so it renders normally without keyboard focus (render scale 0.7: 20.55 ms unfocused vs 21.1–21.7 ms focused before HUD batching). Benchmarks no longer wait for the game to get focus.
2. **Other apps sharing the GPU wreck the numbers.** The Claude desktop app alone used 60–85% of the GPU for hours, and the same run went from 20.6 ms to 43–88 ms. Check with `ioreg -c AGXDeviceUserClient -r -l -w0` (per-process `accumulatedGPUTime`); the runner waits until other apps use < 8% and samples them mid-run. Per-process GPU time is not a usable substitute under contention (render scale 0.5 came out slower than 0.7).
3. Each missed frame in a bench report now carries its CPU sections and game state (`spikes`).

### Tower builds hitched (fixed)
`tests/perf/cpu_hitch.gd` plays 12 waves headless at 60 Hz and lists every frame over budget with its cause. Every build ran the path search twice at ~5 ms a pass, so a build frame cost ~22 ms of CPU. The search now walks flat tile indices with a hole-sifting heap (1.6 ms; identical distances on 600 random mazes) and a build adopts the field its validity check computed.

| Frames over budget, waves 1–12 | Before | After (one-frame boot) | After (shipped loading path) |
|---|---|---|---|
| over 8 ms | 47 | 12 | 3 |
| over 16 ms | 45 | 7 | 1 (the bot placing 6 towers in one frame) |
| over 33 ms | 4 | 2 | 0 |

Creep views pre-built on the loading screen remove the first-spawn stalls (17–36 ms on the one-frame boot).

### Switches, one at a time (wave 35, render scale 0.7, 12 controls 20.63–20.67 ms)

| Switch | Saves | Look |
|---|---|---|
| `glow=false` | 2.03 ms | loses bloom; not shippable as is |
| `sun-angular=0` (PCF instead of PCSS) | 0.80 ms | to check |
| `nature-shadow-proxy` | 0.66 ms | to check |
| `shadow-filter=2` | 0.32 ms | to check |
| `shadow_size=1024` | 0.24 ms | softer shadows |
| `nature-bark-lod=2` | 0.23 ms | to check |
| `ssao_quality=1`, `fog_size=48 fog_depth=32`, `terrain-cheap=3`, `terrain-cheap=1`, `world-tex-compress` | 0.10–0.18 ms each | terrain-cheap=1 and tex-compress match the current look in stills |
| `hud-lite`, tower/creep switches, grass LOD, foliage filter, leaf priority | ~0 | hud-lite also hurts hint readability: drop |
| `shadow_splits=2` | −0.20 ms (slower) | drop |

Glow variants (render scale 0.7, controls 20.7–21.2 ms while another app used 4–7% of the GPU): `glow-bicubic=false` −0.58 ms, `glow-levels=0,0.8,0.4,0,0,0,0` −0.41, `glow-levels=0,1.0,0,0,0,0,0` −0.48, both −0.38, `glow=false` −1.96. Most of glow's cost is the base pass; bicubic off is the only variant that leaves the look alone.

Terrain still costs ~3.5 ms (hiding it) but cheaper shading saves only 0.1 ms, so its cost is elsewhere (geometry, overdraw or prepass).

### Look checks (stills at native resolution, no temporal AA, pixels that don't animate)
1. Same look: `terrain-cheap=1`, `glow-bicubic=false`, `nature-bark-lod=2`, `ssao_quality=1`, `fog_size=48 fog_depth=32`, `shadow-filter=2`, `sun-angular=0` (edges a touch crisper).
2. Visible: `shadow_size=1024` (blocky, speckled edges), `nature-shadow-proxy` (heavier tree shadows that lose the pine outline), `hud-lite` (hint text unreadable over bright ground), `glow=false`.
3. `world-tex-compress` looks the same but only works in the editor binary (export templates have no compressor): dropped.

### Shipped
All presets: soft-shadow filter low (`project.godot`), sun angular distance 0 (PCF), linear glow upscale, `terrain-cheap` 1, bark from LOD 2. Balanced also: SSAO low, fog 48 × 32. Render scale stays 0.5: the keepers at 0.6 land at 16.2 ms, no margin.

| Wave 35, Balanced, uncapped | Frame | Worst | 1% low |
|---|---|---|---|
| Before (old values restored with flags) | 15.82 ms | 16.7 ms | 60 fps |
| Shipped | **14.14 ms** | 14.3–14.8 ms | 70 fps |

Launch (warm, twice): first frame 0.6 s, playable 3.8–4.0 s, worst frame in the 10 s after wave 1 starts **32 ms** (was 114–116 ms), no hitches over 50 ms.

### Heat (fanless Air)
1. Frozen wave-35 battle (`--speed=0`), uncapped: 67.6 fps for 3.5 min, then throttled to ~59.5 fps (−12%) and stays there.
2. Real play from wave 30 capped at 60 fps (`--max-fps 60`, the GPU idles part of each frame): 60.0 fps for 3 min, then 56–58 fps for the remaining 7 (waves 32+) with runs of 22–25 ms frames (53 frames over 20.8 ms in 10 min). Not butter yet in long late-game sessions: needs ~2–3 ms more, or less heat.

### Late waves on a hot Mac
1. The 22–25 ms runs land on moments like "wave cleared" (wave 32 at sim time 1489 s, 0 creeps): no single effect, just the heavier moments going over once the GPU is throttled. The wave banner and crowd cheer are cheap.
2. Terrain's ~3.5 ms is per-pixel lighting and shadow sampling over most of the screen: its meshes total 88k triangles and the 680 m lowland casts no shadow.
3. Balanced-only trims at wave 38 (controls 14.23–14.26 ms): render scale 0.45 −1.01 ms, SSAO off −0.55, shadow distance 110 m −0.48 (cuts shadows at the portal end), fog off −0.13, coarser trees / lighter big effects ~0.
4. Render scale 0.45 always on softens close-ups visibly (gate cobblestones), so it isn't shipped as a default. Changing the scale mid-battle stalls one frame (~92–99 ms), then ~7 frames run 1–3 ms slow.
5. Metal reports no GPU frame time to the game (`viewport_get_measured_render_time_gpu` reads 0), so a governor has to judge from frame times.

### Heat governor (tried, removed)
Idea: when 10 s of wave frames average under ~58 fps, step the render scale down by 0.05 at the next "wave cleared" (up to twice), hiding the one-frame switch stall behind the banner. Two hot 10-minute soaks from wave 30 capped at 60 fps (`--max-fps 60`):

| Run | 30 s windows after throttling | Frames over 20.8 ms | Worst |
|---|---|---|---|
| No governor (`real60`) | 56–58 fps | 53 | 25 ms |
| One step to 0.45 (`gov60`) | 56–60 fps | 750 | 127 ms |
| Up to two steps, 0.40 (`gov60b`) | 54–59 fps | 1482 | 142 ms |

After a switch, a hot Mac stalls for ~0.6 s at a time (frames of 50–140 ms) every few waves; no governor run is free of it, no run without a switch shows it, and short cool replays of the same moments with or without a switch are clean. One 0.05 step also buys only ~7% against ~12% of throttling. Removed: a steady ~57 fps beats repeated 130 ms freezes. Mid-game render-scale changes are off the table on this Mac.

### Next
1. Hot late waves still average ~57 fps on Balanced. The biggest lever left that keeps the look: render the 3D view at the panel's own resolution. The default "looks like 1470 × 956" mode draws 2940 × 1782 and macOS shrinks it to the 2560-wide panel, so MetalFX and post-processing work on ~32% more pixels than the screen shows. Needs the 3D in a SubViewport (picking, overlays and captures map coordinates), so it's its own change.
2. The Performance preset holds 60 when hot for players who want that now.
