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
# LE PERSONNAGE
# ---------------------------------------------------------------------------------------------
ARTICULATIONS = []  # (nom, parent, pivot (Blender), sorte d'animation)


def articulation(nom, parent, pivot, sorte):
    ARTICULATIONS.append({"nom": nom, "parent": parent, "pivot": Vector(pivot), "sorte": sorte})


PX = 0.3

# ----- Corps ---------------------------------------------------------------------------------
BX, BY, BZ = 6.0, 9.6, 4.2
BC = Vector((0, -0.2, 8.7))
articulation("Corps", "Racine", (0, -0.2, 7.2), "corps")
box("Corps", BC, (BX, BY, BZ), "navy", tex="navy")
box("Corps", BC + Vector((0, 0, -BZ / 2 - 0.05)), (BX - 0.6, BY - 0.8, 0.1), "navyDeep")
for s in (1, -1):
    W, H = int(BY / PX), int(BZ / PX)
    places = [(ENGRENAGE, 0.8, 0.42), (SPIRALE, 0.47, 0.5), (CROISSANT, 0.14, 0.45)]
    if s < 0:
        places = [(miroir(m), 1 - fx, fy) for m, fx, fy in places]
    motif = composer(W, H, places, 10 + s, glyphes=5, poussiere=0.05, bord_bas="K", bord_haut="M")
    pixels("Corps", face(BC + Vector((s * BX / 2, 0, 0)), (s, 0, 0), (0, 0, 1)), PX, motif)
# Dos (le haut de la grille = vers la tête)
motif = composer(int(BX / PX), int(BY / PX), [(DIAMANT, 0.5, 0.18), (CRATERE, 0.28, 0.5), (CRATERE, 0.72, 0.64),
                 (PHASES[:1], 0.5, 0.86)], 3, glyphes=6, poussiere=0.05)
pixels("Corps", face(BC + Vector((0, 0, BZ / 2)), (0, 0, 1), (0, 1, 0)), PX, motif)
# Arrière (la queue en cache le milieu) et devant (sous la tête)
motif = composer(int(BX / PX), int(BZ / PX), [(CROISSANT, 0.12, 0.55), (miroir(CROISSANT), 0.88, 0.55)], 4,
                 glyphes=1, poussiere=0.06, interdits=[(5, 0, 14, 13)], bord_bas="K")
pixels("Corps", face(BC + Vector((0, -BY / 2, 0)), (0, -1, 0), (0, 0, 1)), PX, motif)
motif = composer(int(BX / PX), int(BZ / PX), [(CHEVRON, 0.5, 0.8), (PETIT_CRATERE, 0.2, 0.75), (PETIT_CRATERE, 0.8, 0.75)],
                 5, poussiere=0.05, interdits=[(0, 0, 19, 6)], bord_bas="K")
pixels("Corps", face(BC + Vector((0, BY / 2, 0)), (0, 1, 0), (0, 0, 1)), PX, motif)

# ----- Pattes ----------------------------------------------------------------------------------
PATTES = {"AvG": (-1.85, 2.6), "AvD": (1.85, 2.6), "ArG": (-1.85, -3.4), "ArD": (1.85, -3.4)}
for cle, (x, y) in PATTES.items():
    s = 1 if x > 0 else -1
    haut, bas = f"Patte{cle}Haut", f"Patte{cle}Bas"
    articulation(haut, "Corps", (x, y, 7.3), "hanche")
    articulation(bas, haut, (x, y, 4.0), "genou")
    graine = sum(map(ord, cle)) * 7
    # Cuisse / épaule
    box(haut, (x, y, 5.85), (2.2, 2.4, 3.9), "navy", tex="navy")
    box(haut, (x, y, 4.05), (2.36, 2.56, 0.36), "navyLight")
    plaque = Vector((x + s * 1.2, y, 6.35))
    box(haut, plaque, (0.3, 2.8, 2.7), "navyDark")
    box(haut, plaque + Vector((s * 0.06, 0, 1.32)), (0.36, 2.9, 0.12), "navyLight")
    pixels(haut, face(plaque + Vector((s * 0.15, 0, 0)), (s, 0, 0), (0, 0, 1)), 0.26, SPIRALE if s > 0 else miroir(SPIRALE))
    motif = composer(7, 11, [(CHEVRON, 0.5, 0.25)], graine, glyphes=1, poussiere=0.08)
    pixels(haut, face((x, y + 1.2, 5.6), (0, 1, 0), (0, 0, 1)), PX, motif)
    motif = composer(7, 11, [], graine + 1, glyphes=2, poussiere=0.1)
    pixels(haut, face((x, y - 1.2, 5.6), (0, -1, 0), (0, 0, 1)), PX, motif)
    motif = composer(8, 5, [], graine + 2, glyphes=1, poussiere=0.12)
    pixels(haut, face((x + s * 1.1, y, 4.75), (s, 0, 0), (0, 0, 1)), PX, motif)
    # Jambe, patte et doigts
    box(bas, (x, y, 2.45), (2.0, 2.1, 2.9), "navy", tex="navy")
    pixels(bas, face((x + s * 1.0, y, 2.5), (s, 0, 0), (0, 0, 1)), 0.25, MECHES if s > 0 else miroir(MECHES))
    motif = composer(6, 9, [(DIAMANT, 0.5, 0.45)], graine + 3, poussiere=0.06)
    pixels(bas, face((x, y + 1.05, 2.5), (0, 1, 0), (0, 0, 1)), PX, motif)
    motif = composer(6, 9, [], graine + 4, glyphes=1, poussiere=0.1)
    pixels(bas, face((x, y - 1.05, 2.5), (0, -1, 0), (0, 0, 1)), PX, motif)
    motif = composer(6, 9, [], graine + 5, glyphes=1, poussiere=0.1)
    pixels(bas, face((x - s * 1.0, y, 2.5), (-s, 0, 0), (0, 0, 1)), PX, motif)
    box(bas, (x, y + 0.25, 0.5), (2.4, 2.9, 1.0), "navyDeep")
    box(bas, (x, y + 0.25, 1.04), (2.2, 2.7, 0.08), "navyDark")
    for t in (-1, 0, 1):
        box(bas, (x + t * 0.78, y + 1.85, 0.36), (0.64, 0.36, 0.72), "navyDark")
        box(bas, (x + t * 0.78, y + 1.85, 0.76), (0.5, 0.3, 0.08), "navyLight")

# ----- Tête ------------------------------------------------------------------------------------
HX, HY, HZ = 6.6, 5.6, 5.8
HC = Vector((0, 6.0, 11.6))
AV = HC.y + HY / 2  # face avant
articulation("Tete", "Corps", (0, 4.0, 10.2), "cou")
box("Tete", HC, (HX, HY, HZ), "navy", tex="navy")
box("Tete", (0, AV + 0.03, 8.86), (HX - 0.2, 0.06, 0.24), "navyDark")
# Museau sombre, nez, bouche
box("Tete", (0, AV + 0.3, 9.75), (2.8, 0.6, 1.5), "navyDark")
box("Tete", (0, AV + 0.3, 10.54), (2.6, 0.5, 0.08), "navyLight")
box("Tete", (0, AV + 0.75, 10.15), (1.1, 0.34, 0.56), "nose")
box("Tete", (0, AV + 0.93, 10.3), (0.3, 0.04, 0.14), "navyLight")
pixels("Tete", face((0, AV + 0.6, 9.5), (0, 1, 0), (0, 0, 1)), 0.18, BOUCHE)
# Yeux : bord sombre, anneau blanc, iris cyan, cœur pâle, reflet
for s in (1, -1):
    e = Vector((s * 1.62, AV, 11.95))
    cylindre("Tete", e, (0, 1, 0), 1.38, 0.12, "eyeRim")
    cylindre("Tete_NeonBlanc", e + Vector((0, 0.12, 0)), (0, 1, 0), 1.2, 0.05)
    cylindre("Tete_NeonCyan", e + Vector((0, 0.17, 0)), (0, 1, 0), 1.03, 0.05)
    cylindre("Tete_NeonPale", e + Vector((0, 0.22, 0)), (0, 1, 0), 0.5, 0.04)
    box("Tete_NeonBlanc", e + Vector((0.42, 0.29, 0.42)), (0.36, 0.06, 0.36))
    box("Tete_NeonBlanc", e + Vector((-0.38, 0.29, -0.46)), (0.16, 0.06, 0.16))
# Front : croissant gravé, joues
W, H = int(HX / PX), int(HZ / PX)
yeux = [(1, 4, 9, 13), (12, 4, 20, 13)]
motif = composer(W, H, [(miroir(CROISSANT), 0.5, 0.16), (MECHES, 0.08, 0.8), (miroir(MECHES), 0.92, 0.8)], 21,
                 glyphes=2, poussiere=0.04, interdits=yeux + [(7, 13, 14, 18)])
pixels("Tete", face((0, AV, HC.z), (0, 1, 0), (0, 0, 1)), PX, motif)
# Côtés, dessus, arrière
for s in (1, -1):
    places = [(MECHES, 0.82, 0.7), (CROISSANT, 0.35, 0.3), (PETIT_CRATERE, 0.7, 0.25)]
    if s < 0:
        places = [(miroir(m), 1 - fx, fy) for m, fx, fy in places]
    motif = composer(int(HY / PX), int(HZ / PX), places, 30 + s, glyphes=3, poussiere=0.05, bord_bas="K")
    pixels("Tete", face(HC + Vector((s * HX / 2, 0, 0)), (s, 0, 0), (0, 0, 1)), PX, motif)
motif = composer(int(HX / PX), int(HY / PX), [(CRATERE, 0.5, 0.45), (PETIT_CRATERE, 0.25, 0.7)], 33,
                 glyphes=3, poussiere=0.05, interdits=[(0, 0, 5, 18), (17, 0, 21, 18)])
pixels("Tete", face(HC + Vector((0, 0, HZ / 2)), (0, 0, 1), (0, 1, 0)), PX, motif)
motif = composer(int(HX / PX), int(HZ / PX), [(ENGRENAGE, 0.5, 0.3)], 34, glyphes=3, poussiere=0.05)
pixels("Tete", face(HC + Vector((0, -HY / 2, 0)), (0, -1, 0), (0, 0, 1)), PX, motif)

# ----- Oreilles (triangles en marches, intérieur magenta) ---------------------------------------
for s, cote in ((-1, "G"), (1, "D")):
    nom = f"Oreille{cote}"
    articulation(nom, "Tete", (s * 2.2, 6.9, 14.5), "oreille")
    for k in range(8):
        w = 2.9 * (1 - k / 8.6)
        cx = s * (2.05 + 0.27 * k)
        z = 14.5 + 0.25 + 0.5 * k
        box(nom, (cx, 6.9, z), (w, 1.1, 0.5), "navyDark" if k < 7 else "navyLight")
        if k < 7:
            wi = w - 0.8
            if wi > 0.2:
                box(nom, (cx + s * 0.05, 7.55, z), (wi, 0.2, 0.5), "magenta" if k < 5 else "magentaLight")
            if k < 4:
                box(nom, (cx + s * 0.1, 7.7, z), (max(0.2, wi - 1.0), 0.1, 0.5), "magentaDark")
    box(nom + "_NeonMagenta", (s * 3.95, 6.9, 18.6), (0.42, 0.6, 0.4))

# ----- Cristaux derrière les oreilles, éclats sur les joues -------------------------------------
for s in (1, -1):
    for i, (b, d, L, r) in enumerate([
        ((s * 3.0, 4.6, 14.0), (s * 0.72, -0.18, 0.67), 7.4, 1.15),
        ((s * 3.3, 4.2, 13.2), (s * 0.95, -0.15, 0.3), 5.0, 0.85),
        ((s * 2.2, 4.0, 14.3), (s * 0.3, -0.5, 0.8), 4.4, 0.7),
        ((s * 3.4, 5.4, 12.4), (s * 1.0, 0.25, -0.05), 2.8, 0.55),
    ]):
        g = 100 + i * 7 + (s > 0)
        eclat("Tete_Cristal", b, d, L, r, g)
        dd = Vector(d).normalized()
        eclat("Tete_CristalCoeur", Vector(b) + dd * L * 0.12, d, L * 0.78, r * 0.42, g)
    eclat("Tete_Cristal", (s * 4.1, 8.2, 10.4), (s * 1.0, 0.3, 0.4), 1.3, 0.36, 140 + s)
    eclat("Tete_NeonMagenta", (s * 4.25, 6.9, 11.6), (s * 0.8, 0.0, 0.6), 0.9, 0.26, 150 + s)
    eclat("Tete_Cristal", (s * 4.4, 5.4, 9.8), (s * 0.6, -0.3, -0.5), 0.8, 0.24, 160 + s)

# ----- Couronne : grand croissant de lune en pixels qui flotte ----------------------------------
CC = Vector((0, 5.4, 19.0))
R_EXT, D_INT, R_INT = 3.45, 1.55, 2.9
articulation("Couronne", "Tete", (0, 5.4, 17.1), "flotte")
N = int(2 * R_EXT / PX) + 2


def dans_croissant(x, z):
    return math.hypot(x, z) <= R_EXT and math.hypot(x, z - D_INT) >= R_INT and z <= 2.6


cellules = {}
for j in range(N):
    for i in range(N):
        x = (i - (N - 1) / 2) * PX
        z = ((N - 1) / 2 - j) * PX
        if dans_croissant(x, z):
            cellules[(i, j)] = (x, z)
# Volume : une rangée de cubes par ligne (texture de lune sur les faces)
EP = 1.1
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
        box("Couronne", CC + Vector(((x0 + x1) / 2, 0, z)), ((k - i + 1) * PX, EP, PX), "moon", tex="moon")
        i = k + 1
# Faces avant et arrière : bord intérieur lumineux, bord extérieur ombré, cratères, éclats
rc = random.Random(5)
crat = set()
for _ in range(9):
    (ci, cj) = rc.choice(list(cellules))
    rr = rc.choice((1, 1, 2))
    for (i, j) in cellules:
        if math.hypot(i - ci, j - cj) <= rr:
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
            if not dans_croissant(x, z + PX):
                l.append("C")  # bord du dessus (intérieur du croissant) : lueur
            elif not dans_croissant(x, z - PX) or not dans_croissant(x + PX, z) or not dans_croissant(x - PX, z):
                l.append("E")
            elif (i, j) in crat:
                l.append("K")
            elif rc.random() < 0.12:
                l.append(rc.choice("SL"))
            else:
                l.append(".")
        lignes.append("".join(l))
    rep = face(CC + Vector((0, sens * EP / 2, 0)), (0, sens, 0), (0, 0, 1))
    pixels("Couronne", rep, PX, lignes if sens > 0 else miroir(lignes), PIX_LUNE)
# Petit croissant au centre (ouvert vers la gauche de l'image)
pc = 0.2
M2 = 14
lignes = []
for j in range(M2):
    l = ""
    for i in range(M2):
        x = (i - (M2 - 1) / 2) * pc
        z = ((M2 - 1) / 2 - j) * pc
        dedans = math.hypot(x, z) <= 1.15 and math.hypot(x + 0.55, z + 0.05) >= 0.93
        l += "Q" if dedans else "."
    lignes.append(l)
for sens in (1, -1):
    pixels("Couronne", face(CC + Vector((0, 0, 0.45)), (0, sens, 0), (0, 0, 1)), pc, lignes if sens > 0 else miroir(lignes), PIX_LUNE, relief=4.5)
# Étincelles
for (x, z, t) in ((3.3, 3.1, 0.26), (-2.9, 3.4, 0.2), (2.3, -3.0, 0.16)):
    for sens in (1, -1):
        pixels("Couronne", face(CC + Vector((x, sens * EP / 2, z)), (0, sens, 0), (0, 0, 1)), t, [".W.", "WWW", ".W."], PIX_LUNE)

# ----- Queue : cubes de lune lumineux, cube violet au bout -------------------------------------
ANGLES = [0, -2, -2, 0, 3, 7, 13, 22, 34, 48]
NQ = len(ANGLES)
joint = Vector((0, -BY / 2 - 0.2 + BC.y, 9.9))
QUEUE = []
for i, deg in enumerate(ANGLES):
    t = i / (NQ - 1)
    L = 2.4 - 0.45 * t
    h = 2.95 - 0.55 * t
    w = 2.65 - 0.45 * t
    if i == NQ - 1:
        L = h = w = 2.3
    th = math.radians(deg)
    d = Vector((0, -math.cos(th), math.sin(th)))
    centre = joint + d * (L / 2 + 0.08)
    nom = f"Queue{i + 1:02d}"
    articulation(nom, "Corps" if i == 0 else f"Queue{i:02d}", joint.copy(), "queue")
    QUEUE.append((nom, centre.copy(), d.copy(), (w, L, h)))
    R = Matrix.Rotation(-th, 3, "X")
    ex, ey, ez = R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)), R @ Vector((0, 0, 1))
    if i < NQ - 1:
        box(nom, centre, (w, L, h), "moon", R, tex="moon")
        box(nom + "_Halo", centre, (w * 1.1, L * 0.86, h * 1.1), R=R)
        # Côtés : anneau lumineux et disque de lune cratérisé
        pq = 0.2
        Wg, Hg = int(round(L / pq)), int(round(h / pq))
        rr = min(Wg, Hg) / 2 - 0.7
        rq = random.Random(300 + i)
        crs = [(rq.uniform(-rr * 0.5, rr * 0.5), rq.uniform(-rr * 0.5, rr * 0.5), rq.choice((0.9, 1.2, 1.6))) for _ in range(3)]
        lignes = []
        for jj in range(Hg):
            l = ""
            for ii in range(Wg):
                dx, dz = ii - (Wg - 1) / 2, jj - (Hg - 1) / 2
                r = math.hypot(dx, dz)
                if rr - 0.95 <= r <= rr + 0.45:
                    l += "C"
                elif r < rr - 1.9:
                    if any(math.hypot(dx - a, dz - b) <= c for a, b, c in crs):
                        l += "K"
                    else:
                        l += "S" if rq.random() < 0.8 else "E"
                else:
                    l += "." if rq.random() < 0.85 else "E"
            lignes.append(l)
        for sx in (1, -1):
            pixels(nom, face(centre + ex * (sx * w / 2), ex * sx, ez), pq, lignes, PIX_LUNE)
        # Dessus et dessous : cratères
        motif = composer(int(w / 0.25), int(L / 0.25), [(PETIT_CRATERE, rq.uniform(0.25, 0.75), rq.uniform(0.3, 0.7))],
                         400 + i, poussiere=0.05)
        motif = [l.replace("M", "E").replace("D", "K").replace("L", "S") for l in motif]
        pixels(nom, face(centre + ez * (h / 2), ez, -ey), 0.25, motif, PIX_LUNE)
        pixels(nom, face(centre - ez * (h / 2), -ez, ey), 0.25, motif, PIX_LUNE)
    else:
        box(nom, centre, (w, L, h), "tip", R, tex="tip")
        rb = random.Random(77)
        for axe, haut in ((ex, ez), (-ex, ez), (ez, -ey), (-ey, ez), (-ez, ey)):
            motif = composer(9, 9, [(PETIT_CRATERE, rb.uniform(0.3, 0.7), rb.uniform(0.3, 0.7))], rb.randint(0, 999),
                             poussiere=0.12)
            motif = [l.replace("M", "L").replace("D", "K") for l in motif]
            pixels(nom, face(centre + axe * (w / 2), axe, haut), 0.25, motif, PIX_BOUT)
    joint = centre + d * (L / 2 + 0.08)

# ----- Lunes en orbite -------------------------------------------------------------------------
def croissant_px(nom, centre, normale, haut, rayon, graine, ep=0.3):
    """Petit croissant en pixels, épais (lune qui flotte)."""
    px = rayon / 4.2
    n = int(2 * rayon / px) + 2
    r = random.Random(graine)
    lignes = []
    for j in range(n):
        l = ""
        for i in range(n):
            x = (i - (n - 1) / 2) * px
            z = ((n - 1) / 2 - j) * px
            dedans = math.hypot(x, z) <= rayon and math.hypot(x - rayon * 0.5, z - rayon * 0.12) >= rayon * 0.84
            if not dedans:
                l += "."
            elif math.hypot(x - rayon * 0.5, z - rayon * 0.12) < rayon * 0.84 + px * 1.1:
                l += "Q"
            else:
                l += r.choice("SSSSL")
        lignes.append(l)
    o, u, v, nn = face(centre, normale, haut)
    R = mat_axes(u, v, nn)
    # volume
    for j, l in enumerate(lignes):
        idx = [i for i, ch in enumerate(l) if ch != "."]
        if not idx:
            continue
        i0, i1 = min(idx), max(idx)
        c = o + u * (((i0 + i1) / 2 - (n - 1) / 2) * px) + v * (((n - 1) / 2 - j) * px)
        box(nom, c, ((i1 - i0 + 1) * px, px, ep), "moonLav", R)
    pixels(nom, (o + nn * ep / 2, u, v, nn), px, lignes, PIX_LUNE, relief=0.6)
    pixels(nom, (o - nn * ep / 2, -u, v, -nn), px, miroir(lignes), PIX_LUNE, relief=0.6)


def pleine_lune(nom, centre, normale, rayon, graine, ep=0.3):
    """Pleine lune en pixels : disque épais, cratères, anneau lumineux autour."""
    px = rayon / 4.0
    n = int(2 * rayon / px) + 4
    r = random.Random(graine)
    crs = [(r.uniform(-0.5, 0.5) * rayon, r.uniform(-0.5, 0.5) * rayon, r.uniform(0.18, 0.3) * rayon) for _ in range(3)]
    disque, anneau = [], []
    for j in range(n):
        l, a = "", ""
        for i in range(n):
            x = (i - (n - 1) / 2) * px
            z = ((n - 1) / 2 - j) * px
            d = math.hypot(x, z)
            if d <= rayon:
                if any(math.hypot(x - cx, z - cz) <= cr for cx, cz, cr in crs):
                    l += "K"
                elif d > rayon - px * 0.9:
                    l += "E"
                else:
                    l += r.choice("SSSL.")
                a += "."
            else:
                l += "."
                a += "C" if d <= rayon + px * 1.05 else "."
        disque.append(l)
        anneau.append(a)
    o, u, v, nn = face(centre, normale, (0, 0, 1) if abs(Vector(normale).normalized().z) < 0.9 else (0, 1, 0))
    R = mat_axes(u, v, nn)
    for j, l in enumerate(disque):
        idx = [i for i, ch in enumerate(l) if ch != "."]
        if idx:
            i0, i1 = min(idx), max(idx)
            c = o + u * (((i0 + i1) / 2 - (n - 1) / 2) * px) + v * (((n - 1) / 2 - j) * px)
            box(nom, c, ((i1 - i0 + 1) * px, px, ep), "moonLav", R)
    pixels(nom, (o + nn * ep / 2, u, v, nn), px, disque, PIX_LUNE, relief=0.6)
    pixels(nom, (o - nn * ep / 2, -u, v, -nn), px, miroir(disque), PIX_LUNE, relief=0.6)
    pixels(nom, (o - nn * (ep * 0.4), u, v, nn), px, anneau, PIX_LUNE, relief=ep / 0.07 * 0.8)


CENTRE_ORBITE_Q = Vector((0, -15.5, 12.0))
articulation("OrbiteQueue", "Corps", CENTRE_ORBITE_Q, "orbite_queue")
ro = random.Random(11)
for k in range(9):
    phi = math.radians(k * 40 + ro.uniform(-10, 10))
    rayon = ro.uniform(4.6, 6.4)
    le_long = (k / 8 - 0.5) * 15 + ro.uniform(-1, 1)
    pos = CENTRE_ORBITE_Q + Vector((math.cos(phi) * rayon, -le_long, math.sin(phi) * rayon * 0.8))
    normale = Vector((1 if math.cos(phi) >= 0 else -1, ro.uniform(-0.3, 0.3), ro.uniform(-0.3, 0.3)))
    if k % 3 == 1:
        pleine_lune("OrbiteQueue", pos, normale, ro.uniform(0.55, 0.8), 500 + k)
    else:
        croissant_px("OrbiteQueue", pos, normale, Vector((0, ro.uniform(-0.4, 0.4), 1)), ro.uniform(0.9, 1.5), 600 + k)

CENTRE_ORBITE_T = Vector((0, 6.0, 13.0))
articulation("OrbiteTete", "Corps", CENTRE_ORBITE_T, "orbite_tete")
for k, (deg, rayon, dz, sorte, taille) in enumerate([
    (165, 7.2, 1.8, "pleine", 0.75), (200, 6.6, -2.4, "croissant", 1.1), (20, 7.4, 2.6, "croissant", 0.9),
    (330, 6.8, -1.2, "pleine", 0.55), (95, 6.0, 4.2, "croissant", 0.7),
]):
    a = math.radians(deg)
    pos = CENTRE_ORBITE_T + Vector((math.cos(a) * rayon, math.sin(a) * rayon, dz))
    normale = Vector((math.cos(a), math.sin(a), 0)) * -1 + Vector((0, 0.6, 0))
    if sorte == "pleine":
        pleine_lune("OrbiteTete", pos, normale, taille, 700 + k)
    else:
        croissant_px("OrbiteTete", pos, normale, (0, 0, 1), taille, 800 + k)


# Points utiles aux VFX de Roblox (particules des cristaux, lumière des yeux, traînée)
POINTS_VFX = {
    "CristalG": Vector((-5.4, 3.9, 16.8)), "CristalD": Vector((5.4, 3.9, 16.8)),
    "Yeux": Vector((0, AV + 0.4, 11.95)), "QueueBout": QUEUE[-1][1],
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
        "moon": [(214, 212, 246), (232, 234, 250), (240, 242, 255), (222, 222, 250)],
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
            b.inputs["Alpha"].default_value = 0.07
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
        me.materials.append(mats[p.sorte])
        me.validate()
        ob = bpy.data.objects.new(nom, me)
        col.objects.link(ob)
        objets[nom] = ob
    return col, objets


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


def poser(objets, t, marche=0.0):
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
            rot(nom, x=math.sin(t * 0.8) * 3 + math.sin(pas * 2) * 2 * marche, y=math.sin(t * 0.5) * 10 * (1 - marche))
        elif sorte == "queue":
            i = int(nom[-2:])
            rot(nom, x=math.sin(t * 1.1 - i * 0.5) * 2.2, y=math.sin(t * 1.4 - i * 0.45) * 4.5)
    # la couronne flotte (translation) : on la règle à part
    base = next(a for a in ARTICULATIONS if a["nom"] == "Couronne")
    if "Couronne" in objets:
        objets["Couronne"].location = (base["pivot"] - next(x for x in ARTICULATIONS if x["nom"] == "Tete")["pivot"]) + Vector((0, 0, math.sin(t * 1.6) * 0.35))
    if "OrbiteQueue" in objets:
        objets["OrbiteQueue"].rotation_euler = (0, math.radians(t * 22), 0)
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
    # paillettes au sol (sous la queue et autour des pattes)
    for _ in range(420):
        if r.random() < 0.6:
            x, y = r.gauss(0, 3.4), r.uniform(-30, -4)
        else:
            x, y = r.gauss(0, 4.8), r.uniform(-8, 8)
        t = r.uniform(0.04, 0.11)
        box("Sol_NeonBlanc" if r.random() < 0.5 else "Sol_NeonPale", (x, y, 0.03), (t, t, 0.04))
    # poussière d'étoiles en l'air autour de la queue
    for _ in range(260):
        y = r.uniform(-32, -5)
        x = r.gauss(0, 2.6)
        z = r.uniform(5, 16) + max(0, -y - 20) * 0.3
        t = r.uniform(0.04, 0.1)
        box("Air_NeonBlanc" if r.random() < 0.6 else "Air_NeonCyan", (x, y, z), (t, t, t))
    # éclats de lune posés au sol
    for k in range(26):
        ang = r.uniform(0, 2 * math.pi)
        x, y = r.uniform(-11, 11), r.uniform(-34, 12)
        if abs(x) < 3.5 and -8 < y < 6:
            continue
        rr = r.uniform(0.35, 0.7)
        croissant_px("Eclats", (x, y, 0.12), (math.sin(ang) * 0.15, math.cos(ang) * 0.15, 1), (math.cos(ang), math.sin(ang), 0), rr, 900 + k, ep=0.14)
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
        me.materials.append(mats[p.sorte])
        ob = bpy.data.objects.new(nom, me)
        col.objects.link(ob)
        objets.append(ob)
    return col


def scene_rendu():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24 if VITE else 96
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 6
    sc.cycles.transmission_bounces = 6
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0
    sc.render.film_transparent = False
    # Sol et fond de studio : un grand bol (sol plat qui remonte doucement au loin)
    me = bpy.data.meshes.new("Studio")
    prof = [(0.0, 0.0)] + [(r, 0.0) for r in (10, 25, 45, 70)]
    for i in range(1, 11):
        a = (math.pi / 2) * i / 10
        prof.append((70 + math.sin(a) * 30, 30 - math.cos(a) * 30))
    prof.append((100, 90))
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
    b.inputs["Base Color"].default_value = couleur_lin((112, 114, 124))
    b.inputs["Roughness"].default_value = 0.6
    me.materials.append(m)
    # Monde
    w = bpy.data.worlds.new("Monde")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = couleur_lin((86, 90, 104))
    bg.inputs["Strength"].default_value = 0.8
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
    lumiere("Cle", "AREA", (-26, 30, 34), (0, -4, 8), 7000, 18, (1.0, 0.97, 0.95))
    lumiere("Remplissage", "AREA", (30, 12, 16), (0, -6, 8), 2600, 22, (0.85, 0.9, 1.0))
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
    for rayon, poids in ((4, 0.35), (14, 0.4), (42, 0.45)):
        flou = np.asarray(src.filter(ImageFilter.GaussianBlur(rayon * im.width / 1600))).astype(np.float32) / 255
        total += flou * poids
    res = 1 - (1 - a) * (1 - np.clip(total, 0, 1))
    Image.fromarray((np.clip(res, 0, 1) * 255).astype(np.uint8)).save(chemin)


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


def faire_rendus(objets, mats):
    scene_rendu()
    vfx = vfx_rendu(mats)
    sc = bpy.context.scene
    seuls = [a for a in ARGS if a.startswith("--seul=")]
    seul = seuls[0].split("=", 1)[1].split(",") if seuls else None

    def veut(nom):
        return seul is None or nom in seul

    poser(objets, 0.6)
    if veut("heros"):
        rendre("heros", 1600, 900, (-37, 36, 24), (0, -9.5, 9.5), 34)
    if veut("face"):
        rendre("face", 900, 900, (0, 46, 13), (0, 0, 11), 50)
    if veut("profil"):
        rendre("profil", 1600, 900, (-64, -9, 13), (0, -9.5, 10.5), 40)
    if veut("dos"):
        rendre("dos", 900, 900, (24, -58, 22), (0, -10, 10), 45)
    if veut("tete"):
        rendre("tete", 1200, 900, (-16, 24, 17), (0, 5.5, 14.5), 50)
    if veut("queue"):
        rendre("queue", 1200, 900, (-22, -6, 18), (0, -18, 11.5), 45)
    if veut("marche"):
        sc.cycles.samples = 16 if VITE else 40
        images = []
        for k in range(12):
            t = k / 12 * (2 * math.pi / 7.0)
            poser(objets, 0.6 + t * 1.0, marche=1.0)
            images.append(rendre(f"marche_{k:02d}", 800, 450, (-40, 31, 19), (0, -8.5, 10.0), 38))
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
