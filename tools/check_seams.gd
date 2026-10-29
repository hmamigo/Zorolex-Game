extends SceneTree
## Mide cuanto salta el color entre la ultima y la primera columna de cada capa
## que se repite en mosaico (deberia parecerse a un salto normal entre columnas).
##   godot --headless --path . --script res://tools/check_seams.gd
const ART = preload("res://scripts/pixel_art.gd")

func _initialize() -> void:
	var art := ART.new()
	var layers := {
		"far_forest": art.far_forest(11), "valley_forest": art.valley_forest(59),
		"mid_forest": art.mid_forest(23), "near_forest": art.near_forest(37),
		"canopy_layer": art.canopy_layer(71),
	}
	for name in layers:
		var img: Image = layers[name].get_image()
		var w := img.get_width()
		var seam := _col_diff(img, w - 1, 0)
		var normal := 0.0
		var bigger := 0
		var n := 0
		for x in range(0, w - 1):
			var d := _col_diff(img, x, x + 1)
			normal += d
			n += 1
			if d > seam:
				bigger += 1
		normal /= float(n)
		print("%-14s salto en la costura: %.3f   salto normal: %.3f   ratio: %.1f   columnas con salto mayor: %d%%" % [name, seam, normal, seam / maxf(normal, 0.0001), int(100.0 * bigger / n)])
	quit()

func _col_diff(img: Image, xa: int, xb: int) -> float:
	var t := 0.0
	for y in range(img.get_height()):
		var a := img.get_pixel(xa, y)
		var b := img.get_pixel(xb, y)
		t += absf(a.r * a.a - b.r * b.a) + absf(a.g * a.a - b.g * b.a) + absf(a.b * a.a - b.b * b.a) + absf(a.a - b.a)
	return t / float(img.get_height())
