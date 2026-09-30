class_name Creditos
extends Pantalla
## Pantalla de **créditos**: quién ha hecho qué y con qué.
##
## NODO AL QUE SE ADJUNTA: al **Control** raíz de `escenas/Creditos.tscn`.

## Secciones: un título y su lista de parejas "papel → responsable".
const SECCIONES := [
	[
		"Código y diseño",
		[
			["Idea y dirección", "Tú"],
			["Programación", "GDScript (Godot 4.7), escrito a mano paso a paso"],
			["Mecánicas", "Persecución con ratón, turbo, power-ups, bots y minimapa"],
			["Interfaz", "Menús montados por código con contenedores"],
		],
	],
	[
		"Arte",
		[
			["Gusanos, comida y fondo", "Círculos dibujados con _draw() en cada frame"],
			["Pieles", "6 paletas y 6 patrones calculados por código"],
			["Sin texturas", "El proyecto no usa ni una sola imagen"],
		],
	],
	[
		"Sonido",
		[
			["Efectos", "Sintetizados en AudioStreamWAV (16 bits, 22.050 Hz, mono)"],
			["Música", "Bucle generado con notas y bombo, sin archivos de audio"],
			["Ajustes", "Volumen de efectos y música; silencio con la tecla M"],
		],
	],
	[
		"Agradecimientos",
		[
			["Godot Engine", "Motor libre y gratuito (godotengine.org)"],
			["Comunidad", "Documentación de Godot 4 y ejemplos abiertos"],
			["Tú", "Por jugar, probar y decir qué cambiar"],
		],
	],
]


func al_abrir() -> void:
	var contenido := crear_armazon("", "")
	var centro := CenterContainer.new()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(centro)

	var columna := VBoxContainer.new()
	columna.name = "Creditos"
	columna.custom_minimum_size = Vector2(780, 0)
	columna.add_theme_constant_override("separation", 10)
	centro.add_child(columna)

	var logotipo := Label.new()
	logotipo.text = "SLITHER 2D"
	logotipo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Estilo.estilizar_titulo(logotipo, 46)
	logotipo.add_theme_color_override("font_color", Estilo.ACENTO)
	columna.add_child(logotipo)

	var lema := Label.new()
	lema.text = "Versión %s  ·  hecho con Godot %s" % [
		Gestor.VERSION, str(Engine.get_version_info().get("string", "")),
	]
	lema.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Estilo.estilizar_texto(lema, Estilo.NORMAL, Estilo.TEXTO_SUAVE)
	columna.add_child(lema)

	for seccion in SECCIONES:
		var caja := anadir_panel(columna, str(seccion[0]))
		for pareja in seccion[1]:
			caja.add_child(fila_de_datos(str(pareja[0]), str(pareja[1])))

	var nota := Label.new()
	nota.text = (
		"Un prototipo educativo: sirve para aprender a hacer un juego completo\n"
		+ "con código limpio y sin depender de imágenes ni sonidos externos."
	)
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Estilo.estilizar_texto(nota, Estilo.PEQUENO, Estilo.TEXTO_SUAVE)
	columna.add_child(nota)

	var volver := boton("VOLVER AL MENÚ", ir_al_menu, true)
	volver.custom_minimum_size = Vector2(0, 48)
	columna.add_child(volver)
	pie("Gracias por jugar")


func al_pulsar_escape() -> void:
	ir_al_menu()
