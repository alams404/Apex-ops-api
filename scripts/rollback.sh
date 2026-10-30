#!/usr/bin/env bash
# Roll back to a previous version. It NEVER rebuilds anything: it only starts an image
# that already exists, which is what makes a rollback fast and predictable.
#
#   ./scripts/rollback.sh            roll back to the version recorded before the last deploy
#   ./scripts/rollback.sh v1.0.0     roll back to an explicit version
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env

TARGET="${1:-$(read_release previous)}"
[ -n "$TARGET" ] || die "no previous version recorded. Pass one explicitly: ./scripts/rollback.sh v1.0.0"
validate_version "$TARGET"

image_exists "$TARGET" || {
  log "Image $IMAGE:$TARGET not found locally, trying to pull it..."
  docker pull "$IMAGE:$TARGET" || die "cannot roll back: image $IMAGE:$TARGET is not available"
}

FAILED_VERSION="$(read_release current)"
log "ROLLBACK: ${FAILED_VERSION:-unknown} -> $TARGET"
compose_up "$TARGET"

if wait_ready "$TARGET" 40; then
  write_release current "$TARGET"
  [ -n "$FAILED_VERSION" ] && [ "$FAILED_VERSION" != "$TARGET" ] && write_release previous "$FAILED_VERSION"
  log "ROLLBACK SUCCEEDED: now running $TARGET. Database data was not touched (named volume)."
  exit 0
fi

docker compose logs --tail=15 app || true
die "ROLLBACK FAILED: $TARGET is not ready. See docs/runbook.md, section 'Troubleshooting'."
