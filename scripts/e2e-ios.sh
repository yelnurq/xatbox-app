#!/usr/bin/env bash
# E2E tests of XatBox (integration_test/) on an iOS simulator — the macOS
# counterpart of scripts/e2e-android.ps1. Backends are fakes (FakeHttpAdapter,
# FakeSocket, FakeCallServer): no server and no env file needed.
#
#   scripts/e2e-ios.sh                                        # all flows, "iPhone 17"
#   scripts/e2e-ios.sh integration_test/chat_flow_test.dart   # one flow
#   SIM="iPhone 16" scripts/e2e-ios.sh                        # another simulator
#   KEEP=1 scripts/e2e-ios.sh                                 # leave the simulator running
#
# Needs Xcode with an iOS simulator runtime (xcodebuild -downloadPlatform iOS)
# and Flutter. Details: docs/TESTING.md, docs/IOS.md §8.
set -euo pipefail

SIM="${SIM:-iPhone 17}"
TARGET="${1:-integration_test}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "iOS simulator tests run on macOS only" >&2
  exit 2
fi

udid="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)["devices"].items():
    if "iOS" not in runtime:
        continue
    for d in devices:
        if d["name"] == name:
            print(d["udid"]); sys.exit(0)
' "$SIM" || true)"

if [[ -z "$udid" ]]; then
  runtime="$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
ios = [r for r in json.load(sys.stdin)["runtimes"] if r.get("isAvailable") and r["platform"] == "iOS"]
print(ios[-1]["identifier"] if ios else "")
')"
  if [[ -z "$runtime" ]]; then
    echo "No iOS simulator runtime: run  xcodebuild -downloadPlatform iOS" >&2
    exit 1
  fi
  device_type="com.apple.CoreSimulator.SimDeviceType.${SIM// /-}"
  echo "Creating simulator \"$SIM\" ($runtime)"
  udid="$(xcrun simctl create "$SIM" "$device_type" "$runtime")"
fi

booted_here=0
if ! xcrun simctl list devices booted | grep -q "$udid"; then
  echo "Booting \"$SIM\""
  xcrun simctl boot "$udid"
  booted_here=1
fi
xcrun simctl bootstatus "$udid" -b >/dev/null

cleanup() {
  if [[ "$booted_here" == 1 && "${KEEP:-0}" != 1 ]]; then
    xcrun simctl shutdown "$udid" || true
  fi
}
trap cleanup EXIT

flutter pub get
flutter test "$TARGET" -d "$udid"
