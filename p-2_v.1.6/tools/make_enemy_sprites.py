#!/usr/bin/env python3
"""Genera las hojas de sprites del diablillo para cada zona (recolor por zona).

Entrada : assets/enemies/devil_run_right.png y devil_run_left.png (6 frames de 48x48)
Salida  : assets/enemies/zone{1..8}_{right,left}.png

Uso: python3 tools/make_enemy_sprites.py   (requiere Pillow)
"""
import colorsys
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "enemies")

# (nombre, tono cuerpo, sat cuerpo x, brillo cuerpo x, tono cuernos, sat cuernos x, brillo cuernos x)
# Tonos en grados. Zona 1 = el diablillo original (sin cambios).
STYLES = [
    ("pradera",  None, 1.0, 1.0, None, 1.0, 1.0),
    ("bosque",   120, 0.85, 0.85, 35, 0.9, 0.75),    # verde musgo, cuernos de madera
    ("cavernas", 275, 0.80, 0.80, 195, 0.35, 0.95),  # violeta, cuernos de cristal
    ("hielo",    195, 0.70, 1.35, 190, 0.10, 1.20),  # azul glaciar, cuernos blancos
    ("ruinas",    38, 0.60, 0.95, 48, 0.25, 1.05),   # arena, cuernos de hueso
    ("volcan",    10, 0.30, 0.45, 50, 1.00, 1.10),   # carbon, cuernos de lava
    ("cielo",    205, 0.30, 1.40, 48, 0.85, 1.10),   # blanco-celeste, cuernos dorados
    ("cima",      48, 0.85, 1.05, 350, 0.90, 0.95),  # dorado, cuernos carmesi
]


def recolor(im, style):
    _, bh, bs, bv, hh, hs, hv = style
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s < 0.25:          # negro / blanco (ojos, dientes, contorno): se conserva
                continue
            deg = h * 360
            is_body = deg < 14 or deg > 340
            if is_body:
                nh, ns, nv = bh, bs, bv
            else:
                nh, ns, nv = hh, hs, hv
            if nh is None and ns == 1.0 and nv == 1.0:
                continue
            h2 = h if nh is None else (nh % 360) / 360
            s2 = min(1.0, s * ns)
            v2 = min(1.0, v * nv)
            r2, g2, b2 = colorsys.hsv_to_rgb(h2, s2, v2)
            px[x, y] = (round(r2 * 255), round(g2 * 255), round(b2 * 255), a)
    return out


def main():
    for side in ("right", "left"):
        src = Image.open(os.path.join(ROOT, f"devil_run_{side}.png")).convert("RGBA")
        for i, style in enumerate(STYLES):
            recolor(src, style).save(os.path.join(ROOT, f"zone{i + 1}_{side}.png"))
    print("ok")


if __name__ == "__main__":
    main()
