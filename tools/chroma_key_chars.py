#!/usr/bin/env python3
"""Chroma-key hot magenta / green to alpha, crop, and normalize character sprites."""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageFilter


def is_chroma(r: int, g: int, b: int) -> bool:
    # Hot magenta / fuchsia key
    if r >= 180 and b >= 180 and g <= 120 and (r + b) - 2 * g >= 160:
        return True
    # Bright green key fallback
    if g >= 200 and r <= 90 and b <= 90:
        return True
    # Near-pure magenta
    if r >= 200 and b >= 200 and g <= 80:
        return True
    return False


def soft_chroma(r: int, g: int, b: int) -> float:
    """0 = keep, 1 = fully transparent."""
    if is_chroma(r, g, b):
        return 1.0
    # Soft fringe near magenta
    mag = (r + b) / 2.0 - g
    if mag > 90 and r > 140 and b > 140 and g < 150:
        return min(1.0, (mag - 90) / 90.0)
    return 0.0


def process(src: Path, dst: Path) -> None:
    im = Image.open(src).convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            t = soft_chroma(r, g, b)
            if t >= 0.98:
                px[x, y] = (0, 0, 0, 0)
            elif t > 0.05:
                px[x, y] = (r, g, b, int(a * (1.0 - t)))

    # Crop to opaque content with padding
    alpha = im.split()[-1]
    bbox = alpha.getbbox()
    if bbox:
        pad = 12
        x0 = max(0, bbox[0] - pad)
        y0 = max(0, bbox[1] - pad)
        x1 = min(w, bbox[2] + pad)
        y1 = min(h, bbox[3] + pad)
        im = im.crop((x0, y0, x1, y1))

    # Light edge cleanup: remove isolated chroma fringe
    im = im.filter(ImageFilter.SMOOTH_MORE) if False else im
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst)
    print(f"OK {src.name} -> {dst} {im.size}")


def main() -> None:
    pairs = []
    if len(sys.argv) >= 3 and Path(sys.argv[1]).is_file():
        process(Path(sys.argv[1]), Path(sys.argv[2]))
        return
    # Batch map from artifacts
    root = Path("/opt/cursor/artifacts/assets")
    mapping = {
        "garcia_v3_idle.png": Path("/workspace/godot/assets/combat/anime/hero/idle.png"),
        "garcia_v3_shoot.png": Path("/workspace/godot/assets/combat/anime/hero/shoot.png"),
        "garcia_v3_hurt.png": Path("/workspace/godot/assets/combat/anime/hero/hurt.png"),
    }
    for i in range(1, 21):
        # match generated names
        pass
    for src_name, dst in mapping.items():
        src = root / src_name
        if src.exists():
            process(src, dst)
    # foes
    foe_map = {
        "foe_01_hoodie_v3.png": "foe_01_hoodie.png",
        "foe_02_knives_v3.png": "foe_02_knives.png",
        "foe_03_bat_v3.png": "foe_03_bat.png",
        "foe_04_skate_v3.png": "foe_04_skate.png",
        "foe_05_biker_v3.png": "foe_05_biker.png",
        "foe_06_hacker_v3.png": "foe_06_hacker.png",
        "foe_07_revolver_v3.png": "foe_07_revolver.png",
        "foe_08_pickpocket_v3.png": "foe_08_pickpocket.png",
        "foe_09_hooligan_v3.png": "foe_09_hooligan.png",
        "foe_10_crowbar_v3.png": "foe_10_crowbar.png",
        "foe_11_dealer_v3.png": "foe_11_dealer.png",
        "foe_12_sniper_v3.png": "foe_12_sniper.png",
        "foe_13_acrobat_v3.png": "foe_13_acrobat.png",
        "foe_14_medic_v3.png": "foe_14_medic.png",
        "foe_15_clown_v3.png": "foe_15_clown.png",
        "foe_16_handler_v3.png": "foe_16_handler.png",
        "foe_17_courier_v3.png": "foe_17_courier.png",
        "foe_18_molotov_v3.png": "foe_18_molotov.png",
        "foe_19_boxer_v3.png": "foe_19_boxer.png",
        "foe_20_assassin_v3.png": "foe_20_assassin.png",
    }
    foe_dir = Path("/workspace/godot/assets/combat/anime/foes")
    for src_name, dst_name in foe_map.items():
        src = root / src_name
        if src.exists():
            process(src, foe_dir / dst_name)


if __name__ == "__main__":
    main()
