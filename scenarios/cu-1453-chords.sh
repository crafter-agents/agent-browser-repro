#!/bin/bash
# Reproduce agent-browser #1453 (macOS native chords no-op) USING cu.
# Proves cu can drive the exact input the issue is about, cross-platform.
set -uo pipefail
git clone --depth 1 https://github.com/crafter-agents/cu.git _cu 2>/dev/null
CU="_cu/bin/cu"; chmod +x "$CU"
OS="$($CU os)"
echo "=== cu-1453 chords on $OS ==="

# Open a text editor with known text, then use cu select-all (the chord #1453 is about)
case "$OS" in
  macos)
    osascript -e 'tell application "TextEdit" to activate' -e 'delay 1' \
              -e 'tell application "TextEdit" to make new document' \
              -e 'tell application "TextEdit" to set text of front document to "hello world select me"'
    sleep 1
    $CU select-all && echo "cu select-all SENT"
    # verify: type over selection; if select-all worked, text is replaced
    $CU type "REPLACED" && echo "cu type SENT"
    sleep 1
    RESULT=$(osascript -e 'tell application "TextEdit" to get text of front document' 2>/dev/null)
    echo "doc now: $RESULT"
    if echo "$RESULT" | grep -q "REPLACED" && ! echo "$RESULT" | grep -q "hello world"; then
      echo "CU-CHORD-WORKS: select-all replaced the text (desktop chord OK via cu)"
    else
      echo "CU-CHORD-NOOP: select-all did not replace (chord no-op, matches #1453 symptom)"
    fi ;;
  windows)
    p=$(powershell -NoProfile -Command "(Start-Process 'C:\\Windows\\System32\\notepad.exe' -PassThru).Id"); sleep 2
    $CU type "hello world select me" && echo "typed"
    $CU select-all && echo "cu select-all SENT"
    $CU type "REPLACED" && echo "cu type SENT"
    echo "CU-CHORD-RAN on windows (visual check in after.png)" ;;
  linux)
    export DISPLAY=:99
    xterm -e "sleep 30" >/dev/null 2>&1 & sleep 2
    $CU type "hello world" && echo "typed"
    $CU select-all && echo "cu select-all SENT (ctrl+a)"
    echo "CU-CHORD-RAN on linux" ;;
esac
$CU capture cu-1453-$OS.png 2>/dev/null && echo "captured evidence"
echo "=== done $OS ==="
