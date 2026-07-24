#!/usr/bin/env bash
# Scenario #1401 (DETERMINISTIC) — force the launch error path on EVERY OS.
#
# The natural trigger (relying on #1506's Windows-only failure) did not fire
# cleanly, so we force the exact defective path directly: a fake Chrome that
# spawns a helper tree but NEVER opens a DevTools port. That makes
# wait_for_devtools_active_port time out (chrome.rs ~680) -> error path
# (chrome.rs:688 / :696) -> `child.kill()` with NO `child.wait()` and NO
# process-group kill, returning BEFORE a ChromeProcess is built (so Drop /
# ChromeProcess::kill never run).
#
# Predictions (cause is cross-platform; only the *symptom* is not):
#   Unix (Linux/macOS) -> main fake-chrome -> Z <defunct>  (missing wait)
#                         + helper procs orphaned/alive     (missing group-kill)
#   Windows            -> no zombies, but helper procs orphaned/alive
#                         (missing group-kill) = the live tree from #1506's comments
set -uo pipefail
MARK="ABREPRO1401H"

echo "=== #1401 deterministic: forced launch error path ==="
echo "OS: $RUNNER_OS  ARCH: $RUNNER_ARCH"

# 1) Build a NATIVE fake-chrome the Rust launcher can exec directly on any OS.
#    (bun --compile => real .exe on Windows, ELF/Mach-O on Linux/macOS, so
#     std::process::Command::new(path) runs it with no interpreter.)
cat > fake-chrome.ts <<'TS'
// Fake Chrome: spawn idle helpers (a fake GPU/renderer/crashpad tree),
// then hang forever without ever writing DevToolsActivePort or a ws:// url.
if (process.env.ABREPRO_HELPER) {
  setInterval(() => {}, 1e9);                 // helper: idle; carries tag in argv
} else {
  const MARK = process.env.ABREPRO_MARK || "ABREPRO1401H";
  for (let i = 0; i < 3; i++) {
    Bun.spawn([process.execPath, `--abrepro=${MARK}${i}`], {
      env: { ...process.env, ABREPRO_HELPER: "1" },
      stdio: ["ignore", "ignore", "ignore"],
    });
  }
  setInterval(() => {}, 1e9);                 // main: never opens port -> forces timeout
}
TS

bun build fake-chrome.ts --compile --outfile fake-chrome >build.log 2>&1 || { echo "BUILD FAILED"; cat build.log; exit 1; }
EXE="$PWD/fake-chrome"
[ "$RUNNER_OS" = "Windows" ] && EXE="$PWD/fake-chrome.exe"
echo "fake-chrome built: $EXE"

count_helpers() {
  if [ "$RUNNER_OS" = "Windows" ]; then
    # exclude the querying powershell itself (its own CommandLine contains $MARK)
    powershell -NoProfile -Command "(Get-CimInstance Win32_Process | Where-Object { \$_.CommandLine -match '$MARK' -and \$_.CommandLine -notmatch 'CimInstance' } | Measure-Object).Count" | tr -d '\r'
  else
    ps -ax -o command= 2>/dev/null | grep -F -- "$MARK" | grep -v grep | wc -l | tr -d ' '
  fi
}
count_zombies() {
  if [ "$RUNNER_OS" = "Windows" ]; then echo 0; else
    ps -ax -o stat= 2>/dev/null | awk '$1 ~ /^[Zz]/' | wc -l | tr -d ' '
  fi
}

BASE_H=$(count_helpers); BASE_Z=$(count_zombies)
echo "baseline: helpers=$BASE_H zombies=$BASE_Z"

echo "--- open via fake chrome (bounded; forces error path on ALL OSes) ---"
# On Windows the CLI does NOT self-timeout — it retries the daemon<->browser
# connect (os error 10060) and hangs. Bound the foreground wait by PID (portable
# across git-bash/unix); the daemon + any orphaned tree are left behind ON PURPOSE
# so we can count them. That leftover tree IS the #1401 defect.
agent-browser --executable-path "$EXE" open https://example.com >open.txt 2>&1 &
OPID=$!
for _ in $(seq 1 140); do kill -0 "$OPID" 2>/dev/null || break; sleep 1; done
kill "$OPID" 2>/dev/null || true
wait "$OPID" 2>/dev/null || true
echo "[open output]"; cat open.txt 2>/dev/null || true

echo "--- close --all (normal cleanup; cannot reach error-path orphans) ---"
( agent-browser close --all >close.txt 2>&1 & CPID=$!
  for _ in $(seq 1 30); do kill -0 "$CPID" 2>/dev/null || break; sleep 1; done
  kill "$CPID" 2>/dev/null || true ) || true
sleep 3

AFTER_H=$(count_helpers); AFTER_Z=$(count_zombies)
LEAK_H=$(( AFTER_H - BASE_H )); LEAK_Z=$(( AFTER_Z - BASE_Z ))
echo "after: helpers=$AFTER_H zombies=$AFTER_Z  leak_helpers=$LEAK_H leak_zombies=$LEAK_Z"

echo "=== VERDICT ($RUNNER_OS) ==="
if [ "$LEAK_H" -gt 0 ] || [ "$LEAK_Z" -gt 0 ]; then
  echo "REPRODUCED #1401: $LEAK_H orphaned helpers + $LEAK_Z zombies survived cleanup on $RUNNER_OS"
else
  echo "NO LEAK detected on $RUNNER_OS (check open.txt: did the error path run?)"
fi

# safety sweep — never leave the runner dirty
if [ "$RUNNER_OS" = "Windows" ]; then
  powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { \$_.CommandLine -match '$MARK' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue }" || true
  taskkill //F //IM fake-chrome.exe 2>/dev/null || true
else
  pkill -f "$MARK" 2>/dev/null || true
  pkill -f fake-chrome 2>/dev/null || true
fi
echo "=== done ==="
