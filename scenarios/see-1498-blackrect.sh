#!/bin/bash
# #1498 POLISHED: apply headless=new CORRECTLY (avoid the comma-split of #1501),
# confirm Chrome is actually headless (no visible window), capture desktop, and
# check for the phantom rectangle. Also record what windows exist, to distinguish
# the bug's layered window from normal Chrome.
set -uo pipefail
[ "$RUNNER_OS" != "Windows" ] && { echo "SKIP"; exit 0; }
git clone --depth 1 https://github.com/crafter-agents/cu.git _cu 2>/dev/null
export PATH="$HOME/.bun/bin:$PATH"; CU="bun _cu/src/cli.ts"

echo "=== #1498 polished: real headless=new, window enumeration + desktop capture ==="
$CU capture before.png; echo "before: $(wc -c <before.png 2>/dev/null)B"

# window list BEFORE (what's on the desktop normally)
powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; Get-Process | Where-Object {\$_.MainWindowTitle -ne ''} | Select-Object ProcessName,MainWindowTitle | Format-Table -Auto" 2>&1 | head -15 > wins-before.txt
echo "windows before:"; cat wins-before.txt

# reporter's setup: bundled Chrome for Testing, headless=new, window 1280x720.
# Pass args individually via env to dodge the comma-split bug (#1501).
export AGENT_BROWSER_ARGS="--headless=new"
echo "-- launch (AGENT_BROWSER_ARGS=--headless=new) --"
( agent-browser open "https://example.com" < /dev/null > ab.log 2>&1 & echo $! > ab.pid )
sleep 8

# is Chrome actually headless? (no MainWindowTitle) and what windows appeared?
powershell -NoProfile -Command "Get-Process | Where-Object {\$_.MainWindowTitle -ne ''} | Select-Object ProcessName,MainWindowTitle | Format-Table -Auto" 2>&1 | head -15 > wins-during.txt
echo "windows during:"; cat wins-during.txt

$CU capture during.png; echo "during: $(wc -c <during.png 2>/dev/null)B"

powershell -NoProfile -Command "Get-Process chrome*,agent-browser* -ErrorAction SilentlyContinue | Stop-Process -Force" 2>/dev/null || true
agent-browser close --all 2>/dev/null || true; sleep 2
$CU capture after.png; echo "after: $(wc -c <after.png 2>/dev/null)B"
echo "=== new windows during vs before = the bug's phantom window candidate ==="
diff wins-before.txt wins-during.txt || echo "(windows changed)"
