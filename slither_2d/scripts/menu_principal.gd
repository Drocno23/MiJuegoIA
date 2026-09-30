class_name MenuPrincipal
extends Pantalla
## Menú principal: **es la primera pantalla del juego** (ya no hay pantalla de
## carga) y la puerta de entrada a todas las demás.
##
## NODO AL QUE SE ADJUNTA: al **Control** raíz de `escenas/MenuPrincipal.tscn`.
##
## A la izquierda, la lista de botones (JUGAR y compañía); a la derecha, una ficha
## con tu perfil y tus mejores partidas. Los botones se recorren con las flechas y
## con ENTER/TAB, además del ratón y del dedo.
##
## ¿POR QUÉ NO HAY PANTALLA DE CARGA? Porque no hacía falta: aquí todo se genera en
## el momento (los gusanos se dibujan, los sonidos se sintetizan) y no hay archivos
## que descargar. En vez de una barra que no mide nada, el menú **aparece animado**
## mientras `_precalentar()` deja listas las escenas del juego y los sonidos de la
## interfaz. Además, la introducción se puede saltar con cualquier tecla o toque.

## ¿Ya se ha visto el menú en esta sesión? La introducción completa se hace una vez;
## al volver de una partida o de otra pantalla basta con un fundido corto.
static var _ya_presentado := false

var datos: Dictionary = {}

var _boton_jugar: Button = null
var _botones_menu: Array[Button] = []
var _paneles: Array[PanelContainer] = []
var _titulo: Label = null
var _regla: ColorRect = null
var _subtitulo: Label = null
var _tween_intro: Tween = null
var _intro_activo := false


func al_abrir() -> void:
	# Los ajustes de pantalla se aplican aquí: el menú es lo primero que se ve.
	Ajustes.aplicar_pantalla(Ajustes.cargar())
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

	pie("Versión %s  ·  Toca un botón, o muévete con las flechas y ENTER" % Gestor.VERSION)
	_boton_jugar.grab_focus()
	_introduccion()
	_precalentar()


func _input(evento: InputEvent) -> void:
	# Cualquier tecla o toque durante la introducción la termina de golpe.
	if _intro_activo and evento.is_pressed() and _es_entrada_de_usuario(evento):
		_saltar_introduccion()
	super._input(evento)


## ¿Es una tecla, un clic o un toque? (los eventos de movimiento no cuentan)
func _es_entrada_de_usuario(evento: InputEvent) -> bool:
	return (
		evento is InputEventKey
		or evento is InputEventMouseButton
		or evento is InputEventScreenTouch
	)


## ESC en el menú principal no cierra el juego (para eso está SALIR): devuelve el
## foco al botón JUGAR, que es lo que uno espera al pulsar ESC.
func al_pulsar_escape() -> void:
	_saltar_introduccion()
	if _boton_jugar != null:
		_boton_jugar.grab_focus()


# ---------------------------------------------------------------------------
# Lo que antes hacía la pantalla de carga, ahora sin que se note
# ---------------------------------------------------------------------------

## Prepara en segundo plano lo que hace falta para jugar: las escenas del juego y
## los sonidos de la interfaz. Al ir después de montar el menú, la primera imagen
## aparece ya en el primer frame (nada de esperas ni de barras de progreso).
func _precalentar() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	ResourceLoader.load("res://escenas/Gusano.tscn")
	ResourceLoader.load("res://escenas/GusanoCPU.tscn")
	ResourceLoader.load("res://escenas/Comida.tscn")
	Sonido.generar_efecto("blip")
	Sonido.generar_efecto("clic")


# ---------------------------------------------------------------------------
# Introducción animada (sustituye a la pantalla de carga)
# ---------------------------------------------------------------------------

## El título entra con un golpe suave y los botones y las fichas aparecen uno
## detrás de otro. Es corta (menos de un segundo) y se puede saltar.
func _introduccion() -> void:
	_intro_activo = true
	# Dos frames: hasta que los contenedores no colocan a sus hijos no se sabe el
	# tamaño real de cada cosa (y el "pivote" de la escala depende de eso).
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	# Si mientras esperábamos el jugador ya ha tocado algo, la introducción se salta:
	# no hay nada que animar porque todo está ya en su sitio.
	if not _intro_activo:
		return
	_titulo = find_child("Titulo", true, false) as Label
	_regla = find_child("Regla", true, false) as ColorRect
	_subtitulo = find_child("Subtitulo", true, false) as Label

	if _ya_presentado:
		# Segunda visita (volver de una partida, de Opciones...): sin baile, solo un
		# fundido corto para que el cambio de pantalla no sea brusco.
		_aparecer_rapido()
		return
	_ya_presentado = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _titulo != null:
		_titulo.pivot_offset = _titulo.size * 0.5
		_titulo.scale = Vector2(0.82, 0.82)
		_titulo.modulate.a = 0.0
		tween.tween_property(_titulo, "scale", Vector2.ONE, 0.45)
		tween.tween_property(_titulo, "modulate:a", 1.0, 0.30)
	if _regla != null:
		_regla.pivot_offset = _regla.size * Vector2(0.0, 0.5)
		_regla.scale.x = 0.0
		tween.tween_property(_regla, "scale:x", 1.0, 0.40).set_delay(0.15)
	if _subtitulo != null:
		_subtitulo.modulate.a = 0.0
		tween.tween_property(_subtitulo, "modulate:a", 1.0, 0.35).set_delay(0.20)

	var retraso := 0.25
	for i in _botones_menu.size():
		var boton_menu := _botones_menu[i]
		boton_menu.pivot_offset = boton_menu.size * 0.5
		boton_menu.modulate.a = 0.0
		boton_menu.scale = Vector2(0.96, 0.96)
		tween.tween_property(boton_menu, "modulate:a", 1.0, 0.25).set_delay(retraso)
		tween.tween_property(boton_menu, "scale", Vector2.ONE, 0.25).set_delay(retraso)
		retraso += 0.05
	for i in _paneles.size():
		var panel := _paneles[i]
		panel.modulate.a = 0.0
		tween.tween_property(panel, "modulate:a", 1.0, 0.35).set_delay(0.35 + 0.10 * i)

	_tween_intro = tween
	tween.chain().tween_callback(_terminar_introduccion)


## Fundido corto para cuando el menú ya se ha presentado antes en esta sesión.
func _aparecer_rapido() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	_poner_todo_en_su_sitio()
	for nodo in [_titulo, _subtitulo] + _botones_menu + _paneles:
		var control := nodo as Control
		if control == null:
			continue
		control.modulate.a = 0.0
		tween.tween_property(control, "modulate:a", 1.0, 0.18)
	tween.chain().tween_callback(_terminar_introduccion)


## Deja todo en su sitio (al acabar o al saltar la introducción).
func _terminar_introduccion() -> void:
	_intro_activo = false
	_tween_intro = null
	_poner_todo_en_su_sitio()


## Termina la introducción ya mismo (el jugador ha pulsado algo).
func _saltar_introduccion() -> void:
	if not _intro_activo:
		return
	if _tween_intro != null and _tween_intro.is_valid():
		_tween_intro.kill()
	_intro_activo = false
	_tween_intro = null
	_poner_todo_en_su_sitio()


func _poner_todo_en_su_sitio() -> void:
	for nodo in [_titulo, _subtitulo, _regla] + _botones_menu + _paneles:
		var control := nodo as Control
		if control == null:
			continue
		control.modulate.a = 1.0
		control.scale = Vector2.ONE


# ---------------------------------------------------------------------------
# Montaje
# ---------------------------------------------------------------------------

func _boton_menu(padre: Node, texto: String, accion: Callable, destacado := false) -> Button:
	var nuevo := boton(texto, accion, destacado)
	# 58 px de alto: cómodo para el dedo en un móvil.
	nuevo.custom_minimum_size = Vector2(360, 58)
	nuevo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padre.add_child(nuevo)
	_botones_menu.append(nuevo)
	return nuevo


func _ir_a(ruta: String) -> void:
	ir_a(ruta)


func _ficha_de_perfil(padre: Node) -> void:
	var caja := anadir_panel(padre, "Tu perfil")
	_paneles.append(caja.get_parent() as PanelContainer)
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
	_paneles.append(caja.get_parent() as PanelContainer)
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
