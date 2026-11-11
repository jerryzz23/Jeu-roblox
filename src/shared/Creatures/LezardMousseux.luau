--!strict
--[[
	LE LÉZARD MOUSSEUX — Commun
	===========================
	Reptile rampant recouvert de plaques écailleuses vertes (Slate) et de mousse,
	avec de petites dorures sur le dos.

	Détails :
	  • peau verte grumeleuse (Pebble), ventre clair, queue annelée vert clair / vert sombre ;
	  • trois rangées de plaques d'écailles imbriquées (WedgeParts en Slate) du cou à la queue ;
	  • dorures : rivets dorés sur l'échine, liserés dorés sur trois plaques, losange doré au front ;
	  • touffes de mousse (Grass) avec jeunes pousses sur le dos, la tête et la base de la queue,
	    petite barbe de mousse sous le menton ;
	  • yeux dorés à pupille fendue, arcades osseuses, narines, mâchoire articulée,
	    langue fourchue rétractable ;
	  • pattes écartées de reptile, doigts écartés et griffes sombres.
	  • Particules : pollen qui s'échappe de la mousse, reflets sur les dorures, poussière au sol.

	Os (Motor6D) : Root > Body > Chest > Head > Jaw / Tongue
	                      Body > Tail1 > … > Tail7
	                      Chest > Leg_FR / Leg_FL      Body > Leg_BR / Leg_BL
	Taille (scale = 1) : ~1,1 stud de haut, ~7 studs du museau au bout de la queue.
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

local ID = "LezardMousseux"

local P = {
	skin = S(rgb(92, 136, 70), M.Pebble),
	skinDark = S(rgb(60, 98, 54), M.Pebble),
	belly = S(rgb(214, 204, 146)),
	plate = S(rgb(72, 132, 88), M.Slate),
	plateLight = S(rgb(110, 166, 100), M.Slate),
	plateDark = S(rgb(44, 88, 64), M.Slate),
	moss = S(rgb(98, 150, 48), M.Grass),
	mossLight = S(rgb(142, 188, 68), M.Grass),
	sprout = S(rgb(176, 222, 96)),
	gold = S(rgb(226, 176, 66), M.Metal, { reflectance = 0.05 }),
	eye = S(rgb(250, 196, 54)),
	pupil = S(rgb(18, 16, 14)),
	mouth = S(rgb(140, 54, 66)),
	tongue = S(rgb(222, 82, 112)),
	claw = S(rgb(44, 38, 32)),
}

-- Hauteur du dos selon z (sommet des volumes du cou, du torse et des hanches)
local BACK = {
	{ -1.5, 0.84 },
	{ -1.1, 0.85 },
	{ -0.3, 0.85 },
	{ 0.5, 0.85 },
	{ 1.1, 0.8 },
	{ 1.35, 0.72 },
}

local function backY(z: number): number
	for i = 1, #BACK - 1 do
		local a, b = BACK[i], BACK[i + 1]
		if z <= b[1] then
			local t = math.clamp((z - a[1]) / (b[1] - a[1]), 0, 1)
			return a[2] + (b[2] - a[2]) * t
		end
	end
	return BACK[#BACK][2]
end

-- Le torse avant (et le cou) appartiennent à l'os Chest, le reste à Body
local function trunkBone(z: number): string
	return if z < -0.3 then "Chest" else "Body"
end

-- Queue : articulations, largeur et hauteur de chaque segment
local TAIL = {
	v3(0, 0.55, 1.05),
	v3(0, 0.47, 1.6),
	v3(0.08, 0.38, 2.15),
	v3(0.26, 0.3, 2.68),
	v3(0.42, 0.25, 3.2),
	v3(0.42, 0.22, 3.72),
	v3(0.22, 0.2, 4.2),
	v3(-0.12, 0.19, 4.6),
}
local TAIL_W = { 0.66, 0.54, 0.44, 0.36, 0.28, 0.2, 0.13 }

-- Pattes : épaule/hanche -> coude/genou -> poignet/cheville, doigts (angle vers l'extérieur, longueur)
local LEGS = {
	F = {
		hip = v3(0.35, 0.55, -0.85),
		knee = v3(0.82, 0.48, -0.95),
		ankle = v3(0.9, 0.1, -1.02),
		foot = v3(0.92, 0.06, -1.06),
		upper = { 0.24, 0.22 },
		lower = { 0.18, 0.2 },
		joint = 0.24,
		toes = { { -45, 0.2 }, { -15, 0.27 }, { 15, 0.26 }, { 45, 0.2 } },
	},
	B = {
		hip = v3(0.32, 0.55, 0.85),
		knee = v3(0.82, 0.5, 0.72),
		ankle = v3(0.92, 0.1, 0.86),
		foot = v3(0.95, 0.06, 0.86),
		upper = { 0.32, 0.3 },
		lower = { 0.2, 0.22 },
		joint = 0.3,
		toes = { { 5, 0.26 }, { 35, 0.34 }, { 65, 0.3 }, { 100, 0.2 } },
	},
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)

	-- Touffe de mousse : trois boules (Grass) + jeunes pousses
	local function moss(bone: string, c: Vector3, size: number, seed: number)
		rig:prism(bone, "MossPad", cf(c - v3(0, 0.07, 0) * size) * ang(0, seed, 0), v3(0.46, 0.1, 0.4) * size, 0.04 * size, P.moss)
		rig:ball(bone, "Moss", c, 0.26 * size, P.moss)
		rig:ball(bone, "Moss", c + v3(0.11, -0.02, 0.07) * size, 0.19 * size, P.mossLight)
		rig:ball(bone, "Moss", c + v3(-0.1, -0.03, -0.08) * size, 0.17 * size, P.moss)
		for k = 0, 2 do
			local a = seed + k * 2.1
			local base = cf(c + v3(math.cos(a) * 0.07, 0.07, math.sin(a) * 0.07) * size)
				* ang(math.cos(a) * 0.35, a, math.sin(a) * 0.35)
			rig:spike(bone, "Sprout", base, 0.05 * size, (0.13 + k * 0.03) * size, 0.02, P.sprout)
		end
	end

	-- ===================================================================
	-- Squelette
	-- ===================================================================
	rig:bone("Body", "Root", cf(0, 0.56, 0.3))
	rig:bone("Chest", "Body", cf(0, 0.58, -0.3))
	rig:bone("Head", "Chest", cf(0, 0.64, -1.45))
	rig:bone("Jaw", "Head", cf(0, 0.58, -1.62))
	rig:bone("Tongue", "Head", cf(0, 0.555, -1.95))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		local f, b = LEGS.F.hip, LEGS.B.hip
		rig:bone("Leg_F" .. s, "Chest", cf(side * f.X, f.Y, f.Z))
		rig:bone("Leg_B" .. s, "Body", cf(side * b.X, b.Y, b.Z))
	end)
	local tailBones = rig:boneChain("Tail", "Body", TAIL)

	-- ===================================================================
	-- Tronc
	-- ===================================================================
	rig:prism("Chest", "Chest", cf(0, 0.57, -0.72), v3(0.9, 0.54, 0.9), 0.2, P.skin)
	rig:prism("Chest", "Neck", cf(0, 0.62, -1.32) * ang(rad(-6), 0, 0), v3(0.62, 0.44, 0.5), 0.15, P.skin)
	rig:prism("Chest", "Belly", cf(0, 0.3, -0.7), v3(0.6, 0.12, 0.95), 0.03, P.belly)
	rig:prism("Chest", "Throat", cf(0, 0.42, -1.3), v3(0.5, 0.14, 0.5), 0.05, P.belly)

	rig:prism("Body", "Midriff", cf(0, 0.56, 0.1), v3(1.1, 0.6, 0.85), 0.22, P.skin)
	rig:prism("Body", "Hips", cf(0, 0.55, 0.82), v3(0.86, 0.52, 0.7), 0.2, P.skin)
	rig:prism("Body", "Belly", cf(0, 0.29, 0.35), v3(0.66, 0.12, 1.5), 0.03, P.belly)

	-- Rangée centrale de plaques (bord libre relevé vers l'arrière) + dorures
	local i = 0
	for z = -1.35, 1.2, 0.28 do
		i += 1
		local bone = trunkBone(z)
		local w = if z < -1.1 then 0.32 elseif z < -0.3 then 0.38 elseif z > 0.5 then 0.32 else 0.42
		local y = backY(z) + 0.04
		rig:wedge(bone, "Plate", cf(0, y, z), v3(w, 0.12, 0.36), if i % 2 == 0 then P.plate else P.plateLight)
		if i % 2 == 1 then
			rig:ball(bone, "GoldRivet", v3(0, y + 0.07, z + 0.06), 0.075, P.gold)
		end
		if i % 3 == 0 then
			rig:block(bone, "GoldTrim", cf(0, y + 0.06, z + 0.16), v3(w * 0.85, 0.035, 0.04), P.gold)
		end
	end

	-- Rangées latérales, inclinées vers l'extérieur et décalées d'une demi-plaque
	rig:mirrored(function(side)
		for z = -1.21, 1.1, 0.28 do
			local x, y
			if z < -1.1 then
				x, y = 0.27, 0.78
			elseif z < -0.3 then
				x, y = 0.37, 0.76
			elseif z < 0.5 then
				x, y = 0.45, 0.77
			else
				x, y = 0.34, 0.72
			end
			rig:wedge(
				trunkBone(z),
				"SidePlate",
				cf(side * x, y, z) * ang(0, 0, -side * rad(40)),
				v3(0.28, 0.09, 0.3),
				if math.floor(z * 10) % 2 == 0 then P.plateDark else P.plate
			)
		end
	end)

	moss("Chest", v3(-0.26, 0.86, -0.62), 1.3, 0.4)
	moss("Body", v3(0.3, 0.87, 0.36), 1.45, 1.7)
	moss("Body", v3(-0.14, 0.83, 1.0), 1.05, 3.1)

	-- ===================================================================
	-- Tête
	-- ===================================================================
	rig:prism("Head", "Skull", cf(0, 0.72, -1.8), v3(0.76, 0.4, 0.62), 0.14, P.skin)
	rig:prism("Head", "Snout", cf(0, 0.66, -2.24), v3(0.52, 0.28, 0.4), 0.1, P.skin)
	rig:wedge("Head", "Bridge", cf(0, 0.86, -2.275), v3(0.36, 0.12, 0.33), P.skin)
	rig:prism("Head", "HeadPlate", cf(0, 0.93, -1.76), v3(0.42, 0.06, 0.5), 0.03, P.plateDark)
	rig:block("Head", "GoldGem", cf(0, 0.97, -1.92) * ang(0, rad(45), 0), v3(0.1, 0.04, 0.1), P.gold)
	rig:block("Head", "Mouth", cf(0, 0.545, -2.12), v3(0.48, 0.05, 0.55), P.mouth)
	moss("Head", v3(0.14, 0.94, -1.56), 0.75, 5.2)

	rig:mirrored(function(side, sfx)
		rig:wedge("Head", "Brow" .. sfx, cf(side * 0.29, 0.92, -1.84), v3(0.16, 0.1, 0.26), P.plateDark)
		-- Joues biseautées : la tête s'affine vers le museau (vue de dessus triangulaire)
		rig:wedgeTri("Head", "Jowl" .. sfx, v3(side * 0.26, 0.68, -2.1), v3(side, 0, 0), v3(0, 0, -1), 0.12, 0.3, 0.28, P.skin)
		rig:ball("Head", "EyeSocket" .. sfx, v3(side * 0.35, 0.8, -1.88), 0.2, P.skinDark)
		rig:ball("Head", "Eye" .. sfx, v3(side * 0.39, 0.8, -1.89), 0.17, P.eye)
		rig:block("Head", "Pupil" .. sfx, cf(side * 0.472, 0.8, -1.89), v3(0.02, 0.12, 0.04), P.pupil)
		rig:block("Head", "Nostril" .. sfx, cf(side * 0.12, 0.76, -2.44), v3(0.05, 0.03, 0.03), P.pupil)
		-- Barbe de mousse sous le menton
		rig:spike("Jaw", "MossBeard", cf(side * 0.08, 0.45, -2.2) * ang(math.pi, 0, side * rad(12)), 0.09, 0.14, 0.05, P.moss)
	end)

	rig:prism("Jaw", "Jaw", cf(0, 0.49, -2.03), v3(0.56, 0.1, 0.78), 0.04, P.belly)

	-- Langue fourchue (rentrée au repos, sortie par l'animateur)
	rig:strut("Tongue", "Tongue", v3(0, 0.555, -1.95), v3(0, 0.555, -2.32), 0.07, 0.03, P.tongue)
	rig:mirrored(function(side)
		rig:strut("Tongue", "TongueFork", v3(0, 0.555, -2.31), v3(side * 0.05, 0.555, -2.42), 0.04, 0.025, P.tongue)
	end)

	-- ===================================================================
	-- Pattes écartées
	-- ===================================================================
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, L in LEGS do
			local bone = "Leg_" .. key .. s
			local function m(v: Vector3): Vector3
				return v3(side * v.X, v.Y, v.Z)
			end
			local hip, knee, ankle, foot = m(L.hip), m(L.knee), m(L.ankle), m(L.foot)
			rig:prismBetween(bone, "Upper", hip, knee, L.upper[1], L.upper[2], 0.07, P.skin)
			rig:ball(bone, "Joint", knee, L.joint, P.skin)
			rig:prismBetween(bone, "Lower", knee + v3(0, 0.02, 0), ankle, L.lower[1], L.lower[2], 0.06, P.skin)
			rig:prism(bone, "Foot", cf(foot), v3(0.25, 0.1, 0.24), 0.04, P.skinDark)
			rig:wedge(
				bone,
				"LegPlate",
				cf(hip:Lerp(knee, 0.55) + v3(0, L.upper[2] / 2, 0)) * ang(0, 0, -side * rad(10)),
				v3(0.24, 0.07, 0.22),
				P.plate
			)
			for _, toe in L.toes do
				local a = rad(toe[1])
				local dir = v3(side * math.sin(a), 0, -math.cos(a))
				local tip = foot + dir * toe[2] + v3(0, -0.02, 0)
				rig:strut(bone, "Toe", foot, tip, 0.05, 0.05, P.skinDark)
				rig:wedge(bone, "Claw", Kit.lookAlong(tip + dir * 0.04, dir), v3(0.045, 0.05, 0.08), P.claw)
			end
		end
	end)

	-- ===================================================================
	-- Queue annelée à plaques
	-- ===================================================================
	for n, bone in tailBones do
		local a, b, w = TAIL[n], TAIL[n + 1], TAIL_W[n]
		local dir = (b - a).Unit
		rig:prismBetween(bone, "Tail", a - dir * 0.05, b + dir * 0.05, w, w * 0.78, w * 0.28, if n % 2 == 0 then P.skinDark else P.skin)
		for _, t in { 0.3, 0.75 } do
			local p = a:Lerp(b, t) + v3(0, w * 0.39, 0)
			rig:wedge(bone, "TailPlate", Kit.lookAlong(p, -dir), v3(w * 0.55, 0.08, (b - a).Magnitude * 0.42), P.plate)
		end
	end
	moss(tailBones[1], TAIL[1]:Lerp(TAIL[2], 0.55) + v3(0.12, 0.28, 0), 0.95, 2.4)

	rig:hitbox(cf(0, 0.5, 0.6), v3(2.1, 1.1, 5.4))

	-- ===================================================================
	-- Effets
	-- ===================================================================
	if rig.effects then
		local sc = rig.scale

		local pollen = rig:anchor("Body", "FX_Pollen", cf(0, 0.98, 0), v3(0.9, 0.2, 2.2))
		Fx.particles(pollen, {
			name = "MossPollen",
			texture = Fx.TEXTURES.sparkle,
			colors = { rgb(196, 236, 96), rgb(244, 255, 170) },
			sizes = { 0.1, 0.14, 0 },
			transparencies = { 0.3, 0.2, 1 },
			lifetime = NumberRange.new(2, 3.5),
			rate = 3,
			speed = NumberRange.new(0.1, 0.3),
			spread = Vector2.new(40, 40),
			acceleration = v3(0, 0.12, 0),
			drag = 1,
			lightEmission = 0.6,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-40, 40),
			volume = true,
		}, sc)

		local glint = rig:anchor("Body", "FX_GoldGlint", cf(0, 0.95, -0.1), v3(0.2, 0.1, 2.4))
		Fx.particles(glint, {
			name = "GoldGlint",
			texture = Fx.TEXTURES.sparkle,
			colors = { rgb(255, 220, 120) },
			sizes = { 0.28, 0 },
			transparencies = { 0.1, 1 },
			lifetime = NumberRange.new(0.3, 0.5),
			rate = 1.2,
			lockedToPart = true,
			lightEmission = 1,
			rotation = NumberRange.new(0, 360),
			volume = true,
		}, sc)

		local dust = rig:anchor("Root", "FX_Dust", cf(0, 0.1, 0.6), v3(2.0, 0.2, 3.6))
		Fx.particles(dust, {
			name = "GroundDust",
			texture = Fx.TEXTURES.smoke,
			colors = { rgb(140, 126, 98), rgb(104, 96, 80) },
			sizes = { 0.18, 0.45 },
			transparencies = { 1, 0.75, 1 },
			lifetime = NumberRange.new(1.2, 2),
			rate = 2.5,
			speed = NumberRange.new(0.1, 0.35),
			spread = Vector2.new(70, 70),
			acceleration = v3(0, 0.1, 0),
			drag = 1,
			rotation = NumberRange.new(0, 360),
			volume = true,
		}, sc)
	end

	return rig:finish({ Rarity = "Common" })
end

local LezardMousseux: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Lézard Mousseux",
	Rarity = "Common",
	Category = "Créature Commune",
	Description = "Reptile rampant des sous-bois humides. La mousse pousse entre ses écailles et de petites dorures ornent son dos.",
	Icon = {
		top = rgb(92, 74, 40),
		bottom = rgb(24, 20, 14),
		glow = rgb(236, 214, 120),
		motif = rgb(170, 230, 90),
		yaw = 40,
		pitch = 24,
		zoom = 1.15,
	},
	Animation = {
		gait = "Sprawler",
		breathe = 0.015,
		sway = 10,
		stride = 30,
		strideRate = 9,
		tailSway = 12,
		tailRate = 1.4,
		headLook = 18,
		tongueFlick = true,
	},
	build = build,
}

return LezardMousseux
