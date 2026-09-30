class_name Minimapa
extends Control
## Minimapa de la esquina superior derecha.
##
## NODO AL QUE SE ADJUNTA: un **Control** hijo de `HUD` en `escenas/Main.tscn`
## (nodo "Minimapa"). Se dibuja por código, así que no necesita texturas.
##
## Qué muestra (todo alrededor del jugador, que va en el centro):
##   * gusanos (cada uno con su color; el jugador, con un aro blanco),
##   * comida normal (puntos pequeños y translúcidos),
##   * restos de un gusano muerto (naranja),
##   * power-ups (su color, más grandes y con más brillo).
##
## `escala` convierte píxeles del mundo en píxeles del minimapa: con 0.032,
## el panel de ~210 px abarca unos 6500 px de mundo.

@export var escala: float = 0.032
@export var alcance: float = 2600.0  ## Radio del mundo que se muestra (píxeles).
@export var max_puntos_comida: int = 250  ## Límite de puntos de comida por frame.
@export var tamano_punto: float = 2.0

@export var color_fondo: Color = Color(0.04, 0.06, 0.12, 0.72)
@export var color_borde: Color = Color(1.0, 1.0, 1.0, 0.22)
@export var color_comida: Color = Color(1.0, 0.84, 0.29, 0.45)
@export var color_restos: Color = Color(1.0, 0.62, 0.24, 0.95)

var _visible: Rect2  ## Rectángulo interior donde se pintan los puntos.
var _medio := Vector2.ZERO  ## Centro del panel (donde va el jugador).


func _ready() -> void:
	_actualizar_caja()


func _process(_delta: float) -> void:
	queue_redraw()


func _notification(what: int) -> void:
	# Si cambia el tamaño del panel (por ejemplo al redimensionar la ventana),
	# recalculamos el centro y el rectángulo interior.
	if what == NOTIFICATION_RESIZED:
		_actualizar_caja()


func _actualizar_caja() -> void:
	_medio = size * 0.5
	_visible = Rect2(Vector2.ZERO, size).grow(-3.0)


func _draw() -> void:
	_actualizar_caja()
	var caja := Rect2(Vector2.ZERO, size)
	draw_rect(caja, color_fondo, true)

	var jugador := get_tree().get_first_node_in_group(Gusano.GRUPO_JUGADOR) as Node2D
	var origen := jugador.global_position if jugador != null else Vector2.ZERO

	# ---- comida ----
	var mostrados := 0
	for nodo in get_tree().get_nodes_in_group(Comida.GRUPO):
		if mostrados >= max_puntos_comida:
			break
		var comida := nodo as Comida
		if comida == null:
			continue
		var punto := _a_pantalla(comida.global_position, origen)
		if not _visible.has_point(punto):
			continue
		mostrados += 1
		if Comida.es_powerup(comida.tipo):
			draw_circle(punto, tamano_punto * 2.0, comida.color)
		elif comida.es_resto():
			draw_circle(punto, tamano_punto, color_restos)
		else:
			draw_circle(punto, tamano_punto * 0.8, color_comida)

	# ---- gusanos ----
	for nodo in get_tree().get_nodes_in_group(Gusano.GRUPO):
		var gusano := nodo as Gusano
		if gusano == null:
			continue
		var punto := _a_pantalla(gusano.global_position, origen)
		if not _visible.has_point(punto):
			continue
		if gusano == jugador:
			draw_circle(punto, tamano_punto * 2.6, Color.WHITE)
			draw_circle(punto, tamano_punto * 1.9, gusano.color)
		else:
			draw_circle(punto, tamano_punto * 1.6, gusano.color)

	draw_rect(caja, color_borde, false, 2.0)


## Pasa una posición del mundo a coordenadas del minimapa (el jugador al centro).
## Devuelve un punto fuera de la caja si está más lejos que `alcance`.
func _a_pantalla(posicion: Vector2, origen: Vector2) -> Vector2:
	var relativa := posicion - origen
	if relativa.length() > alcance:
		return Vector2(-1000.0, -1000.0)  # Fuera: el bucle lo descarta.
	return _medio + relativa * escala
