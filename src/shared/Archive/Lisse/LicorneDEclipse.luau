--!strict
--[[
	LA LICORNE D'ÉCLIPSE — Exclusif · Grand
	=======================================
	Licorne noire avec un anneau de lumière autour de la corne (tapis + roue).

	• Robe noire lustrée aux reflets violets, ventre d'encre, fanons dorés aux sabots.
	• Longue crinière et queue en mèches noir -> violet nuit aux pointes d'or.
	• Corne torsadée noir et or, entourée d'un anneau de lumière (couronne d'éclipse) qui tourne.
	• Disque d'éclipse derrière la tête : soleil noir et couronne de rayons dorés.
	• Harnais noir et or, selle de velours (monture avec passager).
	• Étoiles d'or en orbite ; effets : poussière d'or, halo de l'anneau, traînée de lumière.
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

local ID = "LicorneDEclipse"

local P = {
	core = S(rgb(8, 6, 14)),
	coat = { S(rgb(54, 46, 74), M.SmoothPlastic, { reflectance = 0.12 }), S(rgb(36, 30, 52), M.SmoothPlastic, { reflectance = 0.1 }), S(rgb(24, 20, 36)), S(rgb(14, 12, 22)) },
	mane = { S(rgb(30, 24, 46)), S(rgb(54, 34, 92)), S(rgb(80, 46, 140)) },
	gold = S(rgb(255, 200, 60), M.Metal, { reflectance = 0.1 }),
	goldDark = S(rgb(190, 120, 20), M.Metal),
	light = S(rgb(255, 236, 150), M.Neon),
	lightSoft = S(rgb(255, 220, 120), M.Neon, { transparency = 0.45 }),
	sun = S(rgb(4, 4, 8)),
	velvet = S(rgb(70, 20, 90), M.Fabric),
	eye = S(rgb(255, 214, 90), M.Neon),
	socket = S(rgb(6, 4, 10)),
	pupil = S(rgb(10, 6, 2)),
	nose = S(rgb(20, 16, 26)),
	inner = S(rgb(80, 50, 110)),
	hoof = S(rgb(20, 18, 24)),
}

local BODY = Kit.spine({
	{ pos = v3(0, 2.95, -1.42), rx = 0.2, ry = 0.24 },
	{ pos = v3(0, 2.6, -1.18), rx = 0.28, ry = 0.36 },
	{ pos = v3(0, 2.2, -0.82), rx = 0.42, ry = 0.5 },
	{ pos = v3(0, 2.1, -0.2), rx = 0.44, ry = 0.48 },
	{ pos = v3(0, 2.14, 0.4), rx = 0.46, ry = 0.47 },
	{ pos = v3(0, 2.05, 0.82), rx = 0.32, ry = 0.32 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 2.62, -2.22), rx = 0.14, ry = 0.13 },
	{ pos = v3(0, 2.75, -2.02), rx = 0.18, ry = 0.17 },
	{ pos = v3(0, 2.92, -1.75), rx = 0.21, ry = 0.23 },
	{ pos = v3(0, 3.02, -1.5), rx = 0.21, ry = 0.25 },
})

local TAIL = Kit.spine({
	{ pos = v3(0, 2.2, 0.88), rx = 0.12, ry = 0.12 },
	{ pos = v3(0, 2.0, 1.25), rx = 0.24, ry = 0.24 },
	{ pos = v3(0, 1.6, 1.5), rx = 0.28, ry = 0.28 },
	{ pos = v3(0.05, 1.15, 1.6), rx = 0.24, ry = 0.24 },
	{ pos = v3(0.1, 0.8, 1.6), rx = 0.1, ry = 0.1 },
})

local HORN_BASE, HORN_TIP = v3(0, 3.2, -1.72), v3(0, 3.95, -2.15)

local ABILITY: Types.Ability = {
	name = "Éclipse totale",
	kind = "Nova",
	colors = { rgb(255, 230, 140), rgb(40, 20, 70), rgb(255, 255, 255) },
	texture = "sparkle",
	radius = 9,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 2.1, 0))
	rig:bone("Head", "Body", cf(0, 2.95, -1.5))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.26, 1.95, -0.65))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.28, 2.0, 0.55))
		rig:bone("Ear" .. sfx, "Head", cf(side * 0.13, 3.22, -1.55))
	end)
	local tj = {}
	for i = 1, #TAIL.sections do
		table.insert(tj, TAIL:pos(i))
	end
	local tail = rig:boneChain("Tail", "Body", tj)
	-- Anneau de lumière : os dédié qui tourne lentement autour de la corne
	rig:bone("AuraHorn", "Head", A.alongUp(HORN_BASE:Lerp(HORN_TIP, 0.55), HORN_TIP - HORN_BASE)) -- axe Y = axe de la corne

	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.26,
		cover = { A.scales(P.coat, v3(0.24, 0.06, 0.28), 0.17, { arc = 180, tilt = 14, refRadius = 0.4, seed = 1 }) },
	})
	-- Crinière le long de l'encolure
	do
		local s0, s1, i = BODY:lengthAt(1.0), BODY:lengthAt(3.3), 0
		while s0 < s1 do
			local u = BODY:uAt(s0)
			for _, d in { -25, 25 } do
				A.tuftBurst(rig, "Body", BODY:surface(u, d * 1.6, 0.02) * ang(rad(40), 0, 0), 2, 0.6, 0.14, P.mane, P.gold, 20, 10 + i)
			end
			s0 += 0.13
			i += 1
		end
	end
	-- Harnais et selle
	rig:band(BODY, "Body", "Breastcollar", 2.3, 0.1, 0.05, P.gold)
	local saddle = BODY:surface(4.35, 0, 0.1)
	rig:prism("Body", "Saddle", saddle, v3(0.85, 0.14, 1.0), 0.06, P.velvet)
	rig:mirrored(function(side)
		local flap = saddle * cf(side * 0.48, -0.26, 0) * ang(0, 0, side * rad(62))
		rig:prism("Body", "SaddleFlap", flap, v3(0.5, 0.05, 0.8), 0.03, P.velvet)
		rig:block("Body", "SaddleTrim", flap * cf(0, 0, 0.4), v3(0.52, 0.06, 0.05), P.gold)
	end)
	rig:prism("Body", "SaddleBack", saddle * cf(0, 0.2, 0.46) * ang(rad(-14), 0, 0), v3(0.7, 0.28, 0.08), 0.04, P.gold)
	rig:seat("Body", saddle * cf(0, 0.16, -0.1), v3(0.7, 0.2, 0.7))

	-- Tête
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.14,
		cover = { A.scales(P.coat, v3(0.13, 0.05, 0.15), 0.1, { arc = 160, refRadius = 0.2, seed = 2 }) },
	})
	rig:ball("Head", "Muzzle", v3(0, 2.62, -2.2), 0.26, P.nose)
	A.tuftBurst(rig, "Head", cf(0, 3.15, -1.62) * ang(rad(-50), 0, 0), 6, 0.45, 0.12, P.mane, P.gold, 25, 3)
	rig:mirrored(function(side, sfx)
		A.eye(rig, "Head", A.mx(v3(0.17, 2.98, -1.82), side), v3(side, 0.15, -0.45), 0.1, "Round", P.socket, P.eye, P.pupil)
		A.brow(rig, "Head", side, v3(0.15, 3.06, -1.84), 0.16, 20, P.coat[4])
		A.ear(rig, "Ear" .. sfx, cf(A.mx(v3(0.13, 3.22, -1.55), side)) * ang(rad(-6), side * rad(-15), side * rad(-12)), 0.16, 0.32, P.coat[2], P.inner, P.gold)
		rig:strut("Head", "Bridle", A.mx(v3(0.15, 2.72, -2.08), side), A.mx(v3(0.2, 3.05, -1.62), side), 0.03, 0.03, P.gold)
		rig:ball("Head", "BridleStud", A.mx(v3(0.17, 2.78, -2.02), side), 0.07, P.gold)
	end)
	-- Corne torsadée noir et or
	local horn = A.horn(rig, "Head", { HORN_BASE, HORN_BASE:Lerp(HORN_TIP, 0.35), HORN_BASE:Lerp(HORN_TIP, 0.7), HORN_TIP }, 0.09, 0.02, P.sun, P.gold, { 1.35, 1.8, 2.25, 2.7, 3.15 })
	rig:thorn("Head", "HornTip", A.alongUp(HORN_TIP, HORN_TIP - HORN_BASE), 0.05, 0.18, P.light)
	-- Anneau de lumière (os AuraHorn : tourne avec les orbites)
	local ringCF = A.alongUp(HORN_BASE:Lerp(HORN_TIP, 0.55), HORN_TIP - HORN_BASE) * ang(math.pi / 2, 0, 0)
	rig:ring("AuraHorn", "LightRing", ringCF, 0.3, 0.05, 0.03, 20, P.light)
	rig:ring("AuraHorn", "LightRingHalo", ringCF, 0.36, 0.06, 0.02, 20, P.lightSoft)
	for k = 0, 5 do
		rig:ball("AuraHorn", "RingStar", (ringCF * ang(0, 0, k / 6 * math.pi * 2) * cf(0, 0.33, 0)).Position, 0.07, P.light)
	end
	-- Disque d'éclipse derrière la tête : soleil noir + couronne de rayons
	local disc = cf(0, 3.3, -1.25) * ang(rad(-15), 0, 0)
	rig:cylinder("Head", "BlackSun", (disc * cf(0, 0, 0.02)).Position, (disc * cf(0, 0, -0.02)).Position, 0.9, P.sun)
	rig:ring("Head", "Corona", disc, 0.48, 0.05, 0.03, 24, P.light)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		rig:spike("Head", "CoronaRay", disc * ang(0, 0, a) * cf(0, 0.5, 0), 0.08, if k % 2 == 0 then 0.32 else 0.2, 0.02, P.gold)
	end

	-- Pattes fines aux fanons d'or
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, L in { F = { v3(0.26, 1.95, -0.65), v3(0.28, 1.15, -0.7), v3(0.28, 0.32, -0.74), 0.2 }, B = { v3(0.28, 2.0, 0.55), v3(0.32, 1.25, 0.72), v3(0.3, 0.32, 0.62), 0.28 } } do
			local bone = "Leg_" .. key .. s
			A.limb(rig, bone, side, { { L[1], L[4], L[4] * 1.15 }, { L[2], 0.1, 0.1 }, { L[3], 0.08, 0.08 } }, P.core, A.scales(P.coat, v3(0.1, 0.04, 0.12), 0.08, { arc = 180, refRadius = 0.1, seed = 10 + side }))
			A.hoof(rig, bone, A.mx((L[3] :: Vector3) - v3(0, 0.3, 0), side), 0.24, P.hoof, P.gold, P.gold, { P.mane[2], P.gold })
		end
	end)

	-- Queue
	rig:tube(TAIL, {
		name = "Tail",
		bone = function(u)
			return tail[math.clamp(math.floor(u), 1, #tail)]
		end,
		core = P.core,
		coreStep = 0.16,
		cover = { A.fur(P.mane, P.gold, v3(0.16, 0.42, 0.3), 0.14, { arc = 180, tilt = 70, refRadius = 0.2, seed = 6 }) },
	})

	-- Étoiles d'or en orbite
	A.orbit(rig, "Aura1", v3(0, 2.6, -0.2), 2.6, 6, 0.4, function(bone, c, i)
		rig:block(bone, "GoldStar", c, v3(0.08, 0.5, 0.08), P.light)
		rig:block(bone, "GoldStar", c * ang(0, 0, math.pi / 2), v3(0.08, 0.5, 0.08), P.light)
		rig:ball(bone, "GoldStarCore", c.Position, 0.16, P.gold)
	end)

	rig:hitbox(cf(0, 2.0, -0.3), v3(1.4, 4, 4))

	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Body", "FX_Eclipse", cf(0, 2.6, -0.3), v3(1.4, 1.6, 2.6))
		Fx.particles(g, Fx.sparkles("GoldDust", { rgb(255, 240, 170), rgb(255, 190, 60) }, 10, 0.2), sc)
		Fx.particles(g, Fx.mist("NightMist", { rgb(60, 30, 100), rgb(6, 4, 12) }, 6, 1.4, 0.1), sc)
		local ring = rig:anchor("AuraHorn", "FX_Ring", ringCF, v3(0.5, 0.5, 0.1))
		Fx.particles(ring, Fx.sparkles("RingSparks", { rgb(255, 250, 210), rgb(255, 210, 100) }, 12, 0.14, 0.1), sc)
		Fx.light(ring, { color = rgb(255, 230, 150), range = 10, brightness = 1.8 }, sc)
		Vfx.trail(rig, "Head", HORN_TIP + v3(0, 0.06, 0), HORN_TIP - v3(0, 0.06, 0), { colors = { rgb(255, 245, 190), rgb(255, 190, 60) }, lifetime = 0.5 })
		Vfx.orbitTethers(rig, "Aura1", Vfx.orbitPoints(v3(0, 2.6, -0.2), 2.6, 6, 0.4), "Head", HORN_TIP, { colors = { rgb(255, 240, 170), rgb(200, 140, 30) }, transparency = { 0.35, 0.85 }, width0 = 0.05, width1 = 0.02, curve0 = 0.5 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Exclusive")
	end

	return rig:finish({ Rarity = "Exclusive" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Licorne d'éclipse",
	Rarity = "Exclusive",
	Size = "Large",
	Income = 8000000,
	SpeedBonus = 2.0,
	Passenger = true,
	Source = "TapisEtRoue",
	Scale = 2.6,
	Category = "Créature Exclusive",
	Description = "Licorne noire née pendant une éclipse : un anneau de lumière tourne autour de sa corne.",
	Icon = { top = rgb(40, 30, 60), bottom = rgb(4, 2, 8), glow = rgb(255, 220, 120), motif = rgb(255, 200, 60), yaw = 30, pitch = 8, zoom = 1.05 },
	Animation = { gait = "Quadruped", breathe = 0.03, bob = 0.14, stride = 34, strideRate = 10, tailSway = 14, tailRate = 1.4, headLook = 16, earTwitch = true, auraSpeed = 0.6 },
	Ability = ABILITY,
	build = build,
}

return Def
