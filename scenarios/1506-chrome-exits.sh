#!/bin/bash
# Scenario: reproduce agent-browser #1506 — Chrome exits early (exit 0) without
# DevToolsActivePort. Reported on Windows 11. Runs on the matrix; Windows is the
# faithful target, Linux/macOS are controls.
set -uo pipefail
echo "=== #1506: does 'agent-browser open' fail with Chrome-exits-early? ==="

echo "--- attempt 1: plain open ---"
agent-browser open https://example.com 2>&1 | tee out1.txt
rc1=$?
echo "exit: $rc1"

echo "--- did it produce a working session? (snapshot should work if open succeeded) ---"
agent-browser snapshot 2>&1 | head -3 || echo "snapshot failed"

echo "--- attempt 2: with --no-sandbox (the issue's hint) ---"
agent-browser close --all 2>/dev/null || true
agent-browser open https://example.com --args "--no-sandbox" 2>&1 | tee out2.txt
echo "exit: $?"

echo "=== VERDICT SIGNALS ==="
if grep -qi "exited early\|without writing DevToolsActivePort\|Chrome exited before" out1.txt; then
  echo "REPRODUCED: Chrome exits early on plain open"
  if grep -qi "exited early\|DevToolsActivePort" out2.txt; then
    echo "  and --no-sandbox does NOT fix it"
  else
    echo "  but --no-sandbox WORKS around it (points at sandbox/permission cause)"
  fi
else
  echo "DOES NOT REPRODUCE on this OS: open succeeded"
fi
