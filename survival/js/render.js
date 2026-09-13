import { TILE, TILE_META } from "./world.js";
import { dayPhase } from "./game.js";

const TILE_PX = 42;

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
      drawWorld(ctx, mctx, canvas, miniCanvas, game, dpr);
    },
  };
}

function drawWorld(ctx, mctx, canvas, miniCanvas, game, dpr) {
  const w = canvas.width / dpr;
  const h = canvas.height / dpr;
  const phase = dayPhase(game);
  const camX = game.player.x * TILE_PX - w / 2;
  const camY = game.player.y * TILE_PX - h / 2;

  const sky = ctx.createLinearGradient(0, 0, 0, h);
  if (phase.night) {
    sky.addColorStop(0, "#0a0e14");
    sky.addColorStop(1, "#1a1512");
  } else if (phase.name === "Atardecer" || phase.name === "Anochecer") {
    sky.addColorStop(0, "#3a2824");
    sky.addColorStop(0.55, "#6a4030");
    sky.addColorStop(1, "#1c1814");
  } else {
    sky.addColorStop(0, "#6a7a82");
    sky.addColorStop(0.5, "#8a8a7e");
    sky.addColorStop(1, "#5a5a52");
  }
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, h);

  const x0 = Math.max(0, Math.floor(camX / TILE_PX) - 1);
  const y0 = Math.max(0, Math.floor(camY / TILE_PX) - 1);
  const x1 = Math.min(game.world.size, Math.ceil((camX + w) / TILE_PX) + 1);
  const y1 = Math.min(game.world.size, Math.ceil((camY + h) / TILE_PX) + 1);

  for (let ty = y0; ty < y1; ty++) {
    for (let tx = x0; tx < x1; tx++) {
      const tile = game.world.tiles[ty * game.world.size + tx];
      drawTile(ctx, tile, tx * TILE_PX - camX, ty * TILE_PX - camY, tx, ty, game.time);
    }
  }

  // Loot
  for (let ty = y0; ty < y1; ty++) {
    for (let tx = x0; tx < x1; tx++) {
      const item = game.world.loot.get(`${tx},${ty}`);
      if (!item) continue;
      drawLoot(ctx, item.id, tx * TILE_PX - camX + TILE_PX / 2, ty * TILE_PX - camY + TILE_PX / 2, game.time);
    }
  }

  // Ghost build preview
  if (game.buildMode) {
    const bx =
      game.buildMode === "claim"
        ? Math.floor(game.player.x)
        : Math.floor(game.player.x + game.player.facing);
    const by = Math.floor(game.player.y);
    ctx.fillStyle = "rgba(210, 180, 90, 0.28)";
    ctx.strokeStyle = "rgba(240, 210, 120, 0.8)";
    ctx.lineWidth = 2;
    ctx.fillRect(bx * TILE_PX - camX + 2, by * TILE_PX - camY + 2, TILE_PX - 4, TILE_PX - 4);
    ctx.strokeRect(bx * TILE_PX - camX + 2, by * TILE_PX - camY + 2, TILE_PX - 4, TILE_PX - 4);
  }

  for (const z of game.zombies) {
    drawZombie(ctx, z.x * TILE_PX - camX, z.y * TILE_PX - camY, game.time, z);
  }

  drawPlayer(ctx, game.player.x * TILE_PX - camX, game.player.y * TILE_PX - camY, game.player, game.time);

  // Night vignette
  ctx.fillStyle = `rgba(4, 6, 8, ${1 - phase.light})`;
  ctx.fillRect(0, 0, w, h);

  if (phase.night) {
    const px = game.player.x * TILE_PX - camX;
    const py = game.player.y * TILE_PX - camY;
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    const g = ctx.createRadialGradient(px, py, 10, px, py, 120);
    g.addColorStop(0, "rgba(220, 200, 140, 0.16)");
    g.addColorStop(1, "rgba(220, 200, 140, 0)");
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(px, py, 120, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  if (game.player.hurtFlash > 0) {
    ctx.fillStyle = `rgba(140, 20, 20, ${game.player.hurtFlash * 0.5})`;
    ctx.fillRect(0, 0, w, h);
  }

  drawMinimap(mctx, miniCanvas, game);
}

function drawTile(ctx, tile, px, py, tx, ty, time) {
  const meta = TILE_META[tile];
  const base = meta?.color || "#333";
  ctx.fillStyle = base;
  ctx.fillRect(px, py, TILE_PX + 0.6, TILE_PX + 0.6);

  ctx.globalAlpha = 0.25;
  if (tile === TILE.ROAD) {
    ctx.strokeStyle = "#cfc87a";
    ctx.setLineDash([6, 8]);
    ctx.beginPath();
    if (tx % 7 <= 1) {
      ctx.moveTo(px + TILE_PX / 2, py + 4);
      ctx.lineTo(px + TILE_PX / 2, py + TILE_PX - 4);
    } else {
      ctx.moveTo(px + 4, py + TILE_PX / 2);
      ctx.lineTo(px + TILE_PX - 4, py + TILE_PX / 2);
    }
    ctx.stroke();
    ctx.setLineDash([]);
  } else if (tile === TILE.WALL) {
    ctx.fillStyle = "#1a1a1c";
    ctx.fillRect(px + 3, py + 3, TILE_PX - 6, TILE_PX - 6);
    ctx.fillStyle = "#4a4a4e";
    ctx.fillRect(px + 8, py + 10, 8, 10);
    ctx.fillRect(px + 22, py + 10, 8, 10);
  } else if (tile === TILE.FLOOR || tile === TILE.BASE) {
    ctx.fillStyle = tile === TILE.BASE ? "#6a8a52" : "#3a322a";
    ctx.fillRect(px + 6, py + 6, TILE_PX - 12, TILE_PX - 12);
    if (tile === TILE.BASE) {
      ctx.strokeStyle = "#b8d48a";
      ctx.strokeRect(px + 10, py + 10, TILE_PX - 20, TILE_PX - 20);
    }
  } else if (tile === TILE.WATER) {
    ctx.strokeStyle = "#8ec8c8";
    const wave = Math.sin(time * 2 + tx * 0.6 + ty) * 2;
    ctx.beginPath();
    ctx.moveTo(px + 4, py + 18 + wave);
    ctx.quadraticCurveTo(px + 20, py + 14 + wave, px + 36, py + 20 + wave);
    ctx.stroke();
  } else if (tile === TILE.PARK) {
    ctx.fillStyle = "#2a4a28";
    ctx.beginPath();
    ctx.arc(px + 14, py + 16, 5, 0, Math.PI * 2);
    ctx.arc(px + 28, py + 24, 4, 0, Math.PI * 2);
    ctx.fill();
  } else if (tile === TILE.BARRICADE) {
    ctx.fillStyle = "#8a5a28";
    ctx.fillRect(px + 6, py + 10, TILE_PX - 12, 8);
    ctx.fillRect(px + 6, py + 24, TILE_PX - 12, 8);
  } else if (tile === TILE.DOOR) {
    ctx.fillStyle = "#a07840";
    ctx.fillRect(px + 12, py + 6, 18, TILE_PX - 10);
    ctx.fillStyle = "#d4b06a";
    ctx.beginPath();
    ctx.arc(px + 26, py + 22, 2, 0, Math.PI * 2);
    ctx.fill();
  } else if (tile === TILE.RUBBLE) {
    ctx.fillStyle = "#7a7060";
    ctx.fillRect(px + 8, py + 18, 12, 8);
    ctx.fillRect(px + 22, py + 14, 10, 10);
  } else if (tile === TILE.PARKING) {
    ctx.strokeStyle = "#9a9aa0";
    ctx.strokeRect(px + 8, py + 8, TILE_PX - 16, TILE_PX - 16);
  }
  ctx.globalAlpha = 1;
}

function drawLoot(ctx, id, px, py, time) {
  const bob = Math.sin(time * 3 + px * 0.02) * 2;
  ctx.save();
  ctx.translate(px, py + bob);
  if (id === "food") {
    ctx.fillStyle = "#c45a3a";
    ctx.fillRect(-6, -4, 12, 8);
  } else if (id === "water") {
    ctx.fillStyle = "#4aa0c8";
    ctx.fillRect(-4, -7, 8, 12);
  } else if (id === "scrap") {
    ctx.fillStyle = "#8a8a92";
    ctx.beginPath();
    ctx.moveTo(-6, 4);
    ctx.lineTo(0, -6);
    ctx.lineTo(6, 5);
    ctx.fill();
  } else if (id === "wood") {
    ctx.strokeStyle = "#8a5a28";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(-7, 4);
    ctx.lineTo(7, -4);
    ctx.stroke();
  } else if (id === "med") {
    ctx.fillStyle = "#e8e8e8";
    ctx.fillRect(-6, -6, 12, 12);
    ctx.fillStyle = "#c03030";
    ctx.fillRect(-2, -6, 4, 12);
    ctx.fillRect(-6, -2, 12, 4);
  }
  ctx.restore();
}

function drawZombie(ctx, px, py, time, z) {
  ctx.save();
  ctx.translate(px, py);
  ctx.fillStyle = "rgba(0,0,0,0.3)";
  ctx.beginPath();
  ctx.ellipse(0, 10, 9, 3.5, 0, 0, Math.PI * 2);
  ctx.fill();

  const limp = Math.sin(time * 6 + z.x) * 2;
  ctx.fillStyle = "#3a4a34";
  ctx.fillRect(-6, -8, 12, 14);
  ctx.fillStyle = "#6a7a5a";
  ctx.beginPath();
  ctx.arc(0, -14, 6, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#8a2020";
  ctx.beginPath();
  ctx.arc(-2, -14, 1.4, 0, Math.PI * 2);
  ctx.arc(3, -14, 1.4, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "#2a3228";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(-4, 4);
  ctx.lineTo(-5, 12 + limp);
  ctx.moveTo(4, 4);
  ctx.lineTo(5, 12 - limp);
  ctx.stroke();
  // brazos
  ctx.beginPath();
  ctx.moveTo(-6, -4);
  ctx.lineTo(-12, 2 + limp);
  ctx.moveTo(6, -4);
  ctx.lineTo(11, 1 - limp);
  ctx.stroke();
  ctx.restore();
}

function drawPlayer(ctx, px, py, player, time) {
  ctx.save();
  ctx.translate(px, py);
  ctx.scale(player.facing, 1);
  ctx.fillStyle = "rgba(0,0,0,0.28)";
  ctx.beginPath();
  ctx.ellipse(0, 11, 10, 4, 0, 0, Math.PI * 2);
  ctx.fill();

  const walk = Math.sin(time * 11) * (player.stamina < 100 ? 2 : 0);
  ctx.strokeStyle = "#1e2420";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(-3, 2);
  ctx.lineTo(-4, 11 + walk);
  ctx.moveTo(3, 2);
  ctx.lineTo(4, 11 - walk);
  ctx.stroke();

  ctx.fillStyle = "#3a4a5a";
  ctx.fillRect(-7, -10, 14, 14);
  ctx.fillStyle = "#6a3a28";
  ctx.fillRect(-8, -6, 4, 10);

  ctx.fillStyle = "#d2b08a";
  ctx.beginPath();
  ctx.arc(0, -16, 6, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#2b2218";
  ctx.beginPath();
  ctx.arc(-3, -19, 3.2, 0, Math.PI * 2);
  ctx.arc(2, -20, 3.4, 0, Math.PI * 2);
  ctx.arc(4, -16, 2.6, 0, Math.PI * 2);
  ctx.fill();

  // tubería
  ctx.strokeStyle = "#8a9098";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(6, -2);
  ctx.lineTo(14, -8);
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
      mctx.fillRect(x * scale, y * scale, scale + 0.5, scale + 0.5);
    }
  }
  mctx.fillStyle = "#7dcea0";
  for (const z of game.zombies) {
    mctx.fillRect(z.x * scale - 0.8, z.y * scale - 0.8, 2, 2);
  }
  mctx.fillStyle = "#f2f6e8";
  mctx.beginPath();
  mctx.arc(game.player.x * scale, game.player.y * scale, 2.4, 0, Math.PI * 2);
  mctx.fill();
  mctx.strokeStyle = "rgba(215,236,228,0.35)";
  mctx.strokeRect(0.5, 0.5, s - 1, s - 1);
}
