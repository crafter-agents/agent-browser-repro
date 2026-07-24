#!/bin/bash
# Scenario #1401 — orphaned / zombie Chrome tree after a FAILED launch.
#
# Mechanism (cli/src/native/cdp/chrome.rs:688 and :696): the launch error path
# does `child.kill()` with NO `child.wait()` and NO process-group kill, and it
# returns BEFORE a ChromeProcess is constructed -- so the full teardown in
# ChromeProcess::kill (chrome.rs:22-34: child.kill + libc::kill(-pgid,SIGKILL)
# + child.wait), reached via Drop (chrome.rs:67-69), never runs.
#
# Prediction (cause is cross-platform, symptom is not):
#   Windows     -> failed open (#1506) leaves the whole chrome.exe tree ALIVE
#                  (no zombies on Windows; children never signaled).
#   Linux/macOS -> open SUCCEEDS, ChromeProcess+Drop clean up -> NO leak (CONTROL).
set -uo pipefail

cap() { local s="$1"; shift; "$@" & local p=$!; ( sleep "$s"; kill -9 "$p" 2>/dev/null ) & local w=$!; wait "$p" 2>/dev/null; local rc=$?; kill "$w" 2>/dev/null; return "$rc"; }

MARK="agent-browser-chrome"   # our launches' temp --user-data-dir marker

count_tree() {
  if [ "$RUNNER_OS" = "Windows" ]; then
    powershell -NoProfile -Command "(Get-CimInstance Win32_Process | Where-Object { \$_.CommandLine -match '$MARK' } | Measure-Object).Count" | tr -d '\r'
  else
    ps -ax -o command= 2>/dev/null | grep -F -- "$MARK" | grep -v grep | wc -l | tr -d ' '
  fi
}
count_zombies() {
  if [ "$RUNNER_OS" = "Windows" ]; then echo 0; else
    ps -ax -o stat= 2>/dev/null | awk '$1 ~ /^[Zz]/' | wc -l | tr -d ' '
  fi
}

echo "=== #1401: orphan/zombie Chrome tree after failed launch ==="
echo "OS: $RUNNER_OS  ARCH: $RUNNER_ARCH"

BASE_TREE=$(count_tree); BASE_Z=$(count_zombies)
echo "baseline: tree=$BASE_TREE zombies=$BASE_Z"

echo "--- forcing a launch (fails on Windows per #1506 -> error path) ---"
cap 60 agent-browser open https://example.com 2>&1 | tee open.txt || true

# Normal session cleanup. Error-path orphans are owned by NO session, so
# close --all cannot reach them -- that is precisely the #1401 defect.
echo "--- close --all (normal cleanup; cannot reap untracked orphans) ---"
cap 25 agent-browser close --all 2>&1 | tee close.txt || true
sleep 3

AFTER_TREE=$(count_tree); AFTER_Z=$(count_zombies)
echo "after:    tree=$AFTER_TREE zombies=$AFTER_Z"

LEAK_TREE=$(( AFTER_TREE - BASE_TREE ))
LEAK_Z=$(( AFTER_Z - BASE_Z ))
FAILED=$(grep -ci "exited early\|DevToolsActivePort\|Chrome exited before\|also tried parsing stderr" open.txt || true)

echo "=== VERDICT SIGNALS ==="
echo "leaked_tree_procs=$LEAK_TREE leaked_zombies=$LEAK_Z failed_launch_signal=$FAILED"
if [ "$LEAK_TREE" -gt 0 ] || [ "$LEAK_Z" -gt 0 ]; then
  echo "REPRODUCED (#1401): $LEAK_TREE orphaned chrome procs + $LEAK_Z zombies survived cleanup on $RUNNER_OS"
elif [ "$FAILED" -gt 0 ]; then
  echo "INCONCLUSIVE: launch failed but no residual tree detected on $RUNNER_OS"
else
  echo "CONTROL (no leak): launch succeeded, ChromeProcess::Drop cleaned up on $RUNNER_OS (expected on Linux/macOS)"
fi

# safety sweep -- never leave the runner dirty
if [ "$RUNNER_OS" = "Windows" ]; then
  powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { \$_.CommandLine -match '$MARK' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue }" || true
else
  pkill -f "$MARK" 2>/dev/null || true
fi
