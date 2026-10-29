extends Node2D
## Bosque de Bruma — mundo, camara, parallax, ambiente y HUD.

const P = preload("res://scripts/palette.gd")
const ART = preload("res://scripts/pixel_art.gd")
const LEVEL = preload("res://scripts/level_data.gd")
const PLAYER_SCRIPT = preload("res://scripts/player.gd")

## Suaviza las capas lejanas (bosque, copas, sol). false = pixeles duros como antes.
const BG_SMOOTH := true

var art: ART
var player: CharacterBody2D
var camera: Camera2D

var _layers: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _shake := 0.0
var _flash: ColorRect
var _hint: Label


func _ready() -> void:
	_rng.seed = 20261028
	art = ART.new()
	RenderingServer.set_default_clear_color(P.SKY_TOP)

	_build_sky()
	_build_parallax()
	_build_screen_frame()
	_build_world()
	_build_ambient()
	_build_player()
	_build_enemies()
	_build_camera()
	_build_ui()
	_update_parallax()
	_validate_level()


# =====================================================================
#  Cielo y capas de bosque
# =====================================================================
func _build_sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -100
	add_child(layer)

	var sky := ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
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
	// la calidez crece hacia el lado del sol
	float side = smoothstep(0.10, 0.95, uv.x);
	c = mix(c, warm_color.rgb, glow * side * 0.42);
	c = mix(c, deep_color.rgb, smoothstep(0.85, 1.02, uv.y));
	// nubes largas y suaves, encendidas por el sol
	float cloud = sin(uv.y * 30.0 + sin(uv.x * 5.0) * 2.2) * 0.5 + 0.5;
	cloud *= smoothstep(0.16, 0.40, uv.y) * (1.0 - smoothstep(0.60, 0.84, uv.y));
	c += cloud * 0.030 * warm_color.rgb;
	float band = sin(uv.y * 24.0 + sin(uv.x * 6.0) * 1.5) * 0.008;
	c += band;
	COLOR = vec4(c, 1.0);
}
"""
	mat.shader = shader
	mat.set_shader_parameter("top_color", P.SKY_TOP)
	mat.set_shader_parameter("mid_color", P.SKY_MID)
	mat.set_shader_parameter("low_color", P.SKY_HORIZON)
	mat.set_shader_parameter("warm_color", P.SUN)
	mat.set_shader_parameter("deep_color", P.FOREST_FRONT)
	sky.material = mat
	layer.add_child(sky)


func _build_parallax() -> void:
	# sol bajo entre la niebla
	_single_layer(art.sun_glow(), Vector2(0.02, 0.01), Vector2(190.0, -62.0), -91, 3.1,
		Color(1.0, 0.78, 0.44, 0.30), true)
	_single_layer(art.sun_disk(), Vector2(0.02, 0.01), Vector2(190.0, -56.0), -90, 1.55,
		Color(1.0, 1.0, 1.0, 0.95), false)

	_tiled_layer(art.far_forest(11), Vector2(0.10, 0.02), Vector2(0.0, -170.0), -92, 5, 2.0,
		Color(1.0, 1.0, 1.0, 0.85))
	# valle de fondo: rellena la parte baja cuando la camara sube
	_tiled_layer(art.valley_forest(59), Vector2(0.07, 0.03), Vector2(0.0, -60.0), -80, 5, 2.0,
		Color(0.94, 0.98, 0.94, 1.0))
	_tiled_layer(art.mid_forest(23), Vector2(0.19, 0.04), Vector2(0.0, -178.0), -84, 5, 2.0,
		Color(1.0, 1.0, 1.0, 1.0))
	# haces de luz que caen entre las copas
	_single_layer(art.light_shafts(151), Vector2(0.03, 0.02), Vector2(90.0, -150.0), -81, 2.0,
		Color(1.0, 0.86, 0.58, 0.9), true)
	_tiled_layer(art.near_forest(37), Vector2(0.33, 1.0), Vector2(0.0, -283.0), -64, 5, 2.0,
		Color(0.94, 0.98, 0.94, 1.0))

	# copas que enmarcan la parte superior
	_tiled_layer(art.canopy_layer(71), Vector2(0.55, 0.06), Vector2(0.0, -100.0), -58, 5, 2.0,
		Color(1.0, 1.0, 1.0, 1.0))

	# barranco oscuro detras de los huecos del suelo
	var pit := Sprite2D.new()
	pit.texture = art.pit_texture()
	pit.centered = false
	pit.position = Vector2(-900.0, 0.0)
	pit.scale = Vector2(300.0, 1.15)
	pit.z_index = -30
	add_child(pit)



func _single_layer(tex: Texture2D, factor: Vector2, base: Vector2, z: int, scale: float,
		modulate: Color, additive := false) -> void:
	var node := Node2D.new()
	node.z_index = z
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = true
	s.scale = Vector2(scale, scale)
	s.position = Vector2.ZERO
	s.modulate = modulate
	if BG_SMOOTH:
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = m
	node.add_child(s)
	add_child(node)
	_layers.append({"node": node, "factor": factor, "base": base})


func _tiled_layer(tex: Texture2D, factor: Vector2, base: Vector2, z: int, tiles: int,
		scale: float, modulate: Color) -> void:
	var node := Node2D.new()
	node.z_index = z
	var tw := float(tex.get_width()) * scale
	for i in range(tiles):
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = true
		s.scale = Vector2(scale, scale)
		s.position = Vector2((float(i) - float(tiles) * 0.5) * tw, 0.0)
		s.modulate = modulate
		if BG_SMOOTH:
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		node.add_child(s)
	add_child(node)
	_layers.append({"node": node, "factor": factor, "base": base})


func _update_parallax() -> void:
	if camera == null:
		return
	var cp := camera.global_position
	for data in _layers:
		var node: Node2D = data["node"]
		var factor: Vector2 = data["factor"]
		var base: Vector2 = data["base"]
		node.position = Vector2(base.x + cp.x * (1.0 - factor.x), base.y + cp.y * (1.0 - factor.y))


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

	# luz calida de pantalla: el sol tiñe la esquina superior derecha
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
	for g in LEVEL.GROUNDS:
		_create_platform(g, false, seed)
		_dress_ground(g, seed)
		seed += 1

	for l in LEVEL.LEDGES:
		_create_platform(l, true, seed)
		_dress_ledge(l, seed)
		seed += 1

	# sotobosque: arbustos y helechos al pie de cada tramo de suelo
	seed = 0
	for g in LEVEL.GROUNDS:
		_dress_understory(g, 71 + seed * 13)
		seed += 1

	for prop in LEVEL.PROPS:
		_place_prop(prop)

	# niebla que respira en la boca de cada barranco
	var gaps := _ground_gaps()
	for i in gaps.size():
		_add_gap_mist(gaps[i].x, gaps[i].y, 77 + i * 14)


func _place_prop(prop: Dictionary) -> void:
	var pos: Vector2 = prop["pos"]
	var z: int = prop.get("z", 2)
	match prop["kind"]:
		"sign":
			_place(art.sign(), pos, z)
		"log":
			_place(art.log(prop.get("size", 3)), pos, z)
		_:
			push_warning("Prop desconocido en level_data.gd: %s" % prop["kind"])


## Huecos entre tramos de suelo consecutivos, como Vector2(izquierda, derecha).
func _ground_gaps() -> Array[Vector2]:
	var sorted_grounds := LEVEL.GROUNDS.duplicate()
	sorted_grounds.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var gaps: Array[Vector2] = []
	for i in range(1, sorted_grounds.size()):
		var left: Rect2 = sorted_grounds[i - 1]
		var right: Rect2 = sorted_grounds[i]
		if right.position.x > left.end.x:
			gaps.append(Vector2(left.end.x, right.position.x))
	return gaps


# =====================================================================
#  Validacion del nivel
# =====================================================================
## Avisa por consola de un nivel que no se puede jugar: plataformas
## solapadas, hongos patrullando fuera de su suelo o repisas que no se
## alcanzan con el salto. El alcance es conservador (calculado a la misma
## altura), asi que un aviso de "no se alcanza" conviene mirarlo a mano.
func _validate_level() -> void:
	for problem in _level_problems():
		push_warning("Nivel: " + problem)


func _level_problems() -> Array[String]:
	var problems: Array[String] = []
	var boxes: Array[Rect2] = []
	boxes.append_array(LEVEL.GROUNDS)
	boxes.append_array(LEVEL.LEDGES)
	var ground_count := LEVEL.GROUNDS.size()

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

	for enemy in LEVEL.ENEMIES:
		var pos: Vector2 = enemy["pos"]
		var ground_index := _ground_at(pos.x)
		if ground_index < 0:
			problems.append("el hongo en x=%.0f no esta sobre ningun tramo de suelo" % pos.x)
			continue
		var ground: Rect2 = LEVEL.GROUNDS[ground_index]
		if enemy.has("patrol"):
			var patrol: Vector2 = enemy["patrol"]
			var left := patrol.x
			var right := patrol.y
			if left < ground.position.x or right > ground.end.x or left > right:
				problems.append("el hongo en x=%.0f patrulla fuera de su suelo (%.0f..%.0f)" % [pos.x, ground.position.x, ground.end.x])

	for i in _unreachable_boxes():
		problems.append("%s no se alcanza desde ninguna plataforma" % _box_name(i, ground_count))

	return problems


## Alcance del salto como Vector2(horizontal a la misma altura, altura maxima).
func _jump_envelope() -> Vector2:
	var rise: float = PLAYER_SCRIPT.JUMP_VELOCITY * PLAYER_SCRIPT.JUMP_VELOCITY / (2.0 * PLAYER_SCRIPT.GRAVITY)
	var t_up: float = -PLAYER_SCRIPT.JUMP_VELOCITY / PLAYER_SCRIPT.GRAVITY
	var fall_gravity: float = PLAYER_SCRIPT.GRAVITY * PLAYER_SCRIPT.FALL_MULT
	var t_down := sqrt(2.0 * rise / fall_gravity)
	return Vector2(PLAYER_SCRIPT.SPEED * (t_up + t_down), rise)


## Tramos de suelo ordenados de izquierda a derecha.
func _sorted_grounds() -> Array[Rect2]:
	var grounds: Array[Rect2] = []
	grounds.append_array(LEVEL.GROUNDS)
	grounds.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	return grounds


func _ground_at(x: float) -> int:
	for i in LEVEL.GROUNDS.size():
		var g: Rect2 = LEVEL.GROUNDS[i]
		if x >= g.position.x and x <= g.end.x:
			return i
	return -1


## Indices de repisas inalcanzables, propagando desde el suelo hacia arriba.
func _unreachable_boxes() -> Array[int]:
	var boxes: Array[Rect2] = []
	boxes.append_array(LEVEL.GROUNDS)
	boxes.append_array(LEVEL.LEDGES)
	var ground_count := LEVEL.GROUNDS.size()
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
	var s := Sprite2D.new()
	s.texture = art.mist_band(seed, 0.24)
	s.centered = true
	s.position = Vector2((left + right) * 0.5, -7.0)
	s.scale = Vector2(0.62, 0.62)
	s.modulate = Color(1.0, 1.0, 1.0, 0.7)
	s.z_index = 3
	add_child(s)

	var start_x := s.position.x
	var t := create_tween().set_loops()
	t.tween_property(s, "position:x", start_x + 9.0, 6.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(s, "position:x", start_x - 9.0, 6.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _create_platform(rect: Rect2, floating: bool, seed: int) -> void:
	var body := StaticBody2D.new()
	body.name = "Plataforma"
	body.position = rect.position
	body.z_index = 0

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	col.position = rect.size * 0.5
	body.add_child(col)

	var visual := Sprite2D.new()
	visual.name = "Visual"
	visual.texture = art.ground_texture(Vector2i(int(rect.size.x), int(rect.size.y)), floating, seed)
	visual.centered = false
	visual.position = Vector2.ZERO
	body.add_child(visual)

	add_child(body)


func _dress_ground(rect: Rect2, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 941 + 61
	var x := rect.position.x + 40.0
	while x < rect.end.x - 30.0:
		var roll := rng.randf()
		if roll < 0.44:
			_place(art.grass_tuft(int(x) + seed), Vector2(x, 0.0), 2, rng.randf_range(0.9, 1.25))
		elif roll < 0.62:
			_place(art.flower(int(x) + seed), Vector2(x, 0.0), 2)
		elif roll < 0.72:
			_place(art.small_mushroom(int(x) + seed), Vector2(x, 0.0), 2)
		elif roll < 0.80:
			_place(art.rock(int(x) + seed), Vector2(x, 0.0), 2, rng.randf_range(0.85, 1.2))
		else:
			_place(art.fern(int(x) + seed), Vector2(x, 0.0), 2, rng.randf_range(0.95, 1.3))
		x += rng.randf_range(38.0, 78.0)

	# helechos extra: el sotobosque se siente mas tupido
	var fx := rect.position.x + rng.randf_range(60.0, 110.0)
	while fx < rect.end.x - 40.0:
		_place(art.fern(int(fx) + seed * 5), Vector2(fx, 1.0), 2, rng.randf_range(1.05, 1.45))
		fx += rng.randf_range(90.0, 150.0)

	# raices colgando en los bordes del barranco
	for side in [rect.position.x, rect.end.x]:
		for i in range(3):
			var vine := art.vine_texture(int(side) + i * 37 + seed)
			var s := Sprite2D.new()
			s.texture = vine
			s.centered = false
			s.position = Vector2(side + rng.randf_range(-8.0, 8.0) + i * 4.0, 2.0)
			s.scale = Vector2(1.0, rng.randf_range(1.0, 1.45))
			s.z_index = 3
			add_child(s)


func _dress_understory(rect: Rect2, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 331 + 17
	# arbustos sueltos al pie del suelo
	var count := 2 + int(rect.size.x / 230.0)
	for i in range(count):
		var x := rng.randf_range(rect.position.x + 30.0, rect.end.x - 30.0)
		_place(art.bush(seed + i * 31), Vector2(x, 3.0), 1, rng.randf_range(0.9, 1.35))
	# helechos altos entre las matas
	for i in range(3):
		var x := rng.randf_range(rect.position.x + 18.0, rect.end.x - 18.0)
		_place(art.fern(seed * 7 + i + 3), Vector2(x, 1.0), 1, rng.randf_range(1.2, 1.55))


func _dress_ledge(rect: Rect2, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 617 + 29
	# matas sobre la repisa
	for i in range(rng.randi_range(1, 3)):
		var x := rng.randf_range(rect.position.x + 12.0, rect.end.x - 12.0)
		_place(art.grass_tuft(int(x) + seed), Vector2(x, rect.position.y), 2, rng.randf_range(0.9, 1.2))
	# enredaderas colgando
	for i in range(rng.randi_range(1, 3)):
		var x := rng.randf_range(rect.position.x + 10.0, rect.end.x - 10.0)
		var vine := art.vine_texture(int(x) + seed)
		var s := Sprite2D.new()
		s.texture = vine
		s.centered = false
		s.position = Vector2(x, rect.position.y + rect.size.y - 1.0)
		s.z_index = 2
		add_child(s)

	# pedrusco de tierra que cuelga de la panza de la repisa
	if rng.randf() < 0.72:
		var beard := art.ledge_beard(int(rect.position.x) + seed)
		var bx := rng.randf_range(rect.position.x + 18.0, rect.end.x - 18.0)
		var b := Sprite2D.new()
		b.texture = beard
		b.centered = false
		b.position = Vector2(bx - float(beard.get_width()) * 0.5, rect.position.y + rect.size.y - 2.0)
		b.z_index = 1
		add_child(b)


func _place(tex: Texture2D, pos: Vector2, z: int, scale := 1.0) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = true
	s.scale = Vector2(scale, scale)
	s.position = Vector2(pos.x, pos.y - tex.get_height() * scale * 0.5)
	s.z_index = z
	add_child(s)


# =====================================================================
#  Ambiente
# =====================================================================
func _build_ambient() -> void:
	# luciernagas
	var flies := CPUParticles2D.new()
	flies.name = "Luciernagas"
	flies.amount = 60
	flies.lifetime = 7.5
	flies.preprocess = 4.0
	flies.position = Vector2(80.0, -70.0)
	flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flies.emission_rect_extents = Vector2(1000.0, 110.0)
	flies.direction = Vector2(0.0, -1.0)
	flies.spread = 180.0
	flies.gravity = Vector2.ZERO
	flies.initial_velocity_min = 3.0
	flies.initial_velocity_max = 14.0
	flies.scale_amount_min = 0.55
	flies.scale_amount_max = 1.25
	flies.texture = art.glow_texture()
	flies.z_index = 6
	flies.local_coords = false
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.62, 0.0))
	ramp.set_color(1, Color(1.0, 0.9, 0.62, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.9, 0.62, 1.0))
	ramp.add_point(0.7, Color(1.0, 0.85, 0.55, 0.9))
	flies.color_ramp = ramp
	var fly_mat := CanvasItemMaterial.new()
	fly_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flies.material = fly_mat
	add_child(flies)

	# hojas que caen
	var leaves := CPUParticles2D.new()
	leaves.name = "Hojas"
	leaves.amount = 15
	leaves.lifetime = 13.0
	leaves.preprocess = 6.0
	leaves.position = Vector2(80.0, -215.0)
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = Vector2(1050.0, 30.0)
	leaves.direction = Vector2(0.0, 1.0)
	leaves.spread = 32.0
	leaves.gravity = Vector2(5.0, 5.0)
	leaves.initial_velocity_min = 4.0
	leaves.initial_velocity_max = 12.0
	leaves.angular_velocity_min = -55.0
	leaves.angular_velocity_max = 45.0
	leaves.scale_amount_min = 0.55
	leaves.scale_amount_max = 1.0
	leaves.texture = art.leaf_particle()
	leaves.z_index = 7
	leaves.local_coords = false
	leaves.color = Color(1.0, 0.94, 0.8, 0.78)
	add_child(leaves)


# =====================================================================
#  Entidades
# =====================================================================
func _build_player() -> void:
	var p := CharacterBody2D.new()
	p.name = "Zorro"
	p.set_script(PLAYER_SCRIPT)
	p.position = LEVEL.SPAWN
	p.z_index = 5
	add_child(p)
	p.set("respawn_position", LEVEL.SPAWN)
	player = p


func _build_enemies() -> void:
	for enemy in LEVEL.ENEMIES:
		var pos: Vector2 = enemy["pos"]
		var patrol: Vector2 = enemy.get("patrol", _patrol_for(pos))
		_spawn_enemy(pos, patrol.x, patrol.y)


## Patrulla por defecto: el tramo de suelo que contiene la posicion, con margen.
func _patrol_for(pos: Vector2) -> Vector2:
	var ground_index := _ground_at(pos.x)
	if ground_index < 0:
		return Vector2(pos.x - 120.0, pos.x + 120.0)
	var g: Rect2 = LEVEL.GROUNDS[ground_index]
	return Vector2(g.position.x + LEVEL.PATROL_MARGIN, g.end.x - LEVEL.PATROL_MARGIN)


func _spawn_enemy(pos: Vector2, left: float, right: float) -> void:
	var e := CharacterBody2D.new()
	e.name = "Hongo"
	e.set_script(load("res://scripts/enemy.gd"))
	e.position = pos
	e.z_index = 4
	e.set("patrol_left", left)
	e.set("patrol_right", right)
	add_child(e)


# =====================================================================
#  Camara
# =====================================================================
func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camara"
	camera.zoom = Vector2(2.2, 2.2)
	camera.position_smoothing_enabled = false
	camera.enabled = true
	add_child(camera)
	camera.make_current()
	camera.global_position = player.global_position + Vector2(0.0, -78.0)


func _process(delta: float) -> void:
	if player == null or camera == null:
		return

	var target := Vector2(
		player.global_position.x + clampf(player.velocity.x * 0.22, -78.0, 78.0),
		player.global_position.y - 78.0
	)
	var half := get_viewport_rect().size * 0.5 / camera.zoom
	var bounds: Rect2 = LEVEL.CAM_BOUNDS
	target.x = clampf(target.x, bounds.position.x + half.x, bounds.end.x - half.x)
	target.y = clampf(target.y, bounds.position.y, bounds.end.y)
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-7.5 * delta))

	_shake = move_toward(_shake, 0.0, delta * 9.0)
	if _shake > 0.01:
		camera.offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * _shake
	else:
		camera.offset = Vector2.ZERO

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

	# vineta
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

	# destello de reaparicion
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1.0, 0.95, 0.84, 0.0)
	layer.add_child(_flash)

	_build_title(layer)
	_build_hint(layer)


func _build_title(layer: CanvasLayer) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_bottom = 0.62
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.07, 0.36)
	style.border_color = Color(P.CREAM.r, P.CREAM.g, P.CREAM.b, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(1)
	style.content_margin_left = 58.0
	style.content_margin_right = 58.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	card.add_child(box)

	var kicker := Label.new()
	kicker.text = "C A P Í T U L O   I"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override("font_size", 11)
	kicker.add_theme_color_override("font_color", Color(P.CREAM.r, P.CREAM.g, P.CREAM.b, 0.52))
	kicker.add_theme_color_override("font_shadow_color", Color(0.08, 0.06, 0.04, 0.6))
	kicker.add_theme_constant_override("shadow_offset_x", 1)
	kicker.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(kicker)

	var title := Label.new()
	title.text = "Bosque de Bruma"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", P.CREAM)
	title.add_theme_color_override("font_shadow_color", Color(0.08, 0.06, 0.04, 0.7))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(title)

	var rule_center := CenterContainer.new()
	rule_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule_center)

	var rule := ColorRect.new()
	rule.color = Color(P.CREAM.r, P.CREAM.g, P.CREAM.b, 0.26)
	rule.custom_minimum_size = Vector2(172.0, 1.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule_center.add_child(rule)

	var sub := Label.new()
	sub.text = "un paseo al atardecer"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(P.CREAM_D.r, P.CREAM_D.g, P.CREAM_D.b, 0.85))
	sub.add_theme_color_override("font_shadow_color", Color(0.08, 0.06, 0.04, 0.5))
	sub.add_theme_constant_override("shadow_offset_x", 1)
	sub.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(sub)

	card.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(card, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	t.tween_interval(2.2)
	t.tween_property(card, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	t.tween_callback(center.queue_free)


func _build_hint(layer: CanvasLayer) -> void:
	_hint = Label.new()
	_hint.text = "←  →   moverse        ESPACIO   saltar"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -58.0
	_hint.offset_bottom = -30.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.97, 0.93, 0.82, 0.78))
	_hint.add_theme_color_override("font_shadow_color", Color(0.06, 0.05, 0.04, 0.8))
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	_hint.modulate.a = 0.0
	layer.add_child(_hint)

	var t := create_tween()
	t.tween_interval(1.1)
	t.tween_property(_hint, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
