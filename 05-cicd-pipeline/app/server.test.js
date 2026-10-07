// Läuft mit dem eingebauten Test-Runner: node --test
const test = require("node:test");
const assert = require("node:assert");
const { buildResponse, createServer } = require("./server");

test("liefert Standardnachricht", () => {
  assert.strictEqual(buildResponse({}).message, "Hallo aus der Pipeline");
});

test("übernimmt Version aus der Umgebung", () => {
  assert.strictEqual(buildResponse({ APP_VERSION: "abc123" }).version, "abc123");
});

test("/health antwortet mit 200", async () => {
  const server = createServer().listen(0);
  const { port } = server.address();
  const res = await fetch(`http://127.0.0.1:${port}/health`);
  assert.strictEqual(res.status, 200);
  server.close();
});
