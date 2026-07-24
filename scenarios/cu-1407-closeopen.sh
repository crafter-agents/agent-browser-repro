#!/bin/bash
# #1407 EXACT repro: Windows PowerShell $output = & agent-browser open --headed,
# then close, then open --headed AGAIN hangs. Version 0.27.0 (as reported).
set -uo pipefail
[ "$RUNNER_OS" != "Windows" ] && { echo "SKIP: #1407 is Windows PowerShell only"; exit 0; }
export PATH="$HOME/.bun/bin:$PATH"

echo "=== #1407 exact repro on Windows (--headed + \$output capture) ==="

# Run the EXACT reported sequence inside PowerShell, each step time-boxed via Job.
powershell -NoProfile -Command '
$ErrorActionPreference="SilentlyContinue"
function TimedCapture([int]$secs,[string[]]$abargs){
  $j = Start-Job -ScriptBlock { param($a) $out = & agent-browser @a 2>&1; $out } -ArgumentList (,$abargs)
  if(Wait-Job $j -Timeout $secs){ $r=Receive-Job $j; Remove-Job $j; return @{ok=$true} }
  else { Stop-Job $j; Remove-Job $j -Force; return @{ok=$false} }
}
Write-Host "-- step 1: open --headed (capture) --"
$s1 = TimedCapture 40 @("open","--headed","https://example.com"); Write-Host ("step1 returned: " + $s1.ok)
Write-Host "-- step 2: close (capture) --"
$s2 = TimedCapture 25 @("close"); Write-Host ("step2 returned: " + $s2.ok)
Write-Host "-- step 3: open --headed AGAIN (capture) — #1407 says HANGS here --"
$s3 = TimedCapture 40 @("open","--headed","https://example.com"); Write-Host ("step3 returned: " + $s3.ok)

if($s1.ok -and $s2.ok -and (-not $s3.ok)){
  Write-Host "CU-1407-REPRODUCED: second open --headed hung with output capture (steps 1,2 ok, 3 hung)"
} elseif(-not $s3.ok){
  Write-Host "CU-1407-PARTIAL: third step hung but earlier steps had issues too"
} else {
  Write-Host "CU-1407-NOT-REPRODUCED: all three returned"
}
& agent-browser close 2>&1 | Out-Null
& agent-browser close 2>&1 | Out-Null
'
echo "=== done ==="
