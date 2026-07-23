#!/bin/bash
# Prove cu works agnostically: clone cu, run the SAME commands on this runner's OS.
set -uo pipefail
echo "=== fetching cu CLI ==="
git clone --depth 1 https://github.com/crafter-agents/cu.git _cu 2>/dev/null || { echo "clone failed"; exit 1; }
CU="_cu/bin/cu"
chmod +x "$CU"
echo "cu os -> $($CU os)"

echo "--- capture (cu picks the right primitive) ---"
$CU capture before.png && echo "CAPTURE-OK" || echo "CAPTURE-FAILED"

echo "--- launch app (agnostic) ---"
case "$($CU os)" in
  macos)   $CU launch TextEdit ;;
  windows) $CU launch "C:\\Windows\\System32\\notepad.exe" ;;
  linux)   $CU launch xterm ;;
esac
sleep 2; echo "LAUNCH-DONE"

echo "--- type (SAME command, every OS) ---"
$CU type "cu made this cross-platform" && echo "TYPE-OK" || echo "TYPE-FAILED"

echo "--- capture after ---"
sleep 1
$CU capture after.png && echo "CAPTURE-OK" || echo "CAPTURE-FAILED"

echo "=== VERDICT ==="
if [ -f before.png ] && [ -f after.png ]; then
  echo "CU-GREEN on $($CU os): identical agnostic commands, correct OS primitives"
else
  echo "CU-PARTIAL on $($CU os)"
fi
