--!strict
--[[
	DRAGON D'AURORE (version cubes) — Exotique · Géant (test du style « cubes + pixels »)
	===================================================================================
	Le Dragon d'aurore refait dans le style du Gardien lunaire.

	• Corps en gros cubes bleu nuit qui passent du sarcelle (tête) au violet (queue), gravés de
	  rubans d'aurore en pixels (vert, turquoise, bleu, violet, rose) et d'étoiles.
	• Tête cubique : museau, gueule qui s'ouvre (crocs blancs), yeux blancs lumineux sur les
	  côtés, arcade sourcilière, double paire de cornes d'argent en cubes, collerette d'aurore.
	• Grandes ailes : bras d'argent sombre et doigts, membrane en carreaux de verre « pixels »
	  en dégradé d'aurore, dont les bords brillent.
	• Rangée de pointes en losange lumineuses le long du dos et de la queue, plaques de ventre
	  nacrées, épaulettes gravées d'un losange lumineux, griffes d'argent.
	• Queue de cubes qui rapetissent et s'enroulent, cristal d'aurore au bout.
	• Effets : rubans d'aurore au-dessus du dos, cristaux en orbite, poussière d'aurore.
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

local ID = "DragonDAuroreCubes"

local AURORA = { rgb(80, 255, 160), rgb(60, 230, 230), rgb(70, 150, 255), rgb(160, 90, 255), rgb(255, 110, 210) }
local WHITE = Color3.new(1, 1, 1)

local P = {
	head = S(rgb(22, 58, 80)),
	neck = S(rgb(24, 48, 84)),
	torso = S(rgb(26, 40, 88)),
	torsoDark = S(rgb(18, 28, 64)),
	torsoLight = S(rgb(44, 64, 128)),
	tail = { S(rgb(34, 36, 92)), S(rgb(44, 34, 96)), S(rgb(56, 32, 98)), S(rgb(68, 30, 98)) },
	pearl = S(rgb(236, 242, 255)),
	pearlShade = S(rgb(200, 212, 240)),
	silver = S(rgb(226, 232, 244), M.Metal),
	silverDark = S(rgb(140, 150, 180), M.Metal),
	finger = S(rgb(30, 36, 70)),
	tooth = S(rgb(255, 255, 255)),
	mouth = S(rgb(70, 20, 90)),
	eyeRim = S(rgb(10, 12, 30)),
	eye = S(rgb(255, 255, 255), M.Neon),
	star = S(rgb(255, 255, 255), M.Neon),
	-- aurore : pastel (gravures), néon (pointes, lumières), verre (membrane)
	pastel = {} :: { Kit.Style },
	neon = {} :: { Kit.Style },
	glass = {} :: { Kit.Style },
	glassDark = {} :: { Kit.Style },
	headDark = S(rgb(34, 84, 108)),
	headLight = S(rgb(84, 156, 176)),
	torsoRim = S(rgb(44, 64, 128)),
	torsoShine = S(rgb(86, 116, 192)),
}
for i, c in AURORA do
	P.pastel[i] = S(c:Lerp(WHITE, 0.12))
	P.neon[i] = S(c, M.Neon)
	P.glass[i] = S(c:Lerp(WHITE, 0.1), M.Glass, { transparency = 0.3 })
	P.glassDark[i] = S(c:Lerp(Color3.new(0, 0, 0), 0.25), M.Glass, { transparency = 0.3 })
end
local TAIL_RGB = { rgb(34, 36, 92), rgb(44, 34, 96), rgb(56, 32, 98), rgb(68, 30, 98) }

--- Couleur d'aurore n° 1..5 selon t (0..1), bornée.
local function au(t: number): number
	return math.clamp(1 + math.floor(t * 5), 1, 5)
end

local DIAMOND = {
	"...L...",
	"..L.L..",
	".L.C.L.",
	"L.CCC.L",
	".L.C.L.",
	"..L.L..",
	"...L...",
}

-- Queue : base dans la croupe, 8 cubes qui rapetissent en s'enroulant, cristal au bout
local TAIL_PTS = {
	v3(0, 2.15, 1.5),
	v3(0, 2.05, 1.95), v3(0, 1.9, 2.6), v3(0.08, 1.7, 3.2), v3(0.25, 1.48, 3.75),
	v3(0.5, 1.28, 4.22), v3(0.82, 1.12, 4.6), v3(1.2, 1.02, 4.88), v3(1.6, 1.0, 5.05),
	v3(1.95, 1.05, 5.12),
}
local TAIL_SIZE = { 0.72, 0.66, 0.6, 0.54, 0.48, 0.42, 0.36, 0.31 }

local ABILITY: Types.Ability = {
	name = "Souffle boréal",
	kind = "Breath",
	colors = { rgb(80, 255, 170), rgb(150, 90, 255), rgb(255, 130, 220) },
	texture = "sparkle",
	bone = "Head",
	origin = v3(0, 3.3, -3.6),
	direction = v3(0, -0.15, -1),
	radius = 9,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local face = Pixel.face
	local function engrave(bone: string, f: CFrame, px: number, rows: { string }, light: Kit.Style, glow: Kit.Style?)
		Pixel.draw(rig, bone, f, px, rows, { L = { light, 0.03 }, C = { glow or light, 0.035 } })
	end
	--- Écailles gravées sur toute une face (contours sombres, reflets clairs, quelques écailles
	--- qui brillent aux couleurs de l'aurore).
	local function scaleFace(bone: string, f: CFrame, w: number, h: number, px: number, seed: number, dark: Kit.Style, light: Kit.Style, glowEvery: number?)
		local pal: Pixel.Palette = { D = { dark, 0.014 }, L = { light, 0.02 } }
		for i = 1, 5 do
			pal[tostring(i)] = { P.neon[i], 0.018 }
		end
		Pixel.draw(rig, bone, f, px, Pixel.grid(w, h, px, Pixel.scales(4, 3, glowEvery or 9, seed)), pal)
	end
	--- Petite étoile lumineuse (croix de pixels).
	local function star(bone: string, f: CFrame, px: number)
		Pixel.draw(rig, bone, f, px, { ".W.", "WWW", ".W." }, { W = { P.star, 0.03 } })
	end
	local auroraPal: Pixel.Palette = {}
	for i = 1, 5 do
		auroraPal[tostring(i)] = { P.pastel[i], 0.03 }
	end
	auroraPal.W = { P.star, 0.035 }

	-- Os
	rig:bone("Body", "Root", cf(0, 2.15, 0))
	rig:bone("Head", "Body", cf(0, 2.8, -1.55))
	rig:bone("Jaw", "Head", cf(0, 3.27, -2.85))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.62, 1.8, -0.8))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.62, 1.8, 0.85))
		rig:bone("Wing" .. sfx, "Body", cf(side * 0.68, 2.85, -0.5))
	end)
	local tail = rig:boneChain("Tail", "Body", TAIL_PTS)

	-- =====================================================================
	-- Corps : cubes bleu nuit gravés de rubans d'aurore
	-- =====================================================================
	local tc = v3(0, 2.2, 0.05)
	local TW, TH, TL = 1.4, 1.2, 2.5
	rig:block("Body", "Torso", cf(tc), v3(TW, TH, TL), P.torso)
	rig:block("Body", "Chest", cf(0, 2.35, -1.35), v3(1.24, 1.0, 0.5), P.torso)
	rig:block("Body", "Rump", cf(0, 2.12, 1.45), v3(1.2, 0.95, 0.4), P.torso)
	rig:block("Body", "BackPlate", cf(tc + v3(0, TH / 2 + 0.02, 0)), v3(0.7, 0.04, TL - 0.2), P.torsoDark)
	for k = 0, 4 do
		local z = -0.95 + k * 0.48
		rig:block("Body", "BellyPlate", cf(0, 1.58, z), v3(1.0, 0.08, 0.38), if k % 2 == 0 then P.pearl else P.pearlShade)
		rig:block("Body", "BellyGroove", cf(0, 1.535, z + 0.17), v3(0.96, 0.02, 0.04), P.pearlShade)
		rig:block("Body", "BellyShine", cf(0, 1.535, z - 0.1), v3(0.5, 0.02, 0.05), P.pearl)
	end
	local waves = Pixel.waves(28, 11, {
		{ 1.6, 18, 0.0, 4.0, 2 },
		{ 1.2, 14, 2.2, 8.0, 1 },
	}, "12345")
	rig:mirrored(function(side)
		local n = v3(side, 0, 0)
		local f = face(tc + v3(side * TW / 2, 0.02, 0), n)
		-- les rubans vont du vert (vers la tête) au rose (vers la queue) des deux côtés :
		-- sur le flanc gauche, l'axe horizontal de la face est inversé, on retourne le motif
		local rows = waves
		if side < 0 then
			rows = {}
			for _, row in waves do
				table.insert(rows, string.reverse(row))
			end
		end
		scaleFace("Body", f, TL - 0.12, TH - 0.28, 0.075, 60 + side, P.torsoRim, P.torsoShine, 11)
		Pixel.draw(rig, "Body", f, 0.08, rows, auroraPal)
		for k, pos in { v3(-0.85, 0.32, 0), v3(0.2, -0.3, 0), v3(0.95, 0.25, 0) } do
			star("Body", f * cf(pos.X * side, pos.Y, 0), 0.04 + (k % 2) * 0.015)
		end
		-- éclats sur les arêtes du dos et du ventre
		Pixel.chips(rig, "Body", tc + v3(side * TW / 2, TH / 2, -TL / 2 + 0.1), tc + v3(side * TW / 2, TH / 2, TL / 2 - 0.1), 9, 0.13, { P.torsoDark, P.torsoLight, P.torso }, 70 + side)
		Pixel.chips(rig, "Body", tc + v3(side * TW / 2, -TH / 2, -TL / 2 + 0.2), tc + v3(side * TW / 2, -TH / 2, TL / 2 - 0.2), 6, 0.11, { P.torsoDark, P.torso }, 80 + side)
		-- écailles le long de l'échine
		scaleFace("Body", face(tc + v3(side * 0.53, TH / 2, 0.02), Vector3.yAxis, v3(0, 0, -1)), 0.3, TL - 0.2, 0.075, 90 + side, P.torsoRim, P.torsoShine, 7)
		rig:block("Body", "FlankBand", cf(tc + v3(side * (TW / 2 + 0.01), -TH / 2 + 0.1, 0)), v3(0.02, 0.12, TL - 0.1), P.torsoDark)
	end)
	scaleFace("Body", face(v3(0, 2.35, -1.6), v3(0, 0, -1)), 1.14, 0.9, 0.07, 101, P.torsoRim, P.torsoShine, 8)
	scaleFace("Body", face(v3(0, 2.12, 1.65), v3(0, 0, 1)), 1.1, 0.85, 0.07, 102, P.torsoRim, P.torsoShine, 8)
	Pixel.chips(rig, "Body", v3(-0.62, 2.85, -1.6), v3(0.62, 2.85, -1.6), 5, 0.11, { P.torsoDark, P.torsoLight }, 103)
	engrave("Body", face(v3(0, 2.35, -1.6), v3(0, 0, -1)), 0.07, DIAMOND, P.torsoLight, P.neon[2])

	-- Pointes en losange lumineuses le long du dos
	for k, z in { -1.15, -0.65, -0.15, 0.35, 0.85, 1.35 } do
		local t = (k - 1) / 10
		rig:block("Body", "Spike", cf(0, 2.86, z) * ang(rad(45), 0, 0), v3(0.18, 0.3, 0.3), P.neon[au(t)])
	end

	-- =====================================================================
	-- Pattes : cubes articulés, épaulettes gravées, griffes d'argent
	-- =====================================================================
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, z in { F = -0.8, B = 0.85 } do
			local bone = "Leg_" .. key .. s
			local x = side * 0.62
			rig:joint(bone, v3(x, 1.8, z), v3(x, 0.95, z))
			rig:block(bone, "UpperLeg", cf(x, 1.36, z), v3(0.52, 0.86, 0.58), P.torso)
			local plate = v3(x + side * 0.06, 1.62, z)
			rig:block(bone, "LegPlate", cf(plate), v3(0.5, 0.52, 0.64), P.torsoDark)
			engrave(bone, face(plate + v3(side * 0.25, 0, 0), v3(side, 0, 0)), 0.06, DIAMOND, P.torsoLight, P.neon[if key == "F" then 2 else 4])
			rig:block(bone, "KneeBand", cf(x, 0.95, z), v3(0.56, 0.09, 0.62), P.torsoLight)
			rig:block(bone, "LowerLeg", cf(x, 0.56, z + 0.02), v3(0.46, 0.72, 0.5), P.torso)
			rig:block(bone, "Shin", cf(x, 0.6, z - 0.255), v3(0.36, 0.5, 0.02), P.pearlShade)
			scaleFace(bone, face(v3(x + side * 0.23, 0.58, z + 0.02), v3(side, 0, 0)), 0.46, 0.62, 0.065, 200 + side * 10 + (if key == "F" then 1 else 2), P.torsoRim, P.torsoShine, 7)
			scaleFace(bone, face(v3(x, 1.2, z - 0.29), v3(0, 0, -1)), 0.48, 0.5, 0.065, 220 + side * 10 + (if key == "F" then 1 else 2), P.torsoRim, P.torsoShine, 0)
			rig:block(bone, "Foot", cf(x, 0.1, z - 0.08), v3(0.62, 0.2, 0.78), P.torsoDark)
			for t = -1, 1 do
				rig:block(bone, "Toe", cf(x + t * 0.19, 0.13, z - 0.36), v3(0.15, 0.16, 0.16), P.torso)
			end
			Pixel.chips(rig, bone, v3(x - 0.29, 0.21, z - 0.46), v3(x + 0.29, 0.21, z - 0.46), 3, 0.07, { P.torsoLight }, 240 + side)
			for t = -1, 1 do
				rig:block(bone, "Claw", cf(x + t * 0.19, 0.11, z - 0.5) * ang(rad(45), 0, 0), v3(0.11, 0.13, 0.13), P.silver)
			end
		end
	end)

	-- =====================================================================
	-- Cou et tête
	-- =====================================================================
	rig:block("Head", "Neck", cf(0, 2.95, -1.75), v3(0.9, 0.85, 0.7), P.neck)
	rig:block("Head", "Neck", cf(0, 3.32, -2.12), v3(0.8, 0.8, 0.6), P.neck)
	rig:block("Head", "Throat", cf(0, 2.72, -2.06), v3(0.62, 0.36, 0.1), P.pearl)
	rig:block("Head", "Throat", cf(0, 3.0, -2.43), v3(0.56, 0.3, 0.1), P.pearlShade)
	rig:block("Head", "NeckSpike", cf(0, 3.42, -1.72) * ang(rad(45), 0, 0), v3(0.16, 0.26, 0.26), P.neon[1])
	rig:block("Head", "NeckSpike", cf(0, 3.76, -2.08) * ang(rad(45), 0, 0), v3(0.16, 0.24, 0.24), P.neon[1])
	rig:mirrored(function(side)
		scaleFace("Head", face(v3(side * 0.45, 2.95, -1.75), v3(side, 0, 0)), 0.66, 0.8, 0.065, 300 + side, P.headDark, P.headLight, 8)
		scaleFace("Head", face(v3(side * 0.4, 3.32, -2.12), v3(side, 0, 0)), 0.56, 0.74, 0.065, 310 + side, P.headDark, P.headLight, 8)
	end)
	local hc = v3(0, 3.62, -2.5)
	rig:block("Head", "Skull", cf(hc), v3(1.0, 0.75, 0.95), P.head)
	rig:block("Head", "Brow", cf(0, 3.93, -2.86), v3(1.06, 0.12, 0.3), P.torsoDark)
	local snout = v3(0, 3.5, -3.25)
	rig:block("Head", "Snout", cf(snout), v3(0.78, 0.42, 0.62), P.head)
	rig:block("Head", "SnoutTop", cf(snout + v3(0, 0.215, 0.02)), v3(0.62, 0.02, 0.5), P.torsoLight)
	rig:block("Head", "Mouth", cf(0, 3.27, -3.2), v3(0.66, 0.06, 0.66), P.mouth)
	for _, sx in { -1, 1 } do
		rig:block("Head", "Nostril", cf(sx * 0.18, 3.715, -3.45), v3(0.1, 0.02, 0.08), P.eyeRim)
	end
	-- Crocs du haut
	for k = -2, 2 do
		rig:block("Head", "Tooth", cf(k * 0.14, 3.24, -3.52), v3(0.07, 0.09, 0.07), P.tooth)
	end
	-- Mâchoire (s'ouvre pendant la capacité)
	rig:block("Jaw", "Jaw", cf(0, 3.15, -3.15), v3(0.72, 0.18, 0.8), P.head)
	rig:block("Jaw", "JawPlate", cf(0, 3.055, -3.1), v3(0.56, 0.02, 0.6), P.pearl)
	for k = -1, 1, 2 do
		rig:block("Jaw", "Tooth", cf(k * 0.24, 3.28, -3.48), v3(0.08, 0.1, 0.08), P.tooth)
	end
	-- Écailles gravées sur le crâne, éclats sur les arêtes
	scaleFace("Head", face(hc + v3(0, 0.375, 0.12), Vector3.yAxis, v3(0, 0, -1)), 0.92, 0.66, 0.065, 320, P.headDark, P.headLight, 6)
	scaleFace("Head", face(snout + v3(0, 0.21, 0.08), Vector3.yAxis, v3(0, 0, -1)), 0.7, 0.36, 0.06, 321, P.headDark, P.headLight, 0)
	for _, sx in { -1, 1 } do
		Pixel.chips(rig, "Head", hc + v3(sx * 0.5, 0.375, -0.4), hc + v3(sx * 0.5, 0.375, 0.45), 4, 0.1, { P.headDark, P.headLight }, 330 + sx)
	end
	rig:mirrored(function(side)
		-- Œil blanc lumineux sur le côté de la tête, pupille d'aurore
		local e = v3(side * 0.5, 3.7, -2.78)
		rig:block("Head", "EyeRim", cf(e + v3(side * 0.012, 0, 0)), v3(0.03, 0.24, 0.36), P.eyeRim)
		rig:block("Head", "Eye", cf(e + v3(side * 0.03, 0, 0)), v3(0.03, 0.17, 0.28), P.eye)
		rig:block("Head", "Pupil", cf(e + v3(side * 0.045, -0.01, -0.06)), v3(0.02, 0.12, 0.07), P.neon[1])
		rig:block("Head", "BrowSide", cf(e + v3(side * 0.02, 0.15, 0.02)) * ang(side * rad(12), 0, 0), v3(0.08, 0.06, 0.42), P.torsoDark)
		scaleFace("Head", face(v3(side * 0.39, 3.5, -3.25), v3(side, 0, 0)), 0.58, 0.38, 0.06, 340 + side, P.headDark, P.headLight, 0)
		scaleFace("Head", face(v3(side * 0.5, 3.5, -2.3), v3(side, 0, 0)), 0.4, 0.5, 0.065, 350 + side, P.headDark, P.headLight, 5)
		-- Double paire de cornes d'argent en cubes, pointe d'aurore
		local h0, dir = v3(side * 0.32, 3.99, -2.2), v3(side * 0.25, 0.55, 0.8).Unit
		for k, sz in { 0.24, 0.19, 0.14 } do
			local p = h0 + dir * (0.05 + (k - 1) * 0.22)
			rig:block("Head", "Horn", Kit.lookAlong(p, dir), v3(sz, sz, 0.24), if k == 3 then P.silverDark else P.silver)
			rig:block("Head", "HornRing", Kit.lookAlong(p - dir * 0.1, dir), v3(sz * 1.08, sz * 1.08, 0.04), P.silverDark)
		end
		rig:block("Head", "HornTip", Kit.lookAlong(h0 + dir * 0.62, dir) * ang(0, 0, rad(45)), v3(0.08, 0.08, 0.16), P.neon[5])
		local h1, dir1 = v3(side * 0.5, 3.8, -2.15), v3(side * 0.85, 0.35, 0.4).Unit
		for k, sz in { 0.18, 0.13 } do
			rig:block("Head", "Horn", Kit.lookAlong(h1 + dir1 * (k - 1) * 0.18, dir1), v3(sz, sz, 0.18), P.silver)
		end
		-- Collerette d'aurore à l'arrière de la tête
		for k = 1, 3 do
			local p = v3(side * (0.5 + k * 0.05), 3.35 + k * 0.08, -2.1 + k * 0.12)
			rig:block("Head", "Frill", cf(p) * ang(rad(30), side * rad(25), side * rad(20)), v3(0.06, 0.3 - k * 0.04, 0.22), P.neon[k + 1])
		end
	end)

	-- =====================================================================
	-- Ailes : bras d'argent sombre, membrane en carreaux de verre (dégradé d'aurore)
	-- =====================================================================
	rig:mirrored(function(side, sfx)
		local w = "Wing" .. sfx
		local S0 = v3(side * 0.68, 2.85, -0.5)
		local E = v3(side * 1.75, 4.15, -0.15)
		local T1 = v3(side * 3.35, 4.85, 0.45)
		local T2 = v3(side * 3.3, 3.75, 1.3)
		local T3 = v3(side * 2.25, 3.05, 1.65)
		local R = v3(side * 0.68, 2.76, 0.85)
		rig:strut(w, "WingArm", S0, E, 0.2, 0.2, P.finger)
		rig:block(w, "WingElbow", cf(E) * ang(rad(45), 0, rad(45)), v3(0.24, 0.24, 0.24), P.silver)
		for i, T in { T1, T2, T3 } do
			rig:strut(w, "WingFinger", E, T, 0.11, 0.11, P.finger)
			rig:block(w, "WingTip", Kit.lookAlong(T, T - E) * ang(0, 0, rad(45)), v3(0.12, 0.12, 0.22), if i == 1 then P.silver else P.neon[3 + i - 1])
		end
		local maxd = (T1 - S0).Magnitude
		local function tile(p: Vector3): Kit.Style?
			local t = (p - S0).Magnitude / maxd
			local i = au(t * 0.98)
			local h = Pixel.hash(math.floor(p.X * 7 + 100), math.floor(p.Y * 7 + 100) * 3 + math.floor(p.Z * 7 + 100), 4)
			if t > 0.86 then
				return P.neon[i]
			elseif h % 23 == 0 then
				return P.neon[i] -- étincelle dans la membrane
			elseif h % 3 == 0 then
				return P.glassDark[i]
			end
			return P.glass[i]
		end
		for _, T in { T1, T2, T3 } do
			rig:block(w, "WingJoint", Kit.lookAlong(E:Lerp(T, 0.5), T - E), v3(0.15, 0.15, 0.08), P.silverDark)
		end
		rig:block(w, "WingJoint", Kit.lookAlong(S0:Lerp(E, 0.5), E - S0), v3(0.25, 0.25, 0.08), P.silverDark)
		for _, tri in { { E, T1, T2 }, { E, T2, T3 }, { E, T3, R }, { S0, E, R } } do
			Pixel.tiles(rig, w, tri[1], tri[2], tri[3], 0.3, 0.05, tile, "WingTile")
		end
	end)

	-- =====================================================================
	-- Queue : cubes qui rapetissent et s'enroulent, cristal d'aurore au bout
	-- =====================================================================
	for j = 1, #TAIL_SIZE do
		local p = TAIL_PTS[j + 1]
		local dir = (TAIL_PTS[j + 2] - TAIL_PTS[j]).Unit
		local c = Kit.lookAlong(p, dir)
		local s = TAIL_SIZE[j]
		local bone = tail[j]
		local t = j / #TAIL_SIZE
		rig:block(bone, "TailCube", c, v3(s, s * 0.9, s * 1.05), P.tail[math.clamp(math.ceil(t * 4), 1, 4)])
		rig:block(bone, "TailBelly", c * cf(0, -s * 0.45 - 0.02, 0), v3(s * 0.7, 0.04, s * 0.8), P.pearlShade)
		rig:block(bone, "TailSpike", c * cf(0, s * 0.45 + s * 0.12, 0) * ang(rad(45), 0, 0), v3(s * 0.26, s * 0.4, s * 0.4), P.neon[au(0.3 + t * 0.7)])
		local base = TAIL_RGB[math.clamp(math.ceil(t * 4), 1, 4)]
		local dark, light = S(base:Lerp(WHITE, 0.14)), S(base:Lerp(WHITE, 0.36))
		for _, sd in { 1, -1 } do
			scaleFace(bone, Pixel.face((c * cf(sd * s / 2, 0, 0)).Position, c.RightVector * sd, c.UpVector), s * 1.0, s * 0.82, s / 7, 400 + j * 3 + sd, dark, light, 6)
		end
		scaleFace(bone, Pixel.face((c * cf(0, s * 0.45, 0)).Position, c.UpVector, c.LookVector), s * 0.92, s * 1.0, s / 7, 450 + j, dark, light, 0)
		Pixel.chips(rig, bone, (c * cf(s / 2, s * 0.45, -s * 0.4)).Position, (c * cf(s / 2, s * 0.45, s * 0.4)).Position, 2, s * 0.16, { dark, light }, 470 + j)
		Pixel.chips(rig, bone, (c * cf(-s / 2, s * 0.45, -s * 0.4)).Position, (c * cf(-s / 2, s * 0.45, s * 0.4)).Position, 2, s * 0.16, { dark, light }, 480 + j)
	end
	do
		local tipP = TAIL_PTS[#TAIL_PTS]
		local dir = (tipP - TAIL_PTS[#TAIL_PTS - 1]).Unit
		A.crystals(rig, tail[#tail], A.alongUp(tipP - dir * 0.1, dir), 4, 0.7, { P.neon[5], P.glass[4], P.neon[4] }, 9, 0.4)
	end

	-- =====================================================================
	-- Cristaux d'aurore en orbite
	-- =====================================================================
	A.orbit(rig, "Aura1", v3(0, 2.7, 0.4), 3.4, 10, 0.6, function(bone, c, i)
		local col = ((i - 1) % 5) + 1
		rig:block(bone, "AuroraGem", c * ang(rad(45), 0, rad(45)), v3(0.2, 0.2, 0.2), P.neon[col])
		rig:block(bone, "AuroraGemShell", c * ang(rad(45), 0, rad(45)), v3(0.3, 0.3, 0.3), P.glass[col])
	end)

	rig:hitbox(cf(0, 2.1, 1.0), v3(3.4, 4.4, 7))

	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Body", "FX_Aurora", cf(0, 2.7, 0.2), v3(2.6, 1.6, 3.4))
		Fx.particles(g, Fx.sparkles("AuroraDust", { rgb(120, 255, 200), rgb(140, 120, 255), rgb(255, 140, 220) }, 12, 0.2), sc)
		Fx.light(g, { color = rgb(120, 220, 255), range = 16, brightness = 1.6 }, sc)
		local tipFx = rig:anchor(tail[#tail], "FX_TailCrystal", cf(TAIL_PTS[#TAIL_PTS]), v3(0.4, 0.4, 0.4))
		Fx.light(tipFx, { color = rgb(255, 120, 220), range = 8, brightness = 1.4 }, sc)
		-- Rubans d'aurore qui ondulent au-dessus du dos
		for i, cols in { { AURORA[1], AURORA[3] }, { AURORA[4], AURORA[5] } } do
			Vfx.beam(rig, "Body", v3(-0.3 * i, 3.9 + i * 0.25, -1.3), "Body", v3(0.3 * i, 3.5 + i * 0.25, 1.6), { colors = cols, transparency = { 0.65, 0.9 }, width0 = 0.45, width1 = 0.3, curve0 = 1.4 * (if i == 1 then 1 else -1), curve1 = -0.8 }, v3(0, 1, 0))
		end
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Exotic")
	end

	return rig:finish({ Rarity = "Exotic" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Dragon d'aurore (cubes)",
	Rarity = "Exotic",
	Size = "Giant",
	Income = 900000,
	SpeedBonus = 1.5,
	Passenger = true,
	Scale = 1.8,
	Source = "Test",
	Category = "Créature Exotique (test de style)",
	Description = "Le Dragon d'aurore refait en cubes : rubans d'aurore gravés en pixels, ailes en carreaux de verre aux couleurs du ciel polaire, cornes d'argent et pointes lumineuses.",
	Icon = { top = rgb(40, 120, 150), bottom = rgb(16, 8, 40), glow = rgb(140, 255, 210), motif = rgb(200, 130, 255), yaw = 30, pitch = 12, zoom = 1.0 },
	Animation = { gait = "Quadruped", breathe = 0.04, bob = 0.1, stride = 24, strideRate = 7, tailSway = 14, tailRate = 1.2, headLook = 16, auraSpeed = 0.5, flicker = 0.1 },
	Ability = ABILITY,
	build = build,
}

return Def
