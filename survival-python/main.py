#!/usr/bin/env python3
"""CRESPO · Niebla Norte — cliente pygame."""

from __future__ import annotations

import math
import sys

import pygame

from niebla.constants import (
    ALLEY,
    BARRICADE,
    BASE,
    COLORS,
    CROSSWALK,
    DAY_LEN,
    DOOR,
    FLOOR,
    ITEMS,
    MAP,
    MAX_HP,
    PARK,
    PARKING,
    ROAD,
    RUBBLE,
    SIDEWALK,
    TILE,
    WALL,
    WATER,
    WIN,
)
from niebla.game import Game

W, H = WIN
HALF_W, HALF_H = W // 2, H // 2


def draw_world(surf: pygame.Surface, g: Game, cam_x: float, cam_y: float, fonts) -> None:
    font_sm = fonts[1]
    tiles = g.world.tiles
    tx0 = max(0, int(cam_x // TILE) - 1)
    ty0 = max(0, int(cam_y // TILE) - 1)
    tx1 = min(MAP, int((cam_x + W) // TILE) + 2)
    ty1 = min(MAP, int((cam_y + H) // TILE) + 2)

    for y in range(ty0, ty1):
        for x in range(tx0, tx1):
            t = tiles[y][x]
            col = COLORS.get(t, (40, 40, 40))
            sx = int(x * TILE - cam_x)
            sy = int(y * TILE - cam_y)
            pygame.draw.rect(surf, col, (sx, sy, TILE, TILE))
            if t == ROAD:
                pygame.draw.line(
                    surf, (70, 72, 68),
                    (sx + 4, sy + TILE // 2), (sx + TILE - 4, sy + TILE // 2), 1,
                )
            elif t == SIDEWALK:
                pygame.draw.rect(surf, (58, 60, 56), (sx + 2, sy + 2, TILE - 4, TILE - 4), 1)
            elif t == CROSSWALK:
                for i in range(3):
                    pygame.draw.line(
                        surf, (140, 140, 120),
                        (sx + 8 + i * 12, sy + 6), (sx + 8 + i * 12, sy + TILE - 6), 2,
                    )
            elif t == WALL:
                pygame.draw.rect(surf, (28, 30, 28), (sx + 3, sy + 3, TILE - 6, TILE - 6))
            elif t == DOOR:
                pygame.draw.rect(surf, (90, 70, 40), (sx + 8, sy + 4, TILE - 16, TILE - 8))
            elif t == WATER:
                pygame.draw.circle(surf, (50, 90, 120), (sx + TILE // 2, sy + TILE // 2), 6, 1)
            elif t in (PARK, PARKING, ALLEY, RUBBLE):
                pygame.draw.line(surf, (40, 90, 48), (sx + 10, sy + 20), (sx + 14, sy + 12), 1)
            elif t == FLOOR:
                pygame.draw.rect(surf, (48, 40, 34), (sx + 1, sy + 1, TILE - 2, TILE - 2), 1)
            elif t == BASE:
                pygame.draw.rect(surf, (90, 140, 80), (sx + 6, sy + 6, TILE - 12, TILE - 12), 2)
            elif t == BARRICADE:
                pygame.draw.rect(surf, (140, 100, 50), (sx + 6, sy + 10, TILE - 12, TILE - 20))

    for lx, ly in g.world.lamps:
        sx = int(lx * TILE + TILE // 2 - cam_x)
        sy = int(ly * TILE + TILE // 2 - cam_y)
        if -20 < sx < W + 20 and -20 < sy < H + 20:
            pygame.draw.circle(surf, (220, 200, 120), (sx, sy), 4)

    for (fx, fy), data in g.world.furniture.items():
        sx = int(fx * TILE + TILE // 2 - cam_x)
        sy = int(fy * TILE + TILE // 2 - cam_y)
        ft = data.get("type", "")
        color = {
            "locker": (90, 100, 110), "fridge": (100, 110, 120),
            "desk": (100, 80, 50), "shelf": (120, 90, 50),
        }.get(ft, (70, 55, 40))
        pygame.draw.rect(surf, color, (sx - 10, sy - 10, 20, 20))
        mark = data.get("label", "?")[:1]
        surf.blit(font_sm.render(mark, True, (230, 230, 220)), (sx - 4, sy - 6))

    for (lx, ly), item in g.world.loot.items():
        sx = int(lx * TILE + TILE // 2 - cam_x)
        sy = int(ly * TILE + TILE // 2 - cam_y)
        pygame.draw.circle(surf, (200, 180, 80), (sx, sy), 5)
        name = ITEMS.get(item.get("id", ""), {}).get("label", "?")[:6]
        surf.blit(font_sm.render(name, True, (240, 220, 140)), (sx + 6, sy - 6))

    for z in g.zombies:
        sx = int(z.pos[0] * TILE - cam_x)
        sy = int(z.pos[1] * TILE - cam_y)
        shade = (160, 50, 50) if z.flash > 0 else (110, 45, 45)
        pygame.draw.circle(surf, shade, (sx, sy), 12)
        pygame.draw.circle(surf, (40, 10, 10), (sx, sy), 12, 2)

    for b in g.bullets:
        sx = int(b.pos[0] * TILE - cam_x)
        sy = int(b.pos[1] * TILE - cam_y)
        pygame.draw.circle(surf, (240, 220, 120), (sx, sy), 3)

    px = int(g.pos[0] * TILE - cam_x)
    py = int(g.pos[1] * TILE - cam_y)
    pygame.draw.circle(surf, (70, 140, 200), (px, py), 11)
    pygame.draw.circle(surf, (30, 60, 90), (px, py), 11, 2)
    ax = px + math.cos(g.aim) * 18
    ay = py + math.sin(g.aim) * 18
    pygame.draw.line(surf, (220, 230, 240), (px, py), (ax, ay), 3)

    if g.swing_t > 0:
        pygame.draw.arc(
            surf, (200, 200, 180),
            (px - 28, py - 28, 56, 56),
            g.aim - 1.0, g.aim + 1.0, 2,
        )
    if g.muzzle > 0:
        pygame.draw.circle(surf, (255, 220, 120), (int(ax), int(ay)), 6)

    for f in g.fx:
        sx = int(f.pos[0] * TILE - cam_x)
        sy = int(f.pos[1] * TILE - cam_y)
        alpha = max(40, int(255 * (f.t / 0.35)))
        pygame.draw.circle(surf, f.color, (sx, sy), 8)


def draw_hud(surf: pygame.Surface, g: Game, fonts) -> None:
    font, font_sm, font_lg = fonts

    def bar(x, y, w, h, ratio, col, label):
        pygame.draw.rect(surf, (20, 22, 20), (x, y, w, h), border_radius=3)
        pygame.draw.rect(surf, col, (x, y, max(0, int(w * max(0.0, min(1.0, ratio)))), h), border_radius=3)
        surf.blit(font_sm.render(label, True, (220, 220, 210)), (x, y - 14))

    bar(16, 28, 180, 10, g.hp / MAX_HP, (180, 60, 60), f"VIDA {int(g.hp)}")
    bar(16, 56, 180, 8, g.stamina / 100, (70, 140, 90), "STAMINA")
    bar(16, 80, 180, 8, g.hunger / 100, (180, 140, 60), "HAMBRE")
    bar(16, 104, 180, 8, g.thirst / 100, (60, 120, 180), "SED")

    phase = g.day_phase()
    clock = f"Día {int(g.time_of_day // DAY_LEN) + 1} · {phase['name']} · {g.weather_label}"
    surf.blit(font.render(clock, True, (230, 230, 220)), (W - 320, 16))
    surf.blit(font_sm.render(g.wave_text(), True, (200, 180, 140)), (W - 320, 40))
    kills = font_sm.render(f"Bajas {g.kills}", True, (180, 160, 140))
    surf.blit(kills, (W - 320, 58))

    hb = g.hotbar()
    bx = W // 2 - (len(hb) * 54) // 2
    for i, slot in enumerate(hb):
        rect = pygame.Rect(bx + i * 54, H - 64, 48, 48)
        active = slot.get("active")
        pygame.draw.rect(surf, (70, 90, 50) if active else (40, 42, 38), rect, border_radius=4)
        pygame.draw.rect(
            surf, (180, 200, 120) if active else (90, 90, 80), rect, 2, border_radius=4,
        )
        if slot.get("empty"):
            surf.blit(font_sm.render(str(i + 1), True, (120, 120, 110)), (rect.x + 18, rect.y + 16))
        else:
            label = str(slot.get("label", "?"))[:7]
            surf.blit(font_sm.render(f"{i + 1} {label}", True, (230, 230, 220)), (rect.x + 4, rect.y + 14))
            if slot.get("ammo") is not None:
                surf.blit(font_sm.render(str(slot["ammo"]), True, (200, 200, 100)), (rect.x + 4, rect.y + 30))

    inv = f"Inv {g.inv_used():.0f}/{g.inv_cap():.0f}"
    surf.blit(font_sm.render(inv, True, (200, 200, 190)), (16, H - 28))
    if g.build_mode:
        modes = {"wall": "barricada", "door": "puerta", "claim": "base"}
        msg = f"MODO {modes.get(g.build_mode, g.build_mode).upper()} · Enter confirma · Esc cancela"
        surf.blit(font.render(msg, True, (160, 200, 120)), (W // 2 - 220, H - 96))

    if g.banner_t > 0 and g.banner:
        t = font_lg.render(g.banner, True, (240, 230, 180))
        surf.blit(t, (W // 2 - t.get_width() // 2, 80))
    if g.toast_t > 0 and g.toast:
        t = font.render(g.toast, True, (220, 220, 200))
        surf.blit(t, (W // 2 - t.get_width() // 2, H - 120))

    if g.dead:
        overlay = pygame.Surface((W, H), pygame.SRCALPHA)
        overlay.fill((10, 8, 8, 180))
        surf.blit(overlay, (0, 0))
        msg = font_lg.render("HAS CAÍDO", True, (220, 80, 70))
        surf.blit(msg, (W // 2 - msg.get_width() // 2, H // 2 - 40))
        reason = font.render(g.death_reason or "", True, (200, 180, 160))
        surf.blit(reason, (W // 2 - reason.get_width() // 2, H // 2 + 10))
        hint = font_sm.render("R · reiniciar", True, (180, 180, 170))
        surf.blit(hint, (W // 2 - hint.get_width() // 2, H // 2 + 44))


def draw_vignette(surf: pygame.Surface, g: Game) -> None:
    phase = g.day_phase()
    night = 0.0 if not phase["night"] else max(0.0, 1.0 - float(phase["light"]))
    if g.weather in ("fog", "rain", "storm"):
        night = max(night, 0.15 + 0.2 * g.weather_i)
    if night <= 0.05 and g.hurt_flash <= 0:
        return
    overlay = pygame.Surface((W, H), pygame.SRCALPHA)
    overlay.fill((8, 10, 18, int(150 * night)))
    if g.hurt_flash > 0:
        overlay.fill((120, 20, 20, int(90 * min(1.0, g.hurt_flash * 3))))
    surf.blit(overlay, (0, 0))


def main() -> int:
    pygame.init()
    pygame.display.set_caption("CRESPO · Niebla Norte")
    screen = pygame.display.set_mode((W, H))
    clock = pygame.time.Clock()
    font = pygame.font.SysFont("dejavusans", 18)
    font_sm = pygame.font.SysFont("dejavusans", 14)
    font_lg = pygame.font.SysFont("dejavusans", 36, bold=True)
    fonts = (font, font_sm, font_lg)

    seed = 42
    if len(sys.argv) > 1:
        try:
            seed = int(sys.argv[1])
        except ValueError:
            pass
    game = Game(seed=seed)
    mouse = (W // 2, H // 2)
    mouse_held = False

    running = True
    while running:
        dt = min(0.05, clock.tick(60) / 1000.0)
        keys = pygame.key.get_pressed()
        just: set[int] = set()
        mouse_click = False

        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                running = False
            elif ev.type == pygame.KEYDOWN:
                if ev.key == pygame.K_ESCAPE and not game.build_mode:
                    running = False
                else:
                    just.add(ev.key)
                    if game.dead and ev.key == pygame.K_r:
                        game = Game(seed=seed)
                        mouse_held = False
            elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                mouse_held = True
                mouse_click = True
            elif ev.type == pygame.MOUSEBUTTONUP and ev.button == 1:
                mouse_held = False
            elif ev.type == pygame.MOUSEMOTION:
                mouse = ev.pos

        cam_x = game.pos[0] * TILE - HALF_W
        cam_y = game.pos[1] * TILE - HALF_H
        if game.shake > 0:
            cam_x += math.sin(pygame.time.get_ticks() * 0.05) * game.shake * 6
            cam_y += math.cos(pygame.time.get_ticks() * 0.07) * game.shake * 6

        world_mx = (mouse[0] + cam_x) / TILE
        world_my = (mouse[1] + cam_y) / TILE
        click = mouse_click or mouse_held
        game.update(dt, keys, (world_mx, world_my), click, just)

        screen.fill((18, 20, 18))
        draw_world(screen, game, cam_x, cam_y, fonts)
        draw_vignette(screen, game)
        draw_hud(screen, game, fonts)

        brand = font_lg.render("CRESPO", True, (200, 210, 180))
        screen.blit(brand, (16, H - 70))
        sub = font_sm.render("Niebla Norte", True, (140, 150, 130))
        screen.blit(sub, (18, H - 40))

        pygame.display.flip()

    pygame.quit()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
