#!/bin/bash
# #1498 v2: black rectangle on Windows desktop, using ab-safe (no hang) + cu diff.
set -uo pipefail
[ "$RUNNER_OS" != "Windows" ] && { echo "SKIP: #1498 is Windows-desktop-visual only"; exit 0; }

git clone --depth 1 https://github.com/crafter-agents/cu.git _cu 2>/dev/null
git clone --depth 1 https://github.com/crafter-agents/agent-browser-repro.git _abr 2>/dev/null || true
CU="_cu/bin/cu"; chmod +x "$CU"
# ab-safe from this same repo checkout
AB_SAFE="_abr/lib/ab-safe.sh"; [ -f "$AB_SAFE" ] || AB_SAFE="lib/ab-safe.sh"
chmod +x "$AB_SAFE" 2>/dev/null || true
export PATH="$HOME/.bun/bin:$PATH"

echo "=== #1498 via ab-safe + cu diff on Windows ==="

$CU capture before.png && echo "before captured"

# run a headless agent-browser session with ab-safe (caps + close --all, no hang)
bash "$AB_SAFE" session https://example.com 2>&1 | tail -3
echo "ab-safe session done (no hang)"

sleep 2
$CU capture after.png && echo "after captured"

echo "--- cu diff: did a visual region change (the black rectangle)? ---"
$CU diff before.png after.png 2>&1 | tail -2

echo "=== VERDICT ==="
CHANGED=$($CU diff before.png after.png 2>/dev/null | grep -c CHANGED || true)
if [ "${CHANGED:-0}" -gt 0 ]; then
  echo "CU-1498-VISUAL-CHANGE: desktop changed after headless session (candidate black rectangle)"
else
  echo "CU-1498-NO-CHANGE: no desktop change detected (rect may not appear on this runner/config)"
fi
