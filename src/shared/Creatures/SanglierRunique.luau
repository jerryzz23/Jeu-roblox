--!strict
--[[
	LE SANGLIER RUNIQUE — Inhabituel · La Surface
	=============================================
	Monture robuste ornée de runes gravées sur les défenses et de harnais en cuir.

	• Corps massif en fourrure hérissée brune, crinière de soies sombres le long de l'échine.
	• Défenses d'ivoire recourbées, cerclées d'or et gravées de runes Neon cyan.
	• Harnais de cuir (Fabric) à boucles dorées, selle avec couverture runique : MONTABLE (Seat).
	• Groin rose, petits yeux ambrés, sabots cerclés d'acier.
	• 3 pierres runiques en orbite ; effets : poussière, lueur des runes.
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

local ID = "SanglierRunique"

local P = {
	core = S(rgb(70, 46, 34)),
	fur = { S(rgb(150, 104, 74)), S(rgb(122, 82, 58)), S(rgb(96, 62, 44)), S(rgb(70, 46, 34)) },
	tip = S(rgb(206, 170, 126)),
	bristle = S(rgb(46, 32, 28)),
	bristleTip = S(rgb(150, 140, 136)),
	snout = S(rgb(236, 150, 146)),
	nostril = S(rgb(80, 30, 34)),
	ivory = S(rgb(250, 240, 214)),
	gold = S(rgb(255, 200, 56)),
	goldDark = S(rgb(208, 132, 24)),
	rune = S(rgb(80, 230, 255), M.Neon),
	leather = S(rgb(110, 66, 40), M.Fabric),
	leatherDark = S(rgb(80, 46, 30), M.Fabric),
	cloth = S(rgb(40, 70, 150), M.Fabric),
	wood = S(rgb(140, 92, 56), M.Wood),
	hoof = S(rgb(40, 34, 34)),
	steel = S(rgb(150, 156, 170), M.Metal),
	stone = S(rgb(110, 112, 126), M.Slate),
	eye = S(rgb(255, 150, 30)),
	socket = S(rgb(30, 16, 12)),
	pupil = S(rgb(16, 10, 8)),
	inner = S(rgb(230, 150, 140)),
}

local BODY = Kit.spine({
	{ pos = v3(0, 1.15, -0.95), rx = 0.42, ry = 0.44 },
	{ pos = v3(0, 1.25, -0.5), rx = 0.66, ry = 0.66 },
	{ pos = v3(0, 1.18, 0.1), rx = 0.64, ry = 0.58 },
	{ pos = v3(0, 1.12, 0.65), rx = 0.58, ry = 0.52 },
	{ pos = v3(0, 1.0, 1.05), rx = 0.36, ry = 0.34 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 0.86, -1.85), rx = 0.2, ry = 0.18 },
	{ pos = v3(0, 0.9, -1.65), rx = 0.28, ry = 0.24 },
	{ pos = v3(0, 1.0, -1.4), rx = 0.38, ry = 0.34 },
	{ pos = v3(0, 1.1, -1.12), rx = 0.42, ry = 0.4 },
})

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 1.15, 0))
	rig:bone("Head", "Body", cf(0, 1.12, -0.95))
	rig:bone("Tail1", "Body", cf(0, 1.15, 1.1))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.42, 0.95, -0.5))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.4, 0.95, 0.65))
		rig:bone("Ear" .. sfx, "Head", cf(side * 0.3, 1.42, -1.05))
	end)

	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.3,
		cover = { A.fur(P.fur, P.tip, v3(0.24, 0.4, 0.36), 0.2, { arc = 150, seed = 1 }) },
	})
	A.crest(rig, BODY, const("Body"), 1.1, 4.6, 0.16, 0.5, 0.22, P.bristle, P.bristleTip, 0, 30)

	-- Harnais : sangle de poitrail, sangle ventrale, selle et couverture runique
	rig:band(BODY, "Body", "Harness", 1.55, 0.16, 0.12, P.leather, P.gold)
	rig:band(BODY, "Body", "Girth", 3.0, 0.18, 0.14, P.leatherDark, P.gold)
	local saddleBase = BODY:surface(2.6, 0, 0.12)
	rig:prism("Body", "Blanket", saddleBase * cf(0, -0.02, 0), v3(1.25, 0.08, 1.0), 0.04, P.cloth)
	rig:mirrored(function(side)
		local flap = saddleBase * cf(side * 0.62, -0.3, 0) * ang(0, 0, side * rad(70))
		rig:prism("Body", "BlanketFlap", flap, v3(0.6, 0.06, 0.95), 0.03, P.cloth)
		A.rune(rig, "Body", flap * cf(0, -side * 0.05, 0) * ang(math.pi / 2, 0, 0), 0.32, P.rune, if side > 0 then 1 else 4)
		rig:block("Body", "BlanketTrim", flap * cf(0, 0, 0.5), v3(0.6, 0.08, 0.05), P.gold)
		rig:block("Body", "BlanketTrim", flap * cf(0, 0, -0.5), v3(0.6, 0.08, 0.05), P.gold)
	end)
	rig:prism("Body", "Saddle", saddleBase * cf(0, 0.1, 0), v3(0.7, 0.16, 0.8), 0.07, P.leather)
	rig:prism("Body", "SaddleBack", saddleBase * cf(0, 0.2, 0.36) * ang(rad(-20), 0, 0), v3(0.62, 0.22, 0.12), 0.05, P.wood)
	rig:prism("Body", "SaddleHorn", saddleBase * cf(0, 0.2, -0.38) * ang(rad(20), 0, 0), v3(0.4, 0.2, 0.1), 0.04, P.wood)
	rig:ball("Body", "SaddleKnob", (saddleBase * cf(0, 0.34, -0.4)).Position, 0.12, P.gold)
	rig:seat("Body", saddleBase * cf(0, 0.25, 0.02), v3(0.6, 0.2, 0.6))

	-- Tête
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.18,
		cover = { A.fur(P.fur, P.tip, v3(0.18, 0.26, 0.24), 0.15, { arc = 160, from = 2.2, refRadius = 0.36, seed = 4 }) },
	})
	rig:cylinder("Head", "Snout", v3(0, 0.86, -1.86), v3(0, 0.86, -2.0), 0.36, P.snout)
	rig:mirrored(function(side, sfx)
		rig:ball("Head", "Nostril", A.mx(v3(0.07, 0.86, -2.0), side), 0.08, P.nostril)
		A.eye(rig, "Head", A.mx(v3(0.27, 1.16, -1.38), side), v3(side, 0.2, -0.6), 0.1, "Round", P.socket, P.eye, P.pupil)
		A.brow(rig, "Head", side, v3(0.25, 1.24, -1.4), 0.2, 20, P.bristle)
		A.ear(rig, "Ear" .. sfx, cf(A.mx(v3(0.3, 1.42, -1.05), side)) * ang(rad(25), side * rad(-30), side * rad(-50)), 0.3, 0.4, P.fur[2], P.inner, P.bristle)
		-- Défense runique cerclée d'or
		local tusk = { A.mx(v3(0.2, 0.82, -1.62), side), A.mx(v3(0.32, 0.86, -1.78), side), A.mx(v3(0.4, 1.02, -1.86), side), A.mx(v3(0.38, 1.2, -1.8), side) }
		local sp = A.horn(rig, "Head", tusk, 0.075, 0.018, P.ivory, P.gold, { 1.25 })
		local runeCF = sp:surface(2.1, side * 90, 0.01)
		A.rune(rig, "Head", runeCF * ang(-math.pi / 2, 0, 0), 0.1, P.rune, if side > 0 then 5 else 2)
	end)

	-- Pattes trapues, sabots cerclés d'acier
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, z in { F = -0.5, B = 0.65 } do
			local bone = "Leg_" .. key .. s
			A.limb(rig, bone, side, {
				{ v3(0.42, 0.98, z), 0.26, 0.3 },
				{ v3(0.45, 0.5, z + 0.04), 0.16, 0.16 },
				{ v3(0.46, 0.2, z - 0.02), 0.12, 0.12 },
			}, P.core, A.fur(P.fur, P.tip, v3(0.2, 0.28, 0.26), 0.17, { arc = 180, to = 2.3, refRadius = 0.24, seed = 20 + side }))
			A.hoof(rig, bone, A.mx(v3(0.46, 0, z - 0.02), side), 0.3, P.hoof, P.core, P.steel, nil)
		end
	end)
	rig:prismBetween("Tail1", "Tail", v3(0, 1.15, 1.1), v3(0, 0.7, 1.3), 0.07, 0.07, 0.02, P.fur[3])
	A.tuftBurst(rig, "Tail1", A.alongUp(v3(0, 0.7, 1.3), v3(0, -1, 0.3)), 6, 0.22, 0.1, { P.bristle }, nil, 25, 9)

	-- Pierres runiques en orbite
	A.orbit(rig, "Aura1", v3(0, 1.4, 0), 1.9, 3, 0.2, function(bone, c, i)
		rig:prism(bone, "RuneStone", c * ang(0, math.pi / 2, 0), v3(0.36, 0.5, 0.12), 0.06, P.stone)
		A.rune(rig, bone, c * ang(0, -math.pi / 2, 0) * cf(0, 0, -0.07), 0.26, P.rune, i + 1)
	end)

	rig:hitbox(cf(0, 1.1, -0.3), v3(1.8, 2.3, 3.6))

	if rig.effects then
		local sc = rig.scale
		local dust = rig:anchor("Root", "FX_Dust", cf(0, 0.15, 0), v3(1.6, 0.25, 2.6))
		Fx.particles(dust, Fx.mist("HoofDust", { rgb(170, 150, 120), rgb(120, 104, 84) }, 4, 0.6), sc)
		local glow = rig:anchor("Head", "FX_RuneGlow", cf(0, 1.0, -1.75), v3(0.9, 0.4, 0.3))
		Fx.particles(glow, Fx.sparkles("RuneSparks", { rgb(120, 240, 255) }, 3, 0.16), sc)
		Fx.light(glow, { color = rgb(80, 220, 255), range = 6, brightness = 1 }, sc)
	end

	return rig:finish({ Rarity = "Uncommon" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Sanglier Runique",
	Rarity = "Uncommon",
	Zone = "Surface",
	Scale = 1.6,
	Category = "Monture Inhabituelle",
	Description = "Monture robuste aux défenses gravées de runes. Sa selle accueille un cavalier.",
	Icon = { top = rgb(60, 90, 130), bottom = rgb(20, 22, 34), glow = rgb(120, 230, 255), motif = rgb(255, 200, 60), yaw = 38, pitch = 16, zoom = 1.1 },
	Animation = { gait = "Quadruped", breathe = 0.035, bob = 0.08, stride = 26, strideRate = 10, tailSway = 18, tailRate = 4, headLook = 16, sniff = true, earTwitch = true, auraSpeed = 0.5 },
	build = build,
}

return Def
