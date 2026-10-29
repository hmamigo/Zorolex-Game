#!/usr/bin/env python3
"""Regenera los frames de movimiento del zorro en scripts/sprite_data.gd.

Parte de `idle_0` (cuerpo) y de `jump` (cuerpo con bufanda al viento) y arma el
resto: ciclo de carrera, respiracion, salto y caida. Las botas se despegan del
cuerpo y se vuelven a pegar con otro desfase (dx, dy). El resultado sigue siendo
un mapa ASCII por frame, 32x40, que mira a la derecha.

Uso:  python3 tools/build_fox_frames.py            (reescribe sprite_data.gd)
Es idempotente: idle_0 y jump no se modifican, asi que se puede repetir.
"""
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
PATH = ROOT / "scripts" / "sprite_data.gd"
W, H = 32, 40
LEG_ROWS = range(35, 40)
LEG_COLS = range(10, 21)          # bloque de botas en idle_0
KEEP = {(35, 20)}                 # esquina del morral que no es bota

# caracteres de la leyenda que pertenecen a la bota
BOOT = set("0ef1")


def parse(text):
    frames = {}
    for m in re.finditer(r'"(\w+)": \[\n(.*?)\n\],', text, re.S):
        frames[m.group(1)] = re.findall(r'"([^"]*)"', m.group(2))
    return frames


def grid(rows):
    return [list(r.ljust(W, ".")) for r in rows]


def to_rows(g):
    return ["".join(r) for r in g]


def split_legs(g):
    """Devuelve (cuerpo sin piernas, bota izquierda, bota derecha)."""
    body = [r[:] for r in g]
    boots = {"L": {}, "R": {}}
    for y in LEG_ROWS:
        for x in LEG_COLS:
            if (y, x) in KEEP:
                continue
            ch = g[y][x]
            if ch != ".":
                side = "L" if x <= 14 else "R"
                boots[side][(y, x)] = ch
            body[y][x] = "."
    return body, boots["L"], boots["R"]


def compress(g, row):
    """Quita una fila de torso: la cabeza baja 1 px y los pies siguen en el suelo."""
    out = [r[:] for r in g]
    for y in range(row, 0, -1):
        out[y] = g[y - 1][:]
    out[0] = ["."] * W
    return out


def paste_boot(layer, boot, dx, dy):
    for (y, x), ch in boot.items():
        yy, xx = y + dy, x + dx
        if 0 <= yy < H and 0 <= xx < W:
            layer[yy][xx] = ch


def build(body, left, right, l_off, r_off, front="R", extra_body=None):
    g = [r[:] for r in body]
    layer = [["."] * W for _ in range(H)]
    order = [("L", left, l_off), ("R", right, r_off)]
    if front == "L":
        order.reverse()
    for _, boot, off in order:
        paste_boot(layer, boot, *off)
    for y in range(H):
        for x in range(W):
            if g[y][x] == "." and layer[y][x] != ".":
                g[y][x] = layer[y][x]
    return g


def main():
    text = PATH.read_text()
    fr = parse(text)
    idle = grid(fr["idle_0"])
    jump = grid(fr["jump"])
    body, L, R = split_legs(idle)
    jbody, _, _ = split_legs(jump)

    out = {}
    out["idle_0"] = fr["idle_0"]
    # respiracion: torso comprimido, los pies no se mueven
    breath = compress(body, 31)
    out["idle_1"] = to_rows(build(breath, L, R, (0, 0), (0, 0)))
    blink_src = grid(fr["idle_blink"])
    bb, _, _ = split_legs(blink_src)
    out["idle_blink"] = to_rows(build(bb, L, R, (0, 0), (0, 0)))

    # ciclo de carrera (mira a la derecha): contacto / paso / contacto / paso
    run0 = compress(body, 31)
    out["run_0"] = to_rows(build(run0, L, R, (-4, -1), (3, 0), front="R"))
    out["run_1"] = to_rows(build(body, L, R, (-2, -2), (1, 0), front="R"))
    out["run_2"] = to_rows(build(run0, L, R, (3, 0), (-4, -1), front="L"))
    out["run_3"] = to_rows(build(body, L, R, (-1, 0), (2, -2), front="L"))

    # aire
    out["jump"] = to_rows(build(jbody, L, R, (-3, -2), (3, -2), front="R"))
    out["fall"] = to_rows(build(body, L, R, (-3, -1), (3, -1), front="R"))
    out["hurt"] = fr["hurt"]

    order = ["idle_0", "idle_1", "idle_blink", "run_0", "run_1", "run_2", "run_3",
             "jump", "fall", "hurt"]
    fox = "const FOX := {\n"
    for k in order:
        fox += f'"{k}": [\n' + "".join(f'\t"{r}",\n' for r in out[k]) + "],\n"
    fox += "}\n"
    head, rest = text.split("const FOX := {", 1)
    tail = rest[rest.index("\nconst MUSHROOM"):]
    PATH.write_text(head + fox + tail)
    print("ok:", ", ".join(order))


if __name__ == "__main__":
    main()
