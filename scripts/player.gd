extends CharacterBody2D
## Zorro viajero: movimiento con aceleracion, coyote time, salto con buffer,
## squash & stretch y polvo al correr/aterrizar.

const ART = preload("res://scripts/pixel_art.gd")
const P = preload("res://scripts/palette.gd")

const SPEED := 265.0
const ACCEL := 2900.0
const FRICTION := 3600.0
const AIR_ACCEL := 2000.0
const GRAVITY := 1250.0
const FALL_MULT := 1.16
const MAX_FALL := 1000.0
const JUMP_VELOCITY := -520.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12

var respawn_position := Vector2.ZERO

var _art: ART
var _sprite: AnimatedSprite2D
var _dust: CPUParticles2D
var _shadow: Sprite2D
var _shadow_ray: RayCast2D
var _coyote := 0.0
var _buffer := 0.0
var _was_on_floor := true
var _facing := 1
var _step_timer := 0.0
var _invuln := 0.0
var _bob := 0.0
var _squash_tween: Tween
var _teleporting := false


func _ready() -> void:
	add_to_group("player")
	_art = ART.new()

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20.0, 30.0)
	col.shape = shape
	col.position = Vector2(0.0, -15.0)
	add_child(col)

	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Visual"
	_sprite.sprite_frames = _art.fox_frames()
	_sprite.position = Vector2(0.0, -20.0)
	_sprite.play("idle")
	add_child(_sprite)

	_shadow = Sprite2D.new()
	_shadow.name = "Sombra"
	_shadow.texture = _art.soft_shadow()
	_shadow.z_index = -4
	add_child(_shadow)

	_shadow_ray = RayCast2D.new()
	_shadow_ray.name = "SombraRay"
	_shadow_ray.position = Vector2(0.0, -10.0)
	_shadow_ray.target_position = Vector2(0.0, 300.0)
	_shadow_ray.collision_mask = 1
	_shadow_ray.exclude_parent = true
	_shadow_ray.enabled = true
	add_child(_shadow_ray)

	_dust = CPUParticles2D.new()
	_dust.name = "Dust"
	_dust.emitting = false
	_dust.amount = 10
	_dust.lifetime = 0.55
	_dust.one_shot = true
	_dust.explosiveness = 0.92
	_dust.local_coords = false
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_dust.emission_sphere_radius = 3.0
	_dust.direction = Vector2(0.0, -1.0)
	_dust.spread = 80.0
	_dust.initial_velocity_min = 14.0
	_dust.initial_velocity_max = 52.0
	_dust.gravity = Vector2(0.0, 160.0)
	_dust.scale_amount_min = 0.35
	_dust.scale_amount_max = 0.9
	_dust.color = P.DUST
	_dust.texture = _art.puff_texture()
	_dust.position = Vector2(0.0, -2.0)
	_dust.z_index = -1
	add_child(_dust)

	respawn_position = global_position


func _physics_process(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)

	var on_floor := is_on_floor()
	var direction := Input.get_axis("ui_left", "ui_right")

	# --- salto con coyote time + buffer ---
	if on_floor:
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(0.0, _coyote - delta)

	if Input.is_action_just_pressed("ui_accept"):
		_buffer = JUMP_BUFFER
	else:
		_buffer = maxf(0.0, _buffer - delta)

	# --- movimiento horizontal ---
	var accel := ACCEL if on_floor else AIR_ACCEL
	if absf(direction) > 0.01:
		velocity.x = move_toward(velocity.x, direction * SPEED, accel * delta)
		_facing = 1 if direction > 0.0 else -1
	else:
		var decel := FRICTION if on_floor else AIR_ACCEL * 0.55
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

	if _buffer > 0.0 and _coyote > 0.0 and not _teleporting:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		_stretch(Vector2(0.82, 1.18))
		_puff(6, 0.7)

	# salto variable
	if Input.is_action_just_released("ui_accept") and velocity.y < -120.0:
		velocity.y *= 0.5

	# --- gravedad ---
	if not on_floor:
		var g := GRAVITY * (FALL_MULT if velocity.y > 0.0 else 1.0)
		velocity.y += g * delta
	else:
		velocity.y += GRAVITY * delta
	velocity.y = minf(velocity.y, MAX_FALL)

	move_and_slide()

	# --- aterrizaje ---
	var now_floor := is_on_floor()
	if now_floor and not _was_on_floor and not _teleporting:
		_stretch(Vector2(1.26, 0.78))
		_puff(11, 1.0)
	_was_on_floor = now_floor

	# --- polvo de carrera ---
	if now_floor and absf(velocity.x) > 90.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.17
			_puff(3, 0.45)
	else:
		_step_timer = 0.0

	_update_animation(delta)
	_update_shadow()

	if global_position.y > 460.0:
		_invuln = 0.0
		respawn()


func _update_shadow() -> void:
	if _shadow == null or _shadow_ray == null:
		return
	_shadow_ray.force_raycast_update()
	if not _shadow_ray.is_colliding():
		_shadow.visible = false
		return
	var hit := _shadow_ray.get_collision_point()
	var dist := global_position.distance_to(hit)
	var t := clampf(dist / 190.0, 0.0, 1.0)
	_shadow.visible = true
	_shadow.global_position = hit + Vector2(0.0, 1.0)
	_shadow.scale = Vector2(1.0 - t * 0.38, 1.0 - t * 0.28)
	_shadow.modulate = Color(1.0, 1.0, 1.0, 0.9 * (1.0 - t * 0.72))


func _update_animation(delta: float) -> void:
	var bob := 0.0
	if not is_on_floor():
		var anim := "jump" if velocity.y < 0.0 else "fall"
		if _sprite.animation != anim:
			_sprite.play(anim)
		_sprite.speed_scale = 1.0
	elif absf(velocity.x) > 18.0:
		if _sprite.animation != "run":
			_sprite.play("run")
		_sprite.speed_scale = clampf(absf(velocity.x) / SPEED, 0.7, 1.35)
		_bob += delta * (11.0 + absf(velocity.x) * 0.035)
		bob = -absf(sin(_bob)) * 0.8
	else:
		if _sprite.animation != "idle":
			_sprite.play("idle")
		_sprite.speed_scale = 1.0
		_bob = 0.0
	_sprite.position.y = move_toward(_sprite.position.y, -20.0 + bob, delta * 26.0)
	_sprite.flip_h = _facing < 0


func _stretch(target: Vector2) -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(_sprite, "scale", target, 0.07)
	_squash_tween.tween_property(_sprite, "scale", Vector2.ONE, 0.20) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _puff(amount: int, strength: float) -> void:
	if _dust == null:
		return
	_dust.amount = maxi(3, amount)
	_dust.initial_velocity_max = 52.0 * strength
	_dust.restart()


func bounce() -> void:
	velocity.y = -370.0
	_stretch(Vector2(0.8, 1.2))
	_puff(7, 0.9)


func respawn() -> void:
	if _invuln > 0.0:
		return
	_invuln = 1.0
	velocity = Vector2.ZERO
	_teleporting = true
	global_position = respawn_position
	_teleporting = false
	_was_on_floor = false
	_coyote = 0.0
	_stretch(Vector2(0.72, 1.28))
	_sprite.modulate.a = 0.15
	var t := create_tween()
	t.tween_property(_sprite, "modulate:a", 1.0, 0.45)
	if get_parent() != null and get_parent().has_method("on_player_respawned"):
		get_parent().on_player_respawned()
