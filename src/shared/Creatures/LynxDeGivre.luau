--!strict
--[[
	LYNX DE GIVRE — Rare · Petit
	============================
	Lynx blanc avec des cristaux de glace sur les oreilles.
	
	• Épaisse fourrure blanche aux pointes givrées, collerette de joues en mèches, queue courte.
	• Grandes oreilles à pinceaux surmontées de cristaux de glace (verre + Neon).
	• Fines traînées de givre Neon bleu pâle sur les flancs, yeux Neon bleu glacier.
	• Flocons de glace en orbite ; effets : neige qui tombe, souffle givré.
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

local ID = "LynxDeGivre"

local P = {
	core = S(rgb(150, 162, 184)),
	coat = { S(rgb(252, 253, 255)), S(rgb(228, 236, 246)), S(rgb(198, 210, 226)), S(rgb(164, 178, 200)) },
	tip = S(rgb(214, 238, 255)),
	stripe = S(rgb(170, 225, 255), M.Neon),
	flameOut = S(rgb(120, 200, 255), M.Neon),
	flameMid = S(rgb(190, 235, 255), M.Neon),
	flameCore = S(rgb(255, 255, 255), M.Neon),
	eye = S(rgb(120, 220, 255), M.Neon),
	socket = S(rgb(30, 40, 60)),
	pupil = S(rgb(10, 14, 24)),
	inner = S(rgb(230, 206, 214)),
	whisker = S(rgb(250, 252, 255)),
	gold = S(rgb(214, 230, 244)),
	gem = S(rgb(150, 220, 255), M.Neon),
	nose = S(rgb(70, 66, 84)),
	claw = S(rgb(220, 240, 255)),
	orb = S(rgb(170, 230, 255), M.Glass, { transparency = 0.2 }),
	orbRing = S(rgb(220, 245, 255), M.Neon),
	ice = { S(rgb(170, 230, 255), M.Glass, { transparency = 0.2 }), S(rgb(210, 245, 255), M.Neon), S(rgb(120, 200, 255), M.Glass, { transparency = 0.25 }) },
}

local BODY = Kit.spine({
	{ pos = v3(0, 1.48, -1.0), rx = 0.22, ry = 0.26 },
	{ pos = v3(0, 1.32, -0.65), rx = 0.36, ry = 0.4 },
	{ pos = v3(0, 1.22, -0.1), rx = 0.34, ry = 0.36 },
	{ pos = v3(0, 1.26, 0.45), rx = 0.38, ry = 0.38 },
	{ pos = v3(0, 1.18, 0.8), rx = 0.24, ry = 0.24 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 1.5, -1.62), rx = 0.08, ry = 0.07 },
	{ pos = v3(0, 1.55, -1.48), rx = 0.17, ry = 0.14 },
	{ pos = v3(0, 1.62, -1.3), rx = 0.27, ry = 0.24 },
	{ pos = v3(0, 1.62, -1.1), rx = 0.25, ry = 0.25 },
})

local TAIL = Kit.spine({
	{ pos = v3(0, 1.3, 0.82), rx = 0.12, ry = 0.12 },
	{ pos = v3(0, 1.38, 0.98), rx = 0.14, ry = 0.14 },
	{ pos = v3(0, 1.45, 1.12), rx = 0.13, ry = 0.13 },
	{ pos = v3(0, 1.5, 1.22), rx = 0.1, ry = 0.1 },
	{ pos = v3(0, 1.53, 1.3), rx = 0.07, ry = 0.07 },
	{ pos = v3(0, 1.55, 1.35), rx = 0.03, ry = 0.03 },
})

-- Capacité spéciale (CreatureForge.playAbility)
local ABILITY: Types.Ability = {
	name = "Souffle de givre",
	kind = "Breath",
	colors = { rgb(170, 230, 255), rgb(90, 160, 230), rgb(255, 255, 255) },
	texture = "smoke",
	radius = 5,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 1.25, 0))
	rig:bone("Head", "Body", cf(0, 1.5, -1.05))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.24, 1.15, -0.6))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.26, 1.2, 0.5))
		rig:bone("Ear" .. sfx, "Head", cf(side * 0.16, 1.82, -1.15))
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
		cover = { A.fur(P.coat, P.tip, v3(0.2, 0.32, 0.3), 0.16, { arc = 165, refRadius = 0.35, seed = 1 }) },
	})
	-- Rayures Neon sur les flancs
	rig:mirrored(function(side)
		for k, u in { 2.0, 2.6, 3.2, 3.8, 4.3 } do
			local a, b, c = BODY:surface(u, side * 35, 0.05), BODY:surface(u + 0.12, side * 70, 0.05), BODY:surface(u + 0.05, side * 105, 0.05)
			rig:strut("Body", "Stripe", a.Position, b.Position, 0.06, 0.03, P.stripe)
			if k % 2 == 1 then
				rig:strut("Body", "Stripe", b.Position, c.Position, 0.05, 0.03, P.stripe)
			end
		end
	end)
	rig:band(BODY, "Body", "GoldCollar", 1.35, 0.08, 0.05, P.gold)
	rig:shard("Body", "CollarGem", BODY:surface(1.38, 160, 0.05) * ang(math.pi, 0, 0), 0.1, 0.12, 0.08, P.gem)

	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.14,
		cover = { A.fur(P.coat, P.tip, v3(0.13, 0.2, 0.18), 0.11, { arc = 150, from = 1.5, refRadius = 0.24, seed = 2 }) },
	})
	rig:ball("Head", "Nose", v3(0, 1.53, -1.66), 0.08, P.nose)
	rig:mirrored(function(side, sfx)
		A.eye(rig, "Head", A.mx(v3(0.16, 1.68, -1.42), side), v3(side * 0.6, 0.1, -1), 0.13, "Slit", P.socket, P.eye, P.pupil)
		A.brow(rig, "Head", side, v3(0.15, 1.78, -1.42), 0.2, 24, P.coat[4])
		A.ear(rig, "Ear" .. sfx, cf(A.mx(v3(0.16, 1.82, -1.15), side)) * ang(rad(-8), side * rad(-18), side * rad(-20)), 0.3, 0.4, P.coat[2], P.inner, P.stripe)
		A.whiskers(rig, "Head", side, v3(0.12, 1.5, -1.58), 0.6, P.whisker)
		A.tuftBurst(rig, "Head", cf(A.mx(v3(0.25, 1.48, -1.2), side)) * ang(0, side * rad(-25), -side * rad(100)), 6, 0.34, 0.12, P.coat, P.tip, 25, 5 + side)
		-- Pinceaux d'oreille en cristaux de glace
		A.crystals(rig, "Ear" .. sfx, cf(A.mx(v3(0.2, 2.18, -1.17), side)) * ang(0, 0, -side * rad(12)), 4, 0.32, P.ice, 30 + side, 0.12)
		rig:thorn("Head", "Fang", cf(A.mx(v3(0.05, 1.44, -1.6), side)) * ang(math.pi, 0, 0), 0.03, 0.07, P.whisker)
	end)

	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, L in { F = { v3(0.24, 1.15, -0.6), v3(0.26, 0.6, -0.62), v3(0.26, 0.14, -0.68), 0.15 }, B = { v3(0.26, 1.2, 0.5), v3(0.3, 0.72, 0.7), v3(0.28, 0.14, 0.58), 0.24 } } do
			local bone = "Leg_" .. key .. s
			A.limb(rig, bone, side, { { L[1], L[4], L[4] * 1.15 }, { L[2], 0.09, 0.09 }, { L[3], 0.07, 0.07 } }, P.core, A.fur(P.coat, P.tip, v3(0.13, 0.22, 0.2), 0.11, { arc = 180, refRadius = 0.12, seed = 10 + side }))
			A.paw(rig, bone, A.mx((L[3] :: Vector3) - v3(0, 0.14, 0.06), side), v3(0, 0, -1), 0.22, 4, P.coat[3], P.coat[2], P.claw)
		end
	end)

	rig:tube(TAIL, {
		name = "Tail",
		bone = function(u)
			return tail[math.clamp(math.floor(u), 1, #tail)]
		end,
		core = P.core,
		coreStep = 0.16,
		cover = { A.fur(P.coat, P.tip, v3(0.14, 0.24, 0.22), 0.1, { arc = 180, refRadius = 0.11, seed = 5 }) },
	})
	local tipCF = A.alongUp(TAIL:pos(6), TAIL:pos(6) - TAIL:pos(5) + v3(0, 0.3, 0))
	A.tuftBurst(rig, tail[5], tipCF, 6, 0.18, 0.1, { P.coat[4] }, P.socket, 30, 9)

	A.orbit(rig, "Aura1", v3(0, 1.5, 0), 1.9, 4, 0.35, function(bone, c, i)
		rig:shard(bone, "IceShard", c * ang(0, 0, rad(25)), 0.14, 0.34, 0.14, P.ice[(i % 3) + 1])
		A.flatRing(rig, bone, c.Position, 0.18, 0.03, 0.03, 8, P.orbRing)
	end)

	rig:hitbox(cf(0, 1.3, -0.2), v3(1.4, 2.6, 3.8))

	if rig.effects then
		local sc = rig.scale
		local m = rig:anchor("Body", "FX_Mist", cf(0, 1.0, 0), v3(1.8, 1.2, 3))
		Fx.particles(m, Fx.sparkles("Snow", { rgb(255, 255, 255), rgb(200, 235, 255) }, 10, 0.16, -0.6), sc)
		Fx.particles(m, Fx.mist("FrostMist", { rgb(220, 240, 255), rgb(170, 200, 230) }, 6, 1.2, 0.2), sc)
		Fx.light(rig.bones.Head, { color = rgb(138, 220, 255), range = 6, brightness = 1 }, sc)
		Fx.light(m, { color = rgb(144, 222, 255), range = 9, brightness = 1.2 }, sc)
	end


	-- Effets avancés : signature, origine de la capacité, aura de rareté
	if rig.effects then
		local tip = TAIL:pos(6)
		Vfx.trail(rig, tail[5], tip + v3(0, 0.06, 0), tip - v3(0, 0.06, 0), { colors = { rgb(174, 231, 255), rgb(84, 148, 176) }, lifetime = 0.5 })
		Vfx.orbitTethers(rig, "Aura1", Vfx.orbitPoints(v3(0, 1.5, 0), 1.9, 4, 0.35), "Body", v3(0, 1.3, 0), { colors = { rgb(168, 229, 255), rgb(84, 148, 176) }, transparency = { 0.4, 0.9 }, width0 = 0.05, width1 = 0.02, curve0 = 0.5 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Rare")
	end

	return rig:finish({ Rarity = "Rare" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Lynx de givre",
	Rarity = "Rare",
	Size = "Small",
	Income = 50,
	SpeedBonus = 0.12,
	Passenger = false,
	Scale = 1.8,
	Category = "Créature Rare",
	Description = "Lynx blanc des neiges : des cristaux de glace poussent au bout de ses oreilles.",
	Icon = { top = rgb(120, 170, 220), bottom = rgb(20, 34, 56), glow = rgb(210, 240, 255), motif = rgb(170, 230, 255), yaw = 34, pitch = 12, zoom = 1.1 },
	Animation = { flicker = 0, gait = "Quadruped", breathe = 0.025, bob = 0.08, stride = 30, strideRate = 11, tailSway = 12, tailRate = 1.4, headLook = 24, earTwitch = true, auraSpeed = 0.6 },
	Ability = ABILITY,
	build = build,
}

return Def
