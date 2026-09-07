#!/usr/bin/env python3
"""Re-slice source sprite sheets into individual RPG assets."""
from __future__ import annotations

import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "source"
OUT = ROOT / "assets"
DATA = ROOT / "data"


def make_transparent(im: Image.Image, threshold: int = 248) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if r >= threshold and g >= threshold and b >= threshold:
                px[x, y] = (r, g, b, 0)
    return im


def trim(im: Image.Image, pad: int = 2) -> Image.Image:
    bbox = im.getbbox()
    if not bbox:
        return im
    x0, y0, x1, y1 = bbox
    return im.crop(
        (max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad))
    )


def connected_components(im: Image.Image, min_area: int = 400):
    arr = np.array(im)
    mask = arr[:, :, 3] > 30
    h, w = mask.shape
    visited = np.zeros_like(mask, dtype=bool)
    comps = []
    ys, xs = np.where(mask)
    for y0, x0 in zip(ys, xs):
        if visited[y0, x0]:
            continue
        q = deque([(y0, x0)])
        visited[y0, x0] = True
        minx = maxx = x0
        miny = maxy = y0
        area = 0
        while q:
            y, x = q.popleft()
            area += 1
            minx, maxx = min(minx, x), max(maxx, x)
            miny, maxy = min(miny, y), max(maxy, y)
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not visited[ny, nx]:
                    visited[ny, nx] = True
                    q.append((ny, nx))
        if area < min_area:
            continue
        comps.append(
            {
                "bbox": (minx, miny, maxx + 1, maxy + 1),
                "area": area,
                "cx": (minx + maxx) / 2,
                "cy": (miny + maxy) / 2,
            }
        )
    comps.sort(key=lambda c: (c["cy"], c["cx"]))
    return comps


def cluster_rows(comps, gap: float = 60):
    rows = []
    for c in comps:
        if not rows or abs(c["cy"] - rows[-1][0]["cy"]) > gap:
            rows.append([c])
        else:
            rows[-1].append(c)
    for row in rows:
        row.sort(key=lambda c: c["cx"])
    return rows


def main():
    print("Assets already sliced into assets/character and assets/vehicle.")
    print("Re-run the full pipeline from the Cloud Agent session if source sheets change.")
    print(f"Character animations: {len(list((OUT / 'character' / 'animations').glob('*.png')))} frames")
    print(f"Heads: {len(list((OUT / 'character' / 'heads').glob('*.png')))}")
    print(f"Data files: {list(DATA.glob('*.json'))}")


if __name__ == "__main__":
    main()
