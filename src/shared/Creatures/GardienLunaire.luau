--!strict
--[[
	GARDIEN LUNAIRE — Mythique · Géant (test du nouveau style « cubes + pixels »)
	============================================================================
	Petit félin cubique bleu nuit, gardien de la lune, fait d'après l'image de référence.

	• Corps, tête et pattes en gros cubes bleu nuit, couverts de motifs gravés en pixels :
	  disques de phases de lune, croissants, spirales carrées sur les épaules, cratères.
	• Grands yeux ronds cyan lumineux, museau carré, nez sombre, petite bouche en pixels,
	  croissant gravé sur le front.
	• Oreilles triangulaires magenta, grands cristaux de glace lumineux derrière les oreilles,
	  petits éclats de cristal sur les joues.
	• Couronne : un grand croissant de lune argenté flotte au-dessus de la tête, avec un petit
	  croissant au centre.
	• Queue : neuf cubes de lune lumineux (cratères, cercle cyan), terminée par un cube violet.
	• Effets : croissants et petites lunes en orbite, poussière d'étoiles au sol, lueur cyan.
]]

local Kit = require(script.Parent.Parent.Kit)
local A = require(script.Parent.Parent.Anatomy)
local Fx = require(script.Parent.Parent.Fx)
local Vfx = require(script.Parent.Parent.Vfx)
local Types = require(script.Parent.Parent.Types)
local Pixel = require(script.Parent.Parent.Pixel)

local S = Kit.style
local M = Enum.Material
local rgb = Color3.fromRGB
local rad = math.rad
local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles

local ID = "GardienLunaire"

local P = {
	navy = S(rgb(46, 38, 98)),
	navyDark = S(rgb(32, 26, 72)),
	navyDeep = S(rgb(22, 18, 52)),
	navyLight = S(rgb(70, 60, 136)),
	navyPale = S(rgb(104, 94, 182)),
	magenta = S(rgb(226, 66, 172)),
	magentaDark = S(rgb(140, 30, 112)),
	magentaLight = S(rgb(255, 140, 214), M.Neon),
	cyan = S(rgb(110, 236, 255), M.Neon),
	cyanSoft = S(rgb(110, 236, 255), M.Neon, { transparency = 0.62 }),
	crystal = S(rgb(226, 246, 255), M.Glass, { transparency = 0.18 }),
	crystalCore = S(rgb(170, 240, 255), M.Neon),
	moon = S(rgb(228, 230, 248)),
	moonLav = S(rgb(204, 198, 242)),
	moonShade = S(rgb(176, 174, 220)),
	crater = S(rgb(146, 142, 198)),
	eyeRim = S(rgb(18, 22, 54)),
	eyeRing = S(rgb(220, 252, 255), M.Neon),
	eye = S(rgb(90, 226, 255), M.Neon),
	eyeCore = S(rgb(200, 255, 255), M.Neon),
	white = S(rgb(255, 255, 255), M.Neon),
	nose = S(rgb(16, 12, 38)),
	tip = S(rgb(80, 60, 156)),
	tipCrater = S(rgb(46, 32, 102)),
}

-- Motifs en pixels (L clair en relief, M intermédiaire, D sombre, C cyan, S argent)
local CRESCENT = {
	"..LLL..",
	".LL....",
	"LL.....",
	"LL.....",
	"LL.....",
	".LL....",
	"..LLL..",
}
local PHASE_DISC = {
	"...MMM...",
	".MM...MM.",
	".M.LLL.M.",
	"M.LL.LL.M",
	"M.L.D.L.M",
	"M.LL.LL.M",
	".M.LLL.M.",
	".MM...MM.",
	"...MMM...",
}
local SPIRAL = {
	"LLLLLLL",
	"......L",
	"LLLLL.L",
	"L...L.L",
	"L.LLL.L",
	"L.....L",
	"LLLLLLL",
}
local CRATER = {
	".MM.",
	"M..M",
	"M..M",
	".MM.",
}
local FOREHEAD = {
	".LLL.",
	"LL...",
	"L....",
	"LL...",
	".LLL.",
}
local MOUTH = {
	"..D..",
	".D.D.",
}
local TUFT = {
	"L.L.",
	".L.L",
	"L.L.",
}

local CROWN = Pixel.crescent(6.5, 5.4, 2.4, true)
local SMALL_MOON = Pixel.crescent(3.5, 2.9, 1.4, false)

-- Queue : points de la chaîne (base dans le dos, 9 cubes, cube violet au bout) et tailles
local TAIL_PTS = {
	v3(0, 1.95, 1.0),
	v3(0, 1.98, 1.5), v3(0, 2.0, 2.12), v3(0, 2.02, 2.73), v3(0, 2.05, 3.33), v3(0, 2.1, 3.92),
	v3(0, 2.18, 4.49), v3(0, 2.32, 5.02), v3(0, 2.55, 5.48), v3(0, 2.88, 5.84),
	v3(0, 3.28, 6.05),
}
local TAIL_SIZE = { 0.6, 0.58, 0.56, 0.54, 0.52, 0.5, 0.48, 0.46, 0.44, 0.46 }

-- Capacité spéciale (CreatureForge.playAbility)
local ABILITY: Types.Ability = {
	name = "Éclat lunaire",
	kind = "Nova",
	colors = { rgb(120, 236, 255), rgb(210, 200, 255), rgb(255, 255, 255) },
	texture = "sparkle",
	origin = v3(0, 2.0, 0.4),
	radius = 6,
	duration = 1.8,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)

	--- Motif en pixels sur une face (palette bleu nuit par défaut, voir Pixel.draw).
	local function pixels(bone: string, f: CFrame, px: number, rows: { string }, depth: number?, pal: Pixel.Palette?)
		local d = depth or 0.03
		Pixel.draw(rig, bone, f, px, rows, pal or {
			L = { P.navyPale, d }, M = { P.navyLight, d * 0.8 }, D = { P.navyDeep, d * 0.5 },
			C = { P.cyan, d }, S = { P.moon, d },
		})
	end
	local face = Pixel.face
	--- Pixels isolés sur une face (texture « pierre de lune »).
	local function speckle(bone: string, f: CFrame, w: number, h: number, count: number, px: number, seed: number)
		Pixel.speckle(rig, bone, f, w, h, count, px, { P.navyDark, P.navyLight }, seed)
	end

	-- Os
	rig:bone("Body", "Root", cf(0, 1.7, 0))
	rig:bone("Head", "Body", cf(0, 2.2, -0.95))
	rig:bone("Float1", "Head", cf(0, 3.6, -1.2))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.36, 1.35, -0.62))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.36, 1.35, 0.68))
		rig:bone("Ear" .. sfx, "Head", cf(side * 0.42, 3.08, -1.36))
	end)
	local tail = rig:boneChain("Tail", "Body", TAIL_PTS)

	-- =====================================================================
	-- Corps : un gros cube bleu nuit gravé de motifs lunaires
	-- =====================================================================
	local BW, BH, BL = 1.2, 0.95, 2.0
	local bc = v3(0, 1.7, 0.05)
	rig:block("Body", "Body", cf(bc), v3(BW, BH, BL), P.navy)
	rig:block("Body", "Belly", cf(bc + v3(0, -BH / 2 - 0.02, 0)), v3(BW - 0.12, 0.06, BL - 0.16), P.navyDeep)
	rig:block("Body", "BackPlate", cf(bc + v3(0, BH / 2 + 0.025, 0.05)), v3(BW - 0.36, 0.05, BL - 0.5), P.navyDark)
	rig:mirrored(function(side)
		local x = side * (BW / 2)
		local n = v3(side, 0, 0)
		-- Bande sombre en bas du flanc, liseré clair en haut
		rig:block("Body", "FlankBand", cf(bc + v3(x + side * 0.01, -BH / 2 + 0.1, 0)), v3(0.02, 0.12, BL - 0.1), P.navyDark)
		rig:block("Body", "FlankEdge", cf(bc + v3(x + side * 0.008, BH / 2 - 0.05, 0)), v3(0.016, 0.05, BL - 0.2), P.navyLight)
		-- Disque des phases de lune près de l'épaule, croissant près de la hanche
		pixels("Body", face(bc + v3(x, 0.03, -0.42), n), 0.075, PHASE_DISC)
		pixels("Body", face(bc + v3(x, 0.05, 0.48), n), 0.07, CRESCENT)
		pixels("Body", face(bc + v3(x, -0.22, 0.05), n), 0.06, CRATER, 0.02)
		speckle("Body", face(bc + v3(x, 0.05, 0), n), BL - 0.3, BH - 0.3, 16, 0.06, 20 + side)
	end)
	-- Dos : cratères et poussière d'étoiles gravés
	local top = face(bc + v3(0, BH / 2 + 0.05, 0.05), Vector3.yAxis, v3(0, 0, -1))
	pixels("Body", top * cf(0, 0.45, 0), 0.06, CRATER, 0.02)
	pixels("Body", top * cf(-0.18, -0.35, 0), 0.05, CRATER, 0.02)
	speckle("Body", top, BW - 0.5, BL - 0.7, 10, 0.05, 31)
	-- Plastron (sous la tête) et croupe
	pixels("Body", face(bc + v3(0, -0.12, -BL / 2), v3(0, 0, -1)), 0.06, CRESCENT)
	pixels("Body", face(bc + v3(0, -0.15, BL / 2), v3(0, 0, 1)), 0.06, PHASE_DISC, 0.02)

	-- =====================================================================
	-- Pattes : cubes articulés (genou), épaulettes à spirale, coussinets sombres
	-- =====================================================================
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, z in { F = -0.62, B = 0.68 } do
			local bone = "Leg_" .. key .. s
			local x = side * 0.36
			rig:joint(bone, v3(x, 1.35, z), v3(x, 0.74, z))
			rig:block(bone, "UpperLeg", cf(x, 1.05, z), v3(0.42, 0.72, 0.44), P.navy)
			-- Épaulette / hanche gravée d'une spirale carrée
			local plate = v3(x + side * 0.05, 1.22, z)
			rig:block(bone, "LegPlate", cf(plate), v3(0.42, 0.44, 0.5), P.navyDark)
			rig:block(bone, "LegPlateRim", cf(plate + v3(side * 0.212, 0, 0)), v3(0.01, 0.46, 0.52), P.navyLight)
			pixels(bone, face(plate + v3(side * 0.217, 0, 0), v3(side, 0, 0)), 0.05, SPIRAL, 0.025)
			rig:block(bone, "KneeBand", cf(x, 0.75, z), v3(0.46, 0.08, 0.48), P.navyLight)
			-- Sous le genou (rattaché à l'articulation)
			rig:block(bone, "LowerLeg", cf(x, 0.44, z), v3(0.38, 0.58, 0.4), P.navy)
			pixels(bone, face(v3(x + side * 0.19, 0.45, z), v3(side, 0, 0)), 0.045, TUFT, 0.02)
			pixels(bone, face(v3(x, 0.47, z - 0.2), v3(0, 0, -1)), 0.045, { ".L.", "L.L", ".L." }, 0.02)
			rig:block(bone, "Paw", cf(x, 0.08, z - 0.03), v3(0.44, 0.16, 0.52), P.navyDeep)
			for t = -1, 1 do
				rig:block(bone, "Toe", cf(x + t * 0.13, 0.1, z - 0.3), v3(0.1, 0.1, 0.06), P.navyDark)
			end
		end
	end)

	-- =====================================================================
	-- Tête : gros cube, museau carré, grands yeux ronds lumineux
	-- =====================================================================
	local hc = v3(0, 2.55, -1.3)
	local HW, HH, HD = 1.3, 1.1, 1.05
	local front = hc.Z - HD / 2
	rig:block("Head", "Head", cf(hc), v3(HW, HH, HD), P.navy)
	rig:block("Head", "Jaw", cf(hc + v3(0, -HH / 2 + 0.06, -HD / 2 - 0.008)), v3(HW - 0.1, 0.1, 0.016), P.navyDark)
	-- Museau, nez, bouche
	local snout = v3(0, 2.2, front - 0.12)
	rig:block("Head", "Snout", cf(snout), v3(0.66, 0.34, 0.26), P.navyLight)
	rig:block("Head", "SnoutTop", cf(snout + v3(0, 0.175, 0)), v3(0.6, 0.02, 0.24), P.navyPale)
	rig:block("Head", "Nose", cf(snout + v3(0, 0.08, -0.15)), v3(0.22, 0.1, 0.06), P.nose)
	pixels("Head", face(snout + v3(0, -0.07, -0.13), v3(0, 0, -1)), 0.045, MOUTH, 0.02)
	-- Croissant gravé sur le front, tufts sur les joues
	pixels("Head", face(v3(0, 2.92, front), v3(0, 0, -1)), 0.05, FOREHEAD)
	rig:mirrored(function(side, sfx)
		-- Œil : bord sombre, anneau clair, iris cyan, cœur blanc, reflet
		local e = v3(side * 0.32, 2.6, front)
		local out = v3(0, 0, -1)
		rig:cylinder("Head", "EyeRim", e, e + out * 0.015, 0.54, P.eyeRim)
		rig:cylinder("Head", "EyeRing", e + out * 0.015, e + out * 0.03, 0.46, P.eyeRing)
		rig:cylinder("Head", "Eye", e + out * 0.03, e + out * 0.045, 0.39, P.eye)
		rig:cylinder("Head", "EyeCore", e + out * 0.045, e + out * 0.055, 0.18, P.eyeCore)
		rig:block("Head", "EyeShine", cf(e + out * 0.06 + v3(-side * 0.1, 0.1, 0)), v3(0.06, 0.06, 0.012), P.white)
		-- Côtés de la tête : tufts gravés et texture
		local sideFace = face(hc + v3(side * HW / 2, -0.15, 0.05), v3(side, 0, 0))
		pixels("Head", sideFace * cf(0.12, -0.1, 0), 0.05, TUFT, 0.02)
		speckle("Head", face(hc + v3(side * HW / 2, 0.15, 0), v3(side, 0, 0)), HD - 0.3, 0.5, 6, 0.05, 40 + side)
		-- Oreilles triangulaires magenta (intérieur sombre, pointe claire)
		local ear = "Ear" .. sfx
		local z0 = hc.Z - 0.08
		A.triangle(rig, ear, "Ear", v3(side * 0.2, 3.06, z0), v3(side * 0.64, 3.06, z0), v3(side * 0.6, 3.66, z0 + 0.04), 0.2, P.magenta)
		A.triangle(rig, ear, "EarInner", v3(side * 0.3, 3.1, z0 - 0.105), v3(side * 0.57, 3.1, z0 - 0.105), v3(side * 0.56, 3.46, z0 - 0.08), 0.03, P.magentaDark)
		rig:block(ear, "EarTip", cf(side * 0.6, 3.6, z0 + 0.03) * ang(0, 0, -side * rad(4)), v3(0.08, 0.1, 0.13), P.magentaLight)
		-- Grands cristaux de glace derrière les oreilles (cœur lumineux)
		local base = cf(side * 0.48, 3.02, hc.Z + 0.32) * ang(rad(18), 0, -side * rad(32))
		rig:shard("Head", "Crystal", base, 0.4, 0.78, 0.42, P.crystal)
		rig:shard("Head", "CrystalCore", base * cf(0, 0.05, 0), 0.16, 0.7, 0.28, P.crystalCore)
		local base2 = cf(side * 0.6, 2.98, hc.Z + 0.42) * ang(rad(30), side * rad(20), -side * rad(58))
		rig:shard("Head", "Crystal", base2, 0.28, 0.52, 0.3, P.crystal)
		rig:shard("Head", "CrystalCore", base2 * cf(0, 0.04, 0), 0.11, 0.46, 0.18, P.crystalCore)
		-- Éclats sur les joues (blanc et rose)
		local cheek = cf(side * 0.66, 2.86, hc.Z - 0.3) * ang(0, 0, -side * rad(72))
		rig:shard("Head", "CheekCrystal", cheek, 0.14, 0.18, 0.14, P.crystal)
		rig:shard("Head", "CheekCrystal", cheek * cf(0.02, -0.02, 0.22) * ang(rad(-20), 0, 0), 0.11, 0.12, 0.1, P.magentaLight)
	end)
	speckle("Head", face(hc + v3(0, HH / 2, 0.1), Vector3.yAxis, v3(0, 0, -1)), HW - 0.5, HD - 0.5, 6, 0.05, 44)

	-- =====================================================================
	-- Couronne : grand croissant de lune en pixels qui flotte (os Float1)
	-- =====================================================================
	do
		local c0 = v3(0, 3.84, -1.2)
		local crownPal = {
			S = { P.moon, 0.2 }, C = { S(rgb(190, 246, 255), M.Neon), 0.2 }, K = { P.crater, 0.2 },
			E = { P.moonLav, 0.16 },
		}
		pixels("Float1", face(c0 + v3(0, 0, 0.1), v3(0, 0, -1)), 0.08, CROWN, 0.2, crownPal)
		rig:block("Float1", "CrownSpark", cf(c0 + v3(0.5, 0.42, -0.1)) * ang(0, 0, rad(45)), v3(0.07, 0.07, 0.03), P.white)
		rig:block("Float1", "CrownSpark", cf(c0 + v3(-0.56, 0.3, -0.1)) * ang(0, 0, rad(45)), v3(0.05, 0.05, 0.03), P.white)
	end

	-- =====================================================================
	-- Queue : cubes de lune lumineux, cube violet au bout
	-- =====================================================================
	for j = 1, #TAIL_PTS - 1 do
		local p = TAIL_PTS[j + 1]
		local dir = (TAIL_PTS[math.min(j + 2, #TAIL_PTS)] - TAIL_PTS[j]).Unit
		local c = Kit.lookAlong(p, dir)
		local s = TAIL_SIZE[j]
		local bone = tail[j]
		if j == #TAIL_PTS - 1 then
			-- Cube violet du bout, creusé de cratères
			rig:block(bone, "TailTip", c, v3(s, s, s), P.tip)
			for k, off in { v3(s / 2, 0.06, -0.05), v3(-s / 2, -0.05, 0.06), v3(0, s / 2, 0.05), v3(0.06, 0.04, -s / 2) } do
				local d = 0.07 + (k % 2) * 0.04
				local size = v3(if off.X ~= 0 then 0.02 else d, if off.Y ~= 0 then 0.02 else d, if off.Z ~= 0 then 0.02 else d)
				rig:block(bone, "TipCrater", c * cf(off * 1.04), size, P.tipCrater)
			end
		else
			rig:block(bone, "TailCube", c, v3(s, s, s), P.moon)
			rig:block(bone, "TailGlow", c, v3(s * 1.14, s * 1.14, s * 0.86), P.cyanSoft)
			for _, sd in { 1, -1 } do
				local o = c * cf(sd * s / 2, 0, 0)
				local ax = c.RightVector * sd
				rig:cylinder(bone, "TailRing", o.Position, o.Position + ax * 0.03, s * 0.86, P.cyan)
				rig:cylinder(bone, "TailMoon", o.Position + ax * 0.03, o.Position + ax * 0.05, s * 0.7, P.moonLav)
				local rng = Random.new(j * 10 + sd)
				for _ = 1, 3 do
					local d = s * rng:NextNumber(0.1, 0.18)
					rig:block(bone, "TailCrater", c * cf(sd * (s / 2 + 0.055), rng:NextNumber(-0.18, 0.18) * s, rng:NextNumber(-0.18, 0.18) * s), v3(0.012, d, d), P.crater)
				end
			end
			rig:block(bone, "TailTopCrater", c * cf(0.06, s / 2 + 0.006, -0.04), v3(s * 0.2, 0.012, s * 0.2), P.moonShade)
		end
	end

	-- =====================================================================
	-- Croissants et petites lunes en orbite
	-- =====================================================================
	local moonPal = { S = { P.moon, 0.07 }, C = { S(rgb(190, 246, 255), M.Neon), 0.07 }, K = { P.moonShade, 0.07 } }
	local function crescent(bone: string, c: CFrame, r: number)
		pixels(bone, c, r / 3.5, SMALL_MOON, 0.07, moonPal)
	end
	local function fullMoon(bone: string, c: CFrame, r: number)
		rig:cylinder(bone, "OrbitMoonRing", (c * cf(0, 0, -0.02)).Position, (c * cf(0, 0, 0.02)).Position, r * 2.2, P.cyanSoft)
		rig:cylinder(bone, "OrbitMoon", (c * cf(0, 0, -0.03)).Position, (c * cf(0, 0, 0.03)).Position, r * 2, P.moon)
		rig:block(bone, "OrbitCrater", c * cf(r * 0.3, r * 0.2, -0.035), v3(r * 0.45, r * 0.45, 0.01), P.crater)
		rig:block(bone, "OrbitCrater", c * cf(-r * 0.35, -r * 0.3, -0.035), v3(r * 0.3, r * 0.3, 0.01), P.moonShade)
	end
	A.orbit(rig, "Aura1", v3(0, 2.5, 3.7), 1.4, 7, 0.35, function(bone, c, i)
		local f = c * ang(0, math.pi / 2, 0) * ang(0, 0, rad(i * 47))
		if i % 3 == 0 then
			fullMoon(bone, f, 0.11)
		else
			crescent(bone, f, 0.26 + (i % 2) * 0.06)
		end
	end)
	A.orbit(rig, "Aura2", v3(0, 2.9, -0.2), 2.0, 4, 0.4, function(bone, c, i)
		local f = c * ang(0, math.pi / 2, 0) * ang(0, 0, rad(i * 71))
		if i % 2 == 0 then
			fullMoon(bone, f, 0.1)
		else
			crescent(bone, f, 0.24)
		end
	end)

	rig:hitbox(cf(0, 1.7, 1.6), v3(2.2, 3.5, 7.6))

	-- Effets : lueur cyan, poussière d'étoiles, paillettes au sol
	if rig.effects then
		local sc = rig.scale
		local tailFx = rig:anchor(tail[4], "FX_TailGlow", cf(TAIL_PTS[5]), v3(0.5, 0.5, 2))
		Fx.particles(tailFx, Fx.sparkles("MoonDust", { rgb(170, 240, 255), rgb(255, 255, 255), rgb(200, 190, 255) }, 10, 0.18, 0.1), sc)
		Fx.light(tailFx, { color = rgb(120, 230, 255), range = 12, brightness = 1.6 }, sc)
		local headFx = rig:anchor("Head", "FX_Eyes", cf(0, 2.7, -1.9), v3(1, 0.5, 0.2))
		Fx.light(headFx, { color = rgb(120, 236, 255), range = 7, brightness = 1.2 }, sc)
		local crownFx = rig:anchor("Float1", "FX_Crown", cf(0, 3.7, -1.2), v3(1.1, 0.6, 0.3))
		Fx.particles(crownFx, Fx.sparkles("CrownStars", { rgb(255, 255, 255), rgb(170, 240, 255) }, 4, 0.14, 0.15), sc)
		local ground = rig:anchor("Root", "FX_Glitter", cf(0, 0.15, 1.4), v3(3.2, 0.2, 6.5))
		Fx.particles(ground, Fx.sparkles("Glitter", { rgb(150, 230, 255), rgb(255, 255, 255) }, 16, 0.1, 0.02), sc)
		local tip = TAIL_PTS[#TAIL_PTS]
		Vfx.trail(rig, tail[#tail], tip + v3(0, 0.12, 0), tip - v3(0, 0.12, 0), { colors = { rgb(170, 240, 255), rgb(120, 90, 255) }, lifetime = 0.5 })
		Vfx.abilityOrigin(rig, ABILITY)
	end

	return rig:finish({ Rarity = "Mythic" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Gardien lunaire",
	Rarity = "Mythic",
	Size = "Giant",
	Income = 80000,
	SpeedBonus = 0.85,
	Passenger = true,
	Scale = 1.9,
	Source = "Test",
	Category = "Créature Mythique (test de style)",
	Description = "Petit félin cubique bleu nuit, gardien de la lune : des yeux cyan lumineux, des cristaux de glace, un croissant de lune qui flotte au-dessus de sa tête et une queue de cubes de lune.",
	Icon = { top = rgb(64, 54, 128), bottom = rgb(16, 12, 38), glow = rgb(120, 230, 255), motif = rgb(200, 190, 255), yaw = 32, pitch = 12, zoom = 1.0 },
	Animation = { flicker = 0.1, gait = "Quadruped", breathe = 0.03, bob = 0.1, stride = 26, strideRate = 9, tailSway = 10, tailRate = 1.4, headLook = 18, earTwitch = true, auraSpeed = 0.6 },
	Ability = ABILITY,
	build = build,
}

return Def
