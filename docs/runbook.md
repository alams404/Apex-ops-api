Runbook – Apex Operations API

This guide explains how to deploy, monitor and troubleshoot the application.

All commands should be run from the project root.

1. Deployment

Make sure GitHub Actions passes before deploying.

./scripts/deploy.sh v1.1.0 --build
./scripts/smoke.sh v1.1.0

Check that the application is healthy and running the correct version.

2. Rollback

If a deployment fails, return to the previous working version.

./scripts/rollback.sh
./scripts/smoke.sh v1.0.0

Rollback should not delete database records.

3. Health Checks and Logs

Check application health:

curl localhost:3000/health
curl localhost:3000/ready

Check containers and logs:

docker compose ps
docker compose logs --tail=50 app
docker compose logs --tail=50 db

4. Troubleshooting

- Application not starting: Check application logs.
- Database connection failure: Check database credentials and database logs.
- Port already in use: Check which process is using port 3000.
- Deployment failure: Investigate the logs and roll back if necessary.

Never run "docker compose down -v" unless you intend to delete the database volume and its data.

5. Evidence

Run the demonstration scripts and save their output:

./scripts/demo-release.sh
./scripts/demo-incident.sh

Save screenshots, logs and GitHub Actions results in the "evidence/" folder.

Final Note

Always verify application health after deployment or rollback. Record important incidents and their solutions in "docs/incident-report.md".