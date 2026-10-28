extends SceneTree
## Carrera y aplastamiento del hongo, con diagnostico por consola.
##
## Uso:
##   godot --path . --script tools/capture_stomp.gd --rendering-driver opengl3 --audio-driver Dummy
##
## Salida: out/06_run.png, out/07_stomp.png, out/08_after.png
## Los prints "d=true" confirman que el hongo quedo aplastado.

const OUT := "res://out"

var frame := 0
var main: Node
var target: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 10:
		main.player.global_position = Vector2(-500.0, 0.0)
	if frame == 200:
		Input.action_press("ui_right")
	if frame == 240:
		root.get_texture().get_image().save_png("%s/06_run.png" % OUT)
	if frame == 245:
		Input.action_release("ui_right")
		main.player.global_position = Vector2(-100.0, 0.0)
		main.player.velocity = Vector2.ZERO
		for c in main.get_children():
			if c.name == "Hongo" and target == null:
				target = c
		if target != null:
			# fijamos la patrulla al minimo para que no se escape del salto
			target.patrol_left = target.global_position.x - 2.0
			target.patrol_right = target.global_position.x + 2.0
			print("target ", target.global_position, " invuln? ", main.player.get("_invuln"))
	if frame == 255:
		if target != null:
			main.player.global_position = target.global_position + Vector2(0.0, -64.0)
			main.player.velocity = Vector2(0.0, 60.0)
			print("teleport to ", main.player.global_position, " target ", target.global_position)
	if frame >= 255 and frame <= 290 and frame % 3 == 0:
		print(frame, " p=", main.player.global_position, " v=", main.player.velocity,
			" d=", target.get("_dead") if is_instance_valid(target) else "gone")
	if frame == 276:
		root.get_texture().get_image().save_png("%s/07_stomp.png" % OUT)
	if frame == 300:
		root.get_texture().get_image().save_png("%s/08_after.png" % OUT)
	if frame > 315:
		return true
	return false
