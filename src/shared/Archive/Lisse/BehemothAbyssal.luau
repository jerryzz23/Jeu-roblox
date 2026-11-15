--!strict
--[[
	LE BÉHÉMOTH ABYSSAL — Exclusif · Colossal
	=========================================
	Monstre des profondeurs aux lumières bleues (roue uniquement).

	• Corps de baleine cuirassée sur quatre pattes trapues : plaques bleu nuit, ventre strié gris-bleu.
	• Immense gueule aux rangées de dents-aiguilles, gorge qui luit d'un bleu profond.
	• Leurre lumineux au bout d'une antenne (poisson-lanterne), six petits yeux Neon bleu pâle.
	• Rangées de photophores bleus le long des flancs, crête dorsale, nageoires et nageoire caudale.
	• Barbillons ondulants sous la mâchoire (os "Sway") ; selle sur le dos (passager).
	• Orbes abyssaux en orbite ; effets : bulles, brume des profondeurs, lueurs bleues.
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

local ID = "BehemothAbyssal"

local P = {
	core = S(rgb(6, 10, 26)),
	plates = { S(rgb(44, 62, 110)), S(rgb(30, 44, 86)), S(rgb(20, 30, 62)), S(rgb(12, 18, 40)) },
	belly = { S(rgb(120, 140, 170)), S(rgb(92, 110, 140)) },
	fin = S(rgb(20, 40, 90), M.Glass, { transparency = 0.25 }),
	finBone = S(rgb(14, 22, 50)),
	light = S(rgb(70, 200, 255), M.Neon),
	lightSoft = S(rgb(120, 230, 255), M.Neon, { transparency = 0.4 }),
	lure = S(rgb(200, 250, 255), M.Neon),
	lureGlass = S(rgb(120, 220, 255), M.Glass, { transparency = 0.4 }),
	tooth = S(rgb(230, 240, 255)),
	maw = S(rgb(10, 40, 90), M.Neon),
	gum = S(rgb(30, 20, 50)),
	eye = S(rgb(170, 240, 255), M.Neon),
	socket = S(rgb(4, 8, 20)),
	claw = S(rgb(170, 190, 220)),
	saddle = S(rgb(30, 40, 70), M.Fabric),
}

local BODY = Kit.spine({
	{ pos = v3(0, 2.45, -2.35), rx = 0.85, ry = 0.7 },
	{ pos = v3(0, 2.7, -1.5), rx = 1.3, ry = 1.15 },
	{ pos = v3(0, 2.75, -0.4), rx = 1.45, ry = 1.25 },
	{ pos = v3(0, 2.65, 0.7), rx = 1.25, ry = 1.1 },
	{ pos = v3(0, 2.4, 1.7), rx = 0.85, ry = 0.78 },
	{ pos = v3(0, 2.2, 2.5), rx = 0.48, ry = 0.42 },
	{ pos = v3(0, 2.1, 3.1), rx = 0.22, ry = 0.2 },
})

local ABILITY: Types.Ability = {
	name = "Rugissement abyssal",
	kind = "Nova",
	colors = { rgb(80, 210, 255), rgb(10, 30, 90), rgb(220, 250, 255) },
	texture = "sparkle",
	radius = 11,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 2.6, 0))
	rig:bone("Head", "Body", cf(0, 2.75, -1.6))
	rig:bone("Jaw", "Head", cf(0, 2.0, -1.5))
	rig:bone("Tail1", "Body", cf(0, 2.2, 2.3))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.95, 2.0, -0.9))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.9, 2.0, 1.1))
	end)

	rig:tube(BODY, {
		name = "Body",
		bone = function(u)
			return if u < 2.3 then "Head" elseif u > 5.6 then "Tail1" else "Body"
		end,
		core = P.core,
		coreStep = 0.45,
		cover = {
			A.scales(P.plates, v3(0.6, 0.18, 0.56), 0.46, { arc = 120, tilt = 10, jitter = 0.35, refRadius = 1.0, seed = 1 }),
			A.scales(P.belly, v3(0.7, 0.08, 0.3), 0.36, { arc = 60, center = 180, tilt = 2, refRadius = 1.0, seed = 2 }),
		},
	})
	-- Photophores : rangées de lumières bleues le long des flancs
	rig:mirrored(function(side)
		for row, deg in { 95, 125 } do
			local s0, s1, i = BODY:lengthAt(1.3), BODY:lengthAt(6.2), 0
			while s0 < s1 do
				local u = BODY:uAt(s0)
				local c = BODY:surface(u, side * deg, 0.1)
				rig:ball(if u < 2.3 then "Head" elseif u > 5.6 then "Tail1" else "Body", "Photophore", c.Position, if i % 3 == 0 then 0.2 else 0.13, if (i + row) % 4 == 0 then P.lure else P.light)
				s0 += 0.42
				i += 1
			end
		end
	end)
	A.crest(rig, BODY, function(u)
		return if u < 2.3 then "Head" elseif u > 5.6 then "Tail1" else "Body"
	end, 1.8, 6.4, 0.5, 0.55, 0.3, P.finBone, P.light, 0, 30)

	-- Selle sur le dos
	local saddle = BODY:surface(3.7, 0, 0.16)
	rig:prism("Body", "Saddle", saddle, v3(1.0, 0.16, 1.3), 0.08, P.saddle)
	rig:prism("Body", "SaddleBack", saddle * cf(0, 0.22, 0.62) * ang(rad(-14), 0, 0), v3(0.9, 0.34, 0.12), 0.05, P.plates[4])
	rig:block("Body", "SaddleLight", saddle * cf(0, 0.09, 0), v3(1.02, 0.04, 0.05), P.light)
	rig:seat("Body", saddle * cf(0, 0.18, -0.2), v3(0.8, 0.2, 0.8))

	-- Gueule : mâchoire inférieure, gorge lumineuse, dents-aiguilles
	rig:prismBetween("Jaw", "Jaw", v3(0, 2.0, -1.2), v3(0, 1.85, -2.85), 1.5, 0.3, 0.12, P.plates[3])
	rig:prismBetween("Jaw", "JawBelly", v3(0, 1.82, -1.3), v3(0, 1.72, -2.75), 1.3, 0.12, 0.06, P.belly[2])
	rig:prismBetween("Head", "Maw", v3(0, 2.2, -1.3), v3(0, 2.1, -2.6), 1.2, 0.3, 0.1, P.maw)
	rig:mirrored(function(side)
		A.teeth(rig, "Head", A.mx(v3(0.1, 2.12, -2.85), side), A.mx(v3(0.72, 2.18, -1.55), side), 9, 0.07, 0.3, P.tooth, true)
		A.teeth(rig, "Jaw", A.mx(v3(0.12, 2.0, -2.8), side), A.mx(v3(0.7, 2.06, -1.5), side), 8, 0.06, 0.26, P.tooth, false)
		-- Six petits yeux
		for k = 0, 2 do
			A.eye(rig, "Head", A.mx(v3(0.62 + k * 0.12, 2.85 + k * 0.1, -2.15 + k * 0.28), side), v3(side, 0.2, -0.4), 0.12 - k * 0.02, "Glow", P.socket, P.eye)
		end
		-- Nageoires pectorales
		local root = A.mx(v3(1.2, 2.3, -0.9), side)
		for k = 0, 4 do
			local dir = A.mx(v3(0.8, -0.45 + k * 0.1, 0.35 + k * 0.18), side).Unit
			rig:strut("Body", "FinRay", root, root + dir * (1.4 - k * 0.12), 0.06, 0.06, P.finBone)
			if k < 4 then
				local dir2 = A.mx(v3(0.8, -0.35 + k * 0.1, 0.53 + k * 0.18), side).Unit
				A.triangle(rig, "Body", "Fin", root, root + dir * (1.4 - k * 0.12), root + dir2 * (1.3 - k * 0.12), 0.03, P.fin)
			end
		end
	end)
	-- Barbillons ondulants sous la mâchoire
	for k, x in { -0.45, -0.15, 0.15, 0.45 } do
		local p0 = v3(x, 1.72, -2.2 + math.abs(x) * 0.6)
		local pts = { p0, p0 + v3(x * 0.3, -0.35, -0.05), p0 + v3(x * 0.5, -0.7, 0.05), p0 + v3(x * 0.5, -1.0, 0.15) }
		local names = {}
		for i = 1, #pts - 1 do
			local name = "Sway" .. (k * 10 + i)
			rig:bone(name, if i == 1 then "Jaw" else names[i - 1], cf(pts[i]))
			names[i] = name
			rig:strut(name, "Barbel", pts[i], pts[i + 1], 0.07 - i * 0.015, 0.07 - i * 0.015, P.plates[2])
		end
		rig:ball(names[#names], "BarbelLight", pts[#pts], 0.14, P.light)
	end

	-- Leurre lumineux (poisson-lanterne)
	local stalk = { v3(0, 3.7, -1.5), v3(0, 4.4, -1.75), v3(0, 4.7, -2.3), v3(0, 4.5, -2.85), v3(0, 4.15, -3.05) }
	A.horn(rig, "Head", stalk, 0.1, 0.05, P.finBone, P.light, { 1.8, 2.8, 3.6 })
	local lurePos = v3(0, 3.9, -3.08)
	rig:ball("Head", "Lure", lurePos, 0.42, P.lure)
	rig:ball("Head", "LureHalo", lurePos, 0.66, P.lureGlass)
	for k = 0, 5 do
		rig:spike("Head", "LureFrill", cf(lurePos) * ang(0, k / 6 * math.pi * 2, 0) * ang(0, 0, rad(70)) * cf(0, 0.28, 0), 0.1, 0.24, 0.02, P.lightSoft)
	end

	-- Pattes trapues
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, z in { F = -0.9, B = 1.1 } do
			local bone = "Leg_" .. key .. s
			A.limb(rig, bone, side, { { v3(0.95, 2.0, z), 0.5, 0.55 }, { v3(1.12, 1.1, z - 0.05), 0.38, 0.38 }, { v3(1.12, 0.35, z), 0.34, 0.34 } }, P.core, A.scales(P.plates, v3(0.34, 0.12, 0.32), 0.28, { arc = 180, tilt = 8, refRadius = 0.36, seed = 10 + side }))
			A.paw(rig, bone, A.mx(v3(1.12, 0.12, z - 0.1), side), v3(0, 0, -1), 0.6, 3, P.plates[4], P.plates[3], P.claw)
			rig:ball(bone, "LegLight", A.mx(v3(1.38, 1.1, z), side), 0.14, P.light)
		end
	end)

	-- Nageoire caudale
	local fluke = v3(0, 2.1, 3.15)
	rig:mirrored(function(side)
		A.triangle(rig, "Tail1", "Fluke", fluke, fluke + A.mx(v3(1.3, 0.25, 0.75), side), fluke + A.mx(v3(0.45, 0.05, 1.05), side), 0.08, P.plates[2])
		rig:strut("Tail1", "FlukeEdge", fluke + A.mx(v3(1.3, 0.25, 0.75), side), fluke + A.mx(v3(0.45, 0.05, 1.05), side), 0.06, 0.06, P.light)
	end)

	-- Orbes abyssaux en orbite
	A.orbit(rig, "Aura1", v3(0, 2.8, 0), 4.0, 8, 0.7, function(bone, c, i)
		rig:ball(bone, "AbyssOrb", c.Position, 0.3 + (i % 2) * 0.12, P.light)
		rig:ball(bone, "AbyssOrbHalo", c.Position, 0.56 + (i % 2) * 0.16, P.lureGlass)
	end)

	rig:hitbox(cf(0, 2.4, 0), v3(3.6, 4.4, 7))

	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Body", "FX_Abyss", cf(0, 2.6, 0), v3(3.2, 2.4, 5))
		Fx.particles(g, {
			name = "Bubbles",
			texture = Fx.TEXTURES.sparkle,
			colors = { rgb(200, 245, 255), rgb(120, 210, 255) },
			sizes = { 0.12, 0.2, 0.06 },
			transparencies = { 0.2, 0.4, 1 },
			lifetime = NumberRange.new(2, 3.4),
			rate = 10,
			speed = NumberRange.new(0.3, 0.8),
			spread = Vector2.new(20, 20),
			acceleration = v3(0, 0.8, 0),
			lightEmission = 0.6,
			volume = true,
		}, sc)
		Fx.particles(g, Fx.mist("DeepMist", { rgb(20, 60, 140), rgb(2, 6, 20) }, 10, 2.4, 0.2), sc)
		Fx.light(g, { color = rgb(70, 190, 255), range = 20, brightness = 1.6 }, sc)
		local lure = rig:anchor("Head", "FX_Lure", cf(lurePos), v3(0.4, 0.4, 0.4))
		Fx.light(lure, { color = rgb(170, 240, 255), range = 14, brightness = 3 }, sc)
		Fx.particles(lure, Fx.sparkles("LureMotes", { rgb(220, 250, 255), rgb(90, 200, 255) }, 8, 0.16), sc)
		Vfx.orbitTethers(rig, "Aura1", Vfx.orbitPoints(v3(0, 2.8, 0), 4.0, 8, 0.7), "Head", lurePos, { colors = { rgb(150, 230, 255), rgb(30, 90, 200) }, transparency = { 0.35, 0.85 }, width0 = 0.07, width1 = 0.02, curve0 = 0.8 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Exclusive")
	end

	return rig:finish({ Rarity = "Exclusive" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Béhémoth abyssal",
	Rarity = "Exclusive",
	Size = "Colossal",
	Income = 14000000,
	SpeedBonus = 2.4,
	Passenger = true,
	Source = "Roue",
	Scale = 2.9,
	Category = "Créature Exclusive",
	Description = "Monstre des fosses océaniques : son leurre et ses photophores bleus sont les seules lumières des profondeurs.",
	Icon = { top = rgb(10, 50, 110), bottom = rgb(2, 4, 14), glow = rgb(90, 210, 255), motif = rgb(170, 240, 255), yaw = 32, pitch = 10, zoom = 1.0 },
	Animation = { gait = "Quadruped", breathe = 0.06, bob = 0.08, stride = 18, strideRate = 5, tailSway = 10, tailRate = 0.9, headLook = 8, auraSpeed = 0.35, flicker = 0.12 },
	Ability = ABILITY,
	build = build,
}

return Def
