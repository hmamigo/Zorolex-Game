extends Area2D
## Saber flotante del bosque: una hoja de luz que se recoge al tocarla.
## El estado y el guardado los lleva el autoload Saberes.

const ART = preload("res://scripts/pixel_art.gd")
const P = preload("res://scripts/palette.gd")

## Id del saber en data/saberes/. Lo setea main.gd antes de agregar el nodo.
var saber_id := ""

var _glow: Sprite2D
var _page: Sprite2D
var _bob: Tween
var _pulse: Tween
var _recogido := false
var _db: Node


func _ready() -> void:
	add_to_group("saber")
	_db = get_node_or_null("/root/Saberes")
	collision_layer = 0
	collision_mask = 1
	monitoring = true

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	col.shape = shape
	add_child(col)

	var art := ART.new()

	_glow = Sprite2D.new()
	_glow.name = "Brillo"
	_glow.texture = art.glow_texture()
	_glow.position = Vector2(0.0, -22.0)
	_glow.scale = Vector2(5.0, 5.0)
	_glow.modulate = Color(P.FIREFLY.r, P.FIREFLY.g, P.FIREFLY.b, 0.42)
	_glow.z_index = 5
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	add_child(_glow)

	_page = Sprite2D.new()
	_page.name = "Hoja"
	_page.texture = art.saber_page()
	_page.position = Vector2(0.0, -22.0)
	_page.z_index = 6
	add_child(_page)

	body_entered.connect(_on_body_entered)
	_animate()


func _animate() -> void:
	_bob = create_tween().set_loops()
	_bob.tween_property(_page, "position:y", -27.0, 1.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob.tween_property(_page, "position:y", -20.0, 1.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_pulse = create_tween().set_loops()
	_pulse.tween_property(_glow, "modulate:a", 0.62, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(_glow, "modulate:a", 0.30, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node2D) -> void:
	if _recogido or not body.is_in_group("player"):
		return
	_recogido = true
	if _db != null:
		_db.recoger(saber_id)
	_desaparecer()


func _desaparecer() -> void:
	if _bob != null and _bob.is_valid():
		_bob.kill()
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	set_deferred("monitoring", false)

	var art := ART.new()
	var polvo := CPUParticles2D.new()
	polvo.one_shot = true
	polvo.emitting = true
	polvo.amount = 16
	polvo.lifetime = 0.8
	polvo.explosiveness = 1.0
	polvo.local_coords = false
	polvo.texture = art.glow_texture()
	polvo.color = Color(P.FIREFLY.r, P.FIREFLY.g, P.FIREFLY.b, 0.9)
	polvo.direction = Vector2(0.0, -1.0)
	polvo.spread = 180.0
	polvo.initial_velocity_min = 30.0
	polvo.initial_velocity_max = 95.0
	polvo.gravity = Vector2(0.0, -35.0)
	polvo.scale_amount_min = 0.35
	polvo.scale_amount_max = 0.9
	polvo.position = _page.position
	polvo.z_index = 2
	add_child(polvo)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_page, "scale", Vector2(1.6, 1.6), 0.35).set_ease(Tween.EASE_OUT)
	t.tween_property(_page, "modulate:a", 0.0, 0.35)
	t.tween_property(_glow, "modulate:a", 0.0, 0.5)
	t.set_parallel(false)
	t.tween_interval(0.6)
	t.tween_callback(queue_free)
