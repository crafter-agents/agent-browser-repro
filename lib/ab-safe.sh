#!/usr/bin/env bash
# ab-safe — a disciplined wrapper around agent-browser for CI/runner use.
# Fixes the frictions that blocked repros, WITHOUT touching vercel-labs' repo:
#  - doctor hangs on Windows -> always use --offline --quick --json there
#  - `open` leaves a persistent daemon -> we never wait on it; always close --all after
#  - everything hard-capped so a hang is a signal, not an infinite burn
# Usage: ab-safe doctor | ab-safe session <url> [-- cmd...] | ab-safe raw <args...>
set -uo pipefail
AB="${AGENT_BROWSER:-agent-browser}"
OSNAME="$(uname -s 2>/dev/null || echo Windows)"
cap() { local s="$1"; shift; "$@" < /dev/null & local p=$!; ( sleep "$s"; kill -9 "$p" 2>/dev/null; echo "[ab-safe: capped ${s}s]" ) & local w=$!; wait "$p" 2>/dev/null; local rc=$?; kill "$w" 2>/dev/null; return "$rc"; }

cmd="${1:-}"; shift || true
case "$cmd" in
  doctor)
    # --offline --quick avoids the Windows doctor hang (#1461); works everywhere.
    cap 40 "$AB" doctor --offline --quick --json ;;
  session)
    url="${1:?ab-safe session <url>}"; shift || true
    cap 30 "$AB" open "$url"
    rc=$?
    # run any inner commands while the session is up
    if [ "${1:-}" = "--" ]; then shift; cap 30 "$@" || true; fi
    # ALWAYS close; the daemon is persistent by design, we must not leak it
    cap 20 "$AB" close --all 2>/dev/null || true
    return "$rc" 2>/dev/null || exit "$rc" ;;
  raw)
    cap 45 "$AB" "$@" ;;
  *)
    echo "ab-safe: doctor | session <url> [-- cmd] | raw <args>" >&2; exit 2 ;;
esac
