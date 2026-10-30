// Database layer. The rest of the app only talks to the small object returned here,
// which makes it easy to replace with a fake in unit tests.
const { Pool } = require("pg");

function createDb(connectionString) {
  const pool = new Pool({
    connectionString,
    max: 5,
    connectionTimeoutMillis: 2000, // fail fast so /ready answers quickly when DB is down
  });

  // A pool emits "error" for idle clients; without a handler the process would crash.
  pool.on("error", () => {});

  return {
    // Used by /ready. Throws if the database cannot be reached OR the table is missing,
    // so an instance is only "ready" when it can really serve /items.
    async ping() {
      await pool.query("SELECT 1 FROM items LIMIT 1");
    },

    async init() {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS items (
          id SERIAL PRIMARY KEY,
          name TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'open',
          created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
      `);
    },

    async listItems() {
      const { rows } = await pool.query(
        "SELECT id, name, status, created_at FROM items ORDER BY id DESC LIMIT 100"
      );
      return rows;
    },

    async createItem(name, status) {
      const { rows } = await pool.query(
        "INSERT INTO items (name, status) VALUES ($1, $2) RETURNING id, name, status, created_at",
        [name, status]
      );
      return rows[0];
    },

    async close() {
      await pool.end();
    },
  };
}

module.exports = { createDb };
