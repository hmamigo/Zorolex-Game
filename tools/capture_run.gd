extends SceneTree
## Tira de frames de carrera, recortados alrededor del jugador y ya escalados
## por la camara (sirve para juzgar si el ciclo y el bob se leen a tamano real).
##
## Uso:
##   godot --path . --script tools/capture_run.gd --rendering-driver opengl3 --audio-driver Dummy
##
## Salida: out/run_00.png ... out/run_09.png (240x240 cada uno)
## Armado final: python3 tools/contact_sheet.py

const OUT := "res://out"
const CROP := Vector2i(240, 240)
## la camara mira 78 unidades por encima del jugador, asi que sus pies quedan
## bastante por debajo del centro de pantalla: por eso el offset vertical es chico
const CROP_OFFSET := Vector2i(120, 150)

var frame := 0
var main: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 10:
		main.player.global_position = Vector2(-140.0, 0.0)
	if frame == 120:
		Input.action_press("ui_right")
	if frame >= 150 and frame <= 204 and frame % 6 == 0:
		_save_around_player((frame - 150) / 6)
	if frame == 215:
		Input.action_release("ui_right")
	if frame > 230:
		return true
	return false


func _save_around_player(index: int) -> void:
	var img := root.get_texture().get_image()
	# pantalla = centro + (mundo - camara) * zoom; no depende del canvas transform
	var cam: Camera2D = main.camera
	var zoom: Vector2 = cam.zoom
	var center := Vector2(img.get_size()) * 0.5
	var world_pos: Vector2 = main.player.global_position
	var screen_pos := center + (world_pos - cam.global_position) * zoom
	var origin := Vector2i(screen_pos) - CROP_OFFSET
	# se mantiene dentro del cuadro para que todos los frames midan igual
	origin.x = clampi(origin.x, 0, img.get_width() - CROP.x)
	origin.y = clampi(origin.y, 0, img.get_height() - CROP.y)
	img.get_region(Rect2i(origin, CROP)).save_png("%s/run_%02d.png" % [OUT, index])
