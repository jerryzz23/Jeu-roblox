--!strict
--[[
	CreatureForge.Types
	-------------------
	Contrat commun à toutes les créatures (src/shared/Creatures/*.luau).
]]

local Kit = require(script.Parent.Kit)

--- Paramètres de l'animation procédurale (voir CreatureAnimator).
export type AnimProfile = {
	-- Quadruped : pattes sous le corps (trot) ; Sprawler : pattes écartées + ondulation (reptiles)
	gait: "Quadruped" | "Sprawler" | "Biped" | "Flyer" | "Serpent" | "Hover",
	breathe: number?, -- amplitude de respiration (studs)
	sway: number?, -- ondulation latérale du corps en marche (degrés, Sprawler)
	tongueFlick: boolean?, -- coups de langue (os "Tongue") avec ouverture de mâchoire (os "Jaw")
	bob: number?, -- rebond du corps en marche (studs)
	stride: number?, -- amplitude des pattes (degrés)
	strideRate: number?, -- cadence des pattes (rad/s)
	tailSway: number?, -- balancement de queue (degrés)
	tailRate: number?, -- vitesse du balancement (rad/s)
	headLook: number?, -- regard gauche/droite au repos (degrés)
	sniff: boolean?, -- petits reniflements rapides
	earTwitch: boolean?, -- frémissement des oreilles
	flap: number?, -- amplitude des battements d'ailes (degrés, Flyer)
	flapRate: number?, -- vitesse des battements (rad/s)
	hover: number?, -- amplitude du flottement (studs, Flyer / Hover)
	auraSpeed: number?, -- vitesse de rotation des objets en orbite (rad/s)
	flicker: number?, -- vacillement des lumières (0 = fixe, 0.3 = feu)
}

--- Capacité spéciale jouée par Vfx.playAbility (état d'animation "Ability").
export type Ability = {
	name: string, -- nom affiché (ex. "Souffle ardent")
	kind: "Nova" | "Breath" | "Stomp" | "Burst" | "Eruption",
	colors: { Color3 }, -- couleur principale, secondaire, (tertiaire)
	texture: string?, -- "sparkle" | "fire" | "smoke" | "spark" (voir Fx.TEXTURES)
	bone: string?, -- os d'origine (souffle) — défaut : Head
	origin: Vector3?, -- point d'origine en espace modèle (avant échelle)
	direction: Vector3?, -- direction du souffle (espace modèle)
	radius: number?, -- rayon de l'onde de choc (studs, avant échelle)
	duration: number?, -- durée (secondes)
}

--- Taille (voir Rarity.Sizes) : plus une créature est grosse, plus elle rapporte.
export type Size = "Small" | "Medium" | "Large" | "Giant" | "Colossal"

--- Où la créature s'obtient : sur le tapis, sur le tapis ET dans la roue, ou seulement dans la roue.
export type Source = "Tapis" | "TapisEtRoue" | "Roue"

--- Habillage de l'icône d'inventaire.
export type IconTheme = {
	top: Color3, -- haut du dégradé de fond
	bottom: Color3, -- bas du dégradé de fond
	glow: Color3, -- halo derrière la créature
	motif: Color3?, -- couleur des motifs décoratifs (losanges)
	yaw: number?, -- angle caméra horizontal (degrés, 0 = face)
	pitch: number?, -- angle caméra vertical (degrés)
	zoom: number?, -- > 1 = plus proche
}

export type CreatureDef = {
	Id: string,
	DisplayName: string,
	Rarity: string, -- "Common" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Exotic" | "Exclusive" | "Chaotic"
	Size: Size,
	Income: number, -- argent de base par seconde ($/s) dans l'enclos
	SpeedBonus: number, -- bonus de vitesse en monture (0.05 = +5 %)
	Passenger: boolean, -- peut porter un passager (selle passager)
	Source: Source?, -- défaut : "Tapis"
	Scale: number?, -- échelle par défaut à l'apparition (taille en jeu)
	Order: number?, -- ordre d'affichage dans une même rareté (sinon : par nom)
	Category: string,
	Description: string,
	Icon: IconTheme,
	Animation: AnimProfile,
	Ability: Ability?,
	build: (opts: Kit.BuildOptions?) -> Model,
}

return {}
