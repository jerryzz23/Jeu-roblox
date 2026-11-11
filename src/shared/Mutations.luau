--!strict
--[[
	CreatureForge.Mutations
	-----------------------
	Variantes rares applicables à N'IMPORTE QUELLE créature après sa construction :
	recoloration (dégradé selon la luminosité de chaque pièce), matériau, lueur des parties
	Neon, particules et lumière dédiées, multiplicateur de valeur.

	    local rat = CreatureForge.spawn("RatDesCavernes", cf, { mutation = "Gold" })
	    Mutations.apply(model, "Rainbow")      -- sur un modèle déjà construit
	    Mutations.roll(rng)                    -- tirage aléatoire selon les chances (nil = aucune)
]]

local Kit = require(script.Parent.Kit)
local Fx = require(script.Parent.Fx)

export type Mutation = {
	id: string,
	label: string,
	chance: number, -- en % (tirage indépendant de la rareté)
	multiplier: number, -- bonus de valeur / de gains
	ramp: { Color3 }, -- couleurs du sombre au clair (nil si `rainbow`)
	glow: Color3, -- couleur des parties Neon + lumière
	material: Enum.Material?, -- matériau imposé aux pièces non-Neon
	rainbow: boolean?, -- teinte selon la position le long du corps
	transparency: number?, -- transparence ajoutée aux pièces claires (cristal)
	badge: { Color3 }, -- dégradé de la pastille d'icône
	particle: Fx.ParticleDef,
}

local rgb = Color3.fromRGB

local function sparkle(name: string, colors: { Color3 }, rate: number, size: number): Fx.ParticleDef
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
		acceleration = Vector3.new(0, 0.4, 0),
		drag = 1,
		lightEmission = 1,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-90, 90),
		volume = true,
	}
end

local Mutations = {}

Mutations.List = {
	{
		id = "Gold",
		label = "DORÉ",
		chance = 8,
		multiplier = 2,
		ramp = { rgb(110, 58, 8), rgb(196, 120, 20), rgb(255, 196, 54), rgb(255, 238, 150) },
		glow = rgb(255, 214, 90),
		badge = { rgb(255, 240, 150), rgb(230, 150, 20) },
		particle = sparkle("GoldSparkle", { rgb(255, 230, 120), rgb(255, 180, 40) }, 8, 0.35),
	},
	{
		id = "Diamond",
		label = "DIAMANT",
		chance = 4,
		multiplier = 3,
		ramp = { rgb(40, 90, 150), rgb(90, 180, 230), rgb(170, 236, 255), rgb(240, 252, 255) },
		glow = rgb(160, 240, 255),
		material = Enum.Material.Glass,
		transparency = 0.15,
		badge = { rgb(230, 252, 255), rgb(70, 170, 240) },
		particle = sparkle("DiamondSparkle", { rgb(255, 255, 255), rgb(150, 230, 255) }, 10, 0.4),
	},
	{
		id = "Toxic",
		label = "TOXIQUE",
		chance = 3,
		multiplier = 4,
		ramp = { rgb(20, 40, 10), rgb(46, 110, 24), rgb(120, 220, 40), rgb(210, 255, 120) },
		glow = rgb(150, 255, 40),
		badge = { rgb(210, 255, 120), rgb(60, 160, 20) },
		particle = {
			name = "ToxicBubbles",
			texture = Fx.TEXTURES.sparkle,
			colors = { rgb(170, 255, 60), rgb(90, 200, 30) },
			sizes = { 0.15, 0.35, 0 },
			transparencies = { 0.2, 0.3, 1 },
			lifetime = NumberRange.new(1.2, 2.2),
			rate = 9,
			speed = NumberRange.new(0.4, 1),
			spread = Vector2.new(30, 30),
			acceleration = Vector3.new(0, 0.6, 0),
			lightEmission = 0.8,
			volume = true,
		},
	},
	{
		id = "Infernal",
		label = "INFERNAL",
		chance = 2,
		multiplier = 5,
		ramp = { rgb(30, 8, 6), rgb(110, 20, 8), rgb(230, 80, 20), rgb(255, 200, 70) },
		glow = rgb(255, 110, 30),
		badge = { rgb(255, 210, 90), rgb(200, 30, 10) },
		particle = {
			name = "InfernalEmbers",
			texture = Fx.TEXTURES.spark,
			colors = { rgb(255, 220, 120), rgb(255, 90, 20), rgb(140, 20, 10) },
			sizes = { 0.25, 0.15, 0 },
			lifetime = NumberRange.new(0.8, 1.6),
			rate = 14,
			speed = NumberRange.new(0.8, 2),
			spread = Vector2.new(25, 25),
			acceleration = Vector3.new(0, 1.2, 0),
			lightEmission = 1,
			volume = true,
		},
	},
	{
		id = "Void",
		label = "OMBRE",
		chance = 1,
		multiplier = 7,
		ramp = { rgb(8, 4, 16), rgb(30, 14, 56), rgb(72, 30, 128), rgb(150, 80, 230) },
		glow = rgb(200, 70, 255),
		badge = { rgb(220, 150, 255), rgb(60, 10, 120) },
		particle = {
			name = "VoidMist",
			texture = Fx.TEXTURES.smoke,
			colors = { rgb(120, 40, 200), rgb(20, 6, 40) },
			sizes = { 0.6, 1.4 },
			transparencies = { 1, 0.5, 1 },
			lifetime = NumberRange.new(1.5, 2.5),
			rate = 10,
			speed = NumberRange.new(0.1, 0.4),
			spread = Vector2.new(180, 180),
			lightEmission = 0.3,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-30, 30),
			volume = true,
		},
	},
	{
		id = "Rainbow",
		label = "ARC-EN-CIEL",
		chance = 0.5,
		multiplier = 10,
		ramp = {},
		rainbow = true,
		glow = rgb(255, 255, 255),
		badge = { rgb(255, 90, 90), rgb(255, 220, 60), rgb(80, 220, 120), rgb(70, 150, 255), rgb(190, 90, 255) },
		particle = sparkle(
			"RainbowSparkle",
			{ rgb(255, 80, 80), rgb(255, 220, 60), rgb(80, 230, 120), rgb(70, 150, 255), rgb(200, 90, 255) },
			12,
			0.4
		),
	},
} :: { Mutation }

local byId: { [string]: Mutation } = {}
for _, m in Mutations.List do
	byId[m.id] = m
end

function Mutations.get(id: string): Mutation?
	return byId[id]
end

--- Tirage : renvoie une mutation selon les chances (en %), ou nil.
function Mutations.roll(rng: Random?): Mutation?
	local r = (rng or Random.new()):NextNumber(0, 100)
	local acc = 0
	for i = #Mutations.List, 1, -1 do -- des plus rares aux plus communes
		local m = Mutations.List[i]
		acc += m.chance
		if r < acc then
			return m
		end
	end
	return nil
end

local function sampleRamp(ramp: { Color3 }, x: number): Color3
	local f = math.clamp(x, 0, 1) * (#ramp - 1)
	local i = math.min(math.floor(f) + 1, #ramp - 1)
	return ramp[i]:Lerp(ramp[i + 1], f - (i - 1))
end

--- Nouvelle couleur d'une pièce (luminosité d'origine -> dégradé de la mutation).
--- `along` = position relative le long du corps (0 = avant, 1 = arrière), pour l'arc-en-ciel.
function Mutations.recolor(m: Mutation, c: Color3, isNeon: boolean, along: number): Color3
	local lum = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	if m.rainbow then
		local h = (along * 0.85 + lum * 0.15) % 1
		return Color3.fromHSV(h, if isNeon then 0.45 else 0.78, 0.45 + 0.55 * math.sqrt(lum))
	end
	if isNeon then
		return m.glow
	end
	return sampleRamp(m.ramp, lum ^ 0.85)
end

--- Applique la mutation `id` au modèle (une seule fois). Renvoie le modèle.
function Mutations.apply(model: Model, id: string): Model
	local m = byId[id]
	assert(m, `CreatureForge: mutation inconnue "{id}"`)
	if model:GetAttribute("Mutation") then
		return model
	end
	local root = model.PrimaryPart
	local ref = if root then root.CFrame else CFrame.identity
	local center, size = Kit.visibleBounds(model)
	local zMin = center.Z - size.Z / 2

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 then
			local isNeon = d.Material == Enum.Material.Neon
			local along = (ref:PointToObjectSpace(d.CFrame.Position).Z - zMin) / math.max(size.Z, 0.01)
			d.Color = Mutations.recolor(m, d.Color, isNeon, along)
			if m.material and not isNeon then
				d.Material = m.material
				local lum = 0.299 * d.Color.R + 0.587 * d.Color.G + 0.114 * d.Color.B
				if m.transparency and lum > 0.55 then
					d.Transparency = math.max(d.Transparency, m.transparency)
				end
			end
		elseif d:IsA("PointLight") then
			d.Color = m.glow
		elseif d:IsA("ParticleEmitter") and m.rainbow then
			-- les effets d'origine gardent leur forme, l'arc-en-ciel les colore
			d.Color = ColorSequence.new(Color3.fromRGB(255, 120, 200), Color3.fromRGB(120, 200, 255))
		end
	end

	-- Halo de particules + lumière autour du corps
	if root then
		local scale = (model:GetAttribute("Scale") :: number?) or 1
		local aura = Instance.new("Part")
		aura.Name = "FX_Mutation"
		aura.Size = size * 0.9
		aura.Transparency = 1
		aura.Anchored = false
		aura.CanCollide = false
		aura.CanTouch = false
		aura.CanQuery = false
		aura.Massless = true
		aura.CastShadow = false
		aura.CFrame = ref * CFrame.new(center)
		local w = Instance.new("Weld")
		w.Part0 = root
		w.Part1 = aura
		w.C0 = CFrame.new(center)
		w.Parent = aura
		aura.Parent = model
		Fx.particles(aura, m.particle, scale)
		Fx.light(aura, { color = m.glow, range = math.max(size.X, size.Z) * 0.8 / scale, brightness = 1.2 }, scale)
	end

	model:SetAttribute("Mutation", m.id)
	model:SetAttribute("Multiplier", m.multiplier)
	return model
end

return Mutations
