extends CanvasLayer
## Diario de saberes: lista de lo encontrado y detalle con el dato y las
## fuentes. Pausa el juego mientras esta abierto.

const P = preload("res://scripts/palette.gd")

signal abierto

var _raiz: Control
var _lista: VBoxContainer
var _tema: Label
var _titulo: Label
var _texto: Label
var _dato: Label
var _fuentes: RichTextLabel
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
	fondo.color = Color(P.INK.r, P.INK.g, P.INK.b, 0.74)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880.0, 500.0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(P.INK_SOFT.r, P.INK_SOFT.g, P.INK_SOFT.b, 0.96)
	estilo.border_color = Color(P.CREAM_D.r, P.CREAM_D.g, P.CREAM_D.b, 0.24)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(3)
	estilo.content_margin_left = 26.0
	estilo.content_margin_right = 26.0
	estilo.content_margin_top = 20.0
	estilo.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	panel.add_child(columna)

	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 12)
	columna.add_child(cabecera)

	var titulo := Label.new()
	titulo.text = tr("DIARIO_TITULO")
	titulo.add_theme_font_size_override("font_size", 26)
	titulo.add_theme_color_override("font_color", P.CREAM)
	cabecera.add_child(titulo)

	var relleno := Control.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(relleno)

	var cerrar := Label.new()
	cerrar.text = tr("DIARIO_CERRAR")
	cerrar.add_theme_font_size_override("font_size", 12)
	cerrar.add_theme_color_override("font_color", Color(P.CREAM_D.r, P.CREAM_D.g, P.CREAM_D.b, 0.7))
	cabecera.add_child(cerrar)

	var linea := ColorRect.new()
	linea.color = Color(P.CREAM_D.r, P.CREAM_D.g, P.CREAM_D.b, 0.18)
	linea.custom_minimum_size = Vector2(0.0, 1.0)
	columna.add_child(linea)

	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 20)
	columna.add_child(cuerpo)

	var scroll_lista := ScrollContainer.new()
	scroll_lista.custom_minimum_size = Vector2(240.0, 0.0)
	scroll_lista.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cuerpo.add_child(scroll_lista)

	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 2)
	scroll_lista.add_child(_lista)

	var separador := ColorRect.new()
	separador.color = Color(P.CREAM_D.r, P.CREAM_D.g, P.CREAM_D.b, 0.14)
	separador.custom_minimum_size = Vector2(1.0, 0.0)
	cuerpo.add_child(separador)

	var scroll_detalle := ScrollContainer.new()
	scroll_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_detalle.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cuerpo.add_child(scroll_detalle)

	var detalle := VBoxContainer.new()
	detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalle.add_theme_constant_override("separation", 10)
	scroll_detalle.add_child(detalle)

	_tema = Label.new()
	_tema.add_theme_font_size_override("font_size", 11)
	_tema.add_theme_color_override("font_color", P.GOLD)
	detalle.add_child(_tema)

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 21)
	_titulo.add_theme_color_override("font_color", P.CREAM)
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalle.add_child(_titulo)

	_dato = Label.new()
	_dato.add_theme_font_size_override("font_size", 14)
	_dato.add_theme_color_override("font_color", P.GOLD)
	_dato.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalle.add_child(_dato)

	_texto = Label.new()
	_texto.add_theme_font_size_override("font_size", 15)
	_texto.add_theme_color_override("font_color", Color(P.CREAM_D.r, P.CREAM_D.g, P.CREAM_D.b, 0.95))
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(480.0, 0.0)
	detalle.add_child(_texto)

	_fuentes = RichTextLabel.new()
	_fuentes.bbcode_enabled = true
	_fuentes.fit_content = true
	_fuentes.scroll_active = false
	_fuentes.custom_minimum_size = Vector2(480.0, 0.0)
	_fuentes.add_theme_font_size_override("normal_font_size", 13)
	_fuentes.add_theme_font_size_override("bold_font_size", 13)
	_fuentes.add_theme_color_override("default_color", Color(P.CREAM_D.r, P.CREAM_D.g, P.CREAM_D.b, 0.8))
	_fuentes.meta_clicked.connect(_abrir_enlace)
	detalle.add_child(_fuentes)

	_vacio = Label.new()
	_vacio.text = tr("DIARIO_VACIO")
	_vacio.add_theme_font_size_override("font_size", 15)
	_vacio.add_theme_color_override("font_color", Color(P.CREAM_D.r, P.CREAM_D.g, P.CREAM_D.b, 0.65))
	_vacio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalle.add_child(_vacio)


# =====================================================================
#  Contenido
# =====================================================================
func _refrescar() -> void:
	for hijo in _lista.get_children():
		hijo.queue_free()
	_actual = ""
	_tema.text = ""
	_titulo.text = ""
	_texto.text = ""
	_dato.text = ""
	_fuentes.text = ""

	if _db == null:
		return

	var saberes: Array = _db.todos()
	var primero := ""
	for saber in saberes:
		var id := str(saber.get("id", ""))
		var encontrado: bool = _db.tiene(id)
		var boton := Button.new()
		boton.flat = true
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var nombre: String = str(_db.titulo(id))
		boton.text = nombre if encontrado else tr("DIARIO_BLOQUEADO")
		boton.disabled = not encontrado
		boton.focus_mode = Control.FOCUS_ALL if encontrado else Control.FOCUS_NONE
		boton.add_theme_font_size_override("font_size", 15)
		boton.add_theme_color_override("font_color", Color(P.CREAM_D.r, P.CREAM_D.g, P.CREAM_D.b, 0.88))
		boton.add_theme_color_override("font_hover_color", P.CREAM)
		boton.add_theme_color_override("font_focus_color", P.GOLD)
		boton.add_theme_color_override("font_pressed_color", P.GOLD)
		boton.add_theme_color_override("font_disabled_color", Color(P.CREAM_D.r, P.CREAM_D.g, P.CREAM_D.b, 0.34))
		boton.pressed.connect(_mostrar.bind(id))
		boton.focus_entered.connect(_mostrar.bind(id))
		_lista.add_child(boton)
		if primero.is_empty() and encontrado:
			primero = id

	_vacio.visible = _db.cantidad_recogidos() == 0
	if not primero.is_empty():
		_mostrar(primero)


func _mostrar(id: String) -> void:
	if _db == null or not _db.tiene(id):
		return
	_actual = id
	var nombre: String = str(_db.titulo(id))
	_titulo.text = nombre
	var etiqueta: String = str(_db.etiqueta_tema(str(_db.tema(id)))).to_upper()
	_tema.text = etiqueta
	var cuerpo: String = str(_db.texto(id))
	_texto.text = cuerpo

	var d: Dictionary = _db.dato(id)
	var valor := str(d.get("valor", ""))
	_dato.text = ("%s: %s" % [tr("DIARIO_DATO"), valor]) if not valor.is_empty() else ""

	var lineas: Array[String] = []
	lineas.append("[color=#%s][b]%s[/b][/color]" % [P.GOLD.to_html(false), tr("DIARIO_FUENTES")])
	for fuente in _db.fuentes(id):
		if typeof(fuente) != TYPE_DICTIONARY:
			continue
		var titulo := str(fuente.get("titulo", ""))
		var url := str(fuente.get("url", ""))
		var idioma := str(fuente.get("idioma", ""))
		if url.is_empty():
			continue
		lineas.append("[color=#%s]• [url=%s]%s[/url] (%s)[/color]" % [
			P.CREAM_D.to_html(false), url, titulo, idioma])
	lineas.append("")
	lineas.append("[color=#%s][i]%s[/i][/color]" % [
		P.CREAM_D.to_html(false), tr("DIARIO_ATRIBUCION")])
	_fuentes.text = "\n".join(lineas)


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
