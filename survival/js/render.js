import { TILE, TILE_META } from "./world.js";
import { dayPhase } from "./game.js";

const TILE_PX = 40;

const PALETTE = {
  [TILE.DEEP]: ["#0f2a2e", "#16353a"],
  [TILE.WATER]: ["#2a6469", "#3f8a8f"],
  [TILE.SAND]: ["#b89f72", "#d2c09a"],
  [TILE.GRASS]: ["#4f7a45", "#6b9a58"],
  [TILE.FOREST]: ["#243c28", "#355a3a"],
  [TILE.SWAMP]: ["#33432e", "#455a3c"],
  [TILE.ROCK]: ["#5c5954", "#7a766f"],
  [TILE.RUIN]: ["#6a5e4e", "#8a7a64"],
};

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

  return { ctx, mctx, canvas, miniCanvas, resize, draw: (game) => drawWorld(ctx, mctx, canvas, miniCanvas, game, dpr) };
}

function drawWorld(ctx, mctx, canvas, miniCanvas, game, dpr) {
  const w = canvas.width / dpr;
  const h = canvas.height / dpr;
  const phase = dayPhase(game);
  const camX = game.player.x * TILE_PX - w / 2;
  const camY = game.player.y * TILE_PX - h / 2;

  // Cielo / atmósfera de fondo
  const sky = ctx.createLinearGradient(0, 0, 0, h);
  if (phase.name === "Noche") {
    sky.addColorStop(0, "#0a1218");
    sky.addColorStop(1, "#15241c");
  } else if (phase.name === "Atardecer" || phase.name === "Crepúsculo") {
    sky.addColorStop(0, "#3a2a28");
    sky.addColorStop(0.5, "#6a4a38");
    sky.addColorStop(1, "#1a2418");
  } else {
    sky.addColorStop(0, "#7ea8a0");
    sky.addColorStop(0.55, "#b7c9a8");
    sky.addColorStop(1, "#6f8f62");
  }
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, h);

  const startTX = Math.max(0, Math.floor(camX / TILE_PX) - 1);
  const startTY = Math.max(0, Math.floor(camY / TILE_PX) - 1);
  const endTX = Math.min(game.world.size, Math.ceil((camX + w) / TILE_PX) + 1);
  const endTY = Math.min(game.world.size, Math.ceil((camY + h) / TILE_PX) + 1);

  for (let ty = startTY; ty < endTY; ty++) {
    for (let tx = startTX; tx < endTX; tx++) {
      const tile = game.world.tiles[ty * game.world.size + tx];
      const px = tx * TILE_PX - camX;
      const py = ty * TILE_PX - camY;
      drawTile(ctx, tile, px, py, tx, ty, game.time);
    }
  }

  // Recursos
  for (let ty = startTY; ty < endTY; ty++) {
    for (let tx = startTX; tx < endTX; tx++) {
      const res = game.world.resources.get(`${tx},${ty}`);
      if (!res) continue;
      const px = tx * TILE_PX - camX + TILE_PX / 2;
      const py = ty * TILE_PX - camY + TILE_PX / 2;
      drawResource(ctx, res.id, px, py, game.time);
    }
  }

  // Fogatas
  for (const c of game.camps) {
    const px = c.x * TILE_PX - camX;
    const py = c.y * TILE_PX - camY;
    drawCampfire(ctx, px, py, game.time);
  }

  // Lobos
  for (const wolf of game.wolves) {
    drawWolf(ctx, wolf.x * TILE_PX - camX, wolf.y * TILE_PX - camY, game.time);
  }

  // Jugador Crespo
  drawPlayer(ctx, game.player.x * TILE_PX - camX, game.player.y * TILE_PX - camY, game.player, game.time);

  // Viñeta / luz día-noche
  ctx.fillStyle = `rgba(4, 8, 6, ${1 - phase.light})`;
  ctx.fillRect(0, 0, w, h);

  // Luz de fogatas en la noche
  if (phase.light < 0.7) {
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    for (const c of game.camps) {
      const px = c.x * TILE_PX - camX;
      const py = c.y * TILE_PX - camY;
      const g = ctx.createRadialGradient(px, py, 4, px, py, 110);
      g.addColorStop(0, "rgba(255, 160, 70, 0.35)");
      g.addColorStop(1, "rgba(255, 120, 40, 0)");
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(px, py, 110, 0, Math.PI * 2);
      ctx.fill();
    }
    // linterna suave del jugador
    const ppx = game.player.x * TILE_PX - camX;
    const ppy = game.player.y * TILE_PX - camY;
    const lg = ctx.createRadialGradient(ppx, ppy, 8, ppx, ppy, 90);
    lg.addColorStop(0, "rgba(200, 220, 180, 0.12)");
    lg.addColorStop(1, "rgba(200, 220, 180, 0)");
    ctx.fillStyle = lg;
    ctx.beginPath();
    ctx.arc(ppx, ppy, 90, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  // Flash de daño
  if (game.player.hurtFlash > 0) {
    ctx.fillStyle = `rgba(160, 40, 30, ${game.player.hurtFlash * 0.45})`;
    ctx.fillRect(0, 0, w, h);
  }

  drawMinimap(mctx, miniCanvas, game);
}

function drawTile(ctx, tile, px, py, tx, ty, time) {
  const [c0, c1] = PALETTE[tile];
  const g = ctx.createLinearGradient(px, py, px + TILE_PX, py + TILE_PX);
  g.addColorStop(0, c0);
  g.addColorStop(1, c1);
  ctx.fillStyle = g;
  ctx.fillRect(px, py, TILE_PX + 0.5, TILE_PX + 0.5);

  // Detalle por bioma
  ctx.globalAlpha = 0.22;
  if (tile === TILE.GRASS) {
    ctx.strokeStyle = "#9fca7a";
    for (let i = 0; i < 3; i++) {
      const gx = px + 8 + i * 11 + ((tx * 3 + ty) % 5);
      ctx.beginPath();
      ctx.moveTo(gx, py + 28);
      ctx.lineTo(gx + 2, py + 14);
      ctx.stroke();
    }
  } else if (tile === TILE.FOREST) {
    ctx.fillStyle = "#1a2e1c";
    ctx.beginPath();
    ctx.moveTo(px + 20, py + 6);
    ctx.lineTo(px + 32, py + 28);
    ctx.lineTo(px + 8, py + 28);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "#2a452e";
    ctx.beginPath();
    ctx.moveTo(px + 20, py + 12);
    ctx.lineTo(px + 28, py + 30);
    ctx.lineTo(px + 12, py + 30);
    ctx.closePath();
    ctx.fill();
  } else if (tile === TILE.WATER || tile === TILE.DEEP) {
    ctx.strokeStyle = tile === TILE.WATER ? "#9fd4d0" : "#4a7a80";
    const wave = Math.sin(time * 2 + tx * 0.7 + ty * 0.5) * 3;
    ctx.beginPath();
    ctx.moveTo(px + 4, py + 18 + wave);
    ctx.quadraticCurveTo(px + 20, py + 14 + wave, px + 36, py + 20 + wave);
    ctx.stroke();
  } else if (tile === TILE.ROCK) {
    ctx.fillStyle = "#8d8980";
    ctx.fillRect(px + 10, py + 14, 14, 10);
    ctx.fillRect(px + 20, py + 20, 12, 8);
  } else if (tile === TILE.RUIN) {
    ctx.fillStyle = "#9a8b74";
    ctx.fillRect(px + 8, py + 10, 8, 22);
    ctx.fillRect(px + 22, py + 16, 8, 16);
    ctx.fillRect(px + 12, py + 10, 14, 4);
  } else if (tile === TILE.SWAMP) {
    ctx.fillStyle = "#6a7a4a";
    ctx.beginPath();
    ctx.ellipse(px + 14, py + 22, 6, 3, 0, 0, Math.PI * 2);
    ctx.ellipse(px + 26, py + 18, 5, 2.5, 0, 0, Math.PI * 2);
    ctx.fill();
  } else if (tile === TILE.SAND) {
    ctx.fillStyle = "#e8d7b0";
    for (let i = 0; i < 4; i++) {
      ctx.fillRect(px + 6 + i * 8, py + 12 + ((tx + i + ty) % 7), 2, 2);
    }
  }
  ctx.globalAlpha = 1;
}

function drawResource(ctx, id, px, py, time) {
  const bob = Math.sin(time * 3 + px * 0.01) * 2;
  ctx.save();
  ctx.translate(px, py + bob);
  if (id === "berry") {
    ctx.fillStyle = "#8b2e3a";
    ctx.beginPath();
    ctx.arc(-4, 0, 4, 0, Math.PI * 2);
    ctx.arc(4, 2, 4, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#4f7a45";
    ctx.fillRect(-1, -8, 2, 6);
  } else if (id === "wood") {
    ctx.strokeStyle = "#6b4a28";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(-8, 4);
    ctx.lineTo(8, -4);
    ctx.stroke();
  } else if (id === "stone") {
    ctx.fillStyle = "#8a8680";
    ctx.beginPath();
    ctx.moveTo(-6, 4);
    ctx.lineTo(-2, -5);
    ctx.lineTo(7, -2);
    ctx.lineTo(5, 6);
    ctx.closePath();
    ctx.fill();
  } else if (id === "reed") {
    ctx.strokeStyle = "#9aaa5a";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(0, 8);
    ctx.quadraticCurveTo(4, 0, 0, -8);
    ctx.stroke();
  } else if (id === "flint") {
    ctx.fillStyle = "#3a3a42";
    ctx.beginPath();
    ctx.moveTo(0, -6);
    ctx.lineTo(6, 4);
    ctx.lineTo(-5, 5);
    ctx.closePath();
    ctx.fill();
  }
  ctx.restore();
}

function drawCampfire(ctx, px, py, time) {
  ctx.fillStyle = "#3a2a18";
  ctx.fillRect(px - 10, py + 4, 20, 5);
  const flicker = 0.85 + Math.sin(time * 14) * 0.15;
  const g = ctx.createRadialGradient(px, py - 4, 2, px, py - 4, 18 * flicker);
  g.addColorStop(0, "#fff2a8");
  g.addColorStop(0.4, "#ff8a3a");
  g.addColorStop(1, "rgba(200, 60, 20, 0)");
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(px, py - 4, 18 * flicker, 0, Math.PI * 2);
  ctx.fill();
}

function drawWolf(ctx, px, py, time) {
  ctx.save();
  ctx.translate(px, py);
  ctx.fillStyle = "#1c1c1e";
  ctx.beginPath();
  ctx.ellipse(0, 2, 12, 7, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(10, -2);
  ctx.lineTo(18, -6);
  ctx.lineTo(16, 2);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = "#c44";
  ctx.beginPath();
  ctx.arc(14, -2, 1.5, 0, Math.PI * 2);
  ctx.fill();
  // patas
  ctx.strokeStyle = "#111";
  ctx.lineWidth = 2;
  const leg = Math.sin(time * 10) * 3;
  ctx.beginPath();
  ctx.moveTo(-6, 6);
  ctx.lineTo(-6, 12 + leg);
  ctx.moveTo(4, 6);
  ctx.lineTo(4, 12 - leg);
  ctx.stroke();
  ctx.restore();
}

function drawPlayer(ctx, px, py, player, time) {
  ctx.save();
  ctx.translate(px, py);
  ctx.scale(player.facing, 1);

  // sombra
  ctx.fillStyle = "rgba(0,0,0,0.25)";
  ctx.beginPath();
  ctx.ellipse(0, 10, 10, 4, 0, 0, Math.PI * 2);
  ctx.fill();

  const walk = Math.sin(time * 10) * (player.stamina < 100 ? 1 : 0);

  // piernas
  ctx.strokeStyle = "#2a2e28";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(-3, 2);
  ctx.lineTo(-4, 10 + walk);
  ctx.moveTo(3, 2);
  ctx.lineTo(4, 10 - walk);
  ctx.stroke();

  // torso
  ctx.fillStyle = "#4a5e48";
  ctx.fillRect(-7, -10, 14, 14);
  // capa / chaleco náufrago
  ctx.fillStyle = "#8a5a32";
  ctx.fillRect(-8, -8, 4, 12);

  // cabeza
  ctx.fillStyle = "#d2b08a";
  ctx.beginPath();
  ctx.arc(0, -16, 6, 0, Math.PI * 2);
  ctx.fill();

  // pelo crespo
  ctx.fillStyle = "#2b2218";
  ctx.beginPath();
  ctx.arc(-3, -19, 3.2, 0, Math.PI * 2);
  ctx.arc(2, -20, 3.5, 0, Math.PI * 2);
  ctx.arc(4, -16, 2.8, 0, Math.PI * 2);
  ctx.fill();

  ctx.restore();
}

function drawMinimap(mctx, mini, game) {
  const s = mini.width;
  const world = game.world;
  const scale = s / world.size;
  mctx.clearRect(0, 0, s, s);

  for (let y = 0; y < world.size; y++) {
    for (let x = 0; x < world.size; x++) {
      const t = world.tiles[y * world.size + x];
      mctx.fillStyle = TILE_META[t].color;
      mctx.fillRect(x * scale, y * scale, scale + 0.5, scale + 0.5);
    }
  }

  for (const c of game.camps) {
    mctx.fillStyle = "#ff8a3a";
    mctx.fillRect(c.x * scale - 1, c.y * scale - 1, 3, 3);
  }

  mctx.fillStyle = "#f2f6e8";
  mctx.beginPath();
  mctx.arc(game.player.x * scale, game.player.y * scale, 2.5, 0, Math.PI * 2);
  mctx.fill();

  mctx.strokeStyle = "rgba(215,236,228,0.35)";
  mctx.strokeRect(0.5, 0.5, s - 1, s - 1);
}
