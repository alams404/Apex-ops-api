# Evidence checklist

Every claim in the README and docs needs evidence from YOUR runs. Capture these, then tick them off.
Never edit logs by hand. Never submit evidence you did not produce.

| # | Evidence | How to produce it | Save as |
| --- | --- | --- | --- |
| 1 | Local tests pass | `cd app && npm ci && npm run lint && npm test 2>&1 \| tee ../evidence/tests-local.log` | `tests-local.log` |
| 2 | Intentional failure | `cd app && FORCE_FAIL=true npm test 2>&1 \| tee ../evidence/tests-intentional-failure.log` | `tests-intentional-failure.log` |
| 3 | Image runs as non-root | `docker compose exec app id -u` (expect 1000) | `non-root.txt` or screenshot |
| 4 | Stack healthy | `docker compose ps` and `./scripts/smoke.sh v1.0.0` | `compose-ps.txt`, `smoke.log` |
| 5 | Persistent storage | Create an item, `docker compose down` (no `-v`), `./scripts/deploy.sh v1.0.0`, list items again | `persistence.log` |
| 6 | Green CI run | Screenshot of the Actions run on `main` with all jobs green | `ci-green.png` |
| 7 | Red CI run blocks deploy | Screenshot of the `demo-failure` run: `test` red, `build` and `deploy` skipped | `ci-red-blocked.png` |
| 8 | Image in registry | Screenshot of the GHCR package page showing the version tags | `ghcr-tags.png` |
| 9 | Scan results | Open the `build` job in Actions and screenshot the Trivy step; screenshot the `audit` job | `trivy.png`, `npm-audit.png` |
| 10 | Release and rollback | `./scripts/demo-release.sh 2>&1 \| tee evidence/release-rollback-demo.log` | `release-rollback-demo.log` |
| 11 | Failure investigation | `./scripts/deploy.sh v1.0.0 --build` then `./scripts/demo-incident.sh 2>&1 \| tee evidence/incident-db-credentials.log` | `incident-db-credentials.log` |
| 12 | Structured logs and metrics | `docker compose logs --tail=10 app` and `curl localhost:3000/metrics \| head -40` | `logs-sample.txt`, `metrics-sample.txt` |
| 13 | Fresh-clone test | Clone to a new empty folder, follow only the README, note that it worked | `fresh-clone.log` |

After capturing, fill the bracketed parts of `docs/incident-report.md` and `docs/ai-disclosure.md` from what you actually saw.
