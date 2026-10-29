extends SceneTree
## Captura el juego en varias posiciones. Uso (con display virtual):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/shot.gd -- NOMBRE
var _frame := 0
var _main: Node
var _stops := [[-560.0, "a"], [-120.0, "b"], [560.0, "c"], [800.0, "d"]]
var _i := 0
var _tag := "shot"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_tag = args[0]
	root.size = Vector2i(1152, 648)
	_main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(_main)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 90 or (_frame > 90 and (_frame - 90) % 50 == 0):
		if _i > 0:
			_save(_stops[_i - 1][1])
		if _i >= _stops.size():
			return true
		var p: Node2D = _main.player
		p.global_position = Vector2(_stops[_i][0], -2.0)
		p.velocity = Vector2.ZERO
		p.set("respawn_position", p.global_position)
		print("set ", _i, " -> ", p.global_position, " frame ", _frame)
		_i += 1
	if _i == 2 and _frame < 200 and _frame % 4 == 0:
		print("f", _frame, " ", _main.player.global_position, " v=", _main.player.velocity)
	return false

func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	print(name, " player=", _main.player.global_position, " cam=", _main.camera.global_position)
	img.save_png("res://out/%s_%s.png" % [_tag, name])
