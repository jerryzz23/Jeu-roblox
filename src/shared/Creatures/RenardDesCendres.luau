--!strict
--[[
	LE RENARD DES CENDRES — Inhabituel · La Surface
	===============================================
	Canidé élégant à la fourrure flamboyante (orange/rouge), braises et marquages dorés.

	• Fourrure en mèches orange → rouge à pointes jaune-or, plastron et joues blancs.
	• Grande queue touffue dont le bout devient cendre grise et s'embrase (flammes Neon).
	• Yeux ambrés à pupille fendue, oreilles à pointes noires, chaussettes sombres.
	• Marquages dorés au front et sur les joues, bracelets dorés aux pattes.
	• 3 braises en orbite ; effets : braises qui s'envolent, lueur chaude.
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

local ID = "RenardDesCendres"

local P = {
	core = S(rgb(170, 60, 24)),
	fur = { S(rgb(255, 156, 60)), S(rgb(246, 116, 36)), S(rgb(214, 76, 26)), S(rgb(164, 46, 22)) },
	tip = S(rgb(255, 214, 96)),
	white = { S(rgb(255, 250, 240)), S(rgb(240, 230, 220)) },
	ash = { S(rgb(150, 144, 150)), S(rgb(110, 104, 112)), S(rgb(80, 76, 84)) },
	sock = S(rgb(52, 30, 30)),
	black = S(rgb(30, 22, 24)),
	gold = S(rgb(255, 204, 60)),
	eye = S(rgb(255, 184, 40)),
	socket = S(rgb(40, 16, 10)),
	pupil = S(rgb(20, 10, 8)),
	inner = S(rgb(255, 226, 200)),
	flameOut = S(rgb(255, 90, 20), M.Neon),
	flameMid = S(rgb(255, 170, 40), M.Neon),
	flameCore = S(rgb(255, 245, 180), M.Neon),
}

local BODY = Kit.spine({
	{ pos = v3(0, 1.62, -1.0), rx = 0.22, ry = 0.24 },
	{ pos = v3(0, 1.42, -0.75), rx = 0.3, ry = 0.34 },
	{ pos = v3(0, 1.3, -0.4), rx = 0.4, ry = 0.42 },
	{ pos = v3(0, 1.28, 0.05), rx = 0.4, ry = 0.38 },
	{ pos = v3(0, 1.3, 0.48), rx = 0.42, ry = 0.4 },
	{ pos = v3(0, 1.2, 0.8), rx = 0.26, ry = 0.26 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 1.6, -1.72), rx = 0.06, ry = 0.06 },
	{ pos = v3(0, 1.63, -1.55), rx = 0.13, ry = 0.12 },
	{ pos = v3(0, 1.68, -1.35), rx = 0.2, ry = 0.17 },
	{ pos = v3(0, 1.74, -1.15), rx = 0.28, ry = 0.24 },
	{ pos = v3(0, 1.74, -0.98), rx = 0.26, ry = 0.24 },
})

local TAIL = Kit.spine({
	{ pos = v3(0, 1.25, 0.82), rx = 0.14, ry = 0.14 },
	{ pos = v3(0, 1.15, 1.25), rx = 0.3, ry = 0.3 },
	{ pos = v3(0.1, 1.15, 1.75), rx = 0.36, ry = 0.36 },
	{ pos = v3(0.25, 1.3, 2.2), rx = 0.3, ry = 0.3 },
	{ pos = v3(0.35, 1.55, 2.5), rx = 0.16, ry = 0.16 },
	{ pos = v3(0.38, 1.75, 2.62), rx = 0.04, ry = 0.04 },
})

-- Capacité spéciale (CreatureForge.playAbility)
local ABILITY: Types.Ability = {
	name = "Souffle de cendres",
	kind = "Breath",
	colors = { rgb(255, 140, 40), rgb(255, 60, 20), rgb(255, 240, 160) },
	texture = "fire",
	origin = v3(0, 1.6, -1.82),
	direction = v3(0, -0.05, -1),
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 1.3, 0))
	rig:bone("Head", "Body", cf(0, 1.6, -0.95))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.25, 1.15, -0.5))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.28, 1.2, 0.5))
		rig:bone("Ear" .. sfx, "Head", cf(side * 0.17, 1.95, -1.05))
	end)
	local tj = {}
	for i = 1, #TAIL.sections do
		table.insert(tj, TAIL:pos(i))
	end
	local tail = rig:boneChain("Tail", "Body", tj)

	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.25,
		cover = {
			A.fur(P.fur, P.tip, v3(0.2, 0.36, 0.34), 0.18, { arc = 125, seed = 1 }),
			A.fur(P.white, nil, v3(0.18, 0.28, 0.3), 0.2, { arc = 50, center = 180, to = 3.3, seed = 2 }),
		},
	})
	-- Plastron blanc
	A.tuftBurst(rig, "Body", cf(0, 1.25, -0.82) * ang(rad(-110), 0, 0), 10, 0.36, 0.16, P.white, nil, 40, 3)

	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.15,
		cover = { A.fur(P.fur, P.tip, v3(0.14, 0.2, 0.2), 0.12, { arc = 130, from = 2.4, refRadius = 0.26, seed = 4 }) },
	})
	rig:ball("Head", "Nose", v3(0, 1.62, -1.78), 0.11, P.black)
	rig:prismBetween("Head", "Muzzle", v3(0, 1.55, -1.25), v3(0, 1.56, -1.7), 0.2, 0.1, 0.04, P.white[1])
	rig:block("Head", "GoldMark", cf(0, 1.99, -1.2) * ang(rad(-20), rad(45), 0), v3(0.1, 0.04, 0.1), P.gold)
	rig:mirrored(function(side, sfx)
		A.eye(rig, "Head", A.mx(v3(0.17, 1.8, -1.3), side), v3(side, 0.25, -0.6), 0.11, "Slit", P.socket, P.eye, P.pupil)
		A.brow(rig, "Head", side, v3(0.15, 1.89, -1.31), 0.18, 20, P.fur[4])
		A.tuftBurst(rig, "Head", cf(A.mx(v3(0.24, 1.62, -1.12), side)) * ang(0, side * rad(-30), -side * rad(95)), 5, 0.3, 0.12, P.white, nil, 25, 5 + side)
		rig:strut("Head", "GoldStripe", A.mx(v3(0.2, 1.72, -1.4), side), A.mx(v3(0.27, 1.7, -1.12), side), 0.03, 0.03, P.gold)
		A.ear(rig, "Ear" .. sfx, cf(A.mx(v3(0.17, 1.95, -1.05), side)) * ang(rad(-6), side * rad(-18), side * rad(-14)), 0.34, 0.5, P.fur[2], P.inner, P.black)
	end)

	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, L in { F = { v3(0.25, 1.15, -0.5), v3(0.27, 0.6, -0.52), v3(0.27, 0.14, -0.58), 0.14 }, B = { v3(0.28, 1.2, 0.5), v3(0.32, 0.7, 0.68), v3(0.3, 0.14, 0.6), 0.24 } } do
			local bone = "Leg_" .. key .. s
			A.limb(rig, bone, side, { { L[1], L[4], L[4] * 1.15 }, { L[2], 0.09, 0.09 }, { L[3], 0.065, 0.065 } }, P.sock, A.fur(P.fur, P.tip, v3(0.16, 0.26, 0.24), 0.14, { arc = 180, to = 1.8, refRadius = 0.18, seed = 10 + side }))
			A.paw(rig, bone, A.mx((L[3] :: Vector3) - v3(0, 0.14, 0.06), side), v3(0, 0, -1), 0.2, 3, P.sock, P.black, P.white[2])
			rig:ring(bone, "GoldAnklet", cf(A.mx((L[2] :: Vector3):Lerp(L[3] :: Vector3, 0.55), side)) * ang(math.pi / 2, 0, 0), 0.085, 0.035, 0.05, 10, P.gold)
		end
	end)

	-- Grande queue : orange, puis cendre, puis flammes
	rig:tube(TAIL, {
		name = "Tail",
		bone = function(u)
			return tail[math.clamp(math.floor(u), 1, #tail)]
		end,
		core = P.core,
		coreStep = 0.22,
		cover = {
			A.fur(P.fur, P.tip, v3(0.22, 0.42, 0.36), 0.17, { arc = 180, to = 4.0, refRadius = 0.32, seed = 6 }),
			A.fur(P.ash, P.white[1], v3(0.22, 0.42, 0.36), 0.17, { arc = 180, from = 4.0, refRadius = 0.32, seed = 7 }),
		},
	})
	local tipCF = A.alongUp(TAIL:pos(6), TAIL:pos(6) - TAIL:pos(5))
	A.flame(rig, tail[5], tipCF, 0.55, 0.22, P.flameOut, P.flameMid, P.flameCore)
	A.flame(rig, tail[5], tipCF * ang(rad(25), 0, rad(20)) * cf(0, -0.08, 0), 0.38, 0.16, P.flameOut, P.flameMid, P.flameCore)

	A.orbit(rig, "Aura1", v3(0, 1.4, 0.2), 1.6, 3, 0.2, function(bone, c)
		A.flame(rig, bone, c, 0.28, 0.12, P.flameOut, P.flameMid, P.flameCore)
	end)

	rig:hitbox(cf(0, 1.2, 0.3), v3(1.4, 2.4, 4.6))

	if rig.effects then
		local sc = rig.scale
		local tipFx = rig:anchor(tail[5], "FX_TailFire", cf(TAIL:pos(6)), v3(0.3, 0.3, 0.3))
		Fx.particles(tipFx, Fx.fire("TailFire", { rgb(255, 230, 120), rgb(255, 110, 30), rgb(120, 20, 10) }, 18, 0.4), sc)
		Fx.light(tipFx, { color = rgb(255, 140, 50), range = 7, brightness = 1.4 }, sc)
		local body = rig:anchor("Body", "FX_Embers", cf(0, 1.5, 0.2), v3(0.9, 0.6, 1.8))
		Fx.particles(body, Fx.embers("Embers", { rgb(255, 220, 120), rgb(255, 100, 30) }, 6, 0.16), sc)
	end


	-- Effets avancés : signature, origine de la capacité, aura de rareté
	if rig.effects then
		local tip = TAIL:pos(6)
		Vfx.trail(rig, tail[5], tip + v3(0, 0.08, 0), tip - v3(0, 0.08, 0), { colors = { rgb(255, 210, 90), rgb(255, 70, 20) }, lifetime = 0.5 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Uncommon")
	end

	return rig:finish({ Rarity = "Uncommon" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Renard des Cendres",
	Rarity = "Uncommon",
	Zone = "Surface",
	Scale = 1.5,
	Category = "Créature Inhabituelle",
	Description = "Canidé élégant à la fourrure flamboyante. Le bout de sa queue n'est que braises et cendres.",
	Icon = { top = rgb(150, 50, 24), bottom = rgb(40, 12, 8), glow = rgb(255, 180, 80), motif = rgb(255, 210, 90), yaw = 34, pitch = 14, zoom = 1.1 },
	Animation = { flicker = 0.3, gait = "Quadruped", breathe = 0.03, bob = 0.12, stride = 32, strideRate = 12, tailSway = 14, tailRate = 1.8, headLook = 22, sniff = true, earTwitch = true },
	Ability = ABILITY,
	build = build,
}

return Def
