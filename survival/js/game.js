import {
  TILE,
  TILE_META,
  LOOT,
  BUILD,
  canWalk,
  tileAt,
  setTile,
  lootLabel,
  lootGatherText,
  buildingAt,
} from "./world.js";

const DAY_LEN = 200;

export function createGame(world) {
  const game = {
    world,
    player: {
      x: world.spawn.x,
      y: world.spawn.y,
      facing: 1,
      health: 100,
      hunger: 82,
      thirst: 78,
      stamina: 100,
      inv: { food: 1, water: 1, scrap: 3, wood: 3, med: 0 },
      gatherCd: 0,
      attackCd: 0,
      hurtFlash: 0,
    },
    zombies: [],
    time: 0.3 * DAY_LEN,
    dayLen: DAY_LEN,
    toast: "",
    toastT: 0,
    dead: false,
    deathReason: "",
    keys: new Set(),
    justPressed: new Set(),
    buildMode: null,
    baseClaimed: false,
    kills: 0,
    noisePulse: 0,
    lastBuilding: null,
  };
  seedZombies(game, 30);
  return game;
}

export function dayPhase(game) {
  const t = (game.time % game.dayLen) / game.dayLen;
  if (t < 0.2) return { name: "Amanecer", light: 0.55 + t * 2, night: false };
  if (t < 0.5) return { name: "Día", light: 1, night: false };
  if (t < 0.65) return { name: "Atardecer", light: 0.72, night: false };
  if (t < 0.78) return { name: "Anochecer", light: 0.38, night: true };
  return { name: "Noche", light: 0.14, night: true };
}

export function setToast(game, msg) {
  game.toast = msg;
  game.toastT = 2.4;
}

export function updateGame(game, dt) {
  if (game.dead) return;
  const p = game.player;
  const phase = dayPhase(game);
  game.time += dt;
  if (game.toastT > 0) game.toastT -= dt;
  game.noisePulse = Math.max(0, game.noisePulse - dt);

  p.gatherCd = Math.max(0, p.gatherCd - dt);
  p.attackCd = Math.max(0, p.attackCd - dt);
  p.hurtFlash = Math.max(0, p.hurtFlash - dt);

  if (pressed(game, "1")) {
    game.buildMode = "wall";
    setToast(game, "Construir: barricada (B delante)");
  }
  if (pressed(game, "2")) {
    game.buildMode = "door";
    setToast(game, "Construir: puerta (B delante)");
  }
  if (pressed(game, "3")) {
    game.buildMode = "claim";
    setToast(game, "Marcar base bajo tus pies (B)");
  }
  if (pressed(game, "0") || pressed(game, "escape")) game.buildMode = null;

  let mx = 0;
  let my = 0;
  if (game.keys.has("w") || game.keys.has("arrowup")) my -= 1;
  if (game.keys.has("s") || game.keys.has("arrowdown")) my += 1;
  if (game.keys.has("a") || game.keys.has("arrowleft")) mx -= 1;
  if (game.keys.has("d") || game.keys.has("arrowright")) mx += 1;
  const moving = mx !== 0 || my !== 0;
  const sprint = game.keys.has(" ") && p.stamina > 2 && moving;
  const tile = TILE_META[tileAt(game.world, p.x, p.y)] || TILE_META[TILE.ROAD];
  const speed = (sprint ? 3.5 : 2.2) * (tile.speed ?? 1);

  if (moving) {
    const len = Math.hypot(mx, my) || 1;
    mx /= len;
    my /= len;
    if (mx !== 0) p.facing = mx > 0 ? 1 : -1;
    tryMove(game, p.x + mx * speed * dt, p.y);
    tryMove(game, p.x, p.y + my * speed * dt);
    p.stamina = Math.max(0, p.stamina - (sprint ? 16 : 3) * dt);
    p.hunger = Math.max(0, p.hunger - (sprint ? 0.9 : 0.35) * dt);
    p.thirst = Math.max(0, p.thirst - (sprint ? 1.1 : 0.45) * dt);
    if (sprint) game.noisePulse = Math.max(game.noisePulse, 2.5);
  } else {
    p.stamina = Math.min(100, p.stamina + 14 * dt);
  }

  // Aviso al entrar en un edificio (el tejado se oculta)
  const bNow = buildingAt(game.world, p.x, p.y);
  const indoorNow = TILE_META[tileAt(game.world, p.x, p.y)]?.indoor;
  if (bNow && indoorNow && game.lastBuilding !== bNow) {
    setToast(game, `Entras en ${bNow.name}`);
    game.lastBuilding = bNow;
  } else if (!indoorNow) {
    game.lastBuilding = null;
  }

  p.hunger = Math.max(0, p.hunger - 0.28 * dt);
  p.thirst = Math.max(0, p.thirst - 0.36 * dt);
  if (tileAt(game.world, p.x, p.y) === TILE.BASE) {
    p.stamina = Math.min(100, p.stamina + 6 * dt);
  }
  if (p.hunger < 8) p.health -= 3.5 * dt;
  if (p.thirst < 8) p.health -= 4.5 * dt;

  if (pressed(game, "e") && p.gatherCd <= 0) interact(game);
  if ((pressed(game, "q") || pressed(game, "f")) && p.attackCd <= 0) melee(game);
  if (pressed(game, "r") && p.gatherCd <= 0) consume(game);
  if (pressed(game, "b") && p.gatherCd <= 0 && game.buildMode) build(game);

  game.justPressed.clear();

  updateZombies(game, dt, phase);

  const maxZ = phase.night ? 58 : 34;
  if (game.zombies.length < maxZ && Math.random() < dt * (phase.night ? 0.6 : 0.14)) {
    spawnZombie(game);
  }

  if (p.health <= 0) {
    p.health = 0;
    game.dead = true;
    if (p.thirst < 1) game.deathReason = "La sed te dejó sin escape.";
    else if (p.hunger < 1) game.deathReason = "El hambre te dobló en la acera.";
    else game.deathReason = "Los muertos de Niebla Norte te alcanzaron.";
  }
}

function pressed(game, key) {
  return game.justPressed.has(key);
}

function tryMove(game, nx, ny) {
  const p = game.player;
  const r = 0.28;
  const pts = [
    [nx - r, ny - r],
    [nx + r, ny - r],
    [nx - r, ny + r],
    [nx + r, ny + r],
  ];
  if (pts.every(([x, y]) => canWalk(game.world, x, y))) {
    p.x = nx;
    p.y = ny;
  }
}

function interact(game) {
  const p = game.player;
  p.gatherCd = 0.35;
  const tx = Math.floor(p.x);
  const ty = Math.floor(p.y);

  for (let oy = -1; oy <= 1; oy++) {
    for (let ox = -1; ox <= 1; ox++) {
      if (TILE_META[tileAt(game.world, tx + ox + 0.5, ty + oy + 0.5)]?.drink) {
        p.thirst = Math.min(100, p.thirst + 20);
        setToast(game, "Bebes del canal. Sabe a óxido.");
        return;
      }
    }
  }

  for (let oy = -1; oy <= 1; oy++) {
    for (let ox = -1; ox <= 1; ox++) {
      const key = `${tx + ox},${ty + oy}`;
      const item = game.world.loot.get(key);
      if (!item) continue;
      p.inv[item.id] = (p.inv[item.id] || 0) + item.amount;
      game.world.loot.delete(key);
      setToast(game, `Saqueas ${lootGatherText(item.id)}.`);
      game.noisePulse = Math.max(game.noisePulse, 1.2);
      return;
    }
  }

  setToast(
    game,
    game.buildMode
      ? `Modo ${BUILD[game.buildMode].label} — pulsa B`
      : "Nada que saquear. 1/2/3 construir · Q atacar · R consumir"
  );
}

function consume(game) {
  const p = game.player;
  p.gatherCd = 0.4;
  if (p.inv.med > 0 && p.health < 95) {
    p.inv.med -= 1;
    p.health = Math.min(100, p.health + 42);
    setToast(game, "Usas un botiquín.");
    return;
  }
  if (p.inv.food > 0 && p.hunger < 92) {
    p.inv.food -= 1;
    p.hunger = Math.min(100, p.hunger + 34);
    setToast(game, "Comes una lata fría.");
    return;
  }
  if (p.inv.water > 0 && p.thirst < 92) {
    p.inv.water -= 1;
    p.thirst = Math.min(100, p.thirst + 40);
    setToast(game, "Bebe agua embotellada.");
    return;
  }
  setToast(game, "Nada útil que consumir.");
}

function melee(game) {
  const p = game.player;
  p.attackCd = 0.4;
  p.stamina = Math.max(0, p.stamina - 8);
  game.noisePulse = Math.max(game.noisePulse, 3.5);
  let hit = false;

  for (const z of game.zombies) {
    const dx = z.x - p.x;
    const dy = z.y - p.y;
    if (Math.hypot(dx, dy) > 1.35) continue;
    if (p.facing > 0 && dx < -0.45) continue;
    if (p.facing < 0 && dx > 0.45) continue;
    z.hp -= 30;
    z.stun = 0.35;
    z.x += Math.sign(dx || p.facing) * 0.4;
    hit = true;
  }

  game.zombies = game.zombies.filter((z) => {
    if (z.hp > 0) return true;
    game.kills += 1;
    if (Math.random() < 0.28) {
      const id = Math.random() < 0.55 ? LOOT.SCRAP : LOOT.FOOD;
      const key = `${Math.floor(z.x)},${Math.floor(z.y)}`;
      if (!game.world.loot.has(key)) game.world.loot.set(key, { id, amount: 1 });
    }
    return false;
  });

  setToast(game, hit ? "Golpeas con la tubería." : "Cortas el aire.");
}

function build(game) {
  const p = game.player;
  p.gatherCd = 0.45;
  const recipe = BUILD[game.buildMode];
  if (!recipe) return;

  const bx = game.buildMode === "claim" ? Math.floor(p.x) : Math.floor(p.x + p.facing * 1.0);
  const by = Math.floor(p.y);
  const key = `${bx},${by}`;
  const current = tileAt(game.world, bx + 0.5, by + 0.5);

  for (const [id, n] of Object.entries(recipe.cost)) {
    if ((p.inv[id] || 0) < n) {
      setToast(game, `Falta material: ${recipe.hint}`);
      return;
    }
  }

  if (game.buildMode === "claim") {
    const ok = [TILE.FLOOR, TILE.BASE, TILE.SIDEWALK, TILE.PARKING, TILE.ALLEY, TILE.RUBBLE, TILE.ROAD, TILE.PARK];
    if (!ok.includes(current)) {
      setToast(game, "Marca base en suelo usable.");
      return;
    }
    pay(p, recipe.cost);
    setTile(game.world, bx, by, TILE.BASE);
    game.baseClaimed = true;
    setToast(game, "Base marcada. Cércala con barricadas (1) y puerta (2).");
    return;
  }

  if (TILE_META[current]?.solid || current === TILE.WATER || current === TILE.WALL) {
    setToast(game, "No puedes construir ahí.");
    return;
  }

  pay(p, recipe.cost);
  setTile(game.world, bx, by, recipe.tile);
  if (game.buildMode === "door") game.world.doors.set(key, { hp: 55 });
  else game.world.doors.delete(key);
  setToast(game, `${recipe.label} colocada.`);
  game.noisePulse = Math.max(game.noisePulse, 2);
}

function pay(p, cost) {
  for (const [id, n] of Object.entries(cost)) p.inv[id] -= n;
}

function seedZombies(game, n) {
  let tries = 0;
  while (game.zombies.length < n && tries++ < n * 50) {
    const x = 2 + Math.random() * (game.world.size - 4);
    const y = 2 + Math.random() * (game.world.size - 4);
    if (!canWalk(game.world, x, y, { zombie: true })) continue;
    if (Math.hypot(x - game.player.x, y - game.player.y) < 12) continue;
    game.zombies.push(makeZombie(x, y));
  }
}

function spawnZombie(game) {
  const p = game.player;
  const ang = Math.random() * Math.PI * 2;
  const dist = 13 + Math.random() * 12;
  const x = p.x + Math.cos(ang) * dist;
  const y = p.y + Math.sin(ang) * dist;
  if (!canWalk(game.world, x, y, { zombie: true })) return;
  game.zombies.push(makeZombie(x, y));
}

function makeZombie(x, y) {
  return {
    x,
    y,
    hp: 38 + ((Math.random() * 28) | 0),
    speed: 0.8 + Math.random() * 0.6,
    stun: 0,
    attackCd: 0,
    wanderT: 0,
    wx: x,
    wy: y,
  };
}

function updateZombies(game, dt, phase) {
  const p = game.player;
  const aggro = (phase.night ? 11 : 7) + (game.noisePulse > 0 ? 6 : 0);

  for (const z of game.zombies) {
    z.stun = Math.max(0, z.stun - dt);
    z.attackCd = Math.max(0, z.attackCd - dt);
    if (z.stun > 0) continue;

    const dist = Math.hypot(z.x - p.x, z.y - p.y);
    let tx = z.wx;
    let ty = z.wy;
    if (dist < aggro) {
      tx = p.x;
      ty = p.y;
    } else {
      z.wanderT -= dt;
      if (z.wanderT <= 0) {
        z.wanderT = 1.4 + Math.random() * 3;
        z.wx = z.x + (Math.random() - 0.5) * 6;
        z.wy = z.y + (Math.random() - 0.5) * 6;
      }
    }

    const spd = z.speed * (phase.night ? 1.28 : 1) * (dist < aggro ? 1.15 : 0.7);
    const dx = tx - z.x;
    const dy = ty - z.y;
    const len = Math.hypot(dx, dy) || 1;
    const nx = z.x + (dx / len) * spd * dt;
    const ny = z.y + (dy / len) * spd * dt;

    for (const [dk, door] of [...game.world.doors]) {
      if (door.hp <= 0) continue;
      const [dx0, dy0] = dk.split(",").map(Number);
      if (Math.hypot(z.x - dx0 - 0.5, z.y - dy0 - 0.5) > 1.15) continue;
      door.hp -= 10 * dt;
      if (door.hp <= 0) {
        setTile(game.world, dx0, dy0, TILE.RUBBLE);
        game.world.doors.delete(dk);
        setToast(game, "¡Una puerta ha cedido!");
      }
    }

    const ax = z.x + (dx / len) * 0.55;
    const ay = z.y + (dy / len) * 0.55;
    if (tileAt(game.world, ax, ay) === TILE.BARRICADE && Math.random() < dt * 0.35) {
      if (Math.random() < 0.025) {
        setTile(game.world, ax, ay, TILE.RUBBLE);
        setToast(game, "Una barricada se derrumba.");
      }
    }

    if (canWalk(game.world, nx, z.y, { zombie: true })) z.x = nx;
    if (canWalk(game.world, z.x, ny, { zombie: true })) z.y = ny;

    if (dist < 0.55 && z.attackCd <= 0) {
      const onBase = tileAt(game.world, p.x, p.y) === TILE.BASE;
      p.health -= onBase ? 7 : 13;
      p.hurtFlash = 0.32;
      z.attackCd = 0.95;
      setToast(game, "¡Un zombie te muerde!");
    }
  }
}

export function inventorySlots(game) {
  return [LOOT.FOOD, LOOT.WATER, LOOT.SCRAP, LOOT.WOOD, LOOT.MED].map((id) => ({
    id,
    label: lootLabel(id),
    n: game.player.inv[id] || 0,
  }));
}
