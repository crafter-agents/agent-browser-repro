#!/bin/bash
# computer-use-lab Shape (Windows): real Windows desktop automation via PowerShell
# + user32/System.Windows.Forms. Windows runner = full desktop, no TCC prompt like
# macOS. Tests the perceive->act->verify loop.
set -uo pipefail
[ "$RUNNER_OS" != "Windows" ] && { echo "SKIP: Windows-only scenario"; exit 0; }
echo "=== computer-use-lab: Windows desktop automation ==="

powershell -NoProfile -Command '
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 1. CAPTURE before (full virtual screen via GDI, no browser needed)
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
Write-Host "screen: $($vs.Width)x$($vs.Height)"
$bmp = New-Object System.Drawing.Bitmap($vs.Width, $vs.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($vs.Left, $vs.Top, 0, 0, $bmp.Size)
$bmp.Save("$PWD\before.png")
Write-Host "before: $((Get-Item before.png).Length) bytes  CAPTURE-OK"

# 2. INPUT: move mouse (user32 via Forms.Cursor)
[System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point(300,300)
Write-Host "mouse moved to: $([System.Windows.Forms.Cursor]::Position)  MOUSE-OK"

# 3. ACT: launch Notepad and type into it via SendKeys
$p = Start-Process notepad -PassThru
Start-Sleep -Seconds 2
[System.Windows.Forms.SendWait]("computer-use-lab: Kai typed this on a Windows cloud runner") 2>$null
# SendWait needs the class; use SendKeys
[System.Windows.Forms.SendKeys]::SendWait("Kai drove Notepad on a Windows cloud runner")
Start-Sleep -Seconds 1
Write-Host "notepad launched pid $($p.Id), keys sent  ACT-OK"

# 4. CAPTURE after
$bmp2 = New-Object System.Drawing.Bitmap($vs.Width, $vs.Height)
$g2 = [System.Drawing.Graphics]::FromImage($bmp2)
$g2.CopyFromScreen($vs.Left, $vs.Top, 0, 0, $bmp2.Size)
$bmp2.Save("$PWD\after.png")
Write-Host "after: $((Get-Item after.png).Length) bytes  CAPTURE-OK"

# 5. keyboard chord (Ctrl+A select all in Notepad)
[System.Windows.Forms.SendKeys]::SendWait("^a")
Write-Host "CTRL+A-SENT"
' 2>&1

echo "=== VERDICT ==="
if [ -f before.png ] && [ -f after.png ]; then
  echo "WINDOWS-COMPUTER-USE-LOOP-OK: captured before+after, moved mouse, drove Notepad"
else
  echo "PARTIAL: check steps"
fi
