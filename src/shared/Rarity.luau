--!strict
--[[
	CreatureForge.Rarity
	--------------------
	Paliers de rareté : libellé, couleurs (UI) et ordre de tri.
]]

export type Tier = {
	id: string,
	label: string,
	order: number,
	color: Color3, -- couleur principale (contour, pastille)
	light: Color3, -- reflet clair du dégradé
	dark: Color3, -- ombre du dégradé
}

local function tier(id: string, label: string, order: number, color: Color3, light: Color3, dark: Color3): Tier
	return { id = id, label = label, order = order, color = color, light = light, dark = dark }
end

local Rarity = {}

Rarity.Tiers = {
	Common = tier("Common", "COMMUN", 1, Color3.fromRGB(176, 184, 196), Color3.fromRGB(236, 240, 246), Color3.fromRGB(104, 110, 122)),
	Uncommon = tier("Uncommon", "INHABITUEL", 2, Color3.fromRGB(98, 210, 112), Color3.fromRGB(196, 255, 170), Color3.fromRGB(32, 120, 60)),
	Rare = tier("Rare", "RARE", 3, Color3.fromRGB(64, 152, 255), Color3.fromRGB(170, 222, 255), Color3.fromRGB(26, 70, 170)),
	Epic = tier("Epic", "ÉPIQUE", 4, Color3.fromRGB(172, 92, 255), Color3.fromRGB(232, 180, 255), Color3.fromRGB(84, 30, 160)),
	Legendary = tier("Legendary", "LÉGENDAIRE", 5, Color3.fromRGB(255, 186, 52), Color3.fromRGB(255, 240, 160), Color3.fromRGB(196, 96, 10)),
	Mythic = tier("Mythic", "MYTHIQUE", 6, Color3.fromRGB(255, 64, 108), Color3.fromRGB(255, 186, 214), Color3.fromRGB(140, 10, 60)),
}

function Rarity.get(id: string): Tier
	return Rarity.Tiers[id] or Rarity.Tiers.Common
end

return Rarity
