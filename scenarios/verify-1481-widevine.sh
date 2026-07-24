#!/bin/bash
# FIX-VERIFY #1481: is Widevine blocked BECAUSE of --disable-component-update?
# Launch Chrome WITHOUT that flag and check if the Widevine CDM component appears.
# If it does, the flag is the cause -> CONFIRMED. If Widevine is still absent, the
# flag is NOT the (only) cause -> hypothesis weakened.
set -uo pipefail
export PATH="$HOME/.bun/bin:$PATH"
echo "=== fix-verify #1481 on $RUNNER_OS: Widevine with vs without --disable-component-update ==="

CHROME=""
case "$RUNNER_OS" in
  macOS) CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ;;
  Linux) CHROME="$(command -v google-chrome || command -v chromium || echo '')" ;;
  Windows) CHROME="$(powershell -c '(Get-Command chrome.exe).Source' 2>/dev/null | tr -d '\r')" ;;
esac
[ -z "$CHROME" ] || [ ! -e "$CHROME" ] && { echo "no system chrome found on $RUNNER_OS"; }

DIR1="$PWD/prof-with-block"; DIR2="$PWD/prof-no-block"
echo "-- WITH --disable-component-update (agent-browser default): does Widevine dir appear? --"
"$CHROME" --headless=new --disable-component-update --user-data-dir="$DIR1" --remote-debugging-port=0 about:blank >/dev/null 2>&1 &
P=$!; sleep 8; kill $P 2>/dev/null
W1=$(find "$DIR1" -iname "*widevine*" -o -iname "*WidevineCdm*" 2>/dev/null | head -1)
echo "widevine with block: ${W1:-ABSENT}"

echo "-- WITHOUT the flag (the proposed fix): does Widevine appear now? --"
"$CHROME" --headless=new --user-data-dir="$DIR2" --remote-debugging-port=0 about:blank >/dev/null 2>&1 &
P=$!; sleep 12; kill $P 2>/dev/null
W2=$(find "$DIR2" -iname "*widevine*" -o -iname "*WidevineCdm*" 2>/dev/null | head -1)
echo "widevine without block: ${W2:-ABSENT}"

echo "=== VERDICT ==="
if [ -z "$W1" ] && [ -n "$W2" ]; then echo "CONFIRMED-1481: Widevine appears only WITHOUT the flag -> --disable-component-update is the cause"
elif [ -n "$W2" ] && [ -n "$W1" ]; then echo "BOTH-HAVE: Widevine present either way -> flag is not the blocker (hypothesis wrong)"
else echo "NEITHER: Widevine absent both ways -> needs component-update time or network; inconclusive on this runner"; fi
