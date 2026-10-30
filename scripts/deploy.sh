#!/usr/bin/env bash
# Deploy a specific, versioned image.
#
#   ./scripts/deploy.sh v1.0.0 --build    build the image from source, then deploy it
#   ./scripts/deploy.sh v1.0.0            deploy an image that already exists locally,
#                                         or pull it from the registry named in $IMAGE
#
# Optional environment variables:
#   INJECT_FAULT=bad-release   build a deliberately broken image (rollback demo only)
#   AUTO_ROLLBACK=1            if the new version is not ready, roll back automatically
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

VERSION="${1:-}"
MODE="${2:-}"
validate_version "$VERSION"
load_env

# 1. Get the image
if [ "$MODE" = "--build" ]; then
  GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
  log "Building $IMAGE:$VERSION (git sha: $GIT_SHA, fault: ${INJECT_FAULT:-none})"
  docker build \
    --build-arg "APP_VERSION=$VERSION" \
    --build-arg "GIT_SHA=$GIT_SHA" \
    --build-arg "INJECT_FAULT=${INJECT_FAULT:-none}" \
    -t "$IMAGE:$VERSION" .
elif ! image_exists "$VERSION"; then
  log "Image $IMAGE:$VERSION not found locally, trying to pull it..."
  docker pull "$IMAGE:$VERSION" || die "image $IMAGE:$VERSION not found. Use --build or pull it first."
fi

# 2. Remember what is running now, so we know what to roll back to
CURRENT="$(read_release current)"
if [ -n "$CURRENT" ] && [ "$CURRENT" != "$VERSION" ]; then
  write_release previous "$CURRENT"
fi
write_release current "$VERSION"
log "Deploying $VERSION (previous version: ${CURRENT:-none})"

# 3. Start the stack
compose_up "$VERSION"

# 4. Verify before declaring success. A new container that is "up" is not enough:
#    it must answer /ready with 200 and report the expected version.
if wait_ready "$VERSION" 40; then
  log "DEPLOY SUCCEEDED: $VERSION"
  exit 0
fi

log "DEPLOY FAILED: $VERSION did not become ready. Last app logs:"
docker compose logs --tail=15 app || true

if [ "${AUTO_ROLLBACK:-0}" = "1" ] && [ -n "$CURRENT" ] && [ "$CURRENT" != "$VERSION" ]; then
  log "AUTO_ROLLBACK=1, rolling back to $CURRENT"
  "$ROOT_DIR/scripts/rollback.sh" "$CURRENT" || die "automatic rollback to $CURRENT FAILED too"
  # The release itself still failed, so exit non-zero (CI and humans must notice).
  die "$VERSION failed its readiness check and was rolled back to $CURRENT"
fi

die "$VERSION is not healthy. Roll back with: ./scripts/rollback.sh"
