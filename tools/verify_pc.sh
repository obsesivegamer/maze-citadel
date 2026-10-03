#!/usr/bin/env bash
# Check a Windows or Linux build the way a player meets it: the archive holds
# only MazeCitadel/<executable>, the executable is x86_64 with the game data
# embedded, and the game runs from the unpacked folder (headless autoplay, like
# tools/smoke.sh). Run it on the build's own OS (Git Bash on Windows): it starts
# the game. Writes <archive>.sha256 and build-info-<platform>.json next to the
# archive; the release and the download site read them.
# Usage: tools/verify_pc.sh windows|linux [dist/MazeCitadel-<version>-<platform>-x86_64.<zip|tar.gz>]
#        tools/verify_pc.sh --summary dist/build-info-<platform>.json  (Markdown table for CI)
#   SMOKE_FRAMES=5400     frames for the headless run (90 s of game at x3)
#   LAUNCH_CHECK=1|soft   Linux only: also open a real window and save
#                         launch-linux-full.png; soft only warns on failure.
#                         Opens a window, so outside CI it needs ALLOW_WINDOW=1.
set -euo pipefail
cd "$(dirname "$0")/.."
# Windows has no python3 (the name can be a Microsoft Store stub there).
python=python3
[[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]] && python=python

if [[ "${1:-}" == --summary ]]; then
  info="${2:-}"
  [[ -f "$info" ]] || { echo "No $(basename "$info"): the build or verification failed."; exit 0; }
  "$python" - "$info" <<'PY'
import json, sys
i = json.load(open(sys.argv[1]))
print(f"### Maze Citadel {i['version']} for {i['platform'].title()}: verified\n")
print("| Check | Result |\n|---|---|")
rows = [
    ("File", f"`{i['file']}` ({i['size_bytes'] / 1048576:.1f} MB)"),
    ("SHA-256", f"`{i['sha256']}`"),
    ("Binary", f"{i['arch']}, game data embedded"),
    ("Headless run from the archive", f"{i['smoke']['frames']} frames, {i['smoke']['seconds']} s, no errors"),
    ("Window check (software Vulkan)", i["launch_check"]),
    ("Godot", i["godot"]),
]
for k, v in rows:
    print(f"| {k} | {v} |")
PY
  exit 0
fi

platform="${1:-}"
version=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
case "$platform" in
  windows) bin=MazeCitadel.exe ext=zip ;;
  linux) bin=MazeCitadel.x86_64 ext=tar.gz ;;
  *) echo "usage: tools/verify_pc.sh windows|linux [archive] | --summary <build-info json>" >&2; exit 2 ;;
esac
archive="${2:-dist/MazeCitadel-$version-$platform-x86_64.$ext}"
frames="${SMOKE_FRAMES:-5400}"
launch_check="${LAUNCH_CHECK:-0}"

fail() {
  echo "verify: FAILED: $*"
  exit 1
}
ok() { echo "  ok  $*"; }

[[ -f "$archive" ]] || fail "no archive at $archive (run tools/export_pc.sh $platform first)"
if [[ "$launch_check" != 0 && -z "${CI:-}" && "${ALLOW_WINDOW:-}" != 1 ]]; then
  echo "refusing: LAUNCH_CHECK opens a window; set ALLOW_WINDOW=1 in a screen slot" >&2
  exit 2
fi
out_dir=$(cd "$(dirname "$archive")" && pwd)
name=$(basename "$archive")

echo "== archive: $name"
# Python reads the zip: Git Bash on Windows has no unzip.
if [[ "$ext" == zip ]]; then
  files=$("$python" -c "import sys,zipfile;print('\n'.join(zipfile.ZipFile(sys.argv[1]).namelist()))" \
    "$archive" | tr -d '\r' | grep -v '/$' || true)
else
  files=$(tar -tzf "$archive" | grep -v '/$' || true)
fi
[[ "$files" == "MazeCitadel/$bin" ]] \
  || fail "expected only MazeCitadel/$bin in the archive, got: $(tr '\n' ' ' <<<"$files")"
size_bytes=$(wc -c <"$archive" | tr -d ' ')
unpacked=$(mktemp -d)
trap 'rm -rf "$unpacked"' EXIT
if [[ "$ext" == zip ]]; then
  "$python" -c "import sys,zipfile;zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" \
    "$archive" "$unpacked"
else
  tar -xzf "$archive" -C "$unpacked"
fi
exe="$unpacked/MazeCitadel/$bin"
ok "holds MazeCitadel/$bin only, $((size_bytes / 1048576)) MB"

echo "== executable"
# x86_64 PE or ELF, with the .pck appended: Godot ends an embedded pack with
# its size and the magic "GDPC".
"$python" - "$exe" "$platform" <<'PY' || fail "not an x86_64 executable with embedded game data"
import struct, sys
path, platform = sys.argv[1], sys.argv[2]
data = open(path, "rb").read()
if platform == "windows":
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    assert data[pe:pe + 4] == b"PE\0\0", "no PE header"
    machine = struct.unpack_from("<H", data, pe + 4)[0]
    assert machine == 0x8664, f"PE machine {machine:#x}, not x86_64"
else:
    assert data[:4] == b"\x7fELF", "no ELF header"
    machine = struct.unpack_from("<H", data, 18)[0]
    assert machine == 0x3E, f"ELF machine {machine:#x}, not x86_64"
assert data[-4:] == b"GDPC", "no embedded .pck at the end of the executable"
PY
if [[ "$platform" == linux ]]; then
  [[ -x "$exe" ]] || fail "$bin is not executable after unpacking"
fi
installed_bytes=$(wc -c <"$exe" | tr -d ' ')
ok "x86_64, game data embedded, $((installed_bytes / 1048576)) MB unpacked"
if [[ "$platform" == windows ]]; then
  # Godot fills the version resource from config/version when the preset leaves it empty.
  exe_version=$(powershell -NoProfile -Command \
    "(Get-Item -LiteralPath '$(cygpath -w "$exe")').VersionInfo.ProductVersion" | tr -d '\r')
  [[ "$exe_version" == "$version"* ]] \
    || fail "exe product version '$exe_version' but project.godot says $version"
  ok "product version $exe_version"
fi

echo "== headless run from the unpacked folder ($frames frames, autoplay x3)"
# The Windows .exe is a GUI program and prints nothing to a console, so read
# the engine's own log file on both platforms.
log_file="$unpacked/smoke.log"
start=$(date +%s)
status=0
"$exe" --headless --log-file "$log_file" --fixed-fps 60 --quit-after "$frames" \
  -- --autoplay --speed=3 >/dev/null 2>&1 || status=$?
smoke_seconds=$(($(date +%s) - start))
log=$(cat "$log_file" 2>/dev/null || true)
godot_version=$(sed -n 's/^Godot Engine v\([^ ]*\) .*/\1/p' <<<"$log" | head -1)
[[ -n "$godot_version" ]] || fail "the game wrote no log; it did not start (exit status $status)"
# Same filter as tools/smoke.sh: a forced quit always reports resources in use.
errors=$(grep -E "SCRIPT ERROR|^ERROR|Parse Error" <<<"$log" \
  | grep -v "resources still in use at exit" || true)
if [[ -n "$errors" || "$status" != 0 ]]; then
  echo "$log" | tail -40
  fail "the exported game errored or exited with status $status"
fi
ok "ran $frames frames in ${smoke_seconds}s with no errors (Godot $godot_version)"

launch=skipped
if [[ "$launch_check" != 0 ]]; then
  [[ "$platform" == linux ]] || fail "LAUNCH_CHECK is only supported for the Linux build"
  echo "== window launch (renders a frame and saves launch-linux-full.png)"
  rm -f "$out_dir/launch-linux-full.png"
  "$exe" -w --resolution 1280x800 --fixed-fps 30 --disable-vsync -- \
    --shot="$out_dir/launch-linux" --views=full --settle=120 --autoplay --speed=3 \
    >"$out_dir/launch-linux.log" 2>&1 &
  pid=$!
  for _ in $(seq 600); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  # Godot drops to its OpenGL renderer if Vulkan fails to start; that window
  # proves nothing about the Forward+ path the game ships with.
  if [[ -s "$out_dir/launch-linux-full.png" ]] \
    && grep -qE '^Vulkan .* - Forward\+ - Using Device' "$out_dir/launch-linux.log"; then
    launch=ok
    ok "window opened and rendered with Vulkan Forward+ (launch-linux-full.png)"
  else
    grep -E '^(Vulkan|OpenGL) ' "$out_dir/launch-linux.log" || true
    launch=failed
    tail -20 "$out_dir/launch-linux.log"
    [[ "$launch_check" == soft ]] || fail "the game did not render a frame with Vulkan Forward+"
    echo "  warn the game did not render a frame with Vulkan Forward+ (LAUNCH_CHECK=soft, not fatal)"
  fi
fi

sha256=$("$python" -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$archive")
echo "$sha256  $name" >"$out_dir/$name.sha256"
commit=$(git rev-parse HEAD 2>/dev/null || echo unknown)
export platform name version size_bytes installed_bytes sha256 godot_version commit frames \
  smoke_seconds launch
"$python" - "$out_dir/build-info-$platform.json" <<'PY'
import datetime, json, os, sys
e = os.environ
info = {
    "name": "Maze Citadel",
    "version": e["version"],
    "platform": e["platform"],
    "file": e["name"],
    "size_bytes": int(e["size_bytes"]),
    "installed_bytes": int(e["installed_bytes"]),
    "sha256": e["sha256"],
    "arch": "x86_64",
    "godot": e["godot_version"],
    "commit": e["commit"],
    "built_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "smoke": {"frames": int(e["frames"]), "seconds": int(e["smoke_seconds"])},
    "launch_check": e["launch"],
}
if e["platform"] == "windows":
    info["signature"] = "unsigned"
with open(sys.argv[1], "w", newline="\n") as f:
    json.dump(info, f, indent=2)
    f.write("\n")
PY
echo "verify: OK ($name, sha256 $sha256)"
