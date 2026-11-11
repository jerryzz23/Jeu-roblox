--!strict
--[[
	LE MAMMOUTH STEAMPUNK — Mythique · Les Grottes de Cristal
	=========================================================
	Mammouth mécanique recouvert d'une fourrure sculptée, surmonté d'une tour d'horloge,
	entouré d'engrenages et de tuyaux à vapeur.

	• Énorme corps en longues mèches de fourrure brune, plaques de laiton rivetées sur les pattes.
	• Tour d'horloge sur le dos : cadrans Neon sur 4 faces, toit doré, flèche,
	  deux cheminées-tuyaux qui crachent de la vapeur.
	• Trompe annelée de bagues de laiton, défenses d'ivoire cerclées de laiton,
	  yeux mécaniques Neon cerclés de laiton, grandes oreilles.
	• Double halo doré derrière lui, 6 engrenages en orbite, voyants triangulaires Neon.
	• Effets : vapeur, étincelles dorées, lueur.
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

local ID = "MammouthSteampunk"

local P = {
	core = S(rgb(70, 42, 22)),
	fur = { S(rgb(160, 104, 56)), S(rgb(132, 82, 42)), S(rgb(104, 62, 32)), S(rgb(78, 46, 24)) },
	tip = S(rgb(206, 150, 86)),
	brass = S(rgb(226, 170, 60), M.Metal, { reflectance = 0.05 }),
	brassDark = S(rgb(170, 112, 34), M.Metal),
	gold = S(rgb(255, 204, 64)),
	ivory = S(rgb(250, 244, 226)),
	wood = S(rgb(110, 64, 34), M.Wood),
	clock = S(rgb(255, 240, 150), M.Neon),
	hand = S(rgb(30, 20, 14)),
	roof = S(rgb(230, 170, 50)),
	light = S(rgb(255, 230, 40), M.Neon),
	eye = S(rgb(255, 210, 60), M.Neon),
	socket = S(rgb(30, 20, 10)),
	pipe = S(rgb(190, 140, 60), M.Metal),
	trunk = S(rgb(96, 60, 32)),
	inner = S(rgb(150, 96, 70)),
}

local BODY = Kit.spine({
	{ pos = v3(0, 2.7, -1.6), rx = 0.72, ry = 0.76 },
	{ pos = v3(0, 2.92, -1.0), rx = 1.2, ry = 1.25 },
	{ pos = v3(0, 2.76, -0.2), rx = 1.25, ry = 1.15 },
	{ pos = v3(0, 2.6, 0.6), rx = 1.15, ry = 1.05 },
	{ pos = v3(0, 2.3, 1.3), rx = 0.8, ry = 0.75 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 2.15, -2.62), rx = 0.5, ry = 0.55 },
	{ pos = v3(0, 2.62, -2.38), rx = 0.8, ry = 0.8 },
	{ pos = v3(0, 3.0, -2.0), rx = 0.85, ry = 0.85 },
	{ pos = v3(0, 3.05, -1.6), rx = 0.72, ry = 0.75 },
})

local TRUNK = Kit.spine({
	{ pos = v3(0, 2.1, -2.75), rx = 0.34, ry = 0.34 },
	{ pos = v3(0, 1.6, -3.0), rx = 0.3, ry = 0.3 },
	{ pos = v3(0, 1.0, -2.95), rx = 0.26, ry = 0.26 },
	{ pos = v3(0, 0.55, -2.75), rx = 0.21, ry = 0.21 },
	{ pos = v3(0, 0.38, -2.45), rx = 0.16, ry = 0.16 },
	{ pos = v3(0, 0.5, -2.22), rx = 0.12, ry = 0.12 },
})

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 2.7, 0))
	rig:bone("Head", "Body", cf(0, 2.8, -1.7))
	rig:bone("Tail1", "Body", cf(0, 2.4, 1.6))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.75, 2.2, -0.85))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.75, 2.2, 0.75))
		rig:bone("Ear" .. sfx, "Head", cf(side * 0.75, 3.1, -1.8))
	end)
	local tj = {}
	for i = 1, #TRUNK.sections do
		table.insert(tj, TRUNK:pos(i))
	end
	local trunk = rig:boneChain("Trunk", "Head", tj)

	-- Fourrure sculptée (longues mèches)
	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.4,
		cover = { A.fur(P.fur, P.tip, v3(0.34, 0.7, 0.5), 0.26, { arc = 175, tilt = 58, refRadius = 1.0, seed = 1 }) },
	})

	-- Tour d'horloge sur le dos
	local deck = BODY:surface(2.6, 0, 0.18)
	rig:prism("Body", "Deck", deck * cf(0, 0, 0), v3(1.4, 0.16, 1.3), 0.12, P.wood)
	rig:ring("Body", "DeckRim", deck * cf(0, 0.06, 0) * ang(math.pi / 2, 0, 0), 0.72, 0.08, 0.1, 16, P.brass)
	local tower = deck * cf(0, 0.9, 0)
	rig:prism("Body", "Tower", tower, v3(0.9, 0.9, 1.5) * v3(1, 1, 1), 0.12, P.wood)
	rig:prism("Body", "Tower", tower * ang(-math.pi / 2, 0, 0), v3(0.9, 0.9, 1.6), 0.12, P.wood)
	for i = 0, 3 do
		local face = tower * ang(0, i * math.pi / 2, 0) * cf(0, 0.25, -0.47)
		rig:cylinder("Body", "ClockFace", (face * cf(0, 0, 0.04)).Position, (face * cf(0, 0, -0.04)).Position, 0.62, P.clock)
		rig:ring("Body", "ClockRim", face * cf(0, 0, -0.03), 0.32, 0.06, 0.06, 14, P.gold)
		rig:block("Body", "ClockHand", face * cf(0, 0.1, -0.06) * ang(0, 0, rad(15)), v3(0.04, 0.24, 0.02), P.hand)
		rig:block("Body", "ClockHand", face * cf(0.07, 0, -0.06) * ang(0, 0, rad(-70)), v3(0.04, 0.16, 0.02), P.hand)
	end
	local roof = tower * cf(0, 0.8, 0)
	rig:prism("Body", "RoofBase", roof * ang(-math.pi / 2, 0, 0), v3(1.1, 1.1, 0.12), 0.14, P.gold)
	rig:thorn("Body", "Roof", roof * cf(0, 0.06, 0) * ang(0, rad(45), 0), 1.0, 0.85, P.roof)
	rig:ball("Body", "Finial", (roof * cf(0, 0.95, 0)).Position, 0.14, P.gold)
	rig:thorn("Body", "Finial", roof * cf(0, 0.98, 0), 0.06, 0.3, P.gold)
	-- Tuyaux à vapeur
	local pipes = {}
	rig:mirrored(function(side)
		local base = deck * cf(side * 0.55, 0.08, 0.45)
		local top = base * cf(0, 1.0, 0)
		rig:cylinder("Body", "SteamPipe", base.Position, top.Position, 0.22, P.pipe)
		rig:cylinder("Body", "PipeRim", (top * cf(0, -0.04, 0)).Position, (top * cf(0, 0.08, 0)).Position, 0.3, P.brassDark)
		rig:cylinder("Body", "PipeRim", (base * cf(0, 0.4, 0)).Position, (base * cf(0, 0.48, 0)).Position, 0.28, P.brassDark)
		table.insert(pipes, top)
	end)

	-- Voyants triangulaires et plaques rivetées sur les flancs
	rig:mirrored(function(side)
		for k, u in { 2.0, 2.8, 3.6, 4.3 } do
			local c = BODY:surface(u, side * 110, 0.12)
			rig:spike("Body", "Indicator", c * ang(-math.pi / 2, 0, 0) * ang(0, 0, if k % 2 == 0 then math.pi else 0), 0.26, 0.24, 0.04, P.light)
		end
	end)

	-- Tête, yeux mécaniques, oreilles
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.3,
		cover = { A.fur(P.fur, P.tip, v3(0.28, 0.5, 0.4), 0.22, { arc = 150, from = 2.0, tilt = 55, refRadius = 0.8, seed = 2 }) },
	})
	rig:mirrored(function(side, sfx)
		local eyePos = A.mx(v3(0.55, 2.9, -2.4), side)
		A.eye(rig, "Head", eyePos, v3(side, 0.1, -0.7), 0.2, "Glow", P.socket, P.eye)
		rig:ring("Head", "EyeRim", Kit.lookAlong(eyePos + v3(side * 0.05, 0, -0.05), v3(side, 0.1, -0.7)), 0.16, 0.05, 0.06, 12, P.brass)
		local ear = cf(A.mx(v3(0.75, 3.1, -1.8), side)) * ang(rad(-10), side * rad(-70), side * rad(-80))
		A.ear(rig, "Ear" .. sfx, ear, 0.9, 0.85, P.fur[3], P.inner, P.fur[4])
		-- Défenses cerclées de laiton
		local tusk = {
			A.mx(v3(0.45, 2.05, -2.55), side),
			A.mx(v3(0.8, 1.45, -3.0), side),
			A.mx(v3(1.0, 1.3, -3.6), side),
			A.mx(v3(0.9, 1.8, -4.05), side),
			A.mx(v3(0.6, 2.35, -3.95), side),
		}
		A.horn(rig, "Head", tusk, 0.2, 0.05, P.ivory, P.brass, { 1.3, 2.2, 3.2 })
	end)

	-- Trompe annelée
	rig:tube(TRUNK, {
		name = "Trunk",
		bone = function(u)
			return trunk[math.clamp(math.floor(u), 1, #trunk)]
		end,
		core = P.trunk,
		coreStep = 0.18,
	})
	for u = 1.4, 5.6, 0.45 do
		local rx = TRUNK:radii(u)
		rig:band(TRUNK, trunk[math.clamp(math.floor(u), 1, #trunk)], "TrunkRing", u, rx * 0.5, 0.06, P.brass)
	end

	-- Pattes-colonnes plaquées de laiton
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, z in { F = -0.85, B = 0.75 } do
			local bone = "Leg_" .. key .. s
			local leg = A.limb(rig, bone, side, {
				{ v3(0.75, 2.25, z), 0.55, 0.6 },
				{ v3(0.8, 1.2, z), 0.45, 0.45 },
				{ v3(0.8, 0.3, z), 0.44, 0.44 },
			}, P.core, A.fur(P.fur, P.tip, v3(0.3, 0.6, 0.44), 0.24, { arc = 180, tilt = 62, to = 2.3, refRadius = 0.5, seed = 10 + side }))
			rig:band(leg, bone, "BrassPlate", 2.55, 0.28, 0.1, P.brass, P.brassDark)
			rig:band(leg, bone, "BrassPlate", 2.85, 0.12, 0.1, P.brassDark)
			rig:prism(bone, "Foot", cf(A.mx(v3(0.8, 0.14, z - 0.02), side)) * ang(-math.pi / 2, 0, 0), v3(1.0, 1.0, 0.28), 0.3, P.brassDark)
			A.gear(rig, bone, leg:surface(1.7, side * 90, 0.06) * ang(-math.pi / 2, 0, 0), 0.2, 8, 0.06, P.gold)
		end
	end)
	rig:prismBetween("Tail1", "Tail", v3(0, 2.4, 1.6), v3(0, 1.6, 2.0), 0.14, 0.14, 0.04, P.trunk)
	A.tuftBurst(rig, "Tail1", A.alongUp(v3(0, 1.6, 2.0), v3(0, -1, 0.4)), 8, 0.4, 0.14, P.fur, P.tip, 25, 7)

	-- Double halo doré derrière
	A.flatRing(rig, "Body", v3(0, 3.8, 1.6), 0, 0, 0, 3, P.gold) -- (point d'ancrage)
	for k, r in { 2.9, 2.5 } do
		rig:ring("Body", "Halo", cf(0, 3.7, 1.9 + k * 0.08), r, if k == 1 then 0.16 else 0.08, 0.12, 40, if k == 1 then P.gold else P.brassDark)
	end
	-- Engrenages en orbite
	A.orbit(rig, "Aura1", v3(0, 2.8, 0), 3.6, 6, 0.6, function(bone, c, i)
		A.gear(rig, bone, c * ang(0, math.pi / 2, 0) * ang(0, 0, i), 0.42 + (i % 2) * 0.12, 10, 0.12, P.gold, P.brassDark)
	end)

	rig:hitbox(cf(0, 2.4, -0.5), v3(3, 5, 6))

	if rig.effects then
		local sc = rig.scale
		for i, top in pipes do
			local fx = rig:anchor("Body", "FX_Steam" .. i, top * cf(0, 0.15, 0), v3(0.2, 0.1, 0.2))
			Fx.particles(fx, {
				name = "Steam",
				texture = Fx.TEXTURES.smoke,
				colors = { rgb(255, 255, 255), rgb(200, 200, 210) },
				sizes = { 0.4, 1.4 },
				transparencies = { 0.3, 0.6, 1 },
				lifetime = NumberRange.new(1.5, 2.5),
				rate = 8,
				speed = NumberRange.new(1, 2),
				spread = Vector2.new(12, 12),
				acceleration = v3(0, 0.6, 0),
				drag = 0.6,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-30, 30),
			}, sc)
		end
		local g = rig:anchor("Body", "FX_Sparks", cf(0, 3.4, 0), v3(3, 1.4, 3))
		Fx.particles(g, Fx.sparkles("GoldSparks", { rgb(255, 230, 120), rgb(255, 180, 50) }, 8, 0.24), sc)
		Fx.light(g, { color = rgb(255, 210, 100), range = 16, brightness = 1.6 }, sc)
	end

	return rig:finish({ Rarity = "Mythic" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Mammouth Steampunk",
	Rarity = "Mythic",
	Zone = "GrottesCristal",
	Scale = 2.6,
	Category = "Créature Mythique",
	Description = "Mammouth mécanique surmonté d'une tour d'horloge, entouré d'engrenages et de vapeur.",
	Icon = { top = rgb(150, 100, 40), bottom = rgb(40, 24, 10), glow = rgb(255, 220, 120), motif = rgb(255, 204, 64), yaw = 34, pitch = 14, zoom = 1.05 },
	Animation = { gait = "Quadruped", breathe = 0.05, bob = 0.08, stride = 18, strideRate = 5, tailSway = 10, tailRate = 2, headLook = 10, earTwitch = true, auraSpeed = 0.35 },
	build = build,
}

return Def
