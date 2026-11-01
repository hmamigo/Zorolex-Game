# Zorolex — La colección del saber

Un juego de plataformas 2D, tranquilo y contemplativo, hecho con Godot.

Eres un zorro que recorre bosques, ruinas, cuevas y montañas buscando **saberes**:
pequeños textos coleccionables basados en entradas reales de Wikipedia, con sus
fuentes. Cada saber esconde un dato que te servirá para abrir puertas y descubrir
nuevos lugares. Explorar, leer y recordar forman parte del juego.

> **Estado:** rebanada vertical jugable. Hoy existe el zorro y dos zonas conectadas: el
> Bosque de Bruma (cuatro saberes, *ciencias naturales*) y Ruinas (dos saberes,
> *historia*). La puerta del bosque pide sus cuatro saberes y abre el camino a Ruinas. El
> diario permite releer todo con sus fuentes. Cueva y Montaña todavía no existen.

## Características

- **Plataformas 2D** con movimiento pensado para sentirse bien: coyote time, squash &
  stretch, polvo y sombra.
- **Arte procedural**: los sprites se escriben como mapas ASCII y las texturas del
  terreno, el bosque, el sol y la niebla se generan en tiempo de ejecución a partir de
  una única paleta de colores.
- **Saberes coleccionables**: hojas de luz repartidas por el nivel; al tocarlas se
  guardan y quedan disponibles en el diario.
- **Diario**: lista de saberes encontrados, con el dato destacado, las fuentes y la
  atribución de Wikipedia. Se abre en cualquier momento y pausa el juego.
- **Puertas que se abren con conocimiento**: la puerta del bosque pide reunir sus cuatro
  saberes y, al responder la pregunta, abre el camino a Ruinas.
- **Español e inglés**: los textos de los saberes y la interfaz del diario están en los
  dos idiomas, con el idioma del sistema como punto de partida.
- **Zonas conectadas por conocimiento**: abrir la puerta de una zona lleva a la
  siguiente; Cueva y Montaña están planificadas.

## Cómo ejecutarlo

Requisitos: [Godot 4.7](https://godotengine.org/) (el proyecto usa el renderer
*GL Compatibility*).

1. Clona el repositorio:
   ```sh
   git clone https://github.com/hmamigo/Zorolex-Game.git
   ```
2. Abre Godot, pulsa **Importar** y selecciona `project.godot`.
3. Pulsa **Ejecutar** (F5). La escena principal es `scenes/Main.tscn`.

También puedes lanzarlo desde la terminal:

```sh
godot --path .
```

## Controles

| Tecla | Acción |
|---|---|
| `←` `→` | moverse |
| `Espacio` | saltar (mantener para saltar más alto) |
| `J` | abrir o cerrar el diario |
| `Esc` | cerrar el diario |

## Estructura del proyecto

| Ruta | Contenido |
|---|---|
| `scripts/` | Código del juego (jugador, enemigos, nivel, saberes, diario, puertas, arte, paleta) |
| `data/saberes/` | Un archivo JSON por saber, con sus textos en español e inglés y sus fuentes |
| `i18n/` | Traducciones de la interfaz (CSV y `.translation` generados por Godot) |
| `scenes/` | Escenas de Godot |
| `tools/` | Scripts de captura, validador de saberes y utilidades para iterar el arte |
| `addons/godot_ai/` | Plugin usado para conectar el editor con agentes de IA |
| `AGENTS.md` | Guía para agentes de IA que trabajen en el proyecto |

## Desarrollo

- Las reglas del proyecto (paleta, sprites, formato de los saberes, qué verificar antes
  de dar algo por terminado) están en [`AGENTS.md`](AGENTS.md).
- Para comprobar que compila sin abrir el editor:
  ```sh
  godot --headless --path . --quit-after 20
  ```
  Busca `SCRIPT ERROR` en la salida.
- Para validar los datos de los saberes y sus enlaces con las puertas:
  ```sh
  godot --headless --path . --script tools/validate_saberes.gd
  ```
- El progreso se guarda en `user://savegame.json` (en Linux,
  `~/.local/share/godot/app_userdata/Zorolex-Game/`). Borrarlo reinicia la partida.
- Las capturas de pantalla para revisar el arte se generan con los scripts de `tools/`
  y se guardan en `out/` (no se versiona). Las herramientas en Python necesitan
  [Pillow](https://python-pillow.org/).

## Hoja de ruta

- [x] Zorro con movimiento y animaciones
- [x] Primer nivel: Bosque de Bruma
- [x] Enemigo (hongo) con patrulla y aplastamiento
- [x] Saberes: formato de datos, recogida al tocarlos y guardado
- [x] Diario de saberes
- [x] Primera puerta: se abre al reunir los cuatro saberes del bosque
- [x] Textos de saberes y diario en español e inglés
- [x] Segunda zona: Ruinas (historia), conectada por la puerta del bosque
- [ ] Traducir toda la interfaz y admitir más idiomas
- [ ] Nuevas zonas: cueva y montaña
- [ ] Sonido y música

## Créditos y contenido

Los saberes están basados en artículos de Wikipedia, redactados con palabras propias, y
cada uno enlaza a su fuente desde el diario. El texto de Wikipedia se publica bajo
licencia [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.es). Las
fuentes de cada saber y los créditos de cualquier recurso externo están en
[`CREDITS.md`](CREDITS.md).

## Licencia

Por definir.
