"""Generador de texturas de El Eclipse Eterno (ropa clásica 2D y caras).

Dibuja plantillas de camisa y pantalón de Roblox (585x559) en escala de grises, para que en
el juego se tiñan del color que elija cada jugador (Shirt.Color3 / Pants.Color3), y caras
estilo anime limpias (decal de 256x256).

Salida:
  - herramientas/texturas/png/*.png          (para verlas)
  - src/ServerStorage/Herramientas/Texturas/  (módulos Luau con los píxeles comprimidos; el
    plugin PluginSubidor los sube a Roblox)

Uso:  python3 herramientas/texturas/generar.py
"""
import base64
import math
import os
import random
import struct

from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(RAIZ, "..", ".."))
SALIDA_PNG = os.path.join(RAIZ, "png")
SALIDA_LUAU = os.path.join(REPO, "src", "ServerStorage", "Herramientas", "Texturas")

S = 4  # dibujamos a 4x y luego reducimos (bordes suaves)
W, H = 585, 559

# ===== Caras de la plantilla de Roblox (x, y, ancho, alto) =====
TORSO = {"F": (231, 74, 128, 128), "B": (427, 74, 128, 128), "R": (165, 74, 64, 128),
         "L": (361, 74, 64, 128), "U": (231, 8, 128, 64), "D": (231, 204, 128, 64)}
# brazo/pierna DERECHA (a la izquierda de la plantilla) e IZQUIERDA
BRAZO_D = {"U": (217, 289, 64, 64), "D": (217, 485, 64, 64), "In": (19, 355, 64, 128),
           "B": (85, 355, 64, 128), "Out": (151, 355, 64, 128), "F": (217, 355, 64, 128)}
BRAZO_I = {"U": (308, 289, 64, 64), "D": (308, 485, 64, 64), "F": (308, 355, 64, 128),
           "Out": (374, 355, 64, 128), "B": (440, 355, 64, 128), "In": (506, 355, 64, 128)}
LADOS = ["F", "B", "R", "L"]
CARAS_BRAZO = ["F", "B", "In", "Out"]


class Lienzo:
    """Lienzo en escala de grises con transparencia, a 4x."""

    def __init__(self):
        self.gris = Image.new("L", (W * S, H * S), 0)
        self.alfa = Image.new("L", (W * S, H * S), 0)
        self.dg = ImageDraw.Draw(self.gris)
        self.da = ImageDraw.Draw(self.alfa)

    # coordenadas: cara + fracciones (0..1) dentro de la cara
    @staticmethod
    def punto(cara, fx, fy):
        x, y, w, h = cara
        return ((x + fx * w) * S, (y + fy * h) * S)

    def rect(self, cara, fx0, fy0, fx1, fy1, valor, alfa=255):
        a = self.punto(cara, fx0, fy0)
        b = self.punto(cara, fx1, fy1)
        caja = [a[0], a[1], b[0] - 1, b[1] - 1]
        self.dg.rectangle(caja, fill=valor)
        self.da.rectangle(caja, fill=alfa)

    def tela(self, cara, fy0, fy1, base, borde=10, vertical=12):
        """Rellena una cara con tela: un poco más clara arriba, bordes algo más oscuros."""
        x, y, w, h = cara
        y0 = int((y + fy0 * h) * S)
        y1 = int((y + fy1 * h) * S)
        x0, x1 = x * S, (x + w) * S
        for yy in range(y0, y1):
            t = (yy - y * S) / (h * S)
            v = base + vertical * (0.5 - t)
            self.dg.line([(x0, yy), (x1 - 1, yy)], fill=int(v))
        self.da.rectangle([x0, y0, x1 - 1, y1 - 1], fill=255)
        # sombra en los bordes laterales (da volumen)
        ancho = max(2, int(w * S * 0.09))
        for i in range(ancho):
            k = (1 - i / ancho) ** 1.6 * borde
            self._oscurecer_columna(x0 + i, y0, y1, k)
            self._oscurecer_columna(x1 - 1 - i, y0, y1, k)

    def _oscurecer_columna(self, xx, y0, y1, k):
        col = self.gris.crop((xx, y0, xx + 1, y1))
        col = col.point(lambda p: max(0, p - k))
        self.gris.paste(col, (xx, y0))

    def linea(self, cara, puntos, ancho, valor):
        pts = [self.punto(cara, fx, fy) for fx, fy in puntos]
        self.dg.line(pts, fill=valor, width=max(1, int(ancho * S)), joint="curve")

    def poligono(self, cara, puntos, valor, alfa=255):
        pts = [self.punto(cara, fx, fy) for fx, fy in puntos]
        self.dg.polygon(pts, fill=valor)
        self.da.polygon(pts, fill=alfa)

    def corte(self, cara, puntos):
        """Recorta (transparente: se ve la piel o la prenda de debajo)."""
        pts = [self.punto(cara, fx, fy) for fx, fy in puntos]
        self.da.polygon(pts, fill=0)

    def circulo(self, cara, fx, fy, radio, valor, contorno=None):
        cx, cy = self.punto(cara, fx, fy)
        r = radio * S
        self.dg.ellipse([cx - r, cy - r, cx + r, cy + r], fill=valor, outline=contorno, width=S)
        self.da.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)

    def puntadas(self, cara, puntos, valor, largo=2.0, hueco=1.6, ancho=0.7):
        """Línea de puntadas (costura discontinua)."""
        pts = [self.punto(cara, fx, fy) for fx, fy in puntos]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            d = math.hypot(bx - ax, by - ay)
            if d == 0:
                continue
            paso = (largo + hueco) * S
            n = int(d // paso) + 1
            for i in range(n):
                t0 = i * paso / d
                t1 = min(1, (i * paso + largo * S) / d)
                self.dg.line([(ax + (bx - ax) * t0, ay + (by - ay) * t0),
                              (ax + (bx - ax) * t1, ay + (by - ay) * t1)],
                             fill=valor, width=max(1, int(ancho * S)))

    def imagen(self):
        g = self.gris.reduce(S)
        a = self.alfa.reduce(S)
        # cuantizar a pasos de 3 (menos colores = archivo más pequeño, no se nota)
        g = g.point(lambda p: min(255, int(round(p / 3.0) * 3)))
        a = a.point(lambda p: 0 if p < 24 else (255 if p > 230 else int(round(p / 32.0) * 32)))
        rgba = Image.merge("RGBA", (g, g, g, a))
        return rgba


# ===== Piezas comunes =====
def torso_completo(l, base, desde=0.0, hasta=1.0):
    for k in LADOS:
        l.tela(TORSO[k], desde, hasta, base if k in ("F", "B") else base - 8)
    l.tela(TORSO["U"], 0, 1, base + 4, borde=6, vertical=4)
    l.tela(TORSO["D"], 0, 1, base - 12, borde=6, vertical=4)


def mangas(l, base, largo, holgura=False):
    """Mangas hasta 'largo' (0..1 del brazo; 0.80 = hasta la muñeca)."""
    if largo <= 0:
        return
    for brazo in (BRAZO_D, BRAZO_I):
        for k in CARAS_BRAZO:
            l.tela(brazo[k], 0, largo, base - (6 if k in ("In", "Out") else 0))
        l.tela(brazo["U"], 0, 1, base + 4, borde=5, vertical=3)
        if largo >= 0.8:
            pass
        # pliegues suaves de la manga
        for k in CARAS_BRAZO:
            c = brazo[k]
            for i, fy in enumerate((0.22, 0.48, 0.66)):
                if fy + 0.06 < largo:
                    l.linea(c, [(0.15, fy), (0.5, fy + 0.035), (0.85, fy + 0.01)], 1.0, base - 26)
            if holgura:
                l.linea(c, [(0.2, largo - 0.12), (0.45, largo - 0.04)], 1.2, base - 30)
                l.linea(c, [(0.6, largo - 0.14), (0.8, largo - 0.05)], 1.2, base - 30)


def puno(l, desde, hasta, valor, costura=True):
    for brazo in (BRAZO_D, BRAZO_I):
        for k in CARAS_BRAZO:
            c = brazo[k]
            l.rect(c, 0, desde, 1, hasta, valor)
            l.linea(c, [(0, desde), (1, desde)], 1.0, valor - 40)
            if costura:
                l.puntadas(c, [(0.02, (desde + hasta) / 2), (0.98, (desde + hasta) / 2)], valor - 48)


def dobladillo(l, desde, hasta, valor):
    for k in LADOS:
        c = TORSO[k]
        l.rect(c, 0, desde, 1, hasta, valor)
        l.linea(c, [(0, desde), (1, desde)], 1.0, valor - 40)
        l.puntadas(c, [(0.02, (desde + hasta) / 2), (0.98, (desde + hasta) / 2)], valor - 50)


def costuras_laterales(l, valor):
    for k in ("R", "L"):
        l.linea(TORSO[k], [(0.5, 0.02), (0.5, 0.98)], 0.9, valor)
    l.linea(TORSO["B"], [(0.5, 0.0), (0.5, 0.98)], 0.8, valor + 10)


def cordones(l, cara, x, y0, y1, valor, cruces=4, ancho=0.16):
    """Cordones cruzados (en la abertura del cuello o en un corpiño)."""
    paso = (y1 - y0) / cruces
    for i in range(cruces):
        ya, yb = y0 + i * paso, y0 + (i + 1) * paso
        l.linea(cara, [(x - ancho / 2, ya), (x + ancho / 2, yb)], 1.2, valor)
        l.linea(cara, [(x + ancho / 2, ya), (x - ancho / 2, yb)], 1.2, valor)
    for i in range(cruces + 1):
        yy = y0 + i * paso
        l.circulo(cara, x - ancho / 2 - 0.01, yy, 0.9, valor - 20)
        l.circulo(cara, x + ancho / 2 + 0.01, yy, 0.9, valor - 20)


def malla(l, cara, fy0, fy1, base):
    """Cota de malla: anillas pequeñas."""
    x, y, w, h = cara
    l.tela(cara, fy0, fy1, base, borde=14)
    filas = int((fy1 - fy0) * h / 3.2)
    cols = int(w / 3.6)
    for j in range(filas):
        for i in range(cols + 1):
            fx = (i + (0.5 if j % 2 else 0)) / cols
            fy = fy0 + (j + 0.6) / filas * (fy1 - fy0)
            cx, cy = l.punto(cara, fx, fy)
            r = 1.5 * S
            l.dg.arc([cx - r, cy - r, cx + r, cy + r], 200, 340, fill=base - 70, width=S)
            l.dg.arc([cx - r, cy - r * 0.6, cx + r, cy + r * 1.2], 20, 160, fill=min(255, base + 30), width=max(1, S // 2))


# ===== CAMISAS (12) =====
def camisa_tunica():
    l = Lienzo()
    b = 234
    torso_completo(l, b)
    mangas(l, b, 0.80)
    puno(l, 0.70, 0.80, b - 10)
    dobladillo(l, 0.86, 1.0, b - 8)
    costuras_laterales(l, b - 40)
    f = TORSO["F"]
    l.corte(f, [(0.36, -0.01), (0.5, 0.36), (0.64, -0.01)])
    l.linea(f, [(0.36, 0.0), (0.5, 0.36), (0.64, 0.0)], 1.4, b - 46)
    cordones(l, f, 0.5, 0.06, 0.30, 120, 3, 0.10)
    l.linea(f, [(0.18, 0.55), (0.35, 0.62)], 1.0, b - 28)
    l.linea(f, [(0.82, 0.55), (0.65, 0.62)], 1.0, b - 28)
    return l.imagen()


def camisa_lino():
    l = Lienzo()
    b = 246
    torso_completo(l, b)
    mangas(l, b, 0.46, holgura=True)
    puno(l, 0.40, 0.46, b - 14, costura=False)
    for brazo in (BRAZO_D, BRAZO_I):  # fruncido del puño
        for k in CARAS_BRAZO:
            for fx in (0.15, 0.35, 0.55, 0.75, 0.9):
                l.linea(brazo[k], [(fx, 0.40), (fx + 0.04, 0.46)], 0.7, b - 50)
    costuras_laterales(l, b - 40)
    f = TORSO["F"]
    l.corte(f, [(0.44, -0.01), (0.5, 0.40), (0.56, -0.01)])
    # cuello vuelto
    l.poligono(f, [(0.28, 0.0), (0.44, 0.0), (0.49, 0.22), (0.36, 0.16)], b - 4)
    l.poligono(f, [(0.72, 0.0), (0.56, 0.0), (0.51, 0.22), (0.64, 0.16)], b - 4)
    l.linea(f, [(0.28, 0.0), (0.36, 0.16), (0.49, 0.22)], 1.0, b - 50)
    l.linea(f, [(0.72, 0.0), (0.64, 0.16), (0.51, 0.22)], 1.0, b - 50)
    cordones(l, f, 0.5, 0.18, 0.38, 140, 2, 0.08)
    for k in LADOS:
        l.linea(TORSO[k], [(0.05, 0.72), (0.5, 0.76), (0.95, 0.72)], 1.0, b - 26)
    return l.imagen()


def camisa_gambeson():
    l = Lienzo()
    b = 226
    torso_completo(l, b)
    mangas(l, b, 0.80)
    puno(l, 0.72, 0.80, b - 16)
    dobladillo(l, 0.90, 1.0, b - 12)
    for k in LADOS:  # acolchado vertical
        c = TORSO[k]
        n = 7 if k in ("F", "B") else 4
        for i in range(1, n):
            fx = i / n
            if k == "F" and abs(fx - 0.5) < 0.06:
                continue
            l.linea(c, [(fx, 0.1), (fx, 0.9)], 1.2, b - 46)
            l.linea(c, [(fx + 0.02, 0.1), (fx + 0.02, 0.9)], 0.6, min(255, b + 18))
    for brazo in (BRAZO_D, BRAZO_I):  # acolchado horizontal en mangas
        for k in CARAS_BRAZO:
            for fy in (0.12, 0.24, 0.36, 0.48, 0.60):
                l.linea(brazo[k], [(0, fy), (1, fy)], 1.2, b - 46)
    for k in LADOS:  # cuello alto
        l.rect(TORSO[k], 0, 0, 1, 0.10, b - 18)
        l.linea(TORSO[k], [(0, 0.10), (1, 0.10)], 1.0, b - 60)
    f = TORSO["F"]
    l.linea(f, [(0.5, 0.0), (0.5, 0.9)], 1.4, b - 70)
    for fy in (0.2, 0.36, 0.52, 0.68):
        l.rect(f, 0.44, fy - 0.02, 0.56, fy + 0.02, b - 80)
    return l.imagen()


def camisa_chaqueta():
    l = Lienzo()
    b = 228
    torso_completo(l, b)
    mangas(l, b, 0.80)
    puno(l, 0.68, 0.80, b - 22)
    dobladillo(l, 0.92, 1.0, b - 10)
    costuras_laterales(l, b - 42)
    f = TORSO["F"]
    l.poligono(f, [(0.40, 0.0), (0.60, 0.0), (0.55, 0.56), (0.45, 0.56)], 252)  # camisa de debajo
    l.linea(f, [(0.5, 0.06), (0.5, 0.5)], 0.8, 210)
    # solapas
    l.poligono(f, [(0.22, 0.0), (0.40, 0.0), (0.45, 0.56), (0.30, 0.30)], b - 22)
    l.poligono(f, [(0.78, 0.0), (0.60, 0.0), (0.55, 0.56), (0.70, 0.30)], b - 22)
    l.linea(f, [(0.22, 0.0), (0.30, 0.30), (0.45, 0.56), (0.45, 1.0)], 1.2, b - 70)
    l.linea(f, [(0.78, 0.0), (0.70, 0.30), (0.55, 0.56), (0.55, 1.0)], 1.2, b - 70)
    for fy in (0.62, 0.74, 0.86):
        l.circulo(f, 0.40, fy, 1.6, b - 90)
    # bolsillos
    for x0 in (0.12, 0.62):
        l.rect(f, x0, 0.66, x0 + 0.26, 0.72, b - 16)
        l.linea(f, [(x0, 0.72), (x0 + 0.26, 0.72)], 1.0, b - 60)
    return l.imagen()


def camisa_mago():
    l = Lienzo()
    b = 222
    torso_completo(l, b)
    mangas(l, b, 0.80, holgura=True)
    for brazo in (BRAZO_D, BRAZO_I):  # borde de runas en el puño
        for k in CARAS_BRAZO:
            c = brazo[k]
            l.rect(c, 0, 0.66, 1, 0.80, b + 18)
            l.linea(c, [(0, 0.66), (1, 0.66)], 1.0, b - 60)
            l.linea(c, [(0, 0.80), (1, 0.80)], 1.0, b - 60)
            for i in range(4):
                fx = 0.12 + i * 0.25
                l.linea(c, [(fx, 0.69), (fx + 0.08, 0.77), (fx + 0.16, 0.69)], 0.8, b - 70)
    f = TORSO["F"]
    # cuello cruzado
    l.poligono(f, [(0.30, 0.0), (0.42, 0.0), (0.62, 0.45), (0.52, 0.52)], b + 20)
    l.poligono(f, [(0.70, 0.0), (0.58, 0.0), (0.46, 0.30), (0.52, 0.40)], b + 20)
    l.linea(f, [(0.30, 0.0), (0.52, 0.52), (0.62, 0.45), (0.42, 0.0)], 1.0, b - 60)
    l.corte(f, [(0.42, -0.01), (0.5, 0.18), (0.58, -0.01)])
    # banda central bordada
    l.rect(f, 0.44, 0.52, 0.56, 1.0, b + 18)
    for fy in (0.6, 0.72, 0.84, 0.96):
        l.poligono(f, [(0.5, fy - 0.05), (0.54, fy), (0.5, fy + 0.05), (0.46, fy)], b - 50)
    l.linea(f, [(0.44, 0.52), (0.44, 1.0)], 0.8, b - 60)
    l.linea(f, [(0.56, 0.52), (0.56, 1.0)], 0.8, b - 60)
    for k in ("B", "R", "L"):
        l.rect(TORSO[k], 0, 0.9, 1, 1.0, b + 18)
    costuras_laterales(l, b - 40)
    return l.imagen()


def camisa_corpino():
    l = Lienzo()
    blusa, corp = 248, 214
    torso_completo(l, blusa)
    mangas(l, blusa, 0.42, holgura=True)
    for brazo in (BRAZO_D, BRAZO_I):
        for k in CARAS_BRAZO:
            l.linea(brazo[k], [(0, 0.40), (1, 0.42)], 1.2, blusa - 60)
    # corpiño encima
    for k in LADOS:
        l.tela(TORSO[k], 0.26, 1.0, corp)
        l.linea(TORSO[k], [(0, 0.26), (1, 0.26)], 1.4, corp - 60)
    f = TORSO["F"]
    l.corte(f, [(0.30, -0.01), (0.30, 0.16), (0.70, 0.16), (0.70, -0.01)])
    l.linea(f, [(0.30, 0.16), (0.70, 0.16)], 1.0, blusa - 40)
    cordones(l, f, 0.5, 0.32, 0.86, 250, 5, 0.14)
    for fx in (0.22, 0.78):
        l.linea(f, [(fx, 0.28), (fx, 0.98)], 0.8, corp - 46)
    return l.imagen()


def camisa_malla():
    l = Lienzo()
    b = 196
    for k in LADOS:
        malla(l, TORSO[k], 0, 1, b)
    l.tela(TORSO["U"], 0, 1, b, 6, 4)
    l.tela(TORSO["D"], 0, 1, b - 10, 6, 4)
    for brazo in (BRAZO_D, BRAZO_I):
        l.tela(brazo["U"], 0, 1, b, 5, 3)
        for k in CARAS_BRAZO:
            malla(l, brazo[k], 0, 0.34, b)
            l.rect(brazo[k], 0, 0.30, 1, 0.36, 150)
    for k in LADOS:  # ribete de cuero
        l.rect(TORSO[k], 0, 0, 1, 0.07, 150)
        l.rect(TORSO[k], 0, 0.93, 1, 1.0, 150)
    l.corte(TORSO["F"], [(0.38, -0.01), (0.5, 0.12), (0.62, -0.01)])
    return l.imagen()


def camisa_pieles():
    l = Lienzo()
    b = 220
    torso_completo(l, b)
    mangas(l, b, 0.80)
    random.seed(7)

    def piel(cara, fy0, fy1):
        l.rect(cara, 0, fy0, 1, fy1, 250)
        x, y, w, h = cara
        n = int(w / 5)
        for i in range(n + 1):
            fx = i / n
            l.poligono(cara, [(fx - 0.05, fy1 - 0.01), (fx + 0.02, fy1 + 0.045), (fx + 0.07, fy1 - 0.01)], 246)
            l.linea(cara, [(fx, fy0 + 0.02), (fx + 0.02, fy1 - 0.02)], 0.6, 214)

    for k in LADOS:
        piel(TORSO[k], 0, 0.16)
        piel(TORSO[k], 0.88, 0.97)
    for brazo in (BRAZO_D, BRAZO_I):
        for k in CARAS_BRAZO:
            piel(brazo[k], 0.66, 0.78)
    f = TORSO["F"]
    l.linea(f, [(0.5, 0.17), (0.5, 0.88)], 1.4, b - 70)
    for fy in (0.3, 0.48, 0.66):
        l.rect(f, 0.42, fy - 0.015, 0.58, fy + 0.015, 120)
        l.circulo(f, 0.42, fy, 1.2, 100)
        l.circulo(f, 0.58, fy, 1.2, 100)
    costuras_laterales(l, b - 40)
    return l.imagen()


def camisa_desierto():
    l = Lienzo()
    b = 240
    torso_completo(l, b)
    mangas(l, b, 0.50, holgura=True)
    f = TORSO["F"]
    # panel cruzado
    l.poligono(f, [(0.20, 0.0), (0.42, 0.0), (1.0, 0.64), (1.0, 0.86)], b - 14)
    l.linea(f, [(0.20, 0.0), (1.0, 0.86)], 1.2, b - 66)
    l.corte(f, [(0.36, -0.01), (0.46, 0.14), (0.58, -0.01)])
    # fajín
    for k in LADOS:
        c = TORSO[k]
        l.rect(c, 0, 0.66, 1, 0.86, b - 30)
        for fy in (0.71, 0.76, 0.81):
            l.linea(c, [(0, fy), (0.5, fy + 0.012), (1, fy)], 0.8, b - 72)
    l.linea(f, [(0.7, 0.86), (0.66, 1.0)], 1.4, b - 70)
    l.linea(f, [(0.78, 0.86), (0.80, 1.0)], 1.4, b - 70)
    return l.imagen()


def camisa_chaleco():
    l = Lienzo()
    b = 216
    torso_completo(l, b)
    f = TORSO["F"]
    l.corte(f, [(0.32, -0.01), (0.5, 0.52), (0.68, -0.01)])
    l.linea(f, [(0.32, 0.0), (0.5, 0.52), (0.5, 1.0)], 1.4, b - 70)
    l.linea(f, [(0.68, 0.0), (0.5, 0.52)], 1.4, b - 70)
    for fy in (0.6, 0.72, 0.84):
        l.circulo(f, 0.44, fy, 1.5, b - 96)
    for x0 in (0.12, 0.64):
        l.puntadas(f, [(x0, 0.64), (x0 + 0.24, 0.64), (x0 + 0.24, 0.78), (x0, 0.78), (x0, 0.64)], b - 60)
    for k in LADOS:
        l.puntadas(TORSO[k], [(0.04, 0.94), (0.96, 0.94)], b - 60)
    costuras_laterales(l, b - 44)
    return l.imagen()


def camisa_sobreveste():
    l = Lienzo()
    b = 232
    for k in LADOS:
        malla(l, TORSO[k], 0, 1, 190)
    l.tela(TORSO["U"], 0, 1, 196, 6, 4)
    l.tela(TORSO["D"], 0, 1, 186, 6, 4)
    for brazo in (BRAZO_D, BRAZO_I):
        l.tela(brazo["U"], 0, 1, 196, 5, 3)
        for k in CARAS_BRAZO:
            malla(l, brazo[k], 0, 0.80, 190)
    # sobreveste (tela teñida) encima, delante y detrás
    for k in ("F", "B"):
        c = TORSO[k]
        l.tela(c, 0.08, 1.0, b, borde=8)
        l.poligono(c, [(0.0, 0.08), (0.18, 0.0), (0.82, 0.0), (1.0, 0.08)], b)
        l.linea(c, [(0.04, 0.12), (0.04, 0.98), (0.96, 0.98), (0.96, 0.12)], 1.0, b - 50)
    f = TORSO["F"]
    # emblema: un sol de 8 rayos
    for i in range(8):
        a = i * math.pi / 4
        l.linea(f, [(0.5, 0.5), (0.5 + 0.2 * math.cos(a), 0.5 + 0.2 * math.sin(a))], 2.2, b - 70)
    l.circulo(f, 0.5, 0.5, 8, b - 30, contorno=b - 80)
    for k in ("R", "L"):  # cinturón de cuero en los lados
        l.rect(TORSO[k], 0, 0.78, 1, 0.86, 140)
    return l.imagen()


def camisa_harapos():
    l = Lienzo()
    b = 222
    torso_completo(l, b)
    mangas(l, b, 0.36)
    random.seed(3)
    for k in LADOS:  # borde de abajo roto
        c = TORSO[k]
        pts = [(0, 1.01)]
        n = 9 if k in ("F", "B") else 5
        for i in range(n + 1):
            pts.append((i / n, 0.86 + random.random() * 0.12))
        pts.append((1, 1.01))
        l.corte(c, pts)
    for brazo in (BRAZO_D, BRAZO_I):
        for k in CARAS_BRAZO:
            c = brazo[k]
            pts = [(0, 0.40)]
            for i in range(5):
                pts.append((i / 4, 0.28 + random.random() * 0.08))
            pts.append((1, 0.40))
            l.corte(c, pts)
    f = TORSO["F"]
    l.rect(f, 0.14, 0.22, 0.34, 0.40, b - 34)  # remiendos
    l.puntadas(f, [(0.14, 0.22), (0.34, 0.22), (0.34, 0.40), (0.14, 0.40), (0.14, 0.22)], b - 90)
    l.rect(f, 0.6, 0.56, 0.78, 0.70, b + 12)
    l.puntadas(f, [(0.6, 0.56), (0.78, 0.56), (0.78, 0.70), (0.6, 0.70), (0.6, 0.56)], b - 90)
    l.corte(f, [(0.40, -0.01), (0.5, 0.2), (0.60, -0.01)])
    l.linea(TORSO["B"], [(0.3, 0.3), (0.42, 0.42)], 1.0, b - 60)
    costuras_laterales(l, b - 40)
    return l.imagen()


# ===== PANTALONES (6) =====
def piernas(l, base, largo=0.84):
    for pierna in (BRAZO_D, BRAZO_I):
        for k in CARAS_BRAZO:
            l.tela(pierna[k], 0, largo, base - (6 if k in ("In", "Out") else 0))
        l.tela(pierna["U"], 0, 1, base + 4, 5, 3)


def zapatos(l, desde=0.84, valor=96):
    for pierna in (BRAZO_D, BRAZO_I):
        for k in CARAS_BRAZO:
            c = pierna[k]
            l.tela(c, desde, 1.0, valor, borde=8, vertical=6)
            l.linea(c, [(0, desde), (1, desde)], 1.2, valor - 40)
        l.tela(pierna["D"], 0, 1, valor - 20, 4, 2)


def cintura(l, base):
    for k in LADOS:
        l.tela(TORSO[k], 0.62, 1.0, base)
        l.rect(TORSO[k], 0, 0.80, 1, 0.88, base - 20)
        l.linea(TORSO[k], [(0, 0.80), (1, 0.80)], 1.0, base - 60)
    l.tela(TORSO["D"], 0, 1, base - 10, 6, 4)


def pantalon_calzas():
    l = Lienzo()
    b = 228
    cintura(l, b)
    piernas(l, b)
    zapatos(l)
    for pierna in (BRAZO_D, BRAZO_I):
        for k in CARAS_BRAZO:
            c = pierna[k]
            l.linea(c, [(0.1, 0.44), (0.5, 0.47), (0.9, 0.44)], 1.0, b - 34)
            l.linea(c, [(0.2, 0.72), (0.5, 0.76), (0.8, 0.72)], 1.0, b - 30)
        l.linea(pierna["Out"], [(0.5, 0.0), (0.5, 0.84)], 0.8, b - 40)
    l.linea(TORSO["F"], [(0.46, 0.84), (0.5, 0.92), (0.54, 0.84)], 1.0, b - 70)
    return l.imagen()


def pantalon_cuero():
    l = Lienzo()
    b = 206
    cintura(l, b)
    piernas(l, b)
    zapatos(l, valor=84)
    for pierna in (BRAZO_D, BRAZO_I):
        l.puntadas(pierna["Out"], [(0.5, 0.0), (0.5, 0.84)], b - 70)
        l.puntadas(pierna["In"], [(0.5, 0.0), (0.5, 0.84)], b - 70)
        f = pierna["F"]
        l.rect(f, 0.16, 0.38, 0.84, 0.56, b + 14)
        l.puntadas(f, [(0.16, 0.38), (0.84, 0.38), (0.84, 0.56), (0.16, 0.56), (0.16, 0.38)], b - 70)
    return l.imagen()


def pantalon_bombacho():
    l = Lienzo()
    b = 240
    cintura(l, b)
    piernas(l, b)
    zapatos(l, 0.86, 120)
    for pierna in (BRAZO_D, BRAZO_I):
        for k in CARAS_BRAZO:
            c = pierna[k]
            for fy in (0.15, 0.32, 0.48):
                l.linea(c, [(0.08, fy), (0.4, fy + 0.07), (0.92, fy + 0.03)], 1.1, b - 40)
            l.rect(c, 0, 0.62, 1, 0.86, b - 26)  # vendas en la espinilla
            for fy in (0.64, 0.70, 0.76, 0.82):
                l.linea(c, [(0, fy), (1, fy + 0.035)], 1.0, b - 70)
    return l.imagen()


def pantalon_falda():
    l = Lienzo()
    b = 232
    cintura(l, b)
    piernas(l, b, 0.92)
    zapatos(l, 0.92, 100)
    for pierna in (BRAZO_D, BRAZO_I):
        for k in CARAS_BRAZO:
            c = pierna[k]
            for fx in (0.2, 0.45, 0.72):
                l.linea(c, [(fx, 0.02), (fx - 0.04, 0.5), (fx + 0.02, 0.88)], 1.1, b - 34)
            l.rect(c, 0, 0.84, 1, 0.92, b - 20)
            l.linea(c, [(0, 0.84), (1, 0.84)], 1.0, b - 56)
    return l.imagen()


def pantalon_faldon():
    l = Lienzo()
    falda, calza = 238, 188
    cintura(l, falda)
    piernas(l, calza)
    zapatos(l)
    for pierna in (BRAZO_D, BRAZO_I):
        for k in CARAS_BRAZO:
            c = pierna[k]
            l.tela(c, 0, 0.46, falda)
            l.rect(c, 0, 0.40, 1, 0.46, falda - 22)
            l.linea(c, [(0, 0.46), (1, 0.46)], 1.2, falda - 80)
            for fx in (0.3, 0.7):
                l.linea(c, [(fx, 0.02), (fx - 0.03, 0.40)], 1.0, falda - 34)
            l.linea(c, [(0.2, 0.7), (0.5, 0.73), (0.8, 0.7)], 1.0, calza - 30)
    return l.imagen()


def pantalon_acolchado():
    l = Lienzo()
    b = 222
    cintura(l, b)
    piernas(l, b)
    zapatos(l, valor=90)
    for pierna in (BRAZO_D, BRAZO_I):
        for k in CARAS_BRAZO:
            c = pierna[k]
            for fy in (0.1, 0.2, 0.3, 0.6, 0.7):
                l.linea(c, [(0, fy), (1, fy)], 1.1, b - 44)
        f = pierna["F"]
        l.rect(f, 0.14, 0.36, 0.86, 0.54, b - 30)  # rodillera
        l.linea(f, [(0.14, 0.36), (0.86, 0.36), (0.86, 0.54), (0.14, 0.54), (0.14, 0.36)], 1.0, b - 80)
    return l.imagen()


CAMISAS = [
    ("Camisa_Tunica", camisa_tunica), ("Camisa_Lino", camisa_lino), ("Camisa_Gambeson", camisa_gambeson),
    ("Camisa_Chaqueta", camisa_chaqueta), ("Camisa_Mago", camisa_mago), ("Camisa_Corpino", camisa_corpino),
    ("Camisa_Malla", camisa_malla), ("Camisa_Pieles", camisa_pieles), ("Camisa_Desierto", camisa_desierto),
    ("Camisa_Chaleco", camisa_chaleco), ("Camisa_Sobreveste", camisa_sobreveste), ("Camisa_Harapos", camisa_harapos),
]
PANTALONES = [
    ("Pantalon_Calzas", pantalon_calzas), ("Pantalon_Cuero", pantalon_cuero), ("Pantalon_Bombacho", pantalon_bombacho),
    ("Pantalon_Falda", pantalon_falda), ("Pantalon_Faldon", pantalon_faldon), ("Pantalon_Acolchado", pantalon_acolchado),
]


# ===== CARAS (anime limpio) =====
C = 1024  # lienzo de la cara (se reduce a 256)
NEGRO = (28, 22, 26, 255)


def ojo(d, cx, cy, ancho, alto, iris, estilo="normal", lado=1, pestanas=False):
    """Un ojo estilo anime. cx, cy en píxeles del lienzo de 1024."""
    w, h = ancho / 2, alto / 2
    if estilo == "cerrado":  # ^ ^ (feliz)
        d.line([(cx - w, cy + h * 0.25), (cx, cy - h * 0.45), (cx + w, cy + h * 0.25)], fill=NEGRO, width=22, joint="curve")
        return
    if estilo == "guino":
        d.line([(cx - w, cy), (cx + w, cy + 6)], fill=NEGRO, width=22)
        return
    caja = [cx - w, cy - h, cx + w, cy + h]
    if estilo == "entornado":  # párpado bajo: mirada fría
        caja = [cx - w, cy - h * 0.45, cx + w, cy + h]
    d.ellipse(caja, fill=(250, 248, 246, 255))
    # iris con degradado (más oscuro arriba)
    iw, ih = w * 0.78, h * 0.86
    icx = cx - lado * w * 0.06
    oscuro = tuple(int(c * 0.45) for c in iris)
    for i in range(40):
        t = i / 39
        col = tuple(int(oscuro[k] + (iris[k] - oscuro[k]) * t) for k in range(3)) + (255,)
        r = 1 - t * 0.0
        yy0 = cy - ih + t * ih * 1.4
        d.ellipse([icx - iw * r, max(caja[1], yy0), icx + iw * r, cy + ih], fill=col)
    d.ellipse([icx - iw * 0.45, cy - ih * 0.25, icx + iw * 0.45, cy + ih * 0.6], fill=NEGRO)
    # brillos
    d.ellipse([icx - iw * 0.62, cy - ih * 0.62, icx - iw * 0.05, cy - ih * 0.05], fill=(255, 255, 255, 255))
    d.ellipse([icx + iw * 0.2, cy + ih * 0.25, icx + iw * 0.5, cy + ih * 0.55], fill=(255, 255, 255, 230))
    # párpado superior grueso
    arriba = caja[1]
    d.arc([cx - w * 1.08, arriba - 4, cx + w * 1.08, cy + h * 1.15], 192, 348, fill=NEGRO, width=26)
    if estilo == "entornado":
        d.line([(cx - w * 1.05, arriba + 6), (cx + w * 1.05, arriba + 2)], fill=NEGRO, width=24)
    # línea de abajo fina
    d.arc([cx - w * 0.85, cy - h * 0.9, cx + w * 0.85, cy + h * 1.02], 40, 140, fill=NEGRO, width=8)
    if pestanas:
        ex = cx + lado * w * 1.02
        d.line([(ex, arriba + h * 0.35), (ex + lado * 34, arriba + h * 0.05)], fill=NEGRO, width=18)
        d.line([(ex - lado * 6, arriba + h * 0.15), (ex + lado * 26, arriba - h * 0.22)], fill=NEGRO, width=14)


def ceja(d, cx, cy, ancho, inclinacion, grosor=20, lado=1):
    w = ancho / 2
    d.line([(cx - w, cy + inclinacion * lado), (cx, cy - 6), (cx + w, cy - inclinacion * lado)],
           fill=NEGRO, width=grosor, joint="curve")


def boca(d, tipo, cx=512, cy=690):
    if tipo == "sonrisa":
        d.arc([cx - 70, cy - 60, cx + 70, cy + 30], 20, 160, fill=NEGRO, width=16)
    elif tipo == "abierta":
        d.chord([cx - 60, cy - 40, cx + 60, cy + 60], 0, 180, fill=(120, 40, 50, 255), outline=NEGRO, width=12)
        d.chord([cx - 34, cy + 18, cx + 34, cy + 58], 180, 360, fill=(220, 110, 120, 255))
    elif tipo == "plana":
        d.line([(cx - 44, cy), (cx + 44, cy)], fill=NEGRO, width=14)
    elif tipo == "picara":
        d.arc([cx - 70, cy - 50, cx + 50, cy + 24], 10, 120, fill=NEGRO, width=16)
    elif tipo == "dientes":
        d.rounded_rectangle([cx - 70, cy - 26, cx + 70, cy + 30], 18, fill=(250, 250, 250, 255), outline=NEGRO, width=12)
        d.line([(cx - 64, cy + 2), (cx + 64, cy + 2)], fill=NEGRO, width=8)
    elif tipo == "pequena":
        d.arc([cx - 30, cy - 20, cx + 30, cy + 14], 20, 160, fill=NEGRO, width=12)
    elif tipo == "triste":
        d.arc([cx - 50, cy - 4, cx + 50, cy + 60], 200, 340, fill=NEGRO, width=14)
    elif tipo == "gato":  # :3
        d.arc([cx - 50, cy - 30, cx, cy + 20], 0, 180, fill=NEGRO, width=12)
        d.arc([cx, cy - 30, cx + 50, cy + 20], 0, 180, fill=NEGRO, width=12)


def rubor(d):
    for cx in (330, 694):
        d.ellipse([cx - 70, 590, cx + 70, 640], fill=(240, 120, 130, 90))


def cara(iris, estilo="normal", cejas=(0, 20), bocaTipo="sonrisa", pestanas=False, sonrojo=False,
         tam=(150, 190), cicatriz=False, arrugas=False, ojeras=False, separacion=150, alto_ojos=470,
         iris2=None, guino=False):
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if sonrojo:
        capa = Image.new("RGBA", (C, C), (0, 0, 0, 0))
        rubor(ImageDraw.Draw(capa))
        capa = capa.filter(ImageFilter.GaussianBlur(14))
        img.alpha_composite(capa)
        d = ImageDraw.Draw(img)
    for lado in (-1, 1):
        cx = 512 + lado * separacion
        e = estilo
        if guino and lado == 1:
            e = "guino"
        ojo(d, cx, alto_ojos, tam[0], tam[1], iris2 if (iris2 and lado == 1) else iris, e, lado, pestanas)
        ceja(d, cx, alto_ojos - tam[1] * 0.78 - cejas[0], tam[0] * 0.95, cejas[1], 20, lado)
        if ojeras:
            d.arc([cx - 60, alto_ojos + 40, cx + 60, alto_ojos + 120], 30, 150, fill=(80, 60, 70, 160), width=8)
        if arrugas:
            d.arc([cx - 56, alto_ojos + 50, cx + 56, alto_ojos + 110], 25, 155, fill=(90, 66, 60, 170), width=7)
    if arrugas:
        d.arc([380, 600, 470, 720], 100, 200, fill=(70, 55, 55, 180), width=8)
        d.arc([554, 600, 644, 720], 340, 80, fill=(70, 55, 55, 180), width=8)
    if cicatriz:
        d.line([(600, 330), (730, 600)], fill=(150, 70, 70, 255), width=14)
        for t in (0.3, 0.55, 0.8):
            x, y = 600 + 130 * t, 330 + 270 * t
            d.line([(x - 22, y + 8), (x + 22, y - 8)], fill=(150, 70, 70, 255), width=8)
    boca(d, bocaTipo)
    # acercar un poco (rasgos más grandes y legibles en la cabeza de bloque)
    m = int(C * 0.1)
    return img.crop((m, m, C - m, C - m)).resize((256, 256), Image.LANCZOS)


MARRON, AZUL, VERDE, AMBAR, GRIS, VIOLETA, ROJO, CELESTE, MIEL = (
    (120, 76, 44), (60, 110, 190), (60, 140, 90), (210, 150, 50), (120, 130, 140), (140, 90, 200),
    (190, 50, 60), (90, 180, 220), (170, 120, 60))

CARAS = [
    ("Cara_Sereno", dict(iris=MARRON, cejas=(0, 8), bocaTipo="pequena", tam=(130, 160))),
    ("Cara_Decidido", dict(iris=AZUL, cejas=(-6, 34), bocaTipo="picara", tam=(130, 160))),
    ("Cara_Frio", dict(iris=GRIS, estilo="entornado", cejas=(-10, 26), bocaTipo="plana", tam=(140, 150))),
    ("Cara_Alegre", dict(iris=VERDE, cejas=(10, -6), bocaTipo="abierta", tam=(130, 170))),
    ("Cara_Cicatriz", dict(iris=AMBAR, cejas=(-4, 30), bocaTipo="plana", tam=(126, 156), cicatriz=True)),
    ("Cara_Fiero", dict(iris=ROJO, cejas=(-16, 44), bocaTipo="dientes", tam=(120, 140))),
    ("Cara_Cansado", dict(iris=MIEL, estilo="entornado", cejas=(4, -10), bocaTipo="triste", tam=(130, 150), ojeras=True)),
    ("Cara_Picaro", dict(iris=VERDE, cejas=(0, 18), bocaTipo="picara", tam=(130, 160), guino=True)),
    ("Cara_Dulce", dict(iris=MARRON, cejas=(12, -8), bocaTipo="sonrisa", pestanas=True, sonrojo=True, tam=(160, 200))),
    ("Cara_Seria", dict(iris=AZUL, cejas=(-2, 14), bocaTipo="plana", pestanas=True, tam=(150, 180))),
    ("Cara_Kawaii", dict(iris=CELESTE, cejas=(16, -4), bocaTipo="gato", pestanas=True, sonrojo=True, tam=(170, 220))),
    ("Cara_Altiva", dict(iris=VIOLETA, estilo="entornado", cejas=(-4, 16), bocaTipo="picara", pestanas=True, tam=(156, 170))),
    ("Cara_Timida", dict(iris=MIEL, cejas=(14, -14), bocaTipo="pequena", pestanas=True, sonrojo=True, tam=(156, 196))),
    ("Cara_Guerrera", dict(iris=AMBAR, cejas=(-12, 40), bocaTipo="plana", pestanas=True, tam=(144, 170))),
    ("Cara_Feliz", dict(iris=MARRON, estilo="cerrado", cejas=(14, -4), bocaTipo="abierta", tam=(150, 160), sonrojo=True)),
    ("Cara_Intensa", dict(iris=AZUL, iris2=AMBAR, cejas=(-8, 30), bocaTipo="plana", tam=(140, 170))),
    ("Cara_Anciano", dict(iris=GRIS, cejas=(2, -6), bocaTipo="sonrisa", tam=(110, 120), arrugas=True)),
    ("Cara_Anciana", dict(iris=AZUL, cejas=(6, -6), bocaTipo="pequena", pestanas=True, tam=(120, 130), arrugas=True)),
]


# ===== Compresión para Luau: paleta + repeticiones (RLE) =====
def comprimir(img):
    """Formato: u16 colores, colores RGBA, luego pares (índice u8, repeticiones u8)."""
    img = img.convert("RGBA")
    datos = list(img.get_flattened_data()) if hasattr(img, 'get_flattened_data') else list(img.getdata())
    # lo transparente es todo igual (0,0,0,0)
    datos = [(0, 0, 0, 0) if a == 0 else (r, g, b, a) for (r, g, b, a) in datos]
    paleta = {}
    orden = []
    for p in datos:
        if p not in paleta:
            paleta[p] = len(orden)
            orden.append(p)
    if len(orden) > 256:
        # reducir colores (caras): cuantizar a 64 niveles y repetir
        img2 = img.quantize(colors=255, method=Image.Quantize.FASTOCTREE).convert("RGBA")
        return comprimir(img2)
    salida = bytearray(struct.pack("<H", len(orden)))
    for r, g, b, a in orden:
        salida += bytes((r, g, b, a))
    i = 0
    n = len(datos)
    while i < n:
        p = datos[i]
        j = i + 1
        while j < n and j - i < 255 and datos[j] == p:
            j += 1
        salida += bytes((paleta[p], j - i))
        i = j
    return bytes(salida)


def escribir_modulo(nombre, img):
    datos = comprimir(img)
    texto = base64.b64encode(datos).decode("ascii")
    ancho, alto = img.size
    lineas = [texto[i:i + 120] for i in range(0, len(texto), 120)]
    luau = (
        f"-- Textura «{nombre}» (generada por herramientas/texturas/generar.py). No editar a mano.\n"
        f"-- La sube a Roblox ServerStorage/Herramientas/PluginSubidor.\n"
        f"return {{\n\tnombre = \"{nombre}\",\n\tancho = {ancho},\n\talto = {alto},\n\tformato = \"rle\",\n"
        f"\tdatos = table.concat({{\n" + "".join(f"\t\t\"{ln}\",\n" for ln in lineas) + "\t}),\n}\n"
    )
    with open(os.path.join(SALIDA_LUAU, nombre + ".luau"), "w") as f:
        f.write(luau)
    return len(datos)


def main():
    os.makedirs(SALIDA_PNG, exist_ok=True)
    os.makedirs(SALIDA_LUAU, exist_ok=True)
    total = 0
    todo = [(n, f()) for n, f in CAMISAS + PANTALONES] + [(n, cara(**k)) for n, k in CARAS]
    for nombre, img in todo:
        img.save(os.path.join(SALIDA_PNG, nombre + ".png"))
        tam = escribir_modulo(nombre, img)
        total += tam
        print(f"{nombre:22s} {tam/1024:7.1f} KB")
    print(f"TOTAL {total/1024:.0f} KB en {len(todo)} texturas")


if __name__ == "__main__":
    main()
