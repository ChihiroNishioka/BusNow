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

if ! xcrun simctl get_app_container "$UDID" app.busnow.ios >/dev/null 2>&1; then
  if ! xcrun simctl install "$UDID" "$APP_PATH"; then
    codesign --force --deep --sign - --timestamp=none "$APP_PATH"
    xcrun simctl install "$UDID" "$APP_PATH"
  fi
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATUS_TIME="10:30"
if [[ -f "$ROOT/BusNowApp/RecordedFixtures/SOURCE.txt" ]]; then
  STATUS_TIME="$(grep -E '^statusBar=' "$ROOT/BusNowApp/RecordedFixtures/SOURCE.txt" | head -1 | cut -d= -f2-)"
  STATUS_TIME="${STATUS_TIME:-10:30}"
fi
xcrun simctl status_bar "$UDID" override \
  --time "$STATUS_TIME" \
  --batteryState charged \
  --batteryLevel 100 \
  --cellularMode active \
  --wifiBars 3

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
capture approach -busnow-scenario recorded-approach -busnow-start approach
capture departures -busnow-scenario recorded-departures -busnow-start departures
capture departures-finished -busnow-scenario departures-finished -busnow-start departures
capture approach-partial -busnow-scenario approach-partial -busnow-start approach
cp "$ROOT/BusNowApp/RecordedFixtures/SOURCE.txt" "$OUT/SOURCE.txt"
