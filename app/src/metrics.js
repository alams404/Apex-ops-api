// Prometheus metrics. Exposed at GET /metrics.
// A new registry per app instance keeps tests isolated from each other.
const client = require("prom-client");

function createMetrics() {
  const register = new client.Registry();
  client.collectDefaultMetrics({ register });

  const httpRequests = new client.Counter({
    name: "http_requests_total",
    help: "Total HTTP requests",
    labelNames: ["method", "route", "status"],
    registers: [register],
  });

  const httpDuration = new client.Histogram({
    name: "http_request_duration_seconds",
    help: "HTTP request latency in seconds",
    labelNames: ["method", "route", "status"],
    buckets: [0.005, 0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5],
    registers: [register],
  });

  const dbUp = new client.Gauge({
    name: "db_up",
    help: "1 if the last database check succeeded, 0 otherwise",
    registers: [register],
  });

  return { register, httpRequests, httpDuration, dbUp };
}

module.exports = { createMetrics };
