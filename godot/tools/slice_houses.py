#!/usr/bin/env python3
"""Slice HOUSE PACK sheet into individual location PNGs."""
from __future__ import annotations

import json
import os
from PIL import Image

SHEET = "/workspace/godot/assets/locations/houses_sheet.jpg"
OUT = "/workspace/godot/assets/locations/houses"
META = "/workspace/godot/data/locations.json"

LEFT, TOP = 205, 30
CELL_W, CELL_H = 110, 200
COLS, ROWS = 10, 5


def punch_checkerboard(cell: Image.Image) -> Image.Image:
	rgba = cell.convert("RGBA")
	px = rgba.load()
	w, h = rgba.size

	def near_check(r: int, g: int, b: int) -> bool:
		avg = (r + g + b) / 3.0
		return avg > 185 and max(r, g, b) - min(r, g, b) < 22

	visited = [[False] * h for _ in range(w)]
	stack: list[tuple[int, int]] = []
	for x in range(w):
		stack.append((x, 0))
		stack.append((x, h - 1))
	for y in range(h):
		stack.append((0, y))
		stack.append((w - 1, y))
	while stack:
		x, y = stack.pop()
		if not (0 <= x < w and 0 <= y < h) or visited[x][y]:
			continue
		visited[x][y] = True
		r, g, b, _a = px[x, y]
		if not near_check(r, g, b):
			continue
		px[x, y] = (0, 0, 0, 0)
		stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
	bb = rgba.split()[-1].getbbox()
	return rgba.crop(bb) if bb else rgba


def main() -> None:
	os.makedirs(OUT, exist_ok=True)
	for name in os.listdir(OUT):
		os.remove(os.path.join(OUT, name))

	sheet = Image.open(SHEET).convert("RGB")
	meta: list[dict] = []

	for r in range(ROWS):
		for c in range(COLS):
			idx = r * COLS + c + 1
			x0 = LEFT + c * CELL_W + 2
			y0 = TOP + r * CELL_H + 2
			x1 = LEFT + (c + 1) * CELL_W - 2
			y1 = TOP + (r + 1) * CELL_H - 2
			cell = punch_checkerboard(sheet.crop((x0, y0, x1, y1)))
			# Upscale for crisp UI
			scale = 2
			cell = cell.resize((cell.width * scale, cell.height * scale), Image.Resampling.LANCZOS)
			fname = "house_%02d.png" % idx
			path = os.path.join(OUT, fname)
			cell.save(path)
			meta.append(
				{
					"id": "house_%02d" % idx,
					"index": idx,
					"path": "res://assets/locations/houses/%s" % fname,
					"name": "Inmueble %02d" % idx,
				}
			)
			print("saved", fname, cell.size)

	with open(META, "w", encoding="utf-8") as f:
		json.dump({"houses": meta}, f, indent=2)
	print("done", len(meta))


if __name__ == "__main__":
	main()
