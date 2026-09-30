class_name Dibujo
extends RefCounted
## Utilidades de dibujo compartidas por los nodos que se dibujan por código.
##
## NODO AL QUE SE ADJUNTA: a ninguno. Es una clase de utilidades estáticas
## (`Dibujo.disco(...)`), no un script de nodo.
##
## ¿POR QUÉ EXISTE ESTE ARCHIVO?
## El proyecto usa el renderizador **GL Compatibility**, que todavía NO soporta
## MSAA 2D. Godot lo avisa por consola:
##
##     render_target_set_msaa: 2D MSAA is not yet supported for GLES3.
##
## Es un aviso, no un error: el ajuste se ignora, así que el juego se veía
## exactamente igual que sin él. Y como `draw_circle()` sólo aplica antialiasing
## a los CONTORNOS (`antialiased` no tiene efecto con `filled = true`), la única
## forma de tener bordes suaves sin depender del renderizador es dibujar una
## TEXTURA de círculo con el borde degradado. Eso es lo que hace `disco()`.

## Resolución de la textura de círculo (se genera una única vez).
const TAMANO_TEXTURA := 128
## Ancho del degradado del borde, como fracción del radio. Con la textura a 128 px
## dibujada a radio 12 px (el del juego), son ~1,5 px de borde suave en pantalla.
const SUAVIZADO := 0.14

static var _textura_circulo: ImageTexture = null


## Textura con un círculo blanco de borde suave. Se genera por código, una sola
## vez, y se comparte entre todos los gusanos, segmentos y comidas.
static func textura_circulo() -> ImageTexture:
	if _textura_circulo == null:
		var n := TAMANO_TEXTURA
		var imagen := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
		var centro := Vector2(n - 1, n - 1) * 0.5
		var radio := centro.x
		var inicio_degradado := radio * (1.0 - SUAVIZADO)
		var ancho_degradado := radio - inicio_degradado
		for y in n:
			for x in n:
				var distancia := Vector2(x, y).distance_to(centro)
				# 1 dentro del círculo, 0 fuera y un degradado lineal en el borde.
				var alfa := clampf((radio - distancia) / ancho_degradado, 0.0, 1.0)
				imagen.set_pixel(x, y, Color(1.0, 1.0, 1.0, alfa))
		_textura_circulo = ImageTexture.create_from_image(imagen)
	return _textura_circulo


## Dibuja un círculo relleno del color indicado. Debe llamarse desde `_draw()`.
## Con `bordes_suaves = true` usa la textura (borde suave en cualquier
## renderizador); con `false` usa el `draw_circle()` de toda la vida.
static func disco(
	canvas: CanvasItem,
	centro: Vector2,
	radio: float,
	color: Color,
	bordes_suaves: bool = true
) -> void:
	if radio <= 0.0:
		return
	if not bordes_suaves:
		canvas.draw_circle(centro, radio, color)
		return
	var tamano := Vector2(radio, radio) * 2.0
	canvas.draw_texture_rect(
		textura_circulo(),
		Rect2(centro - Vector2(radio, radio), tamano),
		false,
		color  # El modulate tiñe de ese color el círculo blanco de la textura.
	)
