#!/usr/bin/env node
/**
 * Wave playthrough bot for Niebla Norte.
 * Usage: node survival/scripts/playbot.mjs [seed] [maxSeconds] [...moreSeeds]
 */
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer-core";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SEED = Number(process.argv[2] || 42) | 0;
const MAX_SEC = Number(process.argv[3] || 300);
const EXTRA = process.argv.slice(4).map((s) => Number(s) | 0).filter(Boolean);
const PORT = 8765 + (SEED % 50);

const MIME = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".css": "text/css",
};

function serve() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
      const rel = url.pathname === "/" ? "/index.html" : url.pathname;
      const file = path.join(ROOT, rel);
      if (!file.startsWith(ROOT) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
        res.writeHead(404);
        res.end("no");
        return;
      }
      res.writeHead(200, { "Content-Type": MIME[path.extname(file)] || "application/octet-stream" });
      fs.createReadStream(file).pipe(res);
    });
    server.listen(PORT, "127.0.0.1", () => resolve(server));
  });
}

async function runSeed(seed) {
  const browser = await puppeteer.launch({
    executablePath: "/usr/bin/google-chrome-stable",
    headless: "new",
    args: ["--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage", "--window-size=1280,720"],
    defaultViewport: { width: 1280, height: 720 },
  });
  const page = await browser.newPage();
  await page.goto(`http://127.0.0.1:${PORT}/?auto&fastwaves&seed=${seed}`, {
    waitUntil: "domcontentloaded",
    timeout: 30000,
  });
  await page.waitForFunction(() => window.__crespo?.player, { timeout: 15000 });

  await page.evaluate(() => {
    window.__botLog = [];
    window.__botBestWave = 0;
    window.__botLegendaries = [];
    let lastWave = -1;
    let lastBossHp = null;

    setInterval(() => {
      const g = window.__crespo;
      if (!g || g.dead) return;
      const p = g.player;

      for (const k of ["w", "a", "s", "d", " ", "q", "e", "r", "f"]) g.keys.delete(k);
      g.mouse.clicked = false;
      g.mouse.down = false;

      if (g.wave > window.__botBestWave) window.__botBestWave = g.wave;
      if (g.wave !== lastWave && g.wave > 0) {
        lastWave = g.wave;
        window.__botLog.push({ event: "wave", wave: g.wave, kills: g.kills, hp: Math.round(p.health) });
      }
      for (const id of ["eclipse_bat", "wail_scythe", "ironhowl"]) {
        if ((p.inv[id] || 0) > 0 && !window.__botLegendaries.includes(id)) {
          window.__botLegendaries.push(id);
          window.__botLog.push({ event: "legendary", id, wave: g.wave, kills: g.kills });
        }
      }

      // Best weapon
      const inv = p.inv;
      const order = ["eclipse_bat", "wail_scythe", "ironhowl", "bat", "shotgun", "rifle", "pistol", "pipe", "knife", "pan"];
      for (const id of order) {
        if ((inv[id] || 0) > 0) {
          if (id === "ironhowl" && !(inv.ammo_shot > 0)) continue;
          if (id === "shotgun" && !(inv.ammo_shot > 0)) continue;
          if (id === "rifle" && !(inv.ammo_rifle > 0)) continue;
          if (id === "pistol" && !(inv.ammo_9mm > 0)) continue;
          p.equip.hand = id;
          break;
        }
      }
      const hand = p.equip.hand;
      const firearm = hand === "ironhowl" || hand === "pistol" || hand === "shotgun" || hand === "rifle";

      if (p.gatherCd <= 0) {
        // Prioritize thirst/hunger — dying of sed lost the best run
        if (p.thirst < 50 && (inv.water || 0) > 0) {
          inv.water -= 1;
          if (inv.water <= 0) delete inv.water;
          p.thirst = Math.min(100, p.thirst + 40);
          p.gatherCd = 0.35;
        } else if (p.hunger < 50 && (inv.food || 0) > 0) {
          inv.food -= 1;
          if (inv.food <= 0) delete inv.food;
          p.hunger = Math.min(100, p.hunger + 34);
          p.gatherCd = 0.35;
        } else if (p.health < 80 && (inv.med || 0) > 0) {
          g.justPressed.add("r");
          g.keys.add("r");
        }
      }

      // Opportunistic water loot / starting stocks won't last — sip often
      if (p.thirst < 70 && (inv.water || 0) > 1 && p.gatherCd <= 0) {
        inv.water -= 1;
        p.thirst = Math.min(100, p.thirst + 40);
        p.gatherCd = 0.35;
      }

      // Target: boss > nearest wave zombie > any zombie
      let target = null;
      let best = 1e9;
      for (const z of g.zombies) {
        if (z.hp <= 0) continue;
        const d = Math.hypot(z.x - p.x, z.y - p.y);
        let score = d;
        if (z.boss) score -= 100;
        else if (z.wave > 0) score -= 10;
        if (score < best) {
          best = score;
          target = z;
        }
      }

      if (!target) {
        const ang = performance.now() / 800;
        g.keys.add(Math.cos(ang) > 0 ? "d" : "a");
        g.keys.add(Math.sin(ang) > 0 ? "s" : "w");
        return;
      }

      if (target.boss) {
        if (lastBossHp == null || target.hp > lastBossHp + 10) lastBossHp = target.hp;
      }

      const dx = target.x - p.x;
      const dy = target.y - p.y;
      const dist = Math.hypot(dx, dy) || 1;
      const nx = dx / dist;
      const ny = dy / dist;

      const camX = g.camX ?? p.x;
      const camY = g.camY ?? p.y;
      const vw = g.mouse.viewW || 1280;
      const vh = g.mouse.viewH || 720;
      g.mouse.viewW = vw;
      g.mouse.viewH = vh;
      g.mouse.x = (target.x - camX) * 48 + vw / 2;
      g.mouse.y = (target.y - camY) * 48 + vh / 2;
      g.mouse.worldX = target.x;
      g.mouse.worldY = target.y;

      const ideal = firearm ? 3.6 : target.boss ? 1.35 : 1.15;

      function move(mx, my) {
        if (Math.abs(mx) >= Math.abs(my) * 0.5) g.keys.add(mx >= 0 ? "d" : "a");
        if (Math.abs(my) >= Math.abs(mx) * 0.5) g.keys.add(my >= 0 ? "s" : "w");
      }

      if (dist > ideal + 0.35) {
        move(nx, ny);
        if (dist > 5 && p.stamina > 40) g.keys.add(" ");
      } else if (dist < ideal - 0.45) {
        move(-nx + ny * 0.5, -ny - nx * 0.5);
        if (p.stamina > 25) g.keys.add(" ");
      } else {
        move(-ny, nx); // orbit
      }

      const inHit = firearm ? dist < 6.5 : dist < 2.2;
      if (inHit && p.attackCd <= 0 && !(p.swingT > 0)) {
        p.aim = Math.atan2(dy, dx);
        p.facingAng = Math.abs(dx) >= Math.abs(dy) ? (dx >= 0 ? 0 : Math.PI) : dy >= 0 ? Math.PI / 2 : -Math.PI / 2;
        if (firearm) {
          g.mouse.clicked = true;
          g.mouse.down = true;
        } else {
          g.justPressed.add("q");
          g.keys.add("q");
          g.mouse.clicked = true;
          g.mouse.down = true;
        }
      } else if (firearm && inHit) {
        g.mouse.down = true;
        g.mouse.clicked = true;
      }
    }, 40);
  });

  const deadline = Date.now() + MAX_SEC * 1000;
  let last = "";
  while (Date.now() < deadline) {
    const state = await page.evaluate(() => {
      const g = window.__crespo;
      if (!g) return { ready: false };
      const bosses = g.zombies
        .filter((z) => z.boss && z.hp > 0)
        .map((z) => `${z.name || z.bossKind}:${Math.round(z.hp)}`);
      return {
        ready: true,
        dead: !!g.dead,
        wave: g.wave,
        bestWave: window.__botBestWave || g.wave,
        phase: g.wavePhase,
        kills: g.kills,
        hp: Math.round(g.player.health),
        hand: g.player.equip.hand,
        legends: window.__botLegendaries || [],
        zCount: g.zombies.filter((z) => z.hp > 0).length,
        bosses,
        deathReason: g.deathReason || "",
        seed: g.world.seed,
        log: window.__botLog || [],
        toast: g.toast || "",
      };
    });
    if (state.ready) {
      const line = `seed=${state.seed} w=${state.wave}/${state.bestWave} ${state.phase} k=${state.kills} hp=${state.hp} hand=${state.hand} ★=${state.legends.join(",") || "-"} z=${state.zCount} ${state.bosses.join("|") || ""}`;
      if (line !== last) {
        console.log(line);
        last = line;
      }
      if (state.dead) {
        await page.screenshot({
          path: `/opt/cursor/artifacts/playbot_seed${seed}_wave${state.bestWave}.png`,
        }).catch(() => {});
        await browser.close();
        return state;
      }
    }
    await new Promise((r) => setTimeout(r, 600));
  }

  const finalState = await page.evaluate(() => {
    const g = window.__crespo;
    return {
      dead: !!g?.dead,
      wave: g?.wave || 0,
      bestWave: window.__botBestWave || 0,
      kills: g?.kills || 0,
      legends: window.__botLegendaries || [],
      deathReason: g?.deathReason || "timeout",
      seed: g?.world?.seed,
      hand: g?.player?.equip?.hand,
      log: window.__botLog || [],
      timeout: true,
    };
  });
  await page.screenshot({ path: `/opt/cursor/artifacts/playbot_seed${seed}_end.png` }).catch(() => {});
  await browser.close();
  return finalState;
}

const server = await serve();
const seeds = EXTRA.length ? [SEED, ...EXTRA] : [SEED, 7, 99, 314];
const results = [];
for (const seed of [...new Set(seeds)]) {
  console.log(`\n=== PLAY seed=${seed} max=${MAX_SEC}s ===`);
  try {
    const r = await runSeed(seed);
    results.push(r);
    console.log("RESULT", JSON.stringify({
      seed: r.seed, bestWave: r.bestWave, kills: r.kills, legends: r.legends,
      dead: r.dead, deathReason: r.deathReason, log: r.log,
    }, null, 2));
  } catch (err) {
    console.error("FAIL", seed, err);
    results.push({ seed, error: String(err), bestWave: 0, kills: 0, legends: [] });
  }
}
server.close();
results.sort((a, b) => (b.bestWave || 0) - (a.bestWave || 0) || (b.kills || 0) - (a.kills || 0));
console.log("\n=== BEST ===");
console.log(JSON.stringify(results[0], null, 2));
fs.writeFileSync("/opt/cursor/artifacts/playbot_results.json", JSON.stringify({ results, best: results[0] }, null, 2));
