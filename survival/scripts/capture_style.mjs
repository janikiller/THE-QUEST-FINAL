#!/usr/bin/env node
/** Capture Stardew-style linear art screenshots (clear day) */
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer-core";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const PORT = 8812;
const server = http.createServer((req, res) => {
  const u = new URL(req.url, `http://127.0.0.1:${PORT}`);
  const rel = u.pathname === "/" ? "/index.html" : u.pathname;
  const file = path.join(ROOT, rel);
  if (!fs.existsSync(file) || !file.startsWith(ROOT)) { res.writeHead(404); res.end("no"); return; }
  const mime = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css" }[path.extname(file)] || "text/plain";
  res.writeHead(200, { "Content-Type": mime });
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(PORT, "127.0.0.1", r));

const browser = await puppeteer.launch({
  executablePath: "/usr/bin/google-chrome-stable",
  headless: "new",
  args: ["--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage"],
  defaultViewport: { width: 1280, height: 720 },
});
const page = await browser.newPage();
await page.goto(`http://127.0.0.1:${PORT}/?auto&weather=clear&seed=42`, { waitUntil: "domcontentloaded" });
await page.waitForFunction(() => window.__crespo?.player, { timeout: 15000 });

await page.evaluate(() => {
  const g = window.__crespo;
  // Día claro forzado
  g.time = g.dayLen * 0.3;
  g.weather.kind = "clear";
  g.weather.label = "Despejado";
  g.weather.intensity = 0.1;
  g.weather.wind = 0.2;
  g.weather.gust = 0;
  g.weather.thunder = 0;
  g.weather.nextChange = 9999;
  g._phase = null;
  g.waveTimer = 60;
  g.wavePhase = "countdown";
  // Clear ambient fog zombies far away
  for (const z of g.zombies) {
    z.x = g.player.x + 20;
    z.y = g.player.y + 20;
  }
  g.player.x = g.world.spawn.x;
  g.player.y = g.world.spawn.y;
  g.camX = g.player.x;
  g.camY = g.player.y;
  g.player.facing = 1;
  g.player.facingAng = 0;
  g.player.moving = true;
  g.player.walkPhase = 3.2;
  g.player.swingT = 0;
  // Bust ground cache
  g._groundCache = null;
});
await new Promise((r) => setTimeout(r, 900));
await page.screenshot({ path: "/opt/cursor/artifacts/demo_stardew_linear_street.png" });

// Character close-up with zombie
await page.evaluate(() => {
  const g = window.__crespo;
  const p = g.player;
  p.x = g.world.spawn.x;
  p.y = g.world.spawn.y;
  g.camX = p.x; g.camY = p.y;
  let z = g.zombies[0];
  if (!z) {
    z = { x: p.x + 1.5, y: p.y, hp: 40, maxHp: 40, facing: -1, walkPhase: 1, color: "#3a4a34", head: "#6a7a5a" };
    g.zombies.push(z);
  }
  z.x = p.x + 1.5;
  z.y = p.y + 0.1;
  z.hp = 40;
  z.boss = false;
  p.equip.hand = "bat";
  p.swingT = 0.18;
  p.swingDur = 0.3;
  p.facingAng = 0;
  p.aim = 0;
});
await new Promise((r) => setTimeout(r, 600));
await page.screenshot({ path: "/opt/cursor/artifacts/demo_stardew_linear_chars.png" });

// Interior
await page.evaluate(() => {
  const g = window.__crespo;
  const b = (g.world.buildings || []).find((bb) => bb.w >= 4 && bb.h >= 4) || g.world.buildings?.[0];
  if (b) {
    g.player.x = b.x + b.w / 2;
    g.player.y = b.y + b.h / 2;
    g.camX = g.player.x;
    g.camY = g.player.y;
  }
  g.time = g.dayLen * 0.3;
  g.weather.kind = "clear";
  g._phase = null;
});
await new Promise((r) => setTimeout(r, 800));
await page.screenshot({ path: "/opt/cursor/artifacts/demo_stardew_linear_interior.png" });

console.log("ok");
await browser.close();
server.close();
