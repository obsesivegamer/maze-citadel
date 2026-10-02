#!/usr/bin/env bash
# Check a built .dmg the way a player meets it: the image is intact and mounts,
# the app inside has the right id, version and arch, its signature holds, and
# the game runs from the mounted image (headless autoplay, like tools/smoke.sh).
# Writes build-info.json and a .sha256 next to the .dmg; the release and the
# download site read them.
# Usage: tools/verify_dmg.sh [dist/MazeCitadel-<version>.dmg]
#   SMOKE_FRAMES=5400     frames for the headless run (90 s of game at x3)
#   REQUIRE_NOTARIZED=1   fail unless Gatekeeper accepts the app as notarized
#   LAUNCH_CHECK=1|soft   also open a real window and save launch-full.png;
#                         soft only warns on failure. Opens a window, so outside
#                         CI it needs ALLOW_WINDOW=1 like tools/capture.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
bundle_id_expected=$(sed -n 's/^application\/bundle_identifier="\(.*\)"/\1/p' export_presets.cfg)
dmg="${1:-dist/MazeCitadel-$version.dmg}"
frames="${SMOKE_FRAMES:-5400}"
launch_check="${LAUNCH_CHECK:-0}"

fail() {
  echo "verify: FAILED: $*"
  exit 1
}
ok() { echo "  ok  $*"; }

[[ -f "$dmg" ]] || fail "no .dmg at $dmg (run tools/export.sh first)"
if [[ "$launch_check" != 0 && -z "${CI:-}" && "${ALLOW_WINDOW:-}" != 1 ]]; then
  echo "refusing: LAUNCH_CHECK opens a window; set ALLOW_WINDOW=1 in a screen slot" >&2
  exit 2
fi
out_dir=$(cd "$(dirname "$dmg")" && pwd)
dmg_name=$(basename "$dmg")

echo "== image: $dmg_name"
hdiutil verify -quiet "$dmg" || fail "hdiutil verify: image checksum is bad"
format=$(hdiutil imageinfo "$dmg" | sed -n 's/^Format: //p')
[[ "$format" == UDZO ]] || fail "expected a compressed UDZO image, got '$format'"
size_bytes=$(stat -f %z "$dmg")
ok "checksum valid, format $format, $((size_bytes / 1048576)) MB"

mnt=$(mktemp -d)
cleanup() {
  hdiutil detach -quiet "$mnt" 2>/dev/null || hdiutil detach -quiet -force "$mnt" 2>/dev/null || true
  rmdir "$mnt" 2>/dev/null || true
}
trap cleanup EXIT
hdiutil attach -quiet -nobrowse -readonly -noautoopen -mountpoint "$mnt" "$dmg" \
  || fail "the image does not mount"
app="$mnt/Maze Citadel.app"
[[ -d "$app" ]] || fail "no 'Maze Citadel.app' at the image root"
[[ -L "$mnt/Applications" ]] || fail "no Applications shortcut to drag the app onto"
ok "mounts with Maze Citadel.app and the Applications shortcut"

echo "== bundle"
plist="$app/Contents/Info.plist"
plist_get() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist"; }
bundle_id=$(plist_get CFBundleIdentifier)
short_version=$(plist_get CFBundleShortVersionString)
# Godot writes the minimum per architecture when the preset sets one per arch.
min_macos=$(plist_get LSMinimumSystemVersionByArchitecture:arm64 2>/dev/null \
  || plist_get LSMinimumSystemVersion 2>/dev/null || true)
bin="$app/Contents/MacOS/$(plist_get CFBundleExecutable)"
[[ "$bundle_id" == "$bundle_id_expected" ]] \
  || fail "bundle id $bundle_id, expected $bundle_id_expected"
[[ "$short_version" == "$version" ]] \
  || fail "app version $short_version but project.godot says $version (export_presets.cfg application/short_version)"
archs=$(lipo -archs "$bin")
[[ "$archs" == arm64 ]] || fail "expected an arm64-only binary, got '$archs'"
app_bytes=$(($(du -sk "$app" | cut -f1) * 1024))
ok "$bundle_id $short_version, $archs, macOS $min_macos+, $((app_bytes / 1048576)) MB installed"

echo "== signature"
codesign --verify --deep --strict "$app" || fail "app signature does not verify"
sig=$(codesign -dv "$app" 2>&1)
if grep -q "Signature=adhoc" <<<"$sig"; then
  signature="ad-hoc"
else
  signature=$(sed -n 's/^Authority=//p' <<<"$sig" | head -1)
fi
gatekeeper=$(spctl --assess --type execute -vv "$app" 2>&1 || true)
notarized=false
if grep -q "source=Notarized Developer ID" <<<"$gatekeeper" \
  && xcrun stapler validate -q "$dmg" >/dev/null 2>&1; then
  notarized=true
fi
ok "signed: $signature; notarized and stapled: $notarized"
if [[ "${REQUIRE_NOTARIZED:-0}" == 1 && "$notarized" != true ]]; then
  echo "$gatekeeper"
  fail "Gatekeeper does not accept the app as notarized, or the .dmg has no stapled ticket"
fi

echo "== headless run from the mounted image ($frames frames, autoplay x3)"
start=$(date +%s)
status=0
log=$("$bin" --headless --fixed-fps 60 --quit-after "$frames" -- --autoplay --speed=3 2>&1) \
  || status=$?
smoke_seconds=$(($(date +%s) - start))
# Same filter as tools/smoke.sh: a forced quit always reports resources in use.
errors=$(grep -E "SCRIPT ERROR|^ERROR|Parse Error" <<<"$log" \
  | grep -v "resources still in use at exit" || true)
if [[ -n "$errors" || "$status" != 0 ]]; then
  echo "$log" | tail -40
  fail "the exported game errored or exited with status $status"
fi
godot_version=$("$bin" --version 2>/dev/null | tail -1 || true)
ok "ran $frames frames in ${smoke_seconds}s with no errors (Godot $godot_version)"

launch=skipped
if [[ "$launch_check" != 0 ]]; then
  echo "== window launch (renders a frame and saves launch-full.png)"
  rm -f "$out_dir/launch-full.png"
  "$bin" -w --resolution 1600x1000 --fixed-fps 30 --disable-vsync -- \
    --shot="$out_dir/launch" --views=full --settle=240 --autoplay --speed=3 \
    >"$out_dir/launch.log" 2>&1 &
  pid=$!
  for _ in $(seq 120); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  if [[ -s "$out_dir/launch-full.png" ]]; then
    launch=ok
    ok "window opened and rendered (launch-full.png)"
  else
    launch=failed
    tail -20 "$out_dir/launch.log"
    [[ "$launch_check" == soft ]] || fail "the app did not open a window and render a frame"
    echo "  warn the app did not render a frame in a window (LAUNCH_CHECK=soft, not fatal)"
  fi
fi

sha256=$(shasum -a 256 "$dmg" | cut -d' ' -f1)
echo "$sha256  $dmg_name" >"$out_dir/$dmg_name.sha256"
commit=$(git rev-parse HEAD 2>/dev/null || echo unknown)
export dmg_name version size_bytes app_bytes sha256 archs min_macos bundle_id signature \
  notarized godot_version commit frames smoke_seconds launch
python3 - "$out_dir/build-info.json" <<'PY'
import datetime, json, os, sys
e = os.environ
info = {
    "name": "Maze Citadel",
    "version": e["version"],
    "dmg": e["dmg_name"],
    "size_bytes": int(e["size_bytes"]),
    "app_bytes": int(e["app_bytes"]),
    "sha256": e["sha256"],
    "arch": e["archs"],
    "min_macos": e["min_macos"],
    "bundle_id": e["bundle_id"],
    "signature": e["signature"],
    "notarized": e["notarized"] == "true",
    "godot": e["godot_version"],
    "commit": e["commit"],
    "built_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "smoke": {"frames": int(e["frames"]), "seconds": int(e["smoke_seconds"])},
    "launch_check": e["launch"],
}
with open(sys.argv[1], "w") as f:
    json.dump(info, f, indent=2)
    f.write("\n")
PY
echo "verify: OK ($dmg_name, sha256 $sha256)"
