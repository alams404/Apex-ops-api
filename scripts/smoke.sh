#!/usr/bin/env bash
# Quick end-to-end check of a running stack. Usage: ./scripts/smoke.sh [expected-version]
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env

BASE="http://127.0.0.1:${APP_PORT}"
EXPECTED="${1:-}"
FAILED=0

check() { # check <name> <command...>
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then log "PASS  $name"; else log "FAIL  $name"; FAILED=1; fi
}

check "GET /health returns 200" curl -fsS "$BASE/health"
check "GET /ready returns 200" curl -fsS "$BASE/ready"
check "GET /metrics returns metrics" curl -fsS "$BASE/metrics"
check "POST /items creates an item" \
  curl -fsS -X POST "$BASE/items" -H 'Content-Type: application/json' -d '{"name":"smoke test item"}'
check "GET /items returns a list" curl -fsS "$BASE/items"

if [ -n "$EXPECTED" ]; then
  RUNNING="$(curl -fsS "$BASE/version" 2>/dev/null || true)"
  if printf '%s' "$RUNNING" | grep -q "\"version\":\"${EXPECTED}\""; then
    log "PASS  /version is $EXPECTED"
  else
    log "FAIL  /version expected $EXPECTED, got: ${RUNNING:-nothing}"
    FAILED=1
  fi
fi

[ "$FAILED" -eq 0 ] && log "SMOKE TEST PASSED" || die "SMOKE TEST FAILED"
