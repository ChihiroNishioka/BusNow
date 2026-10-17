#!/usr/bin/env bash
# Launch the already-built BusNow simulator app and save enamel-board screenshots.
# Usage: capture-screenshots.sh <BusNow.app> <output-dir> [simulator-udid]
set -euo pipefail

APP_PATH="${1:-}"
OUT="${2:-}"
UDID="${3:-${SIMULATOR_UDID:-}}"

if [[ -z "$APP_PATH" || -z "$OUT" ]]; then
  echo "usage: $0 <BusNow.app> <output-dir> [simulator-udid]" >&2
  exit 2
fi
if [[ ! -d "$APP_PATH" ]]; then
  echo "app not found: $APP_PATH" >&2
  exit 1
fi
mkdir -p "$OUT"

if [[ -z "$UDID" ]]; then
  echo "simulator udid is required" >&2
  exit 1
fi

xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b

if ! codesign --verify "$APP_PATH" >/dev/null 2>&1; then
  codesign --force --sign - --timestamp=none "$APP_PATH"
fi
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl status_bar "$UDID" override \
  --time "10:30" \
  --batteryState charged \
  --batteryLevel 100 \
  --cellularMode active \
  --wifiBars 3 || true

capture() {
  local name="$1"
  shift
  xcrun simctl terminate "$UDID" app.busnow.ios >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" app.busnow.ios "$@" >/dev/null
  sleep 3
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png"
  echo "wrote $OUT/$name.png"
}

capture home -busnow-scenario home
capture approach -busnow-scenario approach -busnow-start approach
capture departures -busnow-scenario departures -busnow-start departures
capture finished -busnow-scenario departures-finished -busnow-start departures
capture approach-partial -busnow-scenario approach-partial -busnow-start approach
