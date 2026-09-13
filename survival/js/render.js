import { TILE, TILE_META, buildingAt, furnitureType, furnitureLabel, nearestSearchable, itemDef } from "./world.js";
import { dayPhase } from "./game.js";

const TILE_PX = 48;

export function createRenderer(canvas, miniCanvas) {
  const ctx = canvas.getContext("2d");
  const mctx = miniCanvas.getContext("2d");
  const dpr = Math.min(window.devicePixelRatio || 1, 2);

  function resize() {
    const w = window.innerWidth;
    const h = window.innerHeight;
    canvas.width = Math.floor(w * dpr);
    canvas.height = Math.floor(h * dpr);
    canvas.style.width = `${w}px`;
    canvas.style.height = `${h}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
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
  const phase = dayPhase(game);
  const camX = game.player.x * TILE_PX - w / 2;
  const camY = game.player.y * TILE_PX - h / 2;
  const raining = phase.rain > 0.15;
  const storming = phase.weather === "storm";

  // Cielo / atmósfera
  const sky = ctx.createLinearGradient(0, 0, 0, h);
  if (phase.thunder > 0.05) {
    sky.addColorStop(0, "#c8d0e0");
    sky.addColorStop(1, "#6a7080");
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
  } else {
    sky.addColorStop(0, "#7a8a92");
    sky.addColorStop(0.45, "#9aa0a0");
    sky.addColorStop(1, "#6a6a62");
  }
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, h);

  const x0 = Math.max(0, Math.floor(camX / TILE_PX) - 1);
  const y0 = Math.max(0, Math.floor(camY / TILE_PX) - 1);
  const x1 = Math.min(game.world.size, Math.ceil((camX + w) / TILE_PX) + 2);
  const y1 = Math.min(game.world.size, Math.ceil((camY + h) / TILE_PX) + 2);

  // Suelo
  for (let ty = y0; ty < y1; ty++) {
    for (let tx = x0; tx < x1; tx++) {
      const tile = game.world.tiles[ty * game.world.size + tx];
      drawGround(ctx, game, tile, tx, ty, tx * TILE_PX - camX, ty * TILE_PX - camY, phase);
      if (raining && (tile === TILE.ROAD || tile === TILE.CROSSWALK || tile === TILE.SIDEWALK)) {
        drawWetSheen(ctx, tx * TILE_PX - camX, ty * TILE_PX - camY, game.time, tx, ty);
      }
    }
  }

  // Edificios
  const inside = buildingAt(game.world, game.player.x, game.player.y);
  const playerTile = tileIndex(game, game.player.x, game.player.y);
  const playerIndoor = TILE_META[playerTile]?.indoor || playerTile === TILE.DOOR;
  const litWindows = [];

  for (const b of game.world.buildings) {
    if (b.x1 < x0 - 1 || b.x0 > x1 + 1 || b.y1 < y0 - 1 || b.y0 > y1 + 1) continue;
    const entered = inside === b && playerIndoor;
    drawBuildingRoof(ctx, b, camX, camY, phase, entered, litWindows);
  }

  // Props
  const visibleProps = game.world.props
    .map((p) => ({ p, px: p.x * TILE_PX - camX, py: p.y * TILE_PX - camY }))
    .filter(({ px, py }) => px > -70 && py > -70 && px < w + 70 && py < h + 70)
    .sort((a, b) => a.p.y - b.p.y);
  for (const { p, px, py } of visibleProps) {
    drawProp(ctx, p, px, py, phase);
  }

  // Loot
  for (let ty = y0; ty < y1; ty++) {
    for (let tx = x0; tx < x1; tx++) {
      const item = game.world.loot.get(`${tx},${ty}`);
      if (!item) continue;
      drawLoot(ctx, item.id, tx * TILE_PX - camX + TILE_PX / 2, ty * TILE_PX - camY + TILE_PX / 2, game.time);
    }
  }

  // Barricadas / puertas
  for (let ty = y0; ty < y1; ty++) {
    for (let tx = x0; tx < x1; tx++) {
      const tile = game.world.tiles[ty * game.world.size + tx];
      if (tile === TILE.BARRICADE) drawBarricade(ctx, tx * TILE_PX - camX, ty * TILE_PX - camY);
      if (tile === TILE.DOOR) drawDoor(ctx, game, tx, ty, tx * TILE_PX - camX, ty * TILE_PX - camY);
    }
  }

  if (game.buildMode) {
    const bx = game.buildMode === "claim" ? Math.floor(game.player.x) : Math.floor(game.player.x + game.player.facing);
    const by = Math.floor(game.player.y);
    ctx.fillStyle = "rgba(220, 190, 90, 0.3)";
    ctx.strokeStyle = "rgba(255, 220, 120, 0.9)";
    ctx.lineWidth = 2;
    ctx.fillRect(bx * TILE_PX - camX + 3, by * TILE_PX - camY + 3, TILE_PX - 6, TILE_PX - 6);
    ctx.strokeRect(bx * TILE_PX - camX + 3, by * TILE_PX - camY + 3, TILE_PX - 6, TILE_PX - 6);
  }

  for (const z of game.zombies) {
    drawZombie(ctx, z.x * TILE_PX - camX, z.y * TILE_PX - camY, game.time, z);
  }
  drawAimAndBullets(ctx, game, camX, camY);
  drawPlayer(ctx, game.player.x * TILE_PX - camX, game.player.y * TILE_PX - camY, game.player, game.time, game);

  if (inside && playerIndoor) {
    ctx.fillStyle = "rgba(10,12,14,0.72)";
    ctx.fillRect(w / 2 - 100, 18, 200, 30);
    ctx.fillStyle = "#e8e0d0";
    ctx.font = "600 13px Sora, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(`🚪 ${inside.name}`, w / 2, 38);

    const near = nearestSearchable(game.world, game.player.x, game.player.y);
    if (near) {
      const label = furnitureLabel(near.furn);
      ctx.fillStyle = "rgba(20,18,14,0.78)";
      ctx.fillRect(w / 2 - 110, 54, 220, 26);
      ctx.fillStyle = "#f0d9a0";
      ctx.font = "600 12px Sora, sans-serif";
      ctx.fillText(`E · registrar ${label.toLowerCase()}`, w / 2, 72);
    }
  }

  // Oscuridad + iluminación (farolas, ventanas, linterna)
  drawLighting(ctx, game, phase, camX, camY, w, h, litWindows, visibleProps, playerIndoor);

  // Lluvia encima de la noche (gotas visibles)
  if (phase.rain > 0.08) {
    drawRain(ctx, w, h, game, phase);
  }

  // Flash de rayo
  if (phase.thunder > 0) {
    ctx.fillStyle = `rgba(220, 230, 255, ${Math.min(0.55, phase.thunder * 1.8)})`;
    ctx.fillRect(0, 0, w, h);
  }

  if (game.player.hurtFlash > 0) {
    ctx.fillStyle = `rgba(140, 20, 20, ${game.player.hurtFlash * 0.5})`;
    ctx.fillRect(0, 0, w, h);
  }

  // Viñeta muy suave (no oscurece el centro)
  const fogA = phase.night ? 0.12 : raining ? 0.22 : 0.14;
  const fog = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.45, w / 2, h / 2, Math.max(w, h) * 0.9);
  fog.addColorStop(0, "rgba(0,0,0,0)");
  fog.addColorStop(0.7, "rgba(0,0,0,0)");
  fog.addColorStop(1, phase.night ? `rgba(6,8,14,${fogA})` : `rgba(60,70,78,${fogA})`);
  ctx.fillStyle = fog;
  ctx.fillRect(0, 0, w, h);

  drawMinimap(mctx, mini, game);
}

function drawWetSheen(ctx, px, py, time, tx, ty) {
  const pulse = 0.04 + Math.sin(time * 2 + tx + ty) * 0.02;
  ctx.fillStyle = `rgba(180, 200, 220, ${pulse})`;
  ctx.beginPath();
  ctx.ellipse(px + 24, py + 28, 14, 5, 0.2, 0, Math.PI * 2);
  ctx.fill();
}

function drawRain(ctx, w, h, game, phase) {
  const n = Math.floor(80 + phase.rain * 160);
  const wind = phase.wind * 10;
  ctx.strokeStyle = phase.night ? "rgba(170,190,220,0.35)" : "rgba(200,210,220,0.4)";
  ctx.lineWidth = 1.2;
  const t = game.time;
  for (let i = 0; i < n; i++) {
    const seed = (i * 7919 + ((t * 420) | 0)) % 10000;
    const x = ((seed * 37) % w) + wind * (seed % 7);
    const y = ((seed * 53 + t * (380 + phase.rain * 220)) % (h + 40)) - 20;
    const len = 8 + (seed % 10);
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x + wind * 0.6, y + len);
    ctx.stroke();
  }
  // Salpicaduras en el suelo
  if (phase.rain > 0.4) {
    ctx.fillStyle = phase.night ? "rgba(180,200,230,0.15)" : "rgba(220,230,240,0.18)";
    for (let i = 0; i < 18; i++) {
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
  if (darkness < 0.04 && phase.thunder <= 0) return;

  const lampMargin = 220;
  const lamps = [];
  for (const p of game.world.props) {
    if (p.type !== "lamp") continue;
    const lx = p.x * TILE_PX - camX;
    const ly = p.y * TILE_PX - camY;
    if (lx < -lampMargin || ly < -lampMargin || lx > w + lampMargin || ly > h + lampMargin) continue;
    lamps.push({ p, lx, ly });
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

  // Máscara aparte: destination-out no borra el mundo
  const mask = getLightMask(w, h);
  const m = mask.getContext("2d");
  m.setTransform(1, 0, 0, 1, 0, 0);
  m.clearRect(0, 0, w, h);
  // Velo nocturno ligero: la calle se lee también fuera de farolas
  const veil = phase.night ? Math.min(0.2, 0.1 + darkness * 0.14) : Math.min(0.18, darkness * 0.28);
  m.fillStyle = `rgba(8, 12, 24, ${veil})`;
  m.fillRect(0, 0, w, h);

  m.globalCompositeOperation = "destination-out";
  for (const { p, lx, ly } of lamps) {
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
  ctx.drawImage(mask, 0, 0);

  // Brillo de farolas encima
  ctx.save();
  ctx.globalCompositeOperation = "lighter";
  for (const { p, lx, ly } of lamps) {
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

    const core = ctx.createRadialGradient(cx, cy - 14, 0, cx, cy - 14, 20);
    core.addColorStop(0, cool ? `rgba(250,252,255,${0.75 * flicker})` : `rgba(255,248,220,${0.75 * flicker})`);
    core.addColorStop(1, "rgba(255,220,160,0)");
    ctx.fillStyle = core;
    ctx.beginPath();
    ctx.arc(cx, cy - 14, 20, 0, Math.PI * 2);
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
    const wr = 32;
    const wg = ctx.createRadialGradient(win.x, win.y, 1, win.x, win.y, wr);
    wg.addColorStop(0, "rgba(255, 220, 140, 0.26)");
    wg.addColorStop(0.55, "rgba(255, 185, 100, 0.08)");
    wg.addColorStop(1, "rgba(255, 160, 70, 0)");
    ctx.fillStyle = wg;
    ctx.beginPath();
    ctx.arc(win.x, win.y, wr, 0, Math.PI * 2);
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
    // Las paredes se ven bajo el tejado; dibujar base de fachada
    const b = buildingAt(game.world, tx + 0.5, ty + 0.5);
    ctx.fillStyle = b?.facade || "#4a4540";
    ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
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
  const nightBoost = phase?.night ? 28 : 0;
  const shade = (patch ? 58 + (n % 6) : 46 + n) + nightBoost;
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
  const curb = "rgba(170,168,160,0.7)";
  ctx.fillStyle = curb;
  if (neighborTile(game, tx, ty - 1) === TILE.SIDEWALK) ctx.fillRect(px, py, TILE_PX, 3);
  if (neighborTile(game, tx, ty + 1) === TILE.SIDEWALK) ctx.fillRect(px, py + TILE_PX - 3, TILE_PX, 3);
  if (neighborTile(game, tx - 1, ty) === TILE.SIDEWALK) ctx.fillRect(px, py, 3, TILE_PX);
  if (neighborTile(game, tx + 1, ty) === TILE.SIDEWALK) ctx.fillRect(px + TILE_PX - 3, py, 3, TILE_PX);

  // Línea blanca de borde de calzada
  ctx.strokeStyle = "rgba(220,220,210,0.4)";
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
    ctx.fillStyle = "rgba(235,235,225,0.88)";
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
    ctx.strokeStyle = "rgba(230, 200, 70, 0.62)";
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
  const nightBoost = phase?.night ? 18 : 0;
  const base = 136 + ((tx * 3 + ty * 5) % 8) + nightBoost;
  ctx.fillStyle = `rgb(${base},${base - 3},${base - 8})`;
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);

  ctx.strokeStyle = "rgba(50,48,44,0.28)";
  ctx.lineWidth = 1;
  const h = TILE_PX / 2;
  ctx.strokeRect(px + 0.5, py + 0.5, h - 1, h - 1);
  ctx.strokeRect(px + h + 0.5, py + 0.5, h - 1, h - 1);
  ctx.strokeRect(px + 0.5, py + h + 0.5, h - 1, h - 1);
  ctx.strokeRect(px + h + 0.5, py + h + 0.5, h - 1, h - 1);

  // Hierba entre juntas / chicle / grieta
  if (((tx * 5 + ty * 9) % 7) === 0) {
    ctx.fillStyle = "rgba(60,100,50,0.4)";
    ctx.fillRect(px + h - 1, py + 8, 2, 12);
  }
  if (((tx + ty * 4) % 11) === 0) {
    ctx.fillStyle = "rgba(160,80,120,0.35)";
    ctx.beginPath();
    ctx.arc(px + 18, py + 22, 2.2, 0, Math.PI * 2);
    ctx.fill();
  }
  if (((tx * 9 + ty) % 17) === 0) {
    ctx.strokeStyle = "rgba(40,38,36,0.45)";
    ctx.beginPath();
    ctx.moveTo(px + 6, py + 10);
    ctx.lineTo(px + 20, py + 28);
    ctx.lineTo(px + 38, py + 34);
    ctx.stroke();
  }

  // Bordillo oscuro hacia la calle
  ctx.fillStyle = "rgba(30,30,32,0.45)";
  if (neighborTile(game, tx, ty + 1) === TILE.ROAD || neighborTile(game, tx, ty + 1) === TILE.CROSSWALK) {
    ctx.fillRect(px, py + TILE_PX - 5, TILE_PX, 5);
  }
  if (neighborTile(game, tx, ty - 1) === TILE.ROAD || neighborTile(game, tx, ty - 1) === TILE.CROSSWALK) {
    ctx.fillRect(px, py, TILE_PX, 4);
  }
  if (neighborTile(game, tx - 1, ty) === TILE.ROAD || neighborTile(game, tx - 1, ty) === TILE.CROSSWALK) {
    ctx.fillRect(px, py, 4, TILE_PX);
  }
  if (neighborTile(game, tx + 1, ty) === TILE.ROAD || neighborTile(game, tx + 1, ty) === TILE.CROSSWALK) {
    ctx.fillRect(px + TILE_PX - 4, py, 4, TILE_PX);
  }

  ctx.fillStyle = "rgba(200,195,185,0.22)";
  ctx.fillRect(px, py, TILE_PX, 2);
}

function drawWater(ctx, game, tx, ty, px, py, time) {
  const g = ctx.createLinearGradient(px, py, px + TILE_PX, py + TILE_PX);
  g.addColorStop(0, "#2f7078");
  g.addColorStop(0.45, "#1c5862");
  g.addColorStop(1, "#123e48");
  ctx.fillStyle = g;
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);

  // Orilla de piedra si toca acera/muelle
  const bank = "rgba(90,88,82,0.85)";
  if (neighborTile(game, tx, ty - 1) !== TILE.WATER && neighborTile(game, tx, ty - 1) !== TILE.ROAD) {
    ctx.fillStyle = bank;
    ctx.fillRect(px, py, TILE_PX, 5);
  }
  if (neighborTile(game, tx, ty + 1) !== TILE.WATER && neighborTile(game, tx, ty + 1) !== TILE.ROAD) {
    ctx.fillStyle = bank;
    ctx.fillRect(px, py + TILE_PX - 5, TILE_PX, 5);
  }

  ctx.fillStyle = "rgba(180, 220, 230, 0.14)";
  ctx.fillRect(px + 6, py + 4, 14, TILE_PX - 8);

  ctx.strokeStyle = "rgba(200, 235, 235, 0.42)";
  ctx.lineWidth = 1.5;
  const wave = Math.sin(time * 2.2 + tx * 0.7 + ty * 0.4) * 3;
  ctx.beginPath();
  ctx.moveTo(px + 2, py + 16 + wave);
  ctx.quadraticCurveTo(px + 20, py + 10 + wave, px + 46, py + 18 + wave);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(px + 2, py + 30 + wave * 0.6);
  ctx.quadraticCurveTo(px + 24, py + 26 + wave * 0.6, px + 46, py + 32 + wave * 0.6);
  ctx.stroke();

  if (((tx + ty) % 9) === 0) {
    ctx.fillStyle = "rgba(80,70,40,0.5)";
    ctx.fillRect(px + 18, py + 22 + wave, 6, 3);
  }
  // Reflejo suave
  ctx.fillStyle = "rgba(255,255,255,0.06)";
  ctx.fillRect(px + 20, py + 8 + wave * 0.3, 18, 4);
}

function drawGrass(ctx, tx, ty, px, py) {
  const g = 86 + ((tx * 3 + ty * 5) % 24);
  ctx.fillStyle = `rgb(${38 + (g % 12)},${g},${34 + (g % 10)})`;
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);

  // Parche de tierra
  if (((tx * 5 + ty * 3) % 15) === 0) {
    ctx.fillStyle = "rgba(90,70,40,0.35)";
    ctx.beginPath();
    ctx.ellipse(px + 24, py + 26, 12, 8, 0.2, 0, Math.PI * 2);
    ctx.fill();
  }

  ctx.strokeStyle = "rgba(70,120,55,0.7)";
  ctx.lineWidth = 1.5;
  for (let i = 0; i < 10; i++) {
    const gx = px + 4 + ((tx * 5 + i * 11 + ty * 3) % 40);
    const gy = py + 8 + ((ty * 7 + i * 9) % 32);
    ctx.beginPath();
    ctx.moveTo(gx, gy + 7);
    ctx.lineTo(gx + ((i % 3) - 1), gy);
    ctx.stroke();
  }
  if (((tx + ty * 2) % 11) === 0) {
    ctx.fillStyle = "#c8a050";
    ctx.beginPath();
    ctx.arc(px + 20, py + 18, 2, 0, Math.PI * 2);
    ctx.fill();
  }
  if (((tx * 2 + ty) % 13) === 0) {
    ctx.fillStyle = "#c06070";
    ctx.beginPath();
    ctx.arc(px + 32, py + 28, 2, 0, Math.PI * 2);
    ctx.fill();
  }
  if (((tx + ty * 5) % 17) === 0) {
    ctx.fillStyle = "#d8c060";
    ctx.beginPath();
    ctx.arc(px + 12, py + 34, 1.8, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawParking(ctx, tx, ty, px, py) {
  const n = ((tx + ty) % 4);
  ctx.fillStyle = `rgb(${72 + n},${74 + n},${80 + n})`;
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
  ctx.strokeStyle = "rgba(230,230,220,0.7)";
  ctx.lineWidth = 2;
  ctx.strokeRect(px + 5, py + 3, TILE_PX - 10, TILE_PX - 6);
  // Flecha de plaza
  ctx.fillStyle = "rgba(220,220,210,0.35)";
  ctx.beginPath();
  ctx.moveTo(px + TILE_PX / 2, py + 14);
  ctx.lineTo(px + TILE_PX / 2 + 6, py + 22);
  ctx.lineTo(px + TILE_PX / 2 - 6, py + 22);
  ctx.fill();
  ctx.fillStyle = "rgba(220,220,210,0.5)";
  ctx.font = "600 10px Sora, sans-serif";
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

  const furn = game.world.interiors.get(`${tx},${ty}`);
  const fType = furnitureType(furn);
  const searched = typeof furn === "object" && furn?.searched;
  if (fType) drawFurniturePiece(ctx, fType, searched, px, py, b?.accent);

  if (b && phaseIsDayish(phaseNameSafe(game))) {
    ctx.fillStyle = "rgba(255, 230, 160, 0.07)";
    ctx.fillRect(px, py, TILE_PX, TILE_PX);
  }
}

function drawInteriorFloor(ctx, tile, px, py, b, floorStyle, tx, ty) {
  if (tile === TILE.BASE) {
    ctx.fillStyle = "#4f6a40";
    ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
    return;
  }
  if (floorStyle === "tile") {
    const base = b ? shade(b.facade, 42) : "#8a8078";
    ctx.fillStyle = base;
    ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
    const alt = ((tx + ty) & 1) === 0;
    ctx.fillStyle = alt ? "rgba(255,255,255,0.06)" : "rgba(0,0,0,0.08)";
    ctx.fillRect(px + 1, py + 1, TILE_PX / 2 - 1, TILE_PX / 2 - 1);
    ctx.fillRect(px + TILE_PX / 2 + 1, py + TILE_PX / 2 + 1, TILE_PX / 2 - 1, TILE_PX / 2 - 1);
    ctx.strokeStyle = "rgba(40,30,25,0.2)";
    ctx.strokeRect(px + 0.5, py + 0.5, TILE_PX - 1, TILE_PX - 1);
    ctx.beginPath();
    ctx.moveTo(px + TILE_PX / 2, py);
    ctx.lineTo(px + TILE_PX / 2, py + TILE_PX);
    ctx.moveTo(px, py + TILE_PX / 2);
    ctx.lineTo(px + TILE_PX, py + TILE_PX / 2);
    ctx.stroke();
  } else if (floorStyle === "concrete") {
    ctx.fillStyle = b ? shade(b.facade, 28) : "#6a6864";
    ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
    ctx.fillStyle = "rgba(0,0,0,0.08)";
    ctx.fillRect(px + 4, py + 8, 14, 3);
    ctx.fillRect(px + 22, py + 28, 18, 2);
  } else if (floorStyle === "office") {
    ctx.fillStyle = b ? shade(b.facade, 38) : "#6a6e74";
    ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
    ctx.strokeStyle = "rgba(30,35,40,0.25)";
    ctx.beginPath();
    ctx.moveTo(px, py + TILE_PX);
    ctx.lineTo(px + TILE_PX, py);
    ctx.stroke();
    ctx.fillStyle = "rgba(255,255,255,0.04)";
    ctx.fillRect(px + 2, py + 2, TILE_PX - 4, 3);
  } else {
    const base = b ? shade(b.facade, 32) : "#6e5a46";
    ctx.fillStyle = base;
    ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
    ctx.strokeStyle = "rgba(40,30,20,0.28)";
    ctx.lineWidth = 1;
    for (let i = 1; i < 4; i++) {
      ctx.beginPath();
      ctx.moveTo(px, py + i * 12);
      ctx.lineTo(px + TILE_PX, py + i * 12);
      ctx.stroke();
    }
    ctx.strokeStyle = "rgba(255,220,160,0.05)";
    ctx.beginPath();
    ctx.moveTo(px + 6, py + 4);
    ctx.lineTo(px + 40, py + 8);
    ctx.stroke();
  }
}

function drawFloorDecor(ctx, dec, px, py) {
  if (dec.kind === "rug") {
    const c = dec.color || "#6a3a3a";
    const inset = dec.variant === 2 ? 10 : 4;
    ctx.globalAlpha = 0.82;
    ctx.fillStyle = c;
    ctx.fillRect(px + inset, py + inset, TILE_PX - inset * 2, TILE_PX - inset * 2);
    ctx.globalAlpha = 1;
    ctx.strokeStyle = shade(c, 28);
    ctx.lineWidth = 2;
    ctx.strokeRect(px + inset + 1, py + inset + 1, TILE_PX - inset * 2 - 2, TILE_PX - inset * 2 - 2);
    if (dec.variant === 1) {
      ctx.strokeStyle = shade(c, -25);
      ctx.lineWidth = 1;
      ctx.strokeRect(px + inset + 4, py + inset + 4, TILE_PX - inset * 2 - 8, TILE_PX - inset * 2 - 8);
      ctx.fillStyle = shade(c, 18);
      ctx.globalAlpha = 0.35;
      ctx.fillRect(px + TILE_PX / 2 - 4, py + TILE_PX / 2 - 4, 8, 8);
      ctx.globalAlpha = 1;
    }
  } else if (dec.kind === "mat") {
    const c = dec.color || "#4a4038";
    ctx.fillStyle = c;
    ctx.fillRect(px + 8, py + 14, 32, 20);
    ctx.strokeStyle = shade(c, 20);
    ctx.strokeRect(px + 8, py + 14, 32, 20);
    ctx.fillStyle = "rgba(255,255,255,0.08)";
    for (let i = 0; i < 4; i++) ctx.fillRect(px + 10 + i * 7, py + 16, 4, 16);
  }
}

function drawFurniturePiece(ctx, fType, searched, px, py, accent) {
  if (fType === "table") {
    ctx.fillStyle = "rgba(0,0,0,0.22)";
    ctx.fillRect(px + 10, py + 30, 28, 5);
    ctx.fillStyle = "#6a4a32";
    ctx.fillRect(px + 9, py + 14, 30, 18);
    ctx.fillStyle = "#9a7a52";
    ctx.fillRect(px + 11, py + 16, 26, 5);
    ctx.fillStyle = "#3a2818";
    ctx.fillRect(px + 11, py + 32, 4, 8);
    ctx.fillRect(px + 33, py + 32, 4, 8);
    ctx.fillStyle = "#c8b090";
    ctx.beginPath();
    ctx.arc(px + 24, py + 24, 4, 0, Math.PI * 2);
    ctx.fill();
  } else if (fType === "desk") {
    ctx.fillStyle = "rgba(0,0,0,0.22)";
    ctx.fillRect(px + 6, py + 32, 36, 5);
    ctx.fillStyle = "#4a3a30";
    ctx.fillRect(px + 5, py + 16, 38, 18);
    ctx.fillStyle = "#7a6a58";
    ctx.fillRect(px + 7, py + 18, 34, 4);
    ctx.fillStyle = searched ? "#2a2218" : "#3a3028";
    ctx.fillRect(px + 10, py + 24, 12, 8);
    ctx.fillRect(px + 26, py + 24, 12, 8);
    if (!searched) {
      ctx.fillStyle = "#e8e0d0";
      ctx.fillRect(px + 14, py + 12, 14, 6);
      ctx.fillStyle = "#4080a0";
      ctx.fillRect(px + 30, py + 11, 6, 5);
    }
  } else if (fType === "chair") {
    ctx.fillStyle = "rgba(0,0,0,0.18)";
    ctx.fillRect(px + 14, py + 30, 20, 4);
    ctx.fillStyle = "#5a4030";
    ctx.fillRect(px + 15, py + 20, 18, 12);
    ctx.fillStyle = accent ? shade(accent, 10) : "#7a5a48";
    ctx.fillRect(px + 15, py + 10, 18, 12);
    ctx.fillStyle = "#3a2818";
    ctx.fillRect(px + 16, py + 32, 3, 8);
    ctx.fillRect(px + 29, py + 32, 3, 8);
  } else if (fType === "sofa") {
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.fillRect(px + 4, py + 34, 40, 5);
    const cloth = accent || "#5a3a48";
    ctx.fillStyle = cloth;
    ctx.fillRect(px + 4, py + 14, 40, 22);
    ctx.fillStyle = shade(cloth, 18);
    ctx.fillRect(px + 6, py + 16, 12, 14);
    ctx.fillRect(px + 30, py + 16, 12, 14);
    ctx.fillStyle = shade(cloth, -15);
    ctx.fillRect(px + 4, py + 10, 40, 6);
  } else if (fType === "bed") {
    ctx.fillStyle = "rgba(0,0,0,0.28)";
    ctx.fillRect(px + 5, py + 38, 38, 5);
    ctx.fillStyle = "#3a2a28";
    ctx.fillRect(px + 5, py + 8, 38, 32);
    ctx.fillStyle = "#5a4038";
    ctx.fillRect(px + 5, py + 6, 38, 8);
    ctx.fillStyle = "#e8e0d4";
    ctx.fillRect(px + 8, py + 12, 32, 10);
    ctx.fillStyle = "#d0c8ba";
    ctx.fillRect(px + 10, py + 14, 12, 6);
    const quilt = accent || "#7a3a4a";
    ctx.fillStyle = quilt;
    ctx.fillRect(px + 8, py + 24, 32, 14);
    ctx.fillStyle = shade(quilt, 20);
    ctx.fillRect(px + 8, py + 24, 32, 3);
    ctx.strokeStyle = shade(quilt, -20);
    ctx.beginPath();
    ctx.moveTo(px + 24, py + 24);
    ctx.lineTo(px + 24, py + 38);
    ctx.stroke();
  } else if (fType === "nightstand") {
    ctx.fillStyle = "rgba(0,0,0,0.2)";
    ctx.fillRect(px + 12, py + 34, 24, 4);
    ctx.fillStyle = searched ? "#4a3a30" : "#6a5040";
    ctx.fillRect(px + 12, py + 16, 24, 20);
    ctx.fillStyle = "#8a6a48";
    ctx.fillRect(px + 12, py + 14, 24, 4);
    ctx.fillStyle = searched ? "#2a2018" : "#c8a868";
    ctx.fillRect(px + 21, py + 24, 6, 3);
    ctx.fillStyle = "#d8c898";
    ctx.fillRect(px + 22, py + 6, 4, 8);
    ctx.beginPath();
    ctx.moveTo(px + 18, py + 8);
    ctx.lineTo(px + 30, py + 8);
    ctx.lineTo(px + 24, py + 2);
    ctx.closePath();
    ctx.fill();
  } else if (fType === "shelf") {
    ctx.fillStyle = "#4a3a2a";
    ctx.fillRect(px + 6, py + 6, 36, 36);
    ctx.fillStyle = "#6a5040";
    ctx.fillRect(px + 8, py + 10, 32, 6);
    ctx.fillRect(px + 8, py + 22, 32, 6);
    ctx.fillRect(px + 8, py + 34, 32, 6);
    if (!searched) {
      ctx.fillStyle = "#a05040";
      ctx.fillRect(px + 12, py + 11, 6, 4);
      ctx.fillStyle = "#4080a0";
      ctx.fillRect(px + 22, py + 23, 8, 4);
      ctx.fillStyle = "#c8a060";
      ctx.fillRect(px + 14, py + 35, 10, 4);
    }
  } else if (fType === "crate") {
    ctx.fillStyle = searched ? "#5a4828" : "#7a5a30";
    ctx.fillRect(px + 12, py + 14, 24, 22);
    ctx.strokeStyle = "#3a2a18";
    ctx.strokeRect(px + 12, py + 14, 24, 22);
    ctx.beginPath();
    ctx.moveTo(px + 12, py + 25);
    ctx.lineTo(px + 36, py + 25);
    ctx.stroke();
    if (searched) {
      ctx.fillStyle = "rgba(20,15,10,0.45)";
      ctx.fillRect(px + 14, py + 16, 20, 10);
    }
  } else if (fType === "cabinet") {
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.fillRect(px + 9, py + 40, 30, 5);
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
      ctx.fillStyle = "rgba(255, 210, 120, 0.35)";
      ctx.fillRect(px + 12, py + 10, 8, 6);
    }
  } else if (fType === "drawer") {
    ctx.fillStyle = "rgba(0,0,0,0.22)";
    ctx.fillRect(px + 10, py + 38, 28, 5);
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
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.fillRect(px + 11, py + 40, 26, 4);
    ctx.fillStyle = searched ? "#5a6068" : "#8a9098";
    ctx.fillRect(px + 10, py + 4, 28, 38);
    ctx.fillStyle = searched ? "#3a4048" : "#6a7078";
    ctx.fillRect(px + 12, py + 6, 24, 22);
    ctx.fillRect(px + 12, py + 30, 24, 10);
    ctx.fillStyle = "#2a2e34";
    ctx.fillRect(px + 32, py + 14, 3, 10);
    if (!searched) {
      ctx.fillStyle = "rgba(180, 220, 255, 0.2)";
      ctx.fillRect(px + 14, py + 8, 20, 8);
    } else {
      ctx.fillStyle = "rgba(20,20,24,0.5)";
      ctx.fillRect(px + 14, py + 8, 20, 18);
    }
  } else if (fType === "locker") {
    ctx.fillStyle = searched ? "#3a4a3a" : "#4a5a48";
    ctx.fillRect(px + 12, py + 4, 24, 40);
    ctx.strokeStyle = "#2a3228";
    ctx.strokeRect(px + 12, py + 4, 24, 40);
    ctx.beginPath();
    ctx.moveTo(px + 24, py + 4);
    ctx.lineTo(px + 24, py + 44);
    ctx.stroke();
    ctx.fillStyle = searched ? "#1a2018" : "#c8b060";
    ctx.fillRect(px + 20, py + 22, 4, 6);
  } else if (fType === "counter") {
    ctx.fillStyle = "rgba(0,0,0,0.22)";
    ctx.fillRect(px + 4, py + 34, 40, 5);
    ctx.fillStyle = "#5a4a3a";
    ctx.fillRect(px + 4, py + 18, 40, 18);
    ctx.fillStyle = searched ? "#3a3028" : "#8a7a68";
    ctx.fillRect(px + 4, py + 14, 40, 6);
    ctx.fillStyle = "#c8b090";
    ctx.fillRect(px + 8, py + 10, 10, 4);
    if (!searched) {
      ctx.fillStyle = "#a05040";
      ctx.fillRect(px + 22, py + 8, 8, 6);
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

function drawBuildingRoof(ctx, b, camX, camY, phase, entered, litWindows = []) {
  const px = b.x0 * TILE_PX - camX;
  const py = b.y0 * TILE_PX - camY;
  const bw = (b.x1 - b.x0 + 1) * TILE_PX;
  const bh = (b.y1 - b.y0 + 1) * TILE_PX;
  const t = TILE_PX;
  const style = b.style || "block";
  const floors = b.floors || 2;
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
      ctx.font = "700 10px Sora, sans-serif";
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

  // Ventanas: casi todas apagadas; solo alguna aislada brilla
  const pushWin = (wx, wy, lit) => {
    drawWindow(ctx, wx, wy, lit, style);
    if (lit) litWindows.push({ x: wx + 7, y: wy + 8 });
  };

  for (let x = b.x0 + 1; x < b.x1; x++) {
    const wx = x * TILE_PX - camX + 12;
    const litTop = phase.night && ((x * 3 + b.y0 * 5) % 13) === 0;
    const litBot = phase.night && ((x * 5 + b.y1 * 3) % 17) === 1;
    if (style === "residential") {
      ctx.fillStyle = shade(b.facade, -32);
      ctx.fillRect(wx - 2, py + 24, 18, 4);
      ctx.strokeStyle = "#9aa0a8";
      ctx.beginPath();
      ctx.moveTo(wx - 1, py + 18);
      ctx.lineTo(wx - 1, py + 24);
      ctx.moveTo(wx + 15, py + 18);
      ctx.lineTo(wx + 15, py + 24);
      ctx.stroke();
    }
    pushWin(wx, py + 10, litTop);
    pushWin(wx, py + bh - t + 10, litBot);
  }
  for (let y = b.y0 + 1; y < b.y1; y++) {
    const wy = y * TILE_PX - camY + 10;
    pushWin(px + 12, wy, phase.night && ((y * 3 + b.x0) % 13) === 0);
    pushWin(px + bw - t + 12, wy, phase.night && ((y * 5 + b.x1) % 17) === 3);
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

      const cols = Math.max(1, b.x1 - b.x0 - 2);
      const rows = Math.max(1, b.y1 - b.y0 - 2);
      for (let row = 0; row < rows; row++) {
        for (let col = 0; col < cols; col++) {
          const wx = roofX + 8 + col * ((roofW - 12) / cols);
          const wy = roofY + 8 + row * ((roofH - 12) / rows);
          const ww = Math.max(4, (roofW - 12) / cols - 10);
          const wh = Math.max(4, (roofH - 12) / rows - 10);
          const lit = phase.night && (col + row * 3 + b.x0) % 11 === 0;
          ctx.fillStyle = lit ? "rgba(255, 215, 130, 0.45)" : "rgba(18, 28, 38, 0.6)";
          ctx.fillRect(wx, wy, ww, wh);
          // Casi ningún lucernario aporta glow exterior
          if (lit && (col + row) % 4 === 0) litWindows.push({ x: wx + ww / 2, y: wy + wh / 2 });
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
        ctx.font = "600 12px Sora, sans-serif";
        ctx.textAlign = "left";
        ctx.fillText(b.name, roofX + 10, roofY + 20);
      }
    }
  } else {
    // Interior: luz cálida ambiental
    if (phase.night) {
      ctx.fillStyle = "rgba(255, 210, 140, 0.08)";
      ctx.fillRect(px + t, py + t, bw - t * 2, bh - t * 2);
    }
    ctx.fillStyle = "rgba(255,255,255,0.6)";
    ctx.font = "600 11px Sora, sans-serif";
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
  ctx.font = "600 8px Sora, sans-serif";
  ctx.textAlign = "center";
  ctx.fillText(String((b.x0 + b.y0) % 90 + 10), doorPx + TILE_PX / 2, doorPy + 7);
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
  ctx.fillStyle = lit ? "rgba(255, 220, 140, 0.95)" : "rgba(22, 34, 48, 0.85)";
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
    ctx.save();
    ctx.translate(px, py);
    if (p.rot) ctx.rotate(Math.PI / 2);
    ctx.fillStyle = "rgba(0,0,0,0.35)";
    ctx.beginPath();
    ctx.ellipse(0, 4, 18, 8, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = p.wreck ? shade(p.color || "#4a3030", -40) : (p.color || "#4a3030");
    roundRect(ctx, -18, -10, 36, 18, 3);
    ctx.fill();
    ctx.fillStyle = p.wreck ? "rgba(80,90,100,0.5)" : "rgba(160,200,220,0.6)";
    roundRect(ctx, -8, -8, 14, 12, 2);
    ctx.fill();
    ctx.fillStyle = "#111";
    ctx.fillRect(-14, -12, 7, 4);
    ctx.fillRect(8, -12, 7, 4);
    ctx.fillRect(-14, 9, 7, 4);
    ctx.fillRect(8, 9, 7, 4);
    if (p.wreck) {
      ctx.strokeStyle = "rgba(200,200,200,0.5)";
      ctx.beginPath();
      ctx.moveTo(-10, -6);
      ctx.lineTo(6, 4);
      ctx.moveTo(8, -4);
      ctx.lineTo(-4, 6);
      ctx.stroke();
    }
    // luces
    ctx.fillStyle = phase.night ? "#ffe08a" : "#c8b060";
    ctx.fillRect(15, -4, 3, 5);
    ctx.fillStyle = "#a03030";
    ctx.fillRect(-18, -4, 3, 5);
    ctx.restore();
  } else if (p.type === "tree") {
    const r = p.r || 12;
    ctx.fillStyle = "rgba(0,0,0,0.28)";
    ctx.beginPath();
    ctx.ellipse(px, py + 10, r * 0.75, r * 0.35, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#5a3a20";
    ctx.fillRect(px - 3, py + 2, 6, 14);
    ctx.fillStyle = p.tone ? "#3a6a32" : "#2f4a28";
    ctx.beginPath();
    ctx.arc(px, py - 2, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = p.tone ? "#5a8a48" : "#4a7a3a";
    ctx.beginPath();
    ctx.arc(px - 5, py - 5, r * 0.55, 0, Math.PI * 2);
    ctx.arc(px + 6, py - 2, r * 0.45, 0, Math.PI * 2);
    ctx.fill();
  } else if (p.type === "lamp") {
    // Farola de calle: poste + farol
    ctx.fillStyle = "rgba(0,0,0,0.28)";
    ctx.beginPath();
    ctx.ellipse(px, py + 12, 7, 3.2, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#2a2c30";
    ctx.fillRect(px - 2, py - 4, 4, 18);
    ctx.fillStyle = "#3a3c42";
    ctx.fillRect(px - 3, py + 10, 6, 3);
    // Brazo
    ctx.fillStyle = "#1e2024";
    ctx.fillRect(px - 1, py - 14, 12, 3);
    ctx.fillRect(px + 9, py - 14, 3, 6);
    // Farol
    const lit = phase.night || phase.light < 0.55;
    ctx.fillStyle = lit ? (phase.rain > 0.25 ? "#e8f0ff" : "#ffe6a0") : "#9a9aa0";
    ctx.beginPath();
    ctx.moveTo(px + 6, py - 8);
    ctx.lineTo(px + 15, py - 8);
    ctx.lineTo(px + 13, py - 2);
    ctx.lineTo(px + 8, py - 2);
    ctx.closePath();
    ctx.fill();
    if (lit) {
      ctx.fillStyle = phase.rain > 0.25 ? "rgba(180, 205, 240, 0.2)" : "rgba(255, 220, 140, 0.18)";
      ctx.beginPath();
      ctx.arc(px + 10, py + 4, 22, 0, Math.PI * 2);
      ctx.fill();
    }
  } else if (p.type === "dumpster") {
    ctx.fillStyle = "rgba(0,0,0,0.3)";
    ctx.fillRect(px - 11, py - 4, 24, 14);
    ctx.fillStyle = p.color || "#2f5a38";
    roundRect(ctx, px - 13, py - 10, 26, 18, 2);
    ctx.fill();
    ctx.fillStyle = shade(p.color || "#2f5a38", -25);
    ctx.fillRect(px - 13, py - 12, 26, 5);
    ctx.fillStyle = "rgba(255,255,255,0.15)";
    ctx.fillRect(px - 4, py - 6, 8, 3);
  } else if (p.type === "bench") {
    ctx.save();
    if (p.rot) {
      ctx.translate(px, py);
      ctx.rotate(Math.PI / 2);
      px = 0;
      py = 0;
    }
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.fillRect(px - 14, py + 2, 28, 6);
    ctx.fillStyle = "#6a4a32";
    ctx.fillRect(px - 15, py - 5, 30, 7);
    ctx.fillStyle = "#4a3220";
    ctx.fillRect(px - 15, py - 10, 30, 4);
    ctx.fillRect(px - 13, py + 2, 4, 7);
    ctx.fillRect(px + 9, py + 2, 4, 7);
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
    ctx.font = "600 8px Sora, sans-serif";
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
    ctx.fillStyle = "rgba(180,60,140,0.55)";
    ctx.font = "700 11px Sora, sans-serif";
    ctx.fillText(p.text || "NIEBLA", px - 16, py);
    ctx.fillStyle = "rgba(60,160,200,0.45)";
    ctx.fillText(p.text ? "" : "norte", px - 10, py + 10);
  } else if (p.type === "railing") {
    ctx.strokeStyle = "#6a7078";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(px - 12, py);
    ctx.lineTo(px + 12, py);
    ctx.moveTo(px - 8, py);
    ctx.lineTo(px - 8, py + 8);
    ctx.moveTo(px + 8, py);
    ctx.lineTo(px + 8, py + 8);
    ctx.moveTo(px, py);
    ctx.lineTo(px, py + 8);
    ctx.stroke();
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
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.fillRect(px - 6, py + 2, 12, 5);
    ctx.fillStyle = "#3a4a3a";
    roundRect(ctx, px - 7, py - 8, 14, 14, 2);
    ctx.fill();
    ctx.fillStyle = "#2a3a2a";
    ctx.fillRect(px - 7, py - 10, 14, 3);
    ctx.strokeStyle = "rgba(200,200,180,0.25)";
    ctx.strokeRect(px - 5, py - 5, 10, 8);
  } else if (p.type === "planter") {
    ctx.fillStyle = "rgba(0,0,0,0.22)";
    ctx.fillRect(px - 10, py + 4, 20, 6);
    ctx.fillStyle = "#6a4a32";
    ctx.fillRect(px - 11, py - 2, 22, 10);
    ctx.fillStyle = "#3a2818";
    ctx.fillRect(px - 9, py - 4, 18, 4);
    ctx.fillStyle = p.tone ? "#4a7a3a" : "#3a6a48";
    ctx.beginPath();
    ctx.arc(px - 4, py - 6, 5, 0, Math.PI * 2);
    ctx.arc(px + 4, py - 7, 6, 0, Math.PI * 2);
    ctx.arc(px, py - 10, 4, 0, Math.PI * 2);
    ctx.fill();
    if (p.tone) {
      ctx.fillStyle = "#c05060";
      ctx.beginPath();
      ctx.arc(px + 3, py - 9, 1.5, 0, Math.PI * 2);
      ctx.fill();
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
    ctx.font = "700 8px Sora, sans-serif";
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
    ctx.font = "600 8px Sora, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(`C/ ${(p.label || "LUNA").slice(0, 8)}`, px, py - 13);
    ctx.fillText(`C/ ${(p.label2 || "SOL").slice(0, 8)}`, px, py - 2);
  } else if (p.type === "boat") {
    ctx.fillStyle = "rgba(0,0,0,0.2)";
    ctx.beginPath();
    ctx.ellipse(px, py + 4, 16, 5, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = p.wreck ? "#4a4038" : "#6a5040";
    ctx.beginPath();
    ctx.moveTo(px - 16, py);
    ctx.quadraticCurveTo(px, py + 10, px + 16, py);
    ctx.quadraticCurveTo(px, py - 8, px - 16, py);
    ctx.fill();
    if (!p.wreck) {
      ctx.fillStyle = "#d8d0c0";
      ctx.fillRect(px - 4, py - 10, 3, 10);
      ctx.fillStyle = "rgba(200,60,50,0.7)";
      ctx.beginPath();
      ctx.moveTo(px - 1, py - 10);
      ctx.lineTo(px + 10, py - 6);
      ctx.lineTo(px - 1, py - 2);
      ctx.fill();
    } else {
      ctx.strokeStyle = "rgba(180,180,180,0.4)";
      ctx.beginPath();
      ctx.moveTo(px - 6, py - 2);
      ctx.lineTo(px + 8, py + 2);
      ctx.stroke();
    }
  }
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

function drawBarricade(ctx, px, py) {
  ctx.fillStyle = "#6b4424";
  ctx.fillRect(px + 4, py + 10, TILE_PX - 8, 10);
  ctx.fillRect(px + 4, py + 26, TILE_PX - 8, 10);
  ctx.strokeStyle = "#3a2810";
  ctx.strokeRect(px + 4, py + 10, TILE_PX - 8, 10);
}

function drawDoor(ctx, game, tx, ty, px, py) {
  // Si ya lo dibujó el tejado, reforzar el umbral
  ctx.fillStyle = "#1a1410";
  ctx.fillRect(px + 14, py + 8, 20, TILE_PX - 12);
  ctx.fillStyle = "#b8925a";
  ctx.fillRect(px + 16, py + 10, 16, TILE_PX - 16);
  ctx.fillStyle = "#e0c080";
  ctx.beginPath();
  ctx.arc(px + 28, py + TILE_PX / 2, 2, 0, Math.PI * 2);
  ctx.fill();
}

function drawLoot(ctx, id, px, py, time) {
  const bob = Math.sin(time * 3 + px * 0.02) * 2;
  ctx.save();
  ctx.translate(px, py + bob);
  if (id === "food") {
    ctx.fillStyle = "#c45a3a";
    ctx.fillRect(-7, -5, 14, 10);
  } else if (id === "water") {
    ctx.fillStyle = "#4aa0c8";
    ctx.fillRect(-4, -8, 8, 14);
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
    ctx.fillRect(-7, -7, 14, 14);
    ctx.fillStyle = "#c03030";
    ctx.fillRect(-2, -7, 4, 14);
    ctx.fillRect(-7, -2, 14, 4);
  } else if (id === "bag" || id === "bag_big") {
    ctx.fillStyle = id === "bag_big" ? "#3a5a48" : "#4a3a28";
    ctx.fillRect(-8, -6, 16, 14);
    ctx.fillStyle = "#2a2218";
    ctx.fillRect(-3, -9, 6, 4);
    ctx.strokeStyle = "#c8a060";
    ctx.lineWidth = 1.5;
    ctx.strokeRect(-8, -6, 16, 14);
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

function drawZombie(ctx, px, py, time, z) {
  ctx.save();
  ctx.translate(px, py);
  ctx.fillStyle = "rgba(0,0,0,0.3)";
  ctx.beginPath();
  ctx.ellipse(0, 12, 10, 4, 0, 0, Math.PI * 2);
  ctx.fill();
  const limp = Math.sin(time * 6 + z.x) * 2;
  ctx.fillStyle = "#3a4a34";
  ctx.fillRect(-7, -8, 14, 16);
  ctx.fillStyle = "#6a7a5a";
  ctx.beginPath();
  ctx.arc(0, -14, 6.5, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#8a2020";
  ctx.beginPath();
  ctx.arc(-2.5, -14, 1.5, 0, Math.PI * 2);
  ctx.arc(3, -14, 1.5, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "#2a3228";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(-4, 6);
  ctx.lineTo(-5, 14 + limp);
  ctx.moveTo(4, 6);
  ctx.lineTo(5, 14 - limp);
  ctx.moveTo(-7, -2);
  ctx.lineTo(-13, 4 + limp);
  ctx.moveTo(7, -2);
  ctx.lineTo(12, 3 - limp);
  ctx.stroke();
  ctx.restore();
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
      const fx = px + Math.cos(ang) * 18;
      const fy = py + Math.sin(ang) * 18;
      const g = ctx.createRadialGradient(fx, fy, 0, fx, fy, 16);
      g.addColorStop(0, `rgba(255, 240, 180, ${game.muzzleFlash * 8})`);
      g.addColorStop(1, "rgba(255, 160, 40, 0)");
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(fx, fy, 16, 0, Math.PI * 2);
      ctx.fill();
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

function drawPlayer(ctx, px, py, player, time, game = null) {
  ctx.save();
  ctx.translate(px, py);
  const handDef = itemDef(player.equip?.hand);
  const aimingGun = !!(handDef?.firearm);
  if (aimingGun) {
    ctx.rotate(player.aim || 0);
  } else {
    ctx.scale(player.facing || 1, 1);
  }

  // Sombra
  ctx.fillStyle = "rgba(0,0,0,0.32)";
  ctx.beginPath();
  ctx.ellipse(0, 12, 11, 4, 0, 0, Math.PI * 2);
  ctx.fill();

  const walk = Math.sin(time * 11) * (player.stamina < 100 ? 2 : 0);
  const bodyDef = itemDef(player.equip?.body);
  const wear = bodyDef?.wear || { style: "tee", fill: "#3a4a5a", trim: "#2a343c", accent: "#6a7a88" };
  const bagId = player.equip?.bag;
  const handId = player.equip?.hand;
  const lightId = player.equip?.light;

  // Piernas
  ctx.strokeStyle = "#1e2420";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(-3, 4);
  ctx.lineTo(-4, 13 + walk);
  ctx.moveTo(3, 4);
  ctx.lineTo(4, 13 - walk);
  ctx.stroke();

  // Armas colgadas en el cuerpo (inventario, no la de la mano)
  drawHolsteredWeapons(ctx, player, handId);

  // Mochila detrás del torso
  if (bagId) {
    const big = bagId === "bag_big";
    ctx.fillStyle = big ? "#2a4a3a" : "#3a2e22";
    ctx.fillRect(-14, -9, 7, big ? 15 : 12);
    ctx.strokeStyle = "#c8a060";
    ctx.lineWidth = 1;
    ctx.strokeRect(-14, -9, 7, big ? 15 : 12);
    ctx.fillStyle = "#2a2218";
    ctx.fillRect(-12, -11, 3, 3);
  }

  // Torso según ropa
  drawWornBody(ctx, wear);

  // Linterna / farol al cinto
  if (lightId) {
    if (lightId === "lantern") {
      ctx.fillStyle = "#5a3a18";
      ctx.fillRect(-6, 6, 5, 7);
      ctx.fillStyle = "#ffb84a";
      ctx.beginPath();
      ctx.arc(-3.5, 8, 2, 0, Math.PI * 2);
      ctx.fill();
    } else {
      ctx.fillStyle = "#2a2e34";
      ctx.fillRect(4, 7, 8, 3);
      ctx.fillStyle = "#d8e8ff";
      ctx.fillRect(11, 7, 2, 3);
    }
  }

  // Cabeza
  ctx.fillStyle = "#d2b08a";
  ctx.beginPath();
  ctx.arc(0, -16, 6.5, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#2b2218";
  ctx.beginPath();
  ctx.arc(-3, -19, 3.3, 0, Math.PI * 2);
  ctx.arc(2, -20, 3.5, 0, Math.PI * 2);
  ctx.arc(4, -16, 2.7, 0, Math.PI * 2);
  ctx.fill();
  if (wear.style === "hoodie") {
    ctx.strokeStyle = wear.trim;
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.arc(0, -17, 8, Math.PI * 0.95, Math.PI * 2.05);
    ctx.stroke();
  }

  // Arma en mano (detalle)
  drawHeldWeapon(ctx, handId, time);

  ctx.restore();
}

function drawWornBody(ctx, wear) {
  const { style, fill, trim, accent } = wear;
  ctx.fillStyle = fill;
  if (style === "vest") {
    ctx.fillStyle = "#4a4a52";
    ctx.fillRect(-8, -10, 16, 16);
    ctx.fillStyle = fill;
    ctx.fillRect(-9, -8, 18, 13);
    ctx.fillStyle = trim;
    ctx.fillRect(-7, -6, 5, 8);
    ctx.fillRect(2, -6, 5, 8);
    ctx.fillStyle = accent;
    ctx.fillRect(-2, -4, 4, 6);
  } else if (style === "raincoat") {
    ctx.fillRect(-9, -11, 18, 18);
    ctx.fillStyle = trim;
    ctx.fillRect(-2, -11, 4, 18);
    ctx.fillStyle = accent;
    ctx.fillRect(-9, -11, 18, 3);
  } else if (style === "hoodie") {
    ctx.fillRect(-8, -10, 16, 16);
    ctx.fillStyle = trim;
    ctx.beginPath();
    ctx.moveTo(-6, -10);
    ctx.lineTo(0, -4);
    ctx.lineTo(6, -10);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = accent;
    ctx.fillRect(-3, 2, 6, 3);
  } else if (style === "jacket") {
    ctx.fillRect(-8, -10, 16, 16);
    ctx.fillStyle = trim;
    ctx.fillRect(-2, -10, 4, 16);
    ctx.fillStyle = accent;
    ctx.fillRect(-7, -1, 3, 2);
    ctx.fillRect(4, -1, 3, 2);
  } else if (style === "shirt") {
    ctx.fillRect(-8, -10, 16, 16);
    ctx.fillStyle = trim;
    ctx.fillRect(-8, -10, 16, 3);
    ctx.fillStyle = accent;
    ctx.fillRect(-1, -7, 2, 10);
  } else {
    ctx.fillRect(-8, -10, 16, 16);
    ctx.fillStyle = trim;
    ctx.fillRect(-2, -10, 4, 6);
  }
  // Brazo delantero
  ctx.fillStyle = "#6a3a28";
  ctx.fillRect(-9, -6, 5, 11);
}

function drawHeldWeapon(ctx, hand, time) {
  if (!hand) {
    ctx.strokeStyle = "#d2b08a";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(7, -1);
    ctx.lineTo(10, 2);
    ctx.stroke();
    return;
  }
  const swing = Math.sin(time * 2) * 0.05;
  ctx.save();
  ctx.translate(8, -1);
  ctx.rotate(-0.35 + swing);

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


function drawMinimap(mctx, mini, game) {
  const s = mini.width;
  const world = game.world;
  const scale = s / world.size;
  mctx.clearRect(0, 0, s, s);
  for (let y = 0; y < world.size; y++) {
    for (let x = 0; x < world.size; x++) {
      mctx.fillStyle = TILE_META[world.tiles[y * world.size + x]]?.color || "#222";
      mctx.fillRect(x * scale, y * scale, scale + 0.6, scale + 0.6);
    }
  }
  mctx.fillStyle = "#7dcea0";
  for (const z of game.zombies) mctx.fillRect(z.x * scale - 0.8, z.y * scale - 0.8, 2, 2);
  mctx.fillStyle = "#fff6e0";
  mctx.beginPath();
  mctx.arc(game.player.x * scale, game.player.y * scale, 2.5, 0, Math.PI * 2);
  mctx.fill();
}
