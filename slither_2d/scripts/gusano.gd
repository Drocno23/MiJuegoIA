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
##
## MECÁNICAS IMPLEMENTADAS
##   * Movimiento suave hacia el objetivo (ratón o IA).
##   * Crecimiento al comer (puntos + segmento al final de la cola).
##   * Muerte al chocar la cabeza con el cuerpo de OTRO gusano.
##   * Restos: al morir emite las posiciones exactas de sus segmentos.
##   * TURBO: corre más a cambio de ir soltando segmentos por el camino.
##   * COLA AFILADA: los últimos segmentos son progresivamente más finos.
##   * POWER-UPS: imán, escudo, turbo gratis y fantasma (ver `comida.gd`).

## Emitida al morir. Lleva las posiciones exactas de todos los segmentos para que
## el mundo (main.gd) convierta el cuerpo en comida.
signal murio(posiciones_restos: PackedVector2Array, asesino: Gusano)
## Emitida al comer: puntos acumulados y longitud total (cabeza + segmentos).
signal puntuacion_cambiada(puntos: int, longitud: int)
## Emitida cuando el turbo gasta un segmento. El mundo lo convierte en comida
## (va en diferido, porque se emite durante el paso de física).
signal segmento_soltado(posicion: Vector2)

const GRUPO := "gusano"  ## Grupo con todos los gusanos (lo usa el minimapa).
const GRUPO_JUGADOR := "jugador"  ## Solo el gusano del jugador (lo usan los bots).
const PASO_RUTA := 4.0  ## Distancia en píxeles entre puntos guardados del camino.
const MAX_PASOS_FRAME := 8  ## Límite de seguridad al muestrear el camino.

@export_group("Movimiento")
@export var velocidad: float = 170.0  ## Píxeles por segundo (constante, como en slither.io).
@export var velocidad_giro: float = 6.0  ## Radianes por segundo: cuánto puede girar la cabeza.

@export_group("Turbo")
@export var velocidad_turbo: float = 1.7  ## Multiplicador de velocidad al usar el turbo.
@export var intervalo_costo_turbo: float = 0.35  ## Cada cuántos segundos suelta un segmento.
@export var segmentos_minimos_turbo: int = 6  ## Longitud mínima para poder usarlo.

@export_group("Cuerpo")
@export var separacion: float = 15.0  ## Distancia fija entre segmentos (y entre cabeza y 1º).
@export var segmentos_iniciales: int = 8
@export var segmentos_maximos: int = 80  ## Tope para no reventar el rendimiento.
@export var escena_segmento: PackedScene = preload("res://escenas/Segmento.tscn")
## AFILADO OPCIONAL de la cola: los últimos N segmentos van adelgazando.
## Con 0 (por defecto) todo el cuerpo tiene UN SOLO GROSOR, igual que la cabeza.
## Si algún día lo quieres afilado, ponlo en 8 y ajusta `grosor_cola`.
@export var cola_afilada_segmentos: int = 0
@export var grosor_cola: float = 0.55  ## Radio de la punta si se afila (factor del de la cabeza).

@export_group("Power-ups")
@export var radio_iman: float = 260.0  ## Alcance del imán (píxeles).
@export var velocidad_iman: float = 420.0  ## Píxeles por segundo con que atrae la comida.

@export_group("Apariencia")
@export var radio: float = 12.0
@export var color: Color = Color("35c9ff")
## Dibuja los círculos con el borde suave (independiente del MSAA del renderizador).
## Ponlo en false para volver al draw_circle() clásico.
@export var bordes_suaves: bool = true
@export var nombre: String = ""  ## Nombre en la clasificación ("TÚ", "Bot 3"...).
## PIEL: colores del cuerpo (el primero es el de la cabeza) y patrón que decide
## qué color le toca a cada segmento. Se configuran con `aplicar_piel()` y el
## jugador los elige con las teclas P (paleta) y O (patrón); ver `pieles.gd`.
@export var colores_cuerpo := PackedColorArray([Color("4be36a"), Color("2f9e4d"), Color("a8fffe")])
@export var patron_cuerpo: int = Pieles.Patron.LISO  ## Usa las constantes `Pieles.Patron.*`.

@export_group("Reglas")
## Segundos al nacer en los que no puede morir (evita muertes absurdas al aparecer).
@export var inmunidad_inicial: float = 2.0

var puntuacion: int = 0
var muerto: bool = false
var direccion: Vector2 = Vector2.RIGHT  ## Dirección actual de avance de la cabeza.
## Punto al que apunta el gusano en el MÓVIL. Lo pone `main.gd` con la posición del
## dedo (en coordenadas del mundo); con `usa_objetivo_tactil = false` se ignora y el
## gusano vuelve a seguir el ratón, así que en el PC nada cambia.
var objetivo_tactil: Vector2 = Vector2.ZERO
var usa_objetivo_tactil := false
## Nodo de audio del mundo (lo pone `main.gd`; si no está, se busca en el grupo).
var sonido: Sonido = null
## Semilla de las "motas" del patrón: cada gusano las tiene en sitios distintos.
var semilla_piel: int = 0
var comidas_tragadas: int = 0  ## Comida normal tragada (sin power-ups): para las estadísticas.

var _segmentos: Array[CuerpoSegmento] = []  ## Índice 0 = primer segmento (pegado a la cabeza).
var _ruta := PackedVector2Array()  ## Camino recorrido. Índice 0 = punto más reciente.
var _tiempo_inmunidad := 0.0

# --- estado del turbo y de los power-ups ---
var _turbo_pedido := false
var _turbo_activo := false
var _temporizador_costo_turbo := 0.0
var _tiempo_turbo_gratis := 0.0
var _tiempo_iman := 0.0
var _tiempo_escudo := 0.0
var _tiempo_fantasma := 0.0

var _zumbido: AudioStreamPlayer2D = null  ## Bucle del turbo: suena pegado al gusano.
var _racha_comida := 0  ## Comidas seguidas: el sonido sube en escalera.
var _tiempo_ultima_comida := -99.0

@onready var cabeza: Area2D = $Cabeza
@onready var contenedor_segmentos: Node2D = $Segmentos
@onready var _forma_cabeza: CollisionShape2D = $Cabeza/CollisionShape2D


func _ready() -> void:
	add_to_group(GRUPO)
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

	# Audio: el mundo nos deja su nodo de sonido (si no, lo buscamos por el grupo).
	if sonido == null:
		sonido = get_tree().get_first_node_in_group(Sonido.GRUPO) as Sonido
	# Reproductor propio para el zumbido del turbo: así suena pegado a nosotros.
	_zumbido = AudioStreamPlayer2D.new()
	_zumbido.name = "Zumbido"
	_zumbido.max_distance = 900.0
	_zumbido.attenuation = 1.4
	add_child(_zumbido)


func _physics_process(delta: float) -> void:
	if muerto:
		return
	if _tiempo_inmunidad > 0.0:
		_tiempo_inmunidad -= delta

	_actualizar_efectos(delta)
	_actualizar_turbo(delta)
	_girar(delta)
	global_position += direccion * velocidad_actual() * delta

	_actualizar_ruta()
	_colocar_segmentos()
	_atraer_comida(delta)
	queue_redraw()  # Para que los ojos giren con la cabeza.


# ---------------------------------------------------------------------------
# 1) MOVIMIENTO: la cabeza gira suavemente hacia el objetivo
# ---------------------------------------------------------------------------

## ¿Hacia dónde quiere ir el gusano? Por defecto, hacia el ratón (lo usa el
## jugador). En el móvil, hacia el dedo (`objetivo_tactil`). Los bots de
## `gusano_cpu.gd` sobreescriben esta función.
func _direccion_deseada() -> Vector2:
	if usa_objetivo_tactil:
		return global_position.direction_to(objetivo_tactil)
	return global_position.direction_to(get_global_mouse_position())


func _girar(delta: float) -> void:
	var deseada := _direccion_deseada()
	if deseada.length_squared() < 0.0001:
		return  # Sin objetivo: sigue recto.
	# angle_difference() devuelve el giro más corto entre dos ángulos (Godot 4.2+).
	var diferencia := angle_difference(direccion.angle(), deseada.angle())
	var paso_maximo := velocidad_giro * delta
	direccion = direccion.rotated(clampf(diferencia, -paso_maximo, paso_maximo))


## Velocidad real en este instante (tiene en cuenta el turbo).
func velocidad_actual() -> float:
	return velocidad * (velocidad_turbo if _turbo_activo else 1.0)


# ---------------------------------------------------------------------------
# 2) TURBO: correr más a cambio de soltar segmentos
# ---------------------------------------------------------------------------

## El jugador (o la IA) pide activar/desactivar el turbo. Se aplica en el
## siguiente paso de física, y solo si el gusano tiene longitud suficiente.
func activar_turbo(activar: bool) -> void:
	_turbo_pedido = activar


func esta_en_turbo() -> bool:
	return _turbo_activo


## Fracción de "combustible" de turbo que le queda (0..1), para la barra del HUD.
## Cuenta cuántos segmentos puede gastar antes de llegar al mínimo.
func fraccion_turbo() -> float:
	var disponible := float(longitud() - segmentos_minimos_turbo)
	return clampf(disponible / 20.0, 0.0, 1.0)


func _actualizar_turbo(delta: float) -> void:
	var tiene_gratis := _tiempo_turbo_gratis > 0.0
	var estaba_activo := _turbo_activo
	_turbo_activo = (_turbo_pedido or tiene_gratis) and longitud() > segmentos_minimos_turbo
	if _turbo_activo != estaba_activo:
		_actualizar_zumbido()  # Encender/apagar el bucle del turbo.
	if not _turbo_activo:
		_temporizador_costo_turbo = 0.0
		return
	if tiene_gratis:
		return  # Durante el turbo gratis no se pierde longitud.
	_temporizador_costo_turbo += delta
	if _temporizador_costo_turbo >= intervalo_costo_turbo:
		_temporizador_costo_turbo = 0.0
		_quitar_ultimo_segmento()


## Enciende o apaga el zumbido del turbo (un bucle generado por código).
func _actualizar_zumbido() -> void:
	if _zumbido == null:
		return
	if not _turbo_activo:
		_zumbido.stop()
		return
	if sonido != null:
		_zumbido.stream = sonido.flujo("turbo_bucle")
		_zumbido.volume_db = sonido.volumen_efectos_db() - 6.0  # De fondo, sin molestar.
	if _zumbido.stream != null:
		_zumbido.play()


## Suelta el último segmento (lo convierte en comida a través de la señal).
func _quitar_ultimo_segmento() -> void:
	if _segmentos.size() <= segmentos_minimos_turbo - 1:
		return
	var ultimo: CuerpoSegmento = _segmentos.pop_back()
	segmento_soltado.emit(ultimo.global_position)
	ultimo.queue_free()
	_actualizar_cuerpo()


# ---------------------------------------------------------------------------
# 3) CUERPO: cadena de segmentos sobre el camino de la cabeza
# ---------------------------------------------------------------------------

## Crea la ruta inicial recta detrás de la cabeza (para que el gusano
## no aparezca con todos los segmentos amontonados en el mismo punto).
func _inicializar_ruta() -> void:
	_ruta.clear()
	var puntos := int(((segmentos_iniciales + 2) * separacion) / PASO_RUTA)
	for i in puntos:
		_ruta.append(global_position - direccion * i * PASO_RUTA)


## Guarda el camino que va dejando la cabeza (un punto cada PASO_RUTA píxeles).
## Nota: un PackedVector2Array NO tiene push_front() (eso es del Array normal);
## para poner el punto más reciente delante se usa insert(0, valor).
func _actualizar_ruta() -> void:
	if _ruta.is_empty():
		_ruta.insert(0, global_position)
		return
	var pasos := 0
	while _ruta[0].distance_to(global_position) >= PASO_RUTA and pasos < MAX_PASOS_FRAME:
		_ruta.insert(0, _ruta[0].move_toward(global_position, PASO_RUTA))
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
	segmento.radio = radio  # Un solo grosor: el cuerpo mide lo mismo que la cabeza.
	segmento.color = _color_de_segmento(_segmentos.size())  # Color según la piel.
	segmento.bordes_suaves = bordes_suaves  # El cuerpo hereda el ajuste de la cabeza.
	segmento.dueno = self
	segmento.animar_aparicion = animar
	contenedor_segmentos.add_child(segmento)
	# Después de add_child() ya tiene padre, así que global_position es correcto.
	segmento.global_position = _punto_detras((float(_segmentos.size()) + 1.0) * separacion)
	_segmentos.append(segmento)
	_actualizar_cuerpo()


## Radio que le toca a cada segmento. Por defecto el cuerpo entero tiene el
## MISMO grosor que la cabeza (0 = uniforme); si `cola_afilada_segmentos` es
## mayor que 0, los últimos N van adelgazando hasta `grosor_cola`.
func _radio_de_segmento(indice: int) -> float:
	if cola_afilada_segmentos <= 0:
		return radio
	var inicio_afinado := _segmentos.size() - cola_afilada_segmentos
	if indice < inicio_afinado:
		return radio
	var t := float(indice - inicio_afinado + 1) / float(cola_afilada_segmentos)
	return radio * lerpf(1.0, grosor_cola, clampf(t, 0.0, 1.0))


## Reaplica grosor y color a todos los segmentos. Se llama solo cuando cambia el
## número de segmentos o la piel (no en cada frame: cambiar el radio o el color
## obliga a recalcular la forma de colisión y a repintar).
func _actualizar_cuerpo() -> void:
	for i in _segmentos.size():
		_segmentos[i].radio = _radio_de_segmento(i)
		_segmentos[i].color = _color_de_segmento(i)


## Color que le toca a un segmento con la piel actual (paleta + patrón).
func _color_de_segmento(indice: int) -> Color:
	return Pieles.color_de_segmento(
		colores_cuerpo, patron_cuerpo, indice, _segmentos.size(), semilla_piel
	)


## Aplica una piel al momento (lo usan las teclas P/O del mundo). El primer color
## es el de la cabeza y el que se ve en el minimapa.
func aplicar_piel(colores: PackedColorArray, patron: int) -> void:
	if not colores.is_empty():
		colores_cuerpo = colores
		color = colores_cuerpo[0]
	patron_cuerpo = clampi(patron, 0, Pieles.cantidad_patrones() - 1)
	_actualizar_cuerpo()
	queue_redraw()


## Longitud total del gusano (la cabeza cuenta como 1).
func longitud() -> int:
	return _segmentos.size() + 1


# ---------------------------------------------------------------------------
# 4) CRECIMIENTO: comer añade puntos y un segmento nuevo al final de la cola
# ---------------------------------------------------------------------------

## Añade segmentos al final de la cola. Lo llama `_comer()`.
func crecer(cantidad: int = 1) -> void:
	for i in cantidad:
		if _segmentos.size() >= segmentos_maximos:
			return
		_agregar_segmento()


## Crecimiento SEGURO desde un callback de física (por ejemplo la señal
## `area_entered` de la cabeza al comer). Crear nodos con formas de colisión
## mientras el servidor de física está resolviendo consultas da el error
## "Can't change this state while flushing queries", así que el segmento se
## crea al final del frame con call_deferred(). El retardo es imperceptible.
func crecer_diferido(cantidad: int = 1) -> void:
	crecer.call_deferred(cantidad)


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
	if Comida.es_powerup(comida.tipo):
		aplicar_powerup(comida.tipo, comida.duracion)  # No engorda: da un efecto.
		if sonido != null:
			sonido.tocar("powerup", global_position)
	else:
		comidas_tragadas += 1  # Estadísticas: comida normal (y restos).
		crecer_diferido(comida.segmentos)  # Diferido: estamos dentro de la física.
		if sonido != null:
			sonido.tocar("comer", global_position, _tono_comida())
	puntuacion_cambiada.emit(puntuacion, longitud())
	comida.consumir()


## Tono del sonido de comer: sube en escalera si comes varias seguidas (menos de
## 1,2 s entre una y otra), así comer en racha suena a "ñam-ñam-ñam" y no a bucle.
func _tono_comida() -> float:
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora - _tiempo_ultima_comida <= 1.2:
		_racha_comida = mini(_racha_comida + 1, 6)
	else:
		_racha_comida = 0
	_tiempo_ultima_comida = ahora
	return pow(2.0, float(_racha_comida) / 12.0)  # Medio tono por comida (máx. 1,41x)


# ---------------------------------------------------------------------------
# 5) POWER-UPS: efectos temporales
# ---------------------------------------------------------------------------

## Activa el efecto de un power-up durante `duracion` segundos (se acumula:
## si ya estaba activo, se queda con el tiempo mayor).
func aplicar_powerup(tipo_poder: int, duracion: float) -> void:
	match tipo_poder:
		Comida.Tipo.IMAN:
			_tiempo_iman = maxf(_tiempo_iman, duracion)
		Comida.Tipo.ESCUDO:
			_tiempo_escudo = maxf(_tiempo_escudo, duracion)
		Comida.Tipo.TURBO:
			_tiempo_turbo_gratis = maxf(_tiempo_turbo_gratis, duracion)
		Comida.Tipo.FANTASMA:
			_tiempo_fantasma = maxf(_tiempo_fantasma, duracion)


## ¿Puede ignorar ahora mismo un choque contra otro cuerpo?
func es_invulnerable() -> bool:
	return _tiempo_inmunidad > 0.0 or _tiempo_escudo > 0.0 or _tiempo_fantasma > 0.0


## Texto con los efectos activos, para el HUD ("IMÁN 4.2s   ESCUDO 2.0s").
func texto_efectos() -> String:
	var partes := PackedStringArray()
	if _tiempo_turbo_gratis > 0.0:
		partes.append("TURBO %.1fs" % _tiempo_turbo_gratis)
	if _tiempo_escudo > 0.0:
		partes.append("ESCUDO %.1fs" % _tiempo_escudo)
	if _tiempo_fantasma > 0.0:
		partes.append("FANTASMA %.1fs" % _tiempo_fantasma)
	if _tiempo_iman > 0.0:
		partes.append("IMÁN %.1fs" % _tiempo_iman)
	return "   ".join(partes)


func _actualizar_efectos(delta: float) -> void:
	_tiempo_iman = maxf(_tiempo_iman - delta, 0.0)
	_tiempo_escudo = maxf(_tiempo_escudo - delta, 0.0)
	_tiempo_turbo_gratis = maxf(_tiempo_turbo_gratis - delta, 0.0)
	_tiempo_fantasma = maxf(_tiempo_fantasma - delta, 0.0)
	# El fantasma vuelve translúcido todo el cuerpo (modulate afecta a los hijos).
	var objetivo := 0.45 if _tiempo_fantasma > 0.0 else 1.0
	if not is_equal_approx(modulate.a, objetivo):
		modulate.a = objetivo


## El imán arrastra la comida que tiene cerca hacia la cabeza.
func _atraer_comida(delta: float) -> void:
	if _tiempo_iman <= 0.0:
		return
	for nodo in get_tree().get_nodes_in_group(Comida.GRUPO):
		var comida := nodo as Comida
		if comida == null:
			continue
		if global_position.distance_to(comida.global_position) < radio_iman:
			comida.global_position = comida.global_position.move_toward(
				global_position, velocidad_iman * delta
			)


# ---------------------------------------------------------------------------
# 6) CHOQUES: la cabeza muere si toca el cuerpo de OTRO gusano
# ---------------------------------------------------------------------------

## Regla de muerte: la cabeza muere si toca el cuerpo de OTRO gusano.
## (Tocar el propio cuerpo está permitido, como en slither.io).
func _chocar_con_cuerpo(segmento: CuerpoSegmento) -> void:
	if es_invulnerable():
		return
	var otro := segmento.dueno
	if otro == self or not is_instance_valid(otro):
		return
	morir(otro as Gusano)  # `otro` es quien te ha cortado el paso.


# ---------------------------------------------------------------------------
# 7) MUERTE: el cuerpo se convierte en comida
# ---------------------------------------------------------------------------

## Muere: avisa al mundo con las posiciones exactas de sus segmentos y desaparece.
## `asesino` es el gusano contra cuyo cuerpo ha chocado (puede ser null).
func morir(asesino: Gusano = null) -> void:
	if muerto:
		return
	muerto = true
	set_physics_process(false)

	# a) Sonido: el del jugador es más grave y fuerte; el de un bot, más agudo y
	#    flojo (y se atenúa con la distancia, porque suena donde murió).
	if sonido != null:
		var es_jugador := is_in_group(GRUPO_JUGADOR)
		sonido.tocar(
			"muerte", global_position, 1.0 if es_jugador else 1.5,
			0.0 if es_jugador else -8.0
		)

	# b) Posiciones exactas: la cabeza primero y después cada segmento.
	var posiciones := PackedVector2Array()
	posiciones.append(global_position)
	for segmento in _segmentos:
		posiciones.append(segmento.global_position)

	# c) Desactivamos la colisión. set_deferred() porque estamos dentro de una
	#    señal de física y no se puede tocar el área en ese mismo instante.
	cabeza.set_deferred("monitoring", false)
	for segmento in _segmentos:
		segmento.set_deferred("monitorable", false)

	# d) Avisamos al mundo: main.gd crea una Comida en cada posición y apunta
	#    quién la ha provocado (para las estadísticas de "bots comidos").
	murio.emit(posiciones, asesino)

	# e) Nos ocultamos y liberamos.
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
	# Círculos con borde suave: se dibujan como textura en vez de con
	# draw_circle() porque el renderizador GL Compatibility no soporta MSAA 2D
	# (ver las explicaciones en scripts/dibujo.gd).
	Dibujo.disco(self, Vector2.ZERO, radio, color.darkened(0.45), bordes_suaves)  # borde
	Dibujo.disco(self, Vector2.ZERO, radio * 0.88, color, bordes_suaves)  # relleno
	# Ojos: miran siempre hacia donde va la cabeza.
	var hacia_adelante := direccion * radio * 0.45
	var hacia_lado := direccion.orthogonal() * radio * 0.4
	# La lista va tipada (PackedFloat32Array) y `ojo` con tipo explícito: si no,
	# GDScript no puede deducir el tipo y da error de parseo.
	for lado in PackedFloat32Array([-1.0, 1.0]):
		var ojo: Vector2 = hacia_adelante + hacia_lado * lado
		Dibujo.disco(self, ojo, radio * 0.27, Color.WHITE, bordes_suaves)
		Dibujo.disco(self, ojo + direccion * radio * 0.1, radio * 0.14, Color.BLACK, bordes_suaves)
	# Aro del escudo: se ve de un vistazo que eres invulnerable.
	if _tiempo_escudo > 0.0:
		draw_arc(Vector2.ZERO, radio * 1.55, 0.0, TAU, 32, Color("b8ffcc"), 2.5, true)
