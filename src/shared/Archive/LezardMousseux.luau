--!strict
--[[
	LE LÉZARD MOUSSEUX — Commun
	===========================
	Reptile rampant recouvert de plaques écailleuses vertes et de mousse,
	avec de petites dorures sur le dos.

	Construction :
	  • corps + queue = un seul tube continu le long d'une colonne courbe (Kit.spine / Rig.tube),
	    recouvert de centaines d'écailles imbriquées en dégradé (vert-jaune sur le dessus,
	    vert profond sur les flancs) et d'écailles ventrales jaunes ;
	  • crête dorsale d'épines vert sombre à pointes dorées, du cou au bout de la queue ;
	  • dorures : collier et deux bagues de queue à rivets, losange au front ;
	  • touffes de mousse (Grass) en relief avec pousses et deux petits champignons ;
	  • tête effilée écaillée, yeux Neon ambre à pupille fendue, collerette d'épines
	    derrière les yeux, rangée de petites dents, mâchoire articulée, langue fourchue ;
	  • pattes écailleuses coudées, doigts écartés, griffes ivoire.
	  • Particules : pollen de mousse, reflets dorés le long de la crête, poussière au sol.

	Os (Motor6D) : Root > Body > Chest > Head > Jaw / Tongue
	                      Body > Tail1 > … > Tail6
	                      Chest > Leg_FR / Leg_FL      Body > Leg_BR / Leg_BL
]]

local Kit = require(script.Parent.Parent.Kit)
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

local ID = "LezardMousseux"

local P = {
	core = S(rgb(38, 122, 86)),
	scales = {
		S(rgb(190, 234, 98)),
		S(rgb(136, 210, 88)),
		S(rgb(82, 178, 90)),
		S(rgb(46, 140, 92)),
	},
	headScales = {
		S(rgb(150, 212, 84)),
		S(rgb(92, 182, 86)),
		S(rgb(48, 140, 88)),
	},
	limbScales = {
		S(rgb(100, 188, 84)),
		S(rgb(56, 150, 88)),
		S(rgb(34, 114, 84)),
	},
	belly = { S(rgb(255, 236, 150)), S(rgb(240, 204, 104)) },
	bellyCore = S(rgb(236, 196, 96)),
	spike = S(rgb(22, 84, 78)),
	gold = S(rgb(255, 198, 54)),
	goldDark = S(rgb(214, 138, 26)),
	moss = { S(rgb(130, 204, 56), M.Grass), S(rgb(98, 172, 42), M.Grass), S(rgb(170, 226, 80), M.Grass) },
	mossPad = S(rgb(76, 140, 40), M.Grass),
	sprout = S(rgb(196, 240, 96)),
	stem = S(rgb(250, 236, 200)),
	cap = S(rgb(232, 64, 54)),
	dot = S(rgb(255, 250, 240)),
	eye = S(rgb(255, 196, 40), M.Neon),
	socket = S(rgb(18, 58, 50)),
	pupil = S(rgb(16, 14, 12)),
	mouth = S(rgb(150, 40, 60)),
	tooth = S(rgb(250, 246, 232)),
	tongue = S(rgb(236, 74, 116)),
	claw = S(rgb(244, 236, 214)),
	toe = S(rgb(40, 128, 86)),
}

-- Colonne du cou au bout de la queue (de l'avant vers l'arrière)
local SPINE = Kit.spine({
	{ pos = v3(0, 0.62, -1.5), rx = 0.28, ry = 0.22 },
	{ pos = v3(0, 0.6, -1.1), rx = 0.36, ry = 0.26 },
	{ pos = v3(0, 0.57, -0.6), rx = 0.46, ry = 0.29 },
	{ pos = v3(0, 0.56, 0.05), rx = 0.54, ry = 0.31 },
	{ pos = v3(0, 0.55, 0.7), rx = 0.46, ry = 0.28 },
	{ pos = v3(0, 0.5, 1.25), rx = 0.32, ry = 0.24 },
	{ pos = v3(0.06, 0.4, 1.9), rx = 0.24, ry = 0.19 },
	{ pos = v3(0.24, 0.3, 2.6), rx = 0.17, ry = 0.14 },
	{ pos = v3(0.42, 0.24, 3.3), rx = 0.12, ry = 0.1 },
	{ pos = v3(0.36, 0.2, 3.95), rx = 0.085, ry = 0.075 },
	{ pos = v3(0.05, 0.18, 4.5), rx = 0.05, ry = 0.045 },
	{ pos = v3(-0.3, 0.17, 4.85), rx = 0.02, ry = 0.02 },
})
local TAIL_START = 6 -- section où commence la queue

-- Tête (du bout du museau vers la nuque)
local HEAD = Kit.spine({
	{ pos = v3(0, 0.6, -2.5), rx = 0.09, ry = 0.065 },
	{ pos = v3(0, 0.63, -2.32), rx = 0.2, ry = 0.12 },
	{ pos = v3(0, 0.68, -2.05), rx = 0.3, ry = 0.17 },
	{ pos = v3(0, 0.71, -1.78), rx = 0.36, ry = 0.21 },
	{ pos = v3(0, 0.67, -1.48), rx = 0.29, ry = 0.21 },
})

local JAW = Kit.spine({
	{ pos = v3(0, 0.505, -2.44), rx = 0.08, ry = 0.035 },
	{ pos = v3(0, 0.5, -2.2), rx = 0.19, ry = 0.06 },
	{ pos = v3(0, 0.52, -1.72), rx = 0.27, ry = 0.08 },
})

-- Pattes : épaule/hanche -> coude/genou -> poignet/cheville (rayons), doigts (angle, longueur)
local LEGS = {
	F = {
		path = { { v3(0.35, 0.56, -0.85), 0.14, 0.13 }, { v3(0.8, 0.5, -0.95), 0.11, 0.1 }, { v3(0.88, 0.13, -1.02), 0.08, 0.08 } },
		foot = v3(0.9, 0.06, -1.06),
		toes = { { -45, 0.2 }, { -15, 0.27 }, { 15, 0.26 }, { 45, 0.2 } },
	},
	B = {
		path = { { v3(0.32, 0.56, 0.85), 0.2, 0.18 }, { v3(0.8, 0.52, 0.72), 0.14, 0.13 }, { v3(0.92, 0.13, 0.86), 0.09, 0.09 } },
		foot = v3(0.95, 0.06, 0.86),
		toes = { { 5, 0.26 }, { 35, 0.34 }, { 65, 0.3 }, { 100, 0.2 } },
	},
}

local function trunkBone(u: number): string
	if u < 3.6 then
		return "Chest"
	elseif u < TAIL_START then
		return "Body"
	end
	return "Tail" .. math.clamp(math.floor(u - TAIL_START) + 1, 1, 6)
end

-- Capacité spéciale (CreatureForge.playAbility)
local ABILITY: Types.Ability = {
	name = "Nuage de pollen",
	kind = "Breath",
	colors = { rgb(200, 240, 96), rgb(120, 200, 60), rgb(255, 255, 200) },
	texture = "smoke",
	origin = v3(0, 0.6, -2.5),
	direction = v3(0, 0.15, -1),
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)

	-- ===================================================================
	-- Squelette
	-- ===================================================================
	rig:bone("Body", "Root", cf(0, 0.56, 0.3))
	rig:bone("Chest", "Body", cf(0, 0.57, -0.3))
	rig:bone("Head", "Chest", cf(0, 0.64, -1.48))
	rig:bone("Jaw", "Head", cf(0, 0.56, -1.66))
	rig:bone("Tongue", "Head", cf(0, 0.545, -1.95))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		local f, b = LEGS.F.path[1][1], LEGS.B.path[1][1]
		rig:bone("Leg_F" .. s, "Chest", cf(side * f.X, f.Y, f.Z))
		rig:bone("Leg_B" .. s, "Body", cf(side * b.X, b.Y, b.Z))
	end)
	local tailJoints = {}
	for i = TAIL_START, #SPINE.sections do
		table.insert(tailJoints, SPINE:pos(i))
	end
	rig:boneChain("Tail", "Body", tailJoints)

	-- ===================================================================
	-- Touffe de mousse (+ champignon optionnel), posée sur un repère de surface
	-- ===================================================================
	local function moss(bone: string, base: CFrame, size: number, seed: number, mushroom: boolean?)
		local rng = Random.new(seed)
		local function at(x: number, y: number, z: number): CFrame
			return base * cf(x * size, y * size, z * size)
		end
		rig:prism(bone, "MossPad", at(0, 0, 0) * ang(0, seed, 0), v3(0.42, 0.07, 0.36) * size, 0.05 * size, P.mossPad)
		local blobs = {
			{ 0, 0.09, 0, 0.28 },
			{ 0.14, 0.06, 0.09, 0.21 },
			{ -0.13, 0.05, -0.06, 0.2 },
			{ 0.04, 0.06, -0.15, 0.17 },
			{ -0.08, 0.07, 0.14, 0.16 },
		}
		for i, b in blobs do
			rig:ball(bone, "Moss", at(b[1], b[2], b[3]).Position, b[4] * size, P.moss[(i % #P.moss) + 1])
		end
		for k = 0, 3 do
			local a = seed + k * 1.7
			local r = 0.06 + rng:NextNumber() * 0.08
			rig:spike(
				bone,
				"Sprout",
				at(math.cos(a) * r, 0.1, math.sin(a) * r) * ang(math.cos(a) * 0.4, a, math.sin(a) * 0.4),
				0.05 * size,
				(0.14 + k * 0.03) * size,
				0.02 * size,
				P.sprout
			)
		end
		if mushroom then
			local foot = at(0.12, 0.08, 0.1)
			rig:cylinder(bone, "MushroomStem", foot.Position, (foot * cf(0, 0.2 * size, 0)).Position, 0.075 * size, P.stem)
			-- Chapeau en dôme : trois disques octogonaux empilés (axe = normale)
			for k, d in { { 0.27, 0.05 }, { 0.21, 0.05 }, { 0.12, 0.04 } } do
				local capCF = foot * cf(0, (0.2 + (k - 1) * 0.045) * size, 0) * ang(-math.pi / 2, 0, 0)
				rig:prism(bone, "MushroomCap", capCF, v3(d[1], d[1], d[2]) * size, d[1] * 0.3 * size, P.cap)
			end
			for k = 0, 3 do
				local a = k * 1.6 + 0.4
				local r = if k == 3 then 0 else 0.075
				local y = if k == 3 then 0.3 else 0.255
				local dot = foot * cf(math.cos(a) * r * size, y * size, math.sin(a) * r * size)
				rig:ball(bone, "MushroomDot", dot.Position, 0.045 * size, P.dot)
			end
		end
	end

	-- ===================================================================
	-- Corps + queue : noyau, écailles dorsales, écailles ventrales
	-- ===================================================================
	rig:tube(SPINE, {
		name = "Trunk",
		bone = trunkBone,
		core = P.core,
		coreStep = 0.28,
		cover = {
			{
				kind = "Scale",
				size = v3(0.3, 0.11, 0.32),
				spacing = 0.24,
				arc = 112,
				shades = P.scales,
				tilt = 22,
				refRadius = 0.42,
				seed = 11,
			},
			{
				kind = "Scale",
				size = v3(0.28, 0.06, 0.24),
				spacing = 0.22,
				arc = 60,
				center = 180,
				to = 10,
				shades = P.belly,
				tilt = 8,
				refRadius = 0.42,
				jitter = 0.15,
				seed = 12,
			},
		},
	})

	-- Crête dorsale : épines vert sombre à pointe dorée
	do
		local s, sEnd, i = SPINE:lengthAt(1.3), SPINE:lengthAt(11.3), 0
		while s < sEnd do
			local u = SPINE:uAt(s)
			local _, ry = SPINE:radii(u)
			local k = math.clamp(ry / 0.3, 0.45, 1.1)
			-- Lame en dents de scie (plaque orientée le long de l'échine) + pointe dorée
			local h = 0.36 * k * (if i % 2 == 0 then 1 else 0.7)
			local base = SPINE:surface(u, 0, 0.04 * k) * ang(rad(34), 0, 0) * ang(0, math.pi / 2, 0)
			rig:spike(trunkBone(u), "Spike", base, 0.22 * k, h, 0.05 * k, P.spike)
			rig:spike(trunkBone(u), "SpikeTip", base * cf(0, h * 0.58, 0), 0.11 * k, h * 0.48, 0.07 * k, P.gold)
			s += 0.25 * k
			i += 1
		end
	end

	-- Dorures : collier + deux bagues de queue à rivets
	rig:band(SPINE, "Chest", "GoldCollar", 1.75, 0.12, 0.06, P.gold, P.goldDark)
	rig:band(SPINE, trunkBone(6.9), "GoldBand", 6.9, 0.1, 0.05, P.gold, P.goldDark)
	rig:band(SPINE, trunkBone(8.5), "GoldBand", 8.5, 0.08, 0.04, P.gold, P.goldDark)

	-- Mousse sur le dos et la base de la queue
	moss("Chest", SPINE:surface(3.0, -38, 0.06), 1.15, 1, true)
	moss("Body", SPINE:surface(4.4, 32, 0.07), 1.35, 2, false)
	moss("Body", SPINE:surface(5.5, -24, 0.06), 1.0, 3, true)
	moss(trunkBone(6.4), SPINE:surface(6.4, 28, 0.05), 0.85, 4, false)

	-- ===================================================================
	-- Tête
	-- ===================================================================
	rig:tube(HEAD, {
		name = "Head",
		bone = function()
			return "Head"
		end,
		core = P.core,
		coreStep = 0.2,
		cover = {
			{
				kind = "Scale",
				size = v3(0.17, 0.06, 0.17),
				spacing = 0.14,
				arc = 100,
				from = 1.6,
				shades = P.headScales,
				tilt = 14,
				refRadius = 0.3,
				jitter = 0.2,
				seed = 21,
			},
		},
	})
	rig:tube(JAW, {
		name = "Jaw",
		bone = function()
			return "Jaw"
		end,
		core = P.bellyCore,
		coreStep = 0.2,
	})
	rig:block("Head", "Mouth", cf(0, 0.535, -2.08), v3(0.42, 0.04, 0.62), P.mouth)
	rig:block("Head", "GoldGem", cf(0, 0.935, -1.86) * ang(0, rad(45), 0), v3(0.11, 0.05, 0.11), P.gold)
	moss("Head", HEAD:surface(4.4, 20, 0.03), 0.6, 5, false)

	rig:mirrored(function(side, sfx)
		-- Yeux
		rig:ball("Head", "EyeSocket" .. sfx, v3(side * 0.3, 0.82, -1.84), 0.21, P.socket)
		rig:ball("Head", "Eye" .. sfx, v3(side * 0.335, 0.83, -1.86), 0.17, P.eye)
		rig:block("Head", "Pupil" .. sfx, cf(side * 0.418, 0.83, -1.86), v3(0.02, 0.12, 0.035), P.pupil)
		rig:wedge("Head", "Brow" .. sfx, cf(side * 0.27, 0.93, -1.86) * ang(0, 0, -side * rad(18)), v3(0.2, 0.08, 0.28), P.headScales[3])
		rig:block("Head", "Nostril" .. sfx, cf(side * 0.07, 0.66, -2.47), v3(0.04, 0.03, 0.03), P.pupil)

		-- Collerette d'épines derrière les yeux (pointes dorées)
		for k = 0, 2 do
			local base = cf(side * (0.27 + k * 0.03), 0.8 - k * 0.07, -1.6 + k * 0.04)
				* ang(rad(62 - k * 6), side * rad(-30 - k * 12), side * rad(-20))
			local h = 0.24 - k * 0.04
			rig:thorn("Head", "Frill" .. sfx, base, 0.09, h, P.spike)
			rig:thorn("Head", "FrillTip" .. sfx, base * cf(0, h * 0.6, 0), 0.045, h * 0.5, P.gold)
		end

		-- Petites dents le long de la lèvre supérieure
		for k = 0, 4 do
			rig:thorn("Head", "Tooth" .. sfx, cf(side * (0.07 + k * 0.045), 0.545, -2.36 + k * 0.12) * ang(math.pi, 0, 0), 0.035, 0.055, P.tooth)
		end
	end)

	-- Langue fourchue (rentrée au repos, sortie par l'animateur)
	rig:strut("Tongue", "Tongue", v3(0, 0.545, -1.95), v3(0, 0.545, -2.32), 0.07, 0.03, P.tongue)
	rig:mirrored(function(side)
		rig:strut("Tongue", "TongueFork", v3(0, 0.545, -2.31), v3(side * 0.05, 0.545, -2.42), 0.04, 0.025, P.tongue)
	end)

	-- ===================================================================
	-- Pattes écailleuses
	-- ===================================================================
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, L in LEGS do
			local bone = "Leg_" .. key .. s
			local sections = {}
			for _, p in L.path do
				table.insert(sections, { pos = v3(side * p[1].X, p[1].Y, p[1].Z), rx = p[2], ry = p[3] })
			end
			rig:tube(Kit.spine(sections), {
				name = "Leg",
				bone = function()
					return bone
				end,
				core = P.core,
				coreStep = 0.2,
				cover = {
					{
						kind = "Scale",
						size = v3(0.17, 0.05, 0.15),
						spacing = 0.13,
						arc = 180,
						shades = P.limbScales,
						tilt = 16,
						refRadius = 0.13,
						jitter = 0.2,
						seed = (if key == "F" then 30 else 40) + side,
					},
				},
			})
			local foot = v3(side * L.foot.X, L.foot.Y, L.foot.Z)
			rig:prism(bone, "Foot", cf(foot), v3(0.24, 0.09, 0.22), 0.04, P.limbScales[2])
			for _, toe in L.toes do
				local a = rad(toe[1])
				local dir = v3(side * math.sin(a), 0, -math.cos(a))
				local tip = foot + dir * toe[2] + v3(0, -0.015, 0)
				rig:strut(bone, "Toe", foot, tip, 0.06, 0.05, P.toe)
				rig:ball(bone, "ToePad", tip, 0.07, P.limbScales[1])
				rig:wedge(bone, "Claw", Kit.lookAlong(tip + dir * 0.06, dir), v3(0.04, 0.05, 0.09), P.claw)
			end
		end
	end)

	rig:hitbox(cf(0, 0.5, 0.6), v3(2.1, 1.1, 5.4))

	-- ===================================================================
	-- Effets
	-- ===================================================================
	if rig.effects then
		local sc = rig.scale

		local pollen = rig:anchor("Body", "FX_Pollen", cf(0, 1.0, -0.1), v3(0.9, 0.2, 2.4))
		Fx.particles(pollen, {
			name = "MossPollen",
			texture = Fx.TEXTURES.sparkle,
			colors = { rgb(200, 240, 96), rgb(250, 255, 176) },
			sizes = { 0.1, 0.15, 0 },
			transparencies = { 0.3, 0.15, 1 },
			lifetime = NumberRange.new(2, 3.5),
			rate = 3.5,
			speed = NumberRange.new(0.1, 0.3),
			spread = Vector2.new(40, 40),
			acceleration = v3(0, 0.12, 0),
			drag = 1,
			lightEmission = 0.7,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-40, 40),
			volume = true,
		}, sc)

		local glint = rig:anchor("Body", "FX_GoldGlint", cf(0, 1.02, 0), v3(0.25, 0.15, 3.2))
		Fx.particles(glint, {
			name = "GoldGlint",
			texture = Fx.TEXTURES.sparkle,
			colors = { rgb(255, 226, 120) },
			sizes = { 0.3, 0 },
			transparencies = { 0.05, 1 },
			lifetime = NumberRange.new(0.3, 0.5),
			rate = 2,
			lockedToPart = true,
			lightEmission = 1,
			rotation = NumberRange.new(0, 360),
			volume = true,
		}, sc)

		local dust = rig:anchor("Root", "FX_Dust", cf(0, 0.1, 0.6), v3(2.0, 0.2, 3.6))
		Fx.particles(dust, {
			name = "GroundDust",
			texture = Fx.TEXTURES.smoke,
			colors = { rgb(150, 132, 98), rgb(112, 100, 80) },
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


	-- Effets avancés : signature, origine de la capacité, aura de rareté
	if rig.effects then
		-- Traînée verte au bout de la queue
		local tip = SPINE:pos(12)
		Vfx.trail(rig, "Tail6", tip + v3(0, 0.05, 0), tip - v3(0, 0.05, 0), { colors = { rgb(200, 255, 120) }, lifetime = 0.35 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Common")
	end

	return rig:finish({ Rarity = "Common" })
end

local LezardMousseux: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Lézard Mousseux",
	Rarity = "Common",
	Zone = "Surface",
	Scale = 1.2,
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
	Ability = ABILITY,
	build = build,
}

return LezardMousseux
