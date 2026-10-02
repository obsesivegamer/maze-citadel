#!/usr/bin/env bash
# Export the .app (arm64, shaders precompiled) and wrap it in a .dmg. Ad-hoc
# signed unless MACOS_SIGN_IDENTITY is set. Check the result with tools/verify_dmg.sh.
# Usage: tools/export.sh   ->  dist/MazeCitadel.app, dist/MazeCitadel-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
version=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
rm -rf dist && mkdir -p dist && touch dist/.gdignore
"$GODOT" --headless --path . --export-release "macOS" "$PWD/dist/MazeCitadel.app" 2>&1 \
  | grep -vE "^\s*$" | grep -iE "error|warn|savepack|export" || true
bin="dist/MazeCitadel.app/Contents/MacOS/Maze Citadel"
test -f "$bin" || { echo "export failed: no app binary"; exit 1; }

# Official templates are universal only; this Mac is the sole target, so keep arm64.
lipo "$bin" -thin arm64 -output "$bin.arm64" && mv "$bin.arm64" "$bin"
# MACOS_SIGN_IDENTITY names a "Developer ID Application" identity in the keychain
# (the release workflow sets it when signing secrets exist). Unset means ad-hoc.
identity="${MACOS_SIGN_IDENTITY:-}"
if [[ -n "$identity" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "$identity" dist/MazeCitadel.app
else
  codesign --force --deep --sign - dist/MazeCitadel.app
fi
codesign --verify --deep --strict dist/MazeCitadel.app \
  && echo "codesign: signature valid (${identity:-ad-hoc})"
lipo -archs "$bin"

stage=$(mktemp -d)
cp -R dist/MazeCitadel.app "$stage/Maze Citadel.app"
ln -s /Applications "$stage/Applications"
hdiutil create -quiet -volname "Maze Citadel" -srcfolder "$stage" -ov -format UDZO \
  "dist/MazeCitadel-$version.dmg"
rm -rf "$stage"
if [[ -n "$identity" ]]; then
  codesign --force --timestamp --sign "$identity" "dist/MazeCitadel-$version.dmg"
fi
du -sh dist/MazeCitadel.app "dist/MazeCitadel-$version.dmg"
