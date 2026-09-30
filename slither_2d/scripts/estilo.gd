class_name Estilo
extends RefCounted
## Paleta, tipografías y cajas de la interfaz: el "tema" del juego, por código.
##
## NODO AL QUE SE ADJUNTA: a ninguno. Es una clase de utilidades estáticas
## (`Estilo.caja(...)`, `Estilo.estilizar_boton(...)`), igual que `dibujo.gd`.
##
## ¿POR QUÉ NO UN Theme.tres? Un recurso `Theme` habría que escribirlo a mano y, si
## se cuela un error de formato, la interfaz entera se queda sin estilo. Con estas
## funciones el estilo se aplica en tiempo de ejecución y se ve exactamente igual.
## La ventaja añadida: todos los colores y medidas del menú están aquí, en un sitio,
## así que cambiar el aspecto del juego es cambiar este archivo.

# ---------------------------------- colores ---------------------------------
const FONDO := Color("0b1020")  ## Azul noche de todas las pantallas.
const PANEL := Color(0.06, 0.09, 0.16, 0.92)
const PANEL_CLARO := Color(0.10, 0.14, 0.24, 0.92)
const BORDE := Color(1, 1, 1, 0.12)
const TEXTO := Color("eaf1ff")
const TEXTO_SUAVE := Color(0.72, 0.78, 0.9, 1.0)
const ACENTO := Color("4be36a")  ## Verde del jugador: botones principales.
const AVISO := Color("ffd45c")  ## Ámbar: avisos y récords.
const PELIGRO := Color("ff6b6b")
const OSCURO := Color(0.03, 0.05, 0.09, 0.85)

# ---------------------------------- medidas ---------------------------------
const RADIO := 12  ## Radio de las esquinas de los paneles.
const RADIO_BOTON := 10
const MARGEN := 18.0  ## Margen interior de paneles y botones.
const TITULO := 44
const SUBTITULO := 20
const NORMAL := 16
const PEQUENO := 14
const BOTON := 20

# ------------------------------ estado interno ------------------------------
## Fuente ya creada (se crea una sola vez y se reutiliza en todas las etiquetas:
## crear una `SystemFont` por etiqueta sería un desperdicio).
static var _fuente: Font = null
static var _fuente_negrita: Font = null


## Fuente del sistema (no hay que descargar ni incluir ningún archivo .ttf).
static func fuente() -> Font:
	if _fuente == null:
		var fuente_sistema := SystemFont.new()
		fuente_sistema.font_names = PackedStringArray([
			"Noto Sans", "DejaVu Sans", "Liberation Sans", "Segoe UI", "sans-serif",
		])
		_fuente = fuente_sistema
	return _fuente


## Versión "en negrita" de la misma fuente (`FontVariation`, sin archivos extra):
## sirve para la fila del jugador en la clasificación.
static func fuente_negrita() -> Font:
	if _fuente_negrita == null:
		var variacion := FontVariation.new()
		variacion.base_font = fuente()
		variacion.variation_embolden = 0.7
		_fuente_negrita = variacion
	return _fuente_negrita


## Caja redondeada con borde y margen interior: la base de paneles y botones.
static func caja(
	relleno: Color,
	radio: int = RADIO,
	borde: float = 1.0,
	margen: float = MARGEN
) -> StyleBoxFlat:
	var caja_nueva := StyleBoxFlat.new()
	caja_nueva.bg_color = relleno
	caja_nueva.corner_radius_top_left = radio
	caja_nueva.corner_radius_top_right = radio
	caja_nueva.corner_radius_bottom_right = radio
	caja_nueva.corner_radius_bottom_left = radio
	caja_nueva.border_color = BORDE
	caja_nueva.border_width_left = int(borde)
	caja_nueva.border_width_top = int(borde)
	caja_nueva.border_width_right = int(borde)
	caja_nueva.border_width_bottom = int(borde)
	caja_nueva.content_margin_left = margen
	caja_nueva.content_margin_top = margen * 0.6
	caja_nueva.content_margin_right = margen
	caja_nueva.content_margin_bottom = margen * 0.6
	return caja_nueva


## Aplica el aspecto de "tarjeta" a un panel.
static func estilizar_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", caja(PANEL))


## Aplica el aspecto completo a un botón (normal, hover, pulsado, foco y letra).
## `destacado` lo pinta con el color de acento: para la acción principal de cada
## pantalla. `acento` cambia ese color (por ejemplo `Estilo.PELIGRO` para las
## acciones que borran algo).
static func estilizar_boton(
	boton: Button, destacado: bool = false, acento: Color = ACENTO
) -> void:
	var normal := caja(PANEL_CLARO, RADIO_BOTON, 1.0, MARGEN)
	var encima := caja(PANEL_CLARO.lightened(0.12), RADIO_BOTON, 1.0, MARGEN)
	var pulsado := caja(PANEL_CLARO.darkened(0.2), RADIO_BOTON, 1.0, MARGEN)
	var foco := caja(Color(acento.r, acento.g, acento.b, 0.10), RADIO_BOTON, 2.0, MARGEN)
	if destacado:
		normal.bg_color = Color(acento.r, acento.g, acento.b, 0.22)
		normal.border_color = acento
		encima.bg_color = Color(acento.r, acento.g, acento.b, 0.32)
		encima.border_color = acento
		pulsado.bg_color = Color(acento.r, acento.g, acento.b, 0.14)
		foco.border_color = acento
	boton.add_theme_stylebox_override("normal", normal)
	boton.add_theme_stylebox_override("hover", encima)
	boton.add_theme_stylebox_override("pressed", pulsado)
	boton.add_theme_stylebox_override("focus", foco)
	boton.add_theme_stylebox_override("disabled", caja(OSCURO, RADIO_BOTON, 1.0, MARGEN))
	boton.add_theme_font_override("font", fuente())
	boton.add_theme_font_size_override("font_size", BOTON)
	boton.add_theme_color_override("font_color", TEXTO)
	boton.add_theme_color_override("font_hover_color", acento if not destacado else TEXTO)
	boton.add_theme_color_override("font_pressed_color", TEXTO)
	boton.add_theme_color_override("font_disabled_color", TEXTO_SUAVE.darkened(0.3))
	boton.focus_mode = Control.FOCUS_ALL


## Estilo de las etiquetas de título y de texto normal.
static func estilizar_titulo(etiqueta: Label, tamano: int = TITULO) -> void:
	etiqueta.add_theme_font_override("font", fuente())
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", TEXTO)


static func estilizar_texto(
	etiqueta: Label,
	tamano: int = NORMAL,
	color: Color = TEXTO_SUAVE
) -> void:
	etiqueta.add_theme_font_override("font", fuente())
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)


## Igual que `estilizar_texto` pero en negrita: para los datos importantes
## (tu fila en la clasificación, el récord, la puntuación final...).
static func estilizar_destacado(
	etiqueta: Label, tamano: int = NORMAL, color: Color = ACENTO
) -> void:
	etiqueta.add_theme_font_override("font", fuente_negrita())
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)


## Estilo de una barra de progreso (fondo oscuro + relleno de color).
static func estilizar_barra(barra: ProgressBar, color_relleno: Color = ACENTO) -> void:
	var fondo := caja(OSCURO, 6, 0.0, 2.0)
	var relleno := caja(color_relleno, 6, 0.0, 2.0)
	barra.add_theme_stylebox_override("background", fondo)
	barra.add_theme_stylebox_override("fill", relleno)
	barra.add_theme_font_override("font", fuente())
	barra.add_theme_font_size_override("font_size", PEQUENO)
	barra.add_theme_color_override("font_color", TEXTO)


## Estilo de un deslizador (HSlider) para los volúmenes de Opciones.
static func estilizar_deslizador(deslizador: HSlider) -> void:
	deslizador.add_theme_stylebox_override("slider", caja(OSCURO, 6, 0.0, 0.0))
	deslizador.add_theme_stylebox_override("grabber_area", caja(ACENTO, 6, 0.0, 0.0))
	deslizador.add_theme_stylebox_override(
		"grabber_area_highlight", caja(ACENTO.lightened(0.25), 6, 0.0, 0.0)
	)


## Estilo de un campo de texto (el del apodo).
static func estilizar_campo(campo: LineEdit) -> void:
	campo.add_theme_stylebox_override("normal", caja(OSCURO, RADIO_BOTON, 1.0, 12.0))
	campo.add_theme_stylebox_override("focus", caja(OSCURO, RADIO_BOTON, 2.0, 12.0))
	campo.add_theme_font_override("font", fuente())
	campo.add_theme_font_size_override("font_size", NORMAL)
	campo.add_theme_color_override("font_color", TEXTO)
	campo.add_theme_color_override("caret_color", ACENTO)
	campo.add_theme_color_override("font_placeholder_color", TEXTO_SUAVE.darkened(0.2))


## Recorre un nodo y estiliza lo que encuentra: botones, paneles, barras, campos
## y las etiquetas que lleven su estilo en un metadato (`"estilo" = "titulo"` o
## `"dato"`), además del color de las barras (`"color"`).
##
## OJO: una etiqueta sin metadato **no se toca**. Es a propósito: así esta función
## nunca pisa un tamaño o un color puestos a mano (por ejemplo, el 64 px del
## logotipo de la pantalla de carga).
static func estilizar_arbol(raiz: Node) -> void:
	for nodo in raiz.get_children():
		if nodo is Button:
			estilizar_boton(nodo as Button, bool(nodo.get_meta("destacado", false)))
		elif nodo is PanelContainer:
			estilizar_panel(nodo as PanelContainer)
		elif nodo is ProgressBar:
			# get_meta() devuelve Variant: se copia a una variable CON tipo para no
			# depender de la inferencia.
			var color_barra: Color = nodo.get_meta("color", ACENTO)
			estilizar_barra(nodo as ProgressBar, color_barra)
		elif nodo is LineEdit:
			estilizar_campo(nodo as LineEdit)
		elif nodo is Label:
			var estilo := str(nodo.get_meta("estilo", ""))
			if estilo == "titulo":
				estilizar_titulo(nodo as Label)
			elif estilo == "dato":
				estilizar_texto(nodo as Label, NORMAL, TEXTO)
			elif estilo == "texto":
				estilizar_texto(nodo as Label)
		estilizar_arbol(nodo)
