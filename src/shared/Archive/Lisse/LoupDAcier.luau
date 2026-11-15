--!strict
--[[
	LOUP D'ACIER — Commun · Moyen
	=============================
	Loup au pelage métallique qui brille au soleil.
	
	• Fourrure en lames d'acier poli (matériau Metal, reflets), pointes argent clair.
	• Crinière d'épines métalliques, plaques d'acier bleui sur le ventre et les pattes.
	• Collier d'acier riveté, runes cyan ; yeux Neon bleu glacier, crocs d'acier.
	• Effets : éclats de lumière (reflets du soleil) qui scintillent sur le pelage.
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

local ID = "LoupDAcier"

local P = {
	core = S(rgb(70, 76, 88)),
	fur = { S(rgb(206, 212, 222), M.Metal, { reflectance = 0.15 }), S(rgb(168, 176, 188), M.Metal, { reflectance = 0.12 }), S(rgb(130, 138, 152), M.Metal, { reflectance = 0.1 }), S(rgb(96, 104, 118), M.Metal) },
	tip = S(rgb(244, 248, 255), M.Metal, { reflectance = 0.25 }),
	mud = { S(rgb(92, 104, 126), M.Metal), S(rgb(74, 84, 104), M.Metal), S(rgb(58, 66, 84), M.Metal) },
	mudTip = S(rgb(150, 166, 196), M.Metal),
	nose = S(rgb(30, 32, 38)),
	mouth = S(rgb(110, 30, 44)),
	tooth = S(rgb(230, 236, 246), M.Metal),
	eye = S(rgb(120, 220, 255), M.Neon),
	socket = S(rgb(16, 20, 28)),
	leather = S(rgb(60, 66, 80), M.Metal),
	steel = S(rgb(220, 226, 236), M.Metal),
	rune = S(rgb(120, 220, 255), M.Neon),
	wisp = S(rgb(230, 245, 255), M.Neon),
	wispHalo = S(rgb(200, 235, 255), M.Neon, { transparency = 0.6 }),
	claw = S(rgb(236, 240, 248), M.Metal),
	inner = S(rgb(120, 90, 100)),
}

local BODY = Kit.spine({
	{ pos = v3(0, 1.75, -1.05), rx = 0.3, ry = 0.34 },
	{ pos = v3(0, 1.55, -0.65), rx = 0.5, ry = 0.56 },
	{ pos = v3(0, 1.5, -0.1), rx = 0.46, ry = 0.48 },
	{ pos = v3(0, 1.52, 0.4), rx = 0.44, ry = 0.44 },
	{ pos = v3(0, 1.42, 0.8), rx = 0.3, ry = 0.3 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 1.74, -2.05), rx = 0.08, ry = 0.08 },
	{ pos = v3(0, 1.77, -1.85), rx = 0.16, ry = 0.15 },
	{ pos = v3(0, 1.84, -1.6), rx = 0.24, ry = 0.22 },
	{ pos = v3(0, 1.92, -1.35), rx = 0.34, ry = 0.3 },
	{ pos = v3(0, 1.9, -1.1), rx = 0.3, ry = 0.3 },
})

local JAW = Kit.spine({
	{ pos = v3(0, 1.6, -1.98), rx = 0.07, ry = 0.04 },
	{ pos = v3(0, 1.62, -1.75), rx = 0.15, ry = 0.06 },
	{ pos = v3(0, 1.66, -1.4), rx = 0.22, ry = 0.08 },
})

local TAIL = Kit.spine({
	{ pos = v3(0, 1.48, 0.85), rx = 0.12, ry = 0.12 },
	{ pos = v3(0, 1.25, 1.25), rx = 0.26, ry = 0.26 },
	{ pos = v3(0, 0.95, 1.6), rx = 0.28, ry = 0.28 },
	{ pos = v3(0.05, 0.7, 1.82), rx = 0.18, ry = 0.18 },
	{ pos = v3(0.08, 0.55, 1.92), rx = 0.03, ry = 0.03 },
})

-- Capacité spéciale (CreatureForge.playAbility)
local ABILITY: Types.Ability = {
	name = "Hurlement d'acier",
	kind = "Nova",
	colors = { rgb(162, 227, 255), rgb(100, 142, 160), rgb(222, 245, 255) },
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

	rig:bone("Body", "Root", cf(0, 1.5, 0))
	rig:bone("Head", "Body", cf(0, 1.8, -1.05))
	rig:bone("Jaw", "Head", cf(0, 1.66, -1.35))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.32, 1.35, -0.6))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.32, 1.4, 0.45))
		rig:bone("Ear" .. sfx, "Head", cf(side * 0.2, 2.15, -1.15))
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
		coreStep = 0.28,
		cover = {
			A.fur(P.fur, P.tip, v3(0.24, 0.44, 0.38), 0.19, { arc = 115, seed = 1 }),
			A.fur(P.mud, P.mudTip, v3(0.22, 0.32, 0.32), 0.2, { arc = 70, center = 180, seed = 2 }),
		},
	})
	-- Crinière
	A.crest(rig, BODY, const("Body"), 1.0, 3.2, 0.14, 0.62, 0.24, P.fur[4], P.tip, 0, 40)
	A.crest(rig, BODY, const("Body"), 1.0, 2.6, 0.18, 0.5, 0.22, P.fur[3], P.tip, 45, 40)
	A.crest(rig, BODY, const("Body"), 1.0, 2.6, 0.18, 0.5, 0.22, P.fur[3], P.tip, -45, 40)

	-- Collier runique
	rig:band(BODY, "Body", "Collar", 1.35, 0.18, 0.12, P.leather)
	for i, deg in { -70, -35, 0, 35, 70 } do
		local c = BODY:surface(1.35, deg, 0.1)
		if i % 2 == 1 then
			rig:thorn("Body", "CollarStud", c, 0.08, 0.12, P.steel)
		else
			A.rune(rig, "Body", c * cf(0, 0.01, 0) * ang(-math.pi / 2, 0, 0), 0.14, P.rune, i)
		end
	end

	-- Tête, gueule entrouverte
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.16,
		cover = { A.fur(P.fur, P.tip, v3(0.16, 0.24, 0.22), 0.13, { arc = 130, from = 2.4, refRadius = 0.3, seed = 3 }) },
	})
	rig:tube(JAW, { name = "Jaw", bone = const("Jaw"), core = P.fur[3], coreStep = 0.15 })
	rig:block("Jaw", "Mouth", cf(0, 1.69, -1.65), v3(0.24, 0.03, 0.55), P.mouth)
	rig:ball("Head", "Nose", v3(0, 1.79, -2.08), 0.12, P.nose)
	rig:mirrored(function(side, sfx)
		A.teeth(rig, "Head", A.mx(v3(0.06, 1.7, -2.0), side), A.mx(v3(0.18, 1.74, -1.55), side), 5, 0.04, 0.07, P.tooth, true)
		A.teeth(rig, "Jaw", A.mx(v3(0.06, 1.66, -1.95), side), A.mx(v3(0.16, 1.68, -1.55), side), 4, 0.035, 0.06, P.tooth, false)
		rig:thorn("Head", "Fang", cf(A.mx(v3(0.1, 1.72, -1.95), side)) * ang(math.pi, 0, 0), 0.06, 0.16, P.tooth)
		A.eye(rig, "Head", A.mx(v3(0.2, 2.0, -1.5), side), v3(side, 0.3, -0.6), 0.12, "Glow", P.socket, P.eye)
		A.brow(rig, "Head", side, v3(0.18, 2.09, -1.52), 0.24, 26, P.fur[4])
		A.ear(rig, "Ear" .. sfx, cf(A.mx(v3(0.2, 2.15, -1.15), side)) * ang(rad(-12), side * rad(-20), side * rad(-18)), 0.3, 0.46, P.fur[2], P.inner, P.fur[4])
		A.tuftBurst(rig, "Head", cf(A.mx(v3(0.28, 1.8, -1.2), side)) * ang(0, side * rad(-40), -side * rad(95)), 5, 0.32, 0.12, P.fur, P.tip, 25, 7 + side)
	end)

	-- Pattes boueuses
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, L in { F = { v3(0.32, 1.35, -0.6), v3(0.34, 0.75, -0.62), v3(0.34, 0.16, -0.7), 0.2 }, B = { v3(0.32, 1.4, 0.45), v3(0.36, 0.82, 0.62), v3(0.34, 0.16, 0.54), 0.28 } } do
			local bone = "Leg_" .. key .. s
			A.limb(rig, bone, side, { { L[1], L[4], L[4] * 1.2 }, { L[2], 0.12, 0.12 }, { L[3], 0.085, 0.085 } }, P.mud[3], A.fur(P.mud, P.mudTip, v3(0.18, 0.28, 0.26), 0.15, { arc = 180, refRadius = 0.2, seed = 10 + side }))
			A.paw(rig, bone, A.mx((L[3] :: Vector3) - v3(0, 0.16, 0.08), side), v3(0, 0, -1), 0.26, 4, P.mud[3], P.mud[2], P.claw)
			for k = 0, 2 do
				rig:ball(bone, "MudDrop", A.mx((L[2] :: Vector3):Lerp(L[3] :: Vector3, 0.3 + k * 0.25) + v3(0.1, 0, -0.06), side), 0.09 - k * 0.015, P.mud[1])
			end
		end
	end)

	rig:tube(TAIL, {
		name = "Tail",
		bone = function(u)
			return tail[math.clamp(math.floor(u), 1, #tail)]
		end,
		core = P.core,
		coreStep = 0.2,
		cover = { A.fur(P.fur, P.tip, v3(0.22, 0.42, 0.36), 0.16, { arc = 180, refRadius = 0.26, seed = 6 }) },
	})

	-- Feux follets des marais
	A.orbit(rig, "Aura1", v3(0, 1.8, 0), 1.9, 3, 0.3, function(bone, c)
		rig:ball(bone, "Wisp", c.Position, 0.2, P.wisp)
		rig:ball(bone, "WispHalo", c.Position, 0.38, P.wispHalo)
	end)

	rig:hitbox(cf(0, 1.3, -0.3), v3(1.5, 2.6, 4.0))

	if rig.effects then
		local sc = rig.scale
		local w = rig:anchor("Body", "FX_Wisps", cf(0, 1.6, 0), v3(1.4, 1, 2.4))
		Fx.particles(w, Fx.sparkles("MarshLights", { rgb(186, 234, 255), rgb(142, 197, 220) }, 4, 0.2, 0.1), sc)
		Fx.light(rig.bones.Head, { color = rgb(150, 223, 255), range = 6, brightness = 1 }, sc)
		local drip = rig:anchor("Body", "FX_Mud", cf(0, 1.0, 0), v3(0.8, 0.1, 1.4))
		Fx.particles(drip, {
			name = "SteelGlints",
			texture = Fx.TEXTURES.spark,
			colors = { rgb(74, 99, 110) },
			sizes = { 0.1, 0.07 },
			lifetime = NumberRange.new(0.6, 0.9),
			rate = 3,
			speed = NumberRange.new(0, 0.2),
			acceleration = v3(0, 0.2, 0),
			direction = Enum.NormalId.Bottom,
			volume = true,
		}, sc)
	end


	-- Effets avancés : signature, origine de la capacité, aura de rareté
	if rig.effects then
		Vfx.orbitTethers(rig, "Aura1", Vfx.orbitPoints(v3(0, 1.8, 0), 1.9, 3, 0.3), "Body", v3(0, 1.75, -0.95), { colors = { rgb(186, 234, 255), rgb(128, 178, 200) }, transparency = { 0.4, 0.9 }, width0 = 0.06, width1 = 0.02, curve0 = 0.5 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Common")
	end

	return rig:finish({ Rarity = "Common" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Loup d'acier",
	Rarity = "Common",
	Size = "Medium",
	Income = 9,
	SpeedBonus = 0.07,
	Passenger = false,
	Scale = 2.0,
	Category = "Créature Commune",
	Description = "Loup au pelage d'acier poli : au soleil, chaque mèche renvoie un éclat de lumière.",
	Icon = { top = rgb(80, 100, 130), bottom = rgb(14, 18, 26), glow = rgb(200, 230, 255), motif = rgb(120, 220, 255), yaw = 34, pitch = 12, zoom = 1.1 },
	Animation = { flicker = 0.15, gait = "Quadruped", breathe = 0.035, bob = 0.12, stride = 34, strideRate = 12, tailSway = 10, tailRate = 1.6, headLook = 18, sniff = true, earTwitch = true, auraSpeed = 0.5 },
	Ability = ABILITY,
	build = build,
}

return Def
