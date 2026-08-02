#!/bin/bash
# Test: can agent-browser screenshot capture the browser content on a headless
# runner? And is OS-desktop capture possible (for GUI bugs like #1498)?
set -uo pipefail
cap() { local s="$1"; shift; "$@" & local p=$!; ( sleep "$s"; kill -9 "$p" 2>/dev/null; echo "[HANG-${s}s]" )& local w=$!; wait "$p" 2>/dev/null; local rc=$?; kill "$w" 2>/dev/null; return "$rc"; }
AB_SAFE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/ab-safe.sh"
RUNNER_ARCH="${RUNNER_ARCH:-$(uname -m)}"

echo "=== OS: $RUNNER_OS  ARCH: $RUNNER_ARCH ==="
echo "--- 1. browser-content screenshot (agent-browser) ---"
"$AB_SAFE" doctor 2>&1 | tail -2
"$AB_SAFE" raw open https://example.com 2>&1 | tail -2
"$AB_SAFE" raw screenshot browser-shot.png 2>&1 | tail -2
if [ -f browser-shot.png ]; then
  echo "BROWSER SCREENSHOT OK: $(wc -c < browser-shot.png) bytes"
  file browser-shot.png 2>/dev/null || true
else
  echo "BROWSER SCREENSHOT FAILED (no file)"
fi

echo "--- 2. OS-desktop capture (for GUI bugs) ---"
if [ "$RUNNER_OS" = "macOS" ]; then
  screencapture -x desktop.png 2>&1 && echo "OS DESKTOP OK: $(wc -c < desktop.png) bytes" || echo "OS DESKTOP: no display / failed"
elif [ "$RUNNER_OS" = "Windows" ]; then
  powershell -c "Add-Type -AssemblyName System.Windows.Forms; \$b=[System.Windows.Forms.SystemInformation]::VirtualScreen; Write-Host ('screen: '+\$b.Width+'x'+\$b.Height)" 2>&1 | tail -2
else
  echo "Linux: no X display on runner by default (would need xvfb)"
fi
"$AB_SAFE" raw close --all 2>/dev/null || true
