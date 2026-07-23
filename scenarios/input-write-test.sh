#!/bin/bash
# GRILL rung 1 hole #1: can I do INPUT (write) on a runner, not just capture (read)?
# Computer-use = write. If this fails, the cloud is a viewing gallery, not a lab.
set -uo pipefail
echo "=== OS: $RUNNER_OS — testing INPUT primitives ==="

if [ "$RUNNER_OS" = "macOS" ]; then
  echo "--- osascript (AppleScript UI automation) available? ---"
  osascript -e 'tell application "System Events" to get name of every process' 2>&1 | head -1 && echo "OSASCRIPT-PROC-LIST-OK" || echo "OSASCRIPT-FAILED"
  echo "--- can osascript move mouse / synth key? (needs accessibility) ---"
  osascript -e 'tell application "System Events" to key code 0' 2>&1 | head -2 && echo "KEYSTROKE-SENT (no error = likely works)" || echo "KEYSTROKE-BLOCKED (accessibility perm)"
  echo "--- cliclick installable? ---"
  which cliclick 2>/dev/null || echo "cliclick not preinstalled"
  echo "--- Terminal has a real windowserver session? ---"
  osascript -e 'tell application "System Events" to get bounds of window 1 of (first process whose frontmost is true)' 2>&1 | head -1

elif [ "$RUNNER_OS" = "Linux" ]; then
  echo "--- xvfb available to create a virtual display? ---"
  which Xvfb xvfb-run 2>/dev/null || (sudo apt-get install -y xvfb >/dev/null 2>&1 && echo "xvfb installed" || echo "xvfb install failed")
  echo "--- xdotool for input under xvfb? ---"
  which xdotool 2>/dev/null || (sudo apt-get install -y xdotool >/dev/null 2>&1 && echo "xdotool installed" || echo "no xdotool")
  echo "--- start xvfb + test xdotool mousemove ---"
  export DISPLAY=:99
  Xvfb :99 -screen 0 1280x1024x24 >/dev/null 2>&1 & sleep 3
  xdotool mousemove 100 100 2>&1 && echo "XDOTOOL-MOUSEMOVE-OK (virtual display input works)" || echo "XDOTOOL-FAILED"
  xdotool getmouselocation 2>&1 | head -1

elif [ "$RUNNER_OS" = "Windows" ]; then
  echo "--- PowerShell SendKeys / mouse via user32? ---"
  powershell -c "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point(200,200); Write-Host ('mouse at: '+[System.Windows.Forms.Cursor]::Position)" 2>&1 | tail -2
fi
echo "=== INPUT test done on $RUNNER_OS ==="
