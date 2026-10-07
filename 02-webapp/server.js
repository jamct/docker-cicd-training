const http = require("node:http");
const os = require("node:os");

const port = process.env.PORT || 3000;
const greeting = process.env.GREETING || "Hallo Docker-Training";
const started = new Date();

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "text/plain" });
    return res.end("ok");
  }
  res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify({
    message: greeting,
    hostname: os.hostname(),
    version: process.env.APP_VERSION || "dev",
    startedAt: started.toISOString(),
  }, null, 2));
});

server.listen(port, () => console.log(`listening on :${port}`));

process.on("SIGTERM", () => server.close(() => process.exit(0)));