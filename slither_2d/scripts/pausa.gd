class_name Pausa
extends Pantalla
## Menú de **PAUSA**: aparece encima de la partida cuando pulsas ESC.
##
## NODO AL QUE SE ADJUNTA: al **Control** raíz de `escenas/Pausa.tscn`, que
## `escenas/Main.tscn` instala dentro de su `HUD` (nodo "Pausa").
##
## Dos detalles importantes de cómo está montado:
##   * El nodo raíz lleva `process_mode = ALWAYS`, así que sus botones siguen
##     funcionando aunque el árbol esté en pausa (`get_tree().paused = true`).
##   * El fondo es un **velo translúcido** (`velado = true`), no el fondo opaco de
##     los demás menús: así se sigue viendo la partida por detrás.
##
## Este script NO decide nada de la partida: emite señales y `main.gd` hace el
## trabajo (continuar, reiniciar, volver al menú o salir del juego).

signal continuar
signal reiniciar
signal al_menu
signal salir_juego

var _sonido: Sonido = null

var _boton_continuar: Button = null
var _boton_musica: Button = null
var _boton_silencio: Button = null


## Esto corre ANTES de que `pantalla.gd` monte nada, así que el velo translúcido y
## el `process_mode` ya están puestos cuando se crea el fondo.
func _preparar() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	velado = true
	visible = false


## `main.gd` le pasa el nodo de sonido de la partida para poder cambiar la música
## y el silencio sin salir del juego.
func configurar(sonido: Sonido) -> void:
	_sonido = sonido
	_refrescar_audio()


func abrir() -> void:
	visible = true
	_refrescar_audio()
	if _boton_continuar != null:
		_boton_continuar.grab_focus()


func cerrar() -> void:
	visible = false


func al_abrir() -> void:
	var contenido := crear_armazon("", "")
	var centro := CenterContainer.new()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(centro)

	var columna := VBoxContainer.new()
	columna.name = "Pausa"
	columna.custom_minimum_size = Vector2(520, 0)
	columna.add_theme_constant_override("separation", 10)
	centro.add_child(columna)

	var titulo := Label.new()
	titulo.text = "PAUSA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Estilo.estilizar_titulo(titulo, 52)
	titulo.add_theme_color_override("font_color", Estilo.ACENTO)
	columna.add_child(titulo)

	var subtitulo := Label.new()
	subtitulo.text = "La partida sigue tal cual: sigue cuando quieras"
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Estilo.estilizar_texto(subtitulo, Estilo.PEQUENO, Estilo.TEXTO_SUAVE)
	columna.add_child(subtitulo)

	var caja_partida := anadir_panel(columna, "Partida")
	_boton_continuar = boton("CONTINUAR (ESC)", func(): continuar.emit(), true)
	_boton_continuar.custom_minimum_size = Vector2(0, 50)
	caja_partida.add_child(_boton_continuar)
	var reiniciar_boton := boton("REINICIAR PARTIDA", func(): reiniciar.emit())
	reiniciar_boton.custom_minimum_size = Vector2(0, 46)
	caja_partida.add_child(reiniciar_boton)

	var caja_audio := anadir_panel(columna, "Sonido")
	var fila_musica := HBoxContainer.new()
	fila_musica.add_theme_constant_override("separation", 10)
	var rotulo_musica := etiqueta("Música (tecla N)")
	rotulo_musica.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_musica.add_child(rotulo_musica)
	_boton_musica = boton("", _cambiar_musica)
	_boton_musica.custom_minimum_size = Vector2(190, 42)
	fila_musica.add_child(_boton_musica)
	caja_audio.add_child(fila_musica)

	var fila_silencio := HBoxContainer.new()
	fila_silencio.add_theme_constant_override("separation", 10)
	var rotulo_silencio := etiqueta("Silencio total (tecla M)")
	rotulo_silencio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_silencio.add_child(rotulo_silencio)
	_boton_silencio = boton("", _alternar_silencio)
	_boton_silencio.custom_minimum_size = Vector2(190, 42)
	fila_silencio.add_child(_boton_silencio)
	caja_audio.add_child(fila_silencio)

	var caja_salir := anadir_panel(columna, "Dejar la partida")
	var boton_menu := boton("MENÚ PRINCIPAL (se pierde la partida)", func(): al_menu.emit())
	boton_menu.custom_minimum_size = Vector2(0, 46)
	caja_salir.add_child(boton_menu)
	var boton_salir := boton("SALIR DEL JUEGO", func(): salir_juego.emit())
	Estilo.estilizar_boton(boton_salir, true, Estilo.PELIGRO)
	boton_salir.custom_minimum_size = Vector2(0, 46)
	caja_salir.add_child(boton_salir)

	pie("Pulsa ESC para continuar la partida donde la dejaste")


func al_pulsar_escape() -> void:
	continuar.emit()


# ---------------------------------------------------------------------------
# Audio rápido (sin salir de la partida)
# ---------------------------------------------------------------------------

func _cambiar_musica() -> void:
	if _sonido == null:
		return
	_sonido.alternar_musica()
	_refrescar_audio()
	_tocar("clic")


func _alternar_silencio() -> void:
	if _sonido == null:
		return
	_sonido.alternar_silencio()
	_refrescar_audio()
	_tocar("clic")


func _refrescar_audio() -> void:
	if _boton_musica != null:
		var nivel := _sonido.nivel_musica() if _sonido != null else 2
		_boton_musica.text = Sonido.nombre_nivel_musica(nivel)
	if _boton_silencio != null:
		var callado := _sonido.silenciado() if _sonido != null else false
		_boton_silencio.text = "SÍ (sin sonido)" if callado else "NO (con sonido)"
