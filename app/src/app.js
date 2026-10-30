// The Express application. It is built by a factory function so tests can pass in a
// fake database and a silent logger. Nothing in here reads global state directly.
const express = require("express");
const crypto = require("node:crypto");
const { createMetrics } = require("./metrics");

const VALID_STATUS = ["open", "in_progress", "resolved"];

// Small helper so async route errors reach the Express error handler.
const wrap = (fn) => (req, res, next) => fn(req, res, next).catch(next);

function validateItem(body) {
  const details = [];
  if (typeof body !== "object" || body === null) {
    return ["body must be a JSON object"];
  }
  if (typeof body.name !== "string" || body.name.trim().length < 1 || body.name.length > 100) {
    details.push("name must be a string of 1 to 100 characters");
  }
  if (body.status !== undefined && !VALID_STATUS.includes(body.status)) {
    details.push(`status must be one of: ${VALID_STATUS.join(", ")}`);
  }
  return details;
}

function createApp({ db, logger, fault = "none" }) {
  const app = express();
  const metrics = createMetrics();

  app.disable("x-powered-by");
  app.use(express.json({ limit: "10kb" }));

  // 1. Request ID + metrics + one structured log line per request.
  app.use((req, res, next) => {
    const incoming = req.get("x-request-id");
    req.id = incoming && /^[\w-]{1,64}$/.test(incoming) ? incoming : crypto.randomUUID();
    res.set("x-request-id", req.id);

    const start = process.hrtime.bigint();
    res.on("finish", () => {
      const seconds = Number(process.hrtime.bigint() - start) / 1e9;
      const route = req.route ? `${req.baseUrl}${req.route.path}` : "unmatched";
      const labels = { method: req.method, route, status: res.statusCode };
      metrics.httpRequests.inc(labels);
      metrics.httpDuration.observe(labels, seconds);

      // Health checks and scrapes run every few seconds, so keep them at debug level.
      const noisy = route === "/health" || route === "/metrics";
      logger[noisy ? "debug" : "info"](
        {
          event: "http_request",
          requestId: req.id,
          method: req.method,
          path: req.path,
          route,
          status: res.statusCode,
          durationMs: Math.round(seconds * 1000 * 100) / 100,
        },
        "request completed"
      );
    });
    next();
  });

  // 2. Liveness: is the process up? Never touches the database.
  app.get("/health", (_req, res) => {
    res.status(200).json({ status: "ok" });
  });

  // 3. Readiness: can this instance serve traffic? Checks the database.
  app.get(
    "/ready",
    wrap(async (req, res) => {
      // Fault injection used ONLY for the release/rollback demo (see docs/runbook.md).
      // A "bad release" image is built with INJECT_FAULT=bad-release.
      if (fault === "bad-release") {
        logger.error({ event: "bad_release", requestId: req.id }, "simulated bug: readiness always fails");
        return res.status(500).json({ status: "error", reason: "simulated bad release" });
      }
      try {
        await db.ping();
        metrics.dbUp.set(1);
        res.status(200).json({ status: "ready", db: "up" });
      } catch (err) {
        metrics.dbUp.set(0);
        // The reason is logged for operators but NOT returned to the caller.
        logger.error({ event: "db_check_failed", requestId: req.id, err: err.message }, "database check failed");
        res.status(503).json({ status: "not_ready", db: "down" });
      }
    })
  );

  // 4. Which version is running? Used by deploy and rollback checks.
  app.get("/version", (_req, res) => {
    res.json({
      version: process.env.APP_VERSION || "dev",
      gitSha: process.env.GIT_SHA || "unknown",
    });
  });

  // 5. Prometheus metrics.
  app.get(
    "/metrics",
    wrap(async (_req, res) => {
      res.set("Content-Type", metrics.register.contentType);
      res.send(await metrics.register.metrics());
    })
  );

  // 6. Business endpoints (synthetic "operations items").
  app.get(
    "/items",
    wrap(async (_req, res) => {
      res.json({ items: await db.listItems() });
    })
  );

  app.post(
    "/items",
    wrap(async (req, res) => {
      const details = validateItem(req.body);
      if (details.length > 0) {
        return res.status(422).json({ error: "validation_failed", details });
      }
      const item = await db.createItem(req.body.name.trim(), req.body.status || "open");
      res.status(201).json(item);
    })
  );

  // 7. Unknown routes and errors always return JSON.
  app.use((_req, res) => {
    res.status(404).json({ error: "not_found" });
  });

  // Express recognises an error handler by its 4 arguments, so `_next` must stay.
  app.use((err, req, res, _next) => {
    if (err.type === "entity.parse.failed") {
      return res.status(400).json({ error: "invalid_json" });
    }
    logger.error({ event: "unhandled_error", requestId: req.id, err: err.message }, "request failed");
    res.status(500).json({ error: "internal_error", requestId: req.id });
  });

  return app;
}

module.exports = { createApp };
