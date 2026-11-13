--[[
	Génère un fichier de jeu prêt à ouvrir dans Roblox Studio :
	  dist/CreatureForge.rbxl
	    ReplicatedStorage.CreatureForge       (tous les ModuleScripts de src/shared)
	    ServerScriptService.CreatureShowcase  (démo : les créatures se promènent dans leur zone)
	    StarterPlayerScripts.CreatureAnimator / CreatureBestiary
	    Workspace : la carte (bases, canyon en pente, 4 zones) + point d'apparition

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
scriptFrom("Script", "Bases", "src/server/Bases.server.luau").Parent = game:GetService("ServerScriptService")

local starterPlayer = game:GetService("StarterPlayer")
local sps = Instance.new("StarterPlayerScripts")
sps.Parent = starterPlayer
scriptFrom("LocalScript", "CreatureAnimator", "src/client/CreatureAnimator.client.luau").Parent = sps
scriptFrom("LocalScript", "CreatureBestiary", "src/client/CreatureBestiary.client.luau").Parent = sps

local workspace = game:GetService("Workspace")
-- La carte du jeu (canyon, bases, pente, zones) est construite ici et enregistrée dans la place
local Sandbox = require("./lib/sandbox")
local Forge = Sandbox.load("src/shared")
local map = Forge.Map.build({})
map.Parent = workspace
print(`carte : {map:GetAttribute("PartCount")} pièces`)

local lighting = game:GetService("Lighting")
lighting.ClockTime = 14.5
lighting.Brightness = 2.5
lighting.OutdoorAmbient = roblox.Color3.fromRGB(150, 150, 160)
-- Brume légère et ciel bleu comme sur l'illustration de la carte
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.28
atmosphere.Offset = 0.1
atmosphere.Color = roblox.Color3.fromRGB(190, 210, 240)
atmosphere.Decay = roblox.Color3.fromRGB(110, 120, 170)
atmosphere.Glare = 0.2
atmosphere.Haze = 1.2
atmosphere.Parent = lighting

fs.writeDir("dist")
fs.writeFile("dist/CreatureForge.rbxl", roblox.serializePlace(game))
print("dist/CreatureForge.rbxl")
