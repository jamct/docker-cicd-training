const http = require("node:http");

// Reine Funktion – lässt sich ohne Server testen
function buildResponse(env = process.env) {
  return {
    message: env.GREETING || "Hallo aus der Pipeline",
    version: env.APP_VERSION || "dev",
  };
}

function createServer() {
  return http.createServer((req, res) => {
    if (req.url === "/health") {
      res.writeHead(200, { "Content-Type": "text/plain" });
      return res.end("ok");
    }
    res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
    res.end(JSON.stringify(buildResponse()));
  });
}

if (require.main === module) {
  const server = createServer().listen(process.env.PORT || 3000, () =>
    console.log(`listening on :${server.address().port}`));
  process.on("SIGTERM", () => server.close(() => process.exit(0)));
}

module.exports = { buildResponse, createServer };
