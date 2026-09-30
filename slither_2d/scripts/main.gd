class_name Mundo
extends Node2D
## Gestor del mundo: crea la comida, los power-ups, al jugador y a los bots, y
## actualiza el HUD (cuatro zonas, sin nada encima de nada).
##
## NODO AL QUE SE ADJUNTA: el **Node2D raíz** de `escenas/Main.tscn` (escena principal).
## Estructura de la escena:
##
##   Main                 -> Node2D      (ESTE script)
##   ├── Fondo            -> Node2D      (cuadrícula infinita, fondo.gd)
##   ├── ContenedorComida -> Node2D      (aquí se añaden comidas y power-ups)
##   ├── Gusanos          -> Node2D      (aquí se añaden el jugador y los bots)
##   ├── Camara           -> Camera2D    (sigue al jugador)
##   ├── Sonido           -> Node2D      (scripts/sonido.gd: audio generado por código)
##   └── HUD              -> CanvasLayer
##       ├── ArribaIzquierda -> VBoxContainer (Puntos, Record, Piel)
##       ├── Aviso           -> Label      (avisos que se desvanecen)
##       ├── ArribaDerecha   -> VBoxContainer
##       │   ├── Minimapa    -> Control    (scripts/minimapa.gd)
##       │   └── Clasificacion -> PanelContainer ("CLASIFICACIÓN": 5 filas y pie)
##       ├── Efectos, TurboTexto, TurboFondo/Relleno (abajo a la izquierda)
##       ├── Audio, FPS      -> Label      (abajo a la derecha)
##       ├── Ayuda           -> Label      (abajo en el centro)
##       ├── Final           -> Control    (fin de partida: un panel con TODO
##       │                                   dentro de contenedores, así que no se
##       │                                   puede amontonar)
##       └── Pausa           -> Pausa.tscn (menú de ESC, se abre encima)
##
## Lo que se recuerda entre partidas (récord, estadísticas, piel y apodo) vive en
## `scripts/records.gd` y se guarda en `user://records.cfg` (tu perfil de Godot).

const ESCENA_GUSANO := preload("res://escenas/Gusano.tscn")
const ESCENA_GUSANO_CPU := preload("res://escenas/GusanoCPU.tscn")
const ESCENA_COMIDA := preload("res://escenas/Comida.tscn")

const COLOR_JUGADOR := Color("4be36a")  ## Verde para el jugador.
const COLOR_RESTOS := Color("ff9d3d")  ## Naranja para los restos de un gusano muerto.
const COLOR_SOLTADO := Color("ffd54a")  ## Comida que suelta el turbo al acelerar.
const ANCHO_BARRA_TURBO := 220.0  ## Ancho de la barra de turbo del HUD.
const SEGMENTOS_TURBO_LLENO := 20.0  ## Segmentos que llenan la barra de turbo.
const MAX_FILAS_CLASIFICACION := 5  ## Filas del marcador (los 5 más largos).

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
## Datos que se recuerdan entre partidas (los carga/gestiona `records.gd`).
var datos: Dictionary = {}
var _puntos := 0
var _record := 0  ## Longitud máxima alcanzada en la partida.
var _tiempo_partida := 0.0  ## Segundos de esta partida (para las estadísticas).
var _comida_partida := 0  ## Comida que ha tragado el jugador en esta partida.
var _bots_comidos := 0  ## Bots que ha matado el jugador en esta partida.
var _nuevo_record := false  ## ¿Ha superado su mejor puntuación al morir?
var _temporizador_comida := 0.0
var _temporizador_powerup := 0.0
var _temporizador_clasificacion := 0.0
var _contador_bots := 0
var _generacion := 0  ## Sube al reiniciar, para que los bots viejos no reaparezcan.
## Filas del marcador (se crean una vez y se rellenan; ver `_preparar_clasificacion`).
var _filas_clasificacion: Array = []

@onready var contenedor_comida: Node2D = $ContenedorComida
@onready var contenedor_gusanos: Node2D = $Gusanos
@onready var camara: Camera2D = $Camara
@onready var etiqueta_puntos: Label = $HUD/ArribaIzquierda/Puntos
@onready var etiqueta_record: Label = $HUD/ArribaIzquierda/Record
@onready var etiqueta_piel: Label = $HUD/ArribaIzquierda/Piel
@onready var etiqueta_ayuda: Label = $HUD/Ayuda
@onready var etiqueta_efectos: Label = $HUD/Efectos
@onready var etiqueta_turbo: Label = $HUD/TurboTexto
@onready var turbo_relleno: ColorRect = $HUD/TurboFondo/Relleno
@onready var etiqueta_audio: Label = $HUD/Audio
@onready var etiqueta_fps: Label = $HUD/FPS
@onready var etiqueta_aviso: Label = $HUD/Aviso
@onready var filas_clasificacion: VBoxContainer = $HUD/ArribaDerecha/Clasificacion/Caja/Filas
@onready var pie_clasificacion: Label = $HUD/ArribaDerecha/Clasificacion/Caja/Pie
@onready var sonido: Sonido = $Sonido
@onready var pantalla_final: Control = $HUD/Final
@onready var etiqueta_final: Label = $HUD/Final/Centro/Panel/Caja/Titulo
@onready var etiqueta_estadisticas: Label = $HUD/Final/Centro/Panel/Caja/Estadisticas
@onready var etiqueta_mejores: Label = $HUD/Final/Centro/Panel/Caja/Mejores
@onready var campo_apodo: LineEdit = $HUD/Final/Centro/Panel/Caja/FilaApodo/Apodo
@onready var boton_reintentar: Button = $HUD/Final/Centro/Panel/Caja/Botones/Reintentar
@onready var boton_menu_final: Button = $HUD/Final/Centro/Panel/Caja/Botones/Menu
@onready var boton_salir_final: Button = $HUD/Final/Centro/Panel/Caja/Botones/Salir
@onready var pausa: Pausa = $HUD/Pausa


func _ready() -> void:
	# 1) Lo que se recuerda: récord, estadísticas, piel y apodo.
	datos = Records.cargar()
	if str(datos.get("nombre", "")) == "":
		datos["nombre"] = Records.nombre_sistema()
		Records.guardar(datos)
	campo_apodo.text_submitted.connect(_on_apodo_escrito)
	campo_apodo.focus_exited.connect(_guardar_apodo)

	# 2) Interfaz montada por código: estilo, filas del marcador y botones.
	_estilizar_hud()
	_preparar_clasificacion()
	_conectar_interfaz()
	_mostrar_fps(bool(Ajustes.cargar().get("mostrar_fps", false)))

	_asegurar_accion_turbo()
	_crear_jugador()
	for i in bots_iniciales:
		_crear_bot()
	for i in comida_inicial:
		_aparecer_comida()
	if powerups_activos and powerup_al_empezar:
		_aparecer_powerup()
	sonido.tocar("nueva_partida", jugador.global_position if jugador != null else Vector2.ZERO)
	_actualizar_hud()
	_actualizar_clasificacion()
	_actualizar_audio()
	_actualizar_piel_hud()
	_mostrar_ayuda()


func _process(delta: float) -> void:
	if is_instance_valid(jugador):
		_tiempo_partida += delta  # Estadísticas de tiempo jugado.
	_seguir_jugador()
	_generar_comida(delta)
	_generar_powerups(delta)
	_actualizar_turbo_jugador()
	_actualizar_hud()
	_temporizador_clasificacion -= delta
	if _temporizador_clasificacion <= 0.0:
		_temporizador_clasificacion = intervalo_clasificacion
		_actualizar_clasificacion()
	if etiqueta_fps.visible:
		etiqueta_fps.text = "%d FPS" % Engine.get_frames_per_second()


func _input(evento: InputEvent) -> void:
	# Red de seguridad: si el mundo no ha terminado de montarse (o alguien edita la
	# escena y quita el HUD), no inundamos la consola con errores por cada tecla.
	if pantalla_final == null:
		return
	# Si estás escribiendo tu nombre, las teclas son para el campo (y un clic
	# dentro de él no reinicia la partida).
	if _clic_sobre_el_apodo(evento) or (campo_apodo != null and campo_apodo.has_focus()):
		return
	# Atajos de estilo y audio: M, N, P y O.
	if _atajo_de_estilo(evento):
		return
	# ESC: menú de pausa (o volver al menú principal desde la pantalla de muerte).
	if evento.is_action_pressed("ui_cancel"):
		_alternar_pausa()
		return
	# Reinicio: ESPACIO/ENTER cuando la partida ha terminado.
	if pantalla_final.visible and evento.is_action_pressed("ui_accept"):
		_reiniciar_partida()


## ¿El evento es un clic dentro del campo del apodo? (entonces no es un reinicio)
func _clic_sobre_el_apodo(evento: InputEvent) -> bool:
	var clic := evento as InputEventMouseButton
	if clic == null or campo_apodo == null or not campo_apodo.visible:
		return false
	return clic.pressed and campo_apodo.get_global_rect().has_point(clic.position)


## Teclas de estilo y audio, leídas aquí para no tocar el mapa de entrada del
## proyecto (project.godot):
##   M = silencio · N = música normal/bajita/apagada · P = paleta · O = patrón.
## Devuelve true si la tecla era una de estas (y ya se ha hecho su trabajo).
func _atajo_de_estilo(evento: InputEvent) -> bool:
	var tecla := evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return false
	match tecla.physical_keycode:
		KEY_M:
			sonido.alternar_silencio()
			_actualizar_audio()
		KEY_N:
			sonido.alternar_musica()
			_actualizar_audio()
		KEY_P:
			_siguiente_paleta()
		KEY_O:
			_siguiente_patron()
		_:
			return false
	return true


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
	gusano.semilla_piel = randi()
	# Piel elegida (se recuerda entre partidas; ver teclas P y O).
	gusano.aplicar_piel(
		Pieles.colores_paleta(int(datos.get("paleta", Pieles.Paleta.CLASICO))),
		int(datos.get("patron", Pieles.Patron.LISO))
	)
	gusano.sonido = sonido
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
	# Los bots también llevan piel (colores al azar + un patrón cualquiera), así
	# el mundo se ve variado sin que ellos cuenten logros.
	bot.colores_cuerpo = Pieles.colores_de_bot(randf())
	bot.color = bot.colores_cuerpo[0]
	bot.patron_cuerpo = Pieles.patron_aleatorio()
	bot.semilla_piel = randi()
	bot.segmentos_iniciales = randi_range(6, 14)
	bot.distancia_vision = randf_range(320.0, 520.0)
	bot.distancia_maxima_al_jugador = randf_range(900.0, 1400.0)
	# Algunos bots son "valientes" y usan el turbo para escapar.
	bot.probabilidad_turbo = randf_range(0.0, 0.5)
	bot.nombre = "Bot %d" % _contador_bots
	bot.sonido = sonido
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
## `asesino` es contra quién chocó y `gusano` llega "atado" con bind() desde donde
## conectamos la señal (el orden de los parámetros lo pone esa conexión).
func _on_gusano_murio(posiciones: PackedVector2Array, asesino: Gusano, gusano: Gusano) -> void:
	# call_deferred(): venimos de una señal de física, así que creamos los nodos
	# de comida al final del frame en lugar de dentro del paso de física.
	_esparcir_restos.call_deferred(posiciones)
	_record = maxi(_record, posiciones.size())

	# Estadísticas: si el muerto es un bot y lo ha provocado el jugador, cuenta.
	if gusano != jugador and asesino == jugador:
		_bots_comidos += 1

	if gusano == jugador:
		# Hay que apuntar sus estadísticas ANTES de perder la referencia.
		if is_instance_valid(jugador):
			_comida_partida = jugador.comidas_tragadas
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
	# Lo que se recuerda entre partidas: mejor marca y partidas jugadas.
	etiqueta_record.text = (
		"Récord de la partida: %d  ·  Mejor: %d puntos y %d de largo  ·  Partidas: %d"
	) % [
		_record,
		int(datos.get("record_puntos", 0)),
		int(datos.get("record_longitud", 0)),
		int(datos.get("partidas", 0)),
	]


## Marcador de la derecha (justo debajo del minimapa): los 5 gusanos más largos,
## con la longitud alineada a la derecha y tu fila en negrita y en verde.
func _actualizar_clasificacion() -> void:
	var gusanos: Array[Gusano] = []
	for nodo in contenedor_gusanos.get_children():
		var gusano := nodo as Gusano
		if gusano != null and not gusano.muerto:
			gusanos.append(gusano)
	gusanos.sort_custom(func(a: Gusano, b: Gusano) -> bool: return a.longitud() > b.longitud())

	for i in _filas_clasificacion.size():
		var fila: Dictionary = _filas_clasificacion[i]
		var mostrar := i < gusanos.size()
		(fila["fila"] as Control).visible = mostrar
		if not mostrar:
			continue
		var gusano := gusanos[i]
		var propio := gusano == jugador
		var nombre := "TÚ" if propio else (gusano.nombre if gusano.nombre != "" else "Bot")
		var etiqueta_nombre := fila["nombre"] as Label
		var etiqueta_marca := fila["marca"] as Label
		etiqueta_nombre.text = "%d. %s" % [i + 1, nombre]
		etiqueta_marca.text = "%d" % gusano.longitud()
		if propio:
			Estilo.estilizar_destacado(etiqueta_nombre, 15, Estilo.ACENTO)
			Estilo.estilizar_destacado(etiqueta_marca, 15, Estilo.ACENTO)
		else:
			Estilo.estilizar_texto(etiqueta_nombre, 15, Estilo.TEXTO_SUAVE)
			Estilo.estilizar_texto(etiqueta_marca, 15, Estilo.TEXTO)
	pie_clasificacion.text = "Mejor marca: %d pts · %d de largo" % [
		int(datos.get("record_puntos", 0)), int(datos.get("record_longitud", 0)),
	]


## Rótulo del HUD con el estado del audio (se refresca con M y con N).
func _actualizar_audio() -> void:
	etiqueta_audio.text = sonido.texto_estado()


## Rótulo del HUD con la piel actual y las teclas para cambiarla.
func _actualizar_piel_hud() -> void:
	var paleta := int(datos.get("paleta", 0))
	var patron := int(datos.get("patron", 0))
	etiqueta_piel.text = "Piel: %s · %s   (P y O cambian)" % [
		Pieles.nombre_paleta(paleta), Pieles.nombre_patron(patron),
	]


## Aviso grande que aparece y se desvanece (nuevo récord, piel desbloqueada...).
func _mostrar_aviso(texto: String) -> void:
	etiqueta_aviso.text = texto
	etiqueta_aviso.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(etiqueta_aviso, "modulate:a", 0.0, 1.5)


## Pasa a la siguiente paleta desbloqueada y la guarda.
func _siguiente_paleta() -> void:
	var actual := int(datos.get("paleta", 0))
	datos["paleta"] = Pieles.siguiente(Pieles.Tipo.PALETA, actual, datos)
	_aplicar_piel_elegida()


## Pasa al siguiente patrón desbloqueado y lo guarda.
func _siguiente_patron() -> void:
	var actual := int(datos.get("patron", 0))
	datos["patron"] = Pieles.siguiente(Pieles.Tipo.PATRON, actual, datos)
	_aplicar_piel_elegida()


## Aplica la piel elegida al jugador, avisa por el HUD y la guarda.
func _aplicar_piel_elegida() -> void:
	if is_instance_valid(jugador):
		jugador.aplicar_piel(
			Pieles.colores_paleta(int(datos.get("paleta", 0))),
			int(datos.get("patron", 0))
		)
	_actualizar_piel_hud()
	_mostrar_aviso("%s  ·  %s" % [
		Pieles.nombre_paleta(int(datos.get("paleta", 0))),
		Pieles.nombre_patron(int(datos.get("patron", 0))),
	])
	sonido.tocar("powerup", camara.global_position, 1.5, -6.0)
	Records.guardar(datos)


## Guarda el apodo escrito en la pantalla final (Enter o al salir del campo).
func _guardar_apodo() -> void:
	if campo_apodo == null:
		return
	var limpio := campo_apodo.text.strip_edges().substr(0, Records.LARGO_APODO)
	if limpio == "":
		limpio = Records.nombre_sistema()
	campo_apodo.text = limpio
	datos["nombre"] = limpio
	Records.guardar(datos)


func _on_apodo_escrito(_texto: String) -> void:
	_guardar_apodo()
	campo_apodo.release_focus()
	_mostrar_aviso("Apodo guardado: %s" % str(datos.get("nombre", "")))


func _mostrar_ayuda() -> void:
	etiqueta_ayuda.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(7.0)
	tween.tween_property(etiqueta_ayuda, "modulate:a", 0.0, 1.5)


## Guarda el resultado de la partida en el récord y avisa de los desbloqueos.
func _guardar_resultados() -> void:
	# Antes de tocar nada: qué había desbloqueado (para saber qué es nuevo).
	var paletas_antes := Pieles.desbloqueadas(Pieles.Tipo.PALETA, datos)
	var patrones_antes := Pieles.desbloqueadas(Pieles.Tipo.PATRON, datos)

	_nuevo_record = _puntos > int(datos.get("record_puntos", 0))
	datos["record_puntos"] = maxi(_puntos, int(datos.get("record_puntos", 0)))
	datos["record_longitud"] = maxi(_record, int(datos.get("record_longitud", 0)))
	datos["partidas"] = int(datos.get("partidas", 0)) + 1
	datos["comida"] = int(datos.get("comida", 0)) + _comida_partida
	datos["bots"] = int(datos.get("bots", 0)) + _bots_comidos
	datos["tiempo"] = float(datos.get("tiempo", 0.0)) + _tiempo_partida
	var mejores: Array = datos.get("mejores", []) as Array
	mejores = Records.agregar_mejor(mejores, {
		"puntos": _puntos,
		"longitud": _record,
		"fecha": Records.fecha_de_hoy(),
		"nombre": str(datos.get("nombre", "TÚ")),
	})
	datos["mejores"] = mejores
	Records.guardar(datos)
	_avisar_nuevos_desbloqueos(paletas_antes, patrones_antes)


## Compara los desbloqueos de antes y de después y avisa de lo nuevo.
func _avisar_nuevos_desbloqueos(
	antes_paletas: PackedInt32Array, antes_patrones: PackedInt32Array
) -> void:
	var avisos := PackedStringArray()
	for i in Pieles.cantidad_paletas():
		if not antes_paletas.has(i) and Pieles.desbloqueada(Pieles.Tipo.PALETA, i, datos):
			avisos.append("¡PALETA DESBLOQUEADA! %s" % Pieles.nombre_paleta(i))
	for i in Pieles.cantidad_patrones():
		if not antes_patrones.has(i) and Pieles.desbloqueada(Pieles.Tipo.PATRON, i, datos):
			avisos.append("¡PATRÓN DESBLOQUEADO! %s" % Pieles.nombre_patron(i))
	if avisos.is_empty():
		return
	_mostrar_aviso("  ·  ".join(avisos))
	sonido.tocar("nueva_partida", camara.global_position)


func _terminar_partida() -> void:
	_guardar_resultados()

	var apodo := str(datos.get("nombre", "TÚ"))
	etiqueta_final.text = "¡TE HAN COMIDO, %s!" % apodo.to_upper()
	var extra := "   ·   ¡NUEVO RÉCORD DE PUNTOS!" if _nuevo_record else ""
	etiqueta_estadisticas.text = (
		"Puntos: %d%s   ·   Longitud: %d   ·   Comida: %d   ·   Bots: %d   ·   Tiempo: %s\n"
		+ "Partidas jugadas: %d   ·   Récord: %d puntos y %d de largo"
	) % [
		_puntos,
		extra,
		_record,
		_comida_partida,
		_bots_comidos,
		Records.texto_tiempo(_tiempo_partida),
		int(datos.get("partidas", 0)),
		int(datos.get("record_puntos", 0)),
		int(datos.get("record_longitud", 0)),
	]
	etiqueta_mejores.text = Records.texto_mejores(datos.get("mejores", []) as Array, false)
	campo_apodo.text = apodo
	pantalla_final.visible = true
	boton_reintentar.grab_focus()
	# Golpe grave de cierre, además del sonido de muerte del gusano. Suena donde
	# está la cámara (el gusano ya no existe, pero la cámara sigue ahí).
	sonido.tocar("fin", camara.global_position)


func _reiniciar_partida() -> void:
	# Si venimos de la pausa (o del panel de fin de partida), dejamos todo listo.
	get_tree().paused = false
	if pausa != null:
		pausa.cerrar()
	_generacion += 1
	pantalla_final.visible = false
	campo_apodo.release_focus()
	_puntos = 0
	_record = 0
	_tiempo_partida = 0.0
	_comida_partida = 0
	_bots_comidos = 0
	_nuevo_record = false
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



# ---------------------------------------------------------------------------
# Interfaz: estilo, marcador, pausa y menú
# ---------------------------------------------------------------------------

## Aplica el estilo del juego a las piezas del HUD que no traen tema puesto en
## `Main.tscn` (paneles, el campo del apodo y los botones del final de partida).
func _estilizar_hud() -> void:
	Estilo.estilizar_panel($HUD/ArribaDerecha/Clasificacion)
	Estilo.estilizar_panel($HUD/Final/Centro/Panel)
	Estilo.estilizar_campo(campo_apodo)
	Estilo.estilizar_boton(boton_reintentar, true)
	Estilo.estilizar_boton(boton_menu_final)
	Estilo.estilizar_boton(boton_salir_final, true, Estilo.PELIGRO)
	Estilo.estilizar_texto(etiqueta_fps, Estilo.PEQUENO, Estilo.TEXTO_SUAVE)


## Crea las cinco filas del marcador una sola vez (luego solo se rellenan): así el
## marcador no crea ni destruye nodos cuatro veces por segundo.
func _preparar_clasificacion() -> void:
	_filas_clasificacion.clear()
	for i in MAX_FILAS_CLASIFICACION:
		var fila := HBoxContainer.new()
		fila.name = "Fila%d" % (i + 1)
		fila.add_theme_constant_override("separation", 6)
		var nombre := Label.new()
		nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nombre.clip_text = true
		fila.add_child(nombre)
		var marca := Label.new()
		marca.custom_minimum_size = Vector2(38, 0)
		marca.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fila.add_child(marca)
		filas_clasificacion.add_child(fila)
		_filas_clasificacion.append({"fila": fila, "nombre": nombre, "marca": marca})


## Conecta los botones del final de partida y los del menú de pausa (por señales:
## `pausa.gd` no sabe nada de la partida, solo avisa de lo que pulsa el jugador).
func _conectar_interfaz() -> void:
	boton_reintentar.pressed.connect(_reiniciar_partida)
	boton_menu_final.pressed.connect(_ir_al_menu)
	boton_salir_final.pressed.connect(Gestor.salir)
	pausa.configurar(sonido)
	pausa.continuar.connect(_reanudar)
	pausa.reiniciar.connect(_reiniciar_partida)
	pausa.al_menu.connect(_ir_al_menu)
	pausa.salir_juego.connect(Gestor.salir)


## ESC: abre o cierra la pausa. El árbol se detiene con `get_tree().paused`, y el
## menú de pausa sigue funcionando porque su nodo raíz lleva `process_mode = ALWAYS`.
func _alternar_pausa() -> void:
	if pantalla_final.visible:
		_ir_al_menu()
		return
	if get_tree().paused:
		_reanudar()
		return
	get_tree().paused = true
	pausa.abrir()
	sonido.tocar("clic", camara.global_position)


func _reanudar() -> void:
	if pausa != null:
		pausa.cerrar()
	get_tree().paused = false


## Vuelve al menú principal (con fundido) desde la pausa o desde el final.
func _ir_al_menu() -> void:
	get_tree().paused = false
	if pausa != null:
		pausa.cerrar()
	Gestor.ir_al_menu(self)


## Enseña u oculta el contador de FPS (ajuste "mostrar_fps" de Opciones).
func _mostrar_fps(mostrar: bool) -> void:
	if etiqueta_fps != null:
		etiqueta_fps.visible = mostrar
