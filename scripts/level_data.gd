extends RefCounted
## Nivel 1 — "Bosque de Bruma": geometria, props y poblacion.
##
## Aca solo hay numeros y posiciones. Los dibujos salen de pixel_art.gd y los
## colores de palette.gd. Para reacomodar el nivel se edita este archivo;
## main.gd lo recorre y construye el mundo.
##
## Unidades: las mismas del mundo (1 unidad = 1 pixel a zoom 1).

## Donde aparece el zorro al empezar y despues de caerse.
const SPAWN := Vector2(-560.0, 0.0)

## Limites de la camara: Rect2(x, y, ancho, alto) en coordenadas de mundo.
const CAM_BOUNDS := Rect2(-900.0, -230.0, 2020.0, 250.0)

## Suelo firme. El hueco entre dos tramos consecutivos es un barranco y se
## rellena de niebla solo. Conviene que todos compartan la altura de
## superficie (position.y), si no los saltos dejan de ser parejos.
const GROUNDS := [
	Rect2(-820.0, 0.0, 570.0, 150.0),
	Rect2(-170.0, 0.0, 500.0, 150.0),
	Rect2(420.0, 0.0, 560.0, 150.0),
]

## Repisas flotantes.
const LEDGES := [
	Rect2(-660.0, -90.0, 150.0, 18.0),
	Rect2(-430.0, -176.0, 130.0, 18.0),
	Rect2(-150.0, -96.0, 150.0, 18.0),
	Rect2(60.0, -180.0, 130.0, 18.0),
	Rect2(520.0, -96.0, 130.0, 18.0),
	Rect2(720.0, -176.0, 120.0, 18.0),
	Rect2(860.0, -250.0, 100.0, 18.0),
]

## Decoracion con posicion fija. "kind" elige el dibujo en pixel_art.gd:
##   sign = cartel, log = tronco caido ("size" = cantidad de troncos).
## "z" es la capa de dibujo.
const PROPS := [
	{ "kind": "sign", "pos": Vector2(-650.0, 0.0), "z": 2 },
	{ "kind": "log", "pos": Vector2(250.0, 0.0), "z": 2, "size": 3 },
]

## Hongos. "patrol" = Vector2(izquierda, derecha) es opcional: si se omite, el
## hongo patrulla el tramo de suelo que lo contiene, con PATROL_MARGIN a cada
## lado. Si se explicita, conviene que caiga dentro de ese mismo tramo.
const ENEMIES := [
	{ "pos": Vector2(70.0, 0.0), "patrol": Vector2(-130.0, 310.0) },
	{ "pos": Vector2(610.0, 0.0), "patrol": Vector2(450.0, 935.0) },
]

## Margen que dejan los hongos al patrullar un tramo de suelo.
const PATROL_MARGIN := 40.0
