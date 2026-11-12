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
		for _, m in model:GetDescendants() do
			if m:IsA("Motor6D") and m.Part1 == bp then
				parentName = m.Part0.Name
			end
		end
		table.insert(bones, { n = bp.Name, p = parentName, c = cframeArray(bp.CFrame) })
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

	local cam = iconCard:FindFirstChild("Viewport"):FindFirstChildOfClass("Camera")
	return {
		id = def.Id,
		name = def.DisplayName,
		rarity = def.Rarity,
		zone = def.Zone,
		parts = parts,
		bones = bones,
		anim = def.Animation,
		ability = ability,
		description = def.Description,
		category = def.Category,
		scale = def.Scale or 1,
		fx = { emitters = emitters, beams = beams, lights = lights, trails = trails },
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
		table.insert(index, {
			id = def.Id,
			name = def.DisplayName,
			rarity = def.Rarity,
			zone = def.Zone,
			ability = if def.Ability then def.Ability.name else nil,
			gait = def.Animation.gait,
		})
	end
	fs.writeFile("tools/preview/index.json", serde.encode("json", index, false))
	print(`{#ids} créatures, {total} pièces au total`)
end
