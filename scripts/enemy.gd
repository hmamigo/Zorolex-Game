extends CharacterBody3D
## Hongo del bosque en 2.5D: patrulla por el plano X/Y, gira en bordes y paredes
## y se aplasta al saltarle encima. Al morir suelta una nube de esporas.

const ART = preload("res://scripts/pixel_art.gd")
const P = preload("res://scripts/palette.gd")
const W = preload("res://scripts/world_3d.gd")

const GRAVITY := 1250.0
const SPEED := 52.0

var patrol_left := 0.0
var patrol_right := 0.0

var _art: ART
var _sprite: AnimatedSprite3D
var _shadow: Sprite3D
var _area: Area3D
var _shape: CollisionShape3D
var _ledge: RayCast3D
var _dir := 1.0
var _dead := false


## Nodo raíz del juego (main.gd). Los enemigos cuelgan del nodo "Mundo", así que
## se sube por los padres hasta encontrar el que expone la cámara y los avisos.
func _juego() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method("mostrar_aviso"):
			return n
		n = n.get_parent()
	return null


func _ready() -> void:
	add_to_group("enemy")
	_art = ART.new()

	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(18.0, 22.0, 14.0)
	_shape.shape = box
	_shape.position = Vector3(0.0, 11.0, 0.0)
	add_child(_shape)

	_sprite = AnimatedSprite3D.new()
	_sprite.name = "Visual"
	_sprite.sprite_frames = _art.mushroom_frames()
	_sprite.pixel_size = 1.0
	_sprite.position = Vector3(0.0, 13.0, 0.0)
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.shaded = false
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_sprite.play("walk")
	add_child(_sprite)

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
	_shadow.scale = Vector3(0.62, 0.8, 1.0)
	add_child(_shadow)

	_area = Area3D.new()
	_area.name = "DetectionArea"
	_area.collision_mask = 1
	var acol := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(24.0, 24.0, 24.0)
	acol.shape = abox
	acol.position = Vector3(0.0, 12.0, 0.0)
	_area.add_child(acol)
	add_child(_area)

	_ledge = RayCast3D.new()
	# El rayo busca el piso en el plano de juego, dentro de la caja de terreno.
	# El hongo ya está en PLANE_Z: el desfase local en z es cero.
	_ledge.position = Vector3(10.0, 3.0, 0.0)
	_ledge.target_position = Vector3(0.0, -16.0, 0.0)
	_ledge.collision_mask = 1
	_ledge.exclude_parent = true
	_ledge.enabled = true
	add_child(_ledge)


func _physics_process(delta: float) -> void:
	if _dead:
		velocity = Vector3.ZERO
		return

	velocity.y -= GRAVITY * delta
	velocity.y = maxf(velocity.y, -1000.0)

	if global_position.x - 8.0 <= patrol_left:
		_dir = 1.0
	elif global_position.x + 8.0 >= patrol_right:
		_dir = -1.0
	velocity.x = _dir * SPEED
	velocity.z = 0.0
	move_and_slide()
	global_position.z = W.PLANE_Z

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
		var p := body as CharacterBody3D
		if p == null:
			continue
		var enemy_top := global_position.y + 20.0
		# Aterrizar sobre el hongo detiene la caída (move_and_slide), así que
		# se comprueba la posición de los pies y no solo la velocidad.
		var stomping := p.velocity.y < 20.0 and p.global_position.y >= enemy_top - 8.0
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
	velocity = Vector3.ZERO
	_sprite.play("squash")
	_set_disabled.call_deferred(_shape)
	_area.set_deferred("monitoring", false)

	var spores := CPUParticles3D.new()
	spores.one_shot = true
	spores.emitting = true
	spores.amount = 18
	spores.lifetime = 0.7
	spores.explosiveness = 1.0
	spores.local_coords = false
	spores.mesh = W.particle_mesh(6.0)
	spores.material_override = W.particle_material(_art.puff_texture(), false)
	spores.color = Color(P.CAP_L.r, P.CAP_L.g, P.CAP_L.b, 0.95)
	spores.direction = Vector3(0.0, 1.0, 0.0)
	spores.spread = 110.0
	spores.initial_velocity_min = 45.0
	spores.initial_velocity_max = 135.0
	spores.gravity = Vector3(0.0, -420.0, 0.0)
	spores.scale_amount_min = 0.4
	spores.scale_amount_max = 1.0
	spores.position = Vector3(0.0, 12.0, 0.0)
	add_child(spores)

	var juego := _juego()
	if juego != null and juego.has_method("camera_shake"):
		juego.camera_shake(2.2)

	var t := create_tween()
	t.tween_interval(0.35)
	t.tween_property(_sprite, "modulate:a", 0.0, 0.45)
	t.parallel().tween_property(_shadow, "modulate:a", 0.0, 0.45)
	t.tween_callback(queue_free)


func _set_disabled(s: CollisionShape3D) -> void:
	if s != null:
		s.set_deferred("disabled", true)
