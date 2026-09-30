class_name Ajustes
extends RefCounted
## Ajustes del jugador en `user://ajustes.cfg` (audio, pantalla y extras).
##
## NODO AL QUE SE ADJUNTA: a ninguno. Utilidades estáticas (`Ajustes.cargar()`).
##
## Es el archivo que ya usaba `sonido.gd` para recordar el silencio y la música;
## ahora pasa por aquí para que **todo** (sonido, pantalla completa, mostrar FPS)
## viva en un único sitio y ninguna parte borre las claves de las demás: cada
## `guardar()` carga lo que hay, cambia solo sus claves y vuelve a escribir.

const SECCION := "audio"
const SECCION_PANTALLA := "pantalla"

## Ruta del archivo de ajustes. Es `static var` (y no `const`) para que las
## pruebas puedan apuntar a un archivo temporal sin tocar el del jugador.
static var ruta := "user://ajustes.cfg"

## Todos los ajustes con sus valores por defecto. Las claves coinciden con las del
## archivo, así que añadir uno nuevo es añadirlo aquí (y usarlo donde toque).
static func por_defecto() -> Dictionary:
	return {
		"silencio": false,
		"musica": 2,  # 2 = normal, 1 = bajita, 0 = apagada
		"volumen_efectos": 0.0,  # dB
		"volumen_musica": -10.0,  # dB
		"pantalla_completa": false,
		"mostrar_fps": false,
	}


static func cargar() -> Dictionary:
	var valores := por_defecto()
	var ajustes := ConfigFile.new()
	if ajustes.load(ruta) != OK:
		return valores  # Primera vez: todo por defecto.
	for clave in valores.keys():
		if clave == "musica":
			valores[clave] = clampi(
				int(ajustes.get_value(SECCION, clave, valores[clave])), 0, 2
			)
		elif clave == "volumen_efectos" or clave == "volumen_musica":
			valores[clave] = float(ajustes.get_value(SECCION, clave, valores[clave]))
		elif clave == "pantalla_completa" or clave == "mostrar_fps":
			valores[clave] = bool(ajustes.get_value(SECCION_PANTALLA, clave, valores[clave]))
		else:
			valores[clave] = bool(ajustes.get_value(SECCION, clave, valores[clave]))
	return valores


## Cambia solo las claves que le pasan y deja el resto como estaban.
static func guardar(cambios: Dictionary) -> void:
	var valores := cargar()
	for clave in cambios.keys():
		valores[clave] = cambios[clave]
	var ajustes := ConfigFile.new()
	for clave in valores.keys():
		var seccion := SECCION_PANTALLA if clave in ["pantalla_completa", "mostrar_fps"] \
			else SECCION
		ajustes.set_value(seccion, clave, valores[clave])
	ajustes.save(ruta)


## Aplica los ajustes de pantalla (pantalla completa sí/no). Se llama al arrancar
## el juego y cada vez que se cambian en Opciones.
static func aplicar_pantalla(valores: Dictionary) -> void:
	# En el móvil la ventana ya ocupa toda la pantalla siempre: no hay nada que
	# aplicar (y cambiar el modo de ventana en Android no aporta nada bueno).
	if OS.has_feature("mobile"):
		return
	# Sin ternarios ni `:=` con enums: dos ramas claras, imposible de confundir al
	# analizador de tipos (y el error de inferencia no puede aparecer aquí).
	if bool(valores.get("pantalla_completa", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
