local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local game = roblox.deserializePlace(fs.readFile("dist/CreatureForge.rbxl"))
local cf = game:GetService("ReplicatedStorage"):FindFirstChild("CreatureForge")
print(cf.ClassName, #cf:FindFirstChild("Creatures"):GetChildren(), "modules de personnages ;", #cf:GetChildren(), "enfants")
for _, s in game:GetService("ServerScriptService"):GetChildren() do print("serveur :", s.Name, s.ClassName) end
for _, s in game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts"):GetChildren() do print("client :", s.Name, s.ClassName) end
for _, t in game:GetService("StarterPack"):GetChildren() do
	local h = t:FindFirstChild("Handle")
	print("sac de départ :", t.Name, t.ClassName, "Handle", h ~= nil, "ancré", h and h.Anchored)
end
local ws = game:GetService("Workspace")
local map, vitrine = ws:FindFirstChild("Carte"), ws:FindFirstChild("Vitrine")
print("carte :", map ~= nil, map and map:HasTag("CreatureForge"), "vitrine :", vitrine ~= nil)
local tagged, anchoredRoots, n = 0, 0, 0
for _, m in vitrine.Creatures:GetChildren() do
	n += 1
	if m:HasTag("CreatureForge") then tagged += 1 end
	if m.PrimaryPart and m.PrimaryPart.Anchored then anchoredRoots += 1 end
end
print(string.format("personnages : %d (tag animateur %d, racine ancrée %d)", n, tagged, anchoredRoots))
print("tapis :", #vitrine.Tapis:GetChildren(), "présentoirs :", #vitrine.Objets:FindFirstChild("Battes et seringues"):GetChildren(), #vitrine.Objets.ADN:GetChildren())
local machines, tapis = 0, 0
for _, d in map:GetDescendants() do
	if d.Name == "MachineADN" and d:IsA("Model") then machines += 1 end
	if d.Name == "Tapis" and d:IsA("Model") then tapis += 1 end
end
print("dans les bases : machines à ADN", machines, "tapis", tapis)
