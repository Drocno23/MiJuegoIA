"""Dibuja una hoja de ondas de los sonidos generados por code (scripts/sonido.gd).

Replica EXACTAMENTE las fórmulas del script de Godot (mismo ritmo de mezcla, misma
envolvente, mismas notas) y pinta 8 minigráficos para poder ver de un vistazo cómo
son: duración, envolvente (sin clics), bucle del turbo y música.

Uso:  python3 preview/render_sonidos.py     (necesita Pillow)
"""

import math

from PIL import Image, ImageDraw, ImageFont

FS = 22050  # Igual que Sonido.FRECUENCIA_MEZCLA
ANCHO, ALTO = 960, 620
MARGEN = 24
COLOR_FONDO = (12, 16, 28)
COLOR_TARJETA = (20, 26, 44)
COLOR_TITULO = (235, 240, 255)
COLOR_DETALLE = (150, 165, 195)
COLOR_VERDE = (75, 227, 106)
COLOR_ROSA = (255, 107, 214)
COLOR_CIAN = (92, 225, 255)
COLOR_AMBAR = (255, 213, 74)
COLOR_LILA = (195, 155, 255)


def envolvente(i: int, total: int, caida: float) -> float:
    ataque = min(i / (FS * 0.003), 1.0)
    return ataque * (1.0 - i / total) ** caida


def onda(tipo: str, fase: float) -> float:
    if tipo == "cuadrada":
        return 1.0 if math.fmod(fase, math.tau) < math.pi else -1.0
    if tipo == "triangular":
        return 1.0 - 4.0 * abs(math.fmod(fase, math.tau) / math.tau - 0.5)
    return math.sin(fase)


def barrido(ini, fin, dur, tipo="seno", amp=0.5, ruido=0.0, semilla=12345):
    n = int(FS * dur)
    out, fase = [], 0.0
    az = semilla
    for i in range(n):
        av = i / n
        fase += math.tau * (ini + (fin - ini) * av) / FS
        v = onda(tipo, fase) * amp
        if ruido > 0.0:
            az = (1103515245 * az + 12345) % (2 ** 31)
            v += ((az / 2 ** 31) * 2 - 1) * ruido * (1 - av)
        out.append(v * envolvente(i, n, 1.5))
    return out


def arpegio(freqs, dur_nota, tipo="triangular", amp=0.45):
    por = int(FS * dur_nota)
    out = []
    for f in freqs:
        fase = 0.0
        for i in range(por):
            fase += math.tau * f / FS
            out.append(onda(tipo, fase) * amp * envolvente(i, por, 1.2))
    return out


def bucle(f, dur, trem, amp):
    n = int(FS * dur)
    f_aj = round(f * dur) * FS / n
    t_aj = max(round(trem * dur), 1.0) * FS / n
    out, fase = [], 0.0
    for i in range(n):
        fase += math.tau * f_aj / FS
        pulso = 0.65 + 0.35 * math.sin(math.tau * t_aj * i / FS)
        out.append(onda("cuadrada", fase) * amp * pulso)
    return out


def musica():
    bpm, tiempos = 128.0, 16
    tiempo = 60.0 / bpm
    total = int(FS * tiempo * tiempos)
    flujo = [0.0] * total

    def mezclar(notas, dur, tipo, amp, silencio=0.03):
        por = int(FS * dur)
        con_sonido = max(por - int(FS * silencio), 1)
        for n, f in enumerate(notas):
            ini, fase = n * por, 0.0
            for i in range(con_sonido):
                if ini + i >= len(flujo):
                    break
                fase += math.tau * f / FS
                flujo[ini + i] += onda(tipo, fase) * amp * envolvente(i, con_sonido, 1.0)

    mezclar([440, 523.25, 659.25, 523.25, 587.33, 659.25, 587.33, 523.25,
             349.23, 440, 523.25, 440, 392, 493.88, 587.33, 783.99],
            tiempo, "cuadrada", 0.09)
    mezclar([110, 110, 87.31, 87.31, 130.81, 130.81, 98.0, 98.0],
            tiempo * 2, "triangular", 0.2)
    por_golpe, fase = int(FS * 0.12), 0.0
    golpe = []
    for i in range(por_golpe):
        av = i / por_golpe
        fase += math.tau * (70 + (45 - 70) * av) / FS
        golpe.append(math.sin(fase) * 0.28 * (1 - av) ** 3)
    pos, paso = 0, int(FS * tiempo)
    while pos < total:
        for i, v in enumerate(golpe):
            if pos + i < total:
                flujo[pos + i] += v
        pos += paso
    return flujo


SONIDOS = [
    ("Comer (520 -> 780 Hz, 0,07 s)", barrido(520, 780, 0.07), COLOR_AMBAR),
    ("Power-up (660-880-1320 Hz)", arpegio([660, 880, 1320], 0.085), COLOR_CIAN),
    ("Turbo: arranque (300 -> 900 Hz)", barrido(300, 900, 0.18, "cuadrada", 0.35), COLOR_ROSA),
    ("Turbo: zumbido (bucle, 221 ciclos)", bucle(884.0, 0.25, 8.0, 0.16), COLOR_ROSA),
    ("Muerte (440 -> 90 Hz + ruido)", barrido(440, 90, 0.5, "seno", 0.5, 0.25), COLOR_LILA),
    ("Fin de partida (220 -> 60 Hz)", barrido(220, 60, 0.6, "seno", 0.5, 0.15), COLOR_LILA),
    ("Partida nueva (arpegio subiendo)", arpegio([523.25, 659.25, 783.99, 1046.5], 0.07,
                                                 "triangular", 0.4), COLOR_VERDE),
    ("Música (bucle de 7,5 s con melodía, bajo y bombo)", musica(), COLOR_VERDE),
]


def fuente(tam):
    for ruta in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"):
        try:
            return ImageFont.truetype(ruta, tam)
        except OSError:
            continue
    return ImageFont.load_default()


def dibujar() -> Image.Image:
    img = Image.new("RGB", (ANCHO, ALTO), COLOR_FONDO)
    d = ImageDraw.Draw(img)
    f_tit, f_sub, f_pie = fuente(15), fuente(12), fuente(12)

    d.text((MARGEN, 14), "Sonidos de slither_2d — generados por código (sin archivos)",
           font=fuente(18), fill=COLOR_TITULO)
    d.text((MARGEN, 40), "Ondas tal y como las sintetiza scripts/sonido.gd · "
                         "16 bits · 22050 Hz · envolvente sin clics",
           font=f_sub, fill=COLOR_DETALLE)

    # 4 filas x 2 columnas de tarjetas.
    ancho_tarjeta = (ANCHO - MARGEN * 3) // 2
    alto_tarjeta = 118
    inicio_y = 66
    for indice, (titulo, muestras, color) in enumerate(SONIDOS):
        col, fila = indice % 2, indice // 2
        x0 = MARGEN + col * (ancho_tarjeta + MARGEN)
        y0 = inicio_y + fila * (alto_tarjeta + 14)
        x1, y1 = x0 + ancho_tarjeta, y0 + alto_tarjeta
        d.rounded_rectangle((x0, y0, x1, y1), 8, fill=COLOR_TARJETA)
        d.text((x0 + 10, y0 + 8), titulo, font=f_tit, fill=color)

        # Zona del gráfico.
        gx0, gy0, gx1, gy1 = x0 + 10, y0 + 32, x1 - 10, y1 - 24
        centro = (gy0 + gy1) / 2
        d.line((gx0, centro, gx1, centro), fill=(48, 58, 86), width=1)

        # Reducimos a un punto por columna: por cada columna, mínimo y máximo
        # (así se ven la envolvente y la forma de la onda aunque haya miles de muestras).
        columnas = gx1 - gx0
        paso = max(len(muestras) // columnas, 1)
        pico = max(max(abs(v) for v in muestras), 1e-6)
        escala = (gy1 - gy0) / 2 / pico * 0.95
        for c in range(columnas):
            trozo = muestras[c * paso:(c + 1) * paso]
            if not trozo:
                break
            arriba = centro - max(trozo) * escala
            abajo = centro - min(trozo) * escala
            d.line((gx0 + c, arriba, gx0 + c, max(abajo, arriba + 1)), fill=color)

        dur = len(muestras) / FS
        pico_db = 20 * math.log10(pico) if pico > 0 else -99
        rms = math.sqrt(sum(v * v for v in muestras) / len(muestras))
        d.text((x0 + 10, y1 - 20), f"{dur * 1000:.0f} ms · pico {pico_db:+.1f} dB · "
                                   f"rms {20 * math.log10(rms):+.1f} dB",
               font=f_pie, fill=COLOR_DETALLE)

    d.text((MARGEN, ALTO - 22),
           "M = silencio · N = música normal/bajita/apagada · la preferencia se guarda "
           "en user://ajustes.cfg",
           font=f_pie, fill=COLOR_DETALLE)
    return img


if __name__ == "__main__":
    destino = "preview/sonidos.png"
    dibujar().save(destino, optimize=True)
    print(f"✅ {destino} generado")
