import { TILE, TILE_META, buildingAt, furnitureType, furnitureLabel, nearestSearchable, itemDef, propsInView } from "./world.js";
import { dayPhase } from "./game.js";

const TILE_PX = 48;
const FONT_UI = '"IBM Plex Sans", "Segoe UI", sans-serif';
const FONT_DISPLAY = '"Instrument Serif", Georgia, serif';

/** Edificio actual visto desde dentro (invalida caché de suelo). */
let _viewIndoor = null;

export function createRenderer(canvas, miniCanvas) {
  const ctx = canvas.getContext("2d");
  const mctx = miniCanvas.getContext("2d");
  const dpr = Math.min(window.devicePixelRatio || 1, 1);
  // Formas suaves / antialias (estilo Stardew, no pixel-cuadrado)
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = "high";
  if (mctx) {
    mctx.imageSmoothingEnabled = true;
    mctx.imageSmoothingQuality = "high";
  }

  function resize() {
    const w = window.innerWidth;
    const h = window.innerHeight;
    canvas.width = Math.floor(w * dpr);
    canvas.height = Math.floor(h * dpr);
    canvas.style.width = `${w}px`;
    canvas.style.height = `${h}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = "high";
  }

  resize();
  window.addEventListener("resize", resize);

  return {
    resize,
    draw(game) {
      paint(ctx, mctx, canvas, miniCanvas, game, dpr);
    },
  };
}

function paint(ctx, mctx, canvas, mini, game, dpr) {
  const w = canvas.width / dpr;
  const h = canvas.height / dpr;
  const phase = game._phase || dayPhase(game);
  const shakeAmt = Math.min(10, (game.shake || 0) * 14);
  const shakeX = shakeAmt ? (Math.random() - 0.5) * 2 * shakeAmt : 0;
  const shakeY = shakeAmt ? (Math.random() - 0.5) * 2 * shakeAmt : 0;
  const focusX = game.camX ?? game.player.x;
  const focusY = game.camY ?? game.player.y;
  const camX = focusX * TILE_PX - w / 2 + shakeX;
  const camY = focusY * TILE_PX - h / 2 + shakeY;
  const raining = phase.rain > 0.15;
  const storming = phase.weather === "storm";
  const sanding = phase.weather === "sandstorm" || phase.sand > 0.2;
  const windy = phase.weather === "wind" || phase.wind > 0.9;

  // Cielo / atmósfera
  const sky = ctx.createLinearGradient(0, 0, 0, h);
  if (phase.thunder > 0.05) {
    sky.addColorStop(0, "#c8d0e0");
    sky.addColorStop(1, "#6a7080");
  } else if (sanding) {
    sky.addColorStop(0, phase.night ? "#2a2218" : "#6a5340");
    sky.addColorStop(0.5, phase.night ? "#3a2e20" : "#8a6a48");
    sky.addColorStop(1, phase.night ? "#1a1410" : "#4a3828");
  } else if (phase.night) {
    if (storming) {
      sky.addColorStop(0, "#12151e");
      sky.addColorStop(1, "#1a1822");
    } else {
      sky.addColorStop(0, "#151c28");
      sky.addColorStop(1, "#1e1a16");
    }
  } else if (phase.name === "Atardecer" || phase.name === "Anochecer") {
    sky.addColorStop(0, raining ? "#3a3038" : "#5a3828");
    sky.addColorStop(0.55, raining ? "#4a4048" : "#8a5030");
    sky.addColorStop(1, "#2a2018");
  } else if (raining) {
    sky.addColorStop(0, "#5a646c");
    sky.addColorStop(1, "#3a4248");
  } else if (windy) {
    sky.addColorStop(0, "#5a5852");
    sky.addColorStop(1, "#3a3834");
  } else {
    // Día ceniciento post-colapso
    sky.addColorStop(0, "#4a4e52");
    sky.addColorStop(0.45, "#5a5854");
    sky.addColorStop(1, "#3a3834");
  }
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, h);

  const x0 = Math.max(0, Math.floor(camX / TILE_PX) - 1);
  const y0 = Math.max(0, Math.floor(camY / TILE_PX) - 1);
  const x1 = Math.min(game.world.size, Math.ceil((camX + w) / TILE_PX) + 2);
  const y1 = Math.min(game.world.size, Math.ceil((camY + h) / TILE_PX) + 2);

  // Indoor antes del suelo (yeso vs fachada + invalidación de caché)
  const inside = buildingAt(game.world, game.player.x, game.player.y);
  const playerTile = tileIndex(game, game.player.x, game.player.y);
  const playerIndoor = TILE_META[playerTile]?.indoor || playerTile === TILE.DOOR;
  _viewIndoor = playerIndoor ? inside : null;

  // Suelo cacheado (estático) + agua animada encima
  drawCachedGround(ctx, game, phase, camX, camY, x0, y0, x1, y1);
  // Brillo de lluvia: más ligero y a frames alternos
  if (raining && (_frameN & 1) === 0) {
    for (let ty = y0; ty < y1; ty++) {
      for (let tx = x0; tx < x1; tx++) {
        if (((tx + ty) & 7) !== 0) continue;
        const tile = game.world.tiles[ty * game.world.size + tx];
        if (tile === TILE.ROAD || tile === TILE.CROSSWALK || tile === TILE.SIDEWALK) {
          drawWetSheen(ctx, tx * TILE_PX - camX, ty * TILE_PX - camY, game.time, tx, ty);
        }
      }
    }
  }

  // Edificios
  const litWindows = [];

  for (const b of game.world.buildings) {
    if (b.x1 < x0 - 1 || b.x0 > x1 + 1 || b.y1 < y0 - 1 || b.y0 > y1 + 1) continue;
    const entered = inside === b && playerIndoor;
    drawBuildingRoof(ctx, b, camX, camY, phase, entered, litWindows);
  }

  // Muebles en capa viva (encima del lavado de habitación, fuera de caché)
  if (playerIndoor && inside) {
    drawLiveFurniture(ctx, game, camX, camY, x0, y0, x1, y1, inside);
  }

  // Props: grid espacial + cull
  const visibleProps = [];
  const propCandidates = propsInView(game.world, x0 - 2, y0 - 2, x1 + 2, y1 + 2);
  for (const p of propCandidates) {
    const px = p.x * TILE_PX - camX;
    const py = p.y * TILE_PX - camY;
    if (px <= -70 || py <= -70 || px >= w + 70 || py >= h + 70) continue;
    // Arte interior solo se ve dentro; basura/enredaderas de fachada no tapan el suelo interior.
    if (p.indoor && !playerIndoor) continue;
    if (playerIndoor && inside && p.wall && !p.indoor &&
        p.x >= inside.x0 && p.x <= inside.x1 + 1 && p.y >= inside.y0 && p.y <= inside.y1 + 1) {
      continue;
    }
    visibleProps.push(p);
    drawProp(ctx, p, px, py, phase);
  }

  // Loot + barricadas / puertas (un solo barrido)
  for (let ty = y0; ty < y1; ty++) {
    for (let tx = x0; tx < x1; tx++) {
      const item = game.world.loot.get(`${tx},${ty}`);
      if (item) drawLoot(ctx, item.id, tx * TILE_PX - camX + TILE_PX / 2, ty * TILE_PX - camY + TILE_PX / 2, game.time);
      const tile = game.world.tiles[ty * game.world.size + tx];
      if (tile === TILE.BARRICADE) drawBarricade(ctx, tx * TILE_PX - camX, ty * TILE_PX - camY);
      else if (tile === TILE.DOOR) drawDoor(ctx, game, tx, ty, tx * TILE_PX - camX, ty * TILE_PX - camY);
    }
  }

  if (game.buildMode) {
    const aimDx = Math.cos(game.player.aim || 0);
    const aimDy = Math.sin(game.player.aim || 0);
    const bx = game.buildMode === "claim" ? Math.floor(game.player.x) : Math.floor(game.player.x + aimDx * 1.15);
    const by = game.buildMode === "claim" ? Math.floor(game.player.y) : Math.floor(game.player.y + aimDy * 1.15);
    ctx.fillStyle = "rgba(220, 190, 90, 0.3)";
    ctx.strokeStyle = "rgba(255, 220, 120, 0.9)";
    ctx.lineWidth = 2;
    ctx.fillRect(bx * TILE_PX - camX + 3, by * TILE_PX - camY + 3, TILE_PX - 6, TILE_PX - 6);
    ctx.strokeRect(bx * TILE_PX - camX + 3, by * TILE_PX - camY + 3, TILE_PX - 6, TILE_PX - 6);
  }

  const margin = 40;
  for (const z of game.zombies) {
    const zx = z.x * TILE_PX - camX;
    const zy = z.y * TILE_PX - camY;
    if (zx < -margin || zy < -margin || zx > w + margin || zy > h + margin) continue;
    drawZombie(ctx, zx, zy, game.time, z);
  }
  drawFx(ctx, game, camX, camY);
  drawAimAndBullets(ctx, game, camX, camY);
  drawPlayer(ctx, game.player.x * TILE_PX - camX, game.player.y * TILE_PX - camY, game.player, game.time, game);

  if (inside && playerIndoor) {
    ctx.fillStyle = "rgba(10,12,14,0.72)";
    ctx.fillRect(w / 2 - 100, 18, 200, 30);
    ctx.fillStyle = "#e8e0d0";
    ctx.font = `600 13px ${FONT_UI}`;
    ctx.textAlign = "center";
    ctx.fillText(inside.name, w / 2, 38);
  }

  drawLootPrompt(ctx, game, camX, camY, w, h, playerIndoor);

  // Oscuridad + iluminación (farolas, ventanas, linterna)
  drawLighting(ctx, game, phase, camX, camY, w, h, litWindows.length > 12 ? litWindows.slice(0, 12) : litWindows, visibleProps, playerIndoor);

  // Clima exterior: dentro de casas no llueve ni entra arena
  if (!playerIndoor) {
    if (phase.rain > 0.08 && !sanding) {
      drawRain(ctx, w, h, game, phase);
    }
    if (sanding) {
      drawSandstorm(ctx, w, h, game, phase);
    } else if (windy || phase.wind > 0.7) {
      drawWindDust(ctx, w, h, game, phase);
    }
    if (phase.thunder > 0) {
      ctx.fillStyle = `rgba(220, 230, 255, ${Math.min(0.55, phase.thunder * 1.8)})`;
      ctx.fillRect(0, 0, w, h);
    }
  } else {
    // Polvo en suspensión dentro
    drawIndoorMotes(ctx, w, h, game, phase);
    // Trueno amortiguado (flash suave)
    if (phase.thunder > 0.12) {
      ctx.fillStyle = `rgba(220, 230, 255, ${Math.min(0.18, phase.thunder * 0.45)})`;
      ctx.fillRect(0, 0, w, h);
    }
  }

  if (game.player.hurtFlash > 0) {
    const hf = game.player.hurtFlash;
    ctx.fillStyle = `rgba(140, 20, 20, ${hf * 0.55})`;
    ctx.fillRect(0, 0, w, h);
    ctx.strokeStyle = `rgba(200, 40, 30, ${hf * 0.85})`;
    ctx.lineWidth = 10;
    ctx.strokeRect(4, 4, w - 8, h - 8);
  }

  if (game.dead) {
    ctx.fillStyle = "rgba(8, 6, 6, 0.35)";
    ctx.fillRect(0, 0, w, h);
  }

  if (game.waveBannerT > 0 && game.waveBanner) {
    const a = Math.min(1, game.waveBannerT * 2);
    ctx.save();
    ctx.globalAlpha = a;
    ctx.fillStyle = "rgba(12, 14, 10, 0.72)";
    ctx.fillRect(w / 2 - 160, h * 0.18, 320, 52);
    ctx.strokeStyle = "rgba(216, 192, 120, 0.55)";
    ctx.lineWidth = 2;
    ctx.strokeRect(w / 2 - 160, h * 0.18, 320, 52);
    ctx.fillStyle = "#f0d9a0";
    ctx.font = `italic 28px ${FONT_DISPLAY}`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(game.waveBanner, w / 2, h * 0.18 + 26);
    ctx.restore();
  }

  // Viñeta / velo atmosférico
  const fogA = sanding ? 0.42 : phase.night ? 0.28 : raining ? 0.32 : 0.24;
  const fog = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.28, w / 2, h / 2, Math.max(w, h) * 0.85);
  fog.addColorStop(0, "rgba(0,0,0,0)");
  if (sanding) {
    fog.addColorStop(0.45, "rgba(90,70,40,0.12)");
    fog.addColorStop(1, `rgba(60,42,22,${fogA})`);
  } else {
    fog.addColorStop(0.55, phase.night ? "rgba(8,10,14,0.08)" : "rgba(40,36,30,0.1)");
    fog.addColorStop(1, phase.night ? `rgba(4,5,8,${fogA})` : `rgba(32,28,24,${fogA})`);
  }
  ctx.fillStyle = fog;
  ctx.fillRect(0, 0, w, h);

  // Ceniza / polvo en suspensión (más con viento)
  const ashN = playerIndoor ? 0 : sanding ? 14 : windy ? 10 : 6;
  const windPush = phase.wind * 40 + phase.gust * 60;
  ctx.fillStyle = sanding
    ? "rgba(210,170,110,0.12)"
    : phase.night
      ? "rgba(180,170,150,0.045)"
      : "rgba(120,110,95,0.06)";
  const ashSeed = (game.time * 18) | 0;
  for (let i = 0; i < ashN; i++) {
    const ax = ((ashSeed * 17 + i * 97 + game.time * windPush) % Math.max(1, w | 0) + w) % Math.max(1, w | 0);
    const ay = ((ashSeed * 13 + i * 53 + game.time * 12 * (i % 5)) % Math.max(1, h | 0));
    ctx.fillRect(ax, ay, sanding ? 3 : 2, sanding ? 2 : 2);
  }

  _frameN = (_frameN + 1) | 0;
  if ((_frameN & 1) === 0) drawMinimap(mctx, mini, game);
}

let _frameN = 0;


function drawWetSheen(ctx, px, py, time, tx, ty) {
  const pulse = 0.04 + Math.sin(time * 2 + tx + ty) * 0.02;
  ctx.fillStyle = `rgba(180, 200, 220, ${pulse})`;
  ctx.beginPath();
  ctx.ellipse(px + 24, py + 28, 14, 5, 0.2, 0, Math.PI * 2);
  ctx.fill();
}

function drawSandstorm(ctx, w, h, game, phase) {
  const t = game.time;
  const wind = 18 + phase.wind * 28 + phase.gust * 40;
  const veil = 0.18 + phase.sand * 0.22 + phase.gust * 0.08;
  ctx.fillStyle = `rgba(150, 110, 60, ${veil})`;
  ctx.fillRect(0, 0, w, h);
  ctx.fillStyle = `rgba(90, 60, 30, ${veil * 0.45})`;
  ctx.fillRect(0, 0, w, h * 0.35);

  ctx.strokeStyle = phase.night ? "rgba(200,160,100,0.22)" : "rgba(230,190,130,0.28)";
  ctx.lineWidth = 1.4;
  const n = Math.min(36, Math.floor(16 + phase.sand * 22 + phase.gust * 12));
  for (let i = 0; i < n; i++) {
    const seed = (i * 6151 + ((t * 280) | 0)) % 12000;
    const y = ((seed * 41 + t * (30 + (i % 9))) % (h + 20)) - 10;
    const x = ((seed * 17 + t * wind * (0.7 + (i % 5) * 0.08)) % (w + 80)) - 40;
    const len = 14 + (seed % 22);
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x + len, y + (seed % 5) - 2);
    ctx.stroke();
  }

  ctx.fillStyle = "rgba(180,140,80,0.1)";
  for (let i = 0; i < 6; i++) {
    const seed = (i * 997 + ((t * 9) | 0)) % 4000;
    const x = ((seed * 23 + t * wind * 0.5) % (w + 60)) - 30;
    const y = h * 0.45 + (seed % Math.floor(h * 0.5));
    ctx.beginPath();
    ctx.ellipse(x, y, 28 + (seed % 20), 5 + (seed % 4), -0.2, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawWindDust(ctx, w, h, game, phase) {
  const t = game.time;
  const wind = 10 + phase.wind * 22 + phase.gust * 35;
  ctx.strokeStyle = phase.night ? "rgba(170,160,140,0.12)" : "rgba(140,130,110,0.14)";
  ctx.lineWidth = 1;
  const n = Math.min(28, Math.floor(12 + phase.wind * 16));
  for (let i = 0; i < n; i++) {
    const seed = (i * 5107 + ((t * 160) | 0)) % 9000;
    const y = ((seed * 37) % h);
    const x = ((seed * 19 + t * wind) % (w + 50)) - 25;
    const len = 8 + (seed % 14);
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x + len, y + 1);
    ctx.stroke();
  }
}


function drawIndoorMotes(ctx, w, h, game, phase) {
  const n = phase.night ? 8 : 4;
  const t = game.time;
  ctx.fillStyle = phase.night ? "rgba(255, 210, 140, 0.14)" : "rgba(200, 180, 140, 0.1)";
  for (let i = 0; i < n; i++) {
    const seed = (i * 4201 + ((t * 40) | 0)) % 8000;
    const x = ((seed * 17 + t * 12) % w + w) % w;
    const y = ((seed * 29 + Math.sin(t * 0.7 + i) * 18) % h + h) % h;
    const s = 1 + (seed % 2);
    ctx.fillRect(x, y, s, s);
  }
}

function drawRain(ctx, w, h, game, phase) {
  const n = Math.min(36, Math.floor(18 + phase.rain * 28));
  const wind = phase.wind * 10;
  ctx.strokeStyle = phase.night
    ? phase.weather === "storm"
      ? "rgba(170,190,230,0.45)"
      : "rgba(170,190,220,0.35)"
    : "rgba(200,210,220,0.4)";
  ctx.lineWidth = phase.weather === "storm" ? 1.5 : 1.2;
  const t = game.time;
  for (let i = 0; i < n; i++) {
    const seed = (i * 7919 + ((t * 420) | 0)) % 10000;
    const x = ((seed * 37) % w) + wind * (seed % 7);
    const y = ((seed * 53 + t * (380 + phase.rain * 220)) % (h + 40)) - 20;
    const len = 8 + (seed % 10) + (phase.weather === "storm" ? 4 : 0);
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x + wind * 0.6, y + len);
    ctx.stroke();
  }
  if (phase.rain > 0.4) {
    ctx.fillStyle = phase.night ? "rgba(180,200,230,0.15)" : "rgba(220,230,240,0.18)";
    for (let i = 0; i < 10; i++) {
      const seed = (i * 1301 + ((t * 12) | 0)) % 5000;
      const x = (seed * 17) % w;
      const y = h * 0.35 + (seed % Math.floor(h * 0.6));
      ctx.beginPath();
      ctx.ellipse(x, y, 2 + (seed % 3), 1, 0, 0, Math.PI * 2);
      ctx.fill();
    }
  }
}

function drawLighting(ctx, game, phase, camX, camY, w, h, litWindows, visibleProps, indoor) {
  const darkness = Math.max(0, 1 - phase.light);
  // De día en exterior casi no hay velo; en interior siempre hay penumbra
  if (darkness < 0.04 && phase.thunder <= 0 && !indoor) return;

  const lampMargin = 220;
  const lamps = [];
  const lampSrc = game.world.lamps || game.world.props;
  for (const p of lampSrc) {
    if (p.type && p.type !== "lamp") continue;
    const lx = p.x * TILE_PX - camX;
    const ly = p.y * TILE_PX - camY;
    if (lx < -lampMargin || ly < -lampMargin || lx > w + lampMargin || ly > h + lampMargin) continue;
    lamps.push({ p, lx, ly });
  }
  if (lamps.length > 10) {
    const px0 = game.player.x;
    const py0 = game.player.y;
    lamps.sort((a, b) => {
      const da = (a.p.x - px0) ** 2 + (a.p.y - py0) ** 2;
      const db = (b.p.x - px0) ** 2 + (b.p.y - py0) ** 2;
      return da - db;
    });
    lamps.length = 10;
  }

  const px = game.player.x * TILE_PX - camX;
  const py = game.player.y * TILE_PX - camY;
  const lightDef = itemDef(game.player.equip?.light);
  const hasLight = Boolean(lightDef?.lightRadius);
  const playerR = hasLight
    ? lightDef.lightRadius * (indoor ? 0.85 : phase.night ? 1 : 0.7)
    : 0;
  const cool = phase.rain > 0.25 || phase.weather === "storm";
  const lightCool = hasLight ? lightDef.lightWarm === false : cool;

  // Máscara a media resolución (mucho más barata; se escala al componer)
  const scale = 0.35;
  const mw = Math.max(1, (w * scale) | 0);
  const mh = Math.max(1, (h * scale) | 0);
  const mask = getLightMask(mw, mh);
  const m = mask.getContext("2d");
  m.setTransform(scale, 0, 0, scale, 0, 0);
  m.clearRect(0, 0, w, h);
  // Velo: más denso en interiores (casas cerradas, lejos de farolas)
  // Interior: penumbra suave para que se lean yeso/suelo/muebles
  const veil = indoor
    ? (phase.night ? Math.min(0.42, 0.22 + darkness * 0.22) : Math.min(0.16, 0.08 + darkness * 0.12))
    : phase.night
      ? Math.min(0.2, 0.1 + darkness * 0.14)
      : Math.min(0.18, darkness * 0.28);
  m.fillStyle = indoor ? `rgba(22, 18, 14, ${veil})` : `rgba(8, 12, 24, ${veil})`;
  m.fillRect(0, 0, w, h);

  m.globalCompositeOperation = "destination-out";
  // Farolas de calle: fuera, o solo cerca de la puerta si estás dentro
  for (const { p, lx, ly } of lamps) {
    if (indoor) {
      const dx = p.x - game.player.x;
      const dy = p.y - game.player.y;
      if (dx * dx + dy * dy > 36) continue;
    }
    const flicker =
      phase.weather === "storm" ? 0.85 + Math.sin(game.time * 16 + p.x * 9) * 0.15 : 1;
    const cx = lx + 10;
    const cy = ly + 4;
    const lr = 165;
    const hole = m.createRadialGradient(cx, cy, 10, cx, cy, lr);
    hole.addColorStop(0, `rgba(0,0,0,${0.98 * flicker})`);
    hole.addColorStop(0.4, `rgba(0,0,0,${0.7 * flicker})`);
    hole.addColorStop(0.75, `rgba(0,0,0,${0.28 * flicker})`);
    hole.addColorStop(1, "rgba(0,0,0,0)");
    m.fillStyle = hole;
    m.beginPath();
    m.arc(cx, cy, lr, 0, Math.PI * 2);
    m.fill();
  }
  // Lámparas / velas interiores (lista cacheada)
  const indoorSrc = game.world.indoorLights || game.world.props;
  for (const p of indoorSrc) {
    if ((p.type !== "indoorLamp" && p.type !== "candle") || !p.lit) continue;
    const lx = p.x * TILE_PX - camX;
    const ly = p.y * TILE_PX - camY;
    if (lx < -80 || ly < -80 || lx > w + 80 || ly > h + 80) continue;
    const flick = p.flicker ? 0.82 + Math.sin(game.time * 9 + p.x * 7) * 0.18 : 0.92 + Math.sin(game.time * 3 + p.y) * 0.08;
    const lr = p.type === "candle" ? 78 : 125;
    const hole = m.createRadialGradient(lx, ly, 4, lx, ly, lr);
    hole.addColorStop(0, `rgba(0,0,0,${0.95 * flick})`);
    hole.addColorStop(0.45, `rgba(0,0,0,${0.55 * flick})`);
    hole.addColorStop(1, "rgba(0,0,0,0)");
    m.fillStyle = hole;
    m.beginPath();
    m.arc(lx, ly, lr, 0, Math.PI * 2);
    m.fill();
  }
  // Luz ambiente de habitación (suave; evita el “cuadrado blanco”)
  if (indoor && _viewIndoor) {
    const b = _viewIndoor;
    const rx = ((b.x0 + b.x1 + 1) * 0.5) * TILE_PX - camX;
    const ry = ((b.y0 + b.y1 + 1) * 0.5) * TILE_PX - camY;
    const rr = Math.max(100, Math.min(b.x1 - b.x0, b.y1 - b.y0) * TILE_PX * 0.78);
    const ambient = m.createRadialGradient(rx, ry, rr * 0.15, rx, ry, rr);
    ambient.addColorStop(0, phase.night ? "rgba(0,0,0,0.55)" : "rgba(0,0,0,0.4)");
    ambient.addColorStop(0.6, phase.night ? "rgba(0,0,0,0.22)" : "rgba(0,0,0,0.16)");
    ambient.addColorStop(1, "rgba(0,0,0,0)");
    m.fillStyle = ambient;
    m.beginPath();
    m.arc(rx, ry, rr, 0, Math.PI * 2);
    m.fill();
  }

  if (hasLight && playerR > 0) {
    const hole = m.createRadialGradient(px, py, 8, px, py, playerR);
    hole.addColorStop(0, "rgba(0,0,0,0.95)");
    hole.addColorStop(0.5, "rgba(0,0,0,0.45)");
    hole.addColorStop(1, "rgba(0,0,0,0)");
    m.fillStyle = hole;
    m.beginPath();
    m.arc(px, py, playerR, 0, Math.PI * 2);
    m.fill();
  }
  for (const win of litWindows) {
    const wr = 42;
    const hole = m.createRadialGradient(win.x, win.y, 1, win.x, win.y, wr);
    hole.addColorStop(0, "rgba(0,0,0,0.65)");
    hole.addColorStop(1, "rgba(0,0,0,0)");
    m.fillStyle = hole;
    m.beginPath();
    m.arc(win.x, win.y, wr, 0, Math.PI * 2);
    m.fill();
  }
  m.globalCompositeOperation = "source-over";
  m.setTransform(1, 0, 0, 1, 0, 0);
  ctx.drawImage(mask, 0, 0, w, h);

  // Brillo de farolas (omitir de día en exterior: caro y apenas se nota)
  const doGlow = indoor || phase.night || phase.thunder > 0 || darkness > 0.25;
  if (!doGlow) return;
  ctx.save();
  ctx.globalCompositeOperation = "lighter";
  for (const { p, lx, ly } of lamps) {
    if (indoor) {
      const dx = p.x - game.player.x;
      const dy = p.y - game.player.y;
      if (dx * dx + dy * dy > 36) continue;
    }
    const flicker =
      phase.weather === "storm" ? 0.85 + Math.sin(game.time * 16 + p.x * 9) * 0.15 : 1;
    const cx = lx + 10;
    const cy = ly + 4;
    const lr = 155;
    const lg = ctx.createRadialGradient(cx, cy - 8, 2, cx, cy, lr);
    if (cool) {
      lg.addColorStop(0, `rgba(225, 238, 255, ${0.42 * flicker})`);
      lg.addColorStop(0.4, `rgba(175, 205, 245, ${0.18 * flicker})`);
      lg.addColorStop(1, "rgba(140, 170, 220, 0)");
    } else {
      lg.addColorStop(0, `rgba(255, 238, 190, ${0.4 * flicker})`);
      lg.addColorStop(0.4, `rgba(255, 205, 130, ${0.16 * flicker})`);
      lg.addColorStop(1, "rgba(255, 170, 80, 0)");
    }
    ctx.fillStyle = lg;
    ctx.beginPath();
    ctx.arc(cx, cy, lr, 0, Math.PI * 2);
    ctx.fill();


  }

  if (hasLight && playerR > 0) {
    const pg = ctx.createRadialGradient(px, py, 6, px, py, playerR);
    if (lightCool) {
      pg.addColorStop(0, `rgba(210, 230, 255, ${0.28 + darkness * 0.1})`);
      pg.addColorStop(0.5, `rgba(160, 195, 240, ${0.1 + darkness * 0.05})`);
      pg.addColorStop(1, "rgba(120, 160, 220, 0)");
    } else {
      pg.addColorStop(0, `rgba(255, 220, 150, ${0.3 + darkness * 0.1})`);
      pg.addColorStop(0.5, `rgba(255, 180, 100, ${0.1 + darkness * 0.05})`);
      pg.addColorStop(1, "rgba(255, 150, 70, 0)");
    }
    ctx.fillStyle = pg;
    ctx.beginPath();
    ctx.arc(px, py, playerR, 0, Math.PI * 2);
    ctx.fill();
  }

  for (const win of litWindows) {
    const wr = indoor ? 48 : 32;
    const wg = ctx.createRadialGradient(win.x, win.y, 1, win.x, win.y, wr);
    wg.addColorStop(0, indoor ? "rgba(255, 210, 140, 0.34)" : "rgba(255, 220, 140, 0.26)");
    wg.addColorStop(0.55, indoor ? "rgba(255, 180, 100, 0.12)" : "rgba(255, 185, 100, 0.08)");
    wg.addColorStop(1, "rgba(255, 160, 70, 0)");
    ctx.fillStyle = wg;
    ctx.beginPath();
    ctx.arc(win.x, win.y, wr, 0, Math.PI * 2);
    ctx.fill();
  }

  for (const p of (game.world.indoorLights || game.world.props)) {
    if ((p.type !== "indoorLamp" && p.type !== "candle") || !p.lit) continue;
    const lx = p.x * TILE_PX - camX;
    const ly = p.y * TILE_PX - camY;
    if (lx < -80 || ly < -80 || lx > w + 80 || ly > h + 80) continue;
    const flick = p.flicker ? 0.82 + Math.sin(game.time * 9 + p.x * 7) * 0.18 : 0.94;
    const lr = p.type === "candle" ? 64 : 100;
    const lg = ctx.createRadialGradient(lx, ly - 4, 2, lx, ly, lr);
    lg.addColorStop(0, `rgba(255, 210, 140, ${0.38 * flick})`);
    lg.addColorStop(0.4, `rgba(255, 160, 80, ${0.14 * flick})`);
    lg.addColorStop(1, "rgba(255, 130, 50, 0)");
    ctx.fillStyle = lg;
    ctx.beginPath();
    ctx.arc(lx, ly, lr, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

let _lightMask = null;
function getLightMask(w, h) {
  if (!_lightMask) _lightMask = document.createElement("canvas");
  if (_lightMask.width !== w || _lightMask.height !== h) {
    _lightMask.width = Math.max(1, w | 0);
    _lightMask.height = Math.max(1, h | 0);
  }
  return _lightMask;
}

function tileIndex(game, x, y) {
  return game.world.tiles[Math.floor(y) * game.world.size + Math.floor(x)];
}


let _groundCanvas = null;
let _groundKey = "";
let _groundMeta = { x0: 0, y0: 0, x1: 0, y1: 0 };

function isAnimatedGround(tile) {
  return tile === TILE.WATER;
}

/** Caché de suelo con margen: no se regenera en cada paso de cámara. */
function drawCachedGround(ctx, game, phase, camX, camY, x0, y0, x1, y1) {
  const size = game.world.size;
  const PAD = 12;
  const indoorKey = _viewIndoor ? `${_viewIndoor.x0},${_viewIndoor.y0},${_viewIndoor.style || ""}` : "out";
  const baseKey = `${game.world.seed}|${game.world.tileRev || 0}|${phase.name}|${phase.night ? 1 : 0}|${indoorKey}`;
  const outOfBounds =
    x0 < _groundMeta.x0 ||
    y0 < _groundMeta.y0 ||
    x1 > _groundMeta.x1 ||
    y1 > _groundMeta.y1;

  if (!_groundCanvas || _groundKey !== baseKey || outOfBounds) {
    const cx0 = Math.max(0, x0 - PAD);
    const cy0 = Math.max(0, y0 - PAD);
    const cx1 = Math.min(size, x1 + PAD);
    const cy1 = Math.min(size, y1 + PAD);
    const gw = Math.max(1, (cx1 - cx0) * TILE_PX);
    const gh = Math.max(1, (cy1 - cy0) * TILE_PX);
    if (!_groundCanvas) _groundCanvas = document.createElement("canvas");
    if (_groundCanvas.width !== gw || _groundCanvas.height !== gh) {
      _groundCanvas.width = gw;
      _groundCanvas.height = gh;
    }
    const g = _groundCanvas.getContext("2d", { alpha: false });
    g.fillStyle = "#2a2a28";
    g.fillRect(0, 0, gw, gh);
    for (let ty = cy0; ty < cy1; ty++) {
      for (let tx = cx0; tx < cx1; tx++) {
        const tile = game.world.tiles[ty * size + tx];
        if (isAnimatedGround(tile)) continue;
        drawGround(g, game, tile, tx, ty, (tx - cx0) * TILE_PX, (ty - cy0) * TILE_PX, phase);
      }
    }
    _groundMeta = { x0: cx0, y0: cy0, x1: cx1, y1: cy1 };
    _groundKey = baseKey;
  }

  ctx.drawImage(
    _groundCanvas,
    _groundMeta.x0 * TILE_PX - camX,
    _groundMeta.y0 * TILE_PX - camY
  );

  // Agua animada (fuera de caché)
  for (let ty = y0; ty < y1; ty++) {
    for (let tx = x0; tx < x1; tx++) {
      const tile = game.world.tiles[ty * size + tx];
      if (!isAnimatedGround(tile)) continue;
      drawGround(ctx, game, tile, tx, ty, tx * TILE_PX - camX, ty * TILE_PX - camY, phase);
    }
  }
}

function drawGround(ctx, game, tile, tx, ty, px, py, phase) {
  if (tile === TILE.ROAD || tile === TILE.CROSSWALK) {
    drawRoad(ctx, game, tile, tx, ty, px, py, phase);
    return;
  }
  if (tile === TILE.SIDEWALK) {
    drawSidewalk(ctx, game, tx, ty, px, py, phase);
    return;
  }
  if (tile === TILE.WATER) {
    drawWater(ctx, game, tx, ty, px, py, game.time);
    return;
  }
  if (tile === TILE.PARK) {
    drawGrass(ctx, tx, ty, px, py);
    return;
  }
  if (tile === TILE.PARKING) {
    drawParking(ctx, tx, ty, px, py);
    return;
  }
  if (tile === TILE.ALLEY || tile === TILE.RUBBLE) {
    drawAlley(ctx, tile, tx, ty, px, py);
    return;
  }
  if (tile === TILE.FLOOR || tile === TILE.BASE) {
    drawInterior(ctx, game, tile, tx, ty, px, py);
    return;
  }
  if (tile === TILE.WALL) {
    const b = buildingAt(game.world, tx + 0.5, ty + 0.5);
    if (_viewIndoor && b === _viewIndoor) {
      drawIndoorWallTile(ctx, px, py, b, tx, ty);
      return;
    }
    // Base de fachada + suciedad / grietas
    ctx.fillStyle = b?.facade || "#4a4540";
    ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
    ctx.fillStyle = "rgba(0,0,0,0.16)";
    ctx.fillRect(px + 2, py + 6, 4, 28);
    ctx.fillRect(px + 30, py + 10, 3, 20);
    if (((tx * 5 + ty * 9) % 7) === 0) {
      ctx.strokeStyle = "rgba(15,12,10,0.4)";
      ctx.beginPath();
      ctx.moveTo(px + 10, py + 4);
      ctx.lineTo(px + 14, py + 22);
      ctx.lineTo(px + 12, py + 40);
      ctx.stroke();
    }
    if (((tx + ty * 3) % 5) === 0) {
      ctx.fillStyle = "rgba(40, 60, 30, 0.22)";
      ctx.fillRect(px + 18, py + 28, 12, 10);
    }
    return;
  }
  if (tile === TILE.DOOR) {
    const b = buildingAt(game.world, tx + 0.5, ty + 0.5);
    ctx.fillStyle = b?.facade || "#5a4a3a";
    ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
    return;
  }
  ctx.fillStyle = TILE_META[tile]?.color || "#333";
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
}

function neighborTile(game, tx, ty) {
  if (tx < 0 || ty < 0 || tx >= game.world.size || ty >= game.world.size) return TILE.WALL;
  return game.world.tiles[ty * game.world.size + tx];
}

function drawRoad(ctx, game, tile, tx, ty, px, py, phase) {
  const n = ((tx * 19 + ty * 11) & 15);
  const patch = ((tx * 13 + ty * 7) % 19) === 0;
  // De noche el asfalto sube de tono para no perderse en el velo
  const nightBoost = phase?.night ? 12 : 0;
  const shade = (patch ? 42 + (n % 5) : 32 + (n % 6)) + nightBoost;
  ctx.fillStyle = `rgb(${shade},${shade + 1},${shade + 4})`;
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);

  // Grano de asfalto
  ctx.fillStyle = "rgba(255,255,255,0.035)";
  for (let i = 0; i < 6; i++) {
    const sx = px + ((tx * 7 + i * 13 + ty) % 42);
    const sy = py + ((ty * 5 + i * 9) % 42);
    ctx.fillRect(sx, sy, 2, 2);
  }

  // Manchas de aceite / baches
  if (((tx + ty * 3) % 13) === 0) {
    ctx.fillStyle = "rgba(10,12,14,0.38)";
    ctx.beginPath();
    ctx.ellipse(px + 22, py + 24, 8, 5, 0.4, 0, Math.PI * 2);
    ctx.fill();
  }
  if (patch) {
    ctx.strokeStyle = "rgba(30,28,26,0.55)";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(px + 8, py + 18);
    ctx.lineTo(px + 20, py + 12);
    ctx.lineTo(px + 34, py + 22);
    ctx.lineTo(px + 18, py + 34);
    ctx.closePath();
    ctx.stroke();
  }

  ctx.strokeStyle = "rgba(20,20,22,0.35)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(px + 6 + n, py + 16);
  ctx.lineTo(px + 18 + n, py + 26);
  ctx.lineTo(px + 30, py + 22);
  ctx.stroke();

  // Bordillo hacia acera
  const curb = "rgba(90,88,80,0.55)";
  ctx.fillStyle = curb;
  if (neighborTile(game, tx, ty - 1) === TILE.SIDEWALK) ctx.fillRect(px, py, TILE_PX, 3);
  if (neighborTile(game, tx, ty + 1) === TILE.SIDEWALK) ctx.fillRect(px, py + TILE_PX - 3, TILE_PX, 3);
  if (neighborTile(game, tx - 1, ty) === TILE.SIDEWALK) ctx.fillRect(px, py, 3, TILE_PX);
  if (neighborTile(game, tx + 1, ty) === TILE.SIDEWALK) ctx.fillRect(px + TILE_PX - 3, py, 3, TILE_PX);

  // Línea blanca de borde de calzada
  ctx.strokeStyle = "rgba(140,140,130,0.28)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  if (tx % 10 === 0) {
    ctx.moveTo(px + 3, py + 2);
    ctx.lineTo(px + 3, py + TILE_PX - 2);
  } else if (tx % 10 === 1) {
    ctx.moveTo(px + TILE_PX - 3, py + 2);
    ctx.lineTo(px + TILE_PX - 3, py + TILE_PX - 2);
  } else if (ty % 10 === 0) {
    ctx.moveTo(px + 2, py + 3);
    ctx.lineTo(px + TILE_PX - 2, py + 3);
  } else if (ty % 10 === 1) {
    ctx.moveTo(px + 2, py + TILE_PX - 3);
    ctx.lineTo(px + TILE_PX - 2, py + TILE_PX - 3);
  }
  ctx.stroke();

  const vertRoad = tx % 10 < 2;
  if (tile === TILE.CROSSWALK) {
    ctx.fillStyle = "rgba(160,160,150,0.55)";
    if (vertRoad) {
      for (let i = 0; i < 5; i++) ctx.fillRect(px + 4 + i * 9, py + 6, 5, TILE_PX - 12);
    } else {
      for (let i = 0; i < 5; i++) ctx.fillRect(px + 6, py + 4 + i * 9, TILE_PX - 12, 5);
    }
    // Línea de stop
    ctx.strokeStyle = "rgba(240,240,230,0.75)";
    ctx.lineWidth = 3;
    ctx.beginPath();
    if (vertRoad) {
      ctx.moveTo(px + 4, py + 4);
      ctx.lineTo(px + TILE_PX - 4, py + 4);
    } else {
      ctx.moveTo(px + 4, py + 4);
      ctx.lineTo(px + 4, py + TILE_PX - 4);
    }
    ctx.stroke();
  } else {
    ctx.strokeStyle = "rgba(150, 120, 40, 0.4)";
    ctx.setLineDash([10, 12]);
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    if (vertRoad) {
      ctx.moveTo(px + TILE_PX / 2, py + 3);
      ctx.lineTo(px + TILE_PX / 2, py + TILE_PX - 3);
    } else {
      ctx.moveTo(px + 3, py + TILE_PX / 2);
      ctx.lineTo(px + TILE_PX - 3, py + TILE_PX / 2);
    }
    ctx.stroke();
    ctx.setLineDash([]);
  }

  // Puente sobre canal: tablones
  const up = neighborTile(game, tx, ty - 1);
  const down = neighborTile(game, tx, ty + 1);
  if (up === TILE.WATER || down === TILE.WATER || neighborTile(game, tx - 1, ty) === TILE.WATER || neighborTile(game, tx + 1, ty) === TILE.WATER) {
    ctx.fillStyle = "rgba(90,70,50,0.35)";
    for (let i = 0; i < 4; i++) ctx.fillRect(px + 4, py + 6 + i * 10, TILE_PX - 8, 4);
    ctx.strokeStyle = "rgba(40,30,20,0.5)";
    ctx.strokeRect(px + 2, py + 2, TILE_PX - 4, TILE_PX - 4);
  }
}

function drawSidewalk(ctx, game, tx, ty, px, py, phase) {
  const nightBoost = phase?.night ? 8 : 0;
  const base = 82 + ((tx + ty) % 4) + nightBoost;
  // Superficie continua (sin 4 baldosas cuadradas duras)
  ctx.fillStyle = `rgb(${base},${base - 3},${base - 8})`;
  ctx.fillRect(px - 0.25, py - 0.25, TILE_PX + 0.75, TILE_PX + 0.75);

  // Juntas lineales suaves (cruz)
  ctx.strokeStyle = "rgba(40,36,30,0.22)";
  ctx.lineWidth = 1;
  ctx.lineCap = "round";
  ctx.beginPath();
  ctx.moveTo(px + TILE_PX / 2, py + 4);
  ctx.lineTo(px + TILE_PX / 2, py + TILE_PX - 4);
  ctx.moveTo(px + 4, py + TILE_PX / 2);
  ctx.lineTo(px + TILE_PX - 4, py + TILE_PX / 2);
  ctx.stroke();

  // Mancha / grieta orgánica
  if (((tx * 5 + ty * 9) % 5) === 0) {
    ctx.strokeStyle = "rgba(55,60,40,0.4)";
    ctx.lineWidth = 1.3;
    ctx.beginPath();
    ctx.moveTo(px + TILE_PX / 2 - 1, py + 10);
    ctx.quadraticCurveTo(px + TILE_PX / 2 + 2, py + 18, px + TILE_PX / 2, py + 26);
    ctx.stroke();
  }
  if (((tx + ty * 4) % 7) === 0) {
    ctx.fillStyle = "rgba(30,28,24,0.28)";
    ctx.beginPath();
    ctx.ellipse(px + 20, py + 24, 7, 4, 0.3, 0, Math.PI * 2);
    ctx.fill();
  }
  if (((tx * 9 + ty) % 11) === 0) {
    ctx.strokeStyle = "rgba(20,18,16,0.4)";
    ctx.lineWidth = 1.15;
    ctx.beginPath();
    ctx.moveTo(px + 6, py + 10);
    ctx.quadraticCurveTo(px + 18, py + 22, px + 38, py + 34);
    ctx.stroke();
  }

  // Bordillo suave
  ctx.fillStyle = "rgba(18,18,20,0.45)";
  if (neighborTile(game, tx, ty + 1) === TILE.ROAD || neighborTile(game, tx, ty + 1) === TILE.CROSSWALK) {
    fillRound(ctx, px + 1, py + TILE_PX - 4, TILE_PX - 2, 3, 1.5);
  }
  if (neighborTile(game, tx, ty - 1) === TILE.ROAD || neighborTile(game, tx, ty - 1) === TILE.CROSSWALK) {
    fillRound(ctx, px + 1, py + 1, TILE_PX - 2, 2.5, 1.5);
  }
  if (neighborTile(game, tx - 1, ty) === TILE.ROAD || neighborTile(game, tx - 1, ty) === TILE.CROSSWALK) {
    fillRound(ctx, px + 1, py + 1, 2.5, TILE_PX - 2, 1.5);
  }
  if (neighborTile(game, tx + 1, ty) === TILE.ROAD || neighborTile(game, tx + 1, ty) === TILE.CROSSWALK) {
    fillRound(ctx, px + TILE_PX - 3.5, py + 1, 2.5, TILE_PX - 2, 1.5);
  }

  ctx.fillStyle = "rgba(140,130,110,0.1)";
  ctx.fillRect(px, py, TILE_PX, 2);
}

function drawWater(ctx, game, tx, ty, px, py, time) {
  // Río tóxico post-apocalíptico: verde enfermo / aceite
  const g = ctx.createLinearGradient(px, py, px + TILE_PX, py + TILE_PX);
  g.addColorStop(0, "#1c3a28");
  g.addColorStop(0.35, "#163428");
  g.addColorStop(0.7, "#1a2e22");
  g.addColorStop(1, "#0e2218");
  ctx.fillStyle = g;
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);

  // Manchas de aceite / brillo tóxico
  if (((tx * 5 + ty * 3) % 7) === 0) {
    ctx.fillStyle = "rgba(40, 90, 40, 0.35)";
    ctx.beginPath();
    ctx.ellipse(px + 22, py + 24, 12, 6, 0.3, 0, Math.PI * 2);
    ctx.fill();
  }
  if (((tx + ty * 2) % 11) === 0) {
    ctx.fillStyle = "rgba(20, 16, 10, 0.45)";
    ctx.beginPath();
    ctx.ellipse(px + 18, py + 16, 9, 4, -0.2, 0, Math.PI * 2);
    ctx.fill();
  }

  // Orilla ruinosa
  const bank = "rgba(55,50,42,0.9)";
  if (neighborTile(game, tx, ty - 1) !== TILE.WATER && neighborTile(game, tx, ty - 1) !== TILE.ROAD) {
    ctx.fillStyle = bank;
    ctx.fillRect(px, py, TILE_PX, 6);
    ctx.fillStyle = "rgba(90,70,40,0.35)";
    ctx.fillRect(px + 4, py + 1, 10, 3);
  }
  if (neighborTile(game, tx, ty + 1) !== TILE.WATER && neighborTile(game, tx, ty + 1) !== TILE.ROAD) {
    ctx.fillStyle = bank;
    ctx.fillRect(px, py + TILE_PX - 6, TILE_PX, 6);
  }

  ctx.strokeStyle = "rgba(90, 160, 90, 0.22)";
  ctx.lineWidth = 1.4;
  const wave = Math.sin(time * 1.6 + tx * 0.55 + ty * 0.35) * 2.5;
  ctx.beginPath();
  ctx.moveTo(px + 2, py + 16 + wave);
  ctx.quadraticCurveTo(px + 22, py + 12 + wave, px + 46, py + 18 + wave);
  ctx.stroke();
  ctx.strokeStyle = "rgba(60, 100, 70, 0.18)";
  ctx.beginPath();
  ctx.moveTo(px + 2, py + 30 + wave * 0.6);
  ctx.quadraticCurveTo(px + 24, py + 28 + wave * 0.6, px + 46, py + 32 + wave * 0.6);
  ctx.stroke();

  // Espuma tóxica / basura flotante
  if (((tx + ty) % 8) === 0) {
    ctx.fillStyle = "rgba(120, 140, 60, 0.35)";
    ctx.fillRect(px + 16, py + 20 + wave, 8, 3);
  }
  if (((tx * 3 + ty) % 13) === 0) {
    ctx.fillStyle = "rgba(70, 55, 40, 0.55)";
    ctx.fillRect(px + 10, py + 28 + wave, 7, 4);
  }
}

function drawGrass(ctx, tx, ty, px, py) {
  // Base continua (poca variación entre tiles → menos “cuadritos”)
  const g = 60 + ((tx + ty) % 3);
  ctx.fillStyle = `rgb(30,${g},28)`;
  ctx.fillRect(px - 0.5, py - 0.5, TILE_PX + 1.5, TILE_PX + 1.5);

  // Soft noise dab (muy sutil)
  if (((tx * 3 + ty * 5) % 4) === 0) {
    ctx.fillStyle = "rgba(40,78,36,0.18)";
    ctx.beginPath();
    ctx.ellipse(px + 18 + (tx % 8), py + 20 + (ty % 6), 8, 5, 0.2, 0, Math.PI * 2);
    ctx.fill();
  }

  if (((tx * 5 + ty * 3) % 17) === 0) {
    ctx.fillStyle = "rgba(96,74,44,0.28)";
    ctx.beginPath();
    ctx.ellipse(px + 24, py + 26, 10, 6, 0.25, 0, Math.PI * 2);
    ctx.fill();
  }

  // Briznas curvas que cruzan bordes del tile
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  for (let i = 0; i < 18; i++) {
    const gx = px + ((tx * 5 + i * 13 + ty * 3) % 50) - 3;
    const gy = py + 6 + ((ty * 7 + i * 9) % 38);
    const lean = ((i % 5) - 2) * 2.2;
    const tall = 8 + (i % 5);
    ctx.strokeStyle = i % 3 === 0 ? "rgba(120,168,82,0.88)" : "rgba(52,102,50,0.7)";
    ctx.lineWidth = i % 4 === 0 ? 1.85 : 1.15;
    ctx.beginPath();
    ctx.moveTo(gx, gy + tall);
    ctx.quadraticCurveTo(gx + lean * 0.35, gy + tall * 0.42, gx + lean, gy - 2);
    ctx.stroke();
  }
  if (((tx + ty * 2) % 11) === 0) {
    ctx.fillStyle = "#d4a858";
    ctx.beginPath();
    ctx.arc(px + 20, py + 18, 2, 0, Math.PI * 2);
    ctx.fill();
  }
  if (((tx * 2 + ty) % 13) === 0) {
    ctx.fillStyle = "#c86a78";
    ctx.beginPath();
    ctx.arc(px + 32, py + 28, 2, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawParking(ctx, tx, ty, px, py) {
  const n = ((tx + ty) % 4);
  ctx.fillStyle = `rgb(${72 + n},${74 + n},${80 + n})`;
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
  ctx.strokeStyle = "rgba(230,230,220,0.55)";
  ctx.lineWidth = 1.6;
  ctx.lineCap = "round";
  strokeRound(ctx, px + 5, py + 3, TILE_PX - 10, TILE_PX - 6, 4, "rgba(230,230,220,0.55)", 1.6);
  // Flecha suave
  ctx.fillStyle = "rgba(220,220,210,0.35)";
  ctx.beginPath();
  ctx.moveTo(px + TILE_PX / 2, py + 14);
  ctx.lineTo(px + TILE_PX / 2 + 6, py + 22);
  ctx.lineTo(px + TILE_PX / 2 - 6, py + 22);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = "rgba(220,220,210,0.5)";
  ctx.font = `600 10px ${FONT_UI}`;
  ctx.textAlign = "center";
  ctx.fillText(String(((tx + ty * 3) % 24) + 1), px + TILE_PX / 2, py + TILE_PX / 2 + 10);
}

function drawAlley(ctx, tile, tx, ty, px, py) {
  ctx.fillStyle = tile === TILE.RUBBLE ? "#6a6258" : "#3a3a40";
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
  if (((tx + ty) % 5) === 0) {
    ctx.fillStyle = "rgba(40,70,80,0.35)";
    ctx.beginPath();
    ctx.ellipse(px + 24, py + 30, 10, 5, 0, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.fillStyle = "#7a7060";
  ctx.fillRect(px + 8, py + 22, 12, 8);
  ctx.fillRect(px + 24, py + 16, 14, 11);
  ctx.fillStyle = "#5a5048";
  ctx.fillRect(px + 28, py + 28, 8, 6);
  if (tile === TILE.RUBBLE) {
    ctx.fillStyle = "#8a8070";
    ctx.fillRect(px + 14, py + 10, 10, 7);
    ctx.fillStyle = "#4a4440";
    ctx.fillRect(px + 6, py + 32, 16, 5);
  }
}

function drawInterior(ctx, game, tile, tx, ty, px, py) {
  const b = buildingAt(game.world, tx + 0.5, ty + 0.5);
  const floorStyle = b?.floorStyle || "wood";
  drawInteriorFloor(ctx, tile, px, py, b, floorStyle, tx, ty);

  const dec = game.world.decor?.get(`${tx},${ty}`);
  if (dec) drawFloorDecor(ctx, dec, px, py);

  if (tile === TILE.BASE) {
    ctx.strokeStyle = "rgba(180, 210, 120, 0.55)";
    ctx.lineWidth = 2;
    ctx.strokeRect(px + 5, py + 5, TILE_PX - 10, TILE_PX - 10);
  }

  // Muebles: capa viva (drawLiveFurniture) — no en caché ni bajo fachada
  if (b && phaseIsDayish(phaseNameSafe(game))) {
    ctx.fillStyle = "rgba(255, 236, 190, 0.04)";
    ctx.fillRect(px, py, TILE_PX, TILE_PX);
  }
}

function drawLiveFurniture(ctx, game, camX, camY, x0, y0, x1, y1, building) {
  const target = game.player?.lootTarget;
  const ix0 = Math.max(x0, building.x0 + 1);
  const iy0 = Math.max(y0, building.y0 + 1);
  const ix1 = Math.min(x1 - 1, building.x1 - 1);
  const iy1 = Math.min(y1 - 1, building.y1 - 1);
  for (let ty = iy0; ty <= iy1; ty++) {
    for (let tx = ix0; tx <= ix1; tx++) {
      const furn = game.world.interiors.get(`${tx},${ty}`);
      const fType = furnitureType(furn);
      if (!fType) continue;
      const searched = typeof furn === "object" && furn?.searched;
      const searching = target && target.kind === "container" && target.x === tx && target.y === ty;
      drawFurniturePiece(ctx, fType, searched, tx * TILE_PX - camX, ty * TILE_PX - camY, building.accent, searching);
    }
  }
}
function drawInteriorFloor(ctx, tile, px, py, b, floorStyle, tx, ty) {
  if (tile === TILE.BASE) {
    ctx.fillStyle = "#4f6a40";
    ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
    ctx.strokeStyle = "rgba(180, 210, 120, 0.45)";
    ctx.strokeRect(px + 6, py + 6, TILE_PX - 12, TILE_PX - 12);
    return;
  }

  const odd = ((tx + ty) & 1) === 0;
  if (floorStyle === "tile") {
    ctx.fillStyle = odd ? "#a89c90" : "#91867a";
    ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
    ctx.strokeStyle = "rgba(48,40,34,0.45)";
    ctx.lineWidth = 1;
    ctx.strokeRect(px + 0.5, py + 0.5, TILE_PX - 1, TILE_PX - 1);
    ctx.beginPath();
    ctx.moveTo(px + TILE_PX / 2, py + 1);
    ctx.lineTo(px + TILE_PX / 2, py + TILE_PX - 1);
    ctx.moveTo(px + 1, py + TILE_PX / 2);
    ctx.lineTo(px + TILE_PX - 1, py + TILE_PX / 2);
    ctx.stroke();
    ctx.fillStyle = "rgba(255,255,255,0.1)";
    ctx.fillRect(px + 3, py + 3, 10, 3);
  } else if (floorStyle === "concrete") {
    // Hormigón de nave: losas grandes, juntas y grano
    const slab = ((tx >> 1) + (ty >> 1)) & 1;
    ctx.fillStyle = slab ? "#6a6862" : "#5c5a54";
    ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
    // Grano
    ctx.fillStyle = "rgba(255,255,255,0.04)";
    for (let i = 0; i < 5; i++) {
      const gx = px + ((tx * 11 + i * 17 + ty * 3) % 42);
      const gy = py + ((ty * 13 + i * 9) % 42);
      ctx.fillRect(gx, gy, 2, 1);
    }
    // Junta de dilatación cada 2 tiles
    ctx.strokeStyle = "rgba(24,22,18,0.55)";
    ctx.lineWidth = 2;
    if ((tx & 1) === 0) {
      ctx.beginPath();
      ctx.moveTo(px, py);
      ctx.lineTo(px, py + TILE_PX);
      ctx.stroke();
    }
    if ((ty & 1) === 0) {
      ctx.beginPath();
      ctx.moveTo(px, py);
      ctx.lineTo(px + TILE_PX, py);
      ctx.stroke();
    }
    // Grieta ocasional
    if (((tx * 3 + ty * 5) % 9) === 0) {
      ctx.strokeStyle = "rgba(28,26,24,0.4)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(px + 8, py + 12);
      ctx.lineTo(px + 20, py + 26);
      ctx.lineTo(px + 36, py + 18);
      ctx.stroke();
    }
    // Placa metálica ocasional
    if (((tx * 7 + ty * 11) % 13) === 0) {
      ctx.fillStyle = "rgba(70, 74, 78, 0.55)";
      ctx.fillRect(px + 10, py + 10, 28, 28);
      ctx.strokeStyle = "rgba(20,22,24,0.45)";
      ctx.strokeRect(px + 10, py + 10, 28, 28);
      ctx.fillStyle = "rgba(180,190,200,0.15)";
      ctx.beginPath();
      ctx.arc(px + 16, py + 16, 2, 0, Math.PI * 2);
      ctx.arc(px + 32, py + 16, 2, 0, Math.PI * 2);
      ctx.arc(px + 16, py + 32, 2, 0, Math.PI * 2);
      ctx.arc(px + 32, py + 32, 2, 0, Math.PI * 2);
      ctx.fill();
    }
  } else if (floorStyle === "office") {
    ctx.fillStyle = odd ? "#5c6672" : "#4c5662";
    ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
    ctx.strokeStyle = "rgba(18,22,28,0.35)";
    ctx.beginPath();
    ctx.moveTo(px, py + TILE_PX);
    ctx.lineTo(px + TILE_PX, py);
    ctx.stroke();
    ctx.fillStyle = "rgba(255,255,255,0.055)";
    ctx.fillRect(px + 2, py + 2, TILE_PX - 4, 4);
    ctx.fillStyle = "rgba(0,0,0,0.12)";
    ctx.fillRect(px + 4, py + TILE_PX - 6, TILE_PX - 8, 3);
  } else {
    // Madera real (no teñida por fachada)
    ctx.fillStyle = odd ? "#926e4c" : "#7d5c3c";
    ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
    ctx.strokeStyle = "rgba(42,28,16,0.35)";
    ctx.lineWidth = 1;
    for (let i = 1; i < 4; i++) {
      const yy = py + i * 12;
      ctx.beginPath();
      ctx.moveTo(px, yy);
      ctx.lineTo(px + TILE_PX, yy);
      ctx.stroke();
      const jx = px + ((tx * 5 + i * 11) % 6) * 7 + 4;
      ctx.beginPath();
      ctx.moveTo(jx, yy - 12);
      ctx.lineTo(jx, yy);
      ctx.stroke();
    }
    ctx.strokeStyle = "rgba(255,220,160,0.08)";
    ctx.beginPath();
    ctx.moveTo(px + 4, py + 5);
    ctx.lineTo(px + 40, py + 9);
    ctx.stroke();
  }

  const wear = (tx * 17 + ty * 31) % 19;
  if (wear === 0) {
    ctx.fillStyle = "rgba(0,0,0,0.08)";
    ctx.fillRect(px + 8, py + 22, 16, 2);
  } else if (wear === 7) {
    ctx.fillStyle = "rgba(255,255,255,0.04)";
    ctx.fillRect(px + 18, py + 10, 14, 2);
  }
}

function drawFloorDecor(ctx, dec, px, py) {
  if (dec.kind === "rug") {
    const c = dec.color || "#6a3a3a";
    const inset = dec.variant === 2 ? 8 : 3;
    ctx.fillStyle = "rgba(0,0,0,0.18)";
    ctx.fillRect(px + inset + 2, py + inset + 3, TILE_PX - inset * 2, TILE_PX - inset * 2);
    ctx.fillStyle = c;
    ctx.fillRect(px + inset, py + inset, TILE_PX - inset * 2, TILE_PX - inset * 2);
    ctx.strokeStyle = shade(c, 30);
    ctx.lineWidth = 2;
    ctx.strokeRect(px + inset + 1, py + inset + 1, TILE_PX - inset * 2 - 2, TILE_PX - inset * 2 - 2);
    ctx.strokeStyle = shade(c, -20);
    ctx.lineWidth = 1;
    ctx.strokeRect(px + inset + 4, py + inset + 4, TILE_PX - inset * 2 - 8, TILE_PX - inset * 2 - 8);
    ctx.fillStyle = shade(c, 22);
    ctx.globalAlpha = 0.45;
    if (dec.variant === 1) {
      ctx.fillRect(px + TILE_PX / 2 - 5, py + TILE_PX / 2 - 5, 10, 10);
    } else {
      ctx.beginPath();
      ctx.moveTo(px + TILE_PX / 2, py + inset + 8);
      ctx.lineTo(px + TILE_PX - inset - 8, py + TILE_PX / 2);
      ctx.lineTo(px + TILE_PX / 2, py + TILE_PX - inset - 8);
      ctx.lineTo(px + inset + 8, py + TILE_PX / 2);
      ctx.closePath();
      ctx.fill();
    }
    ctx.globalAlpha = 1;
    ctx.strokeStyle = shade(c, 10);
    for (let i = 0; i < 5; i++) {
      const fx = px + inset + 4 + i * ((TILE_PX - inset * 2 - 8) / 4);
      ctx.beginPath();
      ctx.moveTo(fx, py + inset);
      ctx.lineTo(fx, py + inset - 3);
      ctx.stroke();
    }
  } else if (dec.kind === "mat") {
    const c = dec.color || "#4a4038";
    ctx.fillStyle = c;
    ctx.fillRect(px + 8, py + 14, 32, 20);
    ctx.strokeStyle = shade(c, 20);
    ctx.strokeRect(px + 8, py + 14, 32, 20);
    ctx.fillStyle = "rgba(255,255,255,0.08)";
    for (let i = 0; i < 4; i++) ctx.fillRect(px + 10 + i * 7, py + 16, 4, 16);
  } else if (dec.kind === "hazard") {
    // Franja amarilla/negra de pasillo industrial
    ctx.fillStyle = "#c9a12a";
    ctx.fillRect(px + 14, py + 2, 20, TILE_PX - 4);
    ctx.fillStyle = "#1a1a16";
    for (let i = 0; i < 4; i++) {
      const yy = py + 4 + i * 11;
      ctx.beginPath();
      ctx.moveTo(px + 14, yy);
      ctx.lineTo(px + 34, yy + 8);
      ctx.lineTo(px + 34, yy + 14);
      ctx.lineTo(px + 14, yy + 6);
      ctx.closePath();
      ctx.fill();
    }
  } else if (dec.kind === "oil") {
    ctx.fillStyle = "rgba(20, 22, 18, 0.35)";
    ctx.beginPath();
    ctx.ellipse(px + 22 + (dec.variant || 0) * 2, py + 26, 14, 7, 0.2, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "rgba(60, 80, 40, 0.12)";
    ctx.beginPath();
    ctx.ellipse(px + 26, py + 24, 6, 3, -0.3, 0, Math.PI * 2);
    ctx.fill();
  } else if (dec.kind === "dust") {
    ctx.fillStyle = "rgba(140, 115, 75, 0.16)";
    ctx.beginPath();
    ctx.ellipse(px + 22 + (dec.variant || 0) * 3, py + 28, 12, 5, 0.15, 0, Math.PI * 2);
    ctx.fill();
  } else if (dec.kind === "stain") {
    ctx.fillStyle = "rgba(45, 25, 18, 0.2)";
    ctx.beginPath();
    ctx.ellipse(px + 24, py + 28, 9 + (dec.variant || 0), 5, -0.25, 0, Math.PI * 2);
    ctx.fill();
  } else if (dec.kind === "rubble") {
    ctx.fillStyle = "rgba(0,0,0,0.22)";
    ctx.fillRect(px + 10, py + 30, 22, 6);
    const tones = ["#5a5048", "#4a443c", "#6a5a50"];
    ctx.fillStyle = tones[(dec.variant || 0) % 3];
    ctx.beginPath();
    ctx.moveTo(px + 12, py + 28);
    ctx.lineTo(px + 18, py + 16);
    ctx.lineTo(px + 28, py + 22);
    ctx.lineTo(px + 32, py + 30);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "#3a342c";
    ctx.fillRect(px + 20, py + 24, 9, 6);
  }
}

function drawFurniturePiece(ctx, fType, searched, px, py, accent, searching = false) {
  const soft = searched ? 0.82 : 1;
  ctx.save();
  ctx.globalAlpha = soft;

  // Sombra elíptica común
  ctx.fillStyle = "rgba(0,0,0,0.28)";
  ctx.beginPath();
  ctx.ellipse(px + 24, py + 42, 16, 3.5, 0, 0, Math.PI * 2);
  ctx.fill();

  if (fType === "table") {
    ctx.fillStyle = "#5a3e2a";
    fillRound(ctx, px + 10, py + 32, 4, 8, 1.5);
    fillRound(ctx, px + 34, py + 32, 4, 8, 1.5);
    ctx.fillStyle = "#7a5538";
    fillRound(ctx, px + 8, py + 16, 32, 16, 4);
    strokeRound(ctx, px + 8, py + 16, 32, 16, 4, "rgba(40,24,12,0.45)", 1.1);
    ctx.fillStyle = "#a07a52";
    fillRound(ctx, px + 10, py + 18, 28, 5, 2);
    ctx.fillStyle = "#c8b090";
    ctx.beginPath();
    ctx.arc(px + 24, py + 26, 4, 0, Math.PI * 2);
    ctx.fill();
  } else if (fType === "desk") {
    ctx.fillStyle = "#3a2e26";
    fillRound(ctx, px + 8, py + 32, 4, 8, 1.5);
    fillRound(ctx, px + 36, py + 32, 4, 8, 1.5);
    ctx.fillStyle = searched ? "#3a3028" : "#4a3a30";
    fillRound(ctx, px + 5, py + 16, 38, 18, 4);
    strokeRound(ctx, px + 5, py + 16, 38, 18, 4, "rgba(20,14,10,0.4)", 1);
    ctx.fillStyle = "#7a6a58";
    fillRound(ctx, px + 7, py + 18, 34, 4, 2);
    ctx.fillStyle = searched ? "#2a2218" : "#3a3028";
    fillRound(ctx, px + 10, py + 24, 12, 8, 2);
    fillRound(ctx, px + 26, py + 24, 12, 8, 2);
    if (!searched) {
      ctx.fillStyle = "#e8e0d0";
      fillRound(ctx, px + 12, py + 12, 14, 6, 2);
      ctx.fillStyle = "#4080a0";
      fillRound(ctx, px + 30, py + 11, 7, 5, 2);
    }
    ctx.fillStyle = "#c8a868";
    fillRound(ctx, px + 14, py + 27, 5, 2, 1);
    fillRound(ctx, px + 30, py + 27, 5, 2, 1);
  } else if (fType === "chair") {
    ctx.fillStyle = "#3a2818";
    fillRound(ctx, px + 16, py + 32, 3, 8, 1.5);
    fillRound(ctx, px + 29, py + 32, 3, 8, 1.5);
    ctx.fillStyle = "#5a4030";
    fillRound(ctx, px + 15, py + 20, 18, 12, 4);
    ctx.fillStyle = accent ? shade(accent, 12) : "#7a5a48";
    fillRound(ctx, px + 15, py + 8, 18, 14, 5);
    strokeRound(ctx, px + 15, py + 8, 18, 14, 5, "rgba(30,20,12,0.4)", 1);
  } else if (fType === "sofa") {
    const cloth = accent || "#5a3a48";
    ctx.fillStyle = cloth;
    fillRound(ctx, px + 4, py + 14, 40, 24, 6);
    ctx.fillStyle = shade(cloth, -18);
    fillRound(ctx, px + 4, py + 8, 40, 10, 5);
    ctx.fillStyle = shade(cloth, 16);
    fillRound(ctx, px + 6, py + 16, 12, 14, 4);
    fillRound(ctx, px + 30, py + 16, 12, 14, 4);
    ctx.fillStyle = shade(cloth, -28);
    fillRound(ctx, px + 4, py + 14, 5, 22, 3);
    fillRound(ctx, px + 39, py + 14, 5, 22, 3);
    strokeRound(ctx, px + 4, py + 14, 40, 24, 6, "rgba(20,12,16,0.35)", 1);
  } else if (fType === "bed") {
    ctx.fillStyle = "#3a2a28";
    fillRound(ctx, px + 5, py + 8, 38, 32, 5);
    ctx.fillStyle = "#5a4038";
    fillRound(ctx, px + 5, py + 6, 38, 10, 4);
    ctx.fillStyle = "#e8e0d4";
    fillRound(ctx, px + 8, py + 12, 32, 10, 4);
    ctx.fillStyle = "#d0c8ba";
    fillRound(ctx, px + 10, py + 14, 12, 6, 3);
    const quilt = accent || "#7a3a4a";
    ctx.fillStyle = quilt;
    fillRound(ctx, px + 8, py + 24, 32, 14, 4);
    ctx.strokeStyle = shade(quilt, -22);
    ctx.lineWidth = 1.2;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(px + 24, py + 26);
    ctx.lineTo(px + 24, py + 36);
    ctx.stroke();
    strokeRound(ctx, px + 5, py + 8, 38, 32, 5, "rgba(30,18,16,0.4)", 1);
  } else if (fType === "nightstand") {
    ctx.fillStyle = searched ? "#4a3a30" : "#6a5040";
    fillRound(ctx, px + 12, py + 16, 24, 20, 4);
    ctx.fillStyle = "#8a6a48";
    fillRound(ctx, px + 12, py + 14, 24, 4, 2);
    ctx.fillStyle = searched ? "#2a2018" : "#c8a868";
    fillRound(ctx, px + 21, py + 24, 6, 3, 1.5);
    ctx.fillStyle = "#d8c898";
    fillRound(ctx, px + 22, py + 6, 4, 8, 1);
    ctx.beginPath();
    ctx.moveTo(px + 18, py + 8);
    ctx.lineTo(px + 30, py + 8);
    ctx.lineTo(px + 24, py + 2);
    ctx.closePath();
    ctx.fill();
  } else if (fType === "shelf") {
    // Rack metálico industrial
    ctx.fillStyle = "rgba(0,0,0,0.28)";
    ctx.beginPath();
    ctx.ellipse(px + 24, py + 42, 16, 3.5, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#3a4048";
    ctx.fillRect(px + 6, py + 6, 4, 36);
    ctx.fillRect(px + 38, py + 6, 4, 36);
    ctx.fillStyle = "#5a6870";
    for (let i = 0; i < 3; i++) {
      const ly = py + 10 + i * 11;
      ctx.fillRect(px + 6, ly, 36, 4);
      if (!searched) {
        const box = ["#8a5a30", "#4a6a80", "#6a5a40", "#3a5a48"];
        ctx.fillStyle = box[(i + (px | 0)) % box.length];
        ctx.fillRect(px + 10, ly - 8, 12, 8);
        ctx.fillStyle = shade(box[(i + 1 + (px | 0)) % box.length], 10);
        ctx.fillRect(px + 24, ly - 7, 14, 7);
        ctx.fillStyle = "#5a6870";
      } else {
        ctx.fillStyle = "rgba(20,22,24,0.25)";
        ctx.fillRect(px + 10, ly - 6, 28, 5);
        ctx.fillStyle = "#5a6870";
      }
    }
    ctx.fillStyle = "#c8a040";
    ctx.fillRect(px + 7, py + 7, 2, 8);
  } else if (fType === "crate") {
    // Palé + caja
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.beginPath();
    ctx.ellipse(px + 24, py + 42, 14, 3, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#5a4830";
    ctx.fillRect(px + 10, py + 34, 28, 6);
    ctx.fillStyle = "#3a2e1c";
    ctx.fillRect(px + 12, py + 35, 3, 5);
    ctx.fillRect(px + 22, py + 35, 3, 5);
    ctx.fillRect(px + 33, py + 35, 3, 5);
    ctx.fillStyle = searched ? "#6a5438" : "#9a7850";
    ctx.fillRect(px + 12, py + 12, 24, 24);
    ctx.strokeStyle = "#3a2a18";
    ctx.lineWidth = 2;
    ctx.strokeRect(px + 12, py + 12, 24, 24);
    ctx.beginPath();
    ctx.moveTo(px + 12, py + 24);
    ctx.lineTo(px + 36, py + 24);
    ctx.moveTo(px + 24, py + 12);
    ctx.lineTo(px + 24, py + 36);
    ctx.stroke();
    ctx.fillStyle = "rgba(255,255,255,0.1)";
    ctx.fillRect(px + 14, py + 14, 20, 3);
    if (!searched) {
      ctx.fillStyle = "#c8a060";
      ctx.fillRect(px + 18, py + 18, 12, 5);
    } else {
      ctx.fillStyle = "rgba(20,15,10,0.4)";
      ctx.fillRect(px + 14, py + 16, 20, 12);
    }
  } else if (fType === "cabinet") {
    ctx.fillStyle = searched ? "#5a4838" : "#6a5040";
    ctx.fillRect(px + 8, py + 4, 32, 38);
    ctx.fillStyle = searched ? "#3a3028" : "#4a3a30";
    ctx.fillRect(px + 10, py + 6, 13, 34);
    ctx.fillRect(px + 25, py + 6, 13, 34);
    if (searched) {
      ctx.fillStyle = "#7a6550";
      ctx.fillRect(px + 4, py + 8, 8, 30);
      ctx.fillRect(px + 36, py + 8, 8, 30);
    } else {
      ctx.fillStyle = "#c8a060";
      ctx.beginPath();
      ctx.arc(px + 20, py + 24, 1.8, 0, Math.PI * 2);
      ctx.arc(px + 28, py + 24, 1.8, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "rgba(255, 210, 120, 0.3)";
      ctx.fillRect(px + 12, py + 10, 8, 6);
    }
  } else if (fType === "drawer") {
    ctx.fillStyle = searched ? "#5a4a38" : "#6e5640";
    ctx.fillRect(px + 9, py + 12, 30, 28);
    ctx.strokeStyle = "#3a2a1c";
    for (let i = 0; i < 3; i++) {
      const yy = py + 14 + i * 9;
      ctx.strokeRect(px + 11, yy, 26, 8);
      ctx.fillStyle = searched ? "#2a2018" : "#c8a868";
      ctx.fillRect(px + 21, yy + 3, 6, 2);
    }
    ctx.fillStyle = "#8a9aaa";
    ctx.fillRect(px + 18, py + 4, 12, 8);
    ctx.strokeStyle = "#c8d0d8";
    ctx.strokeRect(px + 18, py + 4, 12, 8);
  } else if (fType === "fridge") {
    ctx.fillStyle = searched ? "#5a6068" : "#b0b8c0";
    ctx.fillRect(px + 10, py + 4, 28, 38);
    ctx.fillStyle = searched ? "#3a4048" : "#d0d8e0";
    ctx.fillRect(px + 12, py + 6, 24, 20);
    ctx.fillRect(px + 12, py + 28, 24, 12);
    ctx.fillStyle = "rgba(0,0,0,0.12)";
    ctx.fillRect(px + 12, py + 26, 24, 2);
    ctx.fillStyle = "#2a2e34";
    ctx.fillRect(px + 32, py + 12, 3, 10);
    ctx.fillRect(px + 32, py + 32, 3, 6);
    if (!searched) {
      ctx.fillStyle = "rgba(180, 220, 255, 0.22)";
      ctx.fillRect(px + 14, py + 8, 20, 8);
    } else {
      ctx.fillStyle = "rgba(20,20,24,0.45)";
      ctx.fillRect(px + 14, py + 8, 20, 16);
    }
    ctx.fillStyle = "rgba(255,255,255,0.2)";
    ctx.fillRect(px + 12, py + 6, 4, 18);
  } else if (fType === "locker") {
    ctx.fillStyle = "rgba(0,0,0,0.28)";
    ctx.beginPath();
    ctx.ellipse(px + 24, py + 44, 12, 3, 0, 0, Math.PI * 2);
    ctx.fill();
    const green = searched ? "#3a4a3e" : "#4a6a52";
    ctx.fillStyle = green;
    ctx.fillRect(px + 10, py + 4, 28, 40);
    ctx.fillStyle = shade(green, 18);
    ctx.fillRect(px + 12, py + 6, 11, 36);
    ctx.fillRect(px + 25, py + 6, 11, 36);
    ctx.strokeStyle = "rgba(20,24,20,0.55)";
    ctx.strokeRect(px + 10, py + 4, 28, 40);
    ctx.beginPath();
    ctx.moveTo(px + 24, py + 4);
    ctx.lineTo(px + 24, py + 44);
    ctx.stroke();
    ctx.fillStyle = searched ? "#1a2018" : "#d0b050";
    ctx.fillRect(px + 19, py + 22, 3, 6);
    ctx.fillRect(px + 26, py + 22, 3, 6);
    ctx.fillStyle = "rgba(255,255,255,0.12)";
    ctx.fillRect(px + 13, py + 8, 3, 14);
    ctx.fillRect(px + 26, py + 8, 3, 14);
    if (searched) {
      ctx.fillStyle = "rgba(10,12,10,0.35)";
      ctx.fillRect(px + 12, py + 8, 11, 20);
    }
  } else if (fType === "counter") {
    ctx.fillStyle = "#5a4a3a";
    ctx.fillRect(px + 4, py + 18, 40, 18);
    ctx.fillStyle = searched ? "#3a3028" : "#a09080";
    ctx.fillRect(px + 4, py + 14, 40, 6);
    ctx.fillStyle = "rgba(255,255,255,0.12)";
    ctx.fillRect(px + 6, py + 15, 20, 2);
    ctx.fillStyle = "#c8b090";
    ctx.fillRect(px + 8, py + 10, 10, 4);
    if (!searched) {
      ctx.fillStyle = "#a05040";
      ctx.fillRect(px + 22, py + 8, 8, 6);
      ctx.fillStyle = "#8090a0";
      ctx.fillRect(px + 34, py + 10, 8, 4);
    }
  } else if (fType === "sink") {
    ctx.fillStyle = "#5a6068";
    ctx.fillRect(px + 8, py + 14, 32, 22);
    ctx.fillStyle = "#8a98a0";
    ctx.fillRect(px + 12, py + 18, 24, 14);
    ctx.fillStyle = "#2a4050";
    ctx.beginPath();
    ctx.arc(px + 24, py + 25, 4, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#c0c8d0";
    ctx.fillRect(px + 22, py + 10, 4, 10);
    ctx.fillRect(px + 18, py + 10, 12, 3);
  } else if (fType === "stove") {
    ctx.fillStyle = "#3a3a40";
    ctx.fillRect(px + 8, py + 12, 32, 28);
    ctx.fillStyle = "#2a2a30";
    ctx.fillRect(px + 10, py + 14, 12, 12);
    ctx.fillRect(px + 26, py + 14, 12, 12);
    ctx.strokeStyle = "#6a6a70";
    ctx.beginPath();
    ctx.arc(px + 16, py + 20, 4, 0, Math.PI * 2);
    ctx.arc(px + 32, py + 20, 4, 0, Math.PI * 2);
    ctx.stroke();
    ctx.fillStyle = "#8a9098";
    ctx.fillRect(px + 12, py + 30, 8, 3);
    ctx.fillRect(px + 28, py + 30, 8, 3);
  } else if (fType === "plant") {
    ctx.fillStyle = "#6a4a32";
    ctx.fillRect(px + 16, py + 28, 16, 12);
    ctx.fillStyle = "#3a2818";
    ctx.fillRect(px + 18, py + 26, 12, 4);
    ctx.fillStyle = "#3a6a3a";
    ctx.beginPath();
    ctx.arc(px + 18, py + 22, 7, 0, Math.PI * 2);
    ctx.arc(px + 30, py + 20, 8, 0, Math.PI * 2);
    ctx.arc(px + 24, py + 14, 7, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#c05060";
    ctx.beginPath();
    ctx.arc(px + 28, py + 16, 2, 0, Math.PI * 2);
    ctx.fill();
  } else {
    ctx.fillStyle = searched ? "#3a342e" : "#5a4a40";
    ctx.fillRect(px + 10, py + 12, 28, 28);
  }

  ctx.restore();

  if (searching) {
    ctx.strokeStyle = "#d4a85a";
    ctx.lineWidth = 2;
    ctx.strokeRect(px + 4, py + 4, 40, 40);
  } else if (searched) {
    ctx.fillStyle = "rgba(18,16,12,0.18)";
    ctx.fillRect(px + 6, py + 8, 36, 32);
  }
}

function phaseNameSafe(game) {
  try {
    return dayPhase(game).name;
  } catch {
    return "Día";
  }
}

function phaseIsDayish(name) {
  return name === "Día" || name === "Amanecer";
}

function indoorPlaster(style) {
  if (style === "warehouse") return "#8a8882";
  if (style === "tower") return "#9aa4b0";
  if (style === "shop") return "#a89888";
  return "#e2d2bc";
}

function drawIndoorWallTile(ctx, px, py, b, tx, ty) {
  const style = b?.style || "block";
  let plaster = indoorPlaster(style);
  if (((tx + ty) & 1) === 0) plaster = shade(plaster, style === "residential" || style === "block" ? 6 : -4);
  ctx.fillStyle = plaster;
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);

  // Zócalo
  ctx.fillStyle = style === "tower" ? "#3a424c" : style === "warehouse" ? "#3a3834" : "#5a4030";
  ctx.fillRect(px, py + TILE_PX - 7, TILE_PX, 7);
  ctx.fillStyle = "rgba(255,255,255,0.08)";
  ctx.fillRect(px, py + TILE_PX - 7, TILE_PX, 2);

  if (style === "warehouse") {
    // Bloque de hormigón bien marcado
    const mortar = "rgba(36,34,30,0.55)";
    ctx.strokeStyle = mortar;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(px, py + TILE_PX / 2);
    ctx.lineTo(px + TILE_PX, py + TILE_PX / 2);
    ctx.stroke();
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(px + TILE_PX / 2, py);
    ctx.lineTo(px + TILE_PX / 2, py + TILE_PX / 2);
    ctx.stroke();
    // Sombra de bloque
    ctx.fillStyle = "rgba(0,0,0,0.08)";
    ctx.fillRect(px + 1, py + 1, TILE_PX / 2 - 2, TILE_PX / 2 - 2);
    ctx.fillStyle = "rgba(255,255,255,0.06)";
    ctx.fillRect(px + TILE_PX / 2 + 2, py + TILE_PX / 2 + 2, TILE_PX / 2 - 4, TILE_PX / 2 - 10);
    // Remaches
    ctx.fillStyle = "rgba(55,52,48,0.7)";
    for (const [rx, ry] of [[5,5],[TILE_PX-8,5],[5,TILE_PX/2+3],[TILE_PX-8,TILE_PX/2+3]]) {
      ctx.fillRect(px + rx, py + ry, 3, 3);
    }
    // Canaleta / tubo
    if (((tx * 5 + ty) % 4) === 0) {
      ctx.fillStyle = "#5a6068";
      ctx.fillRect(px + 14, py + 2, 20, 9);
      ctx.fillStyle = "#2a2e32";
      ctx.fillRect(px + 16, py + 4, 16, 5);
      ctx.fillStyle = "rgba(255,255,255,0.12)";
      ctx.fillRect(px + 16, py + 4, 16, 2);
    }
  } else if (style === "tower") {
    ctx.fillStyle = "rgba(255,255,255,0.06)";
    ctx.fillRect(px + 3, py + 6, TILE_PX - 6, 4);
    ctx.fillStyle = "rgba(0,0,0,0.1)";
    ctx.fillRect(px + 3, py + 22, TILE_PX - 6, 2);
  } else if (style === "shop") {
    ctx.fillStyle = b?.accent ? shade(b.accent, -20) : "#6a3a2a";
    ctx.globalAlpha = 0.3;
    ctx.fillRect(px, py + 10, TILE_PX, 10);
    ctx.globalAlpha = 1;
  } else {
    ctx.strokeStyle = "rgba(90,70,50,0.16)";
    ctx.strokeRect(px + 5, py + 5, TILE_PX - 10, TILE_PX - 16);
    if (((tx * 7 + ty * 3) % 5) === 0) {
      ctx.fillStyle = "rgba(120, 90, 70, 0.1)";
      ctx.fillRect(px + 8, py + 8, TILE_PX - 16, TILE_PX - 22);
    }
  }
}

function drawEnteredInteriorShell(ctx, b, px, py, bw, bh, t, phase, litWindows) {
  const style = b.style || "block";
  const plaster = indoorPlaster(style);
  const base = style === "tower" ? "#3a424c" : style === "warehouse" ? "#3a3834" : "#5a4030";

  // Perímetro tile a tile (bloque/chapa en almacén, yeso en casas)
  for (let x = b.x0; x <= b.x1; x++) {
    drawIndoorWallTile(ctx, px + (x - b.x0) * t, py, b, x, b.y0);
    drawIndoorWallTile(ctx, px + (x - b.x0) * t, py + bh - t, b, x, b.y1);
  }
  for (let y = b.y0 + 1; y < b.y1; y++) {
    drawIndoorWallTile(ctx, px, py + (y - b.y0) * t, b, b.x0, y);
    drawIndoorWallTile(ctx, px + bw - t, py + (y - b.y0) * t, b, b.x1, y);
  }

  // Zócalo interior (borde hacia la habitación)
  ctx.fillStyle = base;
  ctx.fillRect(px + t, py + t - 6, bw - t * 2, 6);
  ctx.fillRect(px + t, py + bh - t, bw - t * 2, 6);
  ctx.fillRect(px + t - 6, py + t, 6, bh - t * 2);
  ctx.fillRect(px + bw - t, py + t, 6, bh - t * 2);
  ctx.fillStyle = "rgba(255,255,255,0.08)";
  ctx.fillRect(px + t, py + t - 6, bw - t * 2, 2);

  // Detalles de pared (ventanas / carteles) sobre el perímetro
  const wallRoll = (x, y, salt) => ((x * 17 + y * 31 + b.x0 * 5 + salt) >>> 0) % 12;
  for (let x = b.x0 + 1; x < b.x1; x++) {
    const wx = px + (x - b.x0) * t + 12;
    for (const [wy, salt] of [[py + 10, 1], [py + bh - t + 10, 4]]) {
      drawInteriorWallFace(ctx, wx, wy, b, wallRoll(x, b.y0 + salt, salt), x + salt, litWindows);
    }
  }
  for (let y = b.y0 + 1; y < b.y1; y++) {
    for (const [ox, salt] of [[12, 2], [bw - t + 12, 7]]) {
      const wy = py + (y - b.y0) * t + 10;
      drawInteriorWallFace(ctx, px + ox, wy, b, wallRoll(b.x0 + salt, y, salt), y + salt, litWindows);
    }
  }

  const roomX = px + t;
  const roomY = py + t;
  const roomW = bw - t * 2;
  const roomH = bh - t * 2;
  if (roomW > 0 && roomH > 0) {
    // Lavado suave (industrial = frio; casa = cálido)
    if (style === "warehouse") {
      ctx.fillStyle = phase.night ? "rgba(180, 200, 210, 0.04)" : "rgba(200, 210, 220, 0.05)";
      ctx.fillRect(roomX, roomY, roomW, roomH);
    } else if (phase.night) {
      ctx.fillStyle = "rgba(255, 200, 130, 0.05)";
      ctx.fillRect(roomX, roomY, roomW, roomH);
    } else {
      ctx.fillStyle = "rgba(255, 240, 210, 0.06)";
      ctx.fillRect(roomX, roomY, roomW, roomH);
    }
    const vg = ctx.createRadialGradient(
      roomX + roomW * 0.5, roomY + roomH * 0.5, Math.min(roomW, roomH) * 0.28,
      roomX + roomW * 0.5, roomY + roomH * 0.5, Math.max(roomW, roomH) * 0.72
    );
    vg.addColorStop(0, "rgba(0,0,0,0)");
    vg.addColorStop(1, phase.night ? "rgba(10,8,6,0.14)" : "rgba(30,24,18,0.06)");
    ctx.fillStyle = vg;
    ctx.fillRect(roomX, roomY, roomW, roomH);

    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    for (const win of litWindows) {
      if (win.x < roomX - 20 || win.x > roomX + roomW + 20) continue;
      if (win.y < roomY - 40 || win.y > roomY + roomH + 40) continue;
      const beam = ctx.createRadialGradient(win.x, win.y, 2, win.x, win.y + 28, 64);
      beam.addColorStop(0, phase.night ? "rgba(255, 200, 120, 0.18)" : "rgba(255, 240, 200, 0.1)");
      beam.addColorStop(1, "rgba(255, 200, 120, 0)");
      ctx.fillStyle = beam;
      ctx.beginPath();
      ctx.arc(win.x, win.y + 18, 64, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  // Puerta interior (marco de madera, no fachada)
  const doorPx = px + (b.doorX - b.x0) * t;
  const doorPy = py + (b.doorY - b.y0) * t;
  ctx.fillStyle = plaster;
  ctx.fillRect(doorPx, doorPy, t, t);
  ctx.fillStyle = "#5a4030";
  ctx.fillRect(doorPx + 6, doorPy + 2, 36, t - 4);
  ctx.fillStyle = "#1a1410";
  ctx.fillRect(doorPx + 10, doorPy + 4, 28, t - 6);
  ctx.fillStyle = "#b8925a";
  ctx.fillRect(doorPx + 14, doorPy + 8, 20, t - 14);
  ctx.fillStyle = "#e0c080";
  ctx.beginPath();
  ctx.arc(doorPx + 28, doorPy + t / 2, 2.5, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#3a3028";
  ctx.fillRect(doorPx + 8, doorPy + t - 6, 32, 5);

  ctx.fillStyle = "rgba(255,255,255,0.55)";
  ctx.font = `600 11px ${FONT_UI}`;
  ctx.textAlign = "left";
  ctx.fillText(b.name, px + t + 6, py + t - 8);
}

function drawBuildingRoof(ctx, b, camX, camY, phase, entered, litWindows = []) {
  const px = b.x0 * TILE_PX - camX;
  const py = b.y0 * TILE_PX - camY;
  const bw = (b.x1 - b.x0 + 1) * TILE_PX;
  const bh = (b.y1 - b.y0 + 1) * TILE_PX;
  const t = TILE_PX;
  const style = b.style || "block";
  const floors = b.floors || 2;

  if (entered) {
    drawEnteredInteriorShell(ctx, b, px, py, bw, bh, t, phase, litWindows);
    return;
  }

  const shadow = 6 + floors * 2;

  // Sombra de volumen
  ctx.fillStyle = "rgba(0,0,0,0.35)";
  ctx.fillRect(px + shadow, py + shadow, bw, bh);

  // Fachada perimetral con bandas de pisos
  const wall = shade(b.facade, style === "warehouse" ? -22 : -12);
  ctx.fillStyle = wall;
  ctx.fillRect(px, py, bw, t);
  ctx.fillRect(px, py + bh - t, bw, t);
  ctx.fillRect(px, py, t, bh);
  ctx.fillRect(px + bw - t, py, t, bh);

  // Bandas horizontales (pisos)
  ctx.strokeStyle = "rgba(0,0,0,0.2)";
  ctx.lineWidth = 1;
  const bands = Math.min(floors, 4);
  for (let i = 1; i < bands; i++) {
    const yy = py + (t / bands) * i;
    ctx.beginPath();
    ctx.moveTo(px, yy);
    ctx.lineTo(px + bw, yy);
    ctx.moveTo(px, py + bh - t + (t / bands) * i);
    ctx.lineTo(px + bw, py + bh - t + (t / bands) * i);
    ctx.stroke();
  }

  if (style === "warehouse") {
    ctx.strokeStyle = "rgba(0,0,0,0.25)";
    ctx.lineWidth = 2;
    for (let i = 0; i < 3; i++) {
      ctx.strokeRect(px + 6 + i * 4, py + 8, t - 14, t - 16);
      ctx.strokeRect(px + 6 + i * 4, py + bh - t + 8, t - 14, t - 16);
    }
  } else if (style === "shop") {
    // Solo ~1 de cada 4 comercios queda encendido de noche
    const shopLit = (phase.night || phase.light < 0.55) && ((b.x0 + b.y0 * 3) % 4 === 0);
    ctx.fillStyle = shopLit ? "rgba(255, 200, 110, 0.28)" : "rgba(35, 55, 75, 0.6)";
    ctx.fillRect(px + t + 4, py + bh - t + 14, bw - t * 2 - 8, t - 20);
    ctx.strokeStyle = shopLit ? "rgba(255, 220, 150, 0.35)" : "rgba(200,210,220,0.35)";
    ctx.strokeRect(px + t + 4, py + bh - t + 14, bw - t * 2 - 8, t - 20);
    if (bw > 70) {
      const neon = b.awning || "#8a3030";
      ctx.fillStyle = shopLit ? neon : shade(neon, -40);
      ctx.fillRect(px + t + 8, py + bh - t + 2, Math.min(120, bw - t * 2 - 16), 13);
      if (shopLit) {
        litWindows.push({ x: px + t + 40, y: py + bh - t + 8 });
        ctx.fillStyle = "rgba(255, 180, 120, 0.12)";
        ctx.fillRect(px + t + 6, py + bh - t, Math.min(124, bw - t * 2 - 12), 16);
      }
      ctx.fillStyle = shopLit ? "#f8f0e0" : "#a09888";
      ctx.font = `700 10px ${FONT_UI}`;
      ctx.textAlign = "left";
      ctx.fillText(b.name.split(" ")[0].toUpperCase(), px + t + 12, py + bh - t + 12);
    }
  }

  // Cornisa
  ctx.fillStyle = shade(b.facade, 28);
  ctx.fillRect(px - 2, py - 4, bw + 4, 5);
  ctx.fillRect(px - 2, py + bh - 2, bw + 4, 4);
  if (style === "tower") {
    ctx.fillStyle = shade(b.facade, -28);
    for (let i = 0; i < 4; i++) {
      ctx.fillRect(px + 10 + i * ((bw - 30) / 3), py - 14, 12, 12);
    }
    // Antena
    ctx.strokeStyle = "#8a9098";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(px + bw * 0.5, py - 14);
    ctx.lineTo(px + bw * 0.5, py - 28);
    ctx.stroke();
  }

  // Algunas ventanas; el resto muro vacío o un detalle suelto (no llenar la pared)
  const pushWin = (wx, wy, lit) => {
    drawWindow(ctx, wx, wy, lit, style);
    if (lit) litWindows.push({ x: wx + 7, y: wy + 8 });
  };
  // 0–1 ventana (~17%), 2 tapiada (~8%), 3–4 detalle (~17%), 5–11 muro limpio (~58%)
  const wallRoll = (x, y, salt) => ((x * 17 + y * 31 + b.x0 * 5 + salt) >>> 0) % 12;

  for (let x = b.x0 + 1; x < b.x1; x++) {
    const wx = x * TILE_PX - camX + 12;
    for (const [wy, salt] of [[py + 10, 1], [py + bh - t + 10, 4]]) {
      const roll = wallRoll(x, b.y0 + salt, salt);
      if (entered) {
        drawInteriorWallFace(ctx, wx, wy, b, roll, x + salt);
        continue;
      }
      if (roll <= 1) {
        const lit = phase.night && ((x + b.y0 + salt) % 7) === 0;
        if (style === "residential") {
          ctx.fillStyle = shade(b.facade, -32);
          ctx.fillRect(wx - 2, wy + 14, 18, 4);
        }
        pushWin(wx, wy, lit);
      } else if (roll === 2) {
        drawBoardedWindow(ctx, wx, wy, style);
      } else if (roll <= 4) {
        drawBareWallDetail(ctx, wx, wy, b, roll, x, salt);
      }
      // roll 5–11: muro vacío
    }
  }
  for (let y = b.y0 + 1; y < b.y1; y++) {
    for (const [wx, salt] of [[px + 12, 2], [px + bw - t + 12, 7]]) {
      const wy = y * TILE_PX - camY + 10;
      const roll = wallRoll(b.x0 + salt, y, salt);
      if (entered) {
        drawInteriorWallFace(ctx, wx, wy, b, roll, y + salt);
        continue;
      }
      if (roll <= 1) {
        const lit = phase.night && ((y + b.x0) % 7) === 0;
        pushWin(wx, wy, lit);
      } else if (roll === 2) {
        drawBoardedWindow(ctx, wx, wy, style);
      } else if (roll <= 4) {
        drawBareWallDetail(ctx, wx, wy, b, roll, y, salt);
      }
    }
  }

  if (!entered) {
    const roofX = px + t;
    const roofY = py + t;
    const roofW = bw - t * 2;
    const roofH = bh - t * 2;
    if (roofW > 0 && roofH > 0) {
      // Tejado con pendiente visual
      const roof = ctx.createLinearGradient(roofX, roofY, roofX + roofW, roofY + roofH);
      if (style === "warehouse") {
        roof.addColorStop(0, "#5a6066");
        roof.addColorStop(1, "#2e343a");
      } else if (style === "tower") {
        roof.addColorStop(0, shade(b.facade, 10));
        roof.addColorStop(1, shade(b.facade, -45));
      } else {
        roof.addColorStop(0, shade(b.facade, 18));
        roof.addColorStop(0.5, shade(b.facade, -10));
        roof.addColorStop(1, shade(b.facade, -38));
      }
      ctx.fillStyle = roof;
      ctx.fillRect(roofX, roofY, roofW, roofH);

      // Claros / lucernarios
      ctx.strokeStyle = "rgba(0,0,0,0.22)";
      for (let i = 1; i < 5; i++) {
        ctx.beginPath();
        ctx.moveTo(roofX, roofY + (roofH / 5) * i);
        ctx.lineTo(roofX + roofW, roofY + (roofH / 5) * i);
        ctx.stroke();
      }

      // Pocos lucernarios (no una rejilla de “ventanas” en el techo)
      const cols = Math.max(1, b.x1 - b.x0 - 2);
      const rows = Math.max(1, b.y1 - b.y0 - 2);
      for (let row = 0; row < rows; row++) {
        for (let col = 0; col < cols; col++) {
          if ((col * 5 + row * 7 + b.x0 + b.y0) % 5 !== 0) continue;
          const wx = roofX + 10 + col * ((roofW - 16) / cols);
          const wy = roofY + 10 + row * ((roofH - 16) / rows);
          const ww = Math.max(5, Math.min(14, (roofW - 16) / cols - 14));
          const wh = Math.max(5, Math.min(12, (roofH - 16) / rows - 14));
          const lit = phase.night && (col + row * 3 + b.x0) % 9 === 0;
          ctx.fillStyle = lit ? "rgba(255, 215, 130, 0.4)" : "rgba(14, 20, 28, 0.55)";
          ctx.fillRect(wx, wy, ww, wh);
          if (lit && (col + row) % 5 === 0) litWindows.push({ x: wx + ww / 2, y: wy + wh / 2 });
        }
      }

      // Equipos de azotea
      ctx.fillStyle = "#6a6e74";
      ctx.fillRect(roofX + roofW * 0.62, roofY + roofH * 0.18, 20, 14);
      ctx.fillStyle = "#3a3e44";
      ctx.fillRect(roofX + roofW * 0.66, roofY + roofH * 0.1, 3, 14);
      ctx.fillStyle = "#7a8088";
      ctx.beginPath();
      ctx.arc(roofX + roofW * 0.28, roofY + roofH * 0.3, 7, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#2a2e34";
      ctx.stroke();

      if (style === "tower") {
        ctx.fillStyle = shade(b.facade, -8);
        ctx.fillRect(roofX + roofW * 0.38, roofY + roofH * 0.32, roofW * 0.24, roofH * 0.28);
      }

      // Letrero
      if (roofW > 70) {
        ctx.fillStyle = "rgba(0,0,0,0.6)";
        ctx.fillRect(roofX + 6, roofY + 6, Math.min(150, roofW - 12), 20);
        ctx.fillStyle = phase.night ? "#ffe8b0" : "#f0e8d8";
        ctx.font = `600 12px ${FONT_UI}`;
        ctx.textAlign = "left";
        ctx.fillText(b.name, roofX + 10, roofY + 20);
      }
    }
  } else {
    // Interior: penumbra cálida + rayos de ventana
    const roomX = px + t;
    const roomY = py + t;
    const roomW = bw - t * 2;
    const roomH = bh - t * 2;
    if (roomW > 0 && roomH > 0) {
      ctx.fillStyle = phase.night ? "rgba(22, 16, 12, 0.34)" : "rgba(36, 28, 20, 0.16)";
      ctx.fillRect(roomX, roomY, roomW, roomH);
      if (phase.night) {
        ctx.fillStyle = "rgba(255, 200, 120, 0.06)";
        ctx.fillRect(roomX, roomY, roomW, roomH);
      } else {
        ctx.fillStyle = "rgba(255, 230, 170, 0.07)";
        ctx.fillRect(roomX, roomY, roomW, roomH);
      }
      // Rayos desde ventanas de fachada hacia el interior
      ctx.save();
      ctx.globalCompositeOperation = "lighter";
      for (const win of litWindows) {
        if (win.x < roomX - 20 || win.x > roomX + roomW + 20) continue;
        if (win.y < roomY - 40 || win.y > roomY + roomH + 40) continue;
        const beam = ctx.createRadialGradient(win.x, win.y, 2, win.x, win.y + 30, 70);
        beam.addColorStop(0, phase.night ? "rgba(255, 200, 120, 0.2)" : "rgba(255, 240, 200, 0.12)");
        beam.addColorStop(1, "rgba(255, 200, 120, 0)");
        ctx.fillStyle = beam;
        ctx.beginPath();
        ctx.arc(win.x, win.y + 20, 70, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    }
    ctx.fillStyle = "rgba(255,255,255,0.6)";
    ctx.font = `600 11px ${FONT_UI}`;
    ctx.textAlign = "left";
    ctx.fillText(b.name, px + t + 6, py + t - 8);
  }

  // Puerta
  const doorPx = b.doorX * TILE_PX - camX;
  const doorPy = b.doorY * TILE_PX - camY;
  ctx.fillStyle = shade(b.facade, -40);
  ctx.fillRect(doorPx, doorPy, TILE_PX, TILE_PX);
  // Marco
  ctx.fillStyle = shade(b.facade, 15);
  ctx.fillRect(doorPx + 6, doorPy + 2, 36, TILE_PX - 4);
  ctx.fillStyle = "#1a1410";
  ctx.fillRect(doorPx + 10, doorPy + 4, 28, TILE_PX - 6);
  ctx.fillStyle = style === "shop" ? "#c8a060" : "#b8925a";
  ctx.fillRect(doorPx + 14, doorPy + 8, 20, TILE_PX - 14);
  if (style === "shop" && phase.night && ((b.x0 + b.y0 * 3) % 4 === 0)) {
    ctx.fillStyle = "rgba(255,220,140,0.35)";
    ctx.fillRect(doorPx + 16, doorPy + 12, 16, 12);
  }
  ctx.fillStyle = "#e0c080";
  ctx.beginPath();
  ctx.arc(doorPx + 28, doorPy + TILE_PX / 2, 2.5, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#3a3028";
  ctx.fillRect(doorPx + 8, doorPy + TILE_PX - 6, 32, 5);
  // Número / placa
  ctx.fillStyle = "rgba(230,220,200,0.7)";
  ctx.font = `600 8px ${FONT_UI}`;
  ctx.textAlign = "center";
  ctx.fillText(String((b.x0 + b.y0) % 90 + 10), doorPx + TILE_PX / 2, doorPy + 7);
}



function drawInteriorWallFace(ctx, x, y, b, roll, seed, litWindows = null) {
  const style = b?.style || "block";
  const industrial = style === "warehouse";
  if (roll <= 2) {
    // Ventana: marco metálico en almacén, madera en casas
    ctx.fillStyle = industrial ? "#1a1e22" : "#2a241c";
    ctx.fillRect(x, y + 1, 16, 18);
    ctx.fillStyle = industrial ? "rgba(120, 150, 160, 0.4)" : "rgba(150, 190, 215, 0.45)";
    ctx.fillRect(x + 2, y + 3, 12, 14);
    ctx.strokeStyle = industrial ? "#6a7278" : "#5a4030";
    ctx.lineWidth = 2;
    ctx.strokeRect(x + 2, y + 3, 12, 14);
    ctx.beginPath();
    ctx.moveTo(x + 8, y + 3);
    ctx.lineTo(x + 8, y + 17);
    ctx.moveTo(x + 2, y + 10);
    ctx.lineTo(x + 14, y + 10);
    ctx.stroke();
    ctx.fillStyle = industrial ? "rgba(40,50,55,0.45)" : (style === "tower" ? "rgba(60,80,100,0.35)" : "rgba(120,70,50,0.4)");
    ctx.fillRect(x + 3, y + 4, 4, 12);
    if (litWindows) litWindows.push({ x: x + 8, y: y + 10 });
    ctx.fillStyle = industrial ? "rgba(200, 220, 230, 0.06)" : "rgba(255, 235, 190, 0.07)";
    ctx.beginPath();
    ctx.moveTo(x + 8, y + 17);
    ctx.lineTo(x - 6, y + 34);
    ctx.lineTo(x + 22, y + 34);
    ctx.closePath();
    ctx.fill();
    return;
  }
  if (roll === 3 || roll === 4) {
    if (industrial) {
      // Cartel de seguridad
      ctx.fillStyle = "#1a1814";
      ctx.fillRect(x + 1, y + 2, 14, 16);
      ctx.fillStyle = seed % 2 ? "#c8a020" : "#c04030";
      ctx.fillRect(x + 2, y + 3, 12, 14);
      ctx.fillStyle = "#1a1814";
      ctx.beginPath();
      ctx.moveTo(x + 8, y + 5);
      ctx.lineTo(x + 12, y + 13);
      ctx.lineTo(x + 4, y + 13);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = "#c8a020";
      ctx.fillRect(x + 7, y + 7, 2, 4);
      ctx.fillRect(x + 7, y + 12, 2, 1);
      return;
    }
    ctx.fillStyle = "#1a1510";
    ctx.fillRect(x + 1, y + 2, 14, 16);
    ctx.fillStyle = seed % 2 ? "#e0d2b4" : "#c8b898";
    ctx.fillRect(x + 2, y + 3, 12, 14);
    const palette = ["#7a4040", "#406080", "#4a6840", "#5a4070", "#8a6030"];
    ctx.fillStyle = palette[seed % palette.length];
    ctx.fillRect(x + 4, y + 5, 8, 10);
    ctx.fillStyle = "rgba(255,255,255,0.18)";
    ctx.fillRect(x + 5, y + 6, 3, 3);
    return;
  }
  if (roll === 5) {
    if (industrial) {
      // Extintor / válvula
      ctx.fillStyle = "#a02828";
      ctx.fillRect(x + 6, y + 6, 5, 12);
      ctx.fillStyle = "#2a2a28";
      ctx.fillRect(x + 5, y + 5, 7, 2);
      ctx.strokeStyle = "#8a9098";
      ctx.beginPath();
      ctx.arc(x + 8, y + 4, 2, 0, Math.PI * 2);
      ctx.stroke();
      return;
    }
    ctx.fillStyle = "rgba(0,0,0,0.12)";
    ctx.fillRect(x + 2, y + 5, 12, 2);
    ctx.fillStyle = "#d8d0c0";
    ctx.fillRect(x + 6, y + 12, 4, 6);
    ctx.fillStyle = "#6a5a40";
    ctx.fillRect(x + 7, y + 13, 2, 3);
    return;
  }
  if (roll === 6) {
    ctx.fillStyle = industrial ? "rgba(40, 55, 50, 0.18)" : "rgba(40, 65, 45, 0.14)";
    ctx.beginPath();
    ctx.ellipse(x + 8, y + 14, 6, 5, 0, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawBoardedWindow(ctx, x, y, style = "block") {
  const w = style === "warehouse" ? 18 : 14;
  const h = style === "warehouse" ? 12 : 16;
  ctx.fillStyle = "rgba(20, 18, 16, 0.75)";
  ctx.fillRect(x, y, w, h);
  ctx.fillStyle = "#5a4634";
  ctx.fillRect(x + 1, y + 1, w - 2, h - 2);
  ctx.strokeStyle = "rgba(30, 22, 14, 0.7)";
  ctx.beginPath();
  ctx.moveTo(x + 2, y + 2);
  ctx.lineTo(x + w - 2, y + h - 2);
  ctx.moveTo(x + w - 2, y + 2);
  ctx.lineTo(x + 2, y + h - 2);
  ctx.moveTo(x + w / 2, y + 1);
  ctx.lineTo(x + w / 2, y + h - 1);
  ctx.stroke();
  ctx.fillStyle = "rgba(0,0,0,0.25)";
  ctx.fillRect(x + 3, y + h - 4, w - 6, 2);
}

function drawBareWallDetail(ctx, x, y, b, roll, seed, salt) {
  // Detalle exterior suelto (solo se llama en pocos tiles)
  const kind = (seed + salt + roll) % 3;
  if (kind === 0) {
    ctx.strokeStyle = "rgba(10, 8, 6, 0.4)";
    ctx.beginPath();
    ctx.moveTo(x + 4, y + 3);
    ctx.lineTo(x + 7, y + 10);
    ctx.lineTo(x + 5, y + 16);
    ctx.stroke();
  } else if (kind === 1) {
    ctx.strokeStyle = "#2a5a28";
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.moveTo(x + 3, y + 16);
    ctx.quadraticCurveTo(x + 7, y + 8, x + 4, y + 2);
    ctx.stroke();
    ctx.fillStyle = "rgba(50, 110, 40, 0.55)";
    ctx.beginPath();
    ctx.ellipse(x + 6, y + 7, 2.5, 1.6, 0.3, 0, Math.PI * 2);
    ctx.ellipse(x + 9, y + 11, 2.8, 1.6, -0.2, 0, Math.PI * 2);
    ctx.fill();
  } else {
    ctx.fillStyle = "rgba(200, 70, 160, 0.55)";
    ctx.font = `800 8px ${FONT_UI}`;
    ctx.fillText(["XX", "SUR", "NO"][(seed + salt) % 3], x + 2, y + 12);
  }
}

function drawWindow(ctx, x, y, lit, style = "block") {
  const w = style === "warehouse" ? 18 : 14;
  const h = style === "warehouse" ? 12 : 16;
  if (lit) {
    ctx.fillStyle = "rgba(255, 220, 140, 0.22)";
    ctx.beginPath();
    ctx.arc(x + w / 2, y + h / 2, 14, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.fillStyle = lit ? "rgba(255, 220, 140, 0.95)" : "rgba(28, 26, 24, 0.92)";
  ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = lit ? "rgba(255, 200, 120, 0.55)" : "rgba(0,0,0,0.4)";
  ctx.strokeRect(x, y, w, h);
  if (style !== "warehouse") {
    ctx.beginPath();
    ctx.moveTo(x + w / 2, y);
    ctx.lineTo(x + w / 2, y + h);
    ctx.moveTo(x, y + h / 2);
    ctx.lineTo(x + w, y + h / 2);
    ctx.stroke();
  }
}

function shade(hex, delta) {
  const n = parseInt(hex.slice(1), 16);
  let r = (n >> 16) & 255;
  let g = (n >> 8) & 255;
  let b = n & 255;
  r = Math.max(0, Math.min(255, r + delta));
  g = Math.max(0, Math.min(255, g + delta));
  b = Math.max(0, Math.min(255, b + delta));
  return `rgb(${r},${g},${b})`;
}

function drawProp(ctx, p, px, py, phase) {
  if (p.type === "car") {
    // Coches eliminados del escenario apocalíptico
    return;
  } else if (p.type === "debris") {
    ctx.fillStyle = "rgba(0,0,0,0.3)";
    ctx.beginPath();
    ctx.ellipse(px, py + 6, 14, 6, 0, 0, Math.PI * 2);
    ctx.fill();
    const tones = ["#4a4038", "#3a322c", "#5a4a40"];
    ctx.fillStyle = tones[p.tone % 3] || tones[0];
    ctx.beginPath();
    ctx.moveTo(px - 12, py + 4);
    ctx.lineTo(px - 4, py - 6);
    ctx.lineTo(px + 8, py - 2);
    ctx.lineTo(px + 12, py + 6);
    ctx.lineTo(px - 8, py + 8);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "rgba(90,70,50,0.7)";
    ctx.fillRect(px - 6, py - 2, 9, 5);
    ctx.strokeStyle = "rgba(180,160,120,0.25)";
    ctx.strokeRect(px - 6, py - 2, 9, 5);
  } else if (p.type === "barricadeJunk") {
    ctx.fillStyle = "rgba(0,0,0,0.28)";
    ctx.fillRect(px - 14, py + 2, 28, 8);
    ctx.fillStyle = "#5a3a22";
    ctx.fillRect(px - 12, py - 6, 24, 10);
    ctx.fillStyle = "#3a3a38";
    ctx.fillRect(px - 10, py - 10, 8, 6);
    ctx.fillRect(px + 2, py - 8, 10, 5);
    ctx.strokeStyle = "rgba(200,180,120,0.2)";
    ctx.strokeRect(px - 12, py - 6, 24, 10);
  } else if (p.type === "tree") {
    const r = p.r || 12;
    ctx.fillStyle = "rgba(0,0,0,0.28)";
    ctx.beginPath();
    ctx.ellipse(px, py + 10, r * 0.75, r * 0.35, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#5a3a20";
    fillRound(ctx, px - 3, py + 2, 6, 14, 2);
    if (p.tone === 2) {
      // Árbol muerto / quemado
      ctx.strokeStyle = "#3a3228";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(px, py + 2);
      ctx.lineTo(px - 8, py - 10);
      ctx.moveTo(px, py);
      ctx.lineTo(px + 9, py - 12);
      ctx.moveTo(px, py - 4);
      ctx.lineTo(px - 3, py - 16);
      ctx.stroke();
      ctx.fillStyle = "#2a241c";
      ctx.beginPath();
      ctx.arc(px, py - 2, r * 0.28, 0, Math.PI * 2);
      ctx.fill();
    } else {
      ctx.fillStyle = p.tone ? "#2a4a24" : "#243a20";
      ctx.beginPath();
      ctx.arc(px, py - 2, r, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = p.tone ? "#3a5a30" : "#325028";
      ctx.beginPath();
      ctx.arc(px - 5, py - 5, r * 0.55, 0, Math.PI * 2);
      ctx.arc(px + 6, py - 2, r * 0.45, 0, Math.PI * 2);
      ctx.fill();
    }
  } else if (p.type === "indoorLamp") {
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.beginPath();
    ctx.ellipse(px, py + 10, 8, 3, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#3a342c";
    ctx.fillRect(px - 5, py + 2, 10, 8);
    ctx.fillStyle = "#5a4a38";
    ctx.fillRect(px - 7, py - 2, 14, 5);
    ctx.fillStyle = "#2a241c";
    ctx.fillRect(px - 1, py - 14, 2, 12);
    ctx.fillStyle = p.lit ? "#f0d080" : "#6a5a40";
    ctx.beginPath();
    ctx.arc(px, py - 16, 5, 0, Math.PI * 2);
    ctx.fill();
    if (p.lit) {
      ctx.fillStyle = "rgba(255, 200, 100, 0.35)";
      ctx.beginPath();
      ctx.arc(px, py - 16, 9, 0, Math.PI * 2);
      ctx.fill();
    }
  } else if (p.type === "candle") {
    ctx.fillStyle = "rgba(0,0,0,0.2)";
    ctx.beginPath();
    ctx.ellipse(px, py + 8, 6, 2.5, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#5a4030";
    ctx.fillRect(px - 5, py + 2, 10, 5);
    ctx.fillStyle = "#e8e0d0";
    ctx.fillRect(px - 2, py - 8, 4, 10);
    if (p.lit) {
      const flick = 0.7 + Math.sin((phase?.wind || 0) * 10 + px * 0.2) * 0.3;
      ctx.fillStyle = `rgba(255, 160, 60, ${0.55 + flick * 0.25})`;
      ctx.beginPath();
      ctx.moveTo(px, py - 18);
      ctx.quadraticCurveTo(px + 4, py - 12, px, py - 8);
      ctx.quadraticCurveTo(px - 4, py - 12, px, py - 18);
      ctx.fill();
      ctx.fillStyle = "rgba(255, 240, 180, 0.8)";
      ctx.beginPath();
      ctx.arc(px, py - 12, 1.5, 0, Math.PI * 2);
      ctx.fill();
    } else {
      ctx.fillStyle = "#3a3020";
      ctx.fillRect(px - 0.5, py - 10, 1, 2);
    }
  } else if (p.type === "lamp") {
    // Farola lineal suave
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.beginPath();
    ctx.ellipse(px, py + 12, 7, 3, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "#2a2c30";
    ctx.lineWidth = 3.2;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(px, py + 12);
    ctx.lineTo(px, py - 12);
    ctx.stroke();
    // Brazo curvo
    ctx.lineWidth = 2.4;
    ctx.beginPath();
    ctx.moveTo(px, py - 12);
    ctx.quadraticCurveTo(px + 8, py - 16, px + 12, py - 10);
    ctx.stroke();
    const lit = phase.night || phase.light < 0.55;
    ctx.fillStyle = lit ? (phase.rain > 0.25 ? "#e8f0ff" : "#ffe6a0") : "#9a9aa0";
    ctx.beginPath();
    ctx.ellipse(px + 12, py - 6, 5, 4.5, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(20,20,24,0.45)";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.ellipse(px + 12, py - 6, 5, 4.5, 0, 0, Math.PI * 2);
    ctx.stroke();
    if (lit) {
      ctx.fillStyle = phase.rain > 0.25 ? "rgba(180, 205, 240, 0.18)" : "rgba(255, 220, 140, 0.16)";
      ctx.beginPath();
      ctx.arc(px + 10, py + 4, 22, 0, Math.PI * 2);
      ctx.fill();
    }
  } else if (p.type === "dumpster") {
    ctx.fillStyle = "rgba(0,0,0,0.28)";
    ctx.beginPath();
    ctx.ellipse(px, py + 8, 14, 4, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = p.color || "#2f5a38";
    fillRound(ctx, px - 13, py - 10, 26, 18, 4);
    strokeRound(ctx, px - 13, py - 10, 26, 18, 4, "rgba(10,20,12,0.4)", 1.1);
    ctx.fillStyle = shade(p.color || "#2f5a38", -25);
    fillRound(ctx, px - 13, py - 12, 26, 5, 2);
    ctx.fillStyle = "rgba(255,255,255,0.12)";
    fillRound(ctx, px - 4, py - 6, 8, 3, 1.5);
  } else if (p.type === "bench") {
    ctx.save();
    if (p.rot) {
      ctx.translate(px, py);
      ctx.rotate(Math.PI / 2);
      px = 0;
      py = 0;
    }
    ctx.fillStyle = "rgba(0,0,0,0.22)";
    ctx.beginPath();
    ctx.ellipse(px, py + 5, 14, 3, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#6a4a32";
    fillRound(ctx, px - 15, py - 5, 30, 7, 3);
    ctx.fillStyle = "#4a3220";
    fillRound(ctx, px - 15, py - 10, 30, 4, 2);
    fillRound(ctx, px - 13, py + 2, 4, 7, 1.5);
    fillRound(ctx, px + 9, py + 2, 4, 7, 1.5);
    ctx.restore();
  } else if (p.type === "fountain") {
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.beginPath();
    ctx.ellipse(px, py + 6, 16, 8, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#6a7078";
    ctx.beginPath();
    ctx.arc(px, py, 14, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#3a8090";
    ctx.beginPath();
    ctx.arc(px, py, 9, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "rgba(200,230,240,0.55)";
    ctx.beginPath();
    ctx.arc(px, py - 2, 4, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#8a9098";
    ctx.fillRect(px - 2, py - 12, 4, 10);
  } else if (p.type === "traffic") {
    ctx.fillStyle = "#222";
    ctx.fillRect(px - 2, py - 4, 4, 16);
    ctx.fillStyle = "#1a1a1a";
    roundRect(ctx, px - 6, py - 18, 12, 16, 2);
    ctx.fill();
    ctx.fillStyle = phase.night ? "#602020" : "#803030";
    ctx.beginPath();
    ctx.arc(px, py - 13, 2.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#806020";
    ctx.beginPath();
    ctx.arc(px, py - 8, 2.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = phase.night ? "#204020" : "#306030";
    ctx.beginPath();
    ctx.arc(px, py - 3, 2.5, 0, Math.PI * 2);
    ctx.fill();
  } else if (p.type === "manhole") {
    ctx.fillStyle = "#2a2a2c";
    ctx.beginPath();
    ctx.ellipse(px, py, 10, 7, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "#5a5a5e";
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.strokeStyle = "#3a3a3e";
    ctx.beginPath();
    ctx.moveTo(px - 6, py);
    ctx.lineTo(px + 6, py);
    ctx.stroke();
  } else if (p.type === "sign") {
    ctx.fillStyle = "#333";
    ctx.fillRect(px - 1, py - 2, 2, 12);
    ctx.fillStyle = "#3a5a8a";
    roundRect(ctx, px - 14, py - 16, 28, 12, 2);
    ctx.fill();
    ctx.fillStyle = "#e8eef8";
    ctx.font = `600 8px ${FONT_UI}`;
    ctx.textAlign = "center";
    ctx.fillText((p.label || "CALLE").slice(0, 8), px, py - 7);
  } else if (p.type === "awning") {
    const col = p.color || "#8a3a30";
    const half = p.wide ? 22 : 16;
    ctx.fillStyle = col;
    ctx.globalAlpha = 0.9;
    ctx.beginPath();
    ctx.moveTo(px - half, py - 4);
    ctx.lineTo(px + half, py - 4);
    ctx.lineTo(px + half - 4, py + 8);
    ctx.lineTo(px - half + 4, py + 8);
    ctx.closePath();
    ctx.fill();
    ctx.globalAlpha = 1;
    ctx.strokeStyle = "rgba(0,0,0,0.25)";
    for (let i = -half + 6; i <= half - 6; i += 5) {
      ctx.beginPath();
      ctx.moveTo(px + i, py - 4);
      ctx.lineTo(px + i * 0.75, py + 8);
      ctx.stroke();
    }
  } else if (p.type === "graffiti") {
    const col = p.color || "#c040a0";
    const text = (p.text || "NIEBLA").slice(0, 8);
    ctx.save();
    ctx.translate(px, py);
    if (p.wall === "e") ctx.rotate(0.1);
    if (p.wall === "w") ctx.rotate(-0.1);
    ctx.beginPath();
    ctx.rect(-16, -8, 32, 18);
    ctx.clip();
    ctx.fillStyle = col;
    ctx.globalAlpha = 0.88;
    ctx.font = `800 11px ${FONT_UI}`;
    ctx.textAlign = "center";
    ctx.fillText(text, 0, 2);
    ctx.fillStyle = col;
    ctx.globalAlpha = 0.4;
    ctx.fillRect(-2, 3, 2, 7);
    ctx.restore();
  } else if (p.type === "poster") {
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.fillRect(px - 7, py - 9, 14, 18);
    ctx.fillStyle = p.color || "#6a3030";
    ctx.fillRect(px - 6, py - 8, 12, 16);
    ctx.fillStyle = "rgba(240,220,180,0.4)";
    ctx.fillRect(px - 4, py - 6, 8, 3);
    ctx.fillStyle = "rgba(0,0,0,0.35)";
    ctx.fillRect(px - 4, py, 8, 5);
    if (p.torn) {
      ctx.fillStyle = shade(p.color || "#6a3030", -40);
      ctx.beginPath();
      ctx.moveTo(px + 3, py + 4);
      ctx.lineTo(px + 6, py + 8);
      ctx.lineTo(px - 1, py + 8);
      ctx.fill();
    }
  } else if (p.type === "wallArt") {
    const frame = p.frame || "#c8b898";
    const motif = p.motif ?? 0;
    ctx.fillStyle = "#14100c";
    ctx.fillRect(px - 9, py - 10, 18, 19);
    ctx.fillStyle = frame;
    ctx.fillRect(px - 8, py - 9, 16, 17);
    const motifs = ["#6a3a3a", "#3a4a6a", "#4a5a3a", "#5a3a5a"];
    ctx.fillStyle = motifs[motif % 4];
    ctx.fillRect(px - 6, py - 7, 12, 13);
    if (motif % 2 === 0) {
      ctx.fillStyle = "rgba(255,255,255,0.22)";
      ctx.beginPath();
      ctx.arc(px - 1, py - 1, 2.8, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "rgba(0,0,0,0.18)";
      ctx.fillRect(px - 4, py + 4, 8, 2);
    } else {
      ctx.strokeStyle = "rgba(255,255,255,0.3)";
      ctx.beginPath();
      ctx.moveTo(px - 4, py + 3);
      ctx.lineTo(px + 4, py - 4);
      ctx.lineTo(px + 2, py + 4);
      ctx.stroke();
    }
  } else if (p.type === "vine") {
    const dead = p.dead;
    const g = p.growth || 0.7;
    ctx.strokeStyle = dead ? "#5a4a30" : "#1e4a22";
    ctx.lineWidth = 1.8;
    ctx.beginPath();
    ctx.moveTo(px, py + 12);
    ctx.quadraticCurveTo(px - 6 * g, py + 3, px - 2, py - 10 * g);
    ctx.quadraticCurveTo(px + 5 * g, py - 1, px + 3, py - 15 * g);
    ctx.stroke();
    ctx.fillStyle = dead ? "rgba(90,70,40,0.55)" : "rgba(45,120,42,0.78)";
    for (let i = 0; i < 5; i++) {
      const ly = py + 8 - i * 4.2 * g;
      const lx = px + ((i % 2) ? 4 : -5) * g;
      ctx.beginPath();
      ctx.ellipse(lx, ly, 3.2, 2, i * 0.4, 0, Math.PI * 2);
      ctx.fill();
    }
  } else if (p.type === "wallGrime") {
    ctx.fillStyle = p.tone === 2 ? "rgba(30, 45, 28, 0.28)" : "rgba(45, 32, 20, 0.3)";
    ctx.beginPath();
    ctx.ellipse(px, py + 5, 11, 7, 0.12, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "rgba(18, 14, 10, 0.22)";
    ctx.fillRect(px - 2, py - 8, 3, 14);
  } else if (p.type === "railing") {
    ctx.strokeStyle = p.broken ? "#4a3a30" : "#5a5248";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(px - 12, py);
    if (p.broken) {
      ctx.lineTo(px - 2, py + 1);
      ctx.moveTo(px + 4, py + 3);
      ctx.lineTo(px + 12, py + 6);
    } else {
      ctx.lineTo(px + 12, py);
    }
    ctx.moveTo(px - 8, py);
    ctx.lineTo(px - 8, py + 8);
    ctx.moveTo(px + 8, py);
    ctx.lineTo(px + 8, p.broken ? py + 4 : py + 8);
    if (!p.broken) {
      ctx.moveTo(px, py);
      ctx.lineTo(px, py + 8);
    }
    ctx.stroke();
    if (p.broken) {
      ctx.fillStyle = "rgba(90, 70, 40, 0.45)";
      ctx.fillRect(px + 2, py + 4, 8, 3);
    }
  } else if (p.type === "hydrant") {
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.beginPath();
    ctx.ellipse(px, py + 6, 6, 3, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#b03028";
    ctx.fillRect(px - 4, py - 6, 8, 12);
    ctx.fillStyle = "#d04030";
    ctx.fillRect(px - 6, py - 2, 12, 4);
    ctx.fillStyle = "#e8e0d0";
    ctx.beginPath();
    ctx.arc(px, py - 8, 3.5, 0, Math.PI * 2);
    ctx.fill();
  } else if (p.type === "trash") {
    ctx.fillStyle = "rgba(0,0,0,0.22)";
    ctx.beginPath();
    ctx.ellipse(px, py + 5, 8, 3, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#3a4a3a";
    fillRound(ctx, px - 7, py - 8, 14, 14, 4);
    strokeRound(ctx, px - 7, py - 8, 14, 14, 4, "rgba(20,28,20,0.4)", 1);
    ctx.fillStyle = "#2a3a2a";
    fillRound(ctx, px - 7, py - 10, 14, 3, 1.5);
  } else if (p.type === "planter") {
    ctx.fillStyle = "rgba(0,0,0,0.2)";
    ctx.beginPath();
    ctx.ellipse(px, py + 6, 12, 3.5, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = p.wild ? "#4a3a28" : "#6a4a32";
    fillRound(ctx, px - 11, py - 2, 22, 10, 3);
    ctx.fillStyle = "#3a2818";
    fillRound(ctx, px - 9, py - 4, 18, 4, 2);
    if (p.tone === 2) {
      ctx.strokeStyle = "#6a5a38";
      ctx.lineWidth = 1.5;
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(px, py - 2);
      ctx.lineTo(px - 6, py - 13);
      ctx.moveTo(px, py - 3);
      ctx.lineTo(px + 7, py - 12);
      ctx.moveTo(px, py - 2);
      ctx.lineTo(px + 1, py - 15);
      ctx.stroke();
    } else {
      ctx.fillStyle = p.wild ? "#356a2e" : (p.tone ? "#4a7a3a" : "#3a6a48");
      ctx.beginPath();
      ctx.arc(px - 4, py - 6, 5, 0, Math.PI * 2);
      ctx.arc(px + 4, py - 7, 6, 0, Math.PI * 2);
      ctx.arc(px, py - 10, 4, 0, Math.PI * 2);
      ctx.fill();
      if (p.wild) {
        ctx.strokeStyle = "#2a5020";
        ctx.beginPath();
        ctx.moveTo(px + 6, py - 4);
        ctx.lineTo(px + 11, py - 12);
        ctx.stroke();
      }
    }
  } else if (p.type === "busStop") {
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.fillRect(px - 14, py + 4, 28, 6);
    ctx.fillStyle = "#3a4a5a";
    ctx.fillRect(px - 16, py - 18, 4, 26);
    ctx.fillRect(px + 12, py - 18, 4, 26);
    ctx.fillStyle = "#5a7a9a";
    ctx.fillRect(px - 16, py - 22, 32, 6);
    ctx.fillStyle = "rgba(180,210,230,0.35)";
    ctx.fillRect(px - 12, py - 16, 24, 14);
    ctx.fillStyle = "#e8c040";
    ctx.font = `700 8px ${FONT_UI}`;
    ctx.textAlign = "center";
    ctx.fillText("BUS", px, py - 12);
  } else if (p.type === "streetSign") {
    ctx.fillStyle = "#333";
    ctx.fillRect(px - 1, py - 4, 2, 14);
    ctx.fillStyle = "#2a4a6a";
    roundRect(ctx, px - 22, py - 22, 44, 12, 2);
    ctx.fill();
    ctx.fillStyle = "#1a3a5a";
    roundRect(ctx, px - 18, py - 10, 36, 10, 2);
    ctx.fill();
    ctx.fillStyle = "#e8eef8";
    ctx.font = `600 8px ${FONT_UI}`;
    ctx.textAlign = "center";
    ctx.fillText(`C/ ${(p.label || "LUNA").slice(0, 8)}`, px, py - 13);
    ctx.fillText(`C/ ${(p.label2 || "SOL").slice(0, 8)}`, px, py - 2);
  } else if (p.type === "boat") {
    ctx.fillStyle = "rgba(0,0,0,0.28)";
    ctx.beginPath();
    ctx.ellipse(px, py + 5, 18, 6, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#2e2820";
    ctx.beginPath();
    ctx.moveTo(px - 18, py);
    ctx.quadraticCurveTo(px, py + 12, px + 18, py);
    ctx.quadraticCurveTo(px, py - 9, px - 18, py);
    ctx.fill();
    // Casco hundido / agujeros
    ctx.fillStyle = "rgba(20, 40, 28, 0.55)";
    ctx.beginPath();
    ctx.ellipse(px - 4, py + 2, 5, 3, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(160,150,130,0.45)";
    ctx.beginPath();
    ctx.moveTo(px - 8, py - 3);
    ctx.lineTo(px + 10, py + 3);
    ctx.moveTo(px - 2, py - 6);
    ctx.lineTo(px + 4, py + 5);
    ctx.stroke();
    ctx.fillStyle = "rgba(90,110,50,0.4)";
    ctx.fillRect(px - 6, py - 1, 10, 4);
    ctx.fillStyle = "#4a3a28";
    ctx.fillRect(px + 6, py - 8, 3, 10);
  } else if (p.type === "riverDebris") {
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.beginPath();
    ctx.ellipse(px, py + 3, 10, 4, 0, 0, Math.PI * 2);
    ctx.fill();
    const tones = ["#4a4034", "#3a342c", "#5a4a38"];
    ctx.fillStyle = tones[p.tone % 3] || tones[0];
    ctx.beginPath();
    ctx.moveTo(px - 9, py + 2);
    ctx.lineTo(px - 3, py - 4);
    ctx.lineTo(px + 8, py - 1);
    ctx.lineTo(px + 6, py + 4);
    ctx.closePath();
    ctx.fill();
  } else if (p.type === "barrel") {
    ctx.fillStyle = "rgba(0,0,0,0.3)";
    ctx.beginPath();
    ctx.ellipse(px, py + 8, 8, 3.5, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = p.toxic ? "#3a5a28" : "#5a4a28";
    ctx.fillRect(px - 7, py - 8, 14, 16);
    ctx.fillStyle = p.toxic ? "#6a8a30" : "#7a6a30";
    ctx.fillRect(px - 7, py - 8, 14, 4);
    ctx.strokeStyle = "rgba(20,20,16,0.55)";
    ctx.strokeRect(px - 7, py - 8, 14, 16);
    if (p.toxic) {
      ctx.fillStyle = "rgba(140, 200, 60, 0.45)";
      ctx.font = "bold 9px sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("☢", px, py + 3);
    }
  } else if (p.type === "dock") {
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.fillRect(px - 16, py - 2, 32, 10);
    ctx.fillStyle = p.broken ? "#3a3228" : "#4a3a28";
    ctx.fillRect(px - 18, py - 6, 36, 8);
    ctx.fillStyle = "#2a241c";
    for (let i = 0; i < 5; i++) ctx.fillRect(px - 16 + i * 7, py - 6, 2, 8);
    if (p.broken) {
      ctx.strokeStyle = "rgba(0,0,0,0.4)";
      ctx.beginPath();
      ctx.moveTo(px + 4, py - 6);
      ctx.lineTo(px + 14, py + 4);
      ctx.stroke();
      ctx.fillStyle = "#2a2218";
      ctx.fillRect(px + 6, py - 2, 12, 5);
    }
  } else if (p.type === "pipe") {
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.fillRect(px - 4, py - 2, 18, 8);
    ctx.fillStyle = "#4a4a42";
    ctx.fillRect(px - 6, py - 8, 10, 14);
    ctx.fillStyle = "#3a3a34";
    ctx.fillRect(px + 2, py - 4, 16, 7);
    ctx.fillStyle = "rgba(70, 120, 50, 0.4)";
    ctx.beginPath();
    ctx.ellipse(px + 18, py + 2, 5, 3, 0, 0, Math.PI * 2);
    ctx.fill();
  }
}

function roundRect(ctx, x, y, w, h, r) {
  const rr = Math.max(0.5, Math.min(r, Math.abs(w) / 2, Math.abs(h) / 2));
  ctx.beginPath();
  ctx.moveTo(x + rr, y);
  ctx.arcTo(x + w, y, x + w, y + h, rr);
  ctx.arcTo(x + w, y + h, x, y + h, rr);
  ctx.arcTo(x, y + h, x, y, rr);
  ctx.arcTo(x, y, x + w, y, rr);
  ctx.closePath();
}

/** Relleno redondeado (siluetas Stardew). */
function fillRound(ctx, x, y, w, h, r) {
  roundRect(ctx, x, y, w, h, r);
  ctx.fill();
}

/** Contorno suave oscuro típico de sprites Stardew. */
function strokeRound(ctx, x, y, w, h, r, color = "rgba(30,24,18,0.55)", width = 1.2) {
  roundRect(ctx, x, y, w, h, r);
  ctx.strokeStyle = color;
  ctx.lineWidth = width;
  ctx.lineJoin = "round";
  ctx.lineCap = "round";
  ctx.stroke();
}

/** Torso cápsula vertical (cuerpo lineal, no bloque). */
function fillCapsule(ctx, x, y, w, h) {
  const r = Math.min(w / 2, h / 2);
  fillRound(ctx, x, y, w, h, r);
}

function drawBarricade(ctx, px, py) {
  ctx.fillStyle = "#6b4424";
  fillRound(ctx, px + 4, py + 10, TILE_PX - 8, 10, 3);
  fillRound(ctx, px + 4, py + 26, TILE_PX - 8, 10, 3);
  ctx.strokeStyle = "#3a2810";
  ctx.lineWidth = 1.2;
  strokeRound(ctx, px + 4, py + 10, TILE_PX - 8, 10, 3, "#3a2810", 1.2);
  // Vetas de madera (lineales)
  ctx.strokeStyle = "rgba(200,160,100,0.35)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(px + 10, py + 13);
  ctx.lineTo(px + TILE_PX - 10, py + 15);
  ctx.moveTo(px + 10, py + 29);
  ctx.lineTo(px + TILE_PX - 10, py + 31);
  ctx.stroke();
}

function drawDoor(ctx, game, tx, ty, px, py) {
  // Umbral + puerta con forma suave
  ctx.fillStyle = "#1a1410";
  fillRound(ctx, px + 14, py + 8, 20, TILE_PX - 12, 4);
  ctx.fillStyle = "#b8925a";
  fillRound(ctx, px + 16, py + 10, 16, TILE_PX - 16, 3);
  strokeRound(ctx, px + 16, py + 10, 16, TILE_PX - 16, 3, "rgba(40,28,14,0.55)", 1.2);
  ctx.strokeStyle = "rgba(80,55,30,0.45)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(px + 24, py + 14);
  ctx.lineTo(px + 24, py + TILE_PX - 14);
  ctx.stroke();
  ctx.fillStyle = "#e0c080";
  ctx.beginPath();
  ctx.arc(px + 28, py + TILE_PX / 2, 2.2, 0, Math.PI * 2);
  ctx.fill();
}

function drawLoot(ctx, id, px, py, time) {
  const bob = Math.sin(time * 3 + px * 0.02) * 2;
  ctx.save();
  ctx.translate(px, py + bob);
  if (id === "food") {
    ctx.fillStyle = "#c45a3a";
    fillRound(ctx, -7, -5, 14, 10, 3);
    strokeRound(ctx, -7, -5, 14, 10, 3, "rgba(40,16,10,0.4)", 1);
  } else if (id === "water") {
    ctx.fillStyle = "#4aa0c8";
    fillRound(ctx, -4, -8, 8, 14, 3);
    strokeRound(ctx, -4, -8, 8, 14, 3, "rgba(20,40,50,0.4)", 1);
    ctx.fillStyle = "rgba(200,230,255,0.45)";
    fillRound(ctx, -2, -6, 3, 6, 1.5);
  } else if (id === "scrap") {
    ctx.fillStyle = "#8a8a92";
    ctx.beginPath();
    ctx.moveTo(-7, 4);
    ctx.lineTo(0, -7);
    ctx.lineTo(7, 5);
    ctx.fill();
  } else if (id === "wood") {
    ctx.strokeStyle = "#8a5a28";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(-8, 4);
    ctx.lineTo(8, -4);
    ctx.stroke();
  } else if (id === "med") {
    ctx.fillStyle = "#eee";
    fillRound(ctx, -7, -7, 14, 14, 3);
    ctx.fillStyle = "#c03030";
    fillRound(ctx, -2, -7, 4, 14, 1.5);
    fillRound(ctx, -7, -2, 14, 4, 1.5);
  } else if (id === "bag" || id === "bag_big") {
    ctx.fillStyle = id === "bag_big" ? "#3a5a48" : "#4a3a28";
    fillRound(ctx, -8, -6, 16, 14, 4);
    ctx.fillStyle = "#2a2218";
    fillRound(ctx, -3, -9, 6, 4, 2);
    strokeRound(ctx, -8, -6, 16, 14, 4, "rgba(200,160,90,0.55)", 1.2);
  } else if (id === "bat" || id === "crowbar" || id === "axe" || id === "hammer") {
    ctx.strokeStyle =
      id === "bat" ? "#8a5a28" :
      id === "axe" ? "#6a7078" :
      id === "hammer" ? "#7a6848" :
      "#7a8088";
    ctx.lineWidth = id === "axe" ? 4 : 3.5;
    ctx.beginPath();
    ctx.moveTo(-9, 6);
    ctx.lineTo(9, -8);
    ctx.stroke();
    if (id === "axe") {
      ctx.fillStyle = "#8a9098";
      ctx.beginPath();
      ctx.moveTo(4, -10);
      ctx.lineTo(12, -6);
      ctx.lineTo(8, -2);
      ctx.fill();
    }
  } else if (id === "pan") {
    ctx.strokeStyle = "#6a7078";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(0, -1, 7, 0, Math.PI * 2);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(6, 2);
    ctx.lineTo(12, 8);
    ctx.stroke();
  } else if (id === "knife") {
    ctx.fillStyle = "#c8d0d8";
    ctx.beginPath();
    ctx.moveTo(-2, 6);
    ctx.lineTo(2, 6);
    ctx.lineTo(1, -8);
    ctx.lineTo(-1, -8);
    ctx.fill();
    ctx.fillStyle = "#5a3a28";
    ctx.fillRect(-2, 5, 4, 5);
  } else if (id === "eclipse_bat" || id === "wail_scythe" || id === "ironhowl") {
    // Glow legendario
    const pulse = 0.35 + Math.sin(time * 5) * 0.2;
    ctx.fillStyle = `rgba(255, 200, 80, ${pulse})`;
    ctx.beginPath();
    ctx.arc(0, 0, 14, 0, Math.PI * 2);
    ctx.fill();
    if (id === "eclipse_bat") {
      ctx.strokeStyle = "#e8c040";
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(-10, 7);
      ctx.lineTo(11, -9);
      ctx.stroke();
      ctx.strokeStyle = "#fff6c0";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(4, -4);
      ctx.lineTo(12, -10);
      ctx.stroke();
    } else if (id === "wail_scythe") {
      ctx.strokeStyle = "#c060e0";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(-4, 8);
      ctx.lineTo(2, -2);
      ctx.lineTo(12, -10);
      ctx.stroke();
      ctx.fillStyle = "#e8d0ff";
      ctx.beginPath();
      ctx.moveTo(4, -4);
      ctx.lineTo(14, -12);
      ctx.lineTo(10, -2);
      ctx.closePath();
      ctx.fill();
    } else {
      ctx.fillStyle = "#2a2030";
      ctx.fillRect(-12, -3, 20, 6);
      ctx.fillStyle = "#e8a040";
      ctx.fillRect(-12, -2, 5, 4);
      ctx.fillStyle = "#ffd070";
      ctx.fillRect(6, -2, 4, 4);
    }
  } else if (id === "jacket") {
    ctx.fillStyle = "#3a4a5a";
    ctx.fillRect(-8, -6, 16, 12);
    ctx.fillStyle = "#2a3238";
    ctx.fillRect(-2, -6, 4, 12);
  } else if (id === "pistol" || id === "shotgun" || id === "rifle") {
    ctx.fillStyle = "#2a2e34";
    ctx.fillRect(-10, -3, id === "pistol" ? 14 : 18, 6);
    ctx.fillStyle = "#c8a060";
    ctx.fillRect(-10, -2, 4, 4);
  } else if (id === "ammo_9mm" || id === "ammo_shot" || id === "ammo_rifle") {
    ctx.fillStyle = id === "ammo_shot" ? "#a04030" : id === "ammo_rifle" ? "#b07830" : "#c8a040";
    ctx.fillRect(-6, -5, 5, 10);
    ctx.fillRect(2, -5, 5, 10);
  } else if (id === "shirt") {
    ctx.fillStyle = "#6a3a3a";
    ctx.fillRect(-8, -6, 16, 12);
    ctx.fillStyle = "#c8a060";
    ctx.fillRect(-1, -4, 2, 8);
  } else if (id === "hoodie") {
    ctx.fillStyle = "#3a5a3a";
    ctx.fillRect(-8, -6, 16, 12);
    ctx.fillStyle = "#2a3a28";
    ctx.beginPath();
    ctx.moveTo(-6, -6);
    ctx.lineTo(0, -1);
    ctx.lineTo(6, -6);
    ctx.fill();
  } else if (id === "raincoat") {
    ctx.fillStyle = "#c4a030";
    ctx.fillRect(-8, -7, 16, 14);
    ctx.fillStyle = "#2a2a28";
    ctx.fillRect(-8, -7, 16, 3);
  } else if (id === "vest") {
    ctx.fillStyle = "#3a3a32";
    ctx.fillRect(-8, -6, 16, 12);
    ctx.fillStyle = "#6a7a40";
    ctx.fillRect(-2, -3, 4, 6);
  } else if (id === "flashlight") {
    ctx.fillStyle = "#2a2e34";
    ctx.fillRect(-8, -3, 14, 6);
    ctx.fillStyle = "#d8e8ff";
    ctx.beginPath();
    ctx.arc(7, 0, 4, 0, Math.PI * 2);
    ctx.fill();
  } else if (id === "lantern") {
    ctx.fillStyle = "#5a3a18";
    ctx.fillRect(-5, -8, 10, 14);
    ctx.fillStyle = "#ffc060";
    ctx.beginPath();
    ctx.arc(0, -1, 3.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "#8a6a30";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(0, -10, 4, Math.PI, 0);
    ctx.stroke();
  }
  ctx.restore();
}


function drawFx(ctx, game, camX, camY) {
  if (!game.fx?.length) return;
  for (const f of game.fx) {
    const a = Math.max(0, f.life / (f.max || 0.5));
    const x = f.x * TILE_PX - camX;
    const y = f.y * TILE_PX - camY;
    if (f.kind === "slash") {
      // Arco de golpe estilo Stardew
      const progress = 1 - a;
      const ang = f.ang || 0;
      const sweep = -0.85 + progress * 1.7;
      const r = (f.range || 1.4) * TILE_PX * 0.72;
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(ang + sweep);
      ctx.strokeStyle = `rgba(255, 245, 210, ${0.15 + a * 0.65})`;
      ctx.lineWidth = 5;
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.arc(0, 0, r, -0.55, 0.55);
      ctx.stroke();
      ctx.strokeStyle = `rgba(255, 210, 120, ${a * 0.55})`;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(0, 0, r * 0.92, -0.4, 0.4);
      ctx.stroke();
      ctx.restore();
      continue;
    }
    ctx.fillStyle =
      f.kind === "death"
        ? `rgba(90, 20, 18, ${a * 0.85})`
        : f.kind === "loot"
          ? `rgba(240, 210, 120, ${a * 0.9})`
          : f.kind === "dust"
            ? `rgba(170, 150, 120, ${a * 0.55})`
            : `rgba(160, 30, 28, ${a * 0.9})`;
    ctx.beginPath();
    ctx.arc(x, y, f.size || 2, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawZombie(ctx, px, py, time, z) {
  ctx.save();
  ctx.translate(px, py);
  const boss = !!z.boss;
  const scale = boss ? 1.55 + Math.min(0.35, (z.radius || 0.7) - 0.55) : 1;
  ctx.scale(scale, scale);
  const flash = z.hitFlash || 0;
  if (flash > 0) ctx.globalAlpha = 0.85 + flash * 0.7;
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  if (z.telegraph > 0) {
    ctx.strokeStyle = `rgba(255, 180, 60, ${0.35 + z.telegraph})`;
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.arc(0, 0, 22 + (0.55 - Math.min(0.55, z.telegraph)) * 18, 0, Math.PI * 2);
    ctx.stroke();
  }
  if (z.chargeT > 0) {
    ctx.fillStyle = "rgba(255, 70, 40, 0.18)";
    ctx.beginPath();
    ctx.arc(0, 0, 26, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.fillStyle = "rgba(0,0,0,0.28)";
  ctx.beginPath();
  ctx.ellipse(0, 13, boss ? 13 : 9, boss ? 4.5 : 3.5, 0, 0, Math.PI * 2);
  ctx.fill();
  if ((z.facing || 1) < 0) ctx.scale(-1, 1);
  const limp = Math.sin(z.walkPhase || time * (boss ? 4.2 : 6) + z.x) * (boss ? 3 : 2);
  const body = flash > 0 ? "#c85848" : boss ? z.color || "#6a2a28" : "#3a4a34";
  const head = flash > 0 ? "#e8b0a0" : boss ? z.head || "#8a4a40" : "#6a7a5a";

  // Piernas lineales
  ctx.strokeStyle = flash > 0 ? "#6a2820" : "#243028";
  ctx.lineWidth = boss ? 3.4 : 2.8;
  ctx.beginPath();
  ctx.moveTo(-3.5, 5);
  ctx.quadraticCurveTo(-4.5, 9 + limp * 0.4, -5, 13 + limp);
  ctx.moveTo(3.5, 5);
  ctx.quadraticCurveTo(4.5, 9 - limp * 0.4, 5, 13 - limp);
  ctx.stroke();

  // Torso cápsula (no bloque)
  ctx.fillStyle = body;
  fillCapsule(ctx, -7, -9, 14, 16);
  strokeRound(ctx, -7, -9, 14, 16, 7, flash > 0 ? "rgba(80,20,16,0.65)" : "rgba(20,28,18,0.55)", 1.3);

  // Brazos curvos
  ctx.strokeStyle = body;
  ctx.lineWidth = boss ? 3.6 : 3;
  ctx.beginPath();
  ctx.moveTo(-7, -2);
  ctx.quadraticCurveTo(-11, 1 + limp * 0.3, -13, 5 + limp);
  ctx.moveTo(7, -2);
  ctx.quadraticCurveTo(11, 1 - limp * 0.3, 12, 4 - limp);
  ctx.stroke();

  // Cabeza suave + ojos
  ctx.fillStyle = head;
  ctx.beginPath();
  ctx.arc(0, -15, boss ? 7.2 : 6.2, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "rgba(25,20,16,0.45)";
  ctx.lineWidth = 1.1;
  ctx.beginPath();
  ctx.arc(0, -15, boss ? 7.2 : 6.2, 0, Math.PI * 2);
  ctx.stroke();
  ctx.fillStyle = boss ? "#ff3030" : "#8a2020";
  ctx.beginPath();
  ctx.arc(-2.4, -15, boss ? 1.8 : 1.4, 0, Math.PI * 2);
  ctx.arc(2.8, -15, boss ? 1.8 : 1.4, 0, Math.PI * 2);
  ctx.fill();

  if (boss) {
    ctx.strokeStyle = "rgba(255, 210, 120, 0.75)";
    ctx.lineWidth = 1.8;
    strokeRound(ctx, -11, -26, 22, 42, 10, "rgba(255, 210, 120, 0.75)", 1.8);
    ctx.fillStyle = "rgba(255, 220, 140, 0.95)";
    ctx.font = "bold 8px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("JEFE", 0, -28);
  }
  if (flash > 0) {
    ctx.globalAlpha = 1;
    strokeRound(ctx, -9, -24, 18, 38, 9, `rgba(255, 220, 200, ${Math.min(1, flash * 4)})`, 2);
  }
  ctx.restore();

  if (boss && z.maxHp > 0) {
    const pct = Math.max(0, z.hp / z.maxHp);
    const bw = 42;
    const bx = px - bw / 2;
    const by = py - 38 * scale;
    ctx.fillStyle = "rgba(0,0,0,0.5)";
    fillRound(ctx, bx - 1, by - 1, bw + 2, 7, 3);
    ctx.fillStyle = "#3a1010";
    fillRound(ctx, bx, by, bw, 5, 2);
    ctx.fillStyle = pct > 0.35 ? "#d0a040" : "#d04540";
    fillRound(ctx, bx, by, Math.max(2, bw * pct), 5, 2);
    if (z.name) {
      ctx.fillStyle = "rgba(255,235,200,0.9)";
      ctx.font = "600 11px sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(z.name, px, by - 5);
    }
  }
}


function drawAimAndBullets(ctx, game, camX, camY) {
  const p = game.player;
  const handDef = itemDef(p.equip?.hand);
  const px = p.x * TILE_PX - camX;
  const py = p.y * TILE_PX - camY;

  if (handDef?.firearm) {
    const ang = p.aim || 0;
    const reach = (handDef.range || 8) * TILE_PX;
    const ammo = handDef.ammo ? (p.inv[handDef.ammo] || 0) : 0;
    ctx.save();
    ctx.strokeStyle = ammo > 0 ? "rgba(255, 220, 140, 0.35)" : "rgba(255, 80, 80, 0.35)";
    ctx.lineWidth = 1.5;
    ctx.setLineDash([6, 6]);
    ctx.beginPath();
    ctx.moveTo(px + Math.cos(ang) * 14, py + Math.sin(ang) * 14);
    ctx.lineTo(px + Math.cos(ang) * reach, py + Math.sin(ang) * reach);
    ctx.stroke();
    ctx.setLineDash([]);
    // Retícula
    const tx = px + Math.cos(ang) * Math.min(120, reach * 0.45);
    const ty = py + Math.sin(ang) * Math.min(120, reach * 0.45);
    ctx.strokeStyle = ammo > 0 ? "rgba(255, 230, 160, 0.7)" : "rgba(255,100,100,0.7)";
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.moveTo(tx - 6, ty);
    ctx.lineTo(tx + 6, ty);
    ctx.moveTo(tx, ty - 6);
    ctx.lineTo(tx, ty + 6);
    ctx.stroke();
    ctx.restore();

    if (game.muzzleFlash > 0) {
      const fx = px + Math.cos(ang) * 20;
      const fy = py + Math.sin(ang) * 20;
      const flash = Math.min(1, game.muzzleFlash * 7);
      const g = ctx.createRadialGradient(fx, fy, 0, fx, fy, 28);
      g.addColorStop(0, `rgba(255, 250, 210, ${flash})`);
      g.addColorStop(0.35, `rgba(255, 180, 60, ${flash * 0.7})`);
      g.addColorStop(1, "rgba(255, 80, 20, 0)");
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(fx, fy, 28, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = `rgba(255, 230, 160, ${flash})`;
      ctx.lineWidth = 2;
      ctx.beginPath();
      for (let i = 0; i < 5; i++) {
        const a = ang + (i - 2) * 0.18;
        ctx.moveTo(fx, fy);
        ctx.lineTo(fx + Math.cos(a) * (10 + i * 2), fy + Math.sin(a) * (10 + i * 2));
      }
      ctx.stroke();
    }
  }

  for (const b of game.bullets || []) {
    const bx = b.x * TILE_PX - camX;
    const by = b.y * TILE_PX - camY;
    ctx.save();
    ctx.translate(bx, by);
    ctx.rotate(Math.atan2(b.vy, b.vx));
    ctx.fillStyle = "#ffe7a0";
    ctx.fillRect(-4, -1.2, 8, 2.4);
    ctx.fillStyle = "#fff6d0";
    ctx.fillRect(2, -0.8, 3, 1.6);
    ctx.restore();
  }
}


function drawLootPrompt(ctx, game, camX, camY, w, h, playerIndoor) {
  const p = game.player;
  if (!p) return;
  const target = p.lootTarget;
  // Progress ring while holding E
  if (target && (p.lootProgress || 0) > 0) {
    const tx = (target.x + 0.5) * TILE_PX - camX;
    const ty = (target.y + 0.5) * TILE_PX - camY;
    const prog = Math.max(0, Math.min(1, p.lootProgress));
    ctx.save();
    ctx.strokeStyle = "rgba(20,18,14,0.55)";
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.arc(tx, ty - 18, 14, 0, Math.PI * 2);
    ctx.stroke();
    ctx.strokeStyle = "#f0d9a0";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.arc(tx, ty - 18, 14, -Math.PI / 2, -Math.PI / 2 + prog * Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  let tip = null;
  if (target && target.kind === "container") {
    tip = `Mantén E · ${furnitureLabel(target.furn).toLowerCase()}`;
  } else {
    const near = nearestSearchable(game.world, p.x, p.y);
    if (near) tip = `E · registrar ${furnitureLabel(near.furn).toLowerCase()}`;
    else {
      // Botín en suelo cercano
      const tx = Math.floor(p.x);
      const ty = Math.floor(p.y);
      let best = null;
      let bestD = 1.35;
      for (let oy = -1; oy <= 1; oy++) {
        for (let ox = -1; ox <= 1; ox++) {
          const item = game.world.loot.get(`${tx + ox},${ty + oy}`);
          if (!item) continue;
          const d = Math.hypot(p.x - (tx + ox + 0.5), p.y - (ty + oy + 0.5));
          if (d < bestD) {
            bestD = d;
            best = item;
          }
        }
      }
      if (best) tip = `E · saquear`;
    }
  }
  if (!tip) return;
  const y = playerIndoor ? 54 : 22;
  ctx.fillStyle = "rgba(20,18,14,0.78)";
  ctx.fillRect(w / 2 - 120, y, 240, 26);
  ctx.fillStyle = "#f0d9a0";
  ctx.font = `600 12px ${FONT_UI}`;
  ctx.textAlign = "center";
  ctx.fillText(tip, w / 2, y + 18);
}

function drawPlayer(ctx, px, py, player, time, game = null) {
  ctx.save();
  ctx.translate(px, py);
  ctx.scale(1.12, 1.12);
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  // Parpadeo de i-frames (Stardew)
  if ((player.invulnT || 0) > 0 && Math.floor(time * 18) % 2 === 0) {
    ctx.globalAlpha = 0.35;
  }
  const handDef = itemDef(player.equip?.hand);
  const aimingGun = !!(handDef?.firearm);
  const swinging = (player.swingT || 0) > 0;
  if (aimingGun) {
    ctx.rotate(player.aim || 0);
  } else if (swinging) {
    ctx.rotate(player.facingAng || player.aim || 0);
  } else {
    ctx.scale(player.facing || 1, 1);
  }

  // Sombra elíptica suave
  ctx.fillStyle = "rgba(0,0,0,0.28)";
  ctx.beginPath();
  ctx.ellipse(0, 13, 10, 3.6, 0, 0, Math.PI * 2);
  ctx.fill();

  const moving = player.moving || Math.hypot(player.vx || 0, player.vy || 0) > 0.15;
  const phase = player.walkPhase || time * 8;
  const amp = moving ? (player.sprinting ? 3.1 : 2.2) : 0;
  const walk = Math.sin(phase) * amp;
  const bob = moving ? Math.abs(Math.sin(phase)) * (player.sprinting ? 1.4 : 0.8) : 0;
  ctx.translate(0, -bob);
  const bodyDef = itemDef(player.equip?.body);
  const wear = bodyDef?.wear || { style: "tee", fill: "#3a4a5a", trim: "#2a343c", accent: "#6a7a88" };
  const bagId = player.equip?.bag;
  const handId = player.equip?.hand;
  const lightId = player.equip?.light;

  // Piernas curvas
  ctx.strokeStyle = "#1a201c";
  ctx.lineWidth = 2.8;
  ctx.beginPath();
  ctx.moveTo(-3.2, 4);
  ctx.quadraticCurveTo(-3.8, 8 + walk * 0.35, -4.2, 13 + walk);
  ctx.moveTo(3.2, 4);
  ctx.quadraticCurveTo(3.8, 8 - walk * 0.35, 4.2, 13 - walk);
  ctx.stroke();

  drawHolsteredWeapons(ctx, player, handId);

  // Mochila redondeada
  if (bagId) {
    const big = bagId === "bag_big";
    ctx.fillStyle = big ? "#2a4a3a" : "#3a2e22";
    fillRound(ctx, -14, -9, 7, big ? 15 : 12, 3);
    strokeRound(ctx, -14, -9, 7, big ? 15 : 12, 3, "rgba(200,160,90,0.55)", 1);
    ctx.fillStyle = "#2a2218";
    fillRound(ctx, -12, -11, 3, 3, 1);
  }

  drawWornBody(ctx, wear);

  // Linterna / farol al cinto
  if (lightId) {
    if (lightId === "lantern") {
      ctx.fillStyle = "#5a3a18";
      fillRound(ctx, -6, 6, 5, 7, 2);
      ctx.fillStyle = "#ffb84a";
      ctx.beginPath();
      ctx.arc(-3.5, 8, 2, 0, Math.PI * 2);
      ctx.fill();
    } else {
      ctx.fillStyle = "#2a2e34";
      fillRound(ctx, 4, 7, 8, 3, 1.5);
      ctx.fillStyle = "#d8e8ff";
      fillRound(ctx, 11, 7, 2, 3, 1);
    }
  }

  // Cabeza + pelo suave
  ctx.fillStyle = "#d8b890";
  ctx.beginPath();
  ctx.arc(0, -16, 6.4, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "rgba(40,28,18,0.35)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.arc(0, -16, 6.4, 0, Math.PI * 2);
  ctx.stroke();
  ctx.fillStyle = "#2b2218";
  ctx.beginPath();
  ctx.arc(-3, -19, 3.2, 0, Math.PI * 2);
  ctx.arc(2, -20, 3.4, 0, Math.PI * 2);
  ctx.arc(4, -16, 2.6, 0, Math.PI * 2);
  ctx.fill();
  // Ojitos
  ctx.fillStyle = "#1a1814";
  ctx.beginPath();
  ctx.arc(-2.2, -15.5, 0.9, 0, Math.PI * 2);
  ctx.arc(2.4, -15.5, 0.9, 0, Math.PI * 2);
  ctx.fill();
  if (wear.style === "hoodie") {
    ctx.strokeStyle = wear.trim;
    ctx.lineWidth = 2.4;
    ctx.beginPath();
    ctx.arc(0, -17, 8, Math.PI * 0.95, Math.PI * 2.05);
    ctx.stroke();
  }

  drawHeldWeapon(ctx, handId, time, player.swingT || 0, player.swingDur || 0.3);

  ctx.restore();
}

function drawWornBody(ctx, wear) {
  const { style, fill, trim, accent } = wear;
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  ctx.fillStyle = fill;
  if (style === "vest") {
    ctx.fillStyle = "#4a4a52";
    fillCapsule(ctx, -8, -10, 16, 16);
    ctx.fillStyle = fill;
    fillRound(ctx, -9, -8, 18, 13, 5);
    strokeRound(ctx, -9, -8, 18, 13, 5, "rgba(20,18,16,0.45)", 1.1);
    ctx.fillStyle = trim;
    fillRound(ctx, -7, -6, 5, 8, 2);
    fillRound(ctx, 2, -6, 5, 8, 2);
    ctx.fillStyle = accent;
    fillRound(ctx, -2, -4, 4, 6, 1.5);
  } else if (style === "raincoat") {
    fillRound(ctx, -9, -11, 18, 18, 6);
    strokeRound(ctx, -9, -11, 18, 18, 6, "rgba(20,28,24,0.4)", 1.1);
    ctx.fillStyle = trim;
    fillRound(ctx, -2, -11, 4, 18, 2);
    ctx.fillStyle = accent;
    fillRound(ctx, -9, -11, 18, 4, 2);
  } else if (style === "hoodie") {
    fillCapsule(ctx, -8, -10, 16, 16);
    strokeRound(ctx, -8, -10, 16, 16, 8, "rgba(20,18,16,0.4)", 1.1);
    ctx.fillStyle = trim;
    ctx.beginPath();
    ctx.moveTo(-6, -10);
    ctx.quadraticCurveTo(0, -3, 6, -10);
    ctx.lineTo(4, -10);
    ctx.quadraticCurveTo(0, -6, -4, -10);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = accent;
    fillRound(ctx, -3, 2, 6, 3, 1.5);
  } else if (style === "jacket") {
    fillCapsule(ctx, -8, -10, 16, 16);
    strokeRound(ctx, -8, -10, 16, 16, 8, "rgba(20,18,16,0.4)", 1.1);
    ctx.fillStyle = trim;
    fillRound(ctx, -2, -10, 4, 16, 2);
    ctx.fillStyle = accent;
    fillRound(ctx, -7, -1, 3, 2, 1);
    fillRound(ctx, 4, -1, 3, 2, 1);
  } else if (style === "shirt") {
    fillCapsule(ctx, -8, -10, 16, 16);
    strokeRound(ctx, -8, -10, 16, 16, 8, "rgba(20,18,16,0.4)", 1.1);
    ctx.fillStyle = trim;
    fillRound(ctx, -8, -10, 16, 4, 2);
    ctx.fillStyle = accent;
    fillRound(ctx, -1, -7, 2, 10, 1);
  } else {
    // tee / default — cápsula suave
    fillCapsule(ctx, -8, -10, 16, 16);
    strokeRound(ctx, -8, -10, 16, 16, 8, "rgba(20,18,16,0.4)", 1.1);
    ctx.fillStyle = trim;
    fillRound(ctx, -2, -10, 4, 6, 2);
  }
  // Brazo delantero redondeado
  ctx.fillStyle = "#c4a078";
  fillRound(ctx, -10, -5, 5, 11, 2.5);
  strokeRound(ctx, -10, -5, 5, 11, 2.5, "rgba(40,28,18,0.35)", 0.9);
}

function drawHeldWeapon(ctx, hand, time, swingT = 0, swingDur = 0.3) {
  if (!hand) {
    ctx.strokeStyle = "#d2b08a";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(7, -1);
    ctx.lineTo(10, 2);
    ctx.stroke();
    return;
  }
  const dur = Math.max(0.18, swingDur || 0.3);
  const swing = swingT > 0
    ? Math.sin((1 - Math.min(1, swingT / dur)) * Math.PI) * 1.35
    : Math.sin(time * 2) * 0.05;
  ctx.save();
  ctx.translate(8, -1);
  ctx.rotate(-0.55 + swing);
  ctx.lineCap = "round";
  ctx.lineJoin = "round";

  if (hand === "bat") {
    ctx.strokeStyle = "#8a5a28";
    ctx.lineWidth = 3.5;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(16, -10);
    ctx.stroke();
    ctx.strokeStyle = "#c8a060";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(12, -8);
    ctx.lineTo(17, -11);
    ctx.stroke();
  } else if (hand === "axe") {
    ctx.strokeStyle = "#6a5030";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(14, -9);
    ctx.stroke();
    ctx.fillStyle = "#8a9098";
    ctx.beginPath();
    ctx.moveTo(10, -12);
    ctx.lineTo(19, -8);
    ctx.lineTo(14, -4);
    ctx.closePath();
    ctx.fill();
  } else if (hand === "crowbar") {
    ctx.strokeStyle = "#7a8088";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(15, -9);
    ctx.lineTo(17, -5);
    ctx.stroke();
  } else if (hand === "hammer") {
    ctx.strokeStyle = "#6a5030";
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(13, -8);
    ctx.stroke();
    ctx.fillStyle = "#7a6848";
    ctx.fillRect(11, -12, 7, 5);
  } else if (hand === "knife") {
    ctx.fillStyle = "#c8d0d8";
    ctx.beginPath();
    ctx.moveTo(0, 1);
    ctx.lineTo(3, -1);
    ctx.lineTo(12, -8);
    ctx.lineTo(10, -4);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "#5a3a28";
    ctx.fillRect(-2, -1, 4, 4);
  } else if (hand === "pistol" || hand === "shotgun" || hand === "rifle") {
    const long = hand === "rifle" ? 18 : hand === "shotgun" ? 16 : 12;
    ctx.fillStyle = "#2a2e32";
    ctx.fillRect(0, -2, long, 4);
    ctx.fillStyle = "#1a1c1e";
    ctx.fillRect(-3, -1, 5, 5);
    ctx.fillStyle = "#6a7078";
    ctx.fillRect(long - 2, -1, 4, 2);
    if (hand === "shotgun") {
      ctx.fillStyle = "#5a4030";
      ctx.fillRect(2, -3, 8, 2);
    }
  } else if (hand === "eclipse_bat") {
    ctx.strokeStyle = "#e8c040";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(18, -12);
    ctx.stroke();
    ctx.strokeStyle = "#fff6c0";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(12, -8);
    ctx.lineTo(19, -13);
    ctx.stroke();
    ctx.fillStyle = "rgba(255, 220, 100, 0.35)";
    ctx.beginPath();
    ctx.arc(16, -10, 5, 0, Math.PI * 2);
    ctx.fill();
  } else if (hand === "wail_scythe") {
    ctx.strokeStyle = "#6a3a78";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(12, -8);
    ctx.stroke();
    ctx.fillStyle = "#e0c0ff";
    ctx.beginPath();
    ctx.moveTo(8, -12);
    ctx.lineTo(20, -14);
    ctx.lineTo(14, -4);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = "rgba(200, 120, 255, 0.7)";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(14, -10, 7, -0.8, 0.6);
    ctx.stroke();
  } else if (hand === "ironhowl") {
    ctx.fillStyle = "#2a2030";
    ctx.fillRect(0, -3, 18, 5);
    ctx.fillStyle = "#1a1420";
    ctx.fillRect(-3, -2, 5, 6);
    ctx.fillStyle = "#e8a040";
    ctx.fillRect(14, -2, 5, 3);
    ctx.fillStyle = "rgba(255, 180, 60, 0.4)";
    ctx.beginPath();
    ctx.arc(18, -0.5, 4, 0, Math.PI * 2);
    ctx.fill();
  } else if (hand === "pan") {
    ctx.strokeStyle = "#8a9098";
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(7, -3);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(11, -5, 5, 0, Math.PI * 2);
    ctx.stroke();
  } else {
    ctx.strokeStyle = "#8a9098";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(14, -8);
    ctx.stroke();
  }
  ctx.restore();
}

function drawHolsteredWeapons(ctx, player, handId) {
  const owned = ["bat", "crowbar", "axe", "hammer", "knife", "pan"].filter(
    (id) => (player.inv[id] || 0) > 0 && id !== handId
  );
  owned.slice(0, 3).forEach((id, i) => {
    const x = -11 - i * 2;
    const y = -2 + i * 3;
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(-0.9 - i * 0.12);
    if (id === "bat") {
      ctx.strokeStyle = "#6a4020";
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.lineTo(0, 12);
      ctx.stroke();
    } else if (id === "axe") {
      ctx.strokeStyle = "#5a4830";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.lineTo(0, 11);
      ctx.stroke();
      ctx.fillStyle = "#7a8088";
      ctx.fillRect(-3, -2, 6, 3);
    } else if (id === "knife") {
      ctx.fillStyle = "#b0b8c0";
      ctx.fillRect(-1, 0, 2, 9);
    } else if (id === "pan") {
      ctx.strokeStyle = "#707880";
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(0, 3, 3.5, 0, Math.PI * 2);
      ctx.stroke();
    } else {
      ctx.strokeStyle = "#6a7078";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.lineTo(0, 11);
      ctx.stroke();
    }
    ctx.restore();
  });
}


let _miniBase = null;
let _miniSeed = null;
let _miniRev = -1;
let _miniSize = 0;

function drawMinimap(mctx, mini, game) {
  const s = mini.width;
  const world = game.world;
  const scale = s / world.size;
  const rev = world.tileRev || 0;
  if (!_miniBase || _miniSeed !== world.seed || _miniRev !== rev || _miniSize !== world.size || _miniBase.width !== s) {
    if (!_miniBase) _miniBase = document.createElement("canvas");
    _miniBase.width = s;
    _miniBase.height = s;
    const b = _miniBase.getContext("2d");
    b.clearRect(0, 0, s, s);
    for (let y = 0; y < world.size; y++) {
      for (let x = 0; x < world.size; x++) {
        b.fillStyle = TILE_META[world.tiles[y * world.size + x]]?.color || "#222";
        b.fillRect(x * scale, y * scale, scale + 0.6, scale + 0.6);
      }
    }
    _miniSeed = world.seed;
    _miniRev = rev;
    _miniSize = world.size;
  }
  mctx.clearRect(0, 0, s, s);
  mctx.drawImage(_miniBase, 0, 0);
  for (const z of game.zombies) {
    mctx.fillStyle = z.boss ? "#e8a040" : "#7dcea0";
    const zs = z.boss ? 3.2 : 2;
    mctx.fillRect(z.x * scale - zs / 2, z.y * scale - zs / 2, zs, zs);
  }
  mctx.fillStyle = "#fff6e0";
  mctx.beginPath();
  mctx.arc(game.player.x * scale, game.player.y * scale, 2.5, 0, Math.PI * 2);
  mctx.fill();
}
