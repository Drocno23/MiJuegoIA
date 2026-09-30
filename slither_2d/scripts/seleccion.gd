class_name Seleccion
extends Pantalla
## Pantalla de **selección de piel**: vista previa del gusano girando + catálogo.
##
## NODO AL QUE SE ADJUNTA: al **Control** raíz de `escenas/Seleccion.tscn`.
##
## A la izquierda se ve el gusano con la piel elegida, dando vueltas (lo dibuja
## `vista_previa.gd` con las MISMAS funciones que usa el juego, así que es fiel).
## A la derecha, dos cuadrículas: paletas y patrones. Las que están bloqueadas
## salen apagadas con el logro que hace falta para conseguirlas.
##
## Teclas: P pasa a la siguiente paleta, O al siguiente patrón (igual que en
## partida) y ESC vuelve al menú.

var datos: Dictionary = {}

var _vista: VistaPrevia = null
var _etiqueta_piel: Label = null
var _aviso: Label = null
var _botones_paleta: Array = []
var _botones_patron: Array = []
var _tween_aviso: Tween = null


func al_abrir() -> void:
	datos = Records.cargar()
	var contenido := crear_armazon(
		"SELECCIÓN DE PIEL",
		"Elige paleta y patrón: se aplican al momento y se recuerdan para la próxima partida"
	)
	var columnas := HBoxContainer.new()
	columnas.add_theme_constant_override("separation", 22)
	columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(columnas)

	# --------------------------- vista previa -------------------------------
	var izquierda := VBoxContainer.new()
	izquierda.name = "VistaPrevia"
	izquierda.custom_minimum_size = Vector2(440, 0)
	izquierda.add_theme_constant_override("separation", 10)
	columnas.add_child(izquierda)

	var caja_vista := anadir_panel(izquierda, "Así se verá tu gusano")
	_vista = VistaPrevia.new()
	_vista.name = "Gusano"
	_vista.custom_minimum_size = Vector2(400, 380)
	caja_vista.add_child(_vista)
	_etiqueta_piel = etiqueta("", "dato")
	_etiqueta_piel.name = "Piel"
	_etiqueta_piel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja_vista.add_child(_etiqueta_piel)

	# ---------------------------- catálogo ---------------------------------
	var derecha := VBoxContainer.new()
	derecha.name = "Catalogo"
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	derecha.add_theme_constant_override("separation", 12)
	columnas.add_child(derecha)

	var caja_paletas := anadir_panel(derecha, "Paletas de color")
	var rejilla_paletas := cuadricula(3)
	caja_paletas.add_child(rejilla_paletas)
	for i in Pieles.cantidad_paletas():
		var boton_paleta := _boton_de_piel(Pieles.Tipo.PALETA, i)
		boton_paleta.pressed.connect(_elegir_paleta.bind(i))
		rejilla_paletas.add_child(boton_paleta)
		_botones_paleta.append(boton_paleta)

	var caja_patrones := anadir_panel(derecha, "Patrones de cuerpo")
	var rejilla_patrones := cuadricula(3)
	caja_patrones.add_child(rejilla_patrones)
	for i in Pieles.cantidad_patrones():
		var boton_patron := _boton_de_piel(Pieles.Tipo.PATRON, i)
		boton_patron.pressed.connect(_elegir_patron.bind(i))
		rejilla_patrones.add_child(boton_patron)
		_botones_patron.append(boton_patron)

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 10)
	acciones.size_flags_vertical = Control.SIZE_EXPAND_FILL
	derecha.add_child(acciones)
	var boton_azar := boton("PIEL AL AZAR", _piel_al_azar)
	boton_azar.custom_minimum_size = Vector2(0, 46)
	boton_azar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acciones.add_child(boton_azar)
	var boton_volver := boton("VOLVER AL MENÚ", ir_al_menu, true)
	boton_volver.custom_minimum_size = Vector2(0, 46)
	boton_volver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acciones.add_child(boton_volver)

	_aviso = etiqueta("", "dato")
	_aviso.name = "Aviso"
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.modulate.a = 0.0
	derecha.add_child(_aviso)

	_refrescar()
	pie(_texto_desbloqueos())


func _input(evento: InputEvent) -> void:
	super._input(evento)
	var tecla := evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode == KEY_P:
		_elegir_paleta(Pieles.siguiente(Pieles.Tipo.PALETA, int(datos.get("paleta", 0)), datos))
	elif tecla.physical_keycode == KEY_O:
		_elegir_patron(Pieles.siguiente(Pieles.Tipo.PATRON, int(datos.get("patron", 0)), datos))


func al_pulsar_escape() -> void:
	ir_al_menu()


# ---------------------------------------------------------------------------
# Botones del catálogo
# ---------------------------------------------------------------------------

## Botón de una paleta o un patrón: nombre + requisito si está bloqueada.
func _boton_de_piel(tipo: int, indice: int) -> Button:
	var nuevo := boton(_texto_de_piel(tipo, indice, false), Callable())
	nuevo.custom_minimum_size = Vector2(190, 66)
	nuevo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nuevo.disabled = not Pieles.desbloqueada(tipo, indice, datos)
	return nuevo


## Texto de un botón de piel: "✔  Nombre" si es la elegida y, debajo, el requisito
## que falta para las que están bloqueadas.
func _texto_de_piel(tipo: int, indice: int, elegida: bool) -> String:
	var nombre := Pieles.nombre_paleta(indice) if tipo == Pieles.Tipo.PALETA \
		else Pieles.nombre_patron(indice)
	if elegida:
		nombre = "✔  " + nombre
	var requisito := Pieles.requisito(tipo, indice)
	return "%s\n%s" % [nombre, requisito] if requisito != "" else nombre


func _elegir_paleta(indice: int) -> void:
	if not Pieles.desbloqueada(Pieles.Tipo.PALETA, indice, datos):
		_mostrar_aviso(Pieles.requisito(Pieles.Tipo.PALETA, indice))
		return
	datos["paleta"] = indice
	_guardar_y_refrescar(Pieles.nombre_paleta(indice))


func _elegir_patron(indice: int) -> void:
	if not Pieles.desbloqueada(Pieles.Tipo.PATRON, indice, datos):
		_mostrar_aviso(Pieles.requisito(Pieles.Tipo.PATRON, indice))
		return
	datos["patron"] = indice
	_guardar_y_refrescar(Pieles.nombre_patron(indice))


## Elige al azar una paleta y un patrón de los que ya tienes desbloqueados.
func _piel_al_azar() -> void:
	var paletas := Pieles.desbloqueadas(Pieles.Tipo.PALETA, datos)
	var patrones := Pieles.desbloqueadas(Pieles.Tipo.PATRON, datos)
	if paletas.is_empty() or patrones.is_empty():
		return
	datos["paleta"] = paletas[randi() % paletas.size()]
	datos["patron"] = patrones[randi() % patrones.size()]
	_guardar_y_refrescar("al azar")


func _guardar_y_refrescar(motivo: String) -> void:
	Records.guardar(datos)
	_refrescar()
	_mostrar_aviso("Piel aplicada: %s  ·  %s" % [
		Pieles.nombre_paleta(int(datos.get("paleta", 0))),
		Pieles.nombre_patron(int(datos.get("patron", 0))),
	])
	if motivo != "":
		pie(_texto_desbloqueos())


## Vuelve a pintar los botones (marca la elegida) y la vista previa.
func _refrescar() -> void:
	var paleta := int(datos.get("paleta", 0))
	var patron := int(datos.get("patron", 0))
	if _vista != null:
		_vista.configurar(paleta, patron)
	if _etiqueta_piel != null:
		_etiqueta_piel.text = "%s  ·  %s" % [
			Pieles.nombre_paleta(paleta), Pieles.nombre_patron(patron),
		]
	for i in _botones_paleta.size():
		var elegida := i == paleta
		var boton_paleta := _botones_paleta[i] as Button
		boton_paleta.text = _texto_de_piel(Pieles.Tipo.PALETA, i, elegida)
		boton_paleta.set_meta("destacado", elegida)
		Estilo.estilizar_boton(boton_paleta, elegida)
	for i in _botones_patron.size():
		var elegido := i == patron
		var boton_patron := _botones_patron[i] as Button
		boton_patron.text = _texto_de_piel(Pieles.Tipo.PATRON, i, elegido)
		boton_patron.set_meta("destacado", elegido)
		Estilo.estilizar_boton(boton_patron, elegido)


func _mostrar_aviso(texto: String) -> void:
	if _aviso == null or texto == "":
		return
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	if _tween_aviso != null and _tween_aviso.is_valid():
		_tween_aviso.kill()
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(2.0)
	_tween_aviso.tween_property(_aviso, "modulate:a", 0.0, 1.0)


func _texto_desbloqueos() -> String:
	var paletas := Pieles.desbloqueadas(Pieles.Tipo.PALETA, datos).size()
	var patrones := Pieles.desbloqueadas(Pieles.Tipo.PATRON, datos).size()
	return "Desbloqueadas: %d de %d paletas  ·  %d de %d patrones  ·  P y O cambian en partida" % [
		paletas, Pieles.cantidad_paletas(), patrones, Pieles.cantidad_patrones(),
	]
