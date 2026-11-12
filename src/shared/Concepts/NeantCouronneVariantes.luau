--!strict
--[[
	VARIANTES DU NÉANT COURONNÉ (concepts à comparer)
	=================================================
	10 interprétations différentes de la même créature mythique. Toutes gardent l'identité
	du Néant Couronné : une couronne, une orbite de cristaux violets, des fragments d'énergie
	rouges en orbite, une aura rouge sang et le cercle runique au sol.

	Ces variantes ne sont PAS enregistrées dans le jeu (CreatureForge ne lit que Creatures/).
	La variante choisie remplacera Creatures/NeantCouronne.luau.

	    local Variantes = require(ReplicatedStorage.CreatureForge.Concepts.NeantCouronneVariantes)
	    local model = Variantes[3].build({ cframe = CFrame.new(0, 0, -20), parent = workspace })
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

type Rig = Kit.Rig

local BASE: { [string]: any } = {
	core = S(rgb(10, 4, 18)),
	void = { S(rgb(70, 36, 110)), S(rgb(48, 22, 80)), S(rgb(28, 12, 50)), S(rgb(14, 6, 26)) },
	obsidian = { S(rgb(74, 62, 88), M.Slate), S(rgb(56, 46, 70), M.Slate), S(rgb(40, 32, 54), M.Slate), S(rgb(28, 22, 40), M.Slate) },
	bloodDark = S(rgb(120, 10, 34)),
	blood = S(rgb(230, 24, 50), M.Neon),
	bloodGlass = S(rgb(120, 10, 40), M.Glass, { transparency = 0.3 }),
	eye = S(rgb(255, 40, 60), M.Neon),
	socket = S(rgb(30, 0, 8)),
	face = S(rgb(4, 2, 8)),
	pale = S(rgb(206, 200, 216)),
	bone = S(rgb(232, 224, 206)),
	gold = S(rgb(255, 200, 56)),
	goldDark = S(rgb(200, 126, 20)),
	gem = S(rgb(255, 30, 60), M.Neon),
	crystals = { S(rgb(170, 80, 255), M.Neon), S(rgb(110, 40, 200), M.Glass, { transparency = 0.15 }), S(rgb(220, 160, 255), M.Neon) },
	fragment = S(rgb(255, 40, 70), M.Neon),
	rune = S(rgb(255, 30, 60), M.Neon, { transparency = 0.2 }),
	glassViolet = { S(rgb(190, 120, 255), M.Glass, { transparency = 0.35 }), S(rgb(150, 80, 240), M.Glass, { transparency = 0.35 }), S(rgb(110, 50, 210), M.Glass, { transparency = 0.3 }) },
	flameOut = S(rgb(60, 14, 110), M.Neon),
	flameMid = S(rgb(200, 20, 60), M.Neon),
	flameCore = S(rgb(255, 160, 170), M.Neon),
	white = S(rgb(255, 255, 255), M.Neon),
	belly = { S(rgb(170, 20, 46)), S(rgb(120, 10, 32)) },
	membrane = S(rgb(90, 10, 34), M.Glass, { transparency = 0.25 }),
	armor = { S(rgb(40, 34, 52)), S(rgb(30, 26, 40)), S(rgb(22, 18, 30)) },
	skin = S(rgb(40, 14, 30)),
	horn = S(rgb(30, 24, 34)),
	bellCore = S(rgb(80, 30, 150), M.Glass, { transparency = 0.45 }),
	heartCore = S(rgb(255, 180, 190), M.Neon),
	porcelain = S(rgb(26, 22, 34)),
	hair = { S(rgb(20, 14, 30)), S(rgb(34, 22, 50)) },
	wingRows = { { S(rgb(26, 16, 40)), S(rgb(18, 10, 30)) }, { S(rgb(50, 26, 80)), S(rgb(40, 20, 64)) }, { S(rgb(80, 40, 120)), S(rgb(64, 30, 100)) } },
	halo = S(rgb(255, 60, 90), M.Neon, { transparency = 0.3 }),
	stars = { S(rgb(255, 255, 255), M.Neon), S(rgb(214, 186, 255), M.Neon), S(rgb(180, 220, 255), M.Neon), S(rgb(255, 150, 170), M.Neon) },
	aura = { rgb(255, 40, 60), rgb(120, 0, 20) },
	mist = { rgb(60, 20, 110), rgb(8, 2, 16) },
	spark = { rgb(220, 140, 255), rgb(255, 60, 90) },
	light = rgb(255, 40, 60),
	tether = { rgb(255, 60, 80), rgb(140, 0, 30) },
	ringBeam = { rgb(200, 120, 255), rgb(110, 40, 200) },
	icon = { rgb(110, 10, 30), rgb(10, 0, 8), rgb(255, 60, 90), rgb(170, 80, 255) },
}


local G, N = M.Glass, M.Neon
local function r4(a: Color3, b: Color3, c: Color3, d: Color3, mat: Enum.Material?): { Kit.Style }
	return { S(a, mat), S(b, mat), S(c, mat), S(d, mat) }
end
local function cr(a: Color3, b: Color3, c: Color3): { Kit.Style }
	return { S(a, N), S(b, G, { transparency = 0.15 }), S(c, N) }
end

--- Un style par variante : palette, matières, couleurs des effets et de l'icône.
local THEMES: { { [string]: any } } = {
	{ -- 1. Gothique spectral : argent et cyan fantôme
		core = S(rgb(10, 12, 20)), void = r4(rgb(70, 74, 100), rgb(50, 54, 78), rgb(34, 36, 56), rgb(18, 20, 32)),
		bloodDark = S(rgb(150, 170, 210)), blood = S(rgb(120, 230, 255), N), eye = S(rgb(140, 240, 255), N), socket = S(rgb(0, 20, 30)),
		gold = S(rgb(214, 220, 232)), goldDark = S(rgb(140, 148, 166)), gem = S(rgb(90, 220, 255), N),
		crystals = cr(rgb(150, 230, 255), rgb(90, 170, 230), rgb(230, 250, 255)), fragment = S(rgb(120, 230, 255), N),
		rune = S(rgb(120, 230, 255), N, { transparency = 0.2 }), halo = S(rgb(150, 240, 255), N, { transparency = 0.3 }),
		aura = { rgb(120, 230, 255), rgb(30, 60, 120) }, mist = { rgb(60, 70, 110), rgb(8, 10, 20) }, spark = { rgb(200, 250, 255), rgb(120, 200, 255) },
		light = rgb(120, 220, 255), tether = { rgb(160, 240, 255), rgb(40, 80, 160) }, ringBeam = { rgb(180, 240, 255), rgb(80, 140, 220) },
		icon = { rgb(20, 60, 90), rgb(4, 6, 14), rgb(120, 230, 255), rgb(200, 240, 255) },
	},
	{ -- 2. Cosmique : bleu nuit galactique et or
		core = S(rgb(6, 8, 30)), obsidian = r4(rgb(54, 66, 150), rgb(38, 48, 120), rgb(26, 32, 90), rgb(14, 18, 56)),
		void = r4(rgb(60, 80, 180), rgb(40, 56, 140), rgb(26, 36, 100), rgb(14, 20, 60)),
		bloodDark = S(rgb(20, 24, 70)), blood = S(rgb(255, 180, 50), N), eye = S(rgb(255, 200, 80), N), socket = S(rgb(4, 4, 20)), face = S(rgb(2, 2, 10)),
		gem = S(rgb(80, 220, 255), N), crystals = cr(rgb(90, 200, 255), rgb(60, 110, 230), rgb(200, 240, 255)), fragment = S(rgb(255, 200, 70), N),
		rune = S(rgb(255, 200, 70), N, { transparency = 0.2 }), halo = S(rgb(255, 210, 90), N, { transparency = 0.3 }),
		stars = { S(rgb(255, 255, 255), N), S(rgb(255, 230, 150), N), S(rgb(150, 210, 255), N) },
		aura = { rgb(90, 160, 255), rgb(10, 20, 80) }, mist = { rgb(40, 50, 140), rgb(4, 6, 24) }, spark = { rgb(255, 230, 150), rgb(120, 200, 255) },
		light = rgb(110, 170, 255), tether = { rgb(255, 210, 100), rgb(60, 90, 200) }, ringBeam = { rgb(140, 200, 255), rgb(60, 100, 220) },
		icon = { rgb(20, 30, 100), rgb(2, 4, 18), rgb(255, 200, 80), rgb(120, 200, 255) },
	},
	{ -- 3. Nébuleuse : turquoise et magenta
		core = S(rgb(8, 14, 26)), void = r4(rgb(40, 150, 170), rgb(30, 110, 140), rgb(24, 70, 110), rgb(16, 36, 64)),
		belly = { S(rgb(220, 60, 170)), S(rgb(160, 30, 130)) }, membrane = S(rgb(200, 40, 170), G, { transparency = 0.3 }),
		blood = S(rgb(255, 90, 220), N), eye = S(rgb(255, 240, 120), N), gold = S(rgb(200, 255, 250)), goldDark = S(rgb(120, 200, 200)),
		obsidian = r4(rgb(40, 50, 70), rgb(30, 40, 60), rgb(24, 30, 50), rgb(20, 30, 50)), gem = S(rgb(80, 255, 230), N),
		crystals = cr(rgb(80, 255, 230), rgb(220, 60, 200), rgb(255, 160, 240)), fragment = S(rgb(255, 100, 220), N),
		rune = S(rgb(80, 255, 230), N, { transparency = 0.2 }), halo = S(rgb(80, 255, 230), N, { transparency = 0.3 }),
		aura = { rgb(80, 255, 230), rgb(150, 20, 130) }, mist = { rgb(30, 100, 130), rgb(10, 10, 30) }, spark = { rgb(255, 160, 240), rgb(120, 255, 240) },
		light = rgb(120, 255, 230), tether = { rgb(255, 120, 230), rgb(40, 160, 170) }, ringBeam = { rgb(120, 255, 230), rgb(200, 60, 200) },
		icon = { rgb(20, 90, 110), rgb(10, 4, 24), rgb(255, 100, 220), rgb(80, 255, 230) },
	},
	{ -- 4. Obsidienne et lave
		core = S(rgb(14, 10, 10)), obsidian = r4(rgb(60, 56, 60), rgb(44, 40, 44), rgb(30, 28, 32), rgb(18, 16, 20), M.Slate),
		blood = S(rgb(255, 120, 20), N), eye = S(rgb(255, 220, 80), N), gem = S(rgb(255, 140, 30), N),
		crystals = cr(rgb(255, 150, 40), rgb(255, 90, 20), rgb(255, 230, 120)), fragment = S(rgb(255, 110, 20), N),
		rune = S(rgb(255, 120, 30), N, { transparency = 0.2 }), halo = S(rgb(255, 140, 40), N, { transparency = 0.3 }),
		stars = { S(rgb(255, 230, 150), N), S(rgb(255, 160, 60), N), S(rgb(255, 255, 220), N) },
		aura = { rgb(255, 120, 30), rgb(120, 20, 0) }, mist = { rgb(70, 40, 30), rgb(10, 6, 4) }, spark = { rgb(255, 200, 80), rgb(255, 90, 20) },
		light = rgb(255, 130, 40), tether = { rgb(255, 170, 60), rgb(200, 40, 0) }, ringBeam = { rgb(255, 160, 60), rgb(160, 40, 10) },
		icon = { rgb(110, 40, 10), rgb(12, 6, 4), rgb(255, 140, 40), rgb(255, 200, 80) },
	},
	{ -- 5. Royal noir et or
		core = S(rgb(12, 10, 16)), void = r4(rgb(40, 36, 50), rgb(30, 27, 38), rgb(22, 20, 28), rgb(14, 12, 18)),
		bloodDark = S(rgb(200, 150, 40)), armor = { S(rgb(30, 28, 36)), S(rgb(22, 20, 28)), S(rgb(16, 14, 20)) },
		skin = S(rgb(24, 20, 28)), horn = S(rgb(26, 22, 30)), blood = S(rgb(255, 200, 60), N), eye = S(rgb(255, 220, 90), N),
		gem = S(rgb(180, 70, 255), N), crystals = cr(rgb(190, 90, 255), rgb(120, 40, 210), rgb(240, 190, 255)), fragment = S(rgb(255, 200, 60), N),
		rune = S(rgb(255, 200, 60), N, { transparency = 0.2 }), halo = S(rgb(255, 210, 90), N, { transparency = 0.3 }),
		stars = { S(rgb(255, 230, 150), N), S(rgb(255, 255, 255), N), S(rgb(220, 170, 255), N) },
		aura = { rgb(255, 200, 70), rgb(80, 40, 0) }, mist = { rgb(40, 34, 40), rgb(6, 4, 8) }, spark = { rgb(255, 230, 140), rgb(200, 120, 255) },
		light = rgb(255, 200, 90), tether = { rgb(255, 210, 90), rgb(140, 60, 220) }, ringBeam = { rgb(210, 140, 255), rgb(120, 50, 200) },
		icon = { rgb(60, 40, 10), rgb(6, 4, 8), rgb(255, 200, 70), rgb(200, 120, 255) },
	},
	{ -- 6. Bioluminescent : verre cyan et rose
		core = S(rgb(10, 20, 40)), glassViolet = { S(rgb(140, 250, 255), G, { transparency = 0.35 }), S(rgb(90, 210, 240), G, { transparency = 0.35 }), S(rgb(60, 160, 220), G, { transparency = 0.3 }) },
		bellCore = S(rgb(40, 120, 180), G, { transparency = 0.45 }), blood = S(rgb(255, 100, 210), N), heartCore = S(rgb(255, 220, 250), N),
		eye = S(rgb(180, 255, 255), N), gold = S(rgb(236, 240, 255)), goldDark = S(rgb(180, 190, 220)), bloodDark = S(rgb(120, 40, 140)),
		void = r4(rgb(200, 90, 200), rgb(160, 60, 170), rgb(120, 40, 140), rgb(80, 24, 100)), gem = S(rgb(255, 120, 220), N),
		crystals = cr(rgb(120, 255, 250), rgb(255, 120, 220), rgb(220, 255, 255)), fragment = S(rgb(255, 130, 220), N),
		rune = S(rgb(120, 255, 250), N, { transparency = 0.2 }), halo = S(rgb(140, 255, 250), N, { transparency = 0.3 }),
		aura = { rgb(120, 255, 250), rgb(20, 60, 120) }, mist = { rgb(40, 120, 170), rgb(4, 14, 30) }, spark = { rgb(220, 255, 255), rgb(255, 140, 230) },
		light = rgb(120, 240, 255), tether = { rgb(255, 140, 230), rgb(40, 140, 200) }, ringBeam = { rgb(140, 255, 250), rgb(60, 140, 220) },
		icon = { rgb(10, 80, 110), rgb(2, 10, 24), rgb(120, 255, 250), rgb(255, 140, 230) },
	},
	{ -- 7. Flammes spectrales bleues
		core = S(rgb(8, 10, 16)), void = r4(rgb(54, 60, 84), rgb(38, 42, 62), rgb(26, 28, 44), rgb(14, 16, 26)),
		bloodDark = S(rgb(40, 110, 220)), flameOut = S(rgb(20, 50, 200), N), flameMid = S(rgb(60, 170, 255), N), flameCore = S(rgb(220, 250, 255), N),
		blood = S(rgb(90, 200, 255), N), eye = S(rgb(160, 240, 255), N), gold = S(rgb(214, 222, 236)), goldDark = S(rgb(140, 150, 170)),
		gem = S(rgb(80, 200, 255), N), crystals = cr(rgb(90, 190, 255), rgb(40, 90, 220), rgb(210, 240, 255)), fragment = S(rgb(120, 220, 255), N),
		rune = S(rgb(90, 200, 255), N, { transparency = 0.2 }), halo = S(rgb(90, 200, 255), N, { transparency = 0.3 }),
		aura = { rgb(80, 180, 255), rgb(10, 30, 100) }, mist = { rgb(30, 40, 80), rgb(4, 6, 14) }, spark = { rgb(210, 245, 255), rgb(80, 160, 255) },
		light = rgb(90, 180, 255), tether = { rgb(150, 230, 255), rgb(30, 80, 200) }, ringBeam = { rgb(140, 210, 255), rgb(40, 100, 220) },
		icon = { rgb(20, 50, 110), rgb(2, 4, 12), rgb(90, 200, 255), rgb(200, 240, 255) },
	},
	{ -- 8. Théâtre : porcelaine blanche, noir et rouge
		porcelain = S(rgb(240, 236, 228)), core = S(rgb(8, 6, 10)), void = r4(rgb(30, 26, 34), rgb(22, 18, 26), rgb(14, 12, 18), rgb(8, 6, 10)),
		bloodDark = S(rgb(170, 10, 30)), blood = S(rgb(255, 30, 50), N), eye = S(rgb(255, 40, 60), N), pale = S(rgb(240, 236, 228)),
		gem = S(rgb(255, 30, 60), N), crystals = cr(rgb(255, 255, 255), rgb(200, 20, 40), rgb(255, 120, 130)), fragment = S(rgb(255, 40, 60), N),
		rune = S(rgb(255, 40, 60), N, { transparency = 0.2 }), halo = S(rgb(255, 255, 255), N, { transparency = 0.3 }),
		stars = { S(rgb(255, 255, 255), N), S(rgb(255, 80, 100), N) },
		aura = { rgb(255, 40, 60), rgb(60, 0, 10) }, mist = { rgb(30, 26, 34), rgb(4, 2, 6) }, spark = { rgb(255, 255, 255), rgb(255, 60, 80) },
		light = rgb(255, 60, 80), tether = { rgb(255, 255, 255), rgb(200, 20, 40) }, ringBeam = { rgb(255, 255, 255), rgb(160, 160, 170) },
		icon = { rgb(90, 8, 20), rgb(6, 4, 8), rgb(255, 255, 255), rgb(255, 40, 60) },
	},
	{ -- 9. Éclipse solaire : soleil noir, couronne d'or et de feu
		obsidian = r4(rgb(40, 36, 40), rgb(30, 26, 30), rgb(20, 18, 22), rgb(12, 10, 14), M.Slate), blood = S(rgb(255, 170, 30), N),
		eye = S(rgb(255, 250, 200), N), flameOut = S(rgb(255, 120, 20), N), flameMid = S(rgb(255, 190, 40), N), flameCore = S(rgb(255, 250, 210), N),
		gem = S(rgb(255, 120, 30), N), crystals = cr(rgb(255, 200, 60), rgb(255, 140, 30), rgb(255, 240, 170)), fragment = S(rgb(255, 220, 90), N),
		rune = S(rgb(255, 190, 50), N, { transparency = 0.2 }), halo = S(rgb(255, 200, 60), N, { transparency = 0.3 }),
		stars = { S(rgb(255, 240, 180), N), S(rgb(255, 180, 60), N) },
		aura = { rgb(255, 190, 50), rgb(140, 50, 0) }, mist = { rgb(80, 50, 20), rgb(10, 6, 2) }, spark = { rgb(255, 240, 180), rgb(255, 150, 40) },
		light = rgb(255, 180, 60), tether = { rgb(255, 230, 120), rgb(255, 110, 20) }, ringBeam = { rgb(255, 210, 90), rgb(220, 110, 20) },
		icon = { rgb(120, 60, 0), rgb(10, 6, 2), rgb(255, 200, 60), rgb(255, 240, 170) },
	},
	{ -- 10. Céleste déchu : ivoire, or, plumes qui noircissent
		core = S(rgb(230, 226, 236)), void = r4(rgb(250, 248, 255), rgb(226, 222, 236), rgb(196, 192, 212), rgb(160, 156, 180)),
		bloodDark = S(rgb(30, 24, 40)), hair = { S(rgb(240, 232, 210)), S(rgb(220, 210, 180)) }, pale = S(rgb(250, 236, 228)),
		wingRows = { { S(rgb(255, 255, 255)), S(rgb(240, 240, 248)) }, { S(rgb(200, 196, 214)), S(rgb(170, 166, 190)) }, { S(rgb(70, 60, 90)), S(rgb(40, 34, 56)) } },
		blood = S(rgb(255, 200, 70), N), eye = S(rgb(255, 220, 120), N), gem = S(rgb(120, 200, 255), N),
		crystals = cr(rgb(255, 255, 255), rgb(200, 220, 255), rgb(255, 220, 120)), fragment = S(rgb(255, 220, 110), N),
		rune = S(rgb(255, 220, 110), N, { transparency = 0.2 }), halo = S(rgb(255, 230, 140), N, { transparency = 0.3 }),
		stars = { S(rgb(255, 210, 90), N), S(rgb(255, 240, 170), N) },
		aura = { rgb(255, 240, 190), rgb(120, 100, 60) }, mist = { rgb(200, 196, 220), rgb(60, 50, 80) }, spark = { rgb(255, 255, 255), rgb(255, 220, 120) },
		light = rgb(255, 230, 160), tether = { rgb(255, 240, 180), rgb(200, 170, 90) }, ringBeam = { rgb(255, 255, 255), rgb(200, 210, 255) },
		icon = { rgb(150, 140, 170), rgb(30, 26, 44), rgb(255, 230, 140), rgb(255, 255, 255) },
	},
}

local P: { [string]: any } = table.clone(BASE)

--- Active le style de la variante `n` (les constructions sont synchrones).
local function theme(n: number)
	table.clear(P)
	for k, v in BASE do
		P[k] = v
	end
	for k, v in THEMES[n] do
		P[k] = v
	end
end

-- ---------------------------------------------------------------------------
-- Éléments communs
-- ---------------------------------------------------------------------------

--- Couronne posée sur `base` (+Y = haut) : "Spikes", "Gothic", "Horned", "Crystal".
local function crown(rig: Rig, bone: string, base: CFrame, r: number, style: string)
	local k = r / 0.5
	rig:ring(bone, "Crown", base * ang(math.pi / 2, 0, 0), r, 0.1 * k, 0.18 * k, 16, P.gold)
	rig:ring(bone, "Crown", base * cf(0, 0.1 * k, 0) * ang(math.pi / 2, 0, 0), r * 1.03, 0.05 * k, 0.05 * k, 16, P.goldDark)
	local n = if style == "Gothic" then 9 elseif style == "Horned" then 5 else 7
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local at = base * ang(0, a, 0) * cf(0, 0.12 * k, -r)
		if style == "Horned" then
			local p0 = at.Position
			local out = (at.Position - base.Position).Unit
			A.horn(rig, bone, { p0, p0 + out * 0.25 * k + v3(0, 0.35 * k, 0), p0 + out * 0.2 * k + v3(0, 0.75 * k, 0) }, 0.07 * k, 0.02 * k, P.gold)
		elseif style == "Crystal" then
			rig:shard(bone, "CrownCrystal", at * ang(rad(-10), 0, 0), 0.12 * k, (if i % 2 == 0 then 0.5 else 0.32) * k, 0.16 * k, P.crystals[(i % 3) + 1])
		else
			local h = (if style == "Gothic" then (if i % 2 == 0 then 0.95 else 0.55) else (if i % 2 == 0 then 0.62 else 0.4)) * k
			local w = (if style == "Gothic" then 0.11 else 0.16) * k
			rig:thorn(bone, "CrownSpike", at * ang(rad(-8), 0, 0), w, h, P.gold)
			if i % 2 == 0 then
				rig:ball(bone, "CrownOrb", (at * ang(rad(-8), 0, 0) * cf(0, h * 0.98, 0)).Position, 0.08 * k, P.gem)
			end
		end
		rig:shard(bone, "CrownGem", at * cf(0, -0.02 * k, -0.06 * k) * ang(rad(-80), 0, 0), 0.08 * k, 0.05 * k, 0.05 * k, P.gem)
	end
end

local crownPos: Vector3? = nil
local auraRarity: string? = nil -- aura de rareté (posée par Creatures/NeantCouronne : "Chaotic")

--- Couronne qui FLOTTE au-dessus de la tête (os "Float9" : lévite et pivote dans l'animateur).
local function floatingCrown(rig: Rig, parent: string, base: CFrame, r: number, style: string)
	local at = base * cf(0, math.max(0.35, r * 0.9), 0)
	rig:bone("Float9", parent, at)
	crown(rig, "Float9", at, r, style)
	rig:ring("Float9", "CrownHalo", at * cf(0, -0.1, 0) * ang(math.pi / 2, 0, 0), r * 1.2, 0.035, 0.02, 20, P.halo)
	crownPos = (at * cf(0, r * 0.9, 0)).Position
end


--- Corps de vide constellé d'étoiles : points et étoiles à 4 branches posés sur un tube.
local function stars(rig: Rig, boneFn: (number) -> string, spine: Kit.Spine, count: number, lift: number, seed: number, size: number?)
	local rng = Random.new(seed)
	local n = #spine.sections
	local k = size or 1
	for i = 1, count do
		local u = rng:NextNumber(1.15, n - 0.15)
		local c = spine:surface(u, rng:NextNumber(-180, 180), lift)
		local sz = rng:NextNumber(0.05, 0.1) * k
		local st = P.stars[rng:NextInteger(1, #P.stars)]
		if i % 3 == 0 then
			local r = c * ang(0, rng:NextNumber(0, math.pi), 0)
			rig:block(boneFn(u), "Star", r, v3(sz * 0.6, sz * 4, sz * 0.6), st)
			rig:block(boneFn(u), "Star", r, v3(sz * 4, sz * 0.6, sz * 0.6), st)
		else
			rig:ball(boneFn(u), "Star", c.Position, sz * 1.8, st)
		end
	end
end

--- Main griffue squelettique tournée vers `fwd`.
local function clawHand(rig: Rig, bone: string, palm: Vector3, fwd: Vector3, size: number, style: Kit.Style, tip: Kit.Style)
	local f = fwd.Unit
	local right = f:Cross(Vector3.yAxis).Unit
	local base = CFrame.fromMatrix(palm, right, right:Cross(-f).Unit * -1, -f)
	rig:prism(bone, "Palm", base, v3(0.5, 0.16, 0.45) * size, 0.06 * size, style)
	for i = 1, 4 do
		local x = (i - 2.5) * 0.13 * size
		local k1 = (base * cf(x, 0, -0.22 * size)).Position
		local k2 = (base * cf(x * 1.2, -0.12 * size, -0.52 * size)).Position
		local k3 = (base * cf(x * 1.3, -0.36 * size, -0.7 * size)).Position
		rig:strut(bone, "Finger", k1, k2, 0.08 * size, 0.08 * size, style)
		rig:strut(bone, "Finger", k2, k3, 0.065 * size, 0.065 * size, style)
		rig:thorn(bone, "Claw", A.alongUp(k3, k3 - k2), 0.08 * size, 0.26 * size, tip)
	end
end

--- Tentacule : chaîne d'os "SwayN" (ondulent dans l'animateur) + tube effilé.
local function tentacle(rig: Rig, parent: string, id: number, pts: { Vector3 }, r0: number, r1: number, core: Kit.Style, cover: Kit.Cover?, tip: Kit.Style?): { string }
	local names = {}
	for i = 1, #pts - 1 do
		local name = "Sway" .. (id * 10 + i)
		rig:bone(name, if i == 1 then parent else names[i - 1], cf(pts[i]))
		names[i] = name
	end
	local secs = {}
	for i, p in pts do
		local t = (i - 1) / (#pts - 1)
		local r = r0 + (r1 - r0) * t
		table.insert(secs, { pos = p, rx = r, ry = r })
	end
	rig:tube(Kit.spine(secs), {
		name = "Tentacle",
		bone = function(u)
			return names[math.clamp(math.floor(u), 1, #names)]
		end,
		core = core,
		coreStep = 0.22,
		cover = if cover then { cover } else nil,
	})
	if tip then
		local a, b = pts[#pts - 1], pts[#pts]
		rig:thorn(names[#names], "TentacleTip", A.alongUp(b, b - a), r1 * 3, r1 * 6, tip)
	end
	return names
end

type NexusOpts = {
	center: Vector3,
	radius: number,
	crystals: number?,
	fragments: number?,
	tetherBone: string,
	tetherPos: Vector3,
	auraSize: Vector3,
	ability: Types.Ability,
	ground: number?,
}

--- Identité commune : orbites (cristaux + fragments), cercle runique, aura rouge sang.
local function nexus(rig: Rig, o: NexusOpts)
	local nc, nf = o.crystals or 8, o.fragments or 10
	local tetherBone, tetherPos = o.tetherBone, o.tetherPos
	if crownPos then
		tetherBone, tetherPos = "Float9", crownPos :: Vector3
		crownPos = nil
	end
	A.orbit(rig, "Aura1", o.center, o.radius, nc, 0.6, function(bone, c, i)
		rig:shard(bone, "OrbitCrystal", c * ang(0, 0, rad(20)), 0.3, 0.8, 0.34, P.crystals[(i % 3) + 1])
	end)
	local fc = o.center + v3(0, 0.5, 0)
	A.orbit(rig, "Aura2", fc, o.radius * 0.7, nf, 0.5, function(bone, c, i)
		rig:shard(bone, "Fragment", c * ang(rad(30 * i), 0, rad(45)), 0.12, 0.22, 0.12, P.fragment)
	end)
	local gr = o.ground or 2.6
	A.flatRing(rig, "Root", v3(0, 0.04, 0), gr, 0.1, 0.03, 32, P.rune)
	A.flatRing(rig, "Root", v3(0, 0.04, 0), gr * 0.77, 0.06, 0.03, 28, P.rune)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		A.rune(rig, "Root", cf(math.sin(a) * gr * 0.88, 0.05, -math.cos(a) * gr * 0.88) * ang(-math.pi / 2, 0, 0) * ang(0, 0, a), 0.32, P.rune, i)
	end
	if rig.effects then
		local sc = rig.scale
		local aura = rig:anchor("Body", "FX_Aura", cf(o.center), o.auraSize)
		Fx.particles(aura, Fx.mist("BloodAura", P.aura, 16, 2.2, 0.6), sc)
		Fx.particles(aura, Fx.mist("VoidMist", P.mist, 10, 1.8, 0.1), sc)
		Fx.particles(aura, Fx.sparkles("VoidSparks", P.spark, 10, 0.24), sc)
		Fx.light(aura, { color = P.light, range = 18, brightness = 2 }, sc)
		Fx.particles(aura, Fx.sparkles("StarDust", { rgb(255, 255, 255), P.spark[1] }, 14, 0.18), sc)
		Vfx.orbitTethers(rig, "Aura2", Vfx.orbitPoints(fc, o.radius * 0.7, nf, 0.5), tetherBone, tetherPos, {
			colors = P.tether,
			transparency = { 0.25, 0.85 },
			width0 = 0.05,
			width1 = 0.015,
			curve0 = 0.8,
		})
		Vfx.orbitRing(rig, "Aura1", Vfx.orbitPoints(o.center, o.radius, nc, 0.6), {
			colors = P.ringBeam,
			transparency = { 0.35, 0.7 },
			width0 = 0.07,
			curve0 = 0.7,
			curve1 = -0.7,
		})
		Vfx.abilityOrigin(rig, o.ability)
		if auraRarity then
			Vfx.rarityAura(rig, auraRarity)
		end
	end
end

local function ab(n: number, name: string, kind: string, extra: { [string]: any }?): Types.Ability
	local t = THEMES[n]
	local a: { [string]: any } = { name = name, kind = kind, colors = { t.light or BASE.light, (t.aura or BASE.aura)[2], (t.spark or BASE.spark)[1] }, texture = "smoke", radius = 8, duration = 2 }
	if extra then
		for k, v in extra do
			a[k] = v
		end
	end
	return a :: any
end

local function constFn(name: string): (number) -> string
	return function()
		return name
	end
end

-- ---------------------------------------------------------------------------
-- 1. Le Roi Spectral
-- ---------------------------------------------------------------------------
local AB1 = ab(1, "Lamentation spectrale", "Nova")
local function build1(opts: Kit.BuildOptions?): Model
	theme(1)
	local rig = Kit.newRig("NeantV01", opts)
	rig:bone("Body", "Root", cf(0, 3.6, 0.1))
	rig:bone("Head", "Body", cf(0, 4.7, 0))
	rig:mirrored(function(side, sfx)
		rig:bone("Arm" .. sfx, "Body", cf(side * 0.7, 4.35, 0))
	end)
	local robe = Kit.spine({
		{ pos = v3(0, 4.55, 0.1), rx = 0.62, ry = 0.5 },
		{ pos = v3(0, 3.9, 0.15), rx = 0.85, ry = 0.65 },
		{ pos = v3(0, 3.1, 0.25), rx = 0.82, ry = 0.62 },
		{ pos = v3(0, 2.3, 0.4), rx = 0.62, ry = 0.5 },
		{ pos = v3(0, 1.6, 0.6), rx = 0.36, ry = 0.32 },
		{ pos = v3(0, 1.1, 0.85), rx = 0.07, ry = 0.07 },
	})
	rig:tube(robe, { name = "Robe", bone = constFn("Body"), core = P.core, coreStep = 0.3, cover = { A.fur(P.void, P.bloodDark, v3(0.32, 0.65, 0.5), 0.26, { arc = 180, tilt = 25, refRadius = 0.6, seed = 1 }) } })
	stars(rig, constFn("Body"), robe, 42, 0.42, 11)
	A.tuftBurst(rig, "Body", cf(0, 1.25, 0.7) * ang(math.pi, 0, 0), 12, 0.9, 0.22, P.void, P.bloodDark, 35, 2)
	rig:ring("Body", "Brooch", cf(0, 4.05, -0.63), 0.16, 0.05, 0.05, 10, P.gold)
	rig:ball("Body", "BroochGem", v3(0, 4.05, -0.66), 0.16, P.gem)
	local hood = Kit.spine({
		{ pos = v3(0, 5.3, -0.62), rx = 0.42, ry = 0.47 },
		{ pos = v3(0, 5.38, -0.25), rx = 0.56, ry = 0.6 },
		{ pos = v3(0, 5.25, 0.15), rx = 0.52, ry = 0.56 },
		{ pos = v3(0, 4.9, 0.45), rx = 0.36, ry = 0.4 },
	})
	rig:tube(hood, { name = "Hood", bone = constFn("Head"), core = P.core, coreStep = 0.2, cover = { A.fur(P.void, nil, v3(0.22, 0.4, 0.34), 0.2, { arc = 180, tilt = 35, refRadius = 0.45, seed = 3 }) } })
	stars(rig, constFn("Head"), hood, 12, 0.3, 12, 0.8)
	rig:ball("Head", "Face", v3(0, 5.2, -0.58), 0.66, P.face)
	rig:ring("Head", "HoodTrim", cf(0, 5.28, -0.66), 0.42, 0.06, 0.06, 16, P.gold)
	rig:mirrored(function(side)
		A.eye(rig, "Head", A.mx(v3(0.14, 5.26, -0.86), side), v3(side * 0.3, 0, -1), 0.11, "Glow", P.socket, P.eye)
	end)
	rig:prism("Head", "Jaw", cf(0, 4.98, -0.78), v3(0.3, 0.09, 0.18), 0.03, P.bone)
	A.teeth(rig, "Head", v3(-0.1, 5.03, -0.86), v3(0.1, 5.03, -0.86), 5, 0.035, 0.06, P.bone, false)
	floatingCrown(rig, "Head", cf(0, 5.88, -0.2), 0.48, "Gothic")
	rig:mirrored(function(side, sfx)
		local arm = "Arm" .. sfx
		A.limb(rig, arm, side, { { v3(0.7, 4.35, 0), 0.2, 0.2 }, { v3(1.35, 3.75, -0.35), 0.15, 0.15 }, { v3(1.65, 3.05, -0.75), 0.11, 0.11 } }, P.core, A.fur(P.void, nil, v3(0.18, 0.32, 0.26), 0.15, { arc = 180, refRadius = 0.2, seed = 10 + side }))
		A.tuftBurst(rig, arm, cf(A.mx(v3(1.62, 3.25, -0.7), side)) * ang(math.pi, 0, 0), 8, 0.55, 0.2, P.void, P.bloodDark, 40, 20 + side)
		clawHand(rig, arm, A.mx(v3(1.72, 2.95, -0.85), side), v3(side * 0.3, -0.6, -1), 0.8, P.bone, P.blood)
		A.crystals(rig, "Body", cf(A.mx(v3(0.62, 4.6, 0.05), side)) * ang(rad(-10), 0, -side * rad(35)), 5, 0.9, P.crystals, 5 + side, 0.4)
	end)
	nexus(rig, { center = v3(0, 3.4, 0.1), radius = 3.0, tetherBone = "Head", tetherPos = v3(0, 6.3, -0.2), auraSize = v3(2.2, 3.4, 1.6), ability = AB1 })
	return rig:finish({ Rarity = "Chaotic" })
end

-- ---------------------------------------------------------------------------
-- 2. L'Œil du Néant
-- ---------------------------------------------------------------------------
local AB2 = ab(2, "Regard du néant", "Breath", { bone = "Head", origin = v3(0, 3.2, -1.4), direction = v3(0, 0, -1), texture = "sparkle" })
local function build2(opts: Kit.BuildOptions?): Model
	theme(2)
	local rig = Kit.newRig("NeantV02", opts)
	rig:bone("Body", "Root", cf(0, 3.2, 0))
	rig:bone("Head", "Body", cf(0, 3.2, 0))
	local orb = Kit.spine({
		{ pos = v3(0, 3.2, -1.32), rx = 0.3, ry = 0.3 },
		{ pos = v3(0, 3.2, -1.05), rx = 1.0, ry = 1.0 },
		{ pos = v3(0, 3.2, -0.3), rx = 1.38, ry = 1.38 },
		{ pos = v3(0, 3.2, 0.5), rx = 1.25, ry = 1.25 },
		{ pos = v3(0, 3.2, 1.05), rx = 0.65, ry = 0.65 },
		{ pos = v3(0, 3.2, 1.3), rx = 0.1, ry = 0.1 },
	})
	rig:tube(orb, { name = "Orb", bone = constFn("Head"), core = P.bloodDark, coreStep = 0.3, cover = { A.scales(P.obsidian, v3(0.5, 0.16, 0.5), 0.42, { arc = 180, from = 2.1, tilt = 10, refRadius = 1.0, seed = 1 }) } })
	stars(rig, constFn("Head"), orb, 36, 0.2, 21, 1.2)
	-- Œil
	local function disc(z: number, d: number, th: number, style: Kit.Style)
		rig:cylinder("Head", "Eye", v3(0, 3.2, z + th / 2), v3(0, 3.2, z - th / 2), d, style)
	end
	disc(-1.2, 1.95, 0.08, P.bloodDark)
	disc(-1.26, 1.3, 0.06, P.blood)
	rig:ring("Head", "Iris", cf(0, 3.2, -1.3), 0.48, 0.07, 0.04, 16, P.socket)
	rig:block("Head", "Pupil", cf(0, 3.2, -1.31), v3(0.2, 1.0, 0.05), P.face)
	rig:ball("Head", "Glint", v3(0.28, 3.5, -1.3), 0.12, P.white)
	for k = -1, 1, 2 do
		rig:prism("Head", "Lid", cf(0, 3.2 + k * 0.78, -0.98) * ang(rad(-35 * k), 0, 0), v3(2.1, 0.26, 0.72), 0.1, P.obsidian[3])
		rig:strut("Head", "LidTrim", v3(-0.95, 3.2 + k * 0.66, -1.28), v3(0.95, 3.2 + k * 0.66, -1.28), 0.06, 0.06, P.gold)
	end
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local base = cf(0, 3.2, -1.05) * ang(0, 0, a) * cf(0, 1.05, 0)
		rig:thorn("Head", "RimSpike", base, 0.16, if i % 2 == 0 then 0.6 else 0.38, if i % 2 == 0 then P.gold else P.obsidian[4])
	end
	floatingCrown(rig, "Head", cf(0, 4.5, 0), 0.62, "Spikes")
	-- Tentacules
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2 + 0.3
		local d = v3(math.cos(a), 0, math.sin(a))
		local b0 = v3(0, 2.15, 0.15) + d * 0.75
		tentacle(rig, "Body", k, { b0, b0 + d * 0.3 + v3(0, -0.55, 0), b0 + d * 0.55 + v3(0, -1.1, 0), b0 + d * 0.5 + v3(0, -1.6, 0), b0 + d * 0.3 + v3(0, -1.95, 0) }, 0.2, 0.04, P.void[2], A.scales(P.void, v3(0.16, 0.05, 0.16), 0.13, { arc = 180, refRadius = 0.18, seed = 30 + k }), P.blood)
	end
	nexus(rig, { center = v3(0, 3.2, 0), radius = 3.2, tetherBone = "Head", tetherPos = v3(0, 5.2, 0), auraSize = v3(2.8, 2.8, 2.8), ability = AB2 })
	return rig:finish({ Rarity = "Chaotic" })
end

-- ---------------------------------------------------------------------------
-- 3. Le Dragon du Néant
-- ---------------------------------------------------------------------------
local AB3 = ab(3, "Souffle nébuleux", "Breath", { bone = "Head", origin = v3(0, 4.3, -2.35), direction = v3(0, -0.15, -1) })
local DRAGON = Kit.spine({
	{ pos = v3(0, 4.3, -1.35), rx = 0.32, ry = 0.3 },
	{ pos = v3(0, 3.75, -0.75), rx = 0.46, ry = 0.42 },
	{ pos = v3(0, 3.2, 0.05), rx = 0.55, ry = 0.5 },
	{ pos = v3(0.25, 2.95, 0.85), rx = 0.5, ry = 0.45 },
	{ pos = v3(0.75, 3.1, 1.55), rx = 0.4, ry = 0.36 },
	{ pos = v3(1.0, 3.55, 2.15), rx = 0.3, ry = 0.27 },
	{ pos = v3(0.75, 4.05, 2.65), rx = 0.2, ry = 0.18 },
	{ pos = v3(0.3, 4.3, 2.95), rx = 0.1, ry = 0.09 },
	{ pos = v3(-0.1, 4.35, 3.1), rx = 0.02, ry = 0.02 },
})
local function build3(opts: Kit.BuildOptions?): Model
	theme(3)
	local rig = Kit.newRig("NeantV03", opts)
	rig:bone("Body", "Root", cf(0, 3.2, 0.2))
	rig:bone("Head", "Body", cf(0, 4.35, -1.4))
	rig:bone("Jaw", "Head", cf(0, 4.25, -1.6))
	rig:mirrored(function(side, sfx)
		rig:bone("Wing" .. sfx, "Body", cf(side * 0.4, 3.75, -0.5))
		rig:bone("Arm" .. sfx, "Body", cf(side * 0.42, 3.3, -0.85))
	end)
	local tj = {}
	for i = 5, #DRAGON.sections do
		table.insert(tj, DRAGON:pos(i))
	end
	local tail = rig:boneChain("Tail", "Body", tj)
	local function boneAt(u: number): string
		if u < 5 then
			return "Body"
		end
		return tail[math.clamp(math.floor(u - 4), 1, #tail)]
	end
	rig:tube(DRAGON, {
		name = "Body",
		bone = boneAt,
		core = P.core,
		coreStep = 0.25,
		cover = {
			A.scales(P.void, v3(0.26, 0.1, 0.3), 0.22, { arc = 120, tilt = 22, refRadius = 0.45, seed = 1 }),
			A.scales(P.belly, v3(0.3, 0.06, 0.22), 0.22, { arc = 55, center = 180, tilt = 8, refRadius = 0.45, jitter = 0.1, seed = 2 }),
		},
	})
	stars(rig, boneAt, DRAGON, 40, 0.14, 31)
	A.crest(rig, DRAGON, boneAt, 1.2, 8.5, 0.22, 0.5, 0.24, P.void[4], P.blood, 0, 34)
	-- Tête
	local head = Kit.spine({
		{ pos = v3(0, 4.35, -2.28), rx = 0.14, ry = 0.1 },
		{ pos = v3(0, 4.42, -2.0), rx = 0.26, ry = 0.18 },
		{ pos = v3(0, 4.5, -1.7), rx = 0.36, ry = 0.26 },
		{ pos = v3(0, 4.45, -1.4), rx = 0.34, ry = 0.3 },
	})
	rig:tube(head, { name = "Head", bone = constFn("Head"), core = P.core, coreStep = 0.18, cover = { A.scales(P.void, v3(0.16, 0.06, 0.18), 0.12, { arc = 130, refRadius = 0.3, seed = 3 }) } })
	rig:prismBetween("Jaw", "Jaw", v3(0, 4.22, -1.6), v3(0, 4.15, -2.2), 0.4, 0.1, 0.04, P.void[3])
	rig:mirrored(function(side)
		A.teeth(rig, "Head", A.mx(v3(0.08, 4.28, -2.22), side), A.mx(v3(0.24, 4.3, -1.7), side), 5, 0.04, 0.09, P.bone, true)
		A.eye(rig, "Head", A.mx(v3(0.22, 4.6, -1.85), side), v3(side, 0.3, -0.5), 0.1, "Slit", P.socket, P.eye, P.face)
		A.horn(rig, "Head", { A.mx(v3(0.18, 4.7, -1.55), side), A.mx(v3(0.35, 4.95, -1.3), side), A.mx(v3(0.45, 5.05, -0.95), side), A.mx(v3(0.38, 4.95, -0.65), side) }, 0.1, 0.025, P.obsidian[4], P.gold, { 1.6, 2.4 })
	end)
	floatingCrown(rig, "Head", cf(0, 4.78, -1.55), 0.3, "Spikes")
	-- Ailes membraneuses
	local membrane = P.membrane
	rig:mirrored(function(side, sfx)
		local w = "Wing" .. sfx
		local arm = { v3(0.4, 3.75, -0.5), v3(1.3, 4.4, -0.3), v3(2.3, 4.6, 0.2), v3(3.0, 4.3, 0.8) }
		local mp = {}
		for _, p in arm do
			table.insert(mp, A.mx(p, side))
		end
		A.limb(rig, w, side, { { arm[1], 0.14, 0.14 }, { arm[2], 0.11, 0.11 }, { arm[3], 0.08, 0.08 } }, P.void[4])
		rig:strut(w, "WingFinger", mp[3], mp[4], 0.07, 0.07, P.void[4])
		local tips = { mp[4], A.mx(v3(3.0, 3.4, 1.35), side), A.mx(v3(2.45, 2.75, 1.5), side), A.mx(v3(1.6, 2.75, 1.25), side), A.mx(v3(0.7, 3.2, 0.6), side) }
		for k = 2, #tips - 1 do
			rig:strut(w, "WingFinger", mp[3], tips[k], 0.06, 0.06, P.void[4])
			rig:thorn(w, "WingClaw", A.alongUp(tips[k], tips[k] - mp[3]), 0.06, 0.16, P.blood)
		end
		for k = 1, #tips - 1 do
			A.triangle(rig, w, "Membrane", mp[3], tips[k], tips[k + 1], 0.03, membrane)
		end
		A.triangle(rig, w, "Membrane", mp[1], mp[3], tips[#tips], 0.03, membrane)
		A.triangle(rig, w, "Membrane", mp[1], mp[2], mp[3], 0.03, membrane)
		-- Petits bras griffus
		local armB = "Arm" .. sfx
		A.limb(rig, armB, side, { { v3(0.42, 3.3, -0.85), 0.12, 0.12 }, { v3(0.62, 2.9, -1.05), 0.09, 0.09 }, { v3(0.6, 2.6, -1.3), 0.07, 0.07 } }, P.void[3])
		clawHand(rig, armB, A.mx(v3(0.6, 2.52, -1.38), side), v3(0, -0.4, -1), 0.45, P.void[4], P.blood)
	end)
	nexus(rig, { center = v3(0.3, 3.4, 0.6), radius = 3.6, tetherBone = "Head", tetherPos = v3(0, 5.1, -1.55), auraSize = v3(2.4, 2.4, 3.6), ability = AB3, ground = 3.0 })
	return rig:finish({ Rarity = "Chaotic" })
end

-- ---------------------------------------------------------------------------
-- 4. Le Colosse Couronné
-- ---------------------------------------------------------------------------
local AB4 = ab(4, "Colère du colosse", "Stomp", { texture = "spark", radius = 9 })
local function build4(opts: Kit.BuildOptions?): Model
	theme(4)
	local rig = Kit.newRig("NeantV04", opts)
	rig:bone("Body", "Root", cf(0, 3.6, 0))
	rig:bone("Head", "Body", cf(0, 5.2, -0.15))
	local torso = Kit.spine({
		{ pos = v3(0, 4.85, 0), rx = 1.45, ry = 1.0 },
		{ pos = v3(0, 4.1, 0.05), rx = 1.35, ry = 0.95 },
		{ pos = v3(0, 3.2, 0.1), rx = 0.95, ry = 0.75 },
		{ pos = v3(0, 2.4, 0.15), rx = 0.55, ry = 0.5 },
		{ pos = v3(0, 1.7, 0.2), rx = 0.22, ry = 0.22 },
	})
	rig:tube(torso, { name = "Torso", bone = constFn("Body"), core = P.blood, coreStep = 0.35, cover = { A.scales(P.obsidian, v3(0.58, 0.22, 0.5), 0.56, { arc = 180, tilt = 6, jitter = 0.5, refRadius = 0.9, seed = 1 }) } })
	stars(rig, constFn("Body"), torso, 36, 0.26, 41, 1.2)
	rig:ball("Body", "Core", v3(0, 4.35, -0.95), 0.55, P.blood)
	rig:ring("Body", "CoreRim", cf(0, 4.35, -0.98), 0.34, 0.09, 0.1, 14, P.gold)
	rig:mirrored(function(side)
		A.crystals(rig, "Body", cf(A.mx(v3(1.15, 5.0, 0), side)) * ang(0, 0, -side * rad(40)), 7, 1.4, P.crystals, 3 + side, 0.45)
		rig:prism("Body", "Pauldron", cf(A.mx(v3(1.25, 4.85, 0), side)) * ang(0, 0, -side * rad(30)), v3(1.0, 0.3, 1.1), 0.2, P.obsidian[3])
	end)
	-- Tête casquée
	rig:prism("Head", "Helm", cf(0, 5.4, -0.15), v3(0.75, 0.82, 0.75), 0.22, P.obsidian[2])
	rig:block("Head", "Visor", cf(0, 5.42, -0.53), v3(0.52, 0.07, 0.05), P.blood)
	rig:mirrored(function(side)
		rig:ball("Head", "EyeGlow", A.mx(v3(0.15, 5.42, -0.54), side), 0.1, P.eye)
	end)
	floatingCrown(rig, "Head", cf(0, 5.82, -0.15), 0.42, "Horned")
	-- Poings flottants reliés par l'énergie
	for i, side in { 1, -1 } do
		local name = "Float" .. i
		local H = A.mx(v3(2.3, 3.1, -0.6), side)
		rig:bone(name, "Root", cf(H))
		rig:prism(name, "Fist", cf(H) * ang(0, side * rad(15), 0), v3(0.85, 0.75, 0.85), 0.2, P.obsidian[2])
		rig:ring(name, "Bracer", cf(H + v3(0, 0, 0.5)) * ang(0, 0, 0), 0.42, 0.1, 0.18, 12, P.gold)
		for k = -1, 2 do
			local kp = H + v3(side * k * 0.18 - side * 0.09, 0.2, -0.45)
			rig:thorn(name, "Knuckle", A.alongUp(kp, v3(0, 0.2, -1)), 0.14, 0.32, P.blood)
		end
		rig:strut(name, "Crack", H + v3(-0.3, 0.38, -0.2), H + v3(0.25, -0.1, -0.43), 0.04, 0.04, P.blood)
		if rig.effects then
			Vfx.beam(rig, name, H + v3(0, 0, 0.45), "Body", A.mx(v3(1.3, 4.6, 0.1), side), { colors = { P.tether[1], P.ringBeam[1] }, transparency = { 0.15, 0.6 }, width0 = 0.16, width1 = 0.08, curve0 = 0.6 }, v3(0, 1, 0))
		end
	end
	-- Débris en orbite sous le buste
	A.orbit(rig, "Aura3", v3(0, 1.5, 0.1), 1.7, 6, 0.3, function(bone, c, i)
		rig:prism(bone, "Debris", c * ang(rad(20 * i), rad(40 * i), 0), v3(0.36, 0.28, 0.32), 0.1, P.obsidian[(i % 3) + 1])
		rig:prism(bone, "DebrisCrack", c * ang(rad(20 * i), rad(40 * i), 0), v3(0.38, 0.05, 0.34), 0.02, P.blood)
	end)
	nexus(rig, { center = v3(0, 3.8, 0), radius = 3.7, tetherBone = "Head", tetherPos = v3(0, 6.3, -0.15), auraSize = v3(3, 3, 2), ability = AB4, ground = 3.0 })
	return rig:finish({ Rarity = "Chaotic" })
end

-- ---------------------------------------------------------------------------
-- 5. Le Seigneur Cornu
-- ---------------------------------------------------------------------------
local AB5 = ab(5, "Décret royal", "Burst", { texture = "sparkle", radius = 7 })
local function build5(opts: Kit.BuildOptions?): Model
	theme(5)
	local rig = Kit.newRig("NeantV05", opts)
	rig:bone("Body", "Root", cf(0, 3.6, 0.1))
	rig:bone("Head", "Body", cf(0, 4.95, -0.05))
	rig:mirrored(function(side, sfx)
		rig:bone("Arm" .. sfx, "Body", cf(side * 0.85, 4.45, 0))
	end)
	local body = Kit.spine({
		{ pos = v3(0, 4.7, 0.05), rx = 0.85, ry = 0.55 },
		{ pos = v3(0, 4.0, 0.05), rx = 0.78, ry = 0.5 },
		{ pos = v3(0, 3.35, 0.1), rx = 0.62, ry = 0.45 },
		{ pos = v3(0, 2.7, 0.2), rx = 0.6, ry = 0.45 },
		{ pos = v3(0, 2.0, 0.35), rx = 0.52, ry = 0.4 },
		{ pos = v3(0, 1.3, 0.55), rx = 0.3, ry = 0.28 },
		{ pos = v3(0, 0.95, 0.75), rx = 0.05, ry = 0.05 },
	})
	rig:tube(body, {
		name = "Body",
		bone = constFn("Body"),
		core = P.core,
		coreStep = 0.3,
		cover = {
			A.scales(P.armor, v3(0.36, 0.1, 0.32), 0.28, { arc = 180, to = 3.0, tilt = 14, refRadius = 0.6, seed = 1 }),
			A.fur(P.void, P.bloodDark, v3(0.3, 0.62, 0.48), 0.25, { arc = 180, from = 3.0, tilt = 22, refRadius = 0.5, seed = 2 }),
		},
	})
	stars(rig, constFn("Body"), body, 30, 0.3, 51)
	rig:band(body, "Body", "Belt", 2.95, 0.16, 0.1, P.gold, P.goldDark)
	rig:band(body, "Body", "Gorget", 1.15, 0.12, 0.08, P.gold)
	rig:shard("Body", "ChestGem", cf(0, 4.15, -0.56) * ang(rad(-90), 0, 0), 0.22, 0.12, 0.12, P.gem)
	rig:ring("Body", "ChestRim", cf(0, 4.15, -0.55), 0.2, 0.06, 0.06, 12, P.gold)
	-- Cape
	for k = -3, 3 do
		local x = k * 0.24
		local base = cf(x, 4.7, 0.45) * ang(rad(160 - math.abs(k) * 4), rad(k * 6), 0)
		A.feather(rig, "Body", base * ang(0, math.pi / 2, 0), 3.0 - math.abs(k) * 0.18, 0.42, if k % 2 == 0 then P.void[3] else P.void[4], P.bloodDark)
	end
	-- Épaulières
	rig:mirrored(function(side)
		local sh = cf(A.mx(v3(0.85, 4.75, 0.05), side)) * ang(0, 0, -side * rad(25))
		rig:prism("Body", "Pauldron", sh, v3(0.75, 0.24, 0.8), 0.16, P.armor[2])
		rig:ring("Body", "PauldronTrim", sh * cf(0, 0.1, 0) * ang(math.pi / 2, 0, 0), 0.36, 0.05, 0.06, 12, P.gold)
		for k = -1, 1 do
			rig:thorn("Body", "PauldronSpike", sh * cf(k * 0.22, 0.12, 0), 0.12, 0.4 - math.abs(k) * 0.1, P.gold)
		end
	end)
	-- Tête cornue
	local head = Kit.spine({
		{ pos = v3(0, 5.0, -0.45), rx = 0.18, ry = 0.2 },
		{ pos = v3(0, 5.1, -0.3), rx = 0.3, ry = 0.35 },
		{ pos = v3(0, 5.15, 0), rx = 0.32, ry = 0.36 },
		{ pos = v3(0, 5.05, 0.2), rx = 0.25, ry = 0.3 },
	})
	rig:tube(head, { name = "Head", bone = constFn("Head"), core = P.skin, coreStep = 0.15 })
	rig:mirrored(function(side)
		A.eye(rig, "Head", A.mx(v3(0.13, 5.18, -0.46), side), v3(side * 0.3, 0, -1), 0.09, "Glow", P.socket, P.eye)
		A.brow(rig, "Head", side, v3(0.12, 5.28, -0.46), 0.2, 26, P.core)
		rig:thorn("Head", "Fang", cf(A.mx(v3(0.07, 4.92, -0.45), side)) * ang(math.pi, 0, 0), 0.04, 0.1, P.bone)
		local horn = {
			A.mx(v3(0.25, 5.35, -0.1), side),
			A.mx(v3(0.62, 5.62, 0.05), side),
			A.mx(v3(0.92, 5.52, 0.35), side),
			A.mx(v3(0.96, 5.12, 0.45), side),
			A.mx(v3(0.78, 4.86, 0.2), side),
			A.mx(v3(0.66, 5.0, -0.1), side),
		}
		A.horn(rig, "Head", horn, 0.17, 0.04, P.horn, P.gold, { 1.6, 2.6, 3.6 })
	end)
	floatingCrown(rig, "Head", cf(0, 5.5, -0.08), 0.3, "Spikes")
	-- Bras en armure, sceptre
	rig:mirrored(function(side, sfx)
		local arm = "Arm" .. sfx
		local sp = A.limb(rig, arm, side, { { v3(0.85, 4.45, 0), 0.24, 0.24 }, { v3(1.25, 3.7, -0.25), 0.2, 0.2 }, { v3(1.35, 3.05, -0.62), 0.16, 0.16 } }, P.armor[2])
		rig:band(sp, arm, "Gauntlet", 2.6, 0.24, 0.08, P.gold)
		clawHand(rig, arm, A.mx(v3(1.38, 2.92, -0.72), side), v3(0, -0.5, -1), 0.65, P.armor[2], P.blood)
		if side > 0 then
			local a, b = v3(1.42, 2.1, -0.85), v3(1.32, 4.7, -0.6)
			rig:cylinder(arm, "Scepter", a, b, 0.09, P.gold)
			rig:ring(arm, "ScepterRing", Kit.lookAlong(b, b - a) * ang(0, 0, 0), 0.14, 0.05, 0.06, 10, P.gold)
			A.crystals(rig, arm, A.alongUp(b, b - a), 5, 0.6, P.crystals, 8, 0.35)
			rig:ball(arm, "ScepterGem", b + (b - a).Unit * 0.05, 0.16, P.gem)
		end
	end)
	nexus(rig, { center = v3(0, 3.5, 0.1), radius = 3.1, tetherBone = "Head", tetherPos = v3(0, 6.0, -0.08), auraSize = v3(2.2, 3.4, 1.6), ability = AB5 })
	return rig:finish({ Rarity = "Chaotic" })
end

-- ---------------------------------------------------------------------------
-- 6. La Méduse Abyssale
-- ---------------------------------------------------------------------------
local AB6 = ab(6, "Pulsation abyssale", "Nova", { texture = "sparkle" })
local function build6(opts: Kit.BuildOptions?): Model
	theme(6)
	local rig = Kit.newRig("NeantV06", opts)
	rig:bone("Body", "Root", cf(0, 3.8, 0))
	local bell = Kit.spine({
		{ pos = v3(0, 4.9, 0), rx = 0.25, ry = 0.25 },
		{ pos = v3(0, 4.65, 0), rx = 1.0, ry = 1.0 },
		{ pos = v3(0, 4.2, 0), rx = 1.45, ry = 1.45 },
		{ pos = v3(0, 3.65, 0), rx = 1.55, ry = 1.55 },
		{ pos = v3(0, 3.35, 0), rx = 1.4, ry = 1.4 },
	})
	rig:tube(bell, { name = "Bell", bone = constFn("Body"), core = P.bellCore, coreStep = 0.3, cover = { A.scales(P.glassViolet, v3(0.5, 0.12, 0.42), 0.4, { arc = 180, tilt = 8, refRadius = 1.2, seed = 1 }) } })
	stars(rig, constFn("Body"), bell, 30, 0.14, 61)
	rig:ball("Body", "Heart", v3(0, 4.0, 0), 1.0, P.blood)
	rig:ball("Body", "HeartCore", v3(0, 4.05, 0), 0.55, P.heartCore)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local tip = v3(math.cos(a) * 1.2, 4.55, math.sin(a) * 1.2)
		rig:strut("Body", "Vein", v3(0, 4.2, 0), tip, 0.06, 0.06, P.blood)
	end
	rig:ring("Body", "Rim", cf(0, 3.3, 0) * ang(math.pi / 2, 0, 0), 1.45, 0.1, 0.12, 24, P.gold)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local p = v3(math.cos(a) * 1.45, 3.26, math.sin(a) * 1.45)
		if i % 2 == 0 then
			rig:ball("Body", "EyeSpot", p + v3(math.cos(a) * 0.08, 0.06, math.sin(a) * 0.08), 0.16, P.eye)
		end
		rig:thorn("Body", "Frill", cf(p) * ang(math.pi, 0, 0), 0.16, 0.32, P.glassViolet[2])
	end
	floatingCrown(rig, "Body", cf(0, 4.98, 0), 0.45, "Crystal")
	-- Tentacules
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		local d = v3(math.cos(a), 0, math.sin(a))
		local b0 = v3(0, 3.25, 0) + d * 1.15
		tentacle(rig, "Body", k, { b0, b0 + d * 0.25 + v3(0, -0.7, 0), b0 + d * 0.35 + v3(0, -1.4, 0), b0 + d * 0.25 + v3(0, -2.1, 0), b0 + d * 0.1 + v3(0, -2.75, 0) }, 0.13, 0.03, P.glassViolet[3], nil, P.blood)
	end
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2 + 0.4
		local d = v3(math.cos(a), 0, math.sin(a))
		local b0 = v3(0, 3.3, 0) + d * 0.3
		local names = tentacle(rig, "Body", 10 + k, { b0, b0 + d * 0.15 + v3(0, -0.55, 0), b0 + d * 0.2 + v3(0, -1.1, 0), b0 + d * 0.1 + v3(0, -1.6, 0) }, 0.2, 0.06, P.bloodDark, nil, nil)
		for j, name in names do
			A.tuftBurst(rig, name, cf(b0 + d * 0.15 + v3(0, -0.5 * j, 0)) * ang(0, 0, math.pi / 2), 4, 0.28, 0.12, { P.bloodDark, P.void[1] }, P.blood, 60, 40 + k * 3 + j)
		end
	end
	nexus(rig, { center = v3(0, 3.6, 0), radius = 3.2, tetherBone = "Body", tetherPos = v3(0, 5.5, 0), auraSize = v3(3, 3, 3), ability = AB6 })
	return rig:finish({ Rarity = "Chaotic" })
end

-- ---------------------------------------------------------------------------
-- 7. La Bête du Néant
-- ---------------------------------------------------------------------------
local AB7 = ab(7, "Hurlement spectral", "Nova", { radius = 7 })
local function build7(opts: Kit.BuildOptions?): Model
	theme(7)
	local rig = Kit.newRig("NeantV07", opts)
	local K = 1.3
	local function s(x: number, y: number, z: number): Vector3
		return v3(x, y, z) * K
	end
	rig:bone("Body", "Root", cf(s(0, 1.5, 0)))
	rig:bone("Head", "Body", cf(s(0, 1.8, -1.05)))
	rig:bone("Jaw", "Head", cf(s(0, 1.66, -1.35)))
	rig:mirrored(function(side, sfx)
		local x = string.sub(sfx, 2)
		rig:bone("Leg_F" .. x, "Body", cf(s(side * 0.32, 1.35, -0.6)))
		rig:bone("Leg_B" .. x, "Body", cf(s(side * 0.32, 1.4, 0.45)))
		rig:bone("Ear" .. sfx, "Head", cf(s(side * 0.2, 2.15, -1.15)))
	end)
	local body = Kit.spine({
		{ pos = s(0, 1.75, -1.05), rx = 0.3 * K, ry = 0.34 * K },
		{ pos = s(0, 1.55, -0.65), rx = 0.5 * K, ry = 0.56 * K },
		{ pos = s(0, 1.5, -0.1), rx = 0.46 * K, ry = 0.48 * K },
		{ pos = s(0, 1.52, 0.4), rx = 0.44 * K, ry = 0.44 * K },
		{ pos = s(0, 1.42, 0.8), rx = 0.3 * K, ry = 0.3 * K },
	})
	rig:tube(body, { name = "Body", bone = constFn("Body"), core = P.core, coreStep = 0.3, cover = { A.fur(P.void, P.bloodDark, v3(0.28, 0.52, 0.44), 0.22, { arc = 160, refRadius = 0.6, seed = 1 }) } })
	stars(rig, constFn("Body"), body, 36, 0.4, 71)
	-- Crinière de flammes noires
	do
		local s0, s1, i = body:lengthAt(1.0), body:lengthAt(3.4), 0
		while s0 < s1 do
			local u = body:uAt(s0)
			for _, deg in { 0, 35, -35 } do
				A.flame(rig, "Body", body:surface(u, deg, 0.05) * ang(rad(30), 0, 0), (if deg == 0 then 0.9 else 0.6) * (1 - i * 0.05), 0.3, P.flameOut, P.flameMid, P.flameCore)
			end
			s0 += 0.32
			i += 1
		end
	end
	local head = Kit.spine({
		{ pos = s(0, 1.74, -2.05), rx = 0.08 * K, ry = 0.08 * K },
		{ pos = s(0, 1.77, -1.85), rx = 0.16 * K, ry = 0.15 * K },
		{ pos = s(0, 1.84, -1.6), rx = 0.24 * K, ry = 0.22 * K },
		{ pos = s(0, 1.92, -1.35), rx = 0.34 * K, ry = 0.3 * K },
		{ pos = s(0, 1.9, -1.1), rx = 0.3 * K, ry = 0.3 * K },
	})
	rig:tube(head, { name = "Head", bone = constFn("Head"), core = P.core, coreStep = 0.2, cover = { A.fur(P.void, P.bloodDark, v3(0.2, 0.3, 0.28), 0.16, { arc = 130, from = 2.4, refRadius = 0.36, seed = 3 }) } })
	rig:prismBetween("Jaw", "Jaw", s(0, 1.66, -1.4), s(0, 1.6, -1.98), 0.32 * K, 0.12 * K, 0.05, P.void[3])
	rig:mirrored(function(side, sfx)
		A.teeth(rig, "Head", s(side * 0.06, 1.7, -2.0), s(side * 0.18, 1.74, -1.55), 5, 0.05, 0.1, P.bone, true)
		A.eye(rig, "Head", s(side * 0.2, 2.0, -1.5), v3(side, 0.3, -0.6), 0.15, "Glow", P.socket, P.eye)
		A.brow(rig, "Head", side, s(0.18, 2.09, -1.52), 0.3, 26, P.void[4])
		A.ear(rig, "Ear" .. sfx, cf(s(side * 0.2, 2.15, -1.15)) * ang(rad(-12), side * rad(-20), side * rad(-18)), 0.4, 0.6, P.void[2], P.bloodDark, P.blood)
	end)
	floatingCrown(rig, "Head", cf(s(0, 2.24, -1.3)) * ang(rad(-10), 0, 0), 0.34, "Spikes")
	rig:mirrored(function(side, sfx)
		local x = string.sub(sfx, 2)
		for key, L in { F = { s(0.32, 1.35, -0.6), s(0.34, 0.75, -0.62), s(0.34, 0.16, -0.7), 0.26 }, B = { s(0.32, 1.4, 0.45), s(0.36, 0.82, 0.62), s(0.34, 0.16, 0.54), 0.36 } } do
			local bone = "Leg_" .. key .. x
			A.limb(rig, bone, side, { { L[1], L[4], L[4] * 1.2 }, { L[2], 0.15, 0.15 }, { L[3], 0.11, 0.11 } }, P.core, A.fur(P.void, P.bloodDark, v3(0.22, 0.34, 0.3), 0.18, { arc = 180, refRadius = 0.24, seed = 10 + side }))
			A.paw(rig, bone, v3(side * (L[3] :: Vector3).X, 0, (L[3] :: Vector3).Z - 0.1), v3(0, 0, -1), 0.34, 4, P.void[4], P.void[3], P.blood)
		end
	end)
	local tailPts = { s(0, 1.48, 0.85), s(0, 1.35, 1.3), s(0.05, 1.45, 1.8), s(0.15, 1.75, 2.15), s(0.2, 2.0, 2.3) }
	local tail = rig:boneChain("Tail", "Body", tailPts)
	local secs = {}
	for i, p in tailPts do
		local r = 0.16 * K * (1 - (i - 1) / #tailPts * 0.7)
		table.insert(secs, { pos = p, rx = r, ry = r })
	end
	rig:tube(Kit.spine(secs), { name = "Tail", bone = function(u)
		return tail[math.clamp(math.floor(u), 1, #tail)]
	end, core = P.core, coreStep = 0.2, cover = { A.fur(P.void, P.bloodDark, v3(0.22, 0.42, 0.36), 0.16, { arc = 180, refRadius = 0.2, seed = 6 }) } })
	A.flame(rig, tail[#tail], A.alongUp(tailPts[#tailPts], tailPts[#tailPts] - tailPts[#tailPts - 1]), 0.9, 0.36, P.flameOut, P.flameMid, P.flameCore)
	nexus(rig, { center = s(0, 1.7, 0), radius = 3.4, tetherBone = "Head", tetherPos = s(0, 2.65, -1.3), auraSize = v3(2.4, 2.4, 4), ability = AB7, ground = 3.2 })
	return rig:finish({ Rarity = "Chaotic" })
end

-- ---------------------------------------------------------------------------
-- 8. Le Masque Couronné
-- ---------------------------------------------------------------------------
local AB8 = ab(8, "Rire du néant", "Nova", { texture = "sparkle" })
local function build8(opts: Kit.BuildOptions?): Model
	theme(8)
	local rig = Kit.newRig("NeantV08", opts)
	rig:bone("Body", "Root", cf(0, 3.6, 0))
	rig:bone("Head", "Body", cf(0, 4.3, 0))
	local porcelain = P.porcelain
	-- Masque : plaques bombées liserées d'or
	local plates = {
		{ cf(0, 4.35, -0.62), v3(0.9, 1.5, 0.16) },
		{ cf(0.55, 4.35, -0.5) * ang(0, rad(-28), 0), v3(0.5, 1.35, 0.15) },
		{ cf(-0.55, 4.35, -0.5) * ang(0, rad(28), 0), v3(0.5, 1.35, 0.15) },
		{ cf(0, 5.12, -0.5) * ang(rad(-30), 0, 0), v3(1.1, 0.5, 0.15) },
		{ cf(0, 3.55, -0.5) * ang(rad(32), 0, 0), v3(0.7, 0.45, 0.15) },
	}
	for _, pl in plates do
		rig:prism("Head", "Mask", pl[1], pl[2], 0.06, porcelain)
	end
	rig:ring("Head", "MaskRim", cf(0, 4.35, -0.5) * ang(0, 0, 0), 0.92, 0.06, 0.08, 20, P.gold)
	rig:mirrored(function(side)
		rig:prism("Head", "EyeHole", cf(A.mx(v3(0.3, 4.55, -0.7), side)) * ang(0, 0, side * rad(-20)), v3(0.34, 0.2, 0.05), 0.08, P.face)
		rig:ball("Head", "Pupil", A.mx(v3(0.3, 4.55, -0.74), side), 0.12, P.eye)
		rig:strut("Head", "Tear", A.mx(v3(0.3, 4.42, -0.72), side), A.mx(v3(0.36, 3.9, -0.66), side), 0.035, 0.03, P.blood)
	end)
	rig:strut("Head", "Crack", v3(-0.15, 5.0, -0.72), v3(0.05, 4.7, -0.73), 0.03, 0.03, P.blood)
	rig:strut("Head", "Crack", v3(0.05, 4.7, -0.73), v3(-0.08, 4.35, -0.73), 0.03, 0.03, P.blood)
	rig:strut("Head", "Mouth", v3(-0.25, 3.92, -0.7), v3(0.25, 3.92, -0.7), 0.04, 0.03, P.gold)
	floatingCrown(rig, "Head", cf(0, 5.32, -0.35), 0.58, "Gothic")
	-- Capuche de néant derrière le masque, manteau qui s'effiloche
	local cowl = Kit.spine({
		{ pos = v3(0, 4.35, -0.4), rx = 0.75, ry = 0.9 },
		{ pos = v3(0, 4.4, 0.05), rx = 0.9, ry = 1.0 },
		{ pos = v3(0, 4.2, 0.5), rx = 0.62, ry = 0.72 },
		{ pos = v3(0, 3.9, 0.85), rx = 0.2, ry = 0.25 },
	})
	rig:tube(cowl, { name = "Cowl", bone = constFn("Head"), core = P.core, coreStep = 0.25, cover = { A.fur(P.void, P.bloodDark, v3(0.3, 0.6, 0.46), 0.24, { arc = 180, tilt = 40, refRadius = 0.8, seed = 2 }) } })
	stars(rig, constFn("Head"), cowl, 14, 0.4, 81)
	local cloak = Kit.spine({
		{ pos = v3(0, 3.5, 0.2), rx = 0.8, ry = 0.6 },
		{ pos = v3(0, 2.7, 0.35), rx = 0.7, ry = 0.55 },
		{ pos = v3(0, 1.9, 0.55), rx = 0.45, ry = 0.38 },
		{ pos = v3(0, 1.2, 0.8), rx = 0.06, ry = 0.06 },
	})
	rig:tube(cloak, { name = "Cloak", bone = constFn("Body"), core = P.core, coreStep = 0.3, cover = { A.fur(P.void, P.bloodDark, v3(0.32, 0.7, 0.5), 0.26, { arc = 180, tilt = 20, refRadius = 0.6, seed = 3 }) } })
	stars(rig, constFn("Body"), cloak, 28, 0.42, 82)
	-- Mains flottantes
	for i, side in { 1, -1 } do
		local name = "Float" .. i
		local H = A.mx(v3(1.9, 3.1, -0.8), side)
		rig:bone(name, "Root", cf(H))
		clawHand(rig, name, H, v3(-side * 0.4, 0.3, -1), 1.1, P.pale, P.blood)
		rig:ring(name, "Cuff", cf(H + v3(side * 0.05, -0.02, 0.32)), 0.24, 0.07, 0.12, 12, P.gold)
	end
	nexus(rig, { center = v3(0, 3.6, 0), radius = 3.0, tetherBone = "Head", tetherPos = v3(0, 6.2, -0.35), auraSize = v3(2.4, 3, 1.8), ability = AB8 })
	return rig:finish({ Rarity = "Chaotic" })
end

-- ---------------------------------------------------------------------------
-- 9. L'Astre Noir
-- ---------------------------------------------------------------------------
local AB9 = ab(9, "Éclipse totale", "Eruption", { texture = "fire", radius = 9 })
local function build9(opts: Kit.BuildOptions?): Model
	theme(9)
	local rig = Kit.newRig("NeantV09", opts)
	rig:bone("Body", "Root", cf(0, 3.4, 0))
	rig:bone("Head", "Body", cf(0, 3.4, 0))
	local star = Kit.spine({
		{ pos = v3(0, 3.4, -1.36), rx = 0.25, ry = 0.25 },
		{ pos = v3(0, 3.4, -1.05), rx = 1.0, ry = 1.0 },
		{ pos = v3(0, 3.4, -0.35), rx = 1.36, ry = 1.36 },
		{ pos = v3(0, 3.4, 0.4), rx = 1.3, ry = 1.3 },
		{ pos = v3(0, 3.4, 1.0), rx = 0.8, ry = 0.8 },
		{ pos = v3(0, 3.4, 1.32), rx = 0.15, ry = 0.15 },
	})
	rig:tube(star, { name = "Star", bone = constFn("Head"), core = P.blood, coreStep = 0.3, cover = { A.scales(P.obsidian, v3(0.5, 0.2, 0.42), 0.48, { arc = 180, tilt = 6, jitter = 0.5, refRadius = 1.0, seed = 1 }) } })
	stars(rig, constFn("Head"), star, 30, 0.26, 91, 1.2)
	-- Couronne solaire : épines rayonnantes (répartition en spirale de Fibonacci)
	local n = 30
	for i = 1, n do
		local y = 1 - (i - 0.5) / n * 1.6
		local r = math.sqrt(math.max(0, 1 - y * y))
		local a = i * 2.39996
		local dir = v3(math.cos(a) * r, y, math.sin(a) * r)
		if dir.Z < -0.55 and math.abs(dir.Y) < 0.5 then
			continue -- garde le visage dégagé
		end
		local base = A.alongUp(v3(0, 3.4, 0) + dir * 1.25, dir)
		local h = if i % 3 == 0 then 1.0 else 0.6
		rig:thorn("Head", "Corona", base, 0.22, h, if i % 2 == 0 then P.gold else P.obsidian[4])
		rig:thorn("Head", "CoronaTip", base * cf(0, h * 0.6, 0), 0.1, h * 0.5, P.blood)
	end
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + 0.5
		local dir = v3(math.cos(a), 0.35, math.sin(a)).Unit
		A.flame(rig, "Head", A.alongUp(v3(0, 3.4, 0) + dir * 1.3, dir), 1.1, 0.4, P.flameOut, P.flameMid, P.flameCore)
	end
	-- Visage
	rig:mirrored(function(side)
		rig:prism("Head", "Eye", cf(A.mx(v3(0.38, 3.65, -1.3), side)) * ang(0, 0, side * rad(-18)), v3(0.42, 0.14, 0.08), 0.05, P.eye)
		A.brow(rig, "Head", side, v3(0.38, 3.86, -1.25), 0.42, 22, P.obsidian[4])
	end)
	for i = -3, 3 do
		local x = i * 0.11
		rig:block("Head", "Mouth", cf(x, 3.05 + (x * x) * 0.6, -1.31), v3(0.09, 0.05, 0.05), P.eye)
	end
	floatingCrown(rig, "Head", cf(0, 4.72, 0), 0.6, "Spikes")
	-- Anneau incliné de cristaux (façon planète)
	rig:bone("AuraRing", "Root", cf(0, 3.4, 0) * ang(rad(18), 0, rad(-14)))
	local ringCF = cf(0, 3.4, 0) * ang(rad(18), 0, rad(-14))
	rig:ring("AuraRing", "PlanetRing", ringCF * ang(math.pi / 2, 0, 0), 2.35, 0.08, 0.04, 40, P.halo)
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		local p = ringCF * cf(math.cos(a) * 2.6, 0, math.sin(a) * 2.6)
		rig:shard("AuraRing", "RingCrystal", p * ang(0, -a, rad(25)), 0.16, 0.36, 0.16, P.crystals[(i % 3) + 1])
	end
	nexus(rig, { center = v3(0, 3.4, 0), radius = 3.5, crystals = 6, tetherBone = "Head", tetherPos = v3(0, 5.4, 0), auraSize = v3(3, 3, 3), ability = AB9, ground = 2.8 })
	return rig:finish({ Rarity = "Chaotic" })
end

-- ---------------------------------------------------------------------------
-- 10. L'Archange Déchu
-- ---------------------------------------------------------------------------
local AB10 = ab(10, "Chute céleste", "Nova", { texture = "sparkle" })
local function build10(opts: Kit.BuildOptions?): Model
	theme(10)
	local rig = Kit.newRig("NeantV10", opts)
	rig:bone("Body", "Root", cf(0, 3.7, 0.1))
	rig:bone("Head", "Body", cf(0, 4.95, -0.05))
	rig:mirrored(function(side, sfx)
		rig:bone("Arm" .. sfx, "Body", cf(side * 0.6, 4.5, 0))
		rig:bone("Wing" .. sfx, "Body", cf(side * 0.35, 4.6, 0.35))
		rig:bone("Wing2" .. sfx, "Body", cf(side * 0.3, 4.05, 0.4))
	end)
	local body = Kit.spine({
		{ pos = v3(0, 4.65, 0.05), rx = 0.6, ry = 0.45 },
		{ pos = v3(0, 4.0, 0.1), rx = 0.55, ry = 0.42 },
		{ pos = v3(0, 3.3, 0.2), rx = 0.65, ry = 0.5 },
		{ pos = v3(0, 2.5, 0.35), rx = 0.7, ry = 0.55 },
		{ pos = v3(0, 1.7, 0.55), rx = 0.5, ry = 0.4 },
		{ pos = v3(0, 1.1, 0.8), rx = 0.1, ry = 0.1 },
	})
	rig:tube(body, { name = "Robe", bone = constFn("Body"), core = P.core, coreStep = 0.3, cover = { A.fur(P.void, P.bloodDark, v3(0.3, 0.62, 0.48), 0.25, { arc = 180, tilt = 22, refRadius = 0.55, seed = 1 }) } })
	stars(rig, constFn("Body"), body, 36, 0.4, 101)
	rig:prism("Body", "Breastplate", cf(0, 4.25, -0.38) * ang(rad(-6), 0, 0), v3(0.8, 0.75, 0.16), 0.14, P.gold)
	rig:shard("Body", "ChestGem", cf(0, 4.25, -0.48) * ang(rad(-90), 0, 0), 0.2, 0.1, 0.1, P.gem)
	-- Visage pâle, cheveux noirs, larmes rouges
	local head = Kit.spine({
		{ pos = v3(0, 5.0, -0.32), rx = 0.2, ry = 0.24 },
		{ pos = v3(0, 5.08, -0.12), rx = 0.3, ry = 0.34 },
		{ pos = v3(0, 5.05, 0.15), rx = 0.3, ry = 0.33 },
		{ pos = v3(0, 4.85, 0.3), rx = 0.2, ry = 0.24 },
	})
	rig:tube(head, { name = "Head", bone = constFn("Head"), core = P.pale, coreStep = 0.15, cover = { A.fur(P.hair, nil, v3(0.18, 0.4, 0.3), 0.14, { arc = 150, from = 2.0, tilt = 50, refRadius = 0.3, seed = 2 }) } })
	A.tuftBurst(rig, "Head", cf(0, 5.0, 0.3) * ang(rad(150), 0, 0), 9, 0.9, 0.18, P.hair, P.bloodDark, 30, 3)
	rig:mirrored(function(side)
		A.eye(rig, "Head", A.mx(v3(0.11, 5.1, -0.33), side), v3(side * 0.2, 0, -1), 0.07, "Glow", P.socket, P.eye)
		rig:strut("Head", "Tear", A.mx(v3(0.11, 5.03, -0.34), side), A.mx(v3(0.13, 4.82, -0.27), side), 0.025, 0.02, P.blood)
	end)
	-- Halo-couronne brisé
	local halo = cf(0, 6.0, 0.15)
	rig:bone("Float9", "Head", halo)
	crownPos = halo.Position + v3(0, 0.35, 0)
	for i = 0, 19 do
		if i % 7 ~= 3 then
			local a = i / 20 * math.pi * 2
			rig:block("Float9", "Halo", halo * ang(0, a, 0) * cf(0, 0, -0.55), v3(0.2, 0.07, 0.1), P.gold)
		end
	end
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		rig:thorn("Float9", "HaloSpike", halo * ang(0, a, 0) * cf(0, 0.03, -0.55), 0.1, if i % 2 == 0 then 0.42 else 0.28, P.gold)
		rig:ball("Float9", "HaloGem", (halo * ang(0, a, 0) * cf(0, 0.02, -0.62)).Position, 0.08, P.gem)
	end
	-- Quatre ailes noires
	local wingRows = P.wingRows
	rig:mirrored(function(side, sfx)
		local sh = A.mx(v3(0.35, 4.6, 0.35), side)
		A.wing(rig, "Wing" .. sfx, side, {
			arm = { v3(0.35, 4.6, 0.35), v3(1.1, 5.0, 0.55), v3(1.95, 5.3, 0.7), v3(2.8, 5.45, 0.85) },
			armRadius = 0.12,
			feathers = 13,
			length = { 1.1, 1.8 },
			width = 0.36,
			sweep = 30,
			rows = wingRows,
			tip = P.blood,
			armStyle = P.void[3],
			pose = cf(sh) * ang(rad(-25), 0, side * rad(32)) * cf(-sh),
		})
		local sh2 = A.mx(v3(0.3, 4.05, 0.4), side)
		A.wing(rig, "Wing2" .. sfx, side, {
			arm = { v3(0.3, 4.05, 0.4), v3(0.9, 3.9, 0.6), v3(1.55, 3.7, 0.75), v3(2.15, 3.45, 0.9) },
			armRadius = 0.1,
			feathers = 10,
			length = { 0.8, 1.3 },
			width = 0.3,
			sweep = 30,
			rows = wingRows,
			tip = P.blood,
			armStyle = P.void[3],
			pose = cf(sh2) * ang(rad(-15), 0, side * rad(-20)) * cf(-sh2),
		})
		-- Bras en manches
		local arm = "Arm" .. sfx
		A.limb(rig, arm, side, { { v3(0.6, 4.5, 0), 0.17, 0.17 }, { v3(0.9, 3.85, -0.2), 0.14, 0.14 }, { v3(1.0, 3.25, -0.5), 0.11, 0.11 } }, P.core, A.fur(P.void, nil, v3(0.16, 0.3, 0.24), 0.14, { arc = 180, refRadius = 0.16, seed = 20 + side }))
		A.tuftBurst(rig, arm, cf(A.mx(v3(1.0, 3.4, -0.45), side)) * ang(math.pi, 0, 0), 6, 0.5, 0.18, P.void, P.bloodDark, 35, 30 + side)
		clawHand(rig, arm, A.mx(v3(1.04, 3.12, -0.58), side), v3(0, -0.6, -1), 0.55, P.pale, P.blood)
	end)
	nexus(rig, { center = v3(0, 3.6, 0.2), radius = 3.3, tetherBone = "Head", tetherPos = v3(0, 6.1, 0.15), auraSize = v3(2.4, 3.4, 1.8), ability = AB10 })
	return rig:finish({ Rarity = "Chaotic" })
end

-- ---------------------------------------------------------------------------
local function def(n: number, name: string, desc: string, gait: string, ability: Types.Ability, build: (Kit.BuildOptions?) -> Model, extra: { [string]: any }?): Types.CreatureDef
	local anim: { [string]: any } = { gait = gait, hover = 0.25, headLook = 14, auraSpeed = 0.5, flicker = 0.2 }
	if extra then
		for k, v in extra do
			anim[k] = v
		end
	end
	local ic = THEMES[n].icon
	return {
		Id = string.format("NeantV%02d", n),
		DisplayName = `{n} · {name}`,
		Rarity = "Chaotic",
		Size = "Colossal",
		Income = 100000000,
		SpeedBonus = 4.0,
		Passenger = true,
		Scale = 3.0,
		Category = "Variante du Néant Couronné",
		Description = desc,
		Icon = { top = ic[1], bottom = ic[2], glow = ic[3], motif = ic[4], yaw = 24, pitch = 8, zoom = 1.05 },
		Animation = anim :: any,
		Ability = ability,
		build = build,
	}
end

local LIST: { any } = {
	def(1, "Le Roi Spectral", "Style gothique spectral — argent et cyan fantôme : roi-spectre en robe de lambeaux, visage d'ombre, couronne d'argent qui flotte.", "Hover", AB1, build1),
	def(2, "L'Œil du Néant", "Style cosmique — bleu nuit galactique et or : œil géant cuirassé, iris d'or, tentacules étoilés.", "Hover", AB2, build2),
	def(3, "Le Dragon du Néant", "Style nébuleuse — turquoise et magenta : dragon serpentin aux ailes de verre rose, ventre magenta.", "Hover", AB3, build3, { tailSway = 14, tailRate = 1.2, hover = 0.3 }),
	def(4, "Le Colosse Couronné", "Style obsidienne et lave — titan de roche noire fendu de lave orange, poings flottants.", "Hover", AB4, build4, { hover = 0.15 }),
	def(5, "Le Seigneur Cornu", "Style royal noir et or — roi démon en armure noire, cornes de bélier, cape et sceptre de cristal violet.", "Hover", AB5, build5),
	def(6, "La Méduse Abyssale", "Style bioluminescent — cloche de verre cyan, cœur rose, tentacules lumineux.", "Hover", AB6, build6, { hover = 0.35 }),
	def(7, "La Bête du Néant", "Style flammes spectrales — loup noir à la crinière de flammes bleues, crocs et griffes glacés.", "Quadruped", AB7, build7, { breathe = 0.04, bob = 0.12, stride = 30, strideRate = 9, tailSway = 12, tailRate = 1.4, earTwitch = true }),
	def(8, "Le Masque Couronné", "Style théâtre — masque de porcelaine blanche fissuré de rouge, capuche de néant noir, mains flottantes.", "Hover", AB8, build8),
	def(9, "L'Astre Noir", "Style éclipse solaire — soleil noir furieux, couronne d'épines d'or, éruptions et anneau de cristaux.", "Hover", AB9, build9, { hover = 0.2 }),
	def(10, "L'Archange Déchu", "Style céleste déchu — ivoire et or, quatre ailes blanches qui noircissent, halo-couronne brisé.", "Hover", AB10, build10),
}

--- Aura de rareté ajoutée aux variantes (nil = aucune). Utilisé par Creatures/NeantCouronne.
(LIST :: any).setRarityAura = function(r: string?)
	auraRarity = r
end

return LIST
