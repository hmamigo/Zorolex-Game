extends Area3D
## Saber flotante del bosque: una hoja de luz que se recoge al tocarla.
## El estado y el guardado los lleva el autoload Saberes.
##
## En el mundo 2.5D el nodo vive en el plano de juego (z = PLANE_Z) y el dibujo
## es un billboard 2D que flota por encima del punto de diseño.

const ART = preload("res://scripts/pixel_art.gd")
const P = preload("res://scripts/palette.gd")
const W = preload("res://scripts/world_3d.gd")

## Altura del dibujo sobre el punto de diseño (en píxeles 2D).
const FLOAT_HEIGHT := 22.0

## Id del saber en data/saberes/. Lo setea main.gd antes de agregar el nodo.
var saber_id := ""

var _glow: Sprite3D
var _page: Sprite3D
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

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 18.0
	col.shape = shape
	add_child(col)

	var art := ART.new()

	_glow = Sprite3D.new()
	_glow.name = "Brillo"
	_glow.texture = art.glow_texture()
	_glow.pixel_size = 1.0
	_glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_glow.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_glow.transparent = true
	_glow.shaded = false
	_glow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_glow.position = Vector3(0.0, FLOAT_HEIGHT, 0.0)
	_glow.scale = Vector3(5.0, 5.0, 1.0)
	_glow.modulate = Color(P.FIREFLY.r, P.FIREFLY.g, P.FIREFLY.b, 0.42)
	_glow.material_override = W.additive_material(art.glow_texture(), Color.WHITE, true)
	add_child(_glow)

	_page = Sprite3D.new()
	_page.name = "Hoja"
	_page.texture = art.saber_page()
	_page.pixel_size = 1.0
	_page.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_page.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_page.shaded = false
	_page.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_page.position = Vector3(0.0, FLOAT_HEIGHT, 0.1)
	add_child(_page)

	body_entered.connect(_on_body_entered)
	_animate()


func _animate() -> void:
	_bob = create_tween().set_loops()
	_bob.tween_property(_page, "position:y", FLOAT_HEIGHT - 5.0, 1.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob.tween_property(_page, "position:y", FLOAT_HEIGHT + 2.0, 1.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_pulse = create_tween().set_loops()
	_pulse.tween_property(_glow, "modulate:a", 0.62, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(_glow, "modulate:a", 0.30, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node3D) -> void:
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
	var polvo := CPUParticles3D.new()
	polvo.one_shot = true
	polvo.emitting = true
	polvo.amount = 16
	polvo.lifetime = 0.8
	polvo.explosiveness = 1.0
	polvo.local_coords = false
	polvo.mesh = W.particle_mesh(6.0)
	polvo.material_override = W.particle_material(art.glow_texture(), true)
	polvo.color = Color(P.FIREFLY.r, P.FIREFLY.g, P.FIREFLY.b, 0.9)
	polvo.direction = Vector3(0.0, 1.0, 0.0)
	polvo.spread = 180.0
	polvo.initial_velocity_min = 30.0
	polvo.initial_velocity_max = 95.0
	polvo.gravity = Vector3(0.0, 35.0, 0.0)
	polvo.scale_amount_min = 0.35
	polvo.scale_amount_max = 0.9
	polvo.position = _page.position
	add_child(polvo)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_page, "scale", Vector3(1.6, 1.6, 1.0), 0.35).set_ease(Tween.EASE_OUT)
	t.tween_property(_page, "modulate:a", 0.0, 0.35)
	t.tween_property(_glow, "modulate:a", 0.0, 0.5)
	t.set_parallel(false)
	t.tween_interval(0.6)
	t.tween_callback(queue_free)
