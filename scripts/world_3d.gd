extends RefCounted
## Convenciones del mundo 2.5D.
##
## El nivel se sigue diseñando en 2D (x horizontal, y hacia arriba en negativo,
## igual que en los archivos de zona). Al construirlo, cada punto se lleva a un
## mundo 3D:
##
##   x3 = x2
##   y3 = -y2      (en 3D la altura crece hacia +Y)
##   z3 = PLANE_Z  (plano de juego; las plataformas se hunden hacia -Z)
##
## Las plataformas son cajas 3D: su cara frontal queda en z = 0 y el cuerpo se
## extiende hacia atrás (z negativo). El zorro, los hongos, los saberes y las
## puertas viven en PLANE_Z, en el centro de la tapa: así caminan por el medio
## del camino y no por el borde que da a la cámara. El fondo y el primer plano
## ocupan z negativos/positivos más lejanos.
##
## La cámara mira de costado con una inclinación leve: así se ven las tapas de
## las plataformas y un poco los costados, sin perder la lectura de plataformas.

# --- plano de juego ---------------------------------------------------
## Profundidad de las cajas de terreno (de z=0 hacia atrás).
const PLATFORM_DEPTH := 120.0
## z del plano donde viven las entidades y el zorro: el centro de la tapa del
## terreno. En la cara frontal (z=0) quedarían al borde, como a punto de caerse
## hacia la cámara.
const PLANE_Z := -PLATFORM_DEPTH * 0.5
## z de la cara frontal de las plataformas.
const FRONT_Z := 0.0
## z de los props decorativos, un poco por detrás del plano de juego para que
## no tapen al zorro al pasar.
const PROP_Z := PLANE_Z - 2.0

# --- cámara -----------------------------------------------------------
## Distancia de la cámara al plano de juego.
const CAM_DISTANCE := 520.0
## Campo de visión vertical, en grados. Junto con CAM_DISTANCE reproduce el
## encuadre del viejo zoom 2.2 sobre una ventana de 1152x648.
const CAM_FOV := 32.0
## Inclinación hacia abajo (negativa) y giro leve para ver el volumen.
const CAM_PITCH := -8.0
const CAM_YAW := 10.0
const CAM_NEAR := 1.0
const CAM_FAR := 3000.0
## Distancia del cielo (hijo de la cámara, siempre delante del fondo).
const SKY_DISTANCE := 1600.0

# --- fondo ------------------------------------------------------------
## Suaviza las capas lejanas; false las deja con píxeles duros.
const BG_SMOOTH := true


## Lleva un punto de diseño 2D al mundo 3D.
static func to_world(p: Vector2, z := PLANE_Z) -> Vector3:
	return Vector3(p.x, -p.y, z)


## Vuelve de un punto 3D a las coordenadas 2D de diseño.
static func to_side(p: Vector3) -> Vector2:
	return Vector2(p.x, -p.y)


## Material aditivo para brillos (luciérnagas, hojas de saber, puertas).
## Con "billboard" el quad mira siempre a la cámara, como los sprites del juego.
static func additive_material(tex: Texture2D, tint: Color, billboard := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = tex
	mat.albedo_color = tint
	# El modulate del Sprite3D llega como color de vértice; sin esto, los
	# materiales propios ignoran el parpadeo y el fundido.
	mat.vertex_color_use_as_albedo = true
	if billboard:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.disable_fog = true
	return mat


## Quad para partículas 3D. El material con BILLBOARD_PARTICLES lo orienta
## hacia la cámara; CPUParticles3D no tiene textura propia, dibuja un mesh.
static func particle_mesh(size := 6.0) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	return quad


## Material para partículas 3D: siempre sin luz, con el color de la partícula.
static func particle_material(tex: Texture2D, additive := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.albedo_texture = tex
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.disable_fog = true
	return mat
