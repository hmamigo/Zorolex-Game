extends SceneTree
## Capturas base del recorrido: titulo, aparicion, medio, lejano y aire.
##
## Uso:
##   godot --path . --script tools/capture.gd --rendering-driver opengl3 --audio-driver Dummy
##
## Salida: out/01_title.png ... out/05_air.png
## Para las capturas de juego (06-08) usar tools/capture_stomp.gd: cada script
## escribe su propio set y no regenera los del otro.

const OUT := "res://out"

var frame := 0
var main: Node
var shots := [
	{"at": 60, "name": "01_title"},
	{"at": 330, "name": "02_spawn"},
	{"at": 420, "name": "03_mid"},
	{"at": 510, "name": "04_far"},
	{"at": 600, "name": "05_air"},
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	main = scene


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 320:
		main.player.global_position = Vector2(120.0, 0.0)
	if frame == 410:
		main.player.global_position = Vector2(700.0, 0.0)
	if frame == 500:
		main.player.global_position = Vector2(760.0, -190.0)
		main.player.velocity = Vector2.ZERO
	if frame == 560:
		Input.action_press("ui_right")
		Input.action_press("ui_accept")
	if frame == 590:
		Input.action_release("ui_accept")

	for s in shots:
		if frame == int(s["at"]):
			root.get_texture().get_image().save_png("%s/%s.png" % [OUT, s["name"]])
	if frame > 640:
		return true
	return false
