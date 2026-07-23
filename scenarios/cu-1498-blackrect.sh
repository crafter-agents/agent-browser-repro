#!/bin/bash
# Reproduce agent-browser #1498 (Windows: headless Chrome leaves a black rectangle
# on the desktop) USING cu to capture the desktop before/after a headless session.
# cu is the right tool: this is a DESKTOP-visual bug, invisible to browser tools.
set -uo pipefail
[ "$RUNNER_OS" != "Windows" ] && { echo "SKIP: #1498 is Windows-desktop-visual only"; exit 0; }

git clone --depth 1 https://github.com/crafter-agents/cu.git _cu 2>/dev/null
CU="_cu/bin/cu"; chmod +x "$CU"
echo "=== cu-1498 black-rectangle on Windows ==="

# 1. cu captures the clean desktop
$CU capture desktop-clean.png && echo "clean desktop captured"

# 2. install + run a headless agent-browser session (the thing that leaves the rect)
export PATH="$HOME/.bun/bin:$PATH"
( agent-browser open https://example.com < /dev/null & AP=$!; sleep 8; kill -9 $AP 2>/dev/null ) 2>&1 | tail -2
echo "headless session ran"

# 3. cu captures the desktop AFTER — is there a black rectangle?
sleep 2
$CU capture desktop-after.png && echo "post-session desktop captured"

# 4. heuristic: compare dark-pixel ratio. A black rectangle raises it notably.
powershell -NoProfile -Command '
Add-Type -AssemblyName System.Drawing
function DarkRatio($p){ $b=[System.Drawing.Bitmap]::FromFile((Resolve-Path $p)); $dark=0;$n=0; for($y=0;$y -lt $b.Height;$y+=8){for($x=0;$x -lt $b.Width;$x+=8){$c=$b.GetPixel($x,$y); if($c.R -lt 20 -and $c.G -lt 20 -and $c.B -lt 20){$dark++}; $n++}}; $b.Dispose(); return [math]::Round(100*$dark/$n,2) }
$before=DarkRatio "desktop-clean.png"; $after=DarkRatio "desktop-after.png"
Write-Host "dark% before=$before after=$after delta=$([math]::Round($after-$before,2))"
if(($after-$before) -gt 3){ Write-Host "CU-1498-REPRODUCED: dark region appeared after headless session (black rectangle)" }
else{ Write-Host "CU-1498-NOT-REPRODUCED: no significant dark region delta" }
'
# rename for artifact upload
cp desktop-after.png after.png 2>/dev/null; cp desktop-clean.png before.png 2>/dev/null
echo "=== done ==="
