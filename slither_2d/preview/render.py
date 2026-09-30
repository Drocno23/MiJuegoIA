"""Recrea el aspecto del prototipo con los MISMOS parámetros de dibujo que los
scripts .gd (no es una captura del motor: es una simulación del _draw()).
Sirve para comprobar de un vistazo cómo se ven los círculos de borde suave."""
import math, random
from PIL import Image, ImageDraw, ImageFont

random.seed(7)
S = 4                      # supersampling para el antialiasing del render
W, H = 1280, 720
BG   = (11, 16, 32)        # environment/defaults/default_clear_color
GRID = (255, 255, 255)     # color_linea con alpha 0.07
paso  = 96

def hex2rgb(h): return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
def darkened(c, a): return tuple(int(v * (1 - a)) for v in c)
def lightened(c, a): return tuple(int(round(v + (255 - v) * a)) for v in c)

img = Image.new("RGB", (W * S, H * S), BG)
d = ImageDraw.Draw(img, "RGBA")

# --- fondo.gd: cuadrícula cada 96 px + ejes en el origen ---
for x in range(0, W + 1, paso):
    d.line([(x*S, 0), (x*S, H*S)], fill=GRID + (int(255*0.07),), width=S)
for y in range(0, H + 1, paso):
    d.line([(0, y*S), (W*S, y*S)], fill=GRID + (int(255*0.07),), width=S)

def circulo(cx, cy, r, color, alfa=255):
    d.ellipse([((cx-r)*S, (cy-r)*S), ((cx+r)*S, (cy+r)*S)], fill=tuple(color) + (alfa,))

def cuerpo_punto(cx, cy, r, color):
    """cuerpo_segmento.gd / gusano.gd: borde + relleno + brillo."""
    circulo(cx, cy, r,       darkened(color, 0.42))
    circulo(cx, cy, r*0.86,  color)
    circulo(cx-r*0.3, cy-r*0.3, r*0.22, lightened(color, 0.4))

def comida_punto(cx, cy, r, color):
    circulo(cx, cy, r,      darkened(color, 0.45))
    circulo(cx, cy, r*0.82, color)
    circulo(cx-r*0.28, cy-r*0.28, r*0.24, lightened(color, 0.5))

def gusano(px, py, ang, r, color, n_seg, sep, curvatura=0.06):
    """Igual que el juego: la cabeza va primero y cada segmento está a `sep`
    píxeles por detrás sobre el camino que dejó la cabeza (aquí, un arco)."""
    pts, a, x, y = [(px, py)], ang, px, py
    for _ in range(n_seg * 4):
        a -= curvatura
        x += math.cos(a) * sep / 4.0
        y += math.sin(a) * sep / 4.0
        pts.append((x, y))
    for i in range(n_seg, 0, -1):          # del último segmento (cola) a la cabeza
        sx, sy = pts[i * 4]
        cuerpo_punto(sx, sy, r, color)
    # cabeza (gusano.gd: borde + relleno + ojos mirando hacia donde va)
    circulo(px, py, r, darkened(color, 0.45))
    circulo(px, py, r * 0.88, color)
    ad, ld = (math.cos(ang), math.sin(ang)), (-math.sin(ang), math.cos(ang))
    for lado in (-1, 1):
        ox = px + ad[0] * r * 0.45 + ld[0] * r * 0.4 * lado
        oy = py + ad[1] * r * 0.45 + ld[1] * r * 0.4 * lado
        circulo(ox, oy, r * 0.27, (255, 255, 255))
        circulo(ox + ad[0] * r * 0.1, oy + ad[1] * r * 0.1, r * 0.14, (16, 24, 32))

# comida normal (amarilla)
for _ in range(90):
    comida_punto(random.uniform(60, W-60), random.uniform(60, H-60), 8, hex2rgb("ffd54a"))
# restos de un gusano muerto (naranja, 9 px) formando el rastro de su cuerpo
cx, cy = 300, 560
for i in range(16):
    comida_punto(cx + i*15, cy - i*3.2 + 30*math.sin(i/3.0), 9, hex2rgb("ff9d3d"))

# bot magenta cruzando por delante
gusano(900, 200, math.radians(150), 12, hex2rgb("d05ce8"), 16, 15, 0.05)
# bot cian
gusano(760, 560, math.radians(190), 11, hex2rgb("5cc9e8"), 12, 15, -0.06)
# jugador verde en primer plano
gusano(470, 200, math.radians(80), 12, hex2rgb("4be36a"), 18, 15, 0.07)

# --- HUD (Main.tscn: Label "Puntos" y "Ayuda") ---
def fuente(px):
    for ruta in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        try: return ImageFont.truetype(ruta, px * S)
        except OSError: pass
    return None

d.text((20 * S, 12 * S), "PUNTOS: 123    LONGITUD: 19    BOTS: 7    COMIDA: 152",
       font=fuente(22), fill=(255, 255, 255, 235))
texto_ayuda = ("Mueve el ratón para dirigir al gusano. Cómete la comida amarilla y "
               "no choques con el cuerpo de otro gusano.")
ancho = d.textlength(texto_ayuda, font=fuente(18))
d.text(((W * S - ancho) / 2, H * S - 74 * S), texto_ayuda, font=fuente(18), fill=(255, 255, 255, 190))

img = img.resize((W, H), Image.LANCZOS)
img.save("aspecto.png")
# recorte ampliado para ver el borde de los círculos
img.crop((380, 130, 700, 320)).resize((900, 540), Image.NEAREST).save("detalle_bordes.png")
print("generados: aspecto.png y detalle_bordes.png")
