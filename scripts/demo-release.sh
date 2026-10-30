#!/usr/bin/env bash
# Scripted release + rollback demo. Produces the evidence for requirement 4.
#
#   ./scripts/demo-release.sh 2>&1 | tee evidence/release-rollback-demo.log
#
# Story:  deploy v1.0.0 (good)  ->  create data  ->  deploy v2.0.0 (has a bug)
#         ->  deployment is detected as unhealthy  ->  roll back to v1.0.0
#         ->  confirm the service works and the data survived.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

step() { printf '\n========== %s ==========\n' "$*"; }

./scripts/init-env.sh

step "1. Deploy v1.0.0 (healthy release)"
./scripts/deploy.sh v1.0.0 --build || exit 1

step "2. Create a record so we can prove data survives the rollback"
# shellcheck disable=SC1091
. .env
curl -fsS -X POST "http://127.0.0.1:${APP_PORT:-3000}/items" \
  -H 'Content-Type: application/json' -d '{"name":"created while v1.0.0 was running"}'
echo

step "3. Deploy v2.0.0, which contains a bug (INJECT_FAULT=bad-release)"
INJECT_FAULT=bad-release ./scripts/deploy.sh v2.0.0 --build
echo "(Exit code above is expected to be non-zero: the bad release was detected.)"

step "4. Evidence of the failure: /ready and /version"
curl -s -o /dev/null -w "GET /ready -> HTTP %{http_code}\n" "http://127.0.0.1:${APP_PORT:-3000}/ready"
curl -s "http://127.0.0.1:${APP_PORT:-3000}/version"; echo

step "5. Roll back to the previous version"
./scripts/rollback.sh || exit 1

step "6. Verify: service healthy, v1.0.0 running, data still present"
./scripts/smoke.sh v1.0.0 || exit 1
curl -fsS "http://127.0.0.1:${APP_PORT:-3000}/items"; echo

step "DONE. Rollback demonstrated."
