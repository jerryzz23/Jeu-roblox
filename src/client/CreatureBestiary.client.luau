--!strict
--[[
	CreatureBestiary (StarterPlayerScripts)
	---------------------------------------
	Démo d'UI : un bouton "Bestiaire" ouvre un panneau listant l'icône de chaque
	créature enregistrée (grille UIGridLayout, tri par rareté). Icônes construites
	à la première ouverture.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CreatureForge = require(ReplicatedStorage:WaitForChild("CreatureForge"))

local OPEN = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FONT = Font.fromEnum(Enum.Font.FredokaOne)

local gui = Instance.new("ScreenGui")
gui.Name = "CreatureBestiary"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function corner(parent: Instance, scale: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = parent
end

-- Bouton d'ouverture
local toggle = Instance.new("TextButton")
toggle.Name = "Toggle"
toggle.AnchorPoint = Vector2.new(0, 1)
toggle.Position = UDim2.new(0, 16, 1, -16)
toggle.Size = UDim2.fromScale(0.13, 0.065)
toggle.BackgroundColor3 = Color3.fromRGB(34, 40, 56)
toggle.FontFace = FONT
toggle.Text = "Bestiaire"
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.TextScaled = true
toggle.AutoButtonColor = true
corner(toggle, 0.3)
local toggleRatio = Instance.new("UIAspectRatioConstraint")
toggleRatio.AspectRatio = 3
toggleRatio.Parent = toggle
local tsc = Instance.new("UITextSizeConstraint")
tsc.MaxTextSize = 24
tsc.Parent = toggle
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0.18, 0)
pad.PaddingBottom = UDim.new(0.18, 0)
pad.Parent = toggle
toggle.Parent = gui

-- Panneau
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.62, 0.7)
panel.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
panel.BackgroundTransparency = 0.08
panel.Visible = false
corner(panel, 0.04)
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(90, 100, 130)
panelStroke.Thickness = 2
panelStroke.Parent = panel
local panelScale = Instance.new("UIScale")
panelScale.Parent = panel
panel.Parent = gui

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromScale(0.04, 0.02)
title.Size = UDim2.fromScale(0.92, 0.09)
title.FontFace = FONT
title.Text = `Bestiaire — {#CreatureForge.list()} créature(s)`
title.TextColor3 = Color3.new(1, 1, 1)
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Grid"
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Position = UDim2.fromScale(0.03, 0.13)
scroll.Size = UDim2.fromScale(0.94, 0.84)
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 6
scroll.Parent = panel

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromScale(0.23, 0)
grid.CellPadding = UDim2.new(0.02, 0, 0, 10)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = scroll
local cellRatio = Instance.new("UIAspectRatioConstraint")
cellRatio.AspectRatio = 1
cellRatio.Parent = grid

-- Les icônes (modèles 3D en ViewportFrame) sont construites à la première ouverture,
-- en densité réduite, pour ne pas alourdir l'arrivée du joueur.
local built = false
local function buildIcons()
	if built then
		return
	end
	built = true
	for i, def in CreatureForge.list() do
		CreatureForge.buildIcon(def.Id, scroll, { layoutOrder = i, detail = 0.4 })
		if i % 3 == 0 then
			task.wait()
		end
	end
end

local open = false
local current: Tween? = nil
toggle.Activated:Connect(function()
	open = not open
	if current then
		current:Cancel()
	end
	if open then
		task.spawn(buildIcons)
		panel.Visible = true
		panelScale.Scale = 0.85
		current = TweenService:Create(panelScale, OPEN, { Scale = 1 })
	else
		current = TweenService:Create(panelScale, CLOSE, { Scale = 0.85 })
	end
	local tw = current :: Tween
	tw:Play()
	if not open then
		tw.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed and not open then
				panel.Visible = false
			end
		end)
	end
end)

gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
