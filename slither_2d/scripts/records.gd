class_name Records
extends RefCounted
## Récord, estadísticas, mejores partidas y apodo: lo que **se recuerda** entre partidas.
##
## NODO AL QUE SE ADJUNTA: a ninguno. Es una clase de utilidades estáticas
## (`Records.cargar()`), no un script de nodo.
##
## ¿DÓNDE SE GUARDA? En `user://records.cfg`, un archivo de texto con `ConfigFile`
## que vive en **tu perfil de Godot** (no en el repositorio, así que tus récords no
## se suben a GitHub ni molestan a nadie). Lo puedes abrir y editar a mano.
## En Linux suele estar en:
##
##     ~/.local/share/godot/app_userdata/<nombre del proyecto>/records.cfg
##
## `main.gd` es quien lo usa: carga los datos al empezar, los actualiza al morir y
## los guarda (con `guardar()`). Las pruebas automáticas cambian `ruta` por un
## archivo temporal para no tocar el récord de verdad.

const MAX_MEJORES := 5  ## Cuántas mejores partidas se guardan (idea 8E).
const LARGO_APODO := 16  ## Longitud máxima del apodo.
const SECCION := "records"
const SECCION_PIEL := "piel"
const SECCION_JUGADOR := "jugador"
const SECCION_MEJORES := "mejores"

## Ruta del archivo. Las pruebas la cambian por una temporal (y la restauran).
static var ruta := "user://records.cfg"


## Datos de un jugador nuevo (todo a cero y con la piel clásica).
static func por_defecto() -> Dictionary:
	return {
		"record_puntos": 0,
		"record_longitud": 0,
		"partidas": 0,
		"comida": 0,
		"bots": 0,
		"tiempo": 0.0,
		"paleta": 0,
		"patron": 0,
		"nombre": "",
		"mejores": [],
	}


## Lee los datos guardados (o los de por defecto si es la primera vez).
static func cargar() -> Dictionary:
	var datos := por_defecto()
	var ajustes := ConfigFile.new()
	if ajustes.load(ruta) != OK:
		return datos  # Primera vez: récord a cero.

	datos["record_puntos"] = int(ajustes.get_value(SECCION, "record_puntos", 0))
	datos["record_longitud"] = int(ajustes.get_value(SECCION, "record_longitud", 0))
	datos["partidas"] = int(ajustes.get_value(SECCION, "partidas", 0))
	datos["comida"] = int(ajustes.get_value(SECCION, "comida", 0))
	datos["bots"] = int(ajustes.get_value(SECCION, "bots", 0))
	datos["tiempo"] = float(ajustes.get_value(SECCION, "tiempo", 0.0))
	datos["paleta"] = int(ajustes.get_value(SECCION_PIEL, "paleta", 0))
	datos["patron"] = int(ajustes.get_value(SECCION_PIEL, "patron", 0))
	datos["nombre"] = str(ajustes.get_value(SECCION_JUGADOR, "nombre", ""))
	# La lista de mejores partidas va como texto (var_to_str): así se guarda
	# cualquier estructura (fechas, nombres...) sin inventarse un formato.
	datos["mejores"] = str_to_var(str(ajustes.get_value(SECCION_MEJORES, "lista", "[]")))
	if not (datos["mejores"] is Array):
		datos["mejores"] = []
	return datos


## Escribe los datos en el archivo. Los valores que no son números o textos
## (la lista de mejores partidas) se guardan con `var_to_str()`.
static func guardar(datos: Dictionary) -> void:
	var ajustes := ConfigFile.new()
	ajustes.set_value(SECCION, "record_puntos", int(datos.get("record_puntos", 0)))
	ajustes.set_value(SECCION, "record_longitud", int(datos.get("record_longitud", 0)))
	ajustes.set_value(SECCION, "partidas", int(datos.get("partidas", 0)))
	ajustes.set_value(SECCION, "comida", int(datos.get("comida", 0)))
	ajustes.set_value(SECCION, "bots", int(datos.get("bots", 0)))
	ajustes.set_value(SECCION, "tiempo", float(datos.get("tiempo", 0.0)))
	ajustes.set_value(SECCION_PIEL, "paleta", int(datos.get("paleta", 0)))
	ajustes.set_value(SECCION_PIEL, "patron", int(datos.get("patron", 0)))
	ajustes.set_value(SECCION_JUGADOR, "nombre", str(datos.get("nombre", "")))
	ajustes.set_value(SECCION_MEJORES, "lista", var_to_str(datos.get("mejores", [])))
	ajustes.save(ruta)


## Borra el archivo (solo lo usan las pruebas automáticas).
static func borrar() -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))


## Mete una partida en la lista de mejores y devuelve la lista ya ordenada
## (mejores puntos primero) y recortada a `MAX_MEJORES`.
static func agregar_mejor(mejores: Array, partida: Dictionary) -> Array:
	var lista := mejores.duplicate()
	lista.append(partida)
	lista.sort_custom(_es_mejor)
	if lista.size() > MAX_MEJORES:
		lista.resize(MAX_MEJORES)
	return lista


static func _es_mejor(a: Dictionary, b: Dictionary) -> bool:
	var puntos_a := int(a.get("puntos", 0))
	var puntos_b := int(b.get("puntos", 0))
	if puntos_a != puntos_b:
		return puntos_a > puntos_b
	return int(a.get("longitud", 0)) > int(b.get("longitud", 0))


## Tabla de mejores partidas lista para enseñar en la pantalla final.
## Con `con_titulo = false` se devuelve sin la cabecera (cuando el título ya lo
## pone un panel, como en la pantalla de muerte).
static func texto_mejores(mejores: Array, con_titulo := true) -> String:
	var cabecera := "TUS MEJORES PARTIDAS" if con_titulo else "MEJORES PARTIDAS"
	if mejores.is_empty():
		return "%s\n(todavía no hay ninguna)" % cabecera
	var lineas := PackedStringArray([cabecera])
	for i in mejores.size():
		var partida: Dictionary = mejores[i]
		lineas.append("%d.  %s  —  %d puntos · %d de largo · %s" % [
			i + 1,
			str(partida.get("nombre", "TÚ")),
			int(partida.get("puntos", 0)),
			int(partida.get("longitud", 0)),
			str(partida.get("fecha", "")),
		])
	return "\n".join(lineas)


## Apodo por defecto: el usuario del sistema (o "JUGADOR").
static func nombre_sistema() -> String:
	for variable in ["USER", "USERNAME", "LOGNAME"]:
		var valor := OS.get_environment(variable).strip_edges()
		if valor != "":
			return valor.substr(0, LARGO_APODO)
	return "JUGADOR"


## Fecha corta de hoy ("30/09/2026"), para la tabla de mejores partidas.
static func fecha_de_hoy() -> String:
	var fecha := Time.get_datetime_dict_from_system()
	return "%02d/%02d/%04d" % [int(fecha["day"]), int(fecha["month"]), int(fecha["year"])]


## Segundos en formato corto ("1 min 23 s"), para las estadísticas.
static func texto_tiempo(segundos: float) -> String:
	var total := int(segundos)
	if total < 60:
		return "%d s" % total
	return "%d min %d s" % [total / 60, total % 60]
