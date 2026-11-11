--[[
	Exporte les créatures hors de Studio (Lune) :
	  dist/models/<Id>.rbxm        -> modèle à glisser-déposer dans Roblox Studio
	  dist/icons/<Id>_Icon.rbxm    -> ScreenGui avec la carte d'icône (à déposer dans StarterGui)
	  tools/preview/<Id>.json      -> géométrie pour l'aperçu web (tools/preview/viewer.html)
	  tools/preview/index.json     -> liste des créatures (nom, rareté, zone)
	  tools/preview/mutations.json -> données des mutations (aperçu web)

	Usage : lune run tools/export [Id ...]   (sans argument : toutes les créatures)
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Sandbox = require("./lib/sandbox")

local Forge = Sandbox.load("src/shared")

local function round(n: number): number
	return math.floor(n * 1000 + 0.5) / 1000
end

local function c3(c): { number }
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
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
			table.insert(parts, {
				n = d.Name,
				k = if d.ClassName == "WedgePart" then "Wedge" else d.Shape.Name,
				s = { round(d.Size.X), round(d.Size.Y), round(d.Size.Z) },
				c = cframeArray(d.CFrame),
				col = c3(d.Color),
				m = d.Material.Name,
				t = round(d.Transparency),
			})
		end
	end
	local cam = iconCard:FindFirstChild("Viewport"):FindFirstChildOfClass("Camera")
	return {
		id = def.Id,
		name = def.DisplayName,
		rarity = def.Rarity,
		zone = def.Zone,
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
local all = #ids == 0
if all then
	for _, def in Forge.list() do
		table.insert(ids, def.Id)
	end
end

fs.writeDir("dist/models")
fs.writeDir("dist/icons")
fs.writeDir("tools/preview")

-- Données des mutations pour l'aperçu web
local muts = {}
for _, m in Forge.Mutations.List do
	local ramp = {}
	for _, c in m.ramp do
		table.insert(ramp, c3(c))
	end
	table.insert(muts, {
		id = m.id,
		label = m.label,
		multiplier = m.multiplier,
		chance = m.chance,
		ramp = ramp,
		glow = c3(m.glow),
		rainbow = m.rainbow == true,
		material = if m.material then m.material.Name else nil,
		transparency = m.transparency,
	})
end
fs.writeFile("tools/preview/mutations.json", serde.encode("json", muts, false))

local index = {}
local total = 0
for _, id in ids do
	local def = Forge.get(id)

	local model = def.build({ scale = 1 })
	fs.writeFile(`dist/models/{id}.rbxm`, roblox.serializeModel({ model }))

	local gui = roblox.Instance.new("ScreenGui")
	gui.Name = "CreatureIcon_" .. id
	gui.ResetOnSpawn = false
	local card = Forge.buildIcon(id, gui, {
		size = roblox.UDim2.fromScale(0.16, 0.16),
		position = roblox.UDim2.fromScale(0.02, 0.96),
		anchorPoint = roblox.Vector2.new(0, 1),
	})
	fs.writeFile(`dist/icons/{id}_Icon.rbxm`, roblox.serializeModel({ gui }))

	local preview = exportPreview(def, model, card)
	fs.writeFile(`tools/preview/{id}.json`, serde.encode("json", preview, false))
	total += #preview.parts

	local _, size = Forge.Kit.visibleBounds(model)
	print(string.format("%-26s %-10s %5d pièces | %.1f x %.1f x %.1f studs (scale 1, défaut x%.1f)", id, def.Rarity, #preview.parts, size.Y, size.X, size.Z, def.Scale or 1))
end

if all then
	for _, def in Forge.list() do
		table.insert(index, { id = def.Id, name = def.DisplayName, rarity = def.Rarity, zone = def.Zone })
	end
	fs.writeFile("tools/preview/index.json", serde.encode("json", index, false))
	print(`{#ids} créatures, {total} pièces au total`)
end
