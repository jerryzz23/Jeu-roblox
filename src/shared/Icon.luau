--!strict
--[[
	CreatureForge.Icon
	------------------
	Carte d'icône d'inventaire pour une créature :
	  • fond en dégradé (UIGradient) aux coins arrondis (UICorner) ;
	  • contour de rareté en dégradé (UIStroke + UIGradient) ;
	  • halo, losanges décoratifs, ombre au sol, reflet brillant ;
	  • la créature en 3D (ViewportFrame + Camera cadrée sur sa boîte englobante) ;
	  • pastille de rareté, gemme, plaque de nom.
	La carte est carrée (UIAspectRatioConstraint) et remplit sa cellule par défaut :
	parfait dans une grille UIGridLayout.
]]

local Kit = require(script.Parent.Kit)
local Rarity = require(script.Parent.Rarity)
local Types = require(script.Parent.Types)

local Icon = {}

export type IconOptions = {
	size: UDim2?, -- défaut : UDim2.fromScale(1, 1)
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	showName: boolean?, -- défaut : true
	showRarity: boolean?, -- défaut : true
}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local FONT = Font.fromEnum(Enum.Font.FredokaOne)

local function corner(parent: Instance, scale: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = parent
	return c
end

local function gradient(parent: Instance, colors: { Color3 }, rotation: number, transparency: { number }?): UIGradient
	local g = Instance.new("UIGradient")
	local kps = {}
	for i, c in colors do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / math.max(#colors - 1, 1), c))
	end
	if #kps == 1 then
		table.insert(kps, ColorSequenceKeypoint.new(1, colors[1]))
	end
	g.Color = ColorSequence.new(kps)
	if transparency then
		local tk = {}
		for i, t in transparency do
			table.insert(tk, NumberSequenceKeypoint.new((i - 1) / math.max(#transparency - 1, 1), t))
		end
		g.Transparency = NumberSequence.new(tk)
	end
	g.Rotation = rotation
	g.Parent = parent
	return g
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.Parent = parent
	return s
end

local function frame(name: string, parent: Instance, size: UDim2, pos: UDim2, color: Color3, transparency: number, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function label(name: string, parent: Instance, text: string, color: Color3, maxSize: number): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.5)
	t.Size = UDim2.fromScale(0.9, 0.78)
	t.BackgroundTransparency = 1
	t.FontFace = FONT
	t.Text = text
	t.TextColor3 = color
	t.TextScaled = true
	t.ZIndex = 6
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.MinTextSize = 6
	c.Parent = t
	t.Parent = parent
	return t
end

--- Calcule le CFrame de caméra qui cadre `model` selon le thème de l'icône.
function Icon.frameCamera(model: Model, camera: Camera, theme: Types.IconTheme)
	local center, size = Kit.visibleBounds(model)
	local root = model.PrimaryPart
	local ref = if root then root.CFrame else CFrame.identity
	local radius = size.Magnitude * 0.5
	local dist = radius / math.sin(math.rad(camera.FieldOfView) / 2) / (theme.zoom or 1)
	local yaw, pitch = math.rad(theme.yaw or 30), math.rad(theme.pitch or 15)
	local dir = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
	local target = ref * center
	camera.CFrame = CFrame.lookAt(target + ref:VectorToWorldSpace(dir) * dist, target)
end

--- Construit la carte d'icône de `def` et la parente à `parent`.
function Icon.build(def: Types.CreatureDef, parent: Instance?, opts: IconOptions?): Frame
	local o: IconOptions = opts or {}
	local theme = def.Icon
	local tier = Rarity.get(def.Rarity)

	-- Carte
	local card = Instance.new("Frame")
	card.Name = "Icon_" .. def.Id
	card.Size = o.size or UDim2.fromScale(1, 1)
	card.Position = o.position or UDim2.new()
	card.AnchorPoint = o.anchorPoint or Vector2.zero
	card.BackgroundColor3 = WHITE
	card.BorderSizePixel = 0
	card.LayoutOrder = o.layoutOrder or tier.order
	card:SetAttribute("CreatureId", def.Id)
	corner(card, 0.16)
	gradient(card, { theme.top, theme.bottom }, 90)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = card
	gradient(stroke(card, WHITE, 3), { tier.light, tier.color, tier.dark, tier.color }, 45)

	-- Losanges décoratifs (cristaux stylisés)
	local motif = theme.motif or theme.glow
	for _, m in { { 0.13, 0.3, 0.1 }, { 0.87, 0.24, 0.07 }, { 0.1, 0.62, 0.06 }, { 0.9, 0.55, 0.09 } } do
		local d = frame("Motif", card, UDim2.fromScale(m[3], m[3]), UDim2.fromScale(m[1], m[2]), motif, 0.55, 1)
		d.Rotation = 45
		gradient(d, { WHITE, motif }, 90, { 0.2, 0.7 })
	end

	-- Halo
	for i, h in { { 0.92, 0.9 }, { 0.68, 0.82 }, { 0.44, 0.72 } } do
		local g = frame("Glow" .. i, card, UDim2.fromScale(h[1], h[1]), UDim2.fromScale(0.5, 0.47), theme.glow, h[2], 1)
		corner(g, 0.5)
	end

	-- Ombre au sol
	local shadow = frame("Shadow", card, UDim2.fromScale(0.62, 0.11), UDim2.fromScale(0.5, 0.71), BLACK, 0.55, 1)
	corner(shadow, 0.5)

	-- Créature en 3D
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Viewport"
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(160, 160, 176)
	vf.LightColor = Color3.fromRGB(255, 248, 236)
	vf.LightDirection = Vector3.new(-0.6, -1, 0.5)
	vf.ZIndex = 2
	vf.Parent = card
	local cam = Instance.new("Camera")
	cam.FieldOfView = 28
	cam.Parent = vf
	vf.CurrentCamera = cam
	local model = def.build({ effects = false, outline = false, animated = false })
	model.Parent = vf
	Icon.frameCamera(model, cam, theme)

	-- Reflet brillant
	local sheen = frame("Sheen", card, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), WHITE, 0, 3)
	corner(sheen, 0.16)
	gradient(sheen, { WHITE }, 35, { 1, 1, 0.82, 1, 1 })

	-- Pastille de rareté
	if o.showRarity ~= false then
		local pill = frame("Rarity", card, UDim2.fromScale(0.44, 0.12), UDim2.fromScale(0.27, 0.1), WHITE, 0, 5)
		corner(pill, 0.5)
		gradient(pill, { tier.light, tier.color }, 90)
		stroke(pill, tier.dark, 1.5)
		local t = label("Label", pill, tier.label, tier.dark, 16)
		t.Size = UDim2.fromScale(0.86, 0.7)

		local gem = frame("Gem", card, UDim2.fromScale(0.085, 0.085), UDim2.fromScale(0.89, 0.1), WHITE, 0, 5)
		gem.Rotation = 45
		gradient(gem, { tier.light, tier.color, tier.dark }, 45)
		stroke(gem, BLACK, 1.5, 0.3)
	end

	-- Plaque de nom
	if o.showName ~= false then
		local plate = frame("NamePlate", card, UDim2.fromScale(0.9, 0.17), UDim2.fromScale(0.5, 0.86), BLACK, 0.3, 5)
		corner(plate, 0.4)
		gradient(plate, { WHITE }, 90, { 0.4, 0 })
		stroke(plate, tier.color, 1.5, 0.35)
		local t = label("Name", plate, def.DisplayName, WHITE, 26)
		stroke(t, BLACK, 1.5)
	end

	card.Parent = parent
	return card
end

return Icon
