--[[
	Exporte les créatures hors de Studio (Lune) :
	  dist/models/<Id>.rbxm        -> modèle à glisser-déposer dans Roblox Studio
	  dist/icons/<Id>_Icon.rbxm    -> ScreenGui avec la carte d'icône (à déposer dans StarterGui)
	  tools/preview/<Id>.json      -> géométrie pour l'aperçu web (tools/preview/viewer.html)
	  tools/preview/index.json     -> liste des créatures (nom, rareté, stats)
	  tools/preview/treadmills.json -> liste des tapis de course (niveau, prix, gain)
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
	-- Os d'une instance : dossier de l'os pour les pièces, pièce-os pour les attachments
	local bonesFolder = model:FindFirstChild("Bones")
	local function boneOf(inst): string
		local parent = inst.Parent
		if inst:IsA("Attachment") then
			return if parent.Parent == bonesFolder then parent.Name else (if parent.Name == "Root" then "Root" else parent.Parent.Name)
		end
		if parent == bonesFolder then
			return inst.Name
		elseif parent == model then
			return "Root"
		end
		return parent.Name
	end

	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(parts, {
				b = boneOf(d),
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
	-- Effets : émetteurs de particules, rayons (Beam) et lumières, en coordonnées monde
	local function worldOf(inst)
		local parent = inst.Parent
		if parent:IsA("Attachment") then
			return parent.Parent.CFrame * parent.CFrame, roblox.Vector3.zero, boneOf(parent)
		end
		return parent.CFrame, parent.Size, boneOf(parent)
	end
	local function seq(s, isColor)
		local out = {}
		for _, k in s.Keypoints do
			if isColor then
				table.insert(out, { round(k.Time), round(k.Value.R), round(k.Value.G), round(k.Value.B) })
			else
				table.insert(out, { round(k.Time), round(k.Value) })
			end
		end
		return out
	end
	local texKey = {}
	for key, path in Forge.Fx.TEXTURES do
		texKey[path] = key
	end
	local emitters, beams, lights, trails = {}, {}, {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local wcf, wsize, bone = worldOf(d)
			table.insert(emitters, {
				b = bone,
				c = cframeArray(wcf),
				s = { round(wsize.X), round(wsize.Y), round(wsize.Z) },
				tex = texKey[d.Texture] or "sparkle",
				col = seq(d.Color, true),
				size = seq(d.Size),
				tr = seq(d.Transparency),
				life = { round(d.Lifetime.Min), round(d.Lifetime.Max) },
				rate = d.Rate,
				speed = { round(d.Speed.Min), round(d.Speed.Max) },
				spread = { d.SpreadAngle.X, d.SpreadAngle.Y },
				acc = { round(d.Acceleration.X), round(d.Acceleration.Y), round(d.Acceleration.Z) },
				drag = d.Drag,
				le = d.LightEmission,
				dir = d.EmissionDirection.Name,
			})
		elseif d:IsA("Beam") and d.Attachment0 and d.Attachment1 then
			local a0 = d.Attachment0.Parent.CFrame * d.Attachment0.CFrame
			local a1 = d.Attachment1.Parent.CFrame * d.Attachment1.CFrame
			table.insert(beams, {
				b0 = boneOf(d.Attachment0),
				b1 = boneOf(d.Attachment1),
				p0 = cframeArray(a0),
				p1 = cframeArray(a1),
				w = { round(d.Width0), round(d.Width1) },
				curve = { round(d.CurveSize0), round(d.CurveSize1) },
				col = seq(d.Color, true),
				tr = seq(d.Transparency),
				le = d.LightEmission,
			})
		elseif d:IsA("PointLight") then
			local wcf, _, bone = worldOf(d)
			table.insert(lights, { bone = bone, p = { round(wcf.X), round(wcf.Y), round(wcf.Z) }, col = c3(d.Color), range = d.Range, b = d.Brightness })
		elseif d:IsA("Trail") and d.Attachment0 and d.Attachment1 then
			local a0 = d.Attachment0.Parent.CFrame * d.Attachment0.CFrame
			local a1 = d.Attachment1.Parent.CFrame * d.Attachment1.CFrame
			table.insert(trails, {
				b = boneOf(d.Attachment0),
				p0 = { round(a0.X), round(a0.Y), round(a0.Z) },
				p1 = { round(a1.X), round(a1.Y), round(a1.Z) },
				col = seq(d.Color, true),
				tr = seq(d.Transparency),
				life = d.Lifetime,
			})
		end
	end

	-- Squelette : os (pièces du dossier Bones + Root) et leur parent (Motor6D)
	local bones = { { n = "Root", c = cframeArray(model.PrimaryPart.CFrame) } }
	for _, bp in bonesFolder:GetChildren() do
		local parentName = "Root"
		local attrs = nil
		for _, m in model:GetDescendants() do
			if m:IsA("Motor6D") and m.Part1 == bp then
				parentName = m.Part0.Name
				for _, key in { "Speed", "BeltSpeed", "BeltSpacing" } do
					local v = m:GetAttribute(key)
					if v then
						attrs = attrs or {}
						attrs[key] = v
					end
				end
			end
		end
		table.insert(bones, { n = bp.Name, p = parentName, c = cframeArray(bp.CFrame), a = attrs })
	end

	-- Capacité spéciale + point d'origine
	local ability = nil
	if def.Ability then
		local a = def.Ability
		local colors = {}
		for _, c in a.colors do
			table.insert(colors, c3(c))
		end
		local origin = model:FindFirstChild("AbilityOrigin", true)
		ability = {
			name = a.name,
			kind = a.kind,
			colors = colors,
			texture = a.texture or "sparkle",
			radius = a.radius or 5,
			duration = a.duration or 1.6,
			origin = if origin then { b = origin.Parent.Name, c = cframeArray(origin.Parent.CFrame * origin.CFrame) } else nil,
		}
	end

	local cam = if iconCard then iconCard:FindFirstChild("Viewport"):FindFirstChildOfClass("Camera") else nil
	return {
		id = def.Id,
		name = def.DisplayName,
		rarity = def.Rarity,
		size = def.Size,
		income = def.Income,
		speed = def.SpeedBonus,
		passenger = def.Passenger,
		source = def.Source or "Tapis",
		parts = parts,
		bones = bones,
		anim = def.Animation,
		ability = ability,
		description = def.Description,
		category = def.Category,
		scale = def.Scale or 1,
		fx = { emitters = emitters, beams = beams, lights = lights, trails = trails },
		icon = if cam then {
			camera = cframeArray(cam.CFrame),
			fov = cam.FieldOfView,
			top = c3(def.Icon.top),
			bottom = c3(def.Icon.bottom),
			glow = c3(def.Icon.glow),
		} else nil,
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

-- Données des mutations et des raretés pour l'aperçu web
local muts = {}
for _, m in Forge.Mutations.List do
	local badge = {}
	for _, c in m.badge do
		table.insert(badge, c3(c))
	end
	table.insert(muts, {
		id = m.id,
		label = m.label,
		effect = m.effect,
		odds = m.odds,
		multiplier = m.multiplier,
		glow = c3(m.glow),
		badge = badge,
		recolor = m.recolor,
	})
end
local tiers = {}
for _, id in Forge.Rarity.Order do
	local t = Forge.Rarity.Tiers[id]
	table.insert(tiers, {
		id = id,
		label = t.label,
		color = c3(t.color),
		light = c3(t.light),
		dark = c3(t.dark),
		where = t.where,
		odds = t.odds,
		rainbow = t.rainbow == true,
		glitch = t.glitch == true,
		gold = t.gold ~= nil,
	})
end
fs.writeFile("tools/preview/rarities.json", serde.encode("json", tiers, false))
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
	-- Taille du corps seul (sans orbites ni aura) pour régler Scale selon la taille visée
	local lo, hi = roblox.Vector3.new(1e9, 1e9, 1e9), roblox.Vector3.new(-1e9, -1e9, -1e9)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Parent and d.Parent.Name ~= "Bones" and string.sub(d.Parent.Name, 1, 4) ~= "Aura" and d.Name ~= "AuraRing" and d.Name ~= "AuraTick" then
			local p = d.CFrame.Position
			lo = roblox.Vector3.new(math.min(lo.X, p.X), math.min(lo.Y, p.Y), math.min(lo.Z, p.Z))
			hi = roblox.Vector3.new(math.max(hi.X, p.X), math.max(hi.Y, p.Y), math.max(hi.Z, p.Z))
		end
	end
	local body = hi - lo
	local span = math.max(body.X, body.Y, body.Z)
	local target = Forge.Rarity.Sizes[def.Size] and Forge.Rarity.Sizes[def.Size].span or span
	print(string.format("%-24s %-9s %-8s %5d pièces | %.1f x %.1f x %.1f (scale 1) | Scale %.2f -> conseillé %.2f", id, def.Rarity, def.Size or "?", #preview.parts, body.Y, body.X, body.Z, def.Scale or 1, target / span))
end

-- Carte du jeu (aperçu web : vue de la carte entière)
if all then
	local map = Forge.Map.build({})
	fs.writeFile("dist/models/Carte.rbxm", roblox.serializeModel({ map }))
	-- Aperçu : la carte + la vitrine (tapis exposés, présentoirs des battes, seringues et ADN)
	Forge.Vitrine.treadmills(map, map)
	Forge.Vitrine.items(map, map)
	local zones = {}
	for _, z in Forge.Map.ZONES do
		table.insert(zones, { id = z.id, label = z.label, sub = z.sub, from = z.from, to = z.to, color = c3(z.color) })
	end
	local preview = exportPreview({ Id = "Carte", DisplayName = "La carte du canyon", Rarity = "Map", Animation = { gait = "Static" }, Description = "Les bases en haut (zone sûre, stands, 8 enclos), puis la pente du canyon à travers 8 zones : plus on descend, plus les personnages sont rares. Remonter la pente vide l'endurance.", Category = "Carte", Scale = 1 }, map, nil)
	preview.kind = "Map"
	preview.zones = zones
	preview.length = Forge.Map.LENGTH
	preview.drop = Forge.Map.DROP
	fs.writeFile("tools/preview/Carte.json", serde.encode("json", preview, false))
	print(string.format("Carte : %d pièces", #preview.parts))
end

-- Armes (battes) et seringues
if all then
	local items = {}
	for _, w in Forge.Weapons.List do
		local model = w.build({ scale = 1, animated = false })
		fs.writeFile(`dist/models/{w.Id}.rbxm`, roblox.serializeModel({ Forge.Weapons.buildTool(w.Id) }))
		local preview = exportPreview({ Id = w.Id, DisplayName = w.DisplayName, Rarity = "Weapon", Animation = { gait = "Static" }, Description = w.Description, Category = "Arme", Scale = 1 }, model, nil)
		preview.kind = "Weapon"
		preview.tier = w.Tier
		preview.price = w.Price
		preview.range = w.Range
		preview.cooldown = w.Cooldown
		fs.writeFile(`tools/preview/{w.Id}.json`, serde.encode("json", preview, false))
		table.insert(items, { id = w.Id, name = w.DisplayName, kind = "Weapon", tier = w.Tier, price = w.Price, range = w.Range, cooldown = w.Cooldown })
	end
	for _, sy in Forge.Syringes.List do
		local model = sy.build({ scale = 1, animated = false })
		fs.writeFile(`dist/models/{sy.Id}.rbxm`, roblox.serializeModel({ Forge.Syringes.buildTool(sy.Id) }))
		local preview = exportPreview({ Id = sy.Id, DisplayName = sy.DisplayName, Rarity = "Syringe", Animation = { gait = "Static" }, Description = sy.Description, Category = "Seringue", Scale = 1 }, model, nil)
		preview.kind = "Syringe"
		preview.tier = sy.Tier
		preview.price = sy.Price
		preview.multiplier = sy.Multiplier
		preview.chance = sy.Chance
		preview.stock = sy.Stock
		preview.color = c3(sy.Color)
		fs.writeFile(`tools/preview/{sy.Id}.json`, serde.encode("json", preview, false))
		table.insert(items, { id = sy.Id, name = sy.DisplayName, kind = "Syringe", tier = sy.Tier, price = sy.Price, multiplier = sy.Multiplier, chance = sy.Chance, color = c3(sy.Color) })
	end
	-- Machine à ADN (une par base) + fragments d'ADN de chaque rareté
	local D = Forge.DnaMachine
	local function oddsOf(rarity: string, amount: number)
		local out = {}
		for _, o in D.odds(rarity, amount) do
			table.insert(out, { rarity = o.rarity, chance = o.chance })
		end
		return out
	end
	local table8 = {}
	for _, r in Forge.Rarity.Order do
		local base = Forge.Syringes.BASE_DNA[r]
		table.insert(table8, { rarity = r, dna = base, incubation = D.incubation(r), odds = oddsOf(r, base), best = oddsOf(r, base * 20) })
	end
	do
		local model = D.build({ scale = 1 })
		fs.writeFile("dist/models/MachineADN.rbxm", roblox.serializeModel({ D.build({ scale = 1 }) }))
		local preview = exportPreview({ Id = "MachineADN", DisplayName = "Machine à ADN", Rarity = "Machine", Animation = { gait = "Static" }, Description = "Une machine à côté de chaque base (une par joueur). Pose l'ADN récolté dans le canyon : après l'incubation, un personnage sort et s'installe dans ta base. Plus l'ADN est rare, meilleures sont tes chances d'avoir un bon personnage.", Category = "Machine", Scale = 1 }, model, nil)
		preview.kind = "Machine"
		preview.table = table8
		fs.writeFile("tools/preview/MachineADN.json", serde.encode("json", preview, false))
		table.insert(items, { id = "MachineADN", name = "Machine à ADN", kind = "Machine" })
	end
	for _, e in table8 do
		local id = "ADN_" .. e.rarity
		local model = D.buildDna(e.rarity, { scale = 1, animated = false })
		fs.writeFile(`dist/models/{id}.rbxm`, roblox.serializeModel({ D.buildDnaTool(e.rarity, e.dna) }))
		local preview = exportPreview({ Id = id, DisplayName = D.NAMES[e.rarity], Rarity = e.rarity, Animation = { gait = "Static" }, Description = `Fragment d'ADN récolté sur un personnage {string.sub(D.NAMES[e.rarity], 5)}. Il tombe si on te frappe : n'importe qui peut le ramasser. Pose-le dans ta machine à ADN.`, Category = "ADN", Scale = 1 }, model, nil)
		preview.kind = "Dna"
		preview.dnaRarity = e.rarity
		preview.dna = e.dna
		preview.incubation = e.incubation
		preview.odds = e.odds
		preview.best = e.best
		fs.writeFile(`tools/preview/{id}.json`, serde.encode("json", preview, false))
		table.insert(items, { id = id, name = D.NAMES[e.rarity], kind = "Dna", rarity = e.rarity, incubation = e.incubation })
	end
	fs.writeFile("tools/preview/items.json", serde.encode("json", items, false))
	print(`{#items} objets (battes, seringues, machine à ADN, fragments d'ADN)`)
end

-- Tapis de course
if all then
	local tlist = {}
	for _, def in Forge.Treadmills.list() do
		local model = def.build({ scale = 1 })
		fs.writeFile(`dist/models/{def.Id}.rbxm`, roblox.serializeModel({ model }))
		local preview = exportPreview({ Id = def.Id, DisplayName = def.DisplayName, Rarity = "Treadmill", Animation = { gait = "Static" }, Description = def.Description, Category = "Tapis de course", Scale = 1 }, model, nil)
		preview.kind = "Treadmill"
		preview.tier = def.Tier
		preview.price = def.Price
		preview.gain = def.Gain
		preview.theme = def.Theme
		preview.color = c3(def.Color)
		fs.writeFile(`tools/preview/{def.Id}.json`, serde.encode("json", preview, false))
		table.insert(tlist, { id = def.Id, name = def.DisplayName, tier = def.Tier, price = def.Price, gain = def.Gain, theme = def.Theme, color = c3(def.Color) })
		print(string.format("%-20s niveau %2d %5d pièces", def.Id, def.Tier, #preview.parts))
	end
	fs.writeFile("tools/preview/treadmills.json", serde.encode("json", tlist, false))
end

if all then
	for _, def in Forge.list() do
		table.insert(index, {
			id = def.Id,
			name = def.DisplayName,
			rarity = def.Rarity,
			size = def.Size,
			income = def.Income,
			speed = def.SpeedBonus,
			passenger = def.Passenger,
			source = def.Source or "Tapis",
			ability = if def.Ability then def.Ability.name else nil,
			gait = def.Animation.gait,
		})
	end
	fs.writeFile("tools/preview/index.json", serde.encode("json", index, false))
	print(`{#ids} créatures, {total} pièces au total`)
end
