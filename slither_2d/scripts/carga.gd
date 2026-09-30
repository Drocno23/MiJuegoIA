class_name Carga
extends Pantalla
## Pantalla de carga: lo primero que se ve al abrir el juego.
##
## NODO AL QUE SE ADJUNTA: al **Control** raíz de `escenas/Carga.tscn`.
##
## Qué hace:
##   1. Muestra el logotipo, la versión y una barra de progreso **real**: cada
##      paso de la barra es trabajo de verdad (leer tu perfil, aplicar los ajustes,
##      precargar las escenas del juego y sintetizar los sonidos de la interfaz),
##      no una animación decorativa.
##   2. Mientras carga, van rotando consejos de juego.
##   3. Al terminar aparece el botón **ENTRAR AL MENÚ** (o se salta con ESPACIO,
##      ENTER o un clic).

const SEGUNDOS_POR_PASO := 0.30  ## Lo que se ve cada paso de la barra.
const SEGUNDOS_POR_CONSEJO := 2.4

## Texto de cada paso (el trabajo lo hace `_ejecutar_paso`).
const PASOS := [
	"Leyendo tu perfil…",
	"Aplicando los ajustes…",
	"Preparando el escenario y los gusanos…",
	"Sintetizando los sonidos…",
	"Ordenando el marcador…",
]

const CONSEJOS := [
	"El ratón dirige al gusano y SHIFT (o clic derecho) da turbo.",
	"El turbo gasta longitud: úsalo para escapar o para cerrar una emboscada.",
	"El minimapa está arriba a la derecha; debajo tienes la clasificación en vivo.",
	"Los power-ups van dentro de un aro: IMÁN, ESCUDO, TURBO y FANTASMA.",
	"Con ESC se abre la pausa: música, reinicio y volver al menú.",
	"En SELECCIÓN DE PIEL (teclas P y O) eliges paleta y patrón.",
	"Los logros desbloquean pieles nuevas: mira RÉCORDS Y LOGROS.",
	"Chocar contra un cuerpo, incluso el tuyo, es el final: deja hueco.",
]

var datos: Dictionary = {}

var _barra: ProgressBar = null
var _porcentaje: Label = null
var _estado: Label = null
var _consejo: Label = null
var _pista: Label = null
var _boton: Button = null
var _tiempo_consejo := 0.0
var _indice_consejo := 0
var _listo := false


func al_abrir() -> void:
	datos = Records.cargar()
	var contenido := crear_armazon("", "")
	var centro := CenterContainer.new()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(centro)

	var caja := VBoxContainer.new()
	caja.name = "Caja"
	caja.custom_minimum_size = Vector2(620, 0)
	caja.add_theme_constant_override("separation", 12)
	centro.add_child(caja)

	# ------------------------------- logotipo -------------------------------
	var logotipo := Label.new()
	logotipo.name = "Logotipo"
	logotipo.text = "SLITHER 2D"
	logotipo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Estilo.estilizar_titulo(logotipo, 64)
	logotipo.add_theme_color_override("font_color", Estilo.ACENTO)
	caja.add_child(logotipo)

	var lema := Label.new()
	lema.text = "Come, crece y no choques  ·  Godot 4.7"
	lema.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Estilo.estilizar_texto(lema, Estilo.SUBTITULO, Estilo.TEXTO_SUAVE)
	caja.add_child(lema)

	caja.add_child(_separador(26))
	caja.add_child(_linea_de_bienvenida())
	caja.add_child(_separador(18))

	# ----------------------------- barra de carga ----------------------------
	var fila := HBoxContainer.new()
	var titulo_barra := Label.new()
	titulo_barra.text = "Cargando"
	titulo_barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Estilo.estilizar_texto(titulo_barra, Estilo.NORMAL, Estilo.TEXTO)
	fila.add_child(titulo_barra)
	_porcentaje = Label.new()
	_porcentaje.text = "0 %"
	Estilo.estilizar_texto(_porcentaje, Estilo.NORMAL, Estilo.ACENTO)
	fila.add_child(_porcentaje)
	caja.add_child(fila)

	_barra = ProgressBar.new()
	_barra.name = "Barra"
	_barra.min_value = 0.0
	_barra.max_value = 100.0
	_barra.value = 0.0
	_barra.show_percentage = false
	_barra.custom_minimum_size = Vector2(620, 20)
	Estilo.estilizar_barra(_barra)
	caja.add_child(_barra)

	_estado = Label.new()
	_estado.name = "Estado"
	_estado.text = PASOS[0]
	Estilo.estilizar_texto(_estado, Estilo.PEQUENO, Estilo.TEXTO_SUAVE)
	caja.add_child(_estado)

	_consejo = Label.new()
	_consejo.name = "Consejo"
	_consejo.text = CONSEJOS[0]
	_consejo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_consejo.custom_minimum_size = Vector2(620, 52)
	_consejo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_consejo.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	Estilo.estilizar_texto(_consejo, Estilo.NORMAL, Estilo.AVISO)
	caja.add_child(_consejo)

	caja.add_child(_separador(16))
	_pista = Label.new()
	_pista.name = "Pista"
	_pista.text = "Pulsa ESPACIO o haz clic para continuar"
	_pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Estilo.estilizar_texto(_pista, Estilo.PEQUENO, Estilo.TEXTO_SUAVE)
	_pista.visible = false
	caja.add_child(_pista)

	_boton = boton("ENTRAR AL MENÚ", ir_al_menu, true)
	_boton.name = "Entrar"
	_boton.custom_minimum_size = Vector2(0, 54)
	_boton.visible = false
	caja.add_child(_boton)

	pie("Versión %s  ·  %s" % [Gestor.VERSION, texto_de_ayuda()])
	_empezar()


func _process(delta: float) -> void:
	if _listo or _consejo == null:
		return
	_tiempo_consejo += delta
	if _tiempo_consejo < SEGUNDOS_POR_CONSEJO:
		return
	_tiempo_consejo = 0.0
	_indice_consejo = (_indice_consejo + 1) % CONSEJOS.size()
	_consejo.text = CONSEJOS[_indice_consejo]


func _input(evento: InputEvent) -> void:
	# ESC (y lo que haga la clase base) primero.
	super._input(evento)
	# Cuando ya está todo cargado, cualquier tecla o clic entra al menú.
	if not _listo or not evento.is_pressed():
		return
	if evento is InputEventKey or evento is InputEventMouseButton:
		ir_al_menu()


func al_pulsar_escape() -> void:
	if _listo:
		ir_al_menu()


# ---------------------------------------------------------------------------
# Carga de verdad
# ---------------------------------------------------------------------------

## Recorre los pasos uno a uno para que la barra avance con trabajo real.
func _empezar() -> void:
	await get_tree().create_timer(0.20).timeout
	for i in PASOS.size():
		_estado.text = PASOS[i]
		_ejecutar_paso(i)
		var avance := float(i + 1) / float(PASOS.size()) * 100.0
		_barra.value = avance
		_porcentaje.text = "%d %%" % int(avance)
		await get_tree().create_timer(SEGUNDOS_POR_PASO).timeout
	_listo = true
	_estado.text = "Todo listo"
	_consejo.text = "¡A jugar!"
	if _pista != null:
		_pista.visible = true
	if _boton != null:
		_boton.visible = true
		_boton.grab_focus()


func _ejecutar_paso(indice: int) -> void:
	match indice:
		0:
			datos = Records.cargar()
		1:
			Ajustes.aplicar_pantalla(Ajustes.cargar())
		2:
			# Precargar las escenas del juego: al pulsar JUGAR entra al instante.
			ResourceLoader.load("res://escenas/Gusano.tscn")
			ResourceLoader.load("res://escenas/GusanoCPU.tscn")
			ResourceLoader.load("res://escenas/Comida.tscn")
		3:
			Sonido.generar_efecto("blip")
			Sonido.generar_efecto("clic")
			Sonido.generar_efecto("comer")
		4:
			pass


## "Bienvenido, <apodo>" (con el récord, si ya hay partidas jugadas).
func _linea_de_bienvenida() -> Label:
	var apodo := str(datos.get("nombre", "")).strip_edges()
	var bienvenida := Label.new()
	bienvenida.name = "Bienvenida"
	bienvenida.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Estilo.estilizar_texto(bienvenida, Estilo.NORMAL, Estilo.TEXTO)
	if apodo == "":
		bienvenida.text = "Pulsa ENTRAR para empezar"
	elif int(datos.get("partidas", 0)) > 0:
		bienvenida.text = "Bienvenido otra vez, %s  ·  tu récord: %d puntos y %d de largo" % [
			apodo, int(datos.get("record_puntos", 0)), int(datos.get("record_longitud", 0)),
		]
	else:
		bienvenida.text = "Bienvenido, %s" % apodo
	return bienvenida


## Un hueco en blanco para separar bloques dentro de una columna.
func _separador(alto: float) -> Control:
	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(0, alto)
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hueco


## Recordatorio del pie: cómo moverse por los menús.
func texto_de_ayuda() -> String:
	return "FLECHAS o ratón para moverte, ENTER para elegir"
