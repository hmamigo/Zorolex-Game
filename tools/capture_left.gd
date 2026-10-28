extends SceneTree
## Verifica el espejado (flip_h) cuando el zorro corre hacia la izquierda.
##
## Uso:
##   godot --path . --script tools/capture_left.gd --rendering-driver opengl3 --audio-driver Dummy
##
## Salida: out/09_left.png

const OUT := "res://out"

var frame := 0
var main: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 200:
		main.player.global_position = Vector2(600.0, -20.0)
		main.player.velocity = Vector2.ZERO
	if frame == 215:
		Input.action_press("ui_left")
	if frame == 245:
		root.get_texture().get_image().save_png("%s/09_left.png" % OUT)
		print("facing=", main.player.get("_facing"), " flip=", main.player.get("_sprite").flip_h)
	if frame == 250:
		Input.action_release("ui_left")
	if frame > 260:
		return true
	return false
