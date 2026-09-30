class_name MenuPrincipal
extends Pantalla
## Menú principal: la puerta de entrada a todas las demás pantallas.
##
## NODO AL QUE SE ADJUNTA: al **Control** raíz de `escenas/MenuPrincipal.tscn`.
##
## A la izquierda, la lista de botones (JUGAR y compañía); a la derecha, una ficha
## con tu perfil y tus mejores partidas. Los botones se recorren con las flechas y
## con ENTER/TAB, además del ratón.

var datos: Dictionary = {}

var _boton_jugar: Button = null


func al_abrir() -> void:
	datos = Records.cargar()
	if str(datos.get("nombre", "")).strip_edges() == "":
		datos["nombre"] = Records.nombre_sistema()
		Records.guardar(datos)

	var contenido := crear_armazon(
		"SLITHER 2D",
		"Come, crece y no choques  ·  Godot 4.7 (arte y sonido generados por código)"
	)
	var columnas := HBoxContainer.new()
	columnas.name = "Columnas"
	columnas.add_theme_constant_override("separation", 26)
	columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(columnas)

	# ----------------------- izquierda: los botones --------------------------
	var izquierda := VBoxContainer.new()
	izquierda.name = "Botones"
	izquierda.add_theme_constant_override("separation", 10)
	izquierda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izquierda.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	columnas.add_child(izquierda)

	_boton_jugar = _boton_menu(izquierda, "JUGAR", ir_al_juego, true)
	_boton_menu(izquierda, "SELECCIÓN DE PIEL", _ir_a.bind(Gestor.SELECCION))
	_boton_menu(izquierda, "RÉCORDS Y LOGROS", _ir_a.bind(Gestor.RECORDS))
	_boton_menu(izquierda, "OPCIONES", _ir_a.bind(Gestor.OPCIONES))
	_boton_menu(izquierda, "CÓMO JUGAR", _ir_a.bind(Gestor.COMO_JUGAR))
	_boton_menu(izquierda, "CRÉDITOS", _ir_a.bind(Gestor.CREDITOS))
	_boton_menu(izquierda, "SALIR", Gestor.salir)

	# ------------------------ derecha: tu perfil -----------------------------
	var derecha := VBoxContainer.new()
	derecha.name = "Perfil"
	derecha.custom_minimum_size = Vector2(420, 0)
	derecha.add_theme_constant_override("separation", 12)
	columnas.add_child(derecha)
	_ficha_de_perfil(derecha)
	_ficha_de_mejores(derecha)

	pie("Versión %s  ·  FLECHAS o ratón para moverte, ENTER para elegir" % Gestor.VERSION)
	_boton_jugar.grab_focus()


## ESC en el menú principal no cierra el juego (para eso está SALIR): devuelve el
## foco al botón JUGAR, que es lo que uno espera al pulsar ESC.
func al_pulsar_escape() -> void:
	if _boton_jugar != null:
		_boton_jugar.grab_focus()


# ---------------------------------------------------------------------------
# Montaje
# ---------------------------------------------------------------------------

func _boton_menu(padre: Node, texto: String, accion: Callable, destacado := false) -> Button:
	var nuevo := boton(texto, accion, destacado)
	nuevo.custom_minimum_size = Vector2(360, 50)
	nuevo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padre.add_child(nuevo)
	return nuevo


func _ir_a(ruta: String) -> void:
	ir_a(ruta)


func _ficha_de_perfil(padre: Node) -> void:
	var caja := anadir_panel(padre, "Tu perfil")
	var apodo := Label.new()
	apodo.name = "Apodo"
	apodo.text = str(datos.get("nombre", "Jugador"))
	apodo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Estilo.estilizar_titulo(apodo, Estilo.SUBTITULO)
	apodo.add_theme_color_override("font_color", Estilo.ACENTO)
	caja.add_child(apodo)
	caja.add_child(fila_de_datos("Partidas jugadas", str(int(datos.get("partidas", 0)))))
	caja.add_child(fila_de_datos(
		"Mejor puntuación", "%d puntos" % int(datos.get("record_puntos", 0))
	))
	caja.add_child(fila_de_datos(
		"Mayor longitud", "%d segmentos" % int(datos.get("record_longitud", 0))
	))
	caja.add_child(fila_de_datos(
		"Tiempo jugado", Records.texto_tiempo(float(datos.get("tiempo", 0.0)))
	))
	caja.add_child(fila_de_datos(
		"Piel actual",
		"%s · %s" % [
			Pieles.nombre_paleta(int(datos.get("paleta", 0))),
			Pieles.nombre_patron(int(datos.get("patron", 0))),
		]
	))
	caja.add_child(fila_de_datos(
		"Logros", "%d de %d" % [_logros_conseguidos(), Pieles.logros.size()]
	))


func _ficha_de_mejores(padre: Node) -> void:
	var caja := anadir_panel(padre, "Tus mejores partidas")
	var mejores: Array = datos.get("mejores", []) as Array
	if mejores.is_empty():
		caja.add_child(etiqueta("Todavía no hay partidas guardadas. ¡A por la primera!"))
		return
	for i in mini(mejores.size(), 3):
		var partida: Dictionary = mejores[i]
		caja.add_child(fila_de_datos(
			"%d. %s" % [i + 1, str(partida.get("fecha", ""))],
			"%d pts · %d de largo" % [int(partida.get("puntos", 0)), int(partida.get("longitud", 0))]
		))


## Cuántos logros tiene ya conseguidos (los que desbloquean pieles).
func _logros_conseguidos() -> int:
	var total := 0
	for clave in Pieles.logros.keys():
		var logro: Dictionary = Pieles.logros[clave]
		var actual := int(datos.get(str(logro.get("estadistica", "")), 0))
		if actual >= int(logro.get("cantidad", 0)):
			total += 1
	return total
