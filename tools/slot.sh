#!/usr/bin/env bash
# Everything that needs Jeremy's screen, in one unattended run (~15 min).
# Game windows open and take focus: hands off keyboard and mouse until done.
#   captures: board at launch and mid-battle (wave 24), 3 views × 3 presets
#   benches:  idle and wave-24 battle per preset (docs/perf/*.json)
#   launch:   exports the .app and opens it the way a double-click does
set -euo pipefail
# Classic rules throughout, as docs/perf.md measured them (bench.sh pins them too).
cd "$(dirname "$0")/.."
export ALLOW_WINDOW=1
out="captures/slot-$(date +%m%d-%H%M)"
mkdir -p "$out"
for q in balanced cinematic performance; do
  tools/capture.sh "$out/start-$q" full,portal,gate "$q" --rules=classic
  tools/capture.sh "$out/battle-$q" full,portal,gate "$q" --rules=classic --autoplay --warp-wave=24 --warp-into=18
done
for f in "$out"/*.png; do
  sips -s format jpeg -s formatOptions 80 -Z 1600 "$f" --out "${f%.png}.jpg" >/dev/null
done
BENCH_TAG=idle tools/bench.sh 20
BENCH_TAG=battle tools/bench.sh 20 "cinematic balanced performance" --autoplay --warp-wave=24 --warp-into=18
tools/export.sh
open dist/MazeCitadel.app
sleep 12
if pgrep -x "Maze Citadel" >/dev/null; then
  echo "launch: Maze Citadel.app is running after open (double-click path)"
  osascript -e 'tell application "Maze Citadel" to quit' || pkill -x "Maze Citadel" || true
else
  echo "launch: FAILED — app not running 12 s after open"
fi
echo "slot done; captures in $out"
