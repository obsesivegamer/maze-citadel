#!/usr/bin/env bash
# Headless smoke run of the real game: the autoplay bot plays at ×3 for
# N rendered frames (default 5400 = 90 s, about 6 waves). Fails on any engine
# or script error. No window.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
frames="${1:-5400}"
log=$("$GODOT" --headless --path . --fixed-fps 60 --quit-after "$frames" -- --autoplay --speed=3 2>&1) || true
# The audio mixer frees stopped sounds asynchronously, so a forced quit always
# reports "N resources still in use at exit"; any other error fails the run.
errors=$(grep -E "SCRIPT ERROR|^ERROR|Parse Error" <<<"$log" | grep -v "resources still in use at exit" || true)
if [[ -n "$errors" ]]; then
  echo "$errors" | head -20
  echo "smoke: FAILED"; exit 1
fi
# The windowed game boots behind a loading screen with a battle rehearsal;
# exercise that path too (headless normally uses the one-frame setup).
log=$("$GODOT" --headless --path . --fixed-fps 60 --quit-after 900 -- --async-boot --autoplay 2>&1) || true
errors=$(grep -E "SCRIPT ERROR|^ERROR|Parse Error" <<<"$log" | grep -v "resources still in use at exit" || true)
if [[ -n "$errors" ]]; then
  echo "$errors" | head -20
  echo "smoke: FAILED (async boot)"; exit 1
fi
echo "smoke: OK ($frames frames, plus async boot)"
