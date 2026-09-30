class_name Comida
extends Area2D
## Bola de comida **o power-up** que el gusano puede comer.
##
## NODO AL QUE SE ADJUNTA: un **Area2D** (escena `escenas/Comida.tscn`).
## Configuración del Area2D en el inspector:
##   * Collision Layer  = capa 3 ("Comida")  -> es lo que el gusano detecta.
##   * Collision Mask   = ninguna            -> la comida no detecta nada.
##   * Monitoring       = OFF (ahorra CPU, nadie necesita que la comida detecte).
##   * Monitorable      = ON  (para que la cabeza del gusano sí la detecte).
##
## El dibujo se hace con `_draw()` para no necesitar ninguna imagen;
## si prefieres un sprite, borra `_draw()` y añade un Sprite2D como hijo.
##
## TIPOS: además de la comida normal (amarilla, 1 punto), hay 4 power-ups que
## otorgan un efecto temporal (los aplica `gusano.gd::aplicar_powerup()`):
##   * IMÁN     -> atrae la comida cercana hacia la cabeza.
##   * ESCUDO   -> no puedes morir por chocar con otro cuerpo.
##   * TURBO    -> turbo gratis (sin perder longitud) durante unos segundos.
##   * FANTASMA -> tampoco mueres y el cuerpo se vuelve translúcido.

## Tipos de comida. NORMAL es la comida corriente; el resto son power-ups.
enum Tipo { NORMAL, IMAN, ESCUDO, TURBO, FANTASMA }

const GRUPO := "comida"  ## Grupo que usa la cabeza del gusano para reconocerla.

@export var tipo: int = Tipo.NORMAL  ## Usa las constantes `Comida.Tipo.*`.
## Duración del efecto en segundos (solo tiene sentido en los power-ups).
@export var duracion: float = 0.0

@export var valor: int = 1:  ## Puntos que otorga al comerse.
	set(nuevo_valor):
		valor = maxi(nuevo_valor, 0)

@export var segmentos: int = 1:  ## Segmentos que crece el gusano al comérsela.
	set(nuevo_valor):
		segmentos = maxi(nuevo_valor, 0)

@export var radio: float = 8.0:  ## Radio visual y de colisión.
	set(nuevo_radio):
		radio = maxf(nuevo_radio, 1.0)
		_actualizar_forma()

@export var color: Color = Color("ffd54a"):
	set(nuevo_color):
		color = nuevo_color
		queue_redraw()

## Dibuja los círculos con el borde suave (independiente del MSAA del renderizador).
## Ponlo en false para volver al draw_circle() clásico.
@export var bordes_suaves: bool = true

var _tween_latido: Tween

@onready var _forma: CollisionShape2D = $CollisionShape2D


# ---------------------------------------------------------------------------
# Utilidades de los power-ups (estáticas: se pueden usar sin instanciar nada)
# ---------------------------------------------------------------------------

## ¿Este tipo es un power-up (y no comida normal)?
static func es_powerup(tipo_comida: int) -> bool:
	return tipo_comida != Tipo.NORMAL


## Nombre para el HUD ("IMÁN", "ESCUDO"...).
static func nombre_por_tipo(tipo_comida: int) -> String:
	match tipo_comida:
		Tipo.IMAN:
			return "IMÁN"
		Tipo.ESCUDO:
			return "ESCUDO"
		Tipo.TURBO:
			return "TURBO"
		Tipo.FANTASMA:
			return "FANTASMA"
		_:
			return "COMIDA"


static func color_por_tipo(tipo_comida: int) -> Color:
	match tipo_comida:
		Tipo.IMAN:
			return Color("5ce1ff")
		Tipo.ESCUDO:
			return Color("b8ffcc")
		Tipo.TURBO:
			return Color("ff6bd6")
		Tipo.FANTASMA:
			return Color("c39bff")
		_:
			return Color("ffd54a")


static func duracion_por_tipo(tipo_comida: int) -> float:
	match tipo_comida:
		Tipo.IMAN:
			return 6.0
		Tipo.ESCUDO:
			return 5.0
		Tipo.TURBO:
			return 4.0
		Tipo.FANTASMA:
			return 5.0
		_:
			return 0.0


## Un power-up al azar (para el generador de `main.gd`).
static func tipo_aleatorio() -> int:
	match randi() % 4:
		0:
			return Tipo.IMAN
		1:
			return Tipo.ESCUDO
		2:
			return Tipo.TURBO
		_:
			return Tipo.FANTASMA


# ---------------------------------------------------------------------------
# Ciclo de vida
# ---------------------------------------------------------------------------

## ¿Es un trozo del cuerpo de un gusano muerto? (Comida normal con mucho valor.)
## Lo usa el minimapa para pintarlos de otro color.
func es_resto() -> bool:
	return not es_powerup(tipo) and valor >= 3


func _ready() -> void:
	add_to_group(GRUPO)
	_actualizar_forma()
	queue_redraw()
	_animar_latido()


## La comida se está comiendo: pequeño "pop" y desaparece.
func consumir() -> void:
	remove_from_group(GRUPO)  # Evita que otra cabeza la vuelva a contar.
	set_deferred("monitorable", false)
	if _tween_latido != null and _tween_latido.is_valid():
		_tween_latido.kill()
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE * 1.8, 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)


func _actualizar_forma() -> void:
	if _forma == null or not is_inside_tree():
		return
	# Duplicamos la forma para que cada comida tenga su propio radio
	# (los recursos compartidos por la escena serían los mismos para todas).
	_forma.shape = _forma.shape.duplicate()
	(_forma.shape as CircleShape2D).radius = radio


func _animar_latido() -> void:
	# Latido sutil para que la comida "brille" y llame la atención.
	_tween_latido = create_tween().set_loops()
	_tween_latido.tween_property(self, "scale", Vector2.ONE * 1.12, randf_range(0.5, 0.9)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_latido.tween_property(self, "scale", Vector2.ONE, randf_range(0.5, 0.9)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _draw() -> void:
	Dibujo.disco(self, Vector2.ZERO, radio, color.darkened(0.45), bordes_suaves)
	Dibujo.disco(self, Vector2.ZERO, radio * 0.82, color, bordes_suaves)
	Dibujo.disco(
		self, -Vector2.ONE * radio * 0.28, radio * 0.24, color.lightened(0.5), bordes_suaves
	)  # brillo
	if es_powerup(tipo):
		# Aro alrededor: así se distingue de un vistazo que es un power-up.
		draw_arc(Vector2.ZERO, radio * 1.5, 0.0, TAU, 28, color, 2.0, true)
