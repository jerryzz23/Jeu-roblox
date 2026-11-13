--!strict
--[[
	CreatureForge.Vitrine — tout le contenu du jeu, exposé dans la carte
	====================================================================
	Construit le dossier Workspace.Vitrine :
	  - Creatures : les 30 personnages, chacun dans la zone de sa rareté le long de la pente ;
	  - Tapis     : les 10 tapis de course alignés derrière le point d'apparition ;
	  - Objets    : présentoirs à côté des bases (5 battes, 8 seringues à gauche ; 8 ADN à droite).

	tools/build_place l'enregistre dans dist/CreatureForge.rbxl (tout est visible dès l'ouverture
	dans Roblox Studio) ; le script CreatureShowcase le construit au démarrage s'il manque (Rojo),
	puis fait se promener les personnages.

	    local vitrine = CreatureForge.Vitrine.build(workspace.Carte, workspace)
]]

local Map = require(script.Parent.Map)
local Weapons = require(script.Parent.Weapons)
local Syringes = require(script.Parent.Syringes)
local DnaMachine = require(script.Parent.DnaMachine)
local Treadmills = require(script.Parent.Treadmills)
local Mutations = require(script.Parent.Mutations)
local Rarity = require(script.Parent.Rarity)

local rgb = Color3.fromRGB
local v3 = Vector3.new

local Vitrine = {}

--- Bandes de distance (0 = haut de la pente, 1 = tout au bout) où se promène chaque rareté.
Vitrine.ZONE_D = {
	Common = { 0.02, 0.11 },
	Rare = { 0.14, 0.24 },
	Epic = { 0.27, 0.36 },
	Legendary = { 0.39, 0.49 },
	Mythic = { 0.52, 0.62 },
	Exotic = { 0.64, 0.74 },
	Exclusive = { 0.77, 0.86 },
	Chaotic = { 0.89, 0.98 },
} :: { [string]: { number } }

Vitrine.MUTATION_DEMO = 0.3 -- part des personnages qui reçoivent 1 ou 2 mutations pour la démo

--- Repère de la carte (sa racine), aussi lisible hors de Roblox (Lune n'a pas GetPivot).
local function pivotOf(map: Model): CFrame
	return if map.PrimaryPart then map.PrimaryPart.CFrame else CFrame.identity
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function part(name: string, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material?, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

local function label(p: BasePart, face: Enum.NormalId, text: string, color: Color3?, canvas: Vector2?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = face
	gui.CanvasSize = canvas or Vector2.new(400, 110)
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
	gui.Parent = p
end

--- Les personnages, dans la zone de leur rareté, tournés vers le haut de la pente.
--- `list` = CreatureForge.list(), `spawn` = CreatureForge.spawn (évite une dépendance circulaire).
function Vitrine.creatures(map: Model, parent: Instance, list: { any }, spawn: (string, CFrame?, any) -> Model, seed: number?): Folder
	local out = folder("Creatures", parent)
	local pivot = pivotOf(map)
	local uphill = pivot:VectorToWorldSpace(v3(0, 0, 1))
	local rng = Random.new(seed or 2026)
	local byRarity: { [string]: { any } } = {}
	for _, def in list do
		byRarity[def.Rarity] = byRarity[def.Rarity] or {}
		table.insert(byRarity[def.Rarity], def)
	end
	for rarity, defs in byRarity do
		local band = Vitrine.ZONE_D[rarity] or { 0.05, 0.2 }
		local n = #defs
		local rows = math.ceil(n / 2)
		for i, def in defs do
			-- deux files de part et d'autre du chemin, réparties sur toute la zone
			local row = (i - 1) // 2
			local d = band[1] + (row + 0.5) / rows * (band[2] - band[1])
			local x = (if i % 2 == 1 then -1 else 1) * rng:NextNumber(5, 11)
			local p = (pivot * Map.pathCFrame(d, x)).Position
			local mutations = {}
			if rng:NextNumber() < Vitrine.MUTATION_DEMO then
				for _ = 1, rng:NextInteger(1, 2) do
					local id = Mutations.List[rng:NextInteger(1, #Mutations.List)].id
					if not table.find(mutations, id) then
						table.insert(mutations, id)
					end
				end
			end
			local model = spawn(def.Id, CFrame.lookAt(p, p + uphill), { parent = out, mutations = mutations })
			model:SetAttribute("Home", p)
		end
	end
	return out
end

--- Les 10 tapis de course, alignés sur la place des bases derrière le point d'apparition.
function Vitrine.treadmills(map: Model, parent: Instance): Folder
	local out = folder("Tapis", parent)
	local pivot = pivotOf(map)
	local uphill = pivot:VectorToWorldSpace(v3(0, 0, 1))
	local list = Treadmills.list()
	for i, def in list do
		local pos = pivot * v3((i - (#list + 1) / 2) * 6, 0.1, 218)
		Treadmills.spawn(def.Id, CFrame.lookAt(pos, pos - uphill), { parent = out })
	end
	return out
end

--- Présentoir : socle blanc, liseré coloré, plaque avec le nom (face à l'allée).
local function pedestal(parent: Instance, at: CFrame, title: string, sub: string, color: Color3): CFrame
	local m = Instance.new("Model")
	m.Name = "Presentoir"
	part("Socle", at * CFrame.new(0, 0.9, 0), v3(3.4, 1.8, 3.4), rgb(245, 245, 248), nil, m)
	part("Liseré", at * CFrame.new(0, 1.84, 0), v3(3.6, 0.12, 3.6), color, Enum.Material.Neon, m)
	part("Base", at * CFrame.new(0, 0.1, 0), v3(4, 0.2, 4), rgb(52, 56, 66), nil, m)
	local plate = part("Plaque", at * CFrame.new(0, 0.9, -1.76), v3(3, 1.1, 0.12), color:Lerp(rgb(20, 20, 30), 0.35), nil, m)
	label(plate, Enum.NormalId.Front, `<b>{title}</b><br/><font size="34">{sub}</font>`, Color3.new(1, 1, 1), Vector2.new(300, 110))
	m.Parent = parent
	return at * CFrame.new(0, 1.9, 0)
end

--- Panneau de rangée (planche sur deux poteaux).
local function header(parent: Instance, at: CFrame, text: string, color: Color3)
	for _, s in { -1, 1 } do
		part("Poteau", at * CFrame.new(s * 3.2, 2.5, 0), v3(0.5, 5, 0.5), rgb(110, 70, 40), Enum.Material.Wood, parent)
	end
	local board = part("Panneau", at * CFrame.new(0, 5.3, 0), v3(7.6, 2, 0.4), color, nil, parent)
	label(board, Enum.NormalId.Front, `<b>{text}</b>`)
	label(board, Enum.NormalId.Back, `<b>{text}</b>`)
end

local function anchorRoot(model: Model)
	-- Les objets restent en place : racine ancrée, pièces soudées (rien ne tombe)
	local root = model.PrimaryPart
	if root then
		root.Anchored = true
	end
end

--- Présentoirs des battes et seringues (à gauche des bases) et des 8 ADN (à droite).
function Vitrine.items(map: Model, parent: Instance): Folder
	local out = folder("Objets", parent)
	local pivot = pivotOf(map)
	local upright = CFrame.Angles(-math.pi / 2, 0, 0) -- le manche des battes / seringues vers le haut
	-- Rangée de gauche (x = -92), tournée vers l'allée (+X)
	local left: { { kind: string, id: string } } = {}
	for _, w in Weapons.List do
		table.insert(left, { kind = "Weapon", id = w.Id })
	end
	for _, s in Syringes.List do
		table.insert(left, { kind = "Syringe", id = s.Id })
	end
	local function slot(side: number, i: number): CFrame
		local p = pivot * v3(side * 92, 0, 52 + (i - 1) * 11)
		return CFrame.lookAt(p, p + pivot:VectorToWorldSpace(v3(-side, 0, 0)))
	end
	local gLeft = folder("Battes et seringues", out)
	header(gLeft, slot(-1, 0), "BATTES", rgb(150, 92, 50))
	header(gLeft, slot(-1, #Weapons.List + 1), "SERINGUES", rgb(255, 196, 30))
	for i, e in left do
		local i2 = if e.kind == "Syringe" then i + 1 else i
		local at = slot(-1, i2)
		if e.kind == "Weapon" then
			local def = Weapons.get(e.id)
			local top = pedestal(gLeft, at, def.DisplayName, if def.Price > 0 then `Niveau {def.Tier}` else "Arme de départ", rgb(150, 92, 50):Lerp(rgb(255, 210, 60), (def.Tier - 1) / 4))
			local m = def.build({ scale = 1.5, animated = false, cframe = top * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(12)) * upright })
			anchorRoot(m)
			m.Parent = gLeft
		else
			local def = Syringes.get(e.id)
			local top = pedestal(gLeft, at, def.DisplayName, `ADN x{(string.gsub(tostring(def.Multiplier), "%.", ","))}`, def.Color)
			local m = def.build({ scale = 1.5, animated = false, cframe = top * CFrame.new(0, 2.3, 0) * upright })
			anchorRoot(m)
			m.Parent = gLeft
		end
	end
	-- Rangée de droite (x = +92) : les 8 fragments d'ADN, du commun au chaotique
	local gRight = folder("ADN", out)
	header(gRight, slot(1, 0), "ADN", rgb(60, 190, 255))
	for i, rarity in Rarity.Order do
		local tier = Rarity.get(rarity)
		local top = pedestal(gRight, slot(1, i), DnaMachine.NAMES[rarity], `Incubation {DnaMachine.incubation(rarity)} s`, tier.color)
		local m = DnaMachine.buildDna(rarity, { scale = 1.8, animated = false, cframe = top })
		anchorRoot(m)
		m.Parent = gRight
	end
	return out
end

--- Construit tout le dossier Vitrine (personnages, tapis, objets) sous `parent`.
function Vitrine.build(map: Model, parent: Instance, list: { any }, spawn: (string, CFrame?, any) -> Model): Folder
	local root = Instance.new("Folder")
	root.Name = "Vitrine"
	Vitrine.creatures(map, root, list, spawn)
	Vitrine.treadmills(map, root)
	Vitrine.items(map, root)
	root.Parent = parent
	return root
end

return Vitrine
