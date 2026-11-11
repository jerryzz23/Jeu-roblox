--!strict
--[[
	LE LÉVIATHAN DES PROFONDEURS — Légendaire · Les Grottes de Cristal
	==================================================================
	Serpent/dragon aquatique géant enroulé en spirale, plaques bleu turquoise,
	nageoires dorsales royales et ceintures dorées.

	• Corps enroulé (une boucle au sol + une spirale plus fine par-dessus), cou dressé en S.
	• Écailles turquoise → bleu canard, ventre en écailles crème dorées.
	• Ceintures d'or à rivets tout le long du corps ; crête dorsale de rayons à pointes d'or.
	• Tête de dragon : gueule ouverte garnie de crocs, yeux Neon jaunes fendus,
	  cornes annelées, grandes nageoires en éventail de chaque côté.
	• Petits bras griffus. 8 piliers d'or brisés en orbite + bulles ; onde d'eau au sol.
	Os : Root > Body (spirale) > Seg1..Seg5 > Head > Jaw ; Arm_R / Arm_L   (démarche "Serpent")
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

local ID = "LeviathanDesProfondeurs"

local P = {
	core = S(rgb(10, 90, 110)),
	scales = { S(rgb(140, 252, 240)), S(rgb(76, 222, 222)), S(rgb(32, 172, 192)), S(rgb(16, 118, 150)) },
	headScales = { S(rgb(60, 170, 190)), S(rgb(30, 120, 150)), S(rgb(16, 80, 110)) },
	belly = { S(rgb(255, 240, 180)), S(rgb(236, 206, 130)) },
	fin = S(rgb(20, 70, 96)),
	membrane = S(rgb(60, 200, 220), M.Glass, { transparency = 0.35 }),
	gold = S(rgb(255, 200, 56)),
	goldDark = S(rgb(206, 130, 24)),
	tooth = S(rgb(255, 250, 240)),
	mouth = S(rgb(110, 20, 40)),
	horn = S(rgb(30, 40, 50)),
	hornBand = S(rgb(220, 226, 236)),
	eye = S(rgb(255, 230, 40), M.Neon),
	socket = S(rgb(4, 30, 40)),
	pupil = S(rgb(10, 10, 10)),
	claw = S(rgb(240, 240, 250)),
	water = S(rgb(120, 240, 255), M.Neon, { transparency = 0.55 }),
	bubble = S(rgb(230, 250, 255), M.Glass, { transparency = 0.35 }),
}

local CENTER = v3(0, 0, 1.3)

-- Cou (de la nuque vers le bas) puis spirale autour de CENTER
local function buildSpine(): Kit.Spine
	local secs = {
		{ pos = v3(0, 4.3, -1.55), rx = 0.42, ry = 0.4 },
		{ pos = v3(0, 3.9, -1.1), rx = 0.5, ry = 0.48 },
		{ pos = v3(0, 3.3, -0.85), rx = 0.58, ry = 0.55 },
		{ pos = v3(-0.05, 2.5, -0.9), rx = 0.64, ry = 0.6 },
		{ pos = v3(0, 1.6, -0.8), rx = 0.7, ry = 0.64 },
		{ pos = v3(0.05, 0.9, -0.62), rx = 0.72, ry = 0.66 },
	}
	-- Grande boucle au sol (R = 1.9)
	for k = 1, 8 do
		local th = k * math.pi / 4
		table.insert(secs, { pos = CENTER + v3(1.9 * math.sin(th), 0.68, -1.9 * math.cos(th)), rx = 0.72 - k * 0.012, ry = 0.64 - k * 0.012 })
	end
	-- Spirale plus fine posée par-dessus (R = 1.25 -> 0.6)
	for k = 1, 7 do
		local th = 2 * math.pi + k * math.pi / 4
		local t = k / 7
		local R = 1.25 - t * 0.65
		local r = 0.52 - t * 0.47
		table.insert(secs, { pos = CENTER + v3(R * math.sin(th), 1.55 + t * 0.15, -R * math.cos(th)), rx = r, ry = r * 0.92 })
	end
	return Kit.spine(secs)
end

local SPINE = buildSpine()

local HEAD = Kit.spine({
	{ pos = v3(0, 4.42, -2.95), rx = 0.2, ry = 0.13 },
	{ pos = v3(0, 4.48, -2.65), rx = 0.38, ry = 0.24 },
	{ pos = v3(0, 4.55, -2.25), rx = 0.5, ry = 0.34 },
	{ pos = v3(0, 4.52, -1.85), rx = 0.54, ry = 0.42 },
	{ pos = v3(0, 4.4, -1.55), rx = 0.44, ry = 0.42 },
})

local JAW = Kit.spine({
	{ pos = v3(0, 3.92, -2.72), rx = 0.16, ry = 0.06 },
	{ pos = v3(0, 4.0, -2.4), rx = 0.34, ry = 0.1 },
	{ pos = v3(0, 4.15, -1.9), rx = 0.42, ry = 0.14 },
})

local function segBone(u: number): string
	if u < 2 then
		return "Seg5"
	elseif u < 3 then
		return "Seg4"
	elseif u < 4 then
		return "Seg3"
	elseif u < 5 then
		return "Seg2"
	elseif u < 6 then
		return "Seg1"
	end
	return "Body"
end

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(CENTER + v3(0, 0.7, 0)))
	rig:bone("Seg1", "Body", cf(SPINE:pos(6)))
	rig:bone("Seg2", "Seg1", cf(SPINE:pos(5)))
	rig:bone("Seg3", "Seg2", cf(SPINE:pos(4)))
	rig:bone("Seg4", "Seg3", cf(SPINE:pos(3)))
	rig:bone("Seg5", "Seg4", cf(SPINE:pos(2)))
	rig:bone("Head", "Seg5", cf(0, 4.4, -1.55))
	rig:bone("Jaw", "Head", cf(0, 4.2, -1.75))
	rig:mirrored(function(side, sfx)
		rig:bone("Arm" .. sfx, "Seg2", cf(side * 0.55, 2.1, -1.0))
	end)

	rig:tube(SPINE, {
		name = "Body",
		bone = segBone,
		core = P.core,
		coreStep = 0.3,
		cover = {
			A.scales(P.scales, v3(0.3, 0.12, 0.32), 0.24, { arc = 118, tilt = 26, refRadius = 0.6, seed = 1 }),
			A.scales(P.belly, v3(0.38, 0.07, 0.24), 0.26, { arc = 52, center = 180, tilt = 8, refRadius = 0.6, jitter = 0.1, seed = 2 }),
		},
	})
	-- Crête dorsale royale (rayons sombres à pointes d'or)
	A.crest(rig, SPINE, segBone, 1.2, 20.5, 0.26, 0.6, 0.26, P.fin, P.gold, 0, 30)
	-- Ceintures d'or à rivets
	for _, u in { 2.4, 4.4, 6.6, 8.4, 10.2, 12.0, 13.8, 15.6, 17.4, 19.0 } do
		local rx = SPINE:radii(u)
		rig:band(SPINE, segBone(u), "GoldBelt", u, math.max(rx * 0.32, 0.08), math.max(rx * 0.2, 0.05), P.gold, P.goldDark)
	end

	-- Tête de dragon, gueule ouverte
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.2,
		cover = { A.scales(P.headScales, v3(0.22, 0.08, 0.24), 0.16, { arc = 125, refRadius = 0.45, tilt = 18, seed = 3 }) },
	})
	rig:tube(JAW, { name = "Jaw", bone = const("Jaw"), core = P.headScales[2], coreStep = 0.2 })
	rig:prismBetween("Jaw", "MouthInside", v3(0, 4.1, -1.9), v3(0, 4.0, -2.6), 0.5, 0.06, 0.02, P.mouth)
	rig:block("Head", "GoldCrown", cf(0, 4.9, -2.05) * ang(rad(-12), rad(45), 0), v3(0.18, 0.06, 0.18), P.gold)
	rig:mirrored(function(side, sfx)
		A.teeth(rig, "Head", A.mx(v3(0.12, 4.3, -2.85), side), A.mx(v3(0.42, 4.32, -1.95), side), 8, 0.07, 0.18, P.tooth, true)
		A.teeth(rig, "Jaw", A.mx(v3(0.1, 4.0, -2.62), side), A.mx(v3(0.36, 4.16, -1.95), side), 7, 0.06, 0.15, P.tooth, false)
		A.eye(rig, "Head", A.mx(v3(0.4, 4.72, -2.1), side), v3(side, 0.35, -0.5), 0.15, "Slit", P.socket, P.eye, P.pupil)
		A.brow(rig, "Head", side, v3(0.36, 4.86, -2.12), 0.32, 22, P.headScales[3])
		-- Cornes annelées
		local horn = { A.mx(v3(0.28, 4.85, -1.8), side), A.mx(v3(0.45, 5.15, -1.45), side), A.mx(v3(0.52, 5.22, -1.0), side), A.mx(v3(0.42, 5.05, -0.62), side) }
		A.horn(rig, "Head", horn, 0.13, 0.03, P.horn, P.hornBand, { 1.4, 2.0, 2.6, 3.2 })
		-- Nageoires en éventail
		local finBase = cf(A.mx(v3(0.5, 4.55, -1.65), side))
		for k = 0, 4 do
			local a = rad(-20 + k * 24)
			local dir = v3(side * math.cos(a) * 0.75, math.sin(a) + 0.35, 0.55).Unit
			local tip = finBase.Position + dir * (1.25 - math.abs(k - 2) * 0.12)
			rig:strut("Head", "FinRay", finBase.Position, tip, 0.06, 0.06, P.fin)
			rig:thorn("Head", "FinTip", A.alongUp(tip, dir), 0.08, 0.2, P.gold)
			if k < 4 then
				local a2 = rad(-20 + (k + 1) * 24)
				local dir2 = v3(side * math.cos(a2) * 0.75, math.sin(a2) + 0.35, 0.55).Unit
				local mid = finBase.Position + (dir + dir2).Unit * 0.55
				rig:spike("Head", "FinMembrane", A.alongUp(finBase.Position, (dir + dir2)) * ang(0, rad(90), 0), 0.5, 1.05, 0.03, P.membrane)
				local _ = mid
			end
		end

		-- Petits bras griffus
		local arm = "Arm" .. sfx
		A.limb(rig, arm, side, { { v3(0.55, 2.1, -1.0), 0.18, 0.18 }, { v3(1.1, 1.85, -1.35), 0.14, 0.14 }, { v3(1.35, 1.75, -1.85), 0.11, 0.11 } }, P.core, A.scales(P.headScales, v3(0.16, 0.06, 0.16), 0.13, { arc = 180, refRadius = 0.16, seed = 10 + side }))
		local hand = A.mx(v3(1.38, 1.73, -1.95), side)
		for k = -1, 1 do
			local dir = v3(side * k * 0.4, -0.35, -1).Unit
			rig:thorn(arm, "Claw", A.alongUp(hand, dir), 0.08, 0.32, P.claw)
		end
	end)

	-- Piliers d'or brisés en orbite + bulles
	A.orbit(rig, "Aura1", v3(0, 1.6, 1.0), 4.0, 8, 0.6, function(bone, c, i)
		local h = 0.9 + (i % 3) * 0.25
		rig:prism(bone, "Pillar", c * cf(0, -h / 2, 0) * ang(-math.pi / 2, 0, 0), v3(0.36, 0.36, h), 0.08, P.gold)
		rig:prism(bone, "PillarCap", c * cf(0, 0.04, 0) * ang(-math.pi / 2, 0, 0), v3(0.56, 0.56, 0.12), 0.06, P.goldDark)
		rig:wedge(bone, "PillarBreak", c * cf(0, -h - 0.08, 0) * ang(0, 0, math.pi), v3(0.36, 0.2, 0.36), P.gold)
	end)
	A.orbit(rig, "Aura2", v3(0, 2.6, 0.4), 2.6, 6, 0.8, function(bone, c, i)
		rig:ball(bone, "Bubble", c.Position, 0.16 + (i % 3) * 0.06, P.bubble)
	end)
	A.flatRing(rig, "Root", CENTER + v3(0, 0.03, 0), 2.9, 0.12, 0.03, 28, P.water)
	A.flatRing(rig, "Root", CENTER + v3(0, 0.03, 0), 3.5, 0.08, 0.03, 32, P.water)

	rig:hitbox(cf(0, 2.4, 0.6), v3(4.6, 5, 5))

	if rig.effects then
		local sc = rig.scale
		local b = rig:anchor("Body", "FX_Bubbles", cf(CENTER + v3(0, 1.2, 0)), v3(3.6, 1.2, 3.6))
		Fx.particles(b, {
			name = "Bubbles",
			texture = Fx.TEXTURES.sparkle,
			colors = { rgb(230, 250, 255), rgb(150, 230, 255) },
			sizes = { 0.12, 0.22 },
			transparencies = { 0.2, 0.4, 1 },
			lifetime = NumberRange.new(2, 3.5),
			rate = 10,
			speed = NumberRange.new(0.3, 0.8),
			spread = Vector2.new(20, 20),
			acceleration = v3(0, 0.6, 0),
			lightEmission = 0.5,
			volume = true,
		}, sc)
		Fx.particles(b, Fx.mist("SeaMist", { rgb(140, 240, 255), rgb(40, 140, 170) }, 5, 1.6, 0.2), sc)
		Fx.light(rig.bones.Head, { color = rgb(90, 230, 255), range = 14, brightness = 1.6 }, sc)
	end

	return rig:finish({ Rarity = "Legendary" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Léviathan des Profondeurs",
	Rarity = "Legendary",
	Zone = "GrottesCristal",
	Scale = 2.4,
	Category = "Créature Légendaire",
	Description = "Dragon aquatique géant enroulé en spirale, ceint d'or, gardien des eaux souterraines.",
	Icon = { top = rgb(20, 110, 140), bottom = rgb(4, 24, 40), glow = rgb(140, 250, 240), motif = rgb(255, 200, 60), yaw = 32, pitch = 14, zoom = 1.1 },
	Animation = { gait = "Serpent", breathe = 0.04, sway = 8, tailRate = 1.1, headLook = 14, auraSpeed = 0.25 },
	build = build,
}

return Def
