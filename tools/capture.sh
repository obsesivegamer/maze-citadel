#!/usr/bin/env bash
# Render named camera views to PNGs. Opens a game window briefly.
# Usage: tools/capture.sh <out-prefix> [views=overview,portal,gate] [quality=balanced] [extra args...]
set -euo pipefail
# Opens a game window (bench also takes focus). Jeremy uses this Mac, so only
# run inside an agreed screen-time slot.
[[ "${ALLOW_WINDOW:-}" == 1 ]] || { echo "refusing: opens a window; set ALLOW_WINDOW=1 in a screen slot" >&2; exit 2; }
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p "$(dirname "$1")"
prefix="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
views="${2:-overview,portal,gate}"
quality="${3:-balanced}"
shift $(( $# < 3 ? $# : 3 ))
"$GODOT" --path . -w --resolution 1600x1000 --fixed-fps 30 --disable-vsync -- \
  --shot="$prefix" --views="$views" --quality="$quality" "$@" 2>&1 | grep -E "shot:|ERROR" || true
