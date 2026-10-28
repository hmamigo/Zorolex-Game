extends SceneTree
## Volca texturas generadas sueltas para revisarlas fuera del juego.
## Sirve para separar "esta mal la textura" de "esta mal la composicion".
##
## Uso:
##   godot --path . --script tools/dump_layers.gd --headless
##
## Salida: out/layers_*.png (fondo transparente)

const OUT := "res://out"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var art = load("res://scripts/pixel_art.gd").new()
	var tex := {
		"layers_valley": art.valley_forest(59),
		"layers_far": art.far_forest(11),
		"layers_mid": art.mid_forest(23),
		"layers_near": art.near_forest(37),
		"layers_canopy": art.canopy_layer(71),
		"layers_sun_disk": art.sun_disk(),
		"layers_sun_glow": art.sun_glow(),
	}
	for key in tex:
		tex[key].get_image().save_png("%s/%s.png" % [OUT, key])
	quit()
