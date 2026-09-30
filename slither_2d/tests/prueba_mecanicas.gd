extends Node
## Prueba automática de las mecánicas del prototipo (se ejecuta SIN ventana).
##
## NODO AL QUE SE ADJUNTA: al Node raíz de `tests/PruebaMecanicas.tscn`.
## No forma parte del juego: es una herramienta para comprobar en segundos que
## nada se ha roto después de tocar el código.
##
## CÓMO EJECUTARLA (desde la carpeta slither_2d):
##
##     godot --headless res://tests/PruebaMecanicas.tscn
##     echo "código de salida: $?"     # 0 = todo bien, 1 = hay fallos
##
## En VS Code:  F1 -> "Tasks: Run Task" -> "Probar: mecánicas (headless)"
##
## Comprueba, en este orden:
##   0) que TODOS los scripts del juego cargan sin errores (sintaxis y API),
##   1) que el mundo se monta (jugador, bots y comida),
##   2) el cuerpo: cadena de segmentos con separación fija,
##   3) comer: suma puntos y alarga el cuerpo,
##   4) la comida desaparece al comerse,
##   5) tocar el PROPIO cuerpo no mata,
##   6) el cuerpo tiene un solo grosor (uniforme),
##   7) turbo: corre más y suelta segmentos,
##   8) power-up ESCUDO: evita la muerte,
##   9) power-up IMÁN: atrae la comida,
##  10) los power-ups se generan en el mundo,
##  11) el HUD nuevo (minimapa, clasificación y barra de turbo) existe,
##  12) morir al chocar con el cuerpo de OTRO gusano,
##  13) los restos: una comida en cada posición del cuerpo del muerto.

const RUTA_MAIN := "res://escenas/Main.tscn"
const RUTA_COMIDA := "res://escenas/Comida.tscn"
const RUTA_GUSANO := "res://escenas/Gusano.tscn"
## Margen en píxeles al medir la separación entre segmentos (la ruta se guarda
## en tramos de 4 px, así que en las curvas hay una diferencia mínima).
const TOLERANCIA_SEPARACION := 2.0
## Distancia máxima a la que debe estar la comida de los restos.
const TOLERANCIA_RESTOS := 4.0
## Scripts del juego: la comprobación 0 verifica que TODOS cargan sin errores.
## Si alguno falla (un método que no existe, un tipo mal deducido...), el error
## sale aquí, claro y primero, en vez de propagarse como errores confusos.
const SCRIPTS_DEL_JUEGO := [
	"res://scripts/dibujo.gd",
	"res://scripts/comida.gd",
	"res://scripts/cuerpo_segmento.gd",
	"res://scripts/gusano.gd",
	"res://scripts/gusano_cpu.gd",
	"res://scripts/fondo.gd",
	"res://scripts/minimapa.gd",
	"res://scripts/main.gd",
]

var _total := 0
var _fallos := 0
var _murio := false
var _posiciones_restos := PackedVector2Array()
var _segmentos_soltados := 0  ## Cuántas veces el turbo ha gastado un segmento.


func _ready() -> void:
	print("")
	print("===============================================================")
	print("  PRUEBA AUTOMÁTICA — slither_2d")
	print("  Godot %s   |   %s" % [
		Engine.get_version_info()["string"], ProjectSettings.globalize_path("res://")
	])
	print("===============================================================")
	await _ejecutar()
	print("---------------------------------------------------------------")
	if _fallos == 0:
		print("  RESULTADO: %d/%d comprobaciones OK   ✔  TODO BIEN" % [_total, _total])
	else:
		print("  RESULTADO: %d/%d comprobaciones OK   ✘  HAY %d FALLO(S)" % [
			_total - _fallos, _total, _fallos
		])
	print("===============================================================")
	print("")
	get_tree().quit(0 if _fallos == 0 else 1)


func _ejecutar() -> void:
	# ---------------------------------------- 0) ¿Cargan todos los scripts?
	var rotos := PackedStringArray()
	for ruta in SCRIPTS_DEL_JUEGO:
		if load(ruta) == null:
			rotos.append(str(ruta))  # str(): siempre String, sin ambigüedad de tipos
	var detalle := "%d scripts cargados sin errores" % SCRIPTS_DEL_JUEGO.size()
	if not rotos.is_empty():
		detalle = "NO se pudieron cargar: %s  (mira los SCRIPT ERROR de arriba)" % ", ".join(rotos)
	_comprobar("0) Los scripts del juego se cargan", rotos.is_empty(), detalle)
	if not rotos.is_empty():
		return

	# ---------------------------------------------------------------- 1) Montaje
	var escena: PackedScene = load(RUTA_MAIN)
	if escena == null:
		_comprobar("1) El mundo se monta", false, "no se pudo cargar %s" % RUTA_MAIN)
		return
	var main := escena.instantiate() as Mundo
	# IMPORTANTE: la configuración va ANTES de add_child(). El mundo se monta en
	# _ready(), que se ejecuta justo al entrar en el árbol; si tocamos los ajustes
	# después, la comida y el power-up iniciales ya estarían creados (y el
	# recuento de la comprobación 1 saldría 151/150).
	main.comida_por_segundo = 0.0  # Sin comida nueva: así los conteos son exactos.
	main.powerups_activos = false  # Los power-ups de la prueba se aplican a mano.
	main.powerup_al_empezar = false  # Sin power-up "de bienvenida".
	add_child(main)
	# Congelamos los bots ya mismo, antes del primer frame de física: así no comen
	# nada (el recuento de comida sería inexacto) ni chocan con el jugador.
	for nodo in main.contenedor_gusanos.get_children():
		if nodo is GusanoCPU:
			(nodo as GusanoCPU).set_physics_process(false)
	await _esperar_fisica(3)

	var gusano := main.jugador
	var bots := main.contenedor_gusanos.get_child_count() - (1 if gusano != null else 0)
	_comprobar(
		"1) El mundo se monta",
		gusano != null and bots == main.bots_iniciales
			and main.contenedor_comida.get_child_count() == main.comida_inicial,
		"jugador: %s | bots: %d/%d | comidas: %d/%d" % [
			"ok" if gusano != null else "FALTA",
			bots, main.bots_iniciales,
			main.contenedor_comida.get_child_count(), main.comida_inicial,
		]
	)
	if gusano == null:
		await _limpiar(main)
		return

	# ------------------------------------------------- 2) Cuerpo con separación
	var peor_separacion := 0.0
	var anterior := gusano.global_position
	for segmento in gusano._segmentos:
		peor_separacion = maxf(peor_separacion, anterior.distance_to(segmento.global_position))
		anterior = segmento.global_position
	_comprobar(
		"2) Cuerpo: segmentos con separación fija",
		gusano._segmentos.size() == gusano.segmentos_iniciales
			and peor_separacion <= gusano.separacion + TOLERANCIA_SEPARACION,
		"%d segmentos | separación máx. medida: %.2f px (esperada: %.1f)" % [
			gusano._segmentos.size(), peor_separacion, gusano.separacion
		]
	)

	# ----------------------------------------------------------- 3) Comer crece
	var comida := load(RUTA_COMIDA).instantiate() as Comida
	var valor_comida := comida.valor
	var segmentos_comida := comida.segmentos
	main.contenedor_comida.add_child(comida)
	comida.global_position = gusano.global_position  # Justo encima de la cabeza.
	var puntos_antes := gusano.puntuacion
	var largo_antes := gusano.longitud()
	await _esperar_fisica(3)
	_comprobar(
		"3) Comer suma puntos y alarga el cuerpo",
		gusano.puntuacion == puntos_antes + valor_comida
			and gusano.longitud() == largo_antes + segmentos_comida,
		"puntos %d -> %d | longitud %d -> %d" % [
			puntos_antes, gusano.puntuacion, largo_antes, gusano.longitud()
		]
	)

	# -------------------------------------------- 4) La comida desaparece (pop)
	await _esperar_fisica(12)  # Le damos tiempo al tween del "pop" (0,12 s).
	_comprobar(
		"4) La comida se destruye al comerse",
		not is_instance_valid(comida),
		"el nodo de comida ya no existe"
	)

	# ---------------------------------------- 5) El propio cuerpo NO mata
	gusano._chocar_con_cuerpo(gusano._segmentos[0])
	_comprobar(
		"5) Tocar el propio cuerpo no mata",
		not gusano.muerto,
		"el gusano sigue vivo tras \"chocar\" con su propio segmento"
	)

	# -------------------------- 6) Un solo grosor en todo el cuerpo
	var radio_cabeza: float = gusano.radio
	var radio_primero: float = gusano._segmentos[0].radio
	var grosores_iguales := true
	for segmento in gusano._segmentos:
		if not is_equal_approx(segmento.radio, radio_primero):
			grosores_iguales = false
	# El afilado de cola sigue disponible como opción: comprobamos que funciona.
	gusano.cola_afilada_segmentos = 8
	gusano._actualizar_grosores()
	var radio_ultimo: float = gusano._segmentos[gusano._segmentos.size() - 1].radio
	gusano.cola_afilada_segmentos = 0  # Y lo volvemos a dejar uniforme.
	gusano._actualizar_grosores()
	_comprobar(
		"6) El cuerpo tiene un solo grosor",
		grosores_iguales and is_equal_approx(radio_primero, radio_cabeza)
			and radio_ultimo < radio_primero,
		"cabeza: %.1f px | cuerpo: %.1f px en todos los segmentos | afilado opcional: %.1f px" % [
			radio_cabeza, radio_primero, radio_ultimo
		]
	)

	# --------------------------------------------------- 7) Turbo
	# Inmunidad alta: mientras el gusano se mueve solo, no debe morir por un bot.
	gusano._tiempo_inmunidad = 999.0
	var velocidad_normal := gusano.velocidad_actual()
	var longitud_antes_turbo := gusano.longitud()
	gusano.segmento_soltado.connect(_on_segmento_soltado_prueba)
	# Pulsamos la acción de verdad (como si se mantuviera SHIFT): el mundo es
	# quien la lee en _process(), igual que hará el jugador en la partida.
	Input.action_press("turbo")
	await _esperar_fisica(30)  # 0,5 s: tiempo de sobra para el primer coste.
	var velocidad_con_turbo := gusano.velocidad_actual()
	Input.action_release("turbo")
	await _esperar_fisica(2)
	_comprobar(
		"7) Turbo: corre más y suelta segmentos",
		velocidad_con_turbo > velocidad_normal and _segmentos_soltados >= 1,
		"velocidad %.0f -> %.0f px/s | longitud %d -> %d | segmentos soltados: %d" % [
			velocidad_normal, velocidad_con_turbo, longitud_antes_turbo,
			gusano.longitud(), _segmentos_soltados
		]
	)

	# ------------------------------------ 8) Power-up ESCUDO
	var otro := load(RUTA_GUSANO).instantiate() as Gusano
	otro.segmentos_iniciales = 6
	# La posición se fija ANTES de add_child(): el gusano construye su cuerpo en
	# _ready() a partir de su posición, así que si lo añadimos primero nacería en
	# el origen... ¡encima del jugador, y lo mataría sin querer!
	otro.position = gusano.global_position + Vector2(500.0, 0.0)
	main.contenedor_gusanos.add_child(otro)
	otro.mirar_hacia(PI)  # Mira hacia el jugador, pero su cuerpo queda detrás.
	otro.set_physics_process(false)

	gusano._tiempo_inmunidad = 0.0
	gusano.aplicar_powerup(Comida.Tipo.ESCUDO, 5.0)
	gusano._chocar_con_cuerpo(otro._segmentos[0])
	_comprobar(
		"8) El escudo evita la muerte",
		not gusano.muerto,
		"con el escudo activo, chocar con otro cuerpo no lo mata"
	)

	# ------------------------------------ 9) Power-up IMÁN
	gusano._tiempo_inmunidad = 999.0
	gusano._tiempo_escudo = 0.0
	gusano.aplicar_powerup(Comida.Tipo.IMAN, 5.0)
	var comida_iman := load(RUTA_COMIDA).instantiate() as Comida
	main.contenedor_comida.add_child(comida_iman)
	comida_iman.global_position = gusano.global_position + Vector2(gusano.radio_iman * 0.75, 0.0)
	await _esperar_fisica(1)
	var posicion_inicial_iman := comida_iman.global_position
	await _esperar_fisica(20)
	var movida := 0.0
	if is_instance_valid(comida_iman):
		movida = posicion_inicial_iman.distance_to(comida_iman.global_position)
	else:
		movida = gusano.radio_iman  # Se la comió: el imán funcionó de sobra.
	_comprobar(
		"9) El imán atrae la comida",
		movida > 20.0,
		"la comida se acercó %.1f px a la cabeza" % movida
	)

	# Apagamos el imán: si siguiera activo arrastraría comida durante las
	# comprobaciones siguientes y podría descuadrar el recuento de los restos.
	gusano._tiempo_iman = 0.0

	# -------------------- 10) Los power-ups se generan en el mundo
	main._aparecer_powerup()
	var powerups_en_el_mundo := 0
	var duracion_powerup := 0.0
	for nodo in main.contenedor_comida.get_children():
		var comida_mundo := nodo as Comida
		if comida_mundo != null and Comida.es_powerup(comida_mundo.tipo):
			powerups_en_el_mundo += 1
			duracion_powerup = comida_mundo.duracion
	_comprobar(
		"10) Los power-ups se generan en el mundo",
		powerups_en_el_mundo >= 1 and duracion_powerup > 0.0,
		"%d power-up(s) en el mundo | duración del último: %.1f s" % [
			powerups_en_el_mundo, duracion_powerup
		]
	)

	# -------------------------------------------- 11) HUD nuevo
	var faltan_hud := PackedStringArray()
	for ruta_hud in ["HUD/Minimapa", "HUD/Clasificacion", "HUD/TurboFondo/Relleno", "HUD/Efectos"]:
		if main.get_node_or_null(ruta_hud) == null:
			faltan_hud.append(ruta_hud)
	var clasificacion := main.get_node_or_null("HUD/Clasificacion") as Label
	var clasificacion_ok := false
	if clasificacion != null:
		clasificacion_ok = clasificacion.text.contains("CLASIFICACIÓN")
	_comprobar(
		"11) HUD: minimapa, clasificación y barra de turbo",
		faltan_hud.is_empty() and clasificacion_ok,
		"nodos del HUD: %s | clasificación: %s" % [
			"todos" if faltan_hud.is_empty() else "faltan " + ", ".join(faltan_hud),
			"ok" if clasificacion_ok else "vacía"
		]
	)

	# A partir de aquí dejamos todo quieto (posiciones fijas = prueba estable).
	gusano.set_physics_process(false)

	# Esperamos a que terminen los "pop" pendientes: una comida recién comida
	# sigue siendo un nodo del árbol 0,12 s mientras dura su animación. Si no
	# esperamos, alguno se libera en mitad de la comprobación 13 y el recuento
	# de restos (que es una resta) sale descuadrado.
	await _esperar_fisica(12)

	# ------------------------------ 12 y 13) Muerte por otro cuerpo y restos
	# Espía de la señal: comprobamos la muerte por lo que EMITE el gusano, no
	# leyendo un nodo que puede haberse liberado con queue_free().
	_murio = false
	_posiciones_restos = PackedVector2Array()
	if not gusano.murio.is_connected(_on_gusano_murio_prueba):
		gusano.murio.connect(_on_gusano_murio_prueba)

	var posicion_muerte := gusano.global_position
	var largo_al_morir := gusano.longitud()
	var comidas_antes := main.contenedor_comida.get_child_count()
	# Colocamos un segmento del otro gusano justo encima de la cabeza del nuestro.
	gusano._tiempo_inmunidad = 0.0  # Sin inmunidad de nacimiento.
	otro._segmentos[0].global_position = posicion_muerte
	await _esperar_fisica(4)

	_comprobar(
		"12) La cabeza muere al tocar el cuerpo de otro gusano",
		_murio and not is_instance_valid(gusano) and is_instance_valid(otro) and not otro.muerto,
		"señal 'murio' recibida: %s | jugador liberado: %s | el otro gusano sigue vivo: %s" % [
			"sí" if _murio else "NO",
			"sí" if not is_instance_valid(gusano) else "NO",
			"sí" if is_instance_valid(otro) and not otro.muerto else "NO",
		]
	)

	# Los restos se crean con call_deferred(), de ahí la espera extra.
	await _esperar_fisica(3)
	var comidas_despues := main.contenedor_comida.get_child_count()
	# Cuántas de las posiciones que emitió el gusano tienen su comida.
	var restos_creados := 0
	for posicion in _posiciones_restos:
		if _hay_comida_en(main, posicion):
			restos_creados += 1
	# El número que manda es el de posiciones que emitió la señal `murio` (una
	# comida por cada una): así la comprobación no depende de lo que haya comido
	# o dejado de comer nadie antes.
	var esperadas := _posiciones_restos.size()
	_comprobar(
		"13) Restos: una comida por cada parte del cuerpo",
		comidas_despues - comidas_antes == esperadas
			and esperadas == largo_al_morir
			and restos_creados == esperadas,
		("+%d comidas | %d posiciones en la señal (longitud al morir: %d) | "
			+ "comida en cada punto del rastro: %d/%d") % [
			comidas_despues - comidas_antes, esperadas, largo_al_morir,
			restos_creados, esperadas,
		]
	)

	await _limpiar(main)


## Libera el mundo antes de terminar: así Godot no avisa de recursos
## ("RID allocations ... were leaked at exit") al cerrar.
func _limpiar(main: Mundo) -> void:
	if is_instance_valid(main):
		main.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame


## Busca una comida a menos de TOLERANCIA_RESTOS píxeles del punto indicado.
func _hay_comida_en(main: Mundo, punto: Vector2) -> bool:
	for nodo in main.contenedor_comida.get_children():
		var comida := nodo as Comida
		if comida != null and comida.global_position.distance_to(punto) <= TOLERANCIA_RESTOS:
			return true
	return false


## Cuenta los segmentos que el turbo ha soltado (comprobación 7).
func _on_segmento_soltado_prueba(_posicion: Vector2) -> void:
	_segmentos_soltados += 1


## Guarda lo que emite el gusano al morir (se conecta en la comprobación 12).
func _on_gusano_murio_prueba(posiciones: PackedVector2Array) -> void:
	_murio = true
	_posiciones_restos = posiciones


func _esperar_fisica(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _comprobar(nombre: String, correcto: bool, detalle: String = "") -> void:
	_total += 1
	if not correcto:
		_fallos += 1
	print("  %s  %s" % ["✔" if correcto else "✘", nombre])
	if detalle != "":
		print("        %s" % detalle)
