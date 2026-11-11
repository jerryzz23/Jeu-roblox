--!strict
--[[
	LE RAT DES CAVERNES — Commun · La Surface
	=========================================
	Petit rongeur agile aux yeux lumineux (Neon), corps sombre texturé et petites oreilles pointues.

	• Corps en tube bombé (croupe haute) couvert de mèches de fourrure indigo à pointes lavande.
	• Grappe de cristaux de grotte (Neon cyan, verre turquoise, améthyste) sur une plaque de roche (Slate).
	• Grands yeux Neon cyan, sourcils froncés, joues touffues, moustaches, incisives, nez rose.
	• Oreilles pointues à intérieur rose et pointe sombre, anneau doré à l'oreille gauche.
	• Queue annelée rose écailleuse avec bague dorée à rivets ; pattes roses griffues.
	• Effets : poussière de grotte, éclats dans les yeux, spores de cristal, 2 lumières.
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

local ID = "RatDesCavernes"

local P = {
	core = S(rgb(42, 36, 68)),
	fur = { S(rgb(92, 80, 136)), S(rgb(70, 60, 110)), S(rgb(52, 44, 86)), S(rgb(38, 32, 64)) },
	furTip = S(rgb(170, 156, 226)),
	belly = { S(rgb(150, 138, 186)), S(rgb(120, 108, 160)) },
	skin = S(rgb(255, 146, 176)),
	skinScales = { S(rgb(255, 170, 196)), S(rgb(236, 126, 160)), S(rgb(206, 98, 136)) },
	skinDark = S(rgb(196, 86, 128)),
	tooth = S(rgb(255, 236, 170)),
	claw = S(rgb(250, 244, 226)),
	eye = S(rgb(110, 255, 236), M.Neon),
	socket = S(rgb(16, 12, 28)),
	whisker = S(rgb(230, 228, 245)),
	stone = S(rgb(86, 84, 104), M.Slate),
	stoneDark = S(rgb(60, 58, 76), M.Slate),
	crystals = {
		S(rgb(120, 250, 255), M.Neon),
		S(rgb(60, 200, 230), M.Glass, { transparency = 0.15 }),
		S(rgb(190, 120, 255), M.Neon),
		S(rgb(90, 230, 255), M.Neon),
	},
	gold = S(rgb(255, 198, 54)),
	goldDark = S(rgb(214, 136, 24)),
}

local BODY = Kit.spine({
	{ pos = v3(0, 1.1, -0.95), rx = 0.36, ry = 0.34 },
	{ pos = v3(0, 1.04, -0.55), rx = 0.5, ry = 0.44 },
	{ pos = v3(0, 1.06, 0.0), rx = 0.6, ry = 0.52 },
	{ pos = v3(0, 1.12, 0.55), rx = 0.7, ry = 0.58 },
	{ pos = v3(0, 1.02, 1.05), rx = 0.58, ry = 0.48 },
	{ pos = v3(0, 0.86, 1.36), rx = 0.3, ry = 0.28 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 1.12, -2.08), rx = 0.08, ry = 0.08 },
	{ pos = v3(0, 1.14, -1.9), rx = 0.2, ry = 0.17 },
	{ pos = v3(0, 1.2, -1.6), rx = 0.33, ry = 0.27 },
	{ pos = v3(0, 1.25, -1.27), rx = 0.43, ry = 0.35 },
	{ pos = v3(0, 1.24, -0.95), rx = 0.36, ry = 0.32 },
})

local TAIL = Kit.spine({
	{ pos = v3(0, 0.95, 1.28), rx = 0.14, ry = 0.14 },
	{ pos = v3(0, 0.66, 1.8), rx = 0.12, ry = 0.12 },
	{ pos = v3(0.08, 0.38, 2.3), rx = 0.1, ry = 0.1 },
	{ pos = v3(0.28, 0.24, 2.85), rx = 0.08, ry = 0.08 },
	{ pos = v3(0.62, 0.26, 3.32), rx = 0.065, ry = 0.065 },
	{ pos = v3(1.02, 0.42, 3.62), rx = 0.045, ry = 0.045 },
	{ pos = v3(1.42, 0.72, 3.74), rx = 0.02, ry = 0.02 },
})

local function earBase(side: number): CFrame
	return cf(side * 0.3, 1.52, -1.08) * ang(rad(12), -side * rad(26), -side * rad(26))
end

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)

	-- Squelette ----------------------------------------------------------
	rig:bone("Body", "Root", cf(0, 1.05, 0.2))
	rig:bone("Head", "Body", cf(0, 1.16, -0.9))
	rig:bone("Jaw", "Head", cf(0, 0.98, -1.5))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Ear" .. sfx, "Head", earBase(side))
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.4, 0.95, -0.55))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.52, 1.05, 0.7))
	end)
	local tailJoints = {}
	for i = 1, #TAIL.sections do
		table.insert(tailJoints, TAIL:pos(i))
	end
	local tailBones = rig:boneChain("Tail", "Body", tailJoints)

	-- Corps fourré --------------------------------------------------------
	rig:tube(BODY, {
		name = "Body",
		bone = function()
			return "Body"
		end,
		core = P.core,
		coreStep = 0.3,
		cover = {
			A.fur(P.fur, P.furTip, v3(0.24, 0.44, 0.38), 0.2, { arc = 130, seed = 3 }),
			A.scales(P.belly, v3(0.3, 0.08, 0.26), 0.24, { arc = 50, center = 180, tilt = 10, seed = 4 }),
		},
	})

	-- Plaque de roche + cristaux de grotte
	local rock = BODY:surface(3.3, 8, 0.05)
	rig:prism("Body", "Rock", rock * cf(0, 0.02, 0), v3(0.62, 0.16, 0.58), 0.12, P.stoneDark)
	rig:prism("Body", "Rock", rock * cf(0.08, 0.1, 0.02) * ang(0, rad(30), 0), v3(0.42, 0.14, 0.4), 0.1, P.stone)
	A.crystals(rig, "Body", rock * cf(0, 0.12, 0), 7, 0.85, P.crystals, 7, 0.45)
	A.crystals(rig, "Body", BODY:surface(4.4, -30, 0.02), 3, 0.38, { P.crystals[3], P.crystals[1] }, 9, 0.4)

	-- Tête ------------------------------------------------------------------
	rig:tube(HEAD, {
		name = "Head",
		bone = function()
			return "Head"
		end,
		core = P.core,
		coreStep = 0.18,
		cover = {
			A.fur(P.fur, P.furTip, v3(0.2, 0.22, 0.24), 0.15, { from = 3.1, arc = 115, refRadius = 0.4, seed = 5 }),
		},
	})
	rig:ball("Head", "Nose", v3(0, 1.13, -2.12), 0.17, P.skin)
	rig:ball("Head", "NoseTip", v3(0, 1.16, -2.18), 0.08, P.skinDark)
	rig:prismBetween("Jaw", "Jaw", v3(0, 0.98, -1.5), v3(0, 0.98, -1.98), 0.3, 0.12, 0.05, P.belly[1])
	rig:mirrored(function(side, sfx)
		rig:block("Head", "Tooth" .. sfx, cf(side * 0.035, 0.97, -2.02), v3(0.06, 0.14, 0.04), P.tooth)
		A.eye(rig, "Head", A.mx(v3(0.3, 1.36, -1.52), side), v3(side, 0.35, -0.7), 0.26, "Glow", P.socket, P.eye)
		A.brow(rig, "Head", side, v3(0.27, 1.52, -1.5), 0.3, 22, P.fur[4])
		A.whiskers(rig, "Head", side, v3(0.16, 1.08, -1.98), 0.8, P.whisker)
		-- Joues touffues
		A.tuftBurst(rig, "Head", cf(A.mx(v3(0.36, 1.06, -1.38), side)) * ang(0, 0, -side * rad(80)) * ang(rad(30), 0, 0), 5, 0.24, 0.12, P.fur, P.furTip, 30, 11 + side)

		-- Oreilles
		local ear = "Ear" .. sfx
		local base = earBase(side)
		A.ear(rig, ear, base, 0.48, 0.58, P.fur[2], P.skin, P.fur[4])
		A.tuftBurst(rig, ear, base * cf(0, 0.02, 0.04), 4, 0.18, 0.1, P.fur, nil, 40, 21 + side)
		if side < 0 then
			local edge = 0.24 * (1 - 0.08 / 0.58)
			rig:ring(ear, "Earring", base * cf(side * edge, 0.08, 0) * ang(0, math.pi / 2, 0), 0.08, 0.035, 0.035, 8, P.gold)
		end
	end)

	-- Pattes ----------------------------------------------------------------
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		local front, back = "Leg_F" .. s, "Leg_B" .. s
		A.limb(rig, front, side, {
			{ v3(0.4, 0.98, -0.55), 0.22, 0.22 },
			{ v3(0.46, 0.5, -0.5), 0.13, 0.13 },
			{ v3(0.48, 0.16, -0.64), 0.09, 0.09 },
		}, P.core, A.fur(P.fur, P.furTip, v3(0.2, 0.22, 0.24), 0.16, { arc = 180, refRadius = 0.2, to = 2.2, seed = 30 + side }))
		A.paw(rig, front, A.mx(v3(0.49, 0, -0.74), side), v3(0, 0, -1), 0.3, 4, P.skin, P.skinDark, P.claw)

		A.limb(rig, back, side, {
			{ v3(0.52, 1.1, 0.65), 0.34, 0.4 },
			{ v3(0.62, 0.62, 0.92), 0.2, 0.2 },
			{ v3(0.6, 0.18, 0.98), 0.1, 0.1 },
		}, P.core, A.fur(P.fur, P.furTip, v3(0.26, 0.28, 0.3), 0.18, { arc = 180, refRadius = 0.3, to = 2.3, seed = 40 + side }))
		A.paw(rig, back, A.mx(v3(0.6, 0, 0.82), side), v3(0, 0, -1), 0.34, 5, P.skin, P.skinDark, P.claw)
	end)

	-- Queue annelée -----------------------------------------------------------
	rig:tube(TAIL, {
		name = "Tail",
		bone = function(u)
			return tailBones[math.clamp(math.floor(u), 1, #tailBones)]
		end,
		core = P.skin,
		coreStep = 0.16,
		cover = {
			A.scales(P.skinScales, v3(0.12, 0.035, 0.1), 0.1, { arc = 180, refRadius = 0.12, tilt = 12, jitter = 0.15, seed = 50 }),
		},
	})
	rig:band(TAIL, tailBones[2], "TailBand", 2.15, 0.12, 0.06, P.gold, P.goldDark)
	rig:band(TAIL, tailBones[2], "TailBand", 2.4, 0.05, 0.05, P.goldDark)

	rig:hitbox(cf(0, 1.0, -0.2), v3(1.8, 2.0, 3.8))

	-- Effets ------------------------------------------------------------------
	if rig.effects then
		local sc = rig.scale
		local dust = rig:anchor("Root", "FX_Dust", cf(0, 0.15, 0.2), v3(1.8, 0.25, 3.0))
		Fx.particles(dust, {
			name = "CaveDust",
			texture = Fx.TEXTURES.smoke,
			colors = { rgb(128, 118, 140), rgb(90, 86, 100) },
			sizes = { 0.2, 0.55 },
			transparencies = { 1, 0.7, 1 },
			lifetime = NumberRange.new(1.4, 2.4),
			rate = 4,
			speed = NumberRange.new(0.15, 0.45),
			spread = Vector2.new(70, 70),
			acceleration = v3(0, 0.12, 0),
			drag = 1,
			rotation = NumberRange.new(0, 360),
			volume = true,
		}, sc)
		local spores = rig:anchor("Body", "FX_Spores", rock * cf(0, 0.6, 0), v3(0.6, 0.5, 0.6))
		Fx.particles(spores, {
			name = "CrystalSpores",
			texture = Fx.TEXTURES.sparkle,
			colors = { rgb(120, 250, 255), rgb(200, 160, 255) },
			sizes = { 0.16, 0.1, 0 },
			transparencies = { 0.1, 0.3, 1 },
			lifetime = NumberRange.new(1.6, 2.6),
			rate = 4,
			speed = NumberRange.new(0.15, 0.4),
			spread = Vector2.new(30, 30),
			acceleration = v3(0, 0.25, 0),
			drag = 0.5,
			lightEmission = 1,
			volume = true,
		}, sc)
		Fx.light(spores, { color = rgb(110, 240, 255), range = 7, brightness = 1 }, sc)
		local eyes = rig:anchor("Head", "FX_Eyes", cf(0, 1.36, -1.5), v3(0.7, 0.2, 0.2))
		Fx.particles(eyes, {
			name = "EyeGlint",
			texture = Fx.TEXTURES.sparkle,
			colors = { rgb(140, 255, 240) },
			sizes = { 0.34, 0 },
			transparencies = { 0.2, 1 },
			lifetime = NumberRange.new(0.35, 0.6),
			rate = 2,
			lockedToPart = true,
			lightEmission = 1,
			zOffset = 0.3,
			rotation = NumberRange.new(0, 360),
			volume = true,
		}, sc)
		Fx.light(eyes, { color = rgb(110, 255, 236), range = 6, brightness = 1.2 }, sc)
	end

	return rig:finish({ Rarity = "Common" })
end

local RatDesCavernes: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Rat des Cavernes",
	Rarity = "Common",
	Zone = "Surface",
	Scale = 1.2,
	Category = "Créature Commune",
	Description = "Petit rongeur agile des grottes. Ses yeux luisent dans le noir et des cristaux poussent sur son dos.",
	Icon = { top = rgb(44, 58, 92), bottom = rgb(14, 14, 30), glow = rgb(120, 255, 236), motif = rgb(190, 120, 255), yaw = 36, pitch = 16, zoom = 1.1 },
	Animation = {
		gait = "Quadruped",
		breathe = 0.03,
		bob = 0.1,
		stride = 34,
		strideRate = 16,
		tailSway = 16,
		tailRate = 2.6,
		headLook = 22,
		sniff = true,
		earTwitch = true,
	},
	build = build,
}

return RatDesCavernes
