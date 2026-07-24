#!/bin/bash
# #1407 v2: isolate the close->open hang. Use HEADLESS (default) not --headed,
# since --headed hangs in CI without a display; test if the hang is about the
# close->open SEQUENCE with output capture, independent of headed.
set -uo pipefail
[ "$RUNNER_OS" != "Windows" ] && { echo "SKIP: Windows only"; exit 0; }
export PATH="$HOME/.bun/bin:$PATH"
echo "=== #1407 v2: close->open sequence with output capture (headless) ==="

powershell -NoProfile -Command '
$ErrorActionPreference="SilentlyContinue"
function TC([int]$secs,[string[]]$abargs){
  $j = Start-Job -ScriptBlock { param($a) $out = & agent-browser @a 2>&1; $out } -ArgumentList (,$abargs)
  $done = Wait-Job $j -Timeout $secs
  if($done){ Receive-Job $j | Out-Null; Remove-Job $j; return $true }
  else { Stop-Job $j; Remove-Job $j -Force; return $false }
}
# headless (no --headed) to avoid the CI-no-display hang; test the SEQUENCE
Write-Host "step1 open:"      ($(TC 35 @("open","https://example.com")))
Write-Host "step2 close:"     ($(TC 20 @("close")))
Write-Host "step3 open-again:" ($(TC 35 @("open","https://example.com")))
Write-Host "step4 close:"     ($(TC 20 @("close")))
# Then the reported --headed variant, expected to hang on open in CI (documents the confound)
Write-Host "--- headed variant (may hang in CI, no display) ---"
Write-Host "headed-open:" ($(TC 30 @("open","--headed","https://example.com")))
& agent-browser close --all 2>&1 | Out-Null
'
echo "=== NOTE: headless sequence tests #1407 core (close->open); --headed needs a"
echo "    real display which CI lacks, so headed hangs are a CI confound, not the bug. ==="
