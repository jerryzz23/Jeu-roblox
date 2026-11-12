local fs = require("@lune/fs")
local luau = require("@lune/luau")
local bad = 0
local function walk(dir)
	for _, n in fs.readDir(dir) do
		local p = dir .. "/" .. n
		if fs.isDir(p) then
			walk(p)
		elseif string.match(n, "%.luau$") then
			local ok, err = pcall(luau.compile, fs.readFile(p))
			if not ok then
				bad += 1
				print("ERREUR", p, err)
			end
		end
	end
end
walk("src")
print(bad == 0 and "tout compile" or (bad .. " fichier(s) en erreur"))
