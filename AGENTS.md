# Zorolex Game — La colección del saber

Godot 4.7.2 / GDScript. Plataformas 2D. Un zorro explora zonas (bosques, ruinas,
cuevas, montañas) y recolecta **saberes**: resúmenes breves, con fuentes, de entradas
de Wikipedia. Cada saber esconde un dato que sirve para abrir puertas y desbloquear
otras zonas. El tono es tranquilo y contemplativo: explorar y aprender, no apurarse.

El estilo visual base sigue siendo **arte procedural** (sprites ASCII, paleta única).

## Reglas duras

- **Los colores salen solo de `scripts/palette.gd`.** No escribas `Color(...)` literales
  en otros archivos; si falta un tono, agregalo a la paleta con nombre.
- **Los sprites del zorro y los enemigos son mapas ASCII** en `scripts/sprite_data.gd`:
  un carácter = un píxel = una clave de `P.LEGEND`. El zorro mide 32x40 (filas de 32,
  10 frames) y mira **a la derecha** por defecto; `flip_h` lo espeja al correr a la
  izquierda.
- **Lo procedural es el estilo base, pero ya no hay prohibición de assets externos.**
  Se pueden incorporar fuentes, audio u otros recursos cuando mejoren el juego, con
  estas condiciones:
  - licencia libre (CC0, CC-BY, OFL, MIT o equivalente), nunca "todos los derechos
    reservados";
  - van en `assets/<tipo>/` y quedan registrados en `CREDITS.md` (autor, URL, licencia);
  - no reemplaces sprites o texturas procedurales existentes por archivos importados
    sin avisar: es una decisión de estilo.
- **No edites `.godot/` ni `addons/godot_ai/`.** Son caché y plugin del MCP.
- **No inventes datos ni fuentes.** Ver "Saberes".

## Saberes

Un saber es un coleccionable de texto. Se recoge al tocarlo y queda guardado en el
diario.

### Contenido

- Basado en una entrada real de Wikipedia, **redactado con palabras propias** (no se
  copia el texto). Un solo párrafo, idealmente de unos 300–600 caracteres por idioma.
- Contiene **un dato concreto y verificable** (número, nombre, fecha, palabra, símbolo)
  que el jugador puede necesitar para abrir una puerta o activar algo.
- Debe tener al menos una fuente real, con URL y fecha de consulta. Si no podés
  verificar un dato contra la fuente, no lo escribas.
- Solo conocimiento verificable. Nada de pseudociencias. Tono neutral e informativo.
- Wikipedia es CC BY-SA 4.0: cada saber enlaza a su artículo y el juego muestra esa
  atribución en el diario y en `CREDITS.md`.

### Formato de datos (propuesto)

Un archivo por saber en `data/saberes/<id>.json`. Los textos van por idioma dentro del
mismo archivo; las fuentes no se traducen.

```json
{
  "id": "ejemplo_id",
  "zona": "bosque_de_bruma",
  "titulo": { "es": "…", "en": "…" },
  "texto":  { "es": "…", "en": "…" },
  "dato":   { "valor": "…", "tipo": "numero|palabra|simbolo" },
  "desbloquea": ["puerta_ruinas_01"],
  "fuentes": [
    { "titulo": "…", "url": "https://…", "idioma": "es", "consultado": "AAAA-MM-DD" }
  ]
}
```

- `id` es estable, en minúsculas y con guiones bajos. Una vez publicado, no se renombra
  (el guardado y las puertas dependen de él).
- Todo saber debe tener todos los idiomas activos del juego. Si falta uno, que falle la
  validación (`tools/validate_saberes.gd`, ver "Verificar").

### Idiomas

- Idiomas iniciales: `es` y `en`. Agregar otro es agregar la clave en cada saber y en
  la tabla de la interfaz, sin tocar código.
- Los textos de la interfaz (menús, HUD, diario) usan el sistema de traducción de Godot
  (`tr()` y `TranslationServer`). Los saberes los carga `scripts/saberes.gd` y eligen
  el idioma activo con fallback a `en`.
- Para alfabetos no latinos hará falta una fuente externa (ver reglas duras).

### Desbloqueo y diario

- Una puerta o mecanismo declara qué saber o dato necesita. Dos modos posibles:
  **requiere tener el saber** o **pide el dato** (el jugador lo lee en el diario y lo
  ingresa). Ver "Por decidir".
- El diario lista los saberes encontrados, con su texto, su dato resaltado y sus
  fuentes, y permite releerlos en cualquier momento.
- El progreso (ids recogidos, puertas abiertas) se guarda en `user://savegame.json`.

## Zonas y progresión

- Estructura: un **hub** tranquilo (el claro del zorro) del que salen puertas a zonas.
  Cada zona (bosque, ruinas, cueva, montaña) es un nivel propio con sus saberes.
- Cada zona se define con datos, no con código especial: spawn, límites de cámara,
  suelos, repisas, props, enemigos, saberes y puertas, siguiendo el patrón de
  `scripts/level_data.gd`. Agregar una zona = agregar un archivo de datos y, si hace
  falta, una paleta de ambiente.
- Hacé primero una **rebanada vertical**: Bosque de Bruma con 4–6 saberes y una sola
  puerta que dependa de uno. Recién cuando eso funcione, sumá zonas.
- Las zonas se enlazan por saberes: el dato de una zona abre la siguiente. Evitá
  dependencias circulares y comprobá que toda puerta se pueda abrir con saberes
  alcanzables.

## Verificar antes de dar algo por terminado

1. **Compila** — un error de parseo deja la escena sin jugador y no siempre es obvio:
   ```sh
   godot --headless --path . --quit-after 20
   ```
   Buscar `SCRIPT ERROR` en la salida, no solo el código de salida. Vale en los dos
   modos: el editor no siempre reporta un parseo roto al abrir la escena.
2. **Captura** lo que tocaste: la tabla de comandos está en el skill `arte-procedural`.
   Con el editor conectado, `editor_screenshot` cubre lo mismo sin salir del editor.
3. **Mirá la imagen.** No afirmes que algo "se ve bien" sin abrir el PNG
   (`out/contact_sheet.png` o el que devuelva `editor_screenshot`).
   Ojo: cada script escribe su propio set de capturas y no regenera el del otro.
4. **Si tocaste saberes**, corré el validador (planificado):
   `godot --headless --path . --script tools/validate_saberes.gd`. Debe comprobar: ids
   únicos, todos los idiomas presentes, un solo párrafo, al menos una fuente con URL, y
   que cada `desbloquea` apunte a una puerta existente.

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
| `scripts/saberes.gd` *(planificado)* | Autoload: carga `data/saberes/`, idioma activo, estado recogido/guardado |
| `scripts/diario.gd` *(planificado)* | Interfaz del diario |
| `tools/validate_saberes.gd` *(planificado)* | Validador de datos de saberes |

Marcá como planificado todo lo que todavía no exista; no lo describas como si estuviera.

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

## Cuándo preguntar

Actuá con autonomía en scripts, datos de zonas, saberes y herramientas de `tools/`.
**Preguntá antes de:**

- agregar un addon o una dependencia nueva;
- cambiar autoloads, mapa de entradas o ajustes de renderizado en `project.godot`;
- incorporar un asset externo cuya licencia no sea claramente libre;
- renombrar o borrar ids de saberes ya existentes, o cambiar el formato de datos
  cuando ya hay contenido escrito;
- borrar archivos, reescribir historial de git o hacer `push`.

## Entorno

- Las capturas van a `out/` (ignorada por Godot vía `out/.gdignore` y por git).
  Regenerables: nunca las edites a mano.
- `tools/*.py` necesitan **Pillow**.
- El repo git ignora `.godot/`, `out/*` (salvo `out/.gdignore`) y `__pycache__/`.

## Por decidir

- Modo de las puertas: ¿basta con tener el saber, o el jugador debe leer el dato en el
  diario y usarlo (código, símbolo, palabra)?
- Nombre del proyecto en `project.godot` (hoy figura como "Plataforma 2d").
- Idiomas más allá de `es` y `en`, y fuente tipográfica para ellos.
