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

