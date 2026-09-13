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
};

const LOOT_DEFS = {
  [LOOT.FOOD]: { label: "Latas", gather: "latas de comida" },
  [LOOT.WATER]: { label: "Agua", gather: "botella de agua" },
  [LOOT.SCRAP]: { label: "Chatarra", gather: "chatarra" },
  [LOOT.WOOD]: { label: "Tablas", gather: "tablas" },
  [LOOT.MED]: { label: "Botiquín", gather: "botiquín" },
};

/** Muebles interiores. searchable = se registran con E. */
export const FURNITURE = {
  table: { label: "Mesa", searchable: false },
  bed: { label: "Cama", searchable: false },
  shelf: { label: "Estantería", searchable: true },
  crate: { label: "Cajón", searchable: true },
  cabinet: { label: "Armario", searchable: true },
  drawer: { label: "Cómoda", searchable: true },
  fridge: { label: "Nevera", searchable: true },
  locker: { label: "Taquilla", searchable: true },
};

const CONTAINER_LOOT = {
  shelf: [
    { id: LOOT.FOOD, w: 3 },
    { id: LOOT.SCRAP, w: 2 },
    { id: LOOT.WOOD, w: 2 },
    { id: LOOT.WATER, w: 1 },
    { empty: true, w: 2 },
  ],
  crate: [
    { id: LOOT.SCRAP, w: 3 },
    { id: LOOT.WOOD, w: 3 },
    { id: LOOT.FOOD, w: 1 },
    { empty: true, w: 2 },
  ],
  cabinet: [
    { id: LOOT.FOOD, w: 2 },
    { id: LOOT.MED, w: 2 },
    { id: LOOT.WOOD, w: 1 },
    { id: LOOT.SCRAP, w: 2 },
    { empty: true, w: 2 },
  ],
  drawer: [
    { id: LOOT.SCRAP, w: 3 },
    { id: LOOT.MED, w: 2 },
    { id: LOOT.FOOD, w: 1 },
    { empty: true, w: 3 },
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
      else carveCityBuilding(tiles, size, bx, by, doors, buildings, interiors, props, noise, seed);
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
      // Farolas muy espaciadas: pocas islas de luz en la noche
      if ((x + y * 5) % 47 === 0 && x % 3 === 0 && y % 2 === 0) {
        props.push({ type: "lamp", x: x + 0.5, y: y + 0.5 });
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
  return { size, seed, tiles, loot, doors, buildings, props, interiors, spawn, noise, canalY };
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

function carveCityBuilding(tiles, size, bx, by, doors, buildings, interiors, props, noise, seed) {
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
  // Matiz de fachada por manzana para que no se vean clonadas
  const tint = ((noise.noise2(bx * 0.17, by * 0.19) * 24) | 0) - 12;
  const awning = AWNING[((bx * 3 + by * 5 + seed) >>> 0) % AWNING.length];
  const facadeTinted = shadeHex(facade, tint);

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

  // Muebles interiores (armarios, cómodas, neveras… buscables con E)
  for (let y = y0 + 1; y < y1; y++) {
    for (let x = x0 + 1; x < x1; x++) {
      if (tiles[y * size + x] !== TILE.FLOOR) continue;
      const againstWall =
        tiles[(y - 1) * size + x] === TILE.WALL ||
        tiles[(y + 1) * size + x] === TILE.WALL ||
        tiles[y * size + (x - 1)] === TILE.WALL ||
        tiles[y * size + (x + 1)] === TILE.WALL;
      const r = noise.noise2(x * 1.3, y * 1.3);
      let type = null;
      if (style === "warehouse") {
        if (againstWall && r < 0.24) type = r < 0.11 ? "locker" : "shelf";
        else if (r < 0.12) type = "crate";
        else if (r < 0.17) type = "shelf";
      } else if (style === "shop") {
        if (againstWall && r < 0.22) type = r < 0.09 ? "fridge" : r < 0.16 ? "cabinet" : "shelf";
        else if (r < 0.1) type = "shelf";
        else if (r < 0.15) type = "table";
        else if (r < 0.18) type = "crate";
      } else if (style === "residential") {
        if (againstWall && r < 0.2) type = r < 0.07 ? "fridge" : r < 0.14 ? "cabinet" : "drawer";
        else if (r < 0.08) type = "bed";
        else if (r < 0.12) type = "table";
        else if (r < 0.15) type = "shelf";
        else if (againstWall && r < 0.22) type = "cabinet";
      } else {
        if (againstWall && r < 0.18) type = r < 0.07 ? "cabinet" : r < 0.12 ? "drawer" : "shelf";
        else if (r < 0.07) type = "table";
        else if (r < 0.11) type = "shelf";
        else if (r < 0.14) type = "bed";
        else if (r < 0.16) type = "crate";
      }
      if (type) placeFurniture(interiors, x, y, type);
    }
  }

  // Mobiliario urbano en acera
  if (noise.noise2(bx + 2, by + 2) > 0.45) {
    props.push({ type: "dumpster", x: ring.x0 + 0.5, y: ((y0 + y1) / 2) + 0.15 });
  }
  if (noise.noise2(bx + 5, by + 1) > 0.55) {
    props.push({ type: "sign", x: dx + (side === 2 ? -0.7 : side === 3 ? 0.7 : 0), y: dy + (side === 0 ? -0.7 : side === 1 ? 0.7 : 0), label: name.split(" ")[0] });
  }
  // Porche / toldo delante de la puerta (tiendas y cafés más grandes)
  props.push({ type: "awning", x: dx + 0.5, y: dy + 0.5, side, color: awning, wide: style === "shop" });
  if (style === "residential" && noise.noise2(bx + 8, by) > 0.4) {
    props.push({ type: "planter", x: dx + (side >= 2 ? 0 : side === 0 ? 0.2 : -0.2) + 0.5, y: dy + (side < 2 ? 0 : 0.2) + 0.5, tone: 1 });
  }

  buildings.push({ x0, y0, x1, y1, doorX: dx, doorY: dy, facade: facadeTinted, name, floors, style, awning });
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
  if (r < 0.03) return LOOT.MED;
  if (r < 0.055) return LOOT.FOOD;
  if (r < 0.08) return LOOT.WATER;
  if (r < 0.1) return LOOT.SCRAP;
  return LOOT.WOOD;
}

function putLoot(map, x, y, id) {
  map.set(`${x},${y}`, { id, amount: 1 + ((x + y) % 2) });
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
  const amount = 1 + ((Math.random() * 2) | 0);
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
