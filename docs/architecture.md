Architecture and Deployment

1. Application Architecture

The Apex Operations API runs with Docker Compose and consists of:

- Node.js: Handles application requests.
- PostgreSQL: Stores application data.
- Docker Compose: Manages the containers.
- Docker Volume: Keeps database data persistent.

Architecture Diagram

flowchart TD
    A[User] --> B[Node.js API]
    B --> C[PostgreSQL]
    C --> D[Persistent Volume]

2. CI/CD Pipeline

GitHub Actions automates testing, security checks and deployment.

The pipeline runs linting, tests, npm audit, Docker builds and Trivy scans before publishing approved images to GHCR.

CI/CD Diagram

flowchart TD
    A[GitHub Push] --> B[GitHub Actions]
    B --> C[Lint and Tests]
    C --> D[Trivy Scan]
    D --> E[Build Docker Image]
    E --> F[Push to GHCR]
    F --> G[Deploy]
    G --> H[Smoke Test]

3. Deployment and Rollback

Each release uses a versioned Docker image.

After deployment, health checks and smoke tests confirm that the application works.

If deployment fails, the rollback script restores the previous working version.

4. Security

The project uses non-root containers, protected environment variables, private database networking and vulnerability scanning.

5. Future Improvements

Future plans include Prometheus and Grafana monitoring, Azure cloud hosting and Terraform infrastructure automation.

Summary

This project uses Docker, PostgreSQL and GitHub Actions to build, test and deploy an application with basic security and rollback support.