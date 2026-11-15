--!strict
--[[
	LE GRIFFON IMPÉRIAL — Légendaire · Grand
	========================================
	Mi-aigle mi-lion avec une armure dorée.

	• Avant d'aigle : tête et poitrail en plumes blanches, bec d'or crochu, huppe de plumes,
	  pattes d'aigle écailleuses jaunes aux serres noires.
	• Arrière de lion : pelage fauve en mèches, pattes à coussinets, queue à touffe sombre.
	• Grandes ailes à 3 rangées (blanc, or, bronze) aux pointes Neon or.
	• Armure impériale : casque à crête, plastron serti d'un rubis, ceinture et épaulières d'or,
	  selle de velours pourpre (monture avec passager).
	• Plumes d'or en orbite ; effets : poussière d'or, traînées dorées au bout des ailes.
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

local ID = "GriffonImperial"

local P = {
	core = S(rgb(150, 110, 60)),
	plume = { S(rgb(255, 255, 255)), S(rgb(236, 236, 242)), S(rgb(210, 210, 222)), S(rgb(180, 180, 196)) },
	fur = { S(rgb(232, 182, 100)), S(rgb(208, 152, 74)), S(rgb(180, 124, 56)), S(rgb(146, 96, 44)) },
	furTip = S(rgb(250, 220, 150)),
	mane = { S(rgb(150, 90, 40)), S(rgb(118, 68, 30)) },
	gold = S(rgb(255, 200, 56), M.Metal, { reflectance = 0.1 }),
	goldDark = S(rgb(200, 128, 24), M.Metal),
	goldNeon = S(rgb(255, 214, 90), M.Neon),
	velvet = S(rgb(130, 20, 50), M.Fabric),
	ruby = S(rgb(255, 40, 70), M.Neon),
	beak = S(rgb(255, 196, 60)),
	scaleLeg = { S(rgb(255, 214, 90)), S(rgb(230, 180, 60)) },
	talon = S(rgb(30, 26, 30)),
	eye = S(rgb(255, 190, 40), M.Neon),
	socket = S(rgb(40, 26, 10)),
	pupil = S(rgb(10, 8, 6)),
	wingA = { S(rgb(255, 255, 255)), S(rgb(240, 240, 248)) },
	wingB = { S(rgb(255, 216, 110)), S(rgb(240, 186, 70)) },
	wingC = { S(rgb(196, 130, 60)), S(rgb(160, 100, 44)) },
	pad = S(rgb(70, 46, 30)),
	claw = S(rgb(246, 240, 226)),
}

local BODY = Kit.spine({
	{ pos = v3(0, 2.05, -1.2), rx = 0.26, ry = 0.28 },
	{ pos = v3(0, 1.8, -0.85), rx = 0.46, ry = 0.5 },
	{ pos = v3(0, 1.6, -0.3), rx = 0.5, ry = 0.52 },
	{ pos = v3(0, 1.56, 0.25), rx = 0.47, ry = 0.47 },
	{ pos = v3(0, 1.55, 0.7), rx = 0.45, ry = 0.43 },
	{ pos = v3(0, 1.42, 1.02), rx = 0.26, ry = 0.26 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 2.2, -1.68), rx = 0.14, ry = 0.14 },
	{ pos = v3(0, 2.25, -1.5), rx = 0.25, ry = 0.25 },
	{ pos = v3(0, 2.24, -1.27), rx = 0.27, ry = 0.28 },
	{ pos = v3(0, 2.1, -1.05), rx = 0.23, ry = 0.25 },
})

local TAIL = Kit.spine({
	{ pos = v3(0, 1.48, 1.05), rx = 0.1, ry = 0.1 },
	{ pos = v3(0, 1.3, 1.5), rx = 0.09, ry = 0.09 },
	{ pos = v3(0.1, 1.25, 1.95), rx = 0.08, ry = 0.08 },
	{ pos = v3(0.25, 1.45, 2.3), rx = 0.07, ry = 0.07 },
	{ pos = v3(0.32, 1.7, 2.45), rx = 0.05, ry = 0.05 },
})

local ABILITY: Types.Ability = {
	name = "Charge impériale",
	kind = "Burst",
	colors = { rgb(255, 214, 90), rgb(200, 120, 20), rgb(255, 255, 255) },
	texture = "sparkle",
	radius = 7,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 1.6, 0))
	rig:bone("Head", "Body", cf(0, 2.1, -1.1))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.3, 1.45, -0.75))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.32, 1.5, 0.62))
		rig:bone("Wing" .. sfx, "Body", cf(side * 0.36, 2.0, -0.55))
	end)
	local tj = {}
	for i = 1, #TAIL.sections do
		table.insert(tj, TAIL:pos(i))
	end
	local tail = rig:boneChain("Tail", "Body", tj)

	-- Corps : plumes à l'avant, pelage de lion à l'arrière
	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.28,
		cover = {
			A.scales(P.plume, v3(0.28, 0.07, 0.34), 0.2, { arc = 180, to = 2.7, tilt = 24, refRadius = 0.45, seed = 1 }),
			A.fur(P.fur, P.furTip, v3(0.22, 0.34, 0.3), 0.18, { arc = 165, from = 2.7, refRadius = 0.45, seed = 2 }),
		},
	})
	-- Armure : plastron, ceinture, épaulières
	rig:prism("Body", "Breastplate", BODY:surface(2.0, 180, 0.04) * ang(rad(-10), 0, 0), v3(0.62, 0.08, 0.72), 0.12, P.gold)
	rig:ring("Body", "BreastRim", BODY:surface(2.0, 180, 0.08) * ang(0, 0, 0), 0.16, 0.05, 0.05, 12, P.goldDark)
	rig:shard("Body", "Ruby", BODY:surface(2.0, 180, 0.1) * ang(math.pi, 0, 0), 0.14, 0.12, 0.1, P.ruby)
	rig:band(BODY, "Body", "GoldBelt", 3.6, 0.14, 0.08, P.gold, P.goldDark)
	rig:band(BODY, "Body", "GoldCollar", 1.4, 0.1, 0.06, P.gold)
	rig:mirrored(function(side)
		local sh = BODY:surface(1.95, side * 60, 0.06)
		rig:prism("Body", "Pauldron", sh, v3(0.5, 0.12, 0.55), 0.1, P.gold)
		rig:prism("Body", "Pauldron", sh * cf(0, 0.08, 0.04), v3(0.34, 0.08, 0.38), 0.07, P.goldDark)
		rig:thorn("Body", "PauldronSpike", sh * cf(0, 0.1, 0), 0.08, 0.22, P.gold)
	end)
	-- Selle de velours pourpre
	local saddle = BODY:surface(3.3, 0, 0.12)
	rig:prism("Body", "SaddleCloth", saddle * cf(0, -0.03, 0), v3(1.1, 0.06, 0.95), 0.04, P.velvet)
	rig:mirrored(function(side)
		local flap = saddle * cf(side * 0.58, -0.3, 0) * ang(0, 0, side * rad(64))
		rig:prism("Body", "SaddleFlap", flap, v3(0.55, 0.05, 0.9), 0.03, P.velvet)
		rig:block("Body", "SaddleTrim", flap * cf(0, 0, 0.45), v3(0.56, 0.06, 0.05), P.gold)
		rig:block("Body", "SaddleTrim", flap * cf(0, 0, -0.45), v3(0.56, 0.06, 0.05), P.gold)
	end)
	rig:prism("Body", "Saddle", saddle * cf(0, 0.08, 0), v3(0.7, 0.14, 0.75), 0.06, P.velvet)
	rig:prism("Body", "SaddleBack", saddle * cf(0, 0.24, 0.36) * ang(rad(-15), 0, 0), v3(0.62, 0.28, 0.1), 0.04, P.gold)
	rig:seat("Body", saddle * cf(0, 0.22, 0), v3(0.7, 0.2, 0.7))

	-- Tête d'aigle
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.16,
		cover = { A.scales(P.plume, v3(0.16, 0.05, 0.2), 0.12, { arc = 180, from = 1.4, tilt = 22, refRadius = 0.26, seed = 3 }) },
	})
	A.horn(rig, "Head", { v3(0, 2.24, -1.62), v3(0, 2.2, -1.85), v3(0, 2.08, -1.96), v3(0, 1.96, -1.93) }, 0.12, 0.025, P.beak)
	rig:prismBetween("Head", "LowerBeak", v3(0, 2.1, -1.62), v3(0, 2.06, -1.82), 0.12, 0.06, 0.03, P.beak)
	-- Casque impérial à crête
	rig:prism("Head", "Helm", cf(0, 2.47, -1.28) * ang(rad(-8), 0, 0), v3(0.42, 0.1, 0.48), 0.1, P.gold)
	rig:block("Head", "HelmBrow", cf(0, 2.4, -1.5) * ang(rad(-20), 0, 0), v3(0.44, 0.06, 0.08), P.goldDark)
	A.featherFan(rig, "Head", cf(0, 2.5, -1.2) * ang(rad(-30), 0, 0), 7, 0.65, 0.16, 50, { P.wingB[1], P.plume[1], P.wingB[2] }, P.goldNeon)
	rig:mirrored(function(side)
		A.eye(rig, "Head", A.mx(v3(0.2, 2.32, -1.45), side), v3(side, 0.15, -0.55), 0.12, "Round", P.socket, P.eye, P.pupil)
		A.brow(rig, "Head", side, v3(0.17, 2.42, -1.47), 0.22, 22, P.plume[4])
		rig:block("Head", "HelmCheek", cf(A.mx(v3(0.24, 2.3, -1.3), side)) * ang(0, side * rad(-15), side * rad(-10)), v3(0.05, 0.22, 0.3), P.gold)
	end)

	-- Ailes
	rig:mirrored(function(side, sfx)
		A.wing(rig, "Wing" .. sfx, side, {
			arm = { v3(0.36, 2.0, -0.55), v3(1.05, 2.35, -0.5), v3(1.85, 2.6, -0.35), v3(2.7, 2.75, -0.1) },
			armRadius = 0.15,
			feathers = 14,
			length = { 1.1, 1.75 },
			width = 0.36,
			sweep = 40,
			rows = { P.wingC, P.wingB, P.wingA },
			tip = P.goldNeon,
			armStyle = P.plume[2],
		})
		rig:prism("Wing" .. sfx, "WingGuard", cf(A.mx(v3(0.8, 2.3, -0.52), side)) * ang(0, 0, -side * rad(26)), v3(0.5, 0.08, 0.3), 0.06, P.gold)
	end)

	-- Pattes : aigle à l'avant, lion à l'arrière
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		local front = "Leg_F" .. s
		A.limb(rig, front, side, { { v3(0.3, 1.45, -0.75), 0.18, 0.2 }, { v3(0.33, 0.85, -0.82), 0.11, 0.11 }, { v3(0.33, 0.24, -0.88), 0.08, 0.08 } }, P.scaleLeg[2], A.scales(P.plume, v3(0.14, 0.05, 0.16), 0.1, { arc = 180, to = 1.7, refRadius = 0.16, seed = 12 + side }))
		for k = 1, 3 do
			rig:ring(front, "LegScale", cf(A.mx(v3(0.33, 0.3 + k * 0.12, -0.87), side)) * ang(math.pi / 2, 0, 0), 0.085, 0.03, 0.04, 10, P.scaleLeg[1])
		end
		local foot = A.mx(v3(0.33, 0.12, -0.9), side)
		for k = -1, 1 do
			local dir = v3(side * k * 0.45, -0.25, -1).Unit
			local tip = foot + dir * 0.28
			rig:strut(front, "Toe", foot, tip, 0.07, 0.07, P.scaleLeg[1])
			rig:thorn(front, "Talon", A.alongUp(tip, dir + v3(0, -0.6, 0)), 0.07, 0.16, P.talon)
		end
		rig:thorn(front, "Talon", A.alongUp(foot + v3(0, 0, 0.16), v3(0, -0.5, 1)), 0.07, 0.15, P.talon)

		local back = "Leg_B" .. s
		A.limb(rig, back, side, { { v3(0.32, 1.5, 0.62), 0.28, 0.32 }, { v3(0.36, 0.9, 0.82), 0.14, 0.14 }, { v3(0.34, 0.22, 0.72), 0.1, 0.1 } }, P.core, A.fur(P.fur, P.furTip, v3(0.16, 0.26, 0.24), 0.14, { arc = 180, refRadius = 0.2, seed = 20 + side }))
		A.paw(rig, back, A.mx(v3(0.34, 0.08, 0.66), side), v3(0, 0, -1), 0.3, 4, P.pad, P.fur[3], P.claw)
		rig:ring(back, "GoldAnklet", cf(A.mx(v3(0.35, 0.5, 0.78), side)) * ang(math.pi / 2, 0, 0), 0.13, 0.04, 0.06, 12, P.gold)
	end)

	-- Queue de lion
	rig:tube(TAIL, {
		name = "Tail",
		bone = function(u)
			return tail[math.clamp(math.floor(u), 1, #tail)]
		end,
		core = P.core,
		coreStep = 0.14,
		cover = { A.fur(P.fur, nil, v3(0.1, 0.16, 0.14), 0.09, { arc = 180, refRadius = 0.08, seed = 6 }) },
	})
	A.tuftBurst(rig, tail[#tail], A.alongUp(TAIL:pos(5), TAIL:pos(5) - TAIL:pos(4)), 10, 0.36, 0.12, P.mane, P.goldNeon, 40, 7)
	rig:ring(tail[#tail], "TailRing", Kit.lookAlong(TAIL:pos(4.6), TAIL:pos(5) - TAIL:pos(4)), 0.07, 0.03, 0.05, 10, P.gold)

	-- Plumes d'or en orbite
	A.orbit(rig, "Aura1", v3(0, 2.0, 0), 2.6, 6, 0.4, function(bone, c)
		A.feather(rig, bone, c * ang(0, 0, rad(25)) * ang(0, math.pi / 2, 0), 0.6, 0.2, P.wingB[1], P.goldNeon)
	end)

	rig:hitbox(cf(0, 1.6, 0), v3(2.4, 3.2, 4.4))

	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Body", "FX_Gold", cf(0, 2.0, 0), v3(2, 1.6, 3))
		Fx.particles(g, Fx.sparkles("GoldDust", { rgb(255, 236, 140), rgb(255, 190, 60) }, 9, 0.22), sc)
		Fx.light(g, { color = rgb(255, 210, 110), range = 12, brightness = 1.3 }, sc)
		rig:mirrored(function(side, sfx)
			local tip = A.mx(v3(2.7, 2.75, -0.1), side)
			Vfx.trail(rig, "Wing" .. sfx, tip + v3(0, 0.08, 0), tip - v3(0, 0.08, 0), { colors = { rgb(255, 236, 150), rgb(255, 180, 40) }, lifetime = 0.45 })
		end)
		Vfx.orbitTethers(rig, "Aura1", Vfx.orbitPoints(v3(0, 2.0, 0), 2.6, 6, 0.4), "Head", v3(0, 2.55, -1.25), { colors = { rgb(255, 230, 130), rgb(220, 150, 30) }, transparency = { 0.4, 0.85 }, width0 = 0.05, width1 = 0.02, curve0 = 0.6 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Legendary")
	end

	return rig:finish({ Rarity = "Legendary" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Griffon impérial",
	Rarity = "Legendary",
	Size = "Large",
	Income = 10000,
	SpeedBonus = 0.55,
	Passenger = true,
	Scale = 2.0,
	Category = "Créature Légendaire",
	Description = "Mi-aigle mi-lion, harnaché d'une armure d'or impériale : la monture des souverains.",
	Icon = { top = rgb(170, 110, 30), bottom = rgb(40, 20, 6), glow = rgb(255, 220, 120), motif = rgb(255, 200, 60), yaw = 32, pitch = 12, zoom = 1.05 },
	Animation = { gait = "Quadruped", breathe = 0.035, bob = 0.12, stride = 30, strideRate = 10, tailSway = 16, tailRate = 1.5, headLook = 20, auraSpeed = 0.5 },
	Ability = ABILITY,
	build = build,
}

return Def
