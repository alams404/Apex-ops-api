// Structured (JSON) logging with pino.
// Every log line is one JSON object, so it can be searched with `jq` or shipped to
// any log platform later without changing the app.
const pino = require("pino");

const logger = pino({
  level: process.env.LOG_LEVEL || "info",
  base: {
    service: "apex-ops-api",
    version: process.env.APP_VERSION || "dev",
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  // Print "level":"error" instead of a number, so logs are readable without a lookup table.
  formatters: { level: (label) => ({ level: label }) },
  // Never write sensitive values to logs, even by accident.
  redact: ["password", "*.password", "req.headers.authorization"],
});

module.exports = logger;
