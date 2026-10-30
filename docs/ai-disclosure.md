# AI-use disclosure

> **Edit this so it is true for YOU before submitting.** The assessment allows AI help but requires specific disclosure. Being honest here matters more than looking independent.

## Tool used

Claude (Anthropic), used as an AI assistant during the 48-hour window.

## What AI helped with (specific)

| Area | AI contribution | What I did myself |
| --- | --- | --- |
| Planning | Read the assessment brief and proposed a work plan, repository layout and stack | [Chose to use Node.js/Express and PostgreSQL because I already know them] |
| Application code | Generated the first version of the Express API, the PostgreSQL access layer, JSON logging and Prometheus metrics | [Reviewed it, ran it, and can explain each endpoint] |
| Tests | Drafted the 11 test cases including the intentional-failure gate | [Ran them locally and in CI] |
| Dockerfile and Compose | Drafted the multi-stage Dockerfile and the Compose file with hardening options | [Built and ran them on my machine] |
| CI workflow | Drafted the GitHub Actions workflow | [Pushed it, fixed any failures, captured the runs] |
| Scripts | Drafted `deploy.sh`, `rollback.sh`, `smoke.sh`, `init-env.sh` and the two demo scripts | [Ran them and captured the output] |
| Documentation | Drafted the README, runbook, security notes, observability proposal, architecture diagrams, decision memo, incident report structure and this disclosure | [Edited for accuracy, filled in my own results] |

## How the AI-generated work was checked before it was handed to me

In the AI workspace (which had no Docker daemon available): the lint passed, all 11 tests passed (including the integration test against a real PostgreSQL), the intentional failure produced exactly one failing test with exit code 1, ShellCheck passed on all scripts, the Compose file validated, and the API ran against a real PostgreSQL, including the wrong-password case. The deploy and rollback script logic was exercised with a simulated Docker command, not real containers.

## What was NOT verified by the AI

The Docker image build, the Compose stack, the GitHub Actions run, the Trivy and Hadolint results, and the real release and rollback demo. **I ran these myself and the evidence in `evidence/` is from my own runs.** [Confirm this is true.]

## Understanding and ownership

I read and understood the submitted code and can explain and modify it in the live review. [Keep this sentence only if it is true.]
