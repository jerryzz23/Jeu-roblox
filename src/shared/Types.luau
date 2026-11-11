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
}

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
	Rarity: string,
	Category: string,
	Description: string,
	Icon: IconTheme,
	Animation: AnimProfile,
	build: (opts: Kit.BuildOptions?) -> Model,
}

return {}
