local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local game = roblox.deserializePlace(fs.readFile("dist/CreatureForge.rbxl"))
local cf = game:GetService("ReplicatedStorage"):FindFirstChild("CreatureForge")
print(cf.ClassName, #cf:FindFirstChild("Creatures"):GetChildren(), "créatures;", #cf:GetChildren(), "enfants")
print(game:GetService("ServerScriptService"):FindFirstChild("CreatureShowcase").ClassName)
for _, s in game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts"):GetChildren() do print(s.Name, s.ClassName) end
