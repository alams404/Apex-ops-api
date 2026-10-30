// Test doubles: a fake in-memory database and a logger that records instead of printing.

function createFakeDb({ down = false } = {}) {
  const items = [];
  let nextId = 1;
  return {
    async ping() {
      if (down) throw new Error("connect ECONNREFUSED (fake: database is down)");
    },
    async init() {},
    async listItems() {
      return [...items].reverse();
    },
    async createItem(name, status) {
      const item = { id: nextId++, name, status, created_at: new Date().toISOString() };
      items.push(item);
      return item;
    },
    async close() {},
  };
}

function createSilentLogger() {
  const lines = [];
  const make = (level) => (obj, msg) => lines.push({ level, ...obj, msg });
  return {
    lines,
    debug: make("debug"),
    info: make("info"),
    warn: make("warn"),
    error: make("error"),
    fatal: make("fatal"),
  };
}

module.exports = { createFakeDb, createSilentLogger };
