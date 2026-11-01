extends SceneTree
## Valida los saberes de data/saberes/ y su enlace con el nivel.
##   godot --headless --path . --script res://tools/validate_saberes.gd
##
## Comprueba: ids unicos y estables, todos los idiomas, un solo parrafo,
## tema de la zona, dato por idioma, tipo, pregunta con una unica respuesta
## correcta, al menos una fuente con URL y fecha, y que cada "desbloquea",
## "requires" y "pregunta_de" apunte a algo existente.

const LEVEL_BOSQUE = preload("res://scripts/level_data.gd")
const LEVEL_RUINAS = preload("res://scripts/level_ruinas.gd")
const DIR := "res://data/saberes"
const IDIOMAS := ["es", "en"]
const TIPOS := ["numero", "palabra", "simbolo"]
const LARGO_MIN := 300
const LARGO_MAX := 600
const LARGO_MINIMO := 100

var _errores: Array[String] = []
var _avisos: Array[String] = []
var _ids: Dictionary = {}
var _puertas: Dictionary = {}
var _niveles: Dictionary = {}
var _archivos := 0
var _re_id := RegEx.new()
var _re_fecha := RegEx.new()


func _initialize() -> void:
	_re_id.compile("^[a-z][a-z0-9_]*$")
	_re_fecha.compile("^\\d{4}-\\d{2}-\\d{2}$")

	# Indexar los niveles por su zona para validar saberes contra el nivel correcto.
	_niveles[LEVEL_BOSQUE.ZONE_ID] = LEVEL_BOSQUE
	_niveles[LEVEL_RUINAS.ZONE_ID] = LEVEL_RUINAS

	# Recopilar puertas de todos los niveles.
	for nivel in _niveles.values():
		for door in nivel.DOORS:
			var id := str(door.get("id", ""))
			if id.is_empty():
				_error("%s: una puerta no tiene id" % str(nivel))
				continue
			if _puertas.has(id):
				_error("%s: puerta repetida '%s'" % [str(nivel), id])
			_puertas[id] = true

	var dir := DirAccess.open(DIR)
	if dir == null:
		_error("no se pudo abrir %s" % DIR)
		_cerrar()
		return

	var archivos := dir.get_files()
	archivos.sort()
	for archivo in archivos:
		if archivo.ends_with(".json"):
			_validar_archivo(archivo)

	for nivel in _niveles.values():
		for saber in nivel.SABERES:
			var id := str(saber.get("id", ""))
			var nombre_nivel := str(nivel)
			if not _ids.has(id):
				_error("%s: el saber '%s' no existe en %s" % [nombre_nivel, id, DIR])

	for nivel in _niveles.values():
		for door in nivel.DOORS:
			var door_id := str(door.get("id", ""))
			var nombre_nivel := str(nivel)
			var requiere = door.get("requires", [])
			if typeof(requiere) != TYPE_ARRAY:
				_error("%s: la puerta '%s' debe tener 'requires' como lista" % [nombre_nivel, door_id])
				continue
			if requiere.is_empty():
				_error("%s: la puerta '%s' no pide ningun saber" % [nombre_nivel, door_id])
			var vistos: Dictionary = {}
			for id in requiere:
				var saber := str(id)
				if not _ids.has(saber):
					_error("%s: la puerta '%s' pide un saber inexistente: '%s'" % [
						nombre_nivel, door_id, saber])
				if vistos.has(saber):
					_error("%s: la puerta '%s' repite el saber '%s'" % [nombre_nivel, door_id, saber])
				vistos[saber] = true

			var pregunta_de := str(door.get("pregunta_de", ""))
			if pregunta_de.is_empty():
				_error("%s: la puerta '%s' no declara de que saber pregunta" % [nombre_nivel, door_id])
			elif not vistos.has(pregunta_de):
				_error("%s: la puerta '%s' pregunta por '%s', que no esta entre sus saberes" % [
					nombre_nivel, door_id, pregunta_de])

	_cerrar()


func _validar_archivo(archivo: String) -> void:
	_archivos += 1
	var ruta := DIR.path_join(archivo)
	var base := archivo.get_basename()

	var datos = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	if typeof(datos) != TYPE_DICTIONARY:
		_error("%s: JSON invalido" % archivo)
		return

	var id := str(datos.get("id", ""))
	if id.is_empty():
		_error("%s: falta el id" % archivo)
	elif id != base:
		_error("%s: el id '%s' no coincide con el nombre del archivo" % [archivo, id])
	elif _re_id.search(id) == null:
		_error("%s: el id debe ser minusculas, numeros y guiones bajos" % archivo)
	if _ids.has(id):
		_error("%s: id repetido '%s'" % [archivo, id])
	else:
		_ids[id] = true

	var zona := str(datos.get("zona", ""))
	var nivel_esperado: RefCounted = _niveles.get(zona, null)
	if nivel_esperado == null:
		_error("%s: zona '%s' no tiene un nivel definido en los archivos de level_data" % [
			archivo, zona])

	var tema := str(datos.get("tema", ""))
	if tema.is_empty():
		_error("%s: falta el tema" % archivo)
	elif nivel_esperado != null and tema != str(nivel_esperado.TEMA):
		_error("%s: tema '%s' distinto del de la zona ('%s')" % [
			archivo, tema, str(nivel_esperado.TEMA)])

	for idioma in IDIOMAS:
		var titulo := _idioma_campo(datos, "titulo", idioma)
		if titulo.is_empty():
			_error("%s: falta el titulo en '%s'" % [archivo, idioma])
		var texto := _idioma_campo(datos, "texto", idioma)
		if texto.is_empty():
			_error("%s: falta el texto en '%s'" % [archivo, idioma])
			continue
		if texto.contains("\n"):
			_error("%s: el texto en '%s' debe ser un solo parrafo" % [archivo, idioma])
		if texto.length() < LARGO_MINIMO:
			_error("%s: el texto en '%s' es demasiado corto (%d)" % [
				archivo, idioma, texto.length()])
		elif texto.length() < LARGO_MIN or texto.length() > LARGO_MAX:
			_aviso("%s: el texto en '%s' mide %d caracteres (ideal %d-%d)" % [
				archivo, idioma, texto.length(), LARGO_MIN, LARGO_MAX])

	var dato = datos.get("dato", {})
	var valores: Dictionary = {}
	if typeof(dato) != TYPE_DICTIONARY:
		_error("%s: falta el bloque 'dato'" % archivo)
	else:
		if not str(dato.get("tipo", "")) in TIPOS:
			_error("%s: tipo de dato invalido (use %s)" % [archivo, ", ".join(TIPOS)])
		var valor = dato.get("valor", {})
		if typeof(valor) != TYPE_DICTIONARY:
			_error("%s: 'dato.valor' debe tener un valor por idioma" % archivo)
		else:
			valores = valor
			for idioma in IDIOMAS:
				if str(valores.get(idioma, "")).strip_edges().is_empty():
					_error("%s: falta el dato en '%s'" % [archivo, idioma])

	_validar_pregunta(archivo, datos, valores)

	var desbloquea = datos.get("desbloquea", [])
	if typeof(desbloquea) != TYPE_ARRAY:
		_error("%s: 'desbloquea' debe ser una lista" % archivo)
	else:
		for puerta in desbloquea:
			if not _puertas.has(str(puerta)):
				_error("%s: desbloquea una puerta inexistente: '%s'" % [archivo, str(puerta)])

	var fuentes = datos.get("fuentes", [])
	if typeof(fuentes) != TYPE_ARRAY or fuentes.is_empty():
		_error("%s: falta al menos una fuente" % archivo)
		return
	for fuente in fuentes:
		if typeof(fuente) != TYPE_DICTIONARY:
			_error("%s: fuente con formato invalido" % archivo)
			continue
		var titulo := str(fuente.get("titulo", ""))
		var url := str(fuente.get("url", ""))
		var idioma := str(fuente.get("idioma", ""))
		var consultado := str(fuente.get("consultado", ""))
		if titulo.is_empty():
			_error("%s: una fuente no tiene titulo" % archivo)
		if not (url.begins_with("https://") or url.begins_with("http://")):
			_error("%s: la fuente '%s' no tiene una URL valida" % [archivo, titulo])
		if not idioma in IDIOMAS:
			_error("%s: la fuente '%s' tiene idioma invalido ('%s')" % [archivo, titulo, idioma])
		if _re_fecha.search(consultado) == null:
			_error("%s: la fuente '%s' no tiene fecha de consulta AAAA-MM-DD" % [archivo, titulo])


func _idioma_campo(datos: Dictionary, campo: String, idioma: String) -> String:
	var tabla = datos.get(campo, {})
	if typeof(tabla) != TYPE_DICTIONARY:
		return ""
	return str(tabla.get(idioma, "")).strip_edges()


## Cada saber trae una pregunta por idioma. La respuesta correcta es su dato:
## debe aparecer exactamente una vez entre las opciones.
func _validar_pregunta(archivo: String, datos: Dictionary, valores: Dictionary) -> void:
	var preguntas = datos.get("pregunta", {})
	if typeof(preguntas) != TYPE_DICTIONARY:
		_error("%s: falta el bloque 'pregunta'" % archivo)
		return
	for idioma in IDIOMAS:
		var p = preguntas.get(idioma, {})
		if typeof(p) != TYPE_DICTIONARY:
			_error("%s: falta la pregunta en '%s'" % [archivo, idioma])
			continue
		if str(p.get("enunciado", "")).strip_edges().is_empty():
			_error("%s: la pregunta en '%s' no tiene enunciado" % [archivo, idioma])
		var opciones = p.get("opciones", [])
		if typeof(opciones) != TYPE_ARRAY:
			_error("%s: las opciones en '%s' deben ser una lista" % [archivo, idioma])
			continue
		if opciones.size() < 2:
			_error("%s: la pregunta en '%s' necesita al menos dos opciones" % [archivo, idioma])
		var vistas: Dictionary = {}
		var correctas := 0
		var buscado := _normalizar(str(valores.get(idioma, "")))
		for opcion in opciones:
			var texto := str(opcion).strip_edges()
			if texto.is_empty():
				_error("%s: hay una opcion vacia en '%s'" % [archivo, idioma])
				continue
			var clave := _normalizar(texto)
			if vistas.has(clave):
				_error("%s: opcion repetida '%s' en '%s'" % [archivo, texto, idioma])
			vistas[clave] = true
			if clave == buscado:
				correctas += 1
		if correctas != 1:
			_error("%s: en '%s' debe haber una sola opcion igual al dato (hay %d)" % [
				archivo, idioma, correctas])


## Compara sin distinguir mayusculas ni espacios: "90 %" = "90%".
func _normalizar(texto: String) -> String:
	return texto.to_lower().replace(" ", "").strip_edges()


func _error(mensaje: String) -> void:
	_errores.append(mensaje)


func _aviso(mensaje: String) -> void:
	_avisos.append(mensaje)


func _cerrar() -> void:
	for aviso in _avisos:
		print("AVISO: " + aviso)
	for error in _errores:
		print("ERROR: " + error)
	if _errores.is_empty():
		print("Saberes OK: %d archivos, %d puertas." % [_archivos, _puertas.size()])
		quit(0)
	else:
		print("%d error(es) en data/saberes." % _errores.size())
		quit(1)
