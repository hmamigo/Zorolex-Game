extends CanvasLayer
## Panel de la pregunta de una puerta. Opciones multiples y sin castigo: si la
## respuesta no es, se puede volver al diario a buscar el dato y reintentar.
## Pausa el juego mientras esta abierto, igual que el diario.

const P = preload("res://scripts/palette.gd")

var _raiz: Control
var _tema: Label
var _enunciado: Label
var _opciones: VBoxContainer
var _feedback: Label
var _pista: Label
var _puerta: Node
var _correcta := -1
var _contestada := false


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
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
	_tema.text = str(db.etiqueta_tema(str(db.tema(saber_id)))).to_upper()
	_enunciado.text = str(datos.get("enunciado", ""))
	_feedback.text = ""
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
		_feedback.text = tr("PREGUNTA_BIEN")
		_feedback.add_theme_color_override("font_color", P.GRASS_L)
		_silenciar_opciones()
		var puerta := _puerta
		cerrar()
		if puerta != null and puerta.has_method("abrir"):
			puerta.call("abrir")
	else:
		_feedback.text = tr("PREGUNTA_MAL")
		_feedback.add_theme_color_override("font_color", P.CAP_L)
		var t := create_tween()
		t.tween_property(_raiz, "modulate:a", 0.72, 0.08)
		t.tween_property(_raiz, "modulate:a", 1.0, 0.22)


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
	fondo.color = Color(P.INK.r, P.INK.g, P.INK.b, 0.62)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780.0, 0.0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(P.INK_SOFT.r, P.INK_SOFT.g, P.INK_SOFT.b, 0.97)
	estilo.border_color = Color(P.CREAM_D.r, P.CREAM_D.g, P.CREAM_D.b, 0.24)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(3)
	estilo.content_margin_left = 30.0
	estilo.content_margin_right = 30.0
	estilo.content_margin_top = 22.0
	estilo.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	panel.add_child(columna)

	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 14)
	columna.add_child(cabecera)

	_tema = Label.new()
	_tema.add_theme_font_size_override("font_size", 11)
	_tema.add_theme_color_override("font_color", P.GOLD)
	cabecera.add_child(_tema)

	var titulo := Label.new()
	titulo.text = tr("PREGUNTA_TITULO")
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", P.CREAM)
	cabecera.add_child(titulo)

	var relleno := Control.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(relleno)

	var cerrar := Label.new()
	cerrar.text = tr("PREGUNTA_CERRAR")
	cerrar.add_theme_font_size_override("font_size", 12)
	cerrar.add_theme_color_override("font_color", Color(P.CREAM_D.r, P.CREAM_D.g, P.CREAM_D.b, 0.7))
	cabecera.add_child(cerrar)

	var linea := ColorRect.new()
	linea.color = Color(P.CREAM_D.r, P.CREAM_D.g, P.CREAM_D.b, 0.18)
	linea.custom_minimum_size = Vector2(0.0, 1.0)
	columna.add_child(linea)

	_enunciado = Label.new()
	_enunciado.add_theme_font_size_override("font_size", 19)
	_enunciado.add_theme_color_override("font_color", P.CREAM)
	_enunciado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_enunciado.custom_minimum_size = Vector2(700.0, 54.0)
	_enunciado.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	columna.add_child(_enunciado)

	_opciones = VBoxContainer.new()
	_opciones.add_theme_constant_override("separation", 4)
	columna.add_child(_opciones)

	_feedback = Label.new()
	_feedback.custom_minimum_size = Vector2(0.0, 26.0)
	_feedback.add_theme_font_size_override("font_size", 14)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_feedback)

	_pista = Label.new()
	_pista.text = tr("PREGUNTA_PISTA")
	_pista.add_theme_font_size_override("font_size", 12)
	_pista.add_theme_color_override("font_color", Color(P.CREAM_D.r, P.CREAM_D.g, P.CREAM_D.b, 0.7))
	columna.add_child(_pista)


func _rearmar_opciones(opciones: Array) -> void:
	for hijo in _opciones.get_children():
		_opciones.remove_child(hijo)
		hijo.queue_free()
	for i in opciones.size():
		var boton := Button.new()
		boton.flat = true
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.text = "%s.  %s" % [i + 1, str(opciones[i])]
		boton.custom_minimum_size = Vector2(0.0, 38.0)
		boton.focus_mode = Control.FOCUS_ALL
		boton.add_theme_font_size_override("font_size", 17)
		boton.add_theme_color_override("font_color", Color(P.CREAM_D.r, P.CREAM_D.g, P.CREAM_D.b, 0.9))
		boton.add_theme_color_override("font_hover_color", P.CREAM)
		boton.add_theme_color_override("font_focus_color", P.GOLD)
		boton.add_theme_color_override("font_pressed_color", P.GOLD)
		boton.pressed.connect(elegir.bind(i))
		_opciones.add_child(boton)


func _silenciar_opciones() -> void:
	for hijo in _opciones.get_children():
		if hijo is Button:
			hijo.disabled = true


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
