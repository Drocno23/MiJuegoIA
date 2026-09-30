class_name Gestor
extends RefCounted
## Catálogo de escenas y **transiciones con fundido** entre pantallas.
##
## NODO AL QUE SE ADJUNTA: a ninguno. Es una clase de utilidades estáticas
## (`Gestor.ir_a(self, Gestor.MENU)`), igual que `dibujo.gd` o `Estilo`.
##
## ¿Por qué NO es un autoload? No hace falta: cada función recibe el nodo desde el
## que se llama (`quien`) y busca sola dónde poner el fundido (el propio nodo, si es
## una pantalla, o su `HUD` si es el mundo). Así `project.godot` no necesita declarar
## ningún autoload y **todas** las pantallas comparten el mismo efecto de transición.
##
## Uso típico desde un botón:
## [codeblock]
## boton.pressed.connect(func(): Gestor.ir_a(self, Gestor.OPCIONES))
## [/codeblock]

const CARGA := "res://escenas/Carga.tscn"
const MENU := "res://escenas/MenuPrincipal.tscn"
const JUEGO := "res://escenas/Main.tscn"
const SELECCION := "res://escenas/Seleccion.tscn"
const RECORDS := "res://escenas/Records.tscn"
const OPCIONES := "res://escenas/Opciones.tscn"
const COMO_JUGAR := "res://escenas/ComoJugar.tscn"
const CREDITOS := "res://escenas/Creditos.tscn"
const PAUSA := "res://escenas/Pausa.tscn"

const VERSION := "0.9.0"  ## Versión que se muestra en el menú y en la carga.
const DURACION_FUNDIDO := 0.22  ## Segundos que tarda la pantalla en fundirse a negro.
const NOMBRE_FUNDIDO := "Fundido"
## Meta que se pone en el nodo mientras hay un cambio en marcha (para no lanzar dos).
const META_OCUPADO := "cambiando_de_escena"


# ---------------------------------------------------------------------------
# Cambiar de pantalla
# ---------------------------------------------------------------------------

## Va a la escena `ruta` con un fundido a negro. No hace nada si ya se está
## cambiando de pantalla (evita que dos clics rápidos encadenen dos cambios).
static func ir_a(quien: Node, ruta: String) -> void:
	if quien == null or not is_instance_valid(quien) or quien.get_tree() == null:
		return
	if bool(quien.get_meta(META_OCUPADO, false)):
		return
	quien.set_meta(META_OCUPADO, true)
	var arbol := quien.get_tree()
	var fundido := _fundido(quien)
	if fundido == null:
		arbol.change_scene_to_file(ruta)
		return
	fundido.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := quien.create_tween()
	tween.tween_property(fundido, "color:a", 1.0, DURACION_FUNDIDO)
	tween.tween_callback(arbol.change_scene_to_file.bind(ruta))


static func ir_al_menu(quien: Node) -> void:
	ir_a(quien, MENU)


static func ir_al_juego(quien: Node) -> void:
	ir_a(quien, JUEGO)


## Cierra el juego (botón SALIR del menú principal).
static func salir() -> void:
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol != null:
		arbol.quit()


# ---------------------------------------------------------------------------
# Interno
# ---------------------------------------------------------------------------

## Busca (o crea) el rectángulo negro que se usa para el fundido.
## Reutiliza el nodo "Fundido" que ya crea `pantalla.gd` al abrir una pantalla.
static func _fundido(quien: Node) -> ColorRect:
	var contenedor := _contenedor(quien)
	if contenedor == null:
		return null
	var existente := contenedor.get_node_or_null(NOMBRE_FUNDIDO) as ColorRect
	if existente != null:
		return existente
	var fundido := ColorRect.new()
	fundido.name = NOMBRE_FUNDIDO
	fundido.color = Color(0, 0, 0, 0)
	fundido.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundido.mouse_filter = Control.MOUSE_FILTER_STOP
	contenedor.add_child(fundido)
	return fundido


## ¿Dónde poner el fundido? En una pantalla (Control) o en la capa de interfaz,
## es el propio nodo; en el mundo (Node2D), su `HUD` (CanvasLayer).
static func _contenedor(quien: Node) -> Node:
	if quien is Control or quien is CanvasLayer:
		return quien
	var hud := quien.get_node_or_null("HUD")
	return hud if hud != null else quien
