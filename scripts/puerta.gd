extends StaticBody2D
## Puerta de piedra del bosque. Se abre sola cuando el zorro reunio todos los
## saberes que pide; si le falta alguno, avisa cuales son.

const ART = preload("res://scripts/pixel_art.gd")
const P = preload("res://scripts/palette.gd")

const ANCHO := 46.0
const ALTO := 148.0
const AVISO_CADA := 4.0

## Los setea main.gd desde level_data.gd antes de agregar el nodo.
var puerta_id := ""
## Saberes que hay que tener todos para abrir la puerta.
var requires: Array = []
## Saber del que sale la pregunta; debe estar en "requires".
var pregunta_de := ""

var _abierta := false
var _jugador: Node2D
var _viajando := false
var _aviso := 0.0
var _espera := 0.0
var _preguntando := false
var _bloqueada := false
var _db: Node
var _glow: Sprite2D
var _hojas: Array[Sprite2D] = []
var _col: CollisionShape2D
var _area: Area2D


func _ready() -> void:
	add_to_group("puerta")
	_db = get_node_or_null("/root/Saberes")
	collision_layer = 1
	collision_mask = 0

	_col = CollisionShape2D.new()
	var caja := RectangleShape2D.new()
	caja.size = Vector2(ANCHO, ALTO)
	_col.shape = caja
	_col.position = Vector2(0.0, -ALTO * 0.5)
	add_child(_col)

	var art := ART.new()

	_glow = Sprite2D.new()
	_glow.name = "Luz"
	_glow.texture = art.glow_texture()
	_glow.position = Vector2(0.0, -68.0)
	_glow.scale = Vector2(7.0, 7.0)
	_glow.modulate = Color(P.GOLD.r, P.GOLD.g, P.GOLD.b, 0.12)
	_glow.z_index = -1
	var brillo := CanvasItemMaterial.new()
	brillo.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = brillo
	add_child(_glow)

	var marco := Sprite2D.new()
	marco.name = "Marco"
	marco.texture = art.door_frame()
	marco.position = Vector2(0.0, -80.0)
	marco.z_index = 2
	add_child(marco)

	var textura := art.door_leaf()
	for lado in [-1.0, 1.0]:
		var hoja := Sprite2D.new()
		hoja.name = "HojaIzq" if lado < 0.0 else "HojaDer"
		hoja.texture = textura
		hoja.flip_h = lado > 0.0
		hoja.position = Vector2(12.0 * lado, -72.0)
		hoja.z_index = 1
		add_child(hoja)
		_hojas.append(hoja)

	_area = Area2D.new()
	_area.name = "Aviso"
	_area.collision_layer = 0
	_area.collision_mask = 1
	var alcance := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 92.0
	alcance.shape = circulo
	alcance.position = Vector2(0.0, -40.0)
	_area.add_child(alcance)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

	if _db != null:
		_db.saber_recogido.connect(_on_saber_recogido)

	var ya_abierta := false
	if _db != null:
		ya_abierta = _db.esta_abierta(puerta_id)
	if ya_abierta:
		abrir(true)


func _process(delta: float) -> void:
	if _abierta or _jugador == null:
		return
	_aviso = maxf(0.0, _aviso - delta)
	_espera = maxf(0.0, _espera - delta)
	if _puede_abrir():
		if not _preguntando and not _bloqueada and _espera <= 0.0:
			_preguntar()
		return
	if _aviso <= 0.0:
		_aviso = AVISO_CADA
		_pedir_saber()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	# Puerta ya abierta (por ejemplo, guardada de una partida anterior): al
	# atravesarla se viaja a la zona siguiente. Si se acaba de abrir con la
	# respuesta correcta, main ya cambio de zona y esta puerta se libera.
	if _abierta:
		if not _viajando:
			_viajando = true
			var juego := _juego()
			if juego != null and juego.has_method("viajar_por_puerta"):
				# Diferido: cambiar de nivel dentro de un callback de fisica
				# rompe el servidor de colisiones.
				juego.call_deferred("viajar_por_puerta", puerta_id)
		return
	_jugador = body
	_aviso = 0.0
	_espera = 0.0
	_bloqueada = false


func _on_body_exited(body: Node2D) -> void:
	if body == _jugador:
		_jugador = null


func _on_saber_recogido(_id: String) -> void:
	# Si el zorro ya esta en la puerta, la pregunta aparece en cuanto tiene todo.
	if not _abierta and _jugador != null:
		_espera = 0.0


## Nodo raiz del juego (main.gd). Las puertas cuelgan del nodo "Mundo", asi que
## se sube por los padres hasta encontrar el que expone la interfaz.
func _juego() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method("mostrar_aviso"):
			return n
		n = n.get_parent()
	return null


## Abre el panel con la pregunta. La puerta se abre solo si se responde bien.
func _preguntar() -> void:
	var panel = null
	var juego := _juego()
	if juego != null:
		panel = juego.get("pregunta")
	if panel == null or not panel.has_method("abrir"):
		push_warning("Puerta '%s': no hay panel de preguntas en la escena" % puerta_id)
		_bloqueada = true
		return
	_preguntando = true
	panel.call("abrir", pregunta_de, self)


## Lo llama el panel al cerrarse. Con "reabrir" (volvio al diario) la pregunta
## reaparece sola; si no, espera a que el zorro salga y vuelva a entrar.
func pregunta_cerrada(reabrir := false) -> void:
	_preguntando = false
	_espera = 0.4 if reabrir else 0.0
	_bloqueada = not reabrir


## Verdadero cuando el zorro ya tiene todos los saberes que pide la puerta.
func _puede_abrir() -> bool:
	if _db == null or requires.is_empty():
		return false
	for id in requires:
		if not _db.tiene(str(id)):
			return false
	return true


## Titulos de los saberes que todavia faltan, en el orden de "requires".
func _faltantes() -> Array[String]:
	var lista: Array[String] = []
	if _db == null:
		return lista
	for id in requires:
		var saber := str(id)
		if _db.tiene(saber):
			continue
		var titulo := str(_db.titulo(saber))
		lista.append(titulo if not titulo.is_empty() else saber)
	return lista


func _pedir_saber() -> void:
	var faltan := _faltantes()
	if faltan.is_empty():
		return
	var texto := ""
	if faltan.size() == 1:
		texto = tr("PUERTA_PIDE_UNO") % faltan[0]
	else:
		# Hasta dos titulos: mas nombres no entran comodos en el aviso.
		var visibles := mini(faltan.size(), 2)
		var nombres := ""
		for i in visibles:
			if i > 0:
				nombres += ", "
			nombres += faltan[i]
		texto = tr("PUERTA_PIDE_VARIOS") % [faltan.size(), nombres]
		if faltan.size() > visibles:
			texto += " " + (tr("Y_MAS") % (faltan.size() - visibles))
	var juego := _juego()
	if juego != null and juego.has_method("mostrar_aviso"):
		juego.mostrar_aviso(texto)
	var t := create_tween()
	t.tween_property(_glow, "modulate:a", 0.32, 0.25)
	t.tween_property(_glow, "modulate:a", 0.12, 0.55)


func abrir(instantanea := false) -> void:
	if _abierta:
		return
	_abierta = true
	_col.set_deferred("disabled", true)

	if instantanea:
		for hoja in _hojas:
			hoja.position.y = 78.0
			hoja.modulate.a = 0.25
		_glow.modulate.a = 0.55
		return

	if _db != null:
		_db.abrir_puerta(puerta_id)

	var t := create_tween()
	t.set_parallel(true)
	for hoja in _hojas:
		t.tween_property(hoja, "position:y", 78.0, 1.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(hoja, "modulate:a", 0.25, 1.1)
	t.tween_property(_glow, "modulate:a", 0.55, 1.3).set_ease(Tween.EASE_OUT)

	var art := ART.new()
	var polvo := CPUParticles2D.new()
	polvo.one_shot = true
	polvo.emitting = true
	polvo.amount = 22
	polvo.lifetime = 0.9
	polvo.explosiveness = 0.92
	polvo.local_coords = false
	polvo.texture = art.puff_texture()
	polvo.color = Color(P.STONE_L.r, P.STONE_L.g, P.STONE_L.b, 0.85)
	polvo.direction = Vector2(0.0, -1.0)
	polvo.spread = 70.0
	polvo.initial_velocity_min = 20.0
	polvo.initial_velocity_max = 70.0
	polvo.gravity = Vector2(0.0, 140.0)
	polvo.scale_amount_min = 0.5
	polvo.scale_amount_max = 1.1
	polvo.position = Vector2(0.0, -6.0)
	polvo.z_index = 3
	add_child(polvo)

	var juego := _juego()
	if juego != null:
		if juego.has_method("camera_shake"):
			juego.camera_shake(1.8)
		if juego.has_method("mostrar_aviso"):
			juego.mostrar_aviso(tr("PUERTA_ABIERTA"))
