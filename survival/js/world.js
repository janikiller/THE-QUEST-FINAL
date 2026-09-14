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
  [TILE.ROAD]: { name: "asfalto", walk: true, color: "#2a2c2e", speed: 1.05 },
  [TILE.SIDEWALK]: { name: "acera", walk: true, color: "#5a564f", speed: 1 },
  [TILE.FLOOR]: { name: "interior", walk: true, color: "#4a3d32", speed: 1, indoor: true },
  [TILE.WALL]: { name: "muro", walk: false, color: "#3a3530", solid: true },
  [TILE.RUBBLE]: { name: "escombros", walk: true, color: "#524a42", speed: 0.65 },
  [TILE.PARK]: { name: "parque", walk: true, color: "#2a3a24", speed: 0.95 },
  [TILE.PARKING]: { name: "parking", walk: true, color: "#323438", speed: 1 },
  [TILE.WATER]: { name: "río tóxico", walk: false, color: "#1a3020", solid: true, drink: true },
  [TILE.ALLEY]: { name: "callejón", walk: true, color: "#2a2a2e", speed: 0.9 },
  [TILE.BARRICADE]: { name: "barricada", walk: false, color: "#6a4220", solid: true, built: true },
  [TILE.DOOR]: { name: "puerta", walk: true, color: "#6b4a2a", speed: 0.9, door: true },
  [TILE.BASE]: { name: "base", walk: true, color: "#3a4a30", speed: 1, indoor: true, base: true },
  [TILE.CROSSWALK]: { name: "paso", walk: true, color: "#343436", speed: 1 },
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
    { id: LOOT.RIFLE, w: 1 },
    { id: LOOT.AMMO_9MM, w: 2 },
    { id: LOOT.AMMO_SHOT, w: 1 },
    { id: LOOT.AMMO_RIFLE, w: 1 },
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
const BUILDING_NAMES = {
  warehouse: ["Almacén Norte", "Depósito Este", "Nave Sur", "Logística Río", "Hangar Niebla", "Silos Crespo"],
  shop: ["Mercado Sur", "Farmacia Alba", "Café Gris", "Panadería Sur", "Bar El Canal", "Bazar Luna"],
  residential: ["Casa Mistral", "Residencial 9", "Lofts Crespo", "Bloque Luna", "Casa Puerto", "Edificio Sol"],
  tower: ["Torre Niebla", "Torre Crespo", "Oficinas Alba", "Centro Niebla", "Torre Norte", "Edificio Sol"],
  block: ["Bloque Luna", "Edificio Sol", "Residencial 9", "Clínica Niebla", "Lofts Crespo", "Casa Mistral"],
};
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

  // Río tóxico post-colapso (ancho, atraviesa la ciudad)
  const canalY = Math.max(18, Math.min(size - 20, ((size * 0.52) | 0) + ((noise.noise2(3, 7) * 8) | 0)));
  const canalHalf = 3; // 7 tiles de ancho — bien visible desde el spawn
  for (let x = 0; x < size; x++) {
    for (let dy = -canalHalf; dy <= canalHalf; dy++) {
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
      if (by <= canalY + canalHalf + 2 && by + BLOCK >= canalY - canalHalf - 1) {
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

  // Puentes del río (solo bajo las avenidas N-S)
  for (let x = 0; x < size; x++) {
    if (x % BLOCK < ROAD_W) {
      for (let dy = -canalHalf; dy <= canalHalf; dy++) {
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

  // Tapas de alcantarilla
  for (let y = 3; y < size - 3; y++) {
    for (let x = 3; x < size - 3; x++) {
      if (tiles[y * size + x] !== TILE.ROAD) continue;
      if ((x * 17 + y * 31) % 47 === 0) props.push({ type: "manhole", x: x + 0.5, y: y + 0.5 });
    }
  }


  // Cicatrices del colapso: escombros y barricadas rotas en calles
  for (let y = 2; y < size - 2; y++) {
    for (let x = 2; x < size - 2; x++) {
      const t = tiles[y * size + x];
      if (t !== TILE.ROAD && t !== TILE.CROSSWALK && t !== TILE.SIDEWALK) continue;
      const r = noise.noise2(x * 0.55 + 9, y * 0.55 + seed * 0.0002);
      if (t === TILE.ROAD && r > 0.78) tiles[y * size + x] = TILE.RUBBLE;
      if (r > 0.82 && (x + y) % 7 === 0) {
        props.push({ type: "debris", x: x + 0.5, y: y + 0.5, tone: (x + y) % 3 });
      }
      if (r > 0.86 && t === TILE.SIDEWALK && (x * y) % 13 === 0) {
        props.push({ type: "barricadeJunk", x: x + 0.5, y: y + 0.5 });
      }
    }
  }

  // Restaurar el río tras manzanas/escombros (los bloques no deben taparlo)
  for (let x = 0; x < size; x++) {
    const isBridge = x % BLOCK < ROAD_W;
    for (let dy = -canalHalf; dy <= canalHalf; dy++) {
      const y = canalY + dy;
      if (y < 0 || y >= size) continue;
      if (isBridge) {
        tiles[y * size + x] = TILE.ROAD;
      } else {
        tiles[y * size + x] = TILE.WATER;
      }
    }
    // Orillas ruinosas
    for (const bank of [canalY - canalHalf - 1, canalY + canalHalf + 1]) {
      if (bank < 1 || bank >= size - 1) continue;
      if (isBridge) continue;
      const t = tiles[bank * size + x];
      if (t === TILE.WATER || t === TILE.ROAD || t === TILE.CROSSWALK) continue;
      if (noise.noise2(x * 0.4, bank * 0.4) > 0.35) tiles[bank * size + x] = TILE.RUBBLE;
    }
  }

  // Assets post-apocalípticos del río (barcas, muelles, tuberías, barriles)
  for (let x = 3; x < size - 3; x += 3) {
    if (x % BLOCK < ROAD_W + 1) continue;
    if (noise.noise2(x * 0.2, canalY) > 0.12) {
      props.push({
        type: "boat",
        x: x + 0.5 + noise.noise2(x, 1) * 0.4,
        y: canalY + 0.5 + (noise.noise2(x, 2) - 0.5) * (canalHalf - 0.6),
        wreck: true,
      });
    }
    if (noise.noise2(x * 0.3 + 2, canalY + 1) > 0.28) {
      props.push({
        type: "riverDebris",
        x: x + 0.3 + noise.noise2(x, 5) * 0.4,
        y: canalY + 0.5 + (noise.noise2(x, 4) - 0.5) * canalHalf,
        tone: (x * 3) % 3,
      });
    }
    if (noise.noise2(x * 0.25, canalY - 2) > 0.25) {
      props.push({
        type: "barrel",
        x: x + 0.6,
        y: canalY - canalHalf - 0.55,
        toxic: noise.noise2(x, 8) > 0.35,
      });
    }
    if (noise.noise2(x * 0.22, canalY + 3) > 0.3) {
      props.push({
        type: "barrel",
        x: x + 0.4,
        y: canalY + canalHalf + 0.55,
        toxic: true,
      });
    }
    if (x % 6 === 0 || noise.noise2(x, 11) > 0.55) {
      props.push({
        type: "dock",
        x: x + 0.5,
        y: canalY - canalHalf - 0.1,
        broken: true,
      });
    }
    if (x % 5 === 2 || noise.noise2(x, 12) > 0.5) {
      props.push({
        type: "pipe",
        x: x + 0.5,
        y: canalY + canalHalf + 0.15,
        toxic: true,
      });
    }
  }

  props.sort((a, b) => a.y - b.y);
  // Índices cacheados para iluminación (evita escanear ~1700 props/frame)
  const lamps = props.filter((p) => p.type === "lamp");
  const indoorLights = props.filter((p) => p.type === "indoorLamp" || p.type === "candle");
  const propGrid = buildPropGrid(props, size);
  const buildingIndex = buildBuildingIndex(buildings, size);

  const spawn = findSpawn(tiles, size, noise, canalY);
  return {
    size, seed, tiles, loot, doors, buildings, props, interiors, decor, spawn, noise, canalY,
    lamps, indoorLights, propGrid, buildingIndex, tileRev: 0,
  };
}

const PROP_CHUNK = 4;

function buildPropGrid(props, size) {
  const cols = Math.ceil(size / PROP_CHUNK);
  const chunks = Array.from({ length: cols * cols }, () => []);
  for (const p of props) {
    const cx = Math.max(0, Math.min(cols - 1, (p.x / PROP_CHUNK) | 0));
    const cy = Math.max(0, Math.min(cols - 1, (p.y / PROP_CHUNK) | 0));
    chunks[cy * cols + cx].push(p);
  }
  return { chunks, cols, chunk: PROP_CHUNK };
}

function buildBuildingIndex(buildings, size) {
  const index = new Map();
  for (const b of buildings) {
    for (let y = b.y0; y <= b.y1; y++) {
      for (let x = b.x0; x <= b.x1; x++) {
        index.set(y * size + x, b);
      }
    }
  }
  return index;
}

/** Props visibles en un rectángulo de tiles (ya casi ordenados por Y). */
export function propsInView(world, x0, y0, x1, y1) {
  const grid = world.propGrid;
  if (!grid) return world.props;
  const { chunks, cols, chunk } = grid;
  const cx0 = Math.max(0, (x0 / chunk) | 0);
  const cy0 = Math.max(0, (y0 / chunk) | 0);
  const cx1 = Math.min(cols - 1, (x1 / chunk) | 0);
  const cy1 = Math.min(cols - 1, (y1 / chunk) | 0);
  const out = [];
  for (let cy = cy0; cy <= cy1; cy++) {
    for (let cx = cx0; cx <= cx1; cx++) {
      const bucket = chunks[cy * cols + cx];
      for (let i = 0; i < bucket.length; i++) out.push(bucket[i]);
    }
  }
  out.sort((a, b) => a.y - b.y);
  return out;
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
  const floors = 2 + (((noise.noise2(bx, by) * 4) | 0) % 4);
  const styleRoll = noise.noise2(bx * 0.31, by * 0.27);
  let style = "block";
  if (floors >= 4) style = "tower";
  else if (styleRoll < 0.22) style = "shop";
  else if (styleRoll < 0.4) style = "warehouse";
  else if (styleRoll < 0.62) style = "residential";
  const namePool = BUILDING_NAMES[style] || BUILDING_NAMES.block;
  const name = namePool[((bx * 5 + by * 11 + seed * 3) >>> 0) % namePool.length];
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
    tiles, size, interiors, decor, props,
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


  decorateFacadeWalls({
    props, x0, y0, x1, y1, doorX: dx, doorY: dy, side,
    style, noise, bx, by, name,
  });

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
          tone: noise.noise2(x + 3, y) > 0.35 ? 2 : (noise.noise2(x + 3, y) > 0.5 ? 0 : 1), // 2 = muerto
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
  for (let y = y0 + 1; y <= y1 - 1; y++) {
    for (let x = x0 + 1; x <= x1 - 1; x++) {
      // Parking abandonado: más escombros que asfalto limpio
      tiles[y * size + x] = noise.noise2(x * 1.3, y * 1.1) > 0.72 ? TILE.RUBBLE : TILE.PARKING;
      if ((x + y) % 4 === 0 && noise.noise2(x, y) > 0.55) {
        props.push({
          type: "debris",
          x: x + 0.5,
          y: y + 0.5,
          tone: (x * 3 + y) % 3,
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
    props.push({ type: "graffiti", x: x0 + 1.5, y: y0 + 2.2, wall: "w", text: "XX" });
  }
  if (noise.noise2(bx + 2, by) > 0.5) {
    props.push({ type: "graffiti", x: x1 - 1.2, y: y1 - 1.5, wall: "e", text: "CRESPO" });
  }
}

function paveQuay(tiles, size, bx, by, props, noise) {
  const { x0, y0, x1, y1 } = paveSidewalkRing(tiles, size, bx, by);
  for (let y = y0 + 1; y <= y1 - 1; y++) {
    for (let x = x0 + 1; x <= x1 - 1; x++) {
      if (tiles[y * size + x] === TILE.WATER) continue;
      tiles[y * size + x] = noise.noise2(x * 0.5, y * 0.5) > 0.38 ? TILE.RUBBLE : TILE.SIDEWALK;
    }
  }
  // Barandillas rotas / oxidadas
  for (let x = x0 + 1; x < x1; x += 2) {
    if (noise.noise2(x * 0.4, by) > 0.25) {
      props.push({ type: "railing", x: x + 0.5, y: y0 + 1.2, broken: noise.noise2(x, by + 1) > 0.4 });
    }
  }
  // Orilla saqueada: barriles, escombros, farolas caídas
  props.push({ type: "debris", x: (x0 + x1) / 2, y: y0 + 2.2, tone: 1 });
  if (noise.noise2(bx + 1, by) > 0.35) {
    props.push({ type: "barrel", x: x0 + 2.2, y: y0 + 2.4, toxic: true });
  }
  if (noise.noise2(bx + 2, by) > 0.4) {
    props.push({ type: "barricadeJunk", x: x1 - 2.1, y: y0 + 2.6 });
  }
  if (noise.noise2(bx + 4, by) > 0.55) {
    props.push({ type: "lamp", x: (x0 + x1) / 2, y: y0 + 1.8 });
  }
  if (noise.noise2(bx, by) > 0.45) {
    props.push({ type: "debris", x: (x0 + x1) / 2 + 1.2, y: y0 + 2.8, tone: 2 });
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

function findSpawn(tiles, size, noise, canalY = (size / 2) | 0) {
  const candidates = [];
  // Orilla norte del río: el agua debe verse en el primer viewport
  const yMin = Math.max(4, canalY - 8);
  const yMax = Math.min(size - 5, canalY - 3);
  for (let y = yMin; y <= yMax; y++) {
    for (let x = 4; x < size - 4; x++) {
      const t = tiles[y * size + x];
      if (t !== TILE.ROAD && t !== TILE.SIDEWALK && t !== TILE.CROSSWALK && t !== TILE.RUBBLE) continue;
      let nearDoor = false;
      for (let oy = -6; oy <= 6 && !nearDoor; oy++) {
        for (let ox = -6; ox <= 6; ox++) {
          const yy = y + oy;
          const xx = x + ox;
          if (yy < 0 || xx < 0 || yy >= size || xx >= size) continue;
          if (tiles[yy * size + xx] === TILE.DOOR) {
            nearDoor = true;
            break;
          }
        }
      }
      const riverBias = 3 - Math.min(3, Math.abs(y - (canalY - 4)) / 5);
      const doorBonus = nearDoor ? 0.4 : 0;
      const score = noise.noise2(x * 0.2, y * 0.2) + riverBias + doorBonus;
      candidates.push({ x: x + 0.5, y: y + 0.5, score });
    }
  }
  candidates.sort((a, b) => b.score - a.score);
  return candidates[0] || { x: size / 2 + 0.5, y: Math.max(6, canalY - 5) + 0.5 };
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
  world.tileRev = (world.tileRev || 0) + 1;
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
  if (world.buildingIndex) {
    return world.buildingIndex.get(iy * world.size + ix) || null;
  }
  return world.buildings.find((b) => ix >= b.x0 && ix <= b.x1 && iy >= b.y0 && iy <= b.y1) || null;
}

function placeFurniture(interiors, x, y, type) {
  interiors.set(`${x},${y}`, { type, searched: false });
}

function placeDecor(decor, x, y, kind, color, variant = 0) {
  decor.set(`${x},${y}`, { kind, color, variant });
}

/** Decor de suelo en tile libre (no pisa muebles ni otro decor). */
function placeFloorDecor(decor, interiors, x, y, kind, color, variant = 0) {
  const key = `${x},${y}`;
  if (interiors?.has(key)) return false;
  if (decor.has(key)) return false;
  placeDecor(decor, x, y, kind, color, variant);
  return true;
}

/** Alfombra: puede quedar bajo mesa/silla, pero nunca bajo muebles altos. */
const RUG_BLOCKERS = new Set([
  "shelf", "cabinet", "locker", "fridge", "bed", "sofa", "counter",
  "sink", "stove", "crate", "barrel", "plant", "drawer",
]);

function canPlace(tiles, size, interiors, x, y, x0, y0, x1, y1) {
  if (x <= x0 || x >= x1 || y <= y0 || y >= y1) return false;
  if (tiles[y * size + x] !== TILE.FLOOR) return false;
  if (interiors.has(`${x},${y}`)) return false;
  return true;
}

function tryPlace(tiles, size, interiors, x, y, type, x0, y0, x1, y1, decor = null) {
  if (!canPlace(tiles, size, interiors, x, y, x0, y0, x1, y1)) return false;
  placeFurniture(interiors, x, y, type);
  // Quitar felpudo/polvo del tile: el mueble manda
  if (decor) {
    const key = `${x},${y}`;
    const d = decor.get(key);
    if (d && (d.kind !== "rug" || RUG_BLOCKERS.has(type))) decor.delete(key);
  }
  return true;
}

function placeRug(decor, x, y, w, h, color, variant = 0, interiors = null) {
  for (let dy = 0; dy < h; dy++) {
    for (let dx = 0; dx < w; dx++) {
      const tx = x + dx;
      const ty = y + dy;
      if (interiors) {
        const ft = furnitureType(interiors.get(`${tx},${ty}`));
        if (ft && RUG_BLOCKERS.has(ft)) continue;
      }
      if (decor.has(`${tx},${ty}`)) continue;
      placeDecor(decor, tx, ty, "rug", color, variant);
    }
  }
}

/**
 * Decora el interior con un layout coherente según el estilo del edificio.
 * No es ruido aleatorio: camas con mesita y alfombra, cocina, zona de estar, etc.
 */

const GRAFFITI_TAGS = ["CRESPO", "NIEBLA", "XX", "VIVOS?", "SUR", "FUERA", "RATAS", "Ω", "FN", "OUT"];
const POSTER_COLORS = ["#8a3030", "#2a4a6a", "#5a3a68", "#3a5a38", "#6a4a20"];

/** Exterior junto a fachada: suciedad, enredaderas, basura, plantas y árboles (no cuadros). */
function decorateFacadeWalls({
  props, x0, y0, x1, y1, doorX, doorY, side,
  style, noise, bx, by, name,
}) {
  const edges = [];
  for (let x = x0; x <= x1; x++) {
    edges.push({ x, y: y0, wall: "n" });
    edges.push({ x, y: y1, wall: "s" });
  }
  for (let y = y0 + 1; y < y1; y++) {
    edges.push({ x: x0, y, wall: "w" });
    edges.push({ x: x1, y, wall: "e" });
  }

  let graffitiOnBuilding = 0;
  for (const e of edges) {
    if (e.x === doorX && e.y === doorY) continue;
    const n = noise.noise2(e.x * 0.37 + bx, e.y * 0.41 + by);
    const n2 = noise.noise2(e.x * 0.9, e.y * 0.7 + 3);
    const corner = (e.x === x0 || e.x === x1) && (e.y === y0 || e.y === y1);

    // Suciedad puntual (no toda la fachada)
    if (n2 > 0.72) {
      props.push({
        type: "wallGrime",
        x: e.x + 0.5,
        y: e.y + 0.5,
        wall: e.wall,
        tone: (e.x + e.y) % 3,
      });
    }

    // Enredadera: sobre todo esquinas
    if ((corner && n > 0.35) || n > 0.82) {
      props.push({
        type: "vine",
        x: e.x + 0.5,
        y: e.y + 0.5,
        wall: e.wall,
        growth: 0.55 + n * 0.5,
        dead: n2 > 0.6,
      });
    }

    // Graffiti callejero (fuera), máximo 1–2 por edificio
    if (graffitiOnBuilding < 2 && n > 0.78 && n2 > 0.5) {
      const tag = GRAFFITI_TAGS[((e.x * 13 + e.y * 7 + bx) >>> 0) % GRAFFITI_TAGS.length];
      props.push({
        type: "graffiti",
        x: e.x + 0.5,
        y: e.y + 0.45,
        wall: e.wall,
        text: tag,
        color: n2 > 0.7 ? "#c040a0" : n2 > 0.5 ? "#40a0c8" : "#d0c040",
      });
      graffitiOnBuilding++;
    }
  }

  // Basura / plantas FUERA (pocos puntos, no saturar)
  for (let i = 0; i < 3; i++) {
    if (noise.noise2(bx + i * 1.7, by + 11) < 0.42) continue;
    const e = edges[((bx * 5 + by * 3 + i * 11) >>> 0) % edges.length];
    if (e.x === doorX && e.y === doorY) continue;
    const ox = e.wall === "w" ? -0.55 : e.wall === "e" ? 0.55 : ((i % 2) ? 0.2 : -0.15);
    const oy = e.wall === "n" ? -0.55 : e.wall === "s" ? 0.55 : ((i % 2) ? 0.15 : -0.2);
    const roll = noise.noise2(e.x + i, e.y + bx);
    if (roll > 0.62) {
      props.push({ type: "trash", x: e.x + 0.5 + ox, y: e.y + 0.5 + oy });
    } else if (roll > 0.38) {
      props.push({ type: "debris", x: e.x + 0.5 + ox, y: e.y + 0.5 + oy, tone: (e.x + e.y + i) % 3 });
    } else {
      props.push({
        type: "planter",
        x: e.x + 0.5 + ox * 0.7,
        y: e.y + 0.5 + oy * 0.7,
        tone: noise.noise2(e.x, e.y) > 0.5 ? 2 : 1,
        wild: true,
      });
    }
  }

  // Árbol / mata seca en esquina exterior
  if (noise.noise2(bx + 4, by + 4) > 0.55) {
    props.push({
      type: "tree",
      x: x0 - 0.35,
      y: y0 - 0.25,
      r: 10 + noise.noise2(bx, by) * 7,
      tone: 2,
    });
  }
  if (noise.noise2(bx + 7, by + 2) > 0.78) {
    props.push({
      type: "tree",
      x: x1 + 0.35,
      y: y1 + 0.3,
      r: 8 + noise.noise2(bx + 1, by) * 5,
      tone: 2,
    });
  }
  if (noise.noise2(bx + 1, by + 8) > 0.6) {
    props.push({ type: "dumpster", x: x1 + 0.7, y: ((y0 + y1) / 2), color: "#3a3a42" });
  }
}

function decorateInterior({
  tiles, size, interiors, decor, props,
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
  const farX = side === 2 ? ix1 : side === 3 ? ix0 : midX;
  const farY = side === 0 ? iy1 : side === 1 ? iy0 : midY;
  const nearDoorX = side === 2 ? ix0 : side === 3 ? ix1 : midX;
  const nearDoorY = side === 0 ? iy0 : side === 1 ? iy1 : midY;
  const cA = { x: ix0, y: iy0 };
  const cB = { x: ix1, y: iy0 };
  const cC = { x: ix0, y: iy1 };
  const cD = { x: ix1, y: iy1 };
  const corners = [cA, cB, cC, cD].filter((c) => !(c.x === doorX && c.y === doorY));

  const put = (x, y, type) => tryPlace(tiles, size, interiors, x, y, type, x0, y0, x1, y1, decor);
  const putOrElse = (type, spots) => {
    for (const s of spots) {
      if (put(s.x, s.y, type)) return true;
    }
    return false;
  };
  const free = (x, y) => !interiors.has(`${x},${y}`);
  const matAt = (x, y, color) => {
    if (tiles[y * size + x] !== TILE.FLOOR) return;
    placeFloorDecor(decor, interiors, x, y, "mat", color, 0);
  };

  if (style === "residential") {
    // 1) Dormitorio en esquina lejos de la puerta
    const bedCorner = corners.reduce((best, c) => {
      const d = Math.abs(c.x - doorX) + Math.abs(c.y - doorY);
      const bd = Math.abs(best.x - doorX) + Math.abs(best.y - doorY);
      return d > bd ? c : best;
    }, corners[0]);
    put(bedCorner.x, bedCorner.y, "bed");
    putOrElse("nightstand", [
      { x: bedCorner.x + 1, y: bedCorner.y },
      { x: bedCorner.x - 1, y: bedCorner.y },
      { x: bedCorner.x, y: bedCorner.y + 1 },
      { x: bedCorner.x, y: bedCorner.y - 1 },
    ]);
    // Alfombra solo en tiles libres junto a la cama (no debajo del colchón)
    {
      const rx = Math.min(ix1, Math.max(ix0, bedCorner.x + (bedCorner.x <= midX ? 1 : -1)));
      const ry = Math.min(iy1, Math.max(iy0, bedCorner.y));
      if (free(rx, ry)) placeFloorDecor(decor, interiors, rx, ry, "rug", accent, 1);
    }

    // 2) Armario en esquina opuesta a la cama
    putOrElse("cabinet", corners.filter((c) => c.x !== bedCorner.x || c.y !== bedCorner.y));

    // 3) Zona de estar en el centro (mesa + sillas); alfombra bajo la mesa
    put(midX, midY, "table");
    putOrElse("chair", [
      { x: midX + 1, y: midY },
      { x: midX - 1, y: midY },
      { x: midX, y: midY + 1 },
      { x: midX, y: midY - 1 },
    ]);
    putOrElse("chair", [
      { x: midX, y: midY + 1 },
      { x: midX, y: midY - 1 },
      { x: midX - 1, y: midY },
      { x: midX + 1, y: midY },
    ]);
    placeRug(decor, midX, midY, 1, 1, accent, 0, interiors);

    // 4) Sofá en pared LEJOS de la puerta y de la cama (no pelear con cocina)
    {
      const sofaWallY = bedCorner.y === iy0 ? iy1 : bedCorner.y === iy1 ? iy0 : (nearDoorY === iy0 ? iy1 : iy0);
      // Preferir pared N/S distinta a la de la puerta
      const sofaY = (side === 0) ? iy1 : (side === 1) ? iy0 : sofaWallY;
      const sofaCandidates = [
        { x: midX, y: sofaY },
        { x: midX - 1, y: sofaY },
        { x: midX + 1, y: sofaY },
        { x: ix0, y: midY },
        { x: ix1, y: midY },
      ].filter((s) => !(s.x === bedCorner.x && s.y === bedCorner.y));
      putOrElse("sofa", sofaCandidates);
    }

    // 5) Cómoda en pared lateral libre
    putOrElse("drawer", [
      { x: bedCorner.x === ix0 ? ix1 : ix0, y: midY },
      { x: ix0, y: midY },
      { x: ix1, y: midY },
    ]);

    // 6) Cocina en pared de la puerta, flanqueando el hueco (nunca en sofá/cama)
    if (side === 0 || side === 1) {
      putOrElse("fridge", [
        { x: Math.max(ix0, doorX - 1), y: nearDoorY },
        { x: Math.min(ix1, doorX + 1), y: nearDoorY },
        { x: ix0, y: nearDoorY },
      ]);
      putOrElse("sink", [
        { x: Math.min(ix1, doorX + 1), y: nearDoorY },
        { x: Math.max(ix0, doorX - 1), y: nearDoorY },
        { x: ix1, y: nearDoorY },
      ]);
      if (ix1 - ix0 >= 3) {
        putOrElse("stove", [
          { x: Math.min(ix1, doorX + 2), y: nearDoorY },
          { x: Math.max(ix0, doorX - 2), y: nearDoorY },
        ]);
      }
    } else {
      putOrElse("fridge", [
        { x: nearDoorX, y: Math.max(iy0, doorY - 1) },
        { x: nearDoorX, y: Math.min(iy1, doorY + 1) },
        { x: nearDoorX, y: iy0 },
      ]);
      putOrElse("sink", [
        { x: nearDoorX, y: Math.min(iy1, doorY + 1) },
        { x: nearDoorX, y: Math.max(iy0, doorY - 1) },
        { x: nearDoorX, y: iy1 },
      ]);
      if (iy1 - iy0 >= 3) {
        putOrElse("stove", [
          { x: nearDoorX, y: Math.min(iy1, doorY + 2) },
          { x: nearDoorX, y: Math.max(iy0, doorY - 2) },
        ]);
      }
    }

    matAt(
      side === 2 ? ix0 : side === 3 ? ix1 : doorX,
      side === 0 ? iy0 : side === 1 ? iy1 : doorY,
      "#5a4a3a",
    );
    putOrElse("plant", corners);
  } else if (style === "shop") {
    matAt(
      side === 2 ? ix0 : side === 3 ? ix1 : doorX,
      side === 0 ? iy0 : side === 1 ? iy1 : doorY,
      "#4a3a28",
    );

    // Mostrador en el centro (no en la pared de estanterías)
    if (side === 0 || side === 1) {
      put(midX, midY, "counter");
      put(midX - 1, midY, "counter");
      put(midX + 1, midY, "counter");
    } else {
      put(midX, midY, "counter");
      put(midX, midY - 1, "counter");
      put(midX, midY + 1, "counter");
    }

    // Estanterías en pared del fondo (cada 2 tiles)
    if (side === 0) {
      for (let x = ix0; x <= ix1; x++) if ((x + bx) % 2 === 0) put(x, iy1, "shelf");
    } else if (side === 1) {
      for (let x = ix0; x <= ix1; x++) if ((x + bx) % 2 === 0) put(x, iy0, "shelf");
    } else if (side === 2) {
      for (let y = iy0; y <= iy1; y++) if ((y + by) % 2 === 0) put(ix1, y, "shelf");
    } else {
      for (let y = iy0; y <= iy1; y++) if ((y + by) % 2 === 0) put(ix0, y, "shelf");
    }

    // Nevera / caja / planta en esquinas libres (nunca encima del mostrador)
    putOrElse("fridge", corners);
    putOrElse("crate", corners);
    putOrElse("plant", [
      { x: ix1, y: midY },
      { x: ix0, y: midY },
      ...corners,
    ]);
    // Alfombra pequeña en pasillo libre
    {
      const rx = midX;
      const ry = side === 0 || side === 1 ? Math.max(iy0, midY - 1) : midY;
      if (free(rx, ry)) placeFloorDecor(decor, interiors, rx, ry, "rug", accent, 2);
    }
  } else if (style === "warehouse") {
    const aisleX = midX;
    // Taquillas solo en pared oeste (dejar hueco de puerta)
    for (let y = iy0; y <= iy1; y++) {
      if (y === doorY && ix0 === doorX) continue;
      put(ix0, y, "locker");
    }
    // Racks en pared este + cajones delante (sin invadir pasillo)
    for (let y = iy0; y <= iy1; y++) {
      if (y === doorY && ix1 === doorX) continue;
      put(ix1, y, "shelf");
      if (ix1 - 1 > aisleX && (y + by) % 2 === 0) put(ix1 - 1, y, "crate");
    }
    // Escritorio en el pasillo central, lejos de la puerta — nunca en columna de lockers/shelves
    putOrElse("desk", [
      { x: aisleX, y: farY },
      { x: aisleX, y: midY },
      { x: aisleX + (aisleX < ix1 ? 0 : 0), y: farY === iy0 ? iy0 + 1 : farY === iy1 ? iy1 - 1 : farY },
      { x: Math.min(ix1 - 1, aisleX + 1), y: midY },
      { x: Math.max(ix0 + 1, aisleX - 1), y: midY },
    ]);
    putOrElse("chair", [
      { x: aisleX, y: farY === iy0 ? farY + 1 : farY - 1 },
      { x: aisleX + 1, y: farY },
      { x: aisleX - 1, y: farY },
      { x: midX, y: midY + 1 },
    ]);
    if (aisleX - 1 > ix0) {
      putOrElse("crate", [
        { x: aisleX - 1, y: midY === doorY ? iy0 + 1 : midY },
        { x: aisleX - 1, y: iy0 },
        { x: aisleX - 1, y: iy1 },
      ]);
    }
    matAt(nearDoorX, nearDoorY, "#2e2e2a");
    for (let y = iy0; y <= iy1; y++) {
      if (!free(aisleX, y)) continue;
      if ((y + bx) % 2 === 0) placeFloorDecor(decor, interiors, aisleX, y, "hazard", "#c8a020", (y + bx) % 2);
    }
    for (let y = iy0; y <= iy1; y++) {
      for (let x = ix0; x <= ix1; x++) {
        if (tiles[y * size + x] !== TILE.FLOOR) continue;
        if (!free(x, y) || decor.has(`${x},${y}`)) continue;
        if (noise.noise2(x * 0.7 + bx, y * 0.7 + by) > 0.82) {
          placeFloorDecor(decor, interiors, x, y, "oil", "#2a2820", (x + y) % 3);
        }
      }
    }
  } else if (style === "tower") {
    put(midX, midY, "desk");
    putOrElse("chair", [
      { x: midX, y: midY + 1 },
      { x: midX, y: midY - 1 },
      { x: midX + 1, y: midY },
      { x: midX - 1, y: midY },
    ]);
    putOrElse("chair", [
      { x: midX + 1, y: midY },
      { x: midX - 1, y: midY },
      { x: midX, y: midY - 1 },
      { x: midX, y: midY + 1 },
    ]);
    placeRug(decor, midX, midY, 1, 1, accent, 0, interiors);
    putOrElse("shelf", [{ x: ix0, y: iy0 }, { x: ix1, y: iy0 }, { x: ix0, y: midY }]);
    putOrElse("cabinet", [{ x: ix1, y: iy0 }, { x: ix1, y: iy1 }, { x: ix0, y: iy0 }]);
    putOrElse("plant", [{ x: ix0, y: iy1 }, { x: ix1, y: iy1 }, ...corners]);
    putOrElse("locker", [{ x: ix1, y: iy1 }, { x: ix0, y: iy1 }, { x: ix1, y: midY }]);
    matAt(nearDoorX, nearDoorY, "#3a4050");
  } else {
    // Bloque: cama lejos, sofá en lateral, mesa en centro — zonas disjuntas
    put(farX, farY, "bed");
    putOrElse("nightstand", [
      { x: farX === ix0 ? farX + 1 : farX - 1, y: farY },
      { x: farX, y: farY === iy0 ? farY + 1 : farY - 1 },
    ]);
    const sofaX = farX === ix0 ? ix1 : ix0;
    putOrElse("sofa", [
      { x: sofaX, y: midY },
      { x: sofaX, y: midY - 1 },
      { x: sofaX, y: midY + 1 },
    ]);
    put(midX, midY, "table");
    putOrElse("chair", [
      { x: midX + 1, y: midY },
      { x: midX - 1, y: midY },
      { x: midX, y: midY + 1 },
    ]);
    placeRug(decor, midX, midY, 1, 1, accent, 1, interiors);
    putOrElse("cabinet", [{ x: ix1, y: iy0 }, { x: ix0, y: iy0 }, { x: ix1, y: iy1 }]);
    putOrElse("fridge", [{ x: ix1, y: iy1 }, { x: ix0, y: iy1 }, { x: ix1, y: midY }]);
    putOrElse("plant", corners);
    putOrElse("drawer", corners);
    matAt(nearDoorX, nearDoorY, "#5a4038");
  }

  // Desgaste solo en suelo libre (nunca debajo de muebles)
  const dustCut =
    style === "tower" ? 0.78 :
    style === "shop" ? 0.72 :
    style === "warehouse" ? 0.88 :
    0.68;
  const stainCut = dustCut - 0.1;
  const rubbleCut = style === "warehouse" ? 0.92 : style === "tower" ? 0.95 : 0.58;
  for (let y = iy0; y <= iy1; y++) {
    for (let x = ix0; x <= ix1; x++) {
      if (tiles[y * size + x] !== TILE.FLOOR) continue;
      if (!free(x, y) || decor.has(`${x},${y}`)) continue;
      const r = noise.noise2(x * 0.55 + bx * 0.1, y * 0.55 + by * 0.1);
      if (r > dustCut) placeFloorDecor(decor, interiors, x, y, "dust", "#6a5a48", (x + y) % 3);
      else if (r > stainCut) placeFloorDecor(decor, interiors, x, y, "stain", "#3a2a22", (x * 3 + y) % 2);
      else if (r > rubbleCut && style !== "tower" && style !== "shop") {
        placeFloorDecor(decor, interiors, x, y, "rubble", "#5a5048", (x + y * 2) % 3);
      }
    }
  }

  if (props) {
    // Máx. 2 lámparas, solo sobre mesa/escritorio/mesita (no apilar en mostradores)
    const lampSpots = [];
    for (let y = iy0; y <= iy1; y++) {
      for (let x = ix0; x <= ix1; x++) {
        const t = furnitureType(interiors.get(`${x},${y}`));
        if (t === "nightstand" || t === "desk" || t === "table") {
          lampSpots.push({ x, y, kind: t === "nightstand" ? "candle" : "indoorLamp" });
        }
      }
    }
    lampSpots.sort((a, b) => (a.x + a.y * 3) - (b.x + b.y * 3));
    let lamps = 0;
    for (const spot of lampSpots) {
      if (lamps >= 2) break;
      if (noise.noise2(spot.x + 3, spot.y + 5) < 0.28 && lamps > 0) continue;
      props.push({
        type: spot.kind,
        x: spot.x + 0.5,
        y: spot.y + 0.5,
        lit: noise.noise2(spot.x * 0.4, spot.y * 0.4) > 0.05,
        indoor: true,
        flicker: spot.kind === "candle",
      });
      lamps++;
    }
    // Si no hay superficie, una vela en tile libre del centro
    if (!lamps && free(midX, midY) && (ix1 - ix0) >= 2) {
      props.push({
        type: style === "warehouse" ? "indoorLamp" : "candle",
        x: midX + 0.5,
        y: midY + 0.5,
        lit: true,
        indoor: true,
        flicker: style !== "warehouse",
      });
    }

    if (style === "residential" || style === "block") {
      for (const c of corners) {
        if (!free(c.x, c.y)) continue;
        if (noise.noise2(c.x + 9, c.y + 2) > 0.62) {
          props.push({ type: "debris", x: c.x + 0.5, y: c.y + 0.55, tone: 1, indoor: true });
          break;
        }
      }
    }

    decorateIndoorWallArt({
      props, interiors, ix0, iy0, ix1, iy1, doorX, doorY,
      style, accent, noise, bx, by,
    });
  }
}

/** Cuadros/carteles solo en muro libre (sin mueble en ese tile). */
function decorateIndoorWallArt({
  props, interiors, ix0, iy0, ix1, iy1, doorX, doorY,
  style, accent, noise, bx, by,
}) {
  const spots = [];
  for (let x = ix0; x <= ix1; x++) {
    if (!(x === doorX && iy0 === doorY)) spots.push({ x, y: iy0, wall: "n", ox: 0, oy: -0.22 });
    if (!(x === doorX && iy1 === doorY)) spots.push({ x, y: iy1, wall: "s", ox: 0, oy: 0.22 });
  }
  for (let y = iy0 + 1; y < iy1; y++) {
    if (!(ix0 === doorX && y === doorY)) spots.push({ x: ix0, y, wall: "w", ox: -0.22, oy: 0 });
    if (!(ix1 === doorX && y === doorY)) spots.push({ x: ix1, y, wall: "e", ox: 0.22, oy: 0 });
  }

  let artCount = 0;
  let posterCount = 0;
  const artBudget = style === "warehouse" ? 0 : style === "shop" ? 1 : 2;
  const posterBudget = style === "warehouse" ? 2 : style === "shop" ? 2 : 1;

  for (const s of spots) {
    const ft = furnitureType(interiors?.get(`${s.x},${s.y}`));
    if (ft) continue; // muro ocupado por mueble — no pintar encima

    const n = noise.noise2(s.x * 0.51 + bx, s.y * 0.47 + by + 4);
    const n2 = noise.noise2(s.x * 0.8 + 2, s.y * 0.7 + by);

    if (artCount < artBudget && n > 0.72 && n2 < 0.55) {
      props.push({
        type: "wallArt",
        x: s.x + 0.5 + s.ox,
        y: s.y + 0.5 + s.oy,
        wall: s.wall,
        motif: (s.x + s.y * 3 + bx) % 4,
        indoor: true,
        frame: accent || "#c8b898",
      });
      artCount++;
      continue;
    }

    if (posterCount < posterBudget && n < 0.28 && n2 > 0.4) {
      props.push({
        type: "poster",
        x: s.x + 0.5 + s.ox,
        y: s.y + 0.5 + s.oy,
        wall: s.wall,
        color: POSTER_COLORS[((s.x + s.y + by) >>> 0) % POSTER_COLORS.length],
        torn: n2 > 0.65,
        indoor: true,
      });
      posterCount++;
    }
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
  let bestD = 1.65;
  for (let oy = -1; oy <= 1; oy++) {
    for (let ox = -1; ox <= 1; ox++) {
      const key = `${tx + ox},${ty + oy}`;
      const furn = world.interiors.get(key);
      const t = furnitureType(furn);
      if (!t || !FURNITURE[t]?.searchable) continue;
      const d = Math.hypot(x - (tx + ox + 0.5), y - (ty + oy + 0.5));
      if (d < bestD) {
        bestD = d;
        best = { key, furn, x: tx + ox, y: ty + oy, d };
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
