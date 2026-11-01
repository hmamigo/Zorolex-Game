extends Node
## Autoload "Saberes": carga data/saberes, resuelve el idioma activo y guarda
## el progreso (saberes recogidos y puertas abiertas) en user://savegame.json.

const DIR_SABERES := "res://data/saberes"
const RUTA_GUARDADO := "user://savegame.json"
const IDIOMAS := ["es", "en"]
const IDIOMA_FALLBACK := "en"
const VERSION_GUARDADO := 1

signal saber_recogido(id: String)
signal puerta_abierta(id: String)
signal idioma_cambiado(codigo: String)

var _saberes: Dictionary = {}
var _recogidos: Dictionary = {}
var _puertas: Dictionary = {}
var _idioma := IDIOMA_FALLBACK
var _idioma_definido := false


func _ready() -> void:
	cargar_saberes()
	_cargar_progreso()
	if not _idioma_definido:
		_idioma = _idioma_del_sistema()
	TranslationServer.set_locale(_idioma)


# =====================================================================
#  Carga de datos
# =====================================================================
func cargar_saberes() -> void:
	_saberes.clear()
	var dir := DirAccess.open(DIR_SABERES)
	if dir == null:
		push_error("Saberes: no se pudo abrir %s" % DIR_SABERES)
		return
	var archivos := dir.get_files()
	archivos.sort()
	for archivo in archivos:
		if not archivo.ends_with(".json"):
			continue
		var ruta := DIR_SABERES.path_join(archivo)
		var datos = JSON.parse_string(FileAccess.get_file_as_string(ruta))
		if typeof(datos) != TYPE_DICTIONARY:
			push_error("Saberes: JSON invalido en %s" % ruta)
			continue
		var id: String = str(datos.get("id", ""))
		if id.is_empty():
			push_error("Saberes: falta el id en %s" % ruta)
			continue
		if _saberes.has(id):
			push_error("Saberes: id repetido %s" % id)
			continue
		_saberes[id] = datos


func _cargar_progreso() -> void:
	if not FileAccess.file_exists(RUTA_GUARDADO):
		return
	var datos = JSON.parse_string(FileAccess.get_file_as_string(RUTA_GUARDADO))
	if typeof(datos) != TYPE_DICTIONARY:
		push_warning("Saberes: guardado ilegible, se empieza de cero")
		return
	for id in datos.get("saberes", []):
		if id is String:
			_recogidos[id] = true
	for id in datos.get("puertas", []):
		if id is String:
			_puertas[id] = true
	var idioma := str(datos.get("idioma", ""))
	if idioma in IDIOMAS:
		_idioma = idioma
		_idioma_definido = true


func guardar() -> void:
	var saberes: Array = _recogidos.keys()
	saberes.sort()
	var puertas: Array = _puertas.keys()
	puertas.sort()
	var datos := {
		"version": VERSION_GUARDADO,
		"saberes": saberes,
		"puertas": puertas,
		"idioma": _idioma,
	}
	var archivo := FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if archivo == null:
		push_error("Saberes: no se pudo escribir %s" % RUTA_GUARDADO)
		return
	archivo.store_string(JSON.stringify(datos, "\t"))


# =====================================================================
#  Consulta
# =====================================================================
func todos() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for id in _saberes:
		lista.append(_saberes[id])
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _titulo_de(a).naturalnocasecmp_to(_titulo_de(b)) < 0)
	return lista


func obtener(id: String) -> Dictionary:
	var saber = _saberes.get(id, {})
	return saber if typeof(saber) == TYPE_DICTIONARY else {}


func titulo(id: String) -> String:
	return _campo(id, "titulo")


func texto(id: String) -> String:
	return _campo(id, "texto")


func dato(id: String) -> Dictionary:
	var d = obtener(id).get("dato", {})
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	var valores = d.get("valor", {})
	var valor := ""
	if typeof(valores) == TYPE_DICTIONARY:
		valor = str(valores.get(_idioma, valores.get(IDIOMA_FALLBACK, "")))
	else:
		valor = str(valores)
	return { "valor": valor, "tipo": str(d.get("tipo", "")) }


## Pregunta de la puerta asociada al saber, ya en el idioma activo.
## Devuelve { enunciado, opciones, correcta }, con -1 si el dato no aparece
## entre las opciones (el validador lo marca como error de datos).
func pregunta(id: String) -> Dictionary:
	var tabla = obtener(id).get("pregunta", {})
	if typeof(tabla) != TYPE_DICTIONARY:
		return {}
	var p = tabla.get(_idioma, tabla.get(IDIOMA_FALLBACK, {}))
	if typeof(p) != TYPE_DICTIONARY:
		return {}
	var opciones: Array[String] = []
	for opcion in p.get("opciones", []):
		opciones.append(str(opcion))
	return {
		"enunciado": str(p.get("enunciado", "")),
		"opciones": opciones,
		"correcta": _indice_correcto(opciones, str(dato(id).get("valor", ""))),
	}


func tema(id: String) -> String:
	return str(obtener(id).get("tema", ""))


## Etiqueta visible del tema. Sale de i18n; si falta, se arma con el id.
func etiqueta_tema(tema_id: String) -> String:
	if tema_id.is_empty():
		return ""
	var clave := "TEMA_" + tema_id.to_upper()
	var traducido := tr(clave)
	if traducido != clave:
		return traducido
	return tema_id.replace("_", " ").capitalize()


func _indice_correcto(opciones: Array[String], valor: String) -> int:
	var buscado := _normalizar(valor)
	if buscado.is_empty():
		return -1
	for i in opciones.size():
		if _normalizar(opciones[i]) == buscado:
			return i
	return -1


## Compara respuestas sin distinguir mayusculas ni espacios: "90 %" = "90%".
func _normalizar(texto: String) -> String:
	return texto.to_lower().replace(" ", "").strip_edges()


func fuentes(id: String) -> Array:
	var f = obtener(id).get("fuentes", [])
	return f if typeof(f) == TYPE_ARRAY else []


func zona(id: String) -> String:
	return str(obtener(id).get("zona", ""))


## Total de saberes. Si se pasa zona_id, cuenta solo los de esa zona.
func total(zona_id: String = "") -> int:
	if zona_id.is_empty():
		return _saberes.size()
	var count := 0
	for id in _saberes:
		if str(_saberes[id].get("zona", "")) == zona_id:
			count += 1
	return count


## Cantidad de saberes recogidos. Si se pasa zona_id, cuenta solo los de esa zona.
func cantidad_recogidos(zona_id: String = "") -> int:
	if zona_id.is_empty():
		return _recogidos.size()
	var count := 0
	for id in _recogidos.keys():
		if _saberes.has(id) and str(_saberes[id].get("zona", "")) == zona_id:
			count += 1
	return count


func tiene(id: String) -> bool:
	return _recogidos.has(id)


func recogidos() -> Array:
	var ids: Array = _recogidos.keys()
	ids.sort()
	return ids


func recoger(id: String) -> bool:
	if not _saberes.has(id) or _recogidos.has(id):
		return false
	_recogidos[id] = true
	guardar()
	saber_recogido.emit(id)
	return true


func esta_abierta(id: String) -> bool:
	return _puertas.has(id)


func abrir_puerta(id: String) -> bool:
	if _puertas.has(id):
		return false
	_puertas[id] = true
	guardar()
	puerta_abierta.emit(id)
	return true


# =====================================================================
#  Idioma
# =====================================================================
func idioma() -> String:
	return _idioma


func cambiar_idioma(codigo: String) -> void:
	if not codigo in IDIOMAS or codigo == _idioma:
		return
	_idioma = codigo
	_idioma_definido = true
	TranslationServer.set_locale(_idioma)
	guardar()
	idioma_cambiado.emit(_idioma)


func _idioma_del_sistema() -> String:
	var locale := TranslationServer.get_locale()
	return "es" if locale.begins_with("es") else IDIOMA_FALLBACK


func _campo(id: String, campo: String) -> String:
	var tabla = obtener(id).get(campo, {})
	if typeof(tabla) != TYPE_DICTIONARY:
		return ""
	return str(tabla.get(_idioma, tabla.get(IDIOMA_FALLBACK, "")))


func _titulo_de(saber: Dictionary) -> String:
	var tabla = saber.get("titulo", {})
	if typeof(tabla) != TYPE_DICTIONARY:
		return ""
	return str(tabla.get(_idioma, tabla.get(IDIOMA_FALLBACK, "")))
