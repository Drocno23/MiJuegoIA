class_name PantallaRecords
extends Pantalla
## Pantalla de **récords y logros**: tu perfil, tus mejores partidas y el progreso
## de cada logro, que es lo que desbloquea las pieles.
##
## NODO AL QUE SE ADJUNTA: al **Control** raíz de `escenas/Records.tscn`.
##
## Los datos salen de `records.gd` (`user://records.cfg`): aquí solo se leen y se
## pintan. El único que escribe es el apodo y el botón de borrar (con confirmación).

const SEGUNDOS_CONFIRMACION := 4.0

## Descripción de los power-ups y demás datos que no vienen de `records.cfg`.
var datos: Dictionary = {}
var confirmando_borrado := false

var _campo_apodo: LineEdit = null
var _boton_borrar: Button = null
var _aviso: Label = null
var _tween_aviso: Tween = null


func al_abrir() -> void:
	datos = Records.cargar()
	_montar()


func al_pulsar_escape() -> void:
	ir_al_menu()


# ---------------------------------------------------------------------------
# Montaje (se puede repetir: al borrar los récords se vuelve a montar todo)
# ---------------------------------------------------------------------------

func _montar() -> void:
	var contenido := crear_armazon(
		"RÉCORDS Y LOGROS",
		"Todo esto se guarda en tu equipo (user://records.cfg) y sobrevive al cerrar el juego"
	)
	var columnas := HBoxContainer.new()
	columnas.add_theme_constant_override("separation", 22)
	columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(columnas)

	var izquierda := VBoxContainer.new()
	izquierda.name = "Izquierda"
	izquierda.custom_minimum_size = Vector2(470, 0)
	izquierda.add_theme_constant_override("separation", 12)
	columnas.add_child(izquierda)
	_montar_perfil(izquierda)
	_montar_estadisticas(izquierda)

	var derecha := VBoxContainer.new()
	derecha.name = "Derecha"
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	derecha.add_theme_constant_override("separation", 12)
	columnas.add_child(derecha)
	_montar_mejores(derecha)
	_montar_logros(derecha)

	contenido.add_child(_montar_acciones())
	_aviso = etiqueta("", "dato")
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Estilo.estilizar_texto(_aviso, Estilo.NORMAL, Estilo.ACENTO)
	_aviso.modulate.a = 0.0
	contenido.add_child(_aviso)
	pie("Los logros conseguidos desbloquean paletas y patrones nuevos")


func _montar_perfil(padre: Node) -> void:
	var caja := anadir_panel(padre, "Tu perfil")
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	caja.add_child(fila)
	var rotulo := etiqueta("Apodo:")
	rotulo.custom_minimum_size = Vector2(80, 0)
	fila.add_child(rotulo)
	_campo_apodo = LineEdit.new()
	_campo_apodo.name = "Apodo"
	_campo_apodo.text = str(datos.get("nombre", ""))
	_campo_apodo.placeholder_text = "escribe tu apodo"
	_campo_apodo.max_length = Records.LARGO_APODO
	_campo_apodo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Estilo.estilizar_campo(_campo_apodo)
	_campo_apodo.text_submitted.connect(_on_apodo_escrito)
	fila.add_child(_campo_apodo)
	fila.add_child(boton("GUARDAR", _guardar_apodo))
	caja.add_child(etiqueta(
		"Así aparecerás en el marcador y en la pantalla final.",
		"", Estilo.PEQUENO
	))


func _montar_estadisticas(padre: Node) -> void:
	var caja := anadir_panel(padre, "Estadísticas de siempre")
	caja.add_child(fila_de_datos("Partidas jugadas", str(int(datos.get("partidas", 0)))))
	caja.add_child(fila_de_datos("Comida comida", str(int(datos.get("comida", 0)))))
	caja.add_child(fila_de_datos("Bots eliminados", str(int(datos.get("bots", 0)))))
	caja.add_child(fila_de_datos(
		"Tiempo jugado", Records.texto_tiempo(float(datos.get("tiempo", 0.0)))
	))
	caja.add_child(fila_de_datos(
		"Mejor puntuación", "%d puntos" % int(datos.get("record_puntos", 0))
	))
	caja.add_child(fila_de_datos(
		"Mayor longitud", "%d segmentos" % int(datos.get("record_longitud", 0))
	))


func _montar_mejores(padre: Node) -> void:
	var caja := anadir_panel(padre, "Tus mejores partidas")
	var mejores: Array = datos.get("mejores", []) as Array
	if mejores.is_empty():
		caja.add_child(etiqueta("Todavía no has jugado ninguna partida."))
	else:
		for i in mejores.size():
			var partida: Dictionary = mejores[i]
			caja.add_child(fila_de_datos(
				"%d.  %s" % [i + 1, str(partida.get("nombre", "TÚ"))],
				"%d pts · %d de largo · %s" % [
					int(partida.get("puntos", 0)),
					int(partida.get("longitud", 0)),
					str(partida.get("fecha", "")),
				]
			))


## Un logro por fila: texto + progreso (barra) + cuánto llevas.
func _montar_logros(padre: Node) -> void:
	var caja := anadir_panel(padre, "Logros (desbloquean pieles)")
	var conseguidos := 0
	for clave in Pieles.logros.keys():
		var logro: Dictionary = Pieles.logros[clave]
		var estadistica := str(logro.get("estadistica", ""))
		var cantidad := maxi(int(logro.get("cantidad", 1)), 1)
		var actual := int(datos.get(estadistica, 0))
		var hecho := actual >= cantidad
		if hecho:
			conseguidos += 1

		var bloque := VBoxContainer.new()
		bloque.add_theme_constant_override("separation", 2)
		var fila := HBoxContainer.new()
		var texto := etiqueta(
			("✔  " if hecho else "•  ") + str(logro.get("texto", clave)),
			"",
			Estilo.NORMAL,
			Estilo.ACENTO if hecho else Estilo.TEXTO_SUAVE
		)
		texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(texto)
		var premio := Pieles.recompensa(clave)
		if premio != "":
			fila.add_child(etiqueta(premio, "", Estilo.PEQUENO, Estilo.AVISO))
		fila.add_child(etiqueta("%d / %d" % [mini(actual, cantidad), cantidad], "dato"))
		bloque.add_child(fila)
		var progreso := barra(
			float(actual) / float(cantidad) * 100.0, Estilo.ACENTO if hecho else Estilo.AVISO
		)
		bloque.add_child(progreso)
		caja.add_child(bloque)
	caja.add_child(etiqueta(
		"Conseguidos: %d de %d" % [conseguidos, Pieles.logros.size()],
		"",
		Estilo.PEQUENO
	))


func _montar_acciones() -> HBoxContainer:
	var acciones := HBoxContainer.new()
	acciones.name = "Acciones"
	acciones.add_theme_constant_override("separation", 10)
	var volver := boton("VOLVER AL MENÚ", ir_al_menu, true)
	volver.custom_minimum_size = Vector2(0, 48)
	volver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acciones.add_child(volver)
	_boton_borrar = boton("BORRAR TODOS LOS RÉCORDS", _borrar_records)
	Estilo.estilizar_boton(_boton_borrar, true, Estilo.PELIGRO)
	_boton_borrar.custom_minimum_size = Vector2(0, 48)
	_boton_borrar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acciones.add_child(_boton_borrar)
	return acciones


# ---------------------------------------------------------------------------
# Acciones
# ---------------------------------------------------------------------------

func _guardar_apodo() -> void:
	if _campo_apodo == null:
		return
	var limpio := _campo_apodo.text.strip_edges().substr(0, Records.LARGO_APODO)
	if limpio == "":
		limpio = Records.nombre_sistema()
	_campo_apodo.text = limpio
	datos["nombre"] = limpio
	Records.guardar(datos)
	_mostrar_aviso("Apodo guardado: %s" % limpio)


func _on_apodo_escrito(_texto: String) -> void:
	_guardar_apodo()
	if _campo_apodo != null:
		_campo_apodo.release_focus()


## Borrar los récords pide confirmación (hay que pulsar dos veces).
func _borrar_records() -> void:
	if not confirmando_borrado:
		confirmando_borrado = true
		if _boton_borrar != null:
			_boton_borrar.text = "¿SEGURO? Pulsa otra vez para borrar"
		_esperar_confirmacion()
		return
	Records.borrar()
	confirmando_borrado = false
	datos = Records.cargar()
	await _remontar()
	_mostrar_aviso("Récords y logros borrados. ¡A empezar de cero!")


func _esperar_confirmacion() -> void:
	await get_tree().create_timer(SEGUNDOS_CONFIRMACION).timeout
	if not confirmando_borrado:
		return
	confirmando_borrado = false
	if _boton_borrar != null:
		_boton_borrar.text = "BORRAR TODOS LOS RÉCORDS"


## Borra lo que hay montado y lo vuelve a montar con los datos nuevos.
## Se espera un frame antes de montar: liberar un nodo en mitad de su propia señal
## (el botón de borrar) es pedir problemas.
func _remontar() -> void:
	var margen := get_node_or_null("Margen")
	if margen != null:
		margen.queue_free()
		await get_tree().process_frame
	_columna = null
	_pie = null
	_montar()
	Estilo.estilizar_arbol(self)
	_conectar_botones()


func _mostrar_aviso(texto: String) -> void:
	if _aviso == null:
		return
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	if _tween_aviso != null and _tween_aviso.is_valid():
		_tween_aviso.kill()
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(2.5)
	_tween_aviso.tween_property(_aviso, "modulate:a", 0.0, 1.2)
