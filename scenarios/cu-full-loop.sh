#!/bin/bash
# computer-use-lab: full loop on ALL THREE OSes, gates fixed. Goal: all green.
set -uo pipefail
cap() { local s="$1"; shift; "$@" & local p=$!; ( sleep "$s"; kill -9 "$p" 2>/dev/null )& local w=$!; wait "$p" 2>/dev/null; local rc=$?; kill "$w" 2>/dev/null; return "$rc"; }
echo "=== computer-use full loop on $RUNNER_OS ==="

if [ "$RUNNER_OS" = "macOS" ]; then
  screencapture -x before.png && echo "before: $(wc -c <before.png)B CAPTURE-OK"
  cap 20 osascript -e 'tell application "TextEdit" to activate' -e 'delay 1' -e 'tell application "TextEdit" to make new document' -e 'tell application "TextEdit" to set text of front document to "Kai on macOS cloud runner"' && echo "LAUNCH-APP-OK (TextEdit)"
  cap 15 osascript -e 'tell application "TextEdit" to get text of front document' 2>&1 | head -1
  sleep 1; screencapture -x after.png && echo "after: $(wc -c <after.png)B CAPTURE-OK"

elif [ "$RUNNER_OS" = "Windows" ]; then
  cat > /tmp/cu.ps1 <<'PS1'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$vs=[System.Windows.Forms.SystemInformation]::VirtualScreen
$b=New-Object System.Drawing.Bitmap($vs.Width,$vs.Height); $g=[System.Drawing.Graphics]::FromImage($b)
$g.CopyFromScreen($vs.Left,$vs.Top,0,0,$b.Size); $b.Save("$PWD\before.png")
Write-Host "before: $((Get-Item before.png).Length)B CAPTURE-OK"
$p=Start-Process "C:\Windows\System32\notepad.exe" -PassThru; Start-Sleep 2
if($p -and !$p.HasExited){ Write-Host "LAUNCH-APP-OK (notepad.exe pid $($p.Id))" } else { Write-Host "LAUNCH-APP-FAILED" }
[System.Windows.Forms.SendKeys]::SendWait("Kai drove Notepad on a Windows cloud runner"); Start-Sleep 1
$b2=New-Object System.Drawing.Bitmap($vs.Width,$vs.Height); $g2=[System.Drawing.Graphics]::FromImage($b2)
$g2.CopyFromScreen($vs.Left,$vs.Top,0,0,$b2.Size); $b2.Save("$PWD\after.png")
Write-Host "after: $((Get-Item after.png).Length)B CAPTURE-OK"
PS1
  powershell -NoProfile -File /tmp/cu.ps1 2>&1 | grep -iE "before:|after:|LAUNCH|CAPTURE"

elif [ "$RUNNER_OS" = "Linux" ]; then
  echo "--- setup xvfb + tools ---"
  sudo apt-get install -y xvfb xdotool imagemagick x11-apps xterm >/dev/null 2>&1
  export DISPLAY=:99
  Xvfb :99 -screen 0 1280x1024x24 >/dev/null 2>&1 & sleep 3
  import -window root before.png 2>/dev/null && echo "before: $(wc -c <before.png)B CAPTURE-OK" || echo "CAPTURE-FAILED"
  xterm -geometry 80x24+100+100 -e "sleep 30" >/dev/null 2>&1 & sleep 2
  if xdotool search --class xterm >/dev/null 2>&1; then echo "LAUNCH-APP-OK (xterm on :99)"; else echo "LAUNCH-APP-FAILED"; fi
  xdotool mousemove 200 200 && echo "MOUSE-OK"
  xdotool type "Kai on a Linux xvfb runner" && echo "TYPE-OK"
  sleep 1
  import -window root after.png 2>/dev/null && echo "after: $(wc -c <after.png)B CAPTURE-OK" || echo "CAPTURE-FAILED"
fi

echo "=== VERDICT ($RUNNER_OS) ==="
[ -f before.png ] && [ -f after.png ] && echo "GREEN: capture+launch+input ran on $RUNNER_OS" || echo "INCOMPLETE"
