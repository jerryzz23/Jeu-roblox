--!strict
--[[
	MAMMOUTH RUNIQUE — Épique · Géant
	=================================
	Mammouth aux défenses gravées de runes bleues.
	
	• Énorme corps en longues mèches de laine brune, pattes cerclées de pierre sculptée.
	• Immenses défenses d'ivoire gravées de runes bleues lumineuses, cerclées de bandes Neon.
	• Nacelle de pierre sur le dos : quatre menhirs runiques couronnés de cristaux, cristal central.
	• Pierres runiques en orbite ; effets : brume bleue au sommet des menhirs, étincelles runiques.
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

local ID = "MammouthRunique"

local P = {
	core = S(rgb(70, 46, 30)),
	fur = { S(rgb(150, 106, 70)), S(rgb(124, 86, 56)), S(rgb(98, 66, 44)), S(rgb(74, 50, 34)) },
	tip = S(rgb(196, 160, 116)),
	brass = S(rgb(150, 152, 164), M.Slate),
	brassDark = S(rgb(108, 110, 124), M.Slate),
	gold = S(rgb(150, 152, 164), M.Slate),
	ivory = S(rgb(250, 244, 226)),
	wood = S(rgb(92, 94, 106), M.Slate),
	clock = S(rgb(120, 200, 255), M.Neon),
	hand = S(rgb(30, 20, 14)),
	roof = S(rgb(110, 110, 124), M.Slate),
	light = S(rgb(80, 180, 255), M.Neon),
	eye = S(rgb(110, 200, 255), M.Neon),
	socket = S(rgb(20, 24, 40)),
	pipe = S(rgb(130, 132, 146), M.Slate),
	trunk = S(rgb(96, 64, 42)),
	inner = S(rgb(150, 100, 76)),
	rune = S(rgb(80, 180, 255), M.Neon),
	runeGlass = S(rgb(140, 210, 255), M.Glass, { transparency = 0.2 }),
	stone = S(rgb(140, 142, 156), M.Slate),
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

-- Capacité spéciale (CreatureForge.playAbility)
local ABILITY: Types.Ability = {
	name = "Charge runique",
	kind = "Stomp",
	colors = { rgb(90, 190, 255), rgb(40, 90, 200), rgb(220, 240, 255) },
	texture = "spark",
	radius = 9,
	duration = 1.8,
}

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

	-- Nacelle runique sur le dos : plateforme de pierre, menhirs gravés de runes, cristal flottant
	local deck = BODY:surface(2.6, 0, 0.18)
	rig:prism("Body", "Deck", deck, v3(1.7, 0.18, 1.9), 0.14, P.wood)
	rig:ring("Body", "DeckRim", deck * cf(0, 0.08, 0) * ang(math.pi / 2, 0, 0), 0.86, 0.08, 0.1, 18, P.rune)
	local pipes = {}
	for i, off in { v3(0.66, 0, -0.74), v3(-0.66, 0, -0.74), v3(0.66, 0, 0.74), v3(-0.66, 0, 0.74) } do
		local h = if i <= 2 then 0.85 else 1.15
		local menhir = deck * cf(off + v3(0, h / 2, 0)) * CFrame.lookAt(Vector3.zero, v3(off.X, 0, off.Z))
		rig:prism("Body", "Menhir", menhir, v3(0.3, h, 0.22), 0.07, P.brass)
		A.rune(rig, "Body", menhir * cf(0, 0.04, -0.12), 0.24, P.rune, i)
		A.crystals(rig, "Body", menhir * cf(0, h / 2, 0), 3, 0.32, { P.runeGlass, P.rune }, 40 + i, 0.2)
		table.insert(pipes, menhir * cf(0, h / 2 + 0.2, 0))
	end
	local core = deck * cf(0, 1.25, 0)
	A.crystals(rig, "Body", core * cf(0, -0.25, 0), 5, 0.7, { P.runeGlass, P.rune }, 7, 0.25)
	rig:ring("Body", "RuneHalo", core * cf(0, 0.1, 0) * ang(math.pi / 2, 0, 0), 0.55, 0.05, 0.05, 20, P.rune)

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
		local tsp = A.horn(rig, "Head", tusk, 0.2, 0.05, P.ivory, P.rune, { 1.3, 2.2, 3.2 })
		for k, u in { 1.7, 2.6, 3.5 } do
			A.rune(rig, "Head", tsp:surface(u, side * 90, 0.01) * ang(-math.pi / 2, 0, 0), 0.2 - k * 0.03, P.rune, k + (if side > 0 then 0 else 3))
		end
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
			A.rune(rig, bone, leg:surface(1.7, side * 90, 0.06) * ang(-math.pi / 2, 0, 0), 0.32, P.rune, if side > 0 then 2 else 5)
		end
	end)
	rig:prismBetween("Tail1", "Tail", v3(0, 2.4, 1.6), v3(0, 1.6, 2.0), 0.14, 0.14, 0.04, P.trunk)
	A.tuftBurst(rig, "Tail1", A.alongUp(v3(0, 1.6, 2.0), v3(0, -1, 0.4)), 8, 0.4, 0.14, P.fur, P.tip, 25, 7)

	-- Double halo doré derrière
	A.flatRing(rig, "Body", v3(0, 3.8, 1.6), 0, 0, 0, 3, P.gold) -- (point d'ancrage)

	-- Engrenages en orbite
	A.orbit(rig, "Aura1", v3(0, 2.8, 0), 3.6, 6, 0.6, function(bone, c, i)
		rig:prism(bone, "RuneStone", c * ang(0, math.pi / 2, 0), v3(0.5, 0.78, 0.16), 0.08, P.stone)
		A.rune(rig, bone, c * ang(0, -math.pi / 2, 0) * cf(0, 0, -0.1), 0.36, P.rune, i)
	end)

	rig:hitbox(cf(0, 2.4, -0.5), v3(3, 5, 6))

	if rig.effects then
		local sc = rig.scale
		for i, top in pipes do
			local fx = rig:anchor("Body", "FX_Steam" .. i, top * cf(0, 0.15, 0), v3(0.2, 0.1, 0.2))
			Fx.particles(fx, {
				name = "RuneMist",
				texture = Fx.TEXTURES.smoke,
				colors = { rgb(170, 220, 255), rgb(70, 140, 240) },
				sizes = { 0.2, 0.7 },
				transparencies = { 0.3, 0.6, 1 },
				lifetime = NumberRange.new(1.5, 2.5),
				rate = 4,
				speed = NumberRange.new(0.4, 0.9),
				spread = Vector2.new(12, 12),
				acceleration = v3(0, 0.6, 0),
				drag = 0.6,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-30, 30),
			}, sc)
		end
		local g = rig:anchor("Body", "FX_Sparks", cf(0, 3.4, 0), v3(3, 1.4, 3))
		Fx.particles(g, Fx.sparkles("RuneSparks", { rgb(120, 198, 255), rgb(50, 169, 255) }, 8, 0.24), sc)
		Fx.light(g, { color = rgb(100, 190, 255), range = 16, brightness = 1.6 }, sc)
	end


	-- Effets avancés : signature, origine de la capacité, aura de rareté
	if rig.effects then
		-- Arcs d'énergie entre les engrenages en orbite et la flèche de la tour d'horloge
		local deck = BODY:surface(2.6, 0, 0.18)
		local finial = (deck * cf(0, 1.25, 0)).Position
		Vfx.orbitTethers(rig, "Aura1", Vfx.orbitPoints(v3(0, 2.8, 0), 3.6, 6, 0.6), "Body", finial, { colors = { rgb(120, 198, 255), rgb(40, 165, 255) }, transparency = { 0.25, 0.8 }, width0 = 0.08, width1 = 0.03, curve0 = 1.0 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Epic")
	end

	return rig:finish({ Rarity = "Epic" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Mammouth runique",
	Rarity = "Epic",
	Size = "Giant",
	Income = 1500,
	SpeedBonus = 0.3,
	Passenger = true,
	Scale = 2.3,
	Category = "Créature Épique",
	Description = "Mammouth ancestral aux défenses gravées de runes bleues ; il porte une nacelle de menhirs sur le dos.",
	Icon = { top = rgb(60, 70, 140), bottom = rgb(12, 14, 34), glow = rgb(110, 200, 255), motif = rgb(80, 180, 255), yaw = 34, pitch = 14, zoom = 1.05 },
	Animation = { flicker = 0.12, gait = "Quadruped", breathe = 0.05, bob = 0.08, stride = 18, strideRate = 5, tailSway = 10, tailRate = 2, headLook = 10, earTwitch = true, auraSpeed = 0.35 },
	Ability = ABILITY,
	build = build,
}

return Def
