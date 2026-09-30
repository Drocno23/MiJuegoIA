class_name VistaPrevia
extends Control
## Vista previa del gusano con la piel elegida, girando despacio.
##
## NODO AL QUE SE ADJUNTA: a un **Control** de la pantalla de selección
## (`escenas/Seleccion.tscn`), que es quien llama a `configurar()` cada vez que el
## jugador cambia de paleta o de patrón.
##
## Usa exactamente las mismas funciones que el juego de verdad
## (`Pieles.color_de_segmento()` y `Dibujo.disco()`), así que lo que se ve aquí es
## literalmente lo que se verá al jugar.

const SEGMENTOS := 22
const SEPARACION := 15.0
const RADIO := 12.0
const VUELTAS_POR_SEGUNDO := 0.12  ## Giro lento del conjunto.

var paleta := 0
var patron := 0

var _tiempo := 0.0


func _ready() -> void:
	# El Control no se come los clics: se puede pulsar a través de él.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_tiempo += delta
	queue_redraw()


## Cambia la piel que se está viendo (la llama `seleccion.gd`).
func configurar(paleta_nueva: int, patron_nuevo: int) -> void:
	paleta = paleta_nueva
	patron = patron_nuevo
	queue_redraw()


## Trayectoria de la cabeza: un círculo un poco deformado, para que se note el giro.
func _punto_trayectoria(angulo: float) -> Vector2:
	var radio := Vector2(size.x * 0.24, size.y * 0.20)
	var deformacion := 1.0 + 0.18 * sin(angulo * 2.0 + _tiempo)
	return size * 0.5 + Vector2(cos(angulo), sin(angulo)) * radio * deformacion


func _draw() -> void:
	var colores := Pieles.colores_paleta(paleta)
	var angulo_cabeza := _tiempo * TAU * VUELTAS_POR_SEGUNDO
	# El cuerpo va por detrás, sobre la misma trayectoria pero un poco antes.
	var paso := SEPARACION / 300.0 * TAU * VUELTAS_POR_SEGUNDO
	for i in range(SEGMENTOS - 1, -1, -1):
		var angulo := angulo_cabeza - float(i) * paso
		var punto := _punto_trayectoria(angulo)
		var color_base := Pieles.color_de_segmento(colores, patron, i, SEGMENTOS, 7)
		# El degradado del borde hace que se vean separados aunque se solapen.
		Dibujo.disco(self, punto, RADIO + 2.0, Color(0.02, 0.03, 0.06, 0.55), true)
		Dibujo.disco(self, punto, RADIO, color_base.darkened(0.18), true)
		Dibujo.disco(self, punto, RADIO * 0.82, color_base, true)
		Dibujo.disco(
			self, punto - Vector2.ONE * RADIO * 0.25, RADIO * 0.2, color_base.lightened(0.45), true
		)
		if i == 0:
			_dibujar_ojos(punto, angulo + PI * 0.5)


func _dibujar_ojos(punto: Vector2, hacia: float) -> void:
	var direccion := Vector2.RIGHT.rotated(hacia)
	var lateral := direccion.orthogonal()
	for lado in PackedFloat32Array([-1.0, 1.0]):
		var ojo: Vector2 = punto + direccion * RADIO * 0.45 + lateral * RADIO * 0.42 * lado
		Dibujo.disco(self, ojo, RADIO * 0.3, Color.WHITE, true)
		Dibujo.disco(self, ojo + direccion * RADIO * 0.1, RADIO * 0.15, Color.BLACK, true)
