"""Lógica de partida CRESPO / Niebla Norte."""
from __future__ import annotations

import math
import random
from typing import Dict, List, Optional, Set, Tuple

import pygame

from .constants import (
    BAGS,
    BARRICADE,
    BASE,
    BASE_CAP,
    CLOTHES,
    DAY_LEN,
    DOOR,
    ITEMS,
    LIGHTS,
    MAX_HP,
    PLAYER_R,
    SPRINT,
    VOID,
    WALL,
    WATER,
    WEAPON_ORDER,
    WEAPONS,
    WALK,
)
from .world import World

Vec = Tuple[float, float]


def vadd(a: Vec, b: Vec) -> Vec:
    return (a[0] + b[0], a[1] + b[1])


def vmul(a: Vec, s: float) -> Vec:
    return (a[0] * s, a[1] * s)


def vlen(a: Vec) -> float:
    return math.hypot(a[0], a[1])


def vnorm(a: Vec) -> Vec:
    length = vlen(a)
    return (0.0, 0.0) if length < 1e-6 else (a[0] / length, a[1] / length)


class Zombie:
    def __init__(self, pos: Vec, wave: int = 0):
        sh = 1.0 + max(0, wave - 1) * 0.14
        ss = 1.0 + max(0, wave - 1) * 0.07
        self.pos = pos
        self.hp = (38 + random.random() * 28) * sh
        self.speed = (0.85 + random.random() * 0.55) * ss
        self.dmg = 15.0 * (1.0 + max(0, wave - 1) * 0.05)
        self.stun = 0.0
        self.flash = 0.0
        self.atk_cd = 0.0

    def hit(self, dmg: float, knock: Vec) -> bool:
        self.hp -= dmg
        self.stun = max(self.stun, 0.28)
        self.flash = 0.2
        self.pos = vadd(self.pos, vmul(knock, 0.02))
        return self.hp <= 0


class Bullet:
    def __init__(self, pos: Vec, vel: Vec, dmg: float, life: float):
        self.pos = pos
        self.vel = vel
        self.dmg = dmg
        self.life = life


class Burst:
    def __init__(self, pos: Vec, color: Tuple[int, int, int]):
        self.pos = pos
        self.color = color
        self.t = 0.35

    def update(self, dt: float) -> bool:
        self.t -= dt
        return self.t > 0


class Game:
    def __init__(self, seed: Optional[int] = None):
        self.world = World(seed=seed)
        self.pos = self.world.spawn
        self.hp = MAX_HP
        self.max_hp = MAX_HP
        self.hunger = 82.0
        self.thirst = 78.0
        self.stamina = 100.0
        self.aim = 0.0
        self.atk_cd = 0.0
        self.interact_cd = 0.0
        self.hurt_flash = 0.0
        self.swing_t = 0.0
        self.dead = False
        self.death_reason = ""
        self.kills = 0

        self.inv: Dict[str, int] = {
            "food": 1, "water": 1, "scrap": 2, "wood": 2, "med": 1,
            "shirt": 1, "bag": 1, "bat": 1, "pistol": 1, "ammo_9mm": 18,
        }
        self.equip: Dict[str, Optional[str]] = {
            "hand": "bat", "body": "shirt", "bag": "bag", "light": None,
        }
        self.gear_phase = "clothes"
        self.build_mode = ""

        self.time_of_day = 0.52 * DAY_LEN
        self.weather = "rain"
        self.weather_label = "Lluvia"
        self.weather_i = 0.55
        self.weather_next = 20.0
        self.thunder = 0.0

        self.wave = 0
        self.wave_phase = "countdown"
        self.wave_timer = 16.0
        self.wave_quota = 0
        self.wave_spawned = 0

        self.zombies: List[Zombie] = []
        self.bullets: List[Bullet] = []
        self.fx: List[Burst] = []
        self.noise = 0.0
        self.shake = 0.0
        self.muzzle = 0.0
        self.toast = "Niebla Norte. Ratón apunta · clic dispara · Q melee · E saquea."
        self.toast_t = 3.0
        self.banner = "NIEBLA NORTE"
        self.banner_t = 2.2
        self._seed_zombies(5)

    def toast_msg(self, msg: str, dur: float = 2.4) -> None:
        self.toast = msg
        self.toast_t = dur

    def show_banner(self, msg: str) -> None:
        self.banner = msg
        self.banner_t = 2.2

    def day_phase(self) -> dict:
        t = (self.time_of_day % DAY_LEN) / DAY_LEN
        if t < 0.18:
            phase = {"name": "Amanecer", "light": 0.45 + t * 2.8, "night": False}
        elif t < 0.48:
            phase = {"name": "Día", "light": 1.0, "night": False}
        elif t < 0.6:
            phase = {"name": "Atardecer", "light": 0.78 - (t - 0.48) * 1.5, "night": False}
        elif t < 0.72:
            phase = {"name": "Anochecer", "light": 0.52 - (t - 0.6) * 1.2, "night": True}
        else:
            phase = {"name": "Noche", "light": 0.42, "night": True}
        mult = {"clear": 1.0, "cloudy": 0.94, "rain": 0.88, "storm": 0.78}.get(self.weather, 1.0)
        phase["light"] = float(phase["light"]) * mult
        if self.thunder > 0:
            phase["light"] = min(1.0, phase["light"] + self.thunder * 0.85)
        phase["weather_label"] = self.weather_label
        phase["rain"] = self.weather_i
        phase["thunder"] = self.thunder
        return phase

    def wave_text(self) -> str:
        if self.wave_phase == "countdown":
            n = max(1, math.ceil(self.wave_timer))
            return f"Oleada 1 en {n}s" if self.wave == 0 else f"Oleada {self.wave + 1} en {n}s"
        if self.wave_phase == "spawning":
            return f"Oleada {self.wave}: {self.wave_spawned}/{self.wave_quota}"
        if self.wave_phase == "fighting":
            return f"Oleada {self.wave} en curso"
        return f"Oleada {self.wave} limpia"

    def weapon(self) -> dict:
        wid = self.equip["hand"]
        if not wid:
            return {
                "id": "", "label": "Manos", "firearm": False,
                "dmg": 18, "rng": 1.15, "cd": 0.35, "stam": 5, "icon": "F",
            }
        d = dict(WEAPONS.get(wid, ITEMS.get(wid, {})))
        d["id"] = wid
        for key, default in (
            ("firearm", False), ("dmg", 18), ("rng", 1.15),
            ("cd", 0.35), ("stam", 5), ("label", wid), ("icon", "?"),
        ):
            d.setdefault(key, default)
        return d

    def hotbar(self) -> List[dict]:
        owned = [w for w in WEAPON_ORDER if self.inv.get(w, 0) > 0]
        slots: List[dict] = []
        for i in range(5):
            if i >= len(owned):
                slots.append({"index": i, "empty": True})
                continue
            wid = owned[i]
            d = WEAPONS.get(wid, {})
            ammo = self.inv.get(d["ammo"], 0) if d.get("firearm") else None
            slots.append({
                "index": i, "empty": False, "id": wid,
                "label": d.get("label", wid), "icon": d.get("icon", "?"),
                "ammo": ammo, "active": self.equip["hand"] == wid,
            })
        return slots

    def inv_used(self) -> float:
        total = 0.0
        for iid, count in self.inv.items():
            if count <= 0:
                continue
            d = ITEMS.get(iid, {"w": 1.0})
            slot = d.get("slot")
            equipped = bool(slot) and self.equip.get(slot) == iid
            total += max(0, count - (1 if equipped else 0)) * float(d.get("w", 1.0))
        return total

    def inv_cap(self) -> float:
        cap = BASE_CAP
        for slot in ("hand", "body", "bag", "light"):
            iid = self.equip.get(slot)
            if iid:
                cap += float(ITEMS.get(iid, {}).get("cap", 0))
        return cap

    def try_take(self, iid: str, amount: int = 1) -> bool:
        weight = float(ITEMS.get(iid, {"w": 1.0}).get("w", 1.0)) * amount
        if self.inv_used() + weight > self.inv_cap() + 0.001:
            return False
        self.inv[iid] = self.inv.get(iid, 0) + amount
        return True

    def _spend(self, iid: str, n: int = 1) -> bool:
        if self.inv.get(iid, 0) < n:
            return False
        self.inv[iid] -= n
        if self.inv[iid] <= 0:
            del self.inv[iid]
        return True

    def update(self, dt: float, pressed, mouse_world: Vec, mouse_click: bool, just: Set[int]) -> None:
        if self.dead:
            return
        self.time_of_day += dt
        self.toast_t = max(0.0, self.toast_t - dt)
        self.banner_t = max(0.0, self.banner_t - dt)
        self.shake = max(0.0, self.shake - dt * 4)
        self.noise = max(0.0, self.noise - dt)
        self.muzzle = max(0.0, self.muzzle - dt)
        self.thunder = max(0.0, self.thunder - dt * 3.2)
        self.atk_cd = max(0.0, self.atk_cd - dt)
        self.interact_cd = max(0.0, self.interact_cd - dt)
        self.hurt_flash = max(0.0, self.hurt_flash - dt)
        self.swing_t = max(0.0, self.swing_t - dt)
        self._tick_weather(dt)

        self.aim = math.atan2(mouse_world[1] - self.pos[1], mouse_world[0] - self.pos[0])
        self._move(dt, pressed)
        self._actions(just, mouse_click)
        self._vitals(dt)
        self._update_zombies(dt)
        self._update_bullets(dt)
        self._update_waves(dt)
        self.fx = [fx for fx in self.fx if fx.update(dt)]
        if self.hp <= 0:
            self._die("Los muertos de Niebla Norte te alcanzaron.")

    def _move(self, dt: float, pressed) -> None:
        dx = (1 if pressed[pygame.K_d] or pressed[pygame.K_RIGHT] else 0) - (
            1 if pressed[pygame.K_a] or pressed[pygame.K_LEFT] else 0
        )
        dy = (1 if pressed[pygame.K_s] or pressed[pygame.K_DOWN] else 0) - (
            1 if pressed[pygame.K_w] or pressed[pygame.K_UP] else 0
        )
        moving = abs(dx) + abs(dy) > 0
        sprint = pressed[pygame.K_SPACE] and self.stamina > 2 and moving
        if moving:
            direction = vnorm((float(dx), float(dy)))
            speed = SPRINT if sprint else WALK
            nx = self.pos[0] + direction[0] * speed * dt
            ny = self.pos[1] + direction[1] * speed * dt
            if self.world.can_walk(nx, self.pos[1], player=True):
                self.pos = (nx, self.pos[1])
            if self.world.can_walk(self.pos[0], ny, player=True):
                self.pos = (self.pos[0], ny)
            self.stamina = max(0.0, self.stamina - (16 if sprint else 3) * dt)
            self.hunger = max(0.0, self.hunger - (0.9 if sprint else 0.35) * dt)
            self.thirst = max(0.0, self.thirst - (1.1 if sprint else 0.45) * dt)
            if sprint:
                self.noise = max(self.noise, 2.5)
        else:
            self.stamina = min(100.0, self.stamina + 14 * dt)

    def _actions(self, just: Set[int], mouse_click: bool) -> None:
        for i, key in enumerate((pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4, pygame.K_5)):
            if key in just:
                self._equip_hotbar(i)
        if pygame.K_q in just and self.atk_cd <= 0:
            self._melee()
        if mouse_click and self.atk_cd <= 0:
            weapon = self.weapon()
            if weapon.get("firearm"):
                self._fire(weapon)
            else:
                self._melee()
        if pygame.K_e in just and self.interact_cd <= 0:
            self._interact()
        if pygame.K_r in just and self.interact_cd <= 0:
            self._consume()
        if pygame.K_t in just:
            self._cycle_gear()
        if pygame.K_b in just:
            self._cycle_build()
        if pygame.K_RETURN in just and self.build_mode:
            self._build()
        if pygame.K_ESCAPE in just or pygame.K_0 in just:
            self.build_mode = ""

    def _vitals(self, dt: float) -> None:
        self.hunger = max(0.0, self.hunger - 0.28 * dt)
        self.thirst = max(0.0, self.thirst - 0.36 * dt)
        if self.hunger < 8:
            self.hp -= 3.5 * dt
        if self.thirst < 8:
            self.hp -= 4.5 * dt
        if self.world.tile_at(*self.pos) == BASE:
            self.stamina = min(100.0, self.stamina + 6 * dt)

    def _equip_hotbar(self, index: int) -> None:
        slots = self.hotbar()
        if index >= len(slots) or slots[index].get("empty"):
            self.toast_msg(f"Hotbar {index + 1} vacío.")
            return
        wid = slots[index]["id"]
        if self.equip["hand"] == wid:
            self.equip["hand"] = None
            self.toast_msg("Mano libre.")
        else:
            self.equip["hand"] = wid
            self.toast_msg(f"Arma: {ITEMS.get(wid, {}).get('label', wid)}")

    def _fire(self, weapon: dict) -> None:
        ammo = weapon.get("ammo", "")
        if not ammo or self.inv.get(ammo, 0) <= 0:
            self.toast_msg("Sin munición.")
            self.atk_cd = 0.2
            return
        self._spend(ammo, 1)
        self.atk_cd = float(weapon["cd"])
        self.stamina = max(0.0, self.stamina - float(weapon["stam"]))
        self.noise = max(self.noise, min(2.6, float(weapon.get("noise", 8)) * 0.22))
        self.muzzle = 0.16
        self.shake = max(self.shake, 0.28 if int(weapon.get("pellets", 1)) > 1 else 0.14)
        for _ in range(int(weapon.get("pellets", 1))):
            ang = self.aim + (random.random() * 2 - 1) * float(weapon.get("spread", 0))
            direction = (math.cos(ang), math.sin(ang))
            speed = float(weapon.get("speed", 20))
            life = float(weapon["rng"]) / max(0.1, speed)
            pos = vadd(self.pos, vmul(direction, 0.4))
            self.bullets.append(Bullet(pos, vmul(direction, speed), float(weapon["dmg"]), life))
        left = self.inv.get(ammo, 0)
        if left == 0:
            self.toast_msg(f"{weapon['label']}: sin balas.")
        elif left <= 5:
            self.toast_msg(f"{weapon['label']}: {left} balas.")

    def _melee(self) -> None:
        weapon = self.weapon()
        firearm = bool(weapon.get("firearm"))
        dmg = max(12.0, math.floor(float(weapon["dmg"]) * 0.28)) if firearm else float(weapon["dmg"])
        mrange = 1.2 if firearm else float(weapon["rng"])
        self.atk_cd = 0.4 if firearm else float(weapon["cd"])
        self.swing_t = 0.22
        self.stamina = max(0.0, self.stamina - (8 if firearm else float(weapon["stam"])))
        self.noise = max(self.noise, 1.6 if firearm else 2.2)
        hit = False
        direction = (math.cos(self.aim), math.sin(self.aim))
        for zombie in list(self.zombies):
            to = (zombie.pos[0] - self.pos[0], zombie.pos[1] - self.pos[1])
            dist = vlen(to)
            if dist > mrange or dist < 0.01:
                continue
            if (to[0] / dist) * direction[0] + (to[1] / dist) * direction[1] < 0.15:
                continue
            if zombie.hit(dmg, vmul(direction, 40)):
                self.kills += 1
                self.zombies.remove(zombie)
                self.fx.append(Burst(zombie.pos, (200, 40, 40)))
            hit = True
            self.shake = max(self.shake, 0.14)
        self.toast_msg(("Culatazo." if firearm else "Golpeas.") if hit else "Cortas el aire.")

    def _interact(self) -> None:
        self.interact_cd = 0.35
        if self.world.tile_at(*self.pos) == WATER or self.world.tile_at(self.pos[0] + 0.6, self.pos[1]) == WATER:
            self.thirst = min(100.0, self.thirst + 20)
            self.toast_msg("Bebes del canal. Sabe a óxido.")
            return
        furniture = self.world.nearest_furniture(self.pos)
        if furniture:
            self.interact_cd = 0.55
            self.noise = max(self.noise, 1.4)
            result = self.world.search_container(furniture["key"])
            if result.get("already"):
                self.toast_msg(f"{result['label']}: ya registrado.")
                return
            if result.get("empty"):
                self.toast_msg(f"Registras {str(result.get('label', 'mueble')).lower()}… vacío.")
                return
            if not self.try_take(result["id"], int(result.get("amount", 1))):
                self.toast_msg("Inventario lleno. Equipa mochila (T).")
                return
            label = ITEMS.get(result["id"], {}).get("label", result["id"])
            self.toast_msg(f"En {result['label'].lower()}: {label}.")
            return
        floor_item = self.world.take_floor_loot(self.pos)
        if floor_item:
            if not self.try_take(floor_item["id"], int(floor_item.get("amount", 1))):
                self.toast_msg("Inventario lleno.")
                return
            self.toast_msg(f"Saqueas {ITEMS.get(floor_item['id'], {}).get('label', floor_item['id'])}.")
            self.noise = max(self.noise, 1.2)
            return
        self.toast_msg("Nada cerca. E saquea · T equipo · Q melee")

    def _consume(self) -> None:
        self.interact_cd = 0.4
        if self.inv.get("med", 0) > 0 and self.hp < self.max_hp - 5:
            self._spend("med")
            self.hp = min(self.max_hp, self.hp + 55)
            self.toast_msg("Usas un botiquín.")
            return
        if self.inv.get("food", 0) > 0 and self.hunger < 92:
            self._spend("food")
            self.hunger = min(100.0, self.hunger + 34)
            self.toast_msg("Comes una lata fría.")
            return
        if self.inv.get("water", 0) > 0 and self.thirst < 92:
            self._spend("water")
            self.thirst = min(100.0, self.thirst + 40)
            self.toast_msg("Bebe agua embotellada.")
            return
        self.toast_msg("Nada útil que consumir.")

    def _cycle_gear(self) -> None:
        if self.gear_phase == "clothes":
            self._cycle_list("body", CLOTHES, "bag")
        elif self.gear_phase == "bag":
            self._cycle_list("bag", BAGS, "light")
        else:
            self._cycle_list("light", LIGHTS, "clothes")

    def _cycle_list(self, slot: str, ids: List[str], next_phase: str) -> None:
        owned = [item_id for item_id in ids if self.inv.get(item_id, 0) > 0]
        if not owned:
            self.gear_phase = next_phase
            self.toast_msg(f"Sin {slot}.")
            return
        current = self.equip[slot]
        if current is None or current not in owned:
            self.equip[slot] = owned[0]
            self.toast_msg(f"Equipas {ITEMS[owned[0]]['label']}.")
            return
        idx = owned.index(current)
        if idx < len(owned) - 1:
            self.equip[slot] = owned[idx + 1]
            self.toast_msg(f"Equipas {ITEMS[owned[idx + 1]]['label']}.")
            return
        previous = self.equip[slot]
        self.equip[slot] = None
        if self.inv_used() > self.inv_cap():
            self.equip[slot] = previous
            self.toast_msg("Demasiada carga.")
            self.gear_phase = next_phase
            return
        self.toast_msg("Guardas el equipo.")
        self.gear_phase = next_phase

    def _cycle_build(self) -> None:
        cycle = ["", "wall", "door", "claim"]
        idx = cycle.index(self.build_mode) if self.build_mode in cycle else 0
        self.build_mode = cycle[(idx + 1) % len(cycle)]
        messages = {
            "": "Construcción cancelada.",
            "wall": "Modo barricada — Enter.",
            "door": "Modo puerta — Enter.",
            "claim": "Modo base — Enter.",
        }
        self.toast_msg(messages[self.build_mode])

    def _build(self) -> None:
        self.interact_cd = 0.45
        mode = self.build_mode
        cost = {"scrap": 1, "wood": 1} if mode == "claim" else {"scrap": 2, "wood": 1}
        for item_id, amount in cost.items():
            if self.inv.get(item_id, 0) < amount:
                self.toast_msg("Falta material.")
                return
        direction = (math.cos(self.aim), math.sin(self.aim))
        if mode == "claim":
            bx, by = int(self.pos[0]), int(self.pos[1])
        else:
            bx = int(self.pos[0] + direction[0] * 1.15)
            by = int(self.pos[1] + direction[1] * 1.15)
        current = self.world.tile_at(bx + 0.5, by + 0.5)
        if mode == "claim":
            if current in (WALL, WATER, VOID):
                self.toast_msg("Suelo no usable.")
                return
            for item_id, amount in cost.items():
                self._spend(item_id, amount)
            self.world.set_tile(bx, by, BASE)
            self.toast_msg("Base marcada.")
        else:
            if current in (WALL, WATER, DOOR):
                self.toast_msg("No puedes construir ahí.")
                return
            for item_id, amount in cost.items():
                self._spend(item_id, amount)
            if mode == "door":
                self.world.set_tile(bx, by, DOOR)
                self.world.doors[(bx, by)] = 55.0
            else:
                self.world.set_tile(bx, by, BARRICADE)
            self.toast_msg("Colocado.")
            self.noise = max(self.noise, 2.0)

    def take_damage(self, amount: float) -> None:
        mult = 1.0
        body = self.equip.get("body")
        if body:
            mult = float(ITEMS.get(body, {}).get("bite", 1.0))
        self.hp -= amount * mult
        self.hurt_flash = 0.4
        self.shake = max(self.shake, 0.35)
        self.toast_msg("¡Un zombie te muerde!")

    def _die(self, reason: str) -> None:
        if self.dead:
            return
        self.dead = True
        self.hp = 0
        self.death_reason = reason
        self.shake = max(self.shake, 0.9)

    def _seed_zombies(self, count: int) -> None:
        tries = 0
        while len(self.zombies) < count and tries < count * 40:
            tries += 1
            pos = (
                2 + random.random() * (self.world.size - 4),
                2 + random.random() * (self.world.size - 4),
            )
            if not self.world.can_walk(*pos):
                continue
            if math.hypot(pos[0] - self.world.spawn[0], pos[1] - self.world.spawn[1]) < 12:
                continue
            self.zombies.append(Zombie(pos, 0))

    def _update_zombies(self, dt: float) -> None:
        phase = self.day_phase()
        for zombie in list(self.zombies):
            zombie.stun = max(0.0, zombie.stun - dt)
            zombie.flash = max(0.0, zombie.flash - dt)
            zombie.atk_cd = max(0.0, zombie.atk_cd - dt)
            if zombie.stun > 0:
                continue
            aggro = (11 if phase["night"] else 7) + (6 if self.noise > 0 else 0)
            to = (self.pos[0] - zombie.pos[0], self.pos[1] - zombie.pos[1])
            dist = vlen(to)
            if dist < aggro:
                speed = zombie.speed * (1.28 if phase["night"] else 1.0)
                direction = vnorm(to)
                nx = zombie.pos[0] + direction[0] * speed * dt
                ny = zombie.pos[1] + direction[1] * speed * dt
                if self.world.can_walk(nx, zombie.pos[1]):
                    zombie.pos = (nx, zombie.pos[1])
                if self.world.can_walk(zombie.pos[0], ny):
                    zombie.pos = (zombie.pos[0], ny)
            if dist < 0.58 and zombie.atk_cd <= 0:
                self.take_damage(zombie.dmg)
                zombie.atk_cd = 0.95

    def _update_bullets(self, dt: float) -> None:
        alive: List[Bullet] = []
        for bullet in self.bullets:
            bullet.life -= dt
            if bullet.life <= 0:
                continue
            travel = vmul(bullet.vel, dt)
            dist = vlen(travel)
            steps = max(1, int(math.ceil(dist / 0.18)))
            hit = False
            for step in range(1, steps + 1):
                nxt = vadd(bullet.pos, vmul(travel, step / steps))
                if not self.world.can_walk(*nxt, bullet=True):
                    hit = True
                    break
                for zombie in list(self.zombies):
                    if math.hypot(zombie.pos[0] - nxt[0], zombie.pos[1] - nxt[1]) < 0.55:
                        if zombie.hit(bullet.dmg, vnorm(bullet.vel)):
                            self.kills += 1
                            self.zombies.remove(zombie)
                            self.fx.append(Burst(zombie.pos, (200, 40, 40)))
                        hit = True
                        break
                if hit:
                    break
            else:
                bullet.pos = vadd(bullet.pos, travel)
            if not hit:
                alive.append(bullet)
        self.bullets = alive

    def _update_waves(self, dt: float) -> None:
        phase = self.day_phase()
        if self.wave_phase == "countdown":
            self.wave_timer -= dt
            if self.wave_timer <= 0:
                self.wave += 1
                self.wave_quota = min(42, 5 + self.wave * 3 + (2 if phase["night"] else 0))
                self.wave_spawned = 0
                self.wave_phase = "spawning"
                self.toast_msg(f"Oleada {self.wave}: llegan {self.wave_quota} zombis.")
                self.show_banner(f"OLEADA {self.wave}")
        elif self.wave_phase == "spawning":
            rate = 2.6 + self.wave * 0.18
            if self.wave_spawned < self.wave_quota and random.random() < dt * rate:
                if self._spawn_wave_zombie():
                    self.wave_spawned += 1
            if self.wave_spawned >= self.wave_quota:
                self.wave_phase = "fighting"
        elif self.wave_phase == "fighting":
            if not self.zombies:
                self.wave_phase = "clear"
                self.wave_timer = 1.2
                self.toast_msg(f"Oleada {self.wave} limpia.")
                self.show_banner(f"OLEADA {self.wave} LIMPIA")
        elif self.wave_phase == "clear":
            self.wave_timer -= dt
            if self.wave_timer <= 0:
                self.wave_phase = "countdown"
                self.wave_timer = max(10.0, 20.0 - self.wave * 0.4)
                self.toast_msg(f"Siguiente oleada en {math.ceil(self.wave_timer)}s.")

    def _spawn_wave_zombie(self) -> bool:
        for _ in range(20):
            ang = random.random() * math.tau
            dist = 12 + random.random() * 16
            pos = (self.pos[0] + math.cos(ang) * dist, self.pos[1] + math.sin(ang) * dist)
            if not self.world.can_walk(*pos):
                continue
            self.zombies.append(Zombie(pos, self.wave))
            return True
        return False

    def _tick_weather(self, dt: float) -> None:
        self.weather_next -= dt
        if self.weather == "storm" and self.thunder <= 0 and random.random() < dt * 0.35:
            self.thunder = 0.18 + random.random() * 0.22
        target = {"clear": 0.0, "cloudy": 0.25, "rain": 0.7, "storm": 1.0}.get(self.weather, 0.0)
        self.weather_i += (target - self.weather_i) * min(1.0, dt * 1.4)
        if self.weather_next > 0:
            return
        self.weather_next = 18 + random.random() * 28
        night = ((self.time_of_day % DAY_LEN) / DAY_LEN) >= 0.6
        roll = random.random()
        if self.weather == "clear":
            nxt = "cloudy" if roll < (0.7 if night else 0.5) else "clear"
        elif self.weather == "cloudy":
            nxt = "rain" if roll < (0.55 if night else 0.35) else ("cloudy" if roll < 0.75 else "clear")
        elif self.weather == "rain":
            nxt = "storm" if roll < (0.55 if night else 0.3) else ("rain" if roll < 0.7 else "cloudy")
        else:
            nxt = "rain" if roll < 0.45 else "cloudy"
        self.weather = nxt
        self.weather_label = {
            "clear": "Despejado", "cloudy": "Nublado", "rain": "Lluvia", "storm": "Tormenta",
        }[nxt]
        if nxt == "storm":
            self.toast_msg("La tormenta cae sobre Niebla Norte.")
        elif nxt == "rain":
            self.toast_msg("Empieza a llover sobre el asfalto.")
