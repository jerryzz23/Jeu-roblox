--!strict
--[[
	LA TORTUE DE MAGMA — Inhabituel · La Surface
	============================================
	Tortue massive à la carapace de roche volcanique fendue de coulées de lave lumineuses.

	• Carapace bombée en dalles de basalte (Slate) posées sur un cœur de lave Neon :
	  la lave rougeoie dans chaque fissure entre les dalles.
	• Trois cheminées volcaniques sur la carapace (fumée + braises), bordure de plastron.
	• Peau rouge-brun écailleuse, bec sombre, yeux Neon orange, pattes d'éléphant griffues.
	• 3 roches de lave en orbite ; effets : fumée, braises, lueur.
	Os : Root > Body > Head / Leg_FR / Leg_FL / Leg_BR / Leg_BL / Tail1   (démarche "Sprawler")
]]

local Kit = require(script.Parent.Parent.Kit)
local A = require(script.Parent.Parent.Anatomy)
local Fx = require(script.Parent.Parent.Fx)
local Types = require(script.Parent.Parent.Types)

local S = Kit.style
local M = Enum.Material
local rgb = Color3.fromRGB
local rad = math.rad
local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles

local ID = "TortueDeMagma"

local P = {
	lava = S(rgb(255, 106, 24), M.Neon),
	lavaHot = S(rgb(255, 214, 80), M.Neon),
	basalt = { S(rgb(92, 80, 80), M.Slate), S(rgb(72, 62, 64), M.Slate), S(rgb(56, 48, 50), M.Slate), S(rgb(42, 36, 38), M.Slate) },
	plastron = { S(rgb(176, 120, 76)), S(rgb(140, 92, 60)) },
	skin = S(rgb(120, 56, 42)),
	skinScales = { S(rgb(176, 84, 56)), S(rgb(144, 66, 46)), S(rgb(108, 50, 38)) },
	beak = S(rgb(40, 30, 30)),
	eye = S(rgb(255, 150, 40), M.Neon),
	socket = S(rgb(30, 10, 8)),
	claw = S(rgb(36, 30, 30)),
	pad = S(rgb(80, 40, 32)),
}

local SHELL = Kit.spine({
	{ pos = v3(0, 0.78, -1.3), rx = 0.3, ry = 0.14 },
	{ pos = v3(0, 0.95, -1.05), rx = 0.8, ry = 0.46 },
	{ pos = v3(0, 1.15, -0.5), rx = 1.1, ry = 0.72 },
	{ pos = v3(0, 1.25, 0.1), rx = 1.2, ry = 0.82 },
	{ pos = v3(0, 1.15, 0.7), rx = 1.1, ry = 0.72 },
	{ pos = v3(0, 0.95, 1.2), rx = 0.8, ry = 0.46 },
	{ pos = v3(0, 0.78, 1.45), rx = 0.3, ry = 0.14 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 0.8, -2.05), rx = 0.15, ry = 0.13 },
	{ pos = v3(0, 0.84, -1.85), rx = 0.27, ry = 0.23 },
	{ pos = v3(0, 0.86, -1.6), rx = 0.31, ry = 0.27 },
	{ pos = v3(0, 0.82, -1.3), rx = 0.27, ry = 0.25 },
	{ pos = v3(0, 0.82, -0.95), rx = 0.3, ry = 0.28 },
})

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 1.0, 0))
	rig:bone("Head", "Body", cf(0, 0.82, -1.0))
	rig:bone("Tail1", "Body", cf(0, 0.7, 1.2))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.75, 0.62, -0.6))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.75, 0.62, 0.65))
	end)

	-- Carapace : cœur de lave + dalles de basalte (la lave luit dans les fissures)
	rig:tube(SHELL, {
		name = "Shell",
		bone = const("Body"),
		core = P.lava,
		coreStep = 0.35,
		cover = {
			A.scales(P.basalt, v3(0.42, 0.16, 0.36), 0.38, { arc = 122, tilt = 4, jitter = 0.45, refRadius = 0.8, seed = 1 }),
			A.scales(P.plastron, v3(0.44, 0.08, 0.4), 0.38, { arc = 60, center = 180, tilt = 2, refRadius = 0.8, jitter = 0.2, seed = 2 }),
		},
	})

	-- Cheminées volcaniques
	for i, spot in { { 3.6, -30 }, { 4.3, 25 }, { 4.9, -10 } } do
		local base = SHELL:surface(spot[1], spot[2], 0.1)
		rig:thorn("Body", "Vent", base, 0.42, 0.42, P.basalt[2])
		rig:thorn("Body", "VentLava", base * cf(0, 0.26, 0), 0.2, 0.22, P.lavaHot)
		if rig.effects then
			local fx = rig:anchor("Body", "FX_Vent" .. i, base * cf(0, 0.42, 0), v3(0.2, 0.1, 0.2))
			Fx.particles(fx, Fx.mist("Smoke", { rgb(90, 80, 80), rgb(40, 36, 36) }, 4, 0.9), rig.scale)
			Fx.particles(fx, Fx.embers("Embers", { rgb(255, 220, 120), rgb(255, 90, 20) }, 5, 0.14), rig.scale)
		end
	end

	-- Tête et cou
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.skin,
		coreStep = 0.18,
		cover = { A.scales(P.skinScales, v3(0.18, 0.06, 0.18), 0.14, { arc = 180, from = 1.6, refRadius = 0.28, seed = 3 }) },
	})
	A.horn(rig, "Head", { v3(0, 0.88, -2.0), v3(0, 0.8, -2.18), v3(0, 0.66, -2.2) }, 0.12, 0.03, P.beak)
	rig:mirrored(function(side)
		A.eye(rig, "Head", A.mx(v3(0.22, 0.98, -1.72), side), v3(side, 0.2, -0.6), 0.12, "Glow", P.socket, P.eye)
		A.brow(rig, "Head", side, v3(0.2, 1.07, -1.74), 0.22, 18, P.basalt[3])
	end)

	-- Pattes d'éléphant
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, z in { F = -0.62, B = 0.68 } do
			local bone = "Leg_" .. key .. s
			A.limb(rig, bone, side, {
				{ v3(0.72, 0.62, z), 0.26, 0.26 },
				{ v3(1.05, 0.46, z - 0.1), 0.24, 0.24 },
				{ v3(1.1, 0.16, z - 0.14), 0.22, 0.22 },
			}, P.skin, A.scales(P.skinScales, v3(0.18, 0.07, 0.18), 0.14, { arc = 180, refRadius = 0.24, seed = 10 + side }))
			A.paw(rig, bone, A.mx(v3(1.12, 0, z - 0.2), side), v3(side * 0.3, 0, -1), 0.46, 3, P.pad, P.skin, P.claw)
		end
	end)
	rig:prismBetween("Tail1", "Tail", v3(0, 0.75, 1.1), v3(0, 0.5, 1.55), 0.2, 0.16, 0.06, P.skin)

	A.orbit(rig, "Aura1", v3(0, 1.4, 0), 2.2, 3, 0.25, function(bone, c)
		rig:prism(bone, "LavaRock", c * ang(rad(20), rad(30), 0), v3(0.36, 0.3, 0.34), 0.1, P.basalt[3])
		rig:prism(bone, "LavaCrack", c * ang(rad(20), rad(30), 0), v3(0.38, 0.06, 0.36), 0.02, P.lava)
	end)

	rig:hitbox(cf(0, 1.0, -0.2), v3(2.8, 2.2, 4.2))

	if rig.effects then
		Fx.light(rig.bones.Body, { color = rgb(255, 120, 40), range = 9, brightness = 1.4 }, rig.scale)
	end

	return rig:finish({ Rarity = "Uncommon" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Tortue de Magma",
	Rarity = "Uncommon",
	Zone = "Surface",
	Scale = 1.5,
	Category = "Créature Inhabituelle",
	Description = "Tortue massive dont la carapace volcanique est fendue de coulées de lave.",
	Icon = { top = rgb(120, 40, 20), bottom = rgb(30, 10, 8), glow = rgb(255, 150, 60), motif = rgb(255, 106, 24), yaw = 36, pitch = 22, zoom = 1.1 },
	Animation = { gait = "Sprawler", breathe = 0.02, sway = 4, stride = 20, strideRate = 4, tailSway = 6, tailRate = 1, headLook = 14, auraSpeed = 0.4 },
	build = build,
}

return Def
