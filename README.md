Apex Operations API

Project Overview

This project was created as part of the Junior DevOps Engineer assessment.

The goal is to build and run a simple API using Docker, automate testing with GitHub Actions, check for security issues and demonstrate a basic deployment and rollback process.

The project also includes monitoring, logging and documentation to make the application easier to manage.

Technologies Used

Technology| Purpose
Node.js and Express| Build the API
PostgreSQL| Store application data
Docker| Package the application
Docker Compose| Run the application and database
GitHub Actions| Automate testing and builds
Trivy| Scan for security issues
Git and GitHub| Manage and store project code

Project Architecture

The diagram below shows how the main parts of the project work together.

flowchart TD
    A[Developer] --> B[GitHub Repository]
    B --> C[GitHub Actions]
    C --> D[Testing and Security Scans]
    D --> E[Docker Image]
    E --> F[Deployment]
    F --> G[Node.js API]
    G --> H[PostgreSQL Database]

Architecture screenshot

"Project Architecture" (evidence/architecture.png)

Project Structure

The project is organised into folders to make the application and its supporting files easier to understand.

apex-operations-api/
│
├── app/
│   └── Application source code
│
├── scripts/
│   └── Deployment and rollback scripts
│
├── docs/
│   ├── architecture.md
│   ├── security.md
│   ├── observability.md
│   ├── runbook.md
│   ├── decision-memo.md
│   ├── incident-report.md
│   └── ai-disclosure.md
│
├── evidence/
│   └── Project screenshots
│
├── Dockerfile
├── docker-compose.yml
├── package.json
├── .dockerignore
├── .gitignore
└── README.md

Project folder screenshot

"Project Structure" (evidence/project_structure.png)

How to Run the Project

Requirements

Before running the project, make sure you have:

1. Docker installed.
2. Docker Compose available.
3. Git installed.

Step 1: Clone the Repository

git clone YOUR_GITHUB_REPOSITORY_URL

Enter the project folder:

cd apex-operations-api

Step 2: Configure Environment Variables

Create your environment file using the example provided in the project.

cp .env.example .env

Update the values in ".env" using your local configuration.

Do not upload ".env" or real passwords to GitHub.

Step 3: Build and Start the Application

docker compose up --build -d

Step 4: Check Running Containers

docker compose ps

Step 5: View Application Logs

docker compose logs -f

Docker containers screenshot

"Docker Containers" (evidence/docker_containers.png)

Health Checks

The application provides health checks to help confirm whether it is running correctly.

The health endpoint checks the application status.

The readiness endpoint helps confirm whether the application is ready to receive requests.

Example commands:

curl http://localhost:3000/health

curl http://localhost:3000/ready

Use the actual application port configured in your project.

Health check screenshot

"Health Checks" (evidence/health_checks.png)

Testing

Automated tests help confirm that the application works as expected.

The project uses automated checks to identify problems before deployment.

Examples include:

1. Application tests.
2. Docker build checks.
3. Dependency security checks.
4. Docker image scanning with Trivy.
5. Code and configuration checks.
6. A test that intentionally fails to demonstrate that the pipeline blocks an unsuccessful build or deployment.

Test results screenshot

"Test Results" (evidence/test_results.png)

Continuous Integration

GitHub Actions is used to automate the project checks whenever code is pushed to the repository or a pull request is created.

The workflow checks the code, runs tests, builds the Docker image and performs security scanning.

A failed check should prevent the deployment process from continuing.

Successful GitHub Actions run

"Successful CI Run" (evidence/ci_success.png)

Failed GitHub Actions run

"Failed CI Run" (evidence/ci_failure.png)

Security

Security is an important part of this project.

The following practices are used:

1. Environment variables are used for sensitive configuration.
2. Passwords and secrets are not stored in the source code.
3. Docker images are scanned with Trivy.
4. Dependencies are checked for known vulnerabilities.
5. The application container is configured to run without root privileges where supported.

Trivy security scan screenshot

"Trivy Security Scan" (evidence/trivy_scan.png)

Deployment and Rollback

The project includes scripts for deployment and rollback.

Deployment is used to release an application version.

Rollback is used to return to a previous working version if a release causes problems.

The scripts should be run from the project directory.

./scripts/deploy.sh

./scripts/rollback.sh

Deployment screenshot

"Deployment" (evidence/deployment.png)

Rollback screenshot

"Rollback" (evidence/rollback.png)

Monitoring and Logs

Application logs help identify errors and understand what happens when the application is running.

Health checks help confirm application availability.

The project also includes a metrics endpoint where configured.

Example:

curl http://localhost:3000/metrics

Application logs screenshot

"Application Logs" (evidence/application_logs.png)

Metrics screenshot

"Application Metrics" (evidence/metrics.png)

Documentation

Additional project information is available in the "docs" folder.

File| Description
architecture.md| Explains the project architecture
security.md| Describes security practices
observability.md| Explains logging and monitoring
runbook.md| Provides operational instructions
decision-memo.md| Explains important project decisions
incident-report.md| Documents a failure investigation
ai-disclosure.md| Explains how AI assistance was used

Project Evidence

Screenshots are stored in the "evidence" folder.

They provide visual proof of the project setup, Docker containers, health checks, test results, security scans, deployment and rollback.

Only screenshots from actual project runs should be included.

Limitations and Future Improvements

This project is a learning and assessment project.

Future improvements could include:

1. Hosting the application on a cloud platform.
2. Adding more automated tests.
3. Improving monitoring and alerting.
4. Adding stronger access controls.
5. Improving deployment automation.

AI Assistance

ChatGPT was used to support planning, troubleshooting, code explanations and documentation during this project.

The implementation and test results should be reviewed and verified by the project owner.

More details are available in "docs/ai-disclosure.md".

Conclusion

This project demonstrates the basic DevOps process of building an application, running it with Docker, automating checks, scanning for security issues and managing deployment.

It also demonstrates the importance of documentation, monitoring and recovery when problems occur.