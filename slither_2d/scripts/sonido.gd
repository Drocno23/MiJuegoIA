class_name Sonido
extends Node2D
## Audio del juego: **todos los sonidos se generan por código** (no hay ni un archivo).
##
## NODO AL QUE SE ADJUNTA: un **Node2D** llamado "Sonido", hijo de la raíz de
## `escenas/Main.tscn`. No necesita nada más en la escena: este script crea por
## código su reproductor de música y su pool de voces (`AudioStreamPlayer2D`).
##
## ¿Cómo se generan? Se rellena un `PackedByteArray` con muestras PCM (16 bits,
## 22050 Hz, mono) y se envuelve en un `AudioStreamWAV` (en Godot 4 ese es el
## nombre; `AudioStreamSample` era de Godot 3). Cada efecto es un barrido de
## frecuencia con una envolvente percusiva (ataque muy corto para no dar "clic";
## caída hasta cero para no chasquear al terminar). La música es un bucle
## chiptune de 8 s con melodía, bajo y bombo, generado nota a nota.
##
## Reproducción:
##   * los efectos suenan con **paneo y distancia** (`AudioStreamPlayer2D`): una
##     muerte a tu derecha suena a la derecha, y lo que pasa lejos se oye flojo;
##   * el **turbo** enciende un bucle ("zumbido") que es un reproductor hijo del
##     propio gusano, así suena pegado a él mientras corre;
##   * hay un pool de voces para que, por ejemplo, comer y coger un power-up a la
##     vez no se corten entre ellos.
##
## Controles (los lee `main.gd`, se pueden pulsar en cualquier momento):
##   * **M** -> silencio total (se recuerda entre partidas).
##   * **N** -> música: normal -> bajita -> apagada -> normal (también se recuerda).
##
## La preferencia se guarda en `user://ajustes.cfg` (fuera del repositorio: no es
## un archivo del juego, es de tu perfil de usuario de Godot).

## Formas de onda disponibles.
enum Onda { SENO, CUADRADA, TRIANGULAR }

## Niveles de música (para la tecla N).
const MUSICA_NORMAL := 2
const MUSICA_BAJITA := 1
const MUSICA_APAGADA := 0

## Grupo con el nodo de audio del mundo (los gusanos lo buscan por aquí).
const GRUPO := "audio"

## Parámetros de la música: 16 tiempos a 128 BPM (60/128 * 16 = 7,5 s de bucle).
const MUSICA_BPM := 128.0
const MUSICA_TIEMPOS := 16

const FRECUENCIA_MEZCLA := 22050  ## Muestras por segundo (calidad de sobra).
const VOCES := 6  ## Cuántos efectos pueden sonar a la vez sin cortarse.

## Índice del bus Master (el único que existe por defecto). Silenciar el juego es
## silenciar ese bus: afecta a efectos, música y a los zumbidos de los gusanos.
const CANAL_MAESTRO := 0

@export var volumen_efectos: float = 0.0  ## dB que se suman a todos los efectos.
@export var volumen_musica: float = -10.0  ## dB de la música en nivel normal.
@export var volumen_musica_bajita: float = -20.0  ## dB en nivel "bajita".
@export var distancia_audible: float = 900.0  ## Alcance de los efectos 2D (píxeles).

## Cuántos efectos se han disparado (lo usa la prueba automática).
var efectos_tocados := 0

var _cache: Dictionary = {}  ## nombre -> AudioStreamWAV (cada efecto se genera una vez).
var _voces: Array[AudioStreamPlayer2D] = []
var _musica: AudioStreamPlayer = null
var _silencio := false
var _nivel_musica := MUSICA_NORMAL


# ---------------------------------------------------------------------------
# Generadores (estáticos: se pueden generar y probar sin instanciar nada)
# ---------------------------------------------------------------------------

## Efecto corto: barrido de frecuencia de `inicio_hz` a `fin_hz` durante
## `duracion` segundos. `ruido` añade algo de ruido blanco que se apaga (golpes).
static func generar_barrido(
	inicio_hz: float,
	fin_hz: float,
	duracion: float,
	onda: int = Onda.SENO,
	amplitud: float = 0.5,
	ruido: float = 0.0
) -> AudioStreamWAV:
	var muestras := int(FRECUENCIA_MEZCLA * duracion)
	var flujo := _flujo_vacio(muestras)
	var fase := 0.0
	# Semilla fija: el ruido suena exactamente igual en cada partida.
	var azar := RandomNumberGenerator.new()
	azar.seed = 12345
	for i in muestras:
		var avance := float(i) / float(muestras)
		fase += TAU * lerpf(inicio_hz, fin_hz, avance) / FRECUENCIA_MEZCLA
		var valor := _onda(onda, fase) * amplitud
		if ruido > 0.0:
			valor += azar.randf_range(-1.0, 1.0) * ruido * (1.0 - avance)
		flujo[i] = valor * _envolvente(i, muestras, 1.5)
	return _a_flujo_wav(flujo)


## Varias notas seguidas (por ejemplo un arpegio), cada una con su envolvente.
static func generar_arpegio(
	frecuencias: PackedFloat32Array,
	duracion_nota: float,
	onda: int,
	amplitud: float
) -> AudioStreamWAV:
	var por_nota := int(FRECUENCIA_MEZCLA * duracion_nota)
	var flujo := _flujo_vacio(por_nota * frecuencias.size())
	for n in frecuencias.size():
		var fase := 0.0
		for i in por_nota:
			fase += TAU * frecuencias[n] / FRECUENCIA_MEZCLA
			flujo[n * por_nota + i] = _onda(onda, fase) * amplitud \
				* _envolvente(i, por_nota, 1.2)
	return _a_flujo_wav(flujo)


## Bucle sin costuras (se usa para el zumbido del turbo). Para que enlace perfecto,
## la frecuencia (y el trémolo) se ajustan para que quepan **ciclos enteros** dentro
## del bucle: si no, la última muestra no encaja con la primera y se oye un "tac".
static func generar_bucle(
	frecuencia: float,
	duracion: float,
	tremolo_hz: float,
	amplitud: float
) -> AudioStreamWAV:
	var muestras := int(FRECUENCIA_MEZCLA * duracion)
	var frecuencia_ajustada := roundf(frecuencia * duracion) * FRECUENCIA_MEZCLA / float(muestras)
	var tremolo_ajustado := maxf(
		roundf(tremolo_hz * duracion), 1.0
	) * FRECUENCIA_MEZCLA / float(muestras)
	var flujo := _flujo_vacio(muestras)
	var fase := 0.0
	for i in muestras:
		fase += TAU * frecuencia_ajustada / FRECUENCIA_MEZCLA
		var pulso := 0.65 + 0.35 * sin(TAU * tremolo_ajustado * float(i) / FRECUENCIA_MEZCLA)
		flujo[i] = _onda(Onda.CUADRADA, fase) * amplitud * pulso
	return _a_flujo_wav(flujo, true)


## Devuelve el efecto pedido por nombre (generado al vuelo, sin archivos).
static func generar_efecto(nombre: String) -> AudioStreamWAV:
	match nombre:
		"comer":
			return generar_barrido(520.0, 780.0, 0.07)
		"powerup":
			return generar_arpegio(
				PackedFloat32Array([660.0, 880.0, 1320.0]), 0.085, Onda.TRIANGULAR, 0.45
			)
		"turbo":
			return generar_barrido(300.0, 900.0, 0.18, Onda.CUADRADA, 0.35)
		"turbo_bucle":
			# 884 Hz * 0,25 s = 221 ciclos exactos (y el trémolo, 2 ciclos).
			return generar_bucle(884.0, 0.25, 8.0, 0.16)
		"muerte":
			return generar_barrido(440.0, 90.0, 0.5, Onda.SENO, 0.5, 0.25)
		"fin":
			# Golpe grave de fin de partida (además del sonido de muerte).
			return generar_barrido(220.0, 60.0, 0.6, Onda.SENO, 0.5, 0.15)
		"nueva_partida":
			return generar_arpegio(
				PackedFloat32Array([523.25, 659.25, 783.99, 1046.5]), 0.07, Onda.TRIANGULAR, 0.4
			)
		"blip":
			# Pasar por encima de un botón del menú.
			return generar_barrido(900.0, 1200.0, 0.04, Onda.SENO, 0.22)
		"clic":
			# Elegir una opción del menú.
			return generar_arpegio(PackedFloat32Array([660.0, 990.0]), 0.05, Onda.TRIANGULAR, 0.4)
		_:
			return generar_barrido(660.0, 660.0, 0.05)


## Música de fondo: bucle chiptune de 8 s (16 tiempos a 128 BPM) con melodía
## (onda cuadrada), bajo (triangular) y bombo. Ninguna nota queda sonando en el
## punto de unión, así que el bucle enlaza sin corte.
static func generar_musica() -> AudioStreamWAV:
	var tiempo := 60.0 / MUSICA_BPM
	var total := int(FRECUENCIA_MEZCLA * tiempo * MUSICA_TIEMPOS)
	var flujo := _flujo_vacio(total)
	# Melodía: una nota por tiempo, escala de La menor.
	var melodia := PackedFloat32Array([
		440.0, 523.25, 659.25, 523.25, 587.33, 659.25, 587.33, 523.25,
		349.23, 440.0, 523.25, 440.0, 392.0, 493.88, 587.33, 783.99,
	])
	_mezclar_notas(flujo, melodia, tiempo, Onda.CUADRADA, 0.09)
	# Bajo: una nota cada dos tiempos (La - Fa - Do - Sol).
	var bajo := PackedFloat32Array([110.0, 110.0, 87.31, 87.31, 130.81, 130.81, 98.0, 98.0])
	_mezclar_notas(flujo, bajo, tiempo * 2.0, Onda.TRIANGULAR, 0.2)
	_mezclar_bombo(flujo, tiempo, 0.28)
	return _a_flujo_wav(flujo, true)


# ---------------------------------------------------------------------------
# Reproducción (el corazón del nodo)
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group(GRUPO)
	_cargar_ajustes()
	_crear_reproductores()
	_aplicar_estado()
	_musica.play()


## Reproduce un efecto en la posición del mundo donde ha pasado algo.
## `tono` cambia el tono (1.0 = normal) y `volumen_db` el volumen relativo.
func tocar(nombre: String, posicion: Vector2, tono: float = 1.0, volumen_db: float = 0.0) -> void:
	if _silencio:
		return
	var voz := _voz_libre()
	voz.stream = flujo(nombre)
	voz.global_position = posicion
	# Micro-variación de tono: el mismo efecto repetido no suena a robot.
	voz.pitch_scale = tono * randf_range(0.97, 1.03)
	voz.volume_db = volumen_efectos + volumen_db
	efectos_tocados += 1
	voz.play()


## Devuelve el flujo de un efecto (se genera la primera vez y se guarda).
## Lo usan los gusanos para su bucle de turbo.
func flujo(nombre: String) -> AudioStreamWAV:
	if not _cache.has(nombre):
		_cache[nombre] = generar_efecto(nombre)
	return _cache[nombre] as AudioStreamWAV


func volumen_efectos_db() -> float:
	return volumen_efectos


## ¿Está el juego en silencio? (buscado por `main.gd` para el rótulo del HUD)
func silenciado() -> bool:
	return _silencio


func nivel_musica() -> int:
	return _nivel_musica


## ¿La música está sonando ahora mismo?
func musica_sonando() -> bool:
	return _musica != null and _musica.playing and _nivel_musica > MUSICA_APAGADA


## ¿La música está lista (generada y cargada)? Lo usa la prueba automática.
func musica_lista() -> bool:
	return _musica != null and _musica.stream != null


## Silencio total sí/no (tecla M). Se recuerda para la próxima vez.
func alternar_silencio() -> void:
	poner_silencio(not _silencio)


## Fija el silencio (lo usa la tecla M y la prueba automática, que necesita
## sonido aunque tú lo tuvieras silenciado en la partida anterior).
func poner_silencio(silencio: bool) -> void:
	_silencio = silencio
	_aplicar_estado()
	_guardar_ajustes()


## Música: normal -> bajita -> apagada -> normal (tecla N). Se recuerda.
func alternar_musica() -> void:
	_nivel_musica = (_nivel_musica + 2) % 3
	_aplicar_estado()
	_guardar_ajustes()


## Rótulo para el HUD ("M: silencio · MÚSICA: ON (N)").
func texto_estado() -> String:
	var estado_sonido := "SONIDO: OFF (M)" if _silencio else "M: silencio"
	return "%s  ·  %s (N)" % [estado_sonido, nombre_nivel_musica(_nivel_musica)]


## Nombre del nivel de música. Es una función con `match` (y no un Array) porque
## sacar un valor de un Array sin tipo da Variant, y GDScript no puede inferir
## el tipo con `:=` (error "Cannot infer the type of ... variable").
static func nombre_nivel_musica(nivel: int) -> String:
	match nivel:
		MUSICA_APAGADA:
			return "MÚSICA: OFF"
		MUSICA_BAJITA:
			return "MÚSICA: BAJITA"
		_:
			return "MÚSICA: ON"


# ---------------------------------------------------------------------------
# Interior
# ---------------------------------------------------------------------------

func _crear_reproductores() -> void:
	for i in VOCES:
		var voz := AudioStreamPlayer2D.new()
		voz.name = "Voz%d" % (i + 1)
		voz.max_distance = distancia_audible
		voz.attenuation = 1.4  # Cae rápido con la distancia: suena "de cerca".
		add_child(voz)
		_voces.append(voz)
	_musica = AudioStreamPlayer.new()
	_musica.name = "Musica"
	_musica.stream = generar_musica()
	_musica.volume_db = volumen_musica
	add_child(_musica)


## Primer reproductor libre (o el primero, si ahora mismo suenan todos).
func _voz_libre() -> AudioStreamPlayer2D:
	for voz in _voces:
		if not voz.playing:
			return voz
	return _voces[0]


func _aplicar_estado() -> void:
	AudioServer.set_bus_mute(CANAL_MAESTRO, _silencio)
	if _musica == null:
		return
	match _nivel_musica:
		MUSICA_APAGADA:
			# -80 dB es silencio; además se pausa para no gastar CPU.
			_musica.volume_db = -80.0
			_musica.stream_paused = true
		MUSICA_BAJITA:
			_musica.stream_paused = false
			_musica.volume_db = volumen_musica_bajita
		_:
			_musica.stream_paused = false
			_musica.volume_db = volumen_musica


func _cargar_ajustes() -> void:
	# Los ajustes viven en `ajustes.gd` (mismo archivo que usa la pantalla de
	# Opciones), así que no hay dos sitios que puedan pisarse las claves.
	var valores := Ajustes.cargar()
	_silencio = bool(valores.get("silencio", false))
	_nivel_musica = clampi(
		int(valores.get("musica", MUSICA_NORMAL)), MUSICA_APAGADA, MUSICA_NORMAL
	)
	volumen_efectos = float(valores.get("volumen_efectos", volumen_efectos))
	volumen_musica = float(valores.get("volumen_musica", volumen_musica))


func _guardar_ajustes() -> void:
	Ajustes.guardar({
		"silencio": _silencio,
		"musica": _nivel_musica,
		"volumen_efectos": volumen_efectos,
		"volumen_musica": volumen_musica,
	})


# ------------------------- ayudas de generación ----------------------------

static func _flujo_vacio(muestras: int) -> PackedFloat32Array:
	var flujo := PackedFloat32Array()
	flujo.resize(muestras)  # Los PackedFloat32Array nacen a 0.0.
	return flujo


## Envolvente percusiva: 3 ms de ataque (evita el "clic" inicial) y una caída
## que llega a cero justo en la última muestra (evita el "clic" final).
static func _envolvente(indice: int, total: int, caida: float) -> float:
	var ataque := minf(float(indice) / (FRECUENCIA_MEZCLA * 0.003), 1.0)
	var avance := float(indice) / float(total)
	return ataque * pow(1.0 - avance, caida)


static func _onda(tipo: int, fase: float) -> float:
	match tipo:
		Onda.CUADRADA:
			return 1.0 if fmod(fase, TAU) < PI else -1.0
		Onda.TRIANGULAR:
			return 1.0 - 4.0 * absf(fmod(fase, TAU) / TAU - 0.5)
		_:
			return sin(fase)


## Suma varias notas seguidas dentro de un flujo (para la música). `silencio_final`
## deja un hueco sin sonido al final de cada nota para que no se solapen.
static func _mezclar_notas(
	flujo: PackedFloat32Array,
	notas: PackedFloat32Array,
	duracion_nota: float,
	onda: int,
	amplitud: float,
	silencio_final: float = 0.03
) -> void:
	var por_nota := int(FRECUENCIA_MEZCLA * duracion_nota)
	var con_sonido := maxi(por_nota - int(FRECUENCIA_MEZCLA * silencio_final), 1)
	for n in notas.size():
		var inicio := n * por_nota
		var fase := 0.0
		for i in con_sonido:
			if inicio + i >= flujo.size():
				break
			fase += TAU * notas[n] / FRECUENCIA_MEZCLA
			flujo[inicio + i] += _onda(onda, fase) * amplitud * _envolvente(i, con_sonido, 1.0)


## Bombo: un golpe grave y corto cada `cada_segundos`, sumado al flujo.
static func _mezclar_bombo(
	flujo: PackedFloat32Array, cada_segundos: float, amplitud: float
) -> void:
	var por_golpe := int(FRECUENCIA_MEZCLA * 0.12)
	var golpe := _flujo_vacio(por_golpe)
	var fase := 0.0
	for i in por_golpe:
		var avance := float(i) / float(por_golpe)
		fase += TAU * lerpf(70.0, 45.0, avance) / FRECUENCIA_MEZCLA
		golpe[i] = sin(fase) * amplitud * pow(1.0 - avance, 3.0)
	var paso := int(FRECUENCIA_MEZCLA * cada_segundos)
	var posicion := 0
	while posicion < flujo.size():
		for i in por_golpe:
			if posicion + i < flujo.size():
				flujo[posicion + i] += golpe[i]
		posicion += paso


## Convierte el flujo de muestras (-1..1) en un `AudioStreamWAV` reproducible.
static func _a_flujo_wav(flujo: PackedFloat32Array, bucle: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(flujo.size() * 2)  # 16 bits = 2 bytes por muestra.
	for i in flujo.size():
		bytes.encode_s16(i * 2, int(clampf(flujo[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = FRECUENCIA_MEZCLA
	wav.stereo = false
	wav.data = bytes
	if bucle:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = flujo.size()
	return wav
