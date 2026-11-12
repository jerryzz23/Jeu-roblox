--!strict
--[[
	Treadmills.Base
	---------------
	Structure commune des tapis de course (en studs réels, avant = -Z, le joueur court vers -Z) :
	socle, rails latéraux à bandes Neon, rouleaux, bande roulante animée (os "Belt" : les lattes
	défilent vers l'arrière), motif lumineux sur la bande, montants, console à écran (face
	coureur + emblème en façade), poignées, surface de course collidable ("RunSurface").

	Base.build(rig, theme) renvoie des points d'ancrage pour les décors propres à chaque tapis.
]]

local Kit = require(script.Parent.Parent.Kit)
local A = require(script.Parent.Parent.Anatomy)

local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles
local rad = math.rad

type Style = Kit.Style
type Rig = Kit.Rig

export type Theme = {
	frame: Style, -- rails, carter moteur, montants, console
	frameDark: Style, -- socle, rouleaux
	trim: Style, -- liserés, poignées
	neon: Style, -- bandes lumineuses
	belt: Style, -- lattes de la bande
	beltUnder: Style, -- dessous de la bande
	accent: Style?, -- motif lumineux sur la bande
	pattern: string?, -- "chevrons" | "stars" | "bolts" | "dots" | "runes" | "waves" | "rainbow" | "none"
	screen: Style, -- fond d'écran de la console
	glyph: string?, -- emblème : "runner" | "flame" | "snow" | "star" | "bolt" | "moon" | "crown" | "eye" | "leaf" | "swirl"
	glyphStyle: Style?, -- couleur de l'emblème (défaut : neon)
	beltSpeed: number?, -- vitesse de défilement (studs/s)
	rainbow: { Style }?, -- couleurs des lattes (motif "rainbow")
}

export type Anchors = {
	length: number,
	halfWidth: number,
	deckY: number,
	consoleCF: CFrame, -- centre de la console (Y = haut, -Z = façade)
	consoleTop: Vector3,
	posts: { Vector3 }, -- sommets des deux montants (droite, gauche)
	frontCorners: { Vector3 }, -- coins avant au niveau du pont (droite, gauche)
	rearCorners: { Vector3 }, -- coins arrière
}

local Base = {}

Base.LENGTH = 8
Base.WIDTH = 3.4
Base.BELT_W = 2.5
Base.DECK_Y = 0.72
Base.SPACING = 0.5

--- Trace un emblème dans le plan XY de `at` (face -Z), taille `s`.
function Base.glyph(rig: Rig, bone: string, at: CFrame, kind: string, s: number, st: Style)
	local w = 0.07 * s / 0.5
	local function seg(x0: number, y0: number, x1: number, y1: number, ww: number?)
		rig:strut(bone, "Glyph", (at * cf(x0 * s, y0 * s, 0)).Position, (at * cf(x1 * s, y1 * s, 0)).Position, ww or w, 0.03, st)
	end
	local function dot(x: number, y: number, d: number)
		rig:ball(bone, "Glyph", (at * cf(x * s, y * s, 0)).Position, d * s, st)
	end
	if kind == "runner" then
		dot(0.12, 0.62, 0.22)
		seg(0.08, 0.48, -0.06, 0.05)
		seg(0.04, 0.38, 0.32, 0.22)
		seg(0.04, 0.38, -0.26, 0.3)
		seg(-0.06, 0.05, 0.22, -0.2)
		seg(0.22, -0.2, 0.16, -0.52)
		seg(-0.06, 0.05, -0.28, -0.22)
		seg(-0.28, -0.22, -0.46, -0.12)
	elseif kind == "flame" then
		seg(0, -0.55, -0.3, -0.1)
		seg(-0.3, -0.1, -0.05, 0.25)
		seg(-0.05, 0.25, 0, 0.65)
		seg(0, -0.55, 0.3, -0.1)
		seg(0.3, -0.1, 0.12, 0.2)
		seg(0.12, 0.2, 0, 0.65)
		dot(0, -0.2, 0.22)
	elseif kind == "snow" then
		for k = 0, 2 do
			local a = k * math.pi / 3
			seg(-math.cos(a) * 0.6, -math.sin(a) * 0.6, math.cos(a) * 0.6, math.sin(a) * 0.6)
			for _, sgn in { 1, -1 } do
				local cx, cy = sgn * math.cos(a) * 0.38, sgn * math.sin(a) * 0.38
				local px, py = -math.sin(a) * 0.14, math.cos(a) * 0.14
				seg(cx, cy, cx + sgn * math.cos(a) * 0.12 + px, cy + sgn * math.sin(a) * 0.12 + py, w * 0.7)
				seg(cx, cy, cx + sgn * math.cos(a) * 0.12 - px, cy + sgn * math.sin(a) * 0.12 - py, w * 0.7)
			end
		end
	elseif kind == "star" then
		for k = 0, 3 do
			local a = k * math.pi / 2
			seg(0, 0, math.cos(a) * 0.62, math.sin(a) * 0.62, w * 1.3)
			seg(0, 0, math.cos(a + math.pi / 4) * 0.32, math.sin(a + math.pi / 4) * 0.32, w * 0.8)
		end
		dot(0, 0, 0.26)
	elseif kind == "bolt" then
		seg(0.18, 0.62, -0.2, 0.02, w * 1.4)
		seg(-0.2, 0.02, 0.2, 0.02, w * 1.4)
		seg(0.2, 0.02, -0.18, -0.62, w * 1.4)
	elseif kind == "moon" then
		for k = 0, 8 do
			local a0, a1 = rad(70 + k * 25), rad(70 + (k + 1) * 25)
			seg(math.cos(a0) * 0.55, math.sin(a0) * 0.55, math.cos(a1) * 0.55, math.sin(a1) * 0.55, w * 1.3)
			seg(math.cos(a0) * 0.32 + 0.16, math.sin(a0) * 0.36, math.cos(a1) * 0.32 + 0.16, math.sin(a1) * 0.36, w * 0.9)
		end
		dot(0.32, 0.36, 0.1)
		dot(0.46, -0.1, 0.08)
	elseif kind == "crown" then
		seg(-0.5, -0.3, 0.5, -0.3, w * 1.4)
		seg(-0.5, -0.3, -0.55, 0.35)
		seg(-0.55, 0.35, -0.25, 0.05)
		seg(-0.25, 0.05, 0, 0.5)
		seg(0, 0.5, 0.25, 0.05)
		seg(0.25, 0.05, 0.55, 0.35)
		seg(0.55, 0.35, 0.5, -0.3)
		dot(-0.55, 0.4, 0.14)
		dot(0, 0.56, 0.16)
		dot(0.55, 0.4, 0.14)
	elseif kind == "eye" then
		for k = 0, 7 do
			local a0, a1 = rad(k * 22.5), rad((k + 1) * 22.5)
			seg(math.cos(a0) * 0.62, math.sin(a0) * 0.3, math.cos(a1) * 0.62, math.sin(a1) * 0.3)
			seg(math.cos(a0) * 0.62, -math.sin(a0) * 0.3, math.cos(a1) * 0.62, -math.sin(a1) * 0.3)
		end
		dot(0, 0, 0.3)
	elseif kind == "leaf" then
		seg(0, -0.6, 0, 0.6, w * 0.8)
		for k = 0, 6 do
			local a0, a1 = rad(-90 + k * 30), rad(-90 + (k + 1) * 30)
			seg(math.cos(a0) * 0.35, math.sin(a0) * 0.6, math.cos(a1) * 0.35, math.sin(a1) * 0.6)
			seg(-math.cos(a0) * 0.35, math.sin(a0) * 0.6, -math.cos(a1) * 0.35, math.sin(a1) * 0.6)
		end
	elseif kind == "swirl" then
		local prev: { number }? = nil
		for k = 0, 18 do
			local a = k * 0.55
			local r = 0.08 + k * 0.03
			local p = { math.cos(a) * r, math.sin(a) * r }
			if prev then
				seg(prev[1], prev[2], p[1], p[2])
			end
			prev = p
		end
	end
end

--- Construit le tapis de base sur `rig` (os Root déjà présent). Renvoie les ancrages.
function Base.build(rig: Rig, t: Theme): Anchors
	local L, W, BW, Y = Base.LENGTH, Base.WIDTH, Base.BELT_W, Base.DECK_Y
	local hw = W / 2
	local zF, zB = -L / 2, L / 2

	-- Socle, rails, rouleaux, carter moteur
	rig:prism("Root", "Base", cf(0, 0.16, 0), v3(W, 0.32, L), 0.08, t.frameDark)
	for _, s in { 1, -1 } do
		local x = s * (hw - 0.25)
		rig:prism("Root", "Rail", cf(x, 0.5, 0.2), v3(0.5, 0.5, L - 0.4), 0.1, t.frame)
		rig:block("Root", "RailTrim", cf(s * (hw - 0.02), 0.5, 0.2), v3(0.06, 0.52, L - 0.5), t.trim)
		rig:block("Root", "RailNeon", cf(x + s * 0.06, 0.765, 0.2), v3(0.2, 0.04, L - 0.9), t.neon)
		rig:block("Root", "RailNeonSide", cf(s * (hw + 0.005), 0.35, 0.2), v3(0.04, 0.08, L - 1.0), t.neon)
		rig:prism("Root", "Foot", cf(x, 0.12, zB - 0.35), v3(0.56, 0.24, 0.6), 0.08, t.frameDark)
		rig:block("Root", "RearLight", cf(x, 0.5, zB + 0.005), v3(0.3, 0.3, 0.04), t.neon)
	end
	rig:cylinder("Root", "RearRoller", v3(-BW / 2, 0.52, zB - 0.3), v3(BW / 2, 0.52, zB - 0.3), 0.42, t.frameDark)
	rig:prism("Root", "Motor", cf(0, 0.62, zF + 0.55), v3(W, 0.95, 1.1), 0.18, t.frame)
	rig:block("Root", "MotorTrim", cf(0, 1.06, zF + 0.55), v3(W - 0.1, 0.06, 1.12), t.trim)
	for _, s in { 1, -1 } do
		rig:block("Root", "FrontLight", cf(s * (hw - 0.35), 0.62, zF - 0.02), v3(0.38, 0.38, 0.06), t.neon)
	end
	rig:block("Root", "FrontStrip", cf(0, 0.62, zF - 0.02), v3(W - 1.6, 0.08, 0.05), t.neon)

	-- Bande roulante (lattes animées)
	rig:block("Root", "BeltUnder", cf(0, Y - 0.08, 0.3), v3(BW, 0.06, L - 1.4), t.beltUnder)
	rig:bone("Belt", "Root", cf(0, Y, 0))
	local n = 0
	local z = zF + 1.2
	while z <= zB - 0.45 do
		n += 1
		local st = t.belt
		if t.pattern == "rainbow" and t.rainbow then
			st = t.rainbow[(n - 1) % #t.rainbow + 1]
		end
		rig:block("Belt", "Slat", cf(0, Y, z), v3(BW - 0.1, 0.05, Base.SPACING - 0.08), st)
		local acc = t.accent
		if acc then
			if t.pattern == "chevrons" and n % 2 == 0 then
				rig:block("Belt", "Chevron", cf(-0.4, Y + 0.03, z) * ang(0, rad(-30), 0), v3(0.9, 0.03, 0.09), acc)
				rig:block("Belt", "Chevron", cf(0.4, Y + 0.03, z) * ang(0, rad(30), 0), v3(0.9, 0.03, 0.09), acc)
			elseif t.pattern == "stars" and n % 2 == 1 then
				rig:ball("Belt", "BeltStar", v3(((n * 37) % 9 - 4) * 0.22, Y + 0.03, z), 0.1, acc)
				rig:ball("Belt", "BeltStar", v3(((n * 53) % 9 - 4) * 0.22, Y + 0.03, z + 0.12), 0.07, acc)
			elseif t.pattern == "bolts" and n % 3 == 0 then
				rig:block("Belt", "Bolt", cf(-0.3, Y + 0.03, z - 0.1) * ang(0, rad(50), 0), v3(0.5, 0.03, 0.07), acc)
				rig:block("Belt", "Bolt", cf(0.05, Y + 0.03, z) * ang(0, rad(-10), 0), v3(0.4, 0.03, 0.07), acc)
				rig:block("Belt", "Bolt", cf(0.35, Y + 0.03, z + 0.1) * ang(0, rad(50), 0), v3(0.5, 0.03, 0.07), acc)
			elseif t.pattern == "dots" then
				for k = -2, 2 do
					if (n + k) % 3 == 0 then
						rig:block("Belt", "BeltDot", cf(k * 0.45, Y + 0.03, z), v3(0.12, 0.03, 0.12), acc)
					end
				end
			elseif t.pattern == "runes" and n % 3 == 1 then
				A.rune(rig, "Belt", cf(0, Y + 0.035, z) * ang(-math.pi / 2, 0, 0), 0.34, acc, n % 6 + 1)
			elseif t.pattern == "waves" then
				local x = math.sin(n * 0.9) * 0.6
				rig:block("Belt", "Wave", cf(x, Y + 0.03, z), v3(0.7, 0.03, 0.1), acc)
			elseif t.pattern == "edges" then
				rig:block("Belt", "BeltEdge", cf(-BW / 2 + 0.15, Y + 0.03, z), v3(0.12, 0.03, 0.3), acc)
				rig:block("Belt", "BeltEdge", cf(BW / 2 - 0.15, Y + 0.03, z), v3(0.12, 0.03, 0.3), acc)
			end
		end
		z += Base.SPACING
	end
	local belt = rig.bones.Root:FindFirstChild("Belt")
	if belt then
		belt:SetAttribute("BeltSpeed", t.beltSpeed or 3)
		belt:SetAttribute("BeltSpacing", Base.SPACING)
	end

	-- Montants, console, poignées
	local posts = {}
	for _, s in { 1, -1 } do
		local x = s * (hw - 0.25)
		rig:prism("Root", "Post", cf(x, 2.55, zF + 0.45) * ang(rad(-6), 0, 0), v3(0.36, 3.4, 0.36), 0.08, t.frame)
		rig:block("Root", "PostNeon", cf(x - s * 0.19, 2.55, zF + 0.47) * ang(rad(-6), 0, 0), v3(0.04, 2.9, 0.12), t.neon)
		local top = v3(x, 4.2, zF + 0.27)
		table.insert(posts, top)
		-- Poignée : du montant vers l'arrière
		local h0 = v3(x, 3.25, zF + 0.4)
		local h1 = v3(s * (hw - 0.1), 3.1, zF + 1.8)
		rig:strut("Root", "Handle", h0, h1, 0.14, 0.14, t.trim)
		rig:cylinder("Root", "Grip", h1 - (h1 - h0).Unit * 0.5, h1, 0.19, t.frameDark)
		rig:ball("Root", "HandleCap", h1, 0.2, t.neon)
	end
	local consoleCF = cf(0, 4.35, zF + 0.3) * ang(rad(-18), 0, 0)
	rig:prism("Root", "Console", consoleCF, v3(W - 0.2, 1.05, 0.5), 0.14, t.frame)
	rig:block("Root", "ConsoleTrim", consoleCF * cf(0, 0.53, 0), v3(W - 0.3, 0.06, 0.52), t.trim)
	-- Écran face au coureur (+Z) et emblème en façade (-Z)
	local screen = consoleCF * cf(0, 0, 0.255) * ang(0, math.pi, 0)
	rig:block("Root", "Screen", screen, v3(2.1, 0.7, 0.03), t.screen)
	Base.glyph(rig, "Root", screen * cf(0, 0, -0.02), "runner", 0.3, t.neon)
	for k = -2, 2 do
		rig:block("Root", "ScreenBar", screen * cf(0.55 + k * 0.08, -0.15 + k * 0.04, -0.02), v3(0.05, 0.12 + (k + 2) * 0.07, 0.02), t.neon)
	end
	local front = consoleCF * cf(0, 0, -0.255)
	rig:block("Root", "Emblem", front, v3(1.4, 0.82, 0.03), t.screen)
	Base.glyph(rig, "Root", front * cf(0, 0, -0.02), t.glyph or "runner", 0.36, t.glyphStyle or t.neon)

	-- Surface de course (collidable) et collision de la console
	local run = rig:anchor("Root", "RunSurface", cf(0, Y, 0.3), v3(BW, 0.2, L - 1.4))
	run.CanCollide = true
	run.CanQuery = true
	run.CanTouch = true
	-- Pièce ancrée indépendante : sa vitesse de convoyeur (Treadmills.setRunning) ne concerne qu'elle
	local weld = run:FindFirstChildOfClass("Weld")
	if weld then
		weld:Destroy()
	end
	run.Anchored = true
	local col = rig:anchor("Root", "ConsoleCollider", cf(0, 2.4, zF + 0.4), v3(W, 4.4, 0.8))
	col.CanCollide = true

	return {
		length = L,
		halfWidth = hw,
		deckY = Y,
		consoleCF = consoleCF,
		consoleTop = (consoleCF * cf(0, 0.55, 0)).Position,
		posts = posts,
		frontCorners = { v3(hw - 0.25, 1.1, zF + 0.1), v3(-(hw - 0.25), 1.1, zF + 0.1) },
		rearCorners = { v3(hw - 0.25, 0.8, zB - 0.3), v3(-(hw - 0.25), 0.8, zB - 0.3) },
	}
end

return Base
