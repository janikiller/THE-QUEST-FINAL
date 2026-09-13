"""Ciudad procedural."""

from __future__ import annotations

import random
from typing import Dict, List, Optional, Tuple

from .constants import (
    ALLEY, BARRICADE, BLOCK, CROSSWALK, DOOR, FLOOR, MAP, PARK, PARKING,
    ROAD, ROAD_W, RUBBLE, SIDEWALK, VOID, WALKABLE, WALL, WATER,
)


class World:
    def __init__(self, size: int = MAP, seed: Optional[int] = None):
        self.size = size
        self.seed = seed if seed is not None else random.randint(1, 999999)
        self.rng = random.Random(self.seed)
        self.tiles = [[PARK for _ in range(size)] for _ in range(size)]
        self.furniture: Dict[Tuple[int, int], dict] = {}
        self.loot: Dict[Tuple[int, int], dict] = {}
        self.doors: Dict[Tuple[int, int], float] = {}
        self.lamps: List[Tuple[int, int]] = []
        self.spawn = (size * 0.5, size * 0.5)
        self._carve()
        self._find_spawn()

    def in_bounds(self, x: int, y: int) -> bool:
        return 0 <= x < self.size and 0 <= y < self.size

    def tile_at(self, x: float, y: float) -> int:
        tx, ty = int(x), int(y)
        if not self.in_bounds(tx, ty):
            return WALL
        return self.tiles[ty][tx]

    def set_tile(self, x: int, y: int, t: int) -> None:
        if self.in_bounds(x, y):
            self.tiles[y][x] = t

    def can_walk(self, x: float, y: float, bullet: bool = False, player: bool = False) -> bool:
        t = self.tile_at(x, y)
        if t in (WALL, VOID, WATER):
            return False
        if t == BARRICADE:
            return bullet
        if t == DOOR:
            key = (int(x), int(y))
            if self.doors.get(key, 0) > 0:
                return player or bullet
            return True
        return t in WALKABLE

    def nearest_furniture(self, pos: Tuple[float, float], radius: float = 1.35):
        best = None
        best_d = radius
        px, py = pos
        for (fx, fy), data in self.furniture.items():
            d = ((fx + 0.5 - px) ** 2 + (fy + 0.5 - py) ** 2) ** 0.5
            if d < best_d:
                best_d = d
                best = {"key": (fx, fy), "pos": (fx + 0.5, fy + 0.5), **data}
        return best

    def take_floor_loot(self, pos: Tuple[float, float]):
        tx, ty = int(pos[0]), int(pos[1])
        for oy in (-1, 0, 1):
            for ox in (-1, 0, 1):
                key = (tx + ox, ty + oy)
                if key in self.loot:
                    return self.loot.pop(key)
        return None

    def search_container(self, key: Tuple[int, int]):
        if key not in self.furniture:
            return {"empty": True}
        f = self.furniture[key]
        if f.get("searched"):
            return {"already": True, "label": f["label"]}
        f["searched"] = True
        pick = self._weighted(self._loot_table(f["type"]))
        if pick.get("empty"):
            return {"empty": True, "label": f["label"]}
        return {"id": pick["id"], "amount": pick.get("amount", 1), "label": f["label"]}

    def _put(self, x: int, y: int, t: int) -> None:
        if self.in_bounds(x, y):
            self.tiles[y][x] = t

    def _carve(self) -> None:
        canal_y = int(self.size * 0.62)
        for x in range(self.size):
            for dy in (-1, 0, 1):
                self._put(x, canal_y + dy, WATER)

        step = BLOCK + ROAD_W
        for by in range(2, self.size - 2, step):
            for bx in range(2, self.size - 2, step):
                self._roads(bx, by)
                if by + BLOCK >= canal_y - 2 and by <= canal_y + 2:
                    self._fill(bx + ROAD_W, by + ROAD_W, PARK, 0.04, "wood")
                elif (bx + by) % 3 == 0:
                    self._fill(bx + ROAD_W, by + ROAD_W, PARKING, 0.05, None)
                elif (bx * 3 + by) % 5 == 0:
                    self._alley(bx + ROAD_W, by + ROAD_W)
                else:
                    self._building(bx + ROAD_W, by + ROAD_W)

        for y in range(3, self.size - 3, step):
            for x in range(3, self.size - 3, step):
                self.lamps.append((x, y))
                if self.rng.random() < 0.35:
                    self.loot[(x + 1, y)] = {"id": self._rand_loot(), "amount": 1}

    def _roads(self, bx: int, by: int) -> None:
        for i in range(BLOCK + ROAD_W):
            for w in range(ROAD_W):
                self._put(bx + i, by + w, ROAD)
                self._put(bx + w, by + i, ROAD)
                if i == BLOCK // 2:
                    self._put(bx + i, by + w, CROSSWALK)
                    self._put(bx + w, by + i, CROSSWALK)
        for i in range(1, BLOCK + 1):
            self._put(bx + ROAD_W + i - 1, by + ROAD_W - 1, SIDEWALK)
            self._put(bx + ROAD_W - 1, by + ROAD_W + i - 1, SIDEWALK)

    def _fill(self, ox: int, oy: int, t: int, chance: float, fixed: Optional[str]) -> None:
        for y in range(oy, min(oy + BLOCK - 1, self.size)):
            for x in range(ox, min(ox + BLOCK - 1, self.size)):
                self._put(x, y, t)
                if chance > 0 and self.rng.random() < chance:
                    self.loot[(x, y)] = {
                        "id": fixed if fixed else self._rand_loot(),
                        "amount": 1,
                    }

    def _alley(self, ox: int, oy: int) -> None:
        for y in range(oy, min(oy + BLOCK - 1, self.size)):
            for x in range(ox, min(ox + BLOCK - 1, self.size)):
                self._put(x, y, ALLEY if (x + y) % 2 == 0 else RUBBLE)

    def _building(self, ox: int, oy: int) -> None:
        w = h = BLOCK - 2
        if w < 4 or h < 4:
            return
        x0, y0, x1, y1 = ox, oy, ox + w, oy + h
        for y in range(y0, y1):
            for x in range(x0, x1):
                edge = x == x0 or y == y0 or x == x1 - 1 or y == y1 - 1
                self._put(x, y, WALL if edge else FLOOR)
        door = (x0 + w // 2, y1 - 1)
        self._put(door[0], door[1], DOOR)
        self.doors[door] = 55.0
        self._put(door[0], door[1] + 1, SIDEWALK)
        types = ["shelf", "desk", "fridge", "locker", "cabinet", "nightstand"]
        labels = {
            "shelf": "Estantería", "desk": "Escritorio", "fridge": "Nevera",
            "locker": "Taquilla", "cabinet": "Armario", "nightstand": "Mesilla",
        }
        for _ in range(3 + self.rng.randint(0, 3)):
            fx = x0 + 1 + self.rng.randint(0, max(0, x1 - x0 - 3))
            fy = y0 + 1 + self.rng.randint(0, max(0, y1 - y0 - 3))
            key = (fx, fy)
            if key in self.furniture:
                continue
            ft = types[self.rng.randint(0, len(types) - 1)]
            self.furniture[key] = {"type": ft, "label": labels[ft], "searched": False}

    def _find_spawn(self) -> None:
        for _ in range(200):
            x = 4 + self.rng.randint(0, self.size - 9)
            y = 4 + self.rng.randint(0, self.size - 9)
            t = self.tile_at(x + 0.5, y + 0.5)
            if t in (ROAD, SIDEWALK):
                self.spawn = (x + 0.5, y + 0.5)
                return
        self.spawn = (self.size * 0.5, self.size * 0.5)

    def _rand_loot(self) -> str:
        r = self.rng.random()
        if r < 0.2:
            return "food"
        if r < 0.35:
            return "water"
        if r < 0.5:
            return "scrap"
        if r < 0.65:
            return "wood"
        if r < 0.75:
            return "med"
        if r < 0.85:
            return "ammo_9mm"
        if r < 0.9:
            return "flashlight"
        if r < 0.95:
            return "shirt"
        return "knife"

    def _loot_table(self, ft: str):
        tables = {
            "fridge": [
                {"id": "food", "w": 3}, {"id": "water", "w": 3},
                {"id": "med", "w": 1}, {"empty": True, "w": 1},
            ],
            "locker": [
                {"id": "scrap", "w": 2}, {"id": "bat", "w": 1}, {"id": "pistol", "w": 1},
                {"id": "ammo_9mm", "w": 2}, {"id": "vest", "w": 1},
                {"id": "flashlight", "w": 2}, {"empty": True, "w": 2},
            ],
            "desk": [
                {"id": "scrap", "w": 2}, {"id": "knife", "w": 1},
                {"id": "ammo_9mm", "w": 2}, {"id": "pistol", "w": 1}, {"empty": True, "w": 2},
            ],
            "nightstand": [
                {"id": "med", "w": 2}, {"id": "knife", "w": 1},
                {"id": "ammo_9mm", "w": 1}, {"empty": True, "w": 1},
            ],
        }
        return tables.get(ft, [
            {"id": "food", "w": 2}, {"id": "scrap", "w": 2}, {"id": "wood", "w": 2},
            {"id": "hoodie", "w": 1}, {"id": "bag", "w": 1}, {"empty": True, "w": 2},
        ])

    def _weighted(self, table):
        total = sum(int(e["w"]) for e in table)
        r = self.rng.randint(0, max(1, total) - 1)
        acc = 0
        for e in table:
            acc += int(e["w"])
            if r < acc:
                return e
        return table[-1]
