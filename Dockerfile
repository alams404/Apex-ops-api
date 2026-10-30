# syntax=docker/dockerfile:1
#
# Multi-stage build:
#   stage "deps"    installs production dependencies only
#   stage "runtime" copies just what is needed to run, as a NON-ROOT user
#
# NOTE: "node:22-alpine" follows the latest 22.x patch release. Before you submit, pin it
# to an exact digest (see README, section "Pin the base image") for fully reproducible builds.
FROM node:22-alpine AS deps
RUN npm install -g npm@11.21.1
WORKDIR /app
COPY app/package.json app/package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force

FROM node:22-alpine AS runtine
RUN npm install -g npm@11.21.1


# Build metadata. These end up in the image so /version can report what is running.
ARG APP_VERSION=dev
ARG GIT_SHA=unknown
# Only used for the rollback demo: building with INJECT_FAULT=bad-release creates a
# deliberately broken image. The default ("none") is the normal, healthy behaviour.
ARG INJECT_FAULT=none

ENV NODE_ENV=production \
    PORT=3000 \
    APP_VERSION=${APP_VERSION} \
    GIT_SHA=${GIT_SHA} \
    INJECT_FAULT=${INJECT_FAULT}

LABEL org.opencontainers.image.title="apex-ops-api" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}"

WORKDIR /app
COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node app/package.json ./package.json
COPY --chown=node:node app/src ./src

# The official node image ships an unprivileged user called "node" (uid 1000).
USER node

EXPOSE 3000

# Liveness check used by Docker itself. Uses Node's built-in fetch, so no curl is needed.
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "src/server.js"]
