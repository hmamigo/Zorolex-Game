extends SceneTree
## Vuelca cada frame de zorro y hongo, ya pulidos por pixel_art.gd, en una hoja:
##   godot --headless --path . --script res://tools/dump_sprites.gd -- NOMBRE
const ART = preload("res://scripts/pixel_art.gd")

func _initialize() -> void:
	var tag := "sheet"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = args[0]
	var art := ART.new()
	var items: Array[Texture2D] = []
	var fox := art.fox_frames()
	for anim in ["idle", "run", "jump", "fall"]:
		for i in range(fox.get_frame_count(anim)):
			items.append(fox.get_frame_texture(anim, i))
	var mush := art.mushroom_frames()
	for anim in ["walk", "squash"]:
		for i in range(mush.get_frame_count(anim)):
			items.append(mush.get_frame_texture(anim, i))
	var cell := Vector2i(44, 44)
	var sheet := Image.create(cell.x * items.size(), cell.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.51, 0.59, 0.49, 1.0))
	for i in range(items.size()):
		var im := items[i].get_image()
		sheet.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()),
			Vector2i(i * cell.x + 2, cell.y - im.get_height() - 2))
	sheet.save_png("res://out/%s_sprites.png" % tag)
	quit()
