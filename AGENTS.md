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
   Buscar `SCRIPT ERROR` en la salida, no solo el código de salida. Vale en los dos
   modos: el editor no siempre reporta un parseo roto al abrir la escena.
2. **Captura** lo que tocaste: la tabla de comandos está en el skill `arte-procedural`.
   Con el editor conectado, `editor_screenshot` cubre lo mismo sin salir del editor.
3. **Mira la imagen.** No afirmes que algo "se ve bien" sin abrir el PNG
   (`out/contact_sheet.png` o el que devuelva `editor_screenshot`).
   Ojo: cada script escribe su propio set de capturas y no regenera el del otro.

## Mapa del código

| Archivo | Responsabilidad |
|---|---|
| `scripts/palette.gd` | Única fuente de color + `LEGEND` de los mapas ASCII |
| `scripts/sprite_data.gd` | Frames ASCII del zorro y del hongo |
| `scripts/level_data.gd` | Nivel: spawn, límites de cámara, suelos, repisas, props y hongos |
| `scripts/pixel_art.gd` | Genera texturas: sprites, terreno, bosque, sol, niebla |
| `scripts/main.gd` | Mundo, parallax, cámara, ambiente, HUD y título |
| `scripts/player.gd` | Movimiento, coyote time, squash & stretch, polvo, sombra |
| `scripts/enemy.gd` | Patrulla del hongo, aplastamiento, esporas |

## Flujo de trabajo

### Paso 0: averiguar si hay editor

Nunca asumas que el MCP está conectado ni que está caído. Consultá
`editor_state` (o `session_manage(op="list")`):

| Resultado | Modo |
|---|---|
| `count: 0`, o error `PLUGIN_DISCONNECTED` | **Headless** |
| `count: 1` con `readiness: "ready"` | **Con editor** |

Con varias sesiones registradas, fijá la correcta con `session_activate`.

### Con editor conectado

- **Editar código** se hace igual que siempre: con las herramientas de archivo sobre
  `scripts/*.gd`. No hace falta pasar por el editor, que recarga los scripts solo.
- **Probar:** `project_run` (`mode: "main"` o `"current"`) y al terminar
  `project_manage(op="stop")`. Verificá antes que `play_state` esté `stopped`.
- **Ver:** `editor_screenshot` con `source: "game"` (juego corriendo) o
  `"viewport_2d"` (editor). Reemplaza al contact sheet en este modo.
- **Errores:** `logs_read` con `source: "game"` para el runtime, `"editor"` para el
  editor. Es más directo que releer la salida de `godot --headless`.
- **Runtime en vivo:** `game_manage` (`get_scene_tree`, `get_node_info`, `input_*`)
  para inspeccionar nodos o simular input sin tocar el juego a mano.
- **No edites `.tscn` a mano** si el editor tiene la escena abierta: usá
  `scene_manage` / `node_set_property` / `scene_save` y evitá pisar cambios en memoria.

### Sin editor (headless)

- Todo se prueba con scripts `SceneTree` vía `--script`, y la lista de comandos y
  capturas está en el skill `arte-procedural`.
- Los scripts `SceneTree` deben declarar `func _process(_delta: float) -> bool` y
  devolver `true` para terminar.

## Entorno

- Las capturas van a `out/` (ignorada por Godot vía `out/.gdignore` y por git).
  Regenerables: nunca las edites a mano.
- `tools/*.py` necesitan **Pillow**.
- El repo git ignora `.godot/`, `out/*` (salvo `out/.gdignore`) y `__pycache__/`.
