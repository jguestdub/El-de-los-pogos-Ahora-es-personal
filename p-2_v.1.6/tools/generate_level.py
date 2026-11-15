#!/usr/bin/env python3
"""
Generador del nivel del juego de pogo.

Escribe:
  scenes/level.tscn          el nivel completo (plataformas, paredes, fondo, meta)
  scripts/level_info.gd      constantes del nivel (ancho, zonas, posiciones)
  assets/generated/tile_*.png texturas de las plataformas
  tools/recipes.json         un salto "de referencia" por cada plataforma (lo usa el bot de pruebas)

Cada plataforma de la ruta principal se coloca simulando la MISMA física del
jugador (gravedad, fuerza de salto, inclinación máxima, colisiones con las
demás piezas). Solo se acepta una plataforma si hay una ventana razonable de
(carga, ángulo) que aterriza en ella, así que el nivel siempre se puede pasar.

Uso:   python3 tools/generate_level.py [semilla]
"""
import json
import math
import os
import random
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEED = int(sys.argv[1]) if len(sys.argv) > 1 else 2026

# ---------------------------------------------------------------- física (igual que player.gd)
G = 1500.0
DT = 1.0 / 60.0
FMIN, FMAX = 300.0, 1250.0
MAXA = math.radians(80.0)
HW, HH = 13.0, 30.0            # mitades del cuerpo del jugador
PX_PER_M = 32.0

W = 2000.0                     # ancho del nivel
NF, NA = 24, 41                # rejilla de (fuerza, ángulo) para simular
T_STEPS = 260


class Solid:
    __slots__ = ("id", "x0", "y0", "x1", "y1", "kind", "surface", "zone")

    def __init__(self, id, x0, y0, x1, y1, kind="platform", surface="normal", zone=0):
        self.id, self.kind, self.surface, self.zone = id, kind, surface, zone
        self.x0, self.y0, self.x1, self.y1 = x0, y0, x1, y1

    @property
    def cx(self):
        return (self.x0 + self.x1) / 2

    @property
    def w(self):
        return self.x1 - self.x0


# ---------------------------------------------------------------- zonas
ZONES = [
    dict(name="PRADERA", theme="grass", h=4800, w=(280, 440), th=(28, 36), rise=(80, 160), dx=480,
         ice=0.0, thr=70, overhang=0.0, pillar=0.0, inset=None, ledges=0.55),
    dict(name="BOSQUE", theme="forest", h=4800, w=(190, 340), th=(28, 36), rise=(110, 200), dx=560,
         ice=0.0, thr=50, overhang=0.0, pillar=0.0, inset=None, ledges=0.5),
    dict(name="CAVERNAS", theme="cave", h=4800, w=(170, 300), th=(30, 40), rise=(110, 210), dx=480,
         ice=0.0, thr=40, overhang=0.45, pillar=0.0, inset=(320, 640, 650), ledges=0.4),
    dict(name="HIELO", theme="ice", h=4800, w=(170, 300), th=(28, 36), rise=(100, 200), dx=560,
         ice=0.85, thr=36, overhang=0.15, pillar=0.0, inset=None, ledges=0.45),
    dict(name="RUINAS", theme="ruins", h=4800, w=(120, 240), th=(28, 36), rise=(140, 240), dx=620,
         ice=0.0, thr=28, overhang=0.25, pillar=0.45, inset=None, ledges=0.4),
    dict(name="VOLCAN", theme="volcano", h=4800, w=(110, 210), th=(30, 40), rise=(150, 260), dx=600,
         ice=0.0, thr=22, overhang=0.3, pillar=0.25, inset=(220, 560, 600), ledges=0.35),
    dict(name="CIELO", theme="sky", h=4800, w=(90, 180), th=(26, 32), rise=(150, 260), dx=700,
         ice=0.15, thr=16, overhang=0.0, pillar=0.0, inset=None, ledges=0.4),
    dict(name="CIMA", theme="summit", h=4800, w=(80, 150), th=(26, 32), rise=(170, 280), dx=720,
         ice=0.4, thr=12, overhang=0.2, pillar=0.15, inset=None, ledges=0.3),
]

THEME = {
    # bg: color del fondo en el centro de la zona; tex: textura; tint: tinte del cuerpo;
    # top: color del borde superior; wall: tinte de las paredes
    "grass":   dict(bg=(0.50, 0.76, 0.95), tex="dirt",  tint=(0.72, 0.50, 0.34), top=(0.30, 0.65, 0.28), wall=(0.45, 0.40, 0.36)),
    "forest":  dict(bg=(0.15, 0.33, 0.27), tex="dirt",  tint=(0.55, 0.38, 0.26), top=(0.22, 0.52, 0.24), wall=(0.30, 0.26, 0.22)),
    "cave":    dict(bg=(0.07, 0.07, 0.12), tex="stone", tint=(0.55, 0.55, 0.65), top=(0.42, 0.42, 0.55), wall=(0.30, 0.30, 0.40)),
    "ice":     dict(bg=(0.55, 0.75, 0.90), tex="stone", tint=(0.70, 0.88, 1.00), top=(0.90, 0.97, 1.00), wall=(0.50, 0.70, 0.88)),
    "ruins":   dict(bg=(0.50, 0.43, 0.38), tex="brick", tint=(0.80, 0.72, 0.58), top=(0.62, 0.55, 0.42), wall=(0.55, 0.48, 0.40)),
    "volcano": dict(bg=(0.22, 0.06, 0.06), tex="stone", tint=(0.42, 0.25, 0.25), top=(0.85, 0.35, 0.12), wall=(0.30, 0.18, 0.18)),
    "sky":     dict(bg=(0.33, 0.58, 0.90), tex="cloud", tint=(1.00, 1.00, 1.00), top=(0.93, 0.97, 1.00), wall=(0.85, 0.92, 1.00)),
    "summit":  dict(bg=(0.04, 0.04, 0.12), tex="stone", tint=(0.55, 0.50, 0.75), top=(0.95, 0.85, 0.40), wall=(0.30, 0.28, 0.50)),
}
ICE_BODY_TINT = (0.62, 0.84, 1.00)
ICE_TOP = (0.88, 0.97, 1.00)

rng = random.Random(SEED)
hop_cache = {}
solids: list[Solid] = []
counter = {"p": 0}


def rnd(a, b):
    return rng.uniform(a, b)


def new_id(prefix):
    counter["p"] += 1
    return f"{prefix}{counter['p']:03d}"


# ---------------------------------------------------------------- simulación de alcance
def simulate(src: Solid, near, xs):
    """Devuelve, por cada x de salida, una matriz [NF,NA] con el índice (en `near`)
    de la pieza donde se aterriza, -1 si no aterriza (choca de lado / techo / se pasa)."""
    Fs = np.linspace(FMIN, FMAX, NF)
    As = np.linspace(-MAXA, MAXA, NA)
    FF, AA = np.meshgrid(Fs, As, indexing="ij")
    vx0 = FF * np.sin(AA)
    vy0 = -FF * np.cos(AA)
    out = []
    for x in xs:
        cx = np.full(FF.shape, float(x))
        cy = np.full(FF.shape, src.y0 - HH)
        vx = vx0.copy()
        vy = vy0.copy()
        res = np.full(FF.shape, -2, dtype=np.int32)      # -2 = en vuelo
        for _ in range(T_STEPS):
            act = res == -2
            if not act.any():
                break
            vy = vy + G * DT
            ncx = cx + vx * DT
            ncy = cy + vy * DT
            blocked = np.zeros(FF.shape, dtype=bool)
            land_idx = np.full(FF.shape, -1, dtype=np.int32)
            for si, s in enumerate(near):
                ov = act & (ncx + HW > s.x0) & (ncx - HW < s.x1) & (ncy + HH > s.y0) & (ncy - HH < s.y1)
                if not ov.any():
                    continue
                land = ov & (vy > 0) & (cy + HH <= s.y0 + 1e-6)
                blocked |= ov & ~land
                land_idx = np.where(land & (land_idx < 0), si, land_idx)
            landed = act & ~blocked & (land_idx >= 0)
            res[landed] = land_idx[landed]
            res[act & blocked] = -1
            cx, cy = ncx, ncy
        res[res == -2] = -1
        out.append(res)
    return out


def start_xs(src: Solid):
    if src.kind == "ground":
        return list(np.linspace(300.0, W - 300.0, 5))
    lo, hi = src.x0 + HW + 3, src.x1 - HW - 3
    if hi <= lo:
        return [src.cx]
    if hi - lo < 60:
        return [src.cx]
    return list(np.linspace(lo, hi, 3))


def nearby(src: Solid, pool, extra=()):
    ymin, ymax = src.y0 - 900, src.y0 + 400
    xmin, xmax = src.x0 - 1250, src.x1 + 1250
    res = [s for s in pool if s.y1 > ymin and s.y0 < ymax and s.x1 > xmin and s.x0 < xmax]
    for e in extra:
        if e not in res:
            res.append(e)
    return res


def ways(src: Solid, dst: Solid, pool):
    """(mejor número de celdas que aterrizan en dst, x de salida, matriz de éxito)."""
    near = nearby(src, pool, [dst])
    idx = near.index(dst)
    xs = start_xs(src)
    best = (0, None, None)
    for x, res in zip(xs, simulate(src, near, xs)):
        mask = res == idx
        n = int(mask.sum())
        if n > best[0]:
            best = (n, x, mask)
    return best


def overlaps(a: Solid, pad=0.0, pool=None):
    for s in (pool if pool is not None else solids):
        if a.x0 < s.x1 + pad and a.x1 > s.x0 - pad and a.y0 < s.y1 + pad and a.y1 > s.y0 - pad:
            return True
    return False


# ---------------------------------------------------------------- construcción del nivel
def inset_profile(zone_idx, y_bottom, y_top, cfg):
    """Genera paredes que estrechan el túnel dentro de una zona. Devuelve lista de (y_a, y_b, izq, der)."""
    if not cfg["inset"]:
        return []
    imin, imax, step = cfg["inset"]
    steps = []
    y = y_bottom
    prev_l, prev_r = 0.0, 0.0
    first = True
    while y > y_top:
        y_next = max(y - step * rnd(0.8, 1.2), y_top)
        lo_l = max(imin * 0.0, prev_l - 220)
        if first:
            l, r = 120.0, 120.0
            first = False
        else:
            l = min(max(rnd(imin * 0.5, imax), prev_l - 260), prev_l + 260)
            r = min(max(rnd(imin * 0.5, imax), prev_r - 260), prev_r + 260)
            l, r = max(l, 90.0), max(r, 90.0)
        # el túnel nunca baja de 900 px de ancho
        if W - l - r < 900:
            shrink = (900 - (W - l - r)) / 2
            l -= shrink
            r -= shrink
        steps.append((y, y_next, l, r))
        prev_l, prev_r = l, r
        y = y_next
    return steps


def bounds_at(profile, y0, y1):
    """Límites x libres para una pieza que ocupa de y0 a y1."""
    lo, hi = 0.0, W
    for (ya, yb, l, r) in profile:
        # ya > yb (y crece hacia abajo): el tramo ocupa [yb, ya]
        if y1 > yb and y0 < ya:
            lo, hi = max(lo, l), min(hi, W - r)
    return lo, hi


def pick_surface(cfg):
    return "ice" if rng.random() < cfg["ice"] else "normal"


def build():
    ground = Solid("Ground", -400.0, 0.0, W + 400, 700.0, "ground")
    solids.append(ground)

    zone_info = []
    chain = [ground]
    mark = {}
    backtracks = {"n": 0}
    hops = []          # (src, dst, n_ways, start_x, mask)
    y_cursor = 0.0
    total_h = sum(z["h"] for z in ZONES)
    top_limit = -float(total_h)

    for zi, cfg in enumerate(ZONES):
        y_bottom = y_cursor
        y_top = y_cursor - cfg["h"]
        profile = inset_profile(zi, y_bottom, y_top, cfg)
        zone_info.append(dict(name=cfg["name"], theme=cfg["theme"], y_bottom=y_bottom, y_top=y_top, profile=profile))
        for k, (ya, yb, l, r) in enumerate(profile):
            if l > 0:
                solids.append(Solid(f"WL{zi}_{k}", -400.0, yb, l, ya + 1, "wall", zone=zi))
            if r > 0:
                solids.append(Solid(f"WR{zi}_{k}", W - r, yb, W + 400, ya + 1, "wall", zone=zi))

        is_last_zone = zi == len(ZONES) - 1
        first = True
        while True:
            cur = chain[-1]
            # ¿llegamos al final de la zona?
            if cur.y0 - cfg["rise"][0] < y_top + (60 if not is_last_zone else 200):
                break
            nxt = None
            extra = None
            prev_of_cur = chain[-2] if len(chain) >= 2 else None
            if not first and rng.random() < cfg["overhang"]:
                extra = make_overhang(cur, cfg, profile, zi)
            elif not first and cur.w >= 150 and rng.random() < cfg["pillar"]:
                extra = make_pillar(cur, cfg, profile, zi)
            if extra is not None and len(chain) >= 2:
                # el extra no debe estropear el salto que llegó hasta `cur`
                prev = chain[-2]
                trial = solids + [extra]
                n_prev, _, _ = ways(prev, cur, trial)
                if n_prev < max(10, 0.7 * min(hop_cache.get((prev.id, cur.id), 0), cfg['thr'])):
                    extra = None
            if extra is not None:
                solids.append(extra)
            nxt = find_next(cur, cfg, profile, zi, first, prev=prev_of_cur)
            if nxt is None and extra is not None:
                solids.remove(extra)
                extra = None
                nxt = find_next(cur, cfg, profile, zi, first, force=True, prev=prev_of_cur)
            elif nxt is None:
                nxt = find_next(cur, cfg, profile, zi, first, force=True, prev=prev_of_cur)
            if nxt is None:
                # callejón sin salida: retroceder una plataforma (y lo que colgaba de ella)
                backtracks["n"] += 1
                if first or backtracks["n"] > 600:
                    raise SystemExit(f"generación atascada en la zona {zi}")
                solids[:] = solids[:mark[cur.id]]
                chain.pop()
                if len(chain) > 1 and chain[-1].zone != zi:
                    first = True
                continue
            mark[nxt.id] = solids.index(nxt)
            chain.append(nxt)
            first = False
        y_cursor = y_top

    # plataforma de la cima
    cur = chain[-1]
    summit = None
    for attempt in range(400):
        w = 460.0
        top = cur.y0 - rnd(130, 220) * (1 - attempt / 500)
        cx = min(max(cur.cx + rnd(-300, 300) * (1 - attempt / 400), w / 2 + 60), W - w / 2 - 60)
        cand = Solid("Summit", cx - w / 2, top, cx + w / 2, top + 36, "summit", zone=len(ZONES) - 1)
        if overlaps(cand, 10):
            continue
        n, sx, mask = ways(cur, cand, solids + [cand])
        if n >= 14:
            summit = cand
            solids.append(summit)
            chain.append(summit)
            break
    assert summit is not None, "No se pudo colocar la cima"
    return chain, zone_info, summit


def find_next(cur, cfg, profile, zi, first, force=False, prev=None):
    thr = cfg["thr"]
    attempts = 90 if not force else 400
    base_prev = ways(prev, cur, solids)[0] if prev is not None else 0
    for attempt in range(attempts):
        relax = 1.0 - 0.75 * (attempt / attempts)         # va bajando el umbral
        if force:
            relax = 1.0 - 0.9 * (attempt / attempts)
        if first:
            w, th = rnd(460, 540), rnd(34, 40)
            rise = rnd(110, 170)
        else:
            w, th = rnd(*cfg["w"]), rnd(*cfg["th"])
            rise = rnd(*cfg["rise"])
        shrink = 1.0 if attempt < attempts * 0.6 else 0.6
        rise *= shrink
        dx = rnd(-cfg["dx"], cfg["dx"]) * (1.0 if attempt < attempts * 0.5 else 0.5)
        if first:
            dx = rnd(-cfg["dx"], cfg["dx"]) * (1.0 + 0.6 * attempt / attempts)
        top = cur.y0 - rise
        lo, hi = bounds_at(profile, top, top + th)
        margin = 40
        cx = cur.cx + dx
        cx = min(max(cx, lo + w / 2 + margin), hi - w / 2 - margin)
        if hi - lo < w + 2 * margin:
            continue
        surface = "normal" if first else pick_surface(cfg)
        cand = Solid(new_id("P"), cx - w / 2, top, cx + w / 2, top + th, "platform", surface, zi)
        if overlaps(cand, 28):
            continue
        if not (force and attempt > attempts * 0.8) and not has_headroom(cand):
            continue
        n, sx, mask = ways(cur, cand, solids + [cand])
        if n >= (max(10, thr * relax) if not force else 7):
            if prev is not None:
                # la nueva plataforma tampoco debe tapar el salto que llegó a `cur`
                n_prev, _, _ = ways(prev, cur, solids + [cand])
                if n_prev < max(8, 0.6 * min(base_prev, thr)):
                    continue
            solids.append(cand)
            hop_cache[(cur.id, cand.id)] = n
            return cand
    return None


def has_headroom(p: Solid, h=270.0):
    probe = Solid("probe", p.x0, p.y0 - h, p.x1, p.y0 - 0.5)
    return not overlaps(probe, 0.0)


def make_overhang(cur, cfg, profile, zi):
    for _ in range(12):
        w, th = rnd(180, 340), rnd(34, 46)
        top = cur.y0 - rnd(230, 330) - th
        cx = rnd(cur.x0 - 80, cur.x1 + 80)
        lo, hi = bounds_at(profile, top, top + th)
        cx = min(max(cx, lo + w / 2 + 30), hi - w / 2 - 30)
        cand = Solid(new_id("O"), cx - w / 2, top, cx + w / 2, top + th, "overhang", "normal", zi)
        if not overlaps(cand, 40):
            return cand
    return None


def make_pillar(cur, cfg, profile, zi):
    for _ in range(8):
        w, h = rnd(36, 52), rnd(170, 330)
        side = rng.choice((0, 1))
        x0 = cur.x0 + 6 if side == 0 else cur.x1 - 6 - w
        cand = Solid(new_id("C"), x0, cur.y0 - h, x0 + w, cur.y0, "pillar", "normal", zi)
        lo, hi = bounds_at(profile, cand.y0, cand.y1)
        if cand.x0 < lo + 20 or cand.x1 > hi - 20:
            continue
        # no pisar la plataforma anterior (comparte borde inferior => solapamiento 0)
        probe = Solid("probe", cand.x0, cand.y0, cand.x1, cand.y1 - 2)
        if not overlaps(probe, 6):
            return cand
    return None


def add_ledges(chain, zone_info):
    """Repisas extra (descansos / rutas alternativas) que no empeoran la ruta principal."""
    added = []
    for i, p in enumerate(chain[1:-1], start=1):
        zi = p.zone
        cfg = ZONES[zi]
        if rng.random() > cfg["ledges"]:
            continue
        profile = zone_info[zi]["profile"]
        for _ in range(6):
            w, th = rnd(*cfg["w"]), rnd(*cfg["th"])
            side = rng.choice((-1, 1))
            cx = p.cx + side * rnd(330, 760)
            top = p.y0 + rnd(-120, 160)
            lo, hi = bounds_at(profile, top, top + th)
            cx = min(max(cx, lo + w / 2 + 40), hi - w / 2 - 40)
            cand = Solid(new_id("L"), cx - w / 2, top, cx + w / 2, top + th, "ledge", pick_surface(cfg), zi)
            if overlaps(cand, 60) or not has_headroom(cand, 150.0):
                continue
            # no debe empeorar los saltos cercanos de la ruta principal
            ok = True
            lo_i, hi_i = max(1, i - 2), min(len(chain) - 1, i + 2)
            trial = solids + [cand]
            for j in range(lo_i, hi_i + 1):
                a, b = chain[j - 1], chain[j]
                before = hop_cache.get((a.id, b.id), 0)
                n, _, _ = ways(a, b, trial)
                if n < before * 0.95:
                    ok = False
                    break
            if ok:
                solids.append(cand)
                added.append(cand)
                break
    return added


# ---------------------------------------------------------------- texturas
def make_textures():
    from PIL import Image
    out = os.path.join(ROOT, "assets", "generated")
    r = random.Random(7)

    def save(img, name):
        img.save(os.path.join(out, f"tile_{name}.png"))

    def noise_tile(base, var, pebbles=0, seed=0):
        rr = random.Random(seed)
        im = Image.new("RGB", (32, 32))
        px = im.load()
        for y in range(32):
            for x in range(32):
                v = base + rr.randint(-var, var)
                px[x, y] = (v, v, v)
        for _ in range(pebbles):
            x, y = rr.randint(0, 29), rr.randint(0, 30)
            v = base + rr.choice((-34, 30))
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                px[(x + dx) % 32, (y + dy) % 32] = (v, v, v)
        return im

    save(noise_tile(200, 22, pebbles=7, seed=1), "dirt")
    # piedra con grietas
    im = noise_tile(190, 14, pebbles=3, seed=2)
    px = im.load()
    for x in range(32):
        px[x, 15] = (120, 120, 120)
        px[x, 31] = (120, 120, 120)
    for y in range(0, 16):
        px[10, y] = (130, 130, 130)
    for y in range(16, 32):
        px[24, y] = (130, 130, 130)
    save(im, "stone")
    # ladrillos
    im = noise_tile(215, 10, seed=3)
    px = im.load()
    for row in range(4):
        y0 = row * 8
        for x in range(32):
            px[x, y0] = (130, 130, 130)
        off = 0 if row % 2 == 0 else 8
        for yy in range(y0, y0 + 8):
            px[(off) % 32, yy] = (130, 130, 130)
            px[(off + 16) % 32, yy] = (130, 130, 130)
    save(im, "brick")
    # nube
    im = noise_tile(238, 9, seed=4)
    save(im, "cloud")


# ---------------------------------------------------------------- escritura de la escena
def f(v):
    return f"{v:.1f}".rstrip("0").rstrip(".") if abs(v) >= 1 or v == 0 else f"{v:.2f}"


def col(c, a=1.0):
    return f"Color({c[0]:.3f}, {c[1]:.3f}, {c[2]:.3f}, {a:.3f})"


def vec(points):
    return "PackedVector2Array(" + ", ".join(f"{f(x)}, {f(y)}" for x, y in points) + ")"


def colors(cs):
    return "PackedColorArray(" + ", ".join(f"{c[0]:.3f}, {c[1]:.3f}, {c[2]:.3f}, 1" for c in cs) + ")"


class Scene:
    def __init__(self):
        self.ext = []
        self.sub = {}
        self.lines = []

    def tex(self, name):
        path = f"res://assets/generated/tile_{name}.png"
        for i, (p, _) in enumerate(self.ext):
            if p == path:
                return f"tex_{name}"
        self.ext.append((path, f"tex_{name}"))
        return f"tex_{name}"

    def rect_shape(self, w, h):
        key = (round(w, 1), round(h, 1))
        if key not in self.sub:
            self.sub[key] = f"Rect_{len(self.sub)}"
        return self.sub[key]

    def node(self, name, typ, parent, **props):
        self.lines.append(f'[node name="{name}" type="{typ}" parent="{parent}"]')
        for k, v in props.items():
            self.lines.append(f"{k.replace('__', '/')} = {v}")
        self.lines.append("")

    def poly(self, name, parent, pts, color, tex=None, vcols=None, z=None, pos=None):
        props = {}
        if z is not None:
            props["z_index"] = z
        if pos is not None:
            props["position"] = f"Vector2({f(pos[0])}, {f(pos[1])})"
        props["color"] = col(color)
        if vcols is not None:
            props["vertex_colors"] = colors(vcols)
        if tex:
            props["texture_filter"] = 1
            props["texture_repeat"] = 2
            props["texture"] = f'ExtResource("{tex}")'
            props["uv"] = vec(pts)
        props["polygon"] = vec(pts)
        self.node(name, "Polygon2D", parent, **props)

    def render(self):
        n_steps = 1 + len(self.ext) + len(self.sub)
        out = [f"[gd_scene load_steps={n_steps} format=3]", ""]
        for path, rid in self.ext:
            out.append(f'[ext_resource type="Texture2D" path="{path}" id="{rid}"]')
        out.append("")
        for (w, h), rid in self.sub.items():
            out.append(f'[sub_resource type="RectangleShape2D" id="{rid}"]')
            out.append(f"size = Vector2({f(w)}, {f(h)})")
            out.append("")
        return "\n".join(out) + "\n" + "\n".join(self.lines)


def mix(a, b, t=0.5):
    return tuple(a[i] * (1 - t) + b[i] * t for i in range(3))


def write_scene(chain, zone_info, summit, extras):
    sc = Scene()
    sc.lines.append('[node name="Level" type="Node2D"]')
    sc.lines.append("")
    sc.node("Background", "Node2D", ".", z_index=-50)
    sc.node("Decor", "Node2D", ".", z_index=-30)
    sc.node("Terrain", "Node2D", ".")
    sc.node("Signs", "Node2D", ".", z_index=-5)

    # ---- fondo degradado continuo
    themes = [THEME[z["theme"]]["bg"] for z in zone_info]
    for zi, z in enumerate(zone_info):
        cur = themes[zi]
        below = mix(themes[zi - 1], cur) if zi > 0 else cur
        above = mix(cur, themes[zi + 1]) if zi + 1 < len(themes) else cur
        yb, yt = z["y_bottom"], z["y_top"]
        ym = (yb + yt) / 2
        x0, x1 = -600.0, W + 600.0
        ov = 2.0
        sc.poly(f"BgZ{zi}a", "Background", [(x0, ym), (x1, ym), (x1, yb + (900 if zi == 0 else ov)), (x0, yb + (900 if zi == 0 else ov))],
                cur, vcols=[cur, cur, below, below])
        sc.poly(f"BgZ{zi}b", "Background", [(x0, yt - (900 if zi == len(zone_info) - 1 else 0)), (x1, yt - (900 if zi == len(zone_info) - 1 else 0)), (x1, ym + ov), (x0, ym + ov)],
                cur, vcols=[above, above, cur, cur])

    # ---- decoración de fondo (no colisiona)
    rr = random.Random(SEED + 1)
    for zi, z in enumerate(zone_info):
        decor(sc, rr, zi, z)

    # ---- terreno
    ground = solids[0]
    t = THEME["grass"]
    sc.node("Ground", "StaticBody2D", "Terrain", position=f"Vector2({f(ground.cx)}, {f((ground.y0 + ground.y1) / 2)})")
    gw, gh = ground.w, ground.y1 - ground.y0
    sc.poly("Body", "Terrain/Ground", rect_pts(gw, gh), t["tint"], tex=sc.tex("dirt"))
    sc.poly("Top", "Terrain/Ground", strip_pts(gw, gh, 12), t["top"])
    sc.node("Shape", "CollisionShape2D", "Terrain/Ground", shape=f'SubResource("{sc.rect_shape(gw, gh)}")')

    # paredes exteriores
    top_y = zone_info[-1]["y_top"] - 1400.0
    for side, x0, x1 in (("L", -400.0, 0.0), ("R", W, W + 400.0)):
        y0, y1 = top_y, 700.0
        name = f"Outer{side}"
        sc.node(name, "StaticBody2D", "Terrain", position=f"Vector2({f((x0 + x1) / 2)}, {f((y0 + y1) / 2)})")
        sc.poly("Body", f"Terrain/{name}", rect_pts(x1 - x0, y1 - y0), (0.35, 0.35, 0.4), tex=sc.tex("stone"), z=-1)
        sc.node("Shape", "CollisionShape2D", f"Terrain/{name}", shape=f'SubResource("{sc.rect_shape(x1 - x0, y1 - y0)}")')

    for s in solids:
        if s.kind in ("ground",):
            continue
        add_solid(sc, s)

    # ---- carteles
    for zi, z in enumerate(zone_info):
        if zi == 0:
            continue
        first = next((p for p in chain if p.zone == zi and p.kind == "platform"), None)
        if first is None:
            continue
        sc.node(f"Sign_Zone{zi}", "Label", "Signs", offset_left=f(first.cx - 300), offset_top=f(first.y0 - 90), offset_right=f(first.cx + 300),
                offset_bottom=f(first.y0 - 30), theme_override_colors__font_color=col((1.0, 0.95, 0.6)),
                theme_override_colors__font_outline_color="Color(0, 0, 0, 0.9)", theme_override_constants__outline_size=8,
                theme_override_font_sizes__font_size=34, horizontal_alignment=1, text=f'"ZONA {zi + 1}: {z["name"]}"')

    # ---- meta
    sc.node("Goal", "Area2D", ".", position=f"Vector2({f(summit.cx)}, {f(summit.y0 - 80)})", collision_layer=0, collision_mask=2)
    sc.node("Shape", "CollisionShape2D", "Goal", shape=f'SubResource("{sc.rect_shape(summit.w - 20, 160)}")')
    gp = f"{f(summit.cx)}, {f(summit.y0)}"
    # copa dorada
    cx0, cy0 = summit.cx, summit.y0
    sc.poly("Pole", "Goal", [(-4 + 0, 80), (4, 80), (4, -60), (-4, -60)], (0.85, 0.85, 0.9), z=2)
    sc.poly("Flag", "Goal", [(4, -60), (70, -40), (4, -20)], (1.0, 0.8, 0.15), z=2)
    sc.poly("Star", "Goal", star_pts(0, -80, 18, 8), (1.0, 0.9, 0.3), z=3)

    scene_text = sc.render()
    with open(os.path.join(ROOT, "scenes", "level.tscn"), "w", encoding="utf-8") as fh:
        fh.write(scene_text)


def rect_pts(w, h):
    return [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]


def strip_pts(w, h, t):
    return [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, -h / 2 + t), (-w / 2, -h / 2 + t)]


def star_pts(cx, cy, r1, r2):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = r1 if i % 2 == 0 else r2
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def add_solid(sc, s):
    th = THEME[ZONES[s.zone]["theme"]]
    name = s.id
    sc.node(name, "StaticBody2D", "Terrain", position=f"Vector2({f(s.cx)}, {f((s.y0 + s.y1) / 2)})",
            **({"metadata__surface": '"ice"'} if s.surface == "ice" else {}))
    w, h = s.w, s.y1 - s.y0
    path = f"Terrain/{name}"
    if s.kind in ("wall",):
        sc.poly("Body", path, rect_pts(w, h), th["wall"], tex=sc.tex(th["tex"]), z=-1)
    elif s.surface == "ice":
        sc.poly("Body", path, rect_pts(w, h), ICE_BODY_TINT, tex=sc.tex("stone"))
        sc.poly("Top", path, strip_pts(w, h, 8), ICE_TOP)
    elif s.kind == "overhang":
        sc.poly("Body", path, rect_pts(w, h), th["tint"], tex=sc.tex(th["tex"]))
        sc.poly("Bottom", path, [(-w / 2, h / 2 - 7), (w / 2, h / 2 - 7), (w / 2, h / 2), (-w / 2, h / 2)], mix(th["tint"], (0, 0, 0), 0.5))
    elif s.kind == "pillar":
        sc.poly("Body", path, rect_pts(w, h), mix(th["tint"], (1, 1, 1), 0.1), tex=sc.tex(th["tex"]))
        sc.poly("Cap", path, strip_pts(w, h, 6), th["top"])
    elif s.kind == "summit":
        sc.poly("Body", path, rect_pts(w, h), (0.75, 0.62, 0.2), tex=sc.tex("stone"))
        sc.poly("Top", path, strip_pts(w, h, 10), (1.0, 0.88, 0.35))
    else:
        sc.poly("Body", path, rect_pts(w, h), th["tint"], tex=sc.tex(th["tex"]))
        sc.poly("Top", path, strip_pts(w, h, 9), th["top"])
        sc.poly("Shade", path, [(-w / 2, h / 2 - 6), (w / 2, h / 2 - 6), (w / 2, h / 2), (-w / 2, h / 2)], mix(th["tint"], (0, 0, 0), 0.45))
    sc.node("Shape", "CollisionShape2D", path, shape=f'SubResource("{sc.rect_shape(w, h)}")')


def decor(sc, rr, zi, z):
    theme = z["theme"]
    yb, yt = z["y_bottom"], z["y_top"]
    n = 0

    def add(pts, color, pos=(0, 0), z=0):
        nonlocal n
        ys = [p[1] for p in pts]
        if min(ys) < yt - 40 or max(ys) > yb + 40:
            return
        n += 1
        sc.poly(f"D{zi}_{n}", "Decor", pts, color, pos=pos, z=z)

    def blob(cx, cy, rx, ry, color, k=14):
        pts = [(cx + rx * math.cos(2 * math.pi * i / k), cy + ry * math.sin(2 * math.pi * i / k)) for i in range(k)]
        add(pts, color)

    bg = THEME[theme]["bg"]
    dark = mix(bg, (0, 0, 0), 0.22)
    light = mix(bg, (1, 1, 1), 0.2)
    count = 55
    for i in range(count):
        y = rr.uniform(yt + 100, yb - 60)
        x = rr.uniform(-100, W + 100)
        if theme == "grass":
            if i < 12:
                blob(x, yb - rr.uniform(0, 400), rr.uniform(180, 380), rr.uniform(120, 220), mix((0.35, 0.65, 0.4), bg, 0.3))
            else:
                blob(x, y, rr.uniform(70, 150), rr.uniform(30, 55), (1, 1, 1, ) if False else mix(bg, (1, 1, 1), 0.55))
        elif theme == "forest":
            tw, th_ = rr.uniform(34, 60), rr.uniform(500, 1100)
            add(rect_pts_at(x, y, tw, th_), mix((0.25, 0.18, 0.12), bg, 0.35))
            blob(x, y - th_ / 2, rr.uniform(110, 190), rr.uniform(90, 150), mix((0.12, 0.34, 0.2), bg, 0.3))
        elif theme == "cave":
            if i % 2 == 0:
                s = rr.uniform(30, 60)
                add([(x - s / 2, y), (x + s / 2, y), (x, y + s * 2.6)], mix(bg, (0.5, 0.5, 0.7), 0.25))
            else:
                s = rr.uniform(6, 12)
                add([(x, y - s), (x + s * 0.7, y), (x, y + s), (x - s * 0.7, y)], (0.45, 0.75, 1.0))
        elif theme == "ice":
            s = rr.uniform(8, 20)
            add([(x, y - s), (x + s * 0.6, y), (x, y + s), (x - s * 0.6, y)], mix(bg, (1, 1, 1), 0.7))
            if i % 6 == 0:
                s2 = rr.uniform(60, 140)
                add([(x - s2 / 3, y + s2), (x + s2 / 3, y + s2), (x, y - s2 * 0.4)], mix(bg, (0.5, 0.8, 1.0), 0.45))
        elif theme == "ruins":
            if i % 3 == 0:
                pw, ph = rr.uniform(44, 70), rr.uniform(250, 600)
                add(rect_pts_at(x, y, pw, ph), mix((0.45, 0.4, 0.34), bg, 0.4))
                add(rect_pts_at(x, y - ph / 2, pw * 1.5, 18), mix((0.5, 0.45, 0.38), bg, 0.35))
            else:
                blob(x, y, rr.uniform(40, 90), rr.uniform(20, 40), mix(bg, (0, 0, 0), 0.15))
        elif theme == "volcano":
            s = rr.uniform(4, 9)
            add([(x - s, y - s), (x + s, y - s), (x + s, y + s), (x - s, y + s)], (1.0, rr.uniform(0.35, 0.7), 0.1))
            if i % 9 == 0:
                s2 = rr.uniform(120, 260)
                add([(x - s2, y + s2 * 2), (x + s2, y + s2 * 2), (x, y - s2 * 0.4)], mix(bg, (0, 0, 0), 0.35))
        elif theme == "sky":
            blob(x, y, rr.uniform(90, 200), rr.uniform(30, 60), mix(bg, (1, 1, 1), 0.7))
            blob(x + rr.uniform(-60, 60), y - 25, rr.uniform(60, 120), rr.uniform(25, 45), mix(bg, (1, 1, 1), 0.85))
        elif theme == "summit":
            s = rr.uniform(2, 6)
            c = rr.uniform(0.7, 1.0)
            add([(x, y - s * 1.6), (x + s, y), (x, y + s * 1.6), (x - s, y)], (c, c, 1.0))


def rect_pts_at(cx, cy, w, h):
    return [(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2), (cx + w / 2, cy + h / 2), (cx - w / 2, cy + h / 2)]


def write_info(zone_info, summit, chain):
    lines = [
        "extends RefCounted",
        "",
        "## GENERADO por tools/generate_level.py -- no editar a mano.",
        "",
        f"const WIDTH := {W:.1f}",
        "const START_POS := Vector2(1000.0, -30.0)",
        "const GROUND_Y := 0.0",
        f"const PX_PER_M := {PX_PER_M}",
        f"const SUMMIT_Y := {summit.y0:.1f}",
        f"const TOP_Y := {zone_info[-1]['y_top'] - 1000:.1f}",
        "",
        "## y_bottom / y_top en coordenadas del mundo (y negativa = más alto).",
        "const ZONES := [",
    ]
    for i, z in enumerate(zone_info):
        c = THEME[z["theme"]]["top"]
        if i == 0:
            sx, sy = W / 2, -30.0
        else:
            fp = next(p for p in chain if p.zone == i and p.kind == "platform")
            sx, sy = fp.cx, fp.y0 - 31.0
        lines.append(
            f'\t{{"name": "{z["name"]}", "y_bottom": {z["y_bottom"]:.1f}, "y_top": {z["y_top"]:.1f}, '
            f'"spawn": Vector2({sx:.1f}, {sy:.1f}), "color": Color({c[0]:.2f}, {c[1]:.2f}, {c[2]:.2f})}},'
        )
    lines.append("]")
    with open(os.path.join(ROOT, "scripts", "level_info.gd"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


def robust_cell(mask):
    """Celda del éxito con más vecinos exitosos alrededor (la más 'segura')."""
    best, bi = -1, None
    for i in range(mask.shape[0]):
        for j in range(mask.shape[1]):
            if not mask[i, j]:
                continue
            i0, i1 = max(0, i - 2), min(mask.shape[0], i + 3)
            j0, j1 = max(0, j - 2), min(mask.shape[1], j + 3)
            score = int(mask[i0:i1, j0:j1].sum())
            if score > best:
                best, bi = score, (i, j)
    return bi, best


def main():
    make_textures()
    chain, zone_info, summit = build()

    # --- cachear la calidad de cada salto, añadir repisas extra y re-validar
    for a, b in zip(chain, chain[1:]):
        n, _, _ = ways(a, b, solids)
        hop_cache[(a.id, b.id)] = n
    extras = add_ledges(chain, zone_info)
    for a, b in zip(chain, chain[1:]):
        n, _, _ = ways(a, b, solids)
        if n < 8:
            print("  AVISO tras repisas:", a.id, "->", b.id, "celdas", n)

    # --- recetas de referencia para el bot de pruebas
    Fs = np.linspace(FMIN, FMAX, NF)
    As = np.linspace(-MAXA, MAXA, NA)
    recipes = []
    worst = 10 ** 9
    for a, b in zip(chain, chain[1:]):
        n, x, mask = ways(a, b, solids)
        worst = min(worst, n)
        if mask is None:
            raise SystemExit(f"salto sin solución: {a.id} -> {b.id}")
        (i, j), score = robust_cell(mask)
        recipes.append(dict(src=a.id, dst=b.id, x=float(x), force=float(Fs[i]), angle=float(As[j]), cells=n, score=score,
                            src_top=a.y0, dst_top=b.y0, dst_x0=b.x0, dst_x1=b.x1))
    with open(os.path.join(ROOT, "tools", "recipes.json"), "w") as fh:
        json.dump(recipes, fh)

    write_scene(chain, zone_info, summit, extras)
    write_info(zone_info, summit, chain)

    heights = zone_info[-1]["y_top"]
    print(f"plataformas ruta principal: {len(chain)}, repisas extra: {len(extras)}, piezas totales: {len(solids)}")
    print(f"altura total: {abs(summit.y0) / PX_PER_M:.0f} m ({abs(summit.y0):.0f} px)")
    print(f"peor salto: {worst} celdas de {NF * NA}")
    per_zone = {}
    for r in recipes:
        pass
    for zi, z in enumerate(zone_info):
        c = [r["cells"] for r, p in zip(recipes, chain[1:]) if p.zone == zi]
        if c:
            print(f"  {z['name']:10s} saltos={len(c):3d} celdas min={min(c):3d} media={sum(c) / len(c):5.1f}")


if __name__ == "__main__":
    main()
