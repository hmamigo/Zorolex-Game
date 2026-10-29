extends RefCounted
## Fabrica procedural de arte: sprites, tiles de terreno, capas de bosque,
## decoracion y texturas de particulas. Todo se genera en memoria, sin assets.

const P = preload("res://scripts/palette.gd")
const SPRITES = preload("res://scripts/sprite_data.gd")

var _cache := {}


# =====================================================================
#  Sprites del elenco
# =====================================================================
func fox_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	_add_anim(sf, "idle", ["idle_0", "idle_1", "idle_0", "idle_1", "idle_0", "idle_blink"], 3.4, true)
	_add_anim(sf, "run", ["run_0", "run_1", "run_2", "run_3"], 10.5, true)
	_add_anim(sf, "jump", ["jump"], 1.0, false)
	_add_anim(sf, "fall", ["fall"], 1.0, false)
	return sf


func mushroom_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	_add_anim(sf, "walk", ["walk_0", "walk_1"], 4.5, true)
	_add_anim(sf, "squash", ["squash"], 1.0, false)
	return sf


func _add_anim(sf: SpriteFrames, anim: String, keys: Array, fps: float, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for key in keys:
		sf.add_frame(anim, _sprite_texture(key))


func _sprite_texture(key: String) -> ImageTexture:
	var cache_key := "sprite_" + key
	if _cache.has(cache_key):
		return _cache[cache_key]
	var rows: Array = SPRITES.FOX[key] if SPRITES.FOX.has(key) else SPRITES.MUSHROOM[key]
	var h: int = rows.size()
	var w: int = String(rows[0]).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(h):
		var row: String = rows[y]
		for x in range(mini(w, row.length())):
			var c: Color = P.LEGEND.get(row[x], Color(0, 0, 0, 0))
			if c.a > 0.0:
				img.set_pixel(x, y, c)
	_polish_sprite(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[cache_key] = tex
	return tex


## Pulido comun a todos los sprites, calculado desde la paleta:
##  - contorno selectivo: el borde exterior deja de ser tinta pura y toma un
##    tono oscuro del color que tiene al lado (pelaje -> rojo oscuro, bufanda ->
##    verde profundo), asi el personaje se integra en la escena en vez de
##    parecer un recorte.
##  - luz cenital: los pixeles bajo un borde superior se calientan un poco.
##    Es simetrica, para que siga siendo correcta con flip_h.
func _polish_sprite(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src: Image = img.duplicate()
	for y in range(h):
		for x in range(w):
			var c := src.get_pixel(x, y)
			if c.a <= 0.0 or not c.is_equal_approx(P.INK):
				continue
			if not _touches_clear(src, x, y):
				continue
			var fill := _inner_color(src, x, y)
			if fill.a > 0.0:
				img.set_pixel(x, y, fill.lerp(P.INK, 0.56))
	for y in range(1, h):
		for x in range(w):
			var c := src.get_pixel(x, y)
			if c.a <= 0.0 or c.is_equal_approx(P.INK):
				continue
			if src.get_pixel(x, y - 1).is_equal_approx(P.INK) \
					and (y < 2 or src.get_pixel(x, y - 2).a <= 0.0):
				img.set_pixel(x, y, c.lerp(P.RIM, 0.24))


func _touches_clear(img: Image, x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 0 or ny < 0 or nx >= img.get_width() or ny >= img.get_height():
			return true
		if img.get_pixel(nx, ny).a <= 0.0:
			return true
	return false


## Color medio de los vecinos opacos que no son tinta (transparente si no hay).
func _inner_color(img: Image, x: int, y: int) -> Color:
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue
			var nx := x + ox
			var ny := y + oy
			if nx < 0 or ny < 0 or nx >= img.get_width() or ny >= img.get_height():
				continue
			var c := img.get_pixel(nx, ny)
			if c.a <= 0.0 or c.is_equal_approx(P.INK):
				continue
			sum += c
			n += 1
	if n == 0:
		return Color(0, 0, 0, 0)
	return Color(sum.r / n, sum.g / n, sum.b / n, 1.0)


# =====================================================================
#  Terreno
# =====================================================================
func ground_texture(size: Vector2i, floating := false, seed := 0) -> ImageTexture:
	var w := maxi(size.x, 8)
	var h := maxi(size.y, 10)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7717 + w * 131 + h * 17

	# estratos: bandas planas de tierra con frontera ondulada y trama en el
	# cambio de tono. Se lee como capas de suelo, no como un degradado.
	var strata_at := [0.0, 0.20, 0.40, 0.60, 0.78]
	var strata_tone: Array[Color] = [
		P.DIRT, P.DIRT.lerp(P.DIRT_D, 0.5), P.DIRT_D,
		P.DIRT_D.lerp(P.DIRT_DD, 0.5), P.DIRT_DD,
	]
	var phases: Array[float] = []
	for k in range(strata_at.size()):
		phases.append(rng.randf() * TAU)
	var edge_y: Array = []   # edge_y[k][x] = fila donde empieza el estrato k
	for k in range(strata_at.size()):
		var col := PackedFloat32Array()
		col.resize(w)
		for x in range(w):
			col[x] = strata_at[k] * float(h) \
				+ sin(x * (0.031 + 0.007 * k) + phases[k]) * 3.0 \
				+ sin(x * 0.11 + phases[k] * 2.0) * 1.1
		edge_y.append(col)
	for x in range(w):
		for y in range(h):
			var idx := 0
			for k in range(1, strata_at.size()):
				var yb: float = edge_y[k][x]
				if float(y) >= yb:
					idx = k
				elif float(y) >= yb - 1.6 and (x + y) % 2 == 0:
					idx = k
			img.set_pixel(x, y, strata_tone[idx])

	# grietas finas siguiendo los estratos, con labio de luz debajo
	for k in range(1, strata_at.size()):
		for i in range(2 + int(w / 110.0)):
			var sx := rng.randi_range(4, maxi(5, w - 26))
			var ln := rng.randi_range(7, 20)
			for j in range(ln):
				var xx := sx + j
				if xx >= w:
					break
				var yy := int(round(float(edge_y[k][xx]))) + int(round(sin(j * 0.55) * 0.8))
				_px(img, xx, yy, P.DIRT_DD.lerp(P.INK_SOFT, 0.45))
				if j % 4 == 1:
					_px(img, xx, yy + 1, P.DIRT_L.lerp(img.get_pixel(clampi(xx, 0, w - 1), clampi(yy + 1, 0, h - 1)), 0.5))

	# grano de tierra: mas fino y menos ruidoso, relativo al tono del estrato
	for y in range(12, h):
		for x in range(w):
			var r := rng.randf()
			var base := img.get_pixel(x, y)
			if r < 0.016:
				img.set_pixel(x, y, base.darkened(0.17))
			elif r < 0.036:
				img.set_pixel(x, y, base.lightened(0.10))

	# terrones sueltos con luz arriba-izquierda y sombra abajo
	for i in range(8 + int(w / 34.0)):
		var cx := rng.randi_range(3, w - 4)
		var cy := rng.randi_range(16, maxi(17, h - 6))
		var cr := rng.randi_range(1, 3)
		var here := img.get_pixel(cx, cy)
		_ellipse(img, cx, cy + 1, cr + 1, cr, here.darkened(0.26))
		_ellipse(img, cx, cy, cr, maxi(1, cr - 1), here.darkened(0.08))
		_px(img, cx - 1, cy - 1, here.lightened(0.18))

	# raices finas y raices gruesas que bajan desde el pasto
	for i in range(3 + int(w / 150.0)):
		var rx := rng.randi_range(10, maxi(11, w - 10))
		var ry := rng.randi_range(13, maxi(14, h - 14))
		var steps := rng.randi_range(5, 14)
		var dx := rng.randi_range(-1, 1)
		for k in range(steps):
			_px(img, rx + dx, ry + k, P.ROOT)
			if rng.randf() < 0.45:
				_px(img, rx + dx + 1, ry + k, P.DIRT_DD)
			if rng.randf() < 0.28:
				dx += 1 if rng.randf() < 0.5 else -1
	for i in range(1 + int(w / 130.0)):
		var rx := rng.randi_range(12, maxi(13, w - 12))
		var ry := rng.randi_range(12, maxi(13, h - 20))
		var rl := rng.randi_range(8, 22)
		var bend := rng.randf_range(-0.5, 0.5)
		for k in range(rl):
			var xx := int(round(rx + sin(k * 0.35) * 2.0 + bend * k))
			_px(img, xx, ry + k, P.ROOT)
			_px(img, xx + 1, ry + k, P.ROOT.lerp(P.DIRT_D, 0.4))
			if k > 4 and k % 6 == 0:
				for j in range(1, 4):
					_px(img, xx + (j if (k / 6) % 2 == 0 else -j), ry + k + j / 2, P.ROOT)

	# piedras enterradas con contorno, cuerpo, luz y a veces musgo
	for i in range(3 + int(w / 70.0)):
		var cx := rng.randi_range(6, w - 7)
		var cy := rng.randi_range(20, maxi(21, h - 12))
		_stone(img, cx, cy, rng.randi_range(2, 4), rng)

	# humus oscuro junto al borde inferior
	var deep_start := maxi(h - 16, 0)
	for y in range(deep_start, h):
		var a := float(y - deep_start) / maxf(float(h - deep_start), 1.0)
		for x in range(w):
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, c.lerp(P.INK_SOFT, a * 0.5))

	# pasto: cinco tonos planos, borde inferior que gotea y brillo arriba
	var grass_h := 9 if not floating else 7
	var tops: Array[int] = []
	for x in range(w):
		var wave := sin(x * 0.071) * 1.15 + sin(x * 0.021 + 1.7) * 1.35
		tops.append(clampi(int(round(2.0 + wave)), 0, 4))
	var drip: Array[int] = []
	var dv := 0
	for x in range(w):
		if rng.randf() < 0.45:
			dv = clampi(dv + rng.randi_range(-2, 2), -1, 3)
		drip.append(dv)
	var lit_depth: Array[int] = []
	var lv := 2
	for x in range(w):
		if rng.randf() < 0.35:
			lv = clampi(lv + rng.randi_range(-1, 1), 1, 4)
		lit_depth.append(lv)
	var outline := P.GRASS_DD.lerp(P.INK_SOFT, 0.5)
	for x in range(w):
		var top := tops[x]
		var gh := grass_h + drip[x]
		if not floating and (x < 5 or x > w - 6):
			gh += 2   # el pasto cuelga sobre el borde del barranco
		for y in range(top, top + gh):
			var d := y - top
			var c: Color
			if d == 0:
				c = P.GRASS_LL.lerp(P.GOLD, 0.18)
			elif d <= lit_depth[x]:
				c = P.GRASS_L
			elif d <= gh - 5:
				c = P.GRASS
			elif d <= gh - 3:
				c = P.GRASS_D
			else:
				c = P.GRASS_DD
			_px(img, x, y, c)
		_px(img, x, top + gh, outline)
		# briznas sueltas sobre el borde
		if rng.randf() < 0.30:
			var bl := rng.randi_range(1, 4)
			var lean := rng.randf_range(-0.5, 0.5)
			var col := P.GRASS_L if rng.randf() < 0.6 else P.GRASS_LL
			for k in range(bl):
				_px(img, x + int(round(lean * k)), top - 1 - k, col)

	# pecas de musgo en el pasto
	for i in range(2 + int(w / 90.0)):
		var mx := rng.randi_range(2, w - 3)
		var my := tops[mx] + rng.randi_range(0, 3)
		_ellipse(img, mx, my, rng.randi_range(1, 3), 1, P.MOSS)
		_px(img, mx, my, P.MOSS_L)

	# sombra del pasto sobre la tierra
	for x in range(w):
		var gy := tops[x] + grass_h + drip[x] + 1
		for k in range(8):
			if gy + k >= h:
				break
			var c := img.get_pixel(x, gy + k)
			if c.a > 0.0:
				img.set_pixel(x, gy + k, c.lerp(P.INK_SOFT, 0.34 * (1.0 - float(k) / 8.0)))

	# raicillas que asoman bajo el pasto
	for i in range(1 + int(w / 110.0)):
		var rx := rng.randi_range(2, w - 3)
		if tops[rx] + grass_h + 4 >= h:
			continue
		var ry := tops[rx] + grass_h + drip[rx] + 1
		var rl := rng.randi_range(3, 8)
		for k in range(rl):
			_px(img, rx + (k / 3), ry + k, P.ROOT)

	if floating:
		# esquinas redondeadas e irregularidad del borde inferior
		var cut := 6
		for x in range(w):
			for y in range(h - cut, h):
				var dx := 0.0
				if x < cut:
					dx = float(cut - x)
				elif x > w - 1 - cut:
					dx = float(x - (w - 1 - cut))
				if dx > 0.0 and float(y - (h - cut)) < (dx - 0.6) * 0.85:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
		# rocas y terrones que cuelgan del borde
		for i in range(2 + int(w / 90.0)):
			var cx := rng.randi_range(8, w - 9)
			var cy := h - rng.randi_range(1, 4)
			_ellipse(img, cx, cy, rng.randi_range(2, 6), rng.randi_range(1, 3),
				P.DIRT_DD.lerp(P.STONE_D, 0.35))
		# contorno oscuro siguiendo la silueta
		for x in range(w):
			for y in range(h - 1, -1, -1):
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					img.set_pixel(x, y, c.lerp(P.INK_SOFT, 0.55))
					break
	else:
		# acantilados: borde desmenuzado, en sombra a la izquierda y con luz del
		# sol a la derecha. Solo bajo el pasto, que ya tiene su propio borde.
		var cl := 0
		var cr := 0
		var rim := P.DIRT_DD.lerp(P.INK_SOFT, 0.55)
		for y in range(h):
			if y < grass_h + 3:
				continue
			cl = clampi(cl + rng.randi_range(-1, 1), 0, 3)
			cr = clampi(cr + rng.randi_range(-1, 1), 0, 3)
			for x in range(cl):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			for x in range(cr):
				img.set_pixel(w - 1 - x, y, Color(0, 0, 0, 0))
			_px(img, cl, y, rim)
			_px(img, w - 1 - cr, y, rim)
			var lit := img.get_pixel(clampi(w - 2 - cr, 0, w - 1), y)
			if lit.a > 0.0:
				img.set_pixel(w - 2 - cr, y, lit.lerp(P.DIRT_L, 0.42))
			var shade := img.get_pixel(clampi(cl + 1, 0, w - 1), y)
			if shade.a > 0.0:
				img.set_pixel(cl + 1, y, shade.lerp(P.INK_SOFT, 0.28))
		for x in range(w):
			var c := img.get_pixel(x, h - 1)
			if c.a > 0.0:
				img.set_pixel(x, h - 1, c.lerp(P.INK_SOFT, 0.6))

	return ImageTexture.create_from_image(img)


func _stone(img: Image, cx: int, cy: int, r: int, rng: RandomNumberGenerator) -> void:
	var rx := r + 1 + rng.randi_range(0, 1)
	var ry := maxi(2, r)
	_ellipse(img, cx, cy, rx + 1, ry + 1, P.INK_SOFT.lerp(P.DIRT_DD, 0.5))
	_ellipse(img, cx, cy, rx, ry, P.STONE_D)
	_ellipse(img, cx - 1, cy - 1, maxi(1, rx - 1), maxi(1, ry - 1), P.STONE)
	_px(img, cx - rx + 2, cy - ry + 1, P.STONE_L)
	_px(img, cx - rx + 3, cy - ry + 1, P.STONE_L)
	if rng.randf() < 0.4:
		_px(img, cx + 1, cy - ry + 1, P.MOSS)
		_px(img, cx + 2, cy - ry + 1, P.MOSS_L)


func _speckle(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color,
		rng: RandomNumberGenerator, density: float) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var nx := float(x - cx) / maxf(float(rx), 1.0)
			var ny := float(y - cy) / maxf(float(ry), 1.0)
			if nx * nx + ny * ny <= 1.0 and rng.randf() < density:
				_px(img, x, y, c)


func _pebble(img: Image, cx: int, cy: int, r: int) -> void:
	var body := P.STONE if (cx + cy) % 3 != 0 else P.STONE_D
	_ellipse(img, cx, cy + 1, r + 1, maxi(1, r), P.DIRT_DD)
	_ellipse(img, cx, cy, r, maxi(1, r - 1), body)
	if r > 1:
		_px(img, cx - 1, cy - 1, P.STONE_L)


func vine_texture(seed: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 977 + 13
	var h := rng.randi_range(18, 44)
	var img := Image.create(7, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var x := 3
	for y in range(h):
		if rng.randf() < 0.2:
			x += 1 if rng.randf() < 0.5 else -1
		x = clampi(x, 1, 5)
		_px(img, x, y, P.GRASS_D)
		if y % 4 == 0 and y > 2:
			var dir := 1 if (y / 4) % 2 == 0 else -1
			_ellipse(img, x + dir, y, 1, 1, P.MOSS)
			_px(img, x + dir, y - 1, P.MOSS_L)
	return ImageTexture.create_from_image(img)


# =====================================================================
#  Bosque de fondo (mitad de resolucion, se dibuja al doble)
# =====================================================================
func far_forest(seed: int) -> ImageTexture:
	var w := 480
	var h := 240
	var img := _image(w, h)
	# colinas lejanas
	var pts := PackedVector2Array()
	pts.append(Vector2(0, h))
	for x in range(0, w + 1, 6):
		var y := 192.0 + sin(TAU * x / w * 2.0) * 6.0 + sin(TAU * x / w * 5.0 + 1.4) * 2.5
		pts.append(Vector2(x, y))
	pts.append(Vector2(w, h))
	_poly(img, pts, Color(P.FOG.r, P.FOG.g, P.FOG.b, 0.30))

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(72):
		var x := rng.randi_range(2, w - 2)
		var base := 198 + rng.randi_range(-4, 8)
		var hh := rng.randi_range(16, 48)
		var c := P.FOREST_FAR.lerp(P.FOG, rng.randf_range(0.22, 0.46))
		_pine_w(img, x, base, hh, c, c, 2, false)
	# arboles bajos y mas transparentes delante de la linea
	for i in range(34):
		var x := rng.randi_range(0, w)
		var base := 206 + rng.randi_range(-2, 6)
		var hh := rng.randi_range(10, 24)
		var fc := P.FOREST_FAR.lerp(P.FOG, rng.randf_range(0.36, 0.56))
		_pine_w(img, x, base, hh, fc, fc, 1, false)
	return _smooth_tex(img)


func mid_forest(seed: int) -> ImageTexture:
	var w := 480
	var h := 260
	var img := _image(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# loma baja
	var pts := PackedVector2Array()
	pts.append(Vector2(0, h))
	for x in range(0, w + 1, 8):
		var y := 226.0 + sin(TAU * x / w * 3.0 + 0.7) * 7.0
		pts.append(Vector2(x, y))
	pts.append(Vector2(w, h))
	_poly(img, pts, P.FOREST_MID.lerp(P.FOG, 0.55))
	for i in range(26):
		var x := rng.randi_range(8, w - 8)
		var base := 214 + rng.randi_range(-2, 10)
		var hh := rng.randi_range(28, 62)
		_pine_w(img, x, base, hh, Color(P.FOREST_MID.r, P.FOREST_MID.g, P.FOREST_MID.b, 1.0),
			Color(P.FOREST_NEAR.r, P.FOREST_NEAR.g, P.FOREST_NEAR.b, 1.0), 3)
		if rng.randf() < 0.5:
			var lx := x - rng.randi_range(4, 10)
			_px(img, lx, base - hh + 2, Color(P.FOREST_FAR.r, P.FOREST_FAR.g, P.FOREST_FAR.b, 0.8))
	# la base se disuelve en niebla
	# (sin transparencia: se funde con el color de la neblina para no dejar una
	# cinta flotando ni dejar ver las capas de atras)
	for y in range(h - 34, h):
		var a := 1.0 - float(y - (h - 34)) / 34.0
		for x in range(w):
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				var f := c.lerp(P.FOG, 1.0 - a)
				img.set_pixel(x, y, Color(f.r, f.g, f.b, c.a))
	return _smooth_tex(img)


func near_forest(seed: int) -> ImageTexture:
	var w := 480
	var h := 300
	var img := _image(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# troncos principales (suben fuera de cuadro para no cortarse en el cielo)
	var spots := [44, 218, 344, 446]
	for i in range(spots.size()):
		var x: int = spots[i] + rng.randi_range(-6, 6)
		var top := 0
		var base := 302
		var tw := rng.randi_range(17, 27)
		var st := rng.state
		for off in [-w, 0, w]:
			rng.state = st
			_trunk(img, rng, x + off, top, base, tw)
	return _smooth_tex(img)


func _trunk(img: Image, rng: RandomNumberGenerator, x: int, top: int, base: int, tw: int) -> void:
	var span := base - top
	var groove_count := 2 + int(tw / 9.0)
	var grooves: Array = []
	for g in range(groove_count):
		grooves.append([rng.randi_range(2, maxi(3, tw - 3)), rng.randi_range(3, 8), rng.randi_range(0, 11)])
	var body := P.FOREST_NEAR.darkened(0.30)
	var body_l := P.FOREST_NEAR.darkened(0.12)
	var side_d := P.FOREST_FRONT.darkened(0.16)

	# raices que se abren en la base
	for k in range(5):
		var dir := -1 if k % 2 == 0 else 1
		var rlen := rng.randi_range(8, 26)
		for j in range(rlen):
			var yy := base - 1 - int(pow(float(j) / float(rlen), 0.75) * 7.0)
			_px(img, x + dir * (tw / 2 + j), yy, body)

	for y in range(top, base):
		var t := float(y - top) / float(span)
		var ww := int(round(tw * (0.70 + t * 0.62)))
		var wob := int(round(sin(y * 0.055 + x * 0.7) * 1.4 + sin(y * 0.021) * 1.1))
		var x0 := x - ww / 2 + wob
		# cuerpo con volumen: sombra a la izquierda, luz de la luna a la derecha
		for k in range(ww):
			var nx := float(k) / maxf(float(ww - 1), 1.0)
			var c := body
			if nx < 0.16:
				c = body.lerp(side_d, 0.55)
			elif nx < 0.34:
				c = body.lerp(body_l, 0.35)
			elif nx > 0.88:
				c = body.lerp(body_l, 0.35)
			elif nx > 0.74:
				c = body.lerp(body_l, 0.18)
			_px(img, x0 + k, y, c)
		# filo trasero iluminado: rim calido del sol bajo
		var glow := 0.5 + 0.5 * sin(y * 0.038 + x * 0.7)
		var rim_c := body.lerp(P.RIM, 0.26 + 0.20 * glow)
		_px(img, x0 + ww - 1, y, rim_c)
		_px(img, x0 + ww - 2, y, body_l.lerp(P.RIM, 0.12))
		_px(img, x0, y, side_d)
		# surcos verticales de corteza
		for gr in grooves:
			if gr[0] < ww - 1 and (y + gr[2]) % (gr[1] * 3) < gr[1]:
				_px(img, x0 + gr[0], y, P.FOREST_FRONT)
				_px(img, x0 + gr[0] + 1, y, body_l.darkened(0.08))

	# manchas de musgo bajas, apenas visibles
	for m in range(4):
		var my := top + int(span * rng.randf_range(0.72, 0.98))
		var mx := x - tw / 2 + rng.randi_range(2, tw - 2)
		var mr := rng.randi_range(2, 4)
		_ellipse(img, mx, my, mr, 1, P.MOSS.darkened(0.62))
		_px(img, mx, my - 1, P.MOSS.darkened(0.55))


func _thin_tree(img: Image, rng: RandomNumberGenerator, x: int, top: int, base: int, tw: int, c: Color) -> void:
	for y in range(top, base):
		_px(img, x, y, c)
		_px(img, x + 1, y, c)
		if tw > 4 and y % 3 == 0:
			_px(img, x + 2, y, c)
	for b in range(3):
		var by := top + rng.randi_range(8, 40)
		var dir := -1 if b % 2 == 0 else 1
		var blen := rng.randi_range(5, 11)
		for k in range(blen):
			_px(img, x + dir * k, by - k / 2, c)
			if k % 3 == 0:
				_px(img, x + dir * (k + 1), by - k / 2 - 1, c)


func valley_forest(seed: int) -> ImageTexture:
	var w := 480
	var h := 200
	var img := _image(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Tres crestas: cada una se disuelve en la neblina por el filo y lleva
	# siluetas de pino que rompen la linea recta del horizonte.
	var ridges := [
		{"base": 134.0, "amp": 8.0, "freq": 2.0, "phase": 0.35, "col": P.FOREST_FAR,
			"a": 0.48, "trees": 34, "ta": 0.38, "th": 30},
		{"base": 158.0, "amp": 7.5, "freq": 3.0, "phase": 1.90, "col": P.FOREST_MID,
			"a": 0.74, "trees": 26, "ta": 0.68, "th": 34},
		{"base": 177.0, "amp": 5.0, "freq": 2.0, "phase": 3.10, "col": P.FOREST_NEAR,
			"a": 0.90, "trees": 20, "ta": 0.94, "th": 32},
	]
	for r in ridges:
		var base: float = r["base"]
		var amp: float = r["amp"]
		var freq: float = r["freq"]
		var phase: float = r["phase"]
		var col: Color = r["col"]
		var alpha: float = r["a"]
		var ridge_col := col.lerp(P.FOG, (1.0 - alpha) * 0.85)
		# perfil del filo: dos senos para que no se lea como una banda plana
		var prof := PackedFloat32Array()
		prof.resize(w)
		for x in range(w):
			var t := float(x) / float(w)
			var yy := base + sin(TAU * t * freq + phase) * amp
			yy += sin(TAU * t * roundf(freq * 2.7 + 1.3) + phase * 1.7) * amp * 0.34
			prof[x] = yy
		# relleno con gradiente vertical: el filo se funde con la niebla
		for x in range(w):
			var top := int(round(prof[x]))
			for y in range(maxi(top, 0), h):
				var d := float(y - top)
				var haze := 0.56 * exp(-d / 4.0)
				var c := ridge_col.lerp(P.FOG, haze)
				_px(img, x, y, Color(c.r, c.g, c.b, 1.0))
		# arboles de la cresta, compuestos aparte para no agujerear la loma
		var trees := _image(w, h)
		for i in range(int(r["trees"])):
			var tx := rng.randi_range(0, w - 1)
			var th2 := rng.randi_range(int(r["th"]) - 5, int(r["th"]) + 7)
			var tc := col.lerp(P.FOG, (1.0 - float(r["ta"])) * 0.85)
			_pine_w(trees, tx, int(prof[tx]) + 3, th2, tc, tc, 1, false)
		img.blend_rect(trees, Rect2i(0, 0, w, h), Vector2i.ZERO)
	return _smooth_tex(img)
func light_shafts(seed: int) -> ImageTexture:
	var w := 480
	var h := 320
	var img := _image(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(7):
		var x0 := rng.randi_range(40, 280)
		var width := rng.randi_range(8, 26)
		var lean := rng.randf_range(0.18, 0.42)
		var alpha := rng.randf_range(0.05, 0.12)
		for y in range(h):
			var fade := sin(float(y) / float(h) * PI)
			var x := int(round(x0 + lean * float(y)))
			for k in range(width):
				var a := alpha * fade * (1.0 - float(k) / float(width))
				var px := x + k
				if px < 0 or px >= w:
					continue
				var c := img.get_pixel(px, y)
				img.set_pixel(px, y, Color(P.SUN.r, P.SUN.g, P.SUN.b, c.a + a))
	return _smooth_tex(img)


func foreground_grass(seed: int) -> ImageTexture:
	var w := 480
	var h := 140
	var img := _image(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var zones := [[0, 74], [406, 480]]
	for zone in zones:
		for i in range(20):
			var x := rng.randi_range(zone[0], zone[1])
			var hh := rng.randi_range(18, 60)
			var lean := rng.randf_range(-0.55, 0.3)
			var col := P.FOREST_FRONT if rng.randf() < 0.78 else P.FOREST_NEAR
			for k in range(hh):
				var xx := int(round(x + lean * k + sin(k * 0.12) * 1.4))
				_px(img, xx, h - 1 - k, col)
				if k < hh * 0.35:
					_px(img, xx + 1, h - 1 - k, col)
			var tip_x := int(round(x + lean * hh + sin(hh * 0.12) * 1.4))
			_px(img, tip_x, h - 1 - hh, P.FOREST_NEAR)
		# frondas
		for i in range(3):
			var fx := rng.randi_range(zone[0], zone[1])
			var fh := rng.randi_range(22, 44)
			var lean := rng.randf_range(-0.4, 0.2)
			for k in range(fh):
				var xx := int(round(fx + lean * k))
				_px(img, xx, h - 1 - k, P.FOREST_FRONT)
				if k > 6 and k % 3 == 0:
					var dir := 1 if (k / 3) % 2 == 0 else -1
					for j in range(1, 4):
						_px(img, xx + dir * j, h - 1 - k - j / 2, P.FOREST_FRONT)
	return ImageTexture.create_from_image(img)


func canopy_layer(seed: int) -> ImageTexture:
	var w := 480
	var h := 96
	var img := _image(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# silueta continua: una altura por columna
	var edge: Array[int] = []
	for x in range(w):
		var k := TAU / float(w)   # ciclos enteros: la textura empalma consigo misma
		var hh := 34.0 + sin(x * k * 3.0 + 0.6) * 9.0 + sin(x * k * 1.0 + 2.2) * 7.0 + sin(x * k * 10.0) * 3.0
		edge.append(clampi(int(round(hh)), 20, h - 14))
	for x in range(w):
		_fill(img, x, 0, 1, edge[x], P.FOREST_NEAR)
	# lobulos de hojas que redondean el borde
	for i in range(40):
		var cx := rng.randi_range(-12, w + 12)
		var cy := edge[posmod(cx, w)] - rng.randi_range(0, 7)
		_ellipse_w(img, cx, cy, rng.randi_range(8, 18), rng.randi_range(4, 9), P.FOREST_NEAR)
	# racimos de hojas que cuelgan del filo
	for i in range(34):
		var x := rng.randi_range(0, w - 1)
		var y0 := edge[x] + rng.randi_range(-1, 4)
		var rx := rng.randi_range(3, 8)
		var ry := rng.randi_range(2, 4)
		_ellipse_w(img, x, y0 + rng.randi_range(0, 2), rx, ry, P.FOREST_NEAR)
		if rng.randf() < 0.45:
			_px(img, x + rx / 2, y0 + 2, P.FOREST_NEAR.lerp(P.RIM, 0.22))
		if rng.randf() < 0.30:
			for k in range(rng.randi_range(1, 3)):
				_px(img, x + rng.randi_range(-2, 2), y0 + ry + 1 + k, P.FOREST_NEAR)
	# textura interna: manchas de follaje que dan volumen
	for i in range(26):
		var cx := rng.randi_range(0, w)
		var top_edge: int = edge[clampi(cx, 0, w - 1)]
		var cy := rng.randi_range(3, maxi(4, top_edge - 10))
		var cc := P.FOREST_NEAR.darkened(0.09) if i % 2 == 0 else P.FOREST_NEAR.lightened(0.03)
		_ellipse_masked_w(img, cx, cy, rng.randi_range(6, 16), rng.randi_range(3, 7), cc)
	# filo inferior iluminado
	for x in range(w):
		for y in range(h - 1, 1, -1):
			if img.get_pixel(x, y).a > 0.0 and img.get_pixel(x, y - 1).a == 0.0:
				_px(img, x, y, P.FOREST_MID.lerp(P.RIM, 0.30))
				if (x + seed) % 11 == 0:
					_px(img, x, y - 1, P.FOREST_NEAR.lerp(P.RIM, 0.18))
				break
	return _smooth_tex(img)


func foreground_clump(seed: int) -> ImageTexture:
	var w := 150
	var h := 110
	var img := _image(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# masa baja de arbustos que une las matas entre si
	for i in range(18):
		var x := int(round(pow(rng.randf(), 1.4) * float(w)))
		var y := h - rng.randi_range(-2, 12)
		_ellipse(img, x, y, rng.randi_range(6, 20), rng.randi_range(4, 11), P.FOREST_FRONT)
	# matas de pasto: pocas hojas por mata, anchas en la base y afiladas
	for i in range(13):
		var base_x := int(round(pow(rng.randf(), 1.7) * float(w - 4)))
		var blades := rng.randi_range(2, 4)
		for b in range(blades):
			var hh := rng.randi_range(14, 70)
			var lean := rng.randf_range(-0.6, 0.45)
			var col := P.FOREST_FRONT
			if rng.randf() < 0.22:
				col = P.FOREST_NEAR
			_blade(img, base_x + rng.randi_range(-4, 4), h - 1, hh, lean, col)
	# helechos
	for i in range(6):
		var fx := int(round(pow(rng.randf(), 1.5) * float(w - 8)))
		_frond(img, fx, h - 1, rng.randi_range(24, 58), rng.randf_range(-0.38, 0.22), P.FOREST_FRONT)
	# hojas anchas
	for i in range(7):
		var lx := int(round(pow(rng.randf(), 1.5) * float(w - 6)))
		var ly := h - rng.randi_range(12, 46)
		var ang := rng.randf_range(-0.9, 0.5)
		_leaf(img, lx, ly, ang, rng.randi_range(9, 17), rng.randi_range(2, 4), P.FOREST_FRONT)
	return ImageTexture.create_from_image(img)


func _blade(img: Image, x: int, base_y: int, length: int, lean: float, c: Color) -> void:
	# hoja afilada: 3 px de ancho en la base, 1 px en la punta
	for k in range(length):
		var xx := int(round(x + lean * k + sin(k * 0.10) * 1.4))
		var yy := base_y - k
		var half := int(round((1.0 - float(k) / float(length)) * 1.6))
		for j in range(-half, half + 1):
			_px(img, xx + j, yy, c)


func _frond(img: Image, x: int, base_y: int, length: int, lean: float, c: Color) -> void:
	for k in range(length):
		var xx := int(round(x + lean * k))
		var yy := base_y - k
		_px(img, xx, yy, c)
		if k > 3 and k % 3 == 0:
			var dir := 1 if (k / 3) % 2 == 0 else -1
			var spread := int(round((1.0 - float(k) / float(length)) * 5.0)) + 1
			for j in range(1, spread + 1):
				_px(img, xx + dir * j, yy - j / 2, c)


func _leaf(img: Image, x: int, y: int, angle: float, length: int, half_w: int, c: Color) -> void:
	var dx := cos(angle)
	var dy := sin(angle)
	for k in range(length):
		var t := float(k) / float(length)
		var wgt := int(round(sin(t * PI) * float(half_w)))
		var cx := int(round(x + dx * k))
		var cy := int(round(y + dy * k))
		for j in range(-wgt, wgt + 1):
			_px(img, cx - int(round(dy * j)), cy + int(round(dx * j)), c)


func mist_band(seed: int, strength := 0.16) -> ImageTexture:
	var w := 320
	var h := 72
	var img := _image(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(26):
		var cx := rng.randi_range(0, w)
		var cy := rng.randi_range(10, h - 8)
		var rx := rng.randi_range(26, 70)
		var ry := rng.randi_range(3, 9)
		_ellipse(img, cx, cy, rx, ry, Color(P.FOG.r, P.FOG.g, P.FOG.b, rng.randf_range(0.05, strength)))
	# difuminado vertical
	for y in range(h):
		var a := 1.0 - absf(float(y) / float(h) - 0.5) * 2.0
		for x in range(w):
			var c := img.get_pixel(x, y)
			var edge_fade := smoothstep(0.0, 44.0, float(mini(x, w - 1 - x)))
			if c.a > 0.0:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * (0.35 + a * 0.65) * edge_fade))
	return _smooth_tex(img)


func sun_glow() -> ImageTexture:
	var s := 96
	var img := _image(s, s)
	var center := Vector2(s, s) * 0.5
	for y in range(s):
		for x in range(s):
			var d := Vector2(x, y).distance_to(center) / (s * 0.5)
			if d > 1.0:
				continue
			# dos halos sumados: uno ancho y tenue, otro mas ceñido al disco
			var a := pow(1.0 - d, 3.0) * 0.75 + pow(1.0 - d, 1.35) * 0.25
			img.set_pixel(x, y, Color(P.SUN.r, P.SUN.g, P.SUN.b, a * 0.82))
	return ImageTexture.create_from_image(img)


func sun_disk() -> ImageTexture:
	var s := 64
	var img := _image(s, s)
	var c := Vector2(s, s) * 0.5
	for y in range(s):
		for x in range(s):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (s * 0.5)
			if d > 1.0:
				continue
			# cola muy larga: el disco se derrite en la neblina del horizonte
			var a := smoothstep(1.0, 0.10, d)
			if a <= 0.004:
				continue
			var col := P.SUN_CORE.lerp(P.SUN, smoothstep(0.0, 0.62, d))
			# el borde toma el color de la niebla para no recortarse contra el cielo
			col = col.lerp(P.FOG, smoothstep(0.58, 1.0, d) * 0.72)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)


func pit_texture() -> ImageTexture:
	var w := 8
	var h := 200
	var img := _image(w, h)
	var top := Color("211a14")
	var mid := Color("16110d")
	var bottom := Color("090706")
	for y in range(h):
		var t := float(y) / float(h)
		var c := top.lerp(mid, clampf(t * 2.2, 0.0, 1.0))
		c = c.lerp(bottom, clampf((t - 0.35) / 0.65, 0.0, 1.0))
		_fill(img, 0, y, w, 1, c)
	# boca del barranco: se pierde en la niebla
	for x in range(w):
		for y in range(22):
			var c := img.get_pixel(x, y)
			var a := 0.72 * pow(1.0 - float(y) / 22.0, 1.4)
			img.set_pixel(x, y, c.lerp(P.FOG, a))
	return ImageTexture.create_from_image(img)


# =====================================================================
#  Decoracion
# =====================================================================
func grass_tuft(seed: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 313 + 7
	var img := Image.create(16, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var blades := rng.randi_range(4, 6)
	for i in range(blades):
		var x := rng.randi_range(2, 13)
		var hh := rng.randi_range(4, 9)
		var lean := rng.randf_range(-0.55, 0.55)
		var col := P.GRASS_L if i % 3 != 0 else P.GRASS_LL
		for k in range(hh):
			_px(img, int(round(x + lean * k)), 11 - k, col)
		_px(img, int(round(x + lean * hh)), 11 - hh, P.GRASS)
	return ImageTexture.create_from_image(img)


func fern(seed: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 431 + 3
	var img := Image.create(26, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var base_x := rng.randi_range(9, 16)
	var lean := rng.randf_range(-0.35, 0.35)
	for k in range(14):
		var x := int(round(base_x + lean * k))
		_px(img, x, 19 - k, P.GRASS_D)
		if k % 3 == 0 and k > 2:
			var dir := 1 if (k / 3) % 2 == 0 else -1
			for j in range(1, 5):
				_px(img, x + dir * j, 19 - k - j / 2, P.GRASS if j < 4 else P.MOSS)
	for k in range(3):
		_px(img, base_x + 3 + k, 18 - k, P.MOSS_L)
	return ImageTexture.create_from_image(img)


func bush(seed: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 733 + 19
	var img := Image.create(44, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var base := P.FOREST_NEAR.lightened(0.02)
	# masa central
	for i in range(4):
		_ellipse(img, 22 + rng.randi_range(-6, 6), 31 - rng.randi_range(0, 5),
			rng.randi_range(8, 12), rng.randi_range(5, 8), base)
	# lóbulos de hojas en la parte alta
	for i in range(9):
		var cx := 22 + rng.randi_range(-11, 11)
		var cy := 24 - rng.randi_range(0, 12)
		var rr := rng.randi_range(3, 6)
		_ellipse(img, cx, cy, rr, maxi(2, rr - 1), base)
		if rng.randf() < 0.45:
			_ellipse(img, cx + rng.randi_range(-2, 2), cy - 1, maxi(1, rr - 2),
				maxi(1, rr - 3), P.FOREST_MID.darkened(0.06))
	# hojas sueltas que rompen el contorno
	for i in range(8):
		var lx := 22 + rng.randi_range(-14, 14)
		var ly := 22 - rng.randi_range(0, 12)
		_leaf(img, lx, ly, rng.randf_range(-2.7, -0.4), rng.randi_range(4, 8), 1, base)
	# tallos que asoman
	for i in range(4):
		var x := 22 + rng.randi_range(-12, 12)
		var hh := rng.randi_range(5, 11)
		for k in range(hh):
			_px(img, x + k / 5, 32 - k, P.FOREST_NEAR)
	# racimos encendidos por el sol (arriba a la derecha)
	for i in range(5):
		_ellipse(img, 24 + rng.randi_range(0, 10), 24 - rng.randi_range(3, 12),
			rng.randi_range(2, 5), rng.randi_range(1, 3),
			P.FOREST_MID.lerp(P.RIM, 0.16))
	# rim calido en el filo superior derecho
	for x in range(44):
		for y in range(40):
			if img.get_pixel(x, y).a > 0.0 and img.get_pixel(x, y - 1).a == 0.0:
				if (x + seed) % 9 < 4:
					img.set_pixel(x, y, P.RIM.lerp(P.FOREST_MID, 0.35))
				break
	return ImageTexture.create_from_image(img)


func flower(seed: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 191 + 11
	var img := Image.create(11, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var x := 5
	var stem_h := rng.randi_range(6, 9)
	for k in range(stem_h):
		_px(img, x, 13 - k, P.GRASS_D)
	_px(img, x - 2, 11, P.GRASS)
	_px(img, x + 2, 12, P.GRASS)
	var petal: Color = [P.CREAM, P.GOLD, P.FLOWER_RUST][rng.randi_range(0, 2)]
	var cy := 13 - stem_h
	_px(img, x, cy - 1, petal)
	_px(img, x - 1, cy, petal)
	_px(img, x + 1, cy, petal)
	_px(img, x, cy + 1, petal)
	_px(img, x, cy, P.CREAM_D if petal == P.CREAM else P.INK_SOFT)
	return ImageTexture.create_from_image(img)


func small_mushroom(seed: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 571 + 17
	var img := Image.create(13, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var x := 6
	_fill(img, x - 1, 8, 2, 5, P.STEM)
	_fill(img, x - 2, 8, 4, 1, P.STEM_D)
	_ellipse(img, x, 6, 5, 3, P.CAP)
	_ellipse(img, x, 5, 4, 2, P.CAP_L)
	_fill(img, x - 5, 8, 10, 1, P.CAP_D)
	_px(img, x - 2, 5, P.SPOT)
	_px(img, x + 2, 6, P.SPOT)
	_px(img, x, 4, P.SPOT)
	return ImageTexture.create_from_image(img)


func rock(seed: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 733 + 29
	var img := Image.create(20, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_ellipse(img, 10, 7, 8, 4, P.STONE_D)
	_ellipse(img, 10, 6, 7, 3, P.STONE)
	_ellipse(img, 8, 5, 4, 2, P.STONE_L)
	_ellipse(img, 6, 4, 3, 1, P.MOSS)
	_ellipse(img, 5, 4, 2, 1, P.MOSS_L)
	return ImageTexture.create_from_image(img)


func log(seed: int) -> ImageTexture:
	var img := Image.create(46, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_ellipse(img, 23, 9, 21, 6, P.LEATH_D)
	_ellipse(img, 23, 8, 20, 5, P.LEATH)
	_fill(img, 6, 4, 32, 2, P.LEATH_L)
	_ellipse(img, 5, 8, 3, 5, P.LEATH_D)
	_ellipse(img, 5, 8, 2, 4, P.LEATH_L)
	_ellipse(img, 5, 8, 1, 2, P.LEATH_D)
	# musgo
	_ellipse(img, 18, 4, 7, 1, P.MOSS)
	_ellipse(img, 30, 4, 5, 1, P.MOSS_L)
	return ImageTexture.create_from_image(img)


func sign() -> ImageTexture:
	var img := Image.create(30, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill(img, 13, 12, 4, 20, P.LEATH_D)
	_fill(img, 14, 12, 2, 19, P.LEATH)
	_fill(img, 2, 3, 26, 13, P.LEATH_D)
	_fill(img, 3, 4, 24, 11, P.LEATH)
	_fill(img, 4, 5, 22, 2, P.LEATH_L)
	# flecha
	for i in range(7):
		_px(img, 8 + i, 9, P.CREAM)
		_px(img, 8 + i, 10, P.CREAM)
	for i in range(4):
		_px(img, 14 + i, 9 - i, P.CREAM)
		_px(img, 14 + i, 10 + i, P.CREAM)
	return ImageTexture.create_from_image(img)


# =====================================================================
#  Particulas
# =====================================================================
func glow_texture() -> ImageTexture:
	var s := 11
	var img := _image(s, s)
	var c := Vector2(s, s) * 0.5
	for y in range(s):
		for x in range(s):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (s * 0.5)
			if d > 1.0:
				continue
			var a := pow(1.0 - d, 2.0)
			img.set_pixel(x, y, Color(P.FIREFLY.r, P.FIREFLY.g, P.FIREFLY.b, a))
	return ImageTexture.create_from_image(img)


func soft_shadow() -> ImageTexture:
	var w := 26
	var h := 8
	var img := _image(w, h)
	for y in range(h):
		for x in range(w):
			var nx := (float(x) + 0.5) / (float(w) * 0.5) - 1.0
			var ny := (float(y) + 0.5) / (float(h) * 0.5) - 1.0
			var d := nx * nx + ny * ny
			if d >= 1.0:
				continue
			var a := pow(1.0 - d, 1.5) * 0.72
			img.set_pixel(x, y, Color(P.INK.r, P.INK.g, P.INK.b, a))
	return ImageTexture.create_from_image(img)


func ledge_beard(seed: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 281 + 43
	var w := rng.randi_range(18, 30)
	var lump_h := 11
	var h := 22
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w / 2
	for y in range(lump_h):
		var t := float(y) / float(lump_h)
		var half := int(round(float(w) * 0.46 * (1.0 - t * 0.52)))
		for x in range(cx - half, cx + half):
			var c := P.DIRT_D.lerp(P.INK_SOFT, clampf(t * 1.15, 0.0, 1.0))
			if (x + y * 3) % 7 == 0:
				c = c.darkened(0.16)
			img.set_pixel(x, y, c)
		if y == 0:
			_fill(img, cx - half, 0, half * 2, 1, P.DIRT)
	# borde inferior irregular
	for x in range(cx - w / 4, cx + w / 4):
		if (x * 7 + seed) % 5 == 0:
			_px(img, x, lump_h - 1, Color(0, 0, 0, 0))
	# raicillas que cuelgan
	for i in range(rng.randi_range(2, 3)):
		var rx := rng.randi_range(cx - 4, cx + 4)
		var rl := rng.randi_range(4, 9)
		for k in range(rl):
			_px(img, rx + int(round(sin(k * 0.6) * 1.2)), lump_h - 1 + k, P.ROOT)
	return ImageTexture.create_from_image(img)


func puff_texture() -> ImageTexture:
	var s := 8
	var img := _image(s, s)
	var c := Vector2(s, s) * 0.5
	for y in range(s):
		for x in range(s):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (s * 0.5)
			if d > 1.0:
				continue
			var a := pow(1.0 - d, 1.6) * 0.8
			img.set_pixel(x, y, Color(0.93, 0.88, 0.75, a))
	return ImageTexture.create_from_image(img)


func leaf_particle() -> ImageTexture:
	var img := Image.create(6, 5, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := P.FLOWER_RUST
	for x in range(2, 4):
		_px(img, x, 0, c)
	for x in range(1, 5):
		_px(img, x, 1, c)
	for x in range(0, 6):
		_px(img, x, 2, c)
	for x in range(1, 5):
		_px(img, x, 3, c)
	for x in range(2, 4):
		_px(img, x, 4, c)
	_px(img, 2, 1, P.GOLD)
	_px(img, 3, 2, P.GOLD)
	_px(img, 2, 3, P.GOLD)
	return ImageTexture.create_from_image(img)


## Textura para capas que se dibujan con filtro lineal: rellena el color de los
## pixeles transparentes con el de sus vecinos para que no aparezca un halo
## oscuro en los bordes al interpolar.
func _smooth_tex(img: Image) -> ImageTexture:
	img.fix_alpha_edges()
	return ImageTexture.create_from_image(img)


# =====================================================================
#  Utilidades de dibujo
# =====================================================================
func _image(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _over(dst: Color, src: Color) -> Color:
	if src.a <= 0.0:
		return dst
	var a := src.a + dst.a * (1.0 - src.a)
	if a <= 0.0001:
		return Color(0.0, 0.0, 0.0, 0.0)
	return Color(
		(src.r * src.a + dst.r * dst.a * (1.0 - src.a)) / a,
		(src.g * src.a + dst.g * dst.a * (1.0 - src.a)) / a,
		(src.b * src.a + dst.b * dst.a * (1.0 - src.a)) / a,
		a)


func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var x0 := maxi(x, 0)
	var y0 := maxi(y, 0)
	var x1 := mini(x + w, img.get_width())
	var y1 := mini(y + h, img.get_height())
	if x1 <= x0 or y1 <= y0:
		return
	for yy in range(y0, y1):
		for xx in range(x0, x1):
			img.set_pixel(xx, yy, c)


func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var nx := float(x - cx) / float(rx)
			var ny := float(y - cy) / float(ry)
			if nx * nx + ny * ny <= 1.0:
				_px(img, x, y, c)


## Variantes que dan la vuelta por los bordes, para texturas que se repiten.
func _ellipse_w(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	var w := img.get_width()
	for off in [-w, 0, w]:
		_ellipse(img, cx + off, cy, rx, ry, c)


func _ellipse_masked_w(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	var w := img.get_width()
	for off in [-w, 0, w]:
		_ellipse_masked(img, cx + off, cy, rx, ry, c)


func _pine_w(img: Image, x: int, base: int, height: int, c: Color, trunk_c: Color,
		trunk_w := 2, detailed := true) -> void:
	var w := img.get_width()
	for off in [-w, 0, w]:
		_pine(img, x + off, base, height, c, trunk_c, trunk_w, detailed)


func _ellipse_masked(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			if img.get_pixel(x, y).a == 0.0:
				continue
			var nx := float(x - cx) / float(rx)
			var ny := float(y - cy) / float(ry)
			if nx * nx + ny * ny <= 1.0:
				img.set_pixel(x, y, c)


func _poly(img: Image, points: PackedVector2Array, c: Color) -> void:
	if points.size() < 3:
		return
	var min_y := 1e9
	var max_y := -1e9
	for p in points:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	for y in range(int(floor(min_y)), int(ceil(max_y)) + 1):
		var xs: Array[float] = []
		var sy := float(y) + 0.5
		for i in range(points.size()):
			var a := points[i]
			var b := points[(i + 1) % points.size()]
			if (a.y <= sy and b.y > sy) or (b.y <= sy and a.y > sy):
				var t := (sy - a.y) / (b.y - a.y)
				xs.append(a.x + t * (b.x - a.x))
		xs.sort()
		for i in range(0, xs.size() - 1, 2):
			for x in range(int(ceil(xs[i])), int(floor(xs[i + 1])) + 1):
				_px(img, x, y, c)


func _pine(img: Image, x: int, base: int, height: int, c: Color, trunk_c: Color,
		trunk_w := 2, detailed := true) -> void:
	_fill(img, x - trunk_w / 2, base - int(height * 0.22), trunk_w, int(height * 0.22), trunk_c)
	var dark := c.darkened(0.16)
	for l in range(3):
		var bottom := base - int(height * 0.10 * l)
		var top_y := bottom - int(height * 0.62)
		var half := int(height * (0.10 + 0.045 * l))
		var pts := PackedVector2Array([
			Vector2(x, top_y), Vector2(x - half, bottom), Vector2(x + half, bottom)
		])
		_poly(img, pts, c)
		if not detailed:
			continue
		# volumen: borde iluminado a la izquierda, sombra a la derecha
		var span := maxi(1, bottom - top_y)
		for k in range(span):
			var half_k := int(half * float(k) / float(span))
			_px(img, x - half_k, top_y + k, Color(c.r * 1.16, c.g * 1.16, c.b * 1.12, c.a))
			_px(img, x + half_k, top_y + k, Color(dark.r, dark.g, dark.b, c.a))
		# muescas de las ramas
		if l > 0:
			for m in range(2):
				var yy := bottom - 2 - m * 4
				_px(img, x - int(half * 0.55), yy, dark)
				_px(img, x + int(half * 0.55), yy, dark)
