#!/usr/bin/env python3
"""Vuelca un diseno de sprite a scripts/sprite_data.gd, con backup previo.

Uso:
    python3 tools/apply_sprite.py tools/designs/fox7.py

El modulo de diseno debe exponer:
    load_old()  -> dict nombre -> filas ASCII del sprite actual
    build_head() -> escena/estructura de la cabeza nueva
    compose(nombre, old, head) -> filas ASCII del frame resultante

OJO: no es idempotente. load_old() lee el sprite_data.gd *actual*, asi que
aplicar el mismo diseno dos veces compone sobre el resultado anterior.
Restaura desde out/backups/ antes de re-aplicar.

Requiere Pillow.
"""
import importlib.util
import re
import shutil
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPRITE = ROOT / "scripts" / "sprite_data.gd"
BACKUPS = ROOT / "out" / "backups"
BLOCK_RE = re.compile(r"const FOX := \{.*?\n\}\n\nconst MUSHROOM", re.S)
VALID_WIDTHS = (30, 32)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2

    design = Path(sys.argv[1]).resolve()
    if not design.exists():
        print(f"no existe el diseno: {design}")
        return 2

    spec = importlib.util.spec_from_file_location(design.stem, design)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    txt = SPRITE.read_text()
    match = BLOCK_RE.search(txt)
    if match is None:
        print("no encontre el bloque `const FOX := {...}` seguido de `const MUSHROOM`")
        return 1

    old = mod.load_old()
    head = mod.build_head()
    composed = {k: mod.compose(k, old, head) for k in old}
    composed["idle_blink"] = mod.compose("idle_1", old, mod.build_head(blink=True))

    widths = {len(row) for rows in composed.values() for row in rows}
    invalid = widths - set(VALID_WIDTHS)
    if invalid:
        print(f"anchos invalidos: {sorted(invalid)} (esperado {VALID_WIDTHS})")
        print("El diseno compone sobre el sprite base de 30 px (lo rellena a 32).")
        print("Si scripts/sprite_data.gd ya esta en 32, el diseno no es re-aplicable:")
        print("restaura tools/designs/sprite_data.base-30.gd o un backup de out/backups/.")
        print("No se escribio nada.")
        return 1

    lines = ["const FOX := {"]
    for name, rows in composed.items():
        lines.append(f'"{name}": [')
        for row in rows:
            lines.append(f'\t"{row}",')
        lines.append("],")
    lines.append("}")
    block = "\n".join(lines) + "\n\nconst MUSHROOM"

    BACKUPS.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    backup = BACKUPS / f"sprite_data.{stamp}.gd"
    shutil.copy(SPRITE, backup)

    SPRITE.write_text(txt[: match.start()] + block + txt[match.end():])
    print(f"escrito {len(composed)} frames desde {design.name}")
    print(f"backup: {backup.relative_to(ROOT)}")
    print("verifica visualmente: godot --headless --path . --quit-after 20")
    return 0


if __name__ == "__main__":
    sys.exit(main())
