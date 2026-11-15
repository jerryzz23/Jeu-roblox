--!strict
--[[
	LE TITAN DE CRISTAL — Exotique · Colossal
	=========================================
	Golem géant fait de cristaux violets.

	• Corps de roche sombre en dalles, d'où jaillissent d'énormes grappes de cristaux violets
	  (verre teinté + cœurs Neon) sur les épaules, le dos, les avant-bras et la tête.
	• Cœur de cristal incandescent dans la poitrine, fissures Neon violettes entre les dalles.
	• Bras massifs aux poings hérissés de cristaux, jambes-colonnes, pieds de roche.
	• Tête basse aux yeux Neon, couronne de cristaux ; plateforme sur les épaules (passager).
	• Éclats de cristal en orbite ; effets : poussière scintillante, forte lueur violette.
]]

local Kit = require(script.Parent.Parent.Kit)
local A = require(script.Parent.Parent.Anatomy)
local Fx = require(script.Parent.Parent.Fx)
local Vfx = require(script.Parent.Parent.Vfx)
local Types = require(script.Parent.Parent.Types)

local S = Kit.style
local M = Enum.Material
local rgb = Color3.fromRGB
local rad = math.rad
local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles

local ID = "TitanDeCristal"

local P = {
	core = S(rgb(190, 90, 255), M.Neon),
	rock = { S(rgb(92, 86, 110), M.Slate), S(rgb(72, 66, 90), M.Slate), S(rgb(54, 50, 70), M.Slate), S(rgb(38, 34, 52), M.Slate) },
	crystals = {
		S(rgb(200, 120, 255), M.Glass, { transparency = 0.15 }),
		S(rgb(150, 70, 240), M.Glass, { transparency = 0.15 }),
		S(rgb(220, 160, 255), M.Neon),
		S(rgb(120, 50, 210), M.Glass, { transparency = 0.1 }),
	},
	glow = S(rgb(200, 110, 255), M.Neon),
	glowHot = S(rgb(245, 210, 255), M.Neon),
	eye = S(rgb(230, 170, 255), M.Neon),
	socket = S(rgb(20, 10, 30)),
	platform = S(rgb(60, 54, 76), M.Slate),
}

local TORSO = Kit.spine({
	{ pos = v3(0, 5.15, 0.05), rx = 0.9, ry = 0.6 },
	{ pos = v3(0, 4.6, 0), rx = 1.25, ry = 0.82 },
	{ pos = v3(0, 3.9, 0.02), rx = 1.05, ry = 0.75 },
	{ pos = v3(0, 3.2, 0.05), rx = 0.8, ry = 0.62 },
	{ pos = v3(0, 2.7, 0.05), rx = 0.82, ry = 0.6 },
})

local ABILITY: Types.Ability = {
	name = "Séisme de cristal",
	kind = "Stomp",
	colors = { rgb(200, 110, 255), rgb(80, 20, 160), rgb(255, 230, 255) },
	texture = "spark",
	radius = 10,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 3.4, 0))
	rig:bone("Head", "Body", cf(0, 5.2, -0.2))
	rig:mirrored(function(side, sfx)
		rig:bone("Arm" .. sfx, "Body", cf(side * 1.3, 4.65, 0))
		rig:bone("Leg" .. sfx, "Body", cf(side * 0.55, 2.7, 0.05))
	end)

	-- Torse de dalles de roche, cœur de cristal Neon entre les plaques
	rig:tube(TORSO, {
		name = "Torso",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.45,
		cover = { A.scales(P.rock, v3(0.62, 0.22, 0.56), 0.52, { arc = 180, tilt = 6, jitter = 0.5, refRadius = 0.9, seed = 1 }) },
	})
	rig:ball("Body", "HeartCrystal", v3(0, 4.25, -0.78), 0.62, P.glowHot)
	A.crystals(rig, "Body", cf(0, 4.25, -0.7) * ang(rad(-90), 0, 0), 6, 0.6, P.crystals, 2, 0.5)
	rig:ring("Body", "HeartRim", cf(0, 4.25, -0.8), 0.42, 0.1, 0.12, 14, P.rock[4])
	-- Grappes de cristaux : épaules et dos
	rig:mirrored(function(side)
		A.crystals(rig, "Body", cf(A.mx(v3(1.05, 5.0, 0.05), side)) * ang(0, 0, -side * rad(30)), 8, 1.5, P.crystals, 4 + side, 0.55)
		A.crystals(rig, "Body", cf(A.mx(v3(0.55, 4.7, 0.6), side)) * ang(rad(40), 0, -side * rad(15)), 6, 1.1, P.crystals, 8 + side, 0.5)
		for k, u in { 1.8, 2.6, 3.4 } do
			local a = TORSO:surface(u, side * 100, 0.1).Position
			local b = TORSO:surface(u + 0.4, side * 135, 0.1).Position
			rig:strut("Body", "Vein", a, b, 0.08, 0.05, P.glow)
		end
	end)
	A.crystals(rig, "Body", cf(0, 4.5, 0.75) * ang(rad(60), 0, 0), 7, 1.2, P.crystals, 12, 0.6)
	A.crystals(rig, "Body", cf(0, 3.4, 0.6) * ang(rad(70), 0, 0), 5, 0.8, P.crystals, 13, 0.6)
	-- Plateforme sur les épaules (passager)
	rig:prism("Body", "Platform", cf(0, 5.32, 0.25), v3(1.1, 0.16, 0.9), 0.1, P.platform)
	rig:seat("Body", cf(0, 5.5, 0.25), v3(0.8, 0.2, 0.8))

	-- Tête basse, couronne de cristaux
	rig:prism("Head", "Head", cf(0, 5.45, -0.35), v3(0.8, 0.62, 0.72), 0.2, P.rock[2])
	rig:prism("Head", "Jaw", cf(0, 5.15, -0.45) * ang(rad(8), 0, 0), v3(0.7, 0.24, 0.6), 0.1, P.rock[3])
	rig:block("Head", "Visor", cf(0, 5.5, -0.72), v3(0.62, 0.08, 0.05), P.glow)
	rig:mirrored(function(side)
		rig:ball("Head", "EyeGlow", A.mx(v3(0.2, 5.5, -0.74), side), 0.14, P.eye)
		A.brow(rig, "Head", side, v3(0.22, 5.66, -0.7), 0.3, 18, P.rock[4])
	end)
	A.crystals(rig, "Head", cf(0, 5.75, -0.3), 7, 0.75, P.crystals, 20, 0.35)

	-- Bras massifs, poings hérissés
	rig:mirrored(function(side, sfx)
		local arm = "Arm" .. sfx
		local sp = A.limb(rig, arm, side, { { v3(1.3, 4.65, 0), 0.5, 0.5 }, { v3(1.65, 3.7, -0.1), 0.42, 0.42 }, { v3(1.75, 2.75, -0.35), 0.38, 0.38 } }, P.core, A.scales(P.rock, v3(0.4, 0.15, 0.36), 0.32, { arc = 180, tilt = 6, jitter = 0.4, refRadius = 0.45, seed = 30 + side }))
		A.crystals(rig, arm, sp:surface(2.4, side * 90, 0.1) * ang(0, 0, -side * rad(10)), 5, 0.9, P.crystals, 40 + side, 0.4)
		local fist = A.mx(v3(1.8, 2.25, -0.45), side)
		rig:prism(arm, "Fist", cf(fist) * ang(0, side * rad(10), 0), v3(0.95, 0.9, 0.95), 0.25, P.rock[2])
		for k = -1, 1 do
			rig:shard(arm, "Knuckle", cf(fist + v3(side * k * 0.25, 0.12, -0.45)) * ang(rad(-80), 0, 0), 0.18, 0.4, 0.18, P.crystals[(k + 2) % 4 + 1])
		end
	end)

	-- Jambes-colonnes
	rig:mirrored(function(side, sfx)
		local leg = "Leg" .. sfx
		A.limb(rig, leg, side, { { v3(0.55, 2.7, 0.05), 0.55, 0.55 }, { v3(0.62, 1.5, 0), 0.48, 0.48 }, { v3(0.62, 0.45, 0), 0.5, 0.5 } }, P.core, A.scales(P.rock, v3(0.42, 0.16, 0.38), 0.34, { arc = 180, tilt = 6, jitter = 0.4, refRadius = 0.5, seed = 50 + side }))
		rig:prism(leg, "Foot", cf(A.mx(v3(0.62, 0.2, -0.15), side)), v3(1.0, 0.4, 1.3), 0.15, P.rock[3])
		A.crystals(rig, leg, cf(A.mx(v3(0.85, 1.6, 0.1), side)) * ang(0, 0, -side * rad(60)), 3, 0.6, P.crystals, 60 + side, 0.3)
	end)

	-- Éclats de cristal en orbite
	A.orbit(rig, "Aura1", v3(0, 3.6, 0), 3.4, 9, 0.7, function(bone, c, i)
		rig:shard(bone, "OrbitCrystal", c * ang(0, 0, rad(20)), 0.32, 0.9, 0.32, P.crystals[(i % 4) + 1])
	end)

	rig:hitbox(cf(0, 3.2, 0), v3(4, 6.4, 2.4))

	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Body", "FX_Crystal", cf(0, 4.2, 0), v3(3, 2.4, 1.8))
		Fx.particles(g, Fx.sparkles("CrystalDust", { rgb(240, 200, 255), rgb(170, 80, 255) }, 14, 0.26), sc)
		Fx.light(g, { color = rgb(190, 100, 255), range = 20, brightness = 2 }, sc)
		Vfx.orbitTethers(rig, "Aura1", Vfx.orbitPoints(v3(0, 3.6, 0), 3.4, 9, 0.7), "Body", v3(0, 4.25, -0.8), { colors = { rgb(230, 170, 255), rgb(120, 40, 220) }, transparency = { 0.3, 0.85 }, width0 = 0.08, width1 = 0.02, curve0 = 0.8 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Exotic")
	end

	return rig:finish({ Rarity = "Exotic" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Titan de cristal",
	Rarity = "Exotic",
	Size = "Colossal",
	Income = 1400000,
	SpeedBonus = 1.6,
	Passenger = true,
	Scale = 3.3,
	Category = "Créature Exotique",
	Description = "Golem colossal fait de roche et de cristaux violets ; son cœur de cristal bat dans sa poitrine.",
	Icon = { top = rgb(90, 40, 150), bottom = rgb(14, 6, 30), glow = rgb(220, 150, 255), motif = rgb(190, 100, 255), yaw = 26, pitch = 8, zoom = 1.0 },
	Animation = { gait = "Biped", breathe = 0.05, bob = 0.15, stride = 18, strideRate = 4, headLook = 10, auraSpeed = 0.35 },
	Ability = ABILITY,
	build = build,
}

return Def
