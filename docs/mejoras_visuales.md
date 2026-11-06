# Backlog visual — Zorolex

Auditoría: **2026-11-06** · Base: capturas del `out/` del 2026-11-05 y código de
`scripts/main.gd`, `pixel_art.gd`, `palette.gd`, `diario.gd` y `pregunta.gd`.

Este archivo registra las mejoras visuales pendientes para no perder el hilo entre
sesiones. No es una lista de features: son cambios de arte, composición, luz,
interfaz y feedback.

## Cómo leerlo

- `[x]` hecho y verificado · `[~]` en curso · `[ ]` pendiente.
- Cada bloque indica **por qué**, **dónde** y un **criterio de aceptación**.
- Antes de cambiar ajustes de renderizado en `project.godot`, sumar un asset
  externo o modificar ids/formato de saberes, **preguntar** (ver `AGENTS.md`).
- Los colores nuevos van a `scripts/palette.gd`, nunca literales en otros archivos.

## Hecho

### [x] Bloque 1 — Tapa del terreno y sombras de decorado

**Problema:** la tapa de cada plataforma era un `PlaneMesh` con
`StandardMaterial3D` iluminado y `P.GRASS_D`/`P.MOSS`; el sol la sobreexponía a un
verde lima fluorescente, mientras la cara frontal era un sprite `unshaded`. Además,
los `Sprite3D`/`MeshInstance3D` decorativos traían `cast_shadow = ON` por defecto y
las repisas proyectaban rectángulos duros sobre el pasto.

**Cambios:**
- `pixel_art.gd`: nueva textura procedural `ground_top_texture()` (tapa de pasto,
  musgo, tierra, piedras y borde delantero) generada por plataforma.
- `pixel_art.gd`: nueva `ground_side_texture()`: reusa el dibujo frontal, pero
  rellena los bordes transparentes para cubrir la cara plana del `BoxMesh`.
- `main.gd:_create_platform`: la tapa usa esa textura con material `UNSHADED`,
  filtro nearest y `cast_shadow = OFF`; el cuerpo y la cara frontal tampoco
  proyectan sombra. Los laterales visibles (+X) tienen un `Sprite3D` con el corte
  de terreno, sin doble cara para que la cara oculta no se cuele.
- `main.gd`: se apagó `cast_shadow` en parallax, niebla de barrancos, props y
  vegetación. Quedan las sombras de las entidades (zorro y hongos) y la blob shadow.

**Verificación:** `godot --headless --path . --quit-after 20`, capturas
`tools/capture.gd`, `tools/capture_stomp.gd` y `tools/capture_saberes.gd`,
revisión visual de `out/02_spawn.png`, `out/03_mid.png`, `out/04_far.png` y
`out/06_run.png`.

### [x] Bloque 2 — Tipografía e interfaz

**Problema:** todo usaba la fuente sans por defecto de Godot; el diario y la pregunta
eran rectángulos marrones planos con esquinas redondeadas de 3 px. Era lo que más
delataba el prototipo.

**Cambios:**
- `assets/fonts/`: **Pixelify Sans** (títulos, HUD y números) y **Alegreya** (cuerpo
  e itálicas), ambas OFL con su archivo de licencia. Se registran en `CREDITS.md`.
- `scripts/ui_style.gd`: carga y cachea las fuentes con `load_dynamic_font` (sin
  depender del import del editor), helpers de tipografía y StyleBoxes compartidos
  (marco de cuero, hoja, recuadro, chip, HUD, aviso, portada, foco y scrollbars).
- `scripts/palette.gd`: sección de interfaz (`UI_SCRIM`, `UI_LEATHER`, `UI_PARCHMENT`,
  `UI_INK`, `UI_GOLD_INK`, `UI_LINK`, `UI_GOOD/BAD`, etc.). Todo color nuevo sale de
  ahí.
- `scripts/diario.gd`: cuero + lomo con costura + hoja de pergamino, esquinas rectas,
  doble filete, el dato en recuadro, fuentes como chips clicables y atribución en
  cursiva. "Aún no encontrado" subió de contraste.
- `scripts/pregunta.gd`: mismo lenguaje visual; opciones numeradas con chip, foco
  dorado y estados correcto/error con icono (no solo color). El feedback ya no se
  recorta y el cierre al acertar espera 0.55 s.
- `scripts/main.gd`: portada con cuero, filete y ornamento, despido con cualquier
  tecla y auto-cierre; contador con hoja y pulso al recoger; aviso tipo toast con
  icono; pista de controles en panel que se desvanece; el HUD se oculta durante la
  portada y las pausas.
- `scripts/pixel_art.gd`: iconos procedurales `ui_check()` / `ui_cross()`, porque las
  fuentes no traen ✓/✗.
- `i18n/ui.csv`: claves nuevas `TITULO_CAPITULO`, `TITULO_ZONA_BOSQUE`,
  `TITULO_SUBTITULO` y `TITULO_PRESIONA`.

**Pendiente de esta propuesta:** el paneo lento de cámara detrás de la portada. La
portada actual ya se apoya en el mundo vivo con un scrim; el paneo se puede sumar
sin rehacer la capa.

**Verificación:** compilación limpia y capturas `tools/capture.gd` +
`tools/capture_saberes.gd`; revisión de `out/01_title.png`, `out/02_spawn.png`,
`out/11_diario.png`, `out/13_puerta_pregunta.png`, `out/14_pregunta_error.png` y
`out/17_diario_completo.png`.

## Pendiente, por prioridad

### 1. [ ] Feedback de saberes y puertas

**Por qué:** la hoja del saber y el cartel son dos rectángulos blancos; la puerta
comunica el progreso solo con texto y su sortija dorada es tenue.

**Dónde:** `scripts/saber_pickup.gd`, `scripts/puerta.gd`, `scripts/main.gd`
(`_on_saber_recogido`).

**Propuesta:**
- Saber con silueta y color propios (dorado/cian), haz de luz y motas orbitando.
- Al recogerlo: la hoja vuela al contador, el contador pulsa y suena/brilla.
- Puerta: muescas o runas que se encienden una por saber; al abrir, luz derramándose,
  polvo y una pausa breve de cámara antes de viajar.
- Sombra de contacto suave para la puerta y los props grandes.

**Criterio:** en una captura fija se distingue saber, cartel, puerta cerrada y puerta
abierta sin leer texto.

### 2. [ ] Tema visual de Ruinas

**Por qué:** `level_ruinas.gd` reutiliza el fondo, la paleta de bosque, los carteles y
los troncos. La zona cambia de layout pero no de identidad. `_build_parallax()` corre
una sola vez y `cargar_nivel()` conserva el fondo.

**Dónde:** `scripts/level_ruinas.gd`, `scripts/main.gd` (`_build_parallax`,
`cargar_nivel`), `scripts/palette.gd`, `scripts/pixel_art.gd`.

**Propuesta:**
- `ZONE_THEME` por archivo de nivel: colores de cielo, niebla, ambiente, capas de
  fondo y tipo de suelo.
- Arte propio: arcos, columnas, piedra, menos vegetación, cielo más frío.
- Reconstruir fondo/ambiente al cambiar de zona, no solo el `Mundo`.

**Criterio:** una captura de Ruinas no se confunde con una del Bosque.

### 3. [ ] Integración 2.5D

**Por qué:** los laterales de las cajas 3D son planos y las esquinas duras; las
repisas se leen como cajas de cartón. El fondo usa filtro lineal y el primer plano
nearest; los billboards son `shaded = false` y se ven pegados.

**Dónde:** `scripts/main.gd` (`_create_platform`, `_single_layer`, `_tiled_layer`),
`scripts/world_3d.gd`, `scripts/pixel_art.gd`.

**Propuesta:**
- Laterales ya cubiertos en el bloque 1; faltan bisel/trasera, tapas de extremo
  para los cortes de terreno y una sombra de contacto para props grandes.
- Decidir el filtro: pixel art consistente (nearest + niebla/color) o fondo
  deliberadamente suave; documentarlo.
- Tinte cálido/rim light leve en billboards para integrarlos con la hora dorada.
- Cámara: pequeño adelanto horizontal y deadzone vertical, sin perder al zorro
  centrado.

**Criterio:** una repisa flotante se lee como volumen de tierra, no como un cubo
con una calcomanía frontal.

### 4. [ ] Vida del zorro y del hongo

**Por qué:** el idle del zorro es estático (`_bob = 0.0` cuando está quieto); el
hongo solo camina.

**Dónde:** `scripts/player.gd` (`_update_animation`), `scripts/sprite_data.gd`,
`scripts/pixel_art.gd`.

**Propuesta:**
- Idle con respiración, parpadeo y movimiento secundario de cola/bufanda.
- Hongo: idle con esporas sueltas y una pausa al girar.
- Aterrizajes altos: polvo extra y una micro sacudida.

**Criterio:** el zorro se ve vivo aunque el jugador no toque nada durante 5 s.

### 5. [ ] Atmósfera y post

**Por qué:** el cielo es un degradado fijo, los haces son estáticos y el vignette
(0.55) apaga las esquinas.

**Dónde:** `scripts/main.gd` (`_build_sky_quad`, `_build_screen_frame`,
`_build_parallax`, `_build_ambient`).

**Propuesta:**
- Polvo dentro de los haces, esporas cerca de los hongos, niebla baja y algún
  pájaro/hoja a ráfagas.
- Nubes y haces con movimiento muy lento; dither en el cielo para evitar bandas.
- Color grading por zona y vignette algo más suave.

**Criterio:** dos capturas separadas 5 s se sienten distintas sin que el fondo
distraiga del platforming.

### 6. [ ] Accesibilidad y legibilidad

**Por qué:** hay texto de bajo contraste y el color es el único indicador de
acierto/error en la pregunta.

**Propuesta:**
- Contraste mínimo en diario/fuentes; opción de texto más grande.
- Iconos de acierto/error además de verde/rojo.
- Opción de reducir movimiento (shake, luciérnagas, haces).
- Revisar la pista de controles sobre el pasto oscuro.

**Criterio:** se puede jugar y leer el diario sin depender del color ni de detalles
finos.

### 7. [ ] Deuda de color y assets

**Por qué:** la UI ya toma todos sus tonos de `palette.gd`, pero quedan literales en
`main.gd` para cielo, sol, viñeta y destello. La regla del proyecto pide que todo
salga de `palette.gd`; centralizarlo facilita el theming por zona y el contraste.

**Propuesta:**
- Agregar a `palette.gd` nombres para los tonos de ambiente que faltan
  (`SUN_TINT`, `SKY_*`, `VIGNETTE`, tonos del destello) y reemplazar los literales.
- Si se suman audio u otros assets, registrar licencia y autor en `CREDITS.md`.

## Verificación rápida para la próxima sesión

```sh
godot --headless --path . --quit-after 20
godot --path . --script tools/capture.gd --rendering-driver opengl3 --audio-driver Dummy
godot --path . --script tools/capture_saberes.gd --rendering-driver opengl3 --audio-driver Dummy
python3 tools/contact_sheet.py
```

Buscar `SCRIPT ERROR` en la salida, no solo el código de salida. Mirar los PNG
(`out/contact_sheet.png`, `out/02_spawn.png`, etc.) antes de dar algo por bueno.
