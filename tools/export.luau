--[[
	Exporte les créatures hors de Studio (Lune) :
	  dist/<Id>.rbxmx            -> modèle à glisser-déposer dans Roblox Studio
	  dist/<Id>_Icon.rbxmx       -> ScreenGui contenant la carte d'icône (à déposer dans StarterGui)
	  tools/preview/<Id>.json    -> géométrie pour l'aperçu web (tools/preview/viewer.html)

	Usage : lune run tools/export [Id ...]   (sans argument : toutes les créatures)
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Sandbox = require("./lib/sandbox")

local Forge = Sandbox.load("src/shared")

local function round(n: number): number
	return math.floor(n * 10000 + 0.5) / 10000
end

local function cframeArray(cf): { number }
	local out = {}
	for _, v in { cf:GetComponents() } do
		table.insert(out, round(v))
	end
	return out
end

local function exportPreview(def, model, iconCard)
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local kind = if d.ClassName == "WedgePart" then "Wedge" else d.Shape.Name
			table.insert(parts, {
				n = d.Name,
				g = d.Parent.Name,
				k = kind,
				s = { round(d.Size.X), round(d.Size.Y), round(d.Size.Z) },
				c = cframeArray(d.CFrame),
				col = { math.floor(d.Color.R * 255 + 0.5), math.floor(d.Color.G * 255 + 0.5), math.floor(d.Color.B * 255 + 0.5) },
				m = d.Material.Name,
				t = round(d.Transparency),
			})
		end
	end
	local cam = iconCard:FindFirstChild("Viewport"):FindFirstChildOfClass("Camera")
	local function c3(c)
		return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
	end
	return {
		id = def.Id,
		name = def.DisplayName,
		rarity = def.Rarity,
		parts = parts,
		icon = {
			camera = cframeArray(cam.CFrame),
			fov = cam.FieldOfView,
			top = c3(def.Icon.top),
			bottom = c3(def.Icon.bottom),
			glow = c3(def.Icon.glow),
		},
	}
end

local ids = table.clone(process.args)
if #ids == 0 then
	for _, def in Forge.list() do
		table.insert(ids, def.Id)
	end
end

fs.writeDir("dist")
fs.writeDir("tools/preview")

for _, id in ids do
	local def = Forge.get(id)

	local model = def.build({})
	fs.writeFile(`dist/{id}.rbxmx`, roblox.serializeModel({ model }, true))

	local gui = roblox.Instance.new("ScreenGui")
	gui.Name = "CreatureIcon_" .. id
	gui.ResetOnSpawn = false
	local card = def.Icon and Forge.buildIcon(id, gui, {
		size = roblox.UDim2.fromScale(0.16, 0.16),
		position = roblox.UDim2.fromScale(0.02, 0.96),
		anchorPoint = roblox.Vector2.new(0, 1),
	})
	fs.writeFile(`dist/{id}_Icon.rbxmx`, roblox.serializeModel({ gui }, true))

	local preview = exportPreview(def, model, card)
	fs.writeFile(`tools/preview/{id}.json`, serde.encode("json", preview, false))

	local center, size = Forge.Kit.visibleBounds(model)
	local counts = {}
	for _, d in model:GetDescendants() do
		counts[d.ClassName] = (counts[d.ClassName] or 0) + 1
	end
	local summary = {}
	for k, v in counts do
		table.insert(summary, `{k}={v}`)
	end
	table.sort(summary)
	print(
		string.format(
			"%s : %d pièces visibles | %.2f haut x %.2f large x %.2f long (studs)",
			id,
			#preview.parts,
			size.Y,
			size.X,
			size.Z
		)
	)
	print("  " .. table.concat(summary, " "))
end
