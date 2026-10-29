extends SceneTree
## Zorro corriendo: recorta al personaje en frames sucesivos (derecha e izquierda).
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/shot_run.gd -- NOMBRE
var _frame := 0
var _main: Node
var _tag := "run"
var _crops: Array[Image] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_tag = args[0]
	root.size = Vector2i(1152, 648)
	_main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(_main)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 60:
		Input.action_press("ui_right")
	if _frame == 160:
		Input.action_release("ui_right")
		Input.action_press("ui_left")
	if _frame > 70 and _frame < 150 and _frame % 5 == 0 and _crops.size() < 8:
		_grab()
	if _frame > 175 and _frame < 215 and _frame % 5 == 0 and _crops.size() < 12:
		_grab()
	if _frame > 220:
		_finish()
		return true
	return false

func _grab() -> void:
	var img := root.get_texture().get_image()
	var cam: Camera2D = _main.camera
	var feet: Vector2 = (_main.player.global_position - cam.global_position) * cam.zoom + Vector2(root.size) * 0.5
	_crops.append(img.get_region(Rect2i(int(feet.x) - 50, int(feet.y) - 92, 100, 100)))

func _finish() -> void:
	var n := _crops.size()
	var sheet := Image.create(100 * n, 100, false, Image.FORMAT_RGBA8)
	for i in range(n):
		sheet.blit_rect(_crops[i], Rect2i(0, 0, 100, 100), Vector2i(100 * i, 0))
	sheet.save_png("res://out/%s_strip.png" % _tag)
