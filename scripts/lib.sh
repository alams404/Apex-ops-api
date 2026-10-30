#!/usr/bin/env bash
# Shared helpers, sourced by the other scripts. Not meant to be run directly.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/.release"
cd "$ROOT_DIR" || exit 1

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
die() { printf '[%s] ERROR: %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; exit 1; }

load_env() {
  [ -f "$ROOT_DIR/.env" ] || die ".env not found. Run ./scripts/init-env.sh first."
  # Export only the variables we need (the file is plain KEY=VALUE lines).
  set -a
  # shellcheck disable=SC1090,SC1091
  . "$ROOT_DIR/.env"
  set +a
  IMAGE="${IMAGE:-apex-ops-api}"
  APP_PORT="${APP_PORT:-3000}"
  mkdir -p "$RELEASE_DIR"
}

# Allowed version tags: letters, digits, dot, dash, underscore. "latest" is refused on
# purpose, because a rollback needs an exact, immutable version to go back to.
validate_version() {
  local v="$1"
  [ -n "$v" ] || die "version is required (example: v1.0.0)"
  [ "$v" != "latest" ] || die "'latest' is not allowed. Use an explicit version such as v1.0.0"
  printf '%s' "$v" | grep -Eq '^[A-Za-z0-9._-]+$' || die "invalid version '$v'"
}

image_exists() { docker image inspect "$IMAGE:$1" >/dev/null 2>&1; }

# Start (or update) the stack with a specific image version.
compose_up() {
  local version="$1"
  APP_VERSION="$version" docker compose up -d --remove-orphans
}

# Wait until /ready is 200 AND /version reports the expected version.
# Returns 0 on success, 1 on timeout.
wait_ready() {
  local version="$1" timeout="${2:-40}" waited=0
  log "Waiting up to ${timeout}s for $IMAGE:$version to become ready..."
  while [ "$waited" -lt "$timeout" ]; do
    if curl -fsS "http://127.0.0.1:${APP_PORT}/ready" >/dev/null 2>&1; then
      local running
      running="$(curl -fsS "http://127.0.0.1:${APP_PORT}/version" 2>/dev/null || true)"
      if printf '%s' "$running" | grep -q "\"version\":\"${version}\""; then
        log "READY. Running: $running"
        return 0
      fi
    fi
    sleep 2
    waited=$((waited + 2))
  done
  return 1
}

read_release() { [ -f "$RELEASE_DIR/$1" ] && cat "$RELEASE_DIR/$1" || true; }
write_release() { printf '%s\n' "$2" >"$RELEASE_DIR/$1"; }
