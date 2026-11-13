# CLAUDE.md — jeu Roblox du canyon (CreatureForge)

La mémoire du projet (le créateur, les règles décidées, ce qui est fait ou à faire, le journal
des demandes) est ici et doit être lue avant de travailler :

@docs/memoire-du-jeu.md

À la fin de chaque demande, **mettre à jour `docs/memoire-du-jeu.md`** : ajouter une ligne au
journal et mettre à jour « Ce qui est fait » / « À faire ».

## Règles de travail

- Tout est en **français** : réponses, commentaires du code, README, messages de commit.
- Code Luau `--!strict`, organisé comme un projet Rojo (`src/shared` → `ReplicatedStorage.CreatureForge`,
  `src/server` → ServerScriptService, `src/client` → StarterPlayerScripts). L'architecture est
  décrite dans le README (section « Architecture »).
- Une créature = un ModuleScript dans `src/shared/Creatures` qui renvoie une définition (ou une
  liste, comme les 10 variétés du Néant). Les pièces sont construites avec `Kit` et `Anatomy`.
  Les os `Leg*` / `Arm*` reçoivent des genoux et coudes. Os génériques animés : `Spin<N>`
  (attribut Speed), `Float<N>`, `Sway<N>`, `Belt`.
- Après une modification de `src/` :
  1. `lune run tools/tests/compile_all.luau` puis les tests concernés (`tools/tests/*.luau`) ;
  2. `lune run tools/export`, qui régénère les données du bestiaire (`tools/preview/*.json`) et
     `dist/models` ;
  3. `lune run tools/bundle`, puis `lune run tools/build_place`, qui régénère
     `dist/CreatureForge.rbxl`, la place complète que le créateur ouvre dans Studio ;
  4. mettre à jour le README, puis commiter (y compris `dist/`).
- Budget de pièces : carte ≈ 13 400 et place complète ≈ 80 000. Rester léger sur les décors
  répétés : éviter `rig:ring` avec beaucoup de segments sur un objet présent 8 fois.

## Aperçus et bestiaire

- Serveur local : `cd tools/preview && python3 -m http.server 8765`. Pages :
  - `bestiaire.html#<Id>` (`#Carte` pour la carte) ;
  - `viewer.html?id=<Id>&view=34&ui=0&bg=dark&zoomout=1.3`.
- Captures avec Playwright et Chromium, lancé avec
  `--use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader`. Attendre
  `window.__ready === true`. Pour placer la caméra sur la carte :
  `window.__view([x, y, z], [cibleX, cibleY, cibleZ])`. Les bases sont vers z = 44 à 212 et le
  canyon vers z < 0.
- Le bestiaire en ligne est un artefact privé : https://claude.ai/artifact/6wLxEoofvni4XYqjNBFNaM
  Pour le republier à la même adresse :
  1. copier `tools/preview/bestiaire.html` sans les lignes `<!doctype>`, `<html>`, `<head>`,
     `<meta charset>`, `<meta viewport>`, `</head>`, `<body>`, `</body>` et `</html>` ;
  2. publier avec `url` = cette adresse, `root` = `tools/preview` et la liste des fichiers
     `*.json`.
  L'artefact est privé : le créateur le partage lui-même avec le menu Partager.

## Pièges connus (Lune, hors Roblox)

- Pas de `Model:GetPivot()` → utiliser `PrimaryPart.CFrame`.
- Pas de `BasePart.Position` → utiliser `.CFrame.Position`.
- Dans les tests, `Random` vient de `Sandbox.Random` et `Color3` / `Vector3` de
  `require("@lune/roblox")`.
- `string.lower` ne met pas les lettres accentuées en minuscules (« LÉGENDAIRE » donne
  « lÉgendaire ») : utiliser des tables de noms écrites à la main.
- Texte des SurfaceGui : `FontFace = Font.fromEnum(Enum.Font.FredokaOne)`.

## Git

- Branche de travail (et branche par défaut du dépôt) : `claude/roblox-creatures-3d-models-x2ag9s`.
- Ne pas créer de pull request sans demande explicite.
