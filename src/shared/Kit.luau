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
	detail: number?, -- densité des écailles/fourrures (1 = complète, 0.5 = moitié) — défaut : 1
	mutation: string?, -- une mutation (raccourci de `mutations`)
	mutations: { string }?, -- mutations cumulées (appliquées par CreatureForge.spawn / Icon.build)
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
	detail: number,
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

--- Éclaircit (k > 0, vers le blanc) ou assombrit (k < 0, vers le noir) une couleur.
function Kit.shade(c: Color3, k: number): Color3
	return if k >= 0 then c:Lerp(Color3.new(1, 1, 1), k) else c:Lerp(Color3.new(0, 0, 0), -k)
end

--- Dégradé de styles à partir d'une couleur : un style par valeur de `steps` (voir Kit.shade).
--- Ex. Kit.ramp(vert, M.SmoothPlastic, { 0.25, 0, -0.25 }) -> clair, base, sombre.
function Kit.ramp(base: Color3, material: Enum.Material?, steps: { number }): { Style }
	local out = {}
	for _, k in steps do
		table.insert(out, Kit.style(Kit.shade(base, k), material))
	end
	return out
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
-- Colonne vertébrale (spine) : courbe + rayons elliptiques, de l'avant vers l'arrière
-- ---------------------------------------------------------------------------

export type Section = { pos: Vector3, rx: number, ry: number }

export type SpineData = {
	sections: { Section },
	pts: { Vector3 },
	n: number,
	lutU: { number },
	lutS: { number },
	total: number,
}

local Spine = {}
Spine.__index = Spine

export type Spine = typeof(setmetatable({} :: SpineData, Spine))

--- Crée une colonne passant par les sections (listées de l'AVANT vers l'ARRIÈRE).
--- Le paramètre `u` va de 1 (première section) à #sections (dernière).
function Kit.spine(sections: { Section }): Spine
	local pts = {}
	for i, s in sections do
		pts[i] = s.pos
	end
	local n = #sections
	local lutU, lutS = {}, {}
	local samples = (n - 1) * 24
	local prev = pts[1]
	local acc = 0
	for k = 0, samples do
		local p = Kit.spline(pts, k / samples)
		acc += (p - prev).Magnitude
		prev = p
		lutU[k + 1] = 1 + (n - 1) * k / samples
		lutS[k + 1] = acc
	end
	local data: SpineData = { sections = sections, pts = pts, n = n, lutU = lutU, lutS = lutS, total = acc }
	return setmetatable(data, Spine)
end

function Spine.pos(self: Spine, u: number): Vector3
	return Kit.spline(self.pts, (u - 1) / (self.n - 1))
end

--- Rayons (horizontal, vertical) interpolés en douceur entre les sections.
function Spine.radii(self: Spine, u: number): (number, number)
	local f = math.clamp(u, 1, self.n)
	local i = math.min(math.floor(f), self.n - 1)
	local a, b = self.sections[i], self.sections[i + 1]
	local k = f - i
	k = k * k * (3 - 2 * k)
	return a.rx + (b.rx - a.rx) * k, a.ry + (b.ry - a.ry) * k
end

--- Repère local en `u` : -Z vers l'avant (u décroissant), +Y vers le haut, +X à droite.
function Spine.frame(self: Spine, u: number): CFrame
	local e = 0.02
	local a = self:pos(math.max(1, u - e))
	local b = self:pos(math.min(self.n, u + e))
	return Kit.lookAlong(self:pos(u), a - b)
end

--- Longueur de courbe depuis la première section jusqu'à `u`.
function Spine.lengthAt(self: Spine, u: number): number
	local f = (math.clamp(u, 1, self.n) - 1) / (self.n - 1) * (#self.lutU - 1) + 1
	local i = math.min(math.floor(f), #self.lutU - 1)
	return self.lutS[i] + (self.lutS[i + 1] - self.lutS[i]) * (f - i)
end

--- Paramètre `u` correspondant à la longueur de courbe `s`.
function Spine.uAt(self: Spine, s: number): number
	local lutS = self.lutS
	if s <= 0 then
		return 1
	elseif s >= self.total then
		return self.n
	end
	local lo, hi = 1, #lutS
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if lutS[mid] < s then
			lo = mid
		else
			hi = mid
		end
	end
	local k = (s - lutS[lo]) / math.max(lutS[hi] - lutS[lo], 1e-6)
	return self.lutU[lo] + (self.lutU[hi] - self.lutU[lo]) * k
end

--- Repère posé à la surface du tube : `deg` = angle autour de l'axe (0 = dessus, 90 = droite),
--- +Y = normale sortante, +Z = vers l'arrière de la colonne. `lift` décolle le repère de la surface.
function Spine.surface(self: Spine, u: number, deg: number, lift: number?): CFrame
	local rx, ry = self:radii(u)
	local th = math.rad(deg)
	local p = Vector3.new(rx * math.sin(th), ry * math.cos(th), 0)
	local n = Vector3.new(math.sin(th) / rx, math.cos(th) / ry, 0).Unit
	return self:frame(u) * CFrame.fromMatrix(p + n * (lift or 0), n:Cross(Vector3.zAxis), n, Vector3.zAxis)
end

Kit.Spine = Spine

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
		detail = math.clamp(o.detail or 1, 0.2, 1),
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
--- `chamfer` = chanfrein horizontal, `chamferY` = chanfrein vertical (défaut : identique).
function Rig.prism(
	self: Rig,
	bone: string,
	name: string,
	cf: CFrame,
	size: Vector3,
	chamfer: number,
	style: Style,
	chamferY: number?
): { BasePart }
	local cx = math.min(chamfer, size.X / 2 - 0.005)
	local cy = math.min(chamferY or chamfer, size.Y / 2 - 0.005)
	if cx <= 0.01 or cy <= 0.01 then
		return { self:block(bone, name, cf, size, style) }
	end
	local hx, hy, L = size.X / 2, size.Y / 2, size.Z
	local parts = {
		self:block(bone, name, cf, Vector3.new(size.X - 2 * cx, size.Y, L), style),
		self:block(bone, name .. "_S", cf * CFrame.new(hx - cx / 2, 0, 0), Vector3.new(cx, size.Y - 2 * cy, L), style),
		self:block(bone, name .. "_S", cf * CFrame.new(-(hx - cx / 2), 0, 0), Vector3.new(cx, size.Y - 2 * cy, L), style),
	}
	for _, sgn in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		local sx, sy = sgn[1], sgn[2]
		local corner = (cf * CFrame.new(sx * (hx - cx), sy * (hy - cy), 0)).Position
		table.insert(
			parts,
			self:wedgeTri(bone, name .. "_C", corner, cf.RightVector * sx, cf.UpVector * sy, cx, cy, L, style)
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
	roll: number?,
	chamferY: number?
): { BasePart }
	local cf = Kit.lookAlong((a + b) / 2, b - a) * CFrame.Angles(0, 0, roll or 0)
	return self:prism(bone, name, cf, Vector3.new(w, h, (b - a).Magnitude), chamfer, style, chamferY)
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

-- ---------------------------------------------------------------------------
-- Tubes organiques : noyau facetté + revêtement d'écailles / de fourrure
-- ---------------------------------------------------------------------------

--- Revêtement de surface d'un tube.
export type Cover = {
	kind: ("Scale" | "Tuft")?, -- Scale : écailles plates imbriquées ; Tuft : mèches de fourrure en pointe
	size: Vector3, -- (largeur, hauteur, longueur) d'un élément pour un rayon de `refRadius`
	spacing: number, -- distance entre deux rangées (pour un rayon de `refRadius`)
	arc: number?, -- demi-angle couvert autour de `center` (degrés, défaut 115)
	center: number?, -- centre de la zone couverte (degrés : 0 = dessus, 90 = droite, 180 = dessous)
	from: number?, -- portion de la colonne couverte (u)
	to: number?,
	shades: { Style }, -- du centre de la zone (clair) vers ses bords (sombre)
	tip: Style?, -- pointe colorée sur chaque élément
	tilt: number?, -- élément couché vers l'arrière (degrés)
	refRadius: number?, -- les éléments rétrécissent là où le tube s'affine
	jitter: number?, -- variations aléatoires (0 à 1)
	seed: number?,
}

export type TubeSpec = {
	name: string,
	bone: (u: number) -> string, -- os de chaque portion du tube
	core: Style?, -- noyau facetté (nil = pas de noyau)
	coreStep: number?, -- longueur des segments du noyau
	from: number?,
	to: number?,
	cover: { Cover }?,
}

local ARC_STEPS = 24

--- Construit un tube le long de `spine` : noyau en prismes octogonaux + revêtements.
function Rig.tube(self: Rig, spine: Spine, spec: TubeSpec)
	local u0, u1 = spec.from or 1, spec.to or spine.n
	local s0, s1 = spine:lengthAt(u0), spine:lengthAt(u1)

	if spec.core then
		local step = spec.coreStep or 0.3
		local segs = math.max(1, math.ceil((s1 - s0) / step))
		for i = 0, segs - 1 do
			local ua = spine:uAt(s0 + (s1 - s0) * i / segs)
			local ub = spine:uAt(s0 + (s1 - s0) * (i + 1) / segs)
			local um = (ua + ub) / 2
			local a, b = spine:pos(ua), spine:pos(ub)
			local rx, ry = spine:radii(um)
			local d = (b - a).Unit
			local ov = math.min(rx, ry) * 0.3
			-- Octogone inscrit dans l'ellipse : les revêtements restent visibles même sur un tube aplati
			self:prismBetween(spec.bone(um), spec.name, a - d * ov, b + d * ov, 1.9 * rx, 1.9 * ry, 0.64 * rx, spec.core, nil, 0.64 * ry)
		end
	end

	for ci, cv in spec.cover or {} do
		local rng = Random.new(cv.seed or (ci * 97))
		local arc = math.rad(cv.arc or 115)
		local center = math.rad(cv.center or 0)
		local refR = cv.refRadius or 0.5
		local jitter = cv.jitter or 0.35
		local tilt = math.rad(cv.tilt or (if cv.kind == "Tuft" then 38 else 18))
		local sEnd = spine:lengthAt(cv.to or u1)
		local s = spine:lengthAt(cv.from or u0)
		local row = 0
		while s <= sEnd + 1e-6 do
			local u = spine:uAt(s)
			local rx, ry = spine:radii(u)
			local k = math.clamp(math.min(rx, ry) / refR, 0.45, 1.4)
			local dk = 1 / math.sqrt(self.detail)
			local size = cv.size * k * Vector3.new(dk, 1, dk)
			local fr = spine:frame(u)

			-- Longueur de l'arc d'ellipse couvert (table cumulée pour un espacement régulier)
			local function at(th: number): Vector2
				return Vector2.new(rx * math.sin(th), ry * math.cos(th))
			end
			local lens = { 0 }
			local prev = at(center - arc)
			for j = 1, ARC_STEPS do
				local p = at(center - arc + 2 * arc * j / ARC_STEPS)
				lens[j + 1] = lens[j] + (p - prev).Magnitude
				prev = p
			end
			local total = lens[ARC_STEPS + 1]
			local count = math.max(1, math.floor(total / (size.X * 0.9) + 0.5))

			for e = 0, count - 1 do
				local target = (e + (if row % 2 == 1 then 0.75 else 0.25)) / count * total
				local j = 1
				while j < ARC_STEPS and lens[j + 1] < target do
					j += 1
				end
				local f = (target - lens[j]) / math.max(lens[j + 1] - lens[j], 1e-6)
				local th = center - arc + 2 * arc * (j - 1 + f) / ARC_STEPS

				local p = Vector3.new(rx * math.sin(th), ry * math.cos(th), 0)
				local nrm = Vector3.new(math.sin(th) / rx, math.cos(th) / ry, 0).Unit
				local back = Vector3.zAxis
				local sz = size * (1 + (rng:NextNumber() - 0.5) * 0.3 * jitter)
				local local0 = CFrame.fromMatrix(p + nrm * (sz.Y * 0.18), nrm:Cross(back), nrm, back)
					* CFrame.Angles(0, (rng:NextNumber() - 0.5) * 0.5 * jitter, 0)
					* CFrame.Angles(tilt + (rng:NextNumber() - 0.5) * 0.4 * jitter, 0, 0)
				local cf = fr * local0

				-- Teinte : clair au centre de la zone, sombre sur les bords (+ un peu de hasard)
				local dist = math.abs(th - center) / arc
				local idx = math.floor(dist * #cv.shades) + 1
				if rng:NextNumber() < 0.18 * jitter then
					idx += if rng:NextNumber() < 0.5 then -1 else 1
				end
				local style = cv.shades[math.clamp(idx, 1, #cv.shades)]

				local bone = spec.bone(u)
				self:wedge(bone, spec.name .. (cv.kind or "Scale"), cf, sz, style)
				if cv.tip then
					self:wedge(
						bone,
						spec.name .. "Tip",
						cf * CFrame.new(0, sz.Y * 0.3, sz.Z * 0.22),
						Vector3.new(sz.X * 0.62, sz.Y * 0.45, sz.Z * 0.5),
						cv.tip
					)
				end
			end
			row += 1
			s += cv.spacing * k * dk
		end
	end
end

--- Ceinture autour du tube en `u` (bande polygonale épousant l'ellipse) + rivets sur le dessus.
function Rig.band(
	self: Rig,
	spine: Spine,
	bone: string,
	name: string,
	u: number,
	width: number,
	thickness: number,
	style: Style,
	rivet: Style?
)
	local fr = spine:frame(u)
	local rx, ry = spine:radii(u)
	rx += thickness * 0.35
	ry += thickness * 0.35
	local m = 16
	for j = 0, m - 1 do
		local a1, a2 = j / m * math.pi * 2, (j + 1) / m * math.pi * 2
		local q1 = Vector3.new(rx * math.sin(a1), ry * math.cos(a1), 0)
		local q2 = Vector3.new(rx * math.sin(a2), ry * math.cos(a2), 0)
		local tan = (q2 - q1).Unit
		local out = Vector3.zAxis:Cross(tan)
		local cf = fr * CFrame.fromMatrix((q1 + q2) / 2, tan, out, Vector3.zAxis)
		self:block(bone, name, cf, Vector3.new((q2 - q1).Magnitude + thickness * 0.6, thickness, width), style)
		if rivet and j % 2 == 0 and math.cos((a1 + a2) / 2) > -0.2 then
			local mid = (q1 + q2) / 2
			self:ball(bone, name .. "Rivet", (fr * CFrame.new(mid + out * thickness * 0.5)).Position, width * 0.42, rivet)
		end
	end
end

--- Pièce invisible (support de particules/lumières ou hitbox).
function Rig.anchor(self: Rig, bone: string, name: string, cf: CFrame, size: Vector3): BasePart
	local p = self:part(bone, name, "Block", cf, size, { color = Color3.new(1, 1, 1), transparency = 1, castShadow = false })
	self.partCount -= 1
	return p
end

--- Siège (Seat) pour monter sur la créature : un joueur qui s'assoit est porté par la monture.
function Rig.seat(self: Rig, bone: string, cf: CFrame, size: Vector3): Seat
	local b = self.bones[bone]
	local seat = Instance.new("Seat")
	seat.Name = "Saddle"
	seat.Size = size * self.scale
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanTouch = true
	seat.Massless = true
	seat.Anchored = false
	seat.CFrame = self:toWorld(cf)
	local w = Instance.new("Weld")
	w.Part0 = b
	w.Part1 = seat
	w.C0 = b.CFrame:ToObjectSpace(seat.CFrame)
	w.Parent = seat
	seat.Parent = self.model
	return seat
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
