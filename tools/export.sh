#!/usr/bin/env bash
# Export the .app (arm64, ad-hoc signed, shaders precompiled) and wrap it in a .dmg.
# Usage: tools/export.sh   ->  dist/MazeCitadel.app, dist/MazeCitadel-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
version=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
rm -rf dist && mkdir -p dist && touch dist/.gdignore
# The shader baker compiles Metal shaders and needs the GPU, which a headless
# export lacks; EXPORT_WINDOWED=1 (screen slots only) exports with a window.
mode=(--headless)
[[ "${EXPORT_WINDOWED:-}" == 1 ]] && mode=()
"$GODOT" ${mode[@]+"${mode[@]}"} --path . --export-release "macOS" "$PWD/dist/MazeCitadel.app" 2>&1 \
  | grep -vE "^\s*$" | grep -iE "error|warn|bak|shader|export" | grep -v "Storing File" || true
bin="dist/MazeCitadel.app/Contents/MacOS/Maze Citadel"
test -f "$bin" || { echo "export failed: no app binary"; exit 1; }

# Official templates are universal only; this Mac is the sole target, so keep arm64.
lipo "$bin" -thin arm64 -output "$bin.arm64" && mv "$bin.arm64" "$bin"
codesign --force --deep --sign - dist/MazeCitadel.app
codesign --verify --deep dist/MazeCitadel.app && echo "codesign: ad-hoc signature valid"
lipo -archs "$bin"

stage=$(mktemp -d)
cp -R dist/MazeCitadel.app "$stage/Maze Citadel.app"
ln -s /Applications "$stage/Applications"
hdiutil create -quiet -volname "Maze Citadel" -srcfolder "$stage" -ov -format UDZO \
  "dist/MazeCitadel-$version.dmg"
rm -rf "$stage"
du -sh dist/MazeCitadel.app "dist/MazeCitadel-$version.dmg"
