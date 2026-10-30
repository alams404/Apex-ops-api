Decision Memo

1. Project Overview

This project is a Node.js API with PostgreSQL, running through Docker Compose. The aim is to demonstrate testing, security and reliable deployment.

2. Key Decisions

- Node.js and Express: Used to build the API.
- PostgreSQL: Used for data storage.
- Docker: Used to package and run the application.
- GitHub Actions: Used to automate testing and deployment.
- Trivy: Used to scan images for vulnerabilities.
- Health checks: Used to confirm application readiness.
- Versioned images: Used to support rollback.

3. Limitations

- Single application instance.
- No automated database backups.
- No database migrations.
- No API authentication.
- Basic monitoring.

4. Future Improvements

- Deploy to Azure.
- Add Prometheus and Grafana monitoring.
- Automate database backups.
- Improve security and access permissions.
- Add better deployment and rollback automation.

5. Conclusion

This project helped me gain practical experience with Docker, CI/CD, security scanning, deployment and basic monitoring.