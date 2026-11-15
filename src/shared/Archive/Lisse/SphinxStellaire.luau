--!strict
--[[
	LE SPHINX STELLAIRE — Exclusif · Géant
	======================================
	Sphinx dont les ailes sont remplies d'étoiles (roue uniquement).

	• Corps de lion au pelage de sable doré, pattes cerclées de bracelets d'or et de lapis.
	• Tête de pharaon : visage serein, yeux soulignés de khôl lumineux turquoise, barbe d'or,
	  coiffe némès rayée lapis/or, cobra dressé sur le front.
	• Grandes ailes : panneaux de ciel nocturne remplis d'étoiles Neon reliées en constellations,
	  bords dorés.
	• Selle d'apparat (monture avec passager).
	• Petites pyramides d'or et étoiles en orbite ; effets : poussière d'étoiles, lueur bleue et or.
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

local ID = "SphinxStellaire"

local P = {
	core = S(rgb(150, 110, 60)),
	fur = { S(rgb(246, 210, 140)), S(rgb(226, 184, 110)), S(rgb(200, 154, 86)), S(rgb(166, 122, 64)) },
	furTip = S(rgb(255, 236, 190)),
	skin = S(rgb(214, 160, 100)),
	gold = S(rgb(255, 204, 64), M.Metal, { reflectance = 0.1 }),
	goldDark = S(rgb(200, 130, 24), M.Metal),
	lapis = S(rgb(30, 60, 170)),
	lapisDark = S(rgb(16, 30, 100)),
	kohl = S(rgb(60, 240, 230), M.Neon),
	eye = S(rgb(255, 255, 255), M.Neon),
	socket = S(rgb(20, 14, 10)),
	night = { S(rgb(16, 20, 70), M.Glass, { transparency = 0.1 }), S(rgb(30, 22, 90), M.Glass, { transparency = 0.1 }), S(rgb(10, 30, 80), M.Glass, { transparency = 0.1 }) },
	star = S(rgb(255, 255, 255), M.Neon),
	starGold = S(rgb(255, 230, 140), M.Neon),
	starBlue = S(rgb(150, 210, 255), M.Neon),
	line = S(rgb(170, 200, 255), M.Neon, { transparency = 0.45 }),
	cobra = S(rgb(255, 200, 60), M.Metal),
	ruby = S(rgb(255, 50, 70), M.Neon),
	pad = S(rgb(110, 70, 40)),
	claw = S(rgb(250, 240, 220)),
}

local BODY = Kit.spine({
	{ pos = v3(0, 2.55, -1.3), rx = 0.3, ry = 0.32 },
	{ pos = v3(0, 2.2, -0.95), rx = 0.52, ry = 0.58 },
	{ pos = v3(0, 2.0, -0.35), rx = 0.56, ry = 0.58 },
	{ pos = v3(0, 2.02, 0.3), rx = 0.55, ry = 0.55 },
	{ pos = v3(0, 2.0, 0.85), rx = 0.52, ry = 0.5 },
	{ pos = v3(0, 1.85, 1.2), rx = 0.3, ry = 0.3 },
})

local TAIL = Kit.spine({
	{ pos = v3(0, 1.92, 1.25), rx = 0.12, ry = 0.12 },
	{ pos = v3(0, 1.6, 1.7), rx = 0.1, ry = 0.1 },
	{ pos = v3(0.15, 1.45, 2.2), rx = 0.09, ry = 0.09 },
	{ pos = v3(0.35, 1.7, 2.6), rx = 0.07, ry = 0.07 },
	{ pos = v3(0.42, 2.0, 2.75), rx = 0.05, ry = 0.05 },
})

local ABILITY: Types.Ability = {
	name = "Énigme stellaire",
	kind = "Nova",
	colors = { rgb(150, 200, 255), rgb(255, 210, 90), rgb(255, 255, 255) },
	texture = "sparkle",
	radius = 9,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 2.0, 0))
	rig:bone("Head", "Body", cf(0, 2.75, -1.4))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.36, 1.85, -0.8))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.38, 1.9, 0.75))
		rig:bone("Wing" .. sfx, "Body", cf(side * 0.4, 2.45, -0.5))
	end)
	local tj = {}
	for i = 1, #TAIL.sections do
		table.insert(tj, TAIL:pos(i))
	end
	local tail = rig:boneChain("Tail", "Body", tj)

	-- Corps de lion
	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.28,
		cover = { A.fur(P.fur, P.furTip, v3(0.24, 0.32, 0.32), 0.19, { arc = 170, refRadius = 0.5, seed = 1 }) },
	})
	-- Collier pectoral d'or et de lapis
	for k = 0, 2 do
		rig:band(BODY, "Body", "Pectoral", 1.55 + k * 0.18, 0.1, 0.05, if k % 2 == 0 then P.gold else P.lapis)
	end
	rig:shard("Body", "PectoralGem", BODY:surface(1.8, 180, 0.08) * ang(math.pi, 0, 0), 0.16, 0.14, 0.12, P.ruby)
	-- Selle d'apparat
	local saddle = BODY:surface(3.9, 0, 0.12)
	rig:prism("Body", "SaddleCloth", saddle * cf(0, -0.03, 0), v3(1.2, 0.06, 1.1), 0.04, P.lapis)
	rig:mirrored(function(side)
		local flap = saddle * cf(side * 0.62, -0.32, 0) * ang(0, 0, side * rad(64))
		rig:prism("Body", "SaddleFlap", flap, v3(0.6, 0.05, 1.0), 0.03, P.lapis)
		for k = -1, 1 do
			rig:block("Body", "SaddleStripe", flap * cf(0, 0.01, k * 0.3), v3(0.62, 0.06, 0.08), P.gold)
		end
	end)
	rig:prism("Body", "Saddle", saddle * cf(0, 0.08, 0), v3(0.75, 0.14, 0.8), 0.06, P.gold)
	rig:seat("Body", saddle * cf(0, 0.2, 0), v3(0.7, 0.2, 0.7))

	-- Tête de pharaon
	rig:ball("Head", "Face", v3(0, 2.95, -1.62), 0.62, P.skin)
	rig:prismBetween("Head", "Nose", v3(0, 3.0, -1.88), v3(0, 2.88, -1.95), 0.1, 0.08, 0.02, P.skin)
	rig:block("Head", "Mouth", cf(0, 2.78, -1.9), v3(0.14, 0.025, 0.03), P.goldDark)
	rig:prismBetween("Head", "Beard", v3(0, 2.7, -1.85), v3(0, 2.38, -1.88), 0.12, 0.1, 0.02, P.gold)
	for k = 0, 3 do
		rig:block("Head", "BeardBand", cf(0, 2.65 - k * 0.08, -1.87), v3(0.13, 0.025, 0.11), P.lapis)
	end
	rig:mirrored(function(side)
		rig:ball("Head", "Eye", A.mx(v3(0.11, 3.03, -1.88), side), 0.08, P.eye)
		rig:ball("Head", "Pupil", A.mx(v3(0.11, 3.03, -1.92), side), 0.04, P.socket)
		rig:strut("Head", "Kohl", A.mx(v3(0.05, 3.07, -1.9), side), A.mx(v3(0.24, 3.04, -1.84), side), 0.025, 0.02, P.kohl)
		rig:strut("Head", "Kohl", A.mx(v3(0.18, 3.05, -1.86), side), A.mx(v3(0.24, 2.98, -1.82), side), 0.02, 0.02, P.kohl)
		rig:wedge("Head", "Brow", cf(A.mx(v3(0.12, 3.12, -1.88), side)) * ang(0, 0, side * rad(-10)), v3(0.18, 0.03, 0.04), P.lapisDark)
	end)
	-- Coiffe némès : calotte + pans rayés tombant sur les épaules
	local nemes = Kit.spine({
		{ pos = v3(0, 3.06, -1.85), rx = 0.36, ry = 0.24 },
		{ pos = v3(0, 3.14, -1.6), rx = 0.4, ry = 0.32 },
		{ pos = v3(0, 3.0, -1.32), rx = 0.36, ry = 0.3 },
		{ pos = v3(0, 2.75, -1.18), rx = 0.18, ry = 0.14 },
	})
	rig:tube(nemes, { name = "Nemes", bone = const("Head"), core = P.lapis, coreStep = 0.1 })
	for k = 0, 5 do
		local u = 1.2 + k * 0.32
		rig:band(nemes, "Head", "NemesStripe", u, 0.05, 0.02, P.gold)
	end
	rig:mirrored(function(side)
		for k = 0, 4 do
			local top = A.mx(v3(0.32 + k * 0.02, 3.0 - k * 0.04, -1.72 + k * 0.03), side)
			local bot = A.mx(v3(0.4 + k * 0.03, 2.35, -1.62 + k * 0.03), side)
			rig:prismBetween("Head", "Lappet", top, bot, 0.08, 0.05, 0.01, if k % 2 == 0 then P.gold else P.lapis)
		end
	end)
	rig:band(nemes, "Head", "Diadem", 1.15, 0.06, 0.04, P.gold)
	-- Cobra dressé sur le front
	A.horn(rig, "Head", { v3(0, 3.2, -1.86), v3(0, 3.3, -1.95), v3(0, 3.42, -1.92) }, 0.05, 0.03, P.cobra)
	rig:prism("Head", "CobraHood", cf(0, 3.42, -1.93), v3(0.14, 0.12, 0.03), 0.03, P.cobra)
	rig:ball("Head", "CobraGem", v3(0, 3.42, -1.95), 0.05, P.ruby)

	-- Ailes : panneaux de ciel nocturne remplis d'étoiles
	rig:mirrored(function(side, sfx)
		local w = "Wing" .. sfx
		local arm = { v3(0.4, 2.45, -0.5), v3(1.3, 3.1, -0.35), v3(2.3, 3.45, 0.1), v3(3.2, 3.5, 0.6) }
		local mp = {}
		for _, p in arm do
			table.insert(mp, A.mx(p, side))
		end
		A.limb(rig, w, side, { { arm[1], 0.15, 0.15 }, { arm[2], 0.12, 0.12 }, { arm[3], 0.09, 0.09 } }, P.gold)
		rig:strut(w, "WingBone", mp[3], mp[4], 0.08, 0.08, P.gold)
		local tips = { mp[4], A.mx(v3(3.3, 2.6, 1.25), side), A.mx(v3(2.7, 1.95, 1.55), side), A.mx(v3(1.8, 1.9, 1.45), side), A.mx(v3(0.9, 2.2, 0.85), side) }
		local tris = {}
		for t = 1, #tips - 1 do
			table.insert(tris, { mp[3], tips[t], tips[t + 1] })
		end
		table.insert(tris, { mp[1], mp[3], tips[#tips] })
		table.insert(tris, { mp[1], mp[2], mp[3] })
		for i, tri in tris do
			A.triangle(rig, w, "StarSky", tri[1], tri[2], tri[3], 0.04, P.night[(i % 3) + 1])
		end
		-- Bord doré
		for t = 1, #tips - 1 do
			rig:strut(w, "WingEdge", tips[t], tips[t + 1], 0.05, 0.05, P.gold)
		end
		-- Étoiles dans les panneaux + constellations
		local rng = Random.new(7 + side)
		local prev: Vector3? = nil
		for i = 1, 34 do
			local tri = tris[rng:NextInteger(1, #tris)]
			local a, b = rng:NextNumber(), rng:NextNumber()
			if a + b > 1 then
				a, b = 1 - a, 1 - b
			end
			local p = tri[1] + (tri[2] - tri[1]) * a + (tri[3] - tri[1]) * b + v3(0, 0.04, 0)
			local st = if i % 5 == 0 then P.starGold elseif i % 3 == 0 then P.starBlue else P.star
			if i % 4 == 0 then
				rig:block(w, "Star", cf(p), v3(0.05, 0.28, 0.05), st)
				rig:block(w, "Star", cf(p) * ang(0, 0, math.pi / 2), v3(0.05, 0.28, 0.05), st)
			else
				rig:ball(w, "Star", p, rng:NextNumber(0.06, 0.12), st)
			end
			if prev and i % 6 ~= 0 and i <= 12 then
				rig:strut(w, "Constellation", prev, p, 0.02, 0.02, P.line)
			end
			prev = p
		end
	end)

	-- Pattes de lion
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, L in { F = { v3(0.36, 1.85, -0.8), v3(0.4, 1.05, -0.88), v3(0.4, 0.3, -0.95), 0.3 }, B = { v3(0.38, 1.9, 0.75), v3(0.44, 1.15, 0.98), v3(0.42, 0.3, 0.86), 0.4 } } do
			local bone = "Leg_" .. key .. s
			A.limb(rig, bone, side, { { L[1], L[4], L[4] * 1.15 }, { L[2], 0.16, 0.16 }, { L[3], 0.12, 0.12 } }, P.core, A.fur(P.fur, P.furTip, v3(0.16, 0.24, 0.22), 0.13, { arc = 180, refRadius = 0.18, seed = 10 + side }))
			A.paw(rig, bone, A.mx((L[3] :: Vector3) - v3(0, 0.2, 0.06), side), v3(0, 0, -1), 0.36, 4, P.pad, P.fur[3], P.claw)
			local wrist = A.mx((L[2] :: Vector3):Lerp(L[3] :: Vector3, 0.6), side)
			rig:ring(bone, "Bracelet", cf(wrist) * ang(math.pi / 2, 0, 0), 0.16, 0.05, 0.1, 12, P.gold)
			rig:ring(bone, "Bracelet", cf(wrist - v3(0, 0.1, 0)) * ang(math.pi / 2, 0, 0), 0.15, 0.04, 0.06, 12, P.lapis)
		end
	end)

	-- Queue à touffe d'or
	rig:tube(TAIL, {
		name = "Tail",
		bone = function(u)
			return tail[math.clamp(math.floor(u), 1, #tail)]
		end,
		core = P.core,
		coreStep = 0.14,
		cover = { A.fur(P.fur, nil, v3(0.1, 0.16, 0.14), 0.09, { arc = 180, refRadius = 0.08, seed = 6 }) },
	})
	A.tuftBurst(rig, tail[#tail], A.alongUp(TAIL:pos(5), TAIL:pos(5) - TAIL:pos(4)), 9, 0.32, 0.12, { P.lapis, P.goldDark }, P.starGold, 40, 7)

	-- Pyramides d'or et étoiles en orbite
	A.orbit(rig, "Aura1", v3(0, 2.6, 0), 3.4, 8, 0.5, function(bone, c, i)
		if i % 2 == 0 then
			rig:thorn(bone, "Pyramid", c * cf(0, -0.2, 0), 0.5, 0.45, P.gold)
		else
			rig:block(bone, "OrbitStar", c, v3(0.08, 0.55, 0.08), P.star)
			rig:block(bone, "OrbitStar", c * ang(0, 0, math.pi / 2), v3(0.08, 0.55, 0.08), P.star)
			rig:ball(bone, "OrbitStarCore", c.Position, 0.16, P.starBlue)
		end
	end)

	rig:hitbox(cf(0, 2.0, 0), v3(2.4, 4, 5))

	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Body", "FX_Stars", cf(0, 2.8, 0), v3(3, 1.6, 3))
		Fx.particles(g, Fx.sparkles("Stardust", { rgb(255, 255, 255), rgb(150, 200, 255), rgb(255, 220, 120) }, 14, 0.22, 0.1), sc)
		Fx.light(g, { color = rgb(140, 180, 255), range = 16, brightness = 1.5 }, sc)
		Fx.light(rig.bones.Head, { color = rgb(255, 210, 120), range = 8, brightness = 1 }, sc)
		Vfx.orbitRing(rig, "Aura1", Vfx.orbitPoints(v3(0, 2.6, 0), 3.4, 8, 0.5), { colors = { rgb(170, 210, 255), rgb(255, 220, 120) }, transparency = { 0.35, 0.7 }, width0 = 0.06, curve0 = 0.6, curve1 = -0.6 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Exclusive")
	end

	return rig:finish({ Rarity = "Exclusive" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Sphinx stellaire",
	Rarity = "Exclusive",
	Size = "Giant",
	Income = 11000000,
	SpeedBonus = 2.2,
	Passenger = true,
	Source = "Roue",
	Scale = 2.4,
	Category = "Créature Exclusive",
	Description = "Gardien des énigmes au visage de pharaon ; ses ailes sont un morceau de ciel nocturne rempli d'étoiles.",
	Icon = { top = rgb(30, 40, 120), bottom = rgb(6, 6, 20), glow = rgb(255, 220, 120), motif = rgb(150, 200, 255), yaw = 30, pitch = 10, zoom = 1.0 },
	Animation = { gait = "Quadruped", breathe = 0.035, bob = 0.1, stride = 26, strideRate = 8, tailSway = 14, tailRate = 1.3, headLook = 14, auraSpeed = 0.45 },
	Ability = ABILITY,
	build = build,
}

return Def
