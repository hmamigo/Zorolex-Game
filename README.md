# Zorolex — La colección del saber

Un juego de plataformas 2D, tranquilo y contemplativo, hecho con Godot.

Eres un zorro que recorre bosques, ruinas, cuevas y montañas buscando **saberes**:
pequeños textos coleccionables basados en entradas reales de Wikipedia, con sus
fuentes. Cada saber esconde un dato que te servirá para abrir puertas y descubrir
nuevos lugares. Explorar, leer y recordar forman parte del juego.

> **Estado:** en desarrollo temprano. Hoy existe el zorro, un primer nivel (el Bosque de
> Bruma) y un enemigo. El sistema de saberes todavía está por construir.

## Características

- **Plataformas 2D** con movimiento pensado para sentirse bien: coyote time, squash &
  stretch, polvo y sombra.
- **Arte procedural**: los sprites se escriben como mapas ASCII y las texturas del
  terreno, el bosque, el sol y la niebla se generan en tiempo de ejecución a partir de
  una única paleta de colores.
- **Saberes coleccionables** *(planificado)*: resúmenes de un párrafo, en varios
  idiomas y con fuentes verificables.
- **Diario** *(planificado)*: vuelve a leer lo que has encontrado cuando una puerta o un
  mecanismo lo requiera.
- **Zonas conectadas por conocimiento** *(planificado)*: el dato de un saber abre el
  camino a la siguiente zona.

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

## Estructura del proyecto

| Ruta | Contenido |
|---|---|
| `scripts/` | Código del juego (jugador, enemigos, nivel, generación de arte, paleta) |
| `scenes/` | Escenas de Godot |
| `tools/` | Scripts de captura y utilidades para iterar el arte |
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
- Las capturas de pantalla para revisar el arte se generan con los scripts de `tools/`
  y se guardan en `out/` (no se versiona). Las herramientas en Python necesitan
  [Pillow](https://python-pillow.org/).

## Hoja de ruta

- [x] Zorro con movimiento y animaciones
- [x] Primer nivel: Bosque de Bruma
- [x] Enemigo (hongo) con patrulla y aplastamiento
- [ ] Saberes: formato de datos, recogida al tocarlos y guardado
- [ ] Diario de saberes
- [ ] Puertas que se abren con los datos de los saberes
- [ ] Soporte de varios idiomas (español e inglés primero)
- [ ] Nuevas zonas: ruinas, cuevas y montañas

## Créditos y contenido

Los saberes están basados en artículos de Wikipedia, redactados con palabras propias, y
cada uno enlazará a su fuente. El texto de Wikipedia se publica bajo licencia
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.es). Los créditos de
cualquier recurso externo (fuentes tipográficas, audio, etc.) se registrarán en
`CREDITS.md`.

## Licencia

Por definir.
