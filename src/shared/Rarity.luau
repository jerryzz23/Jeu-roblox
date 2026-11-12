--!strict
--[[
	CreatureForge.Rarity
	--------------------
	Les 8 raretés du jeu, du plus courant au plus rare : couleurs (UI, aura), position sur le
	tapis roulant et chance d'apparition.

	Le tapis va de 0 (bases, début du tapis) à 1 (tout au bout). Une rareté « normale »
	apparaît à partir de band[1], surtout autour de `peak` (poids `weight`, courbe en cloche) ;
	les raretés ultimes (Exotique, Exclusif, Chaotique) sont tirées à part, en bout de tapis,
	avec une chance de 1 sur `odds`.
	Les valeurs sont un point de départ à ajuster pendant les tests (voir Spawning).
]]

export type Tier = {
	id: string,
	label: string,
	order: number,
	color: Color3, -- couleur principale (contour, pastille)
	light: Color3, -- reflet clair du dégradé
	dark: Color3, -- ombre du dégradé
	where: string, -- où elle apparaît (texte affiché)
	band: { number }, -- { début, fin } sur le tapis (0 = début, 1 = tout au bout)
	peak: number?, -- distance où la rareté est la plus fréquente (raretés normales)
	weight: number?, -- poids du tirage au pic (raretés normales)
	odds: number?, -- 1 chance sur `odds` (raretés ultimes, en bout de tapis)
	rainbow: boolean?, -- couleur arc-en-ciel animée (Exotique)
	glitch: boolean?, -- couleurs qui changent / glitch (Chaotique)
	gold: Color3?, -- seconde couleur (Exclusif : noir et or)
}

local rgb = Color3.fromRGB

local Rarity = {}

Rarity.Order = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Exotic", "Exclusive", "Chaotic" }

Rarity.Tiers = {
	Common = {
		id = "Common", label = "COMMUN", order = 1, where = "Début du tapis",
		color = rgb(170, 176, 188), light = rgb(236, 240, 246), dark = rgb(96, 102, 114),
		band = { 0, 1 }, peak = 0.05, weight = 1,
	},
	Rare = {
		id = "Rare", label = "RARE", order = 2, where = "Un peu plus loin",
		color = rgb(54, 140, 255), light = rgb(170, 216, 255), dark = rgb(20, 60, 170),
		band = { 0.15, 1 }, peak = 0.3, weight = 0.8,
	},
	Epic = {
		id = "Epic", label = "ÉPIQUE", order = 3, where = "Milieu du tapis",
		color = rgb(168, 80, 255), light = rgb(230, 180, 255), dark = rgb(80, 26, 160),
		band = { 0.35, 1 }, peak = 0.5, weight = 0.6,
	},
	Legendary = {
		id = "Legendary", label = "LÉGENDAIRE", order = 4, where = "Loin",
		color = rgb(255, 190, 40), light = rgb(255, 240, 160), dark = rgb(196, 100, 10),
		band = { 0.55, 1 }, peak = 0.7, weight = 0.45,
	},
	Mythic = {
		id = "Mythic", label = "MYTHIQUE", order = 5, where = "Très loin",
		color = rgb(255, 40, 60), light = rgb(255, 170, 180), dark = rgb(140, 0, 20),
		band = { 0.75, 1 }, peak = 0.92, weight = 0.3,
	},
	Exotic = {
		id = "Exotic", label = "EXOTIQUE", order = 6, where = "Tout au bout",
		color = rgb(255, 120, 200), light = rgb(255, 255, 200), dark = rgb(80, 60, 200),
		band = { 0.9, 1 }, odds = 5000, rainbow = true,
	},
	Exclusive = {
		id = "Exclusive", label = "EXCLUSIF", order = 7, where = "Tout au bout + roue",
		color = rgb(255, 200, 60), light = rgb(255, 236, 150), dark = rgb(10, 8, 12), gold = rgb(255, 200, 60),
		band = { 0.9, 1 }, odds = 50000,
	},
	Chaotic = {
		id = "Chaotic", label = "CHAOTIQUE", order = 8, where = "Tout au bout",
		color = rgb(255, 0, 90), light = rgb(0, 255, 230), dark = rgb(20, 0, 40),
		band = { 0.9, 1 }, odds = 1000000, glitch = true,
	},
} :: { [string]: Tier }

--- Couleurs arc-en-ciel (Exotique) et glitch (Chaotique) pour l'UI et les auras.
Rarity.RAINBOW = { rgb(255, 70, 70), rgb(255, 170, 40), rgb(255, 240, 70), rgb(70, 230, 110), rgb(60, 170, 255), rgb(170, 90, 255) }
Rarity.GLITCH = { rgb(255, 0, 90), rgb(0, 255, 230), rgb(255, 255, 255), rgb(120, 0, 255), rgb(0, 0, 0), rgb(255, 230, 0) }

function Rarity.get(id: string): Tier
	return Rarity.Tiers[id] or Rarity.Tiers.Common
end

--- Couleur affichée à l'instant `t` (secondes) : animée pour Exotique (arc-en-ciel) et
--- Chaotique (glitch : saute d'une couleur à l'autre).
function Rarity.colorAt(id: string, t: number): Color3
	local tier = Rarity.get(id)
	if tier.rainbow then
		return Color3.fromHSV((t * 0.25) % 1, 0.75, 1)
	elseif tier.glitch then
		local list = Rarity.GLITCH
		local k = math.floor(t * 12)
		if (k * 7919) % 5 == 0 then
			return list[(k % #list) + 1]
		end
		return list[(math.floor(t * 3) % 2) + 1]
	end
	return tier.color
end

--- Tailles de créature (plus c'est gros, plus ça rapporte). `span` = plus grande dimension
--- visée en jeu (studs) ; chaque créature règle son `Scale` pour s'en approcher.
Rarity.Sizes = {
	Small = { id = "Small", label = "Petit", order = 1, span = 6 },
	Medium = { id = "Medium", label = "Moyen", order = 2, span = 8.5 },
	Large = { id = "Large", label = "Grand", order = 3, span = 11 },
	Giant = { id = "Giant", label = "Géant", order = 4, span = 15 },
	Colossal = { id = "Colossal", label = "Colossal", order = 5, span = 21 },
}

return Rarity
