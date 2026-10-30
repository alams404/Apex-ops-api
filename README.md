# Apex Operations API: reproducible deployment, CI/CD, release and rollback

A small Node.js (Express) API backed by PostgreSQL, packaged in Docker, deployed locally with Docker Compose, and shipped through a GitHub Actions pipeline with versioned images, a rollback script, structured logs, Prometheus metrics and a documented security and cloud path.

All data is synthetic. No real credentials, customer data or paid cloud resources are used.

## What is in this repository

| Path | Purpose |
| --- | --- |
| `app/` | API source (`src/`), tests (`test/`), ESLint config |
| `Dockerfile` | Multi-stage build, non-root user, `HEALTHCHECK` |
| `docker-compose.yml` | API + PostgreSQL, named volume, healthchecks, hardening |
| `.env.example` | Configuration template (the real `.env` is gitignored) |
| `.github/workflows/ci.yml` | Pipeline: lint, test, audit, build, scan, push, deploy |
| `scripts/` | `deploy.sh`, `rollback.sh`, `smoke.sh`, `init-env.sh`, demo scripts |
| `docs/` | Architecture, runbook, security, observability, decision memo, AI disclosure |
| `evidence/` | Logs and screenshots proving the claims (see `evidence/README.md`) |

## Prerequisites

- Docker Engine with Compose v2 (`docker compose version`)
- `bash`, `curl` and `git` (Linux, macOS, or WSL2 / Git Bash on Windows)
- Node.js 20 or newer, only if you want to run the tests outside Docker

## Quick start (about 3 minutes)

```bash
git clone <this-repo-url> apex-ops-api
cd apex-ops-api

./scripts/init-env.sh                 # creates .env with a random DB password
./scripts/deploy.sh v1.0.0 --build    # builds image apex-ops-api:v1.0.0 and starts the stack
./scripts/smoke.sh v1.0.0             # end-to-end check, expect "SMOKE TEST PASSED"
```

Then try it:

```bash
curl localhost:3000/health            # liveness
curl localhost:3000/ready             # readiness (checks the database)
curl localhost:3000/version           # which version is running
curl -X POST localhost:3000/items -H 'Content-Type: application/json' \
     -d '{"name":"Rotate TLS certificate","status":"open"}'
curl localhost:3000/items
curl localhost:3000/metrics           # Prometheus metrics
```

Stop and clean up:

```bash
docker compose down        # stop, keep the data volume
docker compose down -v     # stop and DELETE the data volume
```

## API

| Method and path | Description |
| --- | --- |
| `GET /health` | Liveness. Always 200 if the process is up. Does not touch the database. |
| `GET /ready` | Readiness. 200 if the database answers, otherwise 503. |
| `GET /version` | Running version and git SHA (used by deploy and rollback checks). |
| `GET /metrics` | Prometheus metrics. |
| `GET /items` | List the latest 100 items. |
| `POST /items` | Create an item. Body: `{"name": "...", "status": "open|in_progress|resolved"}`. Invalid input returns 422. |

## Tests

```bash
cd app
npm ci
npm run lint
npm test
```

There are 10 unit-level checks that use a fake database (no Docker needed) and 1 integration check against real PostgreSQL. The integration check runs when `DATABASE_URL` is set, which CI does, and is skipped locally.

**The intentional failure** is the check named `release gate: FORCE_FAIL must not be set`. It passes normally and fails when `FORCE_FAIL=true`:

```bash
FORCE_FAIL=true npm test      # exactly 1 failure, exit code 1
```

In CI the switch is turned on automatically for a branch named `demo-failure`, or manually through Actions > Run workflow > `force_fail`. The failed run stops the pipeline before the build and deploy jobs. See `docs/runbook.md` for the exact steps.

## CI/CD pipeline

```
lint ──► test ──┐
lint ──► audit ─┴──► build (image, non-root check, Trivy scan, push) ──► deploy (compose + smoke test)
```

Every arrow is a `needs:` dependency, so a failure at any stage blocks everything after it. Images are pushed to GitHub Container Registry only from `main` or a `v*` tag, and deployment only runs for the same refs. Details and the reasoning are in `docs/decision-memo.md`.

## Release and rollback

Images are tagged with an explicit version (`v1.0.0`, `v2.0.0`, or `sha-<git sha>` in CI). `latest` is refused by the scripts. Compose runs `${IMAGE}:${APP_VERSION}`.

```bash
./scripts/deploy.sh v2.0.0 --build    # new release; verified via /ready and /version
./scripts/rollback.sh                 # back to the previously deployed version
./scripts/rollback.sh v1.0.0          # or to an explicit version
```

`rollback.sh` never rebuilds. It restarts an image that already exists, and the database volume is untouched, so data survives a rollback.

**One-command demonstration** of deploy v1, deploy a deliberately broken v2, detect it, roll back, and prove data survived:

```bash
./scripts/demo-release.sh 2>&1 | tee evidence/release-rollback-demo.log
```

## Failure investigation (wrong database credentials)

```bash
./scripts/deploy.sh v1.0.0 --build
./scripts/demo-incident.sh 2>&1 | tee evidence/incident-db-credentials.log
```

The write-up is in `docs/incident-report.md`.

## Observability

- **Structured logs:** one JSON object per line, including a per-request `requestId`, also returned in the `x-request-id` response header. View with `docker compose logs -f app`.
- **Health:** `/health` (liveness, used by the Docker `HEALTHCHECK`) and `/ready` (readiness, used by deploy and rollback).
- **Metrics:** `/metrics` exposes `http_requests_total`, `http_request_duration_seconds`, `db_up` and Node.js process metrics.
- **Alert proposal:** `docs/observability.md`.

## Security and cloud path

`docs/security.md` covers secrets handling, least privilege, dependency and image scanning, and a cost-aware path to Azure.

## Assumptions

1. The target is a single local machine (Docker Compose), as the assessment requires. No cloud resources are created.
2. "Deploy" in CI means running the same Compose stack on the GitHub runner and smoke testing it. There is no remote server.
3. One API instance and one database instance, because the scenario is small. Scaling and high availability are discussed in the decision memo as next steps.
4. Node.js 22 and PostgreSQL 16 were chosen because they are current, supported releases.

## Pin the base image (do this once before submitting)

`Dockerfile` uses `node:22-alpine`, which follows new patch releases. For a fully reproducible build, replace it with an exact digest:

```bash
docker pull node:22-alpine
docker inspect --format '{{index .RepoDigests 0}}' node:22-alpine
# paste the result (node@sha256:...) into both FROM lines of the Dockerfile, keeping a comment with the tag
```

Do the same for `postgres:16-alpine` in `docker-compose.yml` if you want the database image pinned too.

## Documents

- [Architecture and process diagram](docs/architecture.md)
- [Runbook (deploy, rollback, incident response, troubleshooting)](docs/runbook.md)
- [Security, secrets, scanning and cloud path](docs/security.md)
- [Observability and alert proposal](docs/observability.md)
- [Incident report (failure investigation)](docs/incident-report.md)
- [Decision memo and trade-offs](docs/decision-memo.md)
- [AI-use disclosure](docs/ai-disclosure.md)
