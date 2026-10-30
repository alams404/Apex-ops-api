Incident Report: API Not Ready After Database Credentials Changed

Incident Summary

Field| Value
Date| 2026-10-30
Time (UTC)| Approximately 07:46
Application| apex-ops-api
Version| v1.0.0
Severity| SEV1 (controlled local test)
Environment| Local Docker Compose, synthetic data
Database| PostgreSQL 16
Incident Type| Database authentication failure

1. Symptom

The API became unavailable for data requests after the application container was restarted with an incorrect database password.

- "GET /items" failed.
- "GET /ready" returned HTTP 503.
- The readiness response reported "{"status":"not_ready","db":"down"}".
- "GET /health" continued returning HTTP 200.

This demonstrated that the application process was running but could not successfully communicate with the database.

2. Detection

The incident was detected through the application's readiness checks and structured application logs.

The following indicators confirmed the failure:

- The "/ready" endpoint returned HTTP 503.
- The database availability metric ("db_up") reported 0.
- Application logs recorded the "db_check_failed" event.
- PostgreSQL authentication errors reported: "password authentication failed for user "apex"".

The separate health and readiness endpoints helped distinguish application process health from database availability.

"/health" checks whether the application process is alive, while "/ready" checks whether the application can receive traffic.

3. Investigation and Timeline

Step| Investigation| Result
1| "curl -i localhost:3000/ready"| HTTP 503, database down
2| "curl -i localhost:3000/health"| HTTP 200, process alive
3| "docker compose ps"| Database container healthy
4| "docker compose logs --tail=20 app"| Authentication failure found in application logs
5| Compared application database credentials with ".env"| Password mismatch identified
6| Restored correct application credentials and restarted app| Application became ready again

Investigation Findings

The PostgreSQL container was healthy and running.

The application logs showed repeated database authentication failures for user "apex".

This confirmed that the problem was not caused by a database container failure or network connectivity issue.

The application was using incorrect database credentials.

4. Root Cause

The root cause was a mismatch between the database password configured for the application and the password configured for PostgreSQL.

During the controlled fault-injection test, the application container was restarted with an incorrect database password while the database retained its correct password.

PostgreSQL rejected the authentication attempts.

As a result, the application could not establish a database connection and failed its readiness checks.

5. Resolution and Recovery

The issue was resolved by restoring the correct database password from the local ".env" configuration.

The following recovery steps were performed:

1. Identified the authentication failure from the application logs.
2. Confirmed that the PostgreSQL container was healthy.
3. Restored the correct database credentials.
4. Recreated the application container.
5. Waited for the database health check to pass.
6. Waited for the application readiness check to succeed.
7. Verified the API using the "/ready" endpoint.

Recovery Verification

The application logs confirmed:

- Database container running and healthy.
- Application container recreated and started.
- Application reported "READY".
- "GET /ready" returned HTTP 200.

The application successfully recovered after the correct credentials were restored.

6. Impact

This was a controlled fault-injection exercise using synthetic data in a local Docker Compose environment.

The observed interval between the first logged authentication failure at approximately 07:46:19 UTC and successful application readiness at approximately 07:46:40 UTC was about 20 seconds.

During this period:

- API data requests were unavailable.
- The readiness endpoint returned HTTP 503.
- The application process remained alive.
- The database container remained healthy.

No data was lost or corrupted because the database itself was not modified during the test.

No production users or production data were affected.

7. Prevention and Follow-up Actions

The following improvements are recommended to reduce the risk of similar incidents.

1. Monitoring and Alerting

Implement an alert when the "db_up" metric remains at 0 for two consecutive minutes.

This will help identify database connectivity problems before users report them.

2. Centralized Secret Management

Ensure the application and database use consistent database credentials.

For cloud deployments, store sensitive credentials in a secure secret manager such as Azure Key Vault or an equivalent service.

Never commit real passwords or ".env" files to GitHub.

3. Pre-deployment Validation

Keep the readiness check in the deployment process.

The deployment script should only report success after the "/ready" endpoint returns HTTP 200.

Add a CI smoke test to validate database connectivity before declaring a deployment successful.

4. Secure Password Rotation

Document a safe database password rotation procedure.

Update the database credentials and application configuration in a coordinated manner, then restart the application and verify readiness.

5. Structured Logging

Continue using structured JSON application logs with meaningful event names.

The "db_check_failed" event helped identify the root cause quickly without exposing internal database credentials in the HTTP response.

8. Lessons Learned

This incident demonstrated several important DevOps practices:

- A running container does not necessarily mean an application is ready.
- Health checks and readiness checks serve different purposes.
- Database health and application database connectivity must be monitored separately.
- Structured logs make troubleshooting faster.
- Secrets must be managed consistently across application and database services.
- Deployment pipelines should verify application readiness before declaring success.

9. Evidence

The following evidence supports this incident report:

- "evidence/incident-db-credentials.log"
- "scripts/demo-incident.sh"
- Docker Compose container health status.
- Application structured logs.
- HTTP 503 readiness failure.
- HTTP 200 recovery verification.

10. Final Status

Incident Status: RESOLVED

The controlled database authentication failure was successfully reproduced, detected, investigated and resolved.

The application returned to a healthy and ready state after the correct database credentials were restored.

The exercise demonstrated database failure detection, structured logging, container recovery, readiness validation and incident documentation.