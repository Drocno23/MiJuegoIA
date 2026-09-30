class_name FondoMenu
extends Node2D
## Fondo vivo de los menús: gusanos de adorno paseando por detrás.
##
## NODO AL QUE SE ADJUNTA: un **Node2D** que `pantalla.gd` crea por código como
## primer hijo de cada pantalla (detrás de todo). No colisiona con nada: los
## gusanos se calculan con matemáticas y se dibujan con círculos, así que no
## cuestan casi nada y no pueden "morir" ni comerse entre ellos.
##
## Cada gusano es una serpiente de círculos que sigue una curva suave
## (seno y coseno); el cuerpo va dibujando posiciones anteriores de esa misma
## curva, de ahí que parezca que se mueve de verdad.

const CANTIDAD := 5  ## Gusanos de adorno en pantalla.
const SEGMENTOS := 14  ## Bolitas por gusano (incluida la cabeza).
const SEPARACION := 16.0  ## Distancia entre bolitas.
const RADIO := 13.0
const RADIO_COLA := 9.0
const ALFA := 0.30  ## Translúcidos: son ambiente, no protagonistas.
## Colores de los gusanos de adorno. Es un `PackedColorArray` (y no un `Array`)
## porque indexarlo devuelve un `Color` de verdad: con un `Array` normal devuelve
## `Variant` y GDScript no puede deducir el tipo en un `:=`.
const COLORES := PackedColorArray([
	Color("4be36a"), Color("00e5ff"), Color("ff7a29"), Color("c39bff"), Color("ffd45c"),
])

var _tiempo := 0.0
var _tonos := PackedFloat32Array()
var _velocidades := PackedFloat32Array()
var _radios := PackedFloat32Array()
var _centros := PackedVector2Array()


func _ready() -> void:
	# Semilla fija: el fondo es siempre igual de bonito al abrir el menú.
	var azar := RandomNumberGenerator.new()
	azar.seed = 20260930
	for i in CANTIDAD:
		_tonos.append(azar.randf())
		_velocidades.append(azar.randf_range(0.16, 0.34) * (1.0 if i % 2 == 0 else -1.0))
		_radios.append(azar.randf_range(0.28, 0.5))


func _process(delta: float) -> void:
	_tiempo += delta
	queue_redraw()


func _draw() -> void:
	var tamano := get_viewport_rect().size
	for i in CANTIDAD:
		_dibujar_gusano(i, tamano)


## Posición de la cabeza del gusano `i` en el instante `t` (curva de Lissajous
## suave dentro de la pantalla). Se usa la misma fórmula para el cuerpo, pero con
## el tiempo un poco atrás: así el cuerpo sigue exactamente el camino de la cabeza.
func _posicion(indice: int, t: float, tamano: Vector2) -> Vector2:
	var velocidad := _velocidades[indice]
	var radio := _radios[indice]
	var fase := _tonos[indice] * TAU
	var centro := tamano * 0.5
	var amplitud := Vector2(tamano.x * 0.42, tamano.y * 0.40) * radio * 2.0
	return centro + Vector2(
		cos(t * velocidad + fase) * amplitud.x * 0.6 + cos(t * velocidad * 0.53) * amplitud.x * 0.4,
		sin(t * velocidad * 1.3 + fase) * amplitud.y * 0.7 + sin(t * velocidad * 0.7) * amplitud.y * 0.3
	)


func _dibujar_gusano(indice: int, tamano: Vector2) -> void:
	var color: Color = COLORES[indice % COLORES.size()]
	var color_cuerpo: Color = color.darkened(0.15)
	# Paso de tiempo entre bolita y bolita: la separación deseada entre 300 px/s
	# (la velocidad aproximada con la que pasean los gusanos de adorno).
	var paso := SEPARACION / 300.0
	for i in range(SEGMENTOS - 1, -1, -1):
		var punto := _posicion(indice, _tiempo - float(i) * paso, tamano)
		var avance := float(i) / float(SEGMENTOS - 1)
		var radio := lerpf(RADIO, RADIO_COLA, avance)
		var relleno: Color = color if i == 0 else color_cuerpo
		var alfa := ALFA * (1.0 - avance * 0.45)
		Dibujo.disco(self, punto, radio + 1.5, Color(color.r, color.g, color.b, alfa * 0.35), true)
		Dibujo.disco(self, punto, radio, Color(relleno.r, relleno.g, relleno.b, alfa), true)
