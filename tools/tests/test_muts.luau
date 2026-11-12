local Sandbox = require("../lib/sandbox")
local Forge = Sandbox.load("src/shared")
local M = Forge.Mutations
print("multi Vitrail+Kintsugi", M.multiplier({ "Vitrail", "Kintsugi" }), "none", M.multiplier({}))
for _, d in Forge.Spawning.odds(0.95) do print(d.rarity, d.chance) end
print(Forge.Spawning.formatMoney(1400000), Forge.Spawning.formatMoney(950), Forge.Spawning.formatMoney(14000))
local def = Forge.list()[1]
for _, m in M.List do
	local model = def.build({ scale = 1 })
	local before = #model:GetDescendants()
	M.apply(model, { m.id })
	print(string.format("%-14s +%d inst  multi=%s", m.id, #model:GetDescendants() - before, tostring(model:GetAttribute("Multiplier"))))
end
local model = def.build({ scale = 1 })
M.apply(model, { "Fossile", "Horloger", "Kintsugi" })
print(model:GetAttribute("Mutations"), model:GetAttribute("Multiplier"), model:GetAttribute("Mutation"))
