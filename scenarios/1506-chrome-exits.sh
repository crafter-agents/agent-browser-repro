#!/bin/bash
# Scenario #1506 v2 — Chrome exits early on Windows. Every agent-browser call is
# hard-capped: a hang IS a signal (matches the #1437 wedge pattern), never an
# infinite runner burn.
set -uo pipefail

# portable hard-timeout wrapper (no coreutils `timeout` on macOS runner)
cap() {
  local secs="$1"; shift
  "$@" & local p=$!
  ( sleep "$secs"; kill -9 "$p" 2>/dev/null; echo "[[HANG: killed after ${secs}s]]" ) & local w=$!
  wait "$p" 2>/dev/null; local rc=$?
  kill "$w" 2>/dev/null; wait "$w" 2>/dev/null
  return "$rc"
}

echo "=== #1506: Chrome-exits-early / hang on open ==="
echo "OS: $RUNNER_OS  ARCH: $RUNNER_ARCH"

echo "--- attempt 1: plain open (cap 60s) ---"
cap 60 agent-browser open https://example.com 2>&1 | tee out1.txt
echo "open rc path done"

echo "--- snapshot to confirm session (cap 30s) ---"
cap 30 agent-browser snapshot 2>&1 | head -3 | tee snap.txt || true

echo "--- attempt 2: --no-sandbox (the issue hint, cap 60s) ---"
cap 20 agent-browser close --all 2>/dev/null || true
cap 60 agent-browser open https://example.com --args "--no-sandbox" 2>&1 | tee out2.txt

echo "=== VERDICT SIGNALS ==="
HANG1=$(grep -c "HANG" out1.txt || true)
EARLY1=$(grep -ci "exited early\|DevToolsActivePort\|Chrome exited before" out1.txt || true)
if [ "${EARLY1:-0}" -gt 0 ]; then
  echo "REPRODUCED: Chrome exits early on plain open ($RUNNER_OS)"
elif [ "${HANG1:-0}" -gt 0 ]; then
  echo "REPRODUCED (hang variant): open never returned on $RUNNER_OS (daemon wedged)"
else
  echo "DOES NOT REPRODUCE on $RUNNER_OS: open returned normally"
fi
echo "--no-sandbox path: $(grep -ci 'exited early\|HANG' out2.txt || echo 0) failure signals"
cap 15 agent-browser close --all 2>/dev/null || true
