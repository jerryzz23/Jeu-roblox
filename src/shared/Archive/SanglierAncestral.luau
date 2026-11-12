--!strict
--[[
	LE SANGLIER ANCESTRAL — Épique · La Pente Brumeuse
	==================================================
	Version géante du sanglier aux colossales défenses d'ivoire serties d'or
	et aux épaulettes de pierre.

	• Énorme bosse d'épaules, fourrure grise ancienne à pointes blanchies, grande crinière.
	• Défenses d'ivoire colossales serties de trois bagues d'or chacune.
	• Épaulettes et frontal de pierre (Slate) gravés de runes ambre, couverts de mousse.
	• Collier d'os et de perles, yeux Neon ambre, sabots de pierre.
	• 4 monolithes runiques en orbite ; effets : poussière ancienne, lueur ambrée.
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

local ID = "SanglierAncestral"

local P = {
	core = S(rgb(56, 50, 46)),
	fur = { S(rgb(150, 140, 128), M.Fabric), S(rgb(120, 112, 102), M.Fabric), S(rgb(92, 86, 78), M.Fabric), S(rgb(68, 62, 56), M.Fabric) },
	tip = S(rgb(226, 222, 212)),
	mane = S(rgb(46, 40, 38)),
	ivory = S(rgb(252, 244, 222)),
	gold = S(rgb(255, 200, 56)),
	goldDark = S(rgb(208, 132, 24)),
	stone = { S(rgb(150, 150, 140), M.Slate), S(rgb(120, 120, 112), M.Slate), S(rgb(92, 92, 86), M.Slate) },
	moss = S(rgb(110, 170, 60), M.Grass),
	rune = S(rgb(255, 170, 40), M.Neon),
	snout = S(rgb(200, 140, 130)),
	nostril = S(rgb(70, 30, 30)),
	bone = S(rgb(240, 232, 210)),
	bead = { S(rgb(200, 60, 40)), S(rgb(40, 130, 160)) },
	eye = S(rgb(255, 170, 40), M.Neon),
	socket = S(rgb(20, 12, 10)),
	inner = S(rgb(170, 120, 110)),
}

local BODY = Kit.spine({
	{ pos = v3(0, 1.3, -1.05), rx = 0.5, ry = 0.52 },
	{ pos = v3(0, 1.5, -0.55), rx = 0.78, ry = 0.82 },
	{ pos = v3(0, 1.38, 0.1), rx = 0.72, ry = 0.68 },
	{ pos = v3(0, 1.28, 0.7), rx = 0.62, ry = 0.56 },
	{ pos = v3(0, 1.12, 1.15), rx = 0.38, ry = 0.36 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 0.92, -2.0), rx = 0.24, ry = 0.2 },
	{ pos = v3(0, 0.98, -1.78), rx = 0.32, ry = 0.28 },
	{ pos = v3(0, 1.1, -1.5), rx = 0.44, ry = 0.4 },
	{ pos = v3(0, 1.24, -1.18), rx = 0.5, ry = 0.48 },
})

-- Capacité spéciale (CreatureForge.playAbility)
local ABILITY: Types.Ability = {
	name = "Colère ancestrale",
	kind = "Stomp",
	colors = { rgb(255, 170, 40), rgb(140, 90, 30), rgb(255, 240, 180) },
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

	rig:bone("Body", "Root", cf(0, 1.3, 0))
	rig:bone("Head", "Body", cf(0, 1.25, -1.05))
	rig:bone("Tail1", "Body", cf(0, 1.25, 1.2))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.5, 1.05, -0.55))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.46, 1.05, 0.7))
		rig:bone("Ear" .. sfx, "Head", cf(side * 0.36, 1.62, -1.2))
	end)

	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.3,
		cover = { A.fur(P.fur, P.tip, v3(0.26, 0.46, 0.4), 0.21, { arc = 150, refRadius = 0.6, seed = 1 }) },
	})
	A.crest(rig, BODY, const("Body"), 1.0, 4.6, 0.16, 0.7, 0.26, P.mane, P.tip, 0, 28)
	A.crest(rig, BODY, const("Body"), 1.2, 3.2, 0.2, 0.5, 0.22, P.mane, P.tip, 40, 30)
	A.crest(rig, BODY, const("Body"), 1.2, 3.2, 0.2, 0.5, 0.22, P.mane, P.tip, -40, 30)

	-- Épaulettes de pierre runique moussues
	rig:mirrored(function(side)
		local sh = BODY:surface(2.1, side * 58, 0.1)
		rig:prism("Body", "StonePauldron", sh, v3(0.95, 0.24, 0.9), 0.2, P.stone[2])
		rig:prism("Body", "StonePauldron", sh * cf(0, 0.16, 0.05), v3(0.66, 0.16, 0.6), 0.14, P.stone[1])
		A.rune(rig, "Body", sh * cf(0, 0.25, 0.05) * ang(-math.pi / 2, 0, 0), 0.34, P.rune, if side > 0 then 1 else 3)
		rig:ball("Body", "Moss", (sh * cf(0.3, 0.2, -0.25)).Position, 0.24, P.moss)
		rig:ball("Body", "Moss", (sh * cf(0.38, 0.16, -0.05)).Position, 0.18, P.moss)
	end)

	-- Collier d'os et de perles
	for i = -4, 4 do
		local c = BODY:surface(1.25, i * 22, 0.04)
		if i % 2 == 0 then
			rig:thorn("Body", "BoneTooth", c * ang(math.pi, 0, 0) * cf(0, 0, 0), 0.08, 0.2, P.bone)
		else
			rig:ball("Body", "Bead", c.Position, 0.1, P.bead[(i % 4 == 1) and 1 or 2])
		end
	end

	-- Tête, frontal de pierre
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.2,
		cover = { A.fur(P.fur, P.tip, v3(0.2, 0.3, 0.26), 0.16, { arc = 160, from = 2.2, refRadius = 0.44, seed = 3 }) },
	})
	rig:prism("Head", "StoneBrow", HEAD:surface(3.2, 0, 0.06) * ang(rad(-10), 0, 0), v3(0.62, 0.16, 0.5), 0.12, P.stone[1])
	A.rune(rig, "Head", HEAD:surface(3.2, 0, 0.16) * ang(-math.pi / 2, 0, 0), 0.26, P.rune, 5)
	rig:cylinder("Head", "Snout", v3(0, 0.92, -2.0), v3(0, 0.92, -2.16), 0.42, P.snout)
	rig:mirrored(function(side, sfx)
		rig:ball("Head", "Nostril", A.mx(v3(0.08, 0.92, -2.16), side), 0.09, P.nostril)
		A.eye(rig, "Head", A.mx(v3(0.33, 1.3, -1.45), side), v3(side, 0.2, -0.5), 0.11, "Glow", P.socket, P.eye)
		A.brow(rig, "Head", side, v3(0.3, 1.38, -1.47), 0.24, 22, P.mane)
		A.ear(rig, "Ear" .. sfx, cf(A.mx(v3(0.36, 1.62, -1.2), side)) * ang(rad(25), side * rad(-30), side * rad(-50)), 0.34, 0.44, P.fur[2], P.inner, P.mane)
		-- Défenses colossales serties d'or
		local tusk = {
			A.mx(v3(0.26, 0.84, -1.8), side),
			A.mx(v3(0.55, 0.8, -2.1), side),
			A.mx(v3(0.85, 1.0, -2.45), side),
			A.mx(v3(0.95, 1.5, -2.6), side),
			A.mx(v3(0.8, 2.0, -2.45), side),
			A.mx(v3(0.55, 2.25, -2.15), side),
		}
		A.horn(rig, "Head", tusk, 0.2, 0.04, P.ivory, P.gold, { 1.5, 2.6, 3.7 })
	end)

	-- Pattes, sabots de pierre
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, z in { F = -0.55, B = 0.7 } do
			local bone = "Leg_" .. key .. s
			A.limb(rig, bone, side, {
				{ v3(0.5, 1.1, z), 0.3, 0.36 },
				{ v3(0.54, 0.55, z + 0.04), 0.2, 0.2 },
				{ v3(0.55, 0.24, z - 0.02), 0.16, 0.16 },
			}, P.core, A.fur(P.fur, P.tip, v3(0.22, 0.32, 0.3), 0.18, { arc = 180, to = 2.4, refRadius = 0.28, seed = 20 + side }))
			A.hoof(rig, bone, A.mx(v3(0.55, 0, z - 0.02), side), 0.38, P.stone[3], P.core, P.gold, nil)
		end
	end)
	rig:prismBetween("Tail1", "Tail", v3(0, 1.25, 1.2), v3(0, 0.8, 1.45), 0.08, 0.08, 0.02, P.fur[3])
	A.tuftBurst(rig, "Tail1", A.alongUp(v3(0, 0.8, 1.45), v3(0, -1, 0.3)), 7, 0.26, 0.12, { P.mane }, P.tip, 25, 9)

	-- Monolithes runiques en orbite
	A.orbit(rig, "Aura1", v3(0, 1.6, 0), 2.6, 4, 0.3, function(bone, c, i)
		rig:prism(bone, "Monolith", c * ang(0, math.pi / 2, 0), v3(0.42, 0.9, 0.2), 0.08, P.stone[(i % 3) + 1])
		A.rune(rig, bone, c * ang(0, -math.pi / 2, 0) * cf(0, 0.1, -0.11), 0.3, P.rune, i)
		rig:ball(bone, "Moss", (c * cf(0, 0.46, 0)).Position, 0.18, P.moss)
	end)

	rig:hitbox(cf(0, 1.3, -0.4), v3(2.2, 2.8, 4.4))

	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Body", "FX_Ancient", cf(0, 1.8, -0.3), v3(1.8, 1, 2.4))
		Fx.particles(g, Fx.sparkles("AmberRunes", { rgb(255, 200, 90), rgb(255, 140, 30) }, 5, 0.2), sc)
		Fx.light(g, { color = rgb(255, 170, 60), range = 10, brightness = 1.2 }, sc)
		local dust = rig:anchor("Root", "FX_Dust", cf(0, 0.2, 0), v3(2.2, 0.3, 3.2))
		Fx.particles(dust, Fx.mist("AncientDust", { rgb(170, 160, 140), rgb(110, 104, 90) }, 5, 0.9), sc)
	end


	-- Effets avancés : signature, origine de la capacité, aura de rareté
	if rig.effects then
		Vfx.orbitTethers(rig, "Aura1", Vfx.orbitPoints(v3(0, 1.6, 0), 2.6, 4, 0.3), "Body", v3(0, 2.1, -0.4), { colors = { rgb(255, 200, 90), rgb(255, 140, 30) }, transparency = { 0.3, 0.85 }, width0 = 0.09, width1 = 0.02, curve0 = 0.6 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Epic")
	end

	return rig:finish({ Rarity = "Epic" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Sanglier Ancestral",
	Rarity = "Epic",
	Zone = "PenteBrumeuse",
	Scale = 2.6,
	Category = "Monture Épique",
	Description = "Sanglier géant des temps anciens. Ses défenses d'ivoire sont serties d'or, ses épaules couvertes de pierre.",
	Icon = { top = rgb(110, 80, 40), bottom = rgb(26, 18, 10), glow = rgb(255, 190, 100), motif = rgb(255, 170, 40), yaw = 38, pitch = 14, zoom = 1.1 },
	Animation = { gait = "Quadruped", breathe = 0.04, bob = 0.07, stride = 22, strideRate = 7, tailSway = 18, tailRate = 3, headLook = 14, sniff = true, earTwitch = true, auraSpeed = 0.35 },
	Ability = ABILITY,
	build = build,
}

return Def
