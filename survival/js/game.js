import {
  TILE,
  TILE_META,
  LOOT,
  BUILD,
  BASE_CAPACITY,
  WEAPON_HOTBAR,
  CLOTHES,
  canWalk,
  tileAt,
  setTile,
  lootLabel,
  lootGatherText,
  buildingAt,
  nearestContainer,
  nearestSearchable,
  searchFurniture,
  furnitureLabel,
  itemDef,
} from "./world.js";

const DAY_LEN = 160;
export const MAX_HEALTH = 160;
const DEFAULT_WEAPON = {
  label: "Manos",
  damage: 18,
  range: 1.15,
  attackCd: 0.35,
  stamina: 5,
  icon: "✊",
};


/** Jefes de oleada (cada 3 oleadas: 3, 6, 9…). Escalan con la oleada. */
export const BOSS_TYPES = {
  bruiser: {
    id: "bruiser",
    name: "El Bruto",
    title: "JEFE · EL BRUTO",
    color: "#6a2a28",
    head: "#8a4a40",
    hp: 320,
    speed: 0.72,
    damage: 28,
    radius: 0.72,
    attackCd: 1.15,
    aggroBonus: 8,
    chargeCd: 4.5,
    chargeSpeed: 2.4,
    chargeTime: 0.55,
    knockback: 0.55,
    loot: [
      { id: LOOT.AMMO_9MM, amount: 12 },
      { id: LOOT.MED, amount: 1 },
      { id: LOOT.SCRAP, amount: 3 },
    ],
  },
  screamer: {
    id: "screamer",
    name: "El Aullador",
    title: "JEFE · EL AULLADOR",
    color: "#4a3a58",
    head: "#7a6a88",
    hp: 210,
    speed: 1.35,
    damage: 18,
    radius: 0.55,
    attackCd: 0.7,
    aggroBonus: 14,
    chargeCd: 3.2,
    chargeSpeed: 3.1,
    chargeTime: 0.4,
    knockback: 0.35,
    screamNoise: 9,
    loot: [
      { id: LOOT.AMMO_SHOT, amount: 6 },
      { id: LOOT.FOOD, amount: 2 },
      { id: LOOT.WOOD, amount: 2 },
    ],
  },
  tank: {
    id: "tank",
    name: "El Blindado",
    title: "JEFE · EL BLINDADO",
    color: "#3a4540",
    head: "#5a6860",
    hp: 480,
    speed: 0.55,
    damage: 34,
    radius: 0.85,
    attackCd: 1.35,
    aggroBonus: 6,
    chargeCd: 5.5,
    chargeSpeed: 1.9,
    chargeTime: 0.7,
    knockback: 0.8,
    loot: [
      { id: LOOT.AMMO_RIFLE, amount: 8 },
      { id: LOOT.VEST, amount: 1 },
      { id: LOOT.SCRAP, amount: 4 },
    ],
  },
};

const BOSS_ROTATION = ["bruiser", "screamer", "tank"];

/** Devuelve el tipo de jefe de una oleada, o null si no toca. */
export function bossKindForWave(wave) {
  if (wave < 3 || wave % 3 !== 0) return null;
  return BOSS_ROTATION[(((wave / 3) | 0) - 1) % BOSS_ROTATION.length];
}

const BUILD_CYCLE = [null, "wall", "door", "claim"];


export function createGame(world) {
  const game = {
    world,
    player: {
      x: world.spawn.x,
      y: world.spawn.y,
      facing: 1,
      health: MAX_HEALTH,
      maxHealth: MAX_HEALTH,
      hunger: 82,
      thirst: 78,
      stamina: 100,
      inv: { food: 1, water: 1, scrap: 2, wood: 2, med: 1, shirt: 1, bat: 1, pistol: 1, ammo_9mm: 8 },
      equip: { hand: "bat", body: "shirt", bag: null, light: null },
      gearPhase: "clothes",
      gatherCd: 0,
      attackCd: 0,
      hurtFlash: 0,
      swingT: 0,
      swingDur: 0,
      swingHit: null,
      facingAng: 0,
      invulnT: 0,
      kbVx: 0,
      kbVy: 0,
      vx: 0,
      vy: 0,
      walkPhase: 0,
      sprinting: false,
      moving: false,
      lootProgress: 0,
      lootTarget: null,
      lootKind: null,
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
    inventoryOpen: false,
    baseClaimed: false,
    kills: 0,
    noisePulse: 0,
    lastBuilding: null,
    // Cámara suavizada (fluidez visual)
    camX: world.spawn.x,
    camY: world.spawn.y,
    _phase: null,
    _zFrame: 0,
    // Oleadas: cada una más fuerte
    wave: 0,
    wavePhase: "countdown", // countdown | spawning | fighting | clear
    waveTimer: 16,
    waveQuota: 0,
    waveSpawned: 0,
    waveBossKind: null,
    waveBossSpawned: false,
    weather: {
      kind: "fog",
      intensity: 0.7,
      nextChange: 14 + Math.random() * 10,
      thunder: 0,
      wind: 0.45,
      gust: 0,
      gustTimer: 4 + Math.random() * 6,
      label: "Niebla",
    },
    bullets: [],
    fx: [],
    shake: 0,
    waveBanner: "",
    waveBannerT: 0,
    muzzleFlash: 0,
    mouse: { x: 0, y: 0, worldX: 0, worldY: 0, viewW: 0, viewH: 0, down: false, clicked: false },
  };
  game.player.aim = 0;
  seedZombies(game, 4);
  setToast(game, "Niebla Norte. WASD mueve · clic golpea (Stardew) · Q melee · armas de fuego apuntan con ratón.");
  applyWaveDebugFlags(game);
  return game;
}

/** ?boss=1 → oleada 3 con jefe pronto; ?fastwaves=1 → timers cortos; ?weather=sandstorm|storm|rain|wind|fog. */
function applyWaveDebugFlags(game) {
  try {
    const q = new URLSearchParams(location.search);
    if (q.has("fastwaves")) {
      game.waveTimer = Math.min(game.waveTimer, 3);
    }
    if (q.has("boss")) {
      game.wave = 2;
      game.wavePhase = "countdown";
      game.waveTimer = q.has("fastwaves") ? 2 : 5;
      setToast(game, "Debug: oleada 3 con jefe en breve.");
    }
    const forced = q.get("weather");
    if (forced) forceWeather(game, forced);
  } catch (_) {
    /* SSR / tests */
  }
}

function forceWeather(game, kind) {
  const map = {
    clear: ["clear", "Despejado", 0.1, 0.35],
    cloudy: ["cloudy", "Nublado", 0.3, 0.45],
    fog: ["fog", "Niebla", 0.75, 0.4],
    rain: ["rain", "Lluvia", 0.8, 0.85],
    storm: ["storm", "Tormenta", 1, 1.35],
    sandstorm: ["sandstorm", "Tormenta de arena", 1, 1.55],
    sand: ["sandstorm", "Tormenta de arena", 1, 1.55],
    wind: ["wind", "Viento fuerte", 0.55, 1.25],
  };
  const conf = map[kind];
  if (!conf) return;
  const w = game.weather;
  w.kind = conf[0];
  w.label = conf[1];
  w.intensity = conf[2];
  w.wind = conf[3];
  w.nextChange = 9999;
  setToast(game, `Clima forzado: ${w.label}.`);
}

/** Texto corto para el HUD de oleadas. */
export function waveStatus(game) {
  const bossAlive = game.zombies.some((z) => z.boss && z.hp > 0);
  const bossName = game.waveBossKind ? BOSS_TYPES[game.waveBossKind]?.name : null;
  if (game.wavePhase === "countdown") {
    const n = Math.max(1, Math.ceil(game.waveTimer));
    const next = game.wave === 0 ? 1 : game.wave + 1;
    const bossHint = bossKindForWave(next) ? " · jefe" : "";
    return `Oleada ${next} en ${n}s${bossHint}`;
  }
  if (game.wavePhase === "spawning") {
    const bossTag = game.waveBossKind
      ? game.waveBossSpawned
        ? " · jefe en campo"
        : " · jefe pronto"
      : "";
    return `Oleada ${game.wave}: ${game.waveSpawned}/${game.waveQuota}${bossTag}`;
  }
  if (game.wavePhase === "fighting") {
    const left = game.zombies.filter((z) => z.wave > 0).length;
    if (bossAlive && bossName) return `Oleada ${game.wave}: ¡${bossName}! · ${left} vivos`;
    return `Oleada ${game.wave}: ${left} vivos`;
  }
  return `Oleada ${game.wave} limpia`;
}

export function dayPhase(game) {
  if (game._phase && game._phase._t === game.time && game._phase._w === game.weather.kind
      && game._phase._th === game.weather.thunder && game._phase._g === game.weather.gust) {
    return game._phase;
  }
  const t = (game.time % game.dayLen) / game.dayLen;
  let phase;
  if (t < 0.18) phase = { name: "Amanecer", light: 0.45 + t * 2.8, night: false };
  else if (t < 0.48) phase = { name: "Día", light: 1, night: false };
  else if (t < 0.6) phase = { name: "Atardecer", light: 0.78 - (t - 0.48) * 1.5, night: false };
  else if (t < 0.72) phase = { name: "Anochecer", light: 0.52 - (t - 0.6) * 1.2, night: true };
  else phase = { name: "Noche", light: 0.42, night: true };

  const w = game.weather;
  if (w.kind === "cloudy") phase.light *= 0.94;
  if (w.kind === "fog") phase.light *= 0.82;
  if (w.kind === "rain") phase.light *= 0.88;
  if (w.kind === "storm") phase.light *= 0.72;
  if (w.kind === "sandstorm") phase.light *= 0.62;
  if (w.kind === "wind") phase.light *= 0.9;
  if (w.thunder > 0) phase.light = Math.min(1, phase.light + w.thunder * 0.85);
  phase.weather = w.kind;
  phase.rain = w.kind === "rain" || w.kind === "storm" ? w.intensity : 0;
  phase.sand = w.kind === "sandstorm" ? w.intensity : 0;
  phase.wind = w.wind + (w.gust || 0) * 0.65;
  phase.gust = w.gust || 0;
  phase.thunder = w.thunder;
  phase.weatherLabel = w.label;
  phase._t = game.time;
  phase._w = w.kind;
  phase._th = w.thunder;
  phase._g = w.gust;
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
  game._phase = phase;
  // Cámara con lerp: más reactiva al sprint / movimiento rápido
  const camRate = 10 + Math.min(10, Math.hypot(p.vx || 0, p.vy || 0) * 2.2);
  const camFollow = 1 - Math.exp(-camRate * dt);
  game.camX += (p.x - game.camX) * camFollow;
  game.camY += (p.y - game.camY) * camFollow;
  if (game.toastT > 0) game.toastT -= dt;
  game.noisePulse = Math.max(0, game.noisePulse - dt);
  game.shake = Math.max(0, (game.shake || 0) - dt * 4);
  if (game.waveBannerT > 0) game.waveBannerT -= dt;

  p.gatherCd = Math.max(0, p.gatherCd - dt);
  p.attackCd = Math.max(0, p.attackCd - dt);
  p.hurtFlash = Math.max(0, p.hurtFlash - dt);
  p.invulnT = Math.max(0, (p.invulnT || 0) - dt);
  const prevSwing = p.swingT || 0;
  p.swingT = Math.max(0, prevSwing - dt);
  if (prevSwing > 0 && p.swingT <= 0) {
    const weapon = equippedWeapon(p);
    if (p._swingLanded) {
      setToast(
        game,
        weapon.firearm
          ? `Culatazo con ${weapon.label.toLowerCase()}.`
          : `Golpeas con ${weapon.label.toLowerCase()}.`
      );
    } else {
      setToast(game, "Cortas el aire.");
    }
    p.swingHit = null;
    p._swingLanded = false;
  }
  // Knockback se desvanece (estilo Stardew)
  p.kbVx = (p.kbVx || 0) * Math.exp(-10 * dt);
  p.kbVy = (p.kbVy || 0) * Math.exp(-10 * dt);
  if (Math.abs(p.kbVx) < 0.05) p.kbVx = 0;
  if (Math.abs(p.kbVy) < 0.05) p.kbVy = 0;

  if (pressed(game, "b")) {
    const cur = BUILD_CYCLE.indexOf(game.buildMode);
    const next = BUILD_CYCLE[(cur + 1) % BUILD_CYCLE.length];
    game.buildMode = next;
    if (!next) setToast(game, "Construcción cancelada.");
    else if (next === "wall") setToast(game, "Modo barricada — Enter para colocar.");
    else if (next === "door") setToast(game, "Modo puerta — Enter para colocar.");
    else setToast(game, "Modo base — Enter para marcar.");
  }
  if (pressed(game, "0") || pressed(game, "escape")) game.buildMode = null;

  // Hotbar de armas estilo Project Zomboid (1-5)
  for (let i = 1; i <= 5; i++) {
    if (pressed(game, String(i))) equipHotbarSlot(game, i - 1);
  }

  let mx = 0;
  let my = 0;
  if (game.keys.has("w") || game.keys.has("arrowup")) my -= 1;
  if (game.keys.has("s") || game.keys.has("arrowdown")) my += 1;
  if (game.keys.has("a") || game.keys.has("arrowleft")) mx -= 1;
  if (game.keys.has("d") || game.keys.has("arrowright")) mx += 1;
  const wantMove = mx !== 0 || my !== 0;
  const looting = Boolean(game.keys.has("e") && p.lootTarget);
  const sprint = game.keys.has(" ") && p.stamina > 2 && wantMove && !looting;
  const tile = TILE_META[tileAt(game.world, p.x, p.y)] || TILE_META[TILE.ROAD];
  const tileSpd = tile.speed ?? 1;
  // Movimiento más deliberado (peso Stardew): caminar más lento, sprint claro
  const maxSpeed = (sprint ? 3.25 : looting ? 1.05 : 2.05) * tileSpd;
  const accel = sprint ? 14 : looting ? 7 : 11;
  const friction = wantMove ? accel : 22;

  if (wantMove) {
    const len = Math.hypot(mx, my) || 1;
    mx /= len;
    my /= len;
    // Facing 4 direcciones desde el movimiento (no desde el ratón)
    p.facingAng = snapCardinalFacing(mx, my);
    p.facing = Math.cos(p.facingAng) >= 0 ? 1 : -1;
  }
  const tx = wantMove ? mx * maxSpeed : 0;
  const ty = wantMove ? my * maxSpeed : 0;
  const blend = 1 - Math.exp(-(wantMove ? accel : friction) * dt);
  p.vx += (tx - p.vx) * blend;
  p.vy += (ty - p.vy) * blend;
  if (Math.abs(p.vx) < 0.02) p.vx = 0;
  if (Math.abs(p.vy) < 0.02) p.vy = 0;

  const beforeX = p.x;
  const beforeY = p.y;
  const stepX = p.vx * dt + (p.kbVx || 0) * dt;
  const stepY = p.vy * dt + (p.kbVy || 0) * dt;
  if (stepX !== 0) {
    if (!tryMove(game, p.x + stepX, p.y)) {
      p.vx = 0;
      p.kbVx = 0;
    }
  }
  if (stepY !== 0) {
    if (!tryMove(game, p.x, p.y + stepY)) {
      p.vy = 0;
      p.kbVy = 0;
    }
  }

  const moved = Math.hypot(p.x - beforeX, p.y - beforeY);
  p.moving = moved > 0.0005;
  p.sprinting = sprint && p.moving;
  if (p.moving) {
    p.walkPhase = (p.walkPhase || 0) + moved * (sprint ? 10.5 : 8.2);
    p.stamina = Math.max(0, p.stamina - (sprint ? 15 : 2.4) * dt);
    p.hunger = Math.max(0, p.hunger - (sprint ? 0.85 : 0.32) * dt);
    p.thirst = Math.max(0, p.thirst - (sprint ? 1.05 : 0.4) * dt);
    if (sprint) {
      game.noisePulse = Math.max(game.noisePulse, 2.5);
      if (Math.random() < dt * 9) spawnDust(game, p.x, p.y);
    }
  } else {
    p.stamina = Math.min(100, p.stamina + 15 * dt);
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

  // Apuntado: armas de fuego usan ratón; melee usa facing de movimiento
  if (game.mouse.viewW) {
    game.mouse.worldX = game.camX + (game.mouse.x - game.mouse.viewW / 2) / 48;
    game.mouse.worldY = game.camY + (game.mouse.y - game.mouse.viewH / 2) / 48;
  }
  const handDef = itemDef(p.equip?.hand);
  if (handDef?.firearm) {
    p.aim = Math.atan2(game.mouse.worldY - p.y, game.mouse.worldX - p.x);
    if (Math.cos(p.aim) !== 0) p.facing = Math.cos(p.aim) >= 0 ? 1 : -1;
  } else {
    p.aim = p.facingAng || 0;
  }

  updateLooting(game, dt);
  updateMeleeSwing(game, dt);
  if (pressed(game, "e") && p.gatherCd <= 0 && !p.lootTarget) beginLoot(game);
  if ((pressed(game, "q") || pressed(game, "f")) && p.attackCd <= 0) startMeleeSwing(game);
  if ((game.mouse.clicked || (game.mouse.down && isAutomaticFire(p))) && p.attackCd <= 0) {
    fireWeapon(game);
  }
  if (pressed(game, "r") && p.gatherCd <= 0) consume(game);
  if (pressed(game, "enter") && p.gatherCd <= 0 && game.buildMode) build(game);
  if (pressed(game, "t")) tryEquipGear(game);
  if (pressed(game, "i")) {
    game.inventoryOpen = !game.inventoryOpen;
    setToast(game, game.inventoryOpen ? "Equipo e inventario (I cierra)." : "Inventario cerrado.");
  }
  if (pressed(game, "escape") && game.inventoryOpen) {
    game.inventoryOpen = false;
  }

  game.mouse.clicked = false;
  game.justPressed.clear();

  updateBullets(game, dt);
  updateFx(game, dt);
  game.muzzleFlash = Math.max(0, game.muzzleFlash - dt);
  updateZombies(game, dt, phase);
  updateWaves(game, dt, phase);

  if (p.health <= 0) {
    p.health = 0;
    game.dead = true;
    game.shake = Math.max(game.shake || 0, 0.9);
    p.hurtFlash = 0.8;
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

  // Ráfagas de viento
  w.gustTimer -= dt;
  if (w.gustTimer <= 0) {
    const stormy = w.kind === "storm" || w.kind === "sandstorm" || w.kind === "wind";
    if (stormy || Math.random() < 0.45) {
      w.gust = stormy ? 0.55 + Math.random() * 0.7 : 0.2 + Math.random() * 0.35;
      w.gustTimer = (stormy ? 2.5 : 5) + Math.random() * (stormy ? 4 : 8);
      if (w.kind === "sandstorm" && Math.random() < 0.35) {
        setToast(game, "El viento arrastra la arena como cuchillas.");
      } else if (w.kind === "wind" && Math.random() < 0.3) {
        setToast(game, "Una ráfaga azota los cables muertos.");
      }
    } else {
      w.gust = 0;
      w.gustTimer = 6 + Math.random() * 10;
    }
  } else {
    w.gust = Math.max(0, w.gust - dt * 0.35);
  }

  if (w.kind === "storm" && w.thunder <= 0 && Math.random() < dt * 0.4) {
    w.thunder = 0.18 + Math.random() * 0.28;
    if (Math.random() < 0.5) setToast(game, "⚡ Un trueno parte el cielo.");
  } else if (w.kind === "rain" && w.thunder <= 0 && Math.random() < dt * 0.04) {
    w.thunder = 0.08 + Math.random() * 0.1;
  }

  const target =
    w.kind === "clear" ? 0 :
    w.kind === "cloudy" ? 0.25 :
    w.kind === "fog" ? 0.7 :
    w.kind === "wind" ? 0.5 :
    w.kind === "rain" ? 0.75 :
    1;
  w.intensity += (target - w.intensity) * Math.min(1, dt * 1.4);

  const windTarget =
    w.kind === "storm" ? 1.45 :
    w.kind === "sandstorm" ? 1.6 :
    w.kind === "wind" ? 1.25 :
    w.kind === "rain" ? 0.85 :
    w.kind === "fog" ? 0.4 :
    w.kind === "cloudy" ? 0.45 :
    0.3;
  w.wind += (windTarget - w.wind) * Math.min(1, dt);

  if (w.nextChange > 0) return;
  w.nextChange = 16 + Math.random() * 26;
  const roll = Math.random();
  const night = ((game.time % game.dayLen) / game.dayLen) >= 0.6;
  const day = !night;
  let next = w.kind;

  if (w.kind === "clear") {
    next = roll < 0.35 ? "fog" : roll < 0.55 ? "wind" : roll < 0.8 ? "cloudy" : "clear";
  } else if (w.kind === "cloudy") {
    next = roll < 0.28 ? "fog" : roll < 0.48 ? "wind" : roll < (night ? 0.72 : 0.62) ? "rain" : roll < 0.82 ? "cloudy" : "clear";
  } else if (w.kind === "fog") {
    next = roll < (day ? 0.28 : 0.12) ? "sandstorm" : roll < 0.45 ? "rain" : roll < 0.7 ? "fog" : roll < 0.85 ? "wind" : "cloudy";
  } else if (w.kind === "wind") {
    next = roll < (day ? 0.4 : 0.15) ? "sandstorm" : roll < 0.6 ? "fog" : roll < 0.8 ? "cloudy" : "rain";
  } else if (w.kind === "rain") {
    next = roll < (night ? 0.5 : 0.28) ? "storm" : roll < 0.65 ? "rain" : roll < 0.8 ? "fog" : "wind";
  } else if (w.kind === "storm") {
    next = roll < 0.5 ? "rain" : roll < 0.75 ? "fog" : "wind";
  } else if (w.kind === "sandstorm") {
    next = roll < 0.4 ? "wind" : roll < 0.7 ? "fog" : "cloudy";
  } else {
    next = roll < 0.4 ? "rain" : "fog";
  }

  w.kind = next;
  w.label = weatherLabel(next);
  if (next === "storm") setToast(game, "La tormenta cae sobre Niebla Norte.");
  else if (next === "sandstorm") setToast(game, "Una tormenta de arena se traga la ciudad.");
  else if (next === "rain") setToast(game, "Empieza a llover sobre el asfalto.");
  else if (next === "wind") setToast(game, "El viento aúlla entre los edificios.");
  else if (next === "fog") setToast(game, "La niebla espesa cubre las calles.");
}

function weatherLabel(kind) {
  return (
    kind === "clear" ? "Despejado" :
    kind === "cloudy" ? "Nublado" :
    kind === "fog" ? "Niebla" :
    kind === "rain" ? "Lluvia" :
    kind === "storm" ? "Tormenta" :
    kind === "sandstorm" ? "Tormenta de arena" :
    kind === "wind" ? "Viento fuerte" :
    "Niebla"
  );
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
    return true;
  }
  return false;
}

function findNearestLoot(game) {
  const p = game.player;
  const tx = Math.floor(p.x);
  const ty = Math.floor(p.y);
  let best = null;
  let bestD = 1.55;
  for (let oy = -1; oy <= 1; oy++) {
    for (let ox = -1; ox <= 1; ox++) {
      const x = tx + ox;
      const y = ty + oy;
      const key = `${x},${y}`;
      const item = game.world.loot.get(key);
      if (!item) continue;
      const d = Math.hypot(p.x - (x + 0.5), p.y - (y + 0.5));
      if (d < bestD) {
        bestD = d;
        best = { kind: "loot", key, id: item.id, amount: item.amount || 1, x, y, d };
      }
    }
  }
  return best;
}

function findNearestDrink(game) {
  const p = game.player;
  const tx = Math.floor(p.x);
  const ty = Math.floor(p.y);
  let best = null;
  let bestD = 1.45;
  for (let oy = -1; oy <= 1; oy++) {
    for (let ox = -1; ox <= 1; ox++) {
      const x = tx + ox + 0.5;
      const y = ty + oy + 0.5;
      if (!TILE_META[tileAt(game.world, x, y)]?.drink) continue;
      const d = Math.hypot(p.x - x, p.y - y);
      if (d < bestD) {
        bestD = d;
        best = { kind: "drink", x, y, d };
      }
    }
  }
  return best;
}

function findLootTarget(game) {
  const p = game.player;
  const drink = findNearestDrink(game);
  const loot = findNearestLoot(game);
  const near = nearestSearchable(game.world, p.x, p.y);
  let container = null;
  if (near) {
    const d = Math.hypot(p.x - (near.x + 0.5), p.y - (near.y + 0.5));
    if (d <= 1.55) {
      container = { kind: "container", key: near.key, furn: near.furn, x: near.x, y: near.y, d };
    }
  }
  const opts = [drink, loot, container].filter(Boolean);
  if (!opts.length) return null;
  opts.sort((a, b) => a.d - b.d);
  // Priorizar botín de suelo casi a los pies
  if (loot && loot.d < 0.85) return loot;
  return opts[0];
}

function beginLoot(game) {
  const p = game.player;
  const target = findLootTarget(game);
  if (!target) {
    p.gatherCd = 0.22;
    const scanned = nearestContainer(game.world, p.x, p.y);
    if (scanned) {
      setToast(game, `${furnitureLabel(scanned.furn)}: ya lo registraste.`);
      return;
    }
    setToast(
      game,
      game.buildMode
        ? `Modo ${BUILD[game.buildMode].label} — pulsa B`
        : "Nada cerca. Acércate a un contenedor o botín."
    );
    return;
  }
  if (target.kind === "loot") {
    finishLoot(game, target);
    return;
  }
  if (target.kind === "drink") {
    p.gatherCd = 0.32;
    p.thirst = Math.min(100, p.thirst + 20);
    setToast(game, "Bebes del canal. Sabe a óxido.");
    spawnDust(game, target.x, target.y, "loot");
    return;
  }
  // Contenedor: mantener E
  const preview = peekContainerLabel(target.furn);
  p.lootTarget = target;
  p.lootKind = "container";
  p.lootProgress = 0;
  setToast(game, `Registrando ${preview}… mantén E`);
}

function peekContainerLabel(furn) {
  return (furnitureLabel(furn) || "contenedor").toLowerCase();
}

function updateLooting(game, dt) {
  const p = game.player;
  if (!p.lootTarget) return;
  if (!game.keys.has("e")) {
    if (p.lootProgress > 0.08) setToast(game, "Saqueo cancelado.");
    p.lootTarget = null;
    p.lootKind = null;
    p.lootProgress = 0;
    return;
  }
  const live = findLootTarget(game);
  if (!live || live.kind !== "container" || live.key !== p.lootTarget.key) {
    p.lootTarget = null;
    p.lootProgress = 0;
    return;
  }
  p.lootTarget = live;
  p.lootProgress = Math.min(1, p.lootProgress + dt / 0.7);
  if (p.lootProgress < 1) return;
  finishLoot(game, live);
  p.lootTarget = null;
  p.lootProgress = 0;
  if (game.keys.has("e") && p.gatherCd <= 0) {
    const next = findLootTarget(game);
    if (next?.kind === "container") {
      p.lootTarget = next;
      p.lootProgress = 0;
      setToast(game, `Registrando ${peekContainerLabel(next.furn)}…`);
    } else if (next?.kind === "loot") {
      finishLoot(game, next);
    }
  }
}

function finishLoot(game, target) {
  const p = game.player;
  if (target.kind === "loot") {
    p.gatherCd = 0.16;
    if (!tryTakeItem(p, target.id, target.amount)) {
      setToast(game, "Inventario lleno. Equipa una mochila (T).");
      return;
    }
    game.world.loot.delete(target.key);
    setToast(game, `Saqueas ${lootGatherText(target.id)}.`);
    game.noisePulse = Math.max(game.noisePulse, 1.05);
    spawnDust(game, target.x + 0.5, target.y + 0.5, "loot");
    return;
  }
  if (target.kind !== "container") return;
  p.gatherCd = 0.25;
  const result = searchFurniture(target.furn);
  game.noisePulse = Math.max(game.noisePulse, 1.35);
  spawnDust(game, target.x + 0.5, target.y + 0.5, "loot");
  if (result.already) {
    setToast(game, `${result.label}: ya lo registraste.`);
    return;
  }
  if (result.empty) {
    setToast(game, `Registras ${result.label.toLowerCase()}… vacío.`);
    return;
  }
  if (!tryTakeItem(p, result.id, result.amount)) {
    if (typeof target.furn === "object") target.furn.searched = false;
    setToast(game, "Inventario lleno. Equipa una mochila (T).");
    return;
  }
  setToast(game, `En ${result.label.toLowerCase()}: ${lootGatherText(result.id)}.`);
}

function interact(game) {
  beginLoot(game);
}

function spawnDust(game, x, y, kind = "dust") {
  if (!game.fx) game.fx = [];
  const n = kind === "loot" ? 6 : 3;
  for (let i = 0; i < n; i++) {
    const ang = Math.random() * Math.PI * 2;
    const spd = kind === "loot" ? 0.9 + Math.random() * 1.4 : 0.4 + Math.random() * 0.9;
    game.fx.push({
      x,
      y,
      vx: Math.cos(ang) * spd,
      vy: Math.sin(ang) * spd - 0.45,
      life: 0.28 + Math.random() * 0.2,
      max: 0.45,
      kind,
      size: kind === "loot" ? 2 + Math.random() * 2.2 : 1.2 + Math.random() * 1.6,
    });
  }
}

function consume(game) {
  const p = game.player;
  p.gatherCd = 0.4;
  const maxHp = p.maxHealth || MAX_HEALTH;
  if (p.inv.med > 0 && p.health < maxHp - 5) {
    p.inv.med -= 1;
    p.health = Math.min(maxHp, p.health + 55);
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
  startMeleeSwing(game);
}

/** Facing cardinal (4 dirs) como Stardew Valley. */
function snapCardinalFacing(mx, my) {
  if (Math.abs(mx) >= Math.abs(my)) return mx >= 0 ? 0 : Math.PI;
  return my >= 0 ? Math.PI / 2 : -Math.PI / 2;
}

/** Inicia un golpe con ventana de hit activa (no daño instantáneo). */
function startMeleeSwing(game) {
  const p = game.player;
  if (p.attackCd > 0 || (p.swingT || 0) > 0) return;
  const weapon = equippedWeapon(p);
  const meleeCd = weapon.firearm ? 0.42 : weapon.attackCd;
  const swingDur = weapon.firearm ? 0.28 : Math.min(0.42, Math.max(0.26, weapon.attackCd * 0.72));
  p.attackCd = meleeCd;
  p.swingT = swingDur;
  p.swingDur = swingDur;
  p.swingHit = new Set();
  p._swingLanded = false;
  p.stamina = Math.max(0, p.stamina - (weapon.firearm ? 8 : weapon.stamina));
  game.noisePulse = Math.max(game.noisePulse, weapon.firearm ? 1.6 : 2.2);
  game.shake = Math.max(game.shake || 0, 0.08);
  spawnSlashFx(game, p);
}

function spawnSlashFx(game, p) {
  if (!game.fx) game.fx = [];
  const ang = p.facingAng || p.aim || 0;
  game.fx.push({
    kind: "slash",
    x: p.x,
    y: p.y,
    ang,
    life: p.swingDur || 0.3,
    max: p.swingDur || 0.3,
    range: equippedWeapon(p).firearm ? 1.15 : equippedWeapon(p).range,
  });
}

/** Durante el swing: arco frontal, un hit por zombie, knockback. */
function updateMeleeSwing(game, dt) {
  const p = game.player;
  if (!p.swingT || p.swingT <= 0) return;
  const dur = p.swingDur || 0.3;
  const progress = 1 - p.swingT / dur;
  // Ventana activa ~18%–70% del swing (como frames de ataque en Stardew)
  if (progress < 0.18 || progress > 0.7) return;

  const weapon = equippedWeapon(p);
  const meleeDmg = weapon.firearm ? Math.max(12, Math.floor(weapon.damage * 0.28)) : weapon.damage;
  const meleeRange = (weapon.firearm ? 1.2 : weapon.range) + 0.08;
  const baseAng = p.facingAng ?? p.aim ?? 0;
  // El arco barre ±~50° durante la ventana activa
  const sweepT = (progress - 0.18) / 0.52;
  const hitAng = baseAng + (sweepT - 0.5) * 1.05;
  const ax = Math.cos(hitAng);
  const ay = Math.sin(hitAng);
  const halfCone = 0.72; // ~41° a cada lado del borde del arco
  const cosCone = Math.cos(halfCone);
  if (!p.swingHit) p.swingHit = new Set();

  let hit = false;
  for (const z of game.zombies) {
    if (p.swingHit.has(z)) continue;
    const dx = z.x - p.x;
    const dy = z.y - p.y;
    const dist = Math.hypot(dx, dy);
    const reach = meleeRange + (z.radius || 0.45) * 0.35;
    if (dist > reach || dist < 0.02) continue;
    const dot = (dx / dist) * ax + (dy / dist) * ay;
    if (dot < cosCone) continue;

    p.swingHit.add(z);
    z.hp -= meleeDmg;
    z.stun = 0.28 + Math.min(0.2, meleeDmg * 0.004);
    z.hitFlash = 0.22;
    const kb = 0.42 + Math.min(0.35, meleeDmg * 0.006);
    z.x += ax * kb;
    z.y += ay * kb;
    z.vx = (z.vx || 0) + ax * kb * 4;
    z.vy = (z.vy || 0) + ay * kb * 4;
    spawnFx(game, z.x, z.y, "blood");
    game.shake = Math.max(game.shake || 0, 0.16);
    hit = true;
  }

  if (hit) p._swingLanded = true;

  game.zombies = game.zombies.filter((z) => {
    if (z.hp > 0) return true;
    onZombieKilled(game, z);
    return false;
  });
}

/** Daño al jugador con i-frames + knockback (Stardew). */
function hurtPlayer(game, fromX, fromY, damage, toastMsg) {
  const p = game.player;
  if ((p.invulnT || 0) > 0) return false;
  p.health -= damage;
  p.hurtFlash = 0.45;
  p.invulnT = 0.55;
  let dx = p.x - fromX;
  let dy = p.y - fromY;
  let len = Math.hypot(dx, dy);
  if (len < 0.08) {
    // Empuje hacia atrás respecto a tu facing si estás encima del zombie
    const a = (p.facingAng || 0) + Math.PI;
    dx = Math.cos(a);
    dy = Math.sin(a);
    len = 1;
  }
  p.kbVx = (dx / len) * 5.5;
  p.kbVy = (dy / len) * 5.5;
  game.shake = Math.max(game.shake || 0, 0.38);
  if (toastMsg) setToast(game, toastMsg);
  return true;
}

function build(game) {
  const p = game.player;
  p.gatherCd = 0.45;
  const recipe = BUILD[game.buildMode];
  if (!recipe) return;

  const aimDx = Math.cos(p.aim || 0);
  const aimDy = Math.sin(p.aim || 0);
  const bx = game.buildMode === "claim" ? Math.floor(p.x) : Math.floor(p.x + aimDx * 1.15);
  const by = game.buildMode === "claim" ? Math.floor(p.y) : Math.floor(p.y + aimDy * 1.15);
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
    setToast(game, "Base marcada. B → barricada / puerta · Enter coloca.");
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
  const hp = (38 + ((Math.random() * 28) | 0)) * scaleHp;
  return {
    x,
    y,
    hp,
    maxHp: hp,
    speed: (0.8 + Math.random() * 0.6) * scaleSpd,
    damage: 15 * scaleDmg,
    radius: 0.45,
    stun: 0,
    hitFlash: 0,
    attackCd: 0,
    wanderT: 0,
    wx: x,
    wy: y,
    vx: 0,
    vy: 0,
    walkPhase: 0,
    facing: 1,
    wave,
    boss: false,
    bossKind: null,
    chargeT: 0,
    chargeCd: 0,
    telegraph: 0,
  };
}

function makeBoss(x, y, wave, kind) {
  const def = BOSS_TYPES[kind] || BOSS_TYPES.bruiser;
  const scale = 1 + Math.max(0, wave - 3) * 0.12;
  const hp = def.hp * scale;
  return {
    x,
    y,
    hp,
    maxHp: hp,
    speed: def.speed * (1 + Math.max(0, wave - 3) * 0.03),
    damage: def.damage * (1 + Math.max(0, wave - 3) * 0.06),
    radius: def.radius,
    stun: 0,
    hitFlash: 0,
    attackCd: 0,
    wanderT: 0,
    wx: x,
    wy: y,
    vx: 0,
    vy: 0,
    walkPhase: 0,
    facing: 1,
    wave,
    boss: true,
    bossKind: def.id,
    name: def.name,
    color: def.color,
    head: def.head,
    chargeT: 0,
    chargeCd: 1.2,
    telegraph: 0,
    chargeSpeed: def.chargeSpeed,
    chargeDuration: def.chargeTime,
    chargeCooldown: def.chargeCd,
    aggroBonus: def.aggroBonus,
    knockback: def.knockback,
    screamNoise: def.screamNoise || 0,
    attackInterval: def.attackCd,
    lootTable: def.loot,
  };
}

function spawnBoss(game, wave, kind) {
  const p = game.player;
  for (let attempt = 0; attempt < 36; attempt++) {
    const ang = Math.random() * Math.PI * 2;
    const dist = 14 + Math.random() * 12;
    const x = p.x + Math.cos(ang) * dist;
    const y = p.y + Math.sin(ang) * dist;
    if (!canWalk(game.world, x, y, { zombie: true })) continue;
    const boss = makeBoss(x, y, wave, kind);
    game.zombies.push(boss);
    return boss;
  }
  const boss = makeBoss(p.x + 10, p.y, wave, kind);
  game.zombies.push(boss);
  return boss;
}

function dropLootAt(game, x, y, id, amount) {
  const key = `${Math.floor(x)},${Math.floor(y)}`;
  const prev = game.world.loot.get(key);
  if (prev && prev.id === id) {
    prev.amount = (prev.amount || 1) + amount;
    return;
  }
  if (!prev) {
    game.world.loot.set(key, { id, amount });
    return;
  }
  const key2 = `${Math.floor(x) + 1},${Math.floor(y)}`;
  if (!game.world.loot.has(key2)) game.world.loot.set(key2, { id, amount });
}

function onZombieKilled(game, z) {
  game.kills += 1;
  spawnFx(game, z.x, z.y, "death");
  game.shake = Math.max(game.shake || 0, z.boss ? 0.55 : 0.16);
  if (z.boss) {
    const drops = z.lootTable || BOSS_TYPES[z.bossKind]?.loot || [];
    for (const drop of drops) {
      const ox = (Math.random() - 0.5) * 1.6;
      const oy = (Math.random() - 0.5) * 1.6;
      dropLootAt(game, z.x + ox, z.y + oy, drop.id, drop.amount);
    }
    setToast(game, `¡${z.name || "Jefe"} abatido! Botín en el suelo.`);
    showWaveBanner(game, "JEFE DERROTADO", 2.0);
    return;
  }
  if (Math.random() < 0.32) {
    const id = Math.random() < 0.55 ? LOOT.SCRAP : LOOT.FOOD;
    dropLootAt(game, z.x, z.y, id, 1);
  }
}

function updateZombies(game, dt, phase) {
  const p = game.player;
  const baseAggro = (phase.night ? 11 : 7) + (game.noisePulse > 0 ? 6 : 0);
  game._zFrame = (game._zFrame || 0) + 1;
  const zFrame = game._zFrame;

  for (let zi = 0; zi < game.zombies.length; zi++) {
    const z = game.zombies[zi];
    z.stun = Math.max(0, z.stun - dt);
    z.hitFlash = Math.max(0, (z.hitFlash || 0) - dt);
    z.attackCd = Math.max(0, z.attackCd - dt);
    z.chargeCd = Math.max(0, (z.chargeCd || 0) - dt);
    z.telegraph = Math.max(0, (z.telegraph || 0) - dt);
    if (z.chargeT > 0) z.chargeT = Math.max(0, z.chargeT - dt);
    if (z.stun > 0) continue;

    // Lejos: actualizar 1 de cada 3 frames (jefes siempre)
    const roughDx = z.x - p.x;
    const roughDy = z.y - p.y;
    const roughD2 = roughDx * roughDx + roughDy * roughDy;
    if (!z.boss && roughD2 > 900 && ((zi + zFrame) % 3) !== 0) continue;

    const dist = Math.hypot(roughDx, roughDy);
    const aggro = baseAggro + (z.boss ? z.aggroBonus || 0 : 0);
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

    // Jefe: telegráfica + carga
    if (z.boss && dist < aggro && dist > 1.6 && z.chargeCd <= 0 && z.chargeT <= 0 && z.telegraph <= 0) {
      z.telegraph = 0.55;
      z.chargeCd = z.chargeCooldown || 4.5;
      if (z.screamNoise) game.noisePulse = Math.max(game.noisePulse || 0, z.screamNoise);
      setToast(game, `${z.name} prepara una carga…`);
    }
    if (z.boss && z.telegraph > 0 && z.telegraph - dt <= 0 && z.chargeT <= 0) {
      z.chargeT = z.chargeDuration || 0.55;
    }

    let spd = z.speed * (phase.night ? 1.28 : 1) * (dist < aggro ? 1.15 : 0.7);
    if (z.boss && z.chargeT > 0) spd = z.chargeSpeed || spd * 2.2;
    const dx = tx - z.x;
    const dy = ty - z.y;
    const len = Math.hypot(dx, dy) || 1;
    const wantX = (dx / len) * spd;
    const wantY = (dy / len) * spd;
    const zBlend = 1 - Math.exp(-(z.boss && z.chargeT > 0 ? 20 : 9) * dt);
    z.vx = (z.vx || 0) + (wantX - (z.vx || 0)) * zBlend;
    z.vy = (z.vy || 0) + (wantY - (z.vy || 0)) * zBlend;
    const nx = z.x + z.vx * dt;
    const ny = z.y + z.vy * dt;
    if (Math.abs(z.vx) > 0.04) z.facing = z.vx > 0 ? 1 : -1;
    z.walkPhase = (z.walkPhase || 0) + Math.hypot(z.vx, z.vy) * dt * 7;

    // Solo la puerta delante / bajo el zombie (no iterar todas)
    {
      const candidates = [
        `${Math.floor(z.x + (dx / len) * 0.7)},${Math.floor(z.y + (dy / len) * 0.7)}`,
        `${Math.floor(z.x)},${Math.floor(z.y)}`,
      ];
      for (const dk of candidates) {
        const door = game.world.doors.get(dk);
        if (!door || door.hp <= 0) continue;
        const [dx0, dy0] = dk.split(",").map(Number);
        if (Math.hypot(z.x - dx0 - 0.5, z.y - dy0 - 0.5) > 1.15) continue;
        door.hp -= 10 * dt;
        if (door.hp <= 0) {
          setTile(game.world, dx0, dy0, TILE.RUBBLE);
          game.world.doors.delete(dk);
          setToast(game, "¡Una puerta ha cedido!");
        }
        break;
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

    const reach = (z.radius || 0.45) + 0.18;
    if (dist < reach) {
      const onBase = tileAt(game.world, p.x, p.y) === TILE.BASE;
      const body = itemDef(p.equip.body);
      const biteMult = body?.biteMult ?? 1;
      const baseDmg = z.damage || 13;
      const charging = z.boss && z.chargeT > 0;
      const dmg = (onBase ? baseDmg * 0.55 : baseDmg) * biteMult * (charging ? 1.35 : 1);
      const msg = z.boss ? `¡${z.name} te golpea!` : "¡Un zombie te alcanza!";
      if (hurtPlayer(game, z.x, z.y, dmg, msg)) {
        game.shake = Math.max(game.shake || 0, z.boss ? 0.55 : 0.35);
        if (z.boss && z.knockback) {
          p.kbVx = (p.kbVx || 0) + (dx / len) * z.knockback * 3;
          p.kbVy = (p.kbVy || 0) + (dy / len) * z.knockback * 3;
        }
        if (charging) z.chargeT = 0;
      }
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
      game.waveBossKind = bossKindForWave(game.wave);
      game.waveBossSpawned = false;
      game.wavePhase = "spawning";
      if (game.waveBossKind) {
        const b = BOSS_TYPES[game.waveBossKind];
        setToast(game, `Oleada ${game.wave}: ${game.waveQuota} zombis + jefe ${b.name}.`);
        showWaveBanner(game, b.title, 2.6);
      } else {
        setToast(game, `Oleada ${game.wave}: llegan ${game.waveQuota} zombis.`);
        showWaveBanner(game, `OLEADA ${game.wave}`, 2.2);
      }
    }
    return;
  }

  if (game.wavePhase === "spawning") {
    game.waveSpawnStall = (game.waveSpawnStall || 0) + dt;
    const rate = 2.6 + game.wave * 0.18;
    if (game.waveSpawned < game.waveQuota && Math.random() < dt * rate) {
      if (spawnZombie(game, game.wave)) game.waveSpawned += 1;
    }
    // El jefe entra a mitad de la oleada (o al terminar el cupo)
    const mid = game.waveQuota * 0.45;
    if (
      game.waveBossKind &&
      !game.waveBossSpawned &&
      (game.waveSpawned >= mid || game.waveSpawned >= game.waveQuota || game.waveSpawnStall > 12)
    ) {
      const boss = spawnBoss(game, game.wave, game.waveBossKind);
      game.waveBossSpawned = true;
      setToast(game, `¡Aparece ${boss.name}!`);
      showWaveBanner(game, BOSS_TYPES[game.waveBossKind].title, 2.2);
    }
    if (
      (game.waveSpawned >= game.waveQuota || game.waveSpawnStall > 18) &&
      (!game.waveBossKind || game.waveBossSpawned)
    ) {
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
      game.waveBossKind = null;
      game.waveBossSpawned = false;
      setToast(game, `Oleada ${game.wave} limpia. Prepárate…`);
      showWaveBanner(game, `OLEADA ${game.wave} LIMPIA`, 1.8);
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

export function invUsed(p) {
  let n = 0;
  for (const [id, count] of Object.entries(p.inv)) {
    if (!count) continue;
    const def = itemDef(id);
    const equipped =
      def?.kind === "equip" &&
      (p.equip.hand === id || p.equip.body === id || p.equip.bag === id || p.equip.light === id);
    const free = equipped ? 1 : 0;
    n += Math.max(0, count - free) * (def?.weight ?? 1);
  }
  return n;
}

export function invCapacity(p) {
  let cap = BASE_CAPACITY;
  for (const slot of ["hand", "body", "bag", "light"]) {
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
      id: p.equip.hand,
      label: def.label,
      damage: def.damage ?? DEFAULT_WEAPON.damage,
      range: def.range ?? DEFAULT_WEAPON.range,
      attackCd: def.attackCd ?? DEFAULT_WEAPON.attackCd,
      stamina: def.stamina ?? DEFAULT_WEAPON.stamina,
      icon: def.icon || "⚔",
      firearm: !!def.firearm,
      ammo: def.ammo || null,
      pellets: def.pellets || 1,
      spread: def.spread || 0,
      bulletSpeed: def.bulletSpeed || 20,
      noise: def.noise || 4,
    };
  }
  return { id: null, firearm: false, ammo: null, pellets: 1, spread: 0, bulletSpeed: 20, noise: 2, ...DEFAULT_WEAPON };
}

function isAutomaticFire(p) {
  // Semiauto: solo click. (Reservado por si hay ametralladoras luego.)
  return false;
}

function fireWeapon(game) {
  const p = game.player;
  const weapon = equippedWeapon(p);
  if (!weapon.firearm) {
    // Clic con melee = golpe Stardew (hacia donde miras)
    startMeleeSwing(game);
    return;
  }
  const ammoId = weapon.ammo;
  if (!ammoId || (p.inv[ammoId] || 0) <= 0) {
    setToast(game, `Sin munición (${itemDef(ammoId)?.label || "balas"}).`);
    p.attackCd = 0.2;
    return;
  }
  p.inv[ammoId] -= 1;
  if (p.inv[ammoId] <= 0) delete p.inv[ammoId];
  p.attackCd = weapon.attackCd;
  p.stamina = Math.max(0, p.stamina - weapon.stamina);
  game.noisePulse = Math.max(game.noisePulse, Math.min(2.6, weapon.noise * 0.22));
  game.muzzleFlash = 0.16;
  game.shake = Math.max(game.shake || 0, weapon.pellets > 1 ? 0.28 : 0.14);

  const pellets = weapon.pellets || 1;
  for (let i = 0; i < pellets; i++) {
    const spread = (Math.random() - 0.5) * (weapon.spread || 0) * 2;
    const ang = p.aim + spread;
    game.bullets.push({
      x: p.x + Math.cos(ang) * 0.45,
      y: p.y + Math.sin(ang) * 0.45,
      vx: Math.cos(ang) * weapon.bulletSpeed,
      vy: Math.sin(ang) * weapon.bulletSpeed,
      life: weapon.range / weapon.bulletSpeed,
      damage: weapon.damage,
      from: "player",
    });
  }
  const left = p.inv[ammoId] || 0;
  if (left === 0) setToast(game, `${weapon.label}: sin balas.`);
  else if (left <= 5) setToast(game, `${weapon.label}: ${left} balas.`);
}

function updateBullets(game, dt) {
  const next = [];
  for (const b of game.bullets) {
    b.life -= dt;
    if (b.life <= 0) continue;
    const nx = b.x + b.vx * dt;
    const ny = b.y + b.vy * dt;
    // Colisión con muros
    if (!canWalk(game.world, nx, ny, { bullet: true })) continue;
    b.x = nx;
    b.y = ny;

    let hit = false;
    for (const z of game.zombies) {
      if (Math.hypot(z.x - b.x, z.y - b.y) < (z.radius || 0.45) + 0.05) {
        z.hp -= b.damage;
        z.stun = Math.max(z.stun || 0, 0.28);
        z.hitFlash = 0.18;
        z.x += Math.sign(b.vx || 1) * 0.28;
        spawnFx(game, z.x, z.y, "blood");
        hit = true;
        break;
      }
    }
    if (hit) continue;
    next.push(b);
  }
  game.bullets = next;
  game.zombies = game.zombies.filter((z) => {
    if (z.hp > 0) return true;
    onZombieKilled(game, z);
    return false;
  });
}


function spawnFx(game, x, y, kind) {
  if (!game.fx) game.fx = [];
  const n = kind === "death" ? 10 : 5;
  for (let i = 0; i < n; i++) {
    const ang = Math.random() * Math.PI * 2;
    const spd = kind === "death" ? 1.2 + Math.random() * 2.2 : 0.6 + Math.random() * 1.4;
    game.fx.push({
      x,
      y,
      vx: Math.cos(ang) * spd,
      vy: Math.sin(ang) * spd,
      life: kind === "death" ? 0.45 + Math.random() * 0.25 : 0.22 + Math.random() * 0.15,
      max: 0.5,
      kind,
      size: kind === "death" ? 2 + Math.random() * 3 : 1.5 + Math.random() * 2,
    });
  }
}

function showWaveBanner(game, text, dur = 2) {
  game.waveBanner = text;
  game.waveBannerT = dur;
}

function updateFx(game, dt) {
  if (!game.fx) return;
  game.fx = game.fx.filter((f) => {
    f.life -= dt;
    if (f.kind === "slash") return f.life > 0;
    f.x += (f.vx || 0) * dt;
    f.y += (f.vy || 0) * dt;
    f.vx = (f.vx || 0) * 0.92;
    f.vy = (f.vy || 0) * 0.92;
    return f.life > 0;
  });
}

/** Armas en inventario, en orden de hotbar (máx 5). */
export function hotbarSlots(game) {
  const p = game.player;
  const owned = WEAPON_HOTBAR.filter((id) => (p.inv[id] || 0) > 0);
  const slots = [];
  for (let i = 0; i < 5; i++) {
    const id = owned[i] || null;
    const def = id ? itemDef(id) : null;
    const ammoN = def?.firearm && def.ammo ? (p.inv[def.ammo] || 0) : null;
    slots.push({
      index: i,
      key: String(i + 1),
      id,
      label: def?.label || "",
      icon: def?.icon || "",
      ammo: ammoN,
      active: id && p.equip.hand === id,
      empty: !id,
    });
  }
  return slots;
}

export function equipPanel(game) {
  const p = game.player;
  const weapon = equippedWeapon(p);
  const body = itemDef(p.equip.body);
  const bag = itemDef(p.equip.bag);
  const light = itemDef(p.equip.light);
  return [
    {
      slot: "hand",
      tag: "Primaria",
      id: p.equip.hand,
      label: weapon.label,
      icon: weapon.icon || "✊",
      stat: p.equip.hand
        ? weapon.firearm
          ? `${weapon.damage} dmg · ${p.inv[weapon.ammo] || 0} balas`
          : `${weapon.damage} dmg`
        : "sin arma",
      empty: !p.equip.hand,
      primary: true,
    },
    {
      slot: "body",
      tag: "Ropa",
      id: p.equip.body,
      label: body?.label || "—",
      icon: body?.icon || "·",
      stat: body ? `prot. ${Math.round((1 - (body.biteMult ?? 1)) * 100)}%` : "camiseta",
      empty: !p.equip.body,
    },
    {
      slot: "bag",
      tag: "Mochila",
      id: p.equip.bag,
      label: bag?.label || "—",
      icon: bag?.icon || "·",
      stat: bag?.capacity ? `+${bag.capacity} carga` : "",
      empty: !p.equip.bag,
    },
    {
      slot: "light",
      tag: "Luz",
      id: p.equip.light,
      label: light?.label || "—",
      icon: light?.icon || "·",
      stat: light?.lightRadius ? `alcance ${light.lightRadius}` : "busca linterna",
      empty: !p.equip.light,
    },
  ];
}

export function equipHotbarSlot(game, index) {
  const slots = hotbarSlots(game);
  const slot = slots[index];
  if (!slot?.id) {
    setToast(game, `Hotbar ${index + 1} vacío.`);
    return;
  }
  const p = game.player;
  if (p.equip.hand === slot.id) {
    p.equip.hand = null;
    setToast(game, `Guardas ${slot.label.toLowerCase()} (mano libre).`);
    return;
  }
  p.equip.hand = slot.id;
  setToast(game, `Arma primaria: ${slot.label}.`);
}

/** T cicla por fases: ropa → mochila → luz → ropa… */
function tryEquipGear(game) {
  const p = game.player;
  if (!p.gearPhase) p.gearPhase = "clothes";

  const clothes = CLOTHES.filter((id) => (p.inv[id] || 0) > 0).sort(
    (a, b) => CLOTHES.indexOf(b) - CLOTHES.indexOf(a)
  );
  const bags = [LOOT.BAG_BIG, LOOT.BAG].filter((id) => (p.inv[id] || 0) > 0);
  const lights = [LOOT.FLASHLIGHT, LOOT.LANTERN].filter((id) => (p.inv[id] || 0) > 0);

  const apply = (slot, id, msg) => {
    const prev = p.equip[slot];
    p.equip[slot] = id;
    if (invUsed(p) > invCapacity(p)) {
      p.equip[slot] = prev;
      setToast(game, "Demasiada carga para ese cambio.");
      return false;
    }
    p.gatherCd = 0.15;
    setToast(game, msg);
    return true;
  };

  // ---- ROPA ----
  if (p.gearPhase === "clothes") {
    if (!clothes.length) {
      p.gearPhase = "bag";
    } else if (!p.equip.body || !clothes.includes(p.equip.body)) {
      if (!apply("body", clothes[0], `Te pones ${itemDef(clothes[0]).label.toLowerCase()}.`)) return;
      return;
    } else {
      const idx = clothes.indexOf(p.equip.body);
      if (idx < clothes.length - 1) {
        const next = clothes[idx + 1];
        if (!apply("body", next, `Te pones ${itemDef(next).label.toLowerCase()}.`)) return;
        return;
      }
      p.equip.body = null;
      p.gatherCd = 0.15;
      setToast(game, "Te quitas la ropa.");
      p.gearPhase = "bag";
      return;
    }
  }

  // ---- MOCHILA ----
  if (p.gearPhase === "bag") {
    if (!bags.length) {
      p.gearPhase = "light";
    } else if (!p.equip.bag) {
      if (!apply("bag", bags[0], `Equipas ${itemDef(bags[0]).label.toLowerCase()}.`)) {
        p.gearPhase = "light";
        // continuar a luz abajo
      } else return;
    } else {
      const idx = bags.indexOf(p.equip.bag);
      if (idx >= 0 && idx < bags.length - 1) {
        const next = bags[idx + 1];
        if (!apply("bag", next, `Equipas ${itemDef(next).label.toLowerCase()}.`)) return;
        return;
      }
      const bag = p.equip.bag;
      p.equip.bag = null;
      if (invUsed(p) > invCapacity(p)) {
        p.equip.bag = bag;
        setToast(game, "Vacía la mochila antes de quitártela.");
        p.gearPhase = "light";
        // no return — pasar a luz
      } else {
        p.gatherCd = 0.15;
        setToast(game, `Dejas ${itemDef(bag).label.toLowerCase()}.`);
        p.gearPhase = "light";
        return;
      }
    }
  }

  // ---- LUZ ----
  if (p.gearPhase === "light") {
    if (!lights.length) {
      p.gearPhase = "clothes";
      if (clothes.length) {
        apply("body", clothes[0], `Te pones ${itemDef(clothes[0]).label.toLowerCase()}.`);
      } else {
        setToast(game, "Nada de ropa/mochila/luz. Armas: teclas 1-5.");
      }
      return;
    }
    if (!p.equip.light) {
      apply("light", lights[0], `Equipas ${itemDef(lights[0]).label.toLowerCase()}.`);
      return;
    }
    const idx = lights.indexOf(p.equip.light);
    if (idx >= 0 && idx < lights.length - 1) {
      const next = lights[idx + 1];
      apply("light", next, `Equipas ${itemDef(next).label.toLowerCase()}.`);
      return;
    }
    setToast(game, `Apagas y guardas ${itemDef(p.equip.light).label.toLowerCase()}.`);
    p.equip.light = null;
    p.gatherCd = 0.15;
    p.gearPhase = "clothes";
    return;
  }

  p.gearPhase = "clothes";
  setToast(game, "Nada de ropa/mochila/luz. Armas: teclas 1-5.");
}

export function inventorySlots(game) {
  const p = game.player;
  const stacks = [LOOT.FOOD, LOOT.WATER, LOOT.SCRAP, LOOT.WOOD, LOOT.MED, LOOT.AMMO_9MM, LOOT.AMMO_SHOT, LOOT.AMMO_RIFLE].map((id) => ({
    id,
    label: lootLabel(id),
    n: p.inv[id] || 0,
    kind: "stack",
  }));
  const cap = {
    id: "cap",
    label: "Carga",
    n: `${invUsed(p)}/${invCapacity(p)}`,
    kind: "cap",
  };
  return [...stacks, cap];
}
