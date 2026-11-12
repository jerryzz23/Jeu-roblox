# CreatureForge — les personnages du jeu du tapis roulant

Les **21 personnages** du jeu (récap du 1er nov. 2026), assemblés **entièrement en code Luau** dans
le style « low-poly détaillé » : des centaines d'écailles, de mèches de fourrure, de plumes et
d'épines (Part / WedgePart), des matériaux Roblox (SmoothPlastic, Slate, Granite, Marble, Basalt,
Sand, Wood, Fabric, Grass, Glass, Metal, Neon), des ornements (armures d'or, runes lumineuses,
cristaux), des objets qui gravitent autour d'eux, des particules et des lumières. Chacun est
articulé (Motor6D), animé, a son **icône UI**, une **selle** (monture) et, pour les grands, une
**selle passager**. Les **8 raretés** et les **11 mutations cumulables** sont prises en compte.

## Bestiaire animé

`tools/preview/bestiaire.html` affiche les 21 personnages en 3D, **animés** (repos, marche,
capacité spéciale, figé), classés par rareté, avec leurs stats (taille, argent de base, bonus de
vitesse, passager) et les **mutations cumulables** (le revenu se calcule en direct). C'est le même
animateur que dans le jeu, porté en JavaScript. En local :
`cd tools/preview && python3 -m http.server 8000` puis http://localhost:8000/bestiaire.html
(une version en ligne est publiée en Artifact sur claude.ai).

![Les 21 personnages](docs/previews/roster.png)

## Raretés

| Rareté | Couleur | Où elle apparaît | Chance |
| --- | --- | --- | --- |
| Commun | Gris | Début du tapis | très fréquent |
| Rare | Bleu | Un peu plus loin | fréquent |
| Épique | Violet | Milieu du tapis | moyen |
| Légendaire | Or | Loin | peu fréquent |
| Mythique | Rouge | Très loin | rare |
| Exotique | Arc-en-ciel (animé) | Tout au bout | 1 sur 5 000 |
| Exclusif | Noir et or | Tout au bout + roue | 1 sur 50 000 |
| Chaotique | Glitch (couleurs qui changent) | Tout au bout | 1 sur 1 000 000 |

Chaque rareté a son **aura** autour des pieds (anneaux au sol, colonnes de lumière, particules),
de plus en plus riche ; l'Exotique est arc-en-ciel, l'Exclusif noir et or, le Chaotique glitch.
`Spawning.rollRarity(distance)` tire la rareté selon la position sur le tapis (0 = début,
1 = tout au bout) : chaque rareté normale suit une courbe en cloche, les raretés ultimes sont
tirées à part au bout du tapis. `luck = 2` pour le boost « Chance x2 ». Valeurs à ajuster en test :

| Distance | Commun | Rare | Épique | Légendaire | Mythique |
| --- | --- | --- | --- | --- | --- |
| 0 (début) | 100 % | | | | |
| 0,2 | 48 % | 52 % | | | |
| 0,5 | 1 % | 33 % | 67 % | | |
| 0,7 | | 2 % | 32 % | 66 % | |
| 1 (bout) | | | 0,4 % | 16 % | 84 % (+ Exotique 0,02 %, Exclusif 0,002 %, Chaotique 0,0001 %) |

## Les 21 personnages

| Personnage | Rareté | Taille | Argent de base | Vitesse | Passager | Points forts |
| --- | --- | --- | --- | --- | --- | --- |
| Renard des cendres | Commun | Petit | 5 $/s | +5 % | Non | fourrure grise, braises Neon dans le pelage, queue en feu |
| Loup d'acier | Commun | Moyen | 9 $/s | +7 % | Non | pelage en lames de métal poli, reflets du soleil |
| Cerf des brumes | Commun | Grand | 15 $/s | +8 % | Oui | bois de verre translucide, brume autour des bois |
| Lynx de givre | Rare | Petit | 50 $/s | +12 % | Non | fourrure blanche, cristaux de glace au bout des oreilles |
| Panthère d'orage | Rare | Moyen | 90 $/s | +15 % | Non | pelage noir, éclairs bleus, arcs électriques |
| Ours de granit | Rare | Grand | 140 $/s | +16 % | Oui | dos couvert de dalles de granit et de quartz |
| Faucon solaire | Épique | Petit | 500 $/s | +25 % | Non | plumes d'or, traînées de lumière |
| Tigre de jade | Épique | Moyen | 900 $/s | +28 % | Non | corps de jade sculpté, rayures lumineuses |
| Mammouth runique | Épique | Géant | 1 500 $/s | +30 % | Oui | défenses gravées de runes bleues, nacelle de menhirs |
| Phénix d'argent | Légendaire | Moyen | 6 000 $/s | +45 % | Non | flammes argentées, traîne de feu froid |
| Griffon impérial | Légendaire | Grand | 10 000 $/s | +55 % | Oui | mi-aigle mi-lion, armure d'or, selle de velours |
| Rhinocéros d'obsidienne | Légendaire | Géant | 14 000 $/s | +55 % | Oui | plaques noires brillantes, fissures de lave |
| Kirin céleste | Mythique | Moyen | 50 000 $/s | +80 % | Non | cheval-dragon de jade, sabots de nuages, crinière de flammes |
| Hydre d'émeraude | Mythique | Géant | 100 000 $/s | +95 % | Oui | trois têtes, trois cous qui ondulent, corps enroulé |
| Léviathan des sables | Mythique | Colossal | 150 000 $/s | +100 % | Oui | anneaux qui plongent dans les dunes |
| Dragon d'aurore | Exotique | Géant | 900 000 $/s | +150 % | Oui | écailles en dégradé d'aurore, ailes de verre teinté |
| Titan de cristal | Exotique | Colossal | 1,4M $/s | +160 % | Oui | golem de roche et de cristaux violets (démarche bipède) |
| Licorne d'éclipse | Exclusif (tapis + roue) | Grand | 8M $/s | +200 % | Oui | licorne noire, anneau de lumière autour de la corne |
| Sphinx stellaire | Exclusif (roue) | Géant | 11M $/s | +220 % | Oui | tête de pharaon, ailes remplies d'étoiles |
| Béhémoth abyssal | Exclusif (roue) | Colossal | 14M $/s | +240 % | Oui | leurre et photophores bleus, gueule aux dents-aiguilles |
| Le Néant Couronné | Chaotique | Colossal | 100M $/s | +400 % | Oui | vide et étoiles, couronne qui flotte au-dessus de la tête |

Les données de jeu sont dans chaque définition : `Size`, `Income`, `SpeedBonus`, `Passenger`,
`Source` (`"Tapis"`, `"TapisEtRoue"`, `"Roue"`). Les anciens modèles (Rat des Cavernes, Lézard
Mousseux…) sont conservés dans `src/shared/Archive/` mais ne sont plus dans le jeu.

### Les 10 variantes du Néant Couronné

![Variantes du Néant Couronné](docs/previews/neant-variantes.png)

`src/shared/Concepts/NeantCouronneVariantes.luau` : 10 styles différents (gothique spectral,
cosmique, nébuleuse, obsidienne et lave, royal noir et or, bioluminescent, flammes spectrales,
théâtre, éclipse solaire, céleste déchu). Toutes ont la couronne qui flotte et un corps de vide
constellé d'étoiles. Le Néant du jeu utilise la variante choisie : change `CHOIX` (1 à 10) dans
`src/shared/Creatures/NeantCouronne.luau`.

## Mutations

![Le Griffon impérial avec chacune des 11 mutations](docs/previews/mutations.png)

Chaque créature peut avoir **une ou plusieurs** mutations, visibles sur son modèle. Chaque
mutation est tirée indépendamment ; le revenu vaut **base × (multi1 + multi2 + …)**. Exemple :
Griffon impérial (10 000 $/s) + Vitrail (x2) + Kintsugi (x1,5) = 35 000 $/s.

| Mutation | Effet sur le modèle | Multi | Chance |
| --- | --- | --- | --- |
| Mousse ancienne | pierre grise couverte de mousse (matériau Grass) et de petites fleurs | x1,3 | 1 sur 8 |
| Kintsugi | porcelaine bleu et blanc, fissures remplies d'or lumineux | x1,5 | 1 sur 15 |
| Vitrail | verre coloré par panneaux, lumières colorées à l'intérieur | x2 | 1 sur 40 |
| Horloger | peau de laiton translucide, engrenages qui tournent dedans | x2,5 | 1 sur 80 |
| Mirage | couleurs de chaleur, corps qui ondule, ombre décalée au sol | x3 | 1 sur 150 |
| Encre | dessin noir et blanc, contour épais, traînées d'encre en courant | x3,5 | 1 sur 300 |
| Aurore | reflets d'aurore boréale qui défilent sur le corps, rubans d'aurore | x4 | 1 sur 600 |
| Fossile vivant | corps d'ambre translucide, squelette (os, côtes, crâne) visible | x5 | 1 sur 1 500 |
| Constellation | corps noir rempli d'étoiles reliées par des lignes | x7 | 1 sur 5 000 |
| Écho | une copie fantôme suit la créature avec une seconde de retard | x10 | 1 sur 20 000 |
| Paradoxe | change d'apparence de mutation toutes les 3 secondes | x15 | 1 sur 100 000 |

Quand plusieurs mutations sont cumulées, la plus rare impose ses couleurs ; les ajouts (fleurs,
fissures, engrenages, squelette, étoiles, ombre, fantôme) s'additionnent. Les effets animés
(engrenages, ondulation, aurore, écho, paradoxe) sont joués côté client par `Mutations.runtime`.

## Effets visuels (VFX)

Chaque créature combine une **aura de rareté**, des **effets signature** (braises, flocons,
éclairs, bulles, brume, poussière d'or…), des **traînées** au bout des ailes et des queues, des
**liens d'énergie** entre les objets en orbite et la créature, des lumières vivantes et une
**capacité spéciale** (`CreatureForge.playAbility(model)`) : onde de choc, dôme d'énergie,
souffle, gerbe d'éclats ou éruption, avec une pose de rugissement.

## Utilisation dans Roblox Studio

### Option 1 — Le jeu complet (le plus simple)

Ouvre **`dist/CreatureForge.rbxl`** dans Roblox Studio et appuie sur **Play** : les 21 personnages
apparaissent en rangées (une par rareté), se promènent et s'animent ; environ un sur trois reçoit
une ou deux mutations. Le bouton **Bestiaire** (en bas à gauche) affiche toutes les icônes.

### Option 2 — Une créature dans ta propre place

- **Command Bar** : copie tout `dist/<Créature>.commandbar.luau`, colle-le dans *View › Command Bar*,
  Entrée. Pour des mutations, change `local MUTATIONS = nil` en par exemple
  `local MUTATIONS = { "Kintsugi", "Vitrail" }` en haut de la partie « Entrée ».
- **Glisser-déposer** : `dist/models/<Créature>.rbxm` dans la vue 3D,
  `dist/icons/<Créature>_Icon.rbxm` sur `StarterGui`.

### Option 3 — Projet Rojo

```bash
rojo serve        # puis « Connect » dans le plugin Rojo de Studio
```

```lua
local CreatureForge = require(game.ReplicatedStorage.CreatureForge)

-- Apparition sur le tapis (côté serveur) : rareté selon la distance, créature, mutations
local def, mutations = CreatureForge.rollSpawn(0.8)   -- 0 = début du tapis, 1 = tout au bout
local model = CreatureForge.spawn(def.Id, CFrame.new(0, 0, -20), { mutations = mutations })
print(model:GetAttribute("Income"))                    -- base × (somme des multiplicateurs)

CreatureForge.setAnimState(model, "Move")              -- "Idle" | "Move" | "Still"
CreatureForge.playAbility(model)                       -- capacité spéciale (effets sur tous les clients)
CreatureForge.income("GriffonImperial", { "Vitrail", "Kintsugi" }) --> 35000
CreatureForge.buildIcon("GriffonImperial", frame, { mutations = { "Aurore" } })
CreatureForge.ofRarity("Exclusive")                    -- personnages d'une rareté
CreatureForge.Spawning.odds(0.5)                       -- chances de chaque rareté (affichage)
```

Options de `spawn` : `scale`, `mutations`, `outline` (contour Highlight, 31 visibles max),
`effects` (particules + lumières), `detail` (densité des écailles/fourrures, 1 = complète).

Chaque personnage a un `Seat` « Saddle » (monture) ; ceux qui ont `Passenger = true` ont aussi un
`Seat` « PassengerSeat » juste derrière. Le modèle porte les attributs `Income`, `SpeedBonus`,
`Passenger`, `Mutations` et `Multiplier` pour les systèmes de jeu.

## Performances

Les personnages font entre 1 000 et 3 800 pièces (soudées à un Root ancré, aucune physique simulée).
L'animation est faite côté client (`Motor6D.Transform`, zéro trafic réseau) et s'arrête au-delà
de 160 studs de la caméra. Les icônes utilisent un modèle allégé (`detail = 0.4–0.55`) et le
bestiaire ne les construit qu'à la première ouverture. Pour un jeu avec beaucoup de créatures à
l'écran, le visualiseur exporte chaque créature en **GLB/OBJ** (un maillage par matériau, couleurs
par sommet) à importer en MeshPart avec l'importateur 3D de Studio.

## Architecture

```
src/shared/                 -> ReplicatedStorage.CreatureForge
  init.luau                 registre, spawn / buildIcon / setAnimState / rollSpawn / income
  Kit.luau                  rig (os Motor6D), primitives low-poly, colonnes (spine),
                            tubes organiques + revêtements d'écailles / fourrure, ceintures
  Anatomy.luau              pattes, sabots, yeux, oreilles, cornes, dents, crêtes, flammes,
                            plumes, ailes, cristaux, engrenages, runes, orbites
  Mutations.luau            11 mutations cumulables (peinture, ajouts, runtime client)
  Spawning.luau             tirage des raretés selon la distance sur le tapis, format 1,5K / 2M
  Vfx.luau                  aura de rareté, rayons (Beam), traînées (Trail), capacités spéciales
  Fx.luau                   particules et lumières (textures moteur, aucun asset à téléverser)
  Icon.luau                 carte d'icône (UICorner, UIGradient, UIStroke, ViewportFrame)
  Rarity.luau               8 raretés (Commun -> Chaotique), couleurs animées, tailles
  Types.luau                contrat CreatureDef / AnimProfile / IconTheme
  Creatures/                un personnage = un ModuleScript (auto-enregistré)
  Concepts/                 les 10 variantes du Néant Couronné (non enregistrées)
  Archive/                  anciens modèles (non enregistrés)
src/client/                 CreatureAnimator (démarches Quadruped, Sprawler, Flyer, Serpent,
                            Hover, Biped + orbites + capacités + lumières + mutations), CreatureBestiary (UI)
src/server/                 CreatureShowcase (démo par rareté)
tools/                      export.luau, bundle.luau, build_place.luau,
                            preview/bestiaire.html (bestiaire animé), preview/viewer.html (aperçus)
```

### Régénérer `dist/` et les aperçus

Nécessite [Lune](https://github.com/lune-org/lune) (`cargo install lune`) :

```bash
lune run tools/export        # dist/models, dist/icons, données d'aperçu
lune run tools/export --concepts   # les 10 variantes du Néant Couronné
lune run tools/bundle        # dist/<Créature>.commandbar.luau
lune run tools/build_place   # dist/CreatureForge.rbxl
cd tools/preview && python3 -m http.server 8000
# http://localhost:8000/viewer.html?id=GriffonImperial&mut=Kintsugi,Vitrail
#   (mutations, VFX, vues, export GLB/OBJ ; ajoute &bg=dark pour un fond sombre)
```
