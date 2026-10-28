# Capas, z-index y constantes

Datos verificados contra `scripts/main.gd`. Si algo no coincide, el código manda:
actualizá este archivo cuando muevas una capa.

## Parallax de fondo

`_single_layer(tex, factor, base, z, scale, modulate, additive)`
`_tiled_layer(tex, factor, base, z, tiles, scale, modulate)`

`factor` es cuánto acompaña a la cámara: `0` = fijo en pantalla, `1` = pegado al mundo.
La posición se recalcula como `base + cam * (1 - factor)`.

| z | Textura | factor | base | escala | notas |
|---|---|---|---|---|---|
| **-92** | `far_forest(11)` | (0.10, 0.02) | (0, -170) | 2.0 | pinos lejanos, 5 tiles |
| **-91** | `sun_glow()` | (0.02, 0.01) | (190, -62) | 3.1 | **aditivo**, halo cálido |
| **-90** | `sun_disk()` | (0.02, 0.01) | (190, -56) | 1.55 | sol en la niebla, blend normal |
| **-84** | `mid_forest(23)` | (0.19, 0.04) | (0, -178) | 2.0 | loma con pinos |
| **-81** | `light_shafts(151)` | (0.03, 0.02) | (90, -150) | 2.0 | **aditivo**, haces entre copas |
| **-80** | `valley_forest(59)` | (0.07, 0.03) | (0, -60) | 2.0 | 3 crestas + treeline |
| **-64** | `near_forest(37)` | (0.33, 0.07) | (0, -210) | 2.0 | troncos cercanos |
| **-58** | `canopy_layer(71)` | (0.55, 0.06) | (0, -100) | 2.0 | copas que enmarcan arriba |

Ojo con el orden: el **valle (-80) va delante de mid_forest (-84)** a propósito, para que
la neblina tape la base de los troncos medios. El sol (-90) queda delante del bosque
lejano (-92) y detrás de todo lo demás, así las siluetas lo recortan.

## Mundo

| z | Qué |
|---|---|
| **-30** | `pit_texture()`, el barranco oscuro detrás de los huecos |
| **-4 / -3** | sombra de contacto del zorro / del hongo |
| **-1** | polvo del jugador |
| **0** | cuerpo del suelo y las repisas |
| **1** | arbustos y helechos de sotobosque; panza de tierra de las repisas |
| **2** | pasto, flores, hongos chicos, rocas, helechos, enredaderas |
| **3** | raíces colgando en los bordes del barranco; niebla de los huecos |
| **4** | hongo (enemigo) |
| **5** | zorro |
| **6** | luciérnagas |
| **7** | hojas que caen (delante de todo) |

## Marco de pantalla

| CanvasLayer | Contenido |
|---|---|
| **16** | niebla cálida (shader, `strength` 0.115) + luz cálida aditiva superior derecha |
| **18** | matas de pasto en las esquinas + HUD (título, pista de controles, viñeta) |

## Cámara

- Ventana 1152x648, `zoom = 2.2` en ambos ejes.
- Sigue a `player + (clamp(vx * 0.22, ±78), -78)` con suavizado exponencial (`1 - exp(-7.5 * dt)`).
- Sacudida por `camera_shake(amount)`, decae a 9/s.
- Pantalla completa = `viewport_size / zoom` ≈ **524x295 unidades de mundo**.

## Pipeline de sprites ASCII

1. `scripts/sprite_data.gd` guarda cada frame como `Array[String]`, un carácter por píxel.
2. `pixel_art.gd` lee `P.LEGEND` (`scripts/palette.gd`) para convertir carácter → `Color`.
3. El resultado se arma como `ImageTexture` y se reparte en `AnimatedSprite2D.sprite_frames`.
4. **Base de 30 px:** los diseños de `tools/designs/` parten de
   `tools/designs/sprite_data.base-30.gd` (zorro frontal original), le agregan un punto de
   margen a cada lado y reemplazan la cabeza → 32 px. El zorro vigente es 32x40.
5. `tools/apply_sprite.py` rechaza cualquier ancho distinto de 30 o 32 y no escribe nada.
6. `flip_h` voltea el sprite; el arte está dibujado mirando a la derecha.

## Constantes de movimiento (`scripts/player.gd`)

`SPEED` 265 · `ACCEL` 2900 · `FRICTION` 3600 · `AIR_ACCEL` 2000 · `GRAVITY` 1250
`FALL_MULT` 1.16 · `MAX_FALL` 1000 · `JUMP_VELOCITY` -520
`COYOTE_TIME` 0.10 s · `JUMP_BUFFER` 0.12 s · bob de carrera 1.7 px
