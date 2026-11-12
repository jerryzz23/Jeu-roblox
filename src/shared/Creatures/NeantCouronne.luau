--!strict
--[[
	LE NÉANT COURONNÉ — Chaotique · Colossal · 10 variétés
	======================================================
	Créature faite de vide et d'étoiles, couronne qui flotte au-dessus de sa tête.
	LE plus rare de tous : 1 chance sur 1 000 000 tout au bout du tapis. Quand un Chaotique
	apparaît, l'une des 10 variétés est tirée au hasard (chacune : 1 sur 10 000 000).

	Ce module enregistre les 10 variétés comme 10 personnages distincts (une fiche chacun
	dans l'Index). Les modèles sont construits par Concepts/NeantCouronneVariantes.
	  1 Roi Spectral (gothique spectral)     6 Méduse Abyssale (bioluminescent)
	  2 Œil du Néant (cosmique)              7 Bête du Néant (flammes spectrales)
	  3 Dragon (nébuleuse)                   8 Masque (théâtre)
	  4 Colosse (obsidienne et lave)         9 Astre Noir (éclipse solaire)
	  5 Seigneur Cornu (royal noir et or)   10 Archange Déchu (céleste déchu)
]]

local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)
local Variantes = require(script.Parent.Parent.Concepts.NeantCouronneVariantes)

-- Identifiant, nom affiché et échelle en jeu (taille Colossale) de chaque variété
local VARIETES = {
	{ id = "NeantCouronneRoiSpectral", name = "Roi Spectral", scale = 2.9 },
	{ id = "NeantCouronneOeil", name = "Œil du Néant", scale = 3.4 },
	{ id = "NeantCouronneDragon", name = "Dragon", scale = 3.3 },
	{ id = "NeantCouronneColosse", name = "Colosse", scale = 3.0 },
	{ id = "NeantCouronneSeigneurCornu", name = "Seigneur Cornu", scale = 3.2 },
	{ id = "NeantCouronneMeduse", name = "Méduse Abyssale", scale = 3.4 },
	{ id = "NeantCouronneBete", name = "Bête du Néant", scale = 3.2 },
	{ id = "NeantCouronneMasque", name = "Masque", scale = 3.0 },
	{ id = "NeantCouronneAstreNoir", name = "Astre Noir", scale = 3.4 },
	{ id = "NeantCouronneArchange", name = "Archange Déchu", scale = 2.8 },
}

local defs: { Types.CreatureDef } = {}

for i, v in VARIETES do
	local V: Types.CreatureDef = Variantes[i]
	local id = v.id

	local function build(opts: Kit.BuildOptions?): Model
		local o: Kit.BuildOptions = if opts then table.clone(opts) else {}
		local parent = o.parent
		o.parent = nil
		Variantes.setRarityAura("Chaotic")
		local model = V.build(o)
		Variantes.setRarityAura(nil)
		model.Name = id
		model:SetAttribute("CreatureId", id)
		model:SetAttribute("Rarity", "Chaotic")
		model:SetAttribute("Variety", i)
		model.Parent = parent
		return model
	end

	table.insert(defs, {
		Id = id,
		DisplayName = "Néant Couronné · " .. v.name,
		Rarity = "Chaotic",
		Size = "Colossal",
		Income = 100000000,
		SpeedBonus = 4.0,
		Passenger = true,
		Scale = v.scale,
		Order = i,
		Category = `Créature Chaotique · variété {i}/10`,
		Description = V.Description,
		Icon = V.Icon,
		Animation = V.Animation,
		Ability = V.Ability,
		build = build,
	})
end

return defs
