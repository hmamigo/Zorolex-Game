---
name: Arte procedural (Bosque de Bruma)
description: Iterar el arte generado por código y el game feel del plataformas "Bosque de Bruma" en Godot — paleta, sprites ASCII, capas de fondo, parallax, luz y cámara — usando el bucle de captura sin editor.
---

# Arte procedural — Bosque de Bruma

Todo el arte de este juego se genera en runtime. Este documento es el **bucle de
trabajo**; las reglas duras y el mapa de archivos están en `AGENTS.md` (siempre cargado).

## Bucle

1. **Cambiá una sola cosa.** Paleta → `scripts/palette.gd`. Píxeles de sprite →
   `scripts/sprite_data.gd`. Generación de textura → `scripts/pixel_art.gd`.
   Composición, parallax y luz → `scripts/main.gd`.
2. **Compilá**: `godot --headless --path . --quit-after 20` (buscá `SCRIPT ERROR`).
3. **Capturá** solo lo que tocaste, con la tabla de abajo.
4. **Mirá el PNG.** Compará contra la captura anterior; si no hay "antes", la iteración
   no cuenta.
5. **Juzgá a escala de juego, no en zoom.** La cámara va a 2.2x sobre una ventana de
   1152x648: 1 px de mundo ≈ 2.2 px de pantalla. Un detalle que se ve hermoso al 2000%
   puede desaparecer por completo.

Todos los comandos de captura se corren con
`--rendering-driver opengl3 --audio-driver Dummy`.

## Qué script para qué

| Cambiaste | Comando | Salida |
|---|---|---|
| Fondo, parallax, luz, HUD, título | `--script tools/capture.gd` | `out/01_title` … `out/05_air` |
| Movimiento, salto, aplastamiento | `--script tools/capture_stomp.gd` | `out/06_run` … `out/08_after` |
| Ciclo de animación, bob | `--script tools/capture_run.gd` | `out/run_00` … `out/run_09` |
| Espejado al correr a la izquierda | `--script tools/capture_left.gd` | `out/09_left` |
| Una textura generada suelta | `--script tools/dump_layers.gd` | `out/layers_*.png` |
| Hoja de contacto / tira de carrera | `python3 tools/contact_sheet.py` | `out/contact_sheet.png`, `out/run_strip.png` |
| Volcar un rediseño de sprite | `python3 tools/apply_sprite.py tools/designs/fox7.py` | backup en `out/backups/` |

## Rediseñar un sprite

1. Partí del base de 30 px: `cp tools/designs/sprite_data.base-30.gd scripts/sprite_data.gd`.
2. Iterá el diseño en `tools/designs/*.py`. Son módulos Python con Pillow: exportan
   `load_old()`, `build_head()` y `compose()`.
3. `python3 tools/apply_sprite.py tools/designs/<nombre>.py` — valida anchos y guarda
   backup en `out/backups/` antes de escribir.
4. `godot --headless --path . --quit-after 20`, y después `tools/capture_run.gd` más
   `tools/capture.gd`. **El veredicto es a escala de juego**, no en el preview a 20x.

## Trampas ya pagadas

- **`_px()` sobrescribe, no compone.** Para dibujar una capa semitransparente encima de
  otra hace falta `_over(dst, src)` o `Image.blend_rect`. Si no, los pinos de una cresta
  "agujerean" la loma en lugar de apoyarse en ella.
- **`modulate` multiplica el color de la textura.** Un glow con modulate oscuro pierde su
  núcleo claro y se lee como un disco plano: así el sol parecía un planeta. El color va en
  la textura; el modulate es solo para tinte y alpha.
- **El borde de un sprite grande se nota.** A 2.2x, un `smoothstep` que cubre el 30% del
  radio se ve como un aro. Usá colas largas y que el borde tome el color del fondo.
- **Cada script escribe su propio set de PNGs.** `tools/capture.gd` no regenera
  `08_after`. Mirar un archivo viejo y creer que refleja el cambio es el error más fácil
  de cometer: revisá la fecha del archivo si algo "no cambió".
- **Un script `SceneTree` necesita `func _process(_delta: float) -> bool`** y devolver
  `true` para terminar; si no, cuelga indefinidamente.
- **`tools/apply_sprite.py` no es idempotente.** El diseño compone sobre el sprite base de
  30 px y lo rellena a 32: solo se aplica a `tools/designs/sprite_data.base-30.gd`. Si
  `scripts/sprite_data.gd` ya está en 32, el script aborta sin escribir (hace bien) y hay
  que restaurar el base primero. Ciclo verificado: base-30 + `fox7.py` reproduce el sprite
  vigente byte a byte.
- **No hay editor.** El MCP `godot-ai` suele estar desconectado; no cuentes con
  inspeccionar nodos en vivo.

## Criterios de arte de este proyecto

- **Hora dorada:** horizonte ámbar, sombras frescas (verdosas-azuladas), rim cálido del
  lado del sol. El sol está bajo, a la derecha, y nunca debe leerse como un planeta.
- **Profundidad por aire, no por oscurecer:** las capas lejanas pierden contraste y
  saturación; no se ennegrecen.
- **Nada de bordes duros** en niebla, sol, copas o niebla de valle: siempre disolver
  contra el fondo.
- **El zorro primero se lee por silueta.** Orejas, bufanda y cola tienen que reconocerse a
  tamaño de juego; el detalle viene después.
- **El bosque es denso pero no una pared.** El follaje cercano es silueta oscura; los
  arbustos sueltos van a z=1 y nunca como una capa continua (generaba setos flotantes y
  costuras de tiling).

Detalle de capas, z-index y constantes: `references/capas.md`.
