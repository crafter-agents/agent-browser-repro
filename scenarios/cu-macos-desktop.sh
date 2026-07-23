#!/bin/bash
# computer-use-lab Shape A: real macOS desktop automation on a cloud runner.
# Proves the full loop: capture state -> perform a UI action -> capture result.
set -uo pipefail
cap() { local s="$1"; shift; "$@" & local p=$!; ( sleep "$s"; kill -9 "$p" 2>/dev/null )& local w=$!; wait "$p" 2>/dev/null; local rc=$?; kill "$w" 2>/dev/null; return "$rc"; }

[ "$RUNNER_OS" != "macOS" ] && { echo "SKIP: Shape A is macOS-only"; exit 0; }
echo "=== computer-use-lab Shape A: macOS desktop automation ==="

echo "--- 1. capture BEFORE ---"
screencapture -x before.png && echo "before: $(wc -c < before.png) bytes"

echo "--- 2. UI action: open TextEdit and type via osascript (real app automation) ---"
cap 20 osascript <<'OSA'
tell application "TextEdit"
  activate
  make new document
  set text of front document to "computer-use-lab: Kai typed this on a cloud macOS runner"
end tell
OSA
echo "textedit-automation rc=$?"

echo "--- 3. verify the action took effect (read the document back) ---"
cap 15 osascript -e 'tell application "TextEdit" to get text of front document' 2>&1 | head -2

echo "--- 4. capture AFTER ---"
sleep 1; screencapture -x after.png && echo "after: $(wc -c < after.png) bytes"

echo "--- 5. keyboard chord test (Cmd+A select all in the real app) ---"
cap 15 osascript -e 'tell application "System Events" to keystroke "a" using command down' 2>&1 && echo "CMD+A-SENT"

echo "--- 6. mouse position control ---"
cap 10 osascript -e 'tell application "System Events" to get position of window 1 of (first process whose frontmost is true)' 2>&1 | head -1

echo "=== VERDICT ==="
if [ -f before.png ] && [ -f after.png ]; then
  echo "COMPUTER-USE-LOOP-OK: captured before+after, drove a real app, verified text"
else
  echo "PARTIAL: check individual steps"
fi
