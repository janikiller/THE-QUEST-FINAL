import {
  TILE,
  TILE_META,
  LOOT,
  BUILD,
  BASE_CAPACITY,
  canWalk,
  tileAt,
  setTile,
  lootLabel,
  lootGatherText,
  buildingAt,
  nearestContainer,
  searchFurniture,
  itemDef,
} from "./world.js";

const DAY_LEN = 160;
const DEFAULT_WEAPON = {
  label: "Tubería",
  damage: 30,
  range: 1.35,
  attackCd: 0.4,
  stamina: 8,
};

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
      equip: { hand: null, body: null, bag: null },
      gatherCd: 0,
      attackCd: 0,
      hurtFlash: 0,
    },
    zombies: [],
    time: 0.52 * DAY_LEN,
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
    // Oleadas: cada una más fuerte
    wave: 0,
    wavePhase: "countdown", // countdown | spawning | fighting | clear
    waveTimer: 16,
    waveQuota: 0,
    waveSpawned: 0,
    weather: {
      kind: "rain",
      intensity: 0.55,
      nextChange: 14 + Math.random() * 10,
      thunder: 0,
      wind: 0.7,
      label: "Lluvia",
    },
  };
  seedZombies(game, 4);
  setToast(game, "Oleada 1 en camino. Busca mochila y arma (T para equipar).");
  return game;
}

/** Texto corto para el HUD de oleadas. */
export function waveStatus(game) {
  if (game.wavePhase === "countdown") {
    const n = Math.max(1, Math.ceil(game.waveTimer));
    return game.wave === 0 ? `Oleada 1 en ${n}s` : `Oleada ${game.wave + 1} en ${n}s`;
  }
  if (game.wavePhase === "spawning") {
    return `Oleada ${game.wave}: ${game.waveSpawned}/${game.waveQuota}`;
  }
  if (game.wavePhase === "fighting") {
    const left = game.zombies.filter((z) => z.wave > 0).length;
    return `Oleada ${game.wave}: ${left} vivos`;
  }
  return `Oleada ${game.wave} limpia`;
}

export function dayPhase(game) {
  const t = (game.time % game.dayLen) / game.dayLen;
  let phase;
  if (t < 0.18) phase = { name: "Amanecer", light: 0.45 + t * 2.8, night: false };
  else if (t < 0.48) phase = { name: "Día", light: 1, night: false };
  else if (t < 0.6) phase = { name: "Atardecer", light: 0.78 - (t - 0.48) * 1.5, night: false };
  else if (t < 0.72) phase = { name: "Anochecer", light: 0.42 - (t - 0.6) * 1.8, night: true };
  else phase = { name: "Noche", light: 0.1, night: true };

  const w = game.weather;
  if (w.kind === "cloudy") phase.light *= 0.88;
  if (w.kind === "rain") phase.light *= 0.72;
  if (w.kind === "storm") phase.light *= 0.55;
  if (w.thunder > 0) phase.light = Math.min(1, phase.light + w.thunder * 0.85);
  phase.weather = w.kind;
  phase.rain = w.intensity;
  phase.wind = w.wind;
  phase.thunder = w.thunder;
  phase.weatherLabel = w.label;
  return phase;
}

export function setToast(game, msg) {
  game.toast = msg;
  game.toastT = 2.4;
}

export function updateGame(game, dt) {
  if (game.dead) return;
  const p = game.player;
  game.time += dt;
  updateWeather(game, dt);
  const phase = dayPhase(game);
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
  if (pressed(game, "t")) tryEquip(game);

  game.justPressed.clear();

  updateZombies(game, dt, phase);
  updateWaves(game, dt, phase);

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

function updateWeather(game, dt) {
  const w = game.weather;
  w.thunder = Math.max(0, w.thunder - dt * 3.2);
  w.nextChange -= dt;

  if (w.kind === "storm" && w.thunder <= 0 && Math.random() < dt * 0.35) {
    w.thunder = 0.18 + Math.random() * 0.22;
    if (Math.random() < 0.45) setToast(game, "⚡ Un trueno parte la noche.");
  } else if (w.kind === "rain" && w.thunder <= 0 && Math.random() < dt * 0.04) {
    w.thunder = 0.08 + Math.random() * 0.1;
  }

  const target =
    w.kind === "clear" ? 0 :
    w.kind === "cloudy" ? 0.25 :
    w.kind === "rain" ? 0.7 :
    1;
  w.intensity += (target - w.intensity) * Math.min(1, dt * 1.4);
  w.wind += ((w.kind === "storm" ? 1.4 : w.kind === "rain" ? 0.8 : 0.25) - w.wind) * Math.min(1, dt);

  if (w.nextChange > 0) return;
  w.nextChange = 18 + Math.random() * 28;
  const roll = Math.random();
  const night = ((game.time % game.dayLen) / game.dayLen) >= 0.6;
  let next = w.kind;
  if (w.kind === "clear") next = roll < (night ? 0.7 : 0.5) ? "cloudy" : "clear";
  else if (w.kind === "cloudy") next = roll < (night ? 0.55 : 0.35) ? "rain" : roll < 0.75 ? "cloudy" : "clear";
  else if (w.kind === "rain") next = roll < (night ? 0.55 : 0.3) ? "storm" : roll < 0.7 ? "rain" : "cloudy";
  else next = roll < 0.45 ? "rain" : "cloudy";

  w.kind = next;
  w.label =
    next === "clear" ? "Despejado" :
    next === "cloudy" ? "Nublado" :
    next === "rain" ? "Lluvia" :
    "Tormenta";
  if (next === "storm") setToast(game, "La tormenta cae sobre Niebla Norte.");
  else if (next === "rain") setToast(game, "Empieza a llover sobre el asfalto.");
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

  const near = nearestContainer(game.world, p.x, p.y);
  if (near) {
    p.gatherCd = 0.55;
    const result = searchFurniture(near.furn);
    game.noisePulse = Math.max(game.noisePulse, 1.4);
    if (result.already) {
      setToast(game, `${result.label}: ya lo registraste.`);
      return;
    }
    if (result.empty) {
      setToast(game, `Registras ${result.label.toLowerCase()}… vacío.`);
      return;
    }
    if (!tryTakeItem(p, result.id, result.amount)) {
      setToast(game, "Inventario lleno. Equipa una mochila (T).");
      return;
    }
    setToast(game, `En ${result.label.toLowerCase()}: ${lootGatherText(result.id)}.`);
    return;
  }

  for (let oy = -1; oy <= 1; oy++) {
    for (let ox = -1; ox <= 1; ox++) {
      const key = `${tx + ox},${ty + oy}`;
      const item = game.world.loot.get(key);
      if (!item) continue;
      if (!tryTakeItem(p, item.id, item.amount)) {
        setToast(game, "Inventario lleno. Necesitas más espacio.");
        return;
      }
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
      : "Nada que saquear. E registrar · T equipar · Q atacar"
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
  const weapon = equippedWeapon(p);
  p.attackCd = weapon.attackCd;
  p.stamina = Math.max(0, p.stamina - weapon.stamina);
  game.noisePulse = Math.max(game.noisePulse, 3.5);
  let hit = false;

  for (const z of game.zombies) {
    const dx = z.x - p.x;
    const dy = z.y - p.y;
    if (Math.hypot(dx, dy) > weapon.range) continue;
    if (p.facing > 0 && dx < -0.45) continue;
    if (p.facing < 0 && dx > 0.45) continue;
    z.hp -= weapon.damage;
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

  setToast(game, hit ? `Golpeas con ${weapon.label.toLowerCase()}.` : "Cortas el aire.");
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
    game.zombies.push(makeZombie(x, y, 0));
  }
}

function spawnZombie(game, wave = 0) {
  const p = game.player;
  for (let attempt = 0; attempt < 28; attempt++) {
    const ang = Math.random() * Math.PI * 2;
    const dist = 12 + Math.random() * 16;
    const x = p.x + Math.cos(ang) * dist;
    const y = p.y + Math.sin(ang) * dist;
    if (!canWalk(game.world, x, y, { zombie: true })) continue;
    game.zombies.push(makeZombie(x, y, wave));
    return true;
  }
  return false;
}

function makeZombie(x, y, wave = 0) {
  const scaleHp = 1 + Math.max(0, wave - 1) * 0.14;
  const scaleSpd = 1 + Math.max(0, wave - 1) * 0.07;
  const scaleDmg = 1 + Math.max(0, wave - 1) * 0.05;
  return {
    x,
    y,
    hp: (38 + ((Math.random() * 28) | 0)) * scaleHp,
    speed: (0.8 + Math.random() * 0.6) * scaleSpd,
    damage: 13 * scaleDmg,
    stun: 0,
    attackCd: 0,
    wanderT: 0,
    wx: x,
    wy: y,
    wave,
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
      const body = itemDef(p.equip.body);
      const biteMult = body?.biteMult ?? 1;
      const baseDmg = z.damage || 13;
      p.health -= (onBase ? baseDmg * 0.55 : baseDmg) * biteMult;
      p.hurtFlash = 0.32;
      z.attackCd = 0.95;
      setToast(game, "¡Un zombie te muerde!");
    }
  }
}

function updateWaves(game, dt, phase) {
  if (game.wavePhase === "countdown") {
    game.waveTimer -= dt;
    if (game.waveTimer <= 0) {
      game.wave += 1;
      game.waveQuota = Math.min(42, 5 + game.wave * 3 + (phase.night ? 2 : 0));
      game.waveSpawned = 0;
      game.waveSpawnStall = 0;
      game.wavePhase = "spawning";
      setToast(game, `Oleada ${game.wave}: llegan ${game.waveQuota} zombis.`);
    }
    return;
  }

  if (game.wavePhase === "spawning") {
    game.waveSpawnStall = (game.waveSpawnStall || 0) + dt;
    const rate = 2.6 + game.wave * 0.18;
    if (game.waveSpawned < game.waveQuota && Math.random() < dt * rate) {
      if (spawnZombie(game, game.wave)) game.waveSpawned += 1;
    }
    if (game.waveSpawned >= game.waveQuota || game.waveSpawnStall > 18) {
      game.wavePhase = "fighting";
      game.waveSpawnStall = 0;
    }
    return;
  }

  if (game.wavePhase === "fighting") {
    const waveLeft = game.zombies.filter((z) => z.wave > 0).length;
    if (waveLeft === 0) {
      game.wavePhase = "clear";
      game.waveTimer = 1.2;
      setToast(game, `Oleada ${game.wave} limpia. Prepárate…`);
    }
    return;
  }

  if (game.wavePhase === "clear") {
    game.waveTimer -= dt;
    if (game.waveTimer <= 0) {
      game.wavePhase = "countdown";
      game.waveTimer = Math.max(10, 20 - game.wave * 0.4);
      setToast(game, `Siguiente oleada en ${Math.ceil(game.waveTimer)}s.`);
    }
  }
}

function invUsed(p) {
  let n = 0;
  for (const [id, count] of Object.entries(p.inv)) {
    if (!count) continue;
    const def = itemDef(id);
    const equipped =
      def?.kind === "equip" &&
      (p.equip.hand === id || p.equip.body === id || p.equip.bag === id);
    const free = equipped ? 1 : 0;
    n += Math.max(0, count - free) * (def?.weight ?? 1);
  }
  return n;
}

export function invCapacity(p) {
  let cap = BASE_CAPACITY;
  for (const slot of ["hand", "body", "bag"]) {
    const def = itemDef(p.equip[slot]);
    if (def?.capacity) cap += def.capacity;
  }
  return cap;
}

function tryTakeItem(p, id, amount = 1) {
  const def = itemDef(id);
  const w = (def?.weight ?? 1) * amount;
  if (invUsed(p) + w > invCapacity(p)) return false;
  p.inv[id] = (p.inv[id] || 0) + amount;
  return true;
}

function equippedWeapon(p) {
  const def = itemDef(p.equip.hand);
  if (def?.slot === "hand") {
    return {
      label: def.label,
      damage: def.damage ?? DEFAULT_WEAPON.damage,
      range: def.range ?? DEFAULT_WEAPON.range,
      attackCd: def.attackCd ?? DEFAULT_WEAPON.attackCd,
      stamina: def.stamina ?? DEFAULT_WEAPON.stamina,
    };
  }
  return { ...DEFAULT_WEAPON };
}

function tryEquip(game) {
  const p = game.player;
  const order = [
    LOOT.BAG_BIG, LOOT.BAG,
    LOOT.BAT, LOOT.CROWBAR, LOOT.KNIFE,
    LOOT.JACKET,
  ];
  for (const id of order) {
    if ((p.inv[id] || 0) <= 0) continue;
    const def = itemDef(id);
    if (!def || def.kind !== "equip") continue;
    if (p.equip[def.slot] === id) continue;
    const prev = p.equip[def.slot];
    p.equip[def.slot] = id;
    if (invUsed(p) > invCapacity(p)) {
      p.equip[def.slot] = prev;
      setToast(game, "Demasiada carga para ese cambio de equipo.");
      return;
    }
    p.gatherCd = 0.15;
    setToast(game, `Equipas ${def.label.toLowerCase()}.`);
    return;
  }

  if (p.equip.hand) {
    setToast(game, `Guardas ${itemDef(p.equip.hand).label.toLowerCase()}.`);
    p.equip.hand = null;
    return;
  }
  if (p.equip.body) {
    setToast(game, `Te quitas ${itemDef(p.equip.body).label.toLowerCase()}.`);
    p.equip.body = null;
    return;
  }
  if (p.equip.bag) {
    const bag = p.equip.bag;
    p.equip.bag = null;
    if (invUsed(p) > invCapacity(p)) {
      p.equip.bag = bag;
      setToast(game, "Vacía la mochila antes de quitártela.");
      return;
    }
    setToast(game, `Dejas ${itemDef(bag).label.toLowerCase()}.`);
    return;
  }
  setToast(game, "Nada que equipar. Saquea armarios (E).");
}

export function inventorySlots(game) {
  const p = game.player;
  const stacks = [LOOT.FOOD, LOOT.WATER, LOOT.SCRAP, LOOT.WOOD, LOOT.MED].map((id) => ({
    id,
    label: lootLabel(id),
    n: p.inv[id] || 0,
    kind: "stack",
  }));
  const gearIds = [LOOT.BAG, LOOT.BAG_BIG, LOOT.BAT, LOOT.CROWBAR, LOOT.KNIFE, LOOT.JACKET];
  const gear = gearIds
    .filter((id) => (p.inv[id] || 0) > 0)
    .map((id) => ({
      id,
      label: lootLabel(id),
      n: p.inv[id],
      kind: "gear",
    }));
  const equipSlots = [
    {
      id: "hand",
      label: p.equip.hand ? lootLabel(p.equip.hand) : "Mano",
      n: p.equip.hand ? "E" : "·",
      kind: "equip",
    },
    {
      id: "body",
      label: p.equip.body ? lootLabel(p.equip.body) : "Cuerpo",
      n: p.equip.body ? "E" : "·",
      kind: "equip",
    },
    {
      id: "bag",
      label: p.equip.bag ? lootLabel(p.equip.bag) : "Mochila",
      n: p.equip.bag ? "E" : "·",
      kind: "equip",
    },
  ];
  const cap = {
    id: "cap",
    label: "Carga",
    n: `${invUsed(p)}/${invCapacity(p)}`,
    kind: "cap",
  };
  return [...stacks, ...gear, ...equipSlots, cap];
}
