// Integration check against a REAL PostgreSQL. It only runs when DATABASE_URL is set
// (CI provides a Postgres service container). Locally it is skipped automatically.
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { createDb } = require("../src/db");

test(
  "real PostgreSQL: init, create, list and ping work end to end",
  { skip: !process.env.DATABASE_URL && "DATABASE_URL not set, skipping integration test" },
  async () => {
    const db = createDb(process.env.DATABASE_URL);
    try {
      await db.init();
      await db.ping();
      const created = await db.createItem("integration check", "open");
      assert.ok(created.id);
      const items = await db.listItems();
      assert.ok(items.some((i) => i.id === created.id));
    } finally {
      await db.close();
    }
  }
);
