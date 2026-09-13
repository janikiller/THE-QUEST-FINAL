import { createNoise } from "./noise.js";

export const TILE = {
  DEEP: 0,
  WATER: 1,
  SAND: 2,
  GRASS: 3,
  FOREST: 4,
  SWAMP: 5,
  ROCK: 6,
  RUIN: 7,
};

export const TILE_META = {
  [TILE.DEEP]: { name: "mar", walk: false, color: "#16353a" },
  [TILE.WATER]: { name: "agua dulce", walk: false, color: "#2d6a6e", drink: true },
  [TILE.SAND]: { name: "playa", walk: true, color: "#c9b48a", speed: 1 },
  [TILE.GRASS]: { name: "pradera", walk: true, color: "#5f8a52", speed: 1 },
  [TILE.FOREST]: { name: "pinar", walk: true, color: "#2f4a34", speed: 0.72 },
  [TILE.SWAMP]: { name: "ciénaga", walk: true, color: "#3d4f36", speed: 0.55 },
  [TILE.ROCK]: { name: "risco", walk: true, color: "#6d6a63", speed: 0.85 },
  [TILE.RUIN]: { name: "ruinas", walk: true, color: "#7a6d5c", speed: 0.9 },
};

export const RESOURCE = {
  BERRY: "berry",
  WOOD: "wood",
  STONE: "stone",
  REED: "reed",
  FLINT: "flint",
};

const RESOURCE_DEFS = {
  [RESOURCE.BERRY]: { label: "Bayas", tile: TILE.GRASS, chance: 0.09, gather: "bayas silvestres" },
  [RESOURCE.WOOD]: { label: "Madera", tile: TILE.FOREST, chance: 0.16, gather: "rama caída" },
  [RESOURCE.STONE]: { label: "Piedra", tile: TILE.ROCK, chance: 0.14, gather: "piedra afilada" },
  [RESOURCE.REED]: { label: "Juncos", tile: TILE.SWAMP, chance: 0.14, gather: "juncos" },
  [RESOURCE.FLINT]: { label: "Pedernal", tile: TILE.RUIN, chance: 0.22, gather: "pedernal" },
};

export function generateWorld(size = 96, seed = (Math.random() * 1e9) | 0) {
  const noise = createNoise(seed);
  const tiles = new Uint8Array(size * size);
  const resources = new Map();
  const cx = (size - 1) / 2;
  const cy = (size - 1) / 2;

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const nx = (x - cx) / (size * 0.42);
      const ny = (y - cy) / (size * 0.42);
      const dist = Math.sqrt(nx * nx + ny * ny);
      const island = 1 - dist;
      const h = noise.fbm(x * 0.045, y * 0.045, 5);
      const m = noise.fbm(x * 0.06 + 40, y * 0.06 + 12, 4);
      const ridge = noise.fbm(x * 0.09 + 90, y * 0.09, 3);
      const shaped = h * 0.7 + island * 0.55 + ridge * 0.12 - 0.18;

      let t = TILE.DEEP;
      if (shaped > 0.12 && shaped < 0.22) t = TILE.WATER;
      else if (shaped >= 0.22 && shaped < 0.3) t = TILE.SAND;
      else if (shaped >= 0.3) {
        if (shaped > 0.7 && ridge > 0.58) t = TILE.ROCK;
        else if (m > 0.64 && shaped < 0.58) t = TILE.SWAMP;
        else if (m < 0.48 && shaped > 0.36) t = TILE.FOREST;
        else if (ridge > 0.74 && m > 0.4 && shaped > 0.45) t = TILE.RUIN;
        else t = TILE.GRASS;
      }

      // Costa irregular: forzar arena cerca del agua en tierra.
      tiles[y * size + x] = t;
    }
  }

  // Suavizar costas: arena entre agua y tierra.
  for (let y = 1; y < size - 1; y++) {
    for (let x = 1; x < size - 1; x++) {
      const i = y * size + x;
      const t = tiles[i];
      if (t !== TILE.GRASS && t !== TILE.FOREST && t !== TILE.SWAMP) continue;
      let nearWater = false;
      for (let oy = -1; oy <= 1; oy++) {
        for (let ox = -1; ox <= 1; ox++) {
          const n = tiles[(y + oy) * size + (x + ox)];
          if (n === TILE.WATER || n === TILE.DEEP) nearWater = true;
        }
      }
      if (nearWater && noise.noise2(x * 0.3, y * 0.3) > 0.35) tiles[i] = TILE.SAND;
    }
  }

  // Recursos
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const t = tiles[y * size + x];
      for (const [id, def] of Object.entries(RESOURCE_DEFS)) {
        if (def.tile !== t) continue;
        const r = noise.noise2(x * 1.7 + def.chance * 20, y * 1.7 + seed * 0.001);
        if (r < def.chance) {
          resources.set(`${x},${y}`, { id, amount: 1 + ((r * 10) | 0) % 3 });
        }
      }
    }
  }

  const spawn = findSpawn(tiles, size, noise);
  return { size, seed, tiles, resources, spawn, noise };
}

function findSpawn(tiles, size, noise) {
  const candidates = [];
  for (let y = 2; y < size - 2; y++) {
    for (let x = 2; x < size - 2; x++) {
      const t = tiles[y * size + x];
      if (t !== TILE.SAND && t !== TILE.GRASS) continue;
      let nearForest = false;
      let nearWater = false;
      for (let oy = -3; oy <= 3; oy++) {
        for (let ox = -3; ox <= 3; ox++) {
          const n = tiles[(y + oy) * size + (x + ox)];
          if (n === TILE.FOREST) nearForest = true;
          if (n === TILE.WATER) nearWater = true;
        }
      }
      if (nearForest && nearWater) {
        candidates.push({ x: x + 0.5, y: y + 0.5, score: noise.noise2(x, y) });
      }
    }
  }
  candidates.sort((a, b) => b.score - a.score);
  if (candidates.length) return { x: candidates[0].x, y: candidates[0].y };
  return { x: size / 2, y: size / 2 };
}

export function tileAt(world, x, y) {
  const ix = Math.floor(x);
  const iy = Math.floor(y);
  if (ix < 0 || iy < 0 || ix >= world.size || iy >= world.size) return TILE.DEEP;
  return world.tiles[iy * world.size + ix];
}

export function canWalk(world, x, y) {
  return TILE_META[tileAt(world, x, y)].walk;
}

export function resourceLabel(id) {
  return RESOURCE_DEFS[id]?.label ?? id;
}

export function resourceGatherText(id) {
  return RESOURCE_DEFS[id]?.gather ?? id;
}
