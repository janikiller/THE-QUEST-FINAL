import { createNoise } from "./noise.js";

/** Niebla Norte — ciudad zombie con manzanas reales y edificios entrables. */
export const TILE = {
  ROAD: 0,
  SIDEWALK: 1,
  FLOOR: 2,
  WALL: 3,
  RUBBLE: 4,
  PARK: 5,
  PARKING: 6,
  WATER: 7,
  ALLEY: 8,
  BARRICADE: 9,
  DOOR: 10,
  BASE: 11,
  CROSSWALK: 12,
};

export const TILE_META = {
  [TILE.ROAD]: { name: "asfalto", walk: true, color: "#3d3f42", speed: 1.05 },
  [TILE.SIDEWALK]: { name: "acera", walk: true, color: "#8a8680", speed: 1 },
  [TILE.FLOOR]: { name: "interior", walk: true, color: "#6b5a48", speed: 1, indoor: true },
  [TILE.WALL]: { name: "muro", walk: false, color: "#4a4540", solid: true },
  [TILE.RUBBLE]: { name: "escombros", walk: true, color: "#6a6258", speed: 0.65 },
  [TILE.PARK]: { name: "parque", walk: true, color: "#3f6a3a", speed: 0.95 },
  [TILE.PARKING]: { name: "parking", walk: true, color: "#4a4c50", speed: 1 },
  [TILE.WATER]: { name: "canal", walk: false, color: "#2a5a62", solid: true, drink: true },
  [TILE.ALLEY]: { name: "callejón", walk: true, color: "#3a3a3e", speed: 0.9 },
  [TILE.BARRICADE]: { name: "barricada", walk: false, color: "#7a5230", solid: true, built: true },
  [TILE.DOOR]: { name: "puerta", walk: true, color: "#8b6238", speed: 0.9, door: true },
  [TILE.BASE]: { name: "base", walk: true, color: "#4f6a40", speed: 1, indoor: true, base: true },
  [TILE.CROSSWALK]: { name: "paso", walk: true, color: "#4a4a4c", speed: 1 },
};

export const LOOT = {
  FOOD: "food",
  WATER: "water",
  SCRAP: "scrap",
  WOOD: "wood",
  MED: "med",
  // Equipo estilo Project Zomboid
  BAG: "bag",
  BAG_BIG: "bag_big",
  BAT: "bat",
  CROWBAR: "crowbar",
  KNIFE: "knife",
  AXE: "axe",
  PAN: "pan",
  HAMMER: "hammer",
  SHIRT: "shirt",
  JACKET: "jacket",
  HOODIE: "hoodie",
  RAINCOAT: "raincoat",
  VEST: "vest",
  FLASHLIGHT: "flashlight",
  LANTERN: "lantern",
  // Armas de fuego + munición
  PISTOL: "pistol",
  SHOTGUN: "shotgun",
  RIFLE: "rifle",
  AMMO_9MM: "ammo_9mm",
  AMMO_SHOT: "ammo_shot",
  AMMO_RIFLE: "ammo_rifle",
};

/** Ropa ciclable con T / panel Ropa */
export const CLOTHES = [LOOT.VEST, LOOT.RAINCOAT, LOOT.JACKET, LOOT.HOODIE, LOOT.SHIRT];

/** Orden de armas en hotbar (mano primaria) */
export const WEAPON_HOTBAR = [
  LOOT.PISTOL,
  LOOT.SHOTGUN,
  LOOT.RIFLE,
  LOOT.BAT,
  LOOT.CROWBAR,
  LOOT.AXE,
  LOOT.HAMMER,
  LOOT.KNIFE,
  LOOT.PAN,
];

const LOOT_DEFS = {
  [LOOT.FOOD]: { label: "Latas", gather: "latas de comida", kind: "stack", weight: 1, icon: "🥫" },
  [LOOT.WATER]: { label: "Agua", gather: "botella de agua", kind: "stack", weight: 1, icon: "🧴" },
  [LOOT.SCRAP]: { label: "Chatarra", gather: "chatarra", kind: "stack", weight: 1, icon: "🔩" },
  [LOOT.WOOD]: { label: "Tablas", gather: "tablas", kind: "stack", weight: 1, icon: "🪵" },
  [LOOT.MED]: { label: "Botiquín", gather: "botiquín", kind: "stack", weight: 1, icon: "✚" },
  [LOOT.BAG]: {
    label: "Mochila",
    gather: "una mochila",
    kind: "equip",
    slot: "bag",
    capacity: 8,
    weight: 1,
    icon: "🎒",
  },
  [LOOT.BAG_BIG]: {
    label: "Mochila grande",
    gather: "una mochila grande",
    kind: "equip",
    slot: "bag",
    capacity: 14,
    weight: 1,
    icon: "🎒",
  },
  [LOOT.BAT]: {
    label: "Bate",
    gather: "un bate de béisbol",
    kind: "equip",
    slot: "hand",
    weapon: true,
    damage: 48,
    range: 1.55,
    attackCd: 0.52,
    stamina: 11,
    weight: 1,
    icon: "🏏",
  },
  [LOOT.CROWBAR]: {
    label: "Palanca",
    gather: "una palanca",
    kind: "equip",
    slot: "hand",
    weapon: true,
    damage: 40,
    range: 1.45,
    attackCd: 0.45,
    stamina: 9,
    weight: 1,
    icon: "⛏️",
  },
  [LOOT.AXE]: {
    label: "Hacha",
    gather: "un hacha",
    kind: "equip",
    slot: "hand",
    weapon: true,
    damage: 58,
    range: 1.5,
    attackCd: 0.62,
    stamina: 14,
    weight: 2,
    icon: "🪓",
  },
  [LOOT.HAMMER]: {
    label: "Martillo",
    gather: "un martillo",
    kind: "equip",
    slot: "hand",
    weapon: true,
    damage: 36,
    range: 1.25,
    attackCd: 0.4,
    stamina: 8,
    weight: 1,
    icon: "🔨",
  },
  [LOOT.KNIFE]: {
    label: "Cuchillo",
    gather: "un cuchillo",
    kind: "equip",
    slot: "hand",
    weapon: true,
    damage: 28,
    range: 1.2,
    attackCd: 0.28,
    stamina: 5,
    weight: 1,
    icon: "🔪",
  },
  [LOOT.PAN]: {
    label: "Sartén",
    gather: "una sartén",
    kind: "equip",
    slot: "hand",
    weapon: true,
    damage: 32,
    range: 1.3,
    attackCd: 0.48,
    stamina: 9,
    weight: 1,
    icon: "🍳",
  },
  [LOOT.SHIRT]: {
    label: "Camisa",
    gather: "una camisa",
    kind: "equip",
    slot: "body",
    biteMult: 0.95,
    capacity: 0,
    weight: 1,
    icon: "👕",
    wear: { style: "shirt", fill: "#6a3a3a", trim: "#4a2828", accent: "#c8a060" },
  },
  [LOOT.JACKET]: {
    label: "Chaqueta",
    gather: "una chaqueta",
    kind: "equip",
    slot: "body",
    biteMult: 0.7,
    capacity: 2,
    weight: 1,
    icon: "🧥",
    wear: { style: "jacket", fill: "#2f4050", trim: "#1e2a34", accent: "#c8a060" },
  },
  [LOOT.HOODIE]: {
    label: "Sudadera",
    gather: "una sudadera",
    kind: "equip",
    slot: "body",
    biteMult: 0.85,
    capacity: 1,
    weight: 1,
    icon: "🧥",
    wear: { style: "hoodie", fill: "#3a5a3a", trim: "#2a3a28", accent: "#8a9a70" },
  },
  [LOOT.RAINCOAT]: {
    label: "Chubasquero",
    gather: "un chubasquero",
    kind: "equip",
    slot: "body",
    biteMult: 0.8,
    capacity: 1,
    weight: 1,
    icon: "🧥",
    wear: { style: "raincoat", fill: "#c4a030", trim: "#8a7020", accent: "#2a2a28" },
  },
  [LOOT.VEST]: {
    label: "Chaleco",
    gather: "un chaleco táctico",
    kind: "equip",
    slot: "body",
    biteMult: 0.55,
    capacity: 3,
    weight: 2,
    icon: "🦺",
    wear: { style: "vest", fill: "#3a3a32", trim: "#1e1e18", accent: "#6a7a40" },
  },
  [LOOT.FLASHLIGHT]: {
    label: "Linterna",
    gather: "una linterna",
    kind: "equip",
    slot: "light",
    lightRadius: 150,
    lightWarm: false,
    weight: 1,
    icon: "🔦",
  },
  [LOOT.LANTERN]: {
    label: "Farol",
    gather: "un farol",
    kind: "equip",
    slot: "light",
    lightRadius: 120,
    lightWarm: true,
    weight: 1,
    icon: "🏮",
  },
  [LOOT.PISTOL]: {
    label: "Pistola",
    gather: "una pistola",
    kind: "equip",
    slot: "hand",
    weapon: true,
    firearm: true,
    damage: 34,
    range: 9,
    attackCd: 0.28,
    stamina: 2,
    weight: 1,
    icon: "🔫",
    ammo: LOOT.AMMO_9MM,
    pellets: 1,
    spread: 0.04,
    bulletSpeed: 22,
    noise: 9,
  },
  [LOOT.SHOTGUN]: {
    label: "Escopeta",
    gather: "una escopeta",
    kind: "equip",
    slot: "hand",
    weapon: true,
    firearm: true,
    damage: 22,
    range: 5.5,
    attackCd: 0.85,
    stamina: 6,
    weight: 2,
    icon: "🔫",
    ammo: LOOT.AMMO_SHOT,
    pellets: 5,
    spread: 0.22,
    bulletSpeed: 18,
    noise: 14,
  },
  [LOOT.RIFLE]: {
    label: "Rifle",
    gather: "un rifle de caza",
    kind: "equip",
    slot: "hand",
    weapon: true,
    firearm: true,
    damage: 62,
    range: 14,
    attackCd: 0.7,
    stamina: 5,
    weight: 2,
    icon: "🔫",
    ammo: LOOT.AMMO_RIFLE,
    pellets: 1,
    spread: 0.02,
    bulletSpeed: 28,
    noise: 12,
  },
  [LOOT.AMMO_9MM]: {
    label: "9mm",
    gather: "munición 9mm",
    kind: "stack",
    weight: 0.15,
    icon: "🔸",
  },
  [LOOT.AMMO_SHOT]: {
    label: "Cartuchos",
    gather: "cartuchos de escopeta",
    kind: "stack",
    weight: 0.2,
    icon: "🔴",
  },
  [LOOT.AMMO_RIFLE]: {
    label: "Munición rifle",
    gather: "munición de rifle",
    kind: "stack",
    weight: 0.18,
    icon: "🟠",
  },
};

export const BASE_CAPACITY = 12;

export function itemDef(id) {
  return LOOT_DEFS[id] || null;
}

export function isEquipItem(id) {
  return LOOT_DEFS[id]?.kind === "equip";
}

/** Muebles interiores. searchable = se registran con E. */
export const FURNITURE = {
  table: { label: "Mesa", searchable: false },
  bed: { label: "Cama", searchable: false },
  chair: { label: "Silla", searchable: false },
  sofa: { label: "Sofá", searchable: false },
  desk: { label: "Escritorio", searchable: true },
  nightstand: { label: "Mesita", searchable: true },
  counter: { label: "Mostrador", searchable: true },
  sink: { label: "Fregadero", searchable: false },
  stove: { label: "Cocina", searchable: false },
  plant: { label: "Planta", searchable: false },
  shelf: { label: "Estantería", searchable: true },
  crate: { label: "Cajón", searchable: true },
  cabinet: { label: "Armario", searchable: true },
  drawer: { label: "Cómoda", searchable: true },
  fridge: { label: "Nevera", searchable: true },
  locker: { label: "Taquilla", searchable: true },
};

const RUG_PALETTES = {
  residential: ["#7a3a3a", "#3a4a6a", "#4a5a3a", "#6a4a3a", "#4a3a5a"],
  shop: ["#5a3a28", "#3a4a48", "#6a4a28", "#4a3a3a"],
  warehouse: ["#3a3a38", "#4a4840", "#3a4038"],
  tower: ["#3a4558", "#4a4858", "#3a4a4a"],
  block: ["#5a4040", "#3a4a52", "#4a4838"],
};

const CONTAINER_LOOT = {
  shelf: [
    { id: LOOT.FOOD, w: 3 },
    { id: LOOT.SCRAP, w: 2 },
    { id: LOOT.WOOD, w: 2 },
    { id: LOOT.WATER, w: 1 },
    { id: LOOT.BAG, w: 1 },
    { empty: true, w: 2 },
  ],
  crate: [
    { id: LOOT.SCRAP, w: 3 },
    { id: LOOT.WOOD, w: 3 },
    { id: LOOT.FOOD, w: 1 },
    { id: LOOT.CROWBAR, w: 1 },
    { id: LOOT.HAMMER, w: 1 },
    { empty: true, w: 2 },
  ],
  cabinet: [
    { id: LOOT.FOOD, w: 2 },
    { id: LOOT.MED, w: 2 },
    { id: LOOT.WOOD, w: 1 },
    { id: LOOT.SCRAP, w: 2 },
    { id: LOOT.JACKET, w: 1 },
    { id: LOOT.HOODIE, w: 1 },
    { id: LOOT.BAG, w: 1 },
    { id: LOOT.PAN, w: 1 },
    { id: LOOT.LANTERN, w: 1 },
    { empty: true, w: 2 },
  ],
  drawer: [
    { id: LOOT.SCRAP, w: 3 },
    { id: LOOT.MED, w: 2 },
    { id: LOOT.FOOD, w: 1 },
    { id: LOOT.KNIFE, w: 1 },
    { id: LOOT.FLASHLIGHT, w: 1 },
    { id: LOOT.SHIRT, w: 2 },
    { empty: true, w: 2 },
  ],
  fridge: [
    { id: LOOT.FOOD, w: 4 },
    { id: LOOT.WATER, w: 4 },
    { empty: true, w: 2 },
  ],
  locker: [
    { id: LOOT.SCRAP, w: 3 },
    { id: LOOT.WOOD, w: 2 },
    { id: LOOT.MED, w: 2 },
    { id: LOOT.FOOD, w: 1 },
    { id: LOOT.BAT, w: 1 },
    { id: LOOT.AXE, w: 1 },
    { id: LOOT.BAG_BIG, w: 1 },
    { id: LOOT.FLASHLIGHT, w: 2 },
    { id: LOOT.VEST, w: 2 },
    { id: LOOT.RAINCOAT, w: 1 },
    { id: LOOT.PISTOL, w: 1 },
    { id: LOOT.SHOTGUN, w: 1 },
    { id: LOOT.AMMO_9MM, w: 2 },
    { id: LOOT.AMMO_SHOT, w: 1 },
    { empty: true, w: 2 },
  ],
  desk: [
    { id: LOOT.SCRAP, w: 2 },
    { id: LOOT.MED, w: 1 },
    { id: LOOT.FOOD, w: 1 },
    { id: LOOT.KNIFE, w: 1 },
    { id: LOOT.FLASHLIGHT, w: 2 },
    { id: LOOT.SHIRT, w: 1 },
    { id: LOOT.AMMO_9MM, w: 2 },
    { id: LOOT.PISTOL, w: 1 },
    { empty: true, w: 2 },
  ],
  nightstand: [
    { id: LOOT.MED, w: 2 },
    { id: LOOT.FOOD, w: 1 },
    { id: LOOT.SCRAP, w: 1 },
    { id: LOOT.KNIFE, w: 1 },
    { id: LOOT.LANTERN, w: 1 },
    { id: LOOT.HOODIE, w: 1 },
    { empty: true, w: 2 },
  ],
  counter: [
    { id: LOOT.FOOD, w: 3 },
    { id: LOOT.WATER, w: 2 },
    { id: LOOT.SCRAP, w: 1 },
    { id: LOOT.PAN, w: 1 },
    { id: LOOT.BAT, w: 1 },
    { empty: true, w: 2 },
  ],
};

export const BUILD = {
  wall: { label: "Barricada", tile: TILE.BARRICADE, cost: { scrap: 2, wood: 1 }, hint: "2 chatarra + 1 tabla" },
  door: { label: "Puerta", tile: TILE.DOOR, cost: { scrap: 2, wood: 1 }, hint: "2 chatarra + 1 tabla" },
  claim: { label: "Marcar base", tile: TILE.BASE, cost: { scrap: 1, wood: 1 }, hint: "1 chatarra + 1 tabla" },
};

const BLOCK = 10;
const ROAD_W = 2;

const FACADE = ["#6b4f3a", "#4a5560", "#7a5a48", "#5a4a3a", "#3d4a52", "#6a5850", "#4e5a48", "#5c4a55", "#7a6a58", "#455060"];
const AWNING = ["#8a3030", "#2a4a6a", "#6a4a20", "#3a5a48", "#5a3050", "#4a4a4a"];
const BUILDING_NAMES = [
  "Bloque Luna", "Edificio Sol", "Casa Mistral", "Torre Niebla", "Mercado Sur",
  "Farmacia Alba", "Taller Río", "Residencial 9", "Almacén Norte", "Café Gris",
  "Panadería Sur", "Clínica Niebla", "Bar El Canal", "Lofts Crespo", "Depósito Este",
];
const STREET_NAMES = ["Luna", "Sol", "Mistral", "Niebla", "Río", "Alba", "Crespo", "Norte", "Sur", "Puerto"];

export function generateWorld(size = 100, seed = (Math.random() * 1e9) | 0) {
  const noise = createNoise(seed);
  const tiles = new Uint8Array(size * size);
  const loot = new Map();
  const doors = new Map();
  const buildings = [];
  const props = [];
  const interiors = new Map(); // "x,y" -> { type, searched }
  const decor = new Map(); // "x,y" -> { kind: "rug"|"mat", color, variant }

  tiles.fill(TILE.SIDEWALK);

  const canalY = 42 + ((noise.noise2(3, 7) * 10) | 0);
  for (let x = 0; x < size; x++) {
    for (let dy = -1; dy <= 1; dy++) {
      const y = canalY + dy;
      if (y >= 0 && y < size) tiles[y * size + x] = TILE.WATER;
    }
  }

  // Calles en retícula
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      if (tiles[y * size + x] === TILE.WATER) continue;
      const onV = x % BLOCK < ROAD_W;
      const onH = y % BLOCK < ROAD_W;
      if (onV || onH) tiles[y * size + x] = TILE.ROAD;
    }
  }

  // Pasos de cebra en cruces
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      if (tiles[y * size + x] !== TILE.ROAD) continue;
      const nearV = x % BLOCK < ROAD_W;
      const nearH = y % BLOCK < ROAD_W;
      if (nearV && nearH) tiles[y * size + x] = TILE.CROSSWALK;
    }
  }

  // Manzanas
  for (let by = ROAD_W; by < size - ROAD_W; by += BLOCK) {
    for (let bx = ROAD_W; bx < size - ROAD_W; bx += BLOCK) {
      if (by <= canalY + 3 && by + BLOCK >= canalY - 1) {
        paveQuay(tiles, size, bx, by, props, noise);
        continue;
      }
      const roll = noise.noise2(bx * 0.13, by * 0.13);
      if (roll < 0.16) pavePark(tiles, size, bx, by, props, noise);
      else if (roll < 0.26) paveParking(tiles, size, bx, by, props, noise);
      else if (roll < 0.34) paveAlley(tiles, size, bx, by, props, noise);
      else carveCityBuilding(tiles, size, bx, by, doors, buildings, interiors, decor, props, noise, seed);
    }
  }

  // Puentes del canal
  for (let x = 0; x < size; x++) {
    if (x % BLOCK < ROAD_W) {
      for (let dy = -1; dy <= 1; dy++) {
        const y = canalY + dy;
        if (y >= 0 && y < size) tiles[y * size + x] = TILE.ROAD;
      }
    }
  }

  // Farolas, hidrantes y papeleras en aceras junto a calles
  for (let y = 1; y < size - 1; y++) {
    for (let x = 1; x < size - 1; x++) {
      if (tiles[y * size + x] !== TILE.SIDEWALK) continue;
      let nearRoad = false;
      for (let oy = -1; oy <= 1; oy++) {
        for (let ox = -1; ox <= 1; ox++) {
          const t = tiles[(y + oy) * size + (x + ox)];
          if (t === TILE.ROAD || t === TILE.CROSSWALK) nearRoad = true;
        }
      }
      if (!nearRoad) continue;
      const n = noise.noise2(x * 0.4, y * 0.4);
      // Farolas regulares en acera (cada ~8 tiles) para pozos de luz nocturnos
      const lampRow = y % 8 === 3 && x % 4 !== 1;
      const lampCol = x % 8 === 3 && y % 4 !== 1;
      if (lampRow || lampCol) {
        if (!props.some((p) => p.type === "lamp" && Math.abs(p.x - (x + 0.5)) < 1.2 && Math.abs(p.y - (y + 0.5)) < 1.2)) {
          props.push({ type: "lamp", x: x + 0.5, y: y + 0.5 });
        }
      } else if ((x * 5 + y * 3) % 29 === 0) props.push({ type: "hydrant", x: x + 0.55, y: y + 0.55 });
      else if ((x * 7 + y) % 23 === 0 && n > 0.2) props.push({ type: "trash", x: x + 0.4, y: y + 0.55 });
      else if ((x + y * 5) % 37 === 0) props.push({ type: "planter", x: x + 0.5, y: y + 0.5, tone: n > 0.5 ? 1 : 0 });
    }
  }

  // Paradas de bus en tramos largos de calle
  for (let y = ROAD_W; y < size - ROAD_W; y += BLOCK) {
    for (let x = ROAD_W + 3; x < size - 3; x += BLOCK * 2) {
      if (tiles[y * size + x] !== TILE.SIDEWALK && tiles[(y + ROAD_W) * size + x] !== TILE.SIDEWALK) continue;
      const sy = tiles[(y + ROAD_W) * size + x] === TILE.SIDEWALK ? y + ROAD_W : y;
      if (tiles[sy * size + x] === TILE.SIDEWALK) {
        props.push({ type: "busStop", x: x + 0.5, y: sy + 0.5 });
      }
    }
  }

  // Loot en el suelo (pocas cosas dentro: el botín está en armarios)
  for (let y = 1; y < size - 1; y++) {
    for (let x = 1; x < size - 1; x++) {
      const t = tiles[y * size + x];
      const r = noise.noise2(x * 2.1 + 4, y * 2.1 + seed * 0.0001);
      if (t === TILE.FLOOR) {
        if (interiors.has(`${x},${y}`)) continue;
        if (r < 0.045) putLoot(loot, x, y, pickLoot(r));
      } else if (t === TILE.RUBBLE && r < 0.1) putLoot(loot, x, y, r < 0.05 ? LOOT.SCRAP : LOOT.WOOD);
      else if (t === TILE.PARKING && r < 0.06) putLoot(loot, x, y, LOOT.SCRAP);
      else if (t === TILE.PARK && r < 0.05) putLoot(loot, x, y, LOOT.WOOD);
      else if (t === TILE.ALLEY && r < 0.08) putLoot(loot, x, y, r < 0.04 ? LOOT.FOOD : LOOT.SCRAP);
      else if (t === TILE.SIDEWALK && r < 0.015) putLoot(loot, x, y, LOOT.SCRAP);
    }
  }

  // Coches aparcados en bordes de calle
  for (let y = 2; y < size - 2; y++) {
    for (let x = 2; x < size - 2; x++) {
      if (tiles[y * size + x] !== TILE.ROAD && tiles[y * size + x] !== TILE.CROSSWALK) continue;
      if (noise.noise2(x * 0.7, y * 0.7) > 0.82 && (x + y * 3) % 17 === 0) {
        const colors = ["#6a3030", "#2a3a4a", "#3a3a3a", "#4a5a30", "#5a4a20"];
        props.push({
          type: "car",
          x: x + 0.5,
          y: y + 0.5,
          rot: x % BLOCK < ROAD_W ? 0 : 1,
          color: colors[(x * 5 + y) % colors.length],
          wreck: noise.noise2(x + 2, y + 4) > 0.85,
        });
      }
    }
  }

  // Semáforos solo en cruces principales (cada 2 manzanas)
  for (let by = 0; by < size; by += BLOCK * 2) {
    for (let bx = 0; bx < size; bx += BLOCK * 2) {
      if (bx + 1 >= size || by + 1 >= size) continue;
      if (tiles[by * size + bx] !== TILE.CROSSWALK && tiles[by * size + bx] !== TILE.ROAD) continue;
      props.push({ type: "traffic", x: bx + ROAD_W + 0.35, y: by + ROAD_W + 0.35 });
      // Placa de calle
      {
        const a = (bx / BLOCK + by / BLOCK) % STREET_NAMES.length;
        const b = (((bx / BLOCK) * 3 + (by / BLOCK) * 5) + 1) % STREET_NAMES.length;
        props.push({
          type: "streetSign",
          x: bx + ROAD_W + 0.85,
          y: by + ROAD_W + 0.2,
          label: STREET_NAMES[a],
          label2: STREET_NAMES[b === a ? (a + 1) % STREET_NAMES.length : b],
        });
      }
    }
  }

  // Barcas / restos en el canal
  for (let x = 4; x < size - 4; x += 7) {
    if (noise.noise2(x * 0.2, canalY) > 0.35) {
      props.push({
        type: "boat",
        x: x + 0.5 + noise.noise2(x, 1) * 0.4,
        y: canalY + 0.5,
        wreck: noise.noise2(x + 1, canalY) > 0.7,
      });
    }
  }

  // Tapas de alcantarilla
  for (let y = 3; y < size - 3; y++) {
    for (let x = 3; x < size - 3; x++) {
      if (tiles[y * size + x] !== TILE.ROAD) continue;
      if ((x * 17 + y * 31) % 47 === 0) props.push({ type: "manhole", x: x + 0.5, y: y + 0.5 });
    }
  }

  props.sort((a, b) => a.y - b.y);

  const spawn = findSpawn(tiles, size, noise);
  return { size, seed, tiles, loot, doors, buildings, props, interiors, decor, spawn, noise, canalY };
}

function blockBounds(bx, by, size) {
  const x0 = bx;
  const y0 = by;
  const x1 = Math.min(size - 1, bx + BLOCK - ROAD_W - 1);
  const y1 = Math.min(size - 1, by + BLOCK - ROAD_W - 1);
  return { x0, y0, x1, y1 };
}

function paveSidewalkRing(tiles, size, bx, by) {
  const { x0, y0, x1, y1 } = blockBounds(bx, by, size);
  for (let y = y0; y <= y1; y++) {
    for (let x = x0; x <= x1; x++) {
      if (tiles[y * size + x] === TILE.ROAD || tiles[y * size + x] === TILE.WATER || tiles[y * size + x] === TILE.CROSSWALK) continue;
      tiles[y * size + x] = TILE.SIDEWALK;
    }
  }
  return { x0, y0, x1, y1 };
}

function carveCityBuilding(tiles, size, bx, by, doors, buildings, interiors, decor, props, noise, seed) {
  const ring = paveSidewalkRing(tiles, size, bx, by);
  // Edificio inset 1 tile (deja acera)
  const x0 = ring.x0 + 1;
  const y0 = ring.y0 + 1;
  const x1 = ring.x1 - 1;
  const y1 = ring.y1 - 1;
  if (x1 - x0 < 3 || y1 - y0 < 3) return;

  const facade = FACADE[((bx * 17 + by * 31 + (seed * 3) + ((bx / BLOCK) | 0) * 7) >>> 0) % FACADE.length];
  const name = BUILDING_NAMES[((bx * 5 + by * 11 + seed) >>> 0) % BUILDING_NAMES.length];
  const floors = 2 + (((noise.noise2(bx, by) * 4) | 0) % 4);
  const styleRoll = noise.noise2(bx * 0.31, by * 0.27);
  let style = "block";
  if (floors >= 4) style = "tower";
  else if (styleRoll < 0.22) style = "shop";
  else if (styleRoll < 0.4) style = "warehouse";
  else if (styleRoll < 0.62) style = "residential";
  const tint = ((noise.noise2(bx * 0.17, by * 0.19) * 24) | 0) - 12;
  const awning = AWNING[((bx * 3 + by * 5 + seed) >>> 0) % AWNING.length];
  const facadeTinted = shadeHex(facade, tint);
  const floorStyle =
    style === "warehouse" ? "concrete" :
    style === "shop" ? "tile" :
    style === "tower" ? "office" :
    "wood";
  const rugPalette = RUG_PALETTES[style] || RUG_PALETTES.block;
  const accent = rugPalette[((bx * 7 + by * 3 + seed) >>> 0) % rugPalette.length];

  for (let y = y0; y <= y1; y++) {
    for (let x = x0; x <= x1; x++) {
      const edge = x === x0 || x === x1 || y === y0 || y === y1;
      tiles[y * size + x] = edge ? TILE.WALL : TILE.FLOOR;
    }
  }

  // Puerta hacia la calle más cercana
  const side = (noise.noise2(bx * 0.5, by * 0.5) * 4) | 0;
  let dx = ((x0 + x1) / 2) | 0;
  let dy = ((y0 + y1) / 2) | 0;
  if (side === 0) dy = y0;
  else if (side === 1) dy = y1;
  else if (side === 2) dx = x0;
  else dx = x1;
  tiles[dy * size + dx] = TILE.DOOR;
  doors.set(`${dx},${dy}`, { hp: 50 });

  decorateInterior({
    tiles, size, interiors, decor,
    x0, y0, x1, y1, doorX: dx, doorY: dy, side,
    style, accent, noise, bx, by,
  });

  // Mobiliario urbano en acera
  if (noise.noise2(bx + 2, by + 2) > 0.45) {
    props.push({ type: "dumpster", x: ring.x0 + 0.5, y: ((y0 + y1) / 2) + 0.15 });
  }
  if (noise.noise2(bx + 5, by + 1) > 0.55) {
    props.push({ type: "sign", x: dx + (side === 2 ? -0.7 : side === 3 ? 0.7 : 0), y: dy + (side === 0 ? -0.7 : side === 1 ? 0.7 : 0), label: name.split(" ")[0] });
  }
  props.push({ type: "awning", x: dx + 0.5, y: dy + 0.5, side, color: awning, wide: style === "shop" });
  if (style === "residential" && noise.noise2(bx + 8, by) > 0.4) {
    props.push({ type: "planter", x: dx + (side >= 2 ? 0 : side === 0 ? 0.2 : -0.2) + 0.5, y: dy + (side < 2 ? 0 : 0.2) + 0.5, tone: 1 });
  }

  buildings.push({
    x0, y0, x1, y1, doorX: dx, doorY: dy,
    facade: facadeTinted, name, floors, style, awning, floorStyle, accent,
  });
}

function pavePark(tiles, size, bx, by, props, noise) {
  const { x0, y0, x1, y1 } = paveSidewalkRing(tiles, size, bx, by);
  const midX = ((x0 + x1) / 2) | 0;
  const midY = ((y0 + y1) / 2) | 0;
  const diagonal = noise.noise2(bx, by) > 0.5;
  for (let y = y0 + 1; y <= y1 - 1; y++) {
    for (let x = x0 + 1; x <= x1 - 1; x++) {
      const onCross = x === midX || y === midY;
      const onDiag = diagonal && Math.abs((x - midX) - (y - midY)) <= 0;
      if (onCross || onDiag) tiles[y * size + x] = TILE.SIDEWALK;
      else tiles[y * size + x] = TILE.PARK;
      if (tiles[y * size + x] === TILE.PARK && noise.noise2(x * 0.9, y * 0.9) > 0.68) {
        props.push({
          type: "tree",
          x: x + 0.35 + noise.noise2(x, y) * 0.3,
          y: y + 0.35 + noise.noise2(y, x) * 0.3,
          r: 11 + noise.noise2(x, y) * 9,
          tone: noise.noise2(x + 3, y) > 0.5 ? 0 : 1,
        });
      }
    }
  }
  props.push({ type: "bench", x: midX - 1.2, y: midY + 0.5 });
  props.push({ type: "bench", x: midX + 1.2, y: midY + 0.5 });
  props.push({ type: "bench", x: midX + 0.5, y: midY - 1.3, rot: 1 });
  props.push({ type: "fountain", x: midX + 0.5, y: midY + 0.5 });
  // Jardineras en las esquinas del parque
  props.push({ type: "planter", x: x0 + 1.5, y: y0 + 1.5, tone: 0 });
  props.push({ type: "planter", x: x1 - 0.5, y: y0 + 1.5, tone: 1 });
  props.push({ type: "planter", x: x0 + 1.5, y: y1 - 0.5, tone: 1 });
  props.push({ type: "planter", x: x1 - 0.5, y: y1 - 0.5, tone: 0 });
  // Parque: sin farola fija (la noche se siente más vacía)
}

function paveParking(tiles, size, bx, by, props, noise) {
  const { x0, y0, x1, y1 } = paveSidewalkRing(tiles, size, bx, by);
  const colors = ["#5a2020", "#2a3040", "#3a3a38", "#4a5030", "#6a5a20", "#203040", "#503828"];
  for (let y = y0 + 1; y <= y1 - 1; y++) {
    for (let x = x0 + 1; x <= x1 - 1; x++) {
      tiles[y * size + x] = TILE.PARKING;
      if ((x + y) % 3 === 0 && noise.noise2(x, y) > 0.35) {
        props.push({
          type: "car",
          x: x + 0.5,
          y: y + 0.5,
          rot: 1,
          color: colors[(x * 3 + y) % colors.length],
          wreck: noise.noise2(x + 9, y) > 0.78,
        });
      }
    }
  }
  if (noise.noise2(bx, by + 3) > 0.4) {
    props.push({ type: "dumpster", x: x1 - 0.6, y: y1 - 0.8, color: "#3a3a42" });
  }
}

function paveAlley(tiles, size, bx, by, props, noise) {
  const { x0, y0, x1, y1 } = paveSidewalkRing(tiles, size, bx, by);
  for (let y = y0 + 1; y <= y1 - 1; y++) {
    for (let x = x0 + 1; x <= x1 - 1; x++) {
      tiles[y * size + x] = noise.noise2(x, y) > 0.65 ? TILE.RUBBLE : TILE.ALLEY;
    }
  }
  props.push({ type: "dumpster", x: ((x0 + x1) / 2) + 0.5, y: y0 + 1.5 });
  props.push({ type: "dumpster", x: ((x0 + x1) / 2) - 0.2, y: y1 - 0.8, color: "#3a4a58" });
  props.push({ type: "trash", x: x0 + 1.4, y: ((y0 + y1) / 2) });
  if (noise.noise2(bx, by) > 0.4) {
    props.push({ type: "graffiti", x: x0 + 1.5, y: y0 + 2.2 });
  }
  if (noise.noise2(bx + 2, by) > 0.5) {
    props.push({ type: "graffiti", x: x1 - 1.2, y: y1 - 1.5, text: "CRESPO" });
  }
}

function paveQuay(tiles, size, bx, by, props, noise) {
  const { x0, y0, x1, y1 } = paveSidewalkRing(tiles, size, bx, by);
  for (let y = y0 + 1; y <= y1 - 1; y++) {
    for (let x = x0 + 1; x <= x1 - 1; x++) {
      tiles[y * size + x] = noise.noise2(x * 0.5, y * 0.5) > 0.55 ? TILE.RUBBLE : TILE.SIDEWALK;
    }
  }
  for (let x = x0 + 1; x < x1; x += 2) {
    props.push({ type: "railing", x: x + 0.5, y: y0 + 1.2 });
  }
  props.push({ type: "bench", x: ((x0 + x1) / 2), y: y0 + 2.2 });
  if (noise.noise2(bx + 4, by) > 0.72) {
    props.push({ type: "lamp", x: ((x0 + x1) / 2), y: y0 + 1.8 });
  }
  if (noise.noise2(bx, by) > 0.3) {
    props.push({ type: "planter", x: ((x0 + x1) / 2) + 1.5, y: y0 + 2.5, tone: 0 });
  }
}

function pickLoot(r) {
  if (r < 0.005) return LOOT.PISTOL;
  if (r < 0.008) return LOOT.AMMO_9MM;
  if (r < 0.011) return LOOT.FLASHLIGHT;
  if (r < 0.014) return LOOT.LANTERN;
  if (r < 0.018) return LOOT.SHIRT;
  if (r < 0.022) return LOOT.AMMO_SHOT;
  if (r < 0.026) return LOOT.BAG;
  if (r < 0.03) return LOOT.KNIFE;
  if (r < 0.034) return LOOT.HOODIE;
  if (r < 0.038) return LOOT.JACKET;
  if (r < 0.042) return LOOT.VEST;
  if (r < 0.046) return LOOT.RAINCOAT;
  if (r < 0.05) return LOOT.AMMO_RIFLE;
  if (r < 0.06) return LOOT.MED;
  if (r < 0.085) return LOOT.FOOD;
  if (r < 0.11) return LOOT.WATER;
  if (r < 0.13) return LOOT.SCRAP;
  return LOOT.WOOD;
}

function putLoot(map, x, y, id) {
  const amount = LOOT_DEFS[id]?.kind === "equip" ? 1 : 1 + ((x + y) % 2);
  map.set(`${x},${y}`, { id, amount });
}

function findSpawn(tiles, size, noise) {
  const candidates = [];
  for (let y = 4; y < size - 4; y++) {
    for (let x = 4; x < size - 4; x++) {
      const t = tiles[y * size + x];
      if (t !== TILE.ROAD && t !== TILE.SIDEWALK && t !== TILE.CROSSWALK) continue;
      let nearDoor = false;
      for (let oy = -5; oy <= 5 && !nearDoor; oy++) {
        for (let ox = -5; ox <= 5; ox++) {
          if (tiles[(y + oy) * size + (x + ox)] === TILE.DOOR) {
            nearDoor = true;
            break;
          }
        }
      }
      if (nearDoor) candidates.push({ x: x + 0.5, y: y + 0.5, score: noise.noise2(x * 0.2, y * 0.2) });
    }
  }
  candidates.sort((a, b) => b.score - a.score);
  return candidates[0] || { x: size / 2 + 0.5, y: size / 2 + 0.5 };
}

export function tileAt(world, x, y) {
  const ix = Math.floor(x);
  const iy = Math.floor(y);
  if (ix < 0 || iy < 0 || ix >= world.size || iy >= world.size) return TILE.WALL;
  return world.tiles[iy * world.size + ix];
}

export function canWalk(world, x, y, { zombie = false } = {}) {
  const t = tileAt(world, x, y);
  const meta = TILE_META[t];
  if (!meta?.walk) return false;
  if (zombie && t === TILE.DOOR) {
    const door = world.doors.get(`${Math.floor(x)},${Math.floor(y)}`);
    if (door && door.hp > 0) return false;
  }
  return true;
}

export function setTile(world, x, y, tile) {
  const ix = Math.floor(x);
  const iy = Math.floor(y);
  if (ix < 0 || iy < 0 || ix >= world.size || iy >= world.size) return false;
  world.tiles[iy * world.size + ix] = tile;
  return true;
}

export function lootLabel(id) {
  return LOOT_DEFS[id]?.label ?? id;
}

export function lootGatherText(id) {
  return LOOT_DEFS[id]?.gather ?? id;
}

export function buildingAt(world, x, y) {
  const ix = Math.floor(x);
  const iy = Math.floor(y);
  return world.buildings.find((b) => ix >= b.x0 && ix <= b.x1 && iy >= b.y0 && iy <= b.y1) || null;
}

function placeFurniture(interiors, x, y, type) {
  interiors.set(`${x},${y}`, { type, searched: false });
}

function placeDecor(decor, x, y, kind, color, variant = 0) {
  decor.set(`${x},${y}`, { kind, color, variant });
}

function canPlace(tiles, size, interiors, x, y, x0, y0, x1, y1) {
  if (x <= x0 || x >= x1 || y <= y0 || y >= y1) return false;
  if (tiles[y * size + x] !== TILE.FLOOR) return false;
  if (interiors.has(`${x},${y}`)) return false;
  return true;
}

function tryPlace(tiles, size, interiors, x, y, type, x0, y0, x1, y1) {
  if (!canPlace(tiles, size, interiors, x, y, x0, y0, x1, y1)) return false;
  placeFurniture(interiors, x, y, type);
  return true;
}

function placeRug(decor, x, y, w, h, color, variant = 0) {
  for (let dy = 0; dy < h; dy++) {
    for (let dx = 0; dx < w; dx++) {
      placeDecor(decor, x + dx, y + dy, "rug", color, variant);
    }
  }
}

/**
 * Decora el interior con un layout coherente según el estilo del edificio.
 * No es ruido aleatorio: camas con mesita y alfombra, cocina, zona de estar, etc.
 */
function decorateInterior({
  tiles, size, interiors, decor,
  x0, y0, x1, y1, doorX, doorY, side,
  style, accent, noise, bx, by,
}) {
  const ix0 = x0 + 1;
  const iy0 = y0 + 1;
  const ix1 = x1 - 1;
  const iy1 = y1 - 1;
  if (ix1 < ix0 || iy1 < iy0) return;

  const midX = ((ix0 + ix1) / 2) | 0;
  const midY = ((iy0 + iy1) / 2) | 0;
  // Esquina opuesta a la puerta = zona íntima / fondo
  const farX = side === 2 ? ix1 : side === 3 ? ix0 : midX;
  const farY = side === 0 ? iy1 : side === 1 ? iy0 : midY;
  const nearDoorX = side === 2 ? ix0 : side === 3 ? ix1 : midX;
  const nearDoorY = side === 0 ? iy0 : side === 1 ? iy1 : midY;
  // Esquinas libres
  const cA = { x: ix0, y: iy0 };
  const cB = { x: ix1, y: iy0 };
  const cC = { x: ix0, y: iy1 };
  const cD = { x: ix1, y: iy1 };
  const corners = [cA, cB, cC, cD].filter((c) => !(c.x === doorX && c.y === doorY));

  const put = (x, y, type) => tryPlace(tiles, size, interiors, x, y, type, x0, y0, x1, y1);

  if (style === "residential") {
    // Dormitorio en la esquina más lejos de la puerta
    const bedCorner = corners.reduce((best, c) => {
      const d = Math.abs(c.x - doorX) + Math.abs(c.y - doorY);
      const bd = Math.abs(best.x - doorX) + Math.abs(best.y - doorY);
      return d > bd ? c : best;
    }, corners[0]);
    put(bedCorner.x, bedCorner.y, "bed");
    // Mesita junto a la cama
    if (!put(bedCorner.x + 1, bedCorner.y, "nightstand")) put(bedCorner.x, bedCorner.y + (bedCorner.y < midY ? 1 : -1), "nightstand");
    // Alfombra bajo/junto a la cama (2×2)
    const rugX = Math.min(ix1 - 1, Math.max(ix0, bedCorner.x - (bedCorner.x > midX ? 1 : 0)));
    const rugY = Math.min(iy1 - 1, Math.max(iy0, bedCorner.y - (bedCorner.y > midY ? 1 : 0)));
    placeRug(decor, rugX, rugY, 2, 2, accent, 1);

    // Armario en pared lateral
    const wardrobeY = bedCorner.y === iy0 ? iy0 : bedCorner.y === iy1 ? iy1 : iy0;
    put(bedCorner.x === ix0 ? ix1 : ix0, wardrobeY, "cabinet");

    // Zona de estar: mesa + sillas + alfombra central
    placeRug(decor, midX - (midX > ix0 ? 0 : 0), midY, Math.min(2, ix1 - midX + 1), Math.min(2, iy1 - midY + 1), accent, 0);
    put(midX, midY, "table");
    put(midX + 1, midY, "chair");
    put(midX, midY + 1, "chair");

    // Cómoda / sofá en pared libre
    put(ix0 === bedCorner.x ? ix1 : ix0, midY, "drawer");
    {
      const sofaY = iy0 === bedCorner.y ? iy1 : iy0;
      const sofaX = midX;
      if (!put(sofaX, sofaY, "sofa")) put(sofaX === ix0 ? ix1 : ix0, sofaY, "sofa");
    }

    // Cocina cerca de la puerta: nevera + fregadero + cocina
    if (side === 0 || side === 1) {
      put(Math.max(ix0, Math.min(ix1, doorX - 1)), nearDoorY, "fridge");
      put(Math.min(ix1, Math.max(ix0, doorX + 1)), nearDoorY, "sink");
      if (ix1 - ix0 >= 3) put(Math.min(ix1, Math.max(ix0, doorX + 2)), nearDoorY, "stove");
    } else {
      put(nearDoorX, Math.max(iy0, Math.min(iy1, doorY - 1)), "fridge");
      put(nearDoorX, Math.min(iy1, Math.max(iy0, doorY + 1)), "sink");
      if (iy1 - iy0 >= 3) put(nearDoorX, Math.min(iy1, Math.max(iy0, doorY + 2)), "stove");
    }
    // Felpudo en la entrada
    const matX = side === 2 ? ix0 : side === 3 ? ix1 : doorX;
    const matY = side === 0 ? iy0 : side === 1 ? iy1 : doorY;
    if (tiles[matY * size + matX] === TILE.FLOOR) placeDecor(decor, matX, matY, "mat", "#5a4a3a", 0);

    // Planta en esquina libre
    for (const c of corners) {
      if (put(c.x, c.y, "plant")) break;
    }
  } else if (style === "shop") {
    // Felpudo entrada + mostrador frente a la puerta
    const matX = side === 2 ? ix0 : side === 3 ? ix1 : doorX;
    const matY = side === 0 ? iy0 : side === 1 ? iy1 : doorY;
    if (tiles[matY * size + matX] === TILE.FLOOR) placeDecor(decor, matX, matY, "mat", "#4a3a28", 0);

    if (side === 0 || side === 1) {
      put(midX, midY, "counter");
      put(midX - 1, midY, "counter");
      put(midX + 1, midY, "counter");
    } else {
      put(midX, midY, "counter");
      put(midX, midY - 1, "counter");
      put(midX, midY + 1, "counter");
    }

    // Estanterías en la pared del fondo
    if (side === 0) {
      for (let x = ix0; x <= ix1; x++) if ((x + bx) % 2 === 0) put(x, iy1, "shelf");
    } else if (side === 1) {
      for (let x = ix0; x <= ix1; x++) if ((x + bx) % 2 === 0) put(x, iy0, "shelf");
    } else if (side === 2) {
      for (let y = iy0; y <= iy1; y++) if ((y + by) % 2 === 0) put(ix1, y, "shelf");
    } else {
      for (let y = iy0; y <= iy1; y++) if ((y + by) % 2 === 0) put(ix0, y, "shelf");
    }

    put(ix0, iy0 === matY ? iy1 : iy0, "fridge");
    put(ix1, iy0 === matY ? iy1 : iy0, "crate");
    placeRug(decor, midX, Math.max(iy0, midY - 1), 1, 1, accent, 2);
    put(ix1, midY, "plant");
  } else if (style === "warehouse") {
    // Taquillas en una pared
    for (let y = iy0; y <= iy1; y++) {
      if ((y + bx) % 2 === 0) put(ix0, y, "locker");
    }
    // Estanterías opuestas
    for (let y = iy0; y <= iy1; y++) {
      if ((y + by) % 2 === 1) put(ix1, y, "shelf");
    }
    // Cajones en fila
    for (let x = ix0 + 1; x <= ix1 - 1; x++) {
      if ((x + y0) % 2 === 0) put(x, midY, "crate");
    }
    put(midX, iy0, "table");
    put(midX + 1, iy0, "chair");
    // Esteras de goma
    placeDecor(decor, midX, midY, "mat", "#3a3a36", 1);
    placeDecor(decor, nearDoorX === midX ? ix0 + 1 : nearDoorX, nearDoorY === midY ? iy0 + 1 : nearDoorY, "mat", "#3a3a36", 1);
  } else if (style === "tower") {
    // Oficina: escritorio, silla, alfombra, estantería, planta
    placeRug(decor, midX - (midX > ix0 ? 0 : 0), midY - (midY > iy0 ? 0 : 0), Math.min(2, ix1 - ix0), Math.min(2, iy1 - iy0), accent, 0);
    put(midX, midY, "desk");
    if (midY + 1 <= iy1) put(midX, midY + 1, "chair");
    else if (midY - 1 >= iy0) put(midX, midY - 1, "chair");
    if (midX + 1 <= ix1) put(midX + 1, midY, "chair");
    else if (midX - 1 >= ix0) put(midX - 1, midY, "chair");
    put(ix0, iy0, "shelf");
    put(ix1, iy0, "cabinet");
    put(ix0, iy1, "plant");
    put(ix1, iy1, "locker");
    if (tiles[nearDoorY * size + nearDoorX] === TILE.FLOOR) placeDecor(decor, nearDoorX, nearDoorY, "mat", "#3a4050", 0);
  } else {
    // Bloque mixto: salón sencillo
    placeRug(decor, midX, midY, Math.min(2, ix1 - midX + 1), Math.min(2, iy1 - midY + 1), accent, 1);
    put(farX, farY, "bed");
    put(farX === ix0 ? farX + 1 : farX - 1, farY, "nightstand");
    put(ix0, midY, "sofa");
    put(midX, midY, "table");
    put(midX + 1, midY, "chair");
    put(ix1, iy0, "cabinet");
    put(ix1, iy1, "fridge");
    put(ix0, iy0 === farY ? iy1 : iy0, "plant");
    put(ix0, iy1 === farY ? iy0 : iy1, "drawer");
    if (tiles[nearDoorY * size + nearDoorX] === TILE.FLOOR) placeDecor(decor, nearDoorX, nearDoorY, "mat", "#5a4038", 0);
  }
}

export function furnitureType(furn) {
  if (!furn) return null;
  return typeof furn === "string" ? furn : furn.type;
}

export function furnitureLabel(furn) {
  const t = furnitureType(furn);
  return FURNITURE[t]?.label ?? "Mueble";
}

export function isSearchable(furn) {
  const t = furnitureType(furn);
  if (!t || !FURNITURE[t]?.searchable) return false;
  if (typeof furn === "string") return true;
  return !furn.searched;
}

/** Marca el mueble como registrado y devuelve loot o vacío. */
export function searchFurniture(furn) {
  const t = furnitureType(furn);
  const label = furnitureLabel(furn);
  if (!t || !FURNITURE[t]?.searchable) return { empty: true, label };
  if (typeof furn !== "string" && furn.searched) {
    return { empty: true, already: true, label };
  }
  if (typeof furn !== "string") furn.searched = true;

  const table = CONTAINER_LOOT[t] || CONTAINER_LOOT.shelf;
  let total = 0;
  for (const row of table) total += row.w;
  let roll = Math.random() * total;
  let pick = table[table.length - 1];
  for (const row of table) {
    roll -= row.w;
    if (roll <= 0) {
      pick = row;
      break;
    }
  }
  if (pick.empty) return { empty: true, label };
  const amount = LOOT_DEFS[pick.id]?.kind === "equip" ? 1 : 1 + ((Math.random() * 2) | 0);
  return { empty: false, id: pick.id, amount, label };
}

/** Contenedor (buscable) más cercano, incluso si ya está registrado. */
export function nearestContainer(world, x, y) {
  const tx = Math.floor(x);
  const ty = Math.floor(y);
  let best = null;
  let bestD = 99;
  for (let oy = -1; oy <= 1; oy++) {
    for (let ox = -1; ox <= 1; ox++) {
      const key = `${tx + ox},${ty + oy}`;
      const furn = world.interiors.get(key);
      const t = furnitureType(furn);
      if (!t || !FURNITURE[t]?.searchable) continue;
      const d = Math.abs(ox) + Math.abs(oy);
      if (d < bestD) {
        bestD = d;
        best = { key, furn, x: tx + ox, y: ty + oy };
      }
    }
  }
  return best;
}

/** Contenedor aún sin registrar más cercano (para el prompt). */
export function nearestSearchable(world, x, y) {
  const hit = nearestContainer(world, x, y);
  if (!hit || !isSearchable(hit.furn)) return null;
  return hit;
}

function shadeHex(hex, delta) {
  const n = parseInt(hex.slice(1), 16);
  let r = (n >> 16) & 255;
  let g = (n >> 8) & 255;
  let b = n & 255;
  r = Math.max(0, Math.min(255, r + delta));
  g = Math.max(0, Math.min(255, g + delta));
  b = Math.max(0, Math.min(255, b + delta));
  return `#${((r << 16) | (g << 8) | b).toString(16).padStart(6, "0")}`;
}
