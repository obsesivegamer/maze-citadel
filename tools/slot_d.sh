#!/usr/bin/env bash
# Screen slot D (~25 min, unattended): finishes M8. Start with the Mac cool
# and plugged in; windows take focus, so hands off until it prints "done".
#   1. launch time of the dev build (3×)
#   2. export with the shader baker (windowed), launch time of the app (3×)
#   3. rebalanced Cinematic in the wave-24 battle (3×) + a Balanced control
#   4. 10-minute Balanced soak while the bot keeps playing (thermal check)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
out="docs/perf/slot-d-$(date +%m%d)"
mkdir -p "$out"
# Benches the Citadel Plateau, not the player's last map pick.
battle=(--autoplay --warp-wave=24 --warp-into=18)

bench() { # preset, seconds, name
  "$GODOT" --path . -m -t --disable-vsync -- --bench="$2" --bench-out="$PWD/$out/$3.json" \
    --quality="$1" --map=citadel "${battle[@]}" >/dev/null 2>&1
}

for i in 1 2 3; do
  "$GODOT" --path . -m -- --first-frame-out="$PWD/$out/first-dev-$i.json" >/dev/null 2>&1
done
EXPORT_WINDOWED=1 tools/export.sh | tee "$out/export.log"
app="dist/MazeCitadel.app/Contents/MacOS/Maze Citadel"
for i in 1 2 3; do
  "$app" -m -- --first-frame-out="$PWD/$out/first-app-$i.json" >/dev/null 2>&1
done
for i in 1 2 3; do
  bench cinematic 20 "cinematic-battle-$i"
  sleep 60
done
bench balanced 20 balanced-battle-control
sleep 60
bench balanced 600 balanced-soak-600s

python3 - "$out" <<'PY'
import json, pathlib, sys
d = pathlib.Path(sys.argv[1])
for f in sorted(d.glob("first-*.json")):
    r = json.loads(f.read_text())
    print(f"{f.stem:22} first frame {r['first_frame_ms']} ms · frame 60 at {r['frame60_ms']} ms · worst early frame {r['worst_frame_ms_first_120']:.0f} ms")
for f in sorted(d.glob("*battle*.json")) + sorted(d.glob("*soak*.json")):
    r = json.loads(f.read_text())
    tl = r.get("timeline_fps") or []
    extra = f" · per-30 s fps {min(tl)}–{max(tl)}" if tl else ""
    print(f"{f.stem:22} {r['avg_fps']:6} fps · 1% low {r['low_1pct_fps']:6} · focused {r['focused']}{extra}")
PY
echo "slot D done: $out"
