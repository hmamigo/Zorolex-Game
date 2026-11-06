extends Node3D
## Zorolex — mundo 2.5D: escenario 3D, cámara lateral y sprites 2D.
##
## El nivel se sigue definiendo en los archivos de zona con coordenadas 2D
## (ver scripts/world_3d.gd). Acá se construye el mundo 3D: cajas de terreno,
## props, saberes, puertas, partículas y una cámara con inclinación leve.
## El zorro y los enemigos son billboards 2D dentro de ese mundo.

const P = preload("res://scripts/palette.gd")
const UIS = preload("res://scripts/ui_style.gd")
const ART = preload("res://scripts/pixel_art.gd")
const W = preload("res://scripts/world_3d.gd")
const LEVEL_BOSQUE = preload("res://scripts/level_data.gd")
const LEVEL_RUINAS = preload("res://scripts/level_ruinas.gd")
const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const SABER_PICKUP = preload("res://scripts/saber_pickup.gd")
const PUERTA = preload("res://scripts/puerta.gd")
const DIARIO = preload("res://scripts/diario.gd")
const PREGUNTA = preload("res://scripts/pregunta.gd")

## Nivel de zona actualmente cargado (datos de geometría, saberes, puertas).
var _nivel
## Contenedor de todo lo que pertenece al mundo de la zona (plataformas,
## decoración, saberes, puertas, enemigos, partículas). Se reemplaza al cambiar
## de zona, sin tocar al jugador, la cámara ni la UI.
var mundo: Node3D

var art: ART
var player: CharacterBody3D
var camera: Camera3D
var diario: CanvasLayer
var pregunta: CanvasLayer
var _db: Node

var _layers: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _shake := 0.0
var _flash: ColorRect
var _hint: Label
var _hint_panel: PanelContainer
var _contador_panel: PanelContainer
var _saberes_label: Label
var _aviso: Label
var _aviso_panel: PanelContainer
var _aviso_tween: Tween
var _title_layer: Control
var _title_tween: Tween
var _titulo_visible := true
var _pausas := 0
## Punto al que mira la cámara. También manda el parallax del fondo.
var _cam_target := Vector3.ZERO


func _ready() -> void:
	_rng.seed = 20261028
	# El autoload se busca por ruta para no depender del identificador global:
	# los scripts SceneTree y un editor abierto antes del autoload no lo ven.
	_db = get_node_or_null("/root/Saberes")
	art = ART.new()
	RenderingServer.set_default_clear_color(P.SKY_TOP)

	# Nivel inicial: Bosque de Bruma.
	_nivel = LEVEL_BOSQUE

	mundo = Node3D.new()
	mundo.name = "Mundo"
	add_child(mundo)

	_build_environment()
	_build_parallax()
	_build_screen_frame()
	_build_world()
	_build_ambient()
	_build_player()
	_build_enemies()
	_build_saberes()
	_build_doors()
	_build_camera()
	_build_ui()
	_update_parallax()
	_validate_level()
	if _db != null:
		_db.saber_recogido.connect(_on_saber_recogido)
		_db.idioma_cambiado.connect(_on_idioma_cambiado)
		_db.puerta_abierta.connect(_on_puerta_abierta)


# =====================================================================
#  Ambiente 3D: entorno, luz y cielo
# =====================================================================
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = P.SKY_TOP
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = P.FOG
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	# Niebla por profundidad: el plano de juego queda limpio y el fondo se
	# disuelve en la bruma dorada.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 640.0
	env.fog_depth_end = 1800.0
	env.fog_depth_curve = 1.0
	env.fog_light_color = P.FOG
	env.fog_light_energy = 0.5
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "Entorno"
	we.environment = env
	add_child(we)

	var sol := DirectionalLight3D.new()
	sol.name = "Sol"
	sol.light_color = P.SUN
	sol.light_energy = 1.05
	sol.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 900.0
	add_child(sol)


## Cielo dibujado en un quad pegado a la cámara: conserva el degradado del
## juego 2D y queda siempre detrás de todas las capas 3D.
func _build_sky_quad() -> void:
	if camera == null:
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(2600.0, 1500.0)
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform vec4 top_color : source_color = vec4(0.17, 0.29, 0.27, 1.0);
uniform vec4 mid_color : source_color = vec4(0.43, 0.55, 0.48, 1.0);
uniform vec4 low_color : source_color = vec4(0.86, 0.75, 0.55, 1.0);
uniform vec4 warm_color : source_color = vec4(1.0, 0.78, 0.48, 1.0);
uniform vec4 deep_color : source_color = vec4(0.14, 0.21, 0.17, 1.0);
void fragment() {
	vec2 uv = UV;
	vec3 c = mix(top_color.rgb, mid_color.rgb, smoothstep(0.0, 0.50, uv.y));
	float glow = smoothstep(0.32, 0.63, uv.y) * (1.0 - smoothstep(0.70, 0.96, uv.y));
	c = mix(c, low_color.rgb, glow * 0.94);
	float side = smoothstep(0.10, 0.95, uv.x);
	c = mix(c, warm_color.rgb, glow * side * 0.42);
	c = mix(c, deep_color.rgb, smoothstep(0.85, 1.02, uv.y));
	float cloud = sin(uv.y * 30.0 + sin(uv.x * 5.0) * 2.2) * 0.5 + 0.5;
	cloud *= smoothstep(0.16, 0.40, uv.y) * (1.0 - smoothstep(0.60, 0.84, uv.y));
	c += cloud * 0.030 * warm_color.rgb;
	float band = sin(uv.y * 24.0 + sin(uv.x * 6.0) * 1.5) * 0.008;
	c += band;
	ALBEDO = c;
}
"""
	mat.shader = shader
	mat.set_shader_parameter("top_color", P.SKY_TOP)
	mat.set_shader_parameter("mid_color", P.SKY_MID)
	mat.set_shader_parameter("low_color", P.SKY_HORIZON)
	mat.set_shader_parameter("warm_color", P.SUN)
	mat.set_shader_parameter("deep_color", P.FOREST_FRONT)
	var mi := MeshInstance3D.new()
	mi.name = "Cielo"
	mi.mesh = quad
	mi.material_override = mat
	mi.position = Vector3(0.0, 0.0, -W.SKY_DISTANCE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(mi)


# =====================================================================
#  Capas de bosque en profundidad
# =====================================================================
func _build_parallax() -> void:
	# sol bajo entre la niebla
	_single_layer(art.sun_glow(), Vector2(0.02, 0.01), Vector2(190.0, -62.0), -900.0, 3.1,
		Color(1.0, 0.78, 0.44, 0.30), true)
	_single_layer(art.sun_disk(), Vector2(0.02, 0.01), Vector2(190.0, -56.0), -890.0, 1.55,
		Color(1.0, 1.0, 1.0, 0.95), false)

	_tiled_layer(art.far_forest(11), Vector2(0.10, 0.02), Vector2(0.0, -170.0), -600.0, 5, 2.0,
		Color(1.0, 1.0, 1.0, 0.85))
	# valle de fondo: rellena la parte baja cuando la cámara sube
	_tiled_layer(art.valley_forest(59), Vector2(0.07, 0.03), Vector2(0.0, -60.0), -500.0, 5, 2.0,
		Color(0.94, 0.98, 0.94, 1.0))
	_tiled_layer(art.mid_forest(23), Vector2(0.19, 0.04), Vector2(0.0, -178.0), -350.0, 5, 2.0,
		Color(1.0, 1.0, 1.0, 1.0))
	# haces de luz que caen entre las copas
	_single_layer(art.light_shafts(151), Vector2(0.03, 0.02), Vector2(90.0, -150.0), -300.0, 2.0,
		Color(1.0, 0.86, 0.58, 0.9), true)
	_tiled_layer(art.near_forest(37), Vector2(0.33, 1.0), Vector2(0.0, -283.0), -200.0, 5, 2.0,
		Color(0.94, 0.98, 0.94, 1.0))

	# copas que enmarcan la parte superior
	_tiled_layer(art.canopy_layer(71), Vector2(0.55, 0.06), Vector2(0.0, -100.0), -150.0, 5, 2.0,
		Color(1.0, 1.0, 1.0, 1.0))

	# barranco oscuro detrás de los huecos del suelo
	var pit := Sprite3D.new()
	pit.texture = art.pit_texture()
	pit.pixel_size = 1.0
	pit.centered = true
	pit.scale = Vector3(300.0, 1.15, 1.0)
	pit.position = Vector3(-900.0 + 4.0 * 300.0, -100.0 * 1.15, -130.0)
	pit.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	pit.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	pit.transparent = true
	pit.shaded = false
	pit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pit)


func _single_layer(tex: Texture2D, factor: Vector2, base: Vector2, z: float, scale: float,
		modulate: Color, additive := false) -> void:
	var node := Node3D.new()
	node.position = Vector3(base.x, -base.y, z)
	add_child(node)

	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = 1.0
	s.centered = true
	# Compensa la perspectiva para que la capa se vea del tamaño diseñado,
	# medida desde el plano de juego (no desde la cara frontal del terreno).
	var depth_scale := (W.CAM_DISTANCE + W.PLANE_Z - z) / W.CAM_DISTANCE
	s.scale = Vector3.ONE * scale * depth_scale
	s.position = Vector3.ZERO
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR if W.BG_SMOOTH \
		else BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.transparent = true
	s.shaded = false
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if additive:
		s.material_override = W.additive_material(tex, modulate)
	else:
		s.modulate = modulate
	node.add_child(s)
	_layers.append({"node": node, "factor": factor, "base": node.position})


func _tiled_layer(tex: Texture2D, factor: Vector2, base: Vector2, z: float, tiles: int,
		scale: float, modulate: Color) -> void:
	var node := Node3D.new()
	node.position = Vector3(base.x, -base.y, z)
	add_child(node)

	var depth_scale := (W.CAM_DISTANCE + W.PLANE_Z - z) / W.CAM_DISTANCE
	var scl := scale * depth_scale
	var tw := float(tex.get_width()) * scl
	for i in range(tiles):
		var s := Sprite3D.new()
		s.texture = tex
		s.pixel_size = 1.0
		s.centered = true
		s.scale = Vector3.ONE * scl
		s.position = Vector3((float(i) - float(tiles) * 0.5) * tw, 0.0, 0.0)
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR if W.BG_SMOOTH \
			else BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		s.transparent = true
		s.shaded = false
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.modulate = modulate
		node.add_child(s)
	_layers.append({"node": node, "factor": factor, "base": node.position})


func _update_parallax() -> void:
	for data in _layers:
		var node: Node3D = data["node"]
		var factor: Vector2 = data["factor"]
		var base: Vector3 = data["base"]
		node.position = Vector3(
			base.x + _cam_target.x * (1.0 - factor.x),
			base.y + _cam_target.y * (1.0 - factor.y),
			base.z
		)


# =====================================================================
#  Marco de pantalla (niebla + hierba en primer plano)
# =====================================================================
func _build_screen_frame() -> void:
	var fog_layer := CanvasLayer.new()
	fog_layer.layer = 16
	add_child(fog_layer)
	var haze := ColorRect.new()
	haze.set_anchors_preset(Control.PRESET_FULL_RECT)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hmat := ShaderMaterial.new()
	var hshader := Shader.new()
	hshader.code = """
shader_type canvas_item;
uniform vec4 fog_color : source_color = vec4(0.94, 0.86, 0.68, 1.0);
uniform float strength = 0.115;
void fragment() {
	float y = UV.y;
	float band = smoothstep(0.10, 0.44, y) * (1.0 - smoothstep(0.56, 0.96, y) * 0.88);
	COLOR = vec4(fog_color.rgb, band * strength);
}
"""
	hmat.shader = hshader
	haze.material = hmat
	fog_layer.add_child(haze)

	# luz cálida de pantalla: el sol tiñe la esquina superior derecha
	var warm := ColorRect.new()
	warm.set_anchors_preset(Control.PRESET_FULL_RECT)
	warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wmat := ShaderMaterial.new()
	var wshader := Shader.new()
	wshader.code = """
shader_type canvas_item;
render_mode blend_add;
uniform vec4 warm_color : source_color = vec4(1.0, 0.78, 0.48, 1.0);
uniform float strength = 0.14;
void fragment() {
	vec2 uv = UV;
	vec2 c = vec2(0.78, 0.20);
	float d = distance(uv * vec2(1.0, 1.35), c * vec2(1.0, 1.35));
	float g = smoothstep(0.74, 0.0, d);
	COLOR = vec4(warm_color.rgb, g * strength);
}
"""
	wmat.shader = wshader
	warm.material = wmat
	fog_layer.add_child(warm)

	var layer := CanvasLayer.new()
	layer.layer = 18
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var tex := art.foreground_clump(61)
	for side in [-1.0, 1.0]:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.flip_h = side > 0.0
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.anchor_top = 1.0
		rect.anchor_bottom = 1.0
		if side < 0.0:
			rect.anchor_left = 0.0
			rect.anchor_right = 0.0
			rect.offset_left = -26.0
			rect.offset_right = 274.0
		else:
			rect.anchor_left = 1.0
			rect.anchor_right = 1.0
			rect.offset_left = -274.0
			rect.offset_right = 26.0
		rect.offset_top = -220.0
		rect.offset_bottom = 0.0
		root.add_child(rect)


# =====================================================================
#  Mundo
# =====================================================================
func _build_world() -> void:
	var seed := 0
	for g in _nivel.GROUNDS:
		_create_platform(g, false, seed)
		_dress_ground(g, seed)
		seed += 1

	for l in _nivel.LEDGES:
		_create_platform(l, true, seed)
		_dress_ledge(l, seed)
		seed += 1

	# sotobosque: arbustos y helechos al pie de cada tramo de suelo
	seed = 0
	for g in _nivel.GROUNDS:
		_dress_understory(g, 71 + seed * 13)
		seed += 1

	for prop in _nivel.PROPS:
		_place_prop(prop)

	# niebla que respira en la boca de cada barranco
	var gaps := _ground_gaps()
	for i in gaps.size():
		_add_gap_mist(gaps[i].x, gaps[i].y, 77 + i * 14)


func _place_prop(prop: Dictionary) -> void:
	var pos: Vector2 = prop["pos"]
	var depth: float = prop.get("depth", W.PROP_Z)
	match prop["kind"]:
		"sign":
			_place(art.sign(), pos, depth)
		"log":
			_place(art.log(prop.get("size", 3)), pos, depth)
		_:
			push_warning("Prop desconocido en level_data.gd: %s" % prop["kind"])


## Huecos entre tramos de suelo consecutivos, como Vector2(izquierda, derecha).
func _ground_gaps() -> Array[Vector2]:
	var sorted_grounds = _nivel.GROUNDS.duplicate()
	sorted_grounds.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var gaps: Array[Vector2] = []
	for i in range(1, sorted_grounds.size()):
		var left: Rect2 = sorted_grounds[i - 1]
		var right: Rect2 = sorted_grounds[i]
		if right.position.x > left.end.x:
			gaps.append(Vector2(left.end.x, right.position.x))
	return gaps


# =====================================================================
#  Validación del nivel
# =====================================================================
## Avisa por consola de un nivel que no se puede jugar: plataformas
## solapadas, hongos patrullando fuera de su suelo o repisas que no se
## alcanzan con el salto. El alcance es conservador (calculado a la misma
## altura), así que un aviso de "no se alcanza" conviene mirarlo a mano.
func _validate_level() -> void:
	for problem in _level_problems():
		push_warning("Nivel: " + problem)


func _level_problems() -> Array[String]:
	var problems: Array[String] = []
	var boxes: Array[Rect2] = []
	boxes.append_array(_nivel.GROUNDS)
	boxes.append_array(_nivel.LEDGES)
	var ground_count: int = _nivel.GROUNDS.size()

	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if boxes[i].intersects(boxes[j]):
				problems.append("%s se solapa con %s" % [_box_name(i, ground_count), _box_name(j, ground_count)])

	var jump := _jump_envelope()
	var grounds := _sorted_grounds()
	for i in range(1, grounds.size()):
		var gap := grounds[i].position.x - grounds[i - 1].end.x
		if gap > jump.x:
			problems.append("el barranco de %.0f px en x=%.0f supera el salto (%.0f px)" % [gap, grounds[i - 1].end.x, jump.x])

	for enemy in _nivel.ENEMIES:
		var pos: Vector2 = enemy["pos"]
		var ground_index := _ground_at(pos.x)
		if ground_index < 0:
			problems.append("el hongo en x=%.0f no esta sobre ningun tramo de suelo" % pos.x)
			continue
		var ground: Rect2 = _nivel.GROUNDS[ground_index]
		if enemy.has("patrol"):
			var patrol: Vector2 = enemy["patrol"]
			var left := patrol.x
			var right := patrol.y
			if left < ground.position.x or right > ground.end.x or left > right:
				problems.append("el hongo en x=%.0f patrulla fuera de su suelo (%.0f..%.0f)" % [pos.x, ground.position.x, ground.end.x])

	for i in _unreachable_boxes():
		problems.append("%s no se alcanza desde ninguna plataforma" % _box_name(i, ground_count))

	return problems


## Alcance del salto como Vector2(horizontal a la misma altura, altura máxima).
func _jump_envelope() -> Vector2:
	var rise: float = PLAYER_SCRIPT.JUMP_VELOCITY * PLAYER_SCRIPT.JUMP_VELOCITY / (2.0 * PLAYER_SCRIPT.GRAVITY)
	var t_up: float = PLAYER_SCRIPT.JUMP_VELOCITY / PLAYER_SCRIPT.GRAVITY
	var fall_gravity: float = PLAYER_SCRIPT.GRAVITY * PLAYER_SCRIPT.FALL_MULT
	var t_down := sqrt(2.0 * rise / fall_gravity)
	return Vector2(PLAYER_SCRIPT.SPEED * (t_up + t_down), rise)


## Tramos de suelo ordenados de izquierda a derecha.
func _sorted_grounds() -> Array[Rect2]:
	var grounds: Array[Rect2] = []
	grounds.append_array(_nivel.GROUNDS)
	grounds.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	return grounds


func _ground_at(x: float) -> int:
	for i in _nivel.GROUNDS.size():
		var g: Rect2 = _nivel.GROUNDS[i]
		if x >= g.position.x and x <= g.end.x:
			return i
	return -1


## Índices de repisas inalcanzables, propagando desde el suelo hacia arriba.
func _unreachable_boxes() -> Array[int]:
	var boxes: Array[Rect2] = []
	boxes.append_array(_nivel.GROUNDS)
	boxes.append_array(_nivel.LEDGES)
	var ground_count: int = _nivel.GROUNDS.size()
	var jump := _jump_envelope()

	var reachable: Array[bool] = []
	reachable.resize(boxes.size())
	for i in boxes.size():
		reachable[i] = i < ground_count

	var changed := true
	while changed:
		changed = false
		for i in range(ground_count, boxes.size()):
			if reachable[i]:
				continue
			for j in boxes.size():
				if reachable[j] and _can_jump(boxes[j], boxes[i], jump):
					reachable[i] = true
					changed = true
					break

	var unreachable: Array[int] = []
	for i in range(ground_count, boxes.size()):
		if not reachable[i]:
			unreachable.append(i)
	return unreachable


func _can_jump(from: Rect2, to: Rect2, jump: Vector2) -> bool:
	var rise := from.position.y - to.position.y
	if rise > jump.y:
		return false
	var gap := 0.0
	if to.position.x > from.end.x:
		gap = to.position.x - from.end.x
	elif from.position.x > to.end.x:
		gap = from.position.x - to.end.x
	return gap <= jump.x


func _box_name(index: int, ground_count: int) -> String:
	if index < ground_count:
		return "el suelo %d" % index
	return "la repisa %d" % (index - ground_count)


func _add_gap_mist(left: float, right: float, seed: int) -> void:
	var s := Sprite3D.new()
	s.texture = art.mist_band(seed, 0.24)
	s.pixel_size = 1.0
	s.centered = true
	s.position = Vector3((left + right) * 0.5, 7.0, 2.0)
	s.scale = Vector3(0.62, 0.62, 1.0)
	s.modulate = Color(1.0, 1.0, 1.0, 0.7)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.transparent = true
	s.shaded = false
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mundo.add_child(s)

	var start_x := s.position.x
	var t := s.create_tween().set_loops()
	t.tween_property(s, "position:x", start_x + 9.0, 6.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(s, "position:x", start_x - 9.0, 6.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Construye una plataforma como caja 3D: colisión, cuerpo, tapa de pasto y
## la textura lateral del arte procedural en la cara frontal.
func _create_platform(rect: Rect2, floating: bool, seed: int) -> void:
	var w := rect.size.x
	var h := rect.size.y
	var depth := W.PLATFORM_DEPTH

	var body := StaticBody3D.new()
	body.name = "Plataforma"
	body.position = Vector3(rect.position.x + w * 0.5, -rect.position.y - h * 0.5, -depth * 0.5)
	body.collision_layer = 1
	body.collision_mask = 0

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, h, depth)
	col.shape = shape
	body.add_child(col)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, h, depth)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = P.STONE_D if floating else P.DIRT_D
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	# El decorado no proyecta sombra: las repisas flotantes dejaban rectangulos
	# duros sobre el pasto y competian con las blob shadows de las entidades.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)

	# tapa: textura procedural sin luz, para que el sol no la queme y case con
	# el sprite frontal (que tambien es unshaded).
	var top := PlaneMesh.new()
	top.size = Vector2(w, depth)
	var top_mat := StandardMaterial3D.new()
	top_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	top_mat.albedo_texture = art.ground_top_texture(Vector2i(int(w), int(depth)), floating, seed)
	top_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	top_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var top_mi := MeshInstance3D.new()
	top_mi.mesh = top
	top_mi.material_override = top_mat
	top_mi.position = Vector3(0.0, h * 0.5 + 0.06, 0.0)
	top_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(top_mi)

	# cara frontal con el dibujo procedural de siempre
	var visual := Sprite3D.new()
	visual.name = "Visual"
	visual.texture = art.ground_texture(Vector2i(int(w), int(h)), floating, seed)
	visual.pixel_size = 1.0
	visual.centered = true
	visual.position = Vector3(0.0, 0.0, depth * 0.5 + 0.6)
	visual.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	visual.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	visual.shaded = false
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visual)

	# laterales: con el giro leve de la camara se ve la cara lateral del
	# BoxMesh, que era un plano pelado. Se cubre con el mismo dibujo procedural
	# de la cara frontal, como si fuera el corte del terreno.
	var side_tex := art.ground_side_texture(Vector2i(int(depth), int(h)), floating, seed + 101)
	for lado in [-1.0, 1.0]:
		var side := Sprite3D.new()
		side.name = "Lateral"
		side.texture = side_tex
		side.pixel_size = 1.0
		side.centered = true
		side.position = Vector3(lado * (w * 0.5 + 0.6), 0.0, 0.0)
		side.rotation_degrees.y = 90.0 * lado
		side.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		side.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		side.shaded = false
		# La camara mira desde +X: la cara -X no debe colarse como una tira.
		side.double_sided = false
		side.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(side)

	mundo.add_child(body)


func _dress_ground(rect: Rect2, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 941 + 61
	var x := rect.position.x + 40.0
	while x < rect.end.x - 30.0:
		var roll := rng.randf()
		var z := rng.randf_range(-W.PLATFORM_DEPTH + 10.0, -8.0)
		if roll < 0.44:
			_place(art.grass_tuft(int(x) + seed), Vector2(x, rect.position.y), z, rng.randf_range(0.9, 1.25))
		elif roll < 0.62:
			_place(art.flower(int(x) + seed), Vector2(x, rect.position.y), z)
		elif roll < 0.72:
			_place(art.small_mushroom(int(x) + seed), Vector2(x, rect.position.y), z)
		elif roll < 0.80:
			_place(art.rock(int(x) + seed), Vector2(x, rect.position.y), z, rng.randf_range(0.85, 1.2))
		else:
			# Los helechos son altos: van detrás del plano de juego para no tapar
			# al zorro cuando pasa por delante.
			var fern_z := rng.randf_range(-W.PLATFORM_DEPTH + 10.0, W.PLANE_Z - 6.0)
			_place(art.fern(int(x) + seed), Vector2(x, rect.position.y), fern_z, rng.randf_range(0.95, 1.3))
		x += rng.randf_range(38.0, 78.0)

	# helechos extra: el sotobosque se siente más tupido
	var fx := rect.position.x + rng.randf_range(60.0, 110.0)
	while fx < rect.end.x - 40.0:
		var fz := rng.randf_range(-W.PLATFORM_DEPTH + 8.0, W.PLANE_Z - 6.0)
		_place(art.fern(int(fx) + seed * 5), Vector2(fx, rect.position.y), fz, rng.randf_range(1.05, 1.45))
		fx += rng.randf_range(90.0, 150.0)

	# raíces colgando en los bordes del barranco
	for side in [rect.position.x, rect.end.x]:
		for i in range(3):
			var vine := art.vine_texture(int(side) + i * 37 + seed)
			_place_hanging(vine, Vector2(side + rng.randf_range(-8.0, 8.0) + i * 4.0, rect.position.y + 2.0),
				0.6, 1.0, rng.randf_range(1.0, 1.45))


func _dress_understory(rect: Rect2, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 331 + 17
	# arbustos sueltos al pie del suelo, detrás del plano de juego
	var count := 2 + int(rect.size.x / 230.0)
	for i in range(count):
		var x := rng.randf_range(rect.position.x + 30.0, rect.end.x - 30.0)
		var z := rng.randf_range(-W.PLATFORM_DEPTH + 12.0, W.PLANE_Z - 6.0)
		_place(art.bush(seed + i * 31), Vector2(x, rect.position.y + 3.0), z, rng.randf_range(0.9, 1.35))
	# helechos altos entre las matas, también detrás del zorro
	for i in range(3):
		var x := rng.randf_range(rect.position.x + 18.0, rect.end.x - 18.0)
		var z := rng.randf_range(-W.PLATFORM_DEPTH + 10.0, W.PLANE_Z - 6.0)
		_place(art.fern(seed * 7 + i + 3), Vector2(x, rect.position.y + 1.0), z, rng.randf_range(1.2, 1.55))


func _dress_ledge(rect: Rect2, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 617 + 29
	# matas sobre la repisa
	for i in range(rng.randi_range(1, 3)):
		var x := rng.randf_range(rect.position.x + 12.0, rect.end.x - 12.0)
		var z := rng.randf_range(-W.PLATFORM_DEPTH + 10.0, -8.0)
		_place(art.grass_tuft(int(x) + seed), Vector2(x, rect.position.y), z, rng.randf_range(0.9, 1.2))
	# enredaderas colgando
	for i in range(rng.randi_range(1, 3)):
		var x := rng.randf_range(rect.position.x + 10.0, rect.end.x - 10.0)
		_place_hanging(art.vine_texture(int(x) + seed),
			Vector2(x, rect.position.y + rect.size.y - 1.0), 0.6, 1.0)

	# pedrusco de tierra que cuelga de la panza de la repisa
	if rng.randf() < 0.72:
		var beard := art.ledge_beard(int(rect.position.x) + seed)
		var bx := rng.randf_range(rect.position.x + 18.0, rect.end.x - 18.0)
		_place_hanging(beard, Vector2(bx, rect.position.y + rect.size.y - 2.0), 0.6, 1.0)


## Coloca un sprite apoyado sobre una superficie 2D (su base queda en pos.y).
func _place(tex: Texture2D, pos: Vector2, z: float, scale := 1.0) -> void:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = 1.0
	s.centered = true
	s.scale = Vector3.ONE * scale
	s.position = Vector3(pos.x, -pos.y + tex.get_height() * scale * 0.5, z)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mundo.add_child(s)


## Coloca un sprite colgante: su borde superior queda en pos.y.
func _place_hanging(tex: Texture2D, pos: Vector2, z: float, scale := 1.0, scale_y := -1.0) -> void:
	var sy := scale_y if scale_y > 0.0 else scale
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = 1.0
	s.centered = true
	s.scale = Vector3(scale, sy, 1.0)
	s.position = Vector3(pos.x, -pos.y - tex.get_height() * sy * 0.5, z)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mundo.add_child(s)


# =====================================================================
#  Ambiente
# =====================================================================
func _build_ambient() -> void:
	# luciérnagas
	var flies := CPUParticles3D.new()
	flies.name = "Luciernagas"
	flies.amount = 60
	flies.lifetime = 7.5
	flies.preprocess = 4.0
	flies.position = Vector3(80.0, 70.0, 0.0)
	flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flies.emission_box_extents = Vector3(1000.0, 110.0, 90.0)
	flies.direction = Vector3(0.0, 1.0, 0.0)
	flies.spread = 180.0
	flies.gravity = Vector3.ZERO
	flies.initial_velocity_min = 3.0
	flies.initial_velocity_max = 14.0
	flies.scale_amount_min = 0.55
	flies.scale_amount_max = 1.25
	flies.mesh = W.particle_mesh(7.0)
	flies.material_override = W.particle_material(art.glow_texture(), true)
	flies.local_coords = false
	flies.visibility_aabb = AABB(Vector3(-1200.0, -250.0, -200.0), Vector3(2400.0, 650.0, 400.0))
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.62, 0.0))
	ramp.set_color(1, Color(1.0, 0.9, 0.62, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.9, 0.62, 1.0))
	ramp.add_point(0.7, Color(1.0, 0.85, 0.55, 0.9))
	flies.color_ramp = ramp
	mundo.add_child(flies)

	# hojas que caen
	var leaves := CPUParticles3D.new()
	leaves.name = "Hojas"
	leaves.amount = 15
	leaves.lifetime = 13.0
	leaves.preprocess = 6.0
	leaves.position = Vector3(80.0, 215.0, 0.0)
	leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	leaves.emission_box_extents = Vector3(1050.0, 30.0, 100.0)
	leaves.direction = Vector3(0.0, -1.0, 0.0)
	leaves.spread = 32.0
	leaves.gravity = Vector3(5.0, -5.0, 2.0)
	leaves.initial_velocity_min = 4.0
	leaves.initial_velocity_max = 12.0
	leaves.angular_velocity_min = -55.0
	leaves.angular_velocity_max = 45.0
	leaves.scale_amount_min = 0.55
	leaves.scale_amount_max = 1.0
	leaves.mesh = W.particle_mesh(6.0)
	leaves.material_override = W.particle_material(art.leaf_particle(), false)
	leaves.local_coords = false
	leaves.visibility_aabb = AABB(Vector3(-1200.0, -250.0, -200.0), Vector3(2400.0, 650.0, 400.0))
	leaves.color = Color(1.0, 0.94, 0.8, 0.78)
	mundo.add_child(leaves)


# =====================================================================
#  Entidades
# =====================================================================
func _build_player() -> void:
	var p := CharacterBody3D.new()
	p.name = "Zorro"
	p.set_script(PLAYER_SCRIPT)
	p.position = W.to_world(_nivel.SPAWN)
	add_child(p)
	p.set("respawn_position", p.position)
	player = p


func _build_enemies() -> void:
	for enemy in _nivel.ENEMIES:
		var pos: Vector2 = enemy["pos"]
		var patrol: Vector2 = enemy.get("patrol", _patrol_for(pos))
		_spawn_enemy(pos, patrol.x, patrol.y)


## Patrulla por defecto: el tramo de suelo que contiene la posición, con margen.
func _patrol_for(pos: Vector2) -> Vector2:
	var ground_index := _ground_at(pos.x)
	if ground_index < 0:
		return Vector2(pos.x - 120.0, pos.x + 120.0)
	var g: Rect2 = _nivel.GROUNDS[ground_index]
	return Vector2(g.position.x + _nivel.PATROL_MARGIN, g.end.x - _nivel.PATROL_MARGIN)


func _spawn_enemy(pos: Vector2, left: float, right: float) -> void:
	var e := CharacterBody3D.new()
	e.name = "Hongo"
	e.set_script(load("res://scripts/enemy.gd"))
	e.position = W.to_world(pos)
	e.set("patrol_left", left)
	e.set("patrol_right", right)
	mundo.add_child(e)


# =====================================================================
#  Saberes y puertas
# =====================================================================
func _build_saberes() -> void:
	for data in _nivel.SABERES:
		var id: String = data["id"]
		if _db != null and _db.tiene(id):
			continue
		var s := Area3D.new()
		s.name = "Saber_" + id
		s.set_script(SABER_PICKUP)
		s.set("saber_id", id)
		s.position = W.to_world(data["pos"])
		mundo.add_child(s)


func _build_doors() -> void:
	for data in _nivel.DOORS:
		var d := StaticBody3D.new()
		d.name = "Puerta_" + str(data["id"])
		d.set_script(PUERTA)
		d.set("puerta_id", data["id"])
		d.set("requires", data["requires"])
		d.set("pregunta_de", str(data.get("pregunta_de", "")))
		d.position = W.to_world(data["pos"])
		mundo.add_child(d)


## Cambia al nivel de zona indicado: reemplaza el mundo (plataformas,
## decoración, saberes, puertas, enemigos) y reposiciona al jugador y la
## cámara en el nuevo spawn. El fondo, el marco de pantalla y la UI se
## conservan.
func cargar_nivel(nuevo_nivel: RefCounted) -> void:
	_nivel = nuevo_nivel
	if mundo != null:
		mundo.queue_free()
	mundo = Node3D.new()
	mundo.name = "Mundo"
	add_child(mundo)

	_build_world()
	_build_ambient()
	_build_enemies()
	_build_saberes()
	_build_doors()

	if player != null:
		var spawn := W.to_world(_nivel.SPAWN)
		player.global_position = spawn
		player.respawn_position = spawn
		player.velocity = Vector3.ZERO
	if camera != null:
		_cam_target = _target_for_camera(player.global_position)
		var forward := -camera.global_transform.basis.z
		camera.global_position = _cam_target - forward * W.CAM_DISTANCE
	_update_parallax()
	_actualizar_contador()


# =====================================================================
#  Cámara
# =====================================================================
func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camara"
	camera.fov = W.CAM_FOV
	camera.near = W.CAM_NEAR
	camera.far = W.CAM_FAR
	camera.rotation_degrees = Vector3(W.CAM_PITCH, W.CAM_YAW, 0.0)
	add_child(camera)
	camera.current = true
	_cam_target = _target_for_camera(player.global_position)
	var forward := -camera.global_transform.basis.z
	camera.global_position = _cam_target - forward * W.CAM_DISTANCE
	_build_sky_quad()


## Punto al que debe mirar la cámara: el centro del zorro (no sus pies),
## respetando los límites de la zona. Sin adelanto en la dirección de la
## carrera: el zorro queda clavado al centro mientras recorre el nivel.
func _target_for_camera(pos: Vector3) -> Vector3:
	var target := Vector3(
		pos.x,
		pos.y + PLAYER_SCRIPT.SPRITE_CENTER_Y,
		W.PLANE_Z
	)
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	var half_h := W.CAM_DISTANCE * tan(deg_to_rad(W.CAM_FOV * 0.5))
	var half_w := half_h * aspect
	var bounds: Rect2 = _nivel.CAM_BOUNDS
	var min_x := bounds.position.x + half_w
	var max_x := bounds.end.x - half_w
	if min_x > max_x:
		target.x = (bounds.position.x + bounds.end.x) * 0.5
	else:
		target.x = clampf(target.x, min_x, max_x)
	var bottom := -bounds.end.y
	var top := -bounds.position.y
	target.y = clampf(target.y, bottom, top)
	return target


func _process(delta: float) -> void:
	if player == null or camera == null:
		return

	_cam_target = _target_for_camera(player.global_position)
	var forward := -camera.global_transform.basis.z
	var desired := _cam_target - forward * W.CAM_DISTANCE
	# En horizontal la cámara sigue al zorro sin retraso: con el lerp anterior
	# se quedaba atrás y el zorro se corría del centro al caminar. En vertical
	# se conserva la suavidad para que los saltos no sacudan el mundo.
	camera.global_position = Vector3(
		desired.x,
		lerpf(camera.global_position.y, desired.y, 1.0 - exp(-7.5 * delta)),
		desired.z
	)

	_shake = move_toward(_shake, 0.0, delta * 9.0)
	if _shake > 0.01:
		camera.h_offset = _rng.randf_range(-1.0, 1.0) * _shake
		camera.v_offset = _rng.randf_range(-1.0, 1.0) * _shake
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

	_update_parallax()


func camera_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func on_player_respawned() -> void:
	camera_shake(3.2)
	if _flash != null:
		_flash.color = Color(1.0, 0.95, 0.84, 0.34)
		var t := create_tween()
		t.tween_property(_flash, "color:a", 0.0, 0.45).set_ease(Tween.EASE_OUT)


# =====================================================================
#  HUD
# =====================================================================
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	# viñeta
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vmat := ShaderMaterial.new()
	var vshader := Shader.new()
	vshader.code = """
shader_type canvas_item;
uniform float strength = 0.55;
uniform vec4 tint : source_color = vec4(0.05, 0.08, 0.06, 1.0);
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float v = smoothstep(0.52, 1.38, length(uv * vec2(1.0, 0.92)));
	COLOR = vec4(tint.rgb, v * strength);
}
"""
	vmat.shader = vshader
	vignette.material = vmat
	layer.add_child(vignette)

	# destello de reaparición
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1.0, 0.95, 0.84, 0.0)
	layer.add_child(_flash)

	_build_title(layer)
	_build_hint(layer)
	_build_progress(layer)

	var d := DIARIO.new()
	add_child(d)
	diario = d
	diario.abierto.connect(_on_diario_abierto)

	var q := PREGUNTA.new()
	add_child(q)
	pregunta = q


## El diario y la pregunta comparten la pausa; si el zorro abre el diario
## desde la pregunta, la pregunta espera abajo y vuelve al cerrarlo.
func _on_diario_abierto() -> void:
	if pregunta != null and pregunta.visible:
		pregunta.ceder_al_diario()


## Pausa compartida: cerrar una capa no reanuda el juego si la otra sigue abierta.
func pausar() -> void:
	_pausas += 1
	get_tree().paused = _pausas > 0
	_actualizar_hud()


func reanudar() -> void:
	_pausas = maxi(0, _pausas - 1)
	get_tree().paused = _pausas > 0
	_actualizar_hud()


func _build_title(layer: CanvasLayer) -> void:
	_titulo_visible = true
	_title_layer = Control.new()
	_title_layer.name = "Portada"
	_title_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_title_layer)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = P.UI_SCRIM_TITLE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_layer.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_layer.add_child(center)

	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", UIS.portada())
	center.add_child(card)

	var filete := PanelContainer.new()
	filete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var filete_estilo := UIS.filete(P.GOLD, 1)
	filete_estilo.content_margin_left = 18.0
	filete_estilo.content_margin_right = 18.0
	filete_estilo.content_margin_top = 12.0
	filete_estilo.content_margin_bottom = 12.0
	filete.add_theme_stylebox_override("panel", filete_estilo)
	card.add_child(filete)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	filete.add_child(box)

	var kicker := Label.new()
	kicker.text = tr("TITULO_CAPITULO")
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIS.aplicar_titulo(kicker, 13, P.CREAM_D, 500)
	box.add_child(kicker)

	var title := Label.new()
	title.text = tr("TITULO_ZONA_BOSQUE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIS.aplicar_titulo(title, 52, P.CREAM, 600)
	title.add_theme_color_override("font_shadow_color", P.INK)
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(title)

	var orn := HBoxContainer.new()
	orn.alignment = BoxContainer.ALIGNMENT_CENTER
	orn.add_theme_constant_override("separation", 12)
	orn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(orn)

	var rule_l := ColorRect.new()
	rule_l.color = P.GOLD
	rule_l.custom_minimum_size = Vector2(88.0, 1.0)
	rule_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orn.add_child(rule_l)

	var diamante := Label.new()
	diamante.text = "◆"
	UIS.aplicar_cuerpo(diamante, 11, P.GOLD, 400)
	diamante.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	orn.add_child(diamante)

	var rule_r := ColorRect.new()
	rule_r.color = P.GOLD
	rule_r.custom_minimum_size = Vector2(88.0, 1.0)
	rule_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orn.add_child(rule_r)

	var sub := Label.new()
	sub.text = tr("TITULO_SUBTITULO")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIS.aplicar_cuerpo(sub, 18, P.CREAM_D, 400, true)
	box.add_child(sub)

	var espacio := Control.new()
	espacio.custom_minimum_size = Vector2(0.0, 10.0)
	espacio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(espacio)

	var press := Label.new()
	press.text = tr("TITULO_PRESIONA")
	press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIS.aplicar_titulo(press, 12, P.CREAM_D, 500)
	press.modulate.a = 0.55
	box.add_child(press)

	_title_layer.modulate.a = 0.0
	_title_tween = create_tween()
	_title_tween.tween_property(_title_layer, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)
	_title_tween.tween_interval(2.2)
	_title_tween.tween_property(_title_layer, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	_title_tween.tween_callback(_terminar_titulo)

	var pulso := _title_layer.create_tween().set_loops()
	pulso.tween_property(press, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	pulso.tween_property(press, "modulate:a", 0.45, 1.0).set_trans(Tween.TRANS_SINE)


func _unhandled_input(event: InputEvent) -> void:
	if not _titulo_visible:
		return
	var dispara := false
	if event is InputEventKey:
		var tecla := event as InputEventKey
		dispara = tecla.pressed and not tecla.echo
	elif event is InputEventJoypadButton:
		dispara = (event as InputEventJoypadButton).pressed
	elif event is InputEventMouseButton:
		dispara = (event as InputEventMouseButton).pressed
	if dispara:
		_cerrar_titulo()
		get_viewport().set_input_as_handled()


func _cerrar_titulo() -> void:
	if not _titulo_visible:
		return
	_titulo_visible = false
	if _title_tween != null and _title_tween.is_valid():
		_title_tween.kill()
	if _title_layer == null:
		return
	var t := create_tween()
	t.tween_property(_title_layer, "modulate:a", 0.0, 0.22).set_ease(Tween.EASE_IN)
	t.tween_callback(_terminar_titulo)


func _terminar_titulo() -> void:
	_titulo_visible = false
	if _title_layer != null:
		_title_layer.queue_free()
		_title_layer = null
	_actualizar_hud()


func _build_hint(layer: CanvasLayer) -> void:
	var centro := CenterContainer.new()
	centro.anchor_left = 0.0
	centro.anchor_right = 1.0
	centro.anchor_top = 1.0
	centro.anchor_bottom = 1.0
	centro.offset_top = -64.0
	centro.offset_bottom = -22.0
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(centro)

	_hint_panel = PanelContainer.new()
	_hint_panel.add_theme_stylebox_override("panel", UIS.hud())
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(_hint_panel)

	_hint = Label.new()
	_hint.text = tr("PISTA_CONTROLES")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIS.aplicar_cuerpo(_hint, 15, P.CREAM, 400)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_child(_hint)

	_hint_panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(1.1)
	t.tween_property(_hint_panel, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	t.tween_interval(5.0)
	t.tween_property(_hint_panel, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)


# =====================================================================
#  Saberes en pantalla
# =====================================================================
func _build_progress(layer: CanvasLayer) -> void:
	_contador_panel = PanelContainer.new()
	_contador_panel.name = "ContadorSaberes"
	_contador_panel.position = Vector2(22.0, 14.0)
	_contador_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contador_panel.add_theme_stylebox_override("panel", UIS.hud())
	layer.add_child(_contador_panel)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	_contador_panel.add_child(fila)

	var icono := TextureRect.new()
	icono.texture = art.saber_page()
	icono.custom_minimum_size = Vector2(15.0, 19.0)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(icono)

	_saberes_label = Label.new()
	UIS.aplicar_titulo(_saberes_label, 16, P.CREAM, 500)
	_saberes_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_saberes_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(_saberes_label)
	_actualizar_contador()

	# Aviso flotante arriba, centrado y con la hoja como icono.
	var aviso_centro := CenterContainer.new()
	aviso_centro.anchor_left = 0.0
	aviso_centro.anchor_right = 1.0
	aviso_centro.offset_top = 54.0
	aviso_centro.offset_bottom = 104.0
	aviso_centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(aviso_centro)

	_aviso_panel = PanelContainer.new()
	_aviso_panel.name = "Aviso"
	_aviso_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso_panel.add_theme_stylebox_override("panel", UIS.aviso())
	aviso_centro.add_child(_aviso_panel)

	var aviso_fila := HBoxContainer.new()
	aviso_fila.add_theme_constant_override("separation", 8)
	_aviso_panel.add_child(aviso_fila)

	var aviso_icono := TextureRect.new()
	aviso_icono.texture = art.saber_page()
	aviso_icono.custom_minimum_size = Vector2(13.0, 17.0)
	aviso_icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	aviso_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	aviso_icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	aviso_icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	aviso_icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_fila.add_child(aviso_icono)

	_aviso = Label.new()
	UIS.aplicar_cuerpo(_aviso, 17, P.CREAM, 500)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_fila.add_child(_aviso)

	_aviso_panel.modulate.a = 0.0
	_actualizar_hud()


## El HUD se retira durante la portada y mientras el diario o la pregunta
## tienen el juego en pausa. Al volver, reaparece sin tapar el mundo.
func _actualizar_hud() -> void:
	var oculto := _titulo_visible or _pausas > 0
	if _contador_panel != null:
		_contador_panel.visible = not oculto
	if _aviso_panel != null:
		_aviso_panel.visible = not oculto
	if _hint_panel != null:
		_hint_panel.visible = not oculto


func _actualizar_contador() -> void:
	if _saberes_label == null or _db == null or _nivel == null:
		return
	# Contar solo los saberes que realmente están en este nivel, no todos los
	# archivos de data/saberes/ que compartan la zona.
	var total_nivel: int = _nivel.SABERES.size()
	var recogidos := 0
	for data in _nivel.SABERES:
		if _db.tiene(str(data["id"])):
			recogidos += 1
	_saberes_label.text = tr("SABERES_CONTADOR") % [recogidos, total_nivel]


## Pequeno pulso del contador al recoger un saber.
func _pulsar_contador() -> void:
	if _contador_panel == null:
		return
	_contador_panel.pivot_offset = _contador_panel.size * 0.5
	var t := create_tween()
	t.tween_property(_contador_panel, "scale", Vector2(1.08, 1.08), 0.1) \
		.set_ease(Tween.EASE_OUT)
	t.tween_property(_contador_panel, "scale", Vector2.ONE, 0.28) \
		.set_ease(Tween.EASE_IN_OUT)


## Mensaje breve arriba de la pantalla (saber encontrado, puerta cerrada).
func mostrar_aviso(texto: String) -> void:
	if _aviso == null or _aviso_panel == null:
		return
	_aviso.text = texto
	_aviso_panel.modulate.a = 0.0
	if _aviso_tween != null and _aviso_tween.is_valid():
		_aviso_tween.kill()
	_aviso_tween = create_tween()
	_aviso_tween.tween_property(_aviso_panel, "modulate:a", 1.0, 0.18).set_ease(Tween.EASE_OUT)
	_aviso_tween.tween_interval(2.2)
	_aviso_tween.tween_property(_aviso_panel, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)


func _on_saber_recogido(id: String) -> void:
	_actualizar_contador()
	_pulsar_contador()
	var nombre := id
	if _db != null:
		nombre = str(_db.titulo(id))
	mostrar_aviso("%s — %s" % [tr("SABER_ENCONTRADO"), nombre])


## Nivel al que lleva cada puerta. Si una puerta no figura acá, se abre pero
## no cambia de zona (por ejemplo, una puerta de una zona que todavía no existe).
func _nivel_destino(id: String):
	match id:
		"puerta_ruinas_01":
			return LEVEL_RUINAS
		_:
			return null


## Cuando se abre una puerta, cambia de zona si la puerta lo declara.
func _on_puerta_abierta(id: String) -> void:
	var destino = _nivel_destino(id)
	if destino != null and destino != _nivel:
		cargar_nivel(destino)


## Lo llama una puerta ya abierta (guardada de una partida anterior) cuando el
## zorro la atraviesa, para no quedar encerrado sin poder seguir.
func viajar_por_puerta(id: String) -> void:
	var destino = _nivel_destino(id)
	if destino != null and destino != _nivel:
		cargar_nivel(destino)


func _on_idioma_cambiado(_codigo: String) -> void:
	_actualizar_contador()
	if _hint != null:
		_hint.text = tr("PISTA_CONTROLES")
