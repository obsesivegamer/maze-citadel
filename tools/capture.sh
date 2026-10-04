#!/usr/bin/env bash
# Render named camera views to PNGs. Opens a game window briefly.
# Usage: tools/capture.sh <out-prefix> [views=full,portal,gate] [quality=balanced] [extra args...]
# Views are the camera presets in src/camera/camera_rig.gd (the render spike's are its own).
# Captures the Citadel Plateau unless the extra args say --map=...
# GODOT_ARGS="--rendering-method mobile" adds engine args (before `--`).
set -euo pipefail
# Opens a game window (bench also takes focus). Jeremy uses this Mac, so only
# run inside an agreed screen-time slot.
[[ "${ALLOW_WINDOW:-}" == 1 ]] || { echo "refusing: opens a window; set ALLOW_WINDOW=1 in a screen slot" >&2; exit 2; }
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p "$(dirname "$1")"
prefix="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
views="${2:-full,portal,gate}"
quality="${3:-balanced}"
shift $(( $# < 3 ? $# : 3 ))
engine=()
if [[ -n "${GODOT_ARGS:-}" ]]; then read -r -a engine <<< "$GODOT_ARGS"; fi
"$GODOT" ${engine[@]+"${engine[@]}"} --path . -w --resolution 1600x1000 --fixed-fps 30 --disable-vsync -- \
  --shot="$prefix" --views="$views" --quality="$quality" --map=citadel "$@" 2>&1 \
  | grep -E "shot:|ERROR" || true
