# Decision memo

Purpose: explain what was chosen, why, what was given up, and what I would do with more time. Written for the live review, so each decision is something I can defend.

## Scope and assumptions

- A small API, run locally with Docker Compose, with a path from commit to release that is repeatable and has evidence.
- Single machine, single instance, synthetic data. No cloud resources created, per the assessment rules.
- I chose a small but real service (items with validation, a database, metrics) so that health, readiness, persistence and failure modes are genuine and not mocked.

## Decisions and trade-offs

| Decision | Why | Trade-off or alternative |
| --- | --- | --- |
| **Node.js + Express** | I already know it from earlier Docker projects, so I can explain and debug every line in the review. Small footprint, quick tests. | Python/FastAPI would give automatic validation docs. Not worth the unfamiliarity. |
| **PostgreSQL 16** with a named volume | Realistic dependency with real failure modes (bad credentials, down, not ready). Named volume makes the data persist across redeploys and rollbacks. | A mock dependency would be simpler but would prove less. |
| **Built-in `node --test` + `supertest`** | No extra test framework to install or learn. Tests use a fake database, so they are fast and need no Docker. One extra integration test uses real PostgreSQL in CI. | Less rich reporting than Jest or Vitest. |
| **Multi-stage Dockerfile, `node:22-alpine`, `USER node`** | Smaller image, fewer vulnerabilities, no dev dependencies at runtime, non-root as required. | Alpine uses musl libc, which occasionally matters for native modules. None are used here. Pin by digest before final submission (README explains how). |
| **Separate `/health` and `/ready`** | Liveness and readiness answer different questions. Restarting a healthy process because the database is down would not help. | Slightly more code. |
| **Compose hardening** (read-only fs, `cap_drop: ALL`, `no-new-privileges`, memory and pid limits, localhost-only port, no DB port) | Cheap, effective least privilege. | `read_only` requires remembering a writable `/tmp` if something later needs it. |
| **GitHub Actions** | Free, lives next to the code, and I have used it before. | Ties the pipeline to GitHub. |
| **Pipeline shape: lint, then test and audit in parallel, then build and scan, then deploy** | Cheapest and fastest feedback first. Every stage is a `needs:` gate, so a failed test blocks the image build and the deploy. | A bit more YAML than one big job, but failures are easier to read. |
| **Trivy fails the build on HIGH or CRITICAL with a fix** (`ignore-unfixed`) | A scanner that always fails on unfixable issues gets ignored. This keeps the gate actionable. | Unfixed vulnerabilities still need a manual review process. |
| **Image tags: `v1.0.0` for releases, `sha-<git sha>` for CI builds. `latest` is refused** | A rollback needs an exact, immutable target. `latest` can point to different things at different times. | Tags are mutable in principle. Pinning the deploy by digest is the stronger form. |
| **Push images only from `main` or version tags** | Pull requests and feature branches should not publish artifacts. | Reviewers cannot pull a PR build from the registry. |
| **Deploy in CI = Compose on the runner + smoke test** | The assessment asks for local deployment, so CI proves the same stack comes up and passes checks, without needing servers or credentials. | It does not push to a persistent environment. That would be the next step. |
| **Rollback = restart the previous existing image tag** | Fast, predictable, no rebuild, works even if CI is down. The database is not touched. | Only safe while the database schema is backward compatible. See below. |
| **Deploy verifies `/ready` and `/version` before saying "success"** | "Container started" is not the same as "service works". Checking the version also prevents declaring success while the old container still answers. | Adds up to 40 seconds of waiting on failure. |
| **Fault injection through a build argument** (`INJECT_FAULT=bad-release`) | Lets me demonstrate a failing release and a rollback honestly and repeatably. It is off by default and documented. | It is test-only code in the app. In a real project this would live in a test image or feature flag. |

## Known risks and limits (being honest)

1. **Database migrations and rollback.** Rolling back the app is safe here because the schema has one table and never changes. If a release changed the schema, rollback would need backward-compatible migrations (expand, then contract) or a database restore. I documented the risk; I did not build migrations.
2. **No backups.** The volume persists data but is not a backup. A real system needs scheduled dumps or a managed database with point-in-time restore.
3. **Single instance.** A restart causes a short outage. No blue-green, canary or load balancer.
4. **Database role.** The app uses the database owner account. Better: a separate role with only the permissions the app needs.
5. **No authentication on the API.** Out of scope for the assessment, and the port is bound to localhost.
6. **`db_up` freshness.** The gauge updates when `/ready` is called, so real monitoring must probe `/ready`.

## With more time

1. Prometheus, Alertmanager and a Grafana dashboard in a second Compose file, plus the alert rules from `docs/observability.md` as real configuration.
2. Terraform for the Azure Container Apps and PostgreSQL Flexible Server path, deployed from the same workflow with OIDC (no stored cloud secrets).
3. Blue-green or canary release with automatic rollback based on error rate, not just readiness.
4. Versioned database migrations and a tested backup and restore procedure.
5. Image signing (cosign) and an SBOM, deploy by image digest, Dependabot, gitleaks.
6. Least-privilege database role and secrets from Azure Key Vault.
7. Load test to set real alert thresholds from measured baselines.
