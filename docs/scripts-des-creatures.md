# Les scripts des 30 créatures

Chaque créature a son **script complet et autonome** dans `dist/` (`<Nom>.commandbar.luau`, de
140 à 200 Ko). Le script contient tout le nécessaire, sans aucun autre fichier :

- les outils de construction ;
- le modèle 3D, pièce par pièce, articulé pour les animations ;
- les couleurs, matériaux et effets (particules, lumières, rayons, traînées) ;
- la capacité spéciale ;
- l'icône d'inventaire.

Il construit la créature devant la caméra de Roblox Studio.

## Utiliser un script dans Roblox Studio

1. Ouvre une place dans Roblox Studio (n'importe laquelle, ou `CreatureForge.rbxl`).
2. Affiche la barre de commande : menu **View**, puis **Command Bar**.
3. Ouvre le fichier `.luau` de la créature avec le Bloc-notes. Sélectionne tout (**Ctrl+A**)
   et copie (**Ctrl+C**).
4. Clique dans la barre de commande, colle (**Ctrl+V**), puis appuie sur **Entrée**.
5. La créature apparaît devant la caméra, déjà sélectionnée. Son icône d'inventaire est ajoutée
   dans **StarterGui > CreatureForgeIcons**.

Pour ajouter des **mutations**, cherche la ligne `local MUTATIONS = nil` vers la fin du
script (**Ctrl+F**) et remplace-la par exemple par `local MUTATIONS = { "Kintsugi", "Vitrail" }`.
Noms possibles : `Mousse`, `Kintsugi`, `Vitrail`, `Horloger`, `Mirage`, `Encre`, `Aurore`,
`Fossile`, `Constellation`, `Echo` et `Paradoxe`.

Le script est long : le collage peut prendre quelques secondes. Les animations se jouent quand
tu lances le jeu (**Play**) dans une place qui contient le script `CreatureAnimator`, comme
`CreatureForge.rbxl`.

Les 30 scripts ont été testés : chacun construit sa créature et son icône sans erreur.

Dans le dépôt, le code lisible de chaque créature est dans `src/shared/Creatures/<Nom>.luau`
(les 10 Néant Couronné sont dans `src/shared/Concepts/NeantCouronneVariantes.luau`). Le script
de `dist/` est ce même code, regroupé en un seul fichier.

## Commun (3)

### Cerf des brumes

*Cerf discret aux bois de verre translucide ; une brume fraîche s'enroule autour de ses bois.*

| | |
| --- | --- |
| Script | `dist/CerfDesBrumes.commandbar.luau` (140 Ko) |
| Rareté | Commun, dans le canyon |
| Taille | Grand |
| Argent de base | 15 $/s |
| Bonus de vitesse (monture) | +8 % |
| Selle passager | oui |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Voile de brume (onde d'énergie, 1,6 s) |
| Pièces | 2 325 |

Cerf aux bois translucides entourés de brume.

- Robe gris-taupe nuancée, poitrail clair, pattes fines et sabots argentés.
- Grands bois en verre translucide (Glass) aux pointes perlées, reliés par des fils de brume.
- Effets : brume qui s'enroule autour des bois et flotte au ras du sol.

### Loup d'acier

*Loup au pelage d'acier poli : au soleil, chaque mèche renvoie un éclat de lumière.*

| | |
| --- | --- |
| Script | `dist/LoupDAcier.commandbar.luau` (141 Ko) |
| Rareté | Commun, dans le canyon |
| Taille | Moyen |
| Argent de base | 9 $/s |
| Bonus de vitesse (monture) | +7 % |
| Selle passager | non |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Hurlement d'acier (onde d'énergie, 1,6 s) |
| Pièces | 2 232 |

Loup au pelage métallique qui brille au soleil.

- Fourrure en lames d'acier poli (matériau Metal, reflets), pointes argent clair.
- Crinière d'épines métalliques, plaques d'acier bleui sur le ventre et les pattes.
- Collier d'acier riveté, runes cyan ; yeux Neon bleu glacier, crocs d'acier.
- Effets : éclats de lumière (reflets du soleil) qui scintillent sur le pelage.

### Renard des cendres

*Renard gris des cendres : des braises rougeoient au fond de sa fourrure et le bout de sa queue brûle encore.*

| | |
| --- | --- |
| Script | `dist/RenardDesCendres.commandbar.luau` (141 Ko) |
| Rareté | Commun, dans le canyon |
| Taille | Petit |
| Argent de base | 5 $/s |
| Bonus de vitesse (monture) | +5 % |
| Selle passager | non |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Souffle de cendres (souffle, 1,6 s) |
| Pièces | 1 754 |

Renard gris avec des braises qui rougeoient dans la fourrure.

- Fourrure grise en mèches, pointes de braise Neon orange qui rougeoient.
- Plastron et joues gris clair, chaussettes anthracite, marques de braise au front.
- Grande queue grise dont le bout devient cendre puis flammes.
- Effets : braises qui s'envolent, lueur chaude au bout de la queue.

## Rare (3)

### Lynx de givre

*Lynx blanc des neiges : des cristaux de glace poussent au bout de ses oreilles.*

| | |
| --- | --- |
| Script | `dist/LynxDeGivre.commandbar.luau` (141 Ko) |
| Rareté | Rare, dans le canyon |
| Taille | Petit |
| Argent de base | 50 $/s |
| Bonus de vitesse (monture) | +12 % |
| Selle passager | non |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Souffle de givre (souffle, 1,6 s) |
| Pièces | 1 702 |

Lynx blanc avec des cristaux de glace sur les oreilles.

- Épaisse fourrure blanche aux pointes givrées, collerette de joues en mèches, queue courte.
- Grandes oreilles à pinceaux surmontées de cristaux de glace (verre + Neon).
- Fines traînées de givre Neon bleu pâle sur les flancs, yeux Neon bleu glacier.
- Flocons de glace en orbite ; effets : neige qui tombe, souffle givré.

### Ours de granit

*Ours massif dont le dos n'est plus qu'un amas de dalles de granit hérissé de quartz.*

| | |
| --- | --- |
| Script | `dist/OursDeGranit.commandbar.luau` (140 Ko) |
| Rareté | Rare, dans le canyon |
| Taille | Grand |
| Argent de base | 140 $/s |
| Bonus de vitesse (monture) | +16 % |
| Selle passager | oui |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Avalanche de granit (onde de choc au sol, 1,6 s) |
| Pièces | 2 014 |

Ours dont le dos est couvert de roche.

- Fourrure brun-gris épaisse, museau clair, griffes d'ivoire.
- Dos couvert de dalles de granit moucheté superposées, hérissé de quartz.
- Épaulières et brassards de pierre, veines de quartz bleu clair.
- Pierres levées en orbite ; selle naturelle entre les rochers pour un passager.

### Panthère d'orage

*Panthère noire chargée d'orage : de petits éclairs courent sur son pelage quand elle bondit.*

| | |
| --- | --- |
| Script | `dist/PanthereDOrage.commandbar.luau` (140 Ko) |
| Rareté | Rare, dans le canyon |
| Taille | Moyen |
| Argent de base | 90 $/s |
| Bonus de vitesse (monture) | +15 % |
| Selle passager | non |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Bond foudroyant (explosion, 1,6 s) |
| Pièces | 1 312 |

Panthère noire parcourue de petits éclairs.

- Pelage noir lustré en écailles fines, reflets bleu nuit.
- Éclairs Neon bleu électrique en zigzag sur les flancs, bout de queue chargé d'électricité.
- Yeux Neon jaune orage, collier d'argent à gemme bleue.
- Orbes d'orage en orbite ; effets : étincelles, arcs électriques entre les épaules et les hanches.

## Épique (3)

### Faucon solaire

*Faucon au plumage d'or : chaque battement d'ailes laisse une traînée de lumière solaire.*

| | |
| --- | --- |
| Script | `dist/FauconSolaire.commandbar.luau` (139 Ko) |
| Rareté | Épique, dans le canyon |
| Taille | Petit |
| Argent de base | 500 $/s |
| Bonus de vitesse (monture) | +25 % |
| Selle passager | non |
| Démarche | vol (ailes) |
| Capacité spéciale | Éclat solaire (explosion, 1,6 s) |
| Pièces | 1 023 |

Faucon aux plumes dorées qui laissent une traînée de lumière.

- Plumage d'or (crème -> or -> ambre), rémiges incrustées de cristaux de soleil.
- Masque ambré, bec et serres dorés, yeux Neon blanc solaire.
- Effets : traînées de lumière dorée au bout des ailes, poussière de soleil.

### Mammouth runique

*Mammouth ancestral aux défenses gravées de runes bleues ; il porte une nacelle de menhirs sur le dos.*

| | |
| --- | --- |
| Script | `dist/MammouthRunique.commandbar.luau` (143 Ko) |
| Rareté | Épique, dans le canyon |
| Taille | Géant |
| Argent de base | 1,5K $/s |
| Bonus de vitesse (monture) | +30 % |
| Selle passager | oui |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Charge runique (onde de choc au sol, 1,8 s) |
| Pièces | 2 674 |

Mammouth aux défenses gravées de runes bleues.

- Énorme corps en longues mèches de laine brune, pattes cerclées de pierre sculptée.
- Immenses défenses d'ivoire gravées de runes bleues lumineuses, cerclées de bandes Neon.
- Nacelle de pierre sur le dos : quatre menhirs runiques couronnés de cristaux, cristal central.
- Pierres runiques en orbite ; effets : brume bleue au sommet des menhirs, étincelles runiques.

### Tigre de jade

*Tigre sculpté dans le jade : ses rayures s'illuminent d'un vert profond quand il rugit.*

| | |
| --- | --- |
| Script | `dist/TigreDeJade.commandbar.luau` (140 Ko) |
| Rareté | Épique, dans le canyon |
| Taille | Moyen |
| Argent de base | 900 $/s |
| Bonus de vitesse (monture) | +28 % |
| Selle passager | non |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Rugissement de jade (onde d'énergie, 1,6 s) |
| Pièces | 1 368 |

Tigre sculpté dans la pierre verte, rayures lumineuses.

- Corps sculpté en plaques de jade (matériau Marble), vert profond -> vert d'eau.
- Rayures Neon vert lumineux sur les flancs, la tête et la queue.
- Collier d'or impérial serti de jade, yeux Neon d'or.
- Pièces de jade cerclées d'or en orbite ; effets : lueurs vertes, poussière d'or.

## Légendaire (3)

### Griffon impérial

*Mi-aigle mi-lion, harnaché d'une armure d'or impériale : la monture des souverains.*

| | |
| --- | --- |
| Script | `dist/GriffonImperial.commandbar.luau` (143 Ko) |
| Rareté | Légendaire, dans le canyon |
| Taille | Grand |
| Argent de base | 10K $/s |
| Bonus de vitesse (monture) | +55 % |
| Selle passager | oui |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Charge impériale (explosion, 1,6 s) |
| Pièces | 2 453 |

Mi-aigle mi-lion avec une armure dorée. pattes d'aigle écailleuses jaunes aux serres noires. selle de velours pourpre (monture avec passager).

- Avant d'aigle : tête et poitrail en plumes blanches, bec d'or crochu, huppe de plumes,
- Arrière de lion : pelage fauve en mèches, pattes à coussinets, queue à touffe sombre.
- Grandes ailes à 3 rangées (blanc, or, bronze) aux pointes Neon or.
- Armure impériale : casque à crête, plastron serti d'un rubis, ceinture et épaulières d'or,
- Plumes d'or en orbite ; effets : poussière d'or, traînées dorées au bout des ailes.

### Phénix d'argent

*Phénix aux flammes d'argent : son feu froid illumine la nuit d'une lueur bleutée.*

| | |
| --- | --- |
| Script | `dist/PhenixDArgent.commandbar.luau` (140 Ko) |
| Rareté | Légendaire, dans le canyon |
| Taille | Moyen |
| Argent de base | 6K $/s |
| Bonus de vitesse (monture) | +45 % |
| Selle passager | non |
| Démarche | vol (ailes) |
| Capacité spéciale | Flamme d'argent (onde d'énergie, 2 s) |
| Pièces | 1 932 |

Oiseau de flammes argentées.

- Plumage argent -> blanc nacré, collerette argentée, couvertures gris perle.
- Immenses ailes à 3 rangées aux pointes Neon blanc bleuté ; flammes argentées le long des ailes.
- Longue traîne de plumes enflammées d'argent ; huppe de flammes blanches, yeux Neon glacier.
- Plumes d'argent et boules de feu blanc en orbite ; effets : traînée de feu argenté, forte lueur froide.

### Rhinocéros d'obsidienne

*Rhinocéros de pierre volcanique noire et brillante ; la lave luit entre ses plaques.*

| | |
| --- | --- |
| Script | `dist/RhinocerosDObsidienne.commandbar.luau` (140 Ko) |
| Rareté | Légendaire, dans le canyon |
| Taille | Géant |
| Argent de base | 14K $/s |
| Bonus de vitesse (monture) | +55 % |
| Selle passager | oui |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Charge volcanique (onde de choc au sol, 1,6 s) |
| Pièces | 1 077 |

Rhinocéros en pierre volcanique noire et brillante.

- Corps massif en plaques d'obsidienne polie (reflets violets), fissures de lave orange.
- Énorme corne principale en obsidienne vitreuse cerclée de lave, seconde corne plus petite.
- Épaulières en lames d'obsidienne, pattes-colonnes aux sabots de basalte.
- Petites oreilles, yeux Neon orange ; selle de basalte pour deux cavaliers.
- Éclats d'obsidienne et braises en orbite ; effets : fumée, braises, lueur de lave.

## Mythique (3)

### Hydre d'émeraude

*Serpent colossal à trois têtes aux écailles d'émeraude ; chaque cou ondule à son propre rythme.*

| | |
| --- | --- |
| Script | `dist/HydreDEmeraude.commandbar.luau` (141 Ko) |
| Rareté | Mythique, dans le canyon |
| Taille | Géant |
| Argent de base | 100K $/s |
| Bonus de vitesse (monture) | +95 % |
| Selle passager | oui |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Triple souffle (souffle, 1,6 s) |
| Pièces | 3 314 |

Serpent à trois têtes aux écailles vertes. cornes noires, collerette d'épines, émeraude incrustée sur le front.

- Corps de serpent massif enroulé au sol, écailles émeraude -> vert sombre, ventre crème annelé.
- Trois longs cous qui ondulent chacun à leur rythme (os "Sway"), cerclés d'anneaux d'or.
- Trois têtes de serpent-dragon : gueules ouvertes, crocs, yeux Neon jaunes fendus,
- Selle sur le haut des anneaux (monture avec passager).
- Émeraudes en orbite ; effets : brume verte, éclats d'émeraude, lueur.

### Kirin céleste

*Cheval-dragon sacré aux écailles de jade : ses sabots se posent sur des nuages.*

| | |
| --- | --- |
| Script | `dist/KirinCeleste.commandbar.luau` (142 Ko) |
| Rareté | Mythique, dans le canyon |
| Taille | Moyen |
| Argent de base | 50K $/s |
| Bonus de vitesse (monture) | +80 % |
| Selle passager | non |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Galop céleste (explosion, 1,6 s) |
| Pièces | 2 567 |

Cheval-dragon aux sabots de nuages.

- Corps de cheval élancé couvert d'écailles de dragon turquoise -> jade, ventre crème doré.
- Tête de dragon : cornes ramifiées d'or, longues moustaches, barbiche, crinière de flammes dorées.
- Crinière de flammes or et blanc le long de l'encolure et du dos, queue de lion enflammée.
- Sabots posés sur des nuages (boules de nuages blancs et lilas) qui laissent une brume.
- Perles célestes en orbite ; effets : nuages qui s'effilochent, poussière d'or.

### Léviathan des sables

*Serpent colossal qui nage dans les dunes : ses anneaux plongent et ressortent du sable.*

| | |
| --- | --- |
| Script | `dist/LeviathanDesSables.commandbar.luau` (143 Ko) |
| Rareté | Mythique, dans le canyon |
| Taille | Colossal |
| Argent de base | 150K $/s |
| Bonus de vitesse (monture) | +100 % |
| Selle passager | oui |
| Démarche | serpent (ondule) |
| Capacité spéciale | Tempête de sable (souffle, 2 s) |
| Pièces | 3 780 |

Serpent colossal qui nage dans le sable.

- Corps enroulé qui plonge et ressort des dunes, cou dressé en S.
- Écailles sable doré -> ocre -> brun, ventre crème ; ceintures d'or rivetées.
- Crête dorsale de rayons aux pointes d'or ; tête de dragon, crocs, yeux Neon orange fendus, cornes annelées.
- Colonnes de grès brisées et rochers en orbite ; dunes et ondes de sable au sol.
- Effets : gerbes de sable, brume de chaleur, lueur dorée.

## Exotique (2)

### Dragon d'aurore

*Dragon aux écailles couleur aurore boréale ; ses ailes de verre teinté filtrent la lumière du ciel polaire.*

| | |
| --- | --- |
| Script | `dist/DragonDAurore.commandbar.luau` (143 Ko) |
| Rareté | Exotique, dans le canyon |
| Taille | Géant |
| Argent de base | 900K $/s |
| Bonus de vitesse (monture) | +150 % |
| Selle passager | oui |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Souffle boréal (souffle, 1,6 s) |
| Pièces | 2 470 |

Dragon aux écailles couleur aurore boréale.

- Écailles en dégradé d'aurore le long du corps : vert -> turquoise -> bleu -> violet -> rose.
- Grandes ailes membraneuses en verre teinté (un panneau par couleur d'aurore), doigts sombres.
- Crête dorsale de pointes Neon changeantes, ventre nacré, griffes et cornes d'argent.
- Tête de dragon : gueule garnie de crocs, yeux Neon blancs, double paire de cornes.
- Selle d'argent (monture avec passager).
- Cristaux d'aurore en orbite ; effets : rubans d'aurore au-dessus du dos, poussière d'étoiles.

### Titan de cristal

*Golem colossal fait de roche et de cristaux violets ; son cœur de cristal bat dans sa poitrine.*

| | |
| --- | --- |
| Script | `dist/TitanDeCristal.commandbar.luau` (139 Ko) |
| Rareté | Exotique, dans le canyon |
| Taille | Colossal |
| Argent de base | 1,4M $/s |
| Bonus de vitesse (monture) | +160 % |
| Selle passager | oui |
| Démarche | bipède (2 jambes, bras) |
| Capacité spéciale | Séisme de cristal (onde de choc au sol, 1,6 s) |
| Pièces | 1 094 |

Golem géant fait de cristaux violets. (verre teinté + cœurs Neon) sur les épaules, le dos, les avant-bras et la tête.

- Corps de roche sombre en dalles, d'où jaillissent d'énormes grappes de cristaux violets
- Cœur de cristal incandescent dans la poitrine, fissures Neon violettes entre les dalles.
- Bras massifs aux poings hérissés de cristaux, jambes-colonnes, pieds de roche.
- Tête basse aux yeux Neon, couronne de cristaux ; plateforme sur les épaules (passager).
- Éclats de cristal en orbite ; effets : poussière scintillante, forte lueur violette.

## Exclusif (3)

### Béhémoth abyssal

*Monstre des fosses océaniques : son leurre et ses photophores bleus sont les seules lumières des profondeurs.*

| | |
| --- | --- |
| Script | `dist/BehemothAbyssal.commandbar.luau` (142 Ko) |
| Rareté | Exclusif, seulement à la roue |
| Taille | Colossal |
| Argent de base | 14M $/s |
| Bonus de vitesse (monture) | +240 % |
| Selle passager | oui |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Rugissement abyssal (onde d'énergie, 1,6 s) |
| Pièces | 1 370 |

Monstre des profondeurs aux lumières bleues (roue uniquement).

- Corps de baleine cuirassée sur quatre pattes trapues : plaques bleu nuit, ventre strié gris-bleu.
- Immense gueule aux rangées de dents-aiguilles, gorge qui luit d'un bleu profond.
- Leurre lumineux au bout d'une antenne (poisson-lanterne), six petits yeux Neon bleu pâle.
- Rangées de photophores bleus le long des flancs, crête dorsale, nageoires et nageoire caudale.
- Barbillons ondulants sous la mâchoire (os "Sway") ; selle sur le dos (passager).
- Orbes abyssaux en orbite ; effets : bulles, brume des profondeurs, lueurs bleues.

### Licorne d'éclipse

*Licorne noire née pendant une éclipse : un anneau de lumière tourne autour de sa corne.*

| | |
| --- | --- |
| Script | `dist/LicorneDEclipse.commandbar.luau` (142 Ko) |
| Rareté | Exclusif, dans le canyon et à la roue |
| Taille | Grand |
| Argent de base | 8M $/s |
| Bonus de vitesse (monture) | +200 % |
| Selle passager | oui |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Éclipse totale (onde d'énergie, 1,6 s) |
| Pièces | 2 352 |

Licorne noire avec un anneau de lumière autour de la corne (tapis + roue).

- Robe noire lustrée aux reflets violets, ventre d'encre, fanons dorés aux sabots.
- Longue crinière et queue en mèches noir -> violet nuit aux pointes d'or.
- Corne torsadée noir et or, entourée d'un anneau de lumière (couronne d'éclipse) qui tourne.
- Disque d'éclipse derrière la tête : soleil noir et couronne de rayons dorés.
- Harnais noir et or, selle de velours (monture avec passager).
- Étoiles d'or en orbite ; effets : poussière d'or, halo de l'anneau, traînée de lumière.

### Sphinx stellaire

*Gardien des énigmes au visage de pharaon ; ses ailes sont un morceau de ciel nocturne rempli d'étoiles.*

| | |
| --- | --- |
| Script | `dist/SphinxStellaire.commandbar.luau` (144 Ko) |
| Rareté | Exclusif, seulement à la roue |
| Taille | Géant |
| Argent de base | 11M $/s |
| Bonus de vitesse (monture) | +220 % |
| Selle passager | oui |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Énigme stellaire (onde d'énergie, 1,6 s) |
| Pièces | 2 833 |

Sphinx dont les ailes sont remplies d'étoiles (roue uniquement). coiffe némès rayée lapis/or, cobra dressé sur le front. bords dorés.

- Corps de lion au pelage de sable doré, pattes cerclées de bracelets d'or et de lapis.
- Tête de pharaon : visage serein, yeux soulignés de khôl lumineux turquoise, barbe d'or,
- Grandes ailes : panneaux de ciel nocturne remplis d'étoiles Neon reliées en constellations,
- Selle d'apparat (monture avec passager).
- Petites pyramides d'or et étoiles en orbite ; effets : poussière d'étoiles, lueur bleue et or.

## Chaotique (10)

Les 10 variétés du Néant Couronné ont chacune leur style. Toutes gardent son identité : une couronne qui flotte au-dessus de la tête, une orbite de cristaux violets, des fragments d'énergie rouges en orbite, une aura rouge sang et un cercle de runes au sol. Quand un Chaotique apparaît, l'une des 10 est tirée au hasard.

### Néant Couronné · Roi Spectral

*Style gothique spectral — argent et cyan fantôme : roi-spectre en robe de lambeaux, visage d'ombre, couronne d'argent qui flotte.*

| | |
| --- | --- |
| Script | `dist/NeantCouronneRoiSpectral.commandbar.luau` (197 Ko) |
| Rareté | Chaotique, dans le canyon |
| Style | gothique spectral |
| Taille | Colossal |
| Argent de base | 100M $/s |
| Bonus de vitesse (monture) | +400 % |
| Selle passager | oui |
| Démarche | lévitation (flotte) |
| Capacité spéciale | Lamentation spectrale (onde d'énergie, 2 s) |
| Pièces | 1 797 |

### Néant Couronné · Œil du Néant

*Style cosmique — bleu nuit galactique et or : œil géant cuirassé, iris d'or, tentacules étoilés.*

| | |
| --- | --- |
| Script | `dist/NeantCouronneOeil.commandbar.luau` (197 Ko) |
| Rareté | Chaotique, dans le canyon |
| Style | cosmique |
| Taille | Colossal |
| Argent de base | 100M $/s |
| Bonus de vitesse (monture) | +400 % |
| Selle passager | oui |
| Démarche | lévitation (flotte) |
| Capacité spéciale | Regard du néant (souffle, 2 s) |
| Pièces | 2 181 |

### Néant Couronné · Dragon

*Style nébuleuse — turquoise et magenta : dragon serpentin aux ailes de verre rose, ventre magenta.*

| | |
| --- | --- |
| Script | `dist/NeantCouronneDragon.commandbar.luau` (197 Ko) |
| Rareté | Chaotique, dans le canyon |
| Style | nébuleuse |
| Taille | Colossal |
| Argent de base | 100M $/s |
| Bonus de vitesse (monture) | +400 % |
| Selle passager | oui |
| Démarche | lévitation (flotte) |
| Capacité spéciale | Souffle nébuleux (souffle, 2 s) |
| Pièces | 1 839 |

### Néant Couronné · Colosse

*Style obsidienne et lave — titan de roche noire fendu de lave orange, poings flottants.*

| | |
| --- | --- |
| Script | `dist/NeantCouronneColosse.commandbar.luau` (197 Ko) |
| Rareté | Chaotique, dans le canyon |
| Style | obsidienne et lave |
| Taille | Colossal |
| Argent de base | 100M $/s |
| Bonus de vitesse (monture) | +400 % |
| Selle passager | oui |
| Démarche | lévitation (flotte) |
| Capacité spéciale | Colère du colosse (onde de choc au sol, 2 s) |
| Pièces | 1 098 |

### Néant Couronné · Seigneur Cornu

*Style royal noir et or — roi démon en armure noire, cornes de bélier, cape et sceptre de cristal violet.*

| | |
| --- | --- |
| Script | `dist/NeantCouronneSeigneurCornu.commandbar.luau` (197 Ko) |
| Rareté | Chaotique, dans le canyon |
| Style | royal noir et or |
| Taille | Colossal |
| Argent de base | 100M $/s |
| Bonus de vitesse (monture) | +400 % |
| Selle passager | oui |
| Démarche | lévitation (flotte) |
| Capacité spéciale | Décret royal (explosion, 2 s) |
| Pièces | 1 590 |

### Néant Couronné · Méduse Abyssale

*Style bioluminescent — cloche de verre cyan, cœur rose, tentacules lumineux.*

| | |
| --- | --- |
| Script | `dist/NeantCouronneMeduse.commandbar.luau` (197 Ko) |
| Rareté | Chaotique, dans le canyon |
| Style | bioluminescent |
| Taille | Colossal |
| Argent de base | 100M $/s |
| Bonus de vitesse (monture) | +400 % |
| Selle passager | oui |
| Démarche | lévitation (flotte) |
| Capacité spéciale | Pulsation abyssale (onde d'énergie, 2 s) |
| Pièces | 1 783 |

### Néant Couronné · Bête du Néant

*Style flammes spectrales — loup noir à la crinière de flammes bleues, crocs et griffes glacés.*

| | |
| --- | --- |
| Script | `dist/NeantCouronneBete.commandbar.luau` (197 Ko) |
| Rareté | Chaotique, dans le canyon |
| Style | flammes spectrales |
| Taille | Colossal |
| Argent de base | 100M $/s |
| Bonus de vitesse (monture) | +400 % |
| Selle passager | oui |
| Démarche | quadrupède (4 pattes, genoux) |
| Capacité spéciale | Hurlement spectral (onde d'énergie, 2 s) |
| Pièces | 2 719 |

### Néant Couronné · Masque

*Style théâtre — masque de porcelaine blanche fissuré de rouge, capuche de néant noir, mains flottantes.*

| | |
| --- | --- |
| Script | `dist/NeantCouronneMasque.commandbar.luau` (197 Ko) |
| Rareté | Chaotique, dans le canyon |
| Style | théâtre |
| Taille | Colossal |
| Argent de base | 100M $/s |
| Bonus de vitesse (monture) | +400 % |
| Selle passager | oui |
| Démarche | lévitation (flotte) |
| Capacité spéciale | Rire du néant (onde d'énergie, 2 s) |
| Pièces | 1 328 |

### Néant Couronné · Astre Noir

*Style éclipse solaire — soleil noir furieux, couronne d'épines d'or, éruptions et anneau de cristaux.*

| | |
| --- | --- |
| Script | `dist/NeantCouronneAstreNoir.commandbar.luau` (197 Ko) |
| Rareté | Chaotique, dans le canyon |
| Style | éclipse solaire |
| Taille | Colossal |
| Argent de base | 100M $/s |
| Bonus de vitesse (monture) | +400 % |
| Selle passager | oui |
| Démarche | lévitation (flotte) |
| Capacité spéciale | Éclipse totale (éruption, 2 s) |
| Pièces | 900 |

### Néant Couronné · Archange Déchu

*Style céleste déchu — ivoire et or, quatre ailes blanches qui noircissent, halo-couronne brisé.*

| | |
| --- | --- |
| Script | `dist/NeantCouronneArchange.commandbar.luau` (197 Ko) |
| Rareté | Chaotique, dans le canyon |
| Style | céleste déchu |
| Taille | Colossal |
| Argent de base | 100M $/s |
| Bonus de vitesse (monture) | +400 % |
| Selle passager | oui |
| Démarche | lévitation (flotte) |
| Capacité spéciale | Chute céleste (onde d'énergie, 2 s) |
| Pièces | 2 309 |
