-- CreatureForge — RatDesCavernes
-- Script autonome pour la COMMAND BAR de Roblox Studio (View > Command Bar).
-- Collez TOUT ce fichier puis appuyez sur Entrée : la créature apparaît devant la caméra,
-- est sélectionnée, et son icône UI est ajoutée dans StarterGui > CreatureForgeIcons.
-- Généré par `lune run tools/bundle` à partir de src/shared — ne pas modifier à la main.

local __modules, __cache = {}, {}
local function __require(name)
	local m = __cache[name]
	if m == nil then
		m = __modules[name]()
		__cache[name] = m
	end
	return m
end

__modules["Kit"] = function()
	--[[
		CreatureForge.Kit
		-----------------
		Boîte à outils d'assemblage low-poly pour créatures Roblox.
	
	• Un "rig" = un Model + un Root ancré + des os (Parts invisibles reliés par Motor6D).
		• Chaque pièce visible est soudée (Weld) à un os : animer un Motor6D fait bouger
		  tout ce qui est soudé à son os (tête, oreilles, queue, pattes...).
		• Primitives facettées : prisme octogonal chanfreiné, triangle (2 WedgeParts),
		  pointe, anneau, cristal, cylindre entre deux points...
	
	Conventions (espace modèle, AVANT mise à l'échelle) :
		  - la créature regarde vers -Z (LookVector), +X = sa droite, +Y = le haut ;
		  - le sol est à Y = 0, le pivot du modèle (Root) est au sol, au centre ;
		  - toutes les tailles/positions passées au Kit sont multipliées par `scale`.
	]]
	
local Kit = {}
	
type Style = {
		color: Color3,
		material: Enum.Material?,
		transparency: number?,
		reflectance: number?,
		castShadow: boolean?,
	}
	
type BuildOptions = {
		scale: number?, -- facteur d'échelle global (1 = taille de référence)
		cframe: CFrame?, -- position/orientation du pivot (au sol)
		parent: Instance?, -- parent final du modèle (nil = non parenté)
		outline: boolean?, -- contour cartoon (Highlight) — défaut : true
		effects: boolean?, -- particules + lumières — défaut : true
		animated: boolean?, -- tag "CreatureForge" pour l'animateur client — défaut : true
	}
	
type PartKind = "Block" | "Wedge" | "Ball" | "Cylinder"
	
type RigData = {
		id: string,
		model: Model,
		root: Part,
		scale: number,
		origin: CFrame,
		effects: boolean,
		outline: boolean,
		animated: boolean,
		parent: Instance?,
		bones: { [string]: BasePart },
		folders: { [string]: Folder },
		boneFolder: Folder,
		partCount: number,
	}
	
local Rig = {}
	Rig.__index = Rig
	
type Rig = typeof(setmetatable({} :: RigData, Rig))
	
Kit.TAG = "CreatureForge"
	Kit.OUTLINE_COLOR = Color3.fromRGB(14, 12, 18)
	
-- ---------------------------------------------------------------------------
	-- Utilitaires mathématiques
	-- ---------------------------------------------------------------------------
	
--- Crée un style (couleur + matériau + options).
	function Kit.style(color: Color3, material: Enum.Material?, extra: { [string]: any }?): Style
		local s: Style = {
			color = color,
			material = material or Enum.Material.SmoothPlastic,
		}
		if extra then
			s.transparency = extra.transparency
			s.reflectance = extra.reflectance
			s.castShadow = extra.castShadow
		end
		return s
	end
	
--- CFrame positionné en `pos` dont le -Z (LookVector) pointe le long de `dir`.
	--- Robuste quand `dir` est vertical (contrairement à CFrame.lookAt).
	function Kit.lookAlong(pos: Vector3, dir: Vector3, upHint: Vector3?): CFrame
		local d = dir.Unit
		local up = upHint or Vector3.yAxis
		if math.abs(d:Dot(up)) > 0.999 then
			up = if math.abs(d:Dot(Vector3.zAxis)) > 0.999 then Vector3.xAxis else Vector3.zAxis
		end
		local right = d:Cross(up).Unit
		local newUp = right:Cross(d)
		return CFrame.fromMatrix(pos, right, newUp, -d)
	end
	
--- Miroir d'un CFrame par rapport au plan X = 0 (gauche <-> droite).
	function Kit.mirrorX(cf: CFrame): CFrame
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
		return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
	end
	
--- Point sur une courbe de Catmull-Rom passant par `pts` (t de 0 à 1).
	function Kit.spline(pts: { Vector3 }, t: number): Vector3
		local n = #pts
		local f = math.clamp(t, 0, 1) * (n - 1)
		local i = math.min(math.floor(f) + 1, n - 1)
		local u = f - (i - 1)
		local p0 = pts[math.max(i - 1, 1)]
		local p1 = pts[i]
		local p2 = pts[i + 1]
		local p3 = pts[math.min(i + 2, n)]
		local u2, u3 = u * u, u * u * u
		return 0.5
			* (
				(2 * p1)
				+ (p2 - p0) * u
				+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2
				+ (3 * p1 - p0 - 3 * p2 + p3) * u3
			)
	end
	
-- ---------------------------------------------------------------------------
	-- Création du rig
	-- ---------------------------------------------------------------------------
	
local function configureLoose(p: BasePart)
		p.Anchored = false
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
	end
	
--- Démarre une nouvelle créature.
	function Kit.newRig(id: string, opts: BuildOptions?): Rig
		local o: BuildOptions = opts or {}
		local scale = o.scale or 1
		local origin = o.cframe or CFrame.identity
	
	local model = Instance.new("Model")
		model.Name = id
	
	local root = Instance.new("Part")
		root.Name = "Root"
		root.Size = Vector3.one * 0.4 * scale
		root.Transparency = 1
		root.Anchored = true
		root.CanCollide = false
		root.CanTouch = false
		root.CanQuery = false
		root.CastShadow = false
		root.CFrame = origin
		root.Parent = model
		model.PrimaryPart = root
	
	local boneFolder = Instance.new("Folder")
		boneFolder.Name = "Bones"
		boneFolder.Parent = model
	
	local data: RigData = {
			id = id,
			model = model,
			root = root,
			scale = scale,
			origin = origin,
			effects = if o.effects == nil then true else o.effects,
			outline = if o.outline == nil then true else o.outline,
			animated = if o.animated == nil then true else o.animated,
			parent = o.parent,
			bones = { Root = root },
			folders = {},
			boneFolder = boneFolder,
			partCount = 0,
		}
		return setmetatable(data, Rig)
	end
	
--- Convertit un CFrame "espace modèle" (non mis à l'échelle) en CFrame monde.
	function Rig.toWorld(self: Rig, cf: CFrame): CFrame
		return self.origin * ((cf - cf.Position) + cf.Position * self.scale)
	end
	
function Rig.folderFor(self: Rig, boneName: string): Folder
		local f = self.folders[boneName]
		if not f then
			f = Instance.new("Folder")
			f.Name = boneName
			f.Parent = self.model
			self.folders[boneName] = f
		end
		return f
	end
	
--- Ajoute un os articulé (Motor6D) à `parentName`. `cf` = pivot de l'articulation.
	--- Les axes locaux de `cf` sont les axes de rotation utilisés par l'animateur.
	function Rig.bone(self: Rig, name: string, parentName: string, cf: CFrame): BasePart
		local parentBone = self.bones[parentName]
		assert(parentBone, `CreatureForge: os parent inconnu "{parentName}"`)
		assert(self.bones[name] == nil, `CreatureForge: os "{name}" déjà défini`)
	
	local b = Instance.new("Part")
		b.Name = name
		b.Size = Vector3.one * 0.2 * self.scale
		b.Transparency = 1
		b.CastShadow = false
		configureLoose(b)
		b.CFrame = self:toWorld(cf)
		b.Parent = self.boneFolder
	
	local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = parentBone
		m.Part1 = b
		m.C0 = parentBone.CFrame:ToObjectSpace(b.CFrame)
		m.Parent = parentBone
	
	self.bones[name] = b
		return b
	end
	
--- Chaîne d'os le long d'une polyligne (queues, cous, corps de serpent) :
	--- crée `prefix1` … `prefix(#points - 1)`, chacun pivotant sur points[i] et orienté
	--- (-Z) vers points[i + 1]. Le premier est attaché à `parentName`. Renvoie les noms.
	function Rig.boneChain(self: Rig, prefix: string, parentName: string, points: { Vector3 }): { string }
		local names = {}
		for i = 1, #points - 1 do
			local name = prefix .. i
			self:bone(name, if i == 1 then parentName else names[i - 1], Kit.lookAlong(points[i], points[i + 1] - points[i]))
			names[i] = name
		end
		return names
	end
	
--- Crée une pièce soudée à l'os `boneName`. `cf`/`size` en espace modèle.
	function Rig.part(
		self: Rig,
		boneName: string,
		name: string,
		kind: PartKind,
		cf: CFrame,
		size: Vector3,
		style: Style
	): BasePart
		local bone = self.bones[boneName]
		assert(bone, `CreatureForge: os inconnu "{boneName}"`)
	
	local p: BasePart
		if kind == "Wedge" then
			p = Instance.new("WedgePart")
		else
			local part = Instance.new("Part")
			if kind == "Ball" then
				part.Shape = Enum.PartType.Ball
			elseif kind == "Cylinder" then
				part.Shape = Enum.PartType.Cylinder
			end
			p = part
		end
	
	p.Name = name
		p.Size = size * self.scale
		p.Color = style.color
		p.Material = style.material or Enum.Material.SmoothPlastic
		p.Transparency = style.transparency or 0
		p.Reflectance = style.reflectance or 0
		p.CastShadow = if style.castShadow == nil then true else style.castShadow
		configureLoose(p)
		p.CFrame = self:toWorld(cf)
		p.Parent = self:folderFor(boneName)
	
	local w = Instance.new("Weld")
		w.Name = "Weld"
		w.Part0 = bone
		w.Part1 = p
		w.C0 = bone.CFrame:ToObjectSpace(p.CFrame)
		w.Parent = p
	
	self.partCount += 1
		return p
	end
	
-- ---------------------------------------------------------------------------
	-- Primitives
	-- ---------------------------------------------------------------------------
	
function Rig.block(self: Rig, bone: string, name: string, cf: CFrame, size: Vector3, style: Style): BasePart
		return self:part(bone, name, "Block", cf, size, style)
	end
	
--- WedgePart standard : pente tournée vers -Z/+Y, face verticale à l'arrière (+Z).
	function Rig.wedge(self: Rig, bone: string, name: string, cf: CFrame, size: Vector3, style: Style): BasePart
		return self:part(bone, name, "Wedge", cf, size, style)
	end
	
function Rig.ball(self: Rig, bone: string, name: string, pos: Vector3, diameter: number, style: Style): BasePart
		return self:part(bone, name, "Ball", CFrame.new(pos), Vector3.one * diameter, style)
	end
	
--- Cylindre de `a` à `b`.
	function Rig.cylinder(
		self: Rig,
		bone: string,
		name: string,
		a: Vector3,
		b: Vector3,
		diameter: number,
		style: Style
	): BasePart
		local cf = Kit.lookAlong((a + b) / 2, b - a) * CFrame.Angles(0, math.pi / 2, 0)
		return self:part(bone, name, "Cylinder", cf, Vector3.new((b - a).Magnitude, diameter, diameter), style)
	end
	
--- Bloc allongé de `a` à `b` (section `width` x `height`, tourné de `roll` autour de son axe).
	function Rig.strut(
		self: Rig,
		bone: string,
		name: string,
		a: Vector3,
		b: Vector3,
		width: number,
		height: number,
		style: Style,
		roll: number?
	): BasePart
		local cf = Kit.lookAlong((a + b) / 2, b - a) * CFrame.Angles(0, 0, roll or 0)
		return self:block(bone, name, cf, Vector3.new(width, height, (b - a).Magnitude), style)
	end
	
--- Prisme triangulaire rectangle (1 WedgePart).
	--- `corner` = sommet de l'angle droit (au milieu de l'épaisseur),
	--- `u`, `v` = directions unitaires perpendiculaires des deux côtés de longueurs `a` et `b`.
	function Rig.wedgeTri(
		self: Rig,
		bone: string,
		name: string,
		corner: Vector3,
		u: Vector3,
		v: Vector3,
		a: number,
		b: number,
		thickness: number,
		style: Style
	): BasePart
		local right = v:Cross(u)
		local center = corner + u * (a / 2) + v * (b / 2)
		local cf = CFrame.fromMatrix(center, right, u, -v)
		return self:wedge(bone, name, cf, Vector3.new(thickness, a, b), style)
	end
	
--- Prisme octogonal (bloc aux 4 arêtes chanfreinées) extrudé le long du Z local de `cf`.
	--- 7 pièces : idéal pour des volumes organiques "low-poly".
	function Rig.prism(
		self: Rig,
		bone: string,
		name: string,
		cf: CFrame,
		size: Vector3,
		chamfer: number,
		style: Style
	): { BasePart }
		local c = math.min(chamfer, size.X / 2 - 0.005, size.Y / 2 - 0.005)
		if c <= 0.01 then
			return { self:block(bone, name, cf, size, style) }
		end
		local hx, hy, L = size.X / 2, size.Y / 2, size.Z
		local parts = {
			self:block(bone, name, cf, Vector3.new(size.X - 2 * c, size.Y, L), style),
			self:block(bone, name .. "_S", cf * CFrame.new(hx - c / 2, 0, 0), Vector3.new(c, size.Y - 2 * c, L), style),
			self:block(bone, name .. "_S", cf * CFrame.new(-(hx - c / 2), 0, 0), Vector3.new(c, size.Y - 2 * c, L), style),
		}
		for _, sgn in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
			local sx, sy = sgn[1], sgn[2]
			local corner = (cf * CFrame.new(sx * (hx - c), sy * (hy - c), 0)).Position
			table.insert(
				parts,
				self:wedgeTri(bone, name .. "_C", corner, cf.RightVector * sx, cf.UpVector * sy, c, c, L, style)
			)
		end
		return parts
	end
	
--- Prisme octogonal tendu entre deux points (section `w` x `h`).
	function Rig.prismBetween(
		self: Rig,
		bone: string,
		name: string,
		a: Vector3,
		b: Vector3,
		w: number,
		h: number,
		chamfer: number,
		style: Style,
		roll: number?
	): { BasePart }
		local cf = Kit.lookAlong((a + b) / 2, b - a) * CFrame.Angles(0, 0, roll or 0)
		return self:prism(bone, name, cf, Vector3.new(w, h, (b - a).Magnitude), chamfer, style)
	end
	
--- Plaque triangulaire isocèle (2 WedgeParts) : base centrée sur `base`,
	--- pointe vers base.UpVector, épaisseur le long de base.LookVector.
	function Rig.spike(
		self: Rig,
		bone: string,
		name: string,
		base: CFrame,
		width: number,
		height: number,
		thickness: number,
		style: Style
	): { BasePart }
		local p, up, r = base.Position, base.UpVector, base.RightVector
		return {
			self:wedgeTri(bone, name, p, up, r, height, width / 2, thickness, style),
			self:wedgeTri(bone, name, p, up, -r, height, width / 2, thickness, style),
		}
	end
	
--- Pointe "en croix" (2 plaques croisées) : griffes, crocs, épines, cornes.
	function Rig.thorn(
		self: Rig,
		bone: string,
		name: string,
		base: CFrame,
		width: number,
		height: number,
		style: Style
	): { BasePart }
		local t = math.max(width * 0.3, 0.02)
		local a = self:spike(bone, name, base, width, height, t, style)
		local b = self:spike(bone, name, base * CFrame.Angles(0, math.pi / 2, 0), width, height, t, style)
		return { a[1], a[2], b[1], b[2] }
	end
	
--- Anneau polygonal dans le plan XY local de `cf` (axe = Z local).
	function Rig.ring(
		self: Rig,
		bone: string,
		name: string,
		cf: CFrame,
		radius: number,
		thickness: number,
		depth: number,
		segments: number,
		style: Style
	): { BasePart }
		local parts = {}
		local segLen = 2 * (radius + thickness / 2) * math.tan(math.pi / segments)
		for i = 0, segments - 1 do
			local a = (i / segments) * math.pi * 2
			local pcf = cf * CFrame.Angles(0, 0, a) * CFrame.new(radius, 0, 0)
			table.insert(parts, self:block(bone, name, pcf, Vector3.new(thickness, segLen, depth), style))
		end
		return parts
	end
	
--- Cristal : prisme carré + pointe biseautée. `base` = centre de la base, axe = base.UpVector.
	function Rig.shard(
		self: Rig,
		bone: string,
		name: string,
		base: CFrame,
		width: number,
		height: number,
		tip: number,
		style: Style
	): { BasePart }
		local parts = {
			self:block(bone, name, base * CFrame.new(0, height / 2, 0), Vector3.new(width, height, width), style),
		}
		for _, p in self:spike(bone, name .. "_Tip", base * CFrame.new(0, height, 0), width, tip, width, style) do
			table.insert(parts, p)
		end
		return parts
	end
	
--- Appelle `fn(side, suffix)` pour le côté droit (+1, "_R") puis gauche (-1, "_L").
	function Rig.mirrored(self: Rig, fn: (side: number, suffix: string) -> ())
		fn(1, "_R")
		fn(-1, "_L")
	end
	
--- Pièce invisible (support de particules/lumières ou hitbox).
	function Rig.anchor(self: Rig, bone: string, name: string, cf: CFrame, size: Vector3): BasePart
		local p = self:part(bone, name, "Block", cf, size, { color = Color3.new(1, 1, 1), transparency = 1, castShadow = false })
		self.partCount -= 1
		return p
	end
	
--- Hitbox invisible interrogeable (clics, ProximityPrompt, raycasts).
	function Rig.hitbox(self: Rig, cf: CFrame, size: Vector3): BasePart
		local p = self:anchor("Root", "Hitbox", cf, size)
		p.CanQuery = true
		p.Parent = self.model
		return p
	end
	
--- Finalise le modèle : attributs, tag, contour, parent.
	function Rig.finish(self: Rig, attributes: { [string]: any }?): Model
		local model = self.model
		model:SetAttribute("CreatureId", self.id)
		model:SetAttribute("Scale", self.scale)
		model:SetAttribute("AnimState", "Idle") -- "Idle" | "Move" | "Still"
		model:SetAttribute("PartCount", self.partCount)
		if attributes then
			for k, v in attributes do
				model:SetAttribute(k, v)
			end
		end
		if self.animated then
			model:AddTag(Kit.TAG)
		end
		-- Avec StreamingEnabled, la créature arrive/part d'un bloc (jamais à moitié)
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		if self.outline then
			local h = Instance.new("Highlight")
			h.Name = "Outline"
			h.FillTransparency = 1
			h.OutlineColor = Kit.OUTLINE_COLOR
			h.OutlineTransparency = 0.15
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Parent = model
		end
		model.Parent = self.parent
		return model
	end
	
-- ---------------------------------------------------------------------------
	-- Boîte englobante des pièces visibles (dans l'espace du Root)
	-- ---------------------------------------------------------------------------
	
function Kit.visibleBounds(model: Model): (Vector3, Vector3)
		local root = model.PrimaryPart
		local ref = if root then root.CFrame else CFrame.identity
		local minV = Vector3.one * math.huge
		local maxV = -Vector3.one * math.huge
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.95 then
				local cf = ref:ToObjectSpace(d.CFrame)
				local h = d.Size / 2
				for _, s in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1) } do
					for _, k in { 1, -1 } do
						local p = cf * (h * s * k)
						minV = minV:Min(p)
						maxV = maxV:Max(p)
					end
				end
			end
		end
		if minV.X == math.huge then
			return Vector3.zero, Vector3.one
		end
		return (minV + maxV) / 2, maxV - minV
	end
	
return Kit

end

__modules["Rarity"] = function()
	--[[
		CreatureForge.Rarity
		--------------------
		Paliers de rareté : libellé, couleurs (UI) et ordre de tri.
	]]
	
type Tier = {
		id: string,
		label: string,
		order: number,
		color: Color3, -- couleur principale (contour, pastille)
		light: Color3, -- reflet clair du dégradé
		dark: Color3, -- ombre du dégradé
	}
	
local function tier(id: string, label: string, order: number, color: Color3, light: Color3, dark: Color3): Tier
		return { id = id, label = label, order = order, color = color, light = light, dark = dark }
	end
	
local Rarity = {}
	
Rarity.Tiers = {
		Common = tier("Common", "COMMUN", 1, Color3.fromRGB(176, 184, 196), Color3.fromRGB(236, 240, 246), Color3.fromRGB(104, 110, 122)),
		Uncommon = tier("Uncommon", "INHABITUEL", 2, Color3.fromRGB(98, 210, 112), Color3.fromRGB(196, 255, 170), Color3.fromRGB(32, 120, 60)),
		Rare = tier("Rare", "RARE", 3, Color3.fromRGB(64, 152, 255), Color3.fromRGB(170, 222, 255), Color3.fromRGB(26, 70, 170)),
		Epic = tier("Epic", "ÉPIQUE", 4, Color3.fromRGB(172, 92, 255), Color3.fromRGB(232, 180, 255), Color3.fromRGB(84, 30, 160)),
		Legendary = tier("Legendary", "LÉGENDAIRE", 5, Color3.fromRGB(255, 186, 52), Color3.fromRGB(255, 240, 160), Color3.fromRGB(196, 96, 10)),
		Mythic = tier("Mythic", "MYTHIQUE", 6, Color3.fromRGB(255, 64, 108), Color3.fromRGB(255, 186, 214), Color3.fromRGB(140, 10, 60)),
	}
	
function Rarity.get(id: string): Tier
		return Rarity.Tiers[id] or Rarity.Tiers.Common
	end
	
return Rarity

end

__modules["Types"] = function()
	--[[
		CreatureForge.Types
		-------------------
		Contrat commun à toutes les créatures (src/shared/Creatures/*.luau).
	]]
	
local Kit = __require("Kit")
	
--- Paramètres de l'animation procédurale (voir CreatureAnimator).
	type AnimProfile = {
		-- Quadruped : pattes sous le corps (trot) ; Sprawler : pattes écartées + ondulation (reptiles)
		gait: "Quadruped" | "Sprawler" | "Biped" | "Flyer" | "Serpent" | "Hover",
		breathe: number?, -- amplitude de respiration (studs)
		sway: number?, -- ondulation latérale du corps en marche (degrés, Sprawler)
		tongueFlick: boolean?, -- coups de langue (os "Tongue") avec ouverture de mâchoire (os "Jaw")
		bob: number?, -- rebond du corps en marche (studs)
		stride: number?, -- amplitude des pattes (degrés)
		strideRate: number?, -- cadence des pattes (rad/s)
		tailSway: number?, -- balancement de queue (degrés)
		tailRate: number?, -- vitesse du balancement (rad/s)
		headLook: number?, -- regard gauche/droite au repos (degrés)
		sniff: boolean?, -- petits reniflements rapides
		earTwitch: boolean?, -- frémissement des oreilles
	}
	
--- Habillage de l'icône d'inventaire.
	type IconTheme = {
		top: Color3, -- haut du dégradé de fond
		bottom: Color3, -- bas du dégradé de fond
		glow: Color3, -- halo derrière la créature
		motif: Color3?, -- couleur des motifs décoratifs (losanges)
		yaw: number?, -- angle caméra horizontal (degrés, 0 = face)
		pitch: number?, -- angle caméra vertical (degrés)
		zoom: number?, -- > 1 = plus proche
	}
	
type CreatureDef = {
		Id: string,
		DisplayName: string,
		Rarity: string,
		Category: string,
		Description: string,
		Icon: IconTheme,
		Animation: AnimProfile,
		build: (opts: Kit.BuildOptions?) -> Model,
	}
	
return {}

end

__modules["Icon"] = function()
	--[[
		CreatureForge.Icon
		------------------
		Carte d'icône d'inventaire pour une créature :
		  • fond en dégradé (UIGradient) aux coins arrondis (UICorner) ;
		  • contour de rareté en dégradé (UIStroke + UIGradient) ;
		  • halo, losanges décoratifs, ombre au sol, reflet brillant ;
		  • la créature en 3D (ViewportFrame + Camera cadrée sur sa boîte englobante) ;
		  • pastille de rareté, gemme, plaque de nom.
		La carte est carrée (UIAspectRatioConstraint) et remplit sa cellule par défaut :
		parfait dans une grille UIGridLayout.
	]]
	
local Kit = __require("Kit")
	local Rarity = __require("Rarity")
	local Types = __require("Types")
	
local Icon = {}
	
type IconOptions = {
		size: UDim2?, -- défaut : UDim2.fromScale(1, 1)
		position: UDim2?,
		anchorPoint: Vector2?,
		layoutOrder: number?,
		showName: boolean?, -- défaut : true
		showRarity: boolean?, -- défaut : true
	}
	
local WHITE = Color3.new(1, 1, 1)
	local BLACK = Color3.new(0, 0, 0)
	local FONT = Font.fromEnum(Enum.Font.FredokaOne)
	
local function corner(parent: Instance, scale: number): UICorner
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(scale, 0)
		c.Parent = parent
		return c
	end
	
local function gradient(parent: Instance, colors: { Color3 }, rotation: number, transparency: { number }?): UIGradient
		local g = Instance.new("UIGradient")
		local kps = {}
		for i, c in colors do
			table.insert(kps, ColorSequenceKeypoint.new((i - 1) / math.max(#colors - 1, 1), c))
		end
		if #kps == 1 then
			table.insert(kps, ColorSequenceKeypoint.new(1, colors[1]))
		end
		g.Color = ColorSequence.new(kps)
		if transparency then
			local tk = {}
			for i, t in transparency do
				table.insert(tk, NumberSequenceKeypoint.new((i - 1) / math.max(#transparency - 1, 1), t))
			end
			g.Transparency = NumberSequence.new(tk)
		end
		g.Rotation = rotation
		g.Parent = parent
		return g
	end
	
local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = thickness
		s.Transparency = transparency or 0
		s.Parent = parent
		return s
	end
	
local function frame(name: string, parent: Instance, size: UDim2, pos: UDim2, color: Color3, transparency: number, z: number): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = size
		f.Position = pos
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency
		f.BorderSizePixel = 0
		f.ZIndex = z
		f.Parent = parent
		return f
	end
	
local function label(name: string, parent: Instance, text: string, color: Color3, maxSize: number): TextLabel
		local t = Instance.new("TextLabel")
		t.Name = name
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(0.5, 0.5)
		t.Size = UDim2.fromScale(0.9, 0.78)
		t.BackgroundTransparency = 1
		t.FontFace = FONT
		t.Text = text
		t.TextColor3 = color
		t.TextScaled = true
		t.ZIndex = 6
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = maxSize
		c.MinTextSize = 6
		c.Parent = t
		t.Parent = parent
		return t
	end
	
--- Calcule le CFrame de caméra qui cadre `model` selon le thème de l'icône.
	function Icon.frameCamera(model: Model, camera: Camera, theme: Types.IconTheme)
		local center, size = Kit.visibleBounds(model)
		local root = model.PrimaryPart
		local ref = if root then root.CFrame else CFrame.identity
		local radius = size.Magnitude * 0.5
		local dist = radius / math.sin(math.rad(camera.FieldOfView) / 2) / (theme.zoom or 1)
		local yaw, pitch = math.rad(theme.yaw or 30), math.rad(theme.pitch or 15)
		local dir = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
		local target = ref * center
		camera.CFrame = CFrame.lookAt(target + ref:VectorToWorldSpace(dir) * dist, target)
	end
	
--- Construit la carte d'icône de `def` et la parente à `parent`.
	function Icon.build(def: Types.CreatureDef, parent: Instance?, opts: IconOptions?): Frame
		local o: IconOptions = opts or {}
		local theme = def.Icon
		local tier = Rarity.get(def.Rarity)
	
	-- Carte
		local card = Instance.new("Frame")
		card.Name = "Icon_" .. def.Id
		card.Size = o.size or UDim2.fromScale(1, 1)
		card.Position = o.position or UDim2.new()
		card.AnchorPoint = o.anchorPoint or Vector2.zero
		card.BackgroundColor3 = WHITE
		card.BorderSizePixel = 0
		card.LayoutOrder = o.layoutOrder or tier.order
		card:SetAttribute("CreatureId", def.Id)
		corner(card, 0.16)
		gradient(card, { theme.top, theme.bottom }, 90)
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.AspectRatio = 1
		ratio.Parent = card
		gradient(stroke(card, WHITE, 3), { tier.light, tier.color, tier.dark, tier.color }, 45)
	
	-- Losanges décoratifs (cristaux stylisés)
		local motif = theme.motif or theme.glow
		for _, m in { { 0.13, 0.3, 0.1 }, { 0.87, 0.24, 0.07 }, { 0.1, 0.62, 0.06 }, { 0.9, 0.55, 0.09 } } do
			local d = frame("Motif", card, UDim2.fromScale(m[3], m[3]), UDim2.fromScale(m[1], m[2]), motif, 0.55, 1)
			d.Rotation = 45
			gradient(d, { WHITE, motif }, 90, { 0.2, 0.7 })
		end
	
	-- Halo
		for i, h in { { 0.92, 0.9 }, { 0.68, 0.82 }, { 0.44, 0.72 } } do
			local g = frame("Glow" .. i, card, UDim2.fromScale(h[1], h[1]), UDim2.fromScale(0.5, 0.47), theme.glow, h[2], 1)
			corner(g, 0.5)
		end
	
	-- Ombre au sol
		local shadow = frame("Shadow", card, UDim2.fromScale(0.62, 0.11), UDim2.fromScale(0.5, 0.71), BLACK, 0.55, 1)
		corner(shadow, 0.5)
	
	-- Créature en 3D
		local vf = Instance.new("ViewportFrame")
		vf.Name = "Viewport"
		vf.Size = UDim2.fromScale(1, 1)
		vf.BackgroundTransparency = 1
		vf.Ambient = Color3.fromRGB(160, 160, 176)
		vf.LightColor = Color3.fromRGB(255, 248, 236)
		vf.LightDirection = Vector3.new(-0.6, -1, 0.5)
		vf.ZIndex = 2
		vf.Parent = card
		local cam = Instance.new("Camera")
		cam.FieldOfView = 28
		cam.Parent = vf
		vf.CurrentCamera = cam
		local model = def.build({ effects = false, outline = false, animated = false })
		model.Parent = vf
		Icon.frameCamera(model, cam, theme)
	
	-- Reflet brillant
		local sheen = frame("Sheen", card, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), WHITE, 0, 3)
		corner(sheen, 0.16)
		gradient(sheen, { WHITE }, 35, { 1, 1, 0.82, 1, 1 })
	
	-- Pastille de rareté
		if o.showRarity ~= false then
			local pill = frame("Rarity", card, UDim2.fromScale(0.44, 0.12), UDim2.fromScale(0.27, 0.1), WHITE, 0, 5)
			corner(pill, 0.5)
			gradient(pill, { tier.light, tier.color }, 90)
			stroke(pill, tier.dark, 1.5)
			local t = label("Label", pill, tier.label, tier.dark, 16)
			t.Size = UDim2.fromScale(0.86, 0.7)
	
		local gem = frame("Gem", card, UDim2.fromScale(0.085, 0.085), UDim2.fromScale(0.89, 0.1), WHITE, 0, 5)
			gem.Rotation = 45
			gradient(gem, { tier.light, tier.color, tier.dark }, 45)
			stroke(gem, BLACK, 1.5, 0.3)
		end
	
	-- Plaque de nom
		if o.showName ~= false then
			local plate = frame("NamePlate", card, UDim2.fromScale(0.9, 0.17), UDim2.fromScale(0.5, 0.86), BLACK, 0.3, 5)
			corner(plate, 0.4)
			gradient(plate, { WHITE }, 90, { 0.4, 0 })
			stroke(plate, tier.color, 1.5, 0.35)
			local t = label("Name", plate, def.DisplayName, WHITE, 26)
			stroke(t, BLACK, 1.5)
		end
	
	card.Parent = parent
		return card
	end
	
return Icon

end

__modules["Fx"] = function()
	--[[
		CreatureForge.Fx
		----------------
		Fabriques de particules et de lumières. Utilise uniquement les textures
		intégrées au moteur (rbxasset://) : aucun asset à téléverser.
		Les tailles, vitesses et accélérations sont multipliées par `scale`.
	]]
	
local Fx = {}
	
Fx.TEXTURES = {
		sparkle = "rbxasset://textures/particles/sparkles_main.dds",
		smoke = "rbxasset://textures/particles/smoke_main.dds",
		fire = "rbxasset://textures/particles/fire_main.dds",
		spark = "rbxasset://textures/particles/fire_sparks_main.dds",
	}
	
type ParticleDef = {
		name: string,
		texture: string?,
		colors: { Color3 }, -- répartis uniformément sur la durée de vie
		sizes: { number }, -- idem (studs, avant échelle)
		transparencies: { number }?, -- idem
		lifetime: NumberRange,
		rate: number,
		speed: NumberRange?,
		spread: Vector2?, -- SpreadAngle en degrés
		acceleration: Vector3?,
		drag: number?,
		lightEmission: number?,
		lightInfluence: number?,
		brightness: number?,
		rotation: NumberRange?,
		rotSpeed: NumberRange?,
		lockedToPart: boolean?,
		direction: Enum.NormalId?,
		volume: boolean?, -- émettre dans tout le volume de la pièce
		zOffset: number?,
	}
	
type LightDef = {
		color: Color3,
		range: number,
		brightness: number?,
		shadows: boolean?,
	}
	
local function numberSeq(values: { number }, mul: number): NumberSequence
		if #values == 1 then
			return NumberSequence.new(values[1] * mul)
		end
		local kps = {}
		for i, v in values do
			table.insert(kps, NumberSequenceKeypoint.new((i - 1) / (#values - 1), v * mul))
		end
		return NumberSequence.new(kps)
	end
	
local function colorSeq(values: { Color3 }): ColorSequence
		if #values == 1 then
			return ColorSequence.new(values[1])
		end
		local kps = {}
		for i, c in values do
			table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#values - 1), c))
		end
		return ColorSequence.new(kps)
	end
	
function Fx.particles(parent: Instance, def: ParticleDef, scale: number?): ParticleEmitter
		local s = scale or 1
		local e = Instance.new("ParticleEmitter")
		e.Name = def.name
		e.Texture = def.texture or Fx.TEXTURES.sparkle
		e.Color = colorSeq(def.colors)
		e.Size = numberSeq(def.sizes, s)
		e.Transparency = numberSeq(def.transparencies or { 0 }, 1)
		e.Lifetime = def.lifetime
		e.Rate = def.rate
		local speed = def.speed or NumberRange.new(0)
		e.Speed = NumberRange.new(speed.Min * s, speed.Max * s)
		e.SpreadAngle = def.spread or Vector2.zero
		e.Acceleration = (def.acceleration or Vector3.zero) * s
		e.Drag = def.drag or 0
		e.LightEmission = def.lightEmission or 0
		e.LightInfluence = def.lightInfluence or 1
		e.Brightness = def.brightness or 1
		e.Rotation = def.rotation or NumberRange.new(0)
		e.RotSpeed = def.rotSpeed or NumberRange.new(0)
		e.LockedToPart = def.lockedToPart or false
		e.EmissionDirection = def.direction or Enum.NormalId.Top
		e.ZOffset = (def.zOffset or 0) * s
		if def.volume then
			e.Shape = Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		end
		e.Parent = parent
		return e
	end
	
function Fx.light(parent: Instance, def: LightDef, scale: number?): PointLight
		local l = Instance.new("PointLight")
		l.Color = def.color
		l.Range = def.range * (scale or 1)
		l.Brightness = def.brightness or 1
		l.Shadows = def.shadows or false
		l.Parent = parent
		return l
	end
	
return Fx

end

__modules["RatDesCavernes"] = function()
	--[[
		LE RAT DES CAVERNES — Commun
		============================
		Petit rongeur agile aux yeux lumineux (Neon), corps sombre texturé (Fabric)
		et petites oreilles pointues.
	
	Détails :
		  • fourrure en écailles le long de l'échine et des flancs (WedgeParts) ;
		  • plaque de roche (Slate) sur le dos d'où poussent trois cristaux de grotte (Neon) ;
		  • yeux Neon cerclés de noir, sourcils, moustaches, incisives, joues ;
		  • anneau doré à l'oreille gauche, bague dorée sur la queue annelée ;
		  • pattes avant fines, cuisses arrière puissantes, griffes.
		  • Particules : poussière de grotte au sol, éclats dans les yeux, spores des cristaux.
		  • Lumières : lueur des yeux + lueur des cristaux.
	
	Os (Motor6D) : Root > Body > Head > Ear_R / Ear_L
		                       Body > Tail1 > … > Tail6
		                       Body > Leg_FR / Leg_FL / Leg_BR / Leg_BL
		Taille (scale = 1) : ~1,9 stud de haut, ~5,7 studs du museau au bout de la queue.
	]]
	
local Kit = __require("Kit")
	local Fx = __require("Fx")
	local Types = __require("Types")
	
local S = Kit.style
	local M = Enum.Material
	local rgb = Color3.fromRGB
	local rad = math.rad
	local v3 = Vector3.new
	local cf = CFrame.new
	local ang = CFrame.Angles
	
local ID = "RatDesCavernes"
	
local P = {
		fur = S(rgb(74, 68, 88), M.Fabric),
		furDark = S(rgb(46, 42, 58), M.Fabric),
		furLight = S(rgb(124, 116, 136), M.Fabric),
		belly = S(rgb(152, 142, 154), M.Fabric),
		skin = S(rgb(206, 138, 150)),
		skinDark = S(rgb(150, 94, 108)),
		tooth = S(rgb(240, 222, 168)),
		claw = S(rgb(232, 226, 212)),
		eye = S(rgb(120, 255, 226), M.Neon),
		eyeSocket = S(rgb(22, 20, 28)),
		whisker = S(rgb(206, 206, 216), M.SmoothPlastic, { transparency = 0.15, castShadow = false }),
		stone = S(rgb(92, 92, 104), M.Slate),
		crystal = S(rgb(110, 236, 255), M.Neon, { transparency = 0.1 }),
		gold = S(rgb(226, 176, 66), M.Metal, { reflectance = 0.05 }),
	}
	
-- Ligne de l'échine : (z, hauteur du dos)
	local SPINE = {
		{ -0.95, 1.36 },
		{ -0.6, 1.45 },
		{ -0.2, 1.53 },
		{ 0.2, 1.62 },
		{ 0.5, 1.72 },
		{ 0.9, 1.66 },
		{ 1.3, 1.52 },
	}
	
local function spineY(z: number): number
		for i = 1, #SPINE - 1 do
			local a, b = SPINE[i], SPINE[i + 1]
			if z <= b[1] then
				local t = math.clamp((z - a[1]) / (b[1] - a[1]), 0, 1)
				return a[2] + (b[2] - a[2]) * t
			end
		end
		return SPINE[#SPINE][2]
	end
	
local function spineSlope(z: number): number
		local d = 0.05
		return math.atan((spineY(z + d) - spineY(z - d)) / (2 * d))
	end
	
-- Queue : articulations et diamètres des segments
	local TAIL = {
		v3(0, 0.98, 1.2),
		v3(0, 0.74, 1.72),
		v3(0.06, 0.48, 2.2),
		v3(0.22, 0.3, 2.7),
		v3(0.5, 0.28, 3.18),
		v3(0.9, 0.42, 3.52),
		v3(1.32, 0.72, 3.68),
	}
	local TAIL_D = { 0.27, 0.23, 0.19, 0.15, 0.115, 0.08 }
	
local function earBase(side: number): CFrame
		return cf(side * 0.3, 1.56, -1.0) * ang(rad(12), -side * rad(28), -side * rad(24))
	end
	
local function build(opts: Kit.BuildOptions?): Model
		local rig = Kit.newRig(ID, opts)
	
	-- ===================================================================
		-- Squelette
		-- ===================================================================
		rig:bone("Body", "Root", cf(0, 1.0, 0.2))
		rig:bone("Head", "Body", cf(0, 1.18, -0.85))
		rig:mirrored(function(side, sfx)
			local s = string.sub(sfx, 2)
			rig:bone("Ear" .. sfx, "Head", earBase(side))
			rig:bone("Leg_F" .. s, "Body", cf(side * 0.45, 0.88, -0.62))
			rig:bone("Leg_B" .. s, "Body", cf(side * 0.6, 1.0, 0.75))
		end)
		rig:boneChain("Tail", "Body", TAIL)
	
	-- ===================================================================
		-- Corps
		-- ===================================================================
		rig:prism("Body", "Torso", cf(0, 1.02, 0.12), v3(1.22, 1.0, 1.5), 0.3, P.fur)
		rig:prism("Body", "Rump", cf(0, 1.12, 0.85) * ang(rad(10), 0, 0), v3(1.42, 1.1, 1.0), 0.38, P.fur)
		rig:prism("Body", "Haunches", cf(0, 1.0, 1.36) * ang(rad(30), 0, 0), v3(1.16, 0.8, 0.52), 0.3, P.fur)
		rig:prism("Body", "Chest", cf(0, 0.98, -0.6) * ang(rad(-6), 0, 0), v3(0.98, 0.9, 0.75), 0.26, P.fur)
		rig:prism("Body", "Neck", cf(0, 1.12, -0.92) * ang(rad(-14), 0, 0), v3(0.8, 0.74, 0.42), 0.22, P.furDark)
		rig:prism("Body", "Belly", cf(0, 0.6, 0.15), v3(0.84, 0.24, 1.75), 0.08, P.belly)
		rig:prism("Body", "Chin", cf(0, 0.76, -0.82) * ang(rad(-18), 0, 0), v3(0.56, 0.26, 0.5), 0.1, P.belly)
	
	-- Fourrure de l'échine : écailles inclinées vers l'arrière
		local tuftZ = { -0.78, -0.48, -0.18, 0.62, 0.92, 1.2 }
		for i, z in tuftZ do
			local w = if z < -0.3 then 0.4 else 0.48
			rig:wedge(
				"Body",
				"SpineTuft",
				cf(0, spineY(z) + 0.08, z) * ang(spineSlope(z), 0, 0),
				v3(w, 0.32, 0.42),
				if i % 2 == 0 then P.fur else P.furDark
			)
		end
	
	-- Fourrure des flancs
		local flank = {
			{ 0.41, 1.33, -0.55 },
			{ 0.49, 1.4, -0.15 },
			{ 0.55, 1.5, 0.3 },
			{ 0.58, 1.52, 0.75 },
			{ 0.53, 1.38, 1.15 },
		}
		rig:mirrored(function(side)
			for i, f in flank do
				rig:wedge(
					"Body",
					"FlankTuft",
					cf(side * f[1], f[2], f[3]) * ang(0, 0, -side * rad(45)),
					v3(0.26, 0.18, 0.4),
					if i % 2 == 0 then P.furDark else P.fur
				)
			end
		end)
	
	-- Plaque de roche + cristaux de grotte
		local rockCF = cf(0, spineY(0.25) + 0.02, 0.25) * ang(spineSlope(0.25), rad(8), 0)
		rig:prism("Body", "RockPlate", rockCF, v3(0.62, 0.2, 0.62), 0.08, P.stone)
		rig:prism("Body", "RockPlate", rockCF * cf(0.12, 0.08, 0.05) * ang(0, rad(30), 0), v3(0.34, 0.16, 0.34), 0.06, P.stone)
		rig:shard("Body", "Crystal", rockCF * cf(0, 0.08, 0.02) * ang(rad(16), 0, 0) * ang(0, rad(45), 0), 0.18, 0.36, 0.16, P.crystal)
		rig:shard("Body", "Crystal", rockCF * cf(0.17, 0.06, 0.08) * ang(rad(10), 0, rad(-32)) * ang(0, rad(45), 0), 0.12, 0.22, 0.11, P.crystal)
		rig:shard("Body", "Crystal", rockCF * cf(-0.15, 0.06, 0.12) * ang(rad(20), 0, rad(28)) * ang(0, rad(45), 0), 0.1, 0.16, 0.09, P.crystal)
	
	-- ===================================================================
		-- Tête
		-- ===================================================================
		local skull = rig:prism("Head", "Skull", cf(0, 1.26, -1.2), v3(0.92, 0.78, 0.8), 0.24, P.fur)[1]
		rig:prism("Head", "Snout", cf(0, 1.1, -1.78), v3(0.54, 0.46, 0.4), 0.15, P.fur)
		rig:prism("Head", "SnoutTip", cf(0, 1.06, -2.06), v3(0.4, 0.36, 0.2), 0.11, P.fur)
		rig:wedge("Head", "Bridge", cf(0, 1.445, -1.88), v3(0.34, 0.41, 0.56), P.fur)
		rig:prism("Head", "Jaw", cf(0, 0.87, -1.78), v3(0.38, 0.15, 0.5), 0.06, P.furLight)
		rig:ball("Head", "Nose", v3(0, 1.17, -2.17), 0.18, P.skin)
	
	-- Crête de fourrure sur le crâne
		rig:wedge("Head", "HeadTuft", cf(0, 1.69, -1.12) * ang(rad(-8), 0, 0), v3(0.34, 0.2, 0.4), P.furDark)
	
	local eyes: { BasePart } = {}
		rig:mirrored(function(side, sfx)
			rig:prism("Head", "Cheek" .. sfx, cf(side * 0.35, 1.0, -1.42), v3(0.24, 0.32, 0.42), 0.1, P.furLight)
			rig:block("Head", "Tooth" .. sfx, cf(side * 0.04, 0.8, -2.08), v3(0.07, 0.15, 0.045), P.tooth)
	
		rig:ball("Head", "EyeSocket" .. sfx, v3(side * 0.4, 1.37, -1.5), 0.27, P.eyeSocket)
			table.insert(eyes, rig:ball("Head", "Eye" .. sfx, v3(side * 0.43, 1.37, -1.53), 0.22, P.eye))
			rig:block("Head", "Brow" .. sfx, cf(side * 0.36, 1.53, -1.52) * ang(0, side * rad(-10), -side * rad(28)), v3(0.3, 0.07, 0.14), P.furDark)
	
		for k = -1, 1 do
				rig:strut(
					"Head",
					"Whisker" .. sfx,
					v3(side * 0.18, 1.05 + k * 0.05, -2.0),
					v3(side * 0.92, 1.1 + k * 0.16, -1.74 + k * 0.08),
					0.025,
					0.025,
					P.whisker
				)
			end
	
		-- Oreilles pointues
			local ear = "Ear" .. sfx
			local base = earBase(side)
			rig:spike(ear, "Ear", base, 0.44, 0.48, 0.07, P.fur)
			rig:spike(ear, "EarInner", base * cf(0, 0.05, -0.045), 0.27, 0.32, 0.03, P.skin)
			if side < 0 then
				-- Anneau doré passé dans le bord extérieur de l'oreille gauche
				local edge = 0.22 * (1 - 0.07 / 0.48)
				rig:ring(ear, "Earring", base * cf(side * edge, 0.07, 0) * ang(0, math.pi / 2, 0), 0.075, 0.03, 0.03, 8, P.gold)
			end
		end)
	
	-- ===================================================================
		-- Pattes
		-- ===================================================================
		rig:mirrored(function(side, sfx)
			local s = string.sub(sfx, 2)
			local front, back = "Leg_F" .. s, "Leg_B" .. s
	
		-- Avant : bras fin, épaule fourrée, petite main rose, griffes
			rig:prism(front, "Shoulder", cf(side * 0.45, 0.82, -0.58), v3(0.32, 0.42, 0.46), 0.12, P.furDark)
			rig:prismBetween(front, "Arm", v3(side * 0.46, 0.84, -0.56), v3(side * 0.48, 0.4, -0.48), 0.24, 0.26, 0.08, P.fur)
			rig:prismBetween(front, "Forearm", v3(side * 0.48, 0.46, -0.48), v3(side * 0.49, 0.13, -0.72), 0.2, 0.22, 0.06, P.fur)
			rig:prism(front, "Paw", cf(side * 0.49, 0.085, -0.8), v3(0.28, 0.15, 0.42), 0.05, P.skin)
			for k = -1, 1 do
				rig:wedge(front, "Claw", cf(side * 0.49 + k * 0.085, 0.045, -1.06), v3(0.05, 0.07, 0.11), P.claw)
			end
	
		-- Arrière : cuisse puissante, jarret, long pied rose, griffes
			rig:prism(back, "Thigh", cf(side * 0.6, 0.86, 0.75) * ang(rad(-14), 0, 0), v3(0.42, 0.8, 0.9), 0.2, P.fur)
			rig:wedge(back, "ThighTuft", cf(side * 0.7, 1.08, 1.12) * ang(rad(-30), 0, -side * rad(20)), v3(0.26, 0.2, 0.34), P.furDark)
			rig:prismBetween(back, "Shin", v3(side * 0.64, 0.6, 1.0), v3(side * 0.64, 0.12, 0.86), 0.22, 0.24, 0.06, P.fur)
			rig:prism(back, "Foot", cf(side * 0.64, 0.085, 0.72), v3(0.3, 0.15, 0.66), 0.05, P.skin)
			for k = -1, 1 do
				rig:wedge(back, "Claw", cf(side * 0.64 + k * 0.09, 0.045, 0.335), v3(0.05, 0.07, 0.11), P.claw)
			end
		end)
	
	-- ===================================================================
		-- Queue annelée
		-- ===================================================================
		for i = 1, #TAIL - 1 do
			local bone = "Tail" .. i
			local a, b, d = TAIL[i], TAIL[i + 1], TAIL_D[i]
			rig:cylinder(bone, "Tail", a, b, d, P.skin)
			rig:ball(bone, "TailJoint", b, d, P.skin)
			if i == 2 then
				-- Bague dorée (à la sortie de la croupe)
				rig:cylinder(bone, "TailBand", a:Lerp(b, 0.1), a:Lerp(b, 0.3), d + 0.08, P.gold)
				rig:cylinder(bone, "TailBandRim", a:Lerp(b, 0.16), a:Lerp(b, 0.24), d + 0.12, P.gold)
				rig:cylinder(bone, "TailRing", a:Lerp(b, 0.63), a:Lerp(b, 0.69), d + 0.035, P.skinDark)
			elseif i > 2 then
				for _, t in { 0.33, 0.66 } do
					rig:cylinder(bone, "TailRing", a:Lerp(b, t - 0.03), a:Lerp(b, t + 0.03), d + 0.035, P.skinDark)
				end
			end
		end
	
	rig:hitbox(cf(0, 0.95, -0.3), v3(1.7, 1.9, 3.6))
	
	-- ===================================================================
		-- Effets
		-- ===================================================================
		if rig.effects then
			local sc = rig.scale
	
		local dust = rig:anchor("Root", "FX_Dust", cf(0, 0.15, 0.2), v3(1.8, 0.25, 3.0))
			Fx.particles(dust, {
				name = "CaveDust",
				texture = Fx.TEXTURES.smoke,
				colors = { rgb(128, 118, 108), rgb(90, 86, 82) },
				sizes = { 0.2, 0.55 },
				transparencies = { 1, 0.7, 1 },
				lifetime = NumberRange.new(1.4, 2.4),
				rate = 4,
				speed = NumberRange.new(0.15, 0.45),
				spread = Vector2.new(70, 70),
				acceleration = v3(0, 0.12, 0),
				drag = 1,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-20, 20),
				volume = true,
			}, sc)
	
		for _, eye in eyes do
				Fx.particles(eye, {
					name = "EyeGlint",
					texture = Fx.TEXTURES.sparkle,
					colors = { P.eye.color },
					sizes = { 0.32, 0 },
					transparencies = { 0.2, 1 },
					lifetime = NumberRange.new(0.35, 0.6),
					rate = 1.5,
					lockedToPart = true,
					lightEmission = 1,
					zOffset = 0.25,
					rotation = NumberRange.new(0, 360),
				}, sc)
			end
			Fx.light(skull, { color = P.eye.color, range = 6, brightness = 1.2 }, sc)
	
		local spores = rig:anchor("Body", "FX_Spores", rockCF * cf(0, 0.35, 0), v3(0.45, 0.4, 0.45))
			Fx.particles(spores, {
				name = "CrystalSpores",
				texture = Fx.TEXTURES.sparkle,
				colors = { P.crystal.color, rgb(200, 255, 255) },
				sizes = { 0.14, 0.08, 0 },
				transparencies = { 0.1, 0.3, 1 },
				lifetime = NumberRange.new(1.6, 2.6),
				rate = 2.5,
				speed = NumberRange.new(0.15, 0.4),
				spread = Vector2.new(30, 30),
				acceleration = v3(0, 0.25, 0),
				drag = 0.5,
				lightEmission = 1,
				volume = true,
			}, sc)
			Fx.light(spores, { color = P.crystal.color, range = 5, brightness = 0.8 }, sc)
		end
	
	return rig:finish({ Rarity = "Common" })
	end
	
local RatDesCavernes: Types.CreatureDef = {
		Id = ID,
		DisplayName = "Rat des Cavernes",
		Rarity = "Common",
		Category = "Créature Commune",
		Description = "Petit rongeur agile des grottes. Ses yeux luisent dans le noir et des cristaux poussent sur son dos.",
		Icon = {
			top = rgb(44, 58, 78),
			bottom = rgb(14, 16, 26),
			glow = rgb(120, 255, 226),
			motif = rgb(110, 236, 255),
			yaw = 36,
			pitch = 14,
			zoom = 1.1,
		},
		Animation = {
			gait = "Quadruped",
			breathe = 0.03,
			bob = 0.1,
			stride = 34,
			strideRate = 16,
			tailSway = 16,
			tailRate = 2.6,
			headLook = 22,
			sniff = true,
			earTwitch = true,
		},
		build = build,
	}
	
return RatDesCavernes

end

-- ============================================================================
-- Entrée
-- ============================================================================
do
	local def = __require("RatDesCavernes")
	local Icon = __require("Icon")

	-- Position : 14 studs devant la caméra, posée au sol, tournée vers la caméra
	local look = Vector3.new(0, 0, -1)
	local pos = Vector3.zero
	local camera = workspace.CurrentCamera
	if camera then
		local flat = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
		if flat.Magnitude > 0.01 then
			look = flat.Unit
		end
		pos = camera.CFrame.Position + look * 14
	end
	local hit = workspace:Raycast(pos + Vector3.new(0, 50, 0), Vector3.new(0, -300, 0))
	local ground = if hit then hit.Position else Vector3.new(pos.X, 0, pos.Z)
	local model = def.build({ cframe = CFrame.lookAt(ground, ground - look), parent = workspace })

	-- Icône UI (visible dans l'éditeur via StarterGui)
	local StarterGui = game:GetService("StarterGui")
	local gui = StarterGui:FindFirstChild("CreatureForgeIcons")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "CreatureForgeIcons"
		gui.ResetOnSpawn = false
		gui.Parent = StarterGui
	end
	local tray = gui:FindFirstChild("Tray")
	if not tray then
		tray = Instance.new("Frame")
		tray.Name = "Tray"
		tray.BackgroundTransparency = 1
		tray.AnchorPoint = Vector2.new(0, 1)
		tray.Position = UDim2.new(0, 16, 1, -16)
		tray.Size = UDim2.fromScale(0.9, 0.18)
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, 10)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = tray
		tray.Parent = gui
	end
	local old = tray:FindFirstChild("Icon_" .. def.Id)
	if old then
		old:Destroy()
	end
	Icon.build(def, tray)

	pcall(function()
		game:GetService("Selection"):Set({ model })
	end)
	pcall(function()
		game:GetService("ChangeHistoryService"):SetWaypoint("CreatureForge : " .. def.DisplayName)
	end)
	print(("[CreatureForge] %s créé (%d pièces) à %s"):format(def.DisplayName, model:GetAttribute("PartCount"), tostring(ground)))
end
