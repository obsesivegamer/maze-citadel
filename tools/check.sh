#!/usr/bin/env bash
# Repo gate. Run before every commit: import, lint, format, unit tests.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
export PATH="$HOME/.local/bin:$PATH"

echo "== import"
log=$("$GODOT" --headless --path . --import 2>&1) || { echo "$log"; exit 1; }
if grep -E "SCRIPT ERROR|Parse Error|^ERROR|USER ERROR" <<<"$log"; then
  echo "import reported errors"; exit 1
fi

echo "== asset licenses"
python3 tools/check_assets.py | tail -1
python3 tools/check_assets.py >/dev/null

echo "== perf matrix tools"
python3 tools/test_perf_matrix.py 2>&1 | tail -1
tools/perf_matrix.sh --dry-run tools/perf_configs/renderer.txt >/dev/null

echo "== lint"
gdlint src tests
gdformat --check src tests

echo "== unit tests"
"$GODOT" --headless --path . --script res://tests/run_tests.gd 2>&1 | tee /dev/stderr \
  | grep -qE "^[0-9]+ passed, 0 failed$"

echo "== smoke (headless game, autoplay)"
# Both rule sets on both maps. The loading-screen boot runs once per rule set
# (their HUDs differ), which keeps the gate as fast as with three runs.
tools/smoke.sh
SMOKE_ASYNC=0 tools/smoke.sh 2700 --map=rampart
tools/smoke.sh 2700 --rules=classic
SMOKE_ASYNC=0 tools/smoke.sh 2700 --rules=classic --map=rampart

echo "check: OK"
