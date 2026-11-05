extends CharacterBody3D
## Zorro viajero en un mundo 2.5D: se mueve por el plano X/Y, con gravedad hacia
## -Y y profundidad bloqueada en el plano de juego. El sprite sigue siendo 2D
## (billboard) y conserva aceleración, coyote time, salto con buffer,
## squash & stretch, polvo y sombra.

const ART = preload("res://scripts/pixel_art.gd")
const P = preload("res://scripts/palette.gd")
const W = preload("res://scripts/world_3d.gd")

const SPEED := 265.0
const ACCEL := 2900.0
const FRICTION := 3600.0
const AIR_ACCEL := 2000.0
const GRAVITY := 1250.0
const FALL_MULT := 1.16
const MAX_FALL := 1000.0
## Velocidad de salto hacia arriba (positiva, porque en 3D +Y es arriba).
const JUMP_VELOCITY := 520.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12
## Altura del centro visual del sprite sobre los pies (el nodo del zorro está
## en el suelo). La cámara lo usa como punto de mira para centrarlo.
const SPRITE_CENTER_Y := 20.0

var respawn_position := Vector3.ZERO

var _art: ART
var _sprite: AnimatedSprite3D
var _dust: CPUParticles3D
var _shadow: Sprite3D
var _shadow_ray: RayCast3D
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

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 30.0, 16.0)
	col.shape = shape
	col.position = Vector3(0.0, 15.0, 0.0)
	add_child(col)

	_sprite = AnimatedSprite3D.new()
	_sprite.name = "Visual"
	_sprite.sprite_frames = _art.fox_frames()
	_sprite.pixel_size = 1.0
	_sprite.position = Vector3(0.0, SPRITE_CENTER_Y, 0.0)
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.shaded = false
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_sprite.play("idle")
	add_child(_sprite)

	# Sombra plana sobre el terreno (girada para quedar apoyada en el piso).
	_shadow = Sprite3D.new()
	_shadow.name = "Sombra"
	_shadow.texture = _art.soft_shadow()
	_shadow.pixel_size = 1.0
	_shadow.centered = true
	_shadow.rotation_degrees.x = -90.0
	_shadow.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_shadow.transparent = true
	_shadow.shaded = false
	_shadow.position = Vector3(0.0, 0.6, 0.0)
	add_child(_shadow)

	_shadow_ray = RayCast3D.new()
	_shadow_ray.name = "SombraRay"
	# El rayo baja por el plano de juego, dentro de la caja de terreno. El nodo
	# del zorro ya está en PLANE_Z, así que el desfase local es cero (con
	# -PLANE_Z el rayo caería justo en el borde trasero de la plataforma).
	_shadow_ray.position = Vector3(0.0, 10.0, 0.0)
	_shadow_ray.target_position = Vector3(0.0, -300.0, 0.0)
	_shadow_ray.collision_mask = 1
	_shadow_ray.exclude_parent = true
	_shadow_ray.enabled = true
	add_child(_shadow_ray)

	_dust = CPUParticles3D.new()
	_dust.name = "Dust"
	_dust.emitting = false
	_dust.amount = 10
	_dust.lifetime = 0.55
	_dust.one_shot = true
	_dust.explosiveness = 0.92
	_dust.local_coords = false
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_dust.emission_sphere_radius = 3.0
	_dust.direction = Vector3(0.0, 1.0, 0.0)
	_dust.spread = 80.0
	_dust.initial_velocity_min = 14.0
	_dust.initial_velocity_max = 52.0
	_dust.gravity = Vector3(0.0, -160.0, 0.0)
	_dust.scale_amount_min = 0.35
	_dust.scale_amount_max = 0.9
	_dust.color = P.DUST
	_dust.mesh = W.particle_mesh(6.0)
	_dust.material_override = W.particle_material(_art.puff_texture(), false)
	_dust.position = Vector3(0.0, 2.0, 0.0)
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
	if Input.is_action_just_released("ui_accept") and velocity.y > 120.0:
		velocity.y *= 0.5

	# --- gravedad ---
	if not on_floor:
		var g := GRAVITY * (FALL_MULT if velocity.y < 0.0 else 1.0)
		velocity.y -= g * delta
	else:
		velocity.y -= GRAVITY * delta
	velocity.y = maxf(velocity.y, -MAX_FALL)

	# La profundidad queda fija: el juego se lee de costado.
	velocity.z = 0.0
	move_and_slide()
	global_position.z = W.PLANE_Z

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

	if global_position.y < -460.0:
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
	_shadow.global_position = Vector3(hit.x, hit.y + 0.8, W.PLANE_Z)
	_shadow.scale = Vector3(1.0 - t * 0.38, 1.0 - t * 0.28, 1.0)
	_shadow.modulate = Color(1.0, 1.0, 1.0, 0.9 * (1.0 - t * 0.72))


func _update_animation(delta: float) -> void:
	var bob := 0.0
	if not is_on_floor():
		var anim := "jump" if velocity.y > 0.0 else "fall"
		if _sprite.animation != anim:
			_sprite.play(anim)
		_sprite.speed_scale = 1.0
	elif absf(velocity.x) > 18.0:
		if _sprite.animation != "run":
			_sprite.play("run")
		_sprite.speed_scale = clampf(absf(velocity.x) / SPEED, 0.7, 1.35)
		_bob += delta * (11.0 + absf(velocity.x) * 0.035)
		bob = absf(sin(_bob)) * 0.8
	else:
		if _sprite.animation != "idle":
			_sprite.play("idle")
		_sprite.speed_scale = 1.0
		_bob = 0.0
	_sprite.position.y = move_toward(_sprite.position.y, SPRITE_CENTER_Y + bob, delta * 26.0)
	_sprite.flip_h = _facing < 0


func _stretch(target: Vector2) -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(_sprite, "scale", Vector3(target.x, target.y, 1.0), 0.07)
	_squash_tween.tween_property(_sprite, "scale", Vector3.ONE, 0.20) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _puff(amount: int, strength: float) -> void:
	if _dust == null:
		return
	_dust.amount = maxi(3, amount)
	_dust.initial_velocity_max = 52.0 * strength
	_dust.restart()


func bounce() -> void:
	velocity.y = 370.0
	_stretch(Vector2(0.8, 1.2))
	_puff(7, 0.9)


func respawn() -> void:
	if _invuln > 0.0:
		return
	_invuln = 1.0
	velocity = Vector3.ZERO
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
