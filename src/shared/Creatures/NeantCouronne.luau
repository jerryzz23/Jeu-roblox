--!strict
--[[
	LE NÉANT COURONNÉ — Chaotique · Colossal
	========================================
	Créature faite de vide et d'étoiles, couronne qui flotte au-dessus de sa tête.
	LE plus rare de tous (1 chance sur 1 000 000, tout au bout du tapis).

	Le modèle est l'une des 10 variantes de Concepts/NeantCouronneVariantes :
	changez CHOIX (1 à 10) pour utiliser une autre variante.
	  1 Gothique spectral · 2 Cosmique · 3 Nébuleuse · 4 Obsidienne et lave · 5 Royal noir et or
	  6 Bioluminescent · 7 Flammes spectrales · 8 Théâtre · 9 Éclipse solaire · 10 Céleste déchu
]]

local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)
local Variantes = require(script.Parent.Parent.Concepts.NeantCouronneVariantes)

local ID = "NeantCouronne"
local CHOIX = 1

local V: Types.CreatureDef = Variantes[CHOIX]

local function build(opts: Kit.BuildOptions?): Model
	local o: Kit.BuildOptions = if opts then table.clone(opts) else {}
	local parent = o.parent
	o.parent = nil
	Variantes.setRarityAura("Chaotic")
	local model = V.build(o)
	Variantes.setRarityAura(nil)
	model.Name = ID
	model:SetAttribute("CreatureId", ID)
	model:SetAttribute("Rarity", "Chaotic")
	model.Parent = parent
	return model
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Le Néant Couronné",
	Rarity = "Chaotic",
	Size = "Colossal",
	Income = 100000000,
	SpeedBonus = 4.0,
	Passenger = true,
	Scale = 3.0,
	Category = "Créature Chaotique",
	Description = "Créature faite de vide et d'étoiles ; sa couronne flotte au-dessus de sa tête. La plus rare de toutes.",
	Icon = V.Icon,
	Animation = V.Animation,
	Ability = V.Ability,
	build = build,
}

return Def
