#!/usr/bin/env bash
# Export the Windows and Linux builds and pack each into the archive players
# download. Both are x86_64 with the game data embedded in the executable, so
# each archive holds one folder with one file. Godot exports both from any
# host, a Mac included. Check the results with tools/verify_pc.sh.
# Usage: tools/export_pc.sh [windows] [linux]   (default: both)
#   -> dist/MazeCitadel-<version>-windows-x86_64.zip  (MazeCitadel/MazeCitadel.exe)
#      dist/MazeCitadel-<version>-linux-x86_64.tar.gz (MazeCitadel/MazeCitadel.x86_64)
# Needs Godot's windows_release_x86_64.exe and linux_release.x86_64 templates.
# Leaves the rest of dist/ alone, but tools/export.sh empties it, so run that first.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
version=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
platforms=("$@")
[[ ${#platforms[@]} -gt 0 ]] || platforms=(windows linux)
mkdir -p dist && touch dist/.gdignore

for platform in "${platforms[@]}"; do
  case "$platform" in
    windows) preset="Windows Desktop" bin=MazeCitadel.exe ext=zip ;;
    linux) preset="Linux" bin=MazeCitadel.x86_64 ext=tar.gz ;;
    *) echo "usage: tools/export_pc.sh [windows] [linux]" >&2; exit 2 ;;
  esac
  stage="dist/$platform"
  archive="MazeCitadel-$version-$platform-x86_64.$ext"
  rm -rf "$stage" "dist/$archive" && mkdir -p "$stage/MazeCitadel"
  echo "== $preset"
  # Headless for the same reason as tools/export.sh: the presets have the
  # shader baker off and the game warms its shaders behind the loading screen.
  "$GODOT" --headless --path . --export-release "$preset" "$PWD/$stage/MazeCitadel/$bin" 2>&1 \
    | grep -vE "^\s*$" | grep -iE "error|warn|export|template" | grep -v "Storing File" || true
  test -f "$stage/MazeCitadel/$bin" || { echo "export failed: no $bin"; exit 1; }
  others=$(ls -A "$stage/MazeCitadel" | grep -vxF "$bin" || true)
  [[ -z "$others" ]] || { echo "export failed: expected only $bin, also got: $others"; exit 1; }
  if [[ "$ext" == zip ]]; then
    (cd "$stage" && zip -qr -X "../$archive" MazeCitadel)
  else
    # Root-owned entries and, on a Mac, no AppleDouble ._ files or xattrs,
    # which GNU tar would unpack as stray files next to the game.
    if tar --version 2>/dev/null | grep -q "GNU tar"; then
      tar -C "$stage" --owner=0 --group=0 --numeric-owner -czf "dist/$archive" MazeCitadel
    else
      COPYFILE_DISABLE=1 tar -C "$stage" --no-mac-metadata --no-xattrs --uid 0 --gid 0 \
        --uname "" --gname "" -czf "dist/$archive" MazeCitadel
    fi
  fi
  du -h "$stage/MazeCitadel/$bin" "dist/$archive"
done
