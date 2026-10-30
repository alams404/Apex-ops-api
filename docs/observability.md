Observability and Monitoring

1. Monitoring

The Apex Operations API uses Pino for logging and provides health checks and metrics to help monitor application performance.

Feature| Purpose
Logs| Records application activities and errors.
Request ID| Helps trace individual requests.
"/health"| Checks application health.
"/ready"| Checks database connectivity.
"/metrics"| Provides application performance metrics.

2. Useful Commands

docker compose logs -f app
curl localhost:3000/health
curl localhost:3000/ready
curl localhost:3000/metrics
docker compose ps

3. Alerts and Monitoring

Prometheus and Grafana are proposed tools for monitoring and dashboards.

Important alerts include:

- High application error rates.
- Slow response times.
- Database connection failures.
- Application downtime.
- Frequent container restarts.

4. Incident Response

When a problem occurs:

1. Check application health.
2. Review application and database logs.
3. Identify the cause.
4. Fix the issue or roll back the deployment.
5. Confirm the application is working.

See "docs/incident-report.md" for a failure investigation example.

5. Future Improvements

Prometheus, Grafana and Azure Monitor can provide more advanced monitoring and alerts in a production environment.

Note: These monitoring tools are proposed improvements unless actually installed and configured.