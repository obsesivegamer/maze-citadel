# Performance log

Machine: MacBook Air M3 (8-core GPU, 16 GB), macOS 26.6.2, Godot 4.7.2 on Metal, window 2940 × 1782 px.

## How to measure

`ALLOW_WINDOW=1 tools/bench.sh <seconds> "<presets>" [--setting=value ...]`

- Only runs inside an agreed screen-time slot: the bench window must be **frontmost**.
- macOS throttles unfocused windows. Unfocused runs reported 100–145 fps for the same scene that measures ~51 fps focused. The bench now only counts frames while the window has focus and records `focused` in its JSON.
- Metal's GPU timer query returns 0, so cost is measured by toggling one setting at a time.
- Focused runs cap at 60 fps (display refresh). Runtime vsync-off is wired in but not yet verified, so "60" means "at least 60".

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
