# Apex Operations API

This is my submission for the Apex AI Arabia Junior DevOps Engineer practical assessment. I built a small API, packaged it in Docker, ran it locally with Docker Compose, and set up a GitHub Actions pipeline that tests, scans and builds it before anything gets deployed. I also wrote a release and rollback process and tested it on my own laptop.

Everything here uses made up data. No real customers, no real credentials, and no paid cloud resources.

## What I built

The API is written in Node.js with Express and stores its data in PostgreSQL. It tracks simple operations items, things like "replace failed disk" or "rotate TLS certificate", each with a status of open, in progress or resolved.

The endpoints are:

1. `GET /health` tells you the process is alive. It never touches the database.
2. `GET /ready` tells you the app can really do its job. It checks the database and answers 503 if the database is not reachable.
3. `GET /version` shows which version and git commit is running. My deploy and rollback scripts use this to confirm the right version is live.
4. `GET /metrics` exposes Prometheus metrics such as request counts, request duration and a database up gauge.
5. `GET /items` lists items and `POST /items` creates one. Bad input gets a 422 with a clear message.

Logs are written as one JSON object per line, and every request gets an id that also comes back in the `x-request-id` response header, so I can follow a single request through the logs.

## How to run it

I ran everything on a Windows 10 laptop with Docker Desktop and Git Bash. It should work the same on Linux or macOS.

You need Docker with Compose v2, Git, and Bash. Node.js 20 or newer is only needed if you want to run the tests outside Docker.

```bash
git clone <repo url>
cd apex-ops-api

./scripts/init-env.sh
./scripts/deploy.sh v1.0.0 --build
./scripts/smoke.sh v1.0.0
```

The first command creates a `.env` file with a random database password, so no secret is ever written in the repository. The second builds the image, tags it `v1.0.0`, starts the app and the database, and waits until `/ready` returns 200 and `/version` reports the right version. The third runs a quick end to end check and should finish with `SMOKE TEST PASSED`.

Then try it:

```bash
curl localhost:3000/health
curl localhost:3000/ready
curl localhost:3000/version
curl -X POST localhost:3000/items -H 'Content-Type: application/json' -d '{"name":"Rotate TLS certificate"}'
curl localhost:3000/items
```

To stop everything, run `docker compose down`. Add `-v` only if you want to delete the stored data as well.

If you get an error saying a script is not found or has the wrong line endings on Windows, run `sed -i 's/\r$//' scripts/*.sh` once and try again.

### Proof that it runs

<img width="670" height="165" alt="healthy" src="https://github.com/user-attachments/assets/0ef0ff51-edbc-4ecf-9de6-c63a9d6b4635" />

<img width="554" height="226" alt="ready" src="https://github.com/user-attachments/assets/d7ee3719-f29d-4289-9ab7-efd4999e017a" />

<img width="396" height="248" alt="smoke text" src="https://github.com/user-attachments/assets/18e2f301-af25-4565-9fed-0880597cf9ea" />


## The container and Compose setup

The Dockerfile has two stages. The first installs only the production dependencies, and the second copies just what is needed to run. The app runs as the unprivileged `node` user, and the image has a built in `HEALTHCHECK`.

The Compose file runs the app and PostgreSQL 16. The database data lives in a named volume called `pgdata`, so it survives restarts, redeploys and rollbacks. The app only starts once the database reports healthy. The API is published on 127.0.0.1 only, and the database has no published port at all, so only the app can reach it. I also dropped all Linux capabilities from the app container, made its filesystem read only, and set memory and process limits.

## Tests

There are 11 automated checks in `app/test`. Ten are unit style checks that use a fake database, so they run in a second without Docker. The eleventh is an integration check that talks to a real PostgreSQL and only runs when `DATABASE_URL` is set, which is the case in CI.

```bash
cd app
npm ci
npm run lint
npm test
```

The intentional failure is a check called "release gate: FORCE_FAIL must not be set". It passes normally. When `FORCE_FAIL=true` it fails on purpose, to prove the pipeline stops and nothing gets deployed.

```bash
FORCE_FAIL=true npm test
```
<img width="695" height="523" alt="ALL TEST PASS EVIDENCE" src="https://github.com/user-attachments/assets/dc4d1c3b-143b-4c27-9be2-50e5d9481720" />

<img width="673" height="635" alt="INTENTIONAL FAILURE" src="https://github.com/user-attachments/assets/8c3e75dd-4c03-4c25-9bbd-a4ece08d46d2" />


## The CI pipeline

The workflow is in `.github/workflows/ci.yml` and runs these jobs in order. Each one waits for the one before it, so a failure stops everything after it.

1. Lint checks the JavaScript with ESLint, the Dockerfile with Hadolint, the shell scripts with ShellCheck, validates the Compose file, and fails if a `.env` file was ever committed.
2. Test runs the unit checks and the PostgreSQL integration check against a real database container.
3. Audit runs `npm audit` on the production dependencies and fails on high or critical findings.
4. Build builds the image, confirms it does not run as root, scans it with Trivy, and pushes it to GitHub Container Registry. Pushing only happens from the main branch or a version tag.
5. Deploy starts the stack with Docker Compose on the runner and runs the smoke test against it.

   <img width="1017" height="524" alt="workflow" src="https://github.com/user-attachments/assets/1e6901fe-5bee-4009-8cc3-9fb73265ed32" />



To show that CI really blocks a bad change, I pushed a branch called `demo-failure`. On that branch the intentional failure is switched on automatically, so the test job fails and the build and deploy jobs are skipped.

<img width="1333" height="600" alt="FELL GREEN RUN ON MAIN" src="https://github.com/user-attachments/assets/63c900f6-485b-432b-a272-8606e650a421" />

<img width="1259" height="511" alt="INTENTIONAL FAILURE CI" src="https://github.com/user-attachments/assets/9cbcd664-86e4-450a-a324-3278f015dd47" />

<img width="1105" height="600" alt="PACKAGE 2" src="https://github.com/user-attachments/assets/b230e80b-3aa5-49d6-8094-a19f8ffc67a3" />



![Scan results](evidence/screenshots/12_scans.png)
*Trivy and npm audit results from the pipeline.*

### Things that broke along the way

Getting the pipeline working was not smooth, and I would rather say so than pretend otherwise.

The first run failed in the build job because the Trivy action version I had pinned could not be found, so I updated it to a version that exists. Later the deploy job failed because I typed `bash./scripts/init-env.sh` without a space, which gave exit code 127, command not found. I also found that Git on Windows commits scripts without the executable bit, so I fixed that with `git update-index --chmod=+x scripts/*.sh`. Without it, scripts that call each other directly would fail on the Linux runner.

Locally, my first smoke test failed because `/version` reported `dev` instead of `v1.0.0`. I had started the stack with a plain `docker compose up --build`, which builds without the version argument. The smoke test caught it, and rebuilding through `deploy.sh` fixed it. That is exactly the kind of mistake the version check is there for.

![Smoke test catching a wrong version](evidence/screenshots/04_smoke_test_caught_version.png)
*The smoke test failing because the image was built without its version.*

## Release and rollback

Every image gets an explicit version tag, such as `v1.0.0`. The scripts refuse `latest`, because a rollback needs an exact, unchanging version to return to.

`deploy.sh` records what is currently running, starts the new version, and only reports success once `/ready` returns 200 and `/version` matches. If the new version never becomes ready it prints the app logs and exits with an error. Setting `AUTO_ROLLBACK=1` makes it roll back by itself.

`rollback.sh` never rebuilds anything. It restarts an image that already exists, checks it is ready, and leaves the database volume untouched.

```bash
./scripts/deploy.sh v2.0.0 --build
./scripts/rollback.sh
```

To demonstrate the whole thing in one go, `demo-release.sh` deploys v1.0.0, creates a record, deploys a deliberately broken v2.0.0, detects that it fails, rolls back to v1.0.0, and then proves the service works and the record is still there. The broken version is built with `INJECT_FAULT=bad-release`, which makes the readiness check fail. That switch is off by default and only exists for this demonstration.

```bash
./scripts/demo-release.sh 2>&1 | tee evidence/release-rollback-demo.log
```

![Release and rollback demo](evidence/screenshots/10_release_rollback.png)
*The rollback succeeding, the smoke test passing on v1.0.0, and the item created earlier still in the list. The full output is saved in `evidence/release-rollback-demo.log`.*

## Observability and the failure I investigated

Besides the JSON logs and the health endpoints, the app exposes Prometheus metrics. The alert rules I would use are written up in `docs/observability.md`, for example an error rate above 5 percent for 5 minutes, a slow 95th percentile response time, and the database being down for 2 minutes.

For the failure investigation I started the app with a wrong database password while the database itself kept the right one. `/health` still answered 200, because the process was fine, but `/ready` answered 503. The container list showed the database was healthy, and the logs showed `password authentication failed`. That pointed straight at the app's credentials, not the network or the database. I restarted the app with the correct password and `/ready` went back to 200.

```bash
./scripts/demo-incident.sh 2>&1 | tee evidence/incident-db-credentials.log
```

![Failure investigation](evidence/screenshots/11_incident.png)
*Health returning 200 while ready returns 503, the log lines that gave the cause, and the recovery.*

The full write up is in `docs/incident-report.md`.

## Security, secrets and cloud hosting

The database password is generated randomly on first run and kept in a `.env` file that is ignored by Git. Only `.env.example` is committed, and the pipeline fails if a `.env` file ever gets tracked. The pipeline itself needs no stored secrets, because it logs in to the registry with the short lived token GitHub gives every run.

Least privilege shows up in several places: the unprivileged container user, the read only filesystem, dropped capabilities, localhost only publishing, no database port exposed, and minimal permissions on the CI token.

Dependencies are checked with `npm audit` and the image is scanned with Trivy on every run.

For cloud hosting, the cheapest sensible path I wrote up is Azure Container Apps on the consumption plan with a small burstable PostgreSQL server, secrets in Key Vault, and a capped log workspace so there are no surprise bills. I only documented this in `docs/security.md`. I did not create anything in the cloud.

## Assumptions and trade offs

I assumed one machine and one instance, because that is what the brief asks for. A restart means a short outage, and there is no blue green deployment. Rolling back the app is safe here because the database schema never changes, but a release that changed the schema would need extra care. The volume keeps the data, but it is not a backup. The app also uses the database owner account, where a real system should use a more limited role. The full list of decisions and what I would add with more time is in `docs/decision-memo.md`.

## Use of AI

I used Claude, an AI assistant, to help plan the work and to draft much of the code, scripts and documents. I ran everything myself on my own machine, read through the code so I can explain it, and fixed the problems that came up. The specific details are in `docs/ai-disclosure.md`.

## Where to find things

The code is in `app/`. The Dockerfile and `docker-compose.yml` are in the project root. The pipeline is in `.github/workflows/ci.yml` and the scripts are in `scripts/`. The documents are in `docs/`: architecture, runbook, security, observability, incident report, decision memo and AI disclosure. Logs and screenshots are in `evidence/`.
