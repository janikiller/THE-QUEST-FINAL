import { TILE, TILE_META, canWalk, tileAt, resourceLabel, resourceGatherText } from "./world.js";

const DAY_LEN = 180; // segundos de ciclo día/noche

export function createGame(world) {
  return {
    world,
    player: {
      x: world.spawn.x,
      y: world.spawn.y,
      facing: 1,
      health: 100,
      hunger: 85,
      thirst: 80,
      warmth: 90,
      stamina: 100,
      inv: { berry: 0, wood: 0, stone: 0, reed: 0, flint: 0 },
      gatherCd: 0,
      hurtFlash: 0,
    },
    camps: [],
    wolves: [],
    time: 0.22 * DAY_LEN, // casi amanecer
    dayLen: DAY_LEN,
    toast: "",
    toastT: 0,
    dead: false,
    deathReason: "",
    keys: new Set(),
  };
}

export function dayPhase(game) {
  const t = (game.time % game.dayLen) / game.dayLen;
  if (t < 0.2) return { name: "Amanecer", light: 0.55 + t * 2, cold: 0.35 };
  if (t < 0.5) return { name: "Día", light: 1, cold: 0 };
  if (t < 0.65) return { name: "Atardecer", light: 0.75, cold: 0.2 };
  if (t < 0.78) return { name: "Crepúsculo", light: 0.4, cold: 0.45 };
  return { name: "Noche", light: 0.18, cold: 0.85 };
}

export function setToast(game, msg) {
  game.toast = msg;
  game.toastT = 2.2;
}

export function updateGame(game, dt) {
  if (game.dead) return;
  const p = game.player;
  const phase = dayPhase(game);
  game.time += dt;
  if (game.toastT > 0) game.toastT -= dt;

  p.gatherCd = Math.max(0, p.gatherCd - dt);
  p.hurtFlash = Math.max(0, p.hurtFlash - dt);

  // Movimiento
  let mx = 0;
  let my = 0;
  if (game.keys.has("w") || game.keys.has("arrowup")) my -= 1;
  if (game.keys.has("s") || game.keys.has("arrowdown")) my += 1;
  if (game.keys.has("a") || game.keys.has("arrowleft")) mx -= 1;
  if (game.keys.has("d") || game.keys.has("arrowright")) mx += 1;
  const moving = mx !== 0 || my !== 0;
  const sprint = game.keys.has(" ") && p.stamina > 2 && moving;
  const tile = TILE_META[tileAt(game.world, p.x, p.y)];
  const base = sprint ? 3.4 : 2.15;
  const speed = base * (tile.speed ?? 1);

  if (moving) {
    const len = Math.hypot(mx, my) || 1;
    mx /= len;
    my /= len;
    if (mx !== 0) p.facing = mx > 0 ? 1 : -1;
    tryMove(game, p.x + mx * speed * dt, p.y);
    tryMove(game, p.x, p.y + my * speed * dt);
    p.stamina = Math.max(0, p.stamina - (sprint ? 18 : 4) * dt);
    p.hunger = Math.max(0, p.hunger - (sprint ? 1.4 : 0.55) * dt);
    p.thirst = Math.max(0, p.thirst - (sprint ? 1.8 : 0.7) * dt);
  } else {
    p.stamina = Math.min(100, p.stamina + 12 * dt);
  }

  // Supervivencia pasiva
  p.hunger = Math.max(0, p.hunger - 0.35 * dt);
  p.thirst = Math.max(0, p.thirst - 0.48 * dt);

  const nearCamp = game.camps.some((c) => Math.hypot(c.x - p.x, c.y - p.y) < 2.4);
  const warmthTarget = nearCamp ? 100 : 100 - phase.cold * 70 - (tileAt(game.world, p.x, p.y) === TILE.SWAMP ? 12 : 0);
  p.warmth += (warmthTarget - p.warmth) * Math.min(1, dt * 0.35);

  if (p.hunger < 8) p.health -= 4 * dt;
  if (p.thirst < 8) p.health -= 5.5 * dt;
  if (p.warmth < 18) p.health -= 6 * dt;

  // Beber en agua dulce (borde)
  if (game.keys.has("e") && p.gatherCd <= 0) {
    interact(game);
  }
  if (game.keys.has("f") && p.gatherCd <= 0) {
    craftCampfire(game);
  }

  updateWolves(game, dt, phase);
  if (p.health <= 0) {
    p.health = 0;
    game.dead = true;
    if (p.thirst < 1) game.deathReason = "La sed te dobló las rodillas.";
    else if (p.hunger < 1) game.deathReason = "El hambre apagó tu cuerpo.";
    else if (p.warmth < 20) game.deathReason = "El frío de Valmora te venció.";
    else game.deathReason = "Las sombras de la isla te alcanzaron.";
  }
}

function tryMove(game, nx, ny) {
  const p = game.player;
  const r = 0.28;
  const points = [
    [nx - r, ny - r],
    [nx + r, ny - r],
    [nx - r, ny + r],
    [nx + r, ny + r],
  ];
  if (points.every(([x, y]) => canWalk(game.world, x, y))) {
    p.x = nx;
    p.y = ny;
  }
}

function interact(game) {
  const p = game.player;
  p.gatherCd = 0.35;
  const tx = Math.floor(p.x);
  const ty = Math.floor(p.y);

  // Beber cerca de agua dulce
  for (let oy = -1; oy <= 1; oy++) {
    for (let ox = -1; ox <= 1; ox++) {
      const t = tileAt(game.world, tx + ox + 0.5, ty + oy + 0.5);
      if (TILE_META[t]?.drink) {
        p.thirst = Math.min(100, p.thirst + 28);
        setToast(game, "Bebes agua dulce del arroyo.");
        return;
      }
    }
  }

  // Recolectar en la casilla o adyacentes
  for (let oy = -1; oy <= 1; oy++) {
    for (let ox = -1; ox <= 1; ox++) {
      const key = `${tx + ox},${ty + oy}`;
      const res = game.world.resources.get(key);
      if (!res) continue;
      p.inv[res.id] = (p.inv[res.id] || 0) + res.amount;
      game.world.resources.delete(key);
      setToast(game, `Recolectas ${resourceGatherText(res.id)}.`);
      return;
    }
  }

  if (p.inv.berry > 0) {
    p.inv.berry -= 1;
    p.hunger = Math.min(100, p.hunger + 22);
    p.health = Math.min(100, p.health + 4);
    setToast(game, "Comes bayas. El hambre afloja.");
    return;
  }

  setToast(game, "Aquí no hay nada que tomar.");
}

function craftCampfire(game) {
  const p = game.player;
  p.gatherCd = 0.5;
  if (p.inv.wood < 3 || p.inv.flint < 1) {
    setToast(game, "Fogata: 3 madera + 1 pedernal.");
    return;
  }
  if (game.camps.some((c) => Math.hypot(c.x - p.x, c.y - p.y) < 1.5)) {
    setToast(game, "Ya hay una fogata cerca.");
    return;
  }
  p.inv.wood -= 3;
  p.inv.flint -= 1;
  game.camps.push({ x: p.x, y: p.y, life: 120 });
  setToast(game, "Levantas una fogata. El calor vuelve.");
}

function updateWolves(game, dt, phase) {
  const night = phase.name === "Noche" || phase.name === "Crepúsculo";
  const p = game.player;

  // Spawnear lobos de noche lejos del jugador
  if (night && game.wolves.length < 5 && Math.random() < dt * 0.35) {
    const ang = Math.random() * Math.PI * 2;
    const dist = 10 + Math.random() * 8;
    const x = p.x + Math.cos(ang) * dist;
    const y = p.y + Math.sin(ang) * dist;
    if (canWalk(game.world, x, y)) {
      game.wolves.push({ x, y, hp: 20, cd: 0 });
    }
  }

  // Desvanecer de día
  if (!night) {
    game.wolves = game.wolves.filter(() => Math.random() > dt * 0.8);
  }

  for (const w of game.wolves) {
    w.cd = Math.max(0, w.cd - dt);
    const dx = p.x - w.x;
    const dy = p.y - w.y;
    const d = Math.hypot(dx, dy) || 1;
    const spd = 1.55;
    const nx = w.x + (dx / d) * spd * dt;
    const ny = w.y + (dy / d) * spd * dt;
    if (canWalk(game.world, nx, w.y)) w.x = nx;
    if (canWalk(game.world, w.x, ny)) w.y = ny;
    if (d < 0.55 && w.cd <= 0) {
      p.health -= 12;
      p.hurtFlash = 0.35;
      w.cd = 1.1;
      setToast(game, "¡Un lobo te muerde!");
    }
  }

  // Piedra ahuyenta (clic conceptual: tecla Q)
  if (game.keys.has("q") && p.gatherCd <= 0 && p.inv.stone > 0) {
    p.gatherCd = 0.4;
    p.inv.stone -= 1;
    let hit = false;
    for (const w of game.wolves) {
      if (Math.hypot(w.x - p.x, w.y - p.y) < 3.5) {
        w.hp -= 20;
        hit = true;
      }
    }
    game.wolves = game.wolves.filter((w) => w.hp > 0);
    setToast(game, hit ? "Lanzas una piedra. El lobo huye." : "Lanzas una piedra al vacío.");
  }

  for (const c of game.camps) c.life -= dt;
  game.camps = game.camps.filter((c) => c.life > 0);
}

export function inventorySlots(game) {
  const order = ["berry", "wood", "stone", "reed", "flint"];
  return order.map((id) => ({ id, label: resourceLabel(id), n: game.player.inv[id] || 0 }));
}
