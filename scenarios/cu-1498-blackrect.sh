#!/bin/bash
# #1498 v3: cu diff is fixed (self-installs Pillow). Force the exact headless flags.
set -uo pipefail
[ "$RUNNER_OS" != "Windows" ] && { echo "SKIP: Windows only"; exit 0; }
git clone --depth 1 https://github.com/crafter-agents/cu.git _cu 2>/dev/null
CU="_cu/bin/cu"; chmod +x "$CU"
export PATH="$HOME/.bun/bin:$PATH"
# ensure Pillow up front so cu diff works
python -m pip install --quiet Pillow >/dev/null 2>&1 || py -m pip install --quiet Pillow >/dev/null 2>&1 || true
echo "=== #1498 v3: headless=new + window-size, cu diff fixed ==="

$CU capture before.png && echo "before: $(wc -c <before.png)B"

# agent-browser is headless by default; pass the reporter's exact Chrome args
echo "-- launch headless with --headless=new --window-size=1280,720 --"
( agent-browser open "https://example.com" --args "--headless=new,--window-size=1280,720,--no-sandbox" < /dev/null > ab.log 2>&1 & echo $! > ab.pid )
sleep 12
echo "ab pid: $(cat ab.pid 2>/dev/null); ab.log tail:"; tail -2 ab.log 2>/dev/null

$CU capture during.png && echo "during: $(wc -c <during.png)B"
echo "-- diff before vs during --"; $CU diff before.png during.png 2>&1 | tail -2

# kill chrome tree, capture after
powershell -NoProfile -Command "Get-Process chrome*,agent-browser* -ErrorAction SilentlyContinue | Stop-Process -Force" 2>/dev/null || true
agent-browser close --all 2>/dev/null || true
sleep 2
$CU capture after.png && echo "after: $(wc -c <after.png)B"
echo "-- diff during vs after --"; $CU diff during.png after.png 2>&1 | tail -2

echo "=== VERDICT ==="
D1=$($CU diff before.png during.png 2>/dev/null | grep -c CHANGED || true)
D2=$($CU diff during.png after.png 2>/dev/null | grep -c CHANGED || true)
echo "before->during changed: $D1 | during->after changed: $D2"
if [ "${D1:-0}" -gt 0 ] && [ "${D2:-0}" -gt 0 ]; then echo "CU-1498-REPRODUCED: appeared during, gone after kill"
elif [ "${D1:-0}" -gt 0 ]; then echo "CU-1498-PARTIAL: change during session"
else echo "CU-1498-NO-CHANGE"; fi
