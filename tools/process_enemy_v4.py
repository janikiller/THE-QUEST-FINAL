#!/usr/bin/env python3
"""Aggressive pink chroma cleanup + normalize enemy sprites to shared canvas."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter, ImageOps

ART = Path("/opt/cursor/artifacts/assets")
FOE_DST = Path("/workspace/godot/assets/combat/anime/foes")
BOSS_DST = Path("/workspace/godot/assets/combat/anime/bosses")
CANVAS = (640, 1120)
FOOT_PAD = 16
TOP_PAD = 20


def chroma_strength(r: int, g: int, b: int) -> float:
    """0 keep .. 1 fully transparent. Broad magenta/pink key."""
    # Classic hot magenta
    if r >= 170 and b >= 140 and g <= 145 and (r - g) >= 35 and (b - g) >= 15:
        return 1.0
    if r >= 200 and b >= 160 and g <= 170 and r >= g:
        return 1.0
    # Hot pink / fuchsia
    if r >= 210 and g <= 120 and b >= 130:
        return 1.0
    # Speckled pink-black noise: high R+B relative to G
    mag = (r + b) * 0.5 - g
    if mag >= 55 and r >= 140 and b >= 100 and g <= 160:
        return min(1.0, 0.55 + (mag - 55) / 80.0)
    # Near-white pink haze
    if r >= 220 and g >= 120 and g <= 200 and b >= 180 and (r - g) >= 25:
        return 0.85
    # Green key
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
    # Flood from borders: any near-pink contiguous with edge → kill
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
        # Also treat very bright/dark pinkish edge pixels as bg
        if t >= 0.35 or (r > 180 and b > 140 and g < 170 and a < 230):
            px[x, y] = (0, 0, 0, 0)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                stack.append((x + dx, y + dy))
    # Edge fringe cleanup: if pixel has transparent neighbor and is pinkish, kill
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


def estimate_facing_right(im: Image.Image) -> bool:
    a = im.split()[-1]
    w, h = im.size
    left = right = 0
    for y in range(int(h * 0.12), int(h * 0.55)):
        for x in range(w):
            v = a.getpixel((x, y))
            if v < 40:
                continue
            if x < w * 0.42:
                left += v
            elif x > w * 0.58:
                right += v
    return right > left * 1.28


# Manual overrides when heuristic fails
FORCE_FLIP = {
	# none currently — heuristic + chroma pass handle most
}
FORCE_NO_FLIP = {
	"foe_13_acrobat",
	"foe_01_hoodie",
	"foe_02_knives",
	"foe_10_crowbar",
	"boss_01_capo",
	"boss_05_titan",
}


def normalize(im: Image.Image, name: str) -> Image.Image:
	im = crop_content(im)
	flip = False
	if name in FORCE_NO_FLIP:
		flip = False
	elif name in FORCE_FLIP:
		flip = True
	else:
		flip = estimate_facing_right(im)
	if flip:
		im = ImageOps.mirror(im)
		print(f"  flip {name}")
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


def pink_pct(im: Image.Image) -> float:
    px = im.load()
    w, h = im.size
    pink = op = 0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            r, g, b, a = px[x, y]
            if a < 20:
                continue
            op += 1
            if chroma_strength(r, g, b) >= 0.5:
                pink += 1
    return 100.0 * pink / max(1, op)


def process_one(src: Path, dst: Path, name: str) -> Image.Image:
    im = Image.open(src)
    im = remove_chroma(im)
    im = normalize(im, name)
    # Second pass on canvas edges
    im = remove_chroma(im)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst, optimize=True)
    print(f"OK {src.name} -> {dst.name} pink%={pink_pct(im):.1f}")
    return im


def main() -> None:
    foes = [
        "foe_01_hoodie", "foe_02_knives", "foe_03_bat", "foe_04_skate", "foe_05_biker",
        "foe_06_hacker", "foe_07_revolver", "foe_08_pickpocket", "foe_09_hooligan", "foe_10_crowbar",
        "foe_11_dealer", "foe_12_sniper", "foe_13_acrobat", "foe_14_medic", "foe_15_clown",
        "foe_16_handler", "foe_17_courier", "foe_18_molotov", "foe_19_boxer", "foe_20_assassin",
    ]
    for name in foes:
        src = ART / f"{name}_v4.png"
        if not src.exists():
            print("MISSING", src)
            continue
        process_one(src, FOE_DST / f"{name}.png", name)

    bosses = [
        "boss_01_capo", "boss_02_viuda", "boss_03_fantasma", "boss_04_veneno", "boss_05_titan",
        "boss_06_sombra", "boss_07_rey_puerto", "boss_08_zero", "boss_09_fuego", "boss_10_coronel",
    ]
    for name in bosses:
        src = ART / f"{name}_v4.png"
        if not src.exists():
            print("MISSING", src)
            continue
        idle = process_one(src, BOSS_DST / f"{name}.png", name)
        make_attack(idle).save(BOSS_DST / f"{name}_attack.png", optimize=True)
        make_hurt(idle).save(BOSS_DST / f"{name}_hurt.png", optimize=True)


if __name__ == "__main__":
    main()
