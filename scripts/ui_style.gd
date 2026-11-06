extends RefCounted
## Tipografia y estilos compartidos por HUD, diario, pregunta y portada.
##
## Las fuentes son OFL y viven en assets/fonts/ (ver CREDITS.md). Se cargan en
## tiempo de ejecucion con load_dynamic_font para que el proyecto no dependa de
## que el editor haya importado el .ttf. Pixelify Sans va en titulos y numeros;
## Alegreya, en el texto largo, donde hace falta leer comodo.
##
## Todos los colores salen de palette.gd. Los StyleBox son planos y sin radio:
## la interfaz imita un diario encuadernado, no una tarjeta moderna.

const P = preload("res://scripts/palette.gd")

const FONT_TITLE := "res://assets/fonts/PixelifySans-Variable.ttf"
const FONT_BODY := "res://assets/fonts/Alegreya-Variable.ttf"
const FONT_ITALIC := "res://assets/fonts/Alegreya-Italic-Variable.ttf"

static var _fuentes := {}


# =====================================================================
#  Fuentes
# =====================================================================
static func _cargar(ruta: String, pixel := false) -> FontFile:
	if _fuentes.has(ruta):
		return _fuentes[ruta]
	var f := FontFile.new()
	var err := f.load_dynamic_font(ruta)
	if err != OK:
		push_error("No se pudo cargar la fuente %s (error %d)" % [ruta, err])
	if pixel:
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		f.hinting = TextServer.HINTING_NONE
	else:
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	_fuentes[ruta] = f
	return f


## Pixelify Sans. El eje wght permite titulos compactos (500-600) y numeros
## firmes (600) sin cambiar de archivo.
static func fuente_titulo(peso := 600) -> Font:
	var clave := "t%d" % peso
	if not _fuentes.has(clave):
		var fv := FontVariation.new()
		fv.base_font = _cargar(FONT_TITLE, true)
		fv.variation_opentype = {"wght": float(peso)}
		_fuentes[clave] = fv
	return _fuentes[clave]


## Alegreya, en redonda o cursiva. El peso 500 sirve para datos y nombres.
static func fuente_cuerpo(peso := 400, cursiva := false) -> Font:
	var ruta := FONT_ITALIC if cursiva else FONT_BODY
	var base := _cargar(ruta, false)
	if peso == 400:
		return base
	var clave := "c%d%s" % [peso, "i" if cursiva else ""]
	if not _fuentes.has(clave):
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {"wght": float(peso)}
		_fuentes[clave] = fv
	return _fuentes[clave]


static func aplicar_titulo(l: Label, tamano: int, color: Color = P.UI_INK, peso := 600) -> void:
	l.add_theme_font_override("font", fuente_titulo(peso))
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)


static func aplicar_cuerpo(l: Label, tamano: int, color: Color = P.UI_INK_SOFT,
		peso := 400, cursiva := false) -> void:
	l.add_theme_font_override("font", fuente_cuerpo(peso, cursiva))
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)


static func aplicar_boton(b: BaseButton, tamano: int, color: Color = P.UI_INK_SOFT,
		peso := 400) -> void:
	b.add_theme_font_override("font", fuente_cuerpo(peso))
	b.add_theme_font_size_override("font_size", tamano)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", P.UI_INK)
	b.add_theme_color_override("font_focus_color", P.UI_INK)
	b.add_theme_color_override("font_pressed_color", P.UI_GOLD_INK)
	b.add_theme_color_override("font_disabled_color", P.UI_INK_FAINT)


# =====================================================================
#  Cajas
# =====================================================================
static func _sin_radio(s: StyleBoxFlat) -> void:
	s.set_corner_radius_all(0)
	s.anti_aliasing = false


## Marco exterior de cuero con doble filete dorado. El margen de contenido deja
## ver el cuero alrededor de la hoja de pergamino.
static func marco() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	_sin_radio(s)
	s.bg_color = P.UI_LEATHER
	s.border_color = P.UI_GOLD
	s.set_border_width_all(2)
	s.content_margin_left = 12.0
	s.content_margin_right = 12.0
	s.content_margin_top = 12.0
	s.content_margin_bottom = 12.0
	s.shadow_color = P.UI_SHADOW
	s.shadow_size = 16
	s.shadow_offset = Vector2(0.0, 7.0)
	return s


## Hoja interior: pergamino claro con un filete de tinta.
static func hoja() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	_sin_radio(s)
	s.bg_color = P.UI_PARCHMENT
	s.border_color = P.UI_INK
	s.set_border_width_all(1)
	s.content_margin_left = 26.0
	s.content_margin_right = 26.0
	s.content_margin_top = 20.0
	s.content_margin_bottom = 20.0
	return s


## Recuadro hundido dentro de la hoja (dato, enunciado, pista).
static func recuadro(fondo: Color = P.UI_PARCHMENT_D) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	_sin_radio(s)
	s.bg_color = fondo
	s.border_color = P.UI_PARCHMENT_DD
	s.set_border_width_all(1)
	s.content_margin_left = 14.0
	s.content_margin_right = 14.0
	s.content_margin_top = 10.0
	s.content_margin_bottom = 10.0
	return s


## Lomo del diario: una tira de cuero con costura dorada a la derecha.
static func lomo() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	_sin_radio(s)
	s.bg_color = P.UI_LEATHER_L
	s.border_color = P.UI_GOLD
	s.border_width_right = 2
	s.content_margin_left = 6.0
	s.content_margin_right = 6.0
	return s


## Fila de opcion o de la lista. Los estados de acierto/error cambian fondo y
## borde, pero el icono agrega la señal que no depende del color.
static func opcion(estado := "normal") -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	_sin_radio(s)
	var fondo := P.UI_PARCHMENT
	var borde := P.UI_PARCHMENT_DD
	var ancho := 1
	match estado:
		"hover":
			fondo = P.UI_PARCHMENT_L
			borde = P.UI_GOLD
		"pressed":
			fondo = P.UI_PARCHMENT_D
			borde = P.UI_GOLD_INK
		"correcto":
			fondo = P.UI_GOOD_BG
			borde = P.UI_GOOD
			ancho = 2
		"error":
			fondo = P.UI_BAD_BG
			borde = P.UI_BAD
			ancho = 2
		"apagado":
			fondo = P.UI_PARCHMENT_D
			borde = P.UI_PARCHMENT_DD
		"lista":
			fondo = P.UI_PARCHMENT
			borde = P.UI_PARCHMENT
		"lista_hover":
			fondo = P.UI_PARCHMENT_L
			borde = P.UI_PARCHMENT_L
		"lista_activo":
			fondo = P.UI_PARCHMENT_L
			borde = P.UI_GOLD
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(ancho)
	s.content_margin_left = 14.0
	s.content_margin_right = 14.0
	s.content_margin_top = 9.0
	s.content_margin_bottom = 9.0
	return s


## Foco del teclado: solo un marco dorado, sin tapar el fondo de la fila.
static func foco() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	_sin_radio(s)
	s.draw_center = false
	s.border_color = P.UI_GOLD
	s.set_border_width_all(2)
	s.set_expand_margin_all(1.0)
	return s


## Chip pequeno para numeros de opcion y etiquetas de tema.
static func chip(fondo: Color = P.UI_PARCHMENT_D, borde: Color = P.UI_GOLD_INK) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	_sin_radio(s)
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(1)
	s.content_margin_left = 7.0
	s.content_margin_right = 7.0
	s.content_margin_top = 2.0
	s.content_margin_bottom = 3.0
	return s


## Caja del HUD: cuero translucido para que el mundo siga viendose.
static func hud() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	_sin_radio(s)
	s.bg_color = Color(P.UI_LEATHER.r, P.UI_LEATHER.g, P.UI_LEATHER.b, 0.82)
	s.border_color = P.UI_GOLD
	s.set_border_width_all(1)
	s.content_margin_left = 11.0
	s.content_margin_right = 12.0
	s.content_margin_top = 5.0
	s.content_margin_bottom = 6.0
	s.shadow_color = P.UI_SHADOW
	s.shadow_size = 5
	s.shadow_offset = Vector2(0.0, 2.0)
	return s


## Aviso flotante: mismo cuero, con mas aire.
static func aviso() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	_sin_radio(s)
	s.bg_color = Color(P.UI_LEATHER.r, P.UI_LEATHER.g, P.UI_LEATHER.b, 0.94)
	s.border_color = P.UI_GOLD
	s.set_border_width_all(1)
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	s.content_margin_top = 9.0
	s.content_margin_bottom = 10.0
	s.shadow_color = P.UI_SHADOW
	s.shadow_size = 8
	s.shadow_offset = Vector2(0.0, 3.0)
	return s


## Portada: marco de cuero con un filete interior dibujado aparte.
static func portada() -> StyleBoxFlat:
	var s := marco()
	s.content_margin_left = 52.0
	s.content_margin_right = 52.0
	s.content_margin_top = 34.0
	s.content_margin_bottom = 34.0
	s.shadow_size = 22
	s.shadow_offset = Vector2(0.0, 9.0)
	return s


## Filete interior de la portada, sin relleno.
static func filete(color: Color = P.GOLD, ancho := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	_sin_radio(s)
	s.draw_center = false
	s.border_color = color
	s.set_border_width_all(ancho)
	s.set_expand_margin_all(0.0)
	return s


## Barra de scroll discreta: solo un trazo dorado sobre el pergamino.
static func scroll_vacio() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	_sin_radio(s)
	s.draw_center = false
	return s


static func scroll_fondo() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	_sin_radio(s)
	s.bg_color = P.UI_PARCHMENT_D
	s.content_margin_left = 2.0
	s.content_margin_right = 2.0
	return s


static func scroll_agarre(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	_sin_radio(s)
	s.bg_color = color
	s.content_margin_left = 3.0
	s.content_margin_right = 3.0
	return s


## Tema minimo para que las barras de scroll no desentonen con el pergamino.
static func tema_scroll() -> Theme:
	var t := Theme.new()
	t.set_stylebox("scroll", "VScrollBar", scroll_fondo())
	t.set_stylebox("grabber", "VScrollBar", scroll_agarre(P.UI_PARCHMENT_DD))
	t.set_stylebox("grabber_highlight", "VScrollBar", scroll_agarre(P.GOLD))
	t.set_stylebox("grabber_pressed", "VScrollBar", scroll_agarre(P.UI_GOLD_INK))
	t.set_stylebox("scroll", "HScrollBar", scroll_fondo())
	t.set_stylebox("grabber", "HScrollBar", scroll_agarre(P.UI_PARCHMENT_DD))
	t.set_stylebox("grabber_highlight", "HScrollBar", scroll_agarre(P.GOLD))
	t.set_stylebox("grabber_pressed", "HScrollBar", scroll_agarre(P.UI_GOLD_INK))
	return t
