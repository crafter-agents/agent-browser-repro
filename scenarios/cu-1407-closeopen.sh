#!/bin/bash
# Reproduce agent-browser #1407: Windows CLI hangs on close->open sequence when
# PowerShell captures output. Cross-platform: Windows is the target, mac/linux
# are controls (issue says it does NOT happen there).
set -uo pipefail
export PATH="$HOME/.bun/bin:$PATH"
echo "=== #1407 close->open hang on $RUNNER_OS ==="

if [ "$RUNNER_OS" = "Windows" ]; then
  # Reproduce the EXACT reported pattern: PowerShell capturing output around
  # close then open. Cap it hard; if it hangs, that IS the repro.
  powershell -NoProfile -Command '
    $ErrorActionPreference="SilentlyContinue"
    function CapCmd($secs,$args){
      $job = Start-Job -ScriptBlock { param($a) & agent-browser @a 2>&1 } -ArgumentList (,$args)
      if(Wait-Job $job -Timeout $secs){ Receive-Job $job; Remove-Job $job; return $true }
      else { Stop-Job $job; Remove-Job $job -Force; return $false }
    }
    Write-Host "-- close (capture) --"
    $r1 = CapCmd 20 @("close","--all"); Write-Host "close returned: $r1"
    Write-Host "-- open (capture) — this is where #1407 hangs --"
    $r2 = CapCmd 25 @("open","https://example.com"); Write-Host "open returned: $r2"
    if(-not $r2){ Write-Host "CU-1407-REPRODUCED: open hung after close when output captured (Windows)" }
    else { Write-Host "CU-1407-NOT-REPRODUCED: open returned normally" }
    & agent-browser close --all 2>&1 | Out-Null
  '
else
  # control: same sequence with output capture; issue says no hang on mac/linux
  echo "-- close (captured) --"; OUT1=$( ( agent-browser close --all < /dev/null & P=$!; (sleep 20; kill -9 $P 2>/dev/null; echo HANG)& wait $P ) 2>&1 ); echo "close: ${OUT1:0:40}"
  echo "-- open (captured) --"; OUT2=$( ( agent-browser open https://example.com < /dev/null & P=$!; (sleep 25; kill -9 $P 2>/dev/null; echo HANG)& wait $P ) 2>&1 )
  agent-browser close --all >/dev/null 2>&1 || true
  if echo "$OUT2" | grep -q HANG; then echo "CU-1407-CONTROL-HANG on $RUNNER_OS (unexpected)"; else echo "CU-1407-CONTROL-OK on $RUNNER_OS (no hang, as issue says)"; fi
fi
echo "=== done $RUNNER_OS ==="
