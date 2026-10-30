#!/usr/bin/env bash
# Scripted failure investigation (requirement 5): wrong database credentials.
#
#   ./scripts/demo-incident.sh 2>&1 | tee evidence/incident-db-credentials.log
#
# Requires the stack to be running first (./scripts/deploy.sh v1.0.0 --build).
set -uo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env

VERSION="$(read_release current)"
[ -n "$VERSION" ] || die "nothing deployed yet. Run ./scripts/deploy.sh v1.0.0 --build first."
BASE="http://127.0.0.1:${APP_PORT}"

step() { printf '\n========== %s ==========\n' "$*"; }

step "1. Baseline: service is healthy"
curl -s -o /dev/null -w "GET /ready -> HTTP %{http_code}\n" "$BASE/ready"

step "2. INJECT FAULT: restart the app with a wrong database password"
APP_DB_PASSWORD="wrong-password-for-demo" APP_VERSION="$VERSION" docker compose up -d app
sleep 8

step "3. DETECT: /health is still 200 (process alive) but /ready is 503 (cannot serve)"
curl -s -o /dev/null -w "GET /health -> HTTP %{http_code}\n" "$BASE/health"
curl -s -w "\nGET /ready  -> HTTP %{http_code}\n" "$BASE/ready"

step "4. INVESTIGATE: read the structured logs"
docker compose logs --tail=20 app
echo
echo "Look for:  \"event\":\"db_check_failed\"  and the message  password authentication failed"
echo "The database container itself is healthy, so the problem is the app's credentials:"
docker compose ps db

step "5. FIX: restart the app with the correct password (from .env)"
APP_VERSION="$VERSION" docker compose up -d app
wait_ready "$VERSION" 40 || die "service did not recover"

step "6. VERIFY: back to normal"
curl -s -o /dev/null -w "GET /ready -> HTTP %{http_code}\n" "$BASE/ready"
echo
echo "Now fill in docs/incident-report.md from this log (symptom, detection, root cause, fix, prevention)."
