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
##   6) morir al chocar con el cuerpo de OTRO gusano,
##   7) los restos: una comida en cada posición del cuerpo del muerto.

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
	"res://scripts/main.gd",
]

var _total := 0
var _fallos := 0


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
	add_child(main)
	main.comida_por_segundo = 0.0  # Sin comida nueva: así los conteos son exactos.
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

	# -------------------------------- 6 y 7) Muerte por otro cuerpo y restos
	var otro := load(RUTA_GUSANO).instantiate() as Gusano
	otro.segmentos_iniciales = 6
	main.contenedor_gusanos.add_child(otro)
	otro.global_position = gusano.global_position + Vector2(400.0, 0.0)
	otro.mirar_hacia(PI)  # Mirando hacia el jugador, pero su cuerpo queda detrás.
	await _esperar_fisica(1)

	# Congelamos los dos gusanos: así las posiciones no cambian durante la prueba
	# y el resultado no depende del momento exacto en que se detecta el choque.
	gusano.set_physics_process(false)
	otro.set_physics_process(false)
	var posicion_muerte := gusano.global_position
	# Colocamos un segmento del otro gusano justo encima de la cabeza del nuestro.
	otro._segmentos[0].global_position = posicion_muerte
	gusano._tiempo_inmunidad = 0.0  # Sin inmunidad de nacimiento.
	var largo_al_morir := gusano.longitud()
	var comidas_antes := main.contenedor_comida.get_child_count()
	await _esperar_fisica(3)

	_comprobar(
		"6) La cabeza muere al tocar el cuerpo de otro gusano",
		gusano.muerto,
		"el gusano que chocó murió" if gusano.muerto else "¡seguía vivo!"
	)

	# Los restos se crean con call_deferred(), de ahí la espera extra.
	await _esperar_fisica(2)
	var comidas_despues := main.contenedor_comida.get_child_count()
	_comprobar(
		"7) Restos: una comida por cada parte del cuerpo",
		comidas_despues - comidas_antes == largo_al_morir
			and _hay_comida_en(main, posicion_muerte),
		"+%d comidas (se esperaban %d) | comida en la posición exacta de la cabeza: %s" % [
			comidas_despues - comidas_antes, largo_al_morir,
			"sí" if _hay_comida_en(main, posicion_muerte) else "NO",
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
