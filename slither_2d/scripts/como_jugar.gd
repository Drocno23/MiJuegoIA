class_name ComoJugar
extends Pantalla
## Pantalla de **cómo jugar**: controles, objetivo, power-ups y pieles.
##
## NODO AL QUE SE ADJUNTA: al **Control** raíz de `escenas/ComoJugar.tscn`.
##
## Los textos son los mismos que usa el HUD y el README, así que si algún día
## cambia un atajo, se cambia aquí y en `main.gd` y queda todo coherente.

## Atajos: primero la tecla (o el gesto), luego lo que hace.
const CONTROLES := [
	["Ratón (mover)", "El gusano gira hacia el puntero. Es todo lo que hace falta para jugar."],
	["SHIFT o clic derecho", "TURBO: corres más rápido, pero vas perdiendo longitud."],
	["P", "Cambia la paleta de color (solo las que tengas desbloqueadas)."],
	["O", "Cambia el patrón del cuerpo."],
	["M", "Silencio total (también está en Opciones)."],
	["N", "Música: normal → bajita → apagada."],
	["ESC", "Pausa: continuar, reiniciar, opciones de audio o volver al menú."],
	["ESPACIO o ENTER", "Reiniciar después de morir."],
]

const REGLAS := [
	"Cómete los puntos de comida para crecer: cada bocado te alarga el cuerpo.",
	"Chocar contra el cuerpo de otro gusano (o contra el tuyo) es el final de la partida.",
	"Si otro se estrella contigo, muere él: su cuerpo queda como comida naranja.",
	"Los gusanos más largos mandan en la clasificación de la derecha.",
	"El turbo suelta comida que otros pueden comer: dosifica su uso.",
]

const POWERUPS := [
	["IMÁN (cian)", "6 s · la comida vuela hacia tu cabeza."],
	["ESCUDO (verde claro)", "5 s · no mueres al chocar con otro cuerpo."],
	["TURBO (rosa)", "4 s · turbo gratis, sin perder longitud."],
	["FANTASMA (lila)", "5 s · no mueres ni te ven: cuerpo translúcido."],
]


func al_abrir() -> void:
	var contenido := crear_armazon(
		"CÓMO JUGAR",
		"Todo se controla con el ratón; el resto son atajos que puedes ignorar"
	)
	var columnas := HBoxContainer.new()
	columnas.add_theme_constant_override("separation", 22)
	columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(columnas)

	var izquierda := VBoxContainer.new()
	izquierda.name = "Controles"
	izquierda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izquierda.add_theme_constant_override("separation", 12)
	columnas.add_child(izquierda)
	_montar_controles(izquierda)

	var derecha := VBoxContainer.new()
	derecha.name = "Reglas"
	derecha.custom_minimum_size = Vector2(520, 0)
	derecha.add_theme_constant_override("separation", 12)
	columnas.add_child(derecha)
	_montar_reglas(derecha)
	_montar_powerups(derecha)

	var volver := boton("VOLVER AL MENÚ", ir_al_menu, true)
	volver.custom_minimum_size = Vector2(0, 48)
	contenido.add_child(volver)
	pie("Consejo: en partida, el marcador de abajo a la izquierda dice qué te toca hacer")


func al_pulsar_escape() -> void:
	ir_al_menu()


func _montar_controles(padre: Node) -> void:
	var caja := anadir_panel(padre, "Controles")
	for pareja in CONTROLES:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 12)
		var tecla := etiqueta(str(pareja[0]), "dato")
		tecla.custom_minimum_size = Vector2(170, 0)
		Estilo.estilizar_texto(tecla, Estilo.NORMAL, Estilo.ACENTO)
		fila.add_child(tecla)
		var accion := etiqueta(str(pareja[1]))
		accion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		accion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(accion)
		caja.add_child(fila)


func _montar_reglas(padre: Node) -> void:
	var caja := anadir_panel(padre, "Cómo se juega")
	for regla in REGLAS:
		var texto := etiqueta("•  " + str(regla))
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caja.add_child(texto)


func _montar_powerups(padre: Node) -> void:
	var caja := anadir_panel(padre, "Power-ups (aparecen dentro de un aro de luz)")
	for pareja in POWERUPS:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 12)
		var nombre := etiqueta(str(pareja[0]), "dato")
		nombre.custom_minimum_size = Vector2(200, 0)
		fila.add_child(nombre)
		var efecto := etiqueta(str(pareja[1]))
		efecto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		efecto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(efecto)
		caja.add_child(fila)
