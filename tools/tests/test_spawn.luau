local Sandbox = require("../lib/sandbox")
local Forge = Sandbox.load("src/shared")
local ok, n = 0, 0
for _, def in Forge.list() do
	n += 1
	local m = Forge.spawn(def.Id, nil, { parent = Sandbox.workspace, mutations = { "Kintsugi", "Constellation" } })
	local saddle, pass = m:FindFirstChild("Saddle"), m:FindFirstChild("PassengerSeat")
	print(string.format("%-24s %-9s saddle=%s passenger=%s income=%s", def.Id, def.Rarity, tostring(saddle ~= nil), tostring(pass ~= nil), Forge.Spawning.formatMoney(m:GetAttribute("Income"))))
	if saddle and ((pass ~= nil) == def.Passenger) then ok += 1 end
end
print(ok, "/", n)
local rng = Sandbox.Random.new(42)
local counts = {}
for i = 1, 20000 do
	local def = Forge.rollSpawn(0.5, rng)
	if def then counts[def.Rarity] = (counts[def.Rarity] or 0) + 1 end
end
for k, v in counts do print("d=0.5", k, v) end
