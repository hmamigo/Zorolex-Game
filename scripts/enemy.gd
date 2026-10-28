extends CharacterBody2D
## Hongo del bosque: patrulla, gira en bordes y paredes, se aplasta al saltarle
## encima. Al morir suelta una nube de esporas.

const ART = preload("res://scripts/pixel_art.gd")
const P = preload("res://scripts/palette.gd")

const GRAVITY := 1250.0
const SPEED := 52.0

var patrol_left := 0.0
var patrol_right := 0.0

var _art: ART
var _sprite: AnimatedSprite2D
var _area: Area2D
var _shape: CollisionShape2D
var _ledge: RayCast2D
var _dir := 1.0
var _dead := false


func _ready() -> void:
	add_to_group("enemy")
	_art = ART.new()

	_shape = CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(18.0, 22.0)
	_shape.shape = box
	_shape.position = Vector2(0.0, -11.0)
	add_child(_shape)

	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Visual"
	_sprite.sprite_frames = _art.mushroom_frames()
	_sprite.position = Vector2(0.0, -13.0)
	_sprite.play("walk")
	add_child(_sprite)

	var shadow := Sprite2D.new()
	shadow.name = "Sombra"
	shadow.texture = _art.soft_shadow()
	shadow.position = Vector2(0.0, 1.0)
	shadow.scale = Vector2(0.62, 0.8)
	shadow.z_index = -3
	add_child(shadow)

	_area = Area2D.new()
	_area.name = "DetectionArea"
	_area.collision_mask = 1
	var acol := CollisionShape2D.new()
	var abox := RectangleShape2D.new()
	abox.size = Vector2(24.0, 24.0)
	acol.shape = abox
	acol.position = Vector2(0.0, -12.0)
	_area.add_child(acol)
	add_child(_area)

	_ledge = RayCast2D.new()
	_ledge.position = Vector2(10.0, -3.0)
	_ledge.target_position = Vector2(0.0, 16.0)
	_ledge.collision_mask = 1
	_ledge.exclude_parent = true
	_ledge.enabled = true
	add_child(_ledge)


func _physics_process(delta: float) -> void:
	if _dead:
		velocity = Vector2.ZERO
		return

	velocity.y += GRAVITY * delta
	velocity.y = minf(velocity.y, 1000.0)

	if global_position.x - 8.0 <= patrol_left:
		_dir = 1.0
	elif global_position.x + 8.0 >= patrol_right:
		_dir = -1.0
	velocity.x = _dir * SPEED
	move_and_slide()

	if is_on_wall():
		_dir = -_dir

	_ledge.position.x = _dir * 10.0
	_ledge.force_raycast_update()
	if is_on_floor() and not _ledge.is_colliding():
		_dir = -_dir
		_ledge.position.x = _dir * 10.0

	_sprite.flip_h = _dir < 0.0
	_check_player()


func _check_player() -> void:
	for body in _area.get_overlapping_bodies():
		if body == self or not body.is_in_group("player"):
			continue
		var p := body as CharacterBody2D
		if p == null:
			continue
		var enemy_top := global_position.y - 20.0
		# Aterrizar sobre el hongo detiene la caida (move_and_slide), asi que
		# se comprueba la posicion de los pies y no solo la velocidad.
		var stomping := p.velocity.y > -20.0 and p.global_position.y <= enemy_top + 8.0
		if stomping:
			if p.has_method("bounce"):
				p.bounce()
			_die()
		else:
			if p.has_method("respawn"):
				p.respawn()
		return


func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	_sprite.play("squash")
	_set_disabled.call_deferred(_shape)
	_area.set_deferred("monitoring", false)

	var spores := CPUParticles2D.new()
	spores.one_shot = true
	spores.emitting = true
	spores.amount = 18
	spores.lifetime = 0.7
	spores.explosiveness = 1.0
	spores.local_coords = false
	spores.texture = _art.puff_texture()
	spores.color = Color(P.CAP_L.r, P.CAP_L.g, P.CAP_L.b, 0.95)
	spores.direction = Vector2(0.0, -1.0)
	spores.spread = 110.0
	spores.initial_velocity_min = 45.0
	spores.initial_velocity_max = 135.0
	spores.gravity = Vector2(0.0, 420.0)
	spores.scale_amount_min = 0.4
	spores.scale_amount_max = 1.0
	spores.position = Vector2(0.0, -12.0)
	add_child(spores)

	if get_parent() != null and get_parent().has_method("camera_shake"):
		get_parent().camera_shake(2.2)

	var t := create_tween()
	t.tween_interval(0.35)
	t.tween_property(self, "modulate:a", 0.0, 0.45)
	t.tween_callback(queue_free)


func _set_disabled(s: CollisionShape2D) -> void:
	if s != null:
		s.set_deferred("disabled", true)
