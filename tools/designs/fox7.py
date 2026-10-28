#!/usr/bin/env python3
"""Zorro 3/4: mascara crema construida como el arte original (desplazada y
extendida al hocico). Silueta, orejas y cuerpo originales."""
import math, re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]

W, H = 32, 40
PAL = {
    '.': None, '0': (36, 26, 21), '1': (150, 62, 36), '2': (201, 92, 50),
    '3': (234, 142, 84), '4': (247, 179, 120), '5': (247, 232, 200),
    '6': (219, 199, 156), '7': (36, 25, 19), '8': (52, 94, 80),
    '9': (86, 140, 117), 'a': (146, 192, 166), 'b': (90, 56, 36),
    'c': (137, 90, 58), 'd': (176, 124, 79), 'e': (58, 39, 29),
    'f': (94, 64, 46), 'g': (232, 178, 96),
}


def E(cx, cy, rx, ry):
    return {(x, y) for y in range(H) for x in range(W)
            if ((x - cx) / max(rx, .001)) ** 2 + ((y - cy) / max(ry, .001)) ** 2 <= 1.0}


def P(pts):
    s = set()
    ys = [p[1] for p in pts]
    for y in range(int(math.floor(min(ys))), int(math.ceil(max(ys))) + 1):
        xs = []
        sy = y + .5
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            if (a[1] <= sy < b[1]) or (b[1] <= sy < a[1]):
                xs.append(a[0] + (sy - a[1]) / (b[1] - a[1]) * (b[0] - a[0]))
        xs.sort()
        for i in range(0, len(xs) - 1, 2):
            for x in range(int(math.ceil(xs[i])), int(math.floor(xs[i + 1])) + 1):
                s.add((x, y))
    return s


def band(y, x0, x1):
    return {(x, y) for x in range(x0, x1 + 1)}


def load_old():
    txt = (ROOT / 'scripts' / 'sprite_data.gd').read_text()
    block = re.search(r'const FOX := \{(.*?)\n\}\n\nconst MUSHROOM', txt, re.S).group(1)
    out = {}
    for m in re.finditer(r'"(idle_0|idle_1|idle_blink|run_0|run_1|run_2|run_3|jump|fall|hurt)": \[(.*?)\n\]', block, re.S):
        out[m.group(1)] = re.findall(r'"([.0-9a-o]+)"', m.group(2))
    return out


def build_head(blink=False, ears_back=0):
    old = load_old()['idle_0']
    rows = [('.' + r + '.') for r in old]
    g = [list(r) for r in rows]

    sil = {(x, y) for y in range(19) for x in range(W) if rows[y][x] != '.'}
    snout = E(27.0, 15.4, 2.6, 2.5) & {(x, y) for x in range(W) for y in range(H)
                                       if 22 <= x <= 29 and 12 <= y <= 18}
    head = sil | snout

    # limpiar cara y hocico
    for y in range(9, 19):
        for x in range(10, 30):
            if rows[y][x] != '.':
                g[y][x] = '2'
    for (x, y) in snout - sil:
        g[y][x] = '2'

    # volumen
    for (x, y) in head:
        if y < 9:
            continue
        if (x - 1, y) not in head:
            g[y][x] = '1'
        elif (x + 1, y) not in head:
            g[y][x] = '3'
        elif (x, y - 1) not in head:
            g[y][x] = '4'
    for (x, y) in head:
        if y >= 17 and (x, y + 1) not in head:
            g[y][x] = '1'

    # --- mascara crema (forma original desplazada + hocico) ---
    mask = (band(9, 16, 19) | band(10, 16, 19) | band(11, 17, 20) | band(12, 16, 20) |
            band(13, 15, 21) | band(14, 13, 28) | band(15, 13, 28) | band(16, 14, 27) |
            band(17, 15, 26) | band(18, 16, 24) | band(19, 17, 22)) & head
    for (x, y) in mask:
        g[y][x] = '5'
    for (x, y) in mask:
        if (x, y + 1) not in mask:
            g[y][x] = '6'

    # --- ojos ---
    if blink:
        for (x0, y0, w) in ((13, 13, 2), (22, 13, 2)):
            for i in range(w):
                g[y0][x0 + i] = '7'
            g[y0 - 1][x0] = '6'
    else:
        for (x0, y0, w) in ((13, 11, 2), (22, 11, 2)):
            for j in range(3):
                for i in range(w):
                    g[y0 + j][x0 + i] = '7'
    # cejas
    for x in (12, 13, 14, 21, 22, 23):
        if g[10][x] in '25':
            g[10][x] = '1'

    # --- nariz ---
    g[14][26] = '7'
    g[14][27] = '7'
    g[15][26] = '7'
    g[15][27] = '0'
    g[13][26] = '1'
    g[16][26] = '1'
    g[17][25] = '1'
    g[17][27] = '1'
    for (x, y) in (snout - sil):
        if (x, y - 1) not in head:
            g[y][x] = '3'

    # --- contorno ---
    for (x, y) in head:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H and (nx, ny) not in head:
                g[ny][nx] = '0'

    out = []
    for y in range(H):
        out.append(''.join(g[y]) if y < 19 else rows[y])
    return out


def compose(name, old, head, dy=0):
    out = [list('.' + r + '.') for r in old[name]]
    for y in range(0, 19):
        for x in range(W):
            if out[y][x] != '.':
                out[y][x] = '.'
    for y in range(H):
        if 0 <= y + dy < H:
            for x in range(W):
                if head[y][x] != '.':
                    out[y + dy][x] = head[y][x]
    return [''.join(r) for r in out]


def sheet(frames, path, scale=12, cols=5):
    rown = (len(frames) + cols - 1) // cols
    sh = Image.new('RGB', (cols * (W * scale + 16), rown * (H * scale + 30)), (30, 36, 34))
    d = ImageDraw.Draw(sh)
    for i, (name, rows) in enumerate(frames.items()):
        ox = (i % cols) * (W * scale + 16) + 8
        oy = (i // cols) * (H * scale + 30) + 8
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                col = PAL.get(ch)
                if col:
                    d.rectangle([ox + x * scale, oy + y * scale, ox + (x + 1) * scale - 1,
                                 oy + (y + 1) * scale - 1], fill=col)
        d.text((ox, oy + H * scale + 6), name, fill=(240, 235, 215))
    sh.save(path)


if __name__ == '__main__':
    old = load_old()
    head = build_head()
    frames = {n: compose(n, old, head) for n in
              ['idle_0', 'idle_1', 'run_0', 'run_1', 'run_2', 'run_3', 'jump', 'fall']}
    frames['idle_blink'] = compose('idle_1', old, build_head(blink=True))
    out = ROOT / 'out'
    out.mkdir(exist_ok=True)
    sheet(frames, str(out / 'fox7_sheet.png'))
    sheet({'idle_0': frames['idle_0']}, str(out / 'fox7_zoom.png'), scale=20, cols=1)
    print('\n'.join(frames['idle_0']))
