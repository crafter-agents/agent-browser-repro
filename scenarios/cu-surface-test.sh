#!/bin/bash
# Full surface test of cu across whatever OS this runner is. Same verbs everywhere.
set -uo pipefail
git clone --depth 1 https://github.com/crafter-agents/cu.git _cu 2>/dev/null
CU="_cu/bin/cu"; chmod +x "$CU"
OS="$($CU os)"
echo "=== cu full-surface test on $OS ==="

pass=0; total=0
try() { total=$((total+1)); if "$@" >/dev/null 2>&1; then echo "OK   $*"; pass=$((pass+1)); else echo "FAIL $*"; fi; }

try $CU capture before.png
case "$OS" in
  macos)   $CU launch TextEdit >/dev/null 2>&1 ;;
  windows) $CU launch "C:\\Windows\\System32\\notepad.exe" >/dev/null 2>&1 ;;
  linux)   $CU launch xterm >/dev/null 2>&1 ;;
esac
sleep 2
try $CU type "surface test line one"
try $CU key "$([ "$OS" = macos ] && echo cmd+a || echo ctrl+a)"
try $CU select-all
try $CU move 250 250
try $CU click 250 250
try $CU scroll down 2
try $CU capture after.png

echo "=== VERDICT ==="
echo "$pass/$total actions OK on $OS"
[ -f before.png ] && [ -f after.png ] && echo "CU-SURFACE-GREEN on $OS ($pass/$total)" || echo "CU-SURFACE-PARTIAL on $OS ($pass/$total)"
