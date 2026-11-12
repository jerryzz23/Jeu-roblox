--!strict
--[[
	CreatureForge.Map — la carte du jeu
	==================================
	Un canyon low-poly creusé dans un plateau. En haut, la place des bases (8 parcelles avec
	bâtiment néon « BASE », enclos et tapis d'entraînement). Depuis l'entrée (lanternes, clôtures),
	un large CHEMIN EN PENTE descend au fond du canyon : on descend facilement, mais remonter la
	pente vide l'endurance (à 0, le joueur est très lent et vulnérable). Plus on descend loin,
	plus les personnages sont rares :

	  1. LA SURFACE            Communs & Rares          herbe, sapins, statue du Renard
	  2. LA PENTE BRUMEUSE     Rares & Épiques          brume violette, améthystes, statue du Kirin
	  3. LES GROTTES DE CRISTAL Légendaires & Mythiques  cristaux bleus, arches, statue du Léviathan
	  4. L'ABYSSE PROFOND      Exotiques & Exclusifs    lave, cristaux rouges, statue du Rhinocéros
	  Tout au bout : portail du Néant, îles flottantes et dragon d'aurore dans le ciel.

	Repère : le haut de la pente est à l'origine, la pente descend vers -Z, les bases sont en +Z.

	    local carte = CreatureForge.Map.build({ parent = workspace })
	    local d = CreatureForge.Map.distanceOf(joueur.Position)   -- 0 (haut) -> 1 (tout au bout)
	    local def, mutations = CreatureForge.rollSpawn(d)          -- apparition selon la distance
	    CreatureForge.Map.pathCFrame(d, x)                         -- point sur le chemin
	    CreatureForge.Map.isClimbing(vitesse)                      -- le joueur remonte-t-il la pente ?

	Les pièces du chemin portent le tag "Pente" et l'attribut Zone (1 à 4).
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

Map.LENGTH = 640 -- longueur de la pente (studs)
Map.PATH_WIDTH = 34 -- largeur du chemin
Map.FLOOR_WIDTH = 96 -- largeur du fond du canyon
Map.DROP = 0.12 -- descente (studs par stud parcouru, environ 7°)
Map.PLOTS = 8 -- nombre de bases

export type Zone = {
	id: string,
	label: string,
	sub: string,
	from: number, -- distance relative de début (0..1)
	to: number,
	color: Color3,
}

Map.ZONES = {
	{ id = "Surface", label = "1. LA SURFACE", sub = "Communs & Rares", from = 0, to = 0.25, color = rgb(140, 230, 100) },
	{ id = "PenteBrumeuse", label = "2. LA PENTE BRUMEUSE", sub = "Rares & Épiques", from = 0.25, to = 0.5, color = rgb(180, 110, 255) },
	{ id = "GrottesCristal", label = "3. LES GROTTES DE CRISTAL", sub = "Légendaires & Mythiques", from = 0.5, to = 0.78, color = rgb(80, 180, 255) },
	{ id = "Abysse", label = "4. L'ABYSSE PROFOND", sub = "Exotiques & Exclusifs", from = 0.78, to = 1, color = rgb(255, 90, 50) },
} :: { Zone }

--- Hauteur du sol du canyon à `dist` studs de l'entrée.
local function fy(dist: number): number
	return -Map.DROP * math.max(dist, 0)
end

--- Point du fond du canyon (x latéral, dist le long du tapis, up au-dessus du sol).
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

--- Distance relative (0 = entrée, 1 = tout au bout) d'une position monde.
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
	return v.Z > 1 -- vers +Z = vers le haut de la pente
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

local ROCK = {
	{ rgb(150, 138, 126), rgb(128, 118, 108), rgb(108, 100, 92) }, -- Surface : roche beige-gris
	{ rgb(120, 108, 138), rgb(100, 90, 118), rgb(82, 74, 100) }, -- Pente : gris violet
	{ rgb(92, 104, 140), rgb(74, 86, 120), rgb(58, 68, 100) }, -- Grottes : bleu ardoise
	{ rgb(96, 64, 62), rgb(76, 50, 50), rgb(56, 38, 40) }, -- Abysse : roche brûlée
}
local GROUND = {
	S(rgb(108, 176, 74), M.Grass),
	S(rgb(92, 84, 112), M.Slate),
	S(rgb(54, 66, 104), M.Slate),
	S(rgb(48, 34, 34), M.Basalt),
}
local CAP = { S(rgb(98, 168, 70), M.Grass), S(rgb(84, 120, 80), M.Grass), nil, nil }
local PINE = { S(rgb(40, 110, 60)), S(rgb(56, 138, 70)), S(rgb(30, 90, 52)) }
local TRUNK = S(rgb(110, 74, 46), M.Wood)
local WOOD = S(rgb(140, 92, 52), M.Wood)
local WOOD_DARK = S(rgb(104, 66, 38), M.Wood)

local COLLIDE = {
	PathStone = true, Ground = true, Rock = true, RockCap = true, Rim = true, Plaza = true, Path = true,
	Border = true, Pedestal = true, PlotFloor = true, Building = true, Roof = true, Fence = true,
	FencePost = true, Pillar = true, Island = true, EndPlatform = true, GatePillar = true, Lantern = true,
}

local function zoneIndex(dist: number): number
	local d = dist / Map.LENGTH
	for i, z in Map.ZONES do
		if d < z.to then
			return i
		end
	end
	return #Map.ZONES
end

local function pine(rig: Rig, g: string, base: Vector3, h: number, rng: Random)
	rig:cylinder(g, "Trunk", base - v3(0, 0.3, 0), base + v3(0, h * 0.3, 0), h * 0.09, TRUNK)
	local tiers = if h > 9 then 3 else 2
	for k = 0, tiers - 1 do
		local w = h * (0.55 - k * 0.14)
		rig:thorn(g, "Pine", cf(base + v3(0, h * (0.22 + k * 0.24), 0)) * ang(0, rng:NextNumber(0, math.pi), 0), w, h * (0.42 - k * 0.06), PINE[(k % #PINE) + 1])
	end
end

local function rock(rig: Rig, g: string, pos: Vector3, size: Vector3, color: Color3, rng: Random)
	rig:block(g, "Rock", cf(pos) * ang(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, math.pi), rng:NextNumber(-0.15, 0.15)), size, S(color, M.Slate))
end

--- Panneau de zone : planche sur deux poteaux + texte (SurfaceGui).
local function sign(rig: Rig, g: string, pos: Vector3, title: string, sub: string, color: Color3)
	for _, s in { 1, -1 } do
		rig:block(g, "SignPost", cf(pos + v3(s * 5, 2.5, 0)), v3(0.6, 5, 0.6), WOOD_DARK)
	end
	local board = rig:block(g, "SignBoard", cf(pos + v3(0, 5.6, 0)), v3(12, 3.6, 0.4), S(rgb(28, 30, 44)))
	rig:block(g, "SignFrame", cf(pos + v3(0, 7.45, 0)), v3(12.2, 0.18, 0.5), S(color, M.Neon))
	rig:block(g, "SignFrame", cf(pos + v3(0, 3.75, 0)), v3(12.2, 0.18, 0.5), S(color, M.Neon))
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(480, 144)
	gui.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.RichText = true
	t.TextScaled = true
	t.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	t.TextColor3 = Color3.new(1, 1, 1)
	local hex = string.format("#%02X%02X%02X", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
	t.Text = `{title}<br/><font color="{hex}" size="34">{sub}</font>`
	t.Parent = gui
	gui.Parent = board
end

--- Statue de pierre d'une créature sur un piédestal (modèle du jeu, recoloré et ancré).
local function statue(rig: Rig, g: string, module: Instance, pos: Vector3, yaw: number, scale: number, stone: Color3, glow: Color3)
	rig:cylinder(g, "Pedestal", pos - v3(0, 0.5, 0), pos + v3(0, 2.0, 0), 9 + scale * 2, S(stone:Lerp(Color3.new(0, 0, 0), 0.25), M.Slate))
	rig:cylinder(g, "PedestalTrim", pos + v3(0, 2.0, 0), pos + v3(0, 2.3, 0), 9.4 + scale * 2, S(glow, M.Neon))
	local def: any = require(module :: any)
	local m: Model = def.build({ cframe = cf(pos + v3(0, 2.3, 0)) * ang(0, yaw, 0), scale = scale, effects = false, animated = false, outline = false, detail = 0.2 })
	local folder = rig:folderFor(g)
	for _, d in m:GetDescendants() do
		local inAura = d.Parent ~= nil and string.sub(d.Parent.Name, 1, 4) == "Aura"
		-- les tout petits détails (dents, rivets, poils fins) ne se voient pas sur une statue
		local tiny = d:IsA("BasePart") and d.Size.Magnitude < 0.22 * scale
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

--- Construit toute la carte. opts : cframe (pivot), parent, effects (particules, défaut true),
--- statues (défaut true), treadmills (tapis d'entraînement dans les bases, défaut true).
function Map.build(opts: { cframe: CFrame?, parent: Instance?, effects: boolean?, statues: boolean?, treadmills: boolean? }?): Model
	local o = opts or {}
	local rig = Kit.newRig("Carte", { cframe = o.cframe, animated = false, outline = false, effects = o.effects ~= false })
	local function group(name: string): string
		rig.bones[name] = rig.root
		return name
	end
	local gPath, gCanyon, gBases, gEnd, gSigns, gStatues = group("Pente"), group("Canyon"), group("Bases"), group("Bout"), group("Panneaux"), group("Statues")
	local gZone = { group("Zone1_Surface"), group("Zone2_PenteBrumeuse"), group("Zone3_GrottesCristal"), group("Zone4_Abysse") }
	local L, BW, FW = Map.LENGTH, Map.PATH_WIDTH, Map.FLOOR_WIDTH
	local rng = Random.new(2026)
	local creatures = script.Parent:FindFirstChild("Creatures")

	-- ===================================================================
	-- Chemin en pente : dalles par zone, marches, bordures de pierre, lampadaires colorés
	-- ===================================================================
	local PATH = {
		S(rgb(178, 126, 82), M.Ground), -- terre battue
		S(rgb(118, 106, 132), M.Cobblestone), -- pavés violets
		S(rgb(86, 100, 136), M.Slate), -- dalles bleues
		S(rgb(58, 42, 42), M.Basalt), -- basalte
	}
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
		-- Marches : arêtes de pierre en travers du chemin
		for k = 0, 4 do
			rig:block(gPath, "Step", c * cf(0, 0.52, -SEG / 2 + 4 + k * 8), v3(BW - 1, 0.08, 0.7), S(rgb(150, 140, 130):Lerp(zc, 0.15), M.Slate))
		end
		if zi == 4 then
			for k = 0, 1 do
				local p0 = v3(rng:NextNumber(-12, 12), 0.53, rng:NextNumber(-16, 16))
				local p1 = p0 + v3(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
				rig:block(gPath, "LavaCrack", c * CFrame.lookAt(p0:Lerp(p1, 0.5), p1), v3(0.4, 0.06, (p1 - p0).Magnitude), S(rgb(255, 110, 30), M.Neon))
			end
		end
		for _, s in { 1, -1 } do
			rig:block(gPath, "Border", c * cf(s * (BW / 2 + 0.75), 0.25, 0), v3(1.5, 1.5, len + 0.05), S(rgb(130, 126, 120):Lerp(ROCK[zi][2], 0.5), M.Slate))
			-- Sol du canyon de chaque côté du chemin
			local w = (FW - BW) / 2 - 1.5
			rig:block(gCanyon, "Ground", c * cf(s * (BW / 2 + 1.5 + w / 2), 0, 0), v3(w, 1, len + 0.05), GROUND[zi])
			-- Lampadaire aux couleurs de la zone
			local lp = (c * cf(s * (BW / 2 + 2.5), 0.5, 0)).Position
			rig:block(gPath, "LampPost", cf(lp + v3(0, 3, 0)), v3(0.5, 6, 0.5), S(rgb(60, 58, 64), M.Metal))
			local orb = rig:ball(gPath, "LampOrb", lp + v3(0, 6.4, 0), 1.2, S(zc, M.Neon))
			if rig.effects and i % 2 == 0 then
				Fx.light(orb, { color = zc, range = 18, brightness = 1.2 }, 1)
			end
		end
	end

	-- ===================================================================
	-- Falaises en terrasses, rebord du plateau, sapins
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
				local col = ROCK[zi][rng:NextInteger(1, 3)]
				rock(rig, gCanyon, v3(s * (xin + 6), (top + floor - 2) / 2, -dist), v3(13, math.max(h, 1), STEP + 2), col, rng)
				local cap = CAP[zi]
				if cap and h > 3 then
					rig:block(gCanyon, "RockCap", cf(s * (xin + 6), top + 0.35, -dist) * ang(0, rng:NextNumber(-0.06, 0.06), 0), v3(13.4, 0.8, STEP + 2.4), cap)
				end
				-- Sapins sur les terrasses des deux premières zones
				if zi <= 2 and k >= 1 and k <= 2 and h > 4 and rng:NextNumber() < 0.35 then
					pine(rig, gZone[zi], v3(s * (xin + rng:NextNumber(3, 9)), top + 0.7, -dist + rng:NextNumber(-5, 5)), rng:NextNumber(7, 12), rng)
				end
			end
		end
		dist += STEP
	end
	-- Plateau (rebord du canyon), avec sapins
	for i = 0, 11 do
		local z0 = -40 - i * 64
		for _, s in { 1, -1 } do
			rig:block(gCanyon, "Rim", cf(s * 150, -1, z0 + 32), v3(140, 2, 64.5), S(rgb(112, 178, 80), M.Grass))
			for _ = 1, 4 do
				pine(rig, gCanyon, v3(s * rng:NextNumber(84, 210), 0, z0 + rng:NextNumber(0, 64)), rng:NextNumber(9, 15), rng)
			end
		end
	end

	-- ===================================================================
	-- Zone 1 — La Surface : clôtures le long du haut de la pente, buissons, rochers, sapins, statue
	-- ===================================================================
	do
		local g = gZone[1]
		local z1 = Map.ZONES[1]
		for _, s in { 1, -1 } do
			local x = s * (BW / 2 + 3.5)
			local prev: Vector3? = nil
			local d = 0
			while d <= 64 do
				local p = at(x, d)
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
		for _ = 1, 18 do
			local s = if rng:NextNumber() < 0.5 then 1 else -1
			local d = rng:NextNumber(10, z1.to * L - 10)
			pine(rig, g, at(s * rng:NextNumber(26, 44), d), rng:NextNumber(8, 13), rng)
		end
		for _ = 1, 22 do
			local s = if rng:NextNumber() < 0.5 then 1 else -1
			local d = rng:NextNumber(4, z1.to * L)
			rig:ball(g, "Bush", at(s * rng:NextNumber(21, 44), d, 0.6), rng:NextNumber(2, 3.6), S(rgb(70, 150, 70), M.Grass))
		end
		for _ = 1, 12 do
			local s = if rng:NextNumber() < 0.5 then 1 else -1
			rock(rig, g, at(s * rng:NextNumber(22, 44), rng:NextNumber(4, z1.to * L), 0.6), v3(rng:NextNumber(2, 4), rng:NextNumber(1.2, 2.4), rng:NextNumber(2, 4)), ROCK[1][2], rng)
		end
		for _ = 1, 30 do
			local s = if rng:NextNumber() < 0.5 then 1 else -1
			local col = if rng:NextNumber() < 0.5 then rgb(255, 150, 200) else rgb(255, 230, 90)
			rig:ball(g, "Flower", at(s * rng:NextNumber(20, 44), rng:NextNumber(2, z1.to * L), 0.3), 0.6, S(col))
		end
		if o.statues ~= false and creatures and creatures:FindFirstChild("RenardDesCendres") then
			statue(rig, gStatues, creatures:FindFirstChild("RenardDesCendres") :: Instance, at(-31, 92), rad(-30), 2.6, rgb(232, 230, 226), z1.color)
		end
		sign(rig, gSigns, at(28, 10), z1.label, z1.sub, z1.color)
	end

	-- ===================================================================
	-- Zone 2 — La Pente Brumeuse : brume violette, améthystes, statue du Kirin
	-- ===================================================================
	do
		local g = gZone[2]
		local z = Map.ZONES[2]
		local amethyst = { S(rgb(180, 100, 255), M.Neon), S(rgb(120, 60, 200), M.Glass, { transparency = 0.15 }), S(rgb(220, 170, 255), M.Neon) }
		for i = 1, 16 do
			local s = if i % 2 == 0 then 1 else -1
			cluster(rig, g, at(s * rng:NextNumber(22, 44), rng:NextNumber(z.from * L + 6, z.to * L - 6)), rng:NextInteger(4, 7), rng:NextNumber(2.5, 4.5), amethyst, 100 + i)
		end
		for _ = 1, 10 do
			local s = if rng:NextNumber() < 0.5 then 1 else -1
			pine(rig, g, at(s * rng:NextNumber(26, 44), rng:NextNumber(z.from * L, z.to * L)), rng:NextNumber(8, 12), rng)
		end
		for _ = 1, 10 do
			local s = if rng:NextNumber() < 0.5 then 1 else -1
			rock(rig, g, at(s * rng:NextNumber(22, 44), rng:NextNumber(z.from * L, z.to * L), 0.8), v3(rng:NextNumber(3, 5), rng:NextNumber(1.5, 3), rng:NextNumber(3, 5)), ROCK[2][2], rng)
		end
		if rig.effects then
			for i = 0, 7 do
				for _, s in { 1, -1 } do
					local fx = rig:anchor(g, "FX_Mist", cf(at(s * 30, z.from * L + 10 + i * 19, 2)), v3(30, 4, 18))
					Fx.particles(fx, Fx.mist("PurpleMist", { rgb(200, 150, 255), rgb(120, 80, 190) }, 4, 9, 0.1), 1)
				end
			end
		end
		if o.statues ~= false and creatures and creatures:FindFirstChild("KirinCeleste") then
			statue(rig, gStatues, creatures:FindFirstChild("KirinCeleste") :: Instance, at(-31, z.from * L + 70), rad(-35), 2.4, rgb(150, 120, 190), z.color)
		end
		sign(rig, gSigns, at(28, z.from * L + 4), z.label, z.sub, z.color)
	end

	-- ===================================================================
	-- Zone 3 — Les Grottes de Cristal : grands cristaux bleus, arches, statue du Léviathan
	-- ===================================================================
	do
		local g = gZone[3]
		local z = Map.ZONES[3]
		local blue = { S(rgb(100, 200, 255), M.Neon), S(rgb(60, 130, 230), M.Glass, { transparency = 0.15 }), S(rgb(190, 235, 255), M.Neon), S(rgb(40, 90, 200), M.Glass, { transparency = 0.1 }) }
		for i = 1, 20 do
			local s = if i % 2 == 0 then 1 else -1
			cluster(rig, g, at(s * rng:NextNumber(22, 46), rng:NextNumber(z.from * L + 4, z.to * L - 4)), rng:NextInteger(5, 8), rng:NextNumber(4, 8), blue, 200 + i)
		end
		-- Arches de cristal au-dessus du tapis
		for k = 1, 3 do
			local dist0 = z.from * L + k * (z.to - z.from) * L / 4
			local center = at(0, dist0)
			for j = 0, 12 do
				local a = j / 12 * math.pi
				local p = center + v3(math.cos(a) * (BW / 2 + 5), math.sin(a) * 22, 0)
				local out = v3(math.cos(a), math.sin(a), 0)
				rig:shard(g, "ArchCrystal", A.alongUp(p, out) * ang(0, rng:NextNumber(0, math.pi), 0), 1.8, 4.5, 1.8, blue[(j % #blue) + 1])
			end
		end
		if rig.effects then
			for i = 0, 5 do
				local fx = rig:anchor(g, "FX_CrystalGlow", cf(at(0, z.from * L + 15 + i * 30, 6)), v3(60, 8, 20))
				Fx.particles(fx, Fx.sparkles("CrystalMotes", { rgb(200, 240, 255), rgb(80, 170, 255) }, 6, 0.8), 1)
				Fx.light(fx, { color = rgb(90, 180, 255), range = 40, brightness = 1.5 }, 1)
			end
		end
		if o.statues ~= false and creatures and creatures:FindFirstChild("LeviathanDesSables") then
			statue(rig, gStatues, creatures:FindFirstChild("LeviathanDesSables") :: Instance, at(-32, z.from * L + 80), rad(-40), 1.6, rgb(70, 84, 120), z.color)
		end
		sign(rig, gSigns, at(28, z.from * L + 4), z.label, z.sub, z.color)
	end

	-- ===================================================================
	-- Zone 4 — L'Abysse Profond : lave, cascades de feu, cristaux rouges, statue du Rhinocéros
	-- ===================================================================
	do
		local g = gZone[4]
		local z = Map.ZONES[4]
		local red = { S(rgb(255, 70, 50), M.Neon), S(rgb(180, 30, 30), M.Glass, { transparency = 0.15 }), S(rgb(255, 170, 90), M.Neon) }
		local lava = S(rgb(255, 110, 30), M.Neon)
		for i = 1, 10 do
			local s = if i % 2 == 0 then 1 else -1
			local p = at(s * rng:NextNumber(26, 42), rng:NextNumber(z.from * L + 8, L - 8), 0.55)
			rig:block(g, "LavaPool", cf(p) * ang(0, rng:NextNumber(0, math.pi), 0), v3(rng:NextNumber(8, 14), 0.1, rng:NextNumber(6, 10)), lava)
		end
		-- Cascades de lave sur les falaises
		for i = 1, 6 do
			local s = if i % 2 == 0 then 1 else -1
			local d = z.from * L + i * 22
			local floor = fy(d)
			rig:block(g, "LavaFall", cf(s * (FW / 2 + 0.6), floor / 2, -d), v3(0.4, -floor, 5), lava)
		end
		for i = 1, 14 do
			local s = if i % 2 == 0 then 1 else -1
			cluster(rig, g, at(s * rng:NextNumber(22, 46), rng:NextNumber(z.from * L, L)), rng:NextInteger(4, 7), rng:NextNumber(3, 6), red, 300 + i)
		end
		for _ = 1, 12 do
			local s = if rng:NextNumber() < 0.5 then 1 else -1
			rig:thorn(g, "BasaltSpike", cf(at(s * rng:NextNumber(22, 46), rng:NextNumber(z.from * L, L))), rng:NextNumber(2, 4), rng:NextNumber(5, 10), S(rgb(40, 28, 30), M.Basalt))
		end
		if rig.effects then
			for i = 0, 4 do
				local fx = rig:anchor(g, "FX_Embers", cf(at(0, z.from * L + 10 + i * 30, 3)), v3(80, 4, 24))
				Fx.particles(fx, Fx.embers("Embers", { rgb(255, 220, 120), rgb(255, 80, 20) }, 12, 0.5), 1)
				Fx.light(fx, { color = rgb(255, 90, 40), range = 40, brightness = 1.6 }, 1)
			end
		end
		if o.statues ~= false and creatures and creatures:FindFirstChild("RhinocerosDObsidienne") then
			statue(rig, gStatues, creatures:FindFirstChild("RhinocerosDObsidienne") :: Instance, at(-30, z.from * L + 60), rad(-25), 2.8, rgb(70, 44, 44), z.color)
		end
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
		-- Îles flottantes
		local islands = {
			{ v3(-40, 34, -L - 90), 26 }, { v3(36, 44, -L - 130), 32 }, { v3(-10, 62, -L - 200), 44 },
			{ v3(70, 30, -L - 60), 18 }, { v3(-80, 50, -L - 150), 22 }, { v3(20, 80, -L - 300), 30 },
		}
		local biggest = islands[3]
		for i, isl in islands do
			local p, r = isl[1] :: Vector3, isl[2] :: number
			local top = p + v3(0, fy(L), 0)
			rig:block(gEnd, "Island", cf(top - v3(0, 1, 0)) * ang(0, i, 0), v3(r, 2, r * 0.8), S(rgb(110, 176, 80), M.Grass))
			rig:thorn(gEnd, "IslandRock", cf(top - v3(0, 1.8, 0)) * ang(math.pi, i * 0.7, 0), r * 0.85, r * 0.9, S(ROCK[1][2], M.Slate))
			for _ = 1, math.floor(r / 10) do
				pine(rig, gEnd, top + v3(rng:NextNumber(-r * 0.3, r * 0.3), 0, rng:NextNumber(-r * 0.25, r * 0.25)), rng:NextNumber(6, 10), rng)
			end
		end
		if o.statues ~= false and creatures and creatures:FindFirstChild("DragonDAurore") then
			local p = (biggest[1] :: Vector3) + v3(0, fy(L), 0)
			statue(rig, gStatues, creatures:FindFirstChild("DragonDAurore") :: Instance, p, rad(0), 4.2, rgb(70, 80, 120), rgb(160, 120, 255))
		end
	end

	-- ===================================================================
	-- Les bases : place, allée, 8 parcelles (bâtiment « BASE », enclos, tapis d'entraînement)
	-- ===================================================================
	do
		local g = gBases
		rig:block(g, "Plaza", cf(0, -1, 115), v3(220, 2, 230), S(rgb(112, 178, 80), M.Grass))
		rig:block(g, "Path", cf(0, 0.02, 112), v3(BW - 6, 0.1, 224), S(rgb(176, 124, 80), M.Ground))
		-- Entrée : piliers à lanternes et clôtures
		for _, s in { 1, -1 } do
			local p = v3(s * (BW / 2 + 3), 0, 4)
			rig:block(g, "Pillar", cf(p + v3(0, 2.5, 0)), v3(4, 5, 4), S(rgb(170, 166, 158), M.Slate))
			rig:block(g, "Lantern", cf(p + v3(0, 6.2, 0)), v3(2.6, 2.4, 2.6), WOOD_DARK)
			local glass = rig:block(g, "LanternGlow", cf(p + v3(0, 6.2, 0)), v3(2.0, 1.8, 2.7), S(rgb(255, 210, 120), M.Neon))
			rig:thorn(g, "LanternRoof", cf(p + v3(0, 7.4, 0)) * ang(0, math.pi / 4, 0), 3.4, 1.4, WOOD_DARK)
			if rig.effects then
				Fx.light(glass, { color = rgb(255, 200, 120), range = 22, brightness = 2 }, 1)
			end
			for k = 0, 4 do
				local x0 = s * (BW / 2 + 5 + k * 6)
				rig:block(g, "FencePost", cf(x0, 1.6, 4), v3(0.6, 3.2, 0.6), WOOD_DARK)
				for _, h in { 1.2, 2.4 } do
					rig:block(g, "Fence", cf(x0 + s * 3, h, 4), v3(6.3, 0.35, 0.3), WOOD)
				end
			end
		end
		-- Parcelles
		local plotIndex = 0
		local treadmill: any = nil
		if o.treadmills ~= false then
			local tm = script.Parent:FindFirstChild("Treadmills")
			if tm then
				treadmill = require(tm :: any)
			end
		end
		for row = 0, Map.PLOTS / 2 - 1 do
			for _, s in { -1, 1 } do
				plotIndex += 1
				local center = v3(s * 46, 0, 32 + row * 44)
				local plot = Instance.new("Model")
				plot.Name = "Base" .. plotIndex
				plot:SetAttribute("PlotIndex", plotIndex)
				plot:SetAttribute("Owner", "")
				local before = #rig:folderFor(g):GetChildren()
				rig:block(g, "PlotFloor", cf(center + v3(0, 0.1, 0)), v3(40, 0.3, 40), S(rgb(150, 156, 168), M.Concrete))
				rig:block(g, "PlotBorder", cf(center + v3(0, 0.02, 0)), v3(40.6, 0.25, 40.6), S(rgb(70, 160, 255), M.Neon))
				-- Bâtiment au fond de la parcelle (côté extérieur), façade vers l'allée
				local bx = center.X + s * 14
				rig:block(g, "Building", cf(bx, 7, center.Z), v3(12, 14, 30), S(rgb(176, 174, 170), M.Slate))
				rig:block(g, "Roof", cf(bx, 14.6, center.Z), v3(13.4, 1.2, 31.4), S(rgb(92, 96, 110), M.Slate))
				for _, h in { 14.0, 0.6 } do
					rig:block(g, "BuildingNeon", cf(bx - s * 6.05, h, center.Z), v3(0.2, 0.4, 30.2), S(rgb(70, 170, 255), M.Neon))
				end
				for k = -1, 1, 2 do
					rig:block(g, "BuildingNeon", cf(bx - s * 6.05, 7, center.Z + k * 15), v3(0.25, 14, 0.4), S(rgb(70, 170, 255), M.Neon))
					rig:block(g, "Window", cf(bx - s * 6.06, 8, center.Z + k * 9), v3(0.2, 4, 5), S(rgb(120, 200, 255), M.Glass, { transparency = 0.2 }))
				end
				rig:block(g, "Door", cf(bx - s * 6.06, 3, center.Z), v3(0.2, 6, 5), S(rgb(40, 60, 90)))
				local board = rig:block(g, "BaseSign", cf(bx - s * 6.4, 11, center.Z), v3(0.5, 3, 12), S(rgb(20, 22, 32)))
				rig:block(g, "BaseSignNeon", cf(bx - s * 6.5, 11, center.Z), v3(0.3, 3.4, 12.4), S(rgb(70, 170, 255), M.Neon))
				local gui = Instance.new("SurfaceGui")
				gui.Name = "Text"
				gui.Face = if s > 0 then Enum.NormalId.Left else Enum.NormalId.Right
				gui.CanvasSize = Vector2.new(400, 100)
				gui.LightInfluence = 0
				local t = Instance.new("TextLabel")
				t.Name = "Owner"
				t.Size = UDim2.fromScale(1, 1)
				t.BackgroundTransparency = 1
				t.TextScaled = true
				t.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
				t.TextColor3 = Color3.new(1, 1, 1)
				t.Text = "BASE"
				t.Parent = gui
				gui.Parent = board
				-- Enclos (côté allée, à l'avant de la parcelle)
				local ex, ez, ew, el = center.X - s * 10, center.Z - 5, 16, 26
				rig:block(g, "PenGrass", cf(ex, 0.3, ez), v3(ew, 0.2, el), S(rgb(104, 180, 76), M.Grass))
				for k = 0, 4 do
					local z = ez - el / 2 + k * el / 4
					for _, xx in { ex - ew / 2, ex + ew / 2 } do
						rig:block(g, "FencePost", cf(xx, 1.4, z), v3(0.5, 2.8, 0.5), WOOD_DARK)
					end
				end
				for _, xx in { ex - ew / 2, ex + ew / 2 } do
					for _, h in { 1.0, 2.1 } do
						rig:block(g, "Fence", cf(xx, h, ez), v3(0.3, 0.3, el), WOOD)
					end
				end
				for _, zz in { ez - el / 2, ez + el / 2 } do
					for _, h in { 1.0, 2.1 } do
						rig:block(g, "Fence", cf(ex, h, zz), v3(ew, 0.3, 0.3), WOOD)
					end
				end
				-- Emplacement du tapis d'entraînement (à l'arrière, bien visible depuis l'allée)
				rig:block(g, "TreadmillPad", cf(center.X - s * 8, 0.32, center.Z + 13.5), v3(6, 0.15, 11), S(rgb(70, 170, 255), M.Neon, { transparency = 0.5 }))
				-- Tout ce qui vient d'être créé pour cette parcelle passe dans son modèle
				local folder = rig:folderFor(g)
				local kids = folder:GetChildren()
				for i = before + 1, #kids do
					kids[i].Parent = plot
				end
				plot.Parent = folder
				-- Tapis d'entraînement (entre l'enclos et le bâtiment)
				if treadmill then
					local tcf = cf(center.X - s * 8, 0.4, center.Z + 13.5)
					local tmodel = treadmill.get("TapisEntrainement").build({ cframe = tcf, outline = false, effects = rig.effects })
					tmodel.Name = "Tapis"
					tmodel.Parent = plot
				end
			end
		end
		-- Point d'apparition au bout de l'allée
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "SpawnLocation"
		spawn.Anchored = true
		spawn.Size = v3(12, 1, 12)
		spawn.CFrame = rig.origin * cf(0, 0.5, 200)
		spawn.Color = rgb(70, 170, 255)
		spawn.Material = M.Neon
		spawn.Transparency = 0.2
		spawn.Duration = 0
		spawn.Parent = rig:folderFor(g)
	end

	-- ===================================================================
	-- Finalisation : tout est ancré (aucune soudure), collisions selon le type de pièce
	-- ===================================================================
	for _, d in rig.model:GetDescendants() do
		if d:IsA("BasePart") then
			for _, w in d:GetChildren() do
				if w:IsA("Weld") and w.Part0 == rig.root then
					w:Destroy()
				end
			end
			if d ~= rig.root and not d:IsA("SpawnLocation") then
				local inTreadmill = d:FindFirstAncestor("Tapis") ~= nil
				if not inTreadmill then
					d.Anchored = true
					d.Massless = false
					d.CanCollide = COLLIDE[d.Name] == true
					d.CanQuery = d.CanCollide
					d.CanTouch = d.Name == "PathStone"
				end
			end
		end
	end
	local bones = rig.model:FindFirstChild("Bones")
	if bones then
		bones:Destroy()
	end
	local count = 0
	for _, d in rig.model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			count += 1
		end
	end
	rig.model:SetAttribute("PartCount", count)
	rig.model:SetAttribute("Length", Map.LENGTH)
	rig.model.Parent = o.parent
	return rig.model
end

return Map
