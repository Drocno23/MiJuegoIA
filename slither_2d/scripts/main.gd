class_name Mundo
extends Node2D
## Gestor del mundo: crea la comida, los power-ups, al jugador y a los bots,
## y actualiza el HUD (puntos, turbo, minimapa y clasificación).
##
## NODO AL QUE SE ADJUNTA: el **Node2D raíz** de `escenas/Main.tscn` (escena principal).
## Estructura de la escena:
##
##   Main                 -> Node2D      (ESTE script)
##   ├── Fondo            -> Node2D      (cuadrícula infinita, fondo.gd)
##   ├── ContenedorComida -> Node2D      (aquí se añaden comidas y power-ups)
##   ├── Gusanos          -> Node2D      (aquí se añaden el jugador y los bots)
##   ├── Camara           -> Camera2D    (sigue al jugador)
##   └── HUD              -> CanvasLayer
##       ├── Puntos, Ayuda, Efectos, TurboTexto
##       ├── TurboFondo/Relleno -> ColorRect (barra de turbo)
##       ├── Clasificacion      -> Label     (los 5 más largos + récord)
##       ├── Minimapa           -> Control   (scripts/minimapa.gd)
##       └── Final              -> Control   (pantalla de fin de partida)

const ESCENA_GUSANO := preload("res://escenas/Gusano.tscn")
const ESCENA_GUSANO_CPU := preload("res://escenas/GusanoCPU.tscn")
const ESCENA_COMIDA := preload("res://escenas/Comida.tscn")

const COLOR_JUGADOR := Color("4be36a")  ## Verde para el jugador.
const COLOR_RESTOS := Color("ff9d3d")  ## Naranja para los restos de un gusano muerto.
const COLOR_SOLTADO := Color("ffd54a")  ## Comida que suelta el turbo al acelerar.
const ANCHO_BARRA_TURBO := 220.0  ## Ancho de la barra de turbo del HUD.
const SEGMENTOS_TURBO_LLENO := 20.0  ## Segmentos que llenan la barra de turbo.

@export_group("Comida")
@export var comida_inicial: int = 150  ## Cuánta comida hay al empezar.
@export var comida_maxima: int = 550  ## Tope de nodos de comida en el mundo.
@export var comida_por_segundo: float = 14.0
@export var radio_aparicion: float = 950.0  ## Radio, alrededor del jugador, donde aparece comida.

@export_group("Power-ups")
@export var powerups_activos: bool = true
@export var intervalo_powerup: float = 18.0  ## Cada cuántos segundos aparece uno.
@export var max_powerups: int = 3  ## Cuántos puede haber a la vez en el mundo.
@export var powerup_al_empezar: bool = true  ## Aparece uno nada más empezar.

@export_group("Gusanos")
@export var bots_iniciales: int = 7
@export var velocidad_jugador: float = 180.0
@export var velocidad_bots: float = 152.0
@export var separacion_segmentos: float = 15.0
@export var distancia_minima_spawn: float = 450.0

@export_group("HUD")
@export var intervalo_clasificacion: float = 0.25  ## Cada cuánto se refresca el marcador.

var jugador: Gusano = null
var _puntos := 0
var _record := 0  ## Longitud máxima alcanzada en la partida.
var _temporizador_comida := 0.0
var _temporizador_powerup := 0.0
var _temporizador_clasificacion := 0.0
var _contador_bots := 0
var _generacion := 0  ## Sube al reiniciar, para que los bots viejos no reaparezcan.

@onready var contenedor_comida: Node2D = $ContenedorComida
@onready var contenedor_gusanos: Node2D = $Gusanos
@onready var camara: Camera2D = $Camara
@onready var etiqueta_puntos: Label = $HUD/Puntos
@onready var etiqueta_ayuda: Label = $HUD/Ayuda
@onready var etiqueta_efectos: Label = $HUD/Efectos
@onready var etiqueta_turbo: Label = $HUD/TurboTexto
@onready var turbo_relleno: ColorRect = $HUD/TurboFondo/Relleno
@onready var etiqueta_clasificacion: Label = $HUD/Clasificacion
@onready var pantalla_final: Control = $HUD/Final
@onready var etiqueta_final: Label = $HUD/Final/Texto


func _ready() -> void:
	_asegurar_accion_turbo()
	_crear_jugador()
	for i in bots_iniciales:
		_crear_bot()
	for i in comida_inicial:
		_aparecer_comida()
	if powerups_activos and powerup_al_empezar:
		_aparecer_powerup()
	_actualizar_hud()
	_actualizar_clasificacion()
	_mostrar_ayuda()


func _process(delta: float) -> void:
	_seguir_jugador()
	_generar_comida(delta)
	_generar_powerups(delta)
	_actualizar_turbo_jugador()
	_actualizar_hud()
	_temporizador_clasificacion -= delta
	if _temporizador_clasificacion <= 0.0:
		_temporizador_clasificacion = intervalo_clasificacion
		_actualizar_clasificacion()


func _input(evento: InputEvent) -> void:
	# Reinicio: ESPACIO/ENTER (acción ui_accept) o clic del ratón.
	if not pantalla_final.visible:
		return
	var es_clic := false
	if evento is InputEventMouseButton:
		es_clic = (evento as InputEventMouseButton).pressed
	if evento.is_action_pressed("ui_accept") or es_clic:
		_reiniciar_partida()


## Crea la acción "turbo" (SHIFT o clic derecho) si no existe todavía.
## Así no hay que tocar el mapa de acciones del `project.godot` y sigue siendo
## remapeable: cualquiera puede añadir más teclas desde Ajustes → Input Map.
func _asegurar_accion_turbo() -> void:
	if InputMap.has_action("turbo"):
		return
	InputMap.add_action("turbo")
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_SHIFT
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("turbo", tecla)
	InputMap.action_add_event("turbo", clic)


# ---------------------------------------------------------------------------
# Mundo
# ---------------------------------------------------------------------------

func _seguir_jugador() -> void:
	# La cámara va suavizada (Camera2D -> Position Smoothing en la escena).
	if is_instance_valid(jugador):
		camara.global_position = jugador.global_position


func _generar_comida(delta: float) -> void:
	if contenedor_comida.get_child_count() >= comida_maxima:
		return
	_temporizador_comida += comida_por_segundo * delta
	while _temporizador_comida >= 1.0:
		_temporizador_comida -= 1.0
		_aparecer_comida()


func _generar_powerups(delta: float) -> void:
	if not powerups_activos:
		return
	_temporizador_powerup += delta
	if _temporizador_powerup < intervalo_powerup:
		return
	_temporizador_powerup = 0.0
	if _contar_powerups() >= max_powerups:
		return
	_aparecer_powerup()


func _contar_powerups() -> int:
	var total := 0
	for nodo in contenedor_comida.get_children():
		var comida := nodo as Comida
		if comida != null and Comida.es_powerup(comida.tipo):
			total += 1
	return total


## Crea una comida. Se usa también para los restos de un gusano muerto.
func _aparecer_comida(
	posicion: Vector2 = Vector2.INF,
	valor: int = 1,
	radio_comida: float = 8.0,
	color_comida: Color = Color("ffd54a")
) -> void:
	var comida := ESCENA_COMIDA.instantiate() as Comida
	comida.valor = valor
	comida.radio = radio_comida
	comida.color = color_comida
	contenedor_comida.add_child(comida)
	comida.global_position = posicion if posicion != Vector2.INF else _punto_aleatorio()


## Crea un power-up al azar (imán, escudo, turbo gratis o fantasma).
func _aparecer_powerup() -> void:
	var tipo := Comida.tipo_aleatorio()
	var comida := ESCENA_COMIDA.instantiate() as Comida
	comida.tipo = tipo
	comida.valor = 3
	comida.segmentos = 0  # Los power-ups dan efecto, no cuerpo.
	comida.radio = 11.0
	comida.color = Comida.color_por_tipo(tipo)
	comida.duracion = Comida.duracion_por_tipo(tipo)
	contenedor_comida.add_child(comida)
	comida.global_position = _punto_aleatorio()


func _punto_aleatorio() -> Vector2:
	var centro := jugador.global_position if is_instance_valid(jugador) else Vector2.ZERO
	var radio := randf_range(140.0, radio_aparicion)
	return centro + Vector2.RIGHT.rotated(randf() * TAU) * radio


# ---------------------------------------------------------------------------
# Gusanos
# ---------------------------------------------------------------------------

func _crear_jugador() -> void:
	var gusano := ESCENA_GUSANO.instantiate() as Gusano
	gusano.velocidad = velocidad_jugador
	gusano.separacion = separacion_segmentos
	gusano.color = COLOR_JUGADOR
	gusano.segmentos_iniciales = 8
	gusano.nombre = "TÚ"
	# Grupo que usan los bots para saber dónde está "la acción".
	gusano.add_to_group(Gusano.GRUPO_JUGADOR)
	gusano.murio.connect(_on_gusano_murio.bind(gusano))
	gusano.puntuacion_cambiada.connect(_on_puntuacion_cambiada)
	gusano.segmento_soltado.connect(_on_segmento_soltado)
	contenedor_gusanos.add_child(gusano)
	jugador = gusano


func _crear_bot() -> void:
	_contador_bots += 1
	var bot := ESCENA_GUSANO_CPU.instantiate() as GusanoCPU
	bot.velocidad = velocidad_bots * randf_range(0.85, 1.15)
	bot.separacion = separacion_segmentos * randf_range(0.95, 1.05)
	bot.color = Color.from_hsv(randf(), 0.65, 1.0)
	bot.segmentos_iniciales = randi_range(6, 14)
	bot.distancia_vision = randf_range(320.0, 520.0)
	bot.distancia_maxima_al_jugador = randf_range(900.0, 1400.0)
	# Algunos bots son "valientes" y usan el turbo para escapar.
	bot.probabilidad_turbo = randf_range(0.0, 0.5)
	bot.nombre = "Bot %d" % _contador_bots
	bot.murio.connect(_on_gusano_murio.bind(bot))
	bot.segmento_soltado.connect(_on_segmento_soltado)
	contenedor_gusanos.add_child(bot)
	bot.global_position = _posicion_libre()
	bot.mirar_hacia(randf() * TAU)  # Cada bot sale en una dirección distinta.


## Busca un punto del mundo lejos del jugador y sin cuerpos de gusanos cerca.
func _posicion_libre() -> Vector2:
	var centro := jugador.global_position if is_instance_valid(jugador) else Vector2.ZERO
	var candidato := centro
	for intento in 14:
		candidato = centro + Vector2.RIGHT.rotated(randf() * TAU) \
			* randf_range(distancia_minima_spawn, distancia_minima_spawn * 2.0)
		if _zona_libre(candidato):
			return candidato
	return candidato


func _zona_libre(punto: Vector2) -> bool:
	const HOLGURA := 150.0
	for nodo in get_tree().get_nodes_in_group(CuerpoSegmento.GRUPO):
		var segmento := nodo as CuerpoSegmento
		if segmento != null and segmento.global_position.distance_to(punto) < HOLGURA:
			return false
	for gusano in contenedor_gusanos.get_children():
		if (gusano as Node2D).global_position.distance_to(punto) < HOLGURA:
			return false
	return true


# ---------------------------------------------------------------------------
# Comer, soltar, morir y reaparecer
# ---------------------------------------------------------------------------

func _on_puntuacion_cambiada(puntos: int, _longitud: int) -> void:
	_puntos = puntos


## El turbo ha gastado un segmento: lo dejamos como comida en su sitio.
## call_deferred(): esto llega desde el paso de física y crear un nodo con
## forma de colisión ahí provocaría "Can't change this state while flushing queries".
func _on_segmento_soltado(posicion: Vector2) -> void:
	_aparecer_comida.call_deferred(posicion, 1, 8.0, COLOR_SOLTADO)


## Un gusano ha muerto: su cuerpo se convierte en comida.
## `gusano` llega "atado" con bind() desde donde conectamos la señal.
func _on_gusano_murio(posiciones: PackedVector2Array, gusano: Gusano) -> void:
	# call_deferred(): venimos de una señal de física, así que creamos los nodos
	# de comida al final del frame en lugar de dentro del paso de física.
	_esparcir_restos.call_deferred(posiciones)
	_record = maxi(_record, posiciones.size())

	if gusano == jugador:
		jugador = null
		_terminar_partida()
	else:
		_reaparecer_bot()


## MECÁNICA: por cada segmento del gusano muerto nace una comida
## en la posición EXACTA donde estaba ese segmento.
func _esparcir_restos(posiciones: PackedVector2Array) -> void:
	for posicion in posiciones:
		_aparecer_comida(posicion, 3, 9.0, COLOR_RESTOS)


func _reaparecer_bot() -> void:
	var generacion := _generacion
	await get_tree().create_timer(1.5).timeout
	# Si mientras esperábamos se reinició la partida, este bot ya no pinta nada.
	if is_inside_tree() and generacion == _generacion:
		_crear_bot()


# ---------------------------------------------------------------------------
# HUD, fin de partida y reinicio
# ---------------------------------------------------------------------------

func _actualizar_turbo_jugador() -> void:
	if not is_instance_valid(jugador):
		etiqueta_efectos.text = ""
		turbo_relleno.size.x = 0.0
		return
	jugador.activar_turbo(Input.is_action_pressed("turbo"))
	turbo_relleno.size.x = ANCHO_BARRA_TURBO * clampf(
		float(jugador.longitud() - jugador.segmentos_minimos_turbo) / SEGMENTOS_TURBO_LLENO,
		0.0, 1.0
	)
	turbo_relleno.color = Color("ff6bd6") if jugador.esta_en_turbo() else Color("4be36a")
	etiqueta_efectos.text = jugador.texto_efectos()


func _actualizar_hud() -> void:
	var largo := jugador.longitud() if is_instance_valid(jugador) else 0
	_record = maxi(_record, largo)
	etiqueta_puntos.text = "PUNTOS: %d    LONGITUD: %d    BOTS: %d    COMIDA: %d" % [
		_puntos,
		largo,
		maxi(contenedor_gusanos.get_child_count() - (1 if is_instance_valid(jugador) else 0), 0),
		contenedor_comida.get_child_count(),
	]


## Marcador con los 5 gusanos más largos y el récord de la partida.
func _actualizar_clasificacion() -> void:
	var gusanos: Array[Gusano] = []
	for nodo in contenedor_gusanos.get_children():
		var gusano := nodo as Gusano
		if gusano != null and not gusano.muerto:
			gusanos.append(gusano)
	gusanos.sort_custom(func(a: Gusano, b: Gusano) -> bool: return a.longitud() > b.longitud())

	var lineas := PackedStringArray(["CLASIFICACIÓN"])
	for i in mini(gusanos.size(), 5):
		var gusano := gusanos[i]
		var etiqueta := gusano.nombre if gusano.nombre != "" else "Bot"
		var marca := "  ★ TÚ" if gusano == jugador else ""
		lineas.append("%d. %s — %d%s" % [i + 1, etiqueta, gusano.longitud(), marca])
	lineas.append("Récord: %d" % _record)
	etiqueta_clasificacion.text = "\n".join(lineas)


func _mostrar_ayuda() -> void:
	etiqueta_ayuda.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(7.0)
	tween.tween_property(etiqueta_ayuda, "modulate:a", 0.0, 1.5)


func _terminar_partida() -> void:
	etiqueta_final.text = (
		"¡TE HAN COMIDO!\n\nPuntos: %d\nLongitud récord: %d\n\n"
		+ "Pulsa ESPACIO o haz clic para volver a jugar"
	) % [_puntos, _record]
	pantalla_final.visible = true


func _reiniciar_partida() -> void:
	_generacion += 1
	pantalla_final.visible = false
	_puntos = 0
	_record = 0
	_temporizador_powerup = 0.0

	# Vaciamos el mundo. Marcamos a los gusanos como muertos para que dejen de
	# moverse en este mismo frame (queue_free() los borra al final del frame).
	for nodo in contenedor_gusanos.get_children():
		var gusano := nodo as Gusano
		if gusano != null:
			gusano.muerto = true
			gusano.set_physics_process(false)
		nodo.queue_free()
	for nodo in contenedor_comida.get_children():
		nodo.queue_free()

	jugador = null
	_crear_jugador()
	for i in bots_iniciales:
		_crear_bot()
	for i in comida_inicial:
		_aparecer_comida()
	if powerups_activos and powerup_al_empezar:
		_aparecer_powerup()
	_actualizar_hud()
	_actualizar_clasificacion()
