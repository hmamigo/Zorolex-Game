extends SceneTree
## Capturas de la rebanada de saberes: hoja flotante, recogida, diario y puerta.
##
## Uso:
##   godot --path . --script tools/capture_saberes.gd --rendering-driver opengl3 --audio-driver Dummy
##
## Salida: out/09_saber_flotante.png ... out/15_diario_completo.png
## Arranca sin guardado previo para que las hojas esten todas en el nivel y la
## puerta cerrada. Los hongos se sacan para que el recorrido sea reproducible.

const OUT := "res://out"
const RUTA_GUARDADO := "user://savegame.json"

var frame := 0
var main: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# Progreso limpio: sin esto, un guardado de una corrida anterior deja el
	# nivel sin hojas y la puerta ya abierta.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_GUARDADO))
	# En un script SceneTree los autoloads no existen como identificador global.
	var saberes := root.get_node_or_null("Saberes")
	if saberes != null:
		saberes._recogidos.clear()
		saberes._puertas.clear()

	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)

	for hijo in main.get_children():
		if hijo.name.begins_with("Hongo"):
			hijo.queue_free()


func _process(_delta: float) -> bool:
	frame += 1

	# La hoja flotante, sin tocar.
	if frame == 330:
		_teleport(-760.0, 0.0)
	if frame == 380:
		_captura("09_saber_flotante")

	# Primera recogida y diario con un solo saber.
	if frame == 400:
		_teleport(-700.0, 0.0)
	if frame == 440:
		_captura("10_saber_recogido")
	if frame == 470:
		_pulsar_tecla(KEY_J)
	if frame == 480:
		print("diario abierto: ", main.diario.visible, "  pausa: ", paused)
	if frame == 510:
		_captura("11_diario")
	if frame == 530:
		main.diario.cerrar()

	# Cuatro saberes mas: la puerta sigue cerrada y pide el que falta.
	if frame == 560:
		_teleport(240.0, 0.0)      # luz_de_luciernaga
	if frame == 590:
		_teleport(-90.0, -96.0)    # niebla
	if frame == 620:
		_teleport(520.0, 0.0)      # helechos
	if frame == 650:
		_teleport(110.0, -180.0)   # anillo_de_hadas
	if frame == 680:
		print("recogidos con la puerta cerrada: ", _db().cantidad_recogidos(), "/", _db().total())
	if frame == 700:
		_teleport(1000.0, 0.0)
		Input.action_press("ui_right")
	if frame == 740:
		Input.action_release("ui_right")
		print("frena en la puerta: x=", main.player.global_position.x)
	if frame == 760:
		_captura("12_puerta_cerrada")

	# Sale del alcance de la puerta antes del ultimo saber: asi la puerta no se
	# abre lejos del zorro, sino cuando vuelve.
	if frame == 775:
		_teleport(930.0, 0.0)

	# Ultimo saber: al volver a la puerta se abre la pregunta, no la puerta.
	if frame == 800:
		_teleport(900.0, -250.0)   # musgo
	if frame == 830:
		print("recogidos al final: ", _db().cantidad_recogidos(), "/", _db().total())
	if frame == 850:
		_teleport(1000.0, 0.0)
	if frame == 860:
		print("pregunta visible: ", main.pregunta.visible, "  pausa: ", paused)
	if frame == 890:
		_captura("13_puerta_pregunta")
	if frame == 900:
		_responder_mal()
	if frame == 920:
		_captura("14_pregunta_error")
	if frame == 935:
		main.pregunta.elegir(main.pregunta._correcta)
	if frame == 975:
		_captura("15_puerta_abriendo")
	if frame == 1045:
		_captura("16_puerta_abierta")
	if frame == 1065:
		print("puerta abierta: ", _db().esta_abierta("puerta_ruinas_01"))
	if frame == 1075:
		_pulsar_tecla(KEY_J)
	if frame == 1115:
		_captura("17_diario_completo")
	if frame == 1135:
		main.diario.cerrar()
	if frame > 1165:
		return true
	return false


## Elige una opcion equivocada, para ver el aviso de reintento.
func _responder_mal() -> void:
	var total: int = main.pregunta._opciones.get_child_count()
	main.pregunta.elegir((main.pregunta._correcta + 1) % total)


func _db() -> Node:
	return root.get_node_or_null("Saberes")


func _teleport(x: float, y: float) -> void:
	main.player.global_position = Vector2(x, y)
	main.player.velocity = Vector2.ZERO


func _pulsar_tecla(codigo: Key) -> void:
	var abajo := InputEventKey.new()
	abajo.physical_keycode = codigo
	abajo.pressed = true
	Input.parse_input_event(abajo)
	var arriba := InputEventKey.new()
	arriba.physical_keycode = codigo
	arriba.pressed = false
	Input.parse_input_event(arriba)


func _captura(nombre: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, nombre])
	print("captura: ", nombre)
