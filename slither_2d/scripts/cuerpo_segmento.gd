class_name CuerpoSegmento
extends Area2D
## Un segmento del cuerpo de un gusano.
##
## NODO AL QUE SE ADJUNTA: un **Area2D** (escena `escenas/Segmento.tscn`).
## Configuración del Area2D en el inspector:
##   * Collision Layer = capa 2 ("Cuerpo")  -> es lo que las cabezas detectan.
##   * Collision Mask  = ninguna            -> el segmento no detecta nada.
##   * Monitoring      = OFF  -> un cuerpo con 60 segmentos no gasta CPU detectando.
##   * Monitorable     = ON   -> pero sí puede ser detectado por las cabezas.
##
## IMPORTANTE: los segmentos NO se colocan a mano en el editor.
## Los crea y los coloca el script `gusano.gd` en tiempo real, y también ajusta
## su `radio` para que la cola se vaya afilando.

const GRUPO := "segmento_cuerpo"  ## Grupo que usa la cabeza para reconocer un cuerpo.

## Radio visual y de colisión. El gusano lo cambia en caliente para afilar la
## cola, así que el setter actualiza la forma de colisión y vuelve a dibujar.
@export var radio: float = 12.0:
	set(nuevo_radio):
		radio = maxf(nuevo_radio, 1.0)
		_actualizar_forma()

@export var color: Color = Color("35c9ff"):  ## Color del cuerpo (lo fija el gusano).
	set(nuevo_color):
		color = nuevo_color
		queue_redraw()

@export var animar_aparicion: bool = true  ## Animación de "nacer" al crecer.
## Dibuja los círculos con el borde suave (independiente del MSAA del renderizador).
@export var bordes_suaves: bool = true

## Gusano dueño de este segmento. Se usa para saber si el choque mortal
## es contra el propio cuerpo (permitido) o contra el de otro gusano (muerte).
## Se tipa como Node2D a propósito, para evitar una dependencia circular con gusano.gd.
var dueno: Node2D = null

@onready var _forma: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group(GRUPO)
	# Cada segmento necesita SU PROPIA forma: si no la duplicamos, todos
	# compartirían el mismo recurso CircleShape2D y cambiar el radio de uno
	# cambiaría el de todos.
	_forma.shape = _forma.shape.duplicate()
	# Aplicamos el radio actual (el gusano puede haberlo cambiado antes de
	# add_child(), y aquí ya existe el nodo de la forma).
	_actualizar_forma()
	queue_redraw()
	if animar_aparicion:
		_animar_nacimiento()


## Aplica el radio a la forma de colisión (el dibujo lo hace `_draw()`).
func _actualizar_forma() -> void:
	if _forma == null or not is_inside_tree():
		return
	(_forma.shape as CircleShape2D).radius = radio


func _animar_nacimiento() -> void:
	scale = Vector2.ONE * 0.35
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	# Círculo con borde, relleno y un pequeño brillo: sin necesidad de imágenes.
	Dibujo.disco(self, Vector2.ZERO, radio, color.darkened(0.42), bordes_suaves)
	Dibujo.disco(self, Vector2.ZERO, radio * 0.86, color, bordes_suaves)
	Dibujo.disco(
		self, -Vector2.ONE * radio * 0.3, radio * 0.22, color.lightened(0.4), bordes_suaves
	)
