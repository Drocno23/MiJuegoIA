class_name GusanoCPU
extends Gusano
## Gusano controlado por la máquina (bot enemigo).
##
## NODO AL QUE SE ADJUNTA: a la raíz Node2D de `escenas/GusanoCPU.tscn`, que es una
## **escena heredada** de `escenas/Gusano.tscn` (misma estructura de nodos, pero con
## este script, que solo cambia "hacia dónde quiere ir").
##
## La IA es sencilla a propósito:
##   1. Si se ha alejado demasiado de la acción, vuelve hacia el jugador.
##   2. Si tiene el cuerpo de otro gusano cerca -> huye en la dirección contraria.
##   3. Si no, persigue la comida más cercana dentro de su campo de visión.
##   4. Si no ve nada, gira un poco al azar para no ir siempre en línea recta.

const GRUPO_JUGADOR := "jugador"  ## El gusano del jugador se añade a este grupo (lo hace main.gd).

@export var distancia_vision: float = 420.0  ## Alcance para buscar comida.
@export var margen_peligro: float = 80.0  ## Distancia a un cuerpo ajeno que considera peligrosa.
@export var tiempo_entre_decisiones: float = 0.15  ## No hace falta pensar en cada frame.
## Si se aleja más de esto del jugador, deja de buscar comida y vuelve
## (si no, en un mundo infinito los bots acaban perdidos donde no hay nada).
@export var distancia_maxima_al_jugador: float = 1100.0

var _direccion_ia: Vector2 = Vector2.RIGHT
var _tiempo_decision := 0.0


func _physics_process(delta: float) -> void:
	_tiempo_decision -= delta
	if _tiempo_decision <= 0.0:
		_tiempo_decision = tiempo_entre_decisiones
		_elegir_decision()
	super(delta)  # Movimiento y cuerpo: los hace gusano.gd.


## Sobreescritura del movimiento: en vez del ratón, usa lo que decidió la IA.
func _direccion_deseada() -> Vector2:
	return _direccion_ia


func _elegir_decision() -> void:
	# 1) ¿Se ha alejado demasiado? Entonces vuelve hacia el jugador.
	var jugador := get_tree().get_first_node_in_group(GRUPO_JUGADOR)
	if jugador is Node2D:
		var centro := (jugador as Node2D).global_position
		if global_position.distance_to(centro) > distancia_maxima_al_jugador:
			_direccion_ia = global_position.direction_to(centro)
			return

	# 2) ¿Hay cuerpos de otros gusanos demasiado cerca?
	var huida := Vector2.ZERO
	var peligros := 0
	for nodo in get_tree().get_nodes_in_group(CuerpoSegmento.GRUPO):
		var segmento := nodo as CuerpoSegmento
		if segmento == null or segmento.dueno == self or not is_instance_valid(segmento.dueno):
			continue
		var distancia := global_position.distance_to(segmento.global_position)
		if distancia < margen_peligro:
			# Cuanto más cerca, más peso tiene ese vector de huida.
			huida += (global_position - segmento.global_position).normalized() \
				* (margen_peligro / maxf(distancia, 1.0))
			peligros += 1

	if peligros > 0:
		# Mezclamos la huida con la dirección actual para no dar un giro brusco.
		_direccion_ia = (huida.normalized() * 1.4 + direccion * 0.6).normalized()
		return

	# 3) Sin peligro: a por la comida más cercana que esté a la vista.
	var comida_cercana := Vector2.ZERO
	var mejor_distancia := distancia_vision
	for nodo in get_tree().get_nodes_in_group(Comida.GRUPO):
		var comida := nodo as Comida
		if comida == null:
			continue
		var distancia := global_position.distance_to(comida.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			comida_cercana = comida.global_position

	if comida_cercana != Vector2.ZERO:
		_direccion_ia = global_position.direction_to(comida_cercana)
		return

	# 4) Nada a la vista: un poco de giro aleatorio.
	_direccion_ia = direccion.rotated(randf_range(-0.7, 0.7))
