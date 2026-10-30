AI Use Disclosure

1. AI Tool Used

ChatGPT (OpenAI) was used as an AI assistant during the development of this Junior DevOps Engineer assessment.

AI assistance was used to support planning, code development, troubleshooting, documentation, testing guidance, Docker configuration, CI/CD configuration, and security improvements.

The AI was used as a supporting tool. I reviewed the generated suggestions, made changes, ran commands, investigated errors, and worked on implementing and understanding the project.

2. What AI Helped With (Specific Contributions)

Area| AI Contribution| My Contribution
Project planning| Helped interpret the assessment requirements and organize the project structure.| Reviewed the requirements and followed the implementation plan.
Application development| Assisted with drafting the Node.js/Express API, PostgreSQL integration, request handling, logging and metrics.| Reviewed the application code, configured the project and tested the endpoints.
Database| Assisted with PostgreSQL connection configuration and database integration.| Configured the database environment and worked on verifying database connectivity.
Testing| Helped develop unit tests, integration tests and intentional failure tests.| Ran tests, reviewed results and investigated failures.
Docker| Assisted with writing and improving the multi-stage Dockerfile, Docker Compose configuration, container hardening and health checks.| Configured the Docker files, built and ran containers, and investigated Docker-related errors.
Security| Assisted with Trivy vulnerability scanning, Hadolint, npm audit and non-root container recommendations.| Ran security checks, reviewed findings and worked on resolving reported issues.
CI/CD| Assisted with creating and troubleshooting the GitHub Actions workflow.| Configured the workflow, pushed changes to GitHub and investigated pipeline failures.
Deployment| Assisted with deployment, smoke-test and rollback script development.| Worked on running deployment commands, checking application readiness and verifying deployment behaviour.
Observability| Assisted with Pino structured logging, request IDs, health checks, readiness checks and Prometheus metrics documentation.| Reviewed the implementation and documented the monitoring and alerting approach.
Documentation| Assisted with the README, architecture diagrams, security notes, runbooks, incident report and observability documentation.| Reviewed and edited the documentation to reflect the project implementation and testing evidence.

3. How AI-Generated Work Was Checked

AI-generated suggestions were not accepted blindly.

The following checks were used during development:

- Application code was reviewed and tested.
- Unit and integration tests were used to check application behaviour.
- PostgreSQL connectivity and database error handling were investigated.
- Dockerfiles and Docker Compose configuration were reviewed and validated.
- GitHub Actions workflows were executed and failures investigated.
- Trivy and other security tools were used to identify potential vulnerabilities and configuration issues.
- Shell scripts were checked and tested.
- Health, readiness and application endpoints were checked during troubleshooting.
- Deployment and rollback behaviour was investigated.
- Git was used to track project changes and submit updates to the repository.

Where a test or command produced an error, I investigated the output and made changes before continuing.

4. Testing and Verification Limitations

Some checks were performed in an AI-assisted development environment, while other checks were performed locally on my computer.

The AI-assisted development environment reported that linting passed, all 11 tests passed, the intentional failure test behaved as expected, ShellCheck passed, and the Compose configuration validated.

However, these results should be distinguished from tests independently executed on my local machine.

The actual Docker image build, running Compose stack, GitHub Actions execution, Trivy and Hadolint results, and real deployment and rollback behaviour must be supported by my own local or CI execution evidence.

I have used the project development and troubleshooting process to investigate these areas and have documented the available results in the repository.

5. What Was Not Independently Verified by AI

AI assistance does not constitute proof that the application works in a real production environment.

The following require actual execution and supporting evidence:

- Successful Docker image builds.
- Successful Docker Compose startup.
- Application and PostgreSQL container health.
- Successful GitHub Actions pipeline execution.
- Trivy vulnerability scan results.
- Hadolint and ShellCheck results.
- Successful deployment and smoke tests.
- Successful rollback using a previously built image.
- Application behaviour under real-world traffic.
- Prometheus scraping and alert delivery in a configured monitoring environment.

Any monitoring features described as proposed or planned should not be presented as already deployed.

6. Security and Configuration

AI assistance was used to identify and improve security practices, including:

- Running containers as a non-root user.
- Using a multi-stage Docker build.
- Applying read-only filesystem restrictions where appropriate.
- Avoiding the publication of unnecessary database ports.
- Keeping environment variables and credentials outside source control.
- Using ".gitignore" to prevent sensitive files from being committed.
- Running vulnerability and configuration checks.
- Using health checks and service readiness conditions.

I am responsible for ensuring that no passwords, database credentials, API keys or other secrets are exposed in the submitted repository.

7. Understanding and Ownership

I take responsibility for the submitted project and the changes made to it.

I have worked through the project implementation, reviewed AI-assisted code, used the terminal to run commands, investigated errors and made changes to the application and infrastructure configuration.

I understand that I may be asked to explain the project during a technical review, including:

- How the Node.js API works.
- How Docker and Docker Compose manage the application and database.
- How PostgreSQL connects to the API.
- How GitHub Actions automates testing and deployment.
- How Trivy helps identify container vulnerabilities.
- How health checks and readiness checks work.
- How deployment and rollback scripts operate.
- How environment variables and secrets are protected.

I am continuing to strengthen my understanding of these technologies and take responsibility for explaining the implementation and its limitations honestly.

8. Final Declaration

I acknowledge that AI tools contributed to parts of the planning, coding, troubleshooting and documentation process.

I have not represented AI-generated work as entirely independent work. I have used AI as a learning and development assistant while participating in the implementation, testing, debugging and documentation of this project.

The submitted code, test results, screenshots and supporting evidence should accurately reflect what was actually implemented and verified.

I accept responsibility for the final submission and for explaining the work during any technical review.