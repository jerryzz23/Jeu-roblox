--!strict
--[[
	CreatureForge.Map — la carte du jeu
	==================================
	EN HAUT, les bases (style Roblox) : un grand champ vert, 8 enclos à clôtures colorées (un par
	joueur, avec son tapis d'entraînement, ses places pour les créatures et son panneau), une
	rangée de stands à auvents rayés (VENDRE, SERINGUES, TAPIS DE COURSE, GRATUIT !, ROUE) et la
	ligne « ZONE SÛRE » : dans les bases, personne ne peut te frapper.

	PUIS la pente du canyon (pas de tapis roulant) : on descend facilement, mais remonter vide
	l'endurance (à 0, le joueur est très lent et vulnérable). Plus on descend, plus c'est rare :

	  1. LA SURFACE          Communs       herbe, sapins, statue du Renard
	  2. LE DÉSERT           Rares         sable, pyramide, cactus, statue du Léviathan
	  3. LA PENTE BRUMEUSE   Épiques       brume violette, améthystes, statue du Kirin
	  4. LE GLACIER          Légendaires   neige, glace, sapins enneigés, statue du Lynx
	  5. LES GROTTES DE CRISTAL Mythiques  cristaux bleus, arches, statue du Mammouth
	  6. L'ABYSSE PROFOND    Exotiques     lave, cascades de feu, statue du Rhinocéros
	  7. LE CIEL ÉTOILÉ      Exclusifs     nuit étoilée, obélisques d'or, statue du Sphinx
	  8. LE NÉANT            Chaotique     vide et glitch, statue du Néant Couronné
	  Tout au bout : portail du Néant, îles flottantes et dragon d'aurore dans le ciel.

	Repère : le haut de la pente est à l'origine, la pente descend vers -Z, les bases sont en +Z.

	    local carte = CreatureForge.Map.build({ parent = workspace })
	    local d = CreatureForge.Map.distanceOf(joueur.Position)   -- 0 (haut) -> 1 (tout au bout)
	    local def, mutations = CreatureForge.rollSpawn(d)          -- apparition selon la distance
	    CreatureForge.Map.isClimbing(vitesse)                      -- remonte la pente ? (endurance)
	    CreatureForge.Map.isSafe(joueur.Position)                  -- dans la zone sûre des bases ?

	Les pièces du chemin portent le tag "Pente" et l'attribut Zone (1 à 8) ; chaque enclos est un
	modèle "Base<N>" (attributs PlotIndex, Owner) ; le tableau de la boutique de seringues est
	une pièce "StockBoard" (texte mis à jour par le script serveur).
]]

local Kit = require(script.Parent.Kit)
local A = require(script.Parent.Anatomy)
local Fx = require(script.Parent.Fx)

local S = Kit.style
local M = Enum.Material
local rgb = Color3.fromRGB
local rad = math.rad
local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles

type Rig = Kit.Rig

local Map = {}

Map.LENGTH = 960 -- longueur de la pente (studs)
Map.PATH_WIDTH = 34 -- largeur du chemin
Map.FLOOR_WIDTH = 96 -- largeur du fond du canyon
Map.DROP = 0.1 -- descente (studs par stud parcouru, environ 6°)
Map.SAFE_Z = 8 -- au-delà (vers +Z), on est dans la zone sûre des bases
Map.PLOTS = 8 -- nombre de bases

export type Zone = {
	id: string,
	label: string,
	sub: string,
	from: number, -- distance relative de début (0..1)
	to: number,
	color: Color3,
}

local function zone(i: number, id: string, label: string, sub: string, color: Color3): Zone
	return { id = id, label = label, sub = sub, from = (i - 1) / 8, to = i / 8, color = color }
end

Map.ZONES = {
	zone(1, "Surface", "1. LA SURFACE", "Communs", rgb(140, 230, 100)),
	zone(2, "Desert", "2. LE DÉSERT", "Rares", rgb(255, 205, 110)),
	zone(3, "PenteBrumeuse", "3. LA PENTE BRUMEUSE", "Épiques", rgb(180, 110, 255)),
	zone(4, "Glacier", "4. LE GLACIER", "Légendaires", rgb(170, 230, 255)),
	zone(5, "GrottesCristal", "5. LES GROTTES DE CRISTAL", "Mythiques", rgb(80, 150, 255)),
	zone(6, "Abysse", "6. L'ABYSSE PROFOND", "Exotiques", rgb(255, 90, 50)),
	zone(7, "CielEtoile", "7. LE CIEL ÉTOILÉ", "Exclusifs", rgb(255, 205, 70)),
	zone(8, "Neant", "8. LE NÉANT", "Chaotique", rgb(255, 50, 170)),
} :: { Zone }

--- Hauteur du sol du canyon à `dist` studs du haut de la pente.
local function fy(dist: number): number
	return -Map.DROP * math.max(dist, 0)
end

--- Point du fond du canyon (x latéral, dist le long de la pente, up au-dessus du sol).
local function at(x: number, dist: number, up: number?): Vector3
	return v3(x, fy(dist) + (up or 0), -dist)
end

function Map.zoneOf(d: number): Zone
	for _, z in Map.ZONES do
		if d < z.to then
			return z
		end
	end
	return Map.ZONES[#Map.ZONES]
end

--- Distance relative (0 = haut de la pente, 1 = tout au bout) d'une position monde.
function Map.distanceOf(pos: Vector3, pivot: CFrame?): number
	local p = (pivot or CFrame.identity):PointToObjectSpace(pos)
	return math.clamp(-p.Z / Map.LENGTH, 0, 1)
end

--- Point sur le chemin à la distance relative `d`, décalé de `x`, tourné vers le bas (-Z).
function Map.pathCFrame(d: number, x: number?): CFrame
	local dist = math.clamp(d, 0, 1) * Map.LENGTH
	local p = at(x or 0, dist)
	return CFrame.lookAt(p, at(x or 0, dist + 1))
end

--- Vrai si un déplacement de vitesse `velocity` remonte la pente (vers les bases) :
--- c'est là que l'endurance se vide.
function Map.isClimbing(velocity: Vector3, pivot: CFrame?): boolean
	local v = (pivot or CFrame.identity):VectorToObjectSpace(velocity)
	return v.Z > 1
end

--- Vrai si la position est dans la zone sûre des bases (on ne peut pas y être frappé).
function Map.isSafe(pos: Vector3, pivot: CFrame?): boolean
	return (pivot or CFrame.identity):PointToObjectSpace(pos).Z > Map.SAFE_Z
end

-- ---------------------------------------------------------------------------
-- Palettes
-- ---------------------------------------------------------------------------

local ROCK = {
	{ rgb(150, 138, 126), rgb(128, 118, 108), rgb(108, 100, 92) }, -- Surface
	{ rgb(214, 170, 110), rgb(190, 146, 92), rgb(160, 120, 76) }, -- Désert : grès
	{ rgb(120, 108, 138), rgb(100, 90, 118), rgb(82, 74, 100) }, -- Pente : gris violet
	{ rgb(200, 214, 230), rgb(170, 186, 206), rgb(140, 156, 180) }, -- Glacier : roche gelée
	{ rgb(92, 104, 140), rgb(74, 86, 120), rgb(58, 68, 100) }, -- Grottes : bleu ardoise
	{ rgb(96, 64, 62), rgb(76, 50, 50), rgb(56, 38, 40) }, -- Abysse : roche brûlée
	{ rgb(54, 52, 80), rgb(42, 40, 64), rgb(30, 28, 50) }, -- Ciel étoilé : nuit
	{ rgb(30, 22, 40), rgb(22, 16, 30), rgb(14, 10, 20) }, -- Néant : noir violet
}
local GROUND = {
	S(rgb(108, 176, 74), M.Grass),
	S(rgb(236, 206, 140), M.Sand),
	S(rgb(92, 84, 112), M.Slate),
	S(rgb(240, 246, 252), M.Snow),
	S(rgb(54, 66, 104), M.Slate),
	S(rgb(48, 34, 34), M.Basalt),
	S(rgb(30, 30, 56), M.Slate),
	S(rgb(12, 8, 18)),
}
local PATH = {
	S(rgb(178, 126, 82), M.Ground),
	S(rgb(222, 184, 120), M.Sandstone),
	S(rgb(118, 106, 132), M.Cobblestone),
	S(rgb(200, 226, 240), M.Ice),
	S(rgb(86, 100, 136), M.Slate),
	S(rgb(58, 42, 42), M.Basalt),
	S(rgb(40, 38, 66), M.Slate),
	S(rgb(20, 14, 30)),
}
local CAP = { S(rgb(98, 168, 70), M.Grass), S(rgb(240, 214, 150), M.Sand), S(rgb(84, 120, 80), M.Grass), S(rgb(248, 250, 255), M.Snow), nil, nil, nil, nil }
local PINE = { S(rgb(40, 110, 60)), S(rgb(56, 138, 70)), S(rgb(30, 90, 52)) }
local TRUNK = S(rgb(110, 74, 46), M.Wood)
local WOOD = S(rgb(140, 92, 52), M.Wood)
local WOOD_DARK = S(rgb(104, 66, 38), M.Wood)

local COLLIDE = {
	PathStone = true, Ground = true, Rock = true, RockCap = true, Rim = true, Field = true, Lane = true,
	Border = true, Pedestal = true, Fence = true, FencePost = true, Pillar = true, Island = true,
	EndPlatform = true, GatePillar = true, Counter = true, StandPole = true, Pyramid = true,
	Cactus = true, Obelisk = true, WheelStand = true, GiftBox = true,
}

local function zoneIndex(dist: number): number
	return math.clamp(math.floor(dist / Map.LENGTH * 8) + 1, 1, 8)
end

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

-- ---------------------------------------------------------------------------
-- Éléments de décor
-- ---------------------------------------------------------------------------

local function pine(rig: Rig, g: string, base: Vector3, h: number, rng: Random, snow: boolean?)
	rig:cylinder(g, "Trunk", base - v3(0, 0.3, 0), base + v3(0, h * 0.3, 0), h * 0.09, TRUNK)
	local tiers = if h > 9 then 3 else 2
	for k = 0, tiers - 1 do
		local w = h * (0.55 - k * 0.14)
		local c = cf(base + v3(0, h * (0.22 + k * 0.24), 0)) * ang(0, rng:NextNumber(0, math.pi), 0)
		rig:thorn(g, "Pine", c, w, h * (0.42 - k * 0.06), PINE[(k % #PINE) + 1])
		if snow then
			rig:thorn(g, "PineSnow", c * cf(0, h * 0.2, 0), w * 0.55, h * 0.22, S(rgb(250, 252, 255), M.Snow))
		end
	end
end

local function rock(rig: Rig, g: string, pos: Vector3, size: Vector3, color: Color3, rng: Random, mat: Enum.Material?)
	rig:block(g, "Rock", cf(pos) * ang(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, math.pi), rng:NextNumber(-0.15, 0.15)), size, S(color, mat or M.Slate))
end

--- Texte sur une face de pièce (SurfaceGui).
local function label(part: BasePart, face: Enum.NormalId, text: string, color: Color3?, canvas: Vector2?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = face
	gui.CanvasSize = canvas or Vector2.new(480, 144)
	gui.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Name = "Label"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.RichText = true
	t.TextScaled = true
	t.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.Text = text
	t.Parent = gui
	gui.Parent = part
end

--- Panneau de zone : planche sur deux poteaux + texte.
local function sign(rig: Rig, g: string, pos: Vector3, title: string, sub: string, color: Color3)
	for _, s in { 1, -1 } do
		rig:block(g, "SignPost", cf(pos + v3(s * 5, 2.5, 0)), v3(0.6, 5, 0.6), WOOD_DARK)
	end
	local board = rig:block(g, "SignBoard", cf(pos + v3(0, 5.6, 0)), v3(12, 3.6, 0.4), S(rgb(28, 30, 44)))
	rig:block(g, "SignFrame", cf(pos + v3(0, 7.45, 0)), v3(12.2, 0.18, 0.5), S(color, M.Neon))
	rig:block(g, "SignFrame", cf(pos + v3(0, 3.75, 0)), v3(12.2, 0.18, 0.5), S(color, M.Neon))
	label(board, Enum.NormalId.Back, `{title}<br/><font color="{hex(color)}" size="34">{sub}</font>`)
end

--- Statue de pierre d'une créature sur un piédestal (modèle du jeu, recoloré et ancré).
local function statue(rig: Rig, g: string, module: Instance?, pos: Vector3, yaw: number, scale: number, stone: Color3, glow: Color3)
	if not module then
		return
	end
	rig:cylinder(g, "Pedestal", pos - v3(0, 0.5, 0), pos + v3(0, 2.0, 0), 9 + scale * 2, S(stone:Lerp(Color3.new(0, 0, 0), 0.25), M.Slate))
	rig:cylinder(g, "PedestalTrim", pos + v3(0, 2.0, 0), pos + v3(0, 2.3, 0), 9.4 + scale * 2, S(glow, M.Neon))
	local def: any = require(module :: any)
	if def.build == nil and def[1] then
		def = def[1] -- module à plusieurs variétés (Néant Couronné) : la première
	end
	local m: Model = def.build({ cframe = cf(pos + v3(0, 2.3, 0)) * ang(0, yaw, 0), scale = scale, effects = false, animated = false, outline = false, detail = 0.2 })
	local folder = rig:folderFor(g)
	for _, d in m:GetDescendants() do
		local inAura = d.Parent ~= nil and string.sub(d.Parent.Name, 1, 4) == "Aura"
		-- les tout petits détails (dents, rivets, poils fins) ne se voient pas sur une statue
		local tiny = d:IsA("BasePart") and d.Size.Magnitude < 0.34 * scale
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "Root" and not inAura and not tiny then
			local lum = 0.299 * d.Color.R + 0.587 * d.Color.G + 0.114 * d.Color.B
			if d.Material == M.Neon then
				d.Color = glow
			else
				d.Color = stone:Lerp(Color3.new(1, 1, 1), lum * 0.35):Lerp(Color3.new(0, 0, 0), (1 - lum) * 0.25)
				d.Material = M.Slate
				d.Transparency = 0
			end
			for _, w in d:GetChildren() do
				if w:IsA("JointInstance") then
					w:Destroy()
				end
			end
			d.Name = "Statue"
			d.Parent = folder
		end
	end
	m:Destroy()
end

local function cluster(rig: Rig, g: string, pos: Vector3, count: number, size: number, styles: { Kit.Style }, seed: number)
	A.crystals(rig, g, cf(pos), count, size, styles, seed, 0.5)
end

--- Côté aléatoire : position latérale sur le sol du canyon, hors du chemin.
local function side(rng: Random): number
	return (if rng:NextNumber() < 0.5 then 1 else -1) * rng:NextNumber(22, 44)
end

--- Stand de boutique style Roblox : comptoir, 4 poteaux, auvent rayé incliné, grande enseigne.
local function stand(rig: Rig, g: string, pos: Vector3, title: string, c1: Color3, c2: Color3, facing: number?): BasePart
	local base = cf(pos) * ang(0, facing or 0, 0)
	local W, D = 12, 7
	rig:block(g, "Counter", base * cf(0, 1.6, -D / 2 + 1), v3(W, 3.2, 1.6), S(rgb(250, 250, 250)))
	rig:block(g, "CounterTop", base * cf(0, 3.3, -D / 2 + 1), v3(W + 0.4, 0.3, 2), S(c1))
	for _, x in { -W / 2 + 0.4, W / 2 - 0.4 } do
		for _, z in { -D / 2 + 0.4, D / 2 - 0.4 } do
			rig:block(g, "StandPole", base * cf(x, 3.6, z), v3(0.5, 7.2, 0.5), S(rgb(240, 240, 240)))
		end
	end
	-- Auvent : bandes alternées inclinées vers l'avant
	local n = 8
	for k = 0, n - 1 do
		local x = -W / 2 + (k + 0.5) * W / n
		rig:block(g, "Awning", base * cf(x, 7.6, 0) * ang(rad(14), 0, 0), v3(W / n + 0.02, 0.3, D + 1.2), S(if k % 2 == 0 then c1 else c2))
		rig:wedge(g, "AwningFlap", base * cf(x, 6.85, -D / 2 - 0.75) * ang(math.pi, 0, 0), v3(W / n + 0.02, 0.8, 0.5), S(if k % 2 == 0 then c1 else c2))
	end
	local board = rig:block(g, "StandSign", base * cf(0, 9.7, 0), v3(W, 2.6, 0.4), S(c1))
	rig:block(g, "StandSignFrame", base * cf(0, 9.7, 0.02), v3(W + 0.4, 3.0, 0.3), S(rgb(30, 30, 40)))
	label(board, Enum.NormalId.Front, `<b>{title}</b>`, Color3.new(1, 1, 1))
	label(board, Enum.NormalId.Back, `<b>{title}</b>`, Color3.new(1, 1, 1))
	return board
end

--- Clôture style Roblox entre deux points : poteaux réguliers + 2 lisses, ou croisillons en X.
local function fence(rig: Rig, g: string, a: Vector3, b: Vector3, color: Color3, xStyle: boolean)
	local len = (b - a).Magnitude
	local n = math.max(1, math.floor(len / 5 + 0.5))
	local postStyle = S(color:Lerp(Color3.new(0, 0, 0), 0.2))
	local railStyle = S(color)
	for k = 0, n do
		local p = a:Lerp(b, k / n)
		rig:block(g, "FencePost", cf(p + v3(0, 1.5, 0)), v3(0.7, 3, 0.7), postStyle)
	end
	local mid = (a + b) / 2
	local look = CFrame.lookAt(mid, b)
	if xStyle then
		rig:block(g, "Fence", look * cf(0, 2.7, 0), v3(0.35, 0.4, len), railStyle)
		rig:block(g, "Fence", look * cf(0, 0.4, 0), v3(0.35, 0.4, len), railStyle)
		for k = 0, n - 1 do
			local p0, p1 = a:Lerp(b, k / n), a:Lerp(b, (k + 1) / n)
			for _, ys in { { 0.5, 2.6 }, { 2.6, 0.5 } } do
				local q0, q1 = p0 + v3(0, ys[1], 0), p1 + v3(0, ys[2], 0)
				rig:block(g, "Fence", CFrame.lookAt((q0 + q1) / 2, q1), v3(0.3, 0.3, (q1 - q0).Magnitude), railStyle)
			end
		end
	else
		for _, h in { 1.1, 2.3 } do
			rig:block(g, "Fence", look * cf(0, h, 0), v3(0.35, 0.5, len), railStyle)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

--- Construit toute la carte. opts : cframe (pivot), parent, effects (particules, défaut true),
--- statues (défaut true), treadmills (tapis d'entraînement dans les bases, défaut true).
function Map.build(opts: { cframe: CFrame?, parent: Instance?, effects: boolean?, statues: boolean?, treadmills: boolean? }?): Model
	local o = opts or {}
	local rig = Kit.newRig("Carte", { cframe = o.cframe, animated = false, outline = false, effects = o.effects ~= false })
	local function group(name: string): string
		rig.bones[name] = rig.root
		return name
	end
	local gPath, gCanyon, gBases, gShops, gEnd, gSigns, gStatues = group("Pente"), group("Canyon"), group("Bases"), group("Boutiques"), group("Bout"), group("Panneaux"), group("Statues")
	local gZone = {}
	for i, z in Map.ZONES do
		gZone[i] = group(`Zone{i}_{z.id}`)
	end
	local L, BW, FW = Map.LENGTH, Map.PATH_WIDTH, Map.FLOOR_WIDTH
	local rng = Random.new(2026)
	local creatures = script.Parent:FindFirstChild("Creatures")
	local function creature(name: string): Instance?
		return if creatures and o.statues ~= false then creatures:FindFirstChild(name) else nil
	end

	-- ===================================================================
	-- Chemin en pente : dalles par zone, marches, bordures de pierre, lampadaires colorés
	-- ===================================================================
	local SEG = 40
	for i = 0, L / SEG - 1 do
		local d0, d1 = i * SEG, (i + 1) * SEG
		local zi = zoneIndex(d0 + 1)
		local zc = Map.ZONES[zi].color
		local a, b = at(0, d0, -0.5), at(0, d1, -0.5)
		local c = CFrame.lookAt((a + b) / 2, b)
		local len = (b - a).Magnitude
		local slab = rig:block(gPath, "PathStone", c, v3(BW, 1, len + 0.05), PATH[zi])
		slab:SetAttribute("Zone", zi)
		slab:AddTag("Pente")
		for k = 0, 4 do
			rig:block(gPath, "Step", c * cf(0, 0.52, -SEG / 2 + 4 + k * 8), v3(BW - 1, 0.08, 0.7), S(rgb(150, 140, 130):Lerp(zc, 0.25), M.Slate))
		end
		if zi == 6 then
			for _ = 1, 2 do
				local p0 = v3(rng:NextNumber(-12, 12), 0.53, rng:NextNumber(-16, 16))
				local p1 = p0 + v3(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
				rig:block(gPath, "LavaCrack", c * CFrame.lookAt(p0:Lerp(p1, 0.5), p1), v3(0.4, 0.06, (p1 - p0).Magnitude), S(rgb(255, 110, 30), M.Neon))
			end
		elseif zi == 8 then
			for k = -1, 1 do
				rig:block(gPath, "GlitchLine", c * cf(k * 10, 0.53, 0), v3(0.25, 0.06, len), S(if k == 0 then rgb(255, 0, 140) else rgb(0, 255, 230), M.Neon))
			end
		end
		for _, s in { 1, -1 } do
			rig:block(gPath, "Border", c * cf(s * (BW / 2 + 0.75), 0.25, 0), v3(1.5, 1.5, len + 0.05), S(rgb(130, 126, 120):Lerp(ROCK[zi][2], 0.6), M.Slate))
			local w = (FW - BW) / 2 - 1.5
			rig:block(gCanyon, "Ground", c * cf(s * (BW / 2 + 1.5 + w / 2), 0, 0), v3(w, 1, len + 0.05), GROUND[zi])
			local lp = (c * cf(s * (BW / 2 + 2.5), 0.5, 0)).Position
			rig:block(gPath, "LampPost", cf(lp + v3(0, 3, 0)), v3(0.5, 6, 0.5), S(rgb(60, 58, 64), M.Metal))
			local orb = rig:ball(gPath, "LampOrb", lp + v3(0, 6.4, 0), 1.2, S(zc, M.Neon))
			if rig.effects and i % 2 == 0 then
				Fx.light(orb, { color = zc, range = 18, brightness = 1.2 }, 1)
			end
		end
	end

	-- ===================================================================
	-- Falaises en terrasses + plateau
	-- ===================================================================
	local STEP = 16
	local dist = -24
	while dist <= L + 40 do
		local zi = zoneIndex(math.clamp(dist, 0, L - 1))
		local floor = fy(dist)
		local depth = -floor
		for _, s in { 1, -1 } do
			for k = 0, 3 do
				local top = floor + depth * (k + 1) / 4 + (if k < 3 then rng:NextNumber(-1.5, 1.5) else 0)
				local xin = FW / 2 + k * 8
				local h = top - (floor - 2)
				rock(rig, gCanyon, v3(s * (xin + 6), (top + floor - 2) / 2, -dist), v3(13, math.max(h, 1), STEP + 2), ROCK[zi][rng:NextInteger(1, 3)], rng)
				local cap = CAP[zi]
				if cap and h > 3 then
					rig:block(gCanyon, "RockCap", cf(s * (xin + 6), top + 0.35, -dist) * ang(0, rng:NextNumber(-0.06, 0.06), 0), v3(13.4, 0.8, STEP + 2.4), cap)
				end
				if (zi == 1 or zi == 3 or zi == 4) and k >= 1 and k <= 2 and h > 4 and rng:NextNumber() < 0.3 then
					pine(rig, gZone[zi], v3(s * (xin + rng:NextNumber(3, 9)), top + 0.7, -dist + rng:NextNumber(-5, 5)), rng:NextNumber(7, 12), rng, zi == 4)
				end
			end
		end
		dist += STEP
	end
	for i = 0, 16 do
		local z0 = -40 - i * 64
		for _, s in { 1, -1 } do
			local zi = zoneIndex(math.clamp(-z0 - 32, 0, L - 1))
			local snowy = zi == 4
			rig:block(gCanyon, "Rim", cf(s * 150, -1, z0 + 32), v3(140, 2, 64.5), if snowy then S(rgb(244, 248, 255), M.Snow) elseif zi == 2 then S(rgb(232, 200, 130), M.Sand) else S(rgb(112, 178, 80), M.Grass))
			if zi ~= 2 and zi < 6 then
				for _ = 1, 3 do
					pine(rig, gCanyon, v3(s * rng:NextNumber(84, 210), 0, z0 + rng:NextNumber(0, 64)), rng:NextNumber(9, 15), rng, snowy)
				end
			end
		end
	end

	-- ===================================================================
	-- Les 8 zones
	-- ===================================================================
	local function span(i: number): (number, number)
		return Map.ZONES[i].from * L, Map.ZONES[i].to * L
	end

	-- 1. La Surface
	do
		local g, z = gZone[1], Map.ZONES[1]
		local d0, d1 = span(1)
		for _, s in { 1, -1 } do
			local prev: Vector3? = nil
			local d = 0
			while d <= 48 do
				local p = at(s * (BW / 2 + 3.5), d)
				rig:block(g, "FencePost", cf(p + v3(0, 1.6, 0)), v3(0.6, 3.2, 0.6), WOOD_DARK)
				if prev then
					for _, hgt in { 1.2, 2.4 } do
						local a0, a1 = prev + v3(0, hgt, 0), p + v3(0, hgt, 0)
						rig:block(g, "Fence", CFrame.lookAt((a0 + a1) / 2, a1), v3(0.3, 0.35, (a1 - a0).Magnitude + 0.3), WOOD)
					end
				end
				prev = p
				d += 8
			end
		end
		for _ = 1, 12 do
			pine(rig, g, at(side(rng), rng:NextNumber(d0 + 10, d1 - 6)), rng:NextNumber(8, 13), rng)
		end
		for _ = 1, 16 do
			rig:ball(g, "Bush", at(side(rng), rng:NextNumber(d0 + 4, d1), 0.6), rng:NextNumber(2, 3.6), S(rgb(70, 150, 70), M.Grass))
		end
		for _ = 1, 24 do
			rig:ball(g, "Flower", at(side(rng), rng:NextNumber(d0 + 2, d1), 0.3), 0.6, S(if rng:NextNumber() < 0.5 then rgb(255, 150, 200) else rgb(255, 230, 90)))
		end
		statue(rig, gStatues, creature("RenardDesCendres"), at(-31, d0 + 70), rad(-30), 2.6, rgb(232, 230, 226), z.color)
	end

	-- 2. Le Désert : sable, pyramide à gradins, cactus, rochers de grès
	do
		local g, z = gZone[2], Map.ZONES[2]
		local d0, d1 = span(2)
		local sand = { S(rgb(232, 196, 128), M.Sandstone), S(rgb(214, 176, 112), M.Sandstone) }
		local base = at(32, d0 + 70)
		for k = 0, 6 do
			local w = 22 - k * 3
			rig:block(g, "Pyramid", cf(base + v3(0, 1 + k * 2, 0)), v3(w, 2, w), sand[(k % 2) + 1])
		end
		rig:block(g, "Pyramid", cf(base + v3(0, 15, 0)), v3(2, 2, 2), S(rgb(255, 210, 90), M.Neon))
		for _ = 1, 14 do
			local p = at(side(rng), rng:NextNumber(d0 + 6, d1 - 6))
			local h = rng:NextNumber(4, 8)
			local cactus = S(rgb(70, 150, 80), M.Grass)
			rig:cylinder(g, "Cactus", p, p + v3(0, h, 0), 1.3, cactus)
			rig:ball(g, "Cactus", p + v3(0, h, 0), 1.3, cactus)
			for _, s in { 1, -1 } do
				if rng:NextNumber() < 0.7 then
					local y = h * rng:NextNumber(0.35, 0.6)
					local e = p + v3(s * 1.6, y, 0)
					rig:cylinder(g, "Cactus", p + v3(0, y, 0), e, 0.8, cactus)
					rig:cylinder(g, "Cactus", e, e + v3(0, h * 0.35, 0), 0.8, cactus)
					rig:ball(g, "Cactus", e + v3(0, h * 0.35, 0), 0.8, cactus)
				end
			end
		end
		for _ = 1, 10 do
			rock(rig, g, at(side(rng), rng:NextNumber(d0, d1), 0.8), v3(rng:NextNumber(3, 6), rng:NextNumber(2, 4), rng:NextNumber(3, 6)), ROCK[2][rng:NextInteger(1, 3)], rng, M.Sandstone)
		end
		statue(rig, gStatues, creature("LeviathanDesSables"), at(-32, d0 + 64), rad(-40), 1.6, rgb(214, 176, 120), z.color)
	end

	-- 3. La Pente Brumeuse : brume violette, améthystes
	do
		local g, z = gZone[3], Map.ZONES[3]
		local d0, d1 = span(3)
		local amethyst = { S(rgb(180, 100, 255), M.Neon), S(rgb(120, 60, 200), M.Glass, { transparency = 0.15 }), S(rgb(220, 170, 255), M.Neon) }
		for i = 1, 12 do
			cluster(rig, g, at(side(rng), rng:NextNumber(d0 + 6, d1 - 6)), rng:NextInteger(4, 7), rng:NextNumber(2.5, 4.5), amethyst, 100 + i)
		end
		for _ = 1, 8 do
			pine(rig, g, at(side(rng), rng:NextNumber(d0, d1)), rng:NextNumber(8, 12), rng)
		end
		if rig.effects then
			for i = 0, 5 do
				for _, s in { 1, -1 } do
					local fx = rig:anchor(g, "FX_Mist", cf(at(s * 30, d0 + 10 + i * 19, 2)), v3(30, 4, 18))
					Fx.particles(fx, Fx.mist("PurpleMist", { rgb(200, 150, 255), rgb(120, 80, 190) }, 4, 9, 0.1), 1)
				end
			end
		end
		statue(rig, gStatues, creature("KirinCeleste"), at(-31, d0 + 60), rad(-35), 2.4, rgb(150, 120, 190), z.color)
	end

	-- 4. Le Glacier : neige, cristaux de glace, sapins enneigés, arches de glace
	do
		local g, z = gZone[4], Map.ZONES[4]
		local d0, d1 = span(4)
		local ice = { S(rgb(190, 235, 255), M.Glass, { transparency = 0.2 }), S(rgb(220, 248, 255), M.Ice), S(rgb(140, 210, 255), M.Neon) }
		for i = 1, 12 do
			cluster(rig, g, at(side(rng), rng:NextNumber(d0 + 6, d1 - 6)), rng:NextInteger(4, 7), rng:NextNumber(3, 5), ice, 150 + i)
		end
		for _ = 1, 12 do
			pine(rig, g, at(side(rng), rng:NextNumber(d0, d1)), rng:NextNumber(8, 13), rng, true)
		end
		for _ = 1, 10 do
			rig:ball(g, "SnowMound", at(side(rng), rng:NextNumber(d0, d1), 0.2), rng:NextNumber(3, 5), S(rgb(248, 250, 255), M.Snow))
		end
		for k = 1, 2 do
			local center = at(0, d0 + k * (d1 - d0) / 3)
			for j = 0, 10 do
				local a = j / 10 * math.pi
				local p = center + v3(math.cos(a) * (BW / 2 + 4), math.sin(a) * 18, 0)
				rig:shard(g, "IceArch", A.alongUp(p, v3(math.cos(a), math.sin(a), 0)), 2, 4, 2, ice[(j % 3) + 1])
			end
		end
		if rig.effects then
			for i = 0, 3 do
				local fx = rig:anchor(g, "FX_Snow", cf(at(0, d0 + 15 + i * 28, 14)), v3(90, 2, 26))
				Fx.particles(fx, Fx.sparkles("Snow", { rgb(255, 255, 255), rgb(210, 235, 255) }, 14, 0.6, -2), 1)
			end
		end
		statue(rig, gStatues, creature("LynxDeGivre"), at(-30, d0 + 60), rad(-30), 4.2, rgb(220, 232, 244), z.color)
	end

	-- 5. Les Grottes de Cristal : grands cristaux bleus, arches de cristal
	do
		local g, z = gZone[5], Map.ZONES[5]
		local d0, d1 = span(5)
		local blue = { S(rgb(100, 200, 255), M.Neon), S(rgb(60, 130, 230), M.Glass, { transparency = 0.15 }), S(rgb(190, 235, 255), M.Neon), S(rgb(40, 90, 200), M.Glass, { transparency = 0.1 }) }
		for i = 1, 14 do
			cluster(rig, g, at(side(rng), rng:NextNumber(d0 + 4, d1 - 4)), rng:NextInteger(5, 8), rng:NextNumber(4, 8), blue, 200 + i)
		end
		for k = 1, 3 do
			local center = at(0, d0 + k * (d1 - d0) / 4)
			for j = 0, 12 do
				local a = j / 12 * math.pi
				local p = center + v3(math.cos(a) * (BW / 2 + 5), math.sin(a) * 22, 0)
				rig:shard(g, "ArchCrystal", A.alongUp(p, v3(math.cos(a), math.sin(a), 0)) * ang(0, rng:NextNumber(0, math.pi), 0), 1.8, 4.5, 1.8, blue[(j % #blue) + 1])
			end
		end
		if rig.effects then
			for i = 0, 3 do
				local fx = rig:anchor(g, "FX_CrystalGlow", cf(at(0, d0 + 15 + i * 30, 6)), v3(60, 8, 20))
				Fx.particles(fx, Fx.sparkles("CrystalMotes", { rgb(200, 240, 255), rgb(80, 170, 255) }, 6, 0.8), 1)
				Fx.light(fx, { color = rgb(90, 180, 255), range = 40, brightness = 1.5 }, 1)
			end
		end
		statue(rig, gStatues, creature("MammouthRunique"), at(-32, d0 + 64), rad(-35), 2.2, rgb(70, 84, 120), z.color)
	end

	-- 6. L'Abysse Profond : lave, cascades de feu, cristaux rouges, pics de basalte
	do
		local g, z = gZone[6], Map.ZONES[6]
		local d0, d1 = span(6)
		local red = { S(rgb(255, 70, 50), M.Neon), S(rgb(180, 30, 30), M.Glass, { transparency = 0.15 }), S(rgb(255, 170, 90), M.Neon) }
		local lava = S(rgb(255, 110, 30), M.Neon)
		for _ = 1, 8 do
			rig:block(g, "LavaPool", cf(at((if rng:NextNumber() < 0.5 then 1 else -1) * rng:NextNumber(26, 42), rng:NextNumber(d0 + 8, d1 - 8), 0.55)) * ang(0, rng:NextNumber(0, math.pi), 0), v3(rng:NextNumber(8, 14), 0.1, rng:NextNumber(6, 10)), lava)
		end
		for i = 1, 6 do
			local d = d0 + i * 18
			local floor = fy(d)
			local s = if i % 2 == 0 then 1 else -1
			rig:block(g, "LavaFall", cf(s * (FW / 2 + 0.6), floor / 2, -d), v3(0.4, -floor, 5), lava)
		end
		for i = 1, 10 do
			cluster(rig, g, at(side(rng), rng:NextNumber(d0, d1)), rng:NextInteger(4, 7), rng:NextNumber(3, 6), red, 300 + i)
		end
		for _ = 1, 10 do
			rig:thorn(g, "BasaltSpike", cf(at(side(rng), rng:NextNumber(d0, d1))), rng:NextNumber(2, 4), rng:NextNumber(5, 10), S(rgb(40, 28, 30), M.Basalt))
		end
		if rig.effects then
			for i = 0, 3 do
				local fx = rig:anchor(g, "FX_Embers", cf(at(0, d0 + 10 + i * 30, 3)), v3(80, 4, 24))
				Fx.particles(fx, Fx.embers("Embers", { rgb(255, 220, 120), rgb(255, 80, 20) }, 12, 0.5), 1)
				Fx.light(fx, { color = rgb(255, 90, 40), range = 40, brightness = 1.6 }, 1)
			end
		end
		statue(rig, gStatues, creature("RhinocerosDObsidienne"), at(-30, d0 + 60), rad(-25), 2.8, rgb(70, 44, 44), z.color)
	end

	-- 7. Le Ciel Étoilé : sol de nuit, obélisques d'or, anneaux flottants, étoiles
	do
		local g, z = gZone[7], Map.ZONES[7]
		local d0, d1 = span(7)
		local gold = S(rgb(255, 204, 64), M.Metal, { reflectance = 0.1 })
		for k = 0, 5 do
			for _, s in { 1, -1 } do
				local p = at(s * 24, d0 + 10 + k * 20)
				rig:block(g, "Obelisk", cf(p + v3(0, 5, 0)), v3(2.4, 10, 2.4), S(rgb(24, 22, 44)))
				rig:thorn(g, "ObeliskTip", cf(p + v3(0, 10, 0)), 2.6, 2.2, gold)
				rig:block(g, "ObeliskGlyph", cf(p + v3(-s * 1.22, 6, 0)), v3(0.1, 4, 0.8), S(rgb(255, 214, 90), M.Neon))
			end
		end
		for _ = 1, 50 do
			rig:ball(g, "Star", at(side(rng), rng:NextNumber(d0, d1), rng:NextNumber(0.3, 30)), rng:NextNumber(0.3, 0.8), S(if rng:NextNumber() < 0.7 then rgb(255, 255, 255) else rgb(255, 220, 120), M.Neon))
		end
		for k = 1, 4 do
			local p = at(side(rng), d0 + k * 25, rng:NextNumber(12, 22))
			rig:ring(g, "FloatingRing", cf(p) * ang(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0), rng:NextNumber(3, 5), 0.3, 0.4, 24, gold)
		end
		if rig.effects then
			for i = 0, 3 do
				local fx = rig:anchor(g, "FX_Stars", cf(at(0, d0 + 15 + i * 30, 12)), v3(90, 16, 28))
				Fx.particles(fx, Fx.sparkles("StarDust", { rgb(255, 255, 255), rgb(255, 220, 120) }, 10, 0.6, 0.2), 1)
				Fx.light(fx, { color = rgb(255, 210, 120), range = 40, brightness = 1.2 }, 1)
			end
		end
		statue(rig, gStatues, creature("SphinxStellaire"), at(-31, d0 + 64), rad(-30), 2.2, rgb(60, 60, 110), z.color)
	end

	-- 8. Le Néant : vide, lignes glitch, cubes flottants, cristaux noirs
	do
		local g, z = gZone[8], Map.ZONES[8]
		local d0, d1 = span(8)
		local glitch = { S(rgb(255, 0, 140), M.Neon), S(rgb(0, 255, 230), M.Neon), S(rgb(255, 255, 255), M.Neon), S(rgb(20, 10, 30)) }
		for _ = 1, 24 do
			local p = at(side(rng), rng:NextNumber(d0, d1), rng:NextNumber(2, 26))
			rig:block(g, "GlitchCube", cf(p) * ang(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), v3(1, 1, 1) * rng:NextNumber(1, 3), glitch[rng:NextInteger(1, 4)])
		end
		for i = 1, 10 do
			cluster(rig, g, at(side(rng), rng:NextNumber(d0, d1)), rng:NextInteger(4, 7), rng:NextNumber(3, 6), { glitch[4], glitch[1], glitch[2] }, 500 + i)
		end
		if rig.effects then
			for i = 0, 3 do
				local fx = rig:anchor(g, "FX_Glitch", cf(at(0, d0 + 15 + i * 30, 6)), v3(80, 10, 26))
				Fx.particles(fx, Fx.sparkles("Glitch", { rgb(255, 0, 140), rgb(0, 255, 230), rgb(255, 255, 255) }, 10, 0.6), 1)
				Fx.light(fx, { color = rgb(255, 40, 160), range = 40, brightness = 1.4 }, 1)
			end
		end
		statue(rig, gStatues, creature("NeantCouronne"), at(-30, d0 + 60), rad(-30), 1.8, rgb(40, 30, 60), z.color)
	end

	for i, z in Map.ZONES do
		sign(rig, gSigns, at(28, z.from * L + 4), z.label, z.sub, z.color)
	end

	-- ===================================================================
	-- Tout au bout : plateforme, portail du Néant, îles flottantes, dragon d'aurore
	-- ===================================================================
	do
		local endP = at(0, L, 0)
		rig:block(gEnd, "EndPlatform", cf(endP + v3(0, -0.5, -20)), v3(FW, 1, 40), S(rgb(30, 22, 34), M.Basalt))
		local glitch = { S(rgb(255, 0, 140), M.Neon), S(rgb(0, 255, 230), M.Neon), S(rgb(255, 255, 255), M.Neon), S(rgb(120, 0, 255), M.Neon) }
		for _, s in { 1, -1 } do
			local p = endP + v3(s * (BW / 2 + 4), 0, -26)
			rig:block(gEnd, "GatePillar", cf(p + v3(0, 14, 0)), v3(5, 28, 5), S(rgb(24, 18, 30), M.Basalt))
			rig:block(gEnd, "GateNeon", cf(p + v3(-s * 2.55, 14, 0)), v3(0.2, 26, 1.2), glitch[if s > 0 then 1 else 2])
			cluster(rig, gEnd, p + v3(0, 28, 0), 6, 4, glitch, 400 + s)
		end
		rig:block(gEnd, "GateLintel", cf(endP + v3(0, 29, -26)), v3(BW + 14, 3, 5), S(rgb(24, 18, 30), M.Basalt))
		rig:ring(gEnd, "VoidPortal", cf(endP + v3(0, 13, -27)), 11, 1.2, 1, 32, S(rgb(150, 60, 255), M.Neon))
		rig:cylinder(gEnd, "VoidDisc", endP + v3(0, 13, -27.3), endP + v3(0, 13, -27.6), 21, S(rgb(14, 6, 28), M.Neon))
		sign(rig, gSigns, endP + v3(26, 0, -8), "TOUT AU BOUT", "Chaotique : 1 sur 1 000 000", rgb(255, 60, 200))
		local islands = {
			{ v3(-40, 34, -L - 90), 26 }, { v3(36, 44, -L - 130), 32 }, { v3(-10, 62, -L - 200), 44 },
			{ v3(70, 30, -L - 60), 18 }, { v3(-80, 50, -L - 150), 22 }, { v3(20, 80, -L - 300), 30 },
		}
		for i, isl in islands do
			local p, r = isl[1] :: Vector3, isl[2] :: number
			local top = p + v3(0, fy(L), 0)
			rig:block(gEnd, "Island", cf(top - v3(0, 1, 0)) * ang(0, i, 0), v3(r, 2, r * 0.8), S(rgb(110, 176, 80), M.Grass))
			rig:thorn(gEnd, "IslandRock", cf(top - v3(0, 1.8, 0)) * ang(math.pi, i * 0.7, 0), r * 0.85, r * 0.9, S(ROCK[1][2], M.Slate))
			for _ = 1, math.floor(r / 10) do
				pine(rig, gEnd, top + v3(rng:NextNumber(-r * 0.3, r * 0.3), 0, rng:NextNumber(-r * 0.25, r * 0.25)), rng:NextNumber(6, 10), rng)
			end
		end
		statue(rig, gStatues, creature("DragonDAurore"), (islands[3][1] :: Vector3) + v3(0, fy(L), 0), 0, 4.2, rgb(70, 80, 120), rgb(160, 120, 255))
	end

	-- ===================================================================
	-- Les bases (style Roblox) : champ vert, ZONE SÛRE, stands, 8 enclos colorés
	-- ===================================================================
	do
		local g = gBases
		local fieldGreen = S(rgb(98, 196, 74))
		rig:block(g, "Field", cf(0, -1, 125), v3(240, 2, 250), fieldGreen)
		rig:block(g, "Lane", cf(0, 0.02, 120), v3(BW - 6, 0.1, 240), S(rgb(122, 214, 92)))
		-- Ligne « ZONE SÛRE » en travers de l'entrée
		local line = rig:block(g, "SafeLine", cf(0, 0.06, Map.SAFE_Z), v3(130, 0.12, 1.2), S(rgb(255, 255, 255)))
		rig:block(g, "SafeLineGlow", cf(0, 0.05, Map.SAFE_Z), v3(130.4, 0.1, 1.8), S(rgb(90, 180, 255), M.Neon))
		local safeText = rig:block(g, "SafeText", cf(0, 0.07, Map.SAFE_Z + 4), v3(30, 0.1, 6), S(rgb(98, 196, 74)))
		safeText.Transparency = 0.999
		label(safeText, Enum.NormalId.Top, "<b>ZONE SÛRE</b>", Color3.new(1, 1, 1), Vector2.new(600, 120))
		for _, x in { -18, 18 } do
			rig:ball(g, "SafeShield", v3(x, 0.4, Map.SAFE_Z + 4), 1.6, S(rgb(90, 180, 255), M.Neon))
		end
		line.Name = "SafeLine"
		-- Entrée de la pente : piliers à lanternes
		for _, s in { 1, -1 } do
			local p = v3(s * (BW / 2 + 3), 0, 2)
			rig:block(g, "Pillar", cf(p + v3(0, 2.5, 0)), v3(4, 5, 4), S(rgb(170, 166, 158), M.Slate))
			rig:block(g, "Lantern", cf(p + v3(0, 6.2, 0)), v3(2.6, 2.4, 2.6), WOOD_DARK)
			local glow = rig:block(g, "LanternGlow", cf(p + v3(0, 6.2, 0)), v3(2.0, 1.8, 2.7), S(rgb(255, 210, 120), M.Neon))
			rig:thorn(g, "LanternRoof", cf(p + v3(0, 7.4, 0)) * ang(0, math.pi / 4, 0), 3.4, 1.4, WOOD_DARK)
			if rig.effects then
				Fx.light(glow, { color = rgb(255, 200, 120), range = 22, brightness = 2 }, 1)
			end
		end

		-- Stands le long de la zone sûre
		local gs = gShops
		stand(rig, gs, v3(-66, 0, 24), "VENDRE", rgb(230, 40, 50), rgb(255, 255, 255))
		local syr = stand(rig, gs, v3(-34, 0, 24), "SERINGUES", rgb(255, 196, 30), rgb(255, 255, 255))
		syr.Name = "SyringeSign"
		stand(rig, gs, v3(34, 0, 24), "TAPIS DE COURSE", rgb(50, 130, 255), rgb(255, 255, 255))
		stand(rig, gs, v3(66, 0, 24), "GRATUIT !", rgb(60, 200, 80), rgb(255, 255, 255))
		-- Tableau du stock de seringues (texte mis à jour par le serveur)
		local board = rig:block(gs, "StockBoard", cf(-34, 5.6, 20.6), v3(9, 3.4, 0.3), S(rgb(24, 26, 40)))
		board:SetAttribute("Shop", "Syringes")
		label(board, Enum.NormalId.Front, "Stock des seringues<br/>réassort toutes les 5 min", Color3.new(1, 1, 1), Vector2.new(450, 170))
		-- Pièces d'or au stand VENDRE, cadeau au stand GRATUIT
		for k = 0, 5 do
			rig:cylinder(gs, "Coin", v3(-68 + k * 0.4, 3.5 + k * 0.12, 21), v3(-68 + k * 0.4, 3.62 + k * 0.12, 21), 1.2, S(rgb(255, 204, 64), M.Metal))
		end
		rig:block(gs, "GiftBox", cf(66, 4.6, 21), v3(2.4, 2.4, 2.4), S(rgb(230, 60, 160)))
		rig:block(gs, "GiftRibbon", cf(66, 4.6, 21), v3(2.5, 2.5, 0.5), S(rgb(255, 230, 90)))
		rig:block(gs, "GiftRibbon", cf(66, 4.6, 21), v3(0.5, 2.5, 2.5), S(rgb(255, 230, 90)))
		rig:ball(gs, "GiftBow", v3(66, 6.1, 21), 1, S(rgb(255, 230, 90)))
		-- Roue de la chance (os Spin1 : rotation lente)
		do
			local c = v3(0, 9, 36)
			rig:block(gs, "WheelStand", cf(0, 4, 36.8), v3(2, 8, 1), S(rgb(240, 240, 240)))
			rig:block(gs, "WheelStand", cf(0, 0.5, 36.8), v3(8, 1, 4), S(rgb(240, 240, 240)))
			rig:bone("Spin1", "Root", cf(c))
			local motor = rig.root:FindFirstChild("Spin1")
			if motor then
				motor:SetAttribute("Speed", 0.3)
			end
			rig.bones.Spin1:SetAttribute("Map", true)
			local cols = { rgb(255, 70, 70), rgb(255, 170, 40), rgb(255, 240, 70), rgb(70, 230, 110), rgb(60, 170, 255), rgb(170, 90, 255), rgb(255, 120, 200), rgb(20, 20, 24) }
			for k = 0, 15 do
				local a = k / 16 * math.pi * 2
				rig:block("Spin1", "WheelSlice", cf(c) * ang(0, 0, a) * cf(0, 3.2, 0), v3(2.3, 6.2, 0.4), S(cols[(k % #cols) + 1]))
			end
			rig:ring("Spin1", "WheelRim", cf(c), 6.4, 0.5, 0.6, 32, S(rgb(255, 204, 64), M.Metal))
			for k = 0, 15 do
				local a = k / 16 * math.pi * 2
				rig:ball("Spin1", "WheelLight", c + v3(math.cos(a) * 6.5, math.sin(a) * 6.5, -0.4), 0.6, S(rgb(255, 250, 220), M.Neon))
			end
			rig:cylinder("Spin1", "WheelHub", c + v3(0, 0, -0.5), c + v3(0, 0, 0.3), 2, S(rgb(255, 204, 64), M.Metal))
			rig:thorn(gs, "WheelPointer", cf(c + v3(0, 7.6, -0.4)) * ang(math.pi, 0, 0), 1.2, 1.6, S(rgb(230, 40, 50)))
			local wb = rig:block(gs, "StandSign", cf(0, 17.3, 36), v3(10, 2.4, 0.4), S(rgb(170, 90, 255)))
			label(wb, Enum.NormalId.Front, "<b>ROUE</b>", Color3.new(1, 1, 1))
		end

		-- 8 enclos colorés (4 de chaque côté de l'allée), ouverture côté allée
		local FENCE_COLORS = { rgb(150, 92, 50), rgb(245, 245, 245), rgb(60, 190, 255), rgb(170, 90, 255), rgb(255, 150, 40), rgb(255, 110, 180), rgb(255, 220, 60), rgb(70, 210, 120) }
		local treadmill: any = nil
		if o.treadmills ~= false then
			local tm = script.Parent:FindFirstChild("Treadmills")
			if tm then
				treadmill = require(tm :: any)
			end
		end
		local plotIndex = 0
		for row = 0, Map.PLOTS / 2 - 1 do
			for _, s in { -1, 1 } do
				plotIndex += 1
				local center = v3(s * 40, 0, 62 + row * 44)
				local plot = Instance.new("Model")
				plot.Name = "Base" .. plotIndex
				plot:SetAttribute("PlotIndex", plotIndex)
				plot:SetAttribute("Owner", "")
				local folder = rig:folderFor(g)
				local before = #folder:GetChildren()
				local col = FENCE_COLORS[plotIndex]
				local h = 18
				local inner, outer = center.X - s * h, center.X + s * h
				local zA, zB = center.Z - h, center.Z + h
				-- Clôtures : trois côtés pleins, côté allée avec une ouverture de 10 studs
				local xStyle = plotIndex % 2 == 0
				fence(rig, g, v3(outer, 0, zA), v3(outer, 0, zB), col, xStyle)
				fence(rig, g, v3(inner, 0, zA), v3(outer, 0, zA), col, xStyle)
				fence(rig, g, v3(inner, 0, zB), v3(outer, 0, zB), col, xStyle)
				fence(rig, g, v3(inner, 0, zA), v3(inner, 0, center.Z - 5), col, xStyle)
				fence(rig, g, v3(inner, 0, center.Z + 5), v3(inner, 0, zB), col, xStyle)
				-- Places pour les créatures (pastilles)
				for i = 0, 5 do
					local px = center.X + s * (if i < 3 then 2 else 10)
					local pz = center.Z - 10 + (i % 3) * 10
					rig:cylinder(g, "CreatureSlot", v3(px, 0.02, pz), v3(px, 0.22, pz), 6, S(col:Lerp(Color3.new(1, 1, 1), 0.4)))
					rig:cylinder(g, "CreatureSlotRing", v3(px, 0.05, pz), v3(px, 0.18, pz), 6.6, S(col, M.Neon))
				end
				-- Panneau du propriétaire à l'entrée de l'enclos
				local sp = v3(inner - s * 1.5, 0, center.Z + 7)
				rig:block(g, "SignPost", cf(sp + v3(0, 2.5, 0)), v3(0.5, 5, 0.5), WOOD_DARK)
				local nameBoard = rig:block(g, "OwnerSign", cf(sp + v3(0, 5.6, 0)) * ang(0, s * math.pi / 2, 0), v3(7, 2, 0.4), S(col))
				label(nameBoard, Enum.NormalId.Front, "<b>BASE LIBRE</b>", Color3.new(1, 1, 1))
				-- Maisonnette (icône de base)
				local hp = v3(outer - s * 4, 0, zB - 4)
				rig:block(g, "Hut", cf(hp + v3(0, 2, 0)), v3(5, 4, 5), S(rgb(255, 250, 240)))
				rig:block(g, "HutDoor", cf(hp + v3(-s * 2.52, 1.4, 0)), v3(0.1, 2.8, 1.6), S(col:Lerp(Color3.new(0, 0, 0), 0.3)))
				rig:wedge(g, "HutRoof", cf(hp + v3(0, 4.9, 1.4)), v3(5.6, 1.8, 2.8), S(rgb(230, 70, 50)))
				rig:wedge(g, "HutRoof", cf(hp + v3(0, 4.9, -1.4)) * ang(0, math.pi, 0), v3(5.6, 1.8, 2.8), S(rgb(230, 70, 50)))
				local kids = folder:GetChildren()
				for i = before + 1, #kids do
					kids[i].Parent = plot
				end
				plot.Parent = folder
				-- Tapis d'entraînement dans l'enclos (au fond, le coureur tourné vers l'allée)
				if treadmill then
					local tc = v3(outer - s * 5, 0.25, zA + 7)
					local tmodel = treadmill.get("TapisEntrainement").build({ cframe = CFrame.lookAt(tc, tc + v3(-s, 0, 0)), outline = false, effects = rig.effects })
					tmodel.Name = "Tapis"
					tmodel.Parent = plot
				end
			end
		end
		-- Point d'apparition au fond du champ
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "SpawnLocation"
		spawn.Anchored = true
		spawn.Size = v3(12, 1, 12)
		spawn.CFrame = rig.origin * cf(0, 0.5, 232)
		spawn.Color = rgb(70, 170, 255)
		spawn.Material = M.Neon
		spawn.Transparency = 0.2
		spawn.Duration = 0
		spawn.Parent = rig:folderFor(g)
	end

	-- ===================================================================
	-- Finalisation : tout est ancré (aucune soudure), sauf l'os de la roue qui tourne
	-- ===================================================================
	local spinBone = rig.bones.Spin1
	for _, d in rig.model:GetDescendants() do
		if d:IsA("BasePart") and d ~= rig.root and not d:IsA("SpawnLocation") and d:FindFirstAncestor("Tapis") == nil then
			local onWheel = false
			for _, w in d:GetChildren() do
				if w:IsA("Weld") then
					if w.Part0 == spinBone then
						onWheel = true
					elseif w.Part0 == rig.root then
						w:Destroy()
					end
				end
			end
			if d == spinBone then
				onWheel = true
			end
			if not onWheel then
				d.Anchored = true
				d.Massless = false
				d.CanCollide = COLLIDE[d.Name] == true
				d.CanQuery = d.CanCollide
				d.CanTouch = d.Name == "PathStone"
			end
		end
	end
	local count = 0
	for _, d in rig.model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			count += 1
		end
	end
	rig.model:SetAttribute("PartCount", count)
	rig.model:SetAttribute("Length", Map.LENGTH)
	rig.model:SetAttribute("SafeZoneZ", Map.SAFE_Z)
	-- La roue tourne grâce à CreatureAnimator (tag + os Spin)
	rig.model:AddTag(Kit.TAG)
	rig.model.Parent = o.parent
	return rig.model
end

return Map
