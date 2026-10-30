# Runbook

Audience: whoever is on call for the Apex Operations API. Every command is run from the repository root.

Quick reference:

| Task | Command |
| --- | --- |
| First-time setup | `./scripts/init-env.sh` |
| Deploy a version | `./scripts/deploy.sh <version> [--build]` |
| Roll back | `./scripts/rollback.sh [version]` |
| Check health | `./scripts/smoke.sh <expected-version>` |
| Which version is live | `curl localhost:3000/version` |
| Follow logs | `docker compose logs -f app` |
| What is deployed (history) | `cat .release/current .release/previous` |

## 1. Deploy

Normal deployment:

1. Confirm CI is green for the commit you are deploying.
2. Choose a new, explicit version (`v1.1.0`). Never use `latest`; the scripts refuse it.
3. Run:
   ```bash
   ./scripts/deploy.sh v1.1.0 --build          # from source
   ./scripts/deploy.sh sha-1a2b3c4             # or an image already built by CI (set IMAGE in .env to the GHCR name)
   ```
4. The script starts the stack, then waits up to 40 seconds for `/ready` = 200 **and** `/version` = the new version. Only then does it print `DEPLOY SUCCEEDED`.
5. Run `./scripts/smoke.sh v1.1.0` for a full end-to-end check.

Optional: `AUTO_ROLLBACK=1 ./scripts/deploy.sh v1.1.0 --build` rolls back by itself if the new version is not ready (the command still exits non-zero so the failed release is noticed).

## 2. Roll back

When to roll back: the new version fails readiness, error rate rises after a deploy, or a serious bug is found. Roll back first, investigate second.

```bash
./scripts/rollback.sh            # to the version that was live before the last deploy
./scripts/rollback.sh v1.0.0     # or to an explicit version
```

What it does: restarts the app container using the existing image tag, waits for `/ready` and the expected `/version`, and records the new state. It never builds anything, and it never touches the database volume.

If the target image is missing locally the script tries to pull it from the registry in `IMAGE`. If that also fails, rebuild the old version from its git tag: `git checkout v1.0.0 && ./scripts/deploy.sh v1.0.0 --build`.

Verify: `./scripts/smoke.sh <version>` and check that records created before the bad release are still returned by `GET /items`.

## 3. Incident response

Severity guide:

| Level | Meaning | Example | Target response |
| --- | --- | --- | --- |
| SEV1 | Service down for everyone | `/ready` failing on the only instance | Start now |
| SEV2 | Degraded | High error rate, slow responses | Within 30 minutes |
| SEV3 | Minor | Single endpoint misbehaving | Next working day |

Steps:

1. **Detect and confirm.** `curl -i localhost:3000/health` and `/ready`.
   - `/health` fails: the process is down or crash-looping. Go to troubleshooting, "Container will not start".
   - `/health` 200 but `/ready` 503: the app is up but cannot use the database. Go to "Database problems".
2. **Stabilise.** If it started right after a deploy, roll back (section 2).
3. **Investigate.** `docker compose logs --tail=50 app` and `docker compose ps`. Log lines are JSON; use the `event` field (`db_check_failed`, `db_init_retry`, `http_request`, `unhandled_error`). Use a `requestId` to follow one request.
4. **Fix and verify** with `./scripts/smoke.sh <version>`.
5. **Write it up** using the structure in `docs/incident-report.md`: symptom, detection, root cause, fix, prevention.

## 4. Troubleshooting

| Symptom | Likely cause | Check and fix |
| --- | --- | --- |
| `deploy.sh`: `.env not found` | Setup not run | `./scripts/init-env.sh` |
| Compose error `POSTGRES_PASSWORD is not set` | `.env` missing or password blank | `./scripts/init-env.sh`, or fill the value in `.env` |
| Deploy says `DEPLOY FAILED ... not ready` | Bad release, or database unreachable | Read the logs it prints. Roll back with `./scripts/rollback.sh` |
| `/ready` 503, logs say `password authentication failed` | App has wrong DB credentials | Check `DATABASE_URL` inside the container: `docker compose exec app printenv DATABASE_URL`. Compare with `.env`. Redeploy so both match |
| `/ready` 503, logs say `ECONNREFUSED` or `ENOTFOUND` | Database container down | `docker compose ps db`, then `docker compose logs db` and `docker compose up -d db` |
| Container restarts repeatedly | App crashes on start (for example `DATABASE_URL is not set`) | `docker compose logs app`. Fix configuration, redeploy |
| `port is already allocated` | Something else uses port 3000 | Set `APP_PORT=3001` in `.env` and redeploy |
| `image ... not found` during rollback | Old image was pruned | Pull from registry, or `git checkout <tag>` and `deploy.sh <tag> --build` |
| Changed `POSTGRES_PASSWORD` in `.env` but DB still uses the old one | PostgreSQL only reads the password when the volume is first created | Either restore the old value or wipe the volume (**deletes data**): `docker compose down -v` |
| Disk filling up | Old images and logs | `docker image prune`. Keep at least the last two versions for rollback |

Useful commands:

```bash
docker compose ps                                   # container status and health
docker compose logs --tail=50 app                   # recent app logs
docker compose logs --tail=50 db                    # recent database logs
docker compose exec db psql -U apex -d apex_ops -c 'SELECT count(*) FROM items;'
docker inspect --format '{{.State.Health.Status}}' "$(docker compose ps -q app)"
docker compose exec app id -u                       # must print 1000, never 0
```

## 5. Demonstrations used as evidence

```bash
# Release and rollback (requirement 4)
./scripts/demo-release.sh 2>&1 | tee evidence/release-rollback-demo.log

# Failure investigation (requirement 5): requires the stack to be running
./scripts/deploy.sh v1.0.0 --build
./scripts/demo-incident.sh 2>&1 | tee evidence/incident-db-credentials.log
```

CI failure demonstration (requirement 2):

1. `git checkout -b demo-failure && git commit --allow-empty -m "demo: trigger intentional test failure" && git push -u origin demo-failure`
2. Open the Actions tab. The `test` job fails on `release gate: FORCE_FAIL must not be set`, and the `build` and `deploy` jobs are skipped. Screenshot it.
3. Compare with a green run on `main`. Screenshot that too.
