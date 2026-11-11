-- CreatureForge — LezardMousseux
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

__modules["LezardMousseux"] = function()
	--[[
		LE LÉZARD MOUSSEUX — Commun
		===========================
		Reptile rampant recouvert de plaques écailleuses vertes (Slate) et de mousse,
		avec de petites dorures sur le dos.
	
	Détails :
		  • peau verte grumeleuse (Pebble), ventre clair, queue annelée vert clair / vert sombre ;
		  • trois rangées de plaques d'écailles imbriquées (WedgeParts en Slate) du cou à la queue ;
		  • dorures : rivets dorés sur l'échine, liserés dorés sur trois plaques, losange doré au front ;
		  • touffes de mousse (Grass) avec jeunes pousses sur le dos, la tête et la base de la queue,
		    petite barbe de mousse sous le menton ;
		  • yeux dorés à pupille fendue, arcades osseuses, narines, mâchoire articulée,
		    langue fourchue rétractable ;
		  • pattes écartées de reptile, doigts écartés et griffes sombres.
		  • Particules : pollen qui s'échappe de la mousse, reflets sur les dorures, poussière au sol.
	
	Os (Motor6D) : Root > Body > Chest > Head > Jaw / Tongue
		                      Body > Tail1 > … > Tail7
		                      Chest > Leg_FR / Leg_FL      Body > Leg_BR / Leg_BL
		Taille (scale = 1) : ~1,1 stud de haut, ~7 studs du museau au bout de la queue.
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
	
local ID = "LezardMousseux"
	
local P = {
		skin = S(rgb(92, 136, 70), M.Pebble),
		skinDark = S(rgb(60, 98, 54), M.Pebble),
		belly = S(rgb(214, 204, 146)),
		plate = S(rgb(72, 132, 88), M.Slate),
		plateLight = S(rgb(110, 166, 100), M.Slate),
		plateDark = S(rgb(44, 88, 64), M.Slate),
		moss = S(rgb(98, 150, 48), M.Grass),
		mossLight = S(rgb(142, 188, 68), M.Grass),
		sprout = S(rgb(176, 222, 96)),
		gold = S(rgb(226, 176, 66), M.Metal, { reflectance = 0.05 }),
		eye = S(rgb(250, 196, 54)),
		pupil = S(rgb(18, 16, 14)),
		mouth = S(rgb(140, 54, 66)),
		tongue = S(rgb(222, 82, 112)),
		claw = S(rgb(44, 38, 32)),
	}
	
-- Hauteur du dos selon z (sommet des volumes du cou, du torse et des hanches)
	local BACK = {
		{ -1.5, 0.84 },
		{ -1.1, 0.85 },
		{ -0.3, 0.85 },
		{ 0.5, 0.85 },
		{ 1.1, 0.8 },
		{ 1.35, 0.72 },
	}
	
local function backY(z: number): number
		for i = 1, #BACK - 1 do
			local a, b = BACK[i], BACK[i + 1]
			if z <= b[1] then
				local t = math.clamp((z - a[1]) / (b[1] - a[1]), 0, 1)
				return a[2] + (b[2] - a[2]) * t
			end
		end
		return BACK[#BACK][2]
	end
	
-- Le torse avant (et le cou) appartiennent à l'os Chest, le reste à Body
	local function trunkBone(z: number): string
		return if z < -0.3 then "Chest" else "Body"
	end
	
-- Queue : articulations, largeur et hauteur de chaque segment
	local TAIL = {
		v3(0, 0.55, 1.05),
		v3(0, 0.47, 1.6),
		v3(0.08, 0.38, 2.15),
		v3(0.26, 0.3, 2.68),
		v3(0.42, 0.25, 3.2),
		v3(0.42, 0.22, 3.72),
		v3(0.22, 0.2, 4.2),
		v3(-0.12, 0.19, 4.6),
	}
	local TAIL_W = { 0.66, 0.54, 0.44, 0.36, 0.28, 0.2, 0.13 }
	
-- Pattes : épaule/hanche -> coude/genou -> poignet/cheville, doigts (angle vers l'extérieur, longueur)
	local LEGS = {
		F = {
			hip = v3(0.35, 0.55, -0.85),
			knee = v3(0.82, 0.48, -0.95),
			ankle = v3(0.9, 0.1, -1.02),
			foot = v3(0.92, 0.06, -1.06),
			upper = { 0.24, 0.22 },
			lower = { 0.18, 0.2 },
			joint = 0.24,
			toes = { { -45, 0.2 }, { -15, 0.27 }, { 15, 0.26 }, { 45, 0.2 } },
		},
		B = {
			hip = v3(0.32, 0.55, 0.85),
			knee = v3(0.82, 0.5, 0.72),
			ankle = v3(0.92, 0.1, 0.86),
			foot = v3(0.95, 0.06, 0.86),
			upper = { 0.32, 0.3 },
			lower = { 0.2, 0.22 },
			joint = 0.3,
			toes = { { 5, 0.26 }, { 35, 0.34 }, { 65, 0.3 }, { 100, 0.2 } },
		},
	}
	
local function build(opts: Kit.BuildOptions?): Model
		local rig = Kit.newRig(ID, opts)
	
	-- Touffe de mousse : trois boules (Grass) + jeunes pousses
		local function moss(bone: string, c: Vector3, size: number, seed: number)
			rig:prism(bone, "MossPad", cf(c - v3(0, 0.07, 0) * size) * ang(0, seed, 0), v3(0.46, 0.1, 0.4) * size, 0.04 * size, P.moss)
			rig:ball(bone, "Moss", c, 0.26 * size, P.moss)
			rig:ball(bone, "Moss", c + v3(0.11, -0.02, 0.07) * size, 0.19 * size, P.mossLight)
			rig:ball(bone, "Moss", c + v3(-0.1, -0.03, -0.08) * size, 0.17 * size, P.moss)
			for k = 0, 2 do
				local a = seed + k * 2.1
				local base = cf(c + v3(math.cos(a) * 0.07, 0.07, math.sin(a) * 0.07) * size)
					* ang(math.cos(a) * 0.35, a, math.sin(a) * 0.35)
				rig:spike(bone, "Sprout", base, 0.05 * size, (0.13 + k * 0.03) * size, 0.02, P.sprout)
			end
		end
	
	-- ===================================================================
		-- Squelette
		-- ===================================================================
		rig:bone("Body", "Root", cf(0, 0.56, 0.3))
		rig:bone("Chest", "Body", cf(0, 0.58, -0.3))
		rig:bone("Head", "Chest", cf(0, 0.64, -1.45))
		rig:bone("Jaw", "Head", cf(0, 0.58, -1.62))
		rig:bone("Tongue", "Head", cf(0, 0.555, -1.95))
		rig:mirrored(function(side, sfx)
			local s = string.sub(sfx, 2)
			local f, b = LEGS.F.hip, LEGS.B.hip
			rig:bone("Leg_F" .. s, "Chest", cf(side * f.X, f.Y, f.Z))
			rig:bone("Leg_B" .. s, "Body", cf(side * b.X, b.Y, b.Z))
		end)
		local tailBones = rig:boneChain("Tail", "Body", TAIL)
	
	-- ===================================================================
		-- Tronc
		-- ===================================================================
		rig:prism("Chest", "Chest", cf(0, 0.57, -0.72), v3(0.9, 0.54, 0.9), 0.2, P.skin)
		rig:prism("Chest", "Neck", cf(0, 0.62, -1.32) * ang(rad(-6), 0, 0), v3(0.62, 0.44, 0.5), 0.15, P.skin)
		rig:prism("Chest", "Belly", cf(0, 0.3, -0.7), v3(0.6, 0.12, 0.95), 0.03, P.belly)
		rig:prism("Chest", "Throat", cf(0, 0.42, -1.3), v3(0.5, 0.14, 0.5), 0.05, P.belly)
	
	rig:prism("Body", "Midriff", cf(0, 0.56, 0.1), v3(1.1, 0.6, 0.85), 0.22, P.skin)
		rig:prism("Body", "Hips", cf(0, 0.55, 0.82), v3(0.86, 0.52, 0.7), 0.2, P.skin)
		rig:prism("Body", "Belly", cf(0, 0.29, 0.35), v3(0.66, 0.12, 1.5), 0.03, P.belly)
	
	-- Rangée centrale de plaques (bord libre relevé vers l'arrière) + dorures
		local i = 0
		for z = -1.35, 1.2, 0.28 do
			i += 1
			local bone = trunkBone(z)
			local w = if z < -1.1 then 0.32 elseif z < -0.3 then 0.38 elseif z > 0.5 then 0.32 else 0.42
			local y = backY(z) + 0.04
			rig:wedge(bone, "Plate", cf(0, y, z), v3(w, 0.12, 0.36), if i % 2 == 0 then P.plate else P.plateLight)
			if i % 2 == 1 then
				rig:ball(bone, "GoldRivet", v3(0, y + 0.07, z + 0.06), 0.075, P.gold)
			end
			if i % 3 == 0 then
				rig:block(bone, "GoldTrim", cf(0, y + 0.06, z + 0.16), v3(w * 0.85, 0.035, 0.04), P.gold)
			end
		end
	
	-- Rangées latérales, inclinées vers l'extérieur et décalées d'une demi-plaque
		rig:mirrored(function(side)
			for z = -1.21, 1.1, 0.28 do
				local x, y
				if z < -1.1 then
					x, y = 0.27, 0.78
				elseif z < -0.3 then
					x, y = 0.37, 0.76
				elseif z < 0.5 then
					x, y = 0.45, 0.77
				else
					x, y = 0.34, 0.72
				end
				rig:wedge(
					trunkBone(z),
					"SidePlate",
					cf(side * x, y, z) * ang(0, 0, -side * rad(40)),
					v3(0.28, 0.09, 0.3),
					if math.floor(z * 10) % 2 == 0 then P.plateDark else P.plate
				)
			end
		end)
	
	moss("Chest", v3(-0.26, 0.86, -0.62), 1.3, 0.4)
		moss("Body", v3(0.3, 0.87, 0.36), 1.45, 1.7)
		moss("Body", v3(-0.14, 0.83, 1.0), 1.05, 3.1)
	
	-- ===================================================================
		-- Tête
		-- ===================================================================
		rig:prism("Head", "Skull", cf(0, 0.72, -1.8), v3(0.76, 0.4, 0.62), 0.14, P.skin)
		rig:prism("Head", "Snout", cf(0, 0.66, -2.24), v3(0.52, 0.28, 0.4), 0.1, P.skin)
		rig:wedge("Head", "Bridge", cf(0, 0.86, -2.275), v3(0.36, 0.12, 0.33), P.skin)
		rig:prism("Head", "HeadPlate", cf(0, 0.93, -1.76), v3(0.42, 0.06, 0.5), 0.03, P.plateDark)
		rig:block("Head", "GoldGem", cf(0, 0.97, -1.92) * ang(0, rad(45), 0), v3(0.1, 0.04, 0.1), P.gold)
		rig:block("Head", "Mouth", cf(0, 0.545, -2.12), v3(0.48, 0.05, 0.55), P.mouth)
		moss("Head", v3(0.14, 0.94, -1.56), 0.75, 5.2)
	
	rig:mirrored(function(side, sfx)
			rig:wedge("Head", "Brow" .. sfx, cf(side * 0.29, 0.92, -1.84), v3(0.16, 0.1, 0.26), P.plateDark)
			-- Joues biseautées : la tête s'affine vers le museau (vue de dessus triangulaire)
			rig:wedgeTri("Head", "Jowl" .. sfx, v3(side * 0.26, 0.68, -2.1), v3(side, 0, 0), v3(0, 0, -1), 0.12, 0.3, 0.28, P.skin)
			rig:ball("Head", "EyeSocket" .. sfx, v3(side * 0.35, 0.8, -1.88), 0.2, P.skinDark)
			rig:ball("Head", "Eye" .. sfx, v3(side * 0.39, 0.8, -1.89), 0.17, P.eye)
			rig:block("Head", "Pupil" .. sfx, cf(side * 0.472, 0.8, -1.89), v3(0.02, 0.12, 0.04), P.pupil)
			rig:block("Head", "Nostril" .. sfx, cf(side * 0.12, 0.76, -2.44), v3(0.05, 0.03, 0.03), P.pupil)
			-- Barbe de mousse sous le menton
			rig:spike("Jaw", "MossBeard", cf(side * 0.08, 0.45, -2.2) * ang(math.pi, 0, side * rad(12)), 0.09, 0.14, 0.05, P.moss)
		end)
	
	rig:prism("Jaw", "Jaw", cf(0, 0.49, -2.03), v3(0.56, 0.1, 0.78), 0.04, P.belly)
	
	-- Langue fourchue (rentrée au repos, sortie par l'animateur)
		rig:strut("Tongue", "Tongue", v3(0, 0.555, -1.95), v3(0, 0.555, -2.32), 0.07, 0.03, P.tongue)
		rig:mirrored(function(side)
			rig:strut("Tongue", "TongueFork", v3(0, 0.555, -2.31), v3(side * 0.05, 0.555, -2.42), 0.04, 0.025, P.tongue)
		end)
	
	-- ===================================================================
		-- Pattes écartées
		-- ===================================================================
		rig:mirrored(function(side, sfx)
			local s = string.sub(sfx, 2)
			for key, L in LEGS do
				local bone = "Leg_" .. key .. s
				local function m(v: Vector3): Vector3
					return v3(side * v.X, v.Y, v.Z)
				end
				local hip, knee, ankle, foot = m(L.hip), m(L.knee), m(L.ankle), m(L.foot)
				rig:prismBetween(bone, "Upper", hip, knee, L.upper[1], L.upper[2], 0.07, P.skin)
				rig:ball(bone, "Joint", knee, L.joint, P.skin)
				rig:prismBetween(bone, "Lower", knee + v3(0, 0.02, 0), ankle, L.lower[1], L.lower[2], 0.06, P.skin)
				rig:prism(bone, "Foot", cf(foot), v3(0.25, 0.1, 0.24), 0.04, P.skinDark)
				rig:wedge(
					bone,
					"LegPlate",
					cf(hip:Lerp(knee, 0.55) + v3(0, L.upper[2] / 2, 0)) * ang(0, 0, -side * rad(10)),
					v3(0.24, 0.07, 0.22),
					P.plate
				)
				for _, toe in L.toes do
					local a = rad(toe[1])
					local dir = v3(side * math.sin(a), 0, -math.cos(a))
					local tip = foot + dir * toe[2] + v3(0, -0.02, 0)
					rig:strut(bone, "Toe", foot, tip, 0.05, 0.05, P.skinDark)
					rig:wedge(bone, "Claw", Kit.lookAlong(tip + dir * 0.04, dir), v3(0.045, 0.05, 0.08), P.claw)
				end
			end
		end)
	
	-- ===================================================================
		-- Queue annelée à plaques
		-- ===================================================================
		for n, bone in tailBones do
			local a, b, w = TAIL[n], TAIL[n + 1], TAIL_W[n]
			local dir = (b - a).Unit
			rig:prismBetween(bone, "Tail", a - dir * 0.05, b + dir * 0.05, w, w * 0.78, w * 0.28, if n % 2 == 0 then P.skinDark else P.skin)
			for _, t in { 0.3, 0.75 } do
				local p = a:Lerp(b, t) + v3(0, w * 0.39, 0)
				rig:wedge(bone, "TailPlate", Kit.lookAlong(p, -dir), v3(w * 0.55, 0.08, (b - a).Magnitude * 0.42), P.plate)
			end
		end
		moss(tailBones[1], TAIL[1]:Lerp(TAIL[2], 0.55) + v3(0.12, 0.28, 0), 0.95, 2.4)
	
	rig:hitbox(cf(0, 0.5, 0.6), v3(2.1, 1.1, 5.4))
	
	-- ===================================================================
		-- Effets
		-- ===================================================================
		if rig.effects then
			local sc = rig.scale
	
		local pollen = rig:anchor("Body", "FX_Pollen", cf(0, 0.98, 0), v3(0.9, 0.2, 2.2))
			Fx.particles(pollen, {
				name = "MossPollen",
				texture = Fx.TEXTURES.sparkle,
				colors = { rgb(196, 236, 96), rgb(244, 255, 170) },
				sizes = { 0.1, 0.14, 0 },
				transparencies = { 0.3, 0.2, 1 },
				lifetime = NumberRange.new(2, 3.5),
				rate = 3,
				speed = NumberRange.new(0.1, 0.3),
				spread = Vector2.new(40, 40),
				acceleration = v3(0, 0.12, 0),
				drag = 1,
				lightEmission = 0.6,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-40, 40),
				volume = true,
			}, sc)
	
		local glint = rig:anchor("Body", "FX_GoldGlint", cf(0, 0.95, -0.1), v3(0.2, 0.1, 2.4))
			Fx.particles(glint, {
				name = "GoldGlint",
				texture = Fx.TEXTURES.sparkle,
				colors = { rgb(255, 220, 120) },
				sizes = { 0.28, 0 },
				transparencies = { 0.1, 1 },
				lifetime = NumberRange.new(0.3, 0.5),
				rate = 1.2,
				lockedToPart = true,
				lightEmission = 1,
				rotation = NumberRange.new(0, 360),
				volume = true,
			}, sc)
	
		local dust = rig:anchor("Root", "FX_Dust", cf(0, 0.1, 0.6), v3(2.0, 0.2, 3.6))
			Fx.particles(dust, {
				name = "GroundDust",
				texture = Fx.TEXTURES.smoke,
				colors = { rgb(140, 126, 98), rgb(104, 96, 80) },
				sizes = { 0.18, 0.45 },
				transparencies = { 1, 0.75, 1 },
				lifetime = NumberRange.new(1.2, 2),
				rate = 2.5,
				speed = NumberRange.new(0.1, 0.35),
				spread = Vector2.new(70, 70),
				acceleration = v3(0, 0.1, 0),
				drag = 1,
				rotation = NumberRange.new(0, 360),
				volume = true,
			}, sc)
		end
	
	return rig:finish({ Rarity = "Common" })
	end
	
local LezardMousseux: Types.CreatureDef = {
		Id = ID,
		DisplayName = "Lézard Mousseux",
		Rarity = "Common",
		Category = "Créature Commune",
		Description = "Reptile rampant des sous-bois humides. La mousse pousse entre ses écailles et de petites dorures ornent son dos.",
		Icon = {
			top = rgb(92, 74, 40),
			bottom = rgb(24, 20, 14),
			glow = rgb(236, 214, 120),
			motif = rgb(170, 230, 90),
			yaw = 40,
			pitch = 24,
			zoom = 1.15,
		},
		Animation = {
			gait = "Sprawler",
			breathe = 0.015,
			sway = 10,
			stride = 30,
			strideRate = 9,
			tailSway = 12,
			tailRate = 1.4,
			headLook = 18,
			tongueFlick = true,
		},
		build = build,
	}
	
return LezardMousseux

end

-- ============================================================================
-- Entrée
-- ============================================================================
do
	local def = __require("LezardMousseux")
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
