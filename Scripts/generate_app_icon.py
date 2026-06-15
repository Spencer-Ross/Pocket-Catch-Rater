#!/usr/bin/env python3
"""Generate Pocket Catch Rater app icon — green Pokéball mid-capture shake."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT_DIR = Path(__file__).resolve().parents[1] / "Pocket Catch Rater/Assets.xcassets/AppIcon.appiconset"

# Green Pokéball (classic shape, green top)
GREEN = (48, 168, 72)
GREEN_HI = (110, 220, 130)
GREEN_SH = (22, 110, 42)
WHITE = (248, 248, 252)
WHITE_SH = (205, 210, 218)
BAND = (18, 18, 22)
BUTTON = (245, 245, 250)


def radial_bg() -> Image.Image:
    img = Image.new("RGB", (SIZE, SIZE), (10, 28, 18))
    px = img.load()
    cx, cy = SIZE / 2, SIZE / 2
    for y in range(SIZE):
        for x in range(SIZE):
            t = min(1.0, math.hypot(x - cx, y - cy) / (SIZE * 0.65))
            t = t**1.35
            r = int(18 * (1 - t) + 6 * t)
            g = int(52 * (1 - t) + 14 * t)
            b = int(38 * (1 - t) + 12 * t)
            px[x, y] = (r, g, b)
    return img


def shaded_sphere_layer(radius: int) -> Image.Image:
    """Full Pokéball on a square canvas, centered."""
    d = radius * 2 + 8
    img = Image.new("RGBA", (d, d), (0, 0, 0, 0))
    px = img.load()
    cx = cy = d / 2
    rx = ry = radius
    band_h = radius * 0.17
    lx, ly, lz = -0.5, -0.62, 0.55
    ln = math.sqrt(lx * lx + ly * ly + lz * lz)
    lx, ly, lz = lx / ln, ly / ln, lz / ln

    for y in range(d):
        for x in range(d):
            nx = (x - cx) / rx
            ny = (y - cy) / ry
            dist = nx * nx + ny * ny
            if dist > 1.0:
                continue

            nz = math.sqrt(max(0.0, 1.0 - dist))
            dot = max(0.0, nx * lx + ny * ly + nz * lz)
            shade = 0.32 + 0.58 * dot

            # Top green / bottom white split at equator
            if y < cy - band_h * 0.55:
                base, hi = GREEN, GREEN_HI
                shade *= 0.95 + dot * 0.08
            elif y > cy + band_h * 0.55:
                base, hi = WHITE, (255, 255, 255)
                shade = 0.26 + 0.52 * dot
            else:
                px[x, y] = (*BAND, 255)
                continue

            r = int(base[0] * shade + hi[0] * dot * 0.28)
            g = int(base[1] * shade + hi[1] * dot * 0.28)
            b = int(base[2] * shade + hi[2] * dot * 0.28)
            px[x, y] = (min(255, r), min(255, g), min(255, b), 255)

    draw = ImageDraw.Draw(img)
    # Center band overlay for crisp seam
    draw.rounded_rectangle(
        (cx - rx, cy - band_h / 2, cx + rx, cy + band_h / 2),
        radius=int(band_h * 0.1),
        fill=(*BAND, 255),
    )
    br = radius * 0.13
    draw.ellipse((cx - br * 1.3, cy - br * 1.3, cx + br * 1.3, cy + br * 1.3), fill=(*WHITE, 255))
    draw.ellipse((cx - br, cy - br, cx + br, cy + br), fill=(*BUTTON, 255))
    draw.ellipse((cx - br * 0.5, cy - br * 0.5, cx + br * 0.42, cy + br * 0.42), fill=(255, 255, 255, 210))

    # Specular highlight on green dome
    draw.ellipse(
        (cx - rx * 0.55, cy - rx * 0.72, cx - rx * 0.05, cy - rx * 0.22),
        fill=(170, 240, 185, 90),
    )

    return img


def rotate_layer(layer: Image.Image, degrees: float) -> Image.Image:
    return layer.rotate(degrees, resample=Image.Resampling.BICUBIC, expand=True)


def paste_centered(base: Image.Image, layer: Image.Image, cx: float, cy: float, alpha: float = 1.0) -> None:
    if alpha < 1.0:
        layer = layer.copy()
        r, g, b, a = layer.split()
        a = a.point(lambda v: int(v * alpha))
        layer = Image.merge("RGBA", (r, g, b, a))
    x = int(cx - layer.width / 2)
    y = int(cy - layer.height / 2)
    base.alpha_composite(layer, (x, y))


def draw_shake_arcs(draw: ImageDraw.ImageDraw, cx: float, cy: float, radius: float, tilt: float) -> None:
    """Curved motion streaks like the in-game capture wobble."""
    rad = math.radians(tilt)
    for sign in (-1, 1):
        ox = cx + sign * radius * 0.22
        oy = cy - radius * 0.02
        for i, (sw, alpha, spread) in enumerate(((14, 200, 0.62), (10, 130, 0.78), (6, 70, 0.92))):
            arc_r = radius * spread
            start = 210 + sign * 12 + i * sign * 5
            end = 330 - sign * 12 - i * sign * 5
            bbox = (ox - arc_r, oy - arc_r * 0.5, ox + arc_r, oy + arc_r * 0.5)
            draw.arc(bbox, start=start, end=end, fill=(160, 240, 175, alpha), width=sw)

    gx = cx + math.sin(rad) * radius * 0.08
    tick_y = cy + radius * 0.93
    for tx, direction in ((gx - radius * 0.5, -1), (gx + radius * 0.5, 1)):
        draw.line(
            [(tx, tick_y), (tx + direction * 22, tick_y)],
            fill=(130, 210, 145, 100),
            width=6,
        )


def draw_stars(draw: ImageDraw.ImageDraw, cx: float, cy: float, radius: float) -> None:
    """Small sparkle stars — capture moment energy."""
    for sx, sy, sz in (
        (cx - radius * 0.75, cy - radius * 0.55, 10),
        (cx + radius * 0.8, cy - radius * 0.35, 8),
        (cx + radius * 0.65, cy + radius * 0.7, 7),
        (cx - radius * 0.7, cy + radius * 0.55, 9),
    ):
        draw.ellipse((sx - sz, sy - sz, sx + sz, sy + sz), fill=(190, 255, 200, 140))
        draw.line([(sx - sz * 1.8, sy), (sx + sz * 1.8, sy)], fill=(190, 255, 200, 110), width=3)
        draw.line([(sx, sy - sz * 1.8), (sx, sy + sz * 1.8)], fill=(190, 255, 200, 110), width=3)


def render(variant: str = "default") -> Image.Image:
    base = radial_bg().convert("RGBA")
    draw = ImageDraw.Draw(base)

    cx, cy = SIZE / 2, SIZE / 2 + 20
    radius = 290
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(5, 0, -1):
        r = radius + i * 36
        gd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(60, 180, 90, 18 * i))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=22))
    base.alpha_composite(glow)

    ball = shaded_sphere_layer(radius)
    shake_tilt = 16

    # Ground shadow (before ball)
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sx = cx + math.sin(math.radians(shake_tilt)) * 18
    sd.ellipse(
        (sx - radius * 0.72, cy + radius * 0.78, sx + radius * 0.72, cy + radius * 0.98),
        fill=(0, 0, 0, 75),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=12))
    base.alpha_composite(shadow)

    # Shake afterimages — left ghost (previous wobble position)
    ghost_left = rotate_layer(ball, -14)
    paste_centered(base, ghost_left, cx - 28, cy + 6, alpha=0.22)

    # Shake afterimage — right faint (next wobble position)
    ghost_right = rotate_layer(ball, 22)
    paste_centered(base, ghost_right, cx + 32, cy - 4, alpha=0.14)

    # Main ball — current shake frame
    main = rotate_layer(ball, shake_tilt)
    paste_centered(base, main, cx, cy)

    draw_shake_arcs(draw, cx, cy, radius, shake_tilt)
    draw_stars(draw, cx, cy, radius)

    if variant == "dark":
        base = Image.alpha_composite(base, Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 65)))
    elif variant == "tinted":
        base = Image.alpha_composite(base, Image.new("RGBA", (SIZE, SIZE), (120, 220, 140, 40)))

    return base.convert("RGB")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for filename, variant in {
        "AppIcon.png": "default",
        "AppIcon-Dark.png": "dark",
        "AppIcon-Tinted.png": "tinted",
    }.items():
        render(variant).save(OUT_DIR / filename, format="PNG", optimize=True)
        print(f"Wrote {OUT_DIR / filename}")


if __name__ == "__main__":
    main()
