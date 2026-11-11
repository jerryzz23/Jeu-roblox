--!strict
--[[
	LE RAT DES CAVERNES — Commun
	============================
	Petit rongeur agile aux yeux lumineux (Neon), corps sombre texturé (Fabric)
	et petites oreilles pointues.

	Détails :
	  • fourrure en écailles le long de l'échine et des flancs (WedgeParts) ;
	  • plaque de roche (Slate) sur le dos d'où poussent trois cristaux de grotte (Neon) ;
	  • yeux Neon cerclés de noir, sourcils, moustaches, incisives, joues ;
	  • anneau doré à l'oreille gauche, bague dorée sur la queue annelée ;
	  • pattes avant fines, cuisses arrière puissantes, griffes.
	  • Particules : poussière de grotte au sol, éclats dans les yeux, spores des cristaux.
	  • Lumières : lueur des yeux + lueur des cristaux.

	Os (Motor6D) : Root > Body > Head > Ear_R / Ear_L
	                       Body > Tail1 > … > Tail6
	                       Body > Leg_FR / Leg_FL / Leg_BR / Leg_BL
	Taille (scale = 1) : ~1,9 stud de haut, ~5,7 studs du museau au bout de la queue.
]]

local Kit = require(script.Parent.Parent.Kit)
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
	fur = S(rgb(74, 68, 88), M.Fabric),
	furDark = S(rgb(46, 42, 58), M.Fabric),
	furLight = S(rgb(124, 116, 136), M.Fabric),
	belly = S(rgb(152, 142, 154), M.Fabric),
	skin = S(rgb(206, 138, 150)),
	skinDark = S(rgb(150, 94, 108)),
	tooth = S(rgb(240, 222, 168)),
	claw = S(rgb(232, 226, 212)),
	eye = S(rgb(120, 255, 226), M.Neon),
	eyeSocket = S(rgb(22, 20, 28)),
	whisker = S(rgb(206, 206, 216), M.SmoothPlastic, { transparency = 0.15, castShadow = false }),
	stone = S(rgb(92, 92, 104), M.Slate),
	crystal = S(rgb(110, 236, 255), M.Neon, { transparency = 0.1 }),
	gold = S(rgb(226, 176, 66), M.Metal, { reflectance = 0.05 }),
}

-- Ligne de l'échine : (z, hauteur du dos)
local SPINE = {
	{ -0.95, 1.36 },
	{ -0.6, 1.45 },
	{ -0.2, 1.53 },
	{ 0.2, 1.62 },
	{ 0.5, 1.72 },
	{ 0.9, 1.66 },
	{ 1.3, 1.52 },
}

local function spineY(z: number): number
	for i = 1, #SPINE - 1 do
		local a, b = SPINE[i], SPINE[i + 1]
		if z <= b[1] then
			local t = math.clamp((z - a[1]) / (b[1] - a[1]), 0, 1)
			return a[2] + (b[2] - a[2]) * t
		end
	end
	return SPINE[#SPINE][2]
end

local function spineSlope(z: number): number
	local d = 0.05
	return math.atan((spineY(z + d) - spineY(z - d)) / (2 * d))
end

-- Queue : articulations et diamètres des segments
local TAIL = {
	v3(0, 0.98, 1.2),
	v3(0, 0.74, 1.72),
	v3(0.06, 0.48, 2.2),
	v3(0.22, 0.3, 2.7),
	v3(0.5, 0.28, 3.18),
	v3(0.9, 0.42, 3.52),
	v3(1.32, 0.72, 3.68),
}
local TAIL_D = { 0.27, 0.23, 0.19, 0.15, 0.115, 0.08 }

local function earBase(side: number): CFrame
	return cf(side * 0.3, 1.56, -1.0) * ang(rad(12), -side * rad(28), -side * rad(24))
end

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)

	-- ===================================================================
	-- Squelette
	-- ===================================================================
	rig:bone("Body", "Root", cf(0, 1.0, 0.2))
	rig:bone("Head", "Body", cf(0, 1.18, -0.85))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Ear" .. sfx, "Head", earBase(side))
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.45, 0.88, -0.62))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.6, 1.0, 0.75))
	end)
	rig:boneChain("Tail", "Body", TAIL)

	-- ===================================================================
	-- Corps
	-- ===================================================================
	rig:prism("Body", "Torso", cf(0, 1.02, 0.12), v3(1.22, 1.0, 1.5), 0.3, P.fur)
	rig:prism("Body", "Rump", cf(0, 1.12, 0.85) * ang(rad(10), 0, 0), v3(1.42, 1.1, 1.0), 0.38, P.fur)
	rig:prism("Body", "Haunches", cf(0, 1.0, 1.36) * ang(rad(30), 0, 0), v3(1.16, 0.8, 0.52), 0.3, P.fur)
	rig:prism("Body", "Chest", cf(0, 0.98, -0.6) * ang(rad(-6), 0, 0), v3(0.98, 0.9, 0.75), 0.26, P.fur)
	rig:prism("Body", "Neck", cf(0, 1.12, -0.92) * ang(rad(-14), 0, 0), v3(0.8, 0.74, 0.42), 0.22, P.furDark)
	rig:prism("Body", "Belly", cf(0, 0.6, 0.15), v3(0.84, 0.24, 1.75), 0.08, P.belly)
	rig:prism("Body", "Chin", cf(0, 0.76, -0.82) * ang(rad(-18), 0, 0), v3(0.56, 0.26, 0.5), 0.1, P.belly)

	-- Fourrure de l'échine : écailles inclinées vers l'arrière
	local tuftZ = { -0.78, -0.48, -0.18, 0.62, 0.92, 1.2 }
	for i, z in tuftZ do
		local w = if z < -0.3 then 0.4 else 0.48
		rig:wedge(
			"Body",
			"SpineTuft",
			cf(0, spineY(z) + 0.08, z) * ang(spineSlope(z), 0, 0),
			v3(w, 0.32, 0.42),
			if i % 2 == 0 then P.fur else P.furDark
		)
	end

	-- Fourrure des flancs
	local flank = {
		{ 0.41, 1.33, -0.55 },
		{ 0.49, 1.4, -0.15 },
		{ 0.55, 1.5, 0.3 },
		{ 0.58, 1.52, 0.75 },
		{ 0.53, 1.38, 1.15 },
	}
	rig:mirrored(function(side)
		for i, f in flank do
			rig:wedge(
				"Body",
				"FlankTuft",
				cf(side * f[1], f[2], f[3]) * ang(0, 0, -side * rad(45)),
				v3(0.26, 0.18, 0.4),
				if i % 2 == 0 then P.furDark else P.fur
			)
		end
	end)

	-- Plaque de roche + cristaux de grotte
	local rockCF = cf(0, spineY(0.25) + 0.02, 0.25) * ang(spineSlope(0.25), rad(8), 0)
	rig:prism("Body", "RockPlate", rockCF, v3(0.62, 0.2, 0.62), 0.08, P.stone)
	rig:prism("Body", "RockPlate", rockCF * cf(0.12, 0.08, 0.05) * ang(0, rad(30), 0), v3(0.34, 0.16, 0.34), 0.06, P.stone)
	rig:shard("Body", "Crystal", rockCF * cf(0, 0.08, 0.02) * ang(rad(16), 0, 0) * ang(0, rad(45), 0), 0.18, 0.36, 0.16, P.crystal)
	rig:shard("Body", "Crystal", rockCF * cf(0.17, 0.06, 0.08) * ang(rad(10), 0, rad(-32)) * ang(0, rad(45), 0), 0.12, 0.22, 0.11, P.crystal)
	rig:shard("Body", "Crystal", rockCF * cf(-0.15, 0.06, 0.12) * ang(rad(20), 0, rad(28)) * ang(0, rad(45), 0), 0.1, 0.16, 0.09, P.crystal)

	-- ===================================================================
	-- Tête
	-- ===================================================================
	local skull = rig:prism("Head", "Skull", cf(0, 1.26, -1.2), v3(0.92, 0.78, 0.8), 0.24, P.fur)[1]
	rig:prism("Head", "Snout", cf(0, 1.1, -1.78), v3(0.54, 0.46, 0.4), 0.15, P.fur)
	rig:prism("Head", "SnoutTip", cf(0, 1.06, -2.06), v3(0.4, 0.36, 0.2), 0.11, P.fur)
	rig:wedge("Head", "Bridge", cf(0, 1.445, -1.88), v3(0.34, 0.41, 0.56), P.fur)
	rig:prism("Head", "Jaw", cf(0, 0.87, -1.78), v3(0.38, 0.15, 0.5), 0.06, P.furLight)
	rig:ball("Head", "Nose", v3(0, 1.17, -2.17), 0.18, P.skin)

	-- Crête de fourrure sur le crâne
	rig:wedge("Head", "HeadTuft", cf(0, 1.69, -1.12) * ang(rad(-8), 0, 0), v3(0.34, 0.2, 0.4), P.furDark)

	local eyes: { BasePart } = {}
	rig:mirrored(function(side, sfx)
		rig:prism("Head", "Cheek" .. sfx, cf(side * 0.35, 1.0, -1.42), v3(0.24, 0.32, 0.42), 0.1, P.furLight)
		rig:block("Head", "Tooth" .. sfx, cf(side * 0.04, 0.8, -2.08), v3(0.07, 0.15, 0.045), P.tooth)

		rig:ball("Head", "EyeSocket" .. sfx, v3(side * 0.4, 1.37, -1.5), 0.27, P.eyeSocket)
		table.insert(eyes, rig:ball("Head", "Eye" .. sfx, v3(side * 0.43, 1.37, -1.53), 0.22, P.eye))
		rig:block("Head", "Brow" .. sfx, cf(side * 0.36, 1.53, -1.52) * ang(0, side * rad(-10), -side * rad(28)), v3(0.3, 0.07, 0.14), P.furDark)

		for k = -1, 1 do
			rig:strut(
				"Head",
				"Whisker" .. sfx,
				v3(side * 0.18, 1.05 + k * 0.05, -2.0),
				v3(side * 0.92, 1.1 + k * 0.16, -1.74 + k * 0.08),
				0.025,
				0.025,
				P.whisker
			)
		end

		-- Oreilles pointues
		local ear = "Ear" .. sfx
		local base = earBase(side)
		rig:spike(ear, "Ear", base, 0.44, 0.48, 0.07, P.fur)
		rig:spike(ear, "EarInner", base * cf(0, 0.05, -0.045), 0.27, 0.32, 0.03, P.skin)
		if side < 0 then
			-- Anneau doré passé dans le bord extérieur de l'oreille gauche
			local edge = 0.22 * (1 - 0.07 / 0.48)
			rig:ring(ear, "Earring", base * cf(side * edge, 0.07, 0) * ang(0, math.pi / 2, 0), 0.075, 0.03, 0.03, 8, P.gold)
		end
	end)

	-- ===================================================================
	-- Pattes
	-- ===================================================================
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		local front, back = "Leg_F" .. s, "Leg_B" .. s

		-- Avant : bras fin, épaule fourrée, petite main rose, griffes
		rig:prism(front, "Shoulder", cf(side * 0.45, 0.82, -0.58), v3(0.32, 0.42, 0.46), 0.12, P.furDark)
		rig:prismBetween(front, "Arm", v3(side * 0.46, 0.84, -0.56), v3(side * 0.48, 0.4, -0.48), 0.24, 0.26, 0.08, P.fur)
		rig:prismBetween(front, "Forearm", v3(side * 0.48, 0.46, -0.48), v3(side * 0.49, 0.13, -0.72), 0.2, 0.22, 0.06, P.fur)
		rig:prism(front, "Paw", cf(side * 0.49, 0.085, -0.8), v3(0.28, 0.15, 0.42), 0.05, P.skin)
		for k = -1, 1 do
			rig:wedge(front, "Claw", cf(side * 0.49 + k * 0.085, 0.045, -1.06), v3(0.05, 0.07, 0.11), P.claw)
		end

		-- Arrière : cuisse puissante, jarret, long pied rose, griffes
		rig:prism(back, "Thigh", cf(side * 0.6, 0.86, 0.75) * ang(rad(-14), 0, 0), v3(0.42, 0.8, 0.9), 0.2, P.fur)
		rig:wedge(back, "ThighTuft", cf(side * 0.7, 1.08, 1.12) * ang(rad(-30), 0, -side * rad(20)), v3(0.26, 0.2, 0.34), P.furDark)
		rig:prismBetween(back, "Shin", v3(side * 0.64, 0.6, 1.0), v3(side * 0.64, 0.12, 0.86), 0.22, 0.24, 0.06, P.fur)
		rig:prism(back, "Foot", cf(side * 0.64, 0.085, 0.72), v3(0.3, 0.15, 0.66), 0.05, P.skin)
		for k = -1, 1 do
			rig:wedge(back, "Claw", cf(side * 0.64 + k * 0.09, 0.045, 0.335), v3(0.05, 0.07, 0.11), P.claw)
		end
	end)

	-- ===================================================================
	-- Queue annelée
	-- ===================================================================
	for i = 1, #TAIL - 1 do
		local bone = "Tail" .. i
		local a, b, d = TAIL[i], TAIL[i + 1], TAIL_D[i]
		rig:cylinder(bone, "Tail", a, b, d, P.skin)
		rig:ball(bone, "TailJoint", b, d, P.skin)
		if i == 2 then
			-- Bague dorée (à la sortie de la croupe)
			rig:cylinder(bone, "TailBand", a:Lerp(b, 0.1), a:Lerp(b, 0.3), d + 0.08, P.gold)
			rig:cylinder(bone, "TailBandRim", a:Lerp(b, 0.16), a:Lerp(b, 0.24), d + 0.12, P.gold)
			rig:cylinder(bone, "TailRing", a:Lerp(b, 0.63), a:Lerp(b, 0.69), d + 0.035, P.skinDark)
		elseif i > 2 then
			for _, t in { 0.33, 0.66 } do
				rig:cylinder(bone, "TailRing", a:Lerp(b, t - 0.03), a:Lerp(b, t + 0.03), d + 0.035, P.skinDark)
			end
		end
	end

	rig:hitbox(cf(0, 0.95, -0.3), v3(1.7, 1.9, 3.6))

	-- ===================================================================
	-- Effets
	-- ===================================================================
	if rig.effects then
		local sc = rig.scale

		local dust = rig:anchor("Root", "FX_Dust", cf(0, 0.15, 0.2), v3(1.8, 0.25, 3.0))
		Fx.particles(dust, {
			name = "CaveDust",
			texture = Fx.TEXTURES.smoke,
			colors = { rgb(128, 118, 108), rgb(90, 86, 82) },
			sizes = { 0.2, 0.55 },
			transparencies = { 1, 0.7, 1 },
			lifetime = NumberRange.new(1.4, 2.4),
			rate = 4,
			speed = NumberRange.new(0.15, 0.45),
			spread = Vector2.new(70, 70),
			acceleration = v3(0, 0.12, 0),
			drag = 1,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-20, 20),
			volume = true,
		}, sc)

		for _, eye in eyes do
			Fx.particles(eye, {
				name = "EyeGlint",
				texture = Fx.TEXTURES.sparkle,
				colors = { P.eye.color },
				sizes = { 0.32, 0 },
				transparencies = { 0.2, 1 },
				lifetime = NumberRange.new(0.35, 0.6),
				rate = 1.5,
				lockedToPart = true,
				lightEmission = 1,
				zOffset = 0.25,
				rotation = NumberRange.new(0, 360),
			}, sc)
		end
		Fx.light(skull, { color = P.eye.color, range = 6, brightness = 1.2 }, sc)

		local spores = rig:anchor("Body", "FX_Spores", rockCF * cf(0, 0.35, 0), v3(0.45, 0.4, 0.45))
		Fx.particles(spores, {
			name = "CrystalSpores",
			texture = Fx.TEXTURES.sparkle,
			colors = { P.crystal.color, rgb(200, 255, 255) },
			sizes = { 0.14, 0.08, 0 },
			transparencies = { 0.1, 0.3, 1 },
			lifetime = NumberRange.new(1.6, 2.6),
			rate = 2.5,
			speed = NumberRange.new(0.15, 0.4),
			spread = Vector2.new(30, 30),
			acceleration = v3(0, 0.25, 0),
			drag = 0.5,
			lightEmission = 1,
			volume = true,
		}, sc)
		Fx.light(spores, { color = P.crystal.color, range = 5, brightness = 0.8 }, sc)
	end

	return rig:finish({ Rarity = "Common" })
end

local RatDesCavernes: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Rat des Cavernes",
	Rarity = "Common",
	Category = "Créature Commune",
	Description = "Petit rongeur agile des grottes. Ses yeux luisent dans le noir et des cristaux poussent sur son dos.",
	Icon = {
		top = rgb(44, 58, 78),
		bottom = rgb(14, 16, 26),
		glow = rgb(120, 255, 226),
		motif = rgb(110, 236, 255),
		yaw = 36,
		pitch = 14,
		zoom = 1.1,
	},
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
