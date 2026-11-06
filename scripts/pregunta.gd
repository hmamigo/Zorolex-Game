extends CanvasLayer
## Panel de la pregunta de una puerta. Opciones multiples y sin castigo: si la
## respuesta no es, se puede volver al diario a buscar el dato y reintentar.
## Pausa el juego mientras esta abierto, igual que el diario.
##
## Comparte el lenguaje visual del diario (cuero, pergamino, Pixelify/Alegreya)
## y agrega iconos de acierto/error para no depender solo del color.

const P = preload("res://scripts/palette.gd")
const UIS = preload("res://scripts/ui_style.gd")
const ART = preload("res://scripts/pixel_art.gd")

var _raiz: Control
var _tema: Label
var _tema_chip: PanelContainer
var _enunciado: Label
var _opciones: VBoxContainer
var _feedback_icon: TextureRect
var _feedback: Label
var _pista: Label
var _puerta: Node
var _correcta := -1
var _contestada := false
var _botones: Array[Button] = []
var _iconos: Array[TextureRect] = []
var _textos: Array[Label] = []
var _numeros: Array[PanelContainer] = []
var _tex_check: Texture2D
var _tex_cross: Texture2D


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	var art := ART.new()
	_tex_check = art.ui_check()
	_tex_cross = art.ui_cross()
	_construir()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	var juego := get_parent()
	if juego != null and juego.get("_titulo_visible") == true:
		return
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		cerrar()
		get_viewport().set_input_as_handled()


# =====================================================================
#  Apertura y cierre
# =====================================================================
## Muestra la pregunta del saber y, si se acierta, abre la puerta que la pidio.
func abrir(saber_id: String, puerta: Node) -> void:
	if visible:
		return
	var db := get_node_or_null("/root/Saberes")
	if db == null:
		return
	var datos: Dictionary = db.pregunta(saber_id)
	if datos.is_empty():
		return

	_puerta = puerta
	_correcta = int(datos.get("correcta", -1))
	_contestada = false
	var etiqueta: String = str(db.etiqueta_tema(str(db.tema(saber_id)))).to_upper()
	_tema.text = etiqueta
	_tema_chip.visible = not etiqueta.is_empty()
	_enunciado.text = str(datos.get("enunciado", ""))
	_feedback.text = ""
	_feedback_icon.visible = false
	_rearmar_opciones(datos.get("opciones", []))

	visible = true
	_pausar()
	_raiz.modulate.a = 0.0
	create_tween().tween_property(_raiz, "modulate:a", 1.0, 0.16) \
		.set_ease(Tween.EASE_OUT)
	_enfocar(0)


## Cierra y le avisa a la puerta. Con "reabrir" la pregunta vuelve sola en
## cuanto el zorro cierra el diario; sin el, espera a que salga y entre de nuevo.
func cerrar(reabrir := false) -> void:
	if not visible:
		return
	visible = false
	_reanudar()
	var puerta := _puerta
	_puerta = null
	if puerta != null and puerta.has_method("pregunta_cerrada"):
		puerta.pregunta_cerrada(reabrir)


## Lo llama main cuando se abre el diario: la pregunta espera abajo.
func ceder_al_diario() -> void:
	cerrar(true)


func elegir(indice: int) -> void:
	if not visible or _contestada:
		return
	if indice == _correcta:
		_contestada = true
		_pintar_opcion(indice, "correcto")
		_feedback_icon.texture = _tex_check
		_feedback_icon.modulate = P.UI_GOOD
		_feedback_icon.visible = true
		_feedback.text = tr("PREGUNTA_BIEN")
		_feedback.add_theme_color_override("font_color", P.UI_GOOD)
		_silenciar_opciones(indice)
		var puerta := _puerta
		var t := create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_interval(0.55)
		t.tween_callback(_abrir_puerta.bind(puerta))
	else:
		_pintar_opcion(indice, "error")
		_feedback_icon.texture = _tex_cross
		_feedback_icon.modulate = P.UI_BAD
		_feedback_icon.visible = true
		_feedback.text = tr("PREGUNTA_MAL")
		_feedback.add_theme_color_override("font_color", P.UI_BAD)
		var t := create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_interval(0.7)
		t.tween_callback(_reset_opcion.bind(indice))
		var golpe := create_tween()
		golpe.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		golpe.tween_property(_raiz, "modulate:a", 0.78, 0.08)
		golpe.tween_property(_raiz, "modulate:a", 1.0, 0.22)


func _abrir_puerta(puerta: Node) -> void:
	cerrar()
	if puerta != null and puerta.has_method("abrir"):
		puerta.call("abrir")


func _reset_opcion(indice: int) -> void:
	if not _contestada:
		_pintar_opcion(indice, "normal")


# =====================================================================
#  Construccion de la interfaz
# =====================================================================
func _construir() -> void:
	_raiz = Control.new()
	_raiz.name = "Pregunta"
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

	var marco := PanelContainer.new()
	marco.custom_minimum_size = Vector2(860.0, 0.0)
	marco.add_theme_stylebox_override("panel", UIS.marco())
	marco.theme = UIS.tema_scroll()
	centro.add_child(marco)

	var libro := HBoxContainer.new()
	libro.add_theme_constant_override("separation", 0)
	marco.add_child(libro)

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

	var hoja := PanelContainer.new()
	hoja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hoja.add_theme_stylebox_override("panel", UIS.hoja())
	libro.add_child(hoja)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	hoja.add_child(columna)

	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 12)
	columna.add_child(cabecera)

	_tema_chip = PanelContainer.new()
	_tema_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tema_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tema_chip.add_theme_stylebox_override("panel", UIS.chip())
	cabecera.add_child(_tema_chip)

	_tema = Label.new()
	UIS.aplicar_titulo(_tema, 12, P.UI_GOLD_INK, 600)
	_tema_chip.add_child(_tema)

	var titulo := Label.new()
	titulo.text = tr("PREGUNTA_TITULO")
	UIS.aplicar_titulo(titulo, 30, P.UI_INK, 600)
	cabecera.add_child(titulo)

	var relleno := Control.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(relleno)

	var cerrar := Label.new()
	cerrar.text = tr("PREGUNTA_CERRAR")
	UIS.aplicar_cuerpo(cerrar, 13, P.UI_INK_FAINT, 400, true)
	cerrar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cabecera.add_child(cerrar)

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

	var bloque := PanelContainer.new()
	bloque.add_theme_stylebox_override("panel", UIS.recuadro(P.UI_PARCHMENT_L))
	columna.add_child(bloque)

	_enunciado = Label.new()
	UIS.aplicar_cuerpo(_enunciado, 20, P.UI_INK, 500)
	_enunciado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_enunciado.custom_minimum_size = Vector2(700.0, 54.0)
	_enunciado.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_enunciado.add_theme_constant_override("line_spacing", 4)
	bloque.add_child(_enunciado)

	_opciones = VBoxContainer.new()
	_opciones.add_theme_constant_override("separation", 8)
	columna.add_child(_opciones)

	var feedback_fila := HBoxContainer.new()
	feedback_fila.add_theme_constant_override("separation", 8)
	feedback_fila.custom_minimum_size = Vector2(0.0, 30.0)
	columna.add_child(feedback_fila)

	_feedback_icon = TextureRect.new()
	_feedback_icon.custom_minimum_size = Vector2(16.0, 16.0)
	_feedback_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_feedback_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_feedback_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_feedback_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_feedback_icon.visible = false
	_feedback_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_fila.add_child(_feedback_icon)

	_feedback = Label.new()
	UIS.aplicar_cuerpo(_feedback, 15, P.UI_INK_SOFT, 500)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feedback.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	feedback_fila.add_child(_feedback)

	var separador := ColorRect.new()
	separador.color = P.UI_PARCHMENT_DD
	separador.custom_minimum_size = Vector2(0.0, 1.0)
	columna.add_child(separador)

	_pista = Label.new()
	_pista.text = tr("PREGUNTA_PISTA")
	UIS.aplicar_cuerpo(_pista, 13, P.UI_INK_FAINT, 400, true)
	_pista.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_pista)


func _rearmar_opciones(opciones: Array) -> void:
	for hijo in _opciones.get_children():
		_opciones.remove_child(hijo)
		hijo.queue_free()
	_botones.clear()
	_iconos.clear()
	_textos.clear()
	_numeros.clear()

	for i in opciones.size():
		var boton := Button.new()
		boton.flat = false
		boton.focus_mode = Control.FOCUS_ALL
		boton.custom_minimum_size = Vector2(0.0, 52.0)
		boton.add_theme_stylebox_override("normal", UIS.opcion("normal"))
		boton.add_theme_stylebox_override("hover", UIS.opcion("hover"))
		boton.add_theme_stylebox_override("pressed", UIS.opcion("pressed"))
		boton.add_theme_stylebox_override("focus", UIS.foco())
		boton.pressed.connect(elegir.bind(i))
		_opciones.add_child(boton)
		_botones.append(boton)

		var fila := HBoxContainer.new()
		fila.set_anchors_preset(Control.PRESET_FULL_RECT)
		fila.offset_left = 12.0
		fila.offset_right = -12.0
		fila.offset_top = 6.0
		fila.offset_bottom = -6.0
		fila.add_theme_constant_override("separation", 12)
		fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boton.add_child(fila)

		var numero_panel := PanelContainer.new()
		numero_panel.custom_minimum_size = Vector2(30.0, 30.0)
		numero_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		numero_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		numero_panel.add_theme_stylebox_override("panel", UIS.chip())
		fila.add_child(numero_panel)
		_numeros.append(numero_panel)

		var numero := Label.new()
		numero.text = str(i + 1)
		UIS.aplicar_titulo(numero, 16, P.UI_GOLD_INK, 600)
		numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		numero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		numero_panel.add_child(numero)

		var texto := Label.new()
		texto.text = str(opciones[i])
		texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIS.aplicar_cuerpo(texto, 18, P.UI_INK_SOFT, 400)
		fila.add_child(texto)
		_textos.append(texto)

		var icono := TextureRect.new()
		icono.custom_minimum_size = Vector2(16.0, 16.0)
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_SCALE
		icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icono.visible = false
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_child(icono)
		_iconos.append(icono)


func _pintar_opcion(indice: int, estado: String) -> void:
	if indice < 0 or indice >= _botones.size():
		return
	var boton := _botones[indice]
	boton.add_theme_stylebox_override("normal", UIS.opcion(estado))
	boton.add_theme_stylebox_override("hover", UIS.opcion(estado if estado != "normal" else "hover"))
	boton.add_theme_stylebox_override("pressed", UIS.opcion(estado if estado != "normal" else "pressed"))
	boton.add_theme_stylebox_override("disabled", UIS.opcion(estado))

	var texto := _textos[indice]
	var color := P.UI_INK_SOFT
	if estado == "correcto":
		color = P.UI_GOOD
	elif estado == "error":
		color = P.UI_BAD
	texto.add_theme_color_override("font_color", color)

	var numero_panel := _numeros[indice]
	var estilo := UIS.chip()
	if estado == "correcto":
		estilo = UIS.chip(P.UI_GOOD_BG, P.UI_GOOD)
	elif estado == "error":
		estilo = UIS.chip(P.UI_BAD_BG, P.UI_BAD)
	numero_panel.add_theme_stylebox_override("panel", estilo)

	var icono := _iconos[indice]
	if estado == "correcto":
		icono.texture = _tex_check
		icono.modulate = P.UI_GOOD
		icono.visible = true
	elif estado == "error":
		icono.texture = _tex_cross
		icono.modulate = P.UI_BAD
		icono.visible = true
	else:
		icono.visible = false


func _silenciar_opciones(correcta: int) -> void:
	for i in _botones.size():
		_botones[i].disabled = true
		if i == correcta:
			_botones[i].add_theme_stylebox_override("disabled", UIS.opcion("correcto"))
		else:
			_botones[i].add_theme_stylebox_override("disabled", UIS.opcion("apagado"))


func _enfocar(indice: int) -> void:
	var botones := _opciones.get_children()
	if indice < botones.size() and botones[indice] is Button:
		botones[indice].grab_focus()


# =====================================================================
#  Pausa compartida con el diario
# =====================================================================
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
