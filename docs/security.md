# Security, secrets, scanning and cloud path

## 1. Secrets handling

| Rule | How it is applied here |
| --- | --- |
| No secrets in git | `.env` is in `.gitignore`. Only `.env.example` (with a blank password) is committed. CI fails if a file named `.env` is tracked. |
| No hard-coded passwords | `scripts/init-env.sh` generates a random 32-character database password on first run. The compose file refuses to start if it is missing (`${POSTGRES_PASSWORD:?...}`). |
| Least exposure of the secret | Only the `db` container receives `POSTGRES_PASSWORD`. The `app` container receives a ready-made `DATABASE_URL` and nothing else sensitive. |
| Not in logs | The logger redacts `password` fields and the `Authorization` header. `/ready` logs the failure reason for operators but does not return it to callers. |
| Not in the image | `.dockerignore` excludes `.env`, `.git` and docs. Secrets are provided at runtime, never at build time. |
| CI secrets | CI uses throwaway values that are only valid inside the job (a Postgres service container and a random `.env`). Registry access uses the short-lived `GITHUB_TOKEN`, not a stored password. |
| Local file permissions | `init-env.sh` sets `.env` to mode `600`. |

Cloud path: store secrets in **Azure Key Vault**, give the workload a **managed identity** with the `Key Vault Secrets User` role, and reference secrets from the Container App instead of passing them as plain environment variables. Rotate the database password on a schedule and after any suspected exposure.

If a secret is ever committed: rotate it immediately (removing it from git history is not enough), then clean the history.

## 2. Least privilege

| Layer | Control |
| --- | --- |
| Container user | Runs as the unprivileged `node` user (uid 1000). CI verifies the image user id is not 0. |
| Container filesystem | `read_only: true` with a `tmpfs` for `/tmp` only. |
| Linux capabilities | `cap_drop: ALL` and `no-new-privileges` on both containers. |
| Resources | `mem_limit: 256m`, `pids_limit: 100` on the app to contain runaway behaviour. |
| Network exposure | API published on `127.0.0.1` only. Database has no published port; only the app can reach it. |
| Image contents | Multi-stage build: production dependencies only, no build tools or dev dependencies in the final image. |
| CI permissions | Workflow default is `contents: read`. Only the `build` job gets `packages: write`, and the `deploy` job gets `packages: read`. |
| Registry pushes | Only from `main` or a `v*` tag, never from feature branches or pull requests. |

Known limitation: the database user created by the official PostgreSQL image is a superuser of that database server. In a real environment, create a separate application role with only `SELECT, INSERT` on the `items` table and use that in `DATABASE_URL`. This is listed under "with more time" in the decision memo.

## 3. Dependency and image scanning

| What | Tool | Where | Failure rule |
| --- | --- | --- | --- |
| Node.js dependencies | `npm audit --omit=dev` | CI job `audit` | Fails on HIGH or CRITICAL |
| Container image (OS packages and libraries) | Trivy | CI job `build` | Fails on HIGH or CRITICAL that have a fix available |
| Dockerfile best practices | Hadolint | CI job `lint` | Fails on warnings |
| Shell scripts | ShellCheck | CI job `lint` | Fails on warnings |

Run the scans locally:

```bash
(cd app && npm audit --omit=dev)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --severity HIGH,CRITICAL --ignore-unfixed apex-ops-api:v1.0.0
```

Process for a finding: upgrade the dependency or base image, rebuild, re-run CI. If there is no fix yet, record the finding, the risk assessment and a review date rather than silently ignoring it. `ignore-unfixed` keeps the pipeline actionable, but unfixed findings should still be reviewed.

Proposed additions: Dependabot for npm and Docker updates, and a secret scanner such as gitleaks in CI.

## 4. Cost-aware path to cloud hosting (Azure)

This is a proposal only. The assessment forbids creating paid cloud resources.

**Recommended starting point: Azure Container Apps (Consumption plan) + Azure Database for PostgreSQL Flexible Server (Burstable tier).**

| Component | Choice | Why it is cost-aware |
| --- | --- | --- |
| Compute | Container Apps, Consumption plan, minimum 1 replica (or scale to zero for non-production) | Pay for actual CPU and memory use, no cluster to run or patch. A small API fits the free monthly grant or costs very little. Scale rules add replicas under load. |
| Database | PostgreSQL Flexible Server, smallest Burstable SKU, minimal storage, auto-grow off until needed | Burstable is designed for low, spiky load. A managed database gives backups and patching, which is worth the cost compared with running Postgres in a container for anything important. |
| Images | Keep using GHCR (free for this use) or Azure Container Registry Basic | Avoids a registry bill until there is a reason to move. |
| Secrets | Key Vault (Standard) with managed identity | Cost is negligible and it removes secrets from configuration. |
| Observability | Log Analytics workspace with a daily ingestion cap and short retention, Azure Monitor alerts | Log ingestion is the usual surprise cost, so cap it. Start with the alerts in `docs/observability.md`. |
| Delivery | Same GitHub Actions pipeline, with the deploy job calling `az containerapp update --image ...` using OIDC federation | No stored cloud credentials. Revisions give built-in rollback by re-activating the previous revision. |

Cost controls: set an Azure budget with email alerts, tag all resources, use separate cheap settings for dev (scale to zero, smallest SKU, stop the database out of hours), and review the bill monthly.

**Cheapest alternative:** a single small Linux VM running this exact Compose stack behind a reverse proxy with automatic TLS. It is the lowest fixed cost and the simplest to reason about, but it means managing OS patches, backups and uptime yourself, so it suits prototypes, not production.

**Later, if needed:** AKS only when there are many services or a platform team; it is more power and more cost than this workload needs.

**Infrastructure as code:** provision all of the above with Terraform so environments are reproducible and reviewable.
