--[[
	Génère, pour chaque créature, un script AUTONOME à coller dans la Command Bar
	de Roblox Studio (aucun ModuleScript requis) :
	  dist/<Id>.commandbar.luau

	Le script embarque Kit, Fx, Rarity, Types, Icon + la créature, construit le modèle
	devant la caméra, le sélectionne et ajoute son icône dans StarterGui.

	Usage : lune run tools/bundle [Id ...]   (sans argument : toutes les créatures)
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local SHARED = "src/shared"

local function modulePath(name: string): string
	for _, p in { `{SHARED}/{name}.luau`, `{SHARED}/Creatures/{name}.luau` } do
		if fs.isFile(p) then
			return p
		end
	end
	error("Module introuvable : " .. name)
end

local function requiresOf(src: string): { string }
	local out = {}
	for name in string.gmatch(src, "require%(script[%.%a]*%.(%w+)%)") do
		table.insert(out, name)
	end
	return out
end

local function transform(src: string): string
	src = string.gsub(src, "^%-%-!strict\n", "")
	src = string.gsub(src, "require%(script[%.%a]*%.(%w+)%)", '__require("%1")')
	src = string.gsub(src, "\nexport type ", "\ntype ")
	return src
end

local function indent(src: string): string
	return (string.gsub(src, "\n(.)", "\n\t%1"))
end

local function bundle(id: string): string
	local order: { string } = {}
	local seen: { [string]: boolean } = {}
	local function visit(name: string)
		if seen[name] then
			return
		end
		seen[name] = true
		for _, dep in requiresOf(fs.readFile(modulePath(name))) do
			visit(dep)
		end
		table.insert(order, name)
	end
	visit("Icon")
	visit(id)

	local chunks = {
		`-- CreatureForge — {id}`,
		"-- Script autonome pour la COMMAND BAR de Roblox Studio (View > Command Bar).",
		"-- Collez TOUT ce fichier puis appuyez sur Entrée : la créature apparaît devant la caméra,",
		"-- est sélectionnée, et son icône UI est ajoutée dans StarterGui > CreatureForgeIcons.",
		"-- Généré par `lune run tools/bundle` à partir de src/shared — ne pas modifier à la main.",
		"",
		"local __modules, __cache = {}, {}",
		"local function __require(name)",
		"\tlocal m = __cache[name]",
		"\tif m == nil then",
		"\t\tm = __modules[name]()",
		"\t\t__cache[name] = m",
		"\tend",
		"\treturn m",
		"end",
		"",
	}
	for _, name in order do
		table.insert(chunks, `__modules["{name}"] = function()`)
		table.insert(chunks, "\t" .. indent(transform(fs.readFile(modulePath(name)))))
		table.insert(chunks, "end")
		table.insert(chunks, "")
	end
	table.insert(
		chunks,
		([[
-- ============================================================================
-- Entrée
-- ============================================================================
do
	local def = __require("%s")
	local Icon = __require("Icon")

	-- Position : 14 studs devant la caméra, posée au sol, tournée vers la caméra
	local look = Vector3.new(0, 0, -1)
	local pos = Vector3.zero
	local camera = workspace.CurrentCamera
	if camera then
		local flat = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
		if flat.Magnitude > 0.01 then
			look = flat.Unit
		end
		pos = camera.CFrame.Position + look * 14
	end
	local hit = workspace:Raycast(pos + Vector3.new(0, 50, 0), Vector3.new(0, -300, 0))
	local ground = if hit then hit.Position else Vector3.new(pos.X, 0, pos.Z)
	local model = def.build({ cframe = CFrame.lookAt(ground, ground - look), parent = workspace })

	-- Icône UI (visible dans l'éditeur via StarterGui)
	local StarterGui = game:GetService("StarterGui")
	local gui = StarterGui:FindFirstChild("CreatureForgeIcons")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "CreatureForgeIcons"
		gui.ResetOnSpawn = false
		gui.Parent = StarterGui
	end
	local tray = gui:FindFirstChild("Tray")
	if not tray then
		tray = Instance.new("Frame")
		tray.Name = "Tray"
		tray.BackgroundTransparency = 1
		tray.AnchorPoint = Vector2.new(0, 1)
		tray.Position = UDim2.new(0, 16, 1, -16)
		tray.Size = UDim2.fromScale(0.9, 0.18)
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, 10)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = tray
		tray.Parent = gui
	end
	local old = tray:FindFirstChild("Icon_" .. def.Id)
	if old then
		old:Destroy()
	end
	Icon.build(def, tray)

	pcall(function()
		game:GetService("Selection"):Set({ model })
	end)
	pcall(function()
		game:GetService("ChangeHistoryService"):SetWaypoint("CreatureForge : " .. def.DisplayName)
	end)
	print(("[CreatureForge] %%s créé (%%d pièces) à %%s"):format(def.DisplayName, model:GetAttribute("PartCount"), tostring(ground)))
end
]]):format(id)
	)
	return table.concat(chunks, "\n")
end

local Sandbox = require("./lib/sandbox")
local ids = table.clone(process.args)
if #ids == 0 then
	for _, def in Sandbox.load(SHARED).list() do
		table.insert(ids, def.Id)
	end
end

fs.writeDir("dist")
for _, id in ids do
	local out = bundle(id)
	fs.writeFile(`dist/{id}.commandbar.luau`, out)
	print(`dist/{id}.commandbar.luau ({#out} octets)`)
end
