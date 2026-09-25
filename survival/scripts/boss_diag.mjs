#!/usr/bin/env node
/** Quick boss-fight diagnostic — seed 42, ?boss=1, 90s */
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer-core";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const PORT = 8799;

const server = http.createServer((req, res) => {
  const u = new URL(req.url, `http://127.0.0.1:${PORT}`);
  const rel = u.pathname === "/" ? "/index.html" : u.pathname;
  const file = path.join(ROOT, rel);
  if (!file.startsWith(ROOT) || !fs.existsSync(file)) {
    res.writeHead(404); res.end("no"); return;
  }
  const ext = path.extname(file);
  const mime = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css" }[ext] || "text/plain";
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
await page.goto(`http://127.0.0.1:${PORT}/?auto&boss&seed=42`, { waitUntil: "domcontentloaded" });
await page.waitForFunction(() => window.__crespo?.player);

await page.evaluate(() => {
  window.__dbg = { swings: 0, hits: 0, frames: 0 };
  const g = window.__crespo;
  // Hook player swing hits by watching zombie hp drops
  let lastBossHp = null;
  setInterval(() => {
    const g = window.__crespo;
    if (!g || g.dead) return;
    window.__dbg.frames++;
    const p = g.player;
    const boss = g.zombies.find((z) => z.boss && z.hp > 0);
    // Clear keys
    for (const k of ["w","a","s","d"," ","q","e","r"]) g.keys.delete(k);
    g.mouse.clicked = false;
    g.mouse.down = false;

    p.equip.hand = "bat";

    if (!boss) {
      // wander
      g.keys.add("d");
      return;
    }

    if (lastBossHp == null) lastBossHp = boss.hp;
    if (boss.hp < lastBossHp) {
      window.__dbg.hits++;
      lastBossHp = boss.hp;
    }

    const dx = boss.x - p.x;
    const dy = boss.y - p.y;
    const dist = Math.hypot(dx, dy) || 1;
    const nx = dx / dist, ny = dy / dist;

    // Aim mouse at boss
    const camX = g.camX ?? p.x, camY = g.camY ?? p.y;
    const vw = 1280, vh = 720;
    g.mouse.viewW = vw; g.mouse.viewH = vh;
    g.mouse.x = (boss.x - camX) * 48 + vw / 2;
    g.mouse.y = (boss.y - camY) * 48 + vh / 2;
    g.mouse.worldX = boss.x;
    g.mouse.worldY = boss.y;

    const ideal = 1.35;
    if (dist > ideal + 0.3) {
      if (Math.abs(nx) >= Math.abs(ny)) g.keys.add(nx > 0 ? "d" : "a");
      else g.keys.add(ny > 0 ? "s" : "w");
      if (dist > 4) g.keys.add(" ");
    } else if (dist < 0.9) {
      if (Math.abs(nx) >= Math.abs(ny)) g.keys.add(nx > 0 ? "a" : "d");
      else g.keys.add(ny > 0 ? "w" : "s");
      g.keys.add(" ");
    } else {
      // strafe
      g.keys.add(-ny > 0 ? "d" : "a");
    }

    // Attack every time ready
    if (p.attackCd <= 0 && !(p.swingT > 0) && dist < 2.2) {
      g.justPressed.add("q");
      g.keys.add("q");
      g.mouse.clicked = true;
      g.mouse.down = true;
      window.__dbg.swings++;
      // Force aim toward boss for this swing
      p.aim = Math.atan2(dy, dx);
      p.facingAng = Math.abs(dx) >= Math.abs(dy) ? (dx >= 0 ? 0 : Math.PI) : (dy >= 0 ? Math.PI / 2 : -Math.PI / 2);
    }

    if (p.health < 70 && (p.inv.med || 0) > 0) {
      g.justPressed.add("r");
      g.keys.add("r");
    }
  }, 40);
});

const t0 = Date.now();
while (Date.now() - t0 < 90000) {
  const s = await page.evaluate(() => {
    const g = window.__crespo;
    const boss = g.zombies.find((z) => z.boss);
    const p = g.player;
    return {
      dead: g.dead,
      hp: Math.round(p.health),
      kills: g.kills,
      bossHp: boss ? Math.round(boss.hp) : 0,
      bossAlive: !!(boss && boss.hp > 0),
      dist: boss ? +Math.hypot(boss.x - p.x, boss.y - p.y).toFixed(2) : null,
      swingT: +(p.swingT || 0).toFixed(2),
      attackCd: +(p.attackCd || 0).toFixed(2),
      hand: p.equip.hand,
      legends: ["eclipse_bat","wail_scythe","ironhowl"].filter((id) => (p.inv[id] || 0) > 0),
      dbg: window.__dbg,
      toast: g.toast,
      px: +p.x.toFixed(1),
      py: +p.y.toFixed(1),
      bx: boss ? +boss.x.toFixed(1) : null,
      by: boss ? +boss.y.toFixed(1) : null,
    };
  });
  console.log(JSON.stringify(s));
  if (s.dead || (s.legends.length && !s.bossAlive)) break;
  await new Promise((r) => setTimeout(r, 500));
}

await page.screenshot({ path: "/opt/cursor/artifacts/boss_diag.png" });
await browser.close();
server.close();
