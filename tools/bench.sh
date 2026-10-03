#!/usr/bin/env bash
# Frame-pacing benchmark per quality preset, maximized window, vsync off.
# Usage: tools/bench.sh [seconds=20] [presets="cinematic balanced performance"] [extra args...]
# Writes docs/perf/<preset>.json (one JSON report per preset). Benches the
# Citadel Plateau, not the player's last map, unless extra args say --map=...
set -euo pipefail
# Opens a game window (bench also takes focus). Jeremy uses this Mac, so only
# run inside an agreed screen-time slot.
[[ "${ALLOW_WINDOW:-}" == 1 ]] || { echo "refusing: opens a window; set ALLOW_WINDOW=1 in a screen slot" >&2; exit 2; }
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
secs="${1:-20}"
presets="${2:-cinematic balanced performance}"
shift $(( $# < 2 ? $# : 2 ))
mkdir -p docs/perf
for p in $presets; do
  out="$PWD/docs/perf/$p${BENCH_TAG:+-$BENCH_TAG}.json"
  label="$p${BENCH_TAG:+ $BENCH_TAG}"
  "$GODOT" --path . -m -t --disable-vsync -- --bench="$secs" --bench-out="$out" --quality="$p" \
    --map=citadel "$@" \
    >/dev/null 2>&1
  python3 -c "import json,sys; r=json.load(open(sys.argv[1])); print(f\"{sys.argv[2]:28} avg {r['avg_fps']:6} fps  1%low {r['low_1pct_fps']:6}  cpu {r['avg_cpu_ms']} ms focus={r['focused']}  {r['window_px']} x{r['render_scale']}\")" "$out" "$label"
done
