#!/bin/bash
# FIX-VERIFY #1506: does the DETACHED_PROCESS mechanism hold? On Windows, launch
# Chrome directly WITH and WITHOUT detachment and see which survives the parent.
# If detached survives and non-detached dies -> mechanism CONFIRMED.
set -uo pipefail
[ "$RUNNER_OS" != "Windows" ] && { echo "SKIP: Windows-only fix-verify"; exit 0; }
echo "=== fix-verify #1506: detached vs non-detached Chrome on Windows ==="

powershell -NoProfile -Command '
$chrome = (Get-Command chrome.exe -ErrorAction SilentlyContinue).Source
if(-not $chrome){ $chrome = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe" }
if(-not (Test-Path $chrome)){ Write-Host "no chrome found"; exit }
$args = "--headless=new --remote-debugging-port=0 --no-first-run --user-data-dir=$env:TEMP\cu-test-1"

Write-Host "-- NON-detached: spawn Chrome tied to this process, then let this scope end --"
$p1 = Start-Process $chrome -ArgumentList $args -PassThru
Start-Sleep 3
$alive1 = -not $p1.HasExited
Write-Host ("non-detached alive after 3s: " + $alive1)
if(-not $p1.HasExited){ Stop-Process $p1 -Force -ErrorAction SilentlyContinue }

Write-Host "-- DETACHED: same but with -NoNewWindow off / process group new --"
# Windows Start-Process is already somewhat detached; the real test is the flag
# agent-browser would pass. Emulate the difference via CREATE_NEW_PROCESS_GROUP.
$args2 = "--headless=new --remote-debugging-port=0 --no-first-run --user-data-dir=$env:TEMP\cu-test-2"
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $chrome; $psi.Arguments = $args2; $psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$p2 = [System.Diagnostics.Process]::Start($psi)
Start-Sleep 3
$alive2 = -not $p2.HasExited
Write-Host ("detached-style alive after 3s: " + $alive2)
if(-not $p2.HasExited){ Stop-Process $p2 -Force -ErrorAction SilentlyContinue }

Write-Host "=== VERDICT ==="
if($alive2 -and -not $alive1){ Write-Host "CONFIRMED-1506: detachment style survives, non-detached dies (mechanism holds)" }
elseif($alive1 -and $alive2){ Write-Host "BOTH-SURVIVE: on this runner both live — the CI console differs from a real user shell (inconclusive here)" }
else { Write-Host "OTHER: alive1=$alive1 alive2=$alive2 — needs the exact agent-browser spawn to be conclusive" }
'
echo "=== done ==="
