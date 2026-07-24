#!/bin/bash
# #1498 EXACT repro: --headless=new --window-size=1280,720 leaves a software-drawn
# black rectangle visible in Windows screenshot capture. Uses cu capture + cu diff.
set -uo pipefail
[ "$RUNNER_OS" != "Windows" ] && { echo "SKIP: #1498 Windows only"; exit 0; }
git clone --depth 1 https://github.com/crafter-agents/cu.git _cu 2>/dev/null
CU="_cu/bin/cu"; chmod +x "$CU"
export PATH="$HOME/.bun/bin:$PATH"
echo "=== #1498 exact: --headless=new --window-size=1280,720 ==="

$CU capture before.png && echo "before captured"

# launch with the EXACT flags the reporter used, headless, leave it running
echo "-- launching headless Chrome via agent-browser with reported flags --"
( agent-browser open "https://example.com" --args "--headless=new,--window-size=1280,720" < /dev/null > ab.log 2>&1 & echo $! > ab.pid )
sleep 10
echo "agent-browser pid: $(cat ab.pid 2>/dev/null)"

# capture WHILE the session is alive (rectangle appears during the session)
$CU capture during.png && echo "during captured"

echo "-- cu diff before vs during: did a rectangle appear? --"
$CU diff before.png during.png 2>&1 | tail -2

# kill the chrome tree (reporter: killing it removes the rectangle)
powershell -NoProfile -Command "Get-Process | Where-Object { \$_.ProcessName -match 'chrome|agent-browser' } | Stop-Process -Force" 2>/dev/null || true
agent-browser close --all 2>/dev/null || true
sleep 2
$CU capture after.png && echo "after captured (post-kill)"

echo "-- cu diff during vs after: did killing remove the rectangle? --"
$CU diff during.png after.png 2>&1 | tail -2

echo "=== VERDICT ==="
D1=$($CU diff before.png during.png 2>/dev/null | grep -c CHANGED || true)
D2=$($CU diff during.png after.png 2>/dev/null | grep -c CHANGED || true)
if [ "${D1:-0}" -gt 0 ] && [ "${D2:-0}" -gt 0 ]; then
  echo "CU-1498-REPRODUCED: rectangle appeared during session AND vanished after kill (matches report)"
elif [ "${D1:-0}" -gt 0 ]; then
  echo "CU-1498-PARTIAL: something appeared during session (rectangle candidate)"
else
  echo "CU-1498-NOT-REPRODUCED: no visual change with the reported flags"
fi
