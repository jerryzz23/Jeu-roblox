-- Exécute le bundle Command Bar dans Lune avec des services factices.
local process = require("@lune/process")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Sandbox = require("../lib/sandbox")
local src = fs.readFile("dist/" .. (process.args[1] or "RatDesCavernes") .. ".commandbar.luau")
src = string.gsub(src, "workspace:Raycast%b()", "nil"); src = string.gsub(src, "workspace%.CurrentCamera", "nil")
local ws = roblox.Instance.new("Model"); ws.Name = "Workspace"
local starter = roblox.Instance.new("Folder"); starter.Name = "StarterGui"
local selected
local services = {
	StarterGui = starter,
	Selection = { Set = function(_, t) selected = t end },
	ChangeHistoryService = { SetWaypoint = function(_, n) print("waypoint:", n) end },
}
local env = {
	Random = Sandbox.Random,
	workspace = ws,
	game = { GetService = function(_, n) return services[n] end },
}
for _, k in { "Vector3", "Vector2", "CFrame", "Color3", "Enum", "Instance", "NumberSequence", "NumberSequenceKeypoint",
	"ColorSequence", "ColorSequenceKeypoint", "NumberRange", "UDim", "UDim2", "Font" } do
	env[k] = (roblox :: any)[k]
end
luau.load(src, { environment = env, debugName = "commandbar" })()
-- Lancé deux fois : l'icône doit être remplacée, pas dupliquée
luau.load(src, { environment = env, debugName = "commandbar" })()
local tray = starter:FindFirstChild("CreatureForgeIcons"):FindFirstChild("Tray")
local icons = 0
for _, c in tray:GetChildren() do if c:IsA("Frame") then icons += 1 end end
print("modèles dans workspace:", #ws:GetChildren(), "| icônes:", icons, "| sélection:", selected and selected[1].Name)
local m = ws:GetChildren()[1]
print("pivot:", m.PrimaryPart.CFrame.Position, "look:", m.PrimaryPart.CFrame.LookVector)
