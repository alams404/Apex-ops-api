# Incident report: API not ready after database credentials changed

> **Fill in the bracketed parts from YOUR run of `./scripts/demo-incident.sh`.**
> The log is saved in `evidence/incident-db-credentials.log`. Do not submit this report with
> placeholders left in, and do not claim anything your log does not show.

| Field | Value |
| --- | --- |
| Date and time (UTC) | [from your log] |
| Version running | [v1.0.0] |
| Severity | SEV1 (the only instance cannot serve data requests) |
| Environment | Local Docker Compose, synthetic data |
| Fault injected | The app container was restarted with a wrong database password (`APP_DB_PASSWORD`), while the database kept its correct password |

## 1. Symptom

`GET /items` and `GET /ready` stopped working for users. `GET /ready` returned **HTTP 503** with `{"status":"not_ready","db":"down"}`. Meanwhile `GET /health` still returned **HTTP 200**, so a simple "is the process running" check would have reported everything as fine.

## 2. Detection

- Readiness check `/ready` returned 503 (visible in `deploy.sh` / `smoke.sh` output and in `curl -i`).
- `db_up` gauge on `/metrics` reads `0` after the failed check. In production the "Database unreachable" alert (`db_up == 0` for 2 minutes) would have fired.
- Error-level log lines appeared in `docker compose logs app`.

Why liveness and readiness are separate: `/health` answers "should the container be restarted?" and `/ready` answers "should it receive traffic?". Restarting this container would not have fixed the problem, so keeping them separate avoids useless restart loops.

## 3. Investigation (timeline)

| Step | Command | What it showed |
| --- | --- | --- |
| 1 | `curl -i localhost:3000/ready` | 503, `db: down` |
| 2 | `curl -i localhost:3000/health` | 200, process alive |
| 3 | `docker compose ps` | `db` container is **healthy**, so the database itself is up |
| 4 | `docker compose logs --tail=20 app` | JSON lines with `"event":"db_check_failed"` and the error text `password authentication failed for user "apex"` |
| 5 | Compare the app's connection settings with `.env` | The password in the app's `DATABASE_URL` did not match the database's password |

Reasoning: the database is healthy and reachable (otherwise the error would be `ECONNREFUSED` or `ENOTFOUND`), and PostgreSQL explicitly rejected the credentials. So the fault is in the app's configuration, not the network or the database.

## 4. Root cause

The application was started with a database password that did not match the one PostgreSQL was initialised with. (In the demo this is injected on purpose. In real life the common triggers are a rotated password updated in only one place, or a typo in a configuration change.)

## 5. Fix

Redeployed the app with the correct credentials from `.env`:

```bash
docker compose up -d app
```

Verified: `/ready` returned 200 and `/version` reported the expected version. No data was lost because the database was never changed.

## 6. Impact

[State the real duration from your log timestamps.] Data requests failed for that period. No data was lost or corrupted.

## 7. Prevention and follow-up

1. **Alerting:** implement the `db_up == 0 for 2m` alert so a human is told within minutes, not when a user complains (see `docs/observability.md`).
2. **Single source of truth for secrets:** both containers read the password from the same `.env` file, and in the cloud from Key Vault, so they cannot drift apart.
3. **Pre-deploy check:** `deploy.sh` already waits for `/ready` before declaring success, so a bad credential change is caught at deploy time. Add a CI smoke test that starts the stack with the generated `.env` (the `deploy` job does this).
4. **Rotation procedure:** document how to rotate the password safely (change the database user's password first, then update the secret, then restart the app).
5. **Good logging:** the cause was found within one command because the error is logged with an `event` name and the real reason, while the HTTP response gives callers no internal details.
