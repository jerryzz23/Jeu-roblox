local Sandbox = require("../lib/sandbox")
local Forge = Sandbox.load("src/shared")
local D = Forge.DnaMachine
local Syr = Forge.Syringes
-- Chances par rareté d'ADN (seringue basique puis seringue du Néant)
for _, rarity in Forge.Rarity.Order do
	for _, mult in { 1, 20 } do
		local amount = Syr.BASE_DNA[rarity] * mult
		local parts = {}
		for _, o in D.odds(rarity, amount) do
			table.insert(parts, string.format("%s %.2f%%", o.rarity, o.chance * 100))
		end
		print(string.format("%-9s x%-2d (%6d ADN) : %s", rarity, mult, amount, table.concat(parts, " | ")))
	end
end
-- Tirages réels
local rng = Sandbox.Random.new(7)
local counts = {}
for _ = 1, 20000 do
	local def = Forge.hatch("Legendary", 30, rng)
	if def then counts[def.Rarity] = (counts[def.Rarity] or 0) + 1 end
end
for k, v in counts do print("  hatch Legendary :", k, v) end
-- Modèles
local m = D.build({ parent = Sandbox.workspace, color = require("@lune/roblox").Color3.fromRGB(255, 110, 180) })
print("machine :", m:GetAttribute("PartCount"), "pièces, prompt :", m:FindFirstChild("DepositPrompt", true) ~= nil, "écran :", m:FindFirstChild("Status", true) ~= nil)
local line = {}
for _, rarity in Forge.Rarity.Order do
	local dna = D.buildDna(rarity, { parent = Sandbox.workspace })
	local tool = D.buildDnaTool(rarity, Syr.BASE_DNA[rarity])
	assert(tool:FindFirstChild("Handle"), "pas de Handle")
	table.insert(line, string.format("%s %d", rarity, dna:GetAttribute("PartCount")))
end
print("fioles d'ADN :", table.concat(line, " | "))
