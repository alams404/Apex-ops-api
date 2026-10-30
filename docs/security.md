Security, Secrets Management and Cloud Deployment

1. Secrets Management

Security is an important part of this project. Passwords, database credentials and other sensitive information should never be exposed in the source code or uploaded to GitHub.

The following practices are used in this project:

Protecting passwords and credentials

- The ".env" file contains the application's private configuration and is excluded from Git using ".gitignore".
- An ".env.example" file is provided to show the required environment variables without exposing real passwords.
- The actual ".env" file should never be committed to the repository.
- The "scripts/init-env.sh" script generates a random database password when the environment file is first created.
- Docker Compose checks that the required database password is available before starting the services.

Limiting access to secrets

The database password is only provided to the PostgreSQL container.

The application container receives a database connection string through "DATABASE_URL" so that it can communicate with PostgreSQL without receiving unnecessary configuration.

Sensitive information is also protected in application logs. Password fields and Authorization headers are redacted to prevent credentials from appearing in log output.

Protecting local environment files

The environment setup script restricts access to the ".env" file by setting its permissions to "600".

This means that only the file owner can read or modify it.

The ".dockerignore" file also excludes sensitive files, including ".env" and ".git", from the Docker build context.

GitHub Actions receives the environment variables it needs at runtime rather than copying private credentials into the Docker image.

What happens if a password is exposed?

If a password or other secret is accidentally committed to GitHub, simply deleting the file is not enough.

The exposed password must be changed immediately. The Git history should also be cleaned, and any other affected credentials should be reviewed.

For a production environment, secrets should be rotated regularly and whenever there is a suspected security incident.

---

2. Container Security and Least Privilege

The application uses several security measures to reduce the risk of a compromised container affecting the host system.

Running containers with limited permissions

The Node.js application runs using an unprivileged "node" user rather than the root user.

The CI workflow also checks that the application image does not run as root.

Protecting the container filesystem

The application container uses a read-only filesystem where supported.

Temporary files are written to a dedicated temporary filesystem rather than allowing unnecessary changes to the main container filesystem.

Restricting container privileges

Docker Compose applies additional security restrictions:

- Linux capabilities are dropped using "cap_drop: ALL".
- Privilege escalation is disabled using "no-new-privileges".
- Memory usage is limited to reduce the risk of excessive resource consumption.
- The application container has a process limit to prevent uncontrolled process creation.

Network security

The application API is published on "127.0.0.1" rather than being exposed on every network interface.

The PostgreSQL database does not have a publicly published port. It is accessible through the private Docker Compose network.

This reduces unnecessary network exposure.

Docker image security

The application uses a multi-stage Docker build.

This keeps development tools and unnecessary dependencies out of the final production image.

Only the dependencies required to run the application should be included in the final image.

GitHub Actions permissions

The CI/CD workflow follows the principle of least privilege.

The workflow uses only the permissions required for each job.

For example:

- The build job receives permission to publish packages.
- The deployment job receives permission to read the required package.
- Container image publishing is restricted to the "main" branch or approved version tags.

Known security limitation

The PostgreSQL user created by the official PostgreSQL image has elevated privileges within the database server.

For a production environment, a separate application database user should be created with only the permissions it needs.

For example, the application user should have the necessary "SELECT" and "INSERT" permissions on the "items" table rather than unnecessary administrative access.

---

3. Dependency and Container Vulnerability Scanning

Security scanning helps identify outdated packages, vulnerable dependencies and unsafe Docker configurations before deployment.

The project uses the following tools:

Tool| Purpose| Where it runs
npm audit| Checks Node.js dependencies for known vulnerabilities.| CI audit job
Trivy| Scans Docker images for operating system and library vulnerabilities.| CI build job
Hadolint| Checks Dockerfiles for common mistakes and security best practices.| CI lint job
ShellCheck| Checks shell scripts for possible errors and unsafe practices.| CI lint job

Security failure rules

The pipeline is configured to stop when the defined security requirements are not met.

- npm audit checks for HIGH and CRITICAL dependency vulnerabilities.
- Trivy checks the container image for HIGH and CRITICAL vulnerabilities that have an available fix.
- Hadolint reports Dockerfile issues.
- ShellCheck identifies problems in shell scripts.

These checks help prevent known security issues from reaching the deployment stage.

Running security scans locally

The following commands can be used to perform security checks from the project directory.

Check Node.js dependencies:

cd app
npm audit --omit=dev

Scan the Docker image using Trivy:

docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  apex-ops-api:v1.0.0

Handling vulnerability findings

When a vulnerability is discovered, the first step is to check whether an updated dependency or base image is available.

The image should then be rebuilt and scanned again.

If no fix is available, the issue should be documented with its potential impact, risk assessment and review date.

The "--ignore-unfixed" option helps prevent the pipeline from failing on vulnerabilities that do not yet have an available fix. However, those findings should still be reviewed.

Future security improvements

Additional security improvements could include:

- Dependabot for automatic dependency update notifications.
- Automated Docker base image updates.
- Gitleaks for detecting accidentally committed passwords and API keys.

These improvements would provide additional protection as the project grows.

---

4. Cost-Aware Cloud Deployment Plan (Microsoft Azure)

The current project is designed to run locally using Docker Compose.

For a future cloud deployment, Microsoft Azure is a suitable option.

The assessment does not require paid cloud resources, so this section describes a proposed deployment approach rather than claiming that the application is already running in Azure.

Recommended Azure services

Component| Recommended service| Reason
Application hosting| Azure Container Apps| Runs Docker containers without requiring management of virtual machines.
Database| Azure Database for PostgreSQL Flexible Server| Provides a managed PostgreSQL database with backups and maintenance support.
Container images| GitHub Container Registry (GHCR)| Allows the existing CI/CD workflow to publish and store images.
Secrets management| Azure Key Vault| Stores database passwords and other sensitive credentials securely.
Monitoring| Azure Monitor| Helps monitor application health, performance and errors.
Deployment| GitHub Actions| Automates application deployment.

Keeping cloud costs low

The deployment should start with small resources and only increase when the application requires more capacity.

For example:

- Use a small Azure Container Apps configuration.
- Scale down or to zero when the application is not required, where supported by the configuration.
- Start with the smallest suitable PostgreSQL service.
- Avoid unnecessary database storage and excessive resource allocation.
- Use GitHub Container Registry to avoid introducing an unnecessary container registry cost.
- Set up an Azure budget with email notifications to monitor spending.

A small Linux virtual machine running Docker Compose behind a reverse proxy with automatic HTTPS is another low-cost option.

However, this approach requires managing operating system updates, backups and server availability yourself. It is more suitable for a prototype or small deployment.

Protecting secrets in Azure

For a cloud deployment, Azure Key Vault should be used to store sensitive credentials.

The application should access these secrets through managed identity rather than storing passwords directly in configuration files.

This reduces the need to maintain long-lived credentials.

Cloud deployment process

The existing GitHub Actions workflow can be extended to deploy the application to Azure.

The proposed deployment process is:

1. A developer pushes code to GitHub.
2. GitHub Actions runs linting, tests and security checks.
3. The Docker image is built and scanned.
4. The approved image is pushed to GitHub Container Registry.
5. GitHub Actions authenticates with Azure using OpenID Connect (OIDC).
6. The application is updated in Azure Container Apps.
7. Health and readiness checks confirm that the application is running correctly.

Azure Container Apps revisions can also help with deployment management and returning to a previous working revision.

Monitoring and cost control

Azure Monitor and Log Analytics can be used to collect application logs, monitor performance and create alerts.

To avoid unexpected costs, log ingestion should be limited and retention periods should be configured appropriately.

A monthly cost review and budget alerts should be part of the cloud operating process.

Future improvements

As the project grows, additional improvements could include:

- Infrastructure as Code using Terraform.
- Automated deployment to separate development and production environments.
- More detailed monitoring dashboards.
- Automated security and dependency updates.
- Stronger database permissions.
- Automated backup and recovery testing.

Kubernetes through Azure Kubernetes Service (AKS) could be considered in the future if the application grows to require multiple services and more advanced orchestration.

For the current project, Docker Compose and a simple container hosting service are more appropriate.

---

5. Summary

Security has been considered throughout the development of this project.

The main priorities are protecting sensitive information, limiting container privileges, scanning dependencies and Docker images, and ensuring that deployment processes are controlled.

The project currently uses a local Docker-based environment, while the Azure section provides a proposed path for future cloud hosting.

The goal is to build an application that is secure, maintainable, cost-conscious and suitable for further development.