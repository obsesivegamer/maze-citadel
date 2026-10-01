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
echo "smoke: OK ($frames frames)"
