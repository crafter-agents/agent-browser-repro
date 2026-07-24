#!/bin/bash
# #1498 SEE IT: cu captures the Windows desktop while agent-browser runs with the
# reporter's EXACT flags. Instead of a pixel heuristic, upload the images so Kai
# can LOOK for the black rectangle. cu already proved it captures the desktop.
set -uo pipefail
[ "$RUNNER_OS" != "Windows" ] && { echo "SKIP"; exit 0; }
git clone --depth 1 https://github.com/crafter-agents/cu.git _cu 2>/dev/null
export PATH="$HOME/.bun/bin:$PATH"; CU="bun _cu/src/cli.ts"

echo "=== #1498 SEE IT: capture desktop before / during / after ==="
$CU capture before.png; echo "before: $(wc -c <before.png 2>/dev/null)B"

# reporter's exact setup: agent-browser + Chrome for Testing + --headless=new + --window-size=1280,720
echo "-- launching agent-browser with reporter flags --"
( agent-browser open "https://example.com" --args "--headless=new,--window-size=1280,720" < /dev/null > ab.log 2>&1 & echo $! > ab.pid )
sleep 8

# capture the desktop DURING (the rectangle appears while the session is alive)
$CU capture during.png; echo "during: $(wc -c <during.png 2>/dev/null)B"
sleep 4
$CU capture during2.png; echo "during2: $(wc -c <during2.png 2>/dev/null)B"

# kill the tree (reporter: killing removes the rectangle) and capture after
powershell -NoProfile -Command "Get-Process chrome*,agent-browser* -ErrorAction SilentlyContinue | Stop-Process -Force" 2>/dev/null || true
agent-browser close --all 2>/dev/null || true
sleep 2
$CU capture after.png; echo "after: $(wc -c <after.png 2>/dev/null)B"

echo "=== images captured — inspect visually for a black rectangle ==="
ls -la *.png 2>/dev/null
