--!strict
--[[
	CreatureForge.Spawning
	----------------------
	Tirage des apparitions dans le canyon (logique pure, à exécuter côté SERVEUR).

	- La pente va de 0 (en haut, près des bases) à 1 (tout au bout) : Map.distanceOf(position).
	- Raretés normales (Commun -> Mythique) : tirage pondéré parmi celles dont la bande
	  contient la distance ; plus on descend, plus les raretés hautes dominent.
	- Raretés ultimes, uniquement dans l'Abysse : Chaotique 1/1 000 000, Exclusif 1/50 000,
	  Exotique 1/5 000 (tirées en premier, de la plus rare à la moins rare).
	- `luck` (boost « Chance x2 ») multiplie les chances de tout ce qui n'est pas Commun.
]]

local Rarity = require(script.Parent.Rarity)

local Spawning = {}

local ULTIMATE = { "Chaotic", "Exclusive", "Exotic" }

local function inBand(tier: Rarity.Tier, d: number): boolean
	return d >= tier.band[1] and d <= tier.band[2]
end

--- Poids d'une rareté normale à la distance d : courbe en cloche autour de `peak`.
local function weightAt(tier: Rarity.Tier, d: number, luck: number): number
	if not tier.weight or not inBand(tier, d) then
		return 0
	end
	local k = (d - (tier.peak or d)) / 0.2
	return tier.weight * math.exp(-k * k) * (if tier.id == "Common" then 1 else luck)
end

--- Probabilités de chaque rareté à la distance `d` (pour l'affichage des chances).
function Spawning.odds(d: number, luck: number?): { { rarity: string, chance: number } }
	local l = luck or 1
	local out = {}
	local rest = 1
	for _, id in ULTIMATE do
		local tier = Rarity.Tiers[id]
		if inBand(tier, d) and tier.odds then
			local p = math.min(1, l / tier.odds) * rest
			table.insert(out, { rarity = id, chance = p })
			rest -= p
		end
	end
	local total = 0
	for _, id in Rarity.Order do
		total += weightAt(Rarity.Tiers[id], d, l)
	end
	for _, id in Rarity.Order do
		local w = weightAt(Rarity.Tiers[id], d, l)
		if w > 0 and total > 0 then
			table.insert(out, { rarity = id, chance = rest * w / total })
		end
	end
	table.sort(out, function(a, b)
		return Rarity.Tiers[a.rarity].order < Rarity.Tiers[b.rarity].order
	end)
	return out
end

--- Tire une rareté à la distance `d` (0..1).
function Spawning.rollRarity(d: number, rng: Random, luck: number?): string
	local dist = math.clamp(d, 0, 1)
	local l = luck or 1
	for _, id in ULTIMATE do
		local tier = Rarity.Tiers[id]
		if inBand(tier, dist) and tier.odds and rng:NextNumber() < l / tier.odds then
			return id
		end
	end
	local total = 0
	for _, id in Rarity.Order do
		total += weightAt(Rarity.Tiers[id], dist, l)
	end
	local r = rng:NextNumber() * total
	for _, id in Rarity.Order do
		local w = weightAt(Rarity.Tiers[id], dist, l)
		if w > 0 then
			r -= w
			if r <= 0 then
				return id
			end
		end
	end
	return "Common"
end

--- Formate un revenu comme dans le jeu : 950, 1,5K, 14M, 2,3B, 1T...
function Spawning.formatMoney(n: number): string
	local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, u in units do
		if n >= u[1] then
			local v = n / u[1]
			local s = if v >= 100 then string.format("%d", math.floor(v)) else string.gsub(string.format("%.1f", v), "%.0$", "")
			return (string.gsub(s, "%.", ",")) .. u[2]
		end
	end
	return string.format("%d", math.floor(n))
end

return Spawning
