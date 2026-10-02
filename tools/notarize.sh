#!/usr/bin/env bash
# Send a Developer ID-signed .dmg to Apple's notary service, wait for the
# verdict, and staple the ticket so Gatekeeper accepts it offline.
# Needs APPLE_ID, APPLE_TEAM_ID and APPLE_APP_PASSWORD (an app-specific
# password from account.apple.com). See docs/RELEASING.md.
# Usage: tools/notarize.sh dist/MazeCitadel-<version>.dmg
set -euo pipefail
dmg="${1:?usage: tools/notarize.sh <dmg>}"
: "${APPLE_ID:?set APPLE_ID}" "${APPLE_TEAM_ID:?set APPLE_TEAM_ID}" \
  "${APPLE_APP_PASSWORD:?set APPLE_APP_PASSWORD}"
auth=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD")
json_field() {
  python3 -c 'import json, sys
try: print(json.load(sys.stdin).get(sys.argv[1], ""))
except ValueError: print("")' "$1"
}

echo "== notarize $(basename "$dmg")"
result=$(xcrun notarytool submit "$dmg" "${auth[@]}" --wait --timeout 45m \
  --output-format json) || true
[[ -n "$result" ]] || result='{}'
status=$(json_field status <<<"$result")
id=$(json_field id <<<"$result")
echo "notary: submission ${id:-none}, status ${status:-unknown}"
if [[ "$status" != Accepted ]]; then
  echo "$result"
  [[ -n "$id" ]] && xcrun notarytool log "$id" "${auth[@]}" || true
  echo "notarize: FAILED"
  exit 1
fi
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
echo "notarize: OK (ticket stapled)"
