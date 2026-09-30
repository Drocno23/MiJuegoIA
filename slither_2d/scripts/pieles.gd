class_name Pieles
extends RefCounted
## Catálogo de pieles del gusano: **paletas de color** y **patrones de cuerpo**.
##
## NODO AL QUE SE ADJUNTA: a ninguno. Es una clase de utilidades estáticas
## (`Pieles.color_de_segmento(...)`), igual que `dibujo.gd`; no es un script de nodo.
##
## ¿CÓMO SE HACE UNA PIEL SIN IMÁGENES? Cada piel es una **lista de colores**
## (2-3 colores) y un **patrón** que decide qué color le toca a cada segmento según
## su índice. Todo se calcula por código, así que no hay ningún archivo de imagen.
##
## Las pieles se **desbloquean con logros** (`desbloqueada()`): las estadísticas se
## las pasa `main.gd` (las guarda en `user://records.cfg` con `records.gd`).

## Sirve para preguntar por paletas o por patrones con las mismas funciones.
enum Tipo { PALETA, PATRON }

## Paletas de color. El índice es el que se guarda en el récord.
enum Paleta { CLASICO, NEON, HIELO, FUEGO, SELVA, ORO }

## Patrones de cuerpo. El índice es el que se guarda en el récord.
enum Patron { LISO, RAYAS, ANILLOS, DEGRADADO, MOTAS, BICOLOR }

## Catálogo de paletas: nombre, tres colores (base, oscuro, claro) y logro que la
## desbloquea ("" = disponible desde el principio). Son `static var` (y no `const`)
## porque un `const` solo admite expresiones constantes y aquí hay constructores de
## `Color` y `PackedColorArray`: así nos aseguramos de que compila en cualquier 4.x.
static var paletas: Array = [
	{
		"nombre": "Clásico",
		"colores": PackedColorArray([Color("4be36a"), Color("2f9e4d"), Color("a8ffbe")]),
		"logro": "",
	},
	{
		"nombre": "Neón",
		"colores": PackedColorArray([Color("00e5ff"), Color("0077b6"), Color("7cfff1")]),
		"logro": "comida_25",
	},
	{
		"nombre": "Hielo",
		"colores": PackedColorArray([Color("9fd8ff"), Color("4a90d9"), Color("eaf8ff")]),
		"logro": "record_longitud_25",
	},
	{
		"nombre": "Fuego",
		"colores": PackedColorArray([Color("ff7a29"), Color("c62828"), Color("ffd166")]),
		"logro": "bots_5",
	},
	{
		"nombre": "Selva",
		"colores": PackedColorArray([Color("2e8b57"), Color("14472b"), Color("d9f99d")]),
		"logro": "partidas_10",
	},
	{
		"nombre": "Oro",
		"colores": PackedColorArray([Color("ffd45c"), Color("a67c00"), Color("fff3c4")]),
		"logro": "record_puntos_300",
	},
]

## Catálogo de patrones: nombre y logro que lo desbloquea ("" = libre).
static var patrones: Array = [
	{"nombre": "Liso", "logro": ""},
	{"nombre": "Rayas", "logro": ""},
	{"nombre": "Anillos", "logro": "comida_50"},
	{"nombre": "Degradado", "logro": "record_longitud_40"},
	{"nombre": "Motas", "logro": "bots_3"},
	{"nombre": "Bicolor", "logro": "partidas_15"},
]

## Logros: qué estadística hay que alcanzar. Las claves son las de `records.gd`:
## comida, bots, partidas, record_puntos, record_longitud, tiempo.
static var logros: Dictionary = {
	"comida_25": {"texto": "Cómete 25 comidas", "estadistica": "comida", "cantidad": 25},
	"comida_50": {"texto": "Cómete 50 comidas", "estadistica": "comida", "cantidad": 50},
	"bots_3": {"texto": "Cómete 3 bots", "estadistica": "bots", "cantidad": 3},
	"bots_5": {"texto": "Cómete 5 bots", "estadistica": "bots", "cantidad": 5},
	"partidas_10": {"texto": "Juega 10 partidas", "estadistica": "partidas", "cantidad": 10},
	"partidas_15": {"texto": "Juega 15 partidas", "estadistica": "partidas", "cantidad": 15},
	"record_longitud_25": {
		"texto": "Llega a 25 de longitud",
		"estadistica": "record_longitud",
		"cantidad": 25,
	},
	"record_longitud_40": {
		"texto": "Llega a 40 de longitud",
		"estadistica": "record_longitud",
		"cantidad": 40,
	},
	"record_puntos_300": {
		"texto": "Haz 300 puntos",
		"estadistica": "record_puntos",
		"cantidad": 300,
	},
}


# ---------------------------------------------------------------------------
# Consultas del catálogo
# ---------------------------------------------------------------------------

static func cantidad_paletas() -> int:
	return paletas.size()


static func cantidad_patrones() -> int:
	return patrones.size()


static func nombre_paleta(indice: int) -> String:
	var datos: Dictionary = paletas[clampi(indice, 0, paletas.size() - 1)]
	return str(datos.get("nombre", "?"))


static func colores_paleta(indice: int) -> PackedColorArray:
	var datos: Dictionary = paletas[clampi(indice, 0, paletas.size() - 1)]
	var colores: PackedColorArray = datos.get("colores", PackedColorArray([Color.WHITE]))
	return colores


static func nombre_patron(indice: int) -> String:
	var datos: Dictionary = patrones[clampi(indice, 0, patrones.size() - 1)]
	return str(datos.get("nombre", "?"))


## Colores de un bot: derivados de un tono al azar (el jugador usa una paleta).
static func colores_de_bot(tono: float) -> PackedColorArray:
	var base := Color.from_hsv(tono, 0.65, 1.0)
	return PackedColorArray([base, base.darkened(0.3), base.lightened(0.35)])


## Patrón al azar para un bot (a los bots no les afectan los desbloqueos).
static func patron_aleatorio() -> int:
	return randi_range(0, cantidad_patrones() - 1)


# ---------------------------------------------------------------------------
# El color de cada segmento (el corazón de las pieles)
# ---------------------------------------------------------------------------

## Color que le toca al segmento `indice` (de `total`) con esos colores y patrón.
## `semilla` hace que las motas de dos gusanos no salgan iguales.
static func color_de_segmento(
	colores: PackedColorArray,
	patron: int,
	indice: int,
	total: int,
	semilla: int = 0
) -> Color:
	if colores.is_empty():
		return Color.WHITE
	var base := colores[0]
	match patron:
		Patron.RAYAS:
			return _alterno(colores, 2) if indice % 2 == 1 else base
		Patron.ANILLOS:
			return _alterno(colores, 1) if indice % 3 == 2 else base
		Patron.DEGRADADO:
			var t := float(indice) / maxf(float(total) - 1.0, 1.0)
			return base.lerp(_alterno(colores, 1), t * 0.85)
		Patron.MOTAS:
			return _alterno(colores, 2) if _ruido_estable(indice, semilla) > 0.68 else base
		Patron.BICOLOR:
			return _alterno(colores, 1) if indice >= total / 2 else base
		_:
			return base


## Color alterno nº `indice` de la lista (si no existe, oscurece el base).
static func _alterno(colores: PackedColorArray, indice: int) -> Color:
	if indice < colores.size():
		return colores[indice]
	return colores[0].darkened(0.3)


## Valor pseudoaleatorio (0..1) pero SIEMPRE igual para el mismo segmento:
## así las motas no cambian de sitio en cada frame.
static func _ruido_estable(indice: int, semilla: int) -> float:
	var valor := sin(float(indice) * 12.9898 + float(semilla) * 78.233) * 43758.5453
	return absf(valor - floorf(valor))


# ---------------------------------------------------------------------------
# Desbloqueos (8C): cuestión de logros
# ---------------------------------------------------------------------------

static func desbloqueada(tipo: int, indice: int, estadisticas: Dictionary) -> bool:
	var clave := _clave_logro(tipo, indice)
	if clave == "":
		return true
	var logro: Dictionary = logros.get(clave, {})
	if logro.is_empty():
		return true
	var estadistica := str(logro.get("estadistica", ""))
	var cantidad := int(logro.get("cantidad", 0))
	return int(estadisticas.get(estadistica, 0)) >= cantidad


## Índices desbloqueados de paletas o patrones, en orden.
static func desbloqueadas(tipo: int, estadisticas: Dictionary) -> PackedInt32Array:
	var lista := PackedInt32Array()
	for i in _cantidad(tipo):
		if desbloqueada(tipo, i, estadisticas):
			lista.append(i)
	return lista


## Siguiente índice desbloqueado (para las teclas P y O), dando la vuelta.
static func siguiente(tipo: int, actual: int, estadisticas: Dictionary) -> int:
	var libres := desbloqueadas(tipo, estadisticas)
	if libres.is_empty():
		return actual
	for indice in libres:
		if indice > actual:
			return indice
	return libres[0]


## Texto del requisito de una piel ("🔒 Cómete 25 comidas") o "" si es libre.
static func requisito(tipo: int, indice: int) -> String:
	var clave := _clave_logro(tipo, indice)
	if clave == "":
		return ""
	var logro: Dictionary = logros.get(clave, {})
	var texto := str(logro.get("texto", ""))
	return "🔒 %s" % texto if texto != "" else ""


## Qué desbloquea un logro: "Paleta Neón", "Patrón Anillos"... ("" si nada).
static func recompensa(clave: String) -> String:
	for i in cantidad_paletas():
		if _clave_logro(Tipo.PALETA, i) == clave:
			return "Paleta %s" % nombre_paleta(i)
	for i in cantidad_patrones():
		if _clave_logro(Tipo.PATRON, i) == clave:
			return "Patrón %s" % nombre_patron(i)
	return ""


static func _clave_logro(tipo: int, indice: int) -> String:
	if tipo == Tipo.PALETA:
		var datos: Dictionary = paletas[clampi(indice, 0, paletas.size() - 1)]
		return str(datos.get("logro", ""))
	var datos_patron: Dictionary = patrones[clampi(indice, 0, patrones.size() - 1)]
	return str(datos_patron.get("logro", ""))


static func _cantidad(tipo: int) -> int:
	return cantidad_paletas() if tipo == Tipo.PALETA else cantidad_patrones()
