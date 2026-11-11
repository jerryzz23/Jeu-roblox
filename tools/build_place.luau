--[[
	Génère un fichier de jeu prêt à ouvrir dans Roblox Studio :
	  dist/CreatureForge.rbxl
	    ReplicatedStorage.CreatureForge       (tous les ModuleScripts de src/shared)
	    ServerScriptService.CreatureShowcase  (démo : les 21 créatures se promènent)
	    StarterPlayerScripts.CreatureAnimator / CreatureBestiary
	    Workspace : sol + point d'apparition

	Usage : lune run tools/build_place
]]

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance

local function scriptFrom(className: string, name: string, path: string)
	local s = Instance.new(className)
	s.Name = name
	s.Source = fs.readFile(path)
	return s
end

-- Reproduit l'arborescence Rojo : init.luau -> ModuleScript parent, dossiers -> Folder
local function moduleTree(dir: string, name: string)
	local root
	if fs.isFile(dir .. "/init.luau") then
		root = scriptFrom("ModuleScript", name, dir .. "/init.luau")
	else
		root = Instance.new("Folder")
		root.Name = name
	end
	local entries = fs.readDir(dir)
	table.sort(entries)
	for _, entry in entries do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			moduleTree(path, entry).Parent = root
		elseif entry ~= "init.luau" and string.sub(entry, -5) == ".luau" then
			scriptFrom("ModuleScript", string.sub(entry, 1, -6), path).Parent = root
		end
	end
	return root
end

local game = Instance.new("DataModel")

moduleTree("src/shared", "CreatureForge").Parent = game:GetService("ReplicatedStorage")
scriptFrom("Script", "CreatureShowcase", "src/server/CreatureShowcase.server.luau").Parent = game:GetService("ServerScriptService")

local starterPlayer = game:GetService("StarterPlayer")
local sps = Instance.new("StarterPlayerScripts")
sps.Parent = starterPlayer
scriptFrom("LocalScript", "CreatureAnimator", "src/client/CreatureAnimator.client.luau").Parent = sps
scriptFrom("LocalScript", "CreatureBestiary", "src/client/CreatureBestiary.client.luau").Parent = sps

local workspace = game:GetService("Workspace")
local ground = Instance.new("Part")
ground.Name = "Ground"
ground.Anchored = true
ground.Size = roblox.Vector3.new(400, 2, 400)
ground.CFrame = roblox.CFrame.new(0, -1, 60)
ground.Color = roblox.Color3.fromRGB(120, 168, 92)
ground.Material = roblox.Enum.Material.Grass
ground.TopSurface = roblox.Enum.SurfaceType.Smooth
ground.Parent = workspace

local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Anchored = true
spawn.Size = roblox.Vector3.new(8, 1, 8)
spawn.CFrame = roblox.CFrame.new(0, 0.5, 0) * roblox.CFrame.Angles(0, math.pi, 0)
spawn.Color = roblox.Color3.fromRGB(240, 240, 240)
spawn.Material = roblox.Enum.Material.SmoothPlastic
spawn.Parent = workspace

local lighting = game:GetService("Lighting")
lighting.ClockTime = 14.5
lighting.Brightness = 2.5
lighting.OutdoorAmbient = roblox.Color3.fromRGB(150, 150, 160)

fs.writeDir("dist")
fs.writeFile("dist/CreatureForge.rbxl", roblox.serializePlace(game))
print("dist/CreatureForge.rbxl")
