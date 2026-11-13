# Mémoire du jeu

Ce fichier garde tout ce qui a été décidé avec le créateur du jeu, pour pouvoir continuer à
l'améliorer d'une conversation à l'autre. **À lire avant toute modification**, et à **mettre à
jour à la fin de chaque demande** (section « Journal » + « Ce qui est fait / à faire »).

## Le créateur du jeu

- Il écrit en **français**, en messages courts et familiers (avec des fautes de frappe) :
  répondre en français simple, sans jargon technique, et montrer des **images / rendus** dès
  qu'il s'agit de visuel.
- Il ne code pas : lui donner des choses **prêtes à ouvrir** (le fichier
  `dist/CreatureForge.rbxl` pour Roblox Studio, le bestiaire en ligne).
- Il envoie souvent des **images de référence** (captures d'autres jeux, illustrations, vidéos) :
  suivre la référence de près.
- Style voulu : **Roblox cartoon**, couleurs vives, modèles détaillés (pas de simples blocs),
  avec des **effets visuels** (VFX).
- Quand il propose un choix (ex. « fais-en 10 et je choisis »), il peut tout garder s'il aime tout.

## Le concept du jeu

Le joueur part de **sa base** (en haut) et **descend une pente de canyon**. Plus il descend loin,
plus les **personnages** qu'il croise sont **rares**. Avec une **seringue**, il récolte
l'**ADN** d'un personnage, puis il **remonte** jusqu'à sa base. Remonter la pente vide son
**endurance**. Dans sa base, il pose l'ADN dans sa **machine à ADN**, qui fabrique un personnage.
Les personnages de la base **rapportent de l'argent par seconde**. Avec cet argent, il achète de
meilleures seringues, de meilleurs **tapis de course** (pour aller plus vite) et de meilleures
**battes**, qui servent à faire tomber l'ADN des autres joueurs.

## Règles décidées

Ne pas revenir sur ces règles sans le lui demander.

1. **Le canyon est une pente**, pas un tapis roulant. Descendre est facile. **Remonter vide
   l'endurance** ; à 0 d'endurance, on est **très lent et vulnérable**.
2. **8 zones = 8 raretés**, de haut en bas :

   | Zone | Rareté | Couleur | Chance (au bout du canyon) |
   | --- | --- | --- | --- |
   | La Surface | Commun | gris | très fréquent |
   | Le Désert | Rare | bleu | fréquent |
   | La Pente Brumeuse | Épique | violet | moyen |
   | Le Glacier | Légendaire | or | peu fréquent |
   | Les Grottes de Cristal | Mythique | rouge | rare |
   | L'Abysse Profond | Exotique | arc-en-ciel | 1 sur 5 000 |
   | Le Ciel Étoilé | Exclusif | noir et or | 1 sur 50 000 (+ roue) |
   | Le Néant | Chaotique | glitch rose/cyan | 1 sur 1 000 000 |

3. **Seringues** : 8 niveaux, de la basique (ADN ×1) à celle du Néant (ADN ×20). ADN récolté =
   ADN de base de la rareté (Commun 1, Rare 3, Épique 10, Légendaire 30, Mythique 100,
   Exotique 400, Exclusif 1 500, Chaotique 10 000) × multiplicateur de la seringue.
4. **Boutique de seringues** : le stock **change toutes les 5 minutes**. Chaque seringue a une
   **chance d'être en stock**, en quantité limitée. Le stock est identique sur tous les serveurs.
5. **Se faire frapper** (batte) fait **tomber l'ADN / la seringue** qu'on porte, et **n'importe
   qui peut le ramasser**. On ne peut voler que **hors des bases** : la ligne « ZONE SÛRE »
   protège.
6. **Machine à ADN** : **une par joueur, à côté de sa base**. **Plus l'ADN est rare, plus on a de
   chances d'avoir un bon personnage**, et plus il y a d'ADN, plus on peut monter d'une ou deux
   raretés. Il y a une incubation (10 s pour un Commun, 5 min pour un Chaotique), puis le
   personnage s'installe sur une place de la base.
7. **Argent** : revenu par seconde = argent de base × (somme des multiplicateurs de mutation),
   ou × 1 sans mutation.
8. **11 mutations, cumulables** : Mousse ancienne ×1,3, Kintsugi ×1,5, Vitrail ×2,
   Horloger ×2,5, Mirage ×3, Encre ×3,5, Aurore ×4, Fossile vivant ×5, Constellation ×7,
   Écho ×10, Paradoxe ×15. La plus rare est 1 sur 100 000.
9. **Tapis de course** : ils sont **devant chaque base** (pas dans l'enclos). On court dessus pour
   gagner de la **vitesse**. Il y a 10 niveaux, avec des **prix volontairement durs** (×20
   environ par niveau, jusqu'à 600T), pour que ce ne soit pas trop facile.
10. **Battes** : 5 niveaux (bois, aluminium, cloutée, dorée, Néant).
11. **Montures** : chaque personnage est une monture (bonus de vitesse). Les grands ont une
    **selle passager** pour un deuxième joueur.
12. **Le Néant Couronné** : le créateur adore les **10 variantes**, donc **les 10 sont dans le
    jeu** (Chaotiques).
13. **Roue de la chance** : certains Exclusifs ne s'obtiennent **qu'à la roue**.
14. **Bases style Roblox** : 8 enclos aux clôtures colorées, 6 places à personnages, un panneau au
    nom du joueur et une maisonnette.
15. **Animations** : **tout le corps doit bouger** (pattes, genoux, coudes, ailes, queue), pas
    seulement la tête.
16. Également prévus dans son « Récap final du jeu », mais **sans détails enregistrés ici** :
    **pièges**, **achats Robux**, **progression**, **anti-triche**, **interface Roblox cartoon**.
    Lui demander de recoller son récap avant de les faire.

## Les 30 personnages

| Rareté | Personnages (taille, argent de base) |
| --- | --- |
| Commun | Renard des cendres (petit, 5 $/s), Loup d'acier (moyen, 9 $/s), Cerf des brumes (grand, 15 $/s) |
| Rare | Lynx de givre (50 $/s), Panthère d'orage (90 $/s), Ours de granit (140 $/s) |
| Épique | Faucon solaire (500 $/s), Tigre de jade (900 $/s), Mammouth runique (1 500 $/s) |
| Légendaire | Phénix d'argent (6K $/s), Griffon impérial (10K $/s), Rhinocéros d'obsidienne (14K $/s) |
| Mythique | Kirin céleste (50K $/s), Hydre d'émeraude (100K $/s), Léviathan des sables (150K $/s) |
| Exotique | Dragon d'aurore (900K $/s), Titan de cristal (1,4M $/s) |
| Exclusif | Licorne d'éclipse (8M $/s, canyon + roue), Sphinx stellaire (11M $/s, roue), Béhémoth abyssal (14M $/s, roue) |
| Chaotique | Néant Couronné × 10 variantes (100M $/s) : Roi Spectral, Œil du Néant, Dragon, Colosse, Seigneur Cornu, Méduse Abyssale, Bête du Néant, Masque, Astre Noir, Archange Déchu |

Les détails (bonus de vitesse, selle passager, démarche, capacité) sont dans le README et dans
`src/shared/Creatures/`.

## Ce qui est fait

- Les **30 personnages** en 3D : animés (démarches, genoux, coudes), avec VFX, icône UI, selles
  et mutations visibles.
- La **carte** : bases, stands (VENDRE, SERINGUES, TAPIS DE COURSE, GRATUIT !), roue, pente du
  canyon, 8 zones décorées avec une statue chacune, et le portail du Néant au bout.
- Les **10 tapis de course**, les **5 battes**, les **8 seringues**, la **machine à ADN** (une
  par base) et les **8 fragments d'ADN**.
- Les règles chiffrées dans le code : raretés selon la distance, mutations, prix, stock de la
  boutique (5 min), chances de la machine à ADN.
- Le serveur : attribution d'une base par joueur, tableau du stock de seringues, dépôt d'ADN dans
  la machine avec incubation (en Studio, 3 ADN de test sont donnés à chaque joueur).
- La **place complète** `dist/CreatureForge.rbxl` : tout est visible dès l'ouverture dans
  Studio, avec la Vitrine (personnages dans leur zone, tapis et présentoirs).
- Le **bestiaire web** (artefact privé) : https://claude.ai/artifact/6wLxEoofvni4XYqjNBFNaM

## À faire (le gameplay n'est pas encore codé)

- **Endurance** : la barre se vide en remontant ; à 0, le joueur est lent et vulnérable.
- **Récolte d'ADN** avec la seringue sur les personnages du canyon (apparitions selon la
  profondeur : `CreatureForge.rollSpawn`).
- **Coup de batte** : portée, délai, recul ; l'ADN ou la seringue tombe au sol et peut être
  ramassé ; pas de vol dans la zone sûre.
- **Argent** gagné par les personnages de la base, et **VENDRE**.
- **Achats** : seringues (stock de la boutique), tapis, battes.
- **Tapis de course** : gain de vitesse quand on court dessus (vérifié par le serveur).
- **Montures** et selle passager, **roue de la chance**, **pièges**, **Robux**, **sauvegarde**
  (DataStore), **interface** (HUD argent, endurance, inventaire), **anti-triche**.

## Journal des demandes

Dans l'ordre, les plus récentes en bas.

1. Modèles 3D détaillés de créatures pour Roblox Studio. Retour : « de meilleures textures,
   couleurs et détails, comme dans l'exemple » → refaits.
2. « Rajoute des VFX » → aura de rareté, rayons, traînées, capacités spéciales.
3. 10 modèles du Néant Couronné dans des styles différents → il a tout gardé (« plus belles les
   unes que les autres »).
4. « Récap final du jeu » → 21 personnages, 8 raretés, 11 mutations, économie.
5. Vidéo de tapis de course → 10 tapis pour gagner de la vitesse.
6. Mutations cumulables, prix des tapis augmentés, carte faite d'après son image du canyon.
7. Correction : « Il n'y a pas de tapis qui descend le canyon, c'est juste une pente ». Endurance
   à la remontée ; l'ADN ou la seringue tombe quand on est frappé.
8. Seringues de différents niveaux et boutique (chances, réinitialisée toutes les 5 min), battes
   en 3D, toutes les animations refaites (« à part bouger la tête ils font rien »), plus de
   zones, bases plus « Roblox » (3 captures de référence).
9. Tapis devant les bases ; une machine à ADN à côté de chaque base (une par joueur) ; plus l'ADN
   est rare, meilleurs sont les personnages.
10. « Mets-moi tout sur Roblox Studio » → place complète `dist/CreatureForge.rbxl`, envoyée en
    fichier.
11. « Contrôle mon PC » → pas possible depuis une session cloud. Il faut l'application Claude
    sur son PC avec Computer use activé.
12. « Je veux que tu te souviennes de cette discussion » → création de ce fichier et de
    `CLAUDE.md`.
13. « Fais-moi un récap détaillé du jeu » → donné dans la conversation (concept, carte, 30
    personnages, mutations, seringues, machine à ADN, tapis, battes, fait / à faire).
14. « Va sur mon PC et mets le jeu sur Roblox Studio » (2e fois) → toujours impossible depuis
    cette session cloud : aucun accès à son ordinateur. Il doit ouvrir une conversation depuis
    l'application Claude de son PC (Computer use activé), ou ouvrir lui-même le fichier `.rbxl`.
