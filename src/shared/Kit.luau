--!strict
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

export type Style = {
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	castShadow: boolean?,
}

export type BuildOptions = {
	scale: number?, -- facteur d'échelle global (1 = taille de référence)
	cframe: CFrame?, -- position/orientation du pivot (au sol)
	parent: Instance?, -- parent final du modèle (nil = non parenté)
	outline: boolean?, -- contour cartoon (Highlight) — défaut : true
	effects: boolean?, -- particules + lumières — défaut : true
	animated: boolean?, -- tag "CreatureForge" pour l'animateur client — défaut : true
}

export type PartKind = "Block" | "Wedge" | "Ball" | "Cylinder"

export type RigData = {
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

export type Rig = typeof(setmetatable({} :: RigData, Rig))

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
