--!strict
--[[
	LE KIRIN CÉLESTE — Mythique · Moyen
	===================================
	Cheval-dragon aux sabots de nuages.

	• Corps de cheval élancé couvert d'écailles de dragon turquoise -> jade, ventre crème doré.
	• Tête de dragon : cornes ramifiées d'or, longues moustaches, barbiche, crinière de flammes dorées.
	• Crinière de flammes or et blanc le long de l'encolure et du dos, queue de lion enflammée.
	• Sabots posés sur des nuages (boules de nuages blancs et lilas) qui laissent une brume.
	• Perles célestes en orbite ; effets : nuages qui s'effilochent, poussière d'or.
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

local ID = "KirinCeleste"

local P = {
	core = S(rgb(20, 90, 100)),
	scales = { S(rgb(130, 250, 220)), S(rgb(70, 214, 196)), S(rgb(36, 168, 160)), S(rgb(20, 118, 124)) },
	belly = { S(rgb(255, 244, 200)), S(rgb(246, 224, 160)) },
	gold = S(rgb(255, 204, 64)),
	goldDark = S(rgb(214, 140, 30)),
	flameOut = S(rgb(255, 170, 40), M.Neon),
	flameMid = S(rgb(255, 222, 110), M.Neon),
	flameCore = S(rgb(255, 255, 230), M.Neon),
	cloud = { S(rgb(255, 255, 255)), S(rgb(236, 230, 255)), S(rgb(214, 206, 250)) },
	eye = S(rgb(255, 120, 60), M.Neon),
	socket = S(rgb(20, 40, 40)),
	pupil = S(rgb(10, 10, 10)),
	whisker = S(rgb(255, 230, 140), M.Neon),
	tooth = S(rgb(255, 250, 240)),
	pearl = S(rgb(255, 250, 230), M.Neon),
	pearlRing = S(rgb(255, 200, 60), M.Neon, { transparency = 0.3 }),
}

local BODY = Kit.spine({
	{ pos = v3(0, 2.75, -1.35), rx = 0.18, ry = 0.2 },
	{ pos = v3(0, 2.45, -1.1), rx = 0.26, ry = 0.3 },
	{ pos = v3(0, 2.05, -0.75), rx = 0.36, ry = 0.42 },
	{ pos = v3(0, 1.95, -0.2), rx = 0.38, ry = 0.4 },
	{ pos = v3(0, 1.98, 0.35), rx = 0.4, ry = 0.4 },
	{ pos = v3(0, 1.9, 0.75), rx = 0.28, ry = 0.28 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 2.62, -2.08), rx = 0.1, ry = 0.08 },
	{ pos = v3(0, 2.7, -1.88), rx = 0.17, ry = 0.14 },
	{ pos = v3(0, 2.82, -1.6), rx = 0.24, ry = 0.22 },
	{ pos = v3(0, 2.86, -1.38), rx = 0.22, ry = 0.24 },
})

local TAIL = Kit.spine({
	{ pos = v3(0, 1.98, 0.8), rx = 0.1, ry = 0.1 },
	{ pos = v3(0, 1.8, 1.2), rx = 0.09, ry = 0.09 },
	{ pos = v3(0.05, 1.6, 1.6), rx = 0.08, ry = 0.08 },
	{ pos = v3(0.15, 1.55, 2.0), rx = 0.06, ry = 0.06 },
	{ pos = v3(0.22, 1.7, 2.3), rx = 0.04, ry = 0.04 },
})

local ABILITY: Types.Ability = {
	name = "Galop céleste",
	kind = "Burst",
	colors = { rgb(255, 230, 140), rgb(90, 220, 200), rgb(255, 255, 255) },
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

	rig:bone("Body", "Root", cf(0, 1.95, 0))
	rig:bone("Head", "Body", cf(0, 2.8, -1.4))
	rig:bone("Jaw", "Head", cf(0, 2.66, -1.62))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.22, 1.85, -0.6))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.24, 1.88, 0.5))
		rig:bone("Ear" .. sfx, "Head", cf(side * 0.18, 3.02, -1.42))
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
		coreStep = 0.24,
		cover = {
			A.scales(P.scales, v3(0.22, 0.07, 0.26), 0.16, { arc = 125, tilt = 18, refRadius = 0.35, seed = 1 }),
			A.scales(P.belly, v3(0.26, 0.05, 0.2), 0.16, { arc = 55, center = 180, tilt = 6, refRadius = 0.35, seed = 2 }),
		},
	})
	-- Crinière de flammes dorées (encolure et dos)
	do
		local s0, s1, i = BODY:lengthAt(1.0), BODY:lengthAt(5.0), 0
		while s0 < s1 do
			local u = BODY:uAt(s0)
			A.flame(rig, "Body", BODY:surface(u, 0, 0.04) * ang(rad(38), 0, 0), 0.5 - i * 0.025, 0.2, P.flameOut, P.flameMid, P.flameCore)
			if u < 3 then
				for _, d in { -40, 40 } do
					A.flame(rig, "Body", BODY:surface(u, d, 0.03) * ang(rad(38), 0, 0), 0.32, 0.14, P.flameOut, P.flameMid, P.flameCore)
				end
			end
			s0 += 0.2
			i += 1
		end
	end
	rig:band(BODY, "Body", "GoldBand", 2.4, 0.08, 0.05, P.gold)
	rig:shard("Body", "ChestPearl", BODY:surface(2.42, 180, 0.06) * ang(math.pi, 0, 0), 0.12, 0.12, 0.1, P.pearl)

	-- Tête de dragon
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.14,
		cover = { A.scales(P.scales, v3(0.13, 0.05, 0.15), 0.1, { arc = 150, refRadius = 0.22, seed = 3 }) },
	})
	rig:prismBetween("Jaw", "Jaw", v3(0, 2.62, -1.6), v3(0, 2.56, -2.0), 0.24, 0.07, 0.03, P.belly[2])
	A.teeth(rig, "Head", v3(-0.08, 2.62, -2.04), v3(0.08, 2.62, -2.04), 4, 0.03, 0.05, P.tooth, true)
	A.tuftBurst(rig, "Jaw", A.alongUp(v3(0, 2.52, -1.85), v3(0, -1, -0.2)), 6, 0.35, 0.1, { P.belly[1] }, P.flameMid, 18, 4)
	rig:mirrored(function(side, sfx)
		A.eye(rig, "Head", A.mx(v3(0.17, 2.94, -1.6), side), v3(side, 0.2, -0.5), 0.1, "Slit", P.socket, P.eye, P.pupil)
		A.brow(rig, "Head", side, v3(0.15, 3.02, -1.62), 0.18, 22, P.scales[4])
		A.ear(rig, "Ear" .. sfx, cf(A.mx(v3(0.18, 3.02, -1.42), side)) * ang(rad(-20), side * rad(-30), side * rad(-50)), 0.18, 0.3, P.scales[2], P.belly[1])
		-- Longues moustaches lumineuses
		local m0 = A.mx(v3(0.1, 2.66, -2.0), side)
		local m1 = A.mx(v3(0.45, 2.5, -2.05), side)
		local m2 = A.mx(v3(0.8, 2.55, -1.8), side)
		rig:strut("Head", "Barbel", m0, m1, 0.035, 0.035, P.whisker)
		rig:strut("Head", "Barbel", m1, m2, 0.025, 0.025, P.whisker)
		-- Cornes ramifiées d'or
		local beam = { A.mx(v3(0.12, 3.05, -1.5), side), A.mx(v3(0.22, 3.35, -1.38), side), A.mx(v3(0.32, 3.62, -1.2), side), A.mx(v3(0.36, 3.82, -0.98), side) }
		local sp = A.horn(rig, "Head", beam, 0.06, 0.02, P.gold)
		for _, t in { { 2.0, v3(0.18, 0.28, -0.12) }, { 2.8, v3(-0.05, 0.3, -0.15) } } do
			local root = sp:pos(t[1])
			local tip = root + A.mx(t[2], side)
			A.horn(rig, "Head", { root, root:Lerp(tip, 0.5) + v3(0, 0.03, 0), tip }, 0.04, 0.015, P.gold)
		end
	end)
	A.flame(rig, "Head", cf(0, 3.0, -1.35) * ang(rad(30), 0, 0), 0.4, 0.16, P.flameOut, P.flameMid, P.flameCore)

	-- Pattes fines aux sabots de nuages
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, L in { F = { v3(0.22, 1.85, -0.6), v3(0.24, 1.15, -0.66), v3(0.24, 0.42, -0.7), 0.17 }, B = { v3(0.24, 1.88, 0.5), v3(0.28, 1.25, 0.66), v3(0.26, 0.42, 0.56), 0.24 } } do
			local bone = "Leg_" .. key .. s
			A.limb(rig, bone, side, { { L[1], L[4], L[4] * 1.15 }, { L[2], 0.08, 0.08 }, { L[3], 0.06, 0.06 } }, P.core, A.scales(P.scales, v3(0.1, 0.04, 0.12), 0.08, { arc = 180, refRadius = 0.1, seed = 10 + side }))
			local hoof = A.mx(L[3] :: Vector3, side)
			rig:prism(bone, "Hoof", cf(hoof - v3(0, 0.08, 0)), v3(0.16, 0.14, 0.18), 0.04, P.gold)
			A.tuftBurst(rig, bone, cf(hoof + v3(0, 0.06, 0)) * ang(math.pi, 0, 0), 6, 0.2, 0.08, { P.flameMid }, P.flameCore, 50, 20 + side)
			-- Nuage sous le sabot
			local rng = Random.new(30 + side * 3 + (if key == "F" then 1 else 2))
			for k = 1, 7 do
				local a = k / 7 * math.pi * 2
				local r = rng:NextNumber(0.12, 0.26)
				local p = hoof + v3(math.cos(a) * 0.2, -0.3 + rng:NextNumber(-0.04, 0.06), math.sin(a) * 0.2)
				rig:ball(bone, "Cloud", p, r * 1.6, P.cloud[(k % 3) + 1])
			end
			rig:ball(bone, "Cloud", hoof - v3(0, 0.22, 0), 0.4, P.cloud[1])
		end
	end)

	-- Queue enflammée
	rig:tube(TAIL, {
		name = "Tail",
		bone = function(u)
			return tail[math.clamp(math.floor(u), 1, #tail)]
		end,
		core = P.core,
		coreStep = 0.12,
		cover = { A.scales(P.scales, v3(0.08, 0.03, 0.1), 0.07, { arc = 180, refRadius = 0.08, seed = 6 }) },
	})
	A.flame(rig, tail[#tail], A.alongUp(TAIL:pos(5), TAIL:pos(5) - TAIL:pos(4)), 0.6, 0.26, P.flameOut, P.flameMid, P.flameCore)
	A.flame(rig, tail[#tail], A.alongUp(TAIL:pos(5), TAIL:pos(5) - TAIL:pos(4)) * ang(rad(30), 0, rad(20)), 0.42, 0.18, P.flameOut, P.flameMid, P.flameCore)

	-- Perles célestes en orbite
	A.orbit(rig, "Aura1", v3(0, 2.3, -0.2), 2.2, 5, 0.35, function(bone, c)
		rig:ball(bone, "Pearl", c.Position, 0.26, P.pearl)
		A.flatRing(rig, bone, c.Position, 0.22, 0.04, 0.03, 10, P.pearlRing)
	end)

	rig:hitbox(cf(0, 1.8, -0.3), v3(1.4, 3.4, 4))

	if rig.effects then
		local sc = rig.scale
		local feet = rig:anchor("Body", "FX_Clouds", cf(0, 0.2, -0.05), v3(1.2, 0.3, 2.2))
		Fx.particles(feet, Fx.mist("CloudTrail", { rgb(255, 255, 255), rgb(220, 210, 255) }, 10, 1.0, 0.1), sc)
		local g = rig:anchor("Body", "FX_Gold", cf(0, 2.4, -0.2), v3(1.2, 1.4, 2.4))
		Fx.particles(g, Fx.sparkles("GoldDust", { rgb(255, 240, 160), rgb(120, 240, 220) }, 8, 0.2), sc)
		Fx.light(g, { color = rgb(255, 220, 140), range = 10, brightness = 1.3 }, sc)
		Vfx.trail(rig, tail[#tail], TAIL:pos(5) + v3(0, 0.08, 0), TAIL:pos(5) - v3(0, 0.08, 0), { colors = { rgb(255, 230, 140), rgb(255, 170, 40) }, lifetime = 0.5 })
		Vfx.orbitTethers(rig, "Aura1", Vfx.orbitPoints(v3(0, 2.3, -0.2), 2.2, 5, 0.35), "Head", v3(0, 3.6, -1.2), { colors = { rgb(255, 230, 150), rgb(90, 220, 200) }, transparency = { 0.35, 0.85 }, width0 = 0.05, width1 = 0.02, curve0 = 0.5 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Mythic")
	end

	return rig:finish({ Rarity = "Mythic" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Kirin céleste",
	Rarity = "Mythic",
	Size = "Medium",
	Income = 50000,
	SpeedBonus = 0.8,
	Passenger = false,
	Scale = 1.9,
	Category = "Créature Mythique",
	Description = "Cheval-dragon sacré aux écailles de jade : ses sabots se posent sur des nuages.",
	Icon = { top = rgb(30, 130, 130), bottom = rgb(6, 30, 34), glow = rgb(255, 230, 140), motif = rgb(130, 250, 220), yaw = 32, pitch = 10, zoom = 1.05 },
	Animation = { gait = "Quadruped", breathe = 0.03, bob = 0.14, stride = 34, strideRate = 11, tailSway = 18, tailRate = 1.6, headLook = 18, earTwitch = true, flicker = 0.2, auraSpeed = 0.5 },
	Ability = ABILITY,
	build = build,
}

return Def
