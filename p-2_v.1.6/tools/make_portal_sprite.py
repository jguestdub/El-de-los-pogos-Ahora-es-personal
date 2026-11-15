#!/usr/bin/env python3
"""Convierte la imagen de portal (8 remolinos sobre fondo azul oscuro, 4x2) en una
hoja de sprites con transparencia: assets/effects/portal.png (8 frames de 128x128).

Uso: python3 tools/make_portal_sprite.py ruta/a/portal.jpg   (requiere Pillow y numpy)
"""
import os
import sys

import numpy as np
from PIL import Image

COLS, ROWS, FRAME = 4, 2, 128
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "effects", "portal.png")


def main(src):
    im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
    h, w, _ = im.shape
    corners = np.concatenate([im[:40, :40].reshape(-1, 3), im[:40, -40:].reshape(-1, 3),
                              im[-40:, :40].reshape(-1, 3), im[-40:, -40:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    # alpha = cuánto se aleja el pixel del fondo; el color se des-premultiplica.
    diff = im - bg
    a = np.clip(diff.max(axis=2) / 95.0, 0.0, 1.0) ** 0.85
    safe = np.maximum(a, 1e-3)[..., None]
    rgb = np.clip((im - bg * (1.0 - a[..., None])) / safe, 0, 255)
    rgba = np.dstack([rgb, a * 255.0]).astype(np.uint8)

    cw, ch = w // COLS, h // ROWS
    cells, boxes = [], []
    for r in range(ROWS):
        for c in range(COLS):
            cell = Image.fromarray(rgba[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw], "RGBA")
            bb = Image.fromarray(rgba[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw, 3]).point(lambda v: 255 if v > 24 else 0).getbbox()
            cells.append(cell)
            boxes.append(bb)
    side = max(max(b[2] - b[0], b[3] - b[1]) for b in boxes)
    side = int(side * 1.08)
    sheet = Image.new("RGBA", (FRAME * len(cells), FRAME), (0, 0, 0, 0))
    for i, (cell, bb) in enumerate(zip(cells, boxes)):
        cx, cy = (bb[0] + bb[2]) // 2, (bb[1] + bb[3]) // 2
        crop = cell.crop((cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2))
        sheet.paste(crop.resize((FRAME, FRAME), Image.LANCZOS), (i * FRAME, 0))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    print("ok", sheet.size)


if __name__ == "__main__":
    main(sys.argv[1])
