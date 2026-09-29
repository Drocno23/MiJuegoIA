class_name Gusano
extends Node2D
## Gusano estilo slither.io (núcleo del juego).
##
## NODO AL QUE SE ADJUNTA: el **Node2D raíz** de `escenas/Gusano.tscn`.
## Estructura de la escena que espera este script:
##
##   Gusano            -> Node2D          (ESTE script)  <- la cabeza ES este nodo
##   ├── Cabeza        -> Area2D          (formato de colisión de la cabeza)
##   │   └── CollisionShape2D -> CircleShape2D
##   └── Segmentos     -> Node2D          (contenedor vacío: aquí se añaden por código
##                                         los segmentos de `escenas/Segmento.tscn`)
##
## CÓMO FUNCIONA EL CUERPO
##   1. La cabeza avanza siempre a la misma velocidad y gira poco a poco hacia el objetivo
##      (el ratón en el jugador, la comida en los bots).
##   2. Cada pocos píxeles se guarda un punto del camino recorrido (`_ruta`).
##   3. Cada segmento se coloca sobre ese camino a una distancia fija de la cabeza
##      (`_punto_detras`), así el cuerpo sigue exactamente la huella que dejó la cabeza
##      y la separación entre segmentos nunca cambia.

## Emitida al morir. Lleva las posiciones exactas de todos los segmentos para que
## el mundo (main.gd) convierta el cuerpo en comida.
signal murio(posiciones_restos: PackedVector2Array)
## Emitida al comer: puntos acumulados y longitud total (cabeza + segmentos).
signal puntuacion_cambiada(puntos: int, longitud: int)

const PASO_RUTA := 4.0  ## Distancia en píxeles entre puntos guardados del camino.
const MAX_PASOS_FRAME := 8  ## Límite de seguridad al muestrear el camino.

@export_group("Movimiento")
@export var velocidad: float = 170.0  ## Píxeles por segundo (constante, como en slither.io).
@export var velocidad_giro: float = 6.0  ## Radianes por segundo: cuánto puede girar la cabeza.

@export_group("Cuerpo")
@export var separacion: float = 15.0  ## Distancia fija entre segmentos (y entre cabeza y 1º).
@export var segmentos_iniciales: int = 8
@export var segmentos_maximos: int = 80  ## Tope para no reventar el rendimiento.
@export var escena_segmento: PackedScene = preload("res://escenas/Segmento.tscn")

@export_group("Apariencia")
@export var radio: float = 12.0
@export var color: Color = Color("35c9ff")

@export_group("Reglas")
## Segundos al nacer en los que no puede morir (evita muertes absurdas al aparecer).
@export var inmunidad_inicial: float = 2.0

var puntuacion: int = 0
var muerto: bool = false
var direccion: Vector2 = Vector2.RIGHT  ## Dirección actual de avance de la cabeza.

var _segmentos: Array[CuerpoSegmento] = []  ## Índice 0 = primer segmento (pegado a la cabeza).
var _ruta := PackedVector2Array()  ## Camino recorrido. Índice 0 = punto más reciente.
var _tiempo_inmunidad := 0.0

@onready var cabeza: Area2D = $Cabeza
@onready var contenedor_segmentos: Node2D = $Segmentos
@onready var _forma_cabeza: CollisionShape2D = $Cabeza/CollisionShape2D


func _ready() -> void:
	_tiempo_inmunidad = inmunidad_inicial
	# Forma de colisión propia de esta instancia (si no, todas las cabezas
	# compartirían el mismo CircleShape2D de la escena).
	_forma_cabeza.shape = _forma_cabeza.shape.duplicate()
	(_forma_cabeza.shape as CircleShape2D).radius = radio

	# La cabeza detecta comida y cuerpos ajenos (Area2D -> monitoring = ON).
	cabeza.area_entered.connect(_on_cabeza_area_entered)

	_inicializar_ruta()
	for i in segmentos_iniciales:
		_agregar_segmento(false)  # Sin animación: al nacer ya están todos.


func _physics_process(delta: float) -> void:
	if muerto:
		return
	if _tiempo_inmunidad > 0.0:
		_tiempo_inmunidad -= delta

	_girar(delta)
	global_position += direccion * velocidad * delta

	_actualizar_ruta()
	_colocar_segmentos()
	queue_redraw()  # Para que los ojos giren con la cabeza.


# ---------------------------------------------------------------------------
# 1) MOVIMIENTO: la cabeza gira suavemente hacia el objetivo
# ---------------------------------------------------------------------------

## ¿Hacia dónde quiere ir el gusano? Por defecto, hacia el ratón (lo usa el jugador).
## Los bots de `gusano_cpu.gd` sobreescriben esta función.
func _direccion_deseada() -> Vector2:
	return global_position.direction_to(get_global_mouse_position())


func _girar(delta: float) -> void:
	var deseada := _direccion_deseada()
	if deseada.length_squared() < 0.0001:
		return  # Sin objetivo: sigue recto.
	# angle_difference() devuelve el giro más corto entre dos ángulos (Godot 4.2+).
	var diferencia := angle_difference(direccion.angle(), deseada.angle())
	var paso_maximo := velocidad_giro * delta
	direccion = direccion.rotated(clampf(diferencia, -paso_maximo, paso_maximo))


# ---------------------------------------------------------------------------
# 2) CUERPO: cadena de segmentos sobre el camino de la cabeza
# ---------------------------------------------------------------------------

## Crea la ruta inicial recta detrás de la cabeza (para que el gusano
## no aparezca con todos los segmentos amontonados en el mismo punto).
func _inicializar_ruta() -> void:
	_ruta.clear()
	var puntos := int(((segmentos_iniciales + 2) * separacion) / PASO_RUTA)
	for i in puntos:
		_ruta.append(global_position - direccion * i * PASO_RUTA)


## Guarda el camino que va dejando la cabeza (un punto cada PASO_RUTA píxeles).
func _actualizar_ruta() -> void:
	if _ruta.is_empty():
		_ruta.push_front(global_position)
		return
	var pasos := 0
	while _ruta[0].distance_to(global_position) >= PASO_RUTA and pasos < MAX_PASOS_FRAME:
		_ruta.push_front(_ruta[0].move_toward(global_position, PASO_RUTA))
		pasos += 1
	# Recortamos la cola de la ruta: solo interesa la longitud que ocupa el cuerpo.
	var necesarios := int(((float(_segmentos.size()) + 1.0) * separacion) / PASO_RUTA) + 4
	if _ruta.size() > necesarios:
		_ruta = _ruta.slice(0, necesarios)


## Punto del camino situado a `distancia` píxeles por detrás de la cabeza.
func _punto_detras(distancia: float) -> Vector2:
	if _ruta.is_empty():
		return global_position
	var d0 := global_position.distance_to(_ruta[0])
	if distancia <= d0 or _ruta.size() < 2:
		# Todavía estamos en el tramo entre la cabeza y el último punto guardado.
		return global_position.lerp(_ruta[0], distancia / maxf(d0, 0.001))
	var indice: float = (distancia - d0) / PASO_RUTA
	var i := int(indice)
	if i + 1 >= _ruta.size():
		return _ruta[_ruta.size() - 1]  # La ruta es más corta que el cuerpo.
	return _ruta[i].lerp(_ruta[i + 1], indice - float(i))


## Coloca cada segmento sobre la ruta a distancia fija (separacion * número de segmento).
func _colocar_segmentos() -> void:
	for i in _segmentos.size():
		_segmentos[i].global_position = _punto_detras((float(i) + 1.0) * separacion)


func _agregar_segmento(animar: bool = true) -> void:
	var segmento := escena_segmento.instantiate() as CuerpoSegmento
	# Estas propiedades hay que asignarlas ANTES de add_child(), porque _ready()
	# del segmento es quien las aplica a la forma de colisión y al dibujo.
	segmento.radio = radio
	segmento.color = color
	segmento.dueno = self
	segmento.animar_aparicion = animar
	contenedor_segmentos.add_child(segmento)
	# Después de add_child() ya tiene padre, así que global_position es correcto.
	segmento.global_position = _punto_detras((float(_segmentos.size()) + 1.0) * separacion)
	_segmentos.append(segmento)


## Longitud total del gusano (la cabeza cuenta como 1).
func longitud() -> int:
	return _segmentos.size() + 1


# ---------------------------------------------------------------------------
# 3) CRECIMIENTO: comer añade puntos y un segmento nuevo al final de la cola
# ---------------------------------------------------------------------------

## Añade segmentos al final de la cola. Lo llama `_comer()`.
func crecer(cantidad: int = 1) -> void:
	for i in cantidad:
		if _segmentos.size() >= segmentos_maximos:
			return
		_agregar_segmento()


func _on_cabeza_area_entered(area: Area2D) -> void:
	if muerto:
		return
	if area.is_in_group(Comida.GRUPO):
		_comer(area as Comida)
	elif area.is_in_group(CuerpoSegmento.GRUPO):
		_chocar_con_cuerpo(area as CuerpoSegmento)


func _comer(comida: Comida) -> void:
	if not is_instance_valid(comida):
		return
	puntuacion += comida.valor
	crecer(comida.segmentos)
	puntuacion_cambiada.emit(puntuacion, longitud())
	comida.consumir()


## Regla de muerte: la cabeza muere si toca el cuerpo de OTRO gusano.
## (Tocar el propio cuerpo está permitido, como en slither.io).
func _chocar_con_cuerpo(segmento: CuerpoSegmento) -> void:
	if _tiempo_inmunidad > 0.0:
		return
	var otro := segmento.dueno
	if otro == self or not is_instance_valid(otro):
		return
	morir()


# ---------------------------------------------------------------------------
# 4) MUERTE: el cuerpo se convierte en comida
# ---------------------------------------------------------------------------

## Muere: avisa al mundo con las posiciones exactas de sus segmentos y desaparece.
func morir() -> void:
	if muerto:
		return
	muerto = true
	set_physics_process(false)

	# a) Posiciones exactas: la cabeza primero y después cada segmento.
	var posiciones := PackedVector2Array()
	posiciones.append(global_position)
	for segmento in _segmentos:
		posiciones.append(segmento.global_position)

	# b) Desactivamos la colisión. set_deferred() porque estamos dentro de una
	#    señal de física y no se puede tocar el área en ese mismo instante.
	cabeza.set_deferred("monitoring", false)
	for segmento in _segmentos:
		segmento.set_deferred("monitorable", false)

	# c) Avisamos al mundo: main.gd crea una Comida en cada posición.
	murio.emit(posiciones)

	# d) Nos ocultamos y liberamos.
	visible = false
	queue_free()


## Orienta el gusano hacia un ángulo (radianes). Útil para los bots al aparecer.
func mirar_hacia(angulo: float) -> void:
	direccion = Vector2.RIGHT.rotated(angulo)
	_inicializar_ruta()


# ---------------------------------------------------------------------------
# Dibujo (todo por código: el proyecto no necesita ninguna imagen)
# ---------------------------------------------------------------------------

func _draw() -> void:
	draw_circle(Vector2.ZERO, radio, color.darkened(0.45))  # borde
	draw_circle(Vector2.ZERO, radio * 0.88, color)  # relleno
	# Ojos: miran siempre hacia donde va la cabeza.
	var hacia_adelante := direccion * radio * 0.45
	var hacia_lado := direccion.orthogonal() * radio * 0.4
	for lado in [-1.0, 1.0]:
		var ojo := hacia_adelante + hacia_lado * lado
		draw_circle(ojo, radio * 0.27, Color.WHITE)
		draw_circle(ojo + direccion * radio * 0.1, radio * 0.14, Color.BLACK)
