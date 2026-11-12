--!strict
--[[
	CreatureForge.Mutations
	-----------------------
	Les 11 mutations du jeu, applicables à N'IMPORTE QUELLE créature et CUMULABLES.
	Chacune se voit sur le modèle : recoloration (la mutation la plus rare impose ses couleurs),
	pièces ajoutées (fleurs, fissures d'or, engrenages, squelette, étoiles...), effets.

	Revenu = base × (multi1 + multi2 + ...)       (base × 1 sans mutation)
	    ex. Griffon impérial 10 000 $/s + Vitrail (x2) + Kintsugi (x1,5) = 35 000 $/s

	    CreatureForge.spawn("GriffonImperial", cf, { mutations = { "Vitrail", "Kintsugi" } })
	    Mutations.apply(model, { "Encre" })          -- sur un modèle déjà construit
	    Mutations.roll(rng)                          -- tirage indépendant de chaque mutation
	    Mutations.multiplier({ "Vitrail", "Kintsugi" }) --> 3.5

	Côté client, Mutations.runtime(model) anime ce qui doit bouger (engrenages, ondulation du
	mirage, reflets d'aurore, copie fantôme de l'écho, changement d'apparence du paradoxe) ;
	CreatureAnimator l'appelle automatiquement.
]]

local Fx = require(script.Parent.Fx)

local rgb = Color3.fromRGB
local Mat = Enum.Material

export type Mutation = {
	id: string,
	label: string,
	effect: string, -- effet visible sur le modèle
	odds: number, -- 1 chance sur `odds`
	multiplier: number,
	glow: Color3, -- lumière + couleur d'accent
	badge: { Color3 }, -- dégradé de la pastille d'icône
	recolor: boolean, -- impose ses couleurs au modèle
	particle: Fx.ParticleDef?,
}

local function sparkle(name: string, colors: { Color3 }, rate: number, size: number, rise: number?): Fx.ParticleDef
	return {
		name = name,
		texture = Fx.TEXTURES.sparkle,
		colors = colors,
		sizes = { size, size * 0.6, 0 },
		transparencies = { 0.1, 0.2, 1 },
		lifetime = NumberRange.new(0.8, 1.6),
		rate = rate,
		speed = NumberRange.new(0.2, 0.6),
		spread = Vector2.new(180, 180),
		acceleration = Vector3.new(0, rise or 0.4, 0),
		drag = 1,
		lightEmission = 1,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-90, 90),
		volume = true,
	}
end

local function haze(name: string, colors: { Color3 }, rate: number, size: number, transparency: number, rise: number, light: number?): Fx.ParticleDef
	return {
		name = name,
		texture = Fx.TEXTURES.smoke,
		colors = colors,
		sizes = { size * 0.6, size, size * 1.3 },
		transparencies = { 1, transparency, 1 },
		lifetime = NumberRange.new(1.2, 2.2),
		rate = rate,
		speed = NumberRange.new(0.1, 0.4),
		spread = Vector2.new(180, 180),
		acceleration = Vector3.new(0, rise, 0),
		drag = 1,
		lightEmission = light or 0,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-30, 30),
		volume = true,
	}
end

local Mutations = {}

Mutations.List = {
	{
		id = "Mousse", label = "MOUSSE ANCIENNE", odds = 8, multiplier = 1.3, recolor = true,
		effect = "Couvert de mousse et de petites fleurs, comme une statue oubliée",
		glow = rgb(170, 230, 120), badge = { rgb(190, 230, 140), rgb(70, 120, 50) },
		particle = sparkle("Pollen", { rgb(230, 255, 160), rgb(255, 200, 230) }, 4, 0.18, -0.2),
	},
	{
		id = "Kintsugi", label = "KINTSUGI", odds = 15, multiplier = 1.5, recolor = true,
		effect = "Fissures remplies d'or, comme une porcelaine réparée",
		glow = rgb(255, 205, 80), badge = { rgb(250, 250, 255), rgb(255, 200, 60) },
		particle = sparkle("GoldDust", { rgb(255, 230, 130), rgb(255, 190, 50) }, 5, 0.22),
	},
	{
		id = "Vitrail", label = "VITRAIL", odds = 40, multiplier = 2, recolor = true,
		effect = "Corps en verre coloré, la lumière passe à travers",
		glow = rgb(255, 240, 200), badge = { rgb(230, 40, 60), rgb(255, 190, 40), rgb(40, 180, 90), rgb(40, 100, 230) },
		particle = sparkle("Motes", { rgb(255, 80, 90), rgb(80, 140, 255), rgb(255, 210, 80) }, 8, 0.25),
	},
	{
		id = "Horloger", label = "HORLOGER", odds = 80, multiplier = 2.5, recolor = true,
		effect = "Engrenages visibles qui tournent sous la peau",
		glow = rgb(255, 180, 70), badge = { rgb(255, 214, 140), rgb(150, 90, 30) },
		particle = sparkle("Sparks", { rgb(255, 210, 120), rgb(255, 150, 40) }, 4, 0.16, -1),
	},
	{
		id = "Mirage", label = "MIRAGE", odds = 150, multiplier = 3, recolor = true,
		effect = "Corps qui ondule comme la chaleur du désert, ombre décalée",
		glow = rgb(255, 200, 140), badge = { rgb(255, 230, 180), rgb(230, 110, 60) },
		particle = haze("HeatHaze", { rgb(255, 210, 160), rgb(255, 160, 100) }, 6, 1.6, 0.85, 0.8),
	},
	{
		id = "Encre", label = "ENCRE", odds = 300, multiplier = 3.5, recolor = true,
		effect = "Dessiné à l'encre noire, laisse des traînées en courant",
		glow = rgb(240, 236, 224), badge = { rgb(250, 246, 234), rgb(20, 20, 26) },
		particle = haze("InkDrops", { rgb(12, 12, 18), rgb(40, 40, 50) }, 5, 0.5, 0.35, -2),
	},
	{
		id = "Aurore", label = "AURORE", odds = 600, multiplier = 4, recolor = true,
		effect = "Reflets d'aurore boréale qui bougent sur le corps",
		glow = rgb(120, 255, 200), badge = { rgb(80, 255, 170), rgb(60, 200, 255), rgb(190, 90, 255) },
		particle = sparkle("AuroraMotes", { rgb(120, 255, 200), rgb(170, 120, 255) }, 8, 0.26),
	},
	{
		id = "Fossile", label = "FOSSILE VIVANT", odds = 1500, multiplier = 5, recolor = true,
		effect = "Squelette visible à travers un corps d'ambre",
		glow = rgb(255, 180, 60), badge = { rgb(255, 210, 120), rgb(170, 80, 10) },
		particle = sparkle("AmberDust", { rgb(255, 200, 100), rgb(255, 150, 40) }, 5, 0.2),
	},
	{
		id = "Constellation", label = "CONSTELLATION", odds = 5000, multiplier = 7, recolor = true,
		effect = "Corps noir rempli d'étoiles reliées entre elles",
		glow = rgb(190, 210, 255), badge = { rgb(40, 40, 90), rgb(6, 6, 18) },
		particle = sparkle("Stardust", { rgb(255, 255, 255), rgb(170, 200, 255) }, 10, 0.2, 0.1),
	},
	{
		id = "Echo", label = "ÉCHO", odds = 20000, multiplier = 10, recolor = false,
		effect = "Une copie fantôme le suit avec une seconde de retard",
		glow = rgb(120, 230, 255), badge = { rgb(200, 250, 255), rgb(60, 150, 230) },
		particle = haze("EchoRipple", { rgb(140, 230, 255), rgb(80, 160, 255) }, 5, 1.2, 0.8, 0, 1),
	},
	{
		id = "Paradoxe", label = "PARADOXE", odds = 100000, multiplier = 15, recolor = true,
		effect = "Change d'apparence de mutation toutes les 3 secondes",
		glow = rgb(255, 60, 200), badge = { rgb(255, 0, 140), rgb(0, 240, 255), rgb(255, 255, 255) },
		particle = sparkle("Glitch", { rgb(255, 0, 140), rgb(0, 255, 230), rgb(255, 255, 255) }, 12, 0.3),
	},
} :: { Mutation }

local byId: { [string]: Mutation } = {}
local rank: { [string]: number } = {}
for i, m in Mutations.List do
	byId[m.id] = m
	rank[m.id] = i
end

function Mutations.get(id: string): Mutation?
	return byId[id]
end

--- Normalise "Vitrail", { "Vitrail", "Kintsugi" } ou "Vitrail,Kintsugi" en liste triée (rareté croissante).
function Mutations.normalize(ids: (string | { string })?): { string }
	local list: { string } = {}
	if type(ids) == "string" then
		for id in string.gmatch(ids, "[^,%s]+") do
			table.insert(list, id)
		end
	elseif type(ids) == "table" then
		list = table.clone(ids)
	end
	local seen, out = {}, {}
	for _, id in list do
		if byId[id] and not seen[id] then
			seen[id] = true
			table.insert(out, id)
		end
	end
	table.sort(out, function(a, b)
		return rank[a] < rank[b]
	end)
	return out
end

--- Somme des multiplicateurs (1 sans mutation).
function Mutations.multiplier(ids: (string | { string })?): number
	local list = Mutations.normalize(ids)
	if #list == 0 then
		return 1
	end
	local sum = 0
	for _, id in list do
		sum += byId[id].multiplier
	end
	return sum
end

--- Tirage : chaque mutation est tirée indépendamment (1 sur `odds`). Renvoie la liste (souvent vide).
function Mutations.roll(rng: Random?, luck: number?): { string }
	local r = rng or Random.new()
	local out = {}
	for _, m in Mutations.List do
		if r:NextNumber() < (luck or 1) / m.odds then
			table.insert(out, m.id)
		end
	end
	return out
end

--- Mutation qui impose ses couleurs : la plus rare de la liste.
function Mutations.dominant(ids: (string | { string })?): Mutation?
	local list = Mutations.normalize(ids)
	for i = #list, 1, -1 do
		local m = byId[list[i]]
		if m.recolor then
			return m
		end
	end
	return if #list > 0 then byId[list[#list]] else nil
end

-- ---------------------------------------------------------------------------
-- Peinture : nouvelle couleur d'une pièce selon sa luminosité d'origine (lum) et sa place
-- dans le corps (ctx). Fonctions pures : réutilisées par le Paradoxe côté client.
-- ---------------------------------------------------------------------------

export type PaintCtx = {
	along: number, -- 0 = avant, 1 = arrière
	height: number, -- 0 = bas, 1 = haut
	h: number, -- hasard stable par pièce (0..1)
	cell: number, -- cellule de vitrail (1..6)
}

local function ramp(list: { Color3 }, x: number): Color3
	local f = math.clamp(x, 0, 1) * (#list - 1)
	local i = math.min(math.floor(f) + 1, #list - 1)
	return list[i]:Lerp(list[i + 1], f - (i - 1))
end

local STONE = { rgb(70, 72, 68), rgb(116, 118, 110), rgb(160, 160, 150), rgb(200, 198, 186) }
local MOSS = { rgb(40, 80, 30), rgb(72, 118, 44), rgb(112, 154, 60), rgb(160, 192, 90) }
local PORCELAIN = { rgb(26, 50, 130), rgb(104, 136, 200), rgb(230, 234, 244), rgb(252, 252, 255) }
local GLASS = { rgb(220, 30, 50), rgb(30, 90, 230), rgb(30, 170, 80), rgb(255, 180, 30), rgb(150, 50, 210), rgb(30, 200, 210) }
local BRASS = { rgb(70, 44, 18), rgb(150, 100, 44), rgb(214, 162, 80), rgb(250, 220, 150) }
local HEAT = { rgb(150, 60, 50), rgb(230, 120, 70), rgb(255, 190, 120), rgb(255, 236, 200) }
local AMBER = { rgb(110, 40, 8), rgb(200, 100, 20), rgb(250, 160, 40), rgb(255, 214, 130) }
local NIGHT = { rgb(4, 4, 12), rgb(10, 10, 28), rgb(20, 20, 54), rgb(40, 40, 92) }
local INK, PAPER, PAPER_SHADE = rgb(16, 16, 22), rgb(246, 242, 230), rgb(212, 206, 192)

local function lumOf(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end
Mutations.lum = lumOf

--- Teinte d'aurore (verts -> cyans -> violets) qui défile le long du corps.
function Mutations.auroraHue(ctx: PaintCtx, t: number): number
	return 0.3 + 0.5 * (0.5 + 0.5 * math.sin((ctx.along * 1.6 + ctx.height * 1.1) * math.pi * 2 - t * 1.3))
end

type Paint = (lum: number, neon: boolean, ctx: PaintCtx, t: number) -> (Color3, Enum.Material?, number?)

Mutations.PAINT = {
	Mousse = function(l, neon, c)
		if neon then
			return rgb(190, 255, 150), nil, nil
		end
		if (c.height > 0.48 and c.h < 0.62) or c.h < 0.14 then
			return ramp(MOSS, l ^ 0.8), Mat.Grass, 0
		end
		return ramp(STONE, l ^ 0.8), Mat.Slate, 0
	end,
	Kintsugi = function(l, neon)
		if neon then
			return rgb(255, 205, 80), nil, nil
		end
		return ramp(PORCELAIN, l ^ 0.7), Mat.SmoothPlastic, 0
	end,
	Vitrail = function(l, neon, c)
		if neon then
			return rgb(255, 250, 230), nil, nil
		end
		return GLASS[c.cell]:Lerp(Color3.new(0, 0, 0), 0.4 * (1 - l)), Mat.Glass, 0.25
	end,
	Horloger = function(l, neon)
		if neon then
			return rgb(255, 170, 60), nil, nil
		end
		return ramp(BRASS, l), Mat.Glass, 0.45
	end,
	Mirage = function(l, neon)
		if neon then
			return rgb(255, 240, 210), nil, nil
		end
		return ramp(HEAT, l), Mat.SmoothPlastic, 0.2
	end,
	Encre = function(l, neon)
		if neon or l < 0.4 then
			return INK, Mat.SmoothPlastic, 0
		end
		return if l < 0.62 then PAPER_SHADE else PAPER, Mat.SmoothPlastic, 0
	end,
	Aurore = function(l, neon, c, t)
		local hue = Mutations.auroraHue(c, t)
		if neon then
			return Color3.fromHSV(hue, 0.35, 1), nil, nil
		end
		return Color3.fromHSV(hue, 0.72, 0.3 + 0.7 * l), Mat.SmoothPlastic, 0
	end,
	Fossile = function(l, neon)
		if neon then
			return rgb(255, 190, 80), nil, nil
		end
		return ramp(AMBER, l), Mat.Glass, 0.45
	end,
	Constellation = function(l, neon)
		if neon then
			return rgb(210, 225, 255), nil, nil
		end
		return ramp(NIGHT, l), Mat.SmoothPlastic, 0
	end,
	Paradoxe = function(l, neon, c, t)
		local hue = (c.along * 0.7 + c.height * 0.3 + t * 0.15) % 1
		if neon then
			return Color3.fromHSV(hue, 0.25, 1), nil, nil
		end
		return Color3.fromHSV(hue, 0.85, 0.3 + 0.7 * l), Mat.SmoothPlastic, 0
	end,
} :: { [string]: Paint }

--- Apparences parcourues par le Paradoxe (une toutes les 3 secondes).
Mutations.PARADOX_CYCLE = { "Constellation", "Vitrail", "Encre", "Aurore", "Kintsugi", "Fossile", "Mousse", "Horloger", "Mirage" }

--- Luminosité d'origine retrouvée à partir d'une couleur peinte en HSV (Aurore, Paradoxe).
function Mutations.unpaintLum(c: Color3): number
	local _, _, v = c:ToHSV()
	return math.clamp((v - 0.3) / 0.7, 0, 1)
end

-- ---------------------------------------------------------------------------
-- Application sur un modèle
-- ---------------------------------------------------------------------------

type PartInfo = { part: BasePart, ctx: PaintCtx, lum: number, neon: boolean, bone: string, aura: boolean }

type Ctx = {
	model: Model,
	root: BasePart,
	ref: CFrame,
	center: Vector3, -- centre (espace Root)
	size: Vector3, -- taille (espace Root)
	span: number, -- plus grande dimension
	sc: number,
	rng: Random,
	parts: { PartInfo },
	body: { PartInfo }, -- pièces du corps (hors orbites et effets)
	bones: { [string]: BasePart },
	parentOf: { [string]: string },
}

local function configure(p: BasePart)
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

local function hash(x: number): number
	local s = math.sin(x * 12.9898) * 43758.5453
	return s - math.floor(s)
end

local function isAuraName(name: string): boolean
	return string.sub(name, 1, 4) == "Aura" or string.sub(name, 1, 3) == "FX_" or name == "Bones"
end

local function boneNameOf(model: Model, p: BasePart): string
	local parent = p.Parent
	if parent and parent ~= model and parent:IsA("Folder") then
		return parent.Name
	end
	return "Root"
end

local function bounds(model: Model, ref: CFrame): (Vector3, Vector3)
	local lo = Vector3.one * math.huge
	local hi = -lo
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 and not isAuraName(boneNameOf(model, d)) then
			local p = ref:PointToObjectSpace(d.CFrame.Position)
			local e = d.Size.Magnitude * 0.3
			lo = lo:Min(p - Vector3.one * e)
			hi = hi:Max(p + Vector3.one * e)
		end
	end
	if lo.X == math.huge then
		return Vector3.zero, Vector3.one
	end
	return (lo + hi) / 2, hi - lo
end

local function buildCtx(model: Model, seed: number): Ctx?
	local root = model.PrimaryPart
	if not root then
		return nil
	end
	local ref = root.CFrame
	local center, size = bounds(model, ref)
	local bones: { [string]: BasePart } = { Root = root }
	local parentOf: { [string]: string } = {}
	local folder = model:FindFirstChild("Bones")
	if folder then
		for _, b in folder:GetChildren() do
			if b:IsA("BasePart") then
				bones[b.Name] = b
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			parentOf[d.Part1.Name] = d.Part0.Name
		end
	end
	local zMin, yMin = center.Z - size.Z / 2, center.Y - size.Y / 2
	local cs = math.max(size.X, size.Y, size.Z) / 7
	local parts, body = {}, {}
	for i, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Parent ~= folder and d ~= root then
			local p = ref:PointToObjectSpace(d.CFrame.Position)
			local bone = boneNameOf(model, d)
			local cell = math.floor(hash(math.floor(p.X / cs) * 7.1 + math.floor(p.Y / cs) * 13.7 + math.floor(p.Z / cs) * 3.3) * 6) + 1
			local info: PartInfo = {
				part = d,
				ctx = {
					along = math.clamp((p.Z - zMin) / math.max(size.Z, 0.01), 0, 1),
					height = math.clamp((p.Y - yMin) / math.max(size.Y, 0.01), 0, 1),
					h = hash(i * 1.37 + seed),
					cell = math.clamp(cell, 1, 6),
				},
				lum = lumOf(d.Color),
				neon = d.Material == Mat.Neon,
				bone = bone,
				aura = isAuraName(bone),
			}
			table.insert(parts, info)
			if not info.aura then
				table.insert(body, info)
			end
		end
	end
	return {
		model = model,
		root = root,
		ref = ref,
		center = center,
		size = size,
		span = math.max(size.X, size.Y, size.Z),
		sc = (model:GetAttribute("Scale") :: number?) or 1,
		rng = Random.new(seed),
		parts = parts,
		body = body,
		bones = bones,
		parentOf = parentOf,
	}
end

--- Pièce ajoutée par une mutation, soudée à l'os `bone` (cf/size en coordonnées monde).
local function add(c: Ctx, bone: string, name: string, shape: string, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, transparency: number?): BasePart
	local b = c.bones[bone] or c.root
	local p: BasePart
	if shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		p = part
	end
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Mat.SmoothPlastic
	p.Transparency = transparency or 0
	p.CastShadow = false
	configure(p)
	p.CFrame = cf
	local f = c.model:FindFirstChild(bone)
	if not (f and f:IsA("Folder")) then
		local nf = Instance.new("Folder")
		nf.Name = bone
		nf.Parent = c.model
		f = nf
	end
	p.Parent = f
	local w = Instance.new("Weld")
	w.Part0 = b
	w.Part1 = p
	w.C0 = b.CFrame:ToObjectSpace(p.CFrame)
	w.Parent = p
	return p
end

--- Segment (poutre) entre deux points monde.
local function segment(c: Ctx, bone: string, name: string, a: Vector3, b: Vector3, w: number, color: Color3, material: Enum.Material?, transparency: number?): BasePart?
	local d = b - a
	if d.Magnitude < 1e-3 then
		return nil
	end
	local up = if math.abs(d.Unit.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	return add(c, bone, name, "Block", CFrame.lookAt((a + b) / 2, b, up), Vector3.new(w, w, d.Magnitude + w * 0.6), color, material, transparency)
end

--- Demi-épaisseur d'une pièce le long de la direction monde `n`.
local function extentAlong(p: BasePart, n: Vector3): number
	local cf = p.CFrame
	return 0.5 * (math.abs(cf.RightVector:Dot(n)) * p.Size.X + math.abs(cf.UpVector:Dot(n)) * p.Size.Y + math.abs(cf.LookVector:Dot(n)) * p.Size.Z)
end

--- Normale extérieure approximative d'une pièce (depuis le centre de son os).
local function outward(c: Ctx, info: PartInfo): Vector3
	local b = c.bones[info.bone] or c.root
	local d = info.part.CFrame.Position - b.CFrame.Position
	if d.Magnitude < 1e-3 then
		return c.ref.UpVector
	end
	return d.Unit
end

local function pick(c: Ctx, list: { PartInfo }, n: number, filter: ((PartInfo) -> boolean)?): { PartInfo }
	local pool = {}
	for _, info in list do
		if not filter or filter(info) then
			table.insert(pool, info)
		end
	end
	local out = {}
	for _ = 1, math.min(n, #pool) do
		local i = c.rng:NextInteger(1, #pool)
		table.insert(out, pool[i])
		pool[i] = pool[#pool]
		pool[#pool] = nil
	end
	return out
end

local function fxPart(c: Ctx, name: string, m: Mutation, lightRange: number?)
	local aura = Instance.new("Part")
	aura.Name = "FX_" .. name
	aura.Size = c.size * 0.9
	aura.Transparency = 1
	aura.CastShadow = false
	configure(aura)
	aura.CFrame = c.ref * CFrame.new(c.center)
	local w = Instance.new("Weld")
	w.Part0 = c.root
	w.Part1 = aura
	w.C0 = CFrame.new(c.center)
	w.Parent = aura
	aura.Parent = c.model
	if m.particle then
		Fx.particles(aura, m.particle, c.sc)
	end
	if lightRange then
		Fx.light(aura, { color = m.glow, range = lightRange / c.sc, brightness = 1.2 }, c.sc)
	end
	return aura
end

-- Pièces ajoutées par chaque mutation ----------------------------------------

local ADD: { [string]: (Ctx, Mutation) -> () } = {}

ADD.Mousse = function(c, m)
	local petals = { rgb(255, 150, 200), rgb(255, 250, 240), rgb(200, 160, 255), rgb(255, 230, 90) }
	local f = math.clamp(c.span * 0.028, 0.08, 1.4)
	local n = math.clamp(math.floor(#c.body / 40), 8, 24)
	for _, info in pick(c, c.body, n, function(i)
		return i.ctx.height > 0.4 and not i.neon
	end) do
		local p = info.part
		local top = p.CFrame.Position + Vector3.yAxis * extentAlong(p, Vector3.yAxis)
		local col = petals[c.rng:NextInteger(1, #petals)]
		add(c, info.bone, "Flower", "Ball", CFrame.new(top + Vector3.yAxis * f * 0.12), Vector3.one * f * 0.45, rgb(255, 214, 60), Mat.SmoothPlastic)
		local a0 = c.rng:NextNumber(0, math.pi)
		for k = 0, 4 do
			local a = a0 + k / 5 * math.pi * 2
			add(c, info.bone, "Petal", "Ball", CFrame.new(top + Vector3.new(math.cos(a), 0.05, math.sin(a)) * f * 0.36), Vector3.new(1, 0.55, 1) * f * 0.5, col, Mat.SmoothPlastic)
		end
		-- Brin de mousse retombant
		add(c, info.bone, "MossTuft", "Ball", CFrame.new(top - Vector3.yAxis * f * 0.1 + Vector3.new(f * 0.5, 0, 0)), Vector3.new(1.2, 0.5, 1) * f * 0.6, rgb(90, 140, 50), Mat.Grass)
	end
	fxPart(c, "Mousse", m)
end

ADD.Kintsugi = function(c, m)
	local n = math.clamp(math.floor(#c.body / 30), 10, 36)
	local list = pick(c, c.body, n, function(i)
		return not i.neon and i.part.Size.Magnitude > c.span * 0.04
	end)
	for _, info in list do
		local p = info.part
		local nrm = outward(c, info)
		local base = p.CFrame.Position + nrm * extentAlong(p, nrm) * 0.92
		local t1 = nrm:Cross(Vector3.new(c.rng:NextNumber(-1, 1), c.rng:NextNumber(-1, 1), c.rng:NextNumber(-1, 1))).Unit
		local t2 = nrm:Cross(t1).Unit
		local L = math.max(p.Size.X, p.Size.Y, p.Size.Z) * 0.35
		local w = math.clamp(c.span * 0.007, 0.03, 0.3)
		local pts = { base - t1 * L * 1.4, base - t1 * L * 0.45 + t2 * L * 0.3, base + t1 * L * 0.45 - t2 * L * 0.25, base + t1 * L * 1.4 + t2 * L * 0.15 }
		for k = 1, #pts - 1 do
			segment(c, info.bone, "GoldCrack", pts[k], pts[k + 1], w, rgb(255, 196, 60), Mat.Neon)
		end
	end
	fxPart(c, "Kintsugi", m)
end

ADD.Vitrail = function(c, m)
	local aura = fxPart(c, "Vitrail", m)
	for i, col in { GLASS[1], GLASS[2], GLASS[4] } do
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(0, 0, (i - 2) * c.size.Z * 0.25)
		a.Parent = aura
		Fx.light(a, { color = col, range = c.span * 0.5 / c.sc, brightness = 1.6 }, c.sc)
	end
end

ADD.Horloger = function(c, m)
	-- Os principaux = ceux qui portent le plus de pièces
	local count: { [string]: number } = {}
	for _, info in c.body do
		local b = info.bone
		if b ~= "Root" and not string.match(b, "^Float") and not string.match(b, "^Sway") then
			count[b] = (count[b] or 0) + 1
		end
	end
	local order = {}
	for b, n in count do
		table.insert(order, { b = b, n = n })
	end
	table.sort(order, function(a, b)
		return a.n > b.n
	end)
	local gears = 0
	local folder = c.model:FindFirstChild("Bones")
	local function gear(bone: string, center: Vector3, r: number, dir: number)
		gears += 1
		local name = "Spin" .. gears
		local right, up = c.ref.RightVector, c.ref.UpVector
		local gcf = CFrame.fromMatrix(center, up, right:Cross(up), right)
		local parent = c.bones[bone] or c.root
		local gb = Instance.new("Part")
		gb.Name = name
		gb.Size = Vector3.one * 0.2
		gb.Transparency = 1
		configure(gb)
		gb.CFrame = gcf
		gb.Parent = folder or c.model
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = parent
		motor.Part1 = gb
		motor.C0 = parent.CFrame:ToObjectSpace(gcf)
		motor:SetAttribute("Speed", dir * 1.4 / math.max(r / c.sc, 0.2))
		motor.Parent = parent
		c.bones[name] = gb
		local th = r * 0.28
		add(c, name, "Gear", "Cylinder", gcf * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(th, r * 2, r * 2), rgb(196, 140, 56), Mat.Metal)
		add(c, name, "GearHub", "Cylinder", gcf * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(th * 1.5, r * 0.7, r * 0.7), rgb(90, 58, 26), Mat.Metal)
		local teeth = math.max(8, math.floor(r / c.sc * 14))
		for k = 0, teeth - 1 do
			local a = k / teeth * math.pi * 2
			add(c, name, "GearTooth", "Block", gcf * CFrame.Angles(0, 0, a) * CFrame.new(0, r + r * 0.1, 0), Vector3.new(r * 0.26, r * 0.3, th), rgb(236, 186, 84), Mat.Metal)
		end
		for k = 0, 2 do
			add(c, name, "GearSpoke", "Block", gcf * CFrame.Angles(0, 0, k / 3 * math.pi), Vector3.new(r * 0.12, r * 1.7, th * 1.2), rgb(150, 100, 40), Mat.Metal)
		end
	end
	for i = 1, math.min(4, #order) do
		local b = order[i].b
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, info in c.body do
			if info.bone == b then
				local p = c.ref:PointToObjectSpace(info.part.CFrame.Position)
				lo, hi = lo:Min(p), hi:Max(p)
			end
		end
		local mid = c.ref * ((lo + hi) / 2)
		local ext = hi - lo
		local r = math.clamp(math.min(ext.Y, math.max(ext.Z, ext.X)) * 0.22, 0.12 * c.sc, c.span * 0.12)
		gear(b, mid, r, 1)
		if i == 1 then
			gear(b, mid + c.ref.LookVector * r * 1.85 + c.ref.UpVector * r * 0.3, r * 0.68, -1)
			gear(b, mid - c.ref.LookVector * r * 1.8 - c.ref.UpVector * r * 0.2, r * 0.78, -1)
		end
	end
	fxPart(c, "Horloger", m, c.span * 0.5)
end

ADD.Mirage = function(c, m)
	-- Ombre décalée : silhouette plate posée à côté du corps
	local list = table.clone(c.body)
	table.sort(list, function(a, b)
		return a.part.Size.Magnitude > b.part.Size.Magnitude
	end)
	local off = Vector3.new(c.size.X * 0.45, 0, c.size.Z * 0.12)
	for i = 1, math.min(80, #list) do
		local p = list[i].part
		local lp = c.ref:PointToObjectSpace(p.CFrame.Position)
		local ex = extentAlong(p, c.ref.RightVector) * 2
		local ez = extentAlong(p, c.ref.LookVector) * 2
		add(c, "Root", "MirageShadow", "Block", c.ref * CFrame.new(lp.X + off.X, 0.03 * c.sc + i * 0.0005, lp.Z + off.Z), Vector3.new(ex, 0.02 * c.sc, ez), rgb(70, 30, 50), Mat.SmoothPlastic, 0.55)
	end
	fxPart(c, "Mirage", m)
end

ADD.Encre = function(c, m)
	local tips = {}
	for name in c.bones do
		if string.match(name, "^Leg") or string.match(name, "^Wing") or string.match(name, "^Arm") then
			table.insert(tips, name)
		end
	end
	local tailEnd, segEnd = 0, 0
	for name in c.bones do
		local n = tonumber(string.match(name, "^Tail(%d+)$"))
		if n and n > tailEnd then
			tailEnd = n
		end
		local s = tonumber(string.match(name, "^Seg(%d+)$"))
		if s and s > segEnd then
			segEnd = s
		end
	end
	if tailEnd > 0 then
		table.insert(tips, "Tail" .. tailEnd)
	end
	if segEnd > 0 then
		table.insert(tips, "Seg" .. segEnd)
	end
	if #tips == 0 then
		table.insert(tips, if c.bones.Body then "Body" else "Root")
	end
	for _, name in tips do
		local b = c.bones[name]
		-- pointe = pièce la plus éloignée de l'articulation
		local far, best = b.CFrame.Position, -1
		for _, info in c.body do
			if info.bone == name then
				local d = (info.part.CFrame.Position - b.CFrame.Position).Magnitude
				if d > best then
					far, best = info.part.CFrame.Position, d
				end
			end
		end
		local w = math.clamp(c.span * 0.02, 0.06, 0.8)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Name, a1.Name = "InkTrail0", "InkTrail1"
		a0.Parent, a1.Parent = b, b
		a0.WorldPosition = far + Vector3.yAxis * w
		a1.WorldPosition = far - Vector3.yAxis * w
		local tr = Instance.new("Trail")
		tr.Name = "InkTrail"
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Color = ColorSequence.new(INK)
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		tr.Lifetime = 0.9
		tr.MinLength = 0.05
		tr.FaceCamera = true
		tr.LightInfluence = 0
		tr.Parent = b
	end
	local h = c.model:FindFirstChildOfClass("Highlight")
	if h then
		h.OutlineColor = INK
		h.OutlineTransparency = 0
	end
	fxPart(c, "Encre", m)
end

ADD.Aurore = function(c, m)
	local aura = fxPart(c, "Aurore", m, c.span * 0.6)
	local cols = { { rgb(80, 255, 170), rgb(60, 200, 255), rgb(190, 90, 255) }, { rgb(190, 90, 255), rgb(80, 255, 200), rgb(60, 160, 255) } }
	for i = 1, 2 do
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position = Vector3.new(-c.size.X * 0.1 * i, c.size.Y * (0.35 + 0.1 * i), -c.size.Z * 0.48)
		a1.Position = Vector3.new(c.size.X * 0.1 * i, c.size.Y * (0.3 + 0.1 * i), c.size.Z * 0.48)
		a0.Parent, a1.Parent = aura, aura
		local b = Instance.new("Beam")
		b.Name = "AuroraRibbon"
		b.Attachment0, b.Attachment1 = a0, a1
		b.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, cols[i][1]), ColorSequenceKeypoint.new(0.5, cols[i][2]), ColorSequenceKeypoint.new(1, cols[i][3]) })
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) })
		b.Width0 = c.size.X * 0.5
		b.Width1 = c.size.X * 0.5
		b.CurveSize0 = c.size.Y * 0.6 * (if i == 1 then 1 else -1)
		b.CurveSize1 = c.size.Y * 0.4
		b.LightEmission = 1
		b.FaceCamera = true
		b.Segments = 20
		b.Parent = aura
	end
end

ADD.Fossile = function(c, m)
	local bone = rgb(238, 230, 210)
	local th = math.clamp(c.span * 0.022, 0.05, 0.7)
	local hasChild: { [string]: boolean } = {}
	for child, parent in c.parentOf do
		hasChild[parent] = true
	end
	local function skip(name: string): boolean
		return name == "Root" or isAuraName(name) or string.match(name, "^Float") ~= nil or string.match(name, "^Spin") ~= nil or string.match(name, "^Ear") ~= nil
	end
	for name, b in c.bones do
		if not skip(name) then
			local parent = c.parentOf[name]
			if parent and not skip(parent) and c.bones[parent] then
				segment(c, parent, "Bone", c.bones[parent].CFrame.Position, b.CFrame.Position, th, bone)
			end
			add(c, name, "Joint", "Ball", CFrame.new(b.CFrame.Position), Vector3.one * th * 1.7, bone)
			if not hasChild[name] then
				local far, best = b.CFrame.Position, -1
				for _, info in c.body do
					if info.bone == name then
						local d = (info.part.CFrame.Position - b.CFrame.Position).Magnitude
						if d > best then
							far, best = info.part.CFrame.Position, d
						end
					end
				end
				if best > th then
					segment(c, name, "Bone", b.CFrame.Position, b.CFrame.Position:Lerp(far, 0.85), th * 0.85, bone)
				end
			end
		end
	end
	-- Côtes autour du corps et crâne
	local function boxOf(name: string): (Vector3?, Vector3?)
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		local any = false
		for _, info in c.body do
			if info.bone == name then
				local p = c.ref:PointToObjectSpace(info.part.CFrame.Position)
				lo, hi = lo:Min(p), hi:Max(p)
				any = true
			end
		end
		if not any then
			return nil, nil
		end
		return (lo + hi) / 2, hi - lo
	end
	local mid, ext = boxOf("Body")
	if mid and ext then
		local ex, ey, ez = ext.X * 0.5, ext.Y * 0.5, ext.Z * 0.5
		for k = 0, 4 do
			local z = mid.Z - ez * 0.45 + k * ez * 0.2
			for _, s in { 1, -1 } do
				local pts = {
					Vector3.new(0, mid.Y + ey * 0.45, z),
					Vector3.new(s * ex * 0.5, mid.Y + ey * 0.25, z),
					Vector3.new(s * ex * 0.55, mid.Y - ey * 0.15, z),
					Vector3.new(s * ex * 0.3, mid.Y - ey * 0.45, z),
				}
				for i = 1, #pts - 1 do
					segment(c, "Body", "Rib", c.ref * pts[i], c.ref * pts[i + 1], th * 0.7, bone)
				end
			end
		end
		segment(c, "Body", "Spine", c.ref * Vector3.new(0, mid.Y + ey * 0.45, mid.Z - ez * 0.6), c.ref * Vector3.new(0, mid.Y + ey * 0.45, mid.Z + ez * 0.6), th, bone)
	end
	local hmid, hext = boxOf("Head")
	if hmid and hext then
		local d = math.min(hext.X, hext.Y, hext.Z) * 0.75 + th
		add(c, "Head", "Skull", "Ball", c.ref * CFrame.new(hmid), Vector3.one * d, bone)
		for _, s in { 1, -1 } do
			add(c, "Head", "EyeSocket", "Ball", c.ref * CFrame.new(hmid + Vector3.new(s * d * 0.22, d * 0.08, -d * 0.4)), Vector3.one * d * 0.28, rgb(40, 20, 10))
		end
	end
	fxPart(c, "Fossile", m, c.span * 0.5)
end

ADD.Constellation = function(c, m)
	local starCol = rgb(235, 242, 255)
	local list = {}
	for _, info in c.body do
		if not info.neon then
			table.insert(list, info)
		end
	end
	if #list == 0 then
		return
	end
	-- Étoiles bien réparties (échantillonnage du point le plus éloigné)
	local k = math.clamp(math.floor(#list / 60), 10, 22)
	local chosen = { list[c.rng:NextInteger(1, #list)] }
	while #chosen < k do
		local best, bestD = nil, -1
		for i = 1, #list, 3 do
			local info = list[i]
			local d = math.huge
			for _, s in chosen do
				d = math.min(d, (s.part.CFrame.Position - info.part.CFrame.Position).Magnitude)
			end
			if d > bestD then
				best, bestD = info, d
			end
		end
		table.insert(chosen, best :: PartInfo)
	end
	local s = math.clamp(c.span * 0.03, 0.08, 1.2)
	local stars = {}
	for _, info in chosen do
		local nrm = outward(c, info)
		local pos = info.part.CFrame.Position + nrm * extentAlong(info.part, nrm)
		local star = add(c, info.bone, "Star", "Ball", CFrame.new(pos), Vector3.one * s * 0.55, starCol, Mat.Neon)
		local rot = CFrame.lookAt(pos, pos + nrm)
		add(c, info.bone, "StarRay", "Block", rot, Vector3.new(s * 0.12, s * 1.3, s * 0.12), starCol, Mat.Neon)
		add(c, info.bone, "StarRay", "Block", rot, Vector3.new(s * 1.3, s * 0.12, s * 0.12), starCol, Mat.Neon)
		local a = Instance.new("Attachment")
		a.Name = "StarLink"
		a.Parent = star
		table.insert(stars, { part = star, att = a })
	end
	-- Lignes de constellation : chaque étoile reliée à la plus proche des précédentes
	for i = 2, #stars do
		local best, bestD = stars[1], math.huge
		for j = 1, i - 1 do
			local d = (stars[j].part.CFrame.Position - stars[i].part.CFrame.Position).Magnitude
			if d < bestD then
				best, bestD = stars[j], d
			end
		end
		local b = Instance.new("Beam")
		b.Name = "ConstellationLine"
		b.Attachment0, b.Attachment1 = best.att, stars[i].att
		b.Color = ColorSequence.new(rgb(170, 200, 255), rgb(255, 255, 255))
		b.Transparency = NumberSequence.new(0.25)
		b.Width0, b.Width1 = s * 0.12, s * 0.12
		b.LightEmission = 1
		b.FaceCamera = true
		b.Segments = 1
		b.Parent = stars[i].part
	end
	-- Poussière d'étoiles
	for _, info in pick(c, list, 40) do
		local nrm = outward(c, info)
		add(c, info.bone, "StarDot", "Ball", CFrame.new(info.part.CFrame.Position + nrm * extentAlong(info.part, nrm)), Vector3.one * s * 0.22, starCol, Mat.Neon)
	end
	fxPart(c, "Constellation", m, c.span * 0.5)
end

ADD.Echo = function(c, m)
	fxPart(c, "Echo", m)
end

ADD.Paradoxe = function(c, m)
	fxPart(c, "Paradoxe", m, c.span * 0.5)
end

--- Applique une ou plusieurs mutations au modèle (une seule fois). Renvoie le modèle.
function Mutations.apply(model: Model, ids: string | { string }): Model
	if model:GetAttribute("Mutations") then
		return model
	end
	local list = Mutations.normalize(ids)
	if #list == 0 then
		return model
	end
	local seed = 0
	for i = 1, #list do
		seed += rank[list[i]] * 97 * i
	end
	local c = buildCtx(model, seed)
	if not c then
		return model
	end
	local dom = Mutations.dominant(list)
	if dom and dom.recolor then
		local paint = Mutations.PAINT[dom.id]
		for _, info in c.parts do
			local col, mat, tr = paint(info.lum, info.neon, info.ctx, 0)
			local p = info.part
			p.Color = col
			if mat then
				p.Material = mat
			end
			if tr and not info.neon then
				p.Transparency = math.max(p.Transparency, tr)
			end
		end
		for _, d in model:GetDescendants() do
			if d:IsA("PointLight") then
				d.Color = dom.glow
			end
		end
	end
	for _, id in list do
		ADD[id](c, byId[id])
	end
	model:SetAttribute("Mutations", table.concat(list, ","))
	model:SetAttribute("Mutation", if dom then dom.id else list[1])
	model:SetAttribute("Multiplier", Mutations.multiplier(list))
	return model
end

-- ---------------------------------------------------------------------------
-- Côté client : animation des mutations (appelé par CreatureAnimator)
-- ---------------------------------------------------------------------------

export type Runtime = {
	step: (self: Runtime, t: number, dt: number) -> (),
	destroy: (self: Runtime) -> (),
}

local ECHO_DELAY = 1
local PARADOX_PERIOD = 3

--- Prépare les effets animés d'un modèle muté (nil s'il n'y a rien à animer).
function Mutations.runtime(model: Model, motors: { [string]: Motor6D }): Runtime?
	local attr = model:GetAttribute("Mutations")
	if typeof(attr) ~= "string" then
		return nil
	end
	local list = Mutations.normalize(attr)
	local has: { [string]: boolean } = {}
	for _, id in list do
		has[id] = true
	end
	local dom = Mutations.dominant(list)
	local root = model.PrimaryPart
	if not root then
		return nil
	end
	local sc = (model:GetAttribute("Scale") :: number?) or 1

	local spins = {}
	for name, m in motors do
		if string.sub(name, 1, 4) == "Spin" then
			table.insert(spins, { motor = m, speed = (m:GetAttribute("Speed") :: number?) or 1 })
		end
	end
	local waves = {}
	if has.Mirage then
		local i = 0
		for name, m in motors do
			if string.sub(name, 1, 4) ~= "Aura" and string.sub(name, 1, 4) ~= "Spin" then
				i += 1
				table.insert(waves, { motor = m, k = i * 1.7 })
			end
		end
	end

	-- Recoloration animée (Aurore dominante, ou Paradoxe)
	local painted: { { part: BasePart, ctx: PaintCtx, lum: number, neon: boolean } }? = nil
	if dom and (dom.id == "Aurore" or dom.id == "Paradoxe") then
		local c = buildCtx(model, 1)
		if c then
			local arr = {}
			for _, info in c.parts do
				local n = info.part.Name
				if not string.match(n, "^Star") and n ~= "Flower" and n ~= "Petal" then
					table.insert(arr, { part = info.part, ctx = info.ctx, lum = Mutations.unpaintLum(info.part.Color), neon = info.neon })
				end
			end
			painted = arr
		end
	end

	-- Copie fantôme (Écho) : rejoue la position et la pose d'il y a une seconde
	local ghost: Model? = nil
	local ghostMotors: { [string]: Motor6D } = {}
	local history: { { t: number, pivot: CFrame, pose: { [string]: CFrame } } } = {}
	if has.Echo then
		local was = model.Archivable
		model.Archivable = true
		local g = model:Clone()
		model.Archivable = was
		if g then
			for _, d in g:GetDescendants() do
				if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") or d:IsA("Highlight") or d:IsA("Seat") or d:IsA("Script") or d:IsA("LocalScript") then
					d:Destroy()
				elseif d:IsA("BasePart") then
					if d.Transparency < 0.95 then
						d.Material = Mat.ForceField
						d.Color = rgb(120, 220, 255)
						d.Transparency = 0.2
					end
					d.CanQuery = false
					d.CanTouch = false
					d.CanCollide = false
				elseif d:IsA("Motor6D") then
					ghostMotors[d.Name] = d
				end
			end
			for _, tag in g:GetTags() do
				g:RemoveTag(tag)
			end
			g:SetAttribute("CreatureId", nil)
			g:SetAttribute("Mutations", nil)
			g.Name = model.Name .. "_Echo"
			if g.PrimaryPart then
				g.PrimaryPart.Anchored = true
			end
			g.Parent = model.Parent
			ghost = g
		end
	end

	local rt = {}
	local lastPaint, lastSample = -1, -1

	function rt.step(_self: Runtime, t: number, dt: number)
		for _, s in spins do
			s.motor.Transform = CFrame.Angles(0, 0, t * s.speed)
		end
		for _, w in waves do
			w.motor.Transform = w.motor.Transform * CFrame.new(math.sin(t * 6 + w.k) * 0.035 * sc, 0, math.cos(t * 4.5 + w.k) * 0.02 * sc)
		end
		if painted and t - lastPaint > 0.1 then
			lastPaint = t
			local id = if dom then dom.id else "Aurore"
			local tt = t
			if id == "Paradoxe" then
				id = Mutations.PARADOX_CYCLE[(math.floor(t / PARADOX_PERIOD) % #Mutations.PARADOX_CYCLE) + 1]
				tt = 0
			end
			local paint = Mutations.PAINT[id]
			for _, e in painted do
				local col, mat, tr = paint(e.lum, e.neon, e.ctx, tt)
				e.part.Color = col
				if dom and dom.id == "Paradoxe" then
					e.part.Material = if e.neon then Mat.Neon else (mat or Mat.SmoothPlastic)
					e.part.Transparency = if e.neon then 0 else (tr or 0)
				end
			end
		end
		if ghost and ghost.PrimaryPart then
			if t - lastSample > 1 / 30 then
				lastSample = t
				local pose = {}
				for name, m in motors do
					pose[name] = m.Transform
				end
				table.insert(history, { t = t, pivot = model:GetPivot(), pose = pose })
			end
			while #history > 2 and history[2].t <= t - ECHO_DELAY do
				table.remove(history, 1)
			end
			local h = history[1]
			if h then
				ghost:PivotTo(h.pivot)
				for name, cfr in h.pose do
					local gm = ghostMotors[name]
					if gm then
						gm.Transform = cfr
					end
				end
			end
		end
	end

	function rt.destroy(_self: Runtime)
		if ghost then
			ghost:Destroy()
			ghost = nil
		end
	end

	if #spins == 0 and #waves == 0 and not painted and not ghost then
		return nil
	end
	return rt :: any
end

return Mutations
