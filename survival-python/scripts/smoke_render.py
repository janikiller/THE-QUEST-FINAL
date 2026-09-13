#!/usr/bin/env python3
"""Smoke render Niebla Norte under xvfb."""
from __future__ import annotations

import pygame

from main import HALF_H, HALF_W, W, H, draw_hud, draw_vignette, draw_world
from niebla.constants import TILE
from niebla.game import Game


def main() -> None:
    pygame.init()
    screen = pygame.display.set_mode((W, H))
    font = pygame.font.SysFont("dejavusans", 18)
    font_sm = pygame.font.SysFont("dejavusans", 14)
    font_lg = pygame.font.SysFont("dejavusans", 36, bold=True)
    fonts = (font, font_sm, font_lg)
    g = Game(seed=42)

    class Pressed:
        def __init__(self) -> None:
            self.keys: set[int] = set()

        def __getitem__(self, k: int) -> bool:
            return k in self.keys

    pressed = Pressed()
    pressed.keys.add(pygame.K_d)

    for i in range(120):
        dt = 1 / 60
        cam_x = g.pos[0] * TILE - HALF_W
        cam_y = g.pos[1] * TILE - HALF_H
        aim = (g.pos[0] + 1.5, g.pos[1])
        just: set[int] = set()
        click = False
        if i == 20:
            just.add(pygame.K_q)
        if i == 40:
            just.add(pygame.K_1)
        if 45 <= i <= 80:
            click = True
        if i == 90:
            just.add(pygame.K_e)
        g.update(dt, pressed, aim, click, just)
        screen.fill((18, 20, 18))
        draw_world(screen, g, cam_x, cam_y, fonts)
        draw_vignette(screen, g)
        draw_hud(screen, g, fonts)
        brand = font_lg.render("CRESPO", True, (200, 210, 180))
        screen.blit(brand, (16, H - 70))
        sub = font_sm.render("Niebla Norte", True, (140, 150, 130))
        screen.blit(sub, (18, H - 40))
        pygame.display.flip()

    out = "/opt/cursor/artifacts/niebla-norte-gameplay.png"
    pygame.image.save(screen, out)
    print("saved", out)
    print("kills", g.kills, "pos", g.pos, "hp", g.hp, "wave", g.wave_text())
    pygame.quit()


if __name__ == "__main__":
    main()
