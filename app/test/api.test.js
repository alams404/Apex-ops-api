// Automated checks that run in CI on every push. They use a fake database, so they
// need no Docker and no network. Run locally with: npm test
const { test } = require("node:test");
const assert = require("node:assert/strict");
const request = require("supertest");
const { createApp } = require("../src/app");
const { createFakeDb, createSilentLogger } = require("./helpers/fakes");

function buildApp(options = {}) {
  const logger = createSilentLogger();
  const db = createFakeDb({ down: options.dbDown });
  const app = createApp({ db, logger, fault: options.fault });
  return { app, logger };
}

// Check 1
test("GET /health returns 200 and status ok", async () => {
  const { app } = buildApp();
  const res = await request(app).get("/health");
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { status: "ok" });
});

// Check 2
test("GET /ready returns 200 when the database is up", async () => {
  const { app } = buildApp();
  const res = await request(app).get("/ready");
  assert.equal(res.status, 200);
  assert.equal(res.body.db, "up");
});

// Check 3
test("GET /ready returns 503 when the database is down, and logs the reason", async () => {
  const { app, logger } = buildApp({ dbDown: true });
  const res = await request(app).get("/ready");
  assert.equal(res.status, 503);
  assert.equal(res.body.db, "down");
  // The reason must be in the logs for operators...
  const logged = logger.lines.find((l) => l.event === "db_check_failed");
  assert.ok(logged, "expected a db_check_failed log line");
  // ...but must NOT leak to the caller.
  assert.equal(JSON.stringify(res.body).includes("ECONNREFUSED"), false);
});

// Check 4
test("POST /items creates an item and GET /items lists it", async () => {
  const { app } = buildApp();
  const created = await request(app).post("/items").send({ name: "Replace failed disk", status: "open" });
  assert.equal(created.status, 201);
  assert.equal(created.body.name, "Replace failed disk");

  const list = await request(app).get("/items");
  assert.equal(list.status, 200);
  assert.equal(list.body.items.length, 1);
});

// Check 5
test("POST /items with invalid input returns 422 with details", async () => {
  const { app } = buildApp();
  const res = await request(app).post("/items").send({ name: "", status: "banana" });
  assert.equal(res.status, 422);
  assert.equal(res.body.error, "validation_failed");
  assert.equal(res.body.details.length, 2);
});

// Check 6
test("GET /metrics exposes Prometheus metrics including request counters", async () => {
  const { app } = buildApp();
  await request(app).get("/health");
  const res = await request(app).get("/metrics");
  assert.equal(res.status, 200);
  assert.match(res.text, /http_requests_total\{method="GET",route="\/health",status="200"\} 1/);
  assert.match(res.text, /http_request_duration_seconds_bucket/);
});

// Check 7
test("every response carries an x-request-id, and a valid incoming one is reused", async () => {
  const { app } = buildApp();
  const generated = await request(app).get("/health");
  assert.ok(generated.headers["x-request-id"]);

  const reused = await request(app).get("/health").set("x-request-id", "demo-123");
  assert.equal(reused.headers["x-request-id"], "demo-123");
});

// Check 8
test("unknown routes and malformed JSON return JSON errors", async () => {
  const { app } = buildApp();
  const notFound = await request(app).get("/nope");
  assert.equal(notFound.status, 404);
  assert.equal(notFound.body.error, "not_found");

  const bad = await request(app).post("/items").set("Content-Type", "application/json").send("{broken");
  assert.equal(bad.status, 400);
  assert.equal(bad.body.error, "invalid_json");
});

// Check 9: proves the "bad release" used in the rollback demo really fails readiness.
test("an image built with INJECT_FAULT=bad-release fails readiness", async () => {
  const { app } = buildApp({ fault: "bad-release" });
  const res = await request(app).get("/ready");
  assert.equal(res.status, 500);
});

// Check 10: the INTENTIONAL FAILURE required by the assessment.
// It passes normally. CI sets FORCE_FAIL=true on the demo-failure branch (or via the
// manual "force_fail" input) so this check fails and the pipeline blocks deployment.
test("release gate: FORCE_FAIL must not be set", () => {
  assert.notEqual(
    process.env.FORCE_FAIL,
    "true",
    "Intentional failure: FORCE_FAIL=true was set to demonstrate that CI blocks deployment"
  );
});
