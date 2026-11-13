--!strict
--[[
	CreatureForge.Syringes — seringues à ADN et leur boutique
	========================================================
	On prélève l'ADN des créatures avec une seringue : plus la seringue est bonne, plus elle
	récolte d'ADN. Si on se fait frapper en portant l'ADN (ou la seringue), il tombe par terre et
	n'importe qui peut le ramasser.

	ADN récolté = ADN de base de la rareté x multiplicateur de la seringue
	    Syringes.dnaFor("SeringueDoree", "Legendary")   --> 30 x 2 = 60

	La boutique se réinitialise toutes les 5 minutes : chaque seringue a une chance d'être en
	stock, en quantité limitée. Le tirage dépend uniquement du créneau de 5 minutes, donc tous
	les serveurs (et l'affichage côté client) ont le même stock au même moment.
	    Syringes.stockAt(os.time())          --> { { id, price, quantity }, ... }
	    Syringes.timeUntilRestock(os.time()) --> secondes avant le prochain réassort

	    local tool = Syringes.buildTool("SeringueCristal")   -- Tool à donner au joueur
]]

local Kit = require(script.Parent.Kit)
local A = require(script.Parent.Anatomy)
local Fx = require(script.Parent.Fx)

local S = Kit.style
local M = Enum.Material
local rgb = Color3.fromRGB
local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles

export type SyringeDef = {
	Id: string,
	DisplayName: string,
	Tier: number,
	Multiplier: number, -- multiplicateur d'ADN récolté
	Price: number, -- prix en boutique
	Chance: number, -- probabilité d'être en stock à chaque réassort (0..1)
	Stock: { number }, -- quantité en stock { min, max }
	Description: string,
	Color: Color3,
	build: (opts: Kit.BuildOptions?) -> Model,
}

type Look = {
	barrel: Kit.Style, -- corps en verre
	liquid: Kit.Style, -- ADN liquide
	helix: Kit.Style, -- double hélice d'ADN
	metal: Kit.Style, -- piston, embout, aiguille
	trim: Kit.Style, -- anneaux, collerette
	thumb: Kit.Style, -- appui-pouce
}

--- Seringue commune (le long de +Z, aiguille en +Z) : appui-pouce, piston, collerette,
--- corps en verre gradué, ADN liquide avec sa double hélice, embout et aiguille.
local function syringe(rig: Kit.Rig, look: Look)
	local g = "Root"
	rig:cylinder(g, "Thumb", v3(0, 0, -1.5), v3(0, 0, -1.42), 0.62, look.thumb)
	rig:cylinder(g, "Plunger", v3(0, 0, -1.44), v3(0, 0, -0.55), 0.14, look.metal)
	rig:prism(g, "Flange", cf(0, 0, -0.62), v3(0.95, 0.22, 0.07), 0.05, look.trim)
	rig:cylinder(g, "Barrel", v3(0, 0, -0.6), v3(0, 0, 0.82), 0.46, look.barrel)
	rig:cylinder(g, "Liquid", v3(0, 0, -0.32), v3(0, 0, 0.8), 0.36, look.liquid)
	rig:cylinder(g, "Stopper", v3(0, 0, -0.45), v3(0, 0, -0.32), 0.4, S(rgb(30, 30, 36)))
	-- Graduations
	for k = 0, 5 do
		local z = -0.25 + k * 0.2
		rig:block(g, "Tick", cf(0, 0.235, z), v3(if k % 2 == 0 then 0.14 else 0.08, 0.01, 0.02), look.trim)
	end
	-- Double hélice d'ADN dans le liquide
	for k = 0, 13 do
		local z = -0.25 + k * 0.075
		local a = k * 0.75
		local p1 = v3(math.cos(a) * 0.11, math.sin(a) * 0.11, z)
		local p2 = v3(-math.cos(a) * 0.11, -math.sin(a) * 0.11, z)
		rig:ball(g, "Helix", p1, 0.06, look.helix)
		rig:ball(g, "Helix", p2, 0.06, look.helix)
		if k % 2 == 0 then
			rig:strut(g, "HelixRung", p1, p2, 0.02, 0.02, look.helix)
		end
	end
	rig:cylinder(g, "Hub", v3(0, 0, 0.8), v3(0, 0, 0.98), 0.24, look.trim)
	rig:cylinder(g, "HubTip", v3(0, 0, 0.98), v3(0, 0, 1.06), 0.12, look.metal)
	rig:cylinder(g, "Needle", v3(0, 0, 1.04), v3(0, 0, 1.75), 0.045, S(rgb(220, 226, 236), M.Metal))
	rig:ring(g, "BarrelRing", cf(0, 0, -0.55), 0.24, 0.03, 0.05, 12, look.trim)
	rig:ring(g, "BarrelRing", cf(0, 0, 0.78), 0.24, 0.03, 0.05, 12, look.trim)
end

local function newRig(id: string, opts: Kit.BuildOptions?): Kit.Rig
	local o: Kit.BuildOptions = if opts then table.clone(opts) else {}
	if o.animated == nil then
		o.animated = false
	end
	if o.outline == nil then
		o.outline = false
	end
	return Kit.newRig(id, o)
end

local function glass(c: Color3, t: number?): Kit.Style
	return S(c, M.Glass, { transparency = t or 0.45 })
end

local DEFS: { SyringeDef } = {}
local function define(def: SyringeDef)
	table.insert(DEFS, def)
end

define({
	Id = "SeringueBasique", DisplayName = "Seringue basique", Tier = 1, Multiplier = 1,
	Price = 500, Chance = 1, Stock = { 5, 10 }, Color = rgb(120, 230, 120),
	Description = "Plastique transparent, ADN vert : la seringue de départ.",
	build = function(opts)
		local rig = newRig("SeringueBasique", opts)
		syringe(rig, { barrel = glass(rgb(230, 240, 236)), liquid = S(rgb(90, 220, 110), M.Glass, { transparency = 0.25 }), helix = S(rgb(200, 255, 200), M.Neon), metal = S(rgb(200, 204, 212), M.Metal), trim = S(rgb(240, 242, 246)), thumb = S(rgb(230, 234, 240)) })
		return rig:finish({ SyringeId = "SeringueBasique" })
	end,
})

define({
	Id = "SeringueRenforcee", DisplayName = "Seringue renforcée", Tier = 2, Multiplier = 1.5,
	Price = 25000, Chance = 0.7, Stock = { 3, 6 }, Color = rgb(80, 170, 255),
	Description = "Corps cerclé d'acier, ADN bleu.",
	build = function(opts)
		local rig = newRig("SeringueRenforcee", opts)
		local steel = S(rgb(150, 160, 176), M.Metal, { reflectance = 0.1 })
		syringe(rig, { barrel = glass(rgb(200, 226, 250)), liquid = S(rgb(60, 140, 255), M.Glass, { transparency = 0.25 }), helix = S(rgb(170, 220, 255), M.Neon), metal = steel, trim = steel, thumb = S(rgb(60, 66, 80), M.Metal) })
		for _, z in { -0.2, 0.25, 0.6 } do
			rig:ring("Root", "SteelBand", cf(0, 0, z), 0.25, 0.04, 0.06, 12, steel)
		end
		return rig:finish({ SyringeId = "SeringueRenforcee" })
	end,
})

define({
	Id = "SeringueDoree", DisplayName = "Seringue dorée", Tier = 3, Multiplier = 2,
	Price = 500000, Chance = 0.45, Stock = { 2, 4 }, Color = rgb(255, 200, 60),
	Description = "Or poli et ADN ambré, appui-pouce gravé.",
	build = function(opts)
		local rig = newRig("SeringueDoree", opts)
		local gold = S(rgb(255, 204, 64), M.Metal, { reflectance = 0.15 })
		syringe(rig, { barrel = glass(rgb(255, 240, 200)), liquid = S(rgb(255, 170, 30), M.Glass, { transparency = 0.2 }), helix = S(rgb(255, 240, 170), M.Neon), metal = gold, trim = gold, thumb = gold })
		A.rune(rig, "Root", cf(0, 0, -1.53) * ang(0, math.pi, 0), 0.32, S(rgb(255, 245, 200), M.Neon), 3)
		return rig:finish({ SyringeId = "SeringueDoree" })
	end,
})

define({
	Id = "SeringueCristal", DisplayName = "Seringue de cristal", Tier = 4, Multiplier = 3,
	Price = 10000000, Chance = 0.25, Stock = { 1, 3 }, Color = rgb(190, 110, 255),
	Description = "Cristal violet taillé, ADN améthyste, éclats de cristal sur la collerette.",
	build = function(opts)
		local rig = newRig("SeringueCristal", opts)
		local crystals = { S(rgb(190, 110, 255), M.Neon), S(rgb(130, 60, 220), M.Glass, { transparency = 0.2 }), S(rgb(230, 190, 255), M.Neon) }
		syringe(rig, { barrel = glass(rgb(220, 190, 255), 0.35), liquid = S(rgb(170, 80, 255), M.Glass, { transparency = 0.2 }), helix = S(rgb(240, 210, 255), M.Neon), metal = S(rgb(200, 190, 220), M.Metal), trim = S(rgb(130, 60, 220), M.Glass, { transparency = 0.15 }), thumb = S(rgb(150, 80, 230), M.Glass, { transparency = 0.1 }) })
		for _, s in { 1, -1 } do
			A.crystals(rig, "Root", cf(s * 0.45, 0, -0.62) * ang(0, 0, -s * math.pi / 2), 3, 0.3, crystals, 5 + s, 0.25)
		end
		return rig:finish({ SyringeId = "SeringueCristal" })
	end,
})

define({
	Id = "SeringueLave", DisplayName = "Seringue de lave", Tier = 5, Multiplier = 5,
	Price = 250000000, Chance = 0.12, Stock = { 1, 2 }, Color = rgb(255, 110, 30),
	Description = "Obsidienne et lave en fusion : l'ADN bouillonne, des braises s'échappent.",
	build = function(opts)
		local rig = newRig("SeringueLave", opts)
		local obsidian = S(rgb(34, 26, 30))
		syringe(rig, { barrel = glass(rgb(255, 160, 100), 0.4), liquid = S(rgb(255, 100, 20), M.Neon), helix = S(rgb(255, 240, 160), M.Neon), metal = obsidian, trim = S(rgb(255, 110, 30), M.Neon), thumb = obsidian })
		for k = 0, 3 do
			local a = k * math.pi / 2
			A.flame(rig, "Root", cf(math.cos(a) * 0.28, math.sin(a) * 0.28, -0.62) * ang(-math.pi / 2, 0, 0), 0.25, 0.09, S(rgb(255, 80, 20), M.Neon), S(rgb(255, 170, 40), M.Neon), S(rgb(255, 245, 180), M.Neon))
		end
		if rig.effects then
			local fx = rig:anchor("Root", "FX_Embers", cf(0, 0, 0.2), v3(0.4, 0.4, 1.2))
			Fx.particles(fx, Fx.embers("Embers", { rgb(255, 220, 120), rgb(255, 80, 20) }, 6, 0.06), rig.scale)
		end
		return rig:finish({ SyringeId = "SeringueLave" })
	end,
})

define({
	Id = "SeringueCosmique", DisplayName = "Seringue cosmique", Tier = 6, Multiplier = 8,
	Price = 5000000000, Chance = 0.05, Stock = { 1, 1 }, Color = rgb(90, 140, 255),
	Description = "Une nébuleuse en bouteille : ADN bleu nuit constellé d'étoiles, anneau planétaire.",
	build = function(opts)
		local rig = newRig("SeringueCosmique", opts)
		local night = S(rgb(24, 30, 80))
		syringe(rig, { barrel = glass(rgb(120, 140, 255), 0.4), liquid = S(rgb(30, 40, 140), M.Glass, { transparency = 0.15 }), helix = S(rgb(255, 255, 255), M.Neon), metal = S(rgb(170, 180, 220), M.Metal), trim = S(rgb(120, 170, 255), M.Neon), thumb = night })
		local rng = Random.new(6)
		for _ = 1, 10 do
			rig:ball("Root", "Star", v3(rng:NextNumber(-0.13, 0.13), rng:NextNumber(-0.13, 0.13), rng:NextNumber(-0.25, 0.75)), 0.035, S(rgb(255, 250, 220), M.Neon))
		end
		rig:ring("Root", "PlanetRing", cf(0, 0, 0.25) * ang(0.5, 0.3, 0), 0.42, 0.03, 0.02, 20, S(rgb(200, 170, 255), M.Neon, { transparency = 0.2 }))
		return rig:finish({ SyringeId = "SeringueCosmique" })
	end,
})

define({
	Id = "SeringuePrisme", DisplayName = "Seringue prisme", Tier = 7, Multiplier = 12,
	Price = 100000000000, Chance = 0.02, Stock = { 1, 1 }, Color = rgb(255, 120, 200),
	Description = "Verre prismatique : l'ADN se décompose en bandes arc-en-ciel.",
	build = function(opts)
		local rig = newRig("SeringuePrisme", opts)
		syringe(rig, { barrel = glass(rgb(255, 255, 255), 0.5), liquid = S(rgb(255, 255, 255), M.Glass, { transparency = 0.6 }), helix = S(rgb(255, 255, 255), M.Neon), metal = S(rgb(230, 236, 246), M.Metal), trim = S(rgb(255, 255, 255), M.Neon), thumb = S(rgb(255, 255, 255)) })
		local rainbow = { rgb(255, 70, 70), rgb(255, 170, 40), rgb(255, 240, 70), rgb(70, 230, 110), rgb(60, 170, 255), rgb(170, 90, 255) }
		for k, c in rainbow do
			local z0 = -0.3 + (k - 1) * 0.18
			rig:cylinder("Root", "RainbowBand", v3(0, 0, z0), v3(0, 0, z0 + 0.18), 0.34, S(c, M.Neon))
		end
		return rig:finish({ SyringeId = "SeringuePrisme" })
	end,
})

define({
	Id = "SeringueNeant", DisplayName = "Seringue du Néant", Tier = 8, Multiplier = 20,
	Price = 2500000000000, Chance = 0.005, Stock = { 1, 1 }, Color = rgb(255, 60, 160),
	Description = "Corps noir et or, ADN du vide constellé d'étoiles, couronne qui flotte au-dessus du piston.",
	build = function(opts)
		local rig = newRig("SeringueNeant", opts)
		local gold = S(rgb(255, 204, 64), M.Metal, { reflectance = 0.1 })
		syringe(rig, { barrel = glass(rgb(60, 20, 90), 0.3), liquid = S(rgb(14, 6, 28), M.Neon), helix = S(rgb(255, 80, 200), M.Neon), metal = gold, trim = gold, thumb = S(rgb(16, 12, 22)) })
		-- Couronne qui flotte au-dessus du piston (os Float1)
		local at = cf(0, 0.55, -1.2)
		rig:bone("Float1", "Root", at)
		rig:ring("Float1", "Crown", at * ang(math.pi / 2, 0, 0), 0.18, 0.04, 0.07, 12, gold)
		for k = 0, 4 do
			rig:thorn("Float1", "CrownSpike", at * ang(0, k / 5 * math.pi * 2, 0) * cf(0, 0.03, -0.18), 0.06, 0.16, gold)
		end
		if rig.effects then
			local fx = rig:anchor("Root", "FX_Void", cf(0, 0, 0.2), v3(0.5, 0.5, 1.4))
			Fx.particles(fx, Fx.sparkles("Glitch", { rgb(255, 0, 140), rgb(0, 255, 230), rgb(255, 255, 255) }, 8, 0.08), rig.scale)
		end
		return rig:finish({ SyringeId = "SeringueNeant" })
	end,
})

local Syringes = {}
Syringes.List = DEFS

--- ADN de base récolté sur une créature selon sa rareté (avant le multiplicateur de la seringue).
Syringes.BASE_DNA = {
	Common = 1, Rare = 3, Epic = 10, Legendary = 30, Mythic = 100, Exotic = 400, Exclusive = 1500, Chaotic = 10000,
} :: { [string]: number }

Syringes.RESTOCK = 300 -- la boutique se réinitialise toutes les 5 minutes

local byId: { [string]: SyringeDef } = {}
for _, d in DEFS do
	byId[d.Id] = d
end

function Syringes.get(id: string): SyringeDef
	local d = byId[id]
	assert(d, `Syringes: seringue inconnue "{id}"`)
	return d
end

--- ADN récolté avec la seringue `id` sur une créature de rareté `rarity`.
function Syringes.dnaFor(id: string, rarity: string): number
	return (Syringes.BASE_DNA[rarity] or 1) * Syringes.get(id).Multiplier
end

--- Stock de la boutique pendant le créneau de 5 minutes qui contient `time` (os.time()).
--- Même résultat sur tous les serveurs : le tirage ne dépend que du numéro de créneau.
--- `luck` (ex. boost « Chance x2 ») multiplie les chances d'apparition.
function Syringes.stockAt(time: number?, luck: number?): { { id: string, price: number, quantity: number } }
	local slot = math.floor((time or os.time()) / Syringes.RESTOCK)
	local rng = Random.new(slot * 7919 + 17)
	local out = {}
	for _, d in DEFS do
		local roll = rng:NextNumber()
		local qty = rng:NextInteger(d.Stock[1], d.Stock[2])
		if roll < math.min(1, d.Chance * (luck or 1)) then
			table.insert(out, { id = d.Id, price = d.Price, quantity = qty })
		end
	end
	return out
end

--- Secondes avant le prochain réassort.
function Syringes.timeUntilRestock(time: number?): number
	local t = time or os.time()
	return Syringes.RESTOCK - (t % Syringes.RESTOCK)
end

--- Outil (Tool) prêt à mettre dans le sac d'un joueur.
function Syringes.buildTool(id: string): Tool
	local def = Syringes.get(id)
	local model = def.build({ animated = false, outline = false })
	local tool = Instance.new("Tool")
	tool.Name = def.DisplayName
	tool.CanBeDropped = false
	tool.ToolTip = `{def.Description} (ADN x{def.Multiplier})`
	tool.Grip = CFrame.new(0, 0, 0.1, 0, 0, 1, 1, 0, 0, 0, 1, 0)
	local root = model.PrimaryPart :: BasePart
	root.Name = "Handle"
	root.Anchored = false
	root.Size = Vector3.new(0.4, 0.4, 1.2)
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	for k, v in model:GetAttributes() do
		tool:SetAttribute(k, v)
	end
	tool:SetAttribute("Multiplier", def.Multiplier)
	model:Destroy()
	return tool
end

return Syringes
