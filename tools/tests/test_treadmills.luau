local Sandbox = require("../lib/sandbox")
local Forge = Sandbox.load("src/shared")
local T = Forge.Treadmills
for _, def in T.list() do
	local m = T.spawn(def.Id, nil, { parent = Sandbox.workspace })
	local run = m:FindFirstChild("RunSurface", true)
	local nxt = T.nextOf(def.Id)
	print(string.format("%2d %-18s %5d pièces | prix %s | +%s vitesse/s | surface=%s ancrée=%s | suivant=%s", def.Tier, def.Id, m:GetAttribute("PartCount"), Forge.Spawning.formatMoney(def.Price), Forge.Spawning.formatMoney(def.Gain), tostring(run ~= nil), tostring(run and run.Anchored), nxt and nxt.Id or "-"))
end
