// Entry point: reads configuration from environment variables, starts the HTTP server,
// prepares the database in the background and shuts down cleanly on SIGTERM.
const logger = require("./logger");
const { createDb } = require("./db");
const { createApp } = require("./app");

const PORT = parseInt(process.env.PORT || "3000", 10);
const DATABASE_URL = process.env.DATABASE_URL;

if (!DATABASE_URL) {
  logger.fatal({ event: "config_error" }, "DATABASE_URL is not set");
  process.exit(1);
}

const db = createDb(DATABASE_URL);
const app = createApp({ db, logger, fault: process.env.INJECT_FAULT || "none" });

const server = app.listen(PORT, "0.0.0.0", () => {
  logger.info({ event: "server_started", port: PORT }, "server listening");
});

// Create the table. Retry so the API survives a database that starts a little later.
// While this has not succeeded /ready returns 503, so no traffic is sent to us.
async function initDatabase() {
  for (let attempt = 1; ; attempt++) {
    try {
      await db.init();
      logger.info({ event: "db_init_ok" }, "database schema ready");
      return;
    } catch (err) {
      logger.warn({ event: "db_init_retry", attempt, err: err.message }, "database not ready, retrying in 3s");
      await new Promise((r) => setTimeout(r, 3000));
    }
  }
}
initDatabase();

function shutdown(signal) {
  logger.info({ event: "shutdown", signal }, "shutting down");
  server.close(async () => {
    await db.close().catch(() => {});
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10000).unref();
}
process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
