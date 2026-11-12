local Sandbox = require("../lib/sandbox")
local Vector3 = require("@lune/roblox").Vector3
local Forge = Sandbox.load("src/shared")
local t0 = os.clock()
local map = Forge.Map.build({ parent = Sandbox.workspace })
local n, collide, byFolder = 0, 0, {}
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
		if d.CanCollide then collide += 1 end
		local top = d
		while top.Parent and top.Parent ~= map do top = top.Parent end
		byFolder[top.Name] = (byFolder[top.Name] or 0) + 1
	end
end
print(string.format("carte : %d pièces (%d collidables) en %.1fs", n, collide, os.clock() - t0))
for k, v in byFolder do print("  ", k, v) end
print("d(0,0,-320) =", Forge.Map.distanceOf(Vector3.new(0, 0, -320)), Forge.Map.zoneOf(0.5).label)
print("montée ?", Forge.Map.isClimbing(Vector3.new(0, 1, 8)), "descente ?", Forge.Map.isClimbing(Vector3.new(0, -1, -8)))
local plots = 0
for _, d in map:GetDescendants() do if d:IsA("Model") and d:GetAttribute("PlotIndex") then plots += 1 end end
print("bases :", plots, "spawn :", map:FindFirstChild("SpawnLocation", true) ~= nil)
