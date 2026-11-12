local Sandbox = require("../lib/sandbox")
local Forge = Sandbox.load("src/shared")
for _, d in { 0, 0.2, 0.4, 0.5, 0.7, 0.85, 1 } do
	local line = string.format("d=%.2f ", d)
	for _, o in Forge.Spawning.odds(d) do
		line ..= string.format("%s %.4g%%  ", o.rarity, o.chance * 100)
	end
	print(line)
end
