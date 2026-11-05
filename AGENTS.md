# Zorolex Game — La colección del saber

Godot 4.7.2 / GDScript. Plataformas 2.5D: mundo 3D con cámara inclinada y sprites 2D
en billboard. Un zorro explora zonas (bosques, ruinas, cuevas, montañas) y recolecta
**saberes**: resúmenes breves, con fuentes, de entradas de Wikipedia. Cada saber
esconde un dato que sirve para abrir puertas y desbloquear otras zonas. El tono es
tranquilo y contemplativo: explorar y aprender, no apurarse.

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

## Mundo 2.5D

El juego se diseña en 2D pero se construye en 3D: suelos y repisas son cajas, la
cámara está inclinada y todo lo dibujado son sprites 2D en billboard. Las
convenciones viven en `scripts/world_3d.gd`:

- `PLANE_Z` es el plano de juego y cae en el **centro de la tapa del terreno**.
  El zorro, los hongos, los saberes y las puertas viven ahí; los props decorativos
  van detrás (`PROP_Z`) para no tapar al zorro.
- La lógica sigue en coordenadas de diseño 2D y se convierte con `W.to_world()` /
  `W.to_side()`.
- La cámara (`CAM_DISTANCE`, `CAM_FOV`, `CAM_PITCH`, `CAM_YAW`) apunta al centro
  del sprite del zorro. Si movés `PLANE_Z`, revisá la sombra del zorro, el rayo de
  borde del hongo y la compensación de escala del parallax.

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

### Formato de datos

Un archivo por saber en `data/saberes/<id>.json`. Los textos van por idioma dentro del
mismo archivo; las fuentes no se traducen.

```json
{
  "id": "ejemplo_id",
  "zona": "bosque_de_bruma",
  "tema": "ciencias_naturales",
  "titulo": { "es": "…", "en": "…" },
  "texto":  { "es": "…", "en": "…" },
  "dato":   { "tipo": "numero|palabra|simbolo", "valor": { "es": "…", "en": "…" } },
  "pregunta": {
    "es": { "enunciado": "…", "opciones": ["…", "…", "…"] },
    "en": { "enunciado": "…", "opciones": ["…", "…", "…"] }
  },
  "desbloquea": ["puerta_ruinas_01"],
  "fuentes": [
    { "titulo": "…", "url": "https://…", "idioma": "es", "consultado": "AAAA-MM-DD" }
  ]
}
```

- `id` es estable, en minúsculas y con guiones bajos. Una vez publicado, no se renombra
  (el guardado y las puertas dependen de él).
- `tema` es el de la zona (`TEMA` en el archivo de nivel, p. ej. `level_data.gd` o
  `level_ruinas.gd`): todos sus saberes comparten el mismo. La etiqueta visible sale de
  `i18n/ui.csv` (`TEMA_<ID>`), no del archivo.
- `dato.valor` lleva un valor por idioma. La respuesta correcta de la pregunta **es**
  ese valor (se compara sin mayúsculas ni espacios), así que no se duplica la verdad.
  Las opciones van como valores pelados ("Esporas", no "Por esporas") para que
  coincidan con el dato.
- `desbloquea` lista las puertas a las que el saber contribuye. Una puerta que pide
  varios saberes aparece en cada uno de ellos: se abre solo cuando están todos.
- Todo saber debe tener todos los idiomas activos del juego. Si falta uno, que falle la
  validación (`tools/validate_saberes.gd`, ver "Verificar").

### Idiomas

- Idiomas iniciales: `es` y `en`. Agregar otro es agregar la clave en cada saber y en
  `i18n/ui.csv`, sin tocar código.
- Los textos de la interfaz (menús, HUD, diario) usan el sistema de traducción de Godot
  (`tr()` y `TranslationServer`). Los saberes los carga `scripts/saberes.gd` y eligen
  el idioma activo con fallback a `en`.
- Para alfabetos no latinos hará falta una fuente externa (ver reglas duras).

### Desbloqueo y diario

- Una puerta declara la **lista de saberes** que necesita (`requires`) y el saber del
  que pregunta (`pregunta_de`, que debe estar en esa lista). Con todos reunidos, al
  acercarse aparece un panel con una **pregunta de opción múltiple**; la puerta se abre
  recién con la respuesta correcta. Mientras falte algún saber, avisa cuáles son.
- La pregunta no castiga: si la respuesta no es, se puede abrir el diario (`J`) desde el
  mismo panel, releer el saber y reintentar. La puerta abierta queda guardada.
- El diario lista los saberes encontrados, con su tema, su texto, su dato resaltado y
  sus fuentes, y permite releerlos en cualquier momento.
- El progreso (ids recogidos, puertas abiertas, idioma) se guarda en
  `user://savegame.json`, y se escribe al recoger un saber o abrir una puerta.

## Zonas y progresión

- **Estado actual:** Bosque de Bruma (nivel inicial, *ciencias naturales*, 4 saberes) y
  Ruinas (*historia*, 2 saberes), conectadas por `puerta_ruinas_01`. La puerta
  `puerta_cueva_01` de Ruinas ya está preparada para la Cueva.
- **Planificado:** un **hub** tranquilo (el claro del zorro) del que salgan puertas a
  cada zona; Cueva = química; Montaña = filosofía.
- **Cada zona tiene una temática**, y todos sus saberes la comparten. El tema se muestra
  en el diario.
- Cada zona se define con datos, no con código especial: spawn, límites de cámara,
  suelos, repisas, props, enemigos, saberes y puertas, en un archivo por zona
  (`scripts/level_data.gd` para el bosque, `scripts/level_ruinas.gd` para Ruinas).
- **Agregar una zona:** crear `scripts/level_<zona>.gd` con las mismas constantes
  (`ZONE_ID`, `TEMA`, `SPAWN`, `CAM_BOUNDS`, `GROUNDS`, `LEDGES`, `PROPS`, `ENEMIES`,
  `SABERES`, `DOORS`), escribir sus saberes en `data/saberes/`, enlazarla en `main.gd`
  (`_nivel_destino` y el `preload`) y pasar el validador.
- Las zonas se enlazan por saberes: el dato de una zona abre la siguiente. Evitá
  dependencias circulares y comprobá que toda puerta se pueda abrir con saberes
  alcanzables.
- La rebanada vertical (bosque con 4 saberes y una puerta) ya está hecha; la Cueva es
  el próximo paso.

## Verificar antes de dar algo por terminado

1. **Compila** — un error de parseo deja la escena sin jugador y no siempre es obvio:
   ```sh
   godot --headless --path . --quit-after 20
   ```
   Buscar `SCRIPT ERROR` en la salida, no solo el código de salida. Vale en los dos
   modos: el editor no siempre reporta un parseo roto al abrir la escena.
2. **Captura** lo que tocaste. Con el editor conectado, `editor_screenshot` cubre lo
   mismo sin salir del editor. Sin editor:
   ```sh
   godot --path . --script tools/capture.gd --rendering-driver opengl3 --audio-driver Dummy
   godot --path . --script tools/capture_saberes.gd --rendering-driver opengl3 --audio-driver Dummy
   python3 tools/contact_sheet.py
   ```
   Cada script escribe su propio set en `out/`; la tabla completa de capturas está en
   los encabezados de `tools/capture*.gd`.
3. **Mirá la imagen.** No afirmes que algo "se ve bien" sin abrir el PNG
   (`out/contact_sheet.png` o el que devuelva `editor_screenshot`).
   Ojo: cada script escribe su propio set de capturas y no regenera el del otro.
4. **Si tocaste saberes o puertas**, corré el validador:
   `godot --headless --path . --script tools/validate_saberes.gd`. Comprueba ids
   únicos y estables, todos los idiomas, un solo párrafo, tema de la zona, dato por
   idioma y tipo, que la pregunta tenga enunciado y **una sola opción igual al dato**,
   al menos una fuente con URL y fecha, y que cada `desbloquea`, `requires` y
   `pregunta_de` apunte a algo existente en los archivos de nivel (`level_data.gd`,
   `level_ruinas.gd`).

## Mapa del código

| Archivo | Responsabilidad |
|---|---|
| `scripts/palette.gd` | Única fuente de color + `LEGEND` de los mapas ASCII |
| `scripts/sprite_data.gd` | Frames ASCII del zorro y del hongo |
| `scripts/world_3d.gd` | Convenciones del mundo 2.5D: plano de juego, profundidad de plataformas, cámara y conversión 2D↔3D |
| `scripts/level_data.gd` | Nivel 1 (Bosque de Bruma): spawn, límites de cámara, suelos, repisas, props, hongos, saberes y puertas |
| `scripts/level_ruinas.gd` | Nivel 2 (Ruinas): mismo formato que `level_data.gd` |
| `scripts/pixel_art.gd` | Genera texturas: sprites, terreno, bosque, sol, niebla, hojas de saber y puertas |
| `scripts/main.gd` | Mundo, parallax, cámara, ambiente, HUD, título, avisos y cambio de zona (`cargar_nivel`) |
| `scripts/player.gd` | Movimiento, coyote time, squash & stretch, polvo, sombra |
| `scripts/enemy.gd` | Patrulla del hongo, aplastamiento, esporas |
| `scripts/saberes.gd` | Autoload: carga `data/saberes/`, idioma activo, progreso guardado |
| `scripts/saber_pickup.gd` | Hoja de luz flotante que se recoge al tocarla |
| `scripts/diario.gd` | Interfaz del diario: lista, tema, texto, dato, fuentes y atribución |
| `scripts/pregunta.gd` | Panel de la pregunta de la puerta: opciones, reintento y pausa |
| `scripts/puerta.gd` | Puerta de piedra: pide sus saberes y una pregunta para abrirse |
| `i18n/ui.csv` | Textos de la interfaz en `es` y `en` (Godot los importa a `.translation`) |
| `tools/validate_saberes.gd` | Validador de datos de saberes y de sus enlaces con los niveles |
| `tools/capture*.gd` | Capturas de pantalla del juego en `out/` |

Los nodos de cada zona cuelgan del nodo `Mundo`, no directamente de `main`. Por eso no
pueden asumir que `get_parent()` es `main`: para llegar al juego (avisos, cámara,
cambio de zona) suben por los padres con el helper `_juego()` (ver `puerta.gd`).

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

- Todo se prueba con scripts `SceneTree` vía `--script`. Las capturas se generan con
  los `tools/capture*.gd` y se arman con `python3 tools/contact_sheet.py`.
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

- Un **hub** central que conecte las zonas (hoy el Bosque arranca directo y su puerta
  lleva a Ruinas).
- Puertas con **más de una pregunta** (una ronda) o variantes que pidan escribir el
  dato en vez de elegir entre opciones.
- Idiomas más allá de `es` y `en`, y fuente tipográfica para ellos.
