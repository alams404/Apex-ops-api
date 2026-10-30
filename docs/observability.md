# Observability and alert proposal

## What exists today

| Signal | Implementation | Where to see it |
| --- | --- | --- |
| Structured logs | `pino`, one JSON object per line. Fields: `time`, `level`, `service`, `version`, `event`, `requestId`, `method`, `path`, `route`, `status`, `durationMs`, and `err` on failures | `docker compose logs -f app` |
| Request correlation | Every request gets a `requestId` (or reuses a valid incoming `x-request-id`), returned in the response header and written to every log line for that request | `curl -i localhost:3000/health` |
| Liveness | `GET /health` plus the Docker `HEALTHCHECK` | `docker compose ps` |
| Readiness | `GET /ready` (checks the database, 503 when it fails) | `curl -i localhost:3000/ready` |
| Metrics | `GET /metrics`: `http_requests_total{method,route,status}`, `http_request_duration_seconds` histogram, `db_up`, default Node.js process metrics | `curl localhost:3000/metrics` |

Useful log queries (with `jq`):

```bash
docker compose logs --no-log-prefix app | jq -c 'select(.level=="error")'
docker compose logs --no-log-prefix app | jq -c 'select(.event=="http_request" and .status>=500)'
docker compose logs --no-log-prefix app | jq -c 'select(.requestId=="<id from the response header>")'
```

Note on `db_up`: the gauge is updated each time `/ready` is called. Docker's own healthcheck only calls `/health`, so in the local Compose setup `db_up` is refreshed by deploy, smoke and any monitoring probe that calls `/ready`. In a real environment the orchestrator's readiness probe, or Prometheus blackbox probing, calls `/ready` continuously.

## Metrics and alert proposal

Proposed stack: Prometheus scrapes `/metrics` every 15 seconds, Alertmanager routes alerts, Grafana shows dashboards. In Azure the equivalents are Azure Monitor managed Prometheus and Azure Monitor alerts.

| Alert | PromQL (proposal) | Condition | Severity | First action |
| --- | --- | --- | --- | --- |
| High error rate | `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))` | `> 0.05` for 5 minutes | Page | Check recent deploy; roll back if it correlates |
| High latency | `histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))` | `> 0.5` seconds for 10 minutes | Ticket, page if sustained | Check DB load and recent changes |
| Database unreachable | `db_up` | `== 0` for 2 minutes | Page | Runbook: "Database problems" |
| Instance down | `up{job="apex-ops-api"}` | `== 0` for 1 minute | Page | `docker compose ps`, read logs |
| Frequent restarts | container restart count (from the platform) | more than 3 in 15 minutes | Ticket | Look for crash loop in logs |
| No traffic (optional) | `sum(rate(http_requests_total[10m]))` | `== 0` for 30 minutes during business hours | Ticket | Check upstream routing |

Why these thresholds: 5 percent errors for 5 minutes ignores brief blips but catches real regressions quickly; p95 is more honest than the average because it shows what the slowest users see. They are starting points to tune after measuring a real baseline.

Dashboards to build first: request rate, error rate, p50/p95 latency by route, `db_up`, and the running `version`.

## Failure investigation

A full worked example (wrong database credentials) is in [incident-report.md](incident-report.md). It is reproducible with `./scripts/demo-incident.sh`.
