extends Node2D
## Cuadrícula "infinita": da sensación de espacio sin límites.
##
## NODO AL QUE SE ADJUNTA: un **Node2D** hijo de Main (escena `escenas/Main.tscn`,
## nodo "Fondo"). Se dibuja por código y sigue a la cámara, así que el mundo
## parece no terminar nunca. Ponle z_index = -100 para que quede detrás de todo.

@export var tamano_celda: float = 96.0
@export var grosor: float = 1.0
@export var color_linea: Color = Color(1.0, 1.0, 1.0, 0.07)
@export var color_ejes: Color = Color(1.0, 1.0, 1.0, 0.16)

var _camara: Camera2D


func _ready() -> void:
	z_index = -100
	_camara = get_viewport().get_camera_2d()


func _process(_delta: float) -> void:
	if not is_instance_valid(_camara):
		# La cámara es hermana de este nodo; puede no existir todavía en _ready().
		_camara = get_viewport().get_camera_2d()
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_camara):
		return
	var celda := maxf(tamano_celda, 8.0)
	# Rectángulo visible del mundo (la cámara aplica su zoom).
	var mitad := get_viewport_rect().size * 0.5 / _camara.zoom
	var esquina := _camara.get_screen_center_position() - mitad - global_position
	var fin := esquina + mitad * 2.0

	# Líneas verticales.
	var x := floorf(esquina.x / celda) * celda
	while x <= fin.x:
		draw_line(Vector2(x, esquina.y), Vector2(x, fin.y), color_linea, grosor)
		x += celda

	# Líneas horizontales.
	var y := floorf(esquina.y / celda) * celda
	while y <= fin.y:
		draw_line(Vector2(esquina.x, y), Vector2(fin.x, y), color_linea, grosor)
		y += celda

	# Ejes del origen (0, 0), para orientarse.
	if esquina.x <= 0.0 and fin.x >= 0.0:
		draw_line(Vector2(0.0, esquina.y), Vector2(0.0, fin.y), color_ejes, grosor * 2.0)
	if esquina.y <= 0.0 and fin.y >= 0.0:
		draw_line(Vector2(esquina.x, 0.0), Vector2(fin.x, 0.0), color_ejes, grosor * 2.0)
