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
