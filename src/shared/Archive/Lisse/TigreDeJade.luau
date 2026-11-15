--!strict
--[[
	TIGRE DE JADE — Épique · Moyen
	==============================
	Tigre sculpté dans la pierre verte, rayures lumineuses.
	
	• Corps sculpté en plaques de jade (matériau Marble), vert profond -> vert d'eau.
	• Rayures Neon vert lumineux sur les flancs, la tête et la queue.
	• Collier d'or impérial serti de jade, yeux Neon d'or.
	• Pièces de jade cerclées d'or en orbite ; effets : lueurs vertes, poussière d'or.
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

local ID = "TigreDeJade"

local P = {
	core = S(rgb(20, 70, 44), M.Marble),
	coat = { S(rgb(130, 220, 164), M.Marble), S(rgb(84, 182, 124), M.Marble), S(rgb(48, 140, 88), M.Marble), S(rgb(28, 98, 60), M.Marble) },
	stripe = S(rgb(120, 255, 170), M.Neon),
	flameOut = S(rgb(40, 200, 110), M.Neon),
	flameMid = S(rgb(140, 255, 180), M.Neon),
	flameCore = S(rgb(230, 255, 230), M.Neon),
	eye = S(rgb(255, 210, 60), M.Neon),
	socket = S(rgb(10, 30, 20)),
	pupil = S(rgb(8, 14, 10)),
	inner = S(rgb(60, 150, 100), M.Marble),
	whisker = S(rgb(220, 240, 220)),
	gold = S(rgb(255, 200, 56)),
	gem = S(rgb(120, 255, 170), M.Neon),
	nose = S(rgb(20, 60, 40), M.Marble),
	claw = S(rgb(255, 220, 120)),
	orb = S(rgb(90, 200, 130), M.Marble),
	orbRing = S(rgb(255, 200, 56)),
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
	{ pos = v3(0, 1.28, 0.85), rx = 0.1, ry = 0.1 },
	{ pos = v3(0, 1.5, 1.3), rx = 0.12, ry = 0.12 },
	{ pos = v3(0.1, 1.95, 1.55), rx = 0.11, ry = 0.11 },
	{ pos = v3(0.35, 2.3, 1.45), rx = 0.09, ry = 0.09 },
	{ pos = v3(0.55, 2.4, 1.15), rx = 0.07, ry = 0.07 },
	{ pos = v3(0.5, 2.25, 0.95), rx = 0.03, ry = 0.03 },
})

-- Capacité spéciale (CreatureForge.playAbility)
local ABILITY: Types.Ability = {
	name = "Rugissement de jade",
	kind = "Nova",
	colors = { rgb(120, 255, 170), rgb(30, 120, 70), rgb(255, 220, 100) },
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
		cover = { A.scales(P.coat, v3(0.22, 0.06, 0.26), 0.17, { arc = 160, tilt = 16, refRadius = 0.35, seed = 1 }) },
	})
	-- Rayures Neon sur les flancs
	rig:mirrored(function(side)
		for k, u in { 1.5, 1.9, 2.3, 2.7, 3.1, 3.5, 3.9, 4.3 } do
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
		cover = { A.scales(P.coat, v3(0.13, 0.05, 0.15), 0.1, { arc = 150, from = 1.5, refRadius = 0.24, seed = 2 }) },
	})
	rig:ball("Head", "Nose", v3(0, 1.53, -1.66), 0.08, P.nose)
	rig:mirrored(function(side, sfx)
		A.eye(rig, "Head", A.mx(v3(0.16, 1.68, -1.42), side), v3(side * 0.6, 0.1, -1), 0.13, "Slit", P.socket, P.eye, P.pupil)
		A.brow(rig, "Head", side, v3(0.15, 1.78, -1.42), 0.2, 24, P.coat[4])
		A.ear(rig, "Ear" .. sfx, cf(A.mx(v3(0.16, 1.82, -1.15), side)) * ang(rad(-8), side * rad(-18), side * rad(-20)), 0.3, 0.4, P.coat[2], P.inner, P.stripe)
		A.whiskers(rig, "Head", side, v3(0.12, 1.5, -1.58), 0.6, P.whisker)
		for k = 0, 2 do
			rig:strut("Head", "Stripe", A.mx(v3(0.08 + k * 0.06, 1.86 - k * 0.02, -1.36 + k * 0.08), side), A.mx(v3(0.2 + k * 0.05, 1.8 - k * 0.04, -1.22 + k * 0.08), side), 0.035, 0.025, P.stripe)
		end
		rig:thorn("Head", "Fang", cf(A.mx(v3(0.05, 1.44, -1.6), side)) * ang(math.pi, 0, 0), 0.03, 0.07, P.whisker)
	end)

	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, L in { F = { v3(0.24, 1.15, -0.6), v3(0.26, 0.6, -0.62), v3(0.26, 0.14, -0.68), 0.15 }, B = { v3(0.26, 1.2, 0.5), v3(0.3, 0.72, 0.7), v3(0.28, 0.14, 0.58), 0.24 } } do
			local bone = "Leg_" .. key .. s
			A.limb(rig, bone, side, { { L[1], L[4], L[4] * 1.15 }, { L[2], 0.09, 0.09 }, { L[3], 0.07, 0.07 } }, P.core, A.scales(P.coat, v3(0.12, 0.04, 0.14), 0.1, { arc = 180, refRadius = 0.12, seed = 10 + side }))
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
		cover = { A.scales(P.coat, v3(0.12, 0.04, 0.14), 0.1, { arc = 180, refRadius = 0.11, seed = 5 }) },
	})
	local tipCF = A.alongUp(TAIL:pos(6), TAIL:pos(6) - TAIL:pos(5) + v3(0, 0.3, 0))
	A.flame(rig, tail[5], tipCF, 0.5, 0.22, P.flameOut, P.flameMid, P.flameCore)

	A.orbit(rig, "Aura1", v3(0, 1.5, 0), 1.9, 4, 0.35, function(bone, c)
		rig:cylinder(bone, "JadeCoin", c.Position - c.LookVector * 0.03, c.Position + c.LookVector * 0.03, 0.36, P.orb)
		A.flatRing(rig, bone, c.Position, 0.2, 0.04, 0.04, 10, P.orbRing)
	end)

	rig:hitbox(cf(0, 1.3, -0.2), v3(1.4, 2.6, 3.8))

	if rig.effects then
		local sc = rig.scale
		local m = rig:anchor("Body", "FX_Mist", cf(0, 1.0, 0), v3(1.8, 1.2, 3))
		Fx.particles(m, Fx.sparkles("JadeMotes", { rgb(140, 255, 180), rgb(60, 200, 120) }, 8, 0.2), sc)
		Fx.particles(m, Fx.sparkles("GoldDust", { rgb(255, 230, 120) }, 4, 0.14), sc)
		Fx.light(rig.bones.Head, { color = rgb(80, 255, 150), range = 6, brightness = 1 }, sc)
		Fx.light(m, { color = rgb(88, 255, 155), range = 9, brightness = 1.2 }, sc)
	end


	-- Effets avancés : signature, origine de la capacité, aura de rareté
	if rig.effects then
		local tip = TAIL:pos(6)
		Vfx.trail(rig, tail[5], tip + v3(0, 0.06, 0), tip - v3(0, 0.06, 0), { colors = { rgb(133, 255, 182), rgb(34, 160, 84) }, lifetime = 0.5 })
		Vfx.orbitTethers(rig, "Aura1", Vfx.orbitPoints(v3(0, 1.5, 0), 1.9, 4, 0.35), "Body", v3(0, 1.3, 0), { colors = { rgb(125, 255, 177), rgb(34, 160, 84) }, transparency = { 0.4, 0.9 }, width0 = 0.05, width1 = 0.02, curve0 = 0.5 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Epic")
	end

	return rig:finish({ Rarity = "Epic" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Tigre de jade",
	Rarity = "Epic",
	Size = "Medium",
	Income = 900,
	SpeedBonus = 0.28,
	Passenger = false,
	Scale = 2.5,
	Category = "Créature Épique",
	Description = "Tigre sculpté dans le jade : ses rayures s'illuminent d'un vert profond quand il rugit.",
	Icon = { top = rgb(30, 110, 70), bottom = rgb(6, 26, 16), glow = rgb(140, 255, 180), motif = rgb(255, 210, 80), yaw = 34, pitch = 12, zoom = 1.1 },
	Animation = { flicker = 0, gait = "Quadruped", breathe = 0.025, bob = 0.08, stride = 30, strideRate = 11, tailSway = 12, tailRate = 1.4, headLook = 24, earTwitch = true, auraSpeed = 0.6 },
	Ability = ABILITY,
	build = build,
}

return Def
