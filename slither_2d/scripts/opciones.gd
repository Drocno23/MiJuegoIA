class_name Opciones
extends Pantalla
## Pantalla de **opciones**: sonido, pantalla y extras.
##
## NODO AL QUE SE ADJUNTA: al **Control** raíz de `escenas/Opciones.tscn`.
##
## Todo lo que se toca aquí se guarda al momento en `user://ajustes.cfg` (vía
## `ajustes.gd`), así que no hay botón de "guardar": lo que ves es lo que hay.
## Los valores de audio afectan también a los sonidos de este menú, de modo que
## el cambio se oye mientras se arrastra el deslizador.

var _valores: Dictionary = {}

var _boton_silencio: Button = null
var _boton_musica: Button = null
var _boton_completa: Button = null
var _boton_fps: Button = null
var _deslizador_efectos: HSlider = null
var _deslizador_musica: HSlider = null
var _etiqueta_efectos: Label = null
var _etiqueta_musica: Label = null
var _etiqueta_fps: Label = null


func al_abrir() -> void:
	_valores = Ajustes.cargar()
	var contenido := crear_armazon(
		"OPCIONES",
		"Se aplican al momento y se guardan solas en user://ajustes.cfg"
	)
	var columnas := HBoxContainer.new()
	columnas.add_theme_constant_override("separation", 22)
	columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(columnas)

	var izquierda := VBoxContainer.new()
	izquierda.name = "Sonido"
	izquierda.custom_minimum_size = Vector2(600, 0)
	izquierda.add_theme_constant_override("separation", 10)
	columnas.add_child(izquierda)
	_montar_sonido(izquierda)

	var derecha := VBoxContainer.new()
	derecha.name = "Pantalla"
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	derecha.add_theme_constant_override("separation", 10)
	columnas.add_child(derecha)
	_montar_pantalla(derecha)

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 10)
	var restablecer := boton("VALORES POR DEFECTO", _restablecer)
	restablecer.custom_minimum_size = Vector2(0, 48)
	restablecer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acciones.add_child(restablecer)
	var volver := boton("VOLVER AL MENÚ", ir_al_menu, true)
	volver.custom_minimum_size = Vector2(0, 48)
	volver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acciones.add_child(volver)
	contenido.add_child(acciones)
	pie("En partida: M silencia, N cambia la música, ESC abre la pausa")


func _process(_delta: float) -> void:
	if _etiqueta_fps != null and _etiqueta_fps.visible:
		_etiqueta_fps.text = "%d FPS" % Engine.get_frames_per_second()


func al_pulsar_escape() -> void:
	ir_al_menu()


# ---------------------------------------------------------------------------
# Montaje
# ---------------------------------------------------------------------------

## Fila de opción: el rótulo a la izquierda y hueco a la derecha para el control.
func _fila(padre: Node, rotulo: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	var texto := etiqueta(rotulo)
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(texto)
	padre.add_child(fila)
	return fila


## Botón que enseña el valor actual de un ajuste (se pulsa para cambiarlo).
func _boton_de_valor(texto: String, accion: Callable) -> Button:
	var nuevo := boton(texto, accion)
	nuevo.custom_minimum_size = Vector2(200, 40)
	return nuevo


## Deslizador de decibelios ya preparado (‑40 dB a +6 dB).
func _deslizador(valor: float, accion: Callable) -> HSlider:
	var nuevo := HSlider.new()
	nuevo.min_value = -40.0
	nuevo.max_value = 6.0
	nuevo.step = 1.0
	nuevo.value = valor
	nuevo.custom_minimum_size = Vector2(220, 0)
	Estilo.estilizar_deslizador(nuevo)
	nuevo.value_changed.connect(accion)
	return nuevo


func _montar_sonido(padre: Node) -> void:
	var caja := anadir_panel(padre, "Sonido")

	_boton_silencio = _boton_de_valor(_texto_silencio(), _alternar_silencio)
	_fila(caja, "Silencio total (tecla M en partida)").add_child(_boton_silencio)

	_boton_musica = _boton_de_valor(_texto_musica(), _cambiar_musica)
	_fila(caja, "Música de fondo (tecla N en partida)").add_child(_boton_musica)

	var fila_efectos := _fila(caja, "Volumen de los efectos")
	_deslizador_efectos = _deslizador(float(_valores.get("volumen_efectos", 0.0)),
		_cambiar_volumen_efectos)
	fila_efectos.add_child(_deslizador_efectos)
	_etiqueta_efectos = etiqueta(_texto_db(_deslizador_efectos.value), "dato")
	_etiqueta_efectos.custom_minimum_size = Vector2(70, 0)
	_etiqueta_efectos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fila_efectos.add_child(_etiqueta_efectos)

	var fila_musica := _fila(caja, "Volumen de la música")
	_deslizador_musica = _deslizador(float(_valores.get("volumen_musica", -10.0)),
		_cambiar_volumen_musica)
	fila_musica.add_child(_deslizador_musica)
	_etiqueta_musica = etiqueta(_texto_db(_deslizador_musica.value), "dato")
	_etiqueta_musica.custom_minimum_size = Vector2(70, 0)
	_etiqueta_musica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fila_musica.add_child(_etiqueta_musica)


func _montar_pantalla(padre: Node) -> void:
	var caja := anadir_panel(padre, "Pantalla y extras")

	if OS.has_feature("mobile"):
		# En un móvil el juego siempre va a pantalla completa: se explica en vez de
		# ofrecer un botón que no haría nada.
		var fila_movil := _fila(caja, "Pantalla completa")
		fila_movil.add_child(etiqueta("SIEMPRE (móvil)", "dato"))
	else:
		_boton_completa = _boton_de_valor(_texto_si_no("pantalla_completa"), _alternar_completa)
		_fila(caja, "Pantalla completa").add_child(_boton_completa)

	_boton_fps = _boton_de_valor(_texto_si_no("mostrar_fps"), _alternar_fps)
	_fila(caja, "Mostrar los FPS en partida").add_child(_boton_fps)

	_etiqueta_fps = etiqueta("%d FPS" % Engine.get_frames_per_second(), "dato")
	_etiqueta_fps.name = "ContadorFPS"
	_etiqueta_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta_fps.visible = bool(_valores.get("mostrar_fps", false))
	caja.add_child(_etiqueta_fps)

	var ficha := anadir_panel(padre, "Ficha técnica")
	ficha.add_child(fila_de_datos("Juego", "Slither 2D"))
	ficha.add_child(fila_de_datos("Versión", Gestor.VERSION))
	var motor := str(Engine.get_version_info().get("string", ""))
	ficha.add_child(fila_de_datos("Motor", "Godot %s" % motor))
	ficha.add_child(fila_de_datos("Gráficos", "GL Compatibility"))
	ficha.add_child(fila_de_datos("Idioma", "Español"))


# ---------------------------------------------------------------------------
# Acciones
# ---------------------------------------------------------------------------

func _alternar_silencio() -> void:
	_valores["silencio"] = not bool(_valores.get("silencio", false))
	_aplicar()
	_boton_silencio.text = _texto_silencio()
	if not bool(_valores["silencio"]):
		_tocar("clic")


func _cambiar_musica() -> void:
	_valores["musica"] = (int(_valores.get("musica", 2)) + 1) % 3
	_aplicar()
	_boton_musica.text = _texto_musica()


func _cambiar_volumen_efectos(valor: float) -> void:
	_valores["volumen_efectos"] = valor
	_aplicar()
	_etiqueta_efectos.text = _texto_db(valor)
	_tocar("blip")


func _cambiar_volumen_musica(valor: float) -> void:
	_valores["volumen_musica"] = valor
	_aplicar()
	_etiqueta_musica.text = _texto_db(valor)


func _alternar_completa() -> void:
	_valores["pantalla_completa"] = not bool(_valores.get("pantalla_completa", false))
	_aplicar()
	_boton_completa.text = _texto_si_no("pantalla_completa")


func _alternar_fps() -> void:
	_valores["mostrar_fps"] = not bool(_valores.get("mostrar_fps", false))
	_aplicar()
	_boton_fps.text = _texto_si_no("mostrar_fps")
	if _etiqueta_fps != null:
		_etiqueta_fps.visible = bool(_valores["mostrar_fps"])


## Vuelve a los valores de fábrica (y los escribe en el archivo).
func _restablecer() -> void:
	_valores = Ajustes.por_defecto()
	Ajustes.guardar(_valores)
	Ajustes.aplicar_pantalla(_valores)
	refrescar_audio()
	_poner_botones_al_dia()
	if _deslizador_efectos != null:
		_deslizador_efectos.value = float(_valores.get("volumen_efectos", 0.0))
	if _deslizador_musica != null:
		_deslizador_musica.value = float(_valores.get("volumen_musica", -10.0))
	if _etiqueta_efectos != null:
		_etiqueta_efectos.text = _texto_db(float(_valores.get("volumen_efectos", 0.0)))
	if _etiqueta_musica != null:
		_etiqueta_musica.text = _texto_db(float(_valores.get("volumen_musica", -10.0)))
	_tocar("clic")


## Guarda los ajustes y los aplica en el momento (audio del menú y pantalla).
func _aplicar() -> void:
	Ajustes.guardar(_valores)
	Ajustes.aplicar_pantalla(_valores)
	refrescar_audio()


func _poner_botones_al_dia() -> void:
	if _boton_silencio != null:
		_boton_silencio.text = _texto_silencio()
	if _boton_musica != null:
		_boton_musica.text = _texto_musica()
	if _boton_completa != null:
		_boton_completa.text = _texto_si_no("pantalla_completa")
	if _boton_fps != null:
		_boton_fps.text = _texto_si_no("mostrar_fps")
	if _etiqueta_fps != null:
		_etiqueta_fps.visible = bool(_valores.get("mostrar_fps", false))


# ---------------------------------------------------------------------------
# Textos
# ---------------------------------------------------------------------------

func _texto_silencio() -> String:
	return "SÍ (sin sonido)" if bool(_valores.get("silencio", false)) else "NO (con sonido)"


func _texto_musica() -> String:
	return Sonido.nombre_nivel_musica(int(_valores.get("musica", 2)))


func _texto_si_no(clave: String) -> String:
	return "SÍ" if bool(_valores.get(clave, false)) else "NO"


func _texto_db(valor: float) -> String:
	return "%d dB" % int(valor)
