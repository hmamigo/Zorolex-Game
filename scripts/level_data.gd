extends RefCounted
## Nivel 1 — "Bosque de Bruma": geometria, props y poblacion.
##
## Aca solo hay numeros y posiciones. Los dibujos salen de pixel_art.gd y los
## colores de palette.gd. Para reacomodar el nivel se edita este archivo;
## main.gd lo recorre y construye el mundo.
##
## Unidades: las mismas del mundo (1 unidad = 1 pixel a zoom 1).

## Identificador de la zona. Debe coincidir con "zona" en data/saberes/*.json.
const ZONE_ID := "bosque_de_bruma"

## Tematica de la zona. Todos sus saberes declaran este mismo tema; la etiqueta
## visible sale de i18n (TEMA_<ID>).
const TEMA := "ciencias_naturales"

## Donde aparece el zorro al empezar y despues de caerse.
const SPAWN := Vector2(-560.0, 0.0)

## Limites de la camara: Rect2(x, y, ancho, alto) en coordenadas de mundo.
const CAM_BOUNDS := Rect2(-900.0, -230.0, 2900.0, 250.0)

## Suelo firme. El hueco entre dos tramos consecutivos es un barranco y se
## rellena de niebla solo. Conviene que todos compartan la altura de
## superficie (position.y), si no los saltos dejan de ser parejos.
const GROUNDS := [
	Rect2(-820.0, 0.0, 570.0, 150.0),
	Rect2(-170.0, 0.0, 500.0, 150.0),
	Rect2(420.0, 0.0, 760.0, 150.0),
	Rect2(1250.0, 0.0, 600.0, 150.0),
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
	Rect2(1350.0, -96.0, 130.0, 18.0),
	Rect2(1560.0, -176.0, 120.0, 18.0),
]

## Decoracion con posicion fija. "kind" elige el dibujo en pixel_art.gd:
##   sign = cartel, log = tronco caido ("size" = cantidad de troncos).
## "depth" es opcional: por defecto el prop queda un poco por detras del plano
## de juego (el centro de la tapa del terreno) para que no tape al zorro. Los
## valores negativos lo alejan de la camara y los positivos lo acercan.
const PROPS := [
	{ "kind": "sign", "pos": Vector2(-650.0, 0.0) },
	{ "kind": "log", "pos": Vector2(250.0, 0.0), "size": 3 },
	{ "kind": "sign", "pos": Vector2(1150.0, 0.0) },
	{ "kind": "log", "pos": Vector2(1650.0, 0.0), "size": 2 },
]

## Hongos. "patrol" = Vector2(izquierda, derecha) es opcional: si se omite, el
## hongo patrulla el tramo de suelo que lo contiene, con PATROL_MARGIN a cada
## lado. Si se explicita, conviene que caiga dentro de ese mismo tramo.
const ENEMIES := [
	{ "pos": Vector2(70.0, 0.0), "patrol": Vector2(-130.0, 310.0) },
	{ "pos": Vector2(610.0, 0.0), "patrol": Vector2(450.0, 935.0) },
	{ "pos": Vector2(1450.0, 0.0), "patrol": Vector2(1300.0, 1820.0) },
]

## Margen que dejan los hongos al patrullar un tramo de suelo.
const PATROL_MARGIN := 40.0

## Saberes repartidos por la zona. "id" debe existir en data/saberes/ y "pos"
## es la superficie donde flota la hoja de luz.
const SABERES := [
	{ "id": "micorrizas", "pos": Vector2(-700.0, 0.0) },
	{ "id": "niebla", "pos": Vector2(-90.0, -96.0) },
	{ "id": "helechos", "pos": Vector2(520.0, 0.0) },
	{ "id": "luz_de_luciernaga", "pos": Vector2(1600.0, 0.0) },
]

## Puertas. "requires" es la lista de saberes que hay que tener para abrirla,
## "pregunta_de" el saber del que pregunta (debe estar en la lista) y "pos" la
## base del arco, sobre la superficie del suelo. Se abre al responder bien.
const DOORS := [
	{ "id": "puerta_ruinas_01", "pos": Vector2(1800.0, 0.0), "requires": [
		"micorrizas",
		"niebla",
		"helechos",
		"luz_de_luciernaga",
	], "pregunta_de": "luz_de_luciernaga" },
]
