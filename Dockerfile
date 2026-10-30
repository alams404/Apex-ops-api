# syntax=docker/dockerfile:1

# =====================================
# STAGE 1: Install production dependencies
# =====================================
FROM node:22-alpine AS deps

WORKDIR /app

# Copy package files
COPY app/package.json app/package-lock.json ./

# Install production dependencies
RUN npm ci --omit=dev --no-audit --no-fund


# =====================================
# STAGE 2: Production runtime
# =====================================
FROM node:22-alpine AS runtime

# Build metadata
ARG APP_VERSION=dev
ARG GIT_SHA=unknown
ARG INJECT_FAULT=none

# Application environment
ENV NODE_ENV=production \
    PORT=3000 \
    APP_VERSION=${APP_VERSION} \
    GIT_SHA=${GIT_SHA} \
    INJECT_FAULT=${INJECT_FAULT}

# Image metadata
LABEL org.opencontainers.image.title="apex-ops-api" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}"

WORKDIR /app

# Copy production dependencies
COPY --from=deps --chown=node:node /app/node_modules ./node_modules

# Copy application files
COPY --chown=node:node app/package.json ./package.json
COPY --chown=node:node app/src ./src

# Remove npm and its bundled dependencies from runtime
RUN rm -rf /usr/local/lib/node_modules/npm \
    /usr/local/bin/npm \
    /usr/local/bin/npx

# Run as non-root user
USER node

# Application port
EXPOSE 3000

# Container health check
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/').then(r=>process.exit(r.status<500?0:1)).catch(()=>process.exit(1))"

# Start application
CMD ["node", "src/server.js"]