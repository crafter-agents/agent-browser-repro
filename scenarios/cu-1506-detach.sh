#!/bin/bash
# #1506 on REAL Windows: confirm Chrome exits early (exit 0) after DevToolsActivePort
# because it is not detached. macOS/Linux are controls (should NOT exit early).
set -uo pipefail
export PATH="$HOME/.bun/bin:$PATH"
AB_SAFE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/ab-safe.sh"
echo "=== #1506 on $RUNNER_OS: does agent-browser open fail with early Chrome exit? ==="

OUT=$("$AB_SAFE" raw open https://example.com < /dev/null 2>&1)
echo "output: $(echo "$OUT" | head -c 300)"

if echo "$OUT" | grep -qi "exited early\|without writing DevToolsActivePort\|exit code: 0"; then
  echo "CU-1506-REPRODUCED on $RUNNER_OS: Chrome exited early (matches the not-detached bug)"
elif echo "$OUT" | grep -qi "Example Domain\|snapshot\|launched"; then
  echo "CU-1506-OK on $RUNNER_OS: open succeeded (Chrome survived, Unix detaches by default)"
else
  echo "CU-1506-UNCLEAR on $RUNNER_OS: $(echo "$OUT" | head -c 80)"
fi
"$AB_SAFE" raw close --all 2>/dev/null || true
