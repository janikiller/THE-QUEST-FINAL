import { TILE, TILE_META, buildingAt } from "./world.js";
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

  // Cielo urbano
  const sky = ctx.createLinearGradient(0, 0, 0, h);
  if (phase.night) {
    sky.addColorStop(0, "#0b1018");
    sky.addColorStop(1, "#1a1410");
  } else if (phase.name.includes("tarde") || phase.name.includes("nochecer")) {
    sky.addColorStop(0, "#4a3028");
    sky.addColorStop(0.5, "#7a4a30");
    sky.addColorStop(1, "#2a2018");
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
    }
  }

  // Tejados (se ocultan si Crespo está dentro, para poder entrar de verdad)
  const inside = buildingAt(game.world, game.player.x, game.player.y);
  const playerTile = tileIndex(game, game.player.x, game.player.y);
  const playerIndoor = TILE_META[playerTile]?.indoor || playerTile === TILE.DOOR;

  for (const b of game.world.buildings) {
    if (b.x1 < x0 - 1 || b.x0 > x1 + 1 || b.y1 < y0 - 1 || b.y0 > y1 + 1) continue;
    const entered = inside === b && playerIndoor;
    drawBuildingRoof(ctx, b, camX, camY, phase, entered);
  }

  // Props (ordenados por Y para profundidad)
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

  // Barricadas / puertas construidas encima
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
  drawPlayer(ctx, game.player.x * TILE_PX - camX, game.player.y * TILE_PX - camY, game.player, game.time);

  // Etiqueta del edificio si estás dentro
  if (inside && playerIndoor) {
    ctx.fillStyle = "rgba(10,12,14,0.72)";
    ctx.fillRect(w / 2 - 100, 18, 200, 30);
    ctx.fillStyle = "#e8e0d0";
    ctx.font = "600 13px Sora, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(`🚪 ${inside.name}`, w / 2, 38);
  }

  // Oscuridad
  ctx.fillStyle = `rgba(5, 7, 10, ${Math.max(0, 1 - phase.light)})`;
  ctx.fillRect(0, 0, w, h);

  if (phase.night) {
    const px = game.player.x * TILE_PX - camX;
    const py = game.player.y * TILE_PX - camY;
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    const g = ctx.createRadialGradient(px, py, 8, px, py, 130);
    g.addColorStop(0, "rgba(230, 210, 150, 0.18)");
    g.addColorStop(1, "rgba(230, 210, 150, 0)");
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(px, py, 130, 0, Math.PI * 2);
    ctx.fill();
    // Farolas
    for (const p of game.world.props) {
      if (p.type !== "lamp") continue;
      const lx = p.x * TILE_PX - camX;
      const ly = p.y * TILE_PX - camY;
      if (lx < -80 || ly < -80 || lx > w + 80 || ly > h + 80) continue;
      const lg = ctx.createRadialGradient(lx, ly, 4, lx, ly, 70);
      lg.addColorStop(0, "rgba(255, 210, 120, 0.22)");
      lg.addColorStop(1, "rgba(255, 210, 120, 0)");
      ctx.fillStyle = lg;
      ctx.beginPath();
      ctx.arc(lx, ly, 70, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  if (game.player.hurtFlash > 0) {
    ctx.fillStyle = `rgba(140, 20, 20, ${game.player.hurtFlash * 0.5})`;
    ctx.fillRect(0, 0, w, h);
  }

  drawMinimap(mctx, mini, game);
}

function tileIndex(game, x, y) {
  return game.world.tiles[Math.floor(y) * game.world.size + Math.floor(x)];
}

function drawGround(ctx, game, tile, tx, ty, px, py, phase) {
  if (tile === TILE.ROAD || tile === TILE.CROSSWALK) {
    drawRoad(ctx, tile, tx, ty, px, py);
    return;
  }
  if (tile === TILE.SIDEWALK) {
    drawSidewalk(ctx, tx, ty, px, py);
    return;
  }
  if (tile === TILE.WATER) {
    drawWater(ctx, tx, ty, px, py, game.time);
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

function drawRoad(ctx, tile, tx, ty, px, py) {
  const n = ((tx * 19 + ty * 11) & 15);
  const shade = 48 + n;
  ctx.fillStyle = `rgb(${shade},${shade + 1},${shade + 4})`;
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);

  ctx.fillStyle = "rgba(255,255,255,0.03)";
  for (let i = 0; i < 5; i++) {
    const sx = px + ((tx * 7 + i * 13 + ty) % 40);
    const sy = py + ((ty * 5 + i * 9) % 40);
    ctx.fillRect(sx, sy, 2, 2);
  }

  if (((tx + ty * 3) % 13) === 0) {
    ctx.fillStyle = "rgba(10,12,14,0.35)";
    ctx.beginPath();
    ctx.ellipse(px + 22, py + 24, 8, 5, 0.4, 0, Math.PI * 2);
    ctx.fill();
  }

  ctx.strokeStyle = "rgba(20,20,22,0.4)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(px + 6 + n, py + 16);
  ctx.lineTo(px + 18 + n, py + 26);
  ctx.lineTo(px + 30, py + 22);
  ctx.stroke();

  ctx.strokeStyle = "rgba(220,220,210,0.35)";
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

  if (tile === TILE.CROSSWALK) {
    ctx.fillStyle = "rgba(235,235,225,0.9)";
    for (let i = 0; i < 5; i++) {
      ctx.fillRect(px + 5, py + 4 + i * 9, TILE_PX - 10, 5);
    }
  } else {
    ctx.strokeStyle = "rgba(230, 200, 70, 0.65)";
    ctx.setLineDash([10, 12]);
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    if (tx % 10 < 2) {
      ctx.moveTo(px + TILE_PX / 2, py + 3);
      ctx.lineTo(px + TILE_PX / 2, py + TILE_PX - 3);
    } else {
      ctx.moveTo(px + 3, py + TILE_PX / 2);
      ctx.lineTo(px + TILE_PX - 3, py + TILE_PX / 2);
    }
    ctx.stroke();
    ctx.setLineDash([]);
  }
}

function drawSidewalk(ctx, tx, ty, px, py) {
  const base = 138 + ((tx + ty) % 5);
  ctx.fillStyle = `rgb(${base},${base - 3},${base - 8})`;
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);

  ctx.strokeStyle = "rgba(50,48,44,0.28)";
  ctx.lineWidth = 1;
  const h = TILE_PX / 2;
  ctx.strokeRect(px + 0.5, py + 0.5, h - 1, h - 1);
  ctx.strokeRect(px + h + 0.5, py + 0.5, h - 1, h - 1);
  ctx.strokeRect(px + 0.5, py + h + 0.5, h - 1, h - 1);
  ctx.strokeRect(px + h + 0.5, py + h + 0.5, h - 1, h - 1);

  if (((tx * 5 + ty * 9) % 7) === 0) {
    ctx.fillStyle = "rgba(60,100,50,0.35)";
    ctx.fillRect(px + h - 1, py + 8, 2, 10);
  }

  ctx.fillStyle = "rgba(30,30,32,0.4)";
  ctx.fillRect(px, py + TILE_PX - 5, TILE_PX, 5);
  ctx.fillStyle = "rgba(200,195,185,0.25)";
  ctx.fillRect(px, py, TILE_PX, 2);
}

function drawWater(ctx, tx, ty, px, py, time) {
  const g = ctx.createLinearGradient(px, py, px + TILE_PX, py + TILE_PX);
  g.addColorStop(0, "#2f7078");
  g.addColorStop(0.5, "#1f5860");
  g.addColorStop(1, "#164850");
  ctx.fillStyle = g;
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);

  ctx.fillStyle = "rgba(180, 220, 230, 0.12)";
  ctx.fillRect(px + 6, py + 4, 14, TILE_PX - 8);

  ctx.strokeStyle = "rgba(200, 235, 235, 0.4)";
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
}

function drawGrass(ctx, tx, ty, px, py) {
  const g = 90 + ((tx * 3 + ty * 5) % 20);
  ctx.fillStyle = `rgb(${40 + (g % 10)},${g},${38 + (g % 8)})`;
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);

  ctx.strokeStyle = "rgba(70,120,55,0.7)";
  ctx.lineWidth = 1.5;
  for (let i = 0; i < 8; i++) {
    const gx = px + 4 + ((tx * 5 + i * 11 + ty * 3) % 40);
    const gy = py + 10 + ((ty * 7 + i * 9) % 30);
    ctx.beginPath();
    ctx.moveTo(gx, gy + 6);
    ctx.lineTo(gx + 1, gy);
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
}

function drawParking(ctx, tx, ty, px, py) {
  ctx.fillStyle = "#4a4c52";
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);
  ctx.strokeStyle = "rgba(230,230,220,0.65)";
  ctx.lineWidth = 2;
  ctx.strokeRect(px + 5, py + 3, TILE_PX - 10, TILE_PX - 6);
  ctx.fillStyle = "rgba(220,220,210,0.45)";
  ctx.font = "600 10px Sora, sans-serif";
  ctx.textAlign = "center";
  ctx.fillText(String(((tx + ty * 3) % 24) + 1), px + TILE_PX / 2, py + TILE_PX / 2 + 3);
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
}

function drawInterior(ctx, game, tile, tx, ty, px, py) {
  const b = buildingAt(game.world, tx + 0.5, ty + 0.5);
  // Suelo con variación por edificio
  const floorBase = tile === TILE.BASE ? "#4f6a40" : b ? shade(b.facade, 35) : "#6e5a46";
  ctx.fillStyle = floorBase;
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);

  // Tablones / baldosas
  ctx.strokeStyle = "rgba(40,30,20,0.22)";
  ctx.lineWidth = 1;
  for (let i = 1; i < 4; i++) {
    ctx.beginPath();
    ctx.moveTo(px, py + i * 12);
    ctx.lineTo(px + TILE_PX, py + i * 12);
    ctx.stroke();
  }
  // Alfombra ocasional
  if (((tx * 3 + ty * 5) % 7) === 0) {
    ctx.fillStyle = "rgba(90, 40, 40, 0.35)";
    ctx.fillRect(px + 8, py + 10, 32, 28);
    ctx.strokeStyle = "rgba(120, 60, 60, 0.4)";
    ctx.strokeRect(px + 8, py + 10, 32, 28);
  }

  if (tile === TILE.BASE) {
    ctx.strokeStyle = "rgba(180, 210, 120, 0.55)";
    ctx.lineWidth = 2;
    ctx.strokeRect(px + 5, py + 5, TILE_PX - 10, TILE_PX - 10);
  }

  const furn = game.world.interiors.get(`${tx},${ty}`);
  if (furn === "table") {
    ctx.fillStyle = "rgba(0,0,0,0.2)";
    ctx.fillRect(px + 11, py + 28, 28, 6);
    ctx.fillStyle = "#5a4030";
    ctx.fillRect(px + 10, py + 12, 28, 18);
    ctx.fillStyle = "#8a6a48";
    ctx.fillRect(px + 12, py + 14, 24, 4);
    ctx.fillStyle = "#3a2818";
    ctx.fillRect(px + 12, py + 30, 4, 8);
    ctx.fillRect(px + 32, py + 30, 4, 8);
  } else if (furn === "shelf") {
    ctx.fillStyle = "#4a3a2a";
    ctx.fillRect(px + 6, py + 6, 36, 36);
    ctx.fillStyle = "#6a5040";
    ctx.fillRect(px + 8, py + 10, 32, 6);
    ctx.fillRect(px + 8, py + 22, 32, 6);
    ctx.fillRect(px + 8, py + 34, 32, 6);
    ctx.fillStyle = "#a05040";
    ctx.fillRect(px + 12, py + 11, 6, 4);
    ctx.fillStyle = "#4080a0";
    ctx.fillRect(px + 22, py + 23, 8, 4);
  } else if (furn === "bed") {
    ctx.fillStyle = "#4a3a50";
    ctx.fillRect(px + 6, py + 8, 36, 32);
    ctx.fillStyle = "#d8d0c0";
    ctx.fillRect(px + 8, py + 10, 32, 12);
    ctx.fillStyle = "#8a4a5a";
    ctx.fillRect(px + 8, py + 24, 32, 14);
  } else if (furn === "crate") {
    ctx.fillStyle = "#7a5a30";
    ctx.fillRect(px + 12, py + 14, 24, 22);
    ctx.strokeStyle = "#3a2a18";
    ctx.strokeRect(px + 12, py + 14, 24, 22);
    ctx.beginPath();
    ctx.moveTo(px + 12, py + 25);
    ctx.lineTo(px + 36, py + 25);
    ctx.stroke();
  }

  // Luz de ventana
  if (b && phaseIsDayish(phaseNameSafe(game))) {
    ctx.fillStyle = "rgba(255, 230, 160, 0.07)";
    ctx.fillRect(px, py, TILE_PX, TILE_PX);
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

function drawBuildingRoof(ctx, b, camX, camY, phase, entered) {
  const px = b.x0 * TILE_PX - camX;
  const py = b.y0 * TILE_PX - camY;
  const bw = (b.x1 - b.x0 + 1) * TILE_PX;
  const bh = (b.y1 - b.y0 + 1) * TILE_PX;
  const t = TILE_PX;

  // Sombra del volumen
  ctx.fillStyle = "rgba(0,0,0,0.3)";
  ctx.fillRect(px + 8, py + 10, bw, bh);

  // Fachada perimetral (muros) con color del edificio
  ctx.fillStyle = shade(b.facade, -15);
  ctx.fillRect(px, py, bw, t);
  ctx.fillRect(px, py + bh - t, bw, t);
  ctx.fillRect(px, py, t, bh);
  ctx.fillRect(px + bw - t, py, t, bh);

  // Detalle de ladrillo / hormigón
  ctx.strokeStyle = "rgba(0,0,0,0.18)";
  ctx.lineWidth = 1;
  for (let i = 1; i < 4; i++) {
    ctx.beginPath();
    ctx.moveTo(px, py + (t / 4) * i);
    ctx.lineTo(px + bw, py + (t / 4) * i);
    ctx.moveTo(px, py + bh - t + (t / 4) * i);
    ctx.lineTo(px + bw, py + bh - t + (t / 4) * i);
    ctx.stroke();
  }

  // Ventanas en fachada
  for (let x = b.x0 + 1; x < b.x1; x++) {
    const wx = x * TILE_PX - camX + 12;
    drawWindow(ctx, wx, py + 10, phase.night && (x + b.y0) % 2 === 0);
    drawWindow(ctx, wx, py + bh - t + 10, phase.night && (x + b.y1) % 2 === 1);
  }
  for (let y = b.y0 + 1; y < b.y1; y++) {
    const wy = y * TILE_PX - camY + 10;
    drawWindow(ctx, px + 12, wy, phase.night && (y + b.x0) % 2 === 0);
    drawWindow(ctx, px + bw - t + 12, wy, phase.night && (y + b.x1) % 2 === 1);
  }

  if (!entered) {
    // Tejado solo sobre el interior (los muros quedan a la vista)
    const roofX = px + t;
    const roofY = py + t;
    const roofW = bw - t * 2;
    const roofH = bh - t * 2;
    if (roofW > 0 && roofH > 0) {
      const roof = ctx.createLinearGradient(roofX, roofY, roofX + roofW, roofY + roofH);
      roof.addColorStop(0, shade(b.facade, 20));
      roof.addColorStop(0.45, shade(b.facade, -8));
      roof.addColorStop(1, shade(b.facade, -40));
      ctx.fillStyle = roof;
      ctx.fillRect(roofX, roofY, roofW, roofH);

      ctx.strokeStyle = "rgba(0,0,0,0.2)";
      for (let i = 1; i < 6; i++) {
        ctx.beginPath();
        ctx.moveTo(roofX, roofY + (roofH / 6) * i);
        ctx.lineTo(roofX + roofW, roofY + (roofH / 6) * i);
        ctx.stroke();
      }
      for (let i = 1; i < 5; i++) {
        ctx.beginPath();
        ctx.moveTo(roofX + (roofW / 5) * i, roofY);
        ctx.lineTo(roofX + (roofW / 5) * i, roofY + roofH);
        ctx.stroke();
      }

      // Claros / lucernarios
      const cols = Math.max(1, b.x1 - b.x0 - 2);
      const rows = Math.max(1, b.y1 - b.y0 - 2);
      for (let row = 0; row < rows; row++) {
        for (let col = 0; col < cols; col++) {
          const wx = roofX + 8 + col * ((roofW - 12) / cols);
          const wy = roofY + 8 + row * ((roofH - 12) / rows);
          const ww = Math.max(4, (roofW - 12) / cols - 10);
          const wh = Math.max(4, (roofH - 12) / rows - 10);
          const lit = phase.night && (col + row + b.x0) % 3 !== 0;
          ctx.fillStyle = lit ? "rgba(255, 215, 130, 0.85)" : "rgba(20, 30, 40, 0.55)";
          ctx.fillRect(wx, wy, ww, wh);
        }
      }

      // Aire acondicionado + antena
      ctx.fillStyle = "#6a6a70";
      ctx.fillRect(roofX + roofW * 0.62, roofY + roofH * 0.2, 18, 12);
      ctx.fillStyle = "#3a3a40";
      ctx.fillRect(roofX + roofW * 0.65, roofY + roofH * 0.12, 3, 12);
      ctx.strokeStyle = "#9a9aa0";
      ctx.beginPath();
      ctx.arc(roofX + roofW * 0.28, roofY + roofH * 0.28, 6, 0, Math.PI * 2);
      ctx.stroke();

      // Letrero en azotea
      if (roofW > 70) {
        ctx.fillStyle = "rgba(0,0,0,0.5)";
        ctx.fillRect(roofX + 6, roofY + 6, Math.min(130, roofW - 12), 18);
        ctx.fillStyle = "#f0e8d8";
        ctx.font = "600 11px Sora, sans-serif";
        ctx.textAlign = "left";
        ctx.fillText(b.name, roofX + 10, roofY + 19);
      }
    }
  } else {
    ctx.fillStyle = "rgba(255,255,255,0.55)";
    ctx.font = "600 11px Sora, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText(b.name, px + t + 6, py + t - 8);
  }

  // Puerta siempre encima (entrada visible)
  const doorPx = b.doorX * TILE_PX - camX;
  const doorPy = b.doorY * TILE_PX - camY;
  ctx.fillStyle = shade(b.facade, -35);
  ctx.fillRect(doorPx, doorPy, TILE_PX, TILE_PX);
  ctx.fillStyle = "#1a1410";
  ctx.fillRect(doorPx + 10, doorPy + 4, 28, TILE_PX - 6);
  ctx.fillStyle = "#b8925a";
  ctx.fillRect(doorPx + 14, doorPy + 8, 20, TILE_PX - 14);
  ctx.fillStyle = "#e0c080";
  ctx.beginPath();
  ctx.arc(doorPx + 28, doorPy + TILE_PX / 2, 2.5, 0, Math.PI * 2);
  ctx.fill();
  // Felpudo / umbral
  ctx.fillStyle = "#3a3028";
  ctx.fillRect(doorPx + 8, doorPy + TILE_PX - 6, 32, 5);
}

function drawWindow(ctx, x, y, lit) {
  ctx.fillStyle = lit ? "rgba(255, 210, 120, 0.9)" : "rgba(30, 45, 60, 0.7)";
  ctx.fillRect(x, y, 14, 16);
  ctx.strokeStyle = "rgba(0,0,0,0.35)";
  ctx.strokeRect(x, y, 14, 16);
  ctx.beginPath();
  ctx.moveTo(x + 7, y);
  ctx.lineTo(x + 7, y + 16);
  ctx.moveTo(x, y + 8);
  ctx.lineTo(x + 14, y + 8);
  ctx.stroke();
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
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.beginPath();
    ctx.ellipse(px, py + 10, 6, 3, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#2e3034";
    ctx.fillRect(px - 2, py - 2, 4, 14);
    ctx.fillStyle = "#1a1a1c";
    ctx.fillRect(px - 5, py - 8, 10, 4);
    ctx.fillStyle = phase.night ? "#ffe08a" : "#d0d0d0";
    ctx.beginPath();
    ctx.arc(px, py - 10, 5, 0, Math.PI * 2);
    ctx.fill();
    if (phase.night) {
      ctx.fillStyle = "rgba(255, 220, 140, 0.12)";
      ctx.beginPath();
      ctx.arc(px, py, 28, 0, Math.PI * 2);
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
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.fillRect(px - 14, py + 2, 28, 6);
    ctx.fillStyle = "#6a4a32";
    ctx.fillRect(px - 15, py - 5, 30, 7);
    ctx.fillStyle = "#4a3220";
    ctx.fillRect(px - 15, py - 10, 30, 4);
    ctx.fillRect(px - 13, py + 2, 4, 7);
    ctx.fillRect(px + 9, py + 2, 4, 7);
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
    ctx.fillStyle = phase.night ? "#ff4040" : "#803030";
    ctx.beginPath();
    ctx.arc(px, py - 13, 2.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#806020";
    ctx.beginPath();
    ctx.arc(px, py - 8, 2.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = phase.night ? "#40c040" : "#306030";
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
    ctx.fillStyle = "rgba(140,60,50,0.85)";
    ctx.beginPath();
    ctx.moveTo(px - 16, py - 4);
    ctx.lineTo(px + 16, py - 4);
    ctx.lineTo(px + 12, py + 6);
    ctx.lineTo(px - 12, py + 6);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = "rgba(0,0,0,0.25)";
    for (let i = -10; i <= 10; i += 5) {
      ctx.beginPath();
      ctx.moveTo(px + i, py - 4);
      ctx.lineTo(px + i * 0.75, py + 6);
      ctx.stroke();
    }
  } else if (p.type === "graffiti") {
    ctx.fillStyle = "rgba(180,60,140,0.55)";
    ctx.font = "700 11px Sora, sans-serif";
    ctx.fillText("NIEBLA", px - 16, py);
    ctx.fillStyle = "rgba(60,160,200,0.45)";
    ctx.fillText("norte", px - 10, py + 10);
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
    ctx.stroke();
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

function drawPlayer(ctx, px, py, player, time) {
  ctx.save();
  ctx.translate(px, py);
  ctx.scale(player.facing, 1);
  ctx.fillStyle = "rgba(0,0,0,0.3)";
  ctx.beginPath();
  ctx.ellipse(0, 12, 11, 4, 0, 0, Math.PI * 2);
  ctx.fill();
  const walk = Math.sin(time * 11) * (player.stamina < 100 ? 2 : 0);
  ctx.strokeStyle = "#1e2420";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(-3, 4);
  ctx.lineTo(-4, 13 + walk);
  ctx.moveTo(3, 4);
  ctx.lineTo(4, 13 - walk);
  ctx.stroke();
  ctx.fillStyle = "#3a4a5a";
  ctx.fillRect(-8, -10, 16, 16);
  ctx.fillStyle = "#6a3a28";
  ctx.fillRect(-9, -6, 5, 12);
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
  ctx.strokeStyle = "#8a9098";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(7, -2);
  ctx.lineTo(15, -8);
  ctx.stroke();
  ctx.restore();
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
