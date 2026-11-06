extends CanvasLayer
## Diario de saberes: lista de lo encontrado y detalle con el dato y las
## fuentes. Pausa el juego mientras esta abierto.
##
## La interfaz imita un libro encuadernado: marco de cuero, lomo con costura y
## hoja de pergamino. Los titulos usan Pixelify Sans y el texto Alegreya; los
## colores salen de palette.gd y los estilos de ui_style.gd.

const P = preload("res://scripts/palette.gd")
const UIS = preload("res://scripts/ui_style.gd")

signal abierto

var _raiz: Control
var _lista: VBoxContainer
var _tema: Label
var _tema_chip: PanelContainer
var _titulo: Label
var _texto: Label
var _dato: Label
var _dato_box: PanelContainer
var _fuentes_titulo: Label
var _fuentes_box: VBoxContainer
var _atribucion: Label
var _vacio: Label
var _actual := ""
var _db: Node


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()
	visible = false
	_db = get_node_or_null("/root/Saberes")
	if _db != null:
		_db.saber_recogido.connect(_on_saber_recogido)
		_db.idioma_cambiado.connect(_on_idioma_cambiado)


func _unhandled_input(event: InputEvent) -> void:
	# Durante la portada, cualquier tecla la cierra; el diario no debe abrirse.
	var juego := get_parent()
	if juego != null and juego.get("_titulo_visible") == true:
		return
	if event.is_action_pressed("diario"):
		alternar()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		cerrar()
		get_viewport().set_input_as_handled()


func alternar() -> void:
	if visible:
		cerrar()
	else:
		abrir()


func abrir() -> void:
	if visible:
		return
	_refrescar()
	visible = true
	# Primero se avisa (asi la pregunta cede la pausa) y recien despues se pausa.
	abierto.emit()
	_pausar()
	_raiz.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_raiz, "modulate:a", 1.0, 0.16).set_ease(Tween.EASE_OUT)
	_enfocar_primero()


func cerrar() -> void:
	if not visible:
		return
	visible = false
	_reanudar()


func _pausar() -> void:
	var padre := get_parent()
	if padre != null and padre.has_method("pausar"):
		padre.pausar()
	else:
		get_tree().paused = true


func _reanudar() -> void:
	var padre := get_parent()
	if padre != null and padre.has_method("reanudar"):
		padre.reanudar()
	else:
		get_tree().paused = false


# =====================================================================
#  Construccion de la interfaz
# =====================================================================
func _construir() -> void:
	_raiz = Control.new()
	_raiz.name = "Diario"
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = P.UI_SCRIM
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)

	# Marco de cuero.
	var marco := PanelContainer.new()
	marco.custom_minimum_size = Vector2(940.0, 560.0)
	marco.add_theme_stylebox_override("panel", UIS.marco())
	marco.theme = UIS.tema_scroll()
	centro.add_child(marco)

	var libro := HBoxContainer.new()
	libro.add_theme_constant_override("separation", 0)
	marco.add_child(libro)

	# Lomo con tres puntos de costura.
	var lomo := PanelContainer.new()
	lomo.custom_minimum_size = Vector2(18.0, 0.0)
	lomo.add_theme_stylebox_override("panel", UIS.lomo())
	libro.add_child(lomo)

	var costura := VBoxContainer.new()
	costura.alignment = BoxContainer.ALIGNMENT_CENTER
	costura.add_theme_constant_override("separation", 30)
	lomo.add_child(costura)
	for i in range(3):
		var punto := ColorRect.new()
		punto.color = P.GOLD
		punto.custom_minimum_size = Vector2(4.0, 4.0)
		punto.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		costura.add_child(punto)

	# Hoja de pergamino.
	var hoja := PanelContainer.new()
	hoja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hoja.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hoja.add_theme_stylebox_override("panel", UIS.hoja())
	libro.add_child(hoja)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	hoja.add_child(columna)

	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 12)
	columna.add_child(cabecera)

	var titulo := Label.new()
	titulo.text = tr("DIARIO_TITULO")
	UIS.aplicar_titulo(titulo, 34, P.UI_INK, 600)
	cabecera.add_child(titulo)

	var relleno := Control.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(relleno)

	var cerrar := Label.new()
	cerrar.text = tr("DIARIO_CERRAR")
	UIS.aplicar_cuerpo(cerrar, 13, P.UI_INK_FAINT, 400, true)
	cerrar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cabecera.add_child(cerrar)

	# Doble filete bajo la cabecera.
	var filete := VBoxContainer.new()
	filete.add_theme_constant_override("separation", 1)
	columna.add_child(filete)
	var linea_alta := ColorRect.new()
	linea_alta.color = P.GOLD
	linea_alta.custom_minimum_size = Vector2(0.0, 2.0)
	linea_alta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filete.add_child(linea_alta)
	var linea_baja := ColorRect.new()
	linea_baja.color = P.UI_INK_FAINT
	linea_baja.custom_minimum_size = Vector2(0.0, 1.0)
	linea_baja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filete.add_child(linea_baja)

	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 18)
	columna.add_child(cuerpo)

	# --- lista de saberes ------------------------------------------------
	var scroll_lista := ScrollContainer.new()
	scroll_lista.custom_minimum_size = Vector2(270.0, 0.0)
	scroll_lista.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cuerpo.add_child(scroll_lista)

	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 4)
	scroll_lista.add_child(_lista)

	var separador := ColorRect.new()
	separador.color = P.UI_PARCHMENT_DD
	separador.custom_minimum_size = Vector2(1.0, 0.0)
	cuerpo.add_child(separador)

	# --- detalle ---------------------------------------------------------
	var scroll_detalle := ScrollContainer.new()
	scroll_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_detalle.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cuerpo.add_child(scroll_detalle)

	var detalle := VBoxContainer.new()
	detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalle.add_theme_constant_override("separation", 10)
	scroll_detalle.add_child(detalle)

	_tema_chip = PanelContainer.new()
	_tema_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tema_chip.add_theme_stylebox_override("panel", UIS.chip())
	detalle.add_child(_tema_chip)

	_tema = Label.new()
	UIS.aplicar_titulo(_tema, 12, P.UI_GOLD_INK, 600)
	_tema_chip.add_child(_tema)

	_titulo = Label.new()
	UIS.aplicar_titulo(_titulo, 30, P.UI_INK, 600)
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalle.add_child(_titulo)

	_dato_box = PanelContainer.new()
	var dato_estilo := UIS.recuadro(P.UI_PARCHMENT_L)
	dato_estilo.border_color = P.GOLD
	dato_estilo.border_width_left = 3
	_dato_box.add_theme_stylebox_override("panel", dato_estilo)
	detalle.add_child(_dato_box)

	var dato_col := VBoxContainer.new()
	dato_col.add_theme_constant_override("separation", 2)
	_dato_box.add_child(dato_col)

	var dato_caption := Label.new()
	dato_caption.text = tr("DIARIO_DATO").to_upper()
	UIS.aplicar_titulo(dato_caption, 11, P.UI_GOLD_INK, 600)
	dato_col.add_child(dato_caption)

	_dato = Label.new()
	UIS.aplicar_cuerpo(_dato, 18, P.UI_INK, 500)
	_dato.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dato_col.add_child(_dato)

	_texto = Label.new()
	UIS.aplicar_cuerpo(_texto, 17, P.UI_INK_SOFT, 400)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(480.0, 0.0)
	_texto.add_theme_constant_override("line_spacing", 5)
	detalle.add_child(_texto)

	var separador_fuentes := ColorRect.new()
	separador_fuentes.color = P.UI_PARCHMENT_DD
	separador_fuentes.custom_minimum_size = Vector2(0.0, 1.0)
	detalle.add_child(separador_fuentes)

	_fuentes_titulo = Label.new()
	_fuentes_titulo.text = tr("DIARIO_FUENTES")
	UIS.aplicar_titulo(_fuentes_titulo, 13, P.UI_GOLD_INK, 600)
	detalle.add_child(_fuentes_titulo)

	_fuentes_box = VBoxContainer.new()
	_fuentes_box.add_theme_constant_override("separation", 4)
	detalle.add_child(_fuentes_box)

	_atribucion = Label.new()
	UIS.aplicar_cuerpo(_atribucion, 12, P.UI_INK_FAINT, 400, true)
	_atribucion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalle.add_child(_atribucion)

	_vacio = Label.new()
	_vacio.text = tr("DIARIO_VACIO")
	UIS.aplicar_cuerpo(_vacio, 17, P.UI_INK_SOFT, 400, true)
	_vacio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vacio.add_theme_constant_override("line_spacing", 4)
	detalle.add_child(_vacio)

	_limpiar_detalle()


# =====================================================================
#  Contenido
# =====================================================================
func _refrescar() -> void:
	for hijo in _lista.get_children():
		_lista.remove_child(hijo)
		hijo.queue_free()
	_actual = ""
	_limpiar_detalle()

	if _db == null:
		return

	var saberes: Array = _db.todos()
	var primero := ""
	for saber in saberes:
		var id := str(saber.get("id", ""))
		var encontrado: bool = _db.tiene(id)
		var nombre: String = str(_db.titulo(id))
		var boton := Button.new()
		boton.flat = false
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.custom_minimum_size = Vector2(0.0, 38.0)
		boton.text = ("›  %s" % nombre) if encontrado else ("·  %s" % tr("DIARIO_BLOQUEADO"))
		boton.disabled = not encontrado
		boton.focus_mode = Control.FOCUS_ALL if encontrado else Control.FOCUS_NONE
		boton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		boton.clip_text = true
		UIS.aplicar_boton(boton, 16, P.UI_INK_SOFT)
		boton.add_theme_color_override("font_disabled_color", P.UI_INK_FAINT)
		boton.add_theme_stylebox_override("normal", UIS.opcion("lista"))
		boton.add_theme_stylebox_override("hover", UIS.opcion("lista_hover"))
		boton.add_theme_stylebox_override("pressed", UIS.opcion("lista_activo"))
		boton.add_theme_stylebox_override("disabled", UIS.opcion("lista"))
		boton.add_theme_stylebox_override("focus", UIS.opcion("lista_activo"))
		boton.pressed.connect(_mostrar.bind(id))
		boton.focus_entered.connect(_mostrar.bind(id))
		_lista.add_child(boton)
		if primero.is_empty() and encontrado:
			primero = id

	_vacio.visible = primero.is_empty()
	if not primero.is_empty():
		_mostrar(primero)


func _mostrar(id: String) -> void:
	if _db == null or not _db.tiene(id):
		return
	_actual = id
	_titulo.text = str(_db.titulo(id))
	_titulo.visible = true

	var etiqueta: String = str(_db.etiqueta_tema(str(_db.tema(id)))).to_upper()
	_tema.text = etiqueta
	_tema_chip.visible = not etiqueta.is_empty()

	_texto.text = str(_db.texto(id))
	_texto.visible = true

	var d: Dictionary = _db.dato(id)
	var valor := str(d.get("valor", ""))
	_dato.text = valor
	_dato_box.visible = not valor.is_empty()

	_fuentes_titulo.text = tr("DIARIO_FUENTES")
	for hijo in _fuentes_box.get_children():
		_fuentes_box.remove_child(hijo)
		hijo.queue_free()

	var hay_fuentes := false
	for fuente in _db.fuentes(id):
		if typeof(fuente) != TYPE_DICTIONARY:
			continue
		var titulo := str(fuente.get("titulo", ""))
		var url := str(fuente.get("url", ""))
		var idioma := str(fuente.get("idioma", ""))
		if url.is_empty():
			continue
		var chip := LinkButton.new()
		chip.text = "↗  %s  ·  %s" % [titulo, idioma]
		chip.underline = LinkButton.UNDERLINE_MODE_NEVER
		chip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		chip.custom_minimum_size = Vector2(0.0, 28.0)
		UIS.aplicar_boton(chip, 14, P.UI_LINK)
		chip.add_theme_color_override("font_hover_color", P.UI_GOLD_INK)
		chip.add_theme_stylebox_override("normal", UIS.chip(P.UI_PARCHMENT_D, P.UI_PARCHMENT_DD))
		chip.add_theme_stylebox_override("hover", UIS.chip(P.UI_PARCHMENT_L, P.GOLD))
		chip.add_theme_stylebox_override("pressed", UIS.chip(P.UI_PARCHMENT_D, P.UI_GOLD_INK))
		chip.add_theme_stylebox_override("focus", UIS.foco())
		chip.pressed.connect(_abrir_enlace.bind(url))
		_fuentes_box.add_child(chip)
		hay_fuentes = true

	_fuentes_titulo.visible = hay_fuentes
	_fuentes_box.visible = hay_fuentes
	_atribucion.text = tr("DIARIO_ATRIBUCION")
	_atribucion.visible = true
	_vacio.visible = false


func _limpiar_detalle() -> void:
	_tema.text = ""
	_tema_chip.visible = false
	_titulo.text = ""
	_titulo.visible = false
	_texto.text = ""
	_texto.visible = false
	_dato.text = ""
	_dato_box.visible = false
	_fuentes_titulo.visible = false
	for hijo in _fuentes_box.get_children():
		_fuentes_box.remove_child(hijo)
		hijo.queue_free()
	_fuentes_box.visible = false
	_atribucion.text = ""
	_atribucion.visible = false


func _enfocar_primero() -> void:
	for hijo in _lista.get_children():
		if hijo is Button and not hijo.disabled:
			hijo.grab_focus()
			return


func _abrir_enlace(url: String) -> void:
	OS.shell_open(url)


func _on_saber_recogido(_id: String) -> void:
	if visible:
		_refrescar()


func _on_idioma_cambiado(_codigo: String) -> void:
	_refrescar()
