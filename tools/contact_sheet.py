#!/usr/bin/env python3
"""Arma la hoja de contacto y la tira de carrera a partir de las capturas de out/.

Uso:
    python3 tools/contact_sheet.py

Salida:
    out/contact_sheet.png  -> 01..08 en grilla 4x2
    out/run_strip.png      -> tira horizontal con out/run_*.png

Requiere Pillow. Solo lee lo que ya capturaste; no ejecuta Godot.
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "out"

SHOTS = [
    "01_title", "02_spawn", "03_mid", "04_far",
    "05_air", "06_run", "07_stomp", "08_after",
]
COLS = 4
PAD = 6
LABEL_H = 20
BG = (16, 18, 17)
FG = (210, 205, 190)


def contact_sheet() -> None:
    have = [(n, Image.open(OUT / f"{n}.png").convert("RGB"))
            for n in SHOTS if (OUT / f"{n}.png").exists()]
    if not have:
        print("no hay capturas en out/; corre primero tools/capture.gd")
        return

    w, h = have[0][1].size
    rows = (len(have) + COLS - 1) // COLS
    sheet = Image.new(
        "RGB",
        (COLS * w + PAD * (COLS + 1), rows * (h + LABEL_H) + PAD * (rows + 1)),
        BG,
    )
    draw = ImageDraw.Draw(sheet)
    for i, (name, im) in enumerate(have):
        x = PAD + (i % COLS) * (w + PAD)
        y = PAD + (i // COLS) * (h + LABEL_H + PAD)
        sheet.paste(im, (x, y))
        draw.text((x + 3, y + h + 5), name, fill=FG)

    sheet.save(OUT / "contact_sheet.png")
    missing = [n for n in SHOTS if not (OUT / f"{n}.png").exists()]
    print(f"out/contact_sheet.png {sheet.size[0]}x{sheet.size[1]}")
    if missing:
        print("faltan:", ", ".join(missing))


def run_strip() -> None:
    frames = sorted(OUT.glob("run_*.png"))
    if not frames:
        return
    imgs = [Image.open(f).convert("RGB") for f in frames]
    w, h = imgs[0].size
    strip = Image.new("RGB", (w * len(imgs), h), BG)
    for i, im in enumerate(imgs):
        strip.paste(im, (i * w, 0))
    strip.save(OUT / "run_strip.png")
    print(f"out/run_strip.png {strip.size[0]}x{strip.size[1]} ({len(imgs)} frames)")


if __name__ == "__main__":
    contact_sheet()
    run_strip()
