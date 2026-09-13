#!/usr/bin/env python3
"""Render frames + short demo video."""
from __future__ import annotations

import math
import os
import subprocess

import pygame

from main import HALF_H, HALF_W, W, H, draw_hud, draw_vignette, draw_world
from niebla.constants import TILE
from niebla.game import Game, Zombie


def main() -> None:
    out_dir = "/opt/cursor/artifacts"
    frames = os.path.join(out_dir, "frames")
    os.makedirs(frames, exist_ok=True)

    pygame.init()
    screen = pygame.display.set_mode((W, H))
    font = pygame.font.SysFont("dejavusans", 18)
    font_sm = pygame.font.SysFont("dejavusans", 14)
    font_lg = pygame.font.SysFont("dejavusans", 36, bold=True)
    fonts = (font, font_sm, font_lg)
    g = Game(seed=42)
    # Place zombies near player for visible combat
    g.zombies = [
        Zombie((g.pos[0] + 2.2, g.pos[1]), 1),
        Zombie((g.pos[0] + 3.5, g.pos[1] - 1.0), 1),
        Zombie((g.pos[0] - 2.8, g.pos[1] + 0.8), 0),
    ]

    class Pressed:
        def __init__(self) -> None:
            self.keys: set[int] = set()

        def __getitem__(self, k: int) -> bool:
            return k in self.keys

    pressed = Pressed()
    n_frames = 180
    for i in range(n_frames):
        dt = 1 / 30
        # aim at first zombie if any
        if g.zombies:
            target = g.zombies[0].pos
        else:
            target = (g.pos[0] + math.cos(g.aim), g.pos[1] + math.sin(g.aim))
        just: set[int] = set()
        click = False
        if i < 40:
            pressed.keys.add(pygame.K_d)
        else:
            pressed.keys.discard(pygame.K_d)
        if i == 10:
            just.add(pygame.K_1)
        if 20 <= i <= 90:
            click = True
        if i in (100, 110, 120):
            just.add(pygame.K_q)
        if i == 130:
            just.add(pygame.K_e)
        g.update(dt, pressed, target, click, just)

        cam_x = g.pos[0] * TILE - HALF_W
        cam_y = g.pos[1] * TILE - HALF_H
        screen.fill((18, 20, 18))
        draw_world(screen, g, cam_x, cam_y, fonts)
        draw_vignette(screen, g)
        draw_hud(screen, g, fonts)
        brand = font_lg.render("CRESPO", True, (200, 210, 180))
        screen.blit(brand, (16, H - 70))
        sub = font_sm.render("Niebla Norte", True, (140, 150, 130))
        screen.blit(sub, (18, H - 40))
        pygame.display.flip()
        pygame.image.save(screen, os.path.join(frames, f"f{i:04d}.png"))
        if i == 60:
            pygame.image.save(screen, os.path.join(out_dir, "niebla-norte-combat.png"))

    pygame.quit()
    video = os.path.join(out_dir, "niebla-norte-demo.mp4")
    subprocess.check_call([
        "ffmpeg", "-y", "-framerate", "30",
        "-i", os.path.join(frames, "f%04d.png"),
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "23",
        video,
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print("video", video)
    print("combat png", os.path.join(out_dir, "niebla-norte-combat.png"))
    print("kills", g.kills, "zombies_left", len(g.zombies), "hp", round(g.hp, 1))


if __name__ == "__main__":
    main()
