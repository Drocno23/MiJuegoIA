class_name Pantalla
extends Control
## Base de **todas las pantallas de menú**: hace el trabajo común y presta los
## ayudantes con los que cada pantalla monta su contenido.
##
## NODO AL QUE SE ADJUNTA: al **Control** raíz de cada escena de menú
## (`MenuPrincipal.tscn`, `Seleccion.tscn`, `Records.tscn`, `Opciones.tscn`,
## `ComoJugar.tscn` y `Creditos.tscn`).
##
## ¿Qué hace por ti?
##   * Pinta el fondo y añade los gusanos de adorno (`FondoMenu`).
##   * Te da los ayudantes `crear_armazon()`, `anadir_panel()`, `boton()`, etc.,
##     así que cada pantalla solo describe **qué** enseña, no **cómo** se coloca.
##     Todo va en contenedores (`VBoxContainer`, `HBoxContainer`, `GridContainer`),
##     que es lo que impide que dos textos se monten uno encima de otro.
##   * Da estilo a lo que crees (`Estilo`) y suena al pasar y al pulsar.
##   * Hace el fundido de entrada y deja el de salida a `Gestor.ir_a()`.
##   * Deja la tecla ESC a tu gusto con `al_pulsar_escape()`.
##
## OJO: **no definas `_ready()`** en las pantallas hijas; usa `al_abrir()`, que se
## llama cuando ya existe el fondo y el audio.

const MARGEN := 40.0  ## Margen exterior de todas las pantallas.
const SEPARACION := 12  ## Separación por defecto entre bloques.

## Si es `true`, el fondo es un **velo translúcido** en vez del fondo opaco con
## gusanos de adorno. Lo usa el menú de pausa, que se ve encima de la partida.
var velado := false

var _reproductor: AudioStreamPlayer = null
var _flujos: Dictionary = {}  ## nombre -> AudioStreamWAV (efectos de interfaz).
var _silencio := false
var _columna: VBoxContainer = null  ## Columna principal (cabecera + contenido + pie).
var _pie: Label = null  ## Rótulo del pie (se crea la primera vez que se usa).


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_preparar()
	_crear_fondo()
	_crear_audio()
	al_abrir()
	Estilo.estilizar_arbol(self)
	_conectar_botones()
	_aparecer()


## Las pantallas hijas sobreescriben esto si tienen que ajustar algo **antes** de
## que la pantalla se monte (por ejemplo, `pausa.gd` pone `velado = true`).
func _preparar() -> void:
	pass


## Las pantallas hijas sobreescriben esto para montar su contenido.
func al_abrir() -> void:
	pass


## Las pantallas hijas sobreescriben esto si quieren hacer algo con ESC
## (volver al menú, cerrar la pausa...).
func al_pulsar_escape() -> void:
	pass


func _input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		al_pulsar_escape()


# ---------------------------------------------------------------------------
# Cambiar de pantalla (delega en Gestor, que es quien sabe hacer el fundido)
# ---------------------------------------------------------------------------

func ir_a(ruta: String) -> void:
	Gestor.ir_a(self, ruta)


func ir_al_menu() -> void:
	Gestor.ir_al_menu(self)


func ir_al_juego() -> void:
	Gestor.ir_al_juego(self)


# ---------------------------------------------------------------------------
# Ayudantes para montar el contenido
# ---------------------------------------------------------------------------

## Monta el armazón de la pantalla: margen exterior + cabecera con el título
## (y un subtítulo opcional) + zona de contenido. Devuelve el `VBoxContainer`
## donde la pantalla va añadiendo sus bloques.
func crear_armazon(titulo: String, subtitulo := "") -> VBoxContainer:
	var margen := MarginContainer.new()
	margen.name = "Margen"
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margen.add_theme_constant_override(lado, int(MARGEN))
	add_child(margen)

	_columna = VBoxContainer.new()
	_columna.name = "Columna"
	_columna.add_theme_constant_override("separation", SEPARACION)
	margen.add_child(_columna)

	if titulo != "":
		var encabezado := Label.new()
		encabezado.name = "Titulo"
		encabezado.text = titulo
		encabezado.set_meta("estilo", "titulo")
		Estilo.estilizar_titulo(encabezado, Estilo.TITULO)
		_columna.add_child(encabezado)
		# Regla de acento bajo el título: da el aire de "juego terminado".
		var regla := ColorRect.new()
		regla.name = "Regla"
		regla.color = Estilo.ACENTO
		regla.custom_minimum_size = Vector2(120, 4)
		regla.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_columna.add_child(regla)
	if subtitulo != "":
		var sub := Label.new()
		sub.name = "Subtitulo"
		sub.text = subtitulo
		sub.set_meta("estilo", "texto")
		Estilo.estilizar_texto(sub, Estilo.SUBTITULO, Estilo.TEXTO_SUAVE)
		_columna.add_child(sub)

	var contenido := VBoxContainer.new()
	contenido.name = "Contenido"
	contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_theme_constant_override("separation", SEPARACION)
	_columna.add_child(contenido)
	return contenido


## Pone (o actualiza) la línea de pie de la pantalla: atajos, versión... Llámalo
## al final de `al_abrir()`; queda pegada abajo porque el contenido se estira.
## Se puede llamar varias veces: siempre reescribe el mismo rótulo.
func pie(texto: String) -> void:
	if _columna == null:
		return
	if _pie == null:
		_pie = Label.new()
		_pie.name = "Pie"
		_pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_pie.set_meta("estilo", "texto")
		Estilo.estilizar_texto(_pie, Estilo.PEQUENO, Estilo.TEXTO_SUAVE)
		_columna.add_child(_pie)
	_pie.text = texto


## Añade un panel (caja redondeada) al nodo que le digas y devuelve su columna
## interior. Si le pasas un `titulo`, lo pone como encabezado del panel.
func anadir_panel(padre: Node, titulo := "") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "Panel" if titulo == "" else "Panel" + titulo.capitalize().replace(" ", "")
	Estilo.estilizar_panel(panel)
	padre.add_child(panel)
	var caja := VBoxContainer.new()
	caja.name = "Caja"
	caja.add_theme_constant_override("separation", 8)
	panel.add_child(caja)
	if titulo != "":
		var encabezado := Label.new()
		encabezado.name = "Encabezado"
		encabezado.text = titulo.to_upper()
		encabezado.set_meta("estilo", "titulo")
		Estilo.estilizar_texto(encabezado, Estilo.SUBTITULO, Estilo.ACENTO)
		caja.add_child(encabezado)
	return caja


## Etiqueta suelta. `estilo` puede ser "titulo" o "dato" (o "" para texto normal).
func etiqueta(texto: String, estilo := "", tamano := 0, color := Color(0, 0, 0, 0)) -> Label:
	var nueva := Label.new()
	nueva.text = texto
	nueva.set_meta("estilo", estilo if estilo != "" else "texto")
	if estilo == "titulo":
		Estilo.estilizar_titulo(nueva, Estilo.SUBTITULO if tamano == 0 else tamano)
	elif estilo == "dato":
		Estilo.estilizar_texto(nueva, Estilo.NORMAL if tamano == 0 else tamano, Estilo.TEXTO)
	else:
		Estilo.estilizar_texto(
			nueva,
			Estilo.NORMAL if tamano == 0 else tamano,
			Estilo.TEXTO_SUAVE if color.a == 0.0 else color
		)
	return nueva


## Fila "clave .......... valor" con el valor pegado a la derecha.
func fila_de_datos(clave: String, valor: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	var izquierda := etiqueta(clave)
	izquierda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(izquierda)
	fila.add_child(etiqueta(valor, "dato"))
	return fila


## Botón ya estilizado y conectado. `destacado` lo pinta en verde (acción principal).
func boton(texto: String, accion: Callable, destacado := false) -> Button:
	var nuevo := Button.new()
	nuevo.text = texto
	nuevo.set_meta("destacado", destacado)
	Estilo.estilizar_boton(nuevo, destacado)
	if accion.is_valid():
		nuevo.pressed.connect(accion)
	return nuevo


## Barra de progreso (0..100) ya estilizada, para logros y cargas.
func barra(valor: float, color := Estilo.ACENTO) -> ProgressBar:
	var nueva := ProgressBar.new()
	nueva.min_value = 0.0
	nueva.max_value = 100.0
	nueva.value = clampf(valor, 0.0, 100.0)
	nueva.show_percentage = false
	nueva.custom_minimum_size = Vector2(120, 14)
	nueva.set_meta("color", color)
	Estilo.estilizar_barra(nueva, color)
	return nueva


## Cuadrícula de N columnas (para los botones de pieles y patrones).
func cuadricula(columnas: int) -> GridContainer:
	var rejilla := GridContainer.new()
	rejilla.columns = maxi(columnas, 1)
	rejilla.add_theme_constant_override("h_separation", 10)
	rejilla.add_theme_constant_override("v_separation", 10)
	return rejilla


## Vuelve a leer los ajustes de audio (lo llama la pantalla de Opciones).
func refrescar_audio() -> void:
	var valores := Ajustes.cargar()
	_silencio = bool(valores.get("silencio", false))
	if _reproductor != null:
		_reproductor.volume_db = float(valores.get("volumen_efectos", 0.0))


# ---------------------------------------------------------------------------
# Montaje interno
# ---------------------------------------------------------------------------

func _crear_fondo() -> void:
	if velado:
		# Menú de pausa: se sigue viendo la partida, solo se oscurece un poco.
		var velo := ColorRect.new()
		velo.name = "Velo"
		velo.color = Color(0.02, 0.03, 0.07, 0.72)
		velo.set_anchors_preset(Control.PRESET_FULL_RECT)
		velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(velo)
		return

	# 1) Color de fondo (un ColorRect que ocupa toda la pantalla).
	var fondo_color := ColorRect.new()
	fondo_color.name = "FondoColor"
	fondo_color.color = Estilo.FONDO
	fondo_color.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo_color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo_color)
	move_child(fondo_color, 0)

	# 2) Gusanos de adorno paseando por detrás.
	var fondo_vivo := FondoMenu.new()
	fondo_vivo.name = "FondoVivo"
	add_child(fondo_vivo)
	move_child(fondo_vivo, 1)


func _crear_audio() -> void:
	refrescar_audio()
	_reproductor = AudioStreamPlayer.new()
	_reproductor.name = "SonidosUI"
	_reproductor.volume_db = float(Ajustes.cargar().get("volumen_efectos", 0.0))
	add_child(_reproductor)


## Conecta el sonido a todos los botones que haya (se puede llamar varias veces:
## las conexiones repetidas se detectan con `is_connected`).
func _conectar_botones() -> void:
	for nodo in find_children("*", "Button", true, false):
		var boton := nodo as Button
		if boton == null:
			continue
		Estilo.estilizar_boton(boton, bool(boton.get_meta("destacado", false)))
		if not boton.mouse_entered.is_connected(_tocar_paso):
			boton.mouse_entered.connect(_tocar_paso)
		if not boton.focus_entered.is_connected(_tocar_paso):
			boton.focus_entered.connect(_tocar_paso)
		if not boton.pressed.is_connected(_tocar_clic):
			boton.pressed.connect(_tocar_clic)


func _aparecer() -> void:
	var fundido := ColorRect.new()
	fundido.name = Gestor.NOMBRE_FUNDIDO
	fundido.color = Color(0, 0, 0, 1)
	fundido.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundido)
	var tween := create_tween()
	tween.tween_property(fundido, "color:a", 0.0, 0.28)


# ---------------------------------------------------------------------------
# Sonidos de interfaz
# ---------------------------------------------------------------------------

func _flujo(nombre: String) -> AudioStreamWAV:
	if not _flujos.has(nombre):
		_flujos[nombre] = Sonido.generar_efecto(nombre)
	return _flujos[nombre] as AudioStreamWAV


func _tocar(nombre: String, tono: float = 1.0) -> void:
	if _reproductor == null or _silencio:
		return
	_reproductor.stream = _flujo(nombre)
	_reproductor.pitch_scale = tono * randf_range(0.98, 1.02)
	_reproductor.play()


func _tocar_paso() -> void:
	_tocar("blip")


func _tocar_clic() -> void:
	_tocar("clic")
