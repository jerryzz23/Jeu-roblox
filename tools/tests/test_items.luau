local Sandbox = require("../lib/sandbox")
local Forge = Sandbox.load("src/shared")
for _, w in Forge.Weapons.List do
	local m = w.build({})
	local tool = Forge.Weapons.buildTool(w.Id)
	print(string.format("%-14s %3d pièces | portée %.1f | délai %.1fs | prix %s | tool:%s handle:%s", w.Id, m:GetAttribute("PartCount"), w.Range, w.Cooldown, Forge.Spawning.formatMoney(w.Price), tool.ClassName, tostring(tool:FindFirstChild("Handle") ~= nil)))
end
for _, s in Forge.Syringes.List do
	local m = s.build({})
	local tool = Forge.Syringes.buildTool(s.Id)
	print(string.format("%-18s %3d pièces | x%-4s | chance %5.1f%% | prix %s | ADN légendaire %d", s.Id, m:GetAttribute("PartCount"), tostring(s.Multiplier), s.Chance * 100, Forge.Spawning.formatMoney(s.Price), Forge.Syringes.dnaFor(s.Id, "Legendary")))
end
-- Boutique : 12 créneaux de 5 minutes consécutifs
local t0 = 1794500000
for k = 0, 5 do
	local stock = Forge.Syringes.stockAt(t0 + k * 300)
	local line = ""
	for _, e in stock do line ..= `{e.id:gsub("Seringue", "")}x{e.quantity} ` end
	print(`créneau {k} : {line}`)
end
print("même créneau, même stock :", #Forge.Syringes.stockAt(t0 + 10) == #Forge.Syringes.stockAt(t0 + 200), "réassort dans", Forge.Syringes.timeUntilRestock(t0 + 10), "s")
