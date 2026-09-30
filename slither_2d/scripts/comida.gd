class_name Comida
extends Area2D
## Bola de comida que el gusano puede comer.
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

const GRUPO := "comida"  ## Grupo que usa la cabeza del gusano para reconocerla.

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

## Dibuja los círculos con el borde suave (independiente del MSAA del renderizador).
## Ponlo en false para volver al draw_circle() clásico.
@export var bordes_suaves: bool = true

@export var color: Color = Color("ffd54a"):
	set(nuevo_color):
		color = nuevo_color
		queue_redraw()

var _tween_latido: Tween

@onready var _forma: CollisionShape2D = $CollisionShape2D


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
