#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GARDIEN LUNAIRE — modèle 3D fait avec Blender, pour Roblox
===========================================================

Ce script construit le Gardien lunaire (d'après l'image de référence « Lunar Guardian ») dans
Blender, en vrais maillages, puis l'exporte pour Roblox Studio :

- `GardienLunaire.fbx` : à importer dans Studio (Avatar > Importer 3D). 1 unité = 1 stud.
- `GardienLunaire.glb` : la même chose au format glTF (aperçu web, autres logiciels).
- `GardienLunaire.blend` : le fichier Blender (pièces rangées et articulées).
- `GardienLunaire_texture.png` : la texture (palette + textures « pierre » et « lune »).
- `GardienLunaire.installer.luau` : le script à coller dans la Command Bar de Studio après
  l'import (articulations, matériaux Neon/Glass, VFX, animation).
- `rendus/*.png` : les images (avec `--rendus`).

Style « cubes + pixels » (règle du créateur) : gros cubes, et **chaque face est couverte de
texture** (motifs gravés en pixels en relief + texture pierre de lune sur les grandes faces).

Utilisation (Python 3.11 avec le module `bpy` de Blender 5 et Pillow) :

    python blender/gardien_lunaire.py              # modèle + exports
    python blender/gardien_lunaire.py --rendus     # + rendus Cycles
    python blender/gardien_lunaire.py --rendus --vite   # rendus rapides (tests)

Repère Blender : x = droite du personnage, y = devant (la tête), z = haut. Le personnage regarde
+Y, ce qui donne -Z (le « devant » de Roblox) après l'export FBX.
"""

import json
import math
import os
import random
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(ICI)
SORTIE = os.path.join(RACINE, "dist", "blender", "GardienLunaire")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
FAIRE_RENDUS = "--rendus" in ARGS
VITE = "--vite" in ARGS

ID = "GardienLunaire"

# ---------------------------------------------------------------------------------------------
# Couleurs
# ---------------------------------------------------------------------------------------------
PAL = {
    "navy": (46, 38, 98), "navyDark": (32, 26, 72), "navyDeep": (22, 18, 52),
    "navyLight": (70, 60, 136), "navyPale": (104, 94, 182), "navyMid": (58, 48, 118),
    "magenta": (226, 66, 172), "magentaDark": (140, 30, 112), "magentaLight": (255, 140, 214),
    "moon": (232, 234, 250), "moonLav": (206, 200, 244), "moonShade": (178, 176, 224),
    "crater": (146, 142, 202), "craterDeep": (118, 112, 182),
    "eyeRim": (16, 20, 52), "nose": (14, 10, 34),
    "tip": (84, 62, 162), "tipCrater": (46, 32, 104), "tipLight": (122, 98, 206),
    "crystal": (226, 246, 255),
    # ajoutés pour coller à la référence
    "eyeIn": (36, 28, 86), "eyeLow": (58, 46, 124), "lunePale": (226, 238, 250), "disque": (196, 204, 232),
    "lavande": (138, 112, 210), "lavandeClair": (178, 160, 236), "rose": (255, 150, 214),
    "panneau": (84, 74, 162), "museau": (62, 52, 132),
}
# Pièces lumineuses : une couleur par pièce (matériau Neon / Glass dans Roblox)
LUMIERES = {
    "NeonCyan": (110, 236, 255), "NeonBlanc": (232, 252, 255), "NeonPale": (178, 244, 255),
    "NeonMagenta": (255, 140, 214), "Cristal": (214, 244, 255), "CristalCoeur": (150, 236, 255),
    "Halo": (110, 236, 255),
}
SWATCH = {nom: i for i, nom in enumerate(PAL)}

# Texture 1024 x 1024 : en haut la palette (cases de 32 px), en bas 4 bandes de « bruit »
# (pierre bleu nuit, lune, violet du bout de la queue, magenta) en gros pixels de 4 texels.
TEX = 1024
CASE = 32
BRUIT = {"navy": 256, "moon": 448, "tip": 640, "magenta": 832}
BRUIT_H = 192
TEXELS_PAR_STUD = 4 / 0.3  # 1 pixel de texture = 0,3 stud, comme les pixels gravés


def uv_case(couleur):
    i = SWATCH[couleur]
    cx = (i % (TEX // CASE)) * CASE + CASE / 2
    cy = (i // (TEX // CASE)) * CASE + CASE / 2
    return [((cx + dx) / TEX, 1 - (cy + dy) / TEX) for dx, dy in ((-6, -6), (6, -6), (6, 6), (-6, 6))]


# ---------------------------------------------------------------------------------------------
# Construction des maillages
# ---------------------------------------------------------------------------------------------
class Piece:
    def __init__(self, nom):
        self.nom = nom
        base, _, sorte = nom.partition("_")
        self.base = base
        self.sorte = sorte if sorte in LUMIERES else "Palette"
        self.v = []
        self.f = []
        self.uv = []

    def poly(self, pts, uvs):
        k = len(self.v)
        self.v.extend(pts)
        self.f.append(tuple(range(k, k + len(pts))))
        self.uv.append(uvs)


PIECES = {}


def piece(nom):
    if nom not in PIECES:
        PIECES[nom] = Piece(nom)
    return PIECES[nom]


RNG = random.Random(7)

# Faces d'un cube : (normale locale, coins (i, j, k) dans {0, 1}) en sens direct vu de dehors
FACES = {
    "+x": ((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
    "-x": ((-1, 0, 0), [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)]),
    "+y": ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]),
    "-y": ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
    "+z": ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]),
    "-z": ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]),
}
I3 = Matrix.Identity(3)


def mat_axes(u, v, n):
    """Matrice dont les colonnes sont u, v, n."""
    return Matrix((tuple(u), tuple(v), tuple(n))).transposed()


def box(nom, c, taille, couleur="navy", R=None, tex=None, skip=()):
    """Un pavé. `tex` = bande de bruit (« navy », « moon »…) pour texturer les grandes faces."""
    p = piece(nom)
    R = R if R is not None else I3
    c = Vector(c)
    h = Vector(taille) / 2
    inverse = R.determinant() < 0
    for cle, (_, coins) in FACES.items():
        if cle in skip:
            continue
        pts = [c + R @ Vector(((2 * i - 1) * h.x, (2 * j - 1) * h.y, (2 * k - 1) * h.z)) for i, j, k in coins]
        if tex and p.sorte == "Palette":
            axe = "xyz".index(cle[1])
            a, b = [q for q in range(3) if q != axe]
            dims = (h[a] * 2, h[b] * 2)
            wt = dims[0] * TEXELS_PAR_STUD
            ht = dims[1] * TEXELS_PAR_STUD
            echelle = min(1.0, (TEX - 8) / wt, (BRUIT_H - 8) / ht)
            wt, ht = wt * echelle, ht * echelle
            x0 = RNG.uniform(4, TEX - 4 - wt)
            y0 = BRUIT[tex] + RNG.uniform(4, BRUIT_H - 4 - ht)
            uvs = []
            for ijk in coins:
                uu = x0 + ijk[a] * wt
                vv = y0 + (1 - ijk[b]) * ht
                uvs.append((uu / TEX, 1 - vv / TEX))
        else:
            uvs = uv_case(couleur) if p.sorte == "Palette" else [(0.5, 0.5)] * 4
        if inverse:
            pts.reverse()
            uvs.reverse()
        p.poly(pts, uvs)


def base_orthonormee(d):
    d = Vector(d).normalized()
    a = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    x = a.cross(d).normalized()
    y = d.cross(x)
    return x, y, d


def cylindre(nom, c, axe, rayon, epaisseur, couleur="navy", seg=24):
    """Disque épais (yeux, lunes). Il part de `c` et avance de `epaisseur` le long de `axe`."""
    p = piece(nom)
    x, y, d = base_orthonormee(axe)
    c = Vector(c)
    bas = [c + (x * math.cos(t) + y * math.sin(t)) * rayon for t in (2 * math.pi * i / seg for i in range(seg))]
    haut = [q + d * epaisseur for q in bas]
    uv = uv_case(couleur) if p.sorte == "Palette" else [(0.5, 0.5)] * 4
    p.poly(list(reversed(bas)), [uv[0]] * seg)
    p.poly(haut, [uv[0]] * seg)
    for i in range(seg):
        j = (i + 1) % seg
        p.poly([bas[i], bas[j], haut[j], haut[i]], uv)


def eclat(nom, base, direction, longueur, rayon, graine, couleur="crystal", cotes=6):
    """Cristal à facettes : une bipyramide allongée un peu irrégulière."""
    p = piece(nom)
    r = random.Random(graine)
    x, y, d = base_orthonormee(direction)
    base = Vector(base)
    anneaux = []
    for t, k in ((0.22, 1.0), (0.68, 0.78)):
        anneau = []
        for i in range(cotes):
            a = 2 * math.pi * (i + r.uniform(-0.15, 0.15)) / cotes
            rr = rayon * k * r.uniform(0.82, 1.1)
            anneau.append(base + d * (longueur * t + r.uniform(-0.08, 0.08) * longueur) + (x * math.cos(a) + y * math.sin(a)) * rr)
        anneaux.append(anneau)
    pointe = base + d * longueur + x * r.uniform(-0.1, 0.1) * rayon
    uv = uv_case(couleur) if p.sorte == "Palette" else [(0.5, 0.5)] * 4
    a0, a1 = anneaux
    for i in range(cotes):
        j = (i + 1) % cotes
        p.poly([base, a0[j], a0[i]], uv[:3])
        p.poly([a0[i], a0[j], a1[j], a1[i]], uv)
        p.poly([a1[i], a1[j], pointe], uv[:3])


# ---------------------------------------------------------------------------------------------
# Pixels gravés
# ---------------------------------------------------------------------------------------------
def face(centre, n, haut):
    """Repère d'une face : origine, u (vers la droite vu de dehors), v (vers le haut), n."""
    n = Vector(n).normalized()
    haut = Vector(haut)
    v = (haut - n * haut.dot(n)).normalized()
    u = v.cross(n)
    return Vector(centre), u, v, n


# Palettes de pixels : caractère -> (suffixe de pièce lumineuse ou None, couleur, relief)
PIX_NAVY = {
    "L": (None, "navyPale", 0.14), "M": (None, "navyLight", 0.09), "K": (None, "navyDark", 0.05),
    "D": (None, "navyDeep", 0.03), "C": ("NeonCyan", None, 0.07), "W": ("NeonBlanc", None, 0.07),
    "S": (None, "moon", 0.08), "P": (None, "magenta", 0.06),
}
PIX_LUNE = {
    "K": (None, "crater", 0.03), "D": (None, "craterDeep", 0.02), "E": (None, "moonShade", 0.06),
    "S": (None, "moon", 0.1), "L": (None, "moonLav", 0.07), "C": ("NeonCyan", None, 0.07),
    "W": ("NeonBlanc", None, 0.07), "Q": ("NeonPale", None, 0.08),
}
PIX_LUNAIRE = {
    "L": (None, "navyPale", 0.13), "M": (None, "panneau", 0.1), "K": (None, "navyDark", 0.05),
    "D": (None, "navyDeep", 0.03),
}
PIX_BOUT = {
    "K": (None, "tipCrater", 0.03), "L": (None, "tipLight", 0.09), "M": (None, "navyPale", 0.06),
}


def pixels(nom, repere, px, lignes, pal=PIX_NAVY, relief=1.0):
    """Dessine des lignes de pixels sur une face ; les pixels voisins identiques sont fusionnés."""
    o, u, v, n = repere
    h = len(lignes)
    w = max(len(l) for l in lignes)
    R = mat_axes(u, v, n)
    for j, ligne in enumerate(lignes):
        i = 0
        while i < len(ligne):
            ch = ligne[i]
            if ch not in pal:
                i += 1
                continue
            k = i
            while k + 1 < len(ligne) and ligne[k + 1] == ch:
                k += 1
            sorte, couleur, prof = pal[ch]
            prof *= relief
            cible = nom if sorte is None else f"{nom}_{sorte}"
            centre = o + u * (((i + k) / 2 - (w - 1) / 2) * px) + v * (((h - 1) / 2 - j) * px) + n * (prof / 2)
            box(cible, centre, ((k - i + 1) * px, px, prof), couleur or "navy", R, skip=("-z",))
            i = k + 1


# Motifs (L clair en relief, M moyen, K sombre, D creux)
ENGRENAGE = [
    "...L.L.L...",
    "..LLLLLLL..",
    ".LLMMMMMLL.",
    "LLM.....MLL",
    ".LM.DDD.ML.",
    "LLM.DLD.MLL",
    ".LM.DDD.ML.",
    "LLM.....MLL",
    ".LLMMMMMLL.",
    "..LLLLLLL..",
    "...L.L.L...",
]
SPIRALE = [
    "LLLLLLLLL",
    "L.......L",
    "L.LLLLL.L",
    "L.L...L.L",
    "L.L.L.L.L",
    "L.L.L...L",
    "L.L.LLLLL",
    "L.L......",
    "L.LLLLLLL",
]
CROISSANT = [
    "..LLL..",
    ".LL....",
    "LL.....",
    "LL.....",
    "LL.....",
    ".LL....",
    "..LLL..",
]
PHASES = [
    "MMM..KMM..KKM..KKK..MKK..MMK",
    "M.M..K.M..K.M..K.K..M.K..M.K",
    "MMM..KMM..KKM..KKK..MKK..MMK",
]
DIAMANT = ["..L..", ".LDL.", "LD.DL", ".LDL.", "..L.."]
CHEVRON = ["L...L", ".L.L.", "..L.."]
MECHES = ["L.L.", ".L.L", "L.L.", ".L.L"]
CRATERE = [".MM.", "MDDM", "MDDM", ".MM."]
PETIT_CRATERE = [".K.", "KDK", ".K."]
GLYPHES = [
    ["L.L", ".L.", "L.L"], ["LLL", "L..", "LLL"], ["L..", "LLL", "..L"], [".L.", "LLL", ".L."],
    ["MM", "M."], ["K.K", "KKK"], ["LL", ".L", "LL"], ["M.M", ".M.", "M.M"],
]
BOUCHE = ["D...D", ".D.D.", "..D.."]


def miroir(lignes):
    return [l[::-1] for l in lignes]


def composer(W, H, places, graine, glyphes=0, poussiere=0.0, interdits=(), bord_bas=None, bord_haut=None):
    """Grille W x H couverte de motifs : motifs placés (fractions 0..1), glyphes au hasard,
    poussière de pixels. `interdits` = rectangles (x0, y0, x1, y1) en pixels à laisser vides."""
    r = random.Random(graine)
    g = [["."] * W for _ in range(H)]
    occ = [[False] * W for _ in range(H)]
    for x0, y0, x1, y1 in interdits:
        for y in range(max(0, y0), min(H, y1 + 1)):
            for x in range(max(0, x0), min(W, x1 + 1)):
                occ[y][x] = True

    def poser(lignes, cx, cy, force=False):
        h = len(lignes)
        w = max(len(l) for l in lignes)
        x0 = int(round(cx - (w - 1) / 2))
        y0 = int(round(cy - (h - 1) / 2))
        if not force:
            if x0 < 1 or y0 < 1 or x0 + w > W - 1 or y0 + h > H - 1:
                return False
            for y in range(y0 - 1, y0 + h + 1):
                for x in range(x0 - 1, x0 + w + 1):
                    if 0 <= x < W and 0 <= y < H and occ[y][x]:
                        return False
        for j, l in enumerate(lignes):
            for i, ch in enumerate(l):
                x, y = x0 + i, y0 + j
                if 0 <= x < W and 0 <= y < H and ch != ".":
                    g[y][x] = ch
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                if 0 <= x < W and 0 <= y < H:
                    occ[y][x] = True
        return True

    for lignes, fx, fy in places:
        poser(lignes, fx * (W - 1), fy * (H - 1), force=True)
    n = 0
    for _ in range(glyphes * 30):
        if n >= glyphes:
            break
        gl = r.choice(GLYPHES)
        if poser(gl, r.uniform(1, W - 2), r.uniform(1, H - 2)):
            n += 1
    for y in range(H):
        for x in range(W):
            if not occ[y][x] and g[y][x] == "." and r.random() < poussiere:
                g[y][x] = r.choice("MMKKDL")
    if bord_bas:
        for x in range(W):
            if g[H - 1][x] == "." and (x % 3 != 2):
                g[H - 1][x] = bord_bas
    if bord_haut:
        for x in range(W):
            if g[0][x] == "." and x % 2 == 0:
                g[0][x] = bord_haut
    return ["".join(l) for l in g]


def disque_px(N, rayon, centre=None):
    """Cases (i, j) d'une grille N x N à l'intérieur d'un cercle (en pixels)."""
    c = (N - 1) / 2 if centre is None else centre
    return lambda i, j: math.hypot(i - c, j - c) <= rayon


# ---------------------------------------------------------------------------------------------
# LE PERSONNAGE — proportions et détails relevés sur l'image de référence
#   tête ≈ corps ≈ pattes en hauteur (≈ 5,3 studs chacun), couronne presque aussi haute que la
#   tête, queue de 9 grosses dalles de lune (aussi hautes que le corps) + un cube violet au bout.
# ---------------------------------------------------------------------------------------------
ARTICULATIONS = []  # (nom, parent, pivot (Blender), sorte d'animation)


def articulation(nom, parent, pivot, sorte):
    ARTICULATIONS.append({"nom": nom, "parent": parent, "pivot": Vector(pivot), "sorte": sorte})


PX = 0.3


def tampon(g, lignes, cx, cy):
    """Recopie un motif dans une grille (centre en pixels), par-dessus ce qui s'y trouve."""
    h = len(lignes)
    w = max(len(l) for l in lignes)
    x0 = int(round(cx - (w - 1) / 2))
    y0 = int(round(cy - (h - 1) / 2))
    for j, l in enumerate(lignes):
        for i, ch in enumerate(l):
            x, y = x0 + i, y0 + j
            if 0 <= y < len(g) and 0 <= x < len(g[0]) and ch != " ":
                g[y][x] = ch


def lunaire(W, H, graine, seuil=0.56, pente=0.0, crateres=3, poussiere=0.035, places=(), vide=()):
    """Texture « sol lunaire » de la référence : plaques claires en relief (M) aux contours
    irréguliers, cratères ronds (anneau clair L, fond creux), pixels épars.
    `pente` > 0 met plus de plaques en haut de la face. `vide` = rectangles laissés lisses."""
    r = random.Random(graine)
    gw, gh = W // 4 + 3, H // 4 + 3
    gros = [[r.random() for _ in range(gw)] for _ in range(gh)]

    def bruit(x, y):
        fx, fy = x / 4, y / 4
        x0, y0 = int(fx), int(fy)
        tx, ty = fx - x0, fy - y0
        a = gros[y0][x0] * (1 - tx) + gros[y0][x0 + 1] * tx
        b = gros[y0 + 1][x0] * (1 - tx) + gros[y0 + 1][x0 + 1] * tx
        return a * (1 - ty) + b * ty

    g = []
    for y in range(H):
        ligne = []
        for x in range(W):
            v = bruit(x, y) + r.uniform(-0.07, 0.07) + pente * (0.5 - y / max(1, H - 1))
            ligne.append("M" if v > seuil else ".")
        g.append(ligne)
    for _ in range(crateres):
        cx, cy = r.uniform(2, W - 3), r.uniform(2, H - 3)
        rr = r.choice((1.3, 1.7, 2.3))
        for y in range(H):
            for x in range(W):
                d = math.hypot(x - cx, y - cy)
                if d <= rr - 0.7:
                    g[y][x] = "."
                elif d <= rr + 0.45:
                    g[y][x] = "L"
    for lignes, fx, fy in places:
        tampon(g, lignes, fx * (W - 1), fy * (H - 1))
    for y in range(H):
        for x in range(W):
            if g[y][x] == "." and r.random() < poussiere:
                g[y][x] = r.choice("MMK")
    for x0, y0, x1, y1 in vide:
        for y in range(max(0, y0), min(H, y1 + 1)):
            for x in range(max(0, x0), min(W, x1 + 1)):
                g[y][x] = "."
    return ["".join(l) for l in g]


def prisme(nom, a, b, c, normale, ep, couleur, decal=0.0):
    """Prisme triangulaire (oreilles, ailerons) : triangle abc épaissi le long de `normale`."""
    p = piece(nom)
    n = Vector(normale).normalized()
    a, b, c = Vector(a) + n * decal, Vector(b) + n * decal, Vector(c) + n * decal
    if (b - a).cross(c - a).dot(n) < 0:
        b, c = c, b
    av = [a + n * ep / 2, b + n * ep / 2, c + n * ep / 2]
    ar = [a - n * ep / 2, b - n * ep / 2, c - n * ep / 2]
    uv = uv_case(couleur) if p.sorte == "Palette" else [(0.5, 0.5)] * 4
    p.poly(av, uv[:3])
    p.poly([ar[0], ar[2], ar[1]], uv[:3])
    for i in range(3):
        j = (i + 1) % 3
        p.poly([ar[i], ar[j], av[j], av[i]], uv)


def reduire(a, b, c, k):
    g = (Vector(a) + Vector(b) + Vector(c)) / 3
    return [g + (Vector(p) - g) * k for p in (a, b, c)]


# ----- Corps : un torse plus haut et plus large à l'avant (poitrail), plus petit à l'arrière ----
def hexa(nom, coins, couleur="navy", tex=None):
    """Pavé déformé à 8 coins : coins[(i, j, k)] avec i = x (0 gauche), j = y (0 arrière), k = z
    (0 bas). Les faces restent planes si les arêtes opposées sont parallèles (tronc de pyramide)."""
    p = piece(nom)
    for cle, (_, ordre) in FACES.items():
        pts = [Vector(coins[ijk]) for ijk in ordre]
        if tex:
            n = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
            a = (pts[1] - pts[0]).normalized()
            b = n.cross(a)
            loc = [((q - pts[0]).dot(a), (q - pts[0]).dot(b)) for q in pts]
            umin, vmin = min(u for u, _ in loc), min(v for _, v in loc)
            wt = (max(u for u, _ in loc) - umin) * TEXELS_PAR_STUD
            ht = (max(v for _, v in loc) - vmin) * TEXELS_PAR_STUD
            k = min(1.0, (TEX - 8) / wt, (BRUIT_H - 8) / ht)
            x0 = RNG.uniform(4, TEX - 4 - wt * k)
            y0 = BRUIT[tex] + RNG.uniform(4, BRUIT_H - 4 - ht * k)
            uvs = [((x0 + (u - umin) * TEXELS_PAR_STUD * k) / TEX, 1 - (y0 + (v - vmin) * TEXELS_PAR_STUD * k) / TEX) for u, v in loc]
        else:
            uvs = uv_case(couleur)
        p.poly(pts, uvs)


def pixels_face(nom, pts4, px, motif, pal=PIX_NAVY, haut=(0, 0, 1), interieur=None):
    """Pixels sur une face quelconque (trapèze) : la grille couvre la face et les cases qui
    dépassent sont retirées. `motif(W, H)` renvoie les lignes."""
    pts4 = [Vector(q) for q in pts4]
    n = (pts4[1] - pts4[0]).cross(pts4[2] - pts4[0]).normalized()
    centre = sum(pts4, Vector()) / 4
    if interieur is not None and n.dot(centre - Vector(interieur)) < 0:
        n = -n
    o, u, v, nn = face(centre, n, haut)
    loc = [((q - centre).dot(u), (q - centre).dot(v)) for q in pts4]
    umin, umax = min(a for a, _ in loc), max(a for a, _ in loc)
    vmin, vmax = min(b for _, b in loc), max(b for _, b in loc)
    W, H = int((umax - umin) / px), int((vmax - vmin) / px)
    cu, cv = (umin + umax) / 2, (vmin + vmax) / 2
    lignes = motif(W, H)
    sens = 1 if sum((loc[i][0] * loc[(i + 1) % 4][1] - loc[(i + 1) % 4][0] * loc[i][1]) for i in range(4)) > 0 else -1

    def dedans(x, y):
        for i in range(4):
            (x1, y1), (x2, y2) = loc[i], loc[(i + 1) % 4]
            if sens * ((x2 - x1) * (y - y1) - (y2 - y1) * (x - x1)) < px * 0.5 * math.hypot(x2 - x1, y2 - y1):
                return False
        return True

    propres = []
    for j, l in enumerate(lignes):
        propres.append("".join(ch if dedans(cu + (i - (W - 1) / 2) * px, cv + ((H - 1) / 2 - j) * px) else "." for i, ch in enumerate(l)))
    pixels(nom, (centre + u * cu + v * cv, u, v, nn), px, propres, pal)


YF, YR = 4.6, -7.0                 # avant et arrière du torse
WF, WR = 6.4, 5.2                  # largeur avant / arrière
ZF, ZR = (6.2, 12.8), (7.8, 12.2)  # bas et haut à l'avant / à l'arrière
BY = YF - YR
BC = Vector((0, (YF + YR) / 2, 9.8))
CORPS = {}
for i in (0, 1):
    for j in (0, 1):
        for k in (0, 1):
            y, w, zz = (YF, WF, ZF) if j else (YR, WR, ZR)
            CORPS[(i, j, k)] = Vector(((i * 2 - 1) * w / 2, y, zz[k]))


def largeur(y):
    return WR + (WF - WR) * (y - YR) / (YF - YR)


def bas_corps(y):
    return ZR[0] + (ZF[0] - ZR[0]) * (y - YR) / (YF - YR)


articulation("Corps", "Racine", (0, BC.y, 7.4), "corps")
hexa("Corps", CORPS, "navy", tex="navy")
ZIGZAG = ["M.MM..M.MMM.M..MM.M", ".M..MM.M...M.MM..M."]
CERCLE = [
    "..LLLL..",
    ".LMMMML.",
    "LM....ML",
    "LM....ML",
    "LM....ML",
    "LM....ML",
    ".LMMMML.",
    "..LLLL..",
]
for s in (1, -1):
    i = 1 if s > 0 else 0
    cote = [CORPS[(i, 0, 0)], CORPS[(i, 1, 0)], CORPS[(i, 1, 1)], CORPS[(i, 0, 1)]]
    places = [(CERCLE, 0.52, 0.3), (ZIGZAG, 0.5, 0.62), (PETIT_CRATERE, 0.28, 0.3)]
    if s < 0:
        places = [(miroir(m), 1 - fx, fy) for m, fx, fy in places]
    pixels_face("Corps", cote, PX, lambda W, H, s=s, places=places: lunaire(W, H, 10 + s, seuil=0.56, pente=0.6, crateres=4, places=places), PIX_LUNAIRE, interieur=BC)
    # Épaulière claire sur le poitrail, au-dessus de la patte avant (cratères en relief)
    ye = 2.2
    ep = Vector((s * (largeur(ye) / 2 + 0.2), ye, 8.8))
    box("Corps", ep, (0.4, 3.6, 4.4), "navyMid")
    motif = lunaire(12, 14, 40 + s, seuil=0.38, crateres=3, poussiere=0.06)
    pixels("Corps", face(ep + Vector((s * 0.2, 0, 0)), (s, 0, 0), (0, 0, 1)), PX, motif, PIX_LUNAIRE)
dessus = [CORPS[(0, 0, 1)], CORPS[(1, 0, 1)], CORPS[(1, 1, 1)], CORPS[(0, 1, 1)]]
pixels_face("Corps", dessus, PX, lambda W, H: lunaire(W, H, 3, seuil=0.5, crateres=4, places=[(CERCLE, 0.5, 0.45)]), PIX_LUNAIRE, haut=(0, 1, 0), interieur=BC)
arriere = [CORPS[(1, 0, 0)], CORPS[(0, 0, 0)], CORPS[(0, 0, 1)], CORPS[(1, 0, 1)]]
pixels_face("Corps", arriere, PX, lambda W, H: lunaire(W, H, 4, seuil=0.6, crateres=1, vide=[(3, 0, W - 4, H)]), PIX_LUNAIRE, interieur=BC)
poitrail = [CORPS[(0, 1, 0)], CORPS[(1, 1, 0)], CORPS[(1, 1, 1)], CORPS[(0, 1, 1)]]
pixels_face("Corps", poitrail, PX, lambda W, H: lunaire(W, H, 5, seuil=0.62, crateres=2), PIX_LUNAIRE, interieur=BC)

# ----- Pattes articulées : épaule / coude / poignet à l'avant, cuisse / genou / jarret à l'arrière
BARRES = [["L.", "L.", "LL"], ["LL", "L.", "L."], ["L", "L", "L"], ["LLL"], ["L.L", "LLL"], ["M", "M"]]


def marques(W, H, graine, n=3, poussiere=0.05):
    r = random.Random(graine)
    g = [["."] * W for _ in range(H)]
    for _ in range(n):
        tampon(g, r.choice(BARRES), r.uniform(1, W - 2), r.uniform(1, H - 2))
    for y in range(H):
        for x in range(W):
            if g[y][x] == "." and r.random() < poussiere:
                g[y][x] = r.choice("MK")
    return ["".join(l) for l in g]


def segment(nom, haut, bas, largeur_x, epaisseur_y, graine, s, tex="navy", couleur="navy", details=True):
    """Segment de patte entre deux points (incliné dans le plan y-z), avec des marques gravées."""
    haut, bas = Vector(haut), Vector(bas)
    d = haut - bas
    L = d.length
    ang = math.atan2(d.y, d.z)  # inclinaison vers l'avant (+y)
    R = Matrix.Rotation(-ang, 3, "X")
    c = (haut + bas) / 2
    box(nom, c, (largeur_x, epaisseur_y, L), couleur, R, tex=tex)
    if details:
        ex, ey, ez = R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)), R @ Vector((0, 0, 1))
        hpx = max(2, int(L / PX))
        pixels(nom, face(c + ex * (s * largeur_x / 2), ex * s, ez), PX, marques(int(epaisseur_y / PX), hpx, graine, 2))
        pixels(nom, face(c + ey * (epaisseur_y / 2), ey, ez), PX, marques(int(largeur_x / PX), hpx, graine + 1, 1))


def jointure(nom, centre, taille):
    """Articulation bien visible : un cube un peu plus large et plus clair."""
    box(nom, centre, taille, "navyMid", tex=None)
    box(nom, Vector(centre) + Vector((0, taille[1] / 2 + 0.01, 0)), (taille[0] * 0.6, 0.04, taille[2] * 0.5), "navyLight")


def patte_bout(nom, x, y):
    """Patte : bloc sombre, deux doigts séparés par une rainure."""
    box(nom, (x, y + 0.3, 0.45), (2.3, 2.8, 0.9), "navyDeep")
    box(nom, (x, y + 1.72, 0.45), (0.14, 0.06, 0.8), "nose")
    box(nom, (x, y + 0.3, 0.93), (2.1, 2.6, 0.06), "navyDark")


PATTES = {"AvG": (-1.95, 2.4), "AvD": (1.95, 2.4), "ArG": (-1.75, -5.2), "ArD": (1.75, -5.2)}
for cle, (x, y) in PATTES.items():
    s = 1 if x > 0 else -1
    arriere = cle.startswith("Ar")
    haut, bas = f"Patte{cle}Haut", f"Patte{cle}Bas"
    graine = sum(map(ord, cle)) * 7
    zc = bas_corps(y)
    if not arriere:
        # avant : épaule (dans le poitrail), coude, avant-bras droit, poignet, patte
        coude = Vector((x, y - 0.35, 3.9))
        articulation(haut, "Corps", (x, y, zc + 0.6), "hanche")
        articulation(bas, haut, coude, "genou")
        segment(haut, (x, y + 0.1, zc + 0.8), coude, 2.3, 2.4, graine, s)
        jointure(bas, coude, (2.5, 2.6, 0.7))
        segment(bas, coude, (x, y - 0.1, 1.15), 1.95, 2.05, graine + 3, s)
        jointure(bas, (x, y - 0.1, 1.05), (2.1, 2.2, 0.32))
        patte_bout(bas, x, y - 0.1)
    else:
        # arrière : grosse cuisse (spirale), genou vers l'avant, tibia qui recule, jarret, pied
        genou = Vector((x, y + 1.0, 5.1))
        jarret = Vector((x, y - 0.8, 2.4))
        articulation(haut, "Corps", (x, y, zc + 0.6), "hanche")
        articulation(bas, haut, genou, "genou")
        cuisse = Vector((x + s * 0.2, y + 0.25, zc - 0.2))
        box(haut, cuisse, (2.7, 3.4, 3.6), "navy", tex="navy")
        pixels(haut, face(cuisse + Vector((s * 1.35, 0, 0)), (s, 0, 0), (0, 0, 1)), 0.3, SPIRALE if s > 0 else miroir(SPIRALE))
        pixels(haut, face(cuisse + Vector((0, -1.7, 0)), (0, -1, 0), (0, 0, 1)), PX, marques(9, 12, graine + 9, 2))
        segment(haut, (x, y + 0.4, zc - 0.5), genou, 2.1, 2.2, graine, s, details=False)
        jointure(bas, genou, (2.3, 2.4, 0.7))
        segment(bas, genou, jarret, 1.9, 1.9, graine + 3, s)
        jointure(bas, jarret, (2.1, 2.1, 0.7))
        segment(bas, jarret, (x, y - 0.4, 0.9), 1.75, 1.8, graine + 4, s)
        patte_bout(bas, x, y - 0.4)

# ----- Tête ------------------------------------------------------------------------------------
HX, HY, HZ = 6.0, 5.0, 5.0
HC = Vector((0, 4.8, 14.4))
AV = HC.y + HY / 2  # face avant (y = 8.0)
HAUT_TETE = HC.z + HZ / 2
articulation("Tete", "Corps", (0, 3.0, 12.4), "cou")
box("Tete", HC, (HX, HY, HZ), "navy", tex="navy")
# Museau : un cube qui dépasse, nez noir, bouche en « w »
MU = Vector((0, AV + 0.75, HC.z - 1.6))
box("Tete", MU, (2.3, 1.5, 1.7), "museau")
box("Tete", MU + Vector((0, 0.02, 0.87)), (2.16, 1.4, 0.06), "navyLight")
box("Tete", MU + Vector((0, 0.77, 0.45)), (0.8, 0.12, 0.38), "nose")
pixels("Tete", face(MU + Vector((0, 0.75, -0.32)), (0, 1, 0), (0, 0, 1)), 0.15, ["D.....D", ".D.D.D.", "..D.D.."])
pixels("Tete", face(MU + Vector((1.15, 0, -0.2)), (1, 0, 0), (0, 0, 1)), 0.2, ["K.K", ".K."])
pixels("Tete", face(MU + Vector((-1.15, 0, -0.2)), (-1, 0, 0), (0, 0, 1)), 0.2, ["K.K", ".K."])

# Yeux : disque sombre, deux anneaux cyan en pixels (le second ouvert), pupille ovale lumineuse
# tournée vers le museau, cœur pâle et petit reflet
PIX_OEIL = {
    "E": (None, "eyeRim", 0.04), "I": (None, "eyeIn", 0.05), "J": (None, "eyeLow", 0.05),
    "C": ("NeonCyan", None, 0.08), "P": ("NeonCyan", None, 0.1), "W": ("NeonPale", None, 0.12),
    "H": ("NeonBlanc", None, 0.13),
}
for s in (1, -1):
    N = 22
    c = (N - 1) / 2
    dcol = s * 2.2  # pupille vers le museau (colonnes = -x vu de face)
    lignes = []
    for j in range(N):
        l = ""
        for i in range(N):
            dx, dy = i - c, j - c
            r = math.hypot(dx, dy)
            ang = math.degrees(math.atan2(dy, dx * -s)) % 360
            pdx, pdy = i - (c + dcol), j - (c - 0.6)
            if r > 10.6:
                l += "."
            elif 9.4 <= r <= 10.4:
                l += "C"
            elif 6.7 <= r <= 7.6 and not (20 <= ang <= 95):
                l += "C"
            elif (pdx / 2.9) ** 2 + (pdy / 4.5) ** 2 <= 1:
                if (pdx / 1.3) ** 2 + ((pdy + 0.8) / 2.4) ** 2 <= 1:
                    l += "W"
                else:
                    l += "P"
            elif r < 6.7:
                l += "J" if dy > 2.5 else "I"
            else:
                l += "E"
        lignes.append(l)
    # petit reflet en haut de la pupille
    rj, ri = int(round(c - 3.6)), int(round(c + dcol - s * 0.8))
    lignes[rj] = lignes[rj][:ri] + "H" + lignes[rj][ri + 1:]
    pixels("Tete", face((s * 1.65, AV, HC.z + 0.15), (0, 1, 0), (0, 0, 1)), 0.125, lignes, PIX_OEIL)
# Front : symbole de croissant gravé en haut, quelques pixels
SYMBOLE = [
    "L...L",
    "LL.LL",
    ".LLL.",
]
W, H = int(HX / PX), int(HZ / PX)
g = [["."] * W for _ in range(H)]
tampon(g, SYMBOLE, (W - 1) / 2, 1.5)
rf = random.Random(21)
for y in range(H):
    for x in range(W):
        oeil = min(math.hypot(x - (W - 1) / 2 - 5.5, y - 7.0), math.hypot(x - (W - 1) / 2 + 5.5, y - 7.0)) < 4.9
        museau = abs(x - (W - 1) / 2) < 4.3 and y > 9.5
        if g[y][x] == "." and not oeil and not museau and rf.random() < 0.06:
            g[y][x] = rf.choice("MMK")
pixels("Tete", face((0, AV, HC.z), (0, 1, 0), (0, 0, 1)), PX, ["".join(l) for l in g])
# Côtés, dessus, arrière : sol lunaire
for s in (1, -1):
    motif = lunaire(int(HY / PX), int(HZ / PX), 30 + s, seuil=0.58, pente=0.3, crateres=2)
    pixels("Tete", face(HC + Vector((s * HX / 2, 0, 0)), (s, 0, 0), (0, 0, 1)), PX, motif, PIX_LUNAIRE)
motif = lunaire(int(HX / PX), int(HY / PX), 33, seuil=0.56, crateres=2)
pixels("Tete", face(HC + Vector((0, 0, HZ / 2)), (0, 0, 1), (0, 1, 0)), PX, motif, PIX_LUNAIRE)
motif = lunaire(int(HX / PX), int(HZ / PX), 34, seuil=0.58, crateres=2)
pixels("Tete", face(HC + Vector((0, -HY / 2, 0)), (0, -1, 0), (0, 0, 1)), PX, motif, PIX_LUNAIRE)

# ----- Oreilles : grands triangles magenta penchés vers l'extérieur ---------------------------
for s, cote in ((-1, "G"), (1, "D")):
    nom = f"Oreille{cote}"
    ye = HC.y + 0.8
    articulation(nom, "Tete", (s * 2.3, ye, HAUT_TETE - 0.4), "oreille")
    a, b, c = (s * 1.1, ye, HAUT_TETE + 0.1), (s * 3.15, ye, HAUT_TETE - 1.45), (s * 4.9, ye, HAUT_TETE + 2.2)
    prisme(nom, a, b, c, (0, 1, 0), 0.9, "magentaDark")
    prisme(nom, *reduire(a, b, c, 0.86), (0, 1, 0), 0.14, "rose", decal=0.5)
    prisme(nom, *reduire(a, b, c, 0.7), (0, 1, 0), 0.14, "magenta", decal=0.6)
    a2, b2, c2 = reduire(a, b, c, 0.7)
    prisme(nom, a2, b2, a2.lerp(c2, 0.45), (0, 1, 0), 0.1, "magentaDark", decal=0.7)
    # aileron magenta sur la joue, pointe vers l'extérieur
    j0 = Vector((s * HX / 2, AV - 1.5, HC.z - 0.3))
    prisme("Tete", j0 + Vector((0, 0, 0.55)), j0 + Vector((0, 0, -0.7)), j0 + Vector((s * 1.6, 0.25, -0.4)), (0, 1, 0), 0.45, "magentaDark")
    prisme("Tete", *reduire(j0 + Vector((0, 0, 0.55)), j0 + Vector((0, 0, -0.7)), j0 + Vector((s * 1.6, 0.25, -0.4)), 0.75), (0, 1, 0), 0.1, "magenta", decal=0.27)


# ----- Cristaux : grandes dalles de pierre de lune (cratères) derrière les oreilles -----------
def dalle(nom, base, direction, haut, longueur, largeur, epaisseur, graine):
    """Dalle de cristal de lune : pavé allongé terminé en pointe, cratères sur les grandes faces."""
    d = Vector(direction).normalized()
    v = (Vector(haut) - d * Vector(haut).dot(d)).normalized()
    u = d.cross(v)
    # repère de la dalle : x = u (largeur), y = d (longueur), z = v (épaisseur)
    R = mat_axes(u, d, v)
    corps_l = longueur * 0.74
    c = Vector(base) + d * (corps_l / 2)
    box(nom, c, (largeur, corps_l, epaisseur), "lunePale", R, tex="moon")
    # pointe à 4 faces
    p = piece(nom)
    bout = Vector(base) + d * longueur
    hx, hz = largeur / 2, epaisseur / 2
    sommet = Vector(base) + d * corps_l
    coins = [sommet + u * sx * hx + v * sz * hz for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    uv = uv_case("lunePale")
    for i in range(4):
        a, b = coins[i], coins[(i + 1) % 4]
        tri = [a, b, bout]
        if (b - a).cross(bout - a).dot((a + b) / 2 - sommet) < 0:
            tri = [b, a, bout]
        p.poly(tri, uv[:3])
    # cratères sur les deux grandes faces
    r = random.Random(graine)
    W, H = max(3, int(largeur / 0.25)), max(3, int(corps_l / 0.25))
    for sens in (1, -1):
        g = [["."] * W for _ in range(H)]
        for _ in range(7):
            tampon(g, r.choice((PETIT_CRATERE, ["KK", "KK"], ["KK", "KK"], ["K"])), r.uniform(1, W - 2), r.uniform(1, H - 2))
        lignes = ["".join(l) for l in g]
        pixels(nom, (c + v * sens * hz, u * sens, d, v * sens), 0.25, lignes, PIX_LUNE)


for s in (1, -1):
    dalle("Tete_Lune", (s * 2.4, HC.y - 1.2, HAUT_TETE - 0.8), (s * 0.62, -0.06, 0.78), (0, 1, 0.1), 6.6, 2.8, 1.6, 100 + s)
    dalle("Tete_Lune", (s * 3.0, HC.y - 1.5, HAUT_TETE - 1.5), (s * 0.95, -0.22, 0.22), (0, 0.4, 1), 4.2, 2.0, 1.2, 110 + s)
    # éclats blancs flottant près des joues
    for (dx, dy, dz, t, deg) in ((1.4, 0.6, -0.2, 0.9, 20), (1.0, -0.6, 1.3, 0.55, -30)):
        cc = Vector((s * (HX / 2 + dx), AV - 1.4 + dy, HC.z - 0.4 + dz))
        box("Tete_Lune", cc, (t * 1.3, t, t * 0.9), "lunePale", Matrix.Rotation(math.radians(deg * s), 3, "Y") @ Matrix.Rotation(math.radians(25), 3, "Z"))

# ----- Couronne : croissant de lune posé sur la tête ------------------------------------------
R_EXT, D_INT, R_INT = 2.9, 1.3, 2.42
CC = Vector((0, HC.y - 0.2, HAUT_TETE - 0.4 + R_EXT))
articulation("Couronne", "Tete", (0, HC.y - 0.2, HAUT_TETE), "flotte")
N = int(2 * R_EXT / 0.25) + 2
PXC = 0.25


def dans_croissant(x, z):
    return math.hypot(x, z) <= R_EXT and math.hypot(x, z - D_INT) >= R_INT and z <= 2.5


cellules = {}
for j in range(N):
    for i in range(N):
        x = (i - (N - 1) / 2) * PXC
        z = ((N - 1) / 2 - j) * PXC
        if dans_croissant(x, z):
            cellules[(i, j)] = (x, z)
EP = 1.0
for j in range(N):
    i = 0
    while i < N:
        if (i, j) not in cellules:
            i += 1
            continue
        k = i
        while (k + 1, j) in cellules:
            k += 1
        x0, z = cellules[(i, j)]
        x1, _ = cellules[(k, j)]
        box("Couronne", CC + Vector(((x0 + x1) / 2, 0, z)), ((k - i + 1) * PXC, EP, PXC), "lunePale", tex="moon")
        i = k + 1
# faces avant et arrière : bande lavande le long du bord intérieur, contour pâle, cratères
PIX_COURONNE = {
    "A": (None, "lavande", 0.07), "B": (None, "lavandeClair", 0.06), "K": (None, "crater", 0.03),
    "E": (None, "disque", 0.05), "S": (None, "moon", 0.08), "C": ("NeonPale", None, 0.08),
}
rc = random.Random(5)
crat = set()
for _ in range(14):
    (ci, cj) = rc.choice(list(cellules))
    for (i, j) in cellules:
        if math.hypot(i - ci, j - cj) <= rc.choice((0.8, 1.2)):
            crat.add((i, j))
for sens in (1, -1):
    lignes = []
    for j in range(N):
        l = []
        for i in range(N):
            if (i, j) not in cellules:
                l.append(".")
                continue
            x, z = cellules[(i, j)]
            d_int = math.hypot(x, z - D_INT) - R_INT  # distance au bord intérieur
            if d_int < PXC * 1.6:
                l.append("A")
            elif d_int < PXC * 3.2:
                l.append("B")
            elif not dans_croissant(x, z - PXC) or not dans_croissant(x + PXC, z) or not dans_croissant(x - PXC, z):
                l.append("C")
            elif (i, j) in crat:
                l.append("K")
            elif rc.random() < 0.1:
                l.append("S")
            else:
                l.append(".")
        lignes.append("".join(l))
    rep = face(CC + Vector((0, sens * EP / 2, 0)), (0, sens, 0), (0, 0, 1))
    pixels("Couronne", rep, PXC, lignes if sens > 0 else miroir(lignes), PIX_COURONNE)
# petit croissant lumineux au centre (ouvert vers la droite de l'image)
pc = 0.17
M2 = 14
lignes = []
for j in range(M2):
    l = ""
    for i in range(M2):
        x = (i - (M2 - 1) / 2) * pc
        z = ((M2 - 1) / 2 - j) * pc
        dedans = math.hypot(x, z) <= 1.0 and math.hypot(x + 0.48, z + 0.05) >= 0.82
        l += "Q" if dedans else "."
    lignes.append(l)
for sens in (1, -1):
    pixels("Couronne", face(CC + Vector((0, 0, 0.95)), (0, sens, 0), (0, 0, 1)), pc, lignes if sens > 0 else miroir(lignes), PIX_LUNE, relief=4.0)

# ----- Queue : 9 dalles de lune lumineuses (anneau ovale cyan, disque cratérisé) + cube violet --
ANGLES = [-10, -9, -7, -4, 0, 5, 12, 22, 34, 48]
NQ = len(ANGLES)
joint = Vector((0, BC.y - BY / 2 - 0.1, 10.2))
QUEUE = []
for i, deg in enumerate(ANGLES):
    t = i / (NQ - 2)
    L = 3.2 - 0.4 * t
    h = 5.6 - 0.9 * t
    w = 4.0 - 0.5 * t
    if i == NQ - 1:
        L = h = w = 3.0
    th = math.radians(deg)
    d = Vector((0, -math.cos(th), math.sin(th)))
    centre = joint + d * (L / 2 + 0.22)
    nom = f"Queue{i + 1:02d}"
    articulation(nom, "Corps" if i == 0 else f"Queue{i:02d}", joint.copy(), "queue")
    QUEUE.append((nom, centre.copy(), d.copy(), (w, L, h)))
    # chaque dalle est un peu tournée par rapport à sa voisine (effet de chaîne, comme l'image)
    torsion = (4.0 if i % 2 else -4.0) if i < NQ - 1 else 0.0
    R = Matrix.Rotation(-th, 3, "X") @ Matrix.Rotation(math.radians(torsion), 3, "Z")
    ex, ey, ez = R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)), R @ Vector((0, 0, 1))
    if i < NQ - 1:
        box(nom, centre, (w, L, h), "lunePale", R, tex="moon")
        box(nom + "_Halo", centre, (w * 1.08, L * 0.9, h * 1.06), R=R)
        pq = 0.16
        Wg, Hg = int(round(L / pq)), int(round(h / pq))
        ax, az = Wg / 2 - 1.2, Hg / 2 - 1.4  # demi-axes de l'ovale (pixels)
        rq = random.Random(300 + i)
        crs = [(rq.uniform(-0.45, 0.45) * ax, rq.uniform(-0.55, 0.55) * az, rq.choice((0.9, 1.3, 1.8))) for _ in range(6)]
        lignes = []
        for jj in range(Hg):
            l = ""
            for ii in range(Wg):
                dx, dz = ii - (Wg - 1) / 2, jj - (Hg - 1) / 2
                e = math.hypot(dx / ax, dz / az)
                if 0.9 <= e <= 1.04:
                    l += "C"
                elif e < 0.84:
                    if any(math.hypot(dx - a, dz - b) <= cc for a, b, cc in crs):
                        l += "K"
                    else:
                        l += "S" if rq.random() < 0.9 else "L"
                else:
                    l += "."
            lignes.append(l)
        for sx in (1, -1):
            pixels(nom, face(centre + ex * (sx * w / 2), ex * sx, ez), pq, lignes, PIX_LUNE)
        motif = composer(int(w / 0.25), int(L / 0.25), [(PETIT_CRATERE, rq.uniform(0.25, 0.75), rq.uniform(0.3, 0.7))],
                         400 + i, poussiere=0.04)
        motif = [l.replace("M", "E").replace("D", "K").replace("L", "S") for l in motif]
        pixels(nom, face(centre + ez * (h / 2), ez, -ey), 0.25, motif, PIX_LUNE)
        pixels(nom, face(centre - ez * (h / 2), -ez, ey), 0.25, motif, PIX_LUNE)
    else:
        R = R @ Matrix.Rotation(math.radians(18), 3, "Z")
        ex, ey, ez = R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)), R @ Vector((0, 0, 1))
        box(nom, centre, (w, L, h), "tip", R, tex="tip")
        rb = random.Random(77)
        for axe, haut in ((ex, ez), (-ex, ez), (ez, -ey), (-ey, ez), (ey, ez), (-ez, ey)):
            g = [["."] * 12 for _ in range(12)]
            for _ in range(6):
                tampon(g, rb.choice((["KK", "KK"], ["K"], ["KKK", "KKK"], [".K.", "KKK"])), rb.uniform(1, 10), rb.uniform(1, 10))
            pixels(nom, face(centre + axe * (w / 2), axe, haut), 0.25, ["".join(l) for l in g], PIX_BOUT)
    joint = centre + d * (L / 2 + 0.22)


# ----- Lunes qui flottent ----------------------------------------------------------------------
def croissant_px(nom, centre, normale, haut, rayon, graine, ep=0.45):
    """Croissant de lune épais en pixels, avec cratères (comme ceux autour de la queue)."""
    px = rayon / 5.0
    n = int(2 * rayon / px) + 2
    r = random.Random(graine)
    crs = [(r.uniform(-0.75, -0.45) * rayon, r.uniform(-0.45, 0.45) * rayon, r.uniform(0.1, 0.15) * rayon) for _ in range(2)]
    lignes = []
    for j in range(n):
        l = ""
        for i in range(n):
            x = (i - (n - 1) / 2) * px
            z = ((n - 1) / 2 - j) * px
            dedans = math.hypot(x, z) <= rayon and math.hypot(x - rayon * 0.62, z - rayon * 0.12) >= rayon * 0.76
            if not dedans:
                l += "."
            elif any(math.hypot(x - cx, z - cz) <= cr for cx, cz, cr in crs):
                l += "K"
            elif math.hypot(x, z) > rayon - px * 0.9:
                l += "E"
            else:
                l += "S"
        lignes.append(l)
    o, u, v, nn = face(centre, normale, haut)
    R = mat_axes(u, v, nn)
    for j, l in enumerate(lignes):
        idx = [i for i, ch in enumerate(l) if ch != "."]
        if not idx:
            continue
        i0, i1 = min(idx), max(idx)
        c = o + u * (((i0 + i1) / 2 - (n - 1) / 2) * px) + v * (((n - 1) / 2 - j) * px)
        box(nom, c, ((i1 - i0 + 1) * px, px, ep), "lunePale", R)
    pixels(nom, (o + nn * ep / 2, u, v, nn), px, lignes, PIX_LUNE, relief=0.5)
    pixels(nom, (o - nn * ep / 2, -u, v, -nn), px, miroir(lignes), PIX_LUNE, relief=0.5)


def pleine_lune(nom, centre, normale, rayon, graine, ep=0.4, demi=False):
    """Pleine lune (ou demi-lune) en pixels : disque épais, cratères."""
    px = rayon / 4.5
    n = int(2 * rayon / px) + 2
    r = random.Random(graine)
    crs = [(r.uniform(-0.5, 0.5) * rayon, r.uniform(-0.5, 0.5) * rayon, r.uniform(0.14, 0.24) * rayon) for _ in range(4)]
    disque = []
    for j in range(n):
        l = ""
        for i in range(n):
            x = (i - (n - 1) / 2) * px
            z = ((n - 1) / 2 - j) * px
            d = math.hypot(x, z)
            if d > rayon:
                l += "."
            elif any(math.hypot(x - cx, z - cz) <= cr for cx, cz, cr in crs):
                l += "K"
            elif demi and x > 0:
                l += "L"
            elif d > rayon - px * 0.9:
                l += "E"
            else:
                l += r.choice("SSSSL")
        disque.append(l)
    nn0 = Vector(normale).normalized()
    o, u, v, nn = face(centre, normale, (0, 0, 1) if abs(nn0.z) < 0.9 else (0, 1, 0))
    R = mat_axes(u, v, nn)
    for j, l in enumerate(disque):
        idx = [i for i, ch in enumerate(l) if ch != "."]
        if idx:
            i0, i1 = min(idx), max(idx)
            c = o + u * (((i0 + i1) / 2 - (n - 1) / 2) * px) + v * (((n - 1) / 2 - j) * px)
            box(nom, c, ((i1 - i0 + 1) * px, px, ep), "lunePale", R)
    pixels(nom, (o + nn * ep / 2, u, v, nn), px, disque, PIX_LUNE, relief=0.5)
    pixels(nom, (o - nn * ep / 2, -u, v, -nn), px, miroir(disque), PIX_LUNE, relief=0.5)


# Nuage de lunes autour de la queue (elles se balancent doucement dans Roblox)
centres_q = [q[1] for q in QUEUE]
CENTRE_ORBITE_Q = sum(centres_q[:9], Vector()) / 9
articulation("OrbiteQueue", "Corps", CENTRE_ORBITE_Q, "orbite_queue")
ro = random.Random(19)
LUNES_Q = [
    # (n° de dalle, côté x, hauteur, sorte, taille)
    (0, -1, 5.6, "croissant", 1.9), (1, -1, -4.4, "croissant", 1.2), (2, -1, -3.9, "fin", 0.6),
    (2, -1, 5.2, "fin", 0.6), (3, -1, -5.0, "croissant", 1.5), (3, -1, 4.6, "croissant", 1.6),
    (4, -1, 6.6, "pleine", 0.9), (4, -1, -4.6, "demi", 1.0), (5, -1, 4.8, "croissant", 1.5),
    (5, -1, -4.4, "fin", 0.6), (6, -1, -4.4, "croissant", 1.6), (6, -1, 5.6, "fin", 0.55),
    (7, -1, 4.4, "croissant", 1.4), (7, -1, -3.8, "pleine", 0.8), (8, -1, -3.6, "croissant", 1.3),
    (8, -1, 4.4, "fin", 0.6), (0, -1, -3.8, "croissant", 1.2), (1, -1, 7.4, "fin", 0.5),
]
for k, (idx, cx, dz, sorte, taille) in enumerate(LUNES_Q):
    q = QUEUE[idx][1]
    pos = q + Vector((cx * ro.uniform(2.6, 3.6), ro.uniform(-0.8, 0.8), dz))
    normale = Vector((-0.85, 0.5 + ro.uniform(-0.2, 0.2), ro.uniform(-0.15, 0.15)))
    haut = Vector((0, ro.uniform(-0.5, 0.5), 1))
    if sorte == "pleine":
        pleine_lune("OrbiteQueue", pos, normale, taille, 500 + k)
    elif sorte == "demi":
        pleine_lune("OrbiteQueue", pos, normale, taille, 500 + k, demi=True)
    elif sorte == "fin":
        croissant_px("OrbiteQueue_NeonPale", pos, normale, haut, taille, 600 + k, ep=0.2)
    else:
        croissant_px("OrbiteQueue", pos, normale, haut, taille, 600 + k)

# Lunes près de la tête (elles tournent lentement autour)
CENTRE_ORBITE_T = Vector((0, HC.y, HC.z + 0.6))
articulation("OrbiteTete", "Corps", CENTRE_ORBITE_T, "orbite_tete")
for k, (deg, rayon, dz, sorte, taille) in enumerate([
    (75, 6.0, 0.4, "demi", 0.85), (200, 6.0, 1.2, "pleine", 0.9), (230, 5.6, -1.4, "fin", 0.45),
    (120, 6.0, 2.2, "croissant", 0.75),
]):
    a = math.radians(deg)
    pos = CENTRE_ORBITE_T + Vector((math.cos(a) * rayon, math.sin(a) * rayon, dz))
    normale = Vector((-0.6, 1, 0))
    if sorte in ("pleine", "demi"):
        pleine_lune("OrbiteTete", pos, normale, taille, 700 + k, demi=(sorte == "demi"))
    elif sorte == "fin":
        croissant_px("OrbiteTete_NeonPale", pos, normale, (0, 0, 1), taille, 800 + k, ep=0.2)
    else:
        croissant_px("OrbiteTete", pos, normale, (0, 0, 1), taille, 800 + k)


# Points utiles aux VFX de Roblox (particules des cristaux, lumière des yeux, traînée)
POINTS_VFX = {
    "CristalG": Vector((-4.4, HC.y - 2.6, HAUT_TETE + 2.4)), "CristalD": Vector((4.4, HC.y - 2.6, HAUT_TETE + 2.4)),
    "Yeux": Vector((0, AV + 0.4, HC.z + 0.15)), "QueueBout": QUEUE[-1][1],
}


# ---------------------------------------------------------------------------------------------
# Texture (palette + bandes de bruit)
# ---------------------------------------------------------------------------------------------
def faire_texture(chemin):
    img = np.zeros((TEX, TEX, 4), dtype=np.float32)
    img[..., 3] = 1
    for nom, i in SWATCH.items():
        x = (i % (TEX // CASE)) * CASE
        y = (i // (TEX // CASE)) * CASE
        img[y:y + CASE, x:x + CASE, :3] = np.array(PAL[nom]) / 255
    rn = np.random.default_rng(3)
    teintes = {
        "navy": [(40, 33, 88), (46, 38, 98), (52, 43, 108), (60, 50, 120)],
        "moon": [(212, 226, 244), (226, 238, 250), (238, 246, 255), (218, 230, 248)],
        "tip": [(70, 52, 142), (84, 62, 162), (96, 74, 178), (108, 86, 192)],
        "magenta": [(206, 54, 158), (226, 66, 172), (238, 92, 186), (246, 112, 198)],
    }
    w, h = TEX // 4, BRUIT_H // 4
    for nom, y0 in BRUIT.items():
        # taches douces (bruit agrandi) + grain
        gros = rn.random((h // 4 + 2, w // 4 + 2))
        gros = np.kron(gros, np.ones((4, 4)))[:h, :w]
        champ = 0.65 * gros + 0.35 * rn.random((h, w))
        idx = np.digitize(champ, [0.3, 0.62, 0.8])
        cols = np.array(teintes[nom], dtype=np.float32) / 255
        bloc = cols[idx]
        bloc = np.kron(bloc, np.ones((4, 4, 1)))
        img[y0:y0 + BRUIT_H, :, :3] = bloc
    from PIL import Image
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(chemin)


# ---------------------------------------------------------------------------------------------
# Scène Blender
# ---------------------------------------------------------------------------------------------
def vider_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def srgb_lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def couleur_lin(rgb, a=1.0):
    return (srgb_lin(rgb[0]), srgb_lin(rgb[1]), srgb_lin(rgb[2]), a)


def materiaux(chemin_tex):
    mats = {}
    m = bpy.data.materials.new("Gardien_Palette")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    img = bpy.data.images.load(chemin_tex)
    img.name = "GardienLunaire_texture.png"
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = img
    tn.interpolation = "Closest"
    nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.72
    mats["Palette"] = m
    # Pierre de lune qui brille (queue, couronne, cristaux, lunes) : la texture + une émission
    m = bpy.data.materials.new("Gardien_Lune")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tl = nt.nodes.new("ShaderNodeTexImage")
    tl.image = img
    tl.interpolation = "Closest"
    teinte = nt.nodes.new("ShaderNodeMix")
    teinte.data_type = "RGBA"
    teinte.blend_type = "MULTIPLY"
    teinte.inputs["Factor"].default_value = 1.0
    teinte.inputs["B"].default_value = (0.55, 0.85, 1.0, 1.0)
    nt.links.new(tl.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(tl.outputs["Color"], teinte.inputs["A"])
    nt.links.new(teinte.outputs["Result"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 0.16
    b.inputs["Roughness"].default_value = 0.5
    mats["Lune"] = m
    for sorte, rgb in LUMIERES.items():
        m = bpy.data.materials.new(f"Gardien_{sorte}")
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        # couleur de base sombre : la couleur vient de l'émission (comme le Neon de Roblox)
        b.inputs["Base Color"].default_value = tuple(c * (0.9 if sorte == "Cristal" else 0.2) for c in couleur_lin(rgb)[:3]) + (1,)
        b.inputs["Emission Color"].default_value = couleur_lin(rgb)
        force = {"NeonCyan": 1.05, "NeonBlanc": 1.15, "NeonPale": 1.0, "NeonMagenta": 1.0, "Cristal": 0.12,
                 "CristalCoeur": 1.2, "Halo": 1.0}[sorte]
        b.inputs["Emission Strength"].default_value = force
        if sorte == "Cristal":
            b.inputs["Transmission Weight"].default_value = 0.6
            b.inputs["Roughness"].default_value = 0.12
            b.inputs["IOR"].default_value = 1.3
        if sorte == "Halo":
            b.inputs["Alpha"].default_value = 0.1
        mats[sorte] = m
    return mats


def creer_objets(mats):
    col = bpy.data.collections.new(ID)
    bpy.context.scene.collection.children.link(col)
    objets = {}
    for nom, p in PIECES.items():
        me = bpy.data.meshes.new(nom)
        me.from_pydata([tuple(v) for v in p.v], [], p.f)
        uvl = me.uv_layers.new(name="UVMap")
        k = 0
        for f, uvs in zip(me.polygons, p.uv):
            for li, uv in zip(f.loop_indices, uvs):
                uvl.data[li].uv = uv
            k += 1
        me.materials.append(mats[sorte_materiau(nom, p)])
        me.validate()
        ob = bpy.data.objects.new(nom, me)
        col.objects.link(ob)
        objets[nom] = ob
    return col, objets


def sorte_materiau(nom, p):
    """Matériau Blender d'une pièce : la pierre de lune brille (dans Roblox : texture + lumières)."""
    if p.sorte != "Palette":
        return p.sorte
    lune = (nom.startswith("Queue") and nom != f"Queue{NQ:02d}") or nom in ("Couronne", "OrbiteQueue", "OrbiteTete", "Tete_Lune", "Eclats")
    return "Lune" if lune else "Palette"


def r_roblox(v):
    """Blender (x, y, z) -> Roblox (x, z, -y) avec 1 unité = 1 stud."""
    return [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]


def boite(ob):
    pts = [Vector(c) for c in ob.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def donnees_squelette(objets):
    centres = {}
    for nom, ob in objets.items():
        mn, mx = boite(ob)
        centres[nom] = (mn + mx) / 2
    mn = Vector((min(boite(o)[0].x for o in objets.values()), min(boite(o)[0].y for o in objets.values()), min(boite(o)[0].z for o in objets.values())))
    mx = Vector((max(boite(o)[1].x for o in objets.values()), max(boite(o)[1].y for o in objets.values()), max(boite(o)[1].z for o in objets.values())))
    corps = centres["Corps"]
    arts = []
    for a in ARTICULATIONS:
        arts.append({
            "nom": a["nom"], "parent": a["parent"], "sorte": a["sorte"],
            "pivot": r_roblox(a["pivot"] - corps),
            "centre": r_roblox(centres[a["nom"]] - corps),
        })
    pieces = []
    for nom, p in PIECES.items():
        pieces.append({"nom": nom, "base": p.base, "sorte": p.sorte, "triangles": sum(len(f) - 2 for f in p.f),
                       "centre": r_roblox(centres[nom] - corps)})
    return {
        "id": ID,
        "hauteur": round(mx.z - mn.z, 3),
        "taille": [abs(c) for c in r_roblox(mx - mn)],
        "sol": round(mn.z - corps.z, 4),
        "points": {k: r_roblox(v - corps) for k, v in POINTS_VFX.items()},
        "articulations": arts,
        "pieces": pieces,
        "lumieres": {k: list(v) for k, v in LUMIERES.items()},
        "triangles": sum(p["triangles"] for p in pieces),
    }


def exporter(col, objets, donnees):
    os.makedirs(SORTIE, exist_ok=True)
    for ob in bpy.context.scene.objects:
        ob.select_set(ob.name in objets)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(SORTIE, f"{ID}.fbx"), use_selection=True, object_types={"MESH"},
        apply_unit_scale=False, apply_scale_options="FBX_SCALE_NONE", global_scale=1.0,
        mesh_smooth_type="FACE", path_mode="COPY", embed_textures=True, bake_anim=False,
        axis_forward="-Z", axis_up="Y",
    )
    bpy.ops.export_scene.gltf(filepath=os.path.join(SORTIE, f"{ID}.glb"), export_format="GLB", use_selection=True)
    with open(os.path.join(SORTIE, "squelette.json"), "w", encoding="utf-8") as f:
        json.dump(donnees, f, ensure_ascii=False, indent=1)


def installer_luau(donnees):
    """Écrit le script d'installation pour la Command Bar de Studio (données du squelette incluses)."""
    def vec(v):
        return "Vector3.new(%s, %s, %s)" % tuple(v)

    lignes = ["{"]
    for a in donnees["articulations"]:
        lignes.append('\t{ nom = "%s", parent = "%s", sorte = "%s", pivot = %s, centre = %s },' % (
            a["nom"], a["parent"], a["sorte"], vec(a["pivot"]), vec(a["centre"])))
    lignes.append("}")
    points = "{\n" + "".join('\t%s = %s,\n' % (k, vec(v)) for k, v in donnees["points"].items()) + "}"
    with open(os.path.join(ICI, "installer_gardien.luau"), encoding="utf-8") as f:
        modele = f.read()
    with open(os.path.join(ICI, "animation_gardien.luau"), encoding="utf-8") as f:
        anim = f.read()
    assert "]==]" not in anim
    remplacements = {
        "{} --@@ARTICULATIONS@@": "\n".join(lignes),
        "{} --@@POINTS@@": points,
        "-8.7 --@@SOL@@": str(donnees["sol"]),
        "22.7 --@@HAUTEUR@@": str(donnees["hauteur"]),
        '"" --@@ANIMATION@@': "[==[\n" + anim + "]==]",
    }
    src = modele
    for cle, val in remplacements.items():
        assert cle in src, cle
        src = src.replace(cle, val)
    with open(os.path.join(SORTIE, f"{ID}.installer.luau"), "w", encoding="utf-8") as f:
        f.write(src)
    with open(os.path.join(SORTIE, f"{ID}.animation.client.luau"), "w", encoding="utf-8") as f:
        f.write(anim)


# ---------------------------------------------------------------------------------------------
# Hiérarchie (pour le .blend et les poses des rendus)
# ---------------------------------------------------------------------------------------------
def articuler(objets):
    """Origine de chaque pièce sur son articulation, pièces lumineuses rattachées à leur base."""
    par_nom = {a["nom"]: a for a in ARTICULATIONS}
    for nom, ob in objets.items():
        base = PIECES[nom].base
        piv = par_nom[base]["pivot"] if base in par_nom else Vector()
        ob.data.transform(Matrix.Translation(-piv))
        ob.location = piv
    bpy.context.view_layer.update()
    for nom, ob in objets.items():
        base = PIECES[nom].base
        parent = base if nom != base else par_nom[nom]["parent"]
        if parent in objets:
            mw = ob.matrix_world.copy()
            ob.parent = objets[parent]
            ob.matrix_world = mw
    bpy.context.view_layer.update()


def poser(objets, t, marche=0.0, regard=None):
    """Même animation que dans Roblox (animation_gardien.luau), pour les rendus."""
    def rot(nom, x=0.0, y=0.0, z=0.0):
        # x : tangage (droite), y : lacet (vertical Roblox = z Blender), z : roulis
        if nom in objets:
            objets[nom].rotation_euler = (math.radians(x), math.radians(-z), math.radians(y))

    pas = t * 7.0
    for a in ARTICULATIONS:
        nom, sorte = a["nom"], a["sorte"]
        if sorte == "hanche":
            phase = 0 if nom in ("PatteAvGHaut", "PatteArDHaut") else math.pi
            rot(nom, x=math.sin(pas + phase) * 26 * marche)
        elif sorte == "genou":
            phase = 0 if nom in ("PatteAvGBas", "PatteArDBas") else math.pi
            rot(nom, x=-max(0.0, math.sin(pas + phase + 1.2)) * 34 * marche)
        elif sorte == "cou":
            lacet = math.sin(t * 0.5) * 10 * (1 - marche) if regard is None else regard
            rot(nom, x=math.sin(t * 0.8) * 3 + math.sin(pas * 2) * 2 * marche, y=lacet)
        elif sorte == "queue":
            i = int(nom[-2:])
            rot(nom, x=math.sin(t * 1.1 - i * 0.5) * 2.2, y=math.sin(t * 1.4 - i * 0.45) * 4.5)
    # la couronne flotte (translation) : on la règle à part
    base = next(a for a in ARTICULATIONS if a["nom"] == "Couronne")
    if "Couronne" in objets:
        objets["Couronne"].location = (base["pivot"] - next(x for x in ARTICULATIONS if x["nom"] == "Tete")["pivot"]) + Vector((0, 0, math.sin(t * 1.6) * 0.35))
    if "OrbiteQueue" in objets:
        objets["OrbiteQueue"].rotation_euler = (0, math.radians(math.sin(t * 0.4) * 8), 0)
    if "OrbiteTete" in objets:
        objets["OrbiteTete"].rotation_euler = (0, 0, math.radians(t * 16))
    if "Corps" in objets:
        corps = next(a for a in ARTICULATIONS if a["nom"] == "Corps")
        objets["Corps"].location = corps["pivot"] + Vector((0, 0, math.sin(t * 2.0) * 0.08 + abs(math.sin(pas)) * 0.35 * marche))


# ---------------------------------------------------------------------------------------------
# Rendus Cycles (décor de studio, effets : poussière d'étoiles, éclats de lune au sol)
# ---------------------------------------------------------------------------------------------
def vfx_rendu(mats):
    """Effets pour les images seulement (dans Roblox ce sont des particules)."""
    col = bpy.data.collections.new("VFX_Rendu")
    bpy.context.scene.collection.children.link(col)
    global PIECES
    sauve = PIECES
    PIECES = {}
    r = random.Random(42)
    # tapis de paillettes au sol, surtout sous la queue (comme sur la référence)
    for _ in range(2600):
        if r.random() < 0.7:
            y = r.uniform(-34, -6)
            x, yy = r.gauss(0, 3.0 + (-y) * 0.06), y
        else:
            x, yy = r.gauss(0, 4.2), r.uniform(-8, 7)
        t = r.uniform(0.03, 0.08)
        box("Sol_NeonBlanc" if r.random() < 0.45 else "Sol_NeonPale", (x, yy, 0.02), (t, t, 0.03))
    # étincelles en l'air autour de la queue
    for _ in range(170):
        y = r.uniform(-32, -6)
        x = r.gauss(-1.0, 3.0)
        z = r.uniform(2, 15)
        t = r.uniform(0.05, 0.11)
        box("Air_NeonBlanc" if r.random() < 0.7 else "Air_NeonCyan", (x, y, z), (t, t, t))
    # éclats de lune posés à plat sur le sol (disques et croissants)
    for k in range(18):
        ang = r.uniform(0, 2 * math.pi)
        x, y = r.uniform(-12, 9), r.uniform(-34, 12)
        if abs(x) < 4.0 and -8 < y < 7:
            continue
        rr = r.uniform(0.8, 1.3)
        n = (math.sin(ang) * 0.12, math.cos(ang) * 0.12, 1)
        if k % 3 == 0:
            pleine_lune("Eclats", (x, y, 0.17), n, rr * 0.8, 900 + k, ep=0.32)
        else:
            croissant_px("Eclats", (x, y, 0.17), n, (math.cos(ang), math.sin(ang), 0), rr, 900 + k, ep=0.32)
    vfx = PIECES
    PIECES = sauve
    objets = []
    for nom, p in vfx.items():
        me = bpy.data.meshes.new(nom)
        me.from_pydata([tuple(v) for v in p.v], [], p.f)
        uvl = me.uv_layers.new(name="UVMap")
        for f, uvs in zip(me.polygons, p.uv):
            for li, uv in zip(f.loop_indices, uvs):
                uvl.data[li].uv = uv
        me.materials.append(mats[sorte_materiau(nom, p)])
        ob = bpy.data.objects.new(nom, me)
        col.objects.link(ob)
        objets.append(ob)
    return col


def scene_rendu():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24 if VITE else 64
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 6
    sc.cycles.transmission_bounces = 6
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0
    sc.render.film_transparent = False
    # Sol et fond de studio : un grand bol (sol plat qui remonte doucement au loin)
    me = bpy.data.meshes.new("Studio")
    prof = [(0.0, 0.0)] + [(r, 0.0) for r in (10, 25, 45, 62)]
    for i in range(1, 7):
        a = (math.pi / 2) * i / 6
        prof.append((62 + math.sin(a) * 8, 8 - math.cos(a) * 8))
    prof.append((70, 90))
    seg = 64
    verts, faces = [], []
    for r, z in prof:
        for k in range(seg):
            a = 2 * math.pi * k / seg
            verts.append((math.cos(a) * r, math.sin(a) * r - 10, z))
    for i in range(len(prof) - 1):
        for k in range(seg):
            a0, a1 = i * seg + k, i * seg + (k + 1) % seg
            faces.append((a0, a1, a1 + seg, a0 + seg))
    me.from_pydata(verts, [], faces)
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new("Studio", me)
    sc.collection.objects.link(ob)
    m = bpy.data.materials.new("Studio")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = couleur_lin((150, 152, 160))
    b.inputs["Roughness"].default_value = 0.65
    me.materials.append(m)
    # Monde
    w = bpy.data.worlds.new("Monde")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = couleur_lin((150, 154, 166))
    bg.inputs["Strength"].default_value = 1.0
    # Lumières
    def lumiere(nom, sorte, pos, cible, energie, taille=5.0, couleur=(1, 1, 1)):
        ld = bpy.data.lights.new(nom, sorte)
        ld.energy = energie
        ld.color = couleur
        if sorte == "AREA":
            ld.size = taille
        elif sorte == "SUN":
            ld.angle = math.radians(taille)
        o = bpy.data.objects.new(nom, ld)
        o.location = pos
        d = Vector(cible) - Vector(pos)
        o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(o)
    lumiere("Cle", "AREA", (-26, 30, 34), (0, -4, 8), 10000, 22, (1.0, 0.98, 0.97))
    lumiere("Remplissage", "AREA", (-40, -20, 14), (0, -8, 8), 3500, 26, (0.85, 0.9, 1.0))
    lumiere("Remplissage2", "AREA", (30, 12, 16), (0, -6, 8), 2600, 22, (0.85, 0.9, 1.0))
    lumiere("Contre", "AREA", (8, -46, 30), (0, -8, 10), 5000, 16, (0.75, 0.85, 1.0))


def camera(pos, cible, focale=50, nom="Camera"):
    sc = bpy.context.scene
    cam = sc.objects.get(nom)
    if cam is None:
        cd = bpy.data.cameras.new(nom)
        cam = bpy.data.objects.new(nom, cd)
        sc.collection.objects.link(cam)
    cam.data.lens = focale
    cam.location = pos
    d = Vector(cible) - Vector(pos)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    return cam


def lueur(chemin):
    """Halo lumineux (bloom) ajouté sur l'image : les parties lumineuses « bavent » comme dans Roblox."""
    from PIL import Image, ImageFilter
    im = Image.open(chemin).convert("RGB")
    a = np.asarray(im).astype(np.float32) / 255
    lum = a.max(axis=2, keepdims=True)
    clair = np.clip((lum - 0.8) / 0.2, 0, 1) * a
    src = Image.fromarray((clair * 255).astype(np.uint8))
    total = np.zeros_like(a)
    for rayon, poids in ((4, 0.35), (14, 0.45), (42, 0.5)):
        flou = np.asarray(src.filter(ImageFilter.GaussianBlur(rayon * im.width / 1600))).astype(np.float32) / 255
        total += flou * poids
    total *= np.array([0.7, 0.95, 1.0], dtype=np.float32)  # lueur bleutée, comme la référence
    res = 1 - (1 - a) * (1 - np.clip(total, 0, 1))
    Image.fromarray((np.clip(res, 0, 1) * 255).astype(np.uint8)).save(chemin)


def comparaison():
    """Image de référence (en haut) et rendu héros (en bas), même taille : pour vérifier qu'ils
    se ressemblent."""
    from PIL import Image
    ref = os.path.join(RACINE, "docs", "references", "lunar-guardian.webp")
    heros = os.path.join(SORTIE, "rendus", "heros.png")
    if not (os.path.exists(ref) and os.path.exists(heros)):
        return
    a = Image.open(ref).convert("RGB").resize((1408, 768))
    b = Image.open(heros).convert("RGB").resize((1408, 768))
    planche = Image.new("RGB", (1408, 1536))
    planche.paste(a, (0, 0))
    planche.paste(b, (0, 768))
    planche.save(os.path.join(SORTIE, "rendus", "comparaison.png"))


def rendre(nom, w, h, pos, cible, focale=50, bloom=True):
    sc = bpy.context.scene
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.resolution_percentage = 100
    camera(pos, cible, focale)
    os.makedirs(os.path.join(SORTIE, "rendus"), exist_ok=True)
    chemin = os.path.join(SORTIE, "rendus", nom + ".png")
    sc.render.filepath = chemin
    bpy.ops.render.render(write_still=True)
    if bloom:
        lueur(chemin)
    print("rendu :", chemin)
    return chemin


CAM_HEROS = ((-56, 17, 13), (0, -11.5, 9.8), 36)


def faire_rendus(objets, mats):
    scene_rendu()
    vfx = vfx_rendu(mats)
    sc = bpy.context.scene
    seuls = [a for a in ARGS if a.startswith("--seul=")]
    seul = seuls[0].split("=", 1)[1].split(",") if seuls else None

    def veut(nom):
        return seul is None or nom in seul

    if veut("heros"):
        # même cadrage que l'image de référence : tête tournée vers nous, queue vers la droite
        poser(objets, 0.6, regard=30)
        rendre("heros", 1408, 768, CAM_HEROS[0], CAM_HEROS[1], CAM_HEROS[2])
        comparaison()
    poser(objets, 0.6)
    if veut("face"):
        rendre("face", 900, 900, (0, 50, 12), (0, 0, 11), 50)
    if veut("profil"):
        rendre("profil", 1600, 900, (-58, -12, 12), (0, -12, 10.5), 31)
    if veut("dos"):
        rendre("dos", 900, 900, (30, -68, 22), (0, -12, 10), 45)
    if veut("tete"):
        rendre("tete", 1200, 900, (-18, 26, 17), (0, 5.2, 14.5), 50)
    if veut("queue"):
        rendre("queue", 1200, 900, (-28, -8, 15), (0, -20, 10.5), 45)
    if veut("marche"):
        sc.cycles.samples = 16 if VITE else 40
        images = []
        for k in range(12):
            t = k / 12 * (2 * math.pi / 7.0)
            poser(objets, 0.6 + t * 1.0, marche=1.0)
            images.append(rendre(f"marche_{k:02d}", 800, 436, CAM_HEROS[0], CAM_HEROS[1], CAM_HEROS[2]))
        from PIL import Image
        ims = [Image.open(p).convert("RGB") for p in images]
        ims[0].save(os.path.join(SORTIE, "rendus", "marche.gif"), save_all=True, append_images=ims[1:], duration=70, loop=0)
        for p in images:
            os.remove(p)
        poser(objets, 0.6)
    return vfx


# ---------------------------------------------------------------------------------------------
def main():
    os.makedirs(SORTIE, exist_ok=True)
    chemin_tex = os.path.join(SORTIE, f"{ID}_texture.png")
    faire_texture(chemin_tex)
    vider_scene()
    bpy.context.scene.unit_settings.system = "NONE"
    mats = materiaux(chemin_tex)
    col, objets = creer_objets(mats)
    donnees = donnees_squelette(objets)
    exporter(col, objets, donnees)
    installer_luau(donnees)
    articuler(objets)
    print("pièces :", len(objets), "triangles :", donnees["triangles"], "hauteur :", donnees["hauteur"], "taille :", donnees["taille"])
    for p in sorted(donnees["pieces"], key=lambda p: -p["triangles"])[:6]:
        print("  ", p["nom"], p["triangles"])
    if FAIRE_RENDUS:
        faire_rendus(objets, mats)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SORTIE, f"{ID}.blend"), compress=True)


main()
