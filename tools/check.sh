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

echo "== lint"
gdlint src tests
gdformat --check src tests

echo "== unit tests"
"$GODOT" --headless --path . --script res://tests/run_tests.gd 2>&1 | tee /dev/stderr \
  | grep -qE "^[0-9]+ passed, 0 failed$"

echo "check: OK"
