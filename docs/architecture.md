# Architecture and process diagrams

## 1. Runtime architecture (local deployment)

```mermaid
flowchart LR
    user["Developer / curl<br/>127.0.0.1:3000"] --> app
    subgraph host["Docker host (Docker Compose project: apex-ops)"]
        app["app container<br/>apex-ops-api:VERSION<br/>non-root, read-only fs"]
        db[("db container<br/>postgres:16-alpine")]
        vol[("named volume<br/>pgdata")]
        app -- "SQL over private network" --> db
        db --- vol
    end
    prom["Prometheus (proposed)"] -. "scrapes /metrics" .-> app
```

- Only the API port is published, and only on `127.0.0.1`. The database has no published port.
- The `db` container has a healthcheck (`pg_isready`). The `app` container starts only when the database is healthy (`depends_on: condition: service_healthy`).
- Data lives in the `pgdata` named volume, so it survives container restarts, redeploys and rollbacks.

## 2. Commit to release (process)

```mermaid
flowchart TD
    push["git push"] --> lint["lint<br/>ESLint, Hadolint, ShellCheck,<br/>compose validation, no .env committed"]
    lint --> test["test<br/>unit + PostgreSQL integration"]
    lint --> audit["audit<br/>npm audit (high+)"]
    test --> build
    audit --> build["build<br/>docker build, non-root check,<br/>Trivy scan"]
    build -->|"main or v* tag only"| push_img["push image to GHCR<br/>tag: sha-xxxxxxx or vX.Y.Z"]
    push_img --> deploy["deploy<br/>docker compose up + smoke test"]
    test -. "any failure" .-> stop["pipeline stops: no build, no deploy"]
    lint -. "any failure" .-> stop
    audit -. "any failure" .-> stop
    build -. "any failure" .-> stop
```

## 3. Release and rollback (process)

```mermaid
sequenceDiagram
    participant Op as Operator
    participant D as deploy.sh
    participant C as Compose
    participant A as API
    Op->>D: deploy.sh v2.0.0 --build
    D->>D: record current=v2.0.0, previous=v1.0.0
    D->>C: up -d with APP_VERSION=v2.0.0
    C->>A: start new container
    D->>A: poll /ready and /version
    alt ready and version matches
        A-->>D: 200 and v2.0.0
        D-->>Op: DEPLOY SUCCEEDED
    else not ready within 40s
        A-->>D: 500 or 503
        D-->>Op: DEPLOY FAILED, run rollback.sh
        Op->>D: rollback.sh
        D->>C: up -d with APP_VERSION=v1.0.0 (existing image, no rebuild)
        D->>A: poll /ready and /version
        A-->>D: 200 and v1.0.0
        D-->>Op: ROLLBACK SUCCEEDED, data untouched
    end
```
