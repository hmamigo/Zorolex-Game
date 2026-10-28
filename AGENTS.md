# Plataforma 2D — Bosque de Bruma

Godot 4.7.2 / GDScript. Plataformas 2D con **arte 100% procedural**: no hay PNG,
fuentes ni audio importados. Todo se genera en runtime.

## Reglas duras

- **Nada de assets externos.** Nada de PNG/OGG/SVG. Las texturas se construyen en
  `scripts/pixel_art.gd` a partir de `scripts/palette.gd`.
- **Los colores salen solo de `scripts/palette.gd`.** No escribas `Color(...)` literales
  en otros archivos; si falta un tono, agregalo a la paleta con nombre.
- **Los sprites son mapas ASCII** en `scripts/sprite_data.gd`: un carácter = un píxel =
  una clave de `P.LEGEND`. El zorro mide 32x40 (filas de 32, 10 frames) y mira **a la
  derecha** por defecto; `flip_h` lo espeja al correr a la izquierda.
- **No edites `.godot/` ni `addons/godot_ai/`.** Son caché y plugin del MCP.

## Verificar antes de dar algo por terminado

1. **Compila** — un error de parseo deja la escena sin jugador y no siempre es obvio:
   ```sh
   godot --headless --path . --quit-after 20
   ```
   Buscar `SCRIPT ERROR` en la salida, no solo el código de salida.
2. **Captura** lo que tocaste: la tabla de comandos está en el skill `arte-procedural`.
3. **Mira el PNG.** No afirmes que algo "se ve bien" sin abrir `out/contact_sheet.png`.
   Ojo: cada script escribe su propio set de capturas y no regenera el del otro.

## Mapa del código

| Archivo | Responsabilidad |
|---|---|
| `scripts/palette.gd` | Única fuente de color + `LEGEND` de los mapas ASCII |
| `scripts/sprite_data.gd` | Frames ASCII del zorro y del hongo |
| `scripts/pixel_art.gd` | Genera texturas: sprites, terreno, bosque, sol, niebla |
| `scripts/main.gd` | Mundo, parallax, cámara, ambiente, HUD y título |
| `scripts/player.gd` | Movimiento, coyote time, squash & stretch, polvo, sombra |
| `scripts/enemy.gd` | Patrulla del hongo, aplastamiento, esporas |

## Entorno

- El MCP `godot-ai` normalmente está **desconectado** (`PLUGIN_DISCONNECTED`): no hay
  editor disponible. Todo se prueba con scripts `SceneTree` vía `--script`.
- Los scripts `SceneTree` deben declarar `func _process(_delta: float) -> bool` y
  devolver `true` para terminar.
- Las capturas van a `out/` (ignorada por Godot vía `out/.gdignore` y por git).
  Regenerables: nunca las edites a mano.
- `tools/*.py` necesitan **Pillow**.
- Este directorio **todavía no es un repo git**.
