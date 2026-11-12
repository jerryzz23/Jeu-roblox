--!strict
--[[
	L'OURS RUNIQUE — Rare · La Pente Brumeuse
	=========================================
	Colosse massif capable de porter des passagers, équipé d'une selle sculptée
	et de brassards en pierre gravée.

	• Énorme corps à bosse d'épaules, fourrure brune en mèches à pointes claires.
	• Selle sculptée en bois (Wood) à liserés dorés + Seat : MONTABLE.
	• Brassards et épaulières de pierre (Slate) gravés de runes Neon bleues.
	• Tête ronde, museau clair, yeux Neon runiques, oreilles rondes ; griffes ivoire.
	• 4 pierres runiques en orbite ; effets : poussière de runes, lueur bleue.
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

local ID = "OursRunique"

local P = {
	core = S(rgb(70, 44, 28)),
	fur = { S(rgb(160, 108, 68)), S(rgb(130, 86, 54)), S(rgb(102, 66, 42)), S(rgb(76, 48, 32)) },
	tip = S(rgb(220, 180, 126)),
	muzzle = S(rgb(214, 176, 130)),
	nose = S(rgb(30, 22, 20)),
	stone = { S(rgb(150, 154, 166), M.Slate), S(rgb(118, 122, 136), M.Slate), S(rgb(90, 94, 108), M.Slate) },
	rune = S(rgb(80, 200, 255), M.Neon),
	wood = S(rgb(150, 96, 52), M.Wood),
	woodDark = S(rgb(104, 64, 36), M.Wood),
	cloth = S(rgb(150, 30, 40), M.Fabric),
	gold = S(rgb(255, 200, 56)),
	goldDark = S(rgb(208, 132, 24)),
	eye = S(rgb(110, 220, 255), M.Neon),
	socket = S(rgb(20, 14, 12)),
	claw = S(rgb(246, 238, 220)),
	pad = S(rgb(50, 34, 28)),
	inner = S(rgb(180, 120, 100)),
}

local BODY = Kit.spine({
	{ pos = v3(0, 1.9, -1.2), rx = 0.46, ry = 0.5 },
	{ pos = v3(0, 2.05, -0.7), rx = 0.85, ry = 0.85 },
	{ pos = v3(0, 1.95, 0.0), rx = 0.9, ry = 0.82 },
	{ pos = v3(0, 1.85, 0.7), rx = 0.82, ry = 0.76 },
	{ pos = v3(0, 1.6, 1.25), rx = 0.5, ry = 0.48 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 1.76, -2.28), rx = 0.14, ry = 0.12 },
	{ pos = v3(0, 1.82, -2.08), rx = 0.26, ry = 0.22 },
	{ pos = v3(0, 1.95, -1.82), rx = 0.4, ry = 0.36 },
	{ pos = v3(0, 2.05, -1.5), rx = 0.5, ry = 0.48 },
	{ pos = v3(0, 2.0, -1.2), rx = 0.44, ry = 0.46 },
})

-- Capacité spéciale (CreatureForge.playAbility)
local ABILITY: Types.Ability = {
	name = "Frappe runique",
	kind = "Stomp",
	colors = { rgb(90, 200, 255), rgb(40, 100, 200), rgb(255, 255, 255) },
	texture = "spark",
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
	rig:bone("Head", "Body", cf(0, 1.95, -1.2))
	rig:bone("Jaw", "Head", cf(0, 1.7, -1.7))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.62, 1.7, -0.75))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.62, 1.75, 0.75))
		rig:bone("Ear" .. sfx, "Head", cf(side * 0.36, 2.45, -1.45))
	end)

	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.35,
		cover = { A.fur(P.fur, P.tip, v3(0.3, 0.5, 0.44), 0.24, { arc = 160, refRadius = 0.7, seed = 1 }) },
	})

	-- Selle sculptée + couverture
	local base = BODY:surface(2.55, 0, 0.12)
	rig:prism("Body", "Blanket", base * cf(0, -0.04, 0), v3(1.6, 0.08, 1.2), 0.04, P.cloth)
	rig:mirrored(function(side)
		local flap = base * cf(side * 0.86, -0.42, 0) * ang(0, 0, side * rad(68))
		rig:prism("Body", "BlanketFlap", flap, v3(0.8, 0.07, 1.15), 0.03, P.cloth)
		rig:block("Body", "BlanketTrim", flap * cf(0, 0, 0.6), v3(0.82, 0.09, 0.06), P.gold)
		rig:block("Body", "BlanketTrim", flap * cf(0, 0, -0.6), v3(0.82, 0.09, 0.06), P.gold)
		A.rune(rig, "Body", flap * cf(0, -side * 0.05, 0) * ang(math.pi / 2, 0, 0), 0.4, P.rune, if side > 0 then 3 else 6)
	end)
	rig:prism("Body", "Saddle", base * cf(0, 0.1, 0), v3(0.95, 0.18, 1.0), 0.08, P.wood)
	rig:prism("Body", "SaddleBack", base * cf(0, 0.32, 0.46) * ang(rad(-15), 0, 0), v3(0.85, 0.4, 0.14), 0.06, P.woodDark)
	rig:prism("Body", "SaddleFront", base * cf(0, 0.26, -0.48) * ang(rad(18), 0, 0), v3(0.6, 0.3, 0.12), 0.05, P.woodDark)
	rig:block("Body", "SaddleTrim", base * cf(0, 0.53, 0.5) * ang(rad(-15), 0, 0), v3(0.87, 0.05, 0.16), P.gold)
	rig:ball("Body", "SaddleKnob", (base * cf(0, 0.45, -0.5)).Position, 0.14, P.gold)
	A.rune(rig, "Body", base * cf(0, 0.34, 0.39) * ang(rad(-15), 0, 0) * ang(0, math.pi, 0), 0.24, P.rune, 1)
	rig:seat("Body", base * cf(0, 0.3, 0.02), v3(0.8, 0.2, 0.8))

	-- Épaulières de pierre runique
	rig:mirrored(function(side)
		local sh = BODY:surface(2.0, side * 62, 0.08)
		rig:prism("Body", "Pauldron", sh * cf(0, 0.02, 0), v3(0.9, 0.2, 0.8), 0.18, P.stone[2])
		rig:prism("Body", "Pauldron", sh * cf(0, 0.14, 0.05), v3(0.6, 0.14, 0.55), 0.12, P.stone[1])
		A.rune(rig, "Body", sh * cf(0, 0.22, 0.05) * ang(-math.pi / 2, 0, 0), 0.32, P.rune, if side > 0 then 2 else 5)
	end)

	-- Tête
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.2,
		cover = { A.fur(P.fur, P.tip, v3(0.2, 0.3, 0.28), 0.17, { arc = 160, from = 2.6, refRadius = 0.45, seed = 3 }) },
	})
	rig:prismBetween("Head", "Muzzle", v3(0, 1.82, -1.7), v3(0, 1.8, -2.24), 0.42, 0.34, 0.14, P.muzzle)
	rig:ball("Head", "Nose", v3(0, 1.88, -2.32), 0.2, P.nose)
	rig:prismBetween("Jaw", "Jaw", v3(0, 1.66, -1.6), v3(0, 1.66, -2.1), 0.34, 0.14, 0.06, P.muzzle)
	rig:mirrored(function(side, sfx)
		A.eye(rig, "Head", A.mx(v3(0.24, 2.14, -1.86), side), v3(side * 0.6, 0.2, -1), 0.12, "Glow", P.socket, P.eye)
		A.brow(rig, "Head", side, v3(0.22, 2.24, -1.86), 0.24, 16, P.fur[4])
		local earCF = cf(A.mx(v3(0.36, 2.45, -1.45), side)) * ang(rad(-8), side * rad(-20), side * rad(-30))
		A.ear(rig, "Ear" .. sfx, earCF, 0.4, 0.3, P.fur[3], P.inner)
		A.teeth(rig, "Head", A.mx(v3(0.1, 1.68, -2.18), side), A.mx(v3(0.16, 1.7, -2.0), side), 2, 0.05, 0.1, P.claw, true)
	end)

	-- Pattes massives, brassards de pierre gravée
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, L in { F = { v3(0.62, 1.75, -0.75), v3(0.7, 0.95, -0.82), v3(0.72, 0.28, -0.88), 0.42 }, B = { v3(0.62, 1.8, 0.75), v3(0.72, 1.0, 0.98), v3(0.7, 0.28, 0.86), 0.5 } } do
			local bone = "Leg_" .. key .. s
			local leg = A.limb(rig, bone, side, { { L[1], L[4], L[4] * 1.1 }, { L[2], 0.3, 0.3 }, { L[3], 0.26, 0.26 } }, P.core, A.fur(P.fur, P.tip, v3(0.26, 0.4, 0.36), 0.2, { arc = 180, refRadius = 0.36, seed = 10 + side }))
			A.paw(rig, bone, A.mx((L[3] :: Vector3) - v3(0, 0.28, 0.12), side), v3(0, 0, -1), 0.62, 4, P.pad, P.fur[4], P.claw)
			if key == "F" then
				rig:band(leg, bone, "StoneBracer", 2.35, 0.36, 0.14, P.stone[2])
				rig:band(leg, bone, "StoneBracer", 2.1, 0.06, 0.18, P.gold)
				local face = leg:surface(2.35, side * 90, 0.1)
				A.rune(rig, bone, face * ang(-math.pi / 2, 0, 0), 0.22, P.rune, if side > 0 then 4 else 1)
			end
		end
	end)
	rig:ball("Body", "Tail", v3(0, 1.75, 1.6), 0.36, P.fur[2])

	A.orbit(rig, "Aura1", v3(0, 2.2, 0), 2.6, 4, 0.3, function(bone, c, i)
		rig:prism(bone, "RuneStone", c * ang(0, math.pi / 2, 0), v3(0.44, 0.62, 0.14), 0.07, P.stone[i % 2 + 1])
		A.rune(rig, bone, c * ang(0, -math.pi / 2, 0) * cf(0, 0, -0.08), 0.32, P.rune, i + 2)
	end)

	rig:hitbox(cf(0, 1.6, -0.4), v3(2.6, 3.2, 4.8))

	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Body", "FX_Runes", cf(0, 2.4, 0), v3(2, 1, 2.4))
		Fx.particles(g, Fx.sparkles("RuneDust", { rgb(140, 220, 255), rgb(60, 160, 255) }, 6, 0.22), sc)
		Fx.light(g, { color = rgb(90, 200, 255), range = 10, brightness = 1.2 }, sc)
		local dust = rig:anchor("Root", "FX_Dust", cf(0, 0.2, 0), v3(2.4, 0.3, 3.4))
		Fx.particles(dust, Fx.mist("Dust", { rgb(170, 150, 120), rgb(120, 104, 84) }, 4, 0.8), sc)
	end


	-- Effets avancés : signature, origine de la capacité, aura de rareté
	if rig.effects then
		Vfx.orbitTethers(rig, "Aura1", Vfx.orbitPoints(v3(0, 2.2, 0), 2.6, 4, 0.3), "Body", v3(0, 2.9, 0.2), { colors = { rgb(120, 220, 255), rgb(60, 140, 255) }, transparency = { 0.3, 0.85 }, width0 = 0.09, width1 = 0.02, curve0 = 0.6 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Rare")
	end

	return rig:finish({ Rarity = "Rare" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Ours Runique",
	Rarity = "Rare",
	Zone = "PenteBrumeuse",
	Scale = 2.0,
	Category = "Monture Rare",
	Description = "Colosse capable de porter des passagers. Sa selle est sculptée et ses brassards de pierre gravés de runes.",
	Icon = { top = rgb(40, 70, 120), bottom = rgb(14, 18, 30), glow = rgb(120, 210, 255), motif = rgb(255, 200, 60), yaw = 36, pitch = 16, zoom = 1.1 },
	Animation = { gait = "Quadruped", breathe = 0.05, bob = 0.1, stride = 24, strideRate = 7, tailSway = 4, tailRate = 2, headLook = 16, sniff = true, earTwitch = true, auraSpeed = 0.45 },
	Ability = ABILITY,
	build = build,
}

return Def
