import { createNoise } from "./noise.js";

/** Niebla Norte — ciudad zombie inventada. */
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
};

export const TILE_META = {
  [TILE.ROAD]: { name: "asfalto", walk: true, color: "#3a3a3c", speed: 1.05 },
  [TILE.SIDEWALK]: { name: "acera", walk: true, color: "#6a6864", speed: 1 },
  [TILE.FLOOR]: { name: "interior", walk: true, color: "#5a4e42", speed: 1, indoor: true },
  [TILE.WALL]: { name: "muro", walk: false, color: "#2a2a2c", solid: true },
  [TILE.RUBBLE]: { name: "escombros", walk: true, color: "#5c5348", speed: 0.65 },
  [TILE.PARK]: { name: "parque", walk: true, color: "#3d5a3a", speed: 0.95 },
  [TILE.PARKING]: { name: "parking", walk: true, color: "#4a4a4e", speed: 1 },
  [TILE.WATER]: { name: "canal", walk: false, color: "#2a555c", solid: true, drink: true },
  [TILE.ALLEY]: { name: "callejón", walk: true, color: "#353438", speed: 0.9 },
  [TILE.BARRICADE]: { name: "barricada", walk: false, color: "#6b4a28", solid: true, built: true },
  [TILE.DOOR]: { name: "puerta", walk: true, color: "#8a6a3a", speed: 0.85, door: true },
  [TILE.BASE]: { name: "base", walk: true, color: "#4a5a3a", speed: 1, indoor: true, base: true },
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

export const BUILD = {
  wall: { label: "Barricada", tile: TILE.BARRICADE, cost: { scrap: 2, wood: 1 }, hint: "2 chatarra + 1 tabla" },
  door: { label: "Puerta", tile: TILE.DOOR, cost: { scrap: 2, wood: 1 }, hint: "2 chatarra + 1 tabla" },
  claim: { label: "Marcar base", tile: TILE.BASE, cost: { scrap: 1, wood: 1 }, hint: "1 chatarra + 1 tabla" },
};

const BLOCK = 7;

export function generateWorld(size = 96, seed = (Math.random() * 1e9) | 0) {
  const noise = createNoise(seed);
  const tiles = new Uint8Array(size * size);
  const loot = new Map();
  const doors = new Map();

  tiles.fill(TILE.SIDEWALK);

  const canalY = 38 + ((noise.noise2(3, 7) * 14) | 0);
  for (let x = 0; x < size; x++) {
    for (let dy = -1; dy <= 1; dy++) {
      const y = canalY + dy;
      if (y >= 0 && y < size) tiles[y * size + x] = TILE.WATER;
    }
  }

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      if (tiles[y * size + x] === TILE.WATER) continue;
      if (x % BLOCK <= 1 || y % BLOCK <= 1) tiles[y * size + x] = TILE.ROAD;
    }
  }

  for (let by = 2; by < size - 2; by += BLOCK) {
    for (let bx = 2; bx < size - 2; bx += BLOCK) {
      if (by <= canalY + 2 && by + BLOCK >= canalY - 2) {
        fillRect(tiles, size, bx, by, TILE.RUBBLE);
        continue;
      }
      const roll = noise.noise2(bx * 0.17, by * 0.17);
      if (roll < 0.18) fillRect(tiles, size, bx, by, TILE.PARK);
      else if (roll < 0.28) fillRect(tiles, size, bx, by, TILE.PARKING);
      else if (roll < 0.36) {
        fillRect(tiles, size, bx, by, TILE.ALLEY);
        sprinkle(tiles, size, bx, by, TILE.RUBBLE, 0.22, noise);
      } else {
        carveBuilding(tiles, size, bx, by, doors, noise);
      }
    }
  }

  for (let x = 0; x < size; x++) {
    if (x % BLOCK <= 1) {
      for (let dy = -1; dy <= 1; dy++) {
        const y = canalY + dy;
        if (y >= 0 && y < size) tiles[y * size + x] = TILE.ROAD;
      }
    }
  }

  for (let y = 1; y < size - 1; y++) {
    for (let x = 1; x < size - 1; x++) {
      const t = tiles[y * size + x];
      const r = noise.noise2(x * 2.1 + 4, y * 2.1 + seed * 0.0001);
      if (t === TILE.FLOOR && r < 0.12) putLoot(loot, x, y, pickLoot(r));
      else if (t === TILE.RUBBLE && r < 0.09) putLoot(loot, x, y, r < 0.045 ? LOOT.SCRAP : LOOT.WOOD);
      else if (t === TILE.PARKING && r < 0.05) putLoot(loot, x, y, LOOT.SCRAP);
      else if (t === TILE.PARK && r < 0.045) putLoot(loot, x, y, LOOT.WOOD);
      else if (t === TILE.ALLEY && r < 0.07) putLoot(loot, x, y, r < 0.035 ? LOOT.FOOD : LOOT.SCRAP);
    }
  }

  const spawn = findSpawn(tiles, size, noise);
  return { size, seed, tiles, loot, doors, spawn, noise, canalY };
}

function fillRect(tiles, size, bx, by, tile) {
  for (let y = by; y < Math.min(size - 1, by + BLOCK - 2); y++) {
    for (let x = bx; x < Math.min(size - 1, bx + BLOCK - 2); x++) {
      const cur = tiles[y * size + x];
      if (cur === TILE.ROAD || cur === TILE.WATER) continue;
      tiles[y * size + x] = tile;
    }
  }
}

function sprinkle(tiles, size, bx, by, tile, chance, noise) {
  for (let y = by; y < Math.min(size - 1, by + BLOCK - 2); y++) {
    for (let x = bx; x < Math.min(size - 1, bx + BLOCK - 2); x++) {
      if (noise.noise2(x, y) < chance) tiles[y * size + x] = tile;
    }
  }
}

function carveBuilding(tiles, size, bx, by, doors, noise) {
  const x0 = bx;
  const y0 = by;
  const x1 = Math.min(size - 2, bx + BLOCK - 3);
  const y1 = Math.min(size - 2, by + BLOCK - 3);
  if (x1 - x0 < 3 || y1 - y0 < 3) return;

  for (let y = y0; y <= y1; y++) {
    for (let x = x0; x <= x1; x++) {
      const cur = tiles[y * size + x];
      if (cur === TILE.ROAD || cur === TILE.WATER) continue;
      const edge = x === x0 || x === x1 || y === y0 || y === y1;
      tiles[y * size + x] = edge ? TILE.WALL : TILE.FLOOR;
    }
  }

  const side = (noise.noise2(bx, by) * 4) | 0;
  let dx = ((x0 + x1) / 2) | 0;
  let dy = ((y0 + y1) / 2) | 0;
  if (side === 0) dy = y0;
  else if (side === 1) dy = y1;
  else if (side === 2) dx = x0;
  else dx = x1;
  tiles[dy * size + dx] = TILE.DOOR;
  doors.set(`${dx},${dy}`, { hp: 45 });

  if (noise.noise2(bx + 9, by + 3) > 0.7) {
    const rx = x0 + 1 + ((noise.noise2(bx, 1) * (x1 - x0 - 2)) | 0);
    const ry = y0 + 1 + ((noise.noise2(1, by) * (y1 - y0 - 2)) | 0);
    tiles[ry * size + rx] = TILE.RUBBLE;
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
      if (t !== TILE.ROAD && t !== TILE.SIDEWALK && t !== TILE.PARKING) continue;
      let nearFloor = false;
      for (let oy = -4; oy <= 4 && !nearFloor; oy++) {
        for (let ox = -4; ox <= 4; ox++) {
          if (tiles[(y + oy) * size + (x + ox)] === TILE.FLOOR) {
            nearFloor = true;
            break;
          }
        }
      }
      if (nearFloor) {
        candidates.push({ x: x + 0.5, y: y + 0.5, score: noise.noise2(x * 0.2, y * 0.2) });
      }
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
