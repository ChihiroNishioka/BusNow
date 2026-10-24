#!/usr/bin/env bash
# Launch the already-built BusNow Watch app and save the two boards plus complication views.
# The complication images are the widget views rendered inside the app from a recorded fetch,
# not a photograph of a watch face. See RecordedFixtures/SOURCE.txt.
# Usage: capture-watch-screenshots.sh <BusNowWatch.app> <output-dir> <simulator-udid>
set -euo pipefail

APP_PATH="${1:-}"
OUT="${2:-}"
UDID="${3:-}"

if [[ -z "$APP_PATH" || -z "$OUT" || -z "$UDID" ]]; then
  echo "usage: $0 <BusNowWatch.app> <output-dir> <simulator-udid>" >&2
  exit 2
fi
if [[ ! -d "$APP_PATH" ]]; then
  echo "app not found: $APP_PATH" >&2
  exit 1
fi
mkdir -p "$OUT"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="app.busnow.ios.watchkitapp"

xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b || true

if ! xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" >/dev/null 2>&1; then
  if ! xcrun simctl install "$UDID" "$APP_PATH"; then
    codesign --force --deep --sign - --timestamp=none "$APP_PATH" || true
    xcrun simctl install "$UDID" "$APP_PATH"
  fi
fi

STATUS_TIME=""
if [[ -f "$ROOT/BusNowApp/RecordedFixtures/SOURCE.txt" ]]; then
  STATUS_TIME="$(grep -E '^statusBar=' "$ROOT/BusNowApp/RecordedFixtures/SOURCE.txt" | head -1 | cut -d= -f2- || true)"
fi
if [[ -n "$STATUS_TIME" ]]; then
  xcrun simctl status_bar "$UDID" override --time "$STATUS_TIME" || true
fi

capture() {
  local name="$1"
  shift
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" "$@" >/dev/null
  sleep 4
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png"
  echo "wrote $OUT/$name.png"
}

capture watch-fujimidai -busnow-scenario recorded-approach -busnow-start approach
capture watch-mizonokuchi -busnow-scenario recorded-departures -busnow-start departures
capture watch-complications -busnow-scenario recorded-complications
if [[ -f "$ROOT/BusNowApp/RecordedFixtures/SOURCE.txt" ]]; then
  cp "$ROOT/BusNowApp/RecordedFixtures/SOURCE.txt" "$OUT/SOURCE.txt"
fi
