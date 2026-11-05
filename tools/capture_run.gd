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
## la camara apunta al centro del sprite, asi que los pies quedan un poco por
## debajo del centro de pantalla: por eso el offset vertical es chico
const CROP_OFFSET := Vector2i(120, 150)
const W = preload("res://scripts/world_3d.gd")

var frame := 0
var main: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 10:
		main.player.global_position = W.to_world(Vector2(-140.0, 0.0))
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
	# pantalla = proyeccion 3D de los pies del zorro
	var cam: Camera3D = main.camera
	var screen_pos := cam.unproject_position(main.player.global_position)
	var origin := Vector2i(screen_pos) - CROP_OFFSET
	# se mantiene dentro del cuadro para que todos los frames midan igual
	origin.x = clampi(origin.x, 0, img.get_width() - CROP.x)
	origin.y = clampi(origin.y, 0, img.get_height() - CROP.y)
	img.get_region(Rect2i(origin, CROP)).save_png("%s/run_%02d.png" % [OUT, index])
