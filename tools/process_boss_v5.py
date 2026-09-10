#!/usr/bin/env python3
"""Process unique boss v5 GenerateImage assets into game idle/attack/hurt."""
from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image, ImageEnhance

ART = Path("/opt/cursor/artifacts/assets")
BOSS_DST = Path("/workspace/godot/assets/combat/anime/bosses")
CANVAS = (640, 1120)
FOOT_PAD = 16
TOP_PAD = 20

BOSSES = [
	"boss_01_capo",
	"boss_02_viuda",
	"boss_03_fantasma",
	"boss_04_veneno",
	"boss_05_titan",
	"boss_06_sombra",
	"boss_07_rey_puerto",
	"boss_08_zero",
	"boss_09_fuego",
	"boss_10_coronel",
]


def chroma_strength(r: int, g: int, b: int) -> float:
	if r >= 170 and b >= 140 and g <= 145 and (r - g) >= 35 and (b - g) >= 15:
		return 1.0
	if r >= 200 and b >= 160 and g <= 170 and r >= g:
		return 1.0
	if r >= 210 and g <= 120 and b >= 130:
		return 1.0
	mag = (r + b) * 0.5 - g
	if mag >= 55 and r >= 140 and b >= 100 and g <= 160:
		return min(1.0, 0.55 + (mag - 55) / 80.0)
	if r >= 220 and g >= 120 and g <= 200 and b >= 180 and (r - g) >= 25:
		return 0.85
	if g >= 200 and r <= 90 and b <= 90:
		return 1.0
	return 0.0


def remove_chroma(im: Image.Image) -> Image.Image:
	im = im.convert("RGBA")
	px = im.load()
	w, h = im.size
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a == 0:
				continue
			t = chroma_strength(r, g, b)
			if t >= 0.92:
				px[x, y] = (0, 0, 0, 0)
			elif t > 0.15:
				px[x, y] = (r, g, b, max(0, int(a * (1.0 - t))))
	visited = set()
	stack: list[tuple[int, int]] = []
	for x in range(w):
		stack.append((x, 0))
		stack.append((x, h - 1))
	for y in range(h):
		stack.append((0, y))
		stack.append((w - 1, y))
	while stack:
		x, y = stack.pop()
		if not (0 <= x < w and 0 <= y < h) or (x, y) in visited:
			continue
		visited.add((x, y))
		r, g, b, a = px[x, y]
		if a < 12:
			px[x, y] = (0, 0, 0, 0)
			for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				stack.append((x + dx, y + dy))
			continue
		t = chroma_strength(r, g, b)
		if t >= 0.35 or (r > 180 and b > 140 and g < 170 and a < 230):
			px[x, y] = (0, 0, 0, 0)
			for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				stack.append((x + dx, y + dy))
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			r, g, b, a = px[x, y]
			if a < 20:
				continue
			near_t = False
			for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1)):
				if px[x + dx, y + dy][3] < 15:
					near_t = True
					break
			if not near_t:
				continue
			t = chroma_strength(r, g, b)
			if t > 0.2 or ((r + b) * 0.5 - g) > 40:
				px[x, y] = (0, 0, 0, 0)
	return im


def crop_content(im: Image.Image, pad: int = 6) -> Image.Image:
	bbox = im.split()[-1].getbbox()
	if not bbox:
		return im
	x0 = max(0, bbox[0] - pad)
	y0 = max(0, bbox[1] - pad)
	x1 = min(im.width, bbox[2] + pad)
	y1 = min(im.height, bbox[3] + pad)
	return im.crop((x0, y0, x1, y1))


def normalize(im: Image.Image) -> Image.Image:
	im = crop_content(im)
	cw, ch = CANVAS
	max_w = cw - 36
	max_h = ch - FOOT_PAD - TOP_PAD
	scale = min(max_w / im.width, max_h / im.height)
	nw = max(1, int(im.width * scale))
	nh = max(1, int(im.height * scale))
	im = im.resize((nw, nh), Image.Resampling.LANCZOS)
	canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
	x = (cw - nw) // 2
	y = ch - FOOT_PAD - nh
	canvas.paste(im, (x, y), im)
	return canvas


def make_attack(im: Image.Image) -> Image.Image:
	out = Image.new("RGBA", im.size, (0, 0, 0, 0))
	out.paste(im, (-20, 4), im)
	return ImageEnhance.Contrast(out).enhance(1.08)


def make_hurt(im: Image.Image) -> Image.Image:
	out = Image.new("RGBA", im.size, (0, 0, 0, 0))
	out.paste(im, (12, 8), im)
	r, g, b, a = out.split()
	r = r.point(lambda v: min(255, int(v * 1.22 + 18)))
	g = g.point(lambda v: int(v * 0.72))
	b = b.point(lambda v: int(v * 0.72))
	return Image.merge("RGBA", (r, g, b, a))


def main() -> None:
	BOSS_DST.mkdir(parents=True, exist_ok=True)
	for name in BOSSES:
		src = ART / f"{name}_v5.png"
		if not src.exists():
			raise SystemExit(f"MISSING {src}")
		im = remove_chroma(Image.open(src))
		im = normalize(im)
		im = remove_chroma(im)
		idle_path = BOSS_DST / f"{name}.png"
		im.save(idle_path, optimize=True)
		make_attack(im).save(BOSS_DST / f"{name}_attack.png", optimize=True)
		make_hurt(im).save(BOSS_DST / f"{name}_hurt.png", optimize=True)
		digest = hashlib.md5(idle_path.read_bytes()).hexdigest()[:10]
		print(f"OK {name} md5={digest} bytes={idle_path.stat().st_size}")


if __name__ == "__main__":
	main()
