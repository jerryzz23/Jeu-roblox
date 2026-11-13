--!strict
--[[
	CreatureForge.Weapons — les battes
	=================================
	Frapper un joueur fait tomber ce qu'il porte (créatures, ADN, seringue), que tout le monde
	peut alors ramasser. La batte en bois est l'arme de départ ; les autres se débloquent.

	    local tool = CreatureForge.Weapons.buildTool("BatteBois")   -- Tool prêt à donner au joueur
	    tool.Parent = player.Backpack
	    CreatureForge.Weapons.get("BatteCloutee").Range             -- portée du coup (studs)

	Chaque batte est construite le long de +Z (pommeau en -Z, tête de frappe en +Z), la poignée
	("Handle") est au niveau de la main. Les statistiques sont des valeurs de départ à ajuster ;
	le serveur doit vérifier la distance et le délai entre deux coups (anti-triche).
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

export type WeaponDef = {
	Id: string,
	DisplayName: string,
	Tier: number,
	Price: number, -- 0 = arme de départ
	Range: number, -- portée du coup (studs)
	Cooldown: number, -- délai entre deux coups (secondes)
	Knockback: number, -- force de recul
	Description: string,
	build: (opts: Kit.BuildOptions?) -> Model,
}

type Look = {
	wood: Kit.Style, -- corps de la batte
	barrel: Kit.Style, -- tête de frappe
	grip: Kit.Style, -- ruban de la poignée
	knob: Kit.Style, -- pommeau
	band: Kit.Style, -- bandes décoratives
	glow: Kit.Style?, -- veines ou runes lumineuses
}

--- Profil de batte commun : pommeau, poignée enrubannée, col conique, tête de frappe arrondie.
local function bat(rig: Kit.Rig, look: Look)
	local g = "Root"
	rig:cylinder(g, "Knob", v3(0, 0, -1.02), v3(0, 0, -0.9), 0.46, look.knob)
	rig:cylinder(g, "Handle", v3(0, 0, -0.92), v3(0, 0, 0.7), 0.24, look.wood)
	-- Ruban de la poignée : spires légèrement décalées
	for k = 0, 7 do
		local z = -0.82 + k * 0.18
		rig:cylinder(g, "GripTape", v3(0, 0, z), v3(0, 0, z + 0.13), 0.27, look.grip)
	end
	-- Col qui s'évase jusqu'à la tête de frappe
	local d0, d1 = 0.24, 0.56
	for k = 0, 5 do
		local t0, t1 = k / 6, (k + 1) / 6
		local z0, z1 = 0.7 + t0 * 1.1, 0.7 + t1 * 1.1
		rig:cylinder(g, "Taper", v3(0, 0, z0), v3(0, 0, z1 + 0.01), d0 + (d1 - d0) * ((t0 + t1) / 2), look.wood)
	end
	rig:cylinder(g, "Barrel", v3(0, 0, 1.8), v3(0, 0, 3.15), d1, look.barrel)
	rig:ball(g, "BarrelEnd", v3(0, 0, 3.15), d1, look.barrel)
	for _, z in { 1.95, 2.25 } do
		rig:cylinder(g, "Band", v3(0, 0, z), v3(0, 0, z + 0.07), d1 + 0.03, look.band)
	end
	-- Marque
	rig:block(g, "Logo", cf(0, d1 / 2 + 0.005, 2.65), v3(0.18, 0.02, 0.5), look.band)
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

local DEFS: { WeaponDef } = {}

local function define(def: WeaponDef)
	table.insert(DEFS, def)
end

define({
	Id = "BatteBois",
	DisplayName = "Batte en bois",
	Tier = 1,
	Price = 0,
	Range = 6,
	Cooldown = 1.2,
	Knockback = 30,
	Description = "La batte de départ : frêne verni, ruban noir, pommeau rouge.",
	build = function(opts)
		local rig = newRig("BatteBois", opts)
		bat(rig, {
			wood = S(rgb(214, 160, 100), M.Wood),
			barrel = S(rgb(200, 146, 88), M.Wood),
			grip = S(rgb(30, 30, 34), M.Fabric),
			knob = S(rgb(200, 40, 40)),
			band = S(rgb(200, 40, 40)),
		})
		return rig:finish({ WeaponId = "BatteBois" })
	end,
})

define({
	Id = "BatteAlu",
	DisplayName = "Batte en aluminium",
	Tier = 2,
	Price = 50000,
	Range = 6.5,
	Cooldown = 1.0,
	Knockback = 38,
	Description = "Aluminium brossé à bandes bleues et rouges, poignée caoutchouc : plus légère, plus rapide.",
	build = function(opts)
		local rig = newRig("BatteAlu", opts)
		bat(rig, {
			wood = S(rgb(190, 198, 212), M.Metal, { reflectance = 0.15 }),
			barrel = S(rgb(214, 222, 236), M.Metal, { reflectance = 0.2 }),
			grip = S(rgb(40, 60, 140), M.Fabric),
			knob = S(rgb(40, 60, 140)),
			band = S(rgb(220, 40, 50)),
		})
		rig:cylinder("Root", "Band", v3(0, 0, 2.5), v3(0, 0, 2.6), 0.59, S(rgb(40, 60, 140)))
		return rig:finish({ WeaponId = "BatteAlu" })
	end,
})

define({
	Id = "BatteCloutee",
	DisplayName = "Batte cloutée",
	Tier = 3,
	Price = 5000000,
	Range = 7,
	Cooldown = 1.1,
	Knockback = 46,
	Description = "Bois sombre hérissé de clous d'acier et cerclé de fil barbelé.",
	build = function(opts)
		local rig = newRig("BatteCloutee", opts)
		bat(rig, {
			wood = S(rgb(120, 82, 52), M.Wood),
			barrel = S(rgb(104, 70, 44), M.Wood),
			grip = S(rgb(140, 30, 30), M.Fabric),
			knob = S(rgb(60, 60, 66), M.Metal),
			band = S(rgb(150, 156, 166), M.Metal),
		})
		-- Clous en spirale autour de la tête de frappe
		for k = 0, 17 do
			local a = k * 2.4
			local z = 1.9 + (k % 6) * 0.22
			local dir = v3(math.cos(a), math.sin(a), 0)
			rig:thorn("Root", "Nail", A.alongUp(v3(0, 0, z) + dir * 0.26, dir), 0.06, 0.24, S(rgb(196, 200, 208), M.Metal))
		end
		-- Barbelé
		for k = 0, 23 do
			local a0, a1 = k / 24 * math.pi * 2, (k + 1) / 24 * math.pi * 2
			local z0, z1 = 2.1 + k * 0.035, 2.1 + (k + 1) * 0.035
			rig:strut("Root", "Wire", v3(math.cos(a0) * 0.3, math.sin(a0) * 0.3, z0), v3(math.cos(a1) * 0.3, math.sin(a1) * 0.3, z1), 0.03, 0.03, S(rgb(130, 134, 142), M.Metal))
		end
		return rig:finish({ WeaponId = "BatteCloutee" })
	end,
})

define({
	Id = "BatteDoree",
	DisplayName = "Batte dorée",
	Tier = 4,
	Price = 500000000,
	Range = 7.5,
	Cooldown = 0.9,
	Knockback = 55,
	Description = "Or massif poli, poignée de velours pourpre, rubis au pommeau et éclats de lumière.",
	build = function(opts)
		local rig = newRig("BatteDoree", opts)
		local gold = S(rgb(255, 204, 64), M.Metal, { reflectance = 0.2 })
		bat(rig, {
			wood = gold,
			barrel = S(rgb(255, 214, 90), M.Metal, { reflectance = 0.25 }),
			grip = S(rgb(110, 20, 120), M.Fabric),
			knob = gold,
			band = S(rgb(255, 245, 200), M.Neon),
		})
		rig:shard("Root", "Ruby", cf(0, 0, -1.08) * ang(-math.pi / 2, 0, 0), 0.16, 0.18, 0.16, S(rgb(255, 40, 70), M.Neon))
		for k = 0, 3 do
			local a = k * math.pi / 2
			rig:shard("Root", "Gem", cf(math.cos(a) * 0.29, math.sin(a) * 0.29, 2.4) * ang(0, 0, a - math.pi / 2), 0.1, 0.12, 0.08, S(rgb(80, 220, 255), M.Neon))
		end
		if rig.effects then
			local fx = rig:anchor("Root", "FX_Shine", cf(0, 0, 2.4), v3(0.6, 0.6, 1.4))
			Fx.particles(fx, Fx.sparkles("GoldShine", { rgb(255, 250, 210), rgb(255, 200, 70) }, 6, 0.12), rig.scale)
		end
		return rig:finish({ WeaponId = "BatteDoree" })
	end,
})

define({
	Id = "BatteNeant",
	DisplayName = "Batte du Néant",
	Tier = 5,
	Price = 50000000000,
	Range = 8,
	Cooldown = 0.8,
	Knockback = 65,
	Description = "Obsidienne fendue de veines violettes, couronne miniature qui flotte au bout, poussière d'étoiles.",
	build = function(opts)
		local rig = newRig("BatteNeant", opts)
		local glow = S(rgb(190, 100, 255), M.Neon)
		bat(rig, {
			wood = S(rgb(26, 20, 36)),
			barrel = S(rgb(20, 14, 30)),
			grip = S(rgb(60, 30, 100), M.Fabric),
			knob = S(rgb(255, 204, 64), M.Metal),
			band = glow,
		})
		-- Veines lumineuses le long de la tête de frappe
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			local p0 = v3(math.cos(a) * 0.285, math.sin(a) * 0.285, 1.9)
			local p1 = v3(math.cos(a + 0.4) * 0.285, math.sin(a + 0.4) * 0.285, 2.6)
			local p2 = v3(math.cos(a + 0.1) * 0.285, math.sin(a + 0.1) * 0.285, 3.1)
			rig:strut("Root", "Vein", p0, p1, 0.04, 0.04, glow)
			rig:strut("Root", "Vein", p1, p2, 0.04, 0.04, glow)
		end
		-- Couronne miniature qui flotte au bout (os Float1)
		local at = cf(0, 0, 3.75)
		rig:bone("Float1", "Root", at)
		local gold = S(rgb(255, 204, 64), M.Metal)
		rig:ring("Float1", "Crown", at, 0.24, 0.05, 0.08, 12, gold)
		for k = 0, 4 do
			rig:thorn("Float1", "CrownSpike", at * ang(0, 0, k / 5 * math.pi * 2) * cf(0, 0.24, 0) * ang(-math.pi / 2, 0, 0), 0.07, 0.2, gold)
		end
		if rig.effects then
			local fx = rig:anchor("Root", "FX_Void", cf(0, 0, 2.5), v3(0.7, 0.7, 1.6))
			Fx.particles(fx, Fx.sparkles("VoidStars", { rgb(255, 255, 255), rgb(190, 110, 255) }, 10, 0.12), rig.scale)
			Fx.light(fx, { color = rgb(170, 90, 255), range = 6, brightness = 1.4 }, rig.scale)
		end
		return rig:finish({ WeaponId = "BatteNeant" })
	end,
})

local Weapons = {}
Weapons.List = DEFS

local byId: { [string]: WeaponDef } = {}
for _, d in DEFS do
	byId[d.Id] = d
end

function Weapons.get(id: string): WeaponDef
	local d = byId[id]
	assert(d, `Weapons: arme inconnue "{id}"`)
	return d
end

--- Outil (Tool) prêt à mettre dans le sac d'un joueur : la poignée "Handle" est l'ancienne
--- racine, toutes les pièces y restent soudées.
function Weapons.buildTool(id: string): Tool
	local def = Weapons.get(id)
	local model = def.build({ animated = false, outline = false })
	local tool = Instance.new("Tool")
	tool.Name = def.DisplayName
	tool.CanBeDropped = false
	tool.ToolTip = def.Description
	-- Tenue façon épée : la batte part vers l'avant depuis la main
	tool.Grip = CFrame.new(0, 0, -0.3, 0, 0, 1, 1, 0, 0, 0, 1, 0)
	local root = model.PrimaryPart :: BasePart
	root.Name = "Handle"
	root.Anchored = false
	root.Size = Vector3.new(0.3, 0.3, 1.6)
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	for k, v in model:GetAttributes() do
		tool:SetAttribute(k, v)
	end
	tool:SetAttribute("Range", def.Range)
	tool:SetAttribute("Cooldown", def.Cooldown)
	tool:SetAttribute("Knockback", def.Knockback)
	model:Destroy()
	return tool
end

return Weapons
