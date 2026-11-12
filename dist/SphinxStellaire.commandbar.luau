-- CreatureForge — SphinxStellaire
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
		detail: number?, -- densité des écailles/fourrures (1 = complète, 0.5 = moitié) — défaut : 1
		mutation: string?, -- une mutation (raccourci de `mutations`)
		mutations: { string }?, -- mutations cumulées (appliquées par CreatureForge.spawn / Icon.build)
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
		detail: number,
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
	
type Section = { pos: Vector3, rx: number, ry: number }
	
type SpineData = {
		sections: { Section },
		pts: { Vector3 },
		n: number,
		lutU: { number },
		lutS: { number },
		total: number,
	}
	
local Spine = {}
	Spine.__index = Spine
	
type Spine = typeof(setmetatable({} :: SpineData, Spine))
	
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
	type Cover = {
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
	
type TubeSpec = {
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

end

__modules["Rarity"] = function()
	--[[
		CreatureForge.Rarity
		--------------------
		Les 8 raretés du jeu, du plus courant au plus rare : couleurs (UI, aura), position sur le
		tapis roulant et chance d'apparition.
	
	Le tapis va de 0 (bases, début du tapis) à 1 (tout au bout). Une rareté « normale »
		apparaît à partir de band[1], surtout autour de `peak` (poids `weight`, courbe en cloche) ;
		les raretés ultimes (Exotique, Exclusif, Chaotique) sont tirées à part, en bout de tapis,
		avec une chance de 1 sur `odds`.
		Les valeurs sont un point de départ à ajuster pendant les tests (voir Spawning).
	]]
	
type Tier = {
		id: string,
		label: string,
		order: number,
		color: Color3, -- couleur principale (contour, pastille)
		light: Color3, -- reflet clair du dégradé
		dark: Color3, -- ombre du dégradé
		where: string, -- où elle apparaît (texte affiché)
		band: { number }, -- { début, fin } sur le tapis (0 = début, 1 = tout au bout)
		peak: number?, -- distance où la rareté est la plus fréquente (raretés normales)
		weight: number?, -- poids du tirage au pic (raretés normales)
		odds: number?, -- 1 chance sur `odds` (raretés ultimes, en bout de tapis)
		rainbow: boolean?, -- couleur arc-en-ciel animée (Exotique)
		glitch: boolean?, -- couleurs qui changent / glitch (Chaotique)
		gold: Color3?, -- seconde couleur (Exclusif : noir et or)
	}
	
local rgb = Color3.fromRGB
	
local Rarity = {}
	
Rarity.Order = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Exotic", "Exclusive", "Chaotic" }
	
Rarity.Tiers = {
		Common = {
			id = "Common", label = "COMMUN", order = 1, where = "Début du tapis",
			color = rgb(170, 176, 188), light = rgb(236, 240, 246), dark = rgb(96, 102, 114),
			band = { 0, 1 }, peak = 0.05, weight = 1,
		},
		Rare = {
			id = "Rare", label = "RARE", order = 2, where = "Un peu plus loin",
			color = rgb(54, 140, 255), light = rgb(170, 216, 255), dark = rgb(20, 60, 170),
			band = { 0.15, 1 }, peak = 0.3, weight = 0.8,
		},
		Epic = {
			id = "Epic", label = "ÉPIQUE", order = 3, where = "Milieu du tapis",
			color = rgb(168, 80, 255), light = rgb(230, 180, 255), dark = rgb(80, 26, 160),
			band = { 0.35, 1 }, peak = 0.5, weight = 0.6,
		},
		Legendary = {
			id = "Legendary", label = "LÉGENDAIRE", order = 4, where = "Loin",
			color = rgb(255, 190, 40), light = rgb(255, 240, 160), dark = rgb(196, 100, 10),
			band = { 0.55, 1 }, peak = 0.7, weight = 0.45,
		},
		Mythic = {
			id = "Mythic", label = "MYTHIQUE", order = 5, where = "Très loin",
			color = rgb(255, 40, 60), light = rgb(255, 170, 180), dark = rgb(140, 0, 20),
			band = { 0.75, 1 }, peak = 0.92, weight = 0.3,
		},
		Exotic = {
			id = "Exotic", label = "EXOTIQUE", order = 6, where = "Tout au bout",
			color = rgb(255, 120, 200), light = rgb(255, 255, 200), dark = rgb(80, 60, 200),
			band = { 0.9, 1 }, odds = 5000, rainbow = true,
		},
		Exclusive = {
			id = "Exclusive", label = "EXCLUSIF", order = 7, where = "Tout au bout + roue",
			color = rgb(255, 200, 60), light = rgb(255, 236, 150), dark = rgb(10, 8, 12), gold = rgb(255, 200, 60),
			band = { 0.9, 1 }, odds = 50000,
		},
		Chaotic = {
			id = "Chaotic", label = "CHAOTIQUE", order = 8, where = "Tout au bout",
			color = rgb(255, 0, 90), light = rgb(0, 255, 230), dark = rgb(20, 0, 40),
			band = { 0.9, 1 }, odds = 1000000, glitch = true,
		},
	} :: { [string]: Tier }
	
--- Couleurs arc-en-ciel (Exotique) et glitch (Chaotique) pour l'UI et les auras.
	Rarity.RAINBOW = { rgb(255, 70, 70), rgb(255, 170, 40), rgb(255, 240, 70), rgb(70, 230, 110), rgb(60, 170, 255), rgb(170, 90, 255) }
	Rarity.GLITCH = { rgb(255, 0, 90), rgb(0, 255, 230), rgb(255, 255, 255), rgb(120, 0, 255), rgb(0, 0, 0), rgb(255, 230, 0) }
	
function Rarity.get(id: string): Tier
		return Rarity.Tiers[id] or Rarity.Tiers.Common
	end
	
--- Couleur affichée à l'instant `t` (secondes) : animée pour Exotique (arc-en-ciel) et
	--- Chaotique (glitch : saute d'une couleur à l'autre).
	function Rarity.colorAt(id: string, t: number): Color3
		local tier = Rarity.get(id)
		if tier.rainbow then
			return Color3.fromHSV((t * 0.25) % 1, 0.75, 1)
		elseif tier.glitch then
			local list = Rarity.GLITCH
			local k = math.floor(t * 12)
			if (k * 7919) % 5 == 0 then
				return list[(k % #list) + 1]
			end
			return list[(math.floor(t * 3) % 2) + 1]
		end
		return tier.color
	end
	
--- Tailles de créature (plus c'est gros, plus ça rapporte). `span` = plus grande dimension
	--- visée en jeu (studs) ; chaque créature règle son `Scale` pour s'en approcher.
	Rarity.Sizes = {
		Small = { id = "Small", label = "Petit", order = 1, span = 6 },
		Medium = { id = "Medium", label = "Moyen", order = 2, span = 8.5 },
		Large = { id = "Large", label = "Grand", order = 3, span = 11 },
		Giant = { id = "Giant", label = "Géant", order = 4, span = 15 },
		Colossal = { id = "Colossal", label = "Colossal", order = 5, span = 21 },
	}
	
return Rarity

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
	
-- Préréglages ---------------------------------------------------------------
	
function Fx.sparkles(name: string, colors: { Color3 }, rate: number, size: number, rise: number?): ParticleDef
		return {
			name = name,
			texture = Fx.TEXTURES.sparkle,
			colors = colors,
			sizes = { size, size * 0.6, 0 },
			transparencies = { 0.1, 0.2, 1 },
			lifetime = NumberRange.new(1, 2),
			rate = rate,
			speed = NumberRange.new(0.1, 0.4),
			spread = Vector2.new(180, 180),
			acceleration = Vector3.new(0, rise or 0.3, 0),
			drag = 1,
			lightEmission = 1,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-60, 60),
			volume = true,
		}
	end
	
function Fx.embers(name: string, colors: { Color3 }, rate: number, size: number): ParticleDef
		return {
			name = name,
			texture = Fx.TEXTURES.spark,
			colors = colors,
			sizes = { size, size * 0.5, 0 },
			lifetime = NumberRange.new(0.8, 1.6),
			rate = rate,
			speed = NumberRange.new(0.5, 1.5),
			spread = Vector2.new(30, 30),
			acceleration = Vector3.new(0, 1.2, 0),
			lightEmission = 1,
			rotation = NumberRange.new(0, 360),
			volume = true,
		}
	end
	
function Fx.mist(name: string, colors: { Color3 }, rate: number, size: number, lightEmission: number?): ParticleDef
		return {
			name = name,
			texture = Fx.TEXTURES.smoke,
			colors = colors,
			sizes = { size * 0.5, size },
			transparencies = { 1, 0.55, 1 },
			lifetime = NumberRange.new(1.5, 3),
			rate = rate,
			speed = NumberRange.new(0.1, 0.4),
			spread = Vector2.new(180, 180),
			acceleration = Vector3.new(0, 0.1, 0),
			drag = 1,
			lightEmission = lightEmission or 0,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-20, 20),
			volume = true,
		}
	end
	
function Fx.fire(name: string, colors: { Color3 }, rate: number, size: number): ParticleDef
		return {
			name = name,
			texture = Fx.TEXTURES.fire,
			colors = colors,
			sizes = { size, size * 0.7, 0 },
			transparencies = { 0.2, 0.4, 1 },
			lifetime = NumberRange.new(0.5, 1),
			rate = rate,
			speed = NumberRange.new(0.6, 1.4),
			spread = Vector2.new(15, 15),
			acceleration = Vector3.new(0, 1.5, 0),
			lightEmission = 1,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-60, 60),
			volume = true,
		}
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

__modules["Mutations"] = function()
	--[[
		CreatureForge.Mutations
		-----------------------
		Les 11 mutations du jeu, applicables à N'IMPORTE QUELLE créature et CUMULABLES.
		Chacune se voit sur le modèle : recoloration (la mutation la plus rare impose ses couleurs),
		pièces ajoutées (fleurs, fissures d'or, engrenages, squelette, étoiles...), effets.
	
	Revenu = base × (multi1 + multi2 + ...)       (base × 1 sans mutation)
		    ex. Griffon impérial 10 000 $/s + Vitrail (x2) + Kintsugi (x1,5) = 35 000 $/s
	
	    CreatureForge.spawn("GriffonImperial", cf, { mutations = { "Vitrail", "Kintsugi" } })
		    Mutations.apply(model, { "Encre" })          -- sur un modèle déjà construit
		    Mutations.roll(rng)                          -- tirage indépendant de chaque mutation
		    Mutations.multiplier({ "Vitrail", "Kintsugi" }) --> 3.5
	
	Côté client, Mutations.runtime(model) anime ce qui doit bouger (engrenages, ondulation du
		mirage, reflets d'aurore, copie fantôme de l'écho, changement d'apparence du paradoxe) ;
		CreatureAnimator l'appelle automatiquement.
	]]
	
local Fx = __require("Fx")
	
local rgb = Color3.fromRGB
	local Mat = Enum.Material
	
type Mutation = {
		id: string,
		label: string,
		effect: string, -- effet visible sur le modèle
		odds: number, -- 1 chance sur `odds`
		multiplier: number,
		glow: Color3, -- lumière + couleur d'accent
		badge: { Color3 }, -- dégradé de la pastille d'icône
		recolor: boolean, -- impose ses couleurs au modèle
		particle: Fx.ParticleDef?,
	}
	
local function sparkle(name: string, colors: { Color3 }, rate: number, size: number, rise: number?): Fx.ParticleDef
		return {
			name = name,
			texture = Fx.TEXTURES.sparkle,
			colors = colors,
			sizes = { size, size * 0.6, 0 },
			transparencies = { 0.1, 0.2, 1 },
			lifetime = NumberRange.new(0.8, 1.6),
			rate = rate,
			speed = NumberRange.new(0.2, 0.6),
			spread = Vector2.new(180, 180),
			acceleration = Vector3.new(0, rise or 0.4, 0),
			drag = 1,
			lightEmission = 1,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-90, 90),
			volume = true,
		}
	end
	
local function haze(name: string, colors: { Color3 }, rate: number, size: number, transparency: number, rise: number, light: number?): Fx.ParticleDef
		return {
			name = name,
			texture = Fx.TEXTURES.smoke,
			colors = colors,
			sizes = { size * 0.6, size, size * 1.3 },
			transparencies = { 1, transparency, 1 },
			lifetime = NumberRange.new(1.2, 2.2),
			rate = rate,
			speed = NumberRange.new(0.1, 0.4),
			spread = Vector2.new(180, 180),
			acceleration = Vector3.new(0, rise, 0),
			drag = 1,
			lightEmission = light or 0,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-30, 30),
			volume = true,
		}
	end
	
local Mutations = {}
	
Mutations.List = {
		{
			id = "Mousse", label = "MOUSSE ANCIENNE", odds = 8, multiplier = 1.3, recolor = true,
			effect = "Couvert de mousse et de petites fleurs, comme une statue oubliée",
			glow = rgb(170, 230, 120), badge = { rgb(190, 230, 140), rgb(70, 120, 50) },
			particle = sparkle("Pollen", { rgb(230, 255, 160), rgb(255, 200, 230) }, 4, 0.18, -0.2),
		},
		{
			id = "Kintsugi", label = "KINTSUGI", odds = 15, multiplier = 1.5, recolor = true,
			effect = "Fissures remplies d'or, comme une porcelaine réparée",
			glow = rgb(255, 205, 80), badge = { rgb(250, 250, 255), rgb(255, 200, 60) },
			particle = sparkle("GoldDust", { rgb(255, 230, 130), rgb(255, 190, 50) }, 5, 0.22),
		},
		{
			id = "Vitrail", label = "VITRAIL", odds = 40, multiplier = 2, recolor = true,
			effect = "Corps en verre coloré, la lumière passe à travers",
			glow = rgb(255, 240, 200), badge = { rgb(230, 40, 60), rgb(255, 190, 40), rgb(40, 180, 90), rgb(40, 100, 230) },
			particle = sparkle("Motes", { rgb(255, 80, 90), rgb(80, 140, 255), rgb(255, 210, 80) }, 8, 0.25),
		},
		{
			id = "Horloger", label = "HORLOGER", odds = 80, multiplier = 2.5, recolor = true,
			effect = "Engrenages visibles qui tournent sous la peau",
			glow = rgb(255, 180, 70), badge = { rgb(255, 214, 140), rgb(150, 90, 30) },
			particle = sparkle("Sparks", { rgb(255, 210, 120), rgb(255, 150, 40) }, 4, 0.16, -1),
		},
		{
			id = "Mirage", label = "MIRAGE", odds = 150, multiplier = 3, recolor = true,
			effect = "Corps qui ondule comme la chaleur du désert, ombre décalée",
			glow = rgb(255, 200, 140), badge = { rgb(255, 230, 180), rgb(230, 110, 60) },
			particle = haze("HeatHaze", { rgb(255, 210, 160), rgb(255, 160, 100) }, 6, 1.6, 0.85, 0.8),
		},
		{
			id = "Encre", label = "ENCRE", odds = 300, multiplier = 3.5, recolor = true,
			effect = "Dessiné à l'encre noire, laisse des traînées en courant",
			glow = rgb(240, 236, 224), badge = { rgb(250, 246, 234), rgb(20, 20, 26) },
			particle = haze("InkDrops", { rgb(12, 12, 18), rgb(40, 40, 50) }, 5, 0.5, 0.35, -2),
		},
		{
			id = "Aurore", label = "AURORE", odds = 600, multiplier = 4, recolor = true,
			effect = "Reflets d'aurore boréale qui bougent sur le corps",
			glow = rgb(120, 255, 200), badge = { rgb(80, 255, 170), rgb(60, 200, 255), rgb(190, 90, 255) },
			particle = sparkle("AuroraMotes", { rgb(120, 255, 200), rgb(170, 120, 255) }, 8, 0.26),
		},
		{
			id = "Fossile", label = "FOSSILE VIVANT", odds = 1500, multiplier = 5, recolor = true,
			effect = "Squelette visible à travers un corps d'ambre",
			glow = rgb(255, 180, 60), badge = { rgb(255, 210, 120), rgb(170, 80, 10) },
			particle = sparkle("AmberDust", { rgb(255, 200, 100), rgb(255, 150, 40) }, 5, 0.2),
		},
		{
			id = "Constellation", label = "CONSTELLATION", odds = 5000, multiplier = 7, recolor = true,
			effect = "Corps noir rempli d'étoiles reliées entre elles",
			glow = rgb(190, 210, 255), badge = { rgb(40, 40, 90), rgb(6, 6, 18) },
			particle = sparkle("Stardust", { rgb(255, 255, 255), rgb(170, 200, 255) }, 10, 0.2, 0.1),
		},
		{
			id = "Echo", label = "ÉCHO", odds = 20000, multiplier = 10, recolor = false,
			effect = "Une copie fantôme le suit avec une seconde de retard",
			glow = rgb(120, 230, 255), badge = { rgb(200, 250, 255), rgb(60, 150, 230) },
			particle = haze("EchoRipple", { rgb(140, 230, 255), rgb(80, 160, 255) }, 5, 1.2, 0.8, 0, 1),
		},
		{
			id = "Paradoxe", label = "PARADOXE", odds = 100000, multiplier = 15, recolor = true,
			effect = "Change d'apparence de mutation toutes les 3 secondes",
			glow = rgb(255, 60, 200), badge = { rgb(255, 0, 140), rgb(0, 240, 255), rgb(255, 255, 255) },
			particle = sparkle("Glitch", { rgb(255, 0, 140), rgb(0, 255, 230), rgb(255, 255, 255) }, 12, 0.3),
		},
	} :: { Mutation }
	
local byId: { [string]: Mutation } = {}
	local rank: { [string]: number } = {}
	for i, m in Mutations.List do
		byId[m.id] = m
		rank[m.id] = i
	end
	
function Mutations.get(id: string): Mutation?
		return byId[id]
	end
	
--- Normalise "Vitrail", { "Vitrail", "Kintsugi" } ou "Vitrail,Kintsugi" en liste triée (rareté croissante).
	function Mutations.normalize(ids: (string | { string })?): { string }
		local list: { string } = {}
		if type(ids) == "string" then
			for id in string.gmatch(ids, "[^,%s]+") do
				table.insert(list, id)
			end
		elseif type(ids) == "table" then
			list = table.clone(ids)
		end
		local seen, out = {}, {}
		for _, id in list do
			if byId[id] and not seen[id] then
				seen[id] = true
				table.insert(out, id)
			end
		end
		table.sort(out, function(a, b)
			return rank[a] < rank[b]
		end)
		return out
	end
	
--- Somme des multiplicateurs (1 sans mutation).
	function Mutations.multiplier(ids: (string | { string })?): number
		local list = Mutations.normalize(ids)
		if #list == 0 then
			return 1
		end
		local sum = 0
		for _, id in list do
			sum += byId[id].multiplier
		end
		return sum
	end
	
--- Tirage : chaque mutation est tirée indépendamment (1 sur `odds`). Renvoie la liste (souvent vide).
	function Mutations.roll(rng: Random?, luck: number?): { string }
		local r = rng or Random.new()
		local out = {}
		for _, m in Mutations.List do
			if r:NextNumber() < (luck or 1) / m.odds then
				table.insert(out, m.id)
			end
		end
		return out
	end
	
--- Mutation qui impose ses couleurs : la plus rare de la liste.
	function Mutations.dominant(ids: (string | { string })?): Mutation?
		local list = Mutations.normalize(ids)
		for i = #list, 1, -1 do
			local m = byId[list[i]]
			if m.recolor then
				return m
			end
		end
		return if #list > 0 then byId[list[#list]] else nil
	end
	
-- ---------------------------------------------------------------------------
	-- Peinture : nouvelle couleur d'une pièce selon sa luminosité d'origine (lum) et sa place
	-- dans le corps (ctx). Fonctions pures : réutilisées par le Paradoxe côté client.
	-- ---------------------------------------------------------------------------
	
type PaintCtx = {
		along: number, -- 0 = avant, 1 = arrière
		height: number, -- 0 = bas, 1 = haut
		h: number, -- hasard stable par pièce (0..1)
		cell: number, -- cellule de vitrail (1..6)
	}
	
local function ramp(list: { Color3 }, x: number): Color3
		local f = math.clamp(x, 0, 1) * (#list - 1)
		local i = math.min(math.floor(f) + 1, #list - 1)
		return list[i]:Lerp(list[i + 1], f - (i - 1))
	end
	
local STONE = { rgb(70, 72, 68), rgb(116, 118, 110), rgb(160, 160, 150), rgb(200, 198, 186) }
	local MOSS = { rgb(40, 80, 30), rgb(72, 118, 44), rgb(112, 154, 60), rgb(160, 192, 90) }
	local PORCELAIN = { rgb(26, 50, 130), rgb(104, 136, 200), rgb(230, 234, 244), rgb(252, 252, 255) }
	local GLASS = { rgb(220, 30, 50), rgb(30, 90, 230), rgb(30, 170, 80), rgb(255, 180, 30), rgb(150, 50, 210), rgb(30, 200, 210) }
	local BRASS = { rgb(70, 44, 18), rgb(150, 100, 44), rgb(214, 162, 80), rgb(250, 220, 150) }
	local HEAT = { rgb(150, 60, 50), rgb(230, 120, 70), rgb(255, 190, 120), rgb(255, 236, 200) }
	local AMBER = { rgb(110, 40, 8), rgb(200, 100, 20), rgb(250, 160, 40), rgb(255, 214, 130) }
	local NIGHT = { rgb(4, 4, 12), rgb(10, 10, 28), rgb(20, 20, 54), rgb(40, 40, 92) }
	local INK, PAPER, PAPER_SHADE = rgb(16, 16, 22), rgb(246, 242, 230), rgb(212, 206, 192)
	
local function lumOf(c: Color3): number
		return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	end
	Mutations.lum = lumOf
	
--- Teinte d'aurore (verts -> cyans -> violets) qui défile le long du corps.
	function Mutations.auroraHue(ctx: PaintCtx, t: number): number
		return 0.3 + 0.5 * (0.5 + 0.5 * math.sin((ctx.along * 1.6 + ctx.height * 1.1) * math.pi * 2 - t * 1.3))
	end
	
type Paint = (lum: number, neon: boolean, ctx: PaintCtx, t: number) -> (Color3, Enum.Material?, number?)
	
Mutations.PAINT = {
		Mousse = function(l, neon, c)
			if neon then
				return rgb(190, 255, 150), nil, nil
			end
			if (c.height > 0.48 and c.h < 0.62) or c.h < 0.14 then
				return ramp(MOSS, l ^ 0.8), Mat.Grass, 0
			end
			return ramp(STONE, l ^ 0.8), Mat.Slate, 0
		end,
		Kintsugi = function(l, neon)
			if neon then
				return rgb(255, 205, 80), nil, nil
			end
			return ramp(PORCELAIN, l ^ 0.7), Mat.SmoothPlastic, 0
		end,
		Vitrail = function(l, neon, c)
			if neon then
				return rgb(255, 250, 230), nil, nil
			end
			return GLASS[c.cell]:Lerp(Color3.new(0, 0, 0), 0.4 * (1 - l)), Mat.Glass, 0.25
		end,
		Horloger = function(l, neon)
			if neon then
				return rgb(255, 170, 60), nil, nil
			end
			return ramp(BRASS, l), Mat.Glass, 0.45
		end,
		Mirage = function(l, neon)
			if neon then
				return rgb(255, 240, 210), nil, nil
			end
			return ramp(HEAT, l), Mat.SmoothPlastic, 0.2
		end,
		Encre = function(l, neon)
			if neon or l < 0.4 then
				return INK, Mat.SmoothPlastic, 0
			end
			return if l < 0.62 then PAPER_SHADE else PAPER, Mat.SmoothPlastic, 0
		end,
		Aurore = function(l, neon, c, t)
			local hue = Mutations.auroraHue(c, t)
			if neon then
				return Color3.fromHSV(hue, 0.35, 1), nil, nil
			end
			return Color3.fromHSV(hue, 0.72, 0.3 + 0.7 * l), Mat.SmoothPlastic, 0
		end,
		Fossile = function(l, neon)
			if neon then
				return rgb(255, 190, 80), nil, nil
			end
			return ramp(AMBER, l), Mat.Glass, 0.45
		end,
		Constellation = function(l, neon)
			if neon then
				return rgb(210, 225, 255), nil, nil
			end
			return ramp(NIGHT, l), Mat.SmoothPlastic, 0
		end,
		Paradoxe = function(l, neon, c, t)
			local hue = (c.along * 0.7 + c.height * 0.3 + t * 0.15) % 1
			if neon then
				return Color3.fromHSV(hue, 0.25, 1), nil, nil
			end
			return Color3.fromHSV(hue, 0.85, 0.3 + 0.7 * l), Mat.SmoothPlastic, 0
		end,
	} :: { [string]: Paint }
	
--- Apparences parcourues par le Paradoxe (une toutes les 3 secondes).
	Mutations.PARADOX_CYCLE = { "Constellation", "Vitrail", "Encre", "Aurore", "Kintsugi", "Fossile", "Mousse", "Horloger", "Mirage" }
	
--- Luminosité d'origine retrouvée à partir d'une couleur peinte en HSV (Aurore, Paradoxe).
	function Mutations.unpaintLum(c: Color3): number
		local _, _, v = c:ToHSV()
		return math.clamp((v - 0.3) / 0.7, 0, 1)
	end
	
-- ---------------------------------------------------------------------------
	-- Application sur un modèle
	-- ---------------------------------------------------------------------------
	
type PartInfo = { part: BasePart, ctx: PaintCtx, lum: number, neon: boolean, bone: string, aura: boolean }
	
type Ctx = {
		model: Model,
		root: BasePart,
		ref: CFrame,
		center: Vector3, -- centre (espace Root)
		size: Vector3, -- taille (espace Root)
		span: number, -- plus grande dimension
		sc: number,
		rng: Random,
		parts: { PartInfo },
		body: { PartInfo }, -- pièces du corps (hors orbites et effets)
		bones: { [string]: BasePart },
		parentOf: { [string]: string },
	}
	
local function configure(p: BasePart)
		p.Anchored = false
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
	end
	
local function hash(x: number): number
		local s = math.sin(x * 12.9898) * 43758.5453
		return s - math.floor(s)
	end
	
local function isAuraName(name: string): boolean
		return string.sub(name, 1, 4) == "Aura" or string.sub(name, 1, 3) == "FX_" or name == "Bones"
	end
	
local function boneNameOf(model: Model, p: BasePart): string
		local parent = p.Parent
		if parent and parent ~= model and parent:IsA("Folder") then
			return parent.Name
		end
		return "Root"
	end
	
local function bounds(model: Model, ref: CFrame): (Vector3, Vector3)
		local lo = Vector3.one * math.huge
		local hi = -lo
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.95 and not isAuraName(boneNameOf(model, d)) then
				local p = ref:PointToObjectSpace(d.CFrame.Position)
				local e = d.Size.Magnitude * 0.3
				lo = lo:Min(p - Vector3.one * e)
				hi = hi:Max(p + Vector3.one * e)
			end
		end
		if lo.X == math.huge then
			return Vector3.zero, Vector3.one
		end
		return (lo + hi) / 2, hi - lo
	end
	
local function buildCtx(model: Model, seed: number): Ctx?
		local root = model.PrimaryPart
		if not root then
			return nil
		end
		local ref = root.CFrame
		local center, size = bounds(model, ref)
		local bones: { [string]: BasePart } = { Root = root }
		local parentOf: { [string]: string } = {}
		local folder = model:FindFirstChild("Bones")
		if folder then
			for _, b in folder:GetChildren() do
				if b:IsA("BasePart") then
					bones[b.Name] = b
				end
			end
		end
		for _, d in model:GetDescendants() do
			if d:IsA("Motor6D") and d.Part0 and d.Part1 then
				parentOf[d.Part1.Name] = d.Part0.Name
			end
		end
		local zMin, yMin = center.Z - size.Z / 2, center.Y - size.Y / 2
		local cs = math.max(size.X, size.Y, size.Z) / 7
		local parts, body = {}, {}
		for i, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.95 and d.Parent ~= folder and d ~= root then
				local p = ref:PointToObjectSpace(d.CFrame.Position)
				local bone = boneNameOf(model, d)
				local cell = math.floor(hash(math.floor(p.X / cs) * 7.1 + math.floor(p.Y / cs) * 13.7 + math.floor(p.Z / cs) * 3.3) * 6) + 1
				local info: PartInfo = {
					part = d,
					ctx = {
						along = math.clamp((p.Z - zMin) / math.max(size.Z, 0.01), 0, 1),
						height = math.clamp((p.Y - yMin) / math.max(size.Y, 0.01), 0, 1),
						h = hash(i * 1.37 + seed),
						cell = math.clamp(cell, 1, 6),
					},
					lum = lumOf(d.Color),
					neon = d.Material == Mat.Neon,
					bone = bone,
					aura = isAuraName(bone),
				}
				table.insert(parts, info)
				if not info.aura then
					table.insert(body, info)
				end
			end
		end
		return {
			model = model,
			root = root,
			ref = ref,
			center = center,
			size = size,
			span = math.max(size.X, size.Y, size.Z),
			sc = (model:GetAttribute("Scale") :: number?) or 1,
			rng = Random.new(seed),
			parts = parts,
			body = body,
			bones = bones,
			parentOf = parentOf,
		}
	end
	
--- Pièce ajoutée par une mutation, soudée à l'os `bone` (cf/size en coordonnées monde).
	local function add(c: Ctx, bone: string, name: string, shape: string, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, transparency: number?): BasePart
		local b = c.bones[bone] or c.root
		local p: BasePart
		if shape == "Wedge" then
			p = Instance.new("WedgePart")
		else
			local part = Instance.new("Part")
			if shape == "Ball" then
				part.Shape = Enum.PartType.Ball
			elseif shape == "Cylinder" then
				part.Shape = Enum.PartType.Cylinder
			end
			p = part
		end
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Mat.SmoothPlastic
		p.Transparency = transparency or 0
		p.CastShadow = false
		configure(p)
		p.CFrame = cf
		local f = c.model:FindFirstChild(bone)
		if not (f and f:IsA("Folder")) then
			local nf = Instance.new("Folder")
			nf.Name = bone
			nf.Parent = c.model
			f = nf
		end
		p.Parent = f
		local w = Instance.new("Weld")
		w.Part0 = b
		w.Part1 = p
		w.C0 = b.CFrame:ToObjectSpace(p.CFrame)
		w.Parent = p
		return p
	end
	
--- Segment (poutre) entre deux points monde.
	local function segment(c: Ctx, bone: string, name: string, a: Vector3, b: Vector3, w: number, color: Color3, material: Enum.Material?, transparency: number?): BasePart?
		local d = b - a
		if d.Magnitude < 1e-3 then
			return nil
		end
		local up = if math.abs(d.Unit.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
		return add(c, bone, name, "Block", CFrame.lookAt((a + b) / 2, b, up), Vector3.new(w, w, d.Magnitude + w * 0.6), color, material, transparency)
	end
	
--- Demi-épaisseur d'une pièce le long de la direction monde `n`.
	local function extentAlong(p: BasePart, n: Vector3): number
		local cf = p.CFrame
		return 0.5 * (math.abs(cf.RightVector:Dot(n)) * p.Size.X + math.abs(cf.UpVector:Dot(n)) * p.Size.Y + math.abs(cf.LookVector:Dot(n)) * p.Size.Z)
	end
	
--- Normale extérieure approximative d'une pièce (depuis le centre de son os).
	local function outward(c: Ctx, info: PartInfo): Vector3
		local b = c.bones[info.bone] or c.root
		local d = info.part.CFrame.Position - b.CFrame.Position
		if d.Magnitude < 1e-3 then
			return c.ref.UpVector
		end
		return d.Unit
	end
	
local function pick(c: Ctx, list: { PartInfo }, n: number, filter: ((PartInfo) -> boolean)?): { PartInfo }
		local pool = {}
		for _, info in list do
			if not filter or filter(info) then
				table.insert(pool, info)
			end
		end
		local out = {}
		for _ = 1, math.min(n, #pool) do
			local i = c.rng:NextInteger(1, #pool)
			table.insert(out, pool[i])
			pool[i] = pool[#pool]
			pool[#pool] = nil
		end
		return out
	end
	
local function fxPart(c: Ctx, name: string, m: Mutation, lightRange: number?)
		local aura = Instance.new("Part")
		aura.Name = "FX_" .. name
		aura.Size = c.size * 0.9
		aura.Transparency = 1
		aura.CastShadow = false
		configure(aura)
		aura.CFrame = c.ref * CFrame.new(c.center)
		local w = Instance.new("Weld")
		w.Part0 = c.root
		w.Part1 = aura
		w.C0 = CFrame.new(c.center)
		w.Parent = aura
		aura.Parent = c.model
		if m.particle then
			Fx.particles(aura, m.particle, c.sc)
		end
		if lightRange then
			Fx.light(aura, { color = m.glow, range = lightRange / c.sc, brightness = 1.2 }, c.sc)
		end
		return aura
	end
	
-- Pièces ajoutées par chaque mutation ----------------------------------------
	
local ADD: { [string]: (Ctx, Mutation) -> () } = {}
	
ADD.Mousse = function(c, m)
		local petals = { rgb(255, 150, 200), rgb(255, 250, 240), rgb(200, 160, 255), rgb(255, 230, 90) }
		local f = math.clamp(c.span * 0.028, 0.08, 1.4)
		local n = math.clamp(math.floor(#c.body / 40), 8, 24)
		for _, info in pick(c, c.body, n, function(i)
			return i.ctx.height > 0.4 and not i.neon
		end) do
			local p = info.part
			local top = p.CFrame.Position + Vector3.yAxis * extentAlong(p, Vector3.yAxis)
			local col = petals[c.rng:NextInteger(1, #petals)]
			add(c, info.bone, "Flower", "Ball", CFrame.new(top + Vector3.yAxis * f * 0.12), Vector3.one * f * 0.45, rgb(255, 214, 60), Mat.SmoothPlastic)
			local a0 = c.rng:NextNumber(0, math.pi)
			for k = 0, 4 do
				local a = a0 + k / 5 * math.pi * 2
				add(c, info.bone, "Petal", "Ball", CFrame.new(top + Vector3.new(math.cos(a), 0.05, math.sin(a)) * f * 0.36), Vector3.new(1, 0.55, 1) * f * 0.5, col, Mat.SmoothPlastic)
			end
			-- Brin de mousse retombant
			add(c, info.bone, "MossTuft", "Ball", CFrame.new(top - Vector3.yAxis * f * 0.1 + Vector3.new(f * 0.5, 0, 0)), Vector3.new(1.2, 0.5, 1) * f * 0.6, rgb(90, 140, 50), Mat.Grass)
		end
		fxPart(c, "Mousse", m)
	end
	
ADD.Kintsugi = function(c, m)
		local n = math.clamp(math.floor(#c.body / 30), 10, 36)
		local list = pick(c, c.body, n, function(i)
			return not i.neon and i.part.Size.Magnitude > c.span * 0.04
		end)
		for _, info in list do
			local p = info.part
			local nrm = outward(c, info)
			local base = p.CFrame.Position + nrm * extentAlong(p, nrm) * 0.92
			local t1 = nrm:Cross(Vector3.new(c.rng:NextNumber(-1, 1), c.rng:NextNumber(-1, 1), c.rng:NextNumber(-1, 1))).Unit
			local t2 = nrm:Cross(t1).Unit
			local L = math.max(p.Size.X, p.Size.Y, p.Size.Z) * 0.35
			local w = math.clamp(c.span * 0.007, 0.03, 0.3)
			local pts = { base - t1 * L * 1.4, base - t1 * L * 0.45 + t2 * L * 0.3, base + t1 * L * 0.45 - t2 * L * 0.25, base + t1 * L * 1.4 + t2 * L * 0.15 }
			for k = 1, #pts - 1 do
				segment(c, info.bone, "GoldCrack", pts[k], pts[k + 1], w, rgb(255, 196, 60), Mat.Neon)
			end
		end
		fxPart(c, "Kintsugi", m)
	end
	
ADD.Vitrail = function(c, m)
		local aura = fxPart(c, "Vitrail", m)
		for i, col in { GLASS[1], GLASS[2], GLASS[4] } do
			local a = Instance.new("Attachment")
			a.Position = Vector3.new(0, 0, (i - 2) * c.size.Z * 0.25)
			a.Parent = aura
			Fx.light(a, { color = col, range = c.span * 0.5 / c.sc, brightness = 1.6 }, c.sc)
		end
	end
	
ADD.Horloger = function(c, m)
		-- Os principaux = ceux qui portent le plus de pièces
		local count: { [string]: number } = {}
		for _, info in c.body do
			local b = info.bone
			if b ~= "Root" and not string.match(b, "^Float") and not string.match(b, "^Sway") then
				count[b] = (count[b] or 0) + 1
			end
		end
		local order = {}
		for b, n in count do
			table.insert(order, { b = b, n = n })
		end
		table.sort(order, function(a, b)
			return a.n > b.n
		end)
		local gears = 0
		local folder = c.model:FindFirstChild("Bones")
		local function gear(bone: string, center: Vector3, r: number, dir: number)
			gears += 1
			local name = "Spin" .. gears
			local right, up = c.ref.RightVector, c.ref.UpVector
			local gcf = CFrame.fromMatrix(center, up, right:Cross(up), right)
			local parent = c.bones[bone] or c.root
			local gb = Instance.new("Part")
			gb.Name = name
			gb.Size = Vector3.one * 0.2
			gb.Transparency = 1
			configure(gb)
			gb.CFrame = gcf
			gb.Parent = folder or c.model
			local motor = Instance.new("Motor6D")
			motor.Name = name
			motor.Part0 = parent
			motor.Part1 = gb
			motor.C0 = parent.CFrame:ToObjectSpace(gcf)
			motor:SetAttribute("Speed", dir * 1.4 / math.max(r / c.sc, 0.2))
			motor.Parent = parent
			c.bones[name] = gb
			local th = r * 0.28
			add(c, name, "Gear", "Cylinder", gcf * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(th, r * 2, r * 2), rgb(196, 140, 56), Mat.Metal)
			add(c, name, "GearHub", "Cylinder", gcf * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(th * 1.5, r * 0.7, r * 0.7), rgb(90, 58, 26), Mat.Metal)
			local teeth = math.max(8, math.floor(r / c.sc * 14))
			for k = 0, teeth - 1 do
				local a = k / teeth * math.pi * 2
				add(c, name, "GearTooth", "Block", gcf * CFrame.Angles(0, 0, a) * CFrame.new(0, r + r * 0.1, 0), Vector3.new(r * 0.26, r * 0.3, th), rgb(236, 186, 84), Mat.Metal)
			end
			for k = 0, 2 do
				add(c, name, "GearSpoke", "Block", gcf * CFrame.Angles(0, 0, k / 3 * math.pi), Vector3.new(r * 0.12, r * 1.7, th * 1.2), rgb(150, 100, 40), Mat.Metal)
			end
		end
		for i = 1, math.min(4, #order) do
			local b = order[i].b
			local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
			for _, info in c.body do
				if info.bone == b then
					local p = c.ref:PointToObjectSpace(info.part.CFrame.Position)
					lo, hi = lo:Min(p), hi:Max(p)
				end
			end
			local mid = c.ref * ((lo + hi) / 2)
			local ext = hi - lo
			local r = math.clamp(math.min(ext.Y, math.max(ext.Z, ext.X)) * 0.22, 0.12 * c.sc, c.span * 0.12)
			gear(b, mid, r, 1)
			if i == 1 then
				gear(b, mid + c.ref.LookVector * r * 1.85 + c.ref.UpVector * r * 0.3, r * 0.68, -1)
				gear(b, mid - c.ref.LookVector * r * 1.8 - c.ref.UpVector * r * 0.2, r * 0.78, -1)
			end
		end
		fxPart(c, "Horloger", m, c.span * 0.5)
	end
	
ADD.Mirage = function(c, m)
		-- Ombre décalée : silhouette plate posée à côté du corps
		local list = table.clone(c.body)
		table.sort(list, function(a, b)
			return a.part.Size.Magnitude > b.part.Size.Magnitude
		end)
		local off = Vector3.new(c.size.X * 0.45, 0, c.size.Z * 0.12)
		for i = 1, math.min(80, #list) do
			local p = list[i].part
			local lp = c.ref:PointToObjectSpace(p.CFrame.Position)
			local ex = extentAlong(p, c.ref.RightVector) * 2
			local ez = extentAlong(p, c.ref.LookVector) * 2
			add(c, "Root", "MirageShadow", "Block", c.ref * CFrame.new(lp.X + off.X, 0.03 * c.sc + i * 0.0005, lp.Z + off.Z), Vector3.new(ex, 0.02 * c.sc, ez), rgb(70, 30, 50), Mat.SmoothPlastic, 0.55)
		end
		fxPart(c, "Mirage", m)
	end
	
ADD.Encre = function(c, m)
		local tips = {}
		for name in c.bones do
			if string.match(name, "^Leg") or string.match(name, "^Wing") or string.match(name, "^Arm") then
				table.insert(tips, name)
			end
		end
		local tailEnd, segEnd = 0, 0
		for name in c.bones do
			local n = tonumber(string.match(name, "^Tail(%d+)$"))
			if n and n > tailEnd then
				tailEnd = n
			end
			local s = tonumber(string.match(name, "^Seg(%d+)$"))
			if s and s > segEnd then
				segEnd = s
			end
		end
		if tailEnd > 0 then
			table.insert(tips, "Tail" .. tailEnd)
		end
		if segEnd > 0 then
			table.insert(tips, "Seg" .. segEnd)
		end
		if #tips == 0 then
			table.insert(tips, if c.bones.Body then "Body" else "Root")
		end
		for _, name in tips do
			local b = c.bones[name]
			-- pointe = pièce la plus éloignée de l'articulation
			local far, best = b.CFrame.Position, -1
			for _, info in c.body do
				if info.bone == name then
					local d = (info.part.CFrame.Position - b.CFrame.Position).Magnitude
					if d > best then
						far, best = info.part.CFrame.Position, d
					end
				end
			end
			local w = math.clamp(c.span * 0.02, 0.06, 0.8)
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Name, a1.Name = "InkTrail0", "InkTrail1"
			a0.Parent, a1.Parent = b, b
			a0.WorldPosition = far + Vector3.yAxis * w
			a1.WorldPosition = far - Vector3.yAxis * w
			local tr = Instance.new("Trail")
			tr.Name = "InkTrail"
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.Color = ColorSequence.new(INK)
			tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
			tr.Lifetime = 0.9
			tr.MinLength = 0.05
			tr.FaceCamera = true
			tr.LightInfluence = 0
			tr.Parent = b
		end
		local h = c.model:FindFirstChildOfClass("Highlight")
		if h then
			h.OutlineColor = INK
			h.OutlineTransparency = 0
		end
		fxPart(c, "Encre", m)
	end
	
ADD.Aurore = function(c, m)
		local aura = fxPart(c, "Aurore", m, c.span * 0.6)
		local cols = { { rgb(80, 255, 170), rgb(60, 200, 255), rgb(190, 90, 255) }, { rgb(190, 90, 255), rgb(80, 255, 200), rgb(60, 160, 255) } }
		for i = 1, 2 do
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position = Vector3.new(-c.size.X * 0.1 * i, c.size.Y * (0.35 + 0.1 * i), -c.size.Z * 0.48)
			a1.Position = Vector3.new(c.size.X * 0.1 * i, c.size.Y * (0.3 + 0.1 * i), c.size.Z * 0.48)
			a0.Parent, a1.Parent = aura, aura
			local b = Instance.new("Beam")
			b.Name = "AuroraRibbon"
			b.Attachment0, b.Attachment1 = a0, a1
			b.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, cols[i][1]), ColorSequenceKeypoint.new(0.5, cols[i][2]), ColorSequenceKeypoint.new(1, cols[i][3]) })
			b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) })
			b.Width0 = c.size.X * 0.5
			b.Width1 = c.size.X * 0.5
			b.CurveSize0 = c.size.Y * 0.6 * (if i == 1 then 1 else -1)
			b.CurveSize1 = c.size.Y * 0.4
			b.LightEmission = 1
			b.FaceCamera = true
			b.Segments = 20
			b.Parent = aura
		end
	end
	
ADD.Fossile = function(c, m)
		local bone = rgb(238, 230, 210)
		local th = math.clamp(c.span * 0.022, 0.05, 0.7)
		local hasChild: { [string]: boolean } = {}
		for child, parent in c.parentOf do
			hasChild[parent] = true
		end
		local function skip(name: string): boolean
			return name == "Root" or isAuraName(name) or string.match(name, "^Float") ~= nil or string.match(name, "^Spin") ~= nil or string.match(name, "^Ear") ~= nil
		end
		for name, b in c.bones do
			if not skip(name) then
				local parent = c.parentOf[name]
				if parent and not skip(parent) and c.bones[parent] then
					segment(c, parent, "Bone", c.bones[parent].CFrame.Position, b.CFrame.Position, th, bone)
				end
				add(c, name, "Joint", "Ball", CFrame.new(b.CFrame.Position), Vector3.one * th * 1.7, bone)
				if not hasChild[name] then
					local far, best = b.CFrame.Position, -1
					for _, info in c.body do
						if info.bone == name then
							local d = (info.part.CFrame.Position - b.CFrame.Position).Magnitude
							if d > best then
								far, best = info.part.CFrame.Position, d
							end
						end
					end
					if best > th then
						segment(c, name, "Bone", b.CFrame.Position, b.CFrame.Position:Lerp(far, 0.85), th * 0.85, bone)
					end
				end
			end
		end
		-- Côtes autour du corps et crâne
		local function boxOf(name: string): (Vector3?, Vector3?)
			local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
			local any = false
			for _, info in c.body do
				if info.bone == name then
					local p = c.ref:PointToObjectSpace(info.part.CFrame.Position)
					lo, hi = lo:Min(p), hi:Max(p)
					any = true
				end
			end
			if not any then
				return nil, nil
			end
			return (lo + hi) / 2, hi - lo
		end
		local mid, ext = boxOf("Body")
		if mid and ext then
			local ex, ey, ez = ext.X * 0.5, ext.Y * 0.5, ext.Z * 0.5
			for k = 0, 4 do
				local z = mid.Z - ez * 0.45 + k * ez * 0.2
				for _, s in { 1, -1 } do
					local pts = {
						Vector3.new(0, mid.Y + ey * 0.45, z),
						Vector3.new(s * ex * 0.5, mid.Y + ey * 0.25, z),
						Vector3.new(s * ex * 0.55, mid.Y - ey * 0.15, z),
						Vector3.new(s * ex * 0.3, mid.Y - ey * 0.45, z),
					}
					for i = 1, #pts - 1 do
						segment(c, "Body", "Rib", c.ref * pts[i], c.ref * pts[i + 1], th * 0.7, bone)
					end
				end
			end
			segment(c, "Body", "Spine", c.ref * Vector3.new(0, mid.Y + ey * 0.45, mid.Z - ez * 0.6), c.ref * Vector3.new(0, mid.Y + ey * 0.45, mid.Z + ez * 0.6), th, bone)
		end
		local hmid, hext = boxOf("Head")
		if hmid and hext then
			local d = math.min(hext.X, hext.Y, hext.Z) * 0.75 + th
			add(c, "Head", "Skull", "Ball", c.ref * CFrame.new(hmid), Vector3.one * d, bone)
			for _, s in { 1, -1 } do
				add(c, "Head", "EyeSocket", "Ball", c.ref * CFrame.new(hmid + Vector3.new(s * d * 0.22, d * 0.08, -d * 0.4)), Vector3.one * d * 0.28, rgb(40, 20, 10))
			end
		end
		fxPart(c, "Fossile", m, c.span * 0.5)
	end
	
ADD.Constellation = function(c, m)
		local starCol = rgb(235, 242, 255)
		local list = {}
		for _, info in c.body do
			if not info.neon then
				table.insert(list, info)
			end
		end
		if #list == 0 then
			return
		end
		-- Étoiles bien réparties (échantillonnage du point le plus éloigné)
		local k = math.clamp(math.floor(#list / 60), 10, 22)
		local chosen = { list[c.rng:NextInteger(1, #list)] }
		while #chosen < k do
			local best, bestD = nil, -1
			for i = 1, #list, 3 do
				local info = list[i]
				local d = math.huge
				for _, s in chosen do
					d = math.min(d, (s.part.CFrame.Position - info.part.CFrame.Position).Magnitude)
				end
				if d > bestD then
					best, bestD = info, d
				end
			end
			table.insert(chosen, best :: PartInfo)
		end
		local s = math.clamp(c.span * 0.03, 0.08, 1.2)
		local stars = {}
		for _, info in chosen do
			local nrm = outward(c, info)
			local pos = info.part.CFrame.Position + nrm * extentAlong(info.part, nrm)
			local star = add(c, info.bone, "Star", "Ball", CFrame.new(pos), Vector3.one * s * 0.55, starCol, Mat.Neon)
			local rot = CFrame.lookAt(pos, pos + nrm)
			add(c, info.bone, "StarRay", "Block", rot, Vector3.new(s * 0.12, s * 1.3, s * 0.12), starCol, Mat.Neon)
			add(c, info.bone, "StarRay", "Block", rot, Vector3.new(s * 1.3, s * 0.12, s * 0.12), starCol, Mat.Neon)
			local a = Instance.new("Attachment")
			a.Name = "StarLink"
			a.Parent = star
			table.insert(stars, { part = star, att = a })
		end
		-- Lignes de constellation : chaque étoile reliée à la plus proche des précédentes
		for i = 2, #stars do
			local best, bestD = stars[1], math.huge
			for j = 1, i - 1 do
				local d = (stars[j].part.CFrame.Position - stars[i].part.CFrame.Position).Magnitude
				if d < bestD then
					best, bestD = stars[j], d
				end
			end
			local b = Instance.new("Beam")
			b.Name = "ConstellationLine"
			b.Attachment0, b.Attachment1 = best.att, stars[i].att
			b.Color = ColorSequence.new(rgb(170, 200, 255), rgb(255, 255, 255))
			b.Transparency = NumberSequence.new(0.25)
			b.Width0, b.Width1 = s * 0.12, s * 0.12
			b.LightEmission = 1
			b.FaceCamera = true
			b.Segments = 1
			b.Parent = stars[i].part
		end
		-- Poussière d'étoiles
		for _, info in pick(c, list, 40) do
			local nrm = outward(c, info)
			add(c, info.bone, "StarDot", "Ball", CFrame.new(info.part.CFrame.Position + nrm * extentAlong(info.part, nrm)), Vector3.one * s * 0.22, starCol, Mat.Neon)
		end
		fxPart(c, "Constellation", m, c.span * 0.5)
	end
	
ADD.Echo = function(c, m)
		fxPart(c, "Echo", m)
	end
	
ADD.Paradoxe = function(c, m)
		fxPart(c, "Paradoxe", m, c.span * 0.5)
	end
	
--- Applique une ou plusieurs mutations au modèle (une seule fois). Renvoie le modèle.
	function Mutations.apply(model: Model, ids: string | { string }): Model
		if model:GetAttribute("Mutations") then
			return model
		end
		local list = Mutations.normalize(ids)
		if #list == 0 then
			return model
		end
		local seed = 0
		for i = 1, #list do
			seed += rank[list[i]] * 97 * i
		end
		local c = buildCtx(model, seed)
		if not c then
			return model
		end
		local dom = Mutations.dominant(list)
		if dom and dom.recolor then
			local paint = Mutations.PAINT[dom.id]
			for _, info in c.parts do
				local col, mat, tr = paint(info.lum, info.neon, info.ctx, 0)
				local p = info.part
				p.Color = col
				if mat then
					p.Material = mat
				end
				if tr and not info.neon then
					p.Transparency = math.max(p.Transparency, tr)
				end
			end
			for _, d in model:GetDescendants() do
				if d:IsA("PointLight") then
					d.Color = dom.glow
				end
			end
		end
		for _, id in list do
			ADD[id](c, byId[id])
		end
		model:SetAttribute("Mutations", table.concat(list, ","))
		model:SetAttribute("Mutation", if dom then dom.id else list[1])
		model:SetAttribute("Multiplier", Mutations.multiplier(list))
		return model
	end
	
-- ---------------------------------------------------------------------------
	-- Côté client : animation des mutations (appelé par CreatureAnimator)
	-- ---------------------------------------------------------------------------
	
type Runtime = {
		step: (self: Runtime, t: number, dt: number) -> (),
		destroy: (self: Runtime) -> (),
	}
	
local ECHO_DELAY = 1
	local PARADOX_PERIOD = 3
	
--- Prépare les effets animés d'un modèle muté (nil s'il n'y a rien à animer).
	function Mutations.runtime(model: Model, motors: { [string]: Motor6D }): Runtime?
		local attr = model:GetAttribute("Mutations")
		if typeof(attr) ~= "string" then
			return nil
		end
		local list = Mutations.normalize(attr)
		local has: { [string]: boolean } = {}
		for _, id in list do
			has[id] = true
		end
		local dom = Mutations.dominant(list)
		local root = model.PrimaryPart
		if not root then
			return nil
		end
		local sc = (model:GetAttribute("Scale") :: number?) or 1
	
	local spins = {}
		for name, m in motors do
			if string.sub(name, 1, 4) == "Spin" then
				table.insert(spins, { motor = m, speed = (m:GetAttribute("Speed") :: number?) or 1 })
			end
		end
		local waves = {}
		if has.Mirage then
			local i = 0
			for name, m in motors do
				if string.sub(name, 1, 4) ~= "Aura" and string.sub(name, 1, 4) ~= "Spin" then
					i += 1
					table.insert(waves, { motor = m, k = i * 1.7 })
				end
			end
		end
	
	-- Recoloration animée (Aurore dominante, ou Paradoxe)
		local painted: { { part: BasePart, ctx: PaintCtx, lum: number, neon: boolean } }? = nil
		if dom and (dom.id == "Aurore" or dom.id == "Paradoxe") then
			local c = buildCtx(model, 1)
			if c then
				local arr = {}
				for _, info in c.parts do
					local n = info.part.Name
					if not string.match(n, "^Star") and n ~= "Flower" and n ~= "Petal" then
						table.insert(arr, { part = info.part, ctx = info.ctx, lum = Mutations.unpaintLum(info.part.Color), neon = info.neon })
					end
				end
				painted = arr
			end
		end
	
	-- Copie fantôme (Écho) : rejoue la position et la pose d'il y a une seconde
		local ghost: Model? = nil
		local ghostMotors: { [string]: Motor6D } = {}
		local history: { { t: number, pivot: CFrame, pose: { [string]: CFrame } } } = {}
		if has.Echo then
			local was = model.Archivable
			model.Archivable = true
			local g = model:Clone()
			model.Archivable = was
			if g then
				for _, d in g:GetDescendants() do
					if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") or d:IsA("Highlight") or d:IsA("Seat") or d:IsA("Script") or d:IsA("LocalScript") then
						d:Destroy()
					elseif d:IsA("BasePart") then
						if d.Transparency < 0.95 then
							d.Material = Mat.ForceField
							d.Color = rgb(120, 220, 255)
							d.Transparency = 0.2
						end
						d.CanQuery = false
						d.CanTouch = false
						d.CanCollide = false
					elseif d:IsA("Motor6D") then
						ghostMotors[d.Name] = d
					end
				end
				for _, tag in g:GetTags() do
					g:RemoveTag(tag)
				end
				g:SetAttribute("CreatureId", nil)
				g:SetAttribute("Mutations", nil)
				g.Name = model.Name .. "_Echo"
				if g.PrimaryPart then
					g.PrimaryPart.Anchored = true
				end
				g.Parent = model.Parent
				ghost = g
			end
		end
	
	local rt = {}
		local lastPaint, lastSample = -1, -1
	
	function rt.step(_self: Runtime, t: number, dt: number)
			for _, s in spins do
				s.motor.Transform = CFrame.Angles(0, 0, t * s.speed)
			end
			for _, w in waves do
				w.motor.Transform = w.motor.Transform * CFrame.new(math.sin(t * 6 + w.k) * 0.035 * sc, 0, math.cos(t * 4.5 + w.k) * 0.02 * sc)
			end
			if painted and t - lastPaint > 0.1 then
				lastPaint = t
				local id = if dom then dom.id else "Aurore"
				local tt = t
				if id == "Paradoxe" then
					id = Mutations.PARADOX_CYCLE[(math.floor(t / PARADOX_PERIOD) % #Mutations.PARADOX_CYCLE) + 1]
					tt = 0
				end
				local paint = Mutations.PAINT[id]
				for _, e in painted do
					local col, mat, tr = paint(e.lum, e.neon, e.ctx, tt)
					e.part.Color = col
					if dom and dom.id == "Paradoxe" then
						e.part.Material = if e.neon then Mat.Neon else (mat or Mat.SmoothPlastic)
						e.part.Transparency = if e.neon then 0 else (tr or 0)
					end
				end
			end
			if ghost and ghost.PrimaryPart then
				if t - lastSample > 1 / 30 then
					lastSample = t
					local pose = {}
					for name, m in motors do
						pose[name] = m.Transform
					end
					table.insert(history, { t = t, pivot = model:GetPivot(), pose = pose })
				end
				while #history > 2 and history[2].t <= t - ECHO_DELAY do
					table.remove(history, 1)
				end
				local h = history[1]
				if h then
					ghost:PivotTo(h.pivot)
					for name, cfr in h.pose do
						local gm = ghostMotors[name]
						if gm then
							gm.Transform = cfr
						end
					end
				end
			end
		end
	
	function rt.destroy(_self: Runtime)
			if ghost then
				ghost:Destroy()
				ghost = nil
			end
		end
	
	if #spins == 0 and #waves == 0 and not painted and not ghost then
			return nil
		end
		return rt :: any
	end
	
return Mutations

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
		flap: number?, -- amplitude des battements d'ailes (degrés, Flyer)
		flapRate: number?, -- vitesse des battements (rad/s)
		hover: number?, -- amplitude du flottement (studs, Flyer / Hover)
		auraSpeed: number?, -- vitesse de rotation des objets en orbite (rad/s)
		flicker: number?, -- vacillement des lumières (0 = fixe, 0.3 = feu)
	}
	
--- Capacité spéciale jouée par Vfx.playAbility (état d'animation "Ability").
	type Ability = {
		name: string, -- nom affiché (ex. "Souffle ardent")
		kind: "Nova" | "Breath" | "Stomp" | "Burst" | "Eruption",
		colors: { Color3 }, -- couleur principale, secondaire, (tertiaire)
		texture: string?, -- "sparkle" | "fire" | "smoke" | "spark" (voir Fx.TEXTURES)
		bone: string?, -- os d'origine (souffle) — défaut : Head
		origin: Vector3?, -- point d'origine en espace modèle (avant échelle)
		direction: Vector3?, -- direction du souffle (espace modèle)
		radius: number?, -- rayon de l'onde de choc (studs, avant échelle)
		duration: number?, -- durée (secondes)
	}
	
--- Taille (voir Rarity.Sizes) : plus une créature est grosse, plus elle rapporte.
	type Size = "Small" | "Medium" | "Large" | "Giant" | "Colossal"
	
--- Où la créature s'obtient : sur le tapis, sur le tapis ET dans la roue, ou seulement dans la roue.
	type Source = "Tapis" | "TapisEtRoue" | "Roue"
	
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
		Rarity: string, -- "Common" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Exotic" | "Exclusive" | "Chaotic"
		Size: Size,
		Income: number, -- argent de base par seconde ($/s) dans l'enclos
		SpeedBonus: number, -- bonus de vitesse en monture (0.05 = +5 %)
		Passenger: boolean, -- peut porter un passager (selle passager)
		Source: Source?, -- défaut : "Tapis"
		Scale: number?, -- échelle par défaut à l'apparition (taille en jeu)
		Category: string,
		Description: string,
		Icon: IconTheme,
		Animation: AnimProfile,
		Ability: Ability?,
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
	local Mutations = __require("Mutations")
	local Types = __require("Types")
	
local Icon = {}
	
type IconOptions = {
		size: UDim2?, -- défaut : UDim2.fromScale(1, 1)
		position: UDim2?,
		anchorPoint: Vector2?,
		layoutOrder: number?,
		showName: boolean?, -- défaut : true
		showRarity: boolean?, -- défaut : true
		mutation: string?, -- affiche la variante mutée + sa pastille
		mutations: { string }?, -- plusieurs mutations cumulées
		detail: number?, -- densité du modèle 3D (défaut : 0.55, plus léger)
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
		local model = def.build({ effects = false, outline = false, animated = false, detail = o.detail or 0.55 })
		local mutList = Mutations.normalize(o.mutations or o.mutation)
		local mutation = Mutations.dominant(mutList)
		if mutation then
			Mutations.apply(model, mutList)
			for _, d in model:GetDescendants() do
				if d:IsA("ParticleEmitter") or d:IsA("Light") then
					d:Destroy()
				end
			end
		end
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
	
	-- Pastille de mutation (sous la rareté)
		if mutation then
			local tag = frame("Mutation", card, UDim2.fromScale(0.5, 0.11), UDim2.fromScale(0.3, 0.22), WHITE, 0, 5)
			corner(tag, 0.5)
			gradient(tag, mutation.badge, 0)
			stroke(tag, BLACK, 1.5, 0.2)
			local text = if #mutList > 1 then `{mutation.label} +{#mutList - 1}` else mutation.label
			local t = label("Label", tag, `{text} x{Mutations.multiplier(mutList)}`, WHITE, 14)
			t.Size = UDim2.fromScale(0.9, 0.72)
			stroke(t, BLACK, 1.2)
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

__modules["Anatomy"] = function()
	--[[
		CreatureForge.Anatomy
		---------------------
		Pièces anatomiques et ornements réutilisables, construits avec le Kit :
		membres (tubes), pattes griffues, sabots, yeux, oreilles, cornes/défenses, dents,
		crêtes d'épines, touffes, flammes, plumes et ailes, cristaux, engrenages, runes,
		anneaux au sol et objets en orbite (aura).
	
	Conventions : espace modèle (la créature regarde vers -Z, +X = droite, sol à Y = 0).
		Les fonctions "côté droit" prennent `side` (+1 droite / -1 gauche) et miroitent X.
	]]
	
local Kit = __require("Kit")
	
type Rig = Kit.Rig
	type Style = Kit.Style
	type Spine = Kit.Spine
	
local A = {}
	
local v3 = Vector3.new
	local cf = CFrame.new
	local ang = CFrame.Angles
	local rad = math.rad
	
--- Miroir d'un point selon le côté (+1 droite, -1 gauche).
	function A.mx(v: Vector3, side: number): Vector3
		return v3(side * v.X, v.Y, v.Z)
	end
	
--- Repère dont +Y pointe le long de `dir` (pour pointes, plumes, flammes).
	function A.alongUp(pos: Vector3, dir: Vector3): CFrame
		return Kit.lookAlong(pos, dir) * ang(-math.pi / 2, 0, 0)
	end
	
-- ---------------------------------------------------------------------------
	-- Revêtements prêts à l'emploi
	-- ---------------------------------------------------------------------------
	
--- Fourrure en mèches pointues (style "mammouth / loup") avec pointes colorées.
	function A.fur(shades: { Style }, tip: Style?, size: Vector3?, spacing: number?, extra: { [string]: any }?): Kit.Cover
		local c: Kit.Cover = {
			kind = "Tuft",
			size = size or v3(0.22, 0.4, 0.36),
			spacing = spacing or 0.2,
			arc = 125,
			shades = shades,
			tip = tip,
			tilt = 50,
			refRadius = 0.5,
			jitter = 0.75,
		}
		if extra then
			for k, v in extra do
				(c :: any)[k] = v
			end
		end
		return c
	end
	
--- Écailles plates imbriquées.
	function A.scales(shades: { Style }, size: Vector3?, spacing: number?, extra: { [string]: any }?): Kit.Cover
		local c: Kit.Cover = {
			kind = "Scale",
			size = size or v3(0.26, 0.1, 0.28),
			spacing = spacing or 0.21,
			arc = 115,
			shades = shades,
			tilt = 20,
			refRadius = 0.45,
			jitter = 0.35,
		}
		if extra then
			for k, v in extra do
				(c :: any)[k] = v
			end
		end
		return c
	end
	
-- ---------------------------------------------------------------------------
	-- Membres et extrémités
	-- ---------------------------------------------------------------------------
	
type LimbPoint = { Vector3 | number }
	
--- Membre en tube : `path` = { {position, rx, ry}, ... } du haut (hanche) vers le bas (cheville),
	--- coordonnées du côté DROIT (miroitées si side = -1).
	function A.limb(rig: Rig, bone: string, side: number, path: { { any } }, core: Style, cover: Kit.Cover?): Spine
		local sections = {}
		for _, p in path do
			table.insert(sections, { pos = A.mx(p[1] :: Vector3, side), rx = p[2] :: number, ry = p[3] :: number })
		end
		local spine = Kit.spine(sections)
		rig:tube(spine, {
			name = "Limb",
			bone = function()
				return bone
			end,
			core = core,
			coreStep = 0.22,
			cover = if cover then { cover } else nil,
		})
		return spine
	end
	
--- Patte griffue posée au sol en `pos`, orientée vers `fwd`.
	function A.paw(rig: Rig, bone: string, pos: Vector3, fwd: Vector3, size: number, toes: number, pad: Style, toe: Style, claw: Style)
		local f = v3(fwd.X, 0, fwd.Z).Unit
		local right = f:Cross(Vector3.yAxis).Unit
		local base = CFrame.fromMatrix(pos, right, Vector3.yAxis, -f)
		rig:prism(bone, "Paw", base * cf(0, 0.2 * size, 0.05 * size), v3(size, 0.4 * size, 1.05 * size), 0.15 * size, pad)
		for i = 1, toes do
			local x = if toes == 1 then 0 else ((i - 1) / (toes - 1) - 0.5) * size * 0.78
			rig:ball(bone, "Toe", (base * cf(x, 0.18 * size, -0.48 * size)).Position, 0.36 * size, toe)
			rig:wedge(bone, "Claw", base * cf(x, 0.1 * size, -0.74 * size), v3(0.12, 0.18, 0.3) * size, claw)
		end
	end
	
--- Sabot (octogonal) avec fente avant, cerclage et touffe de fanon optionnelle.
	function A.hoof(rig: Rig, bone: string, pos: Vector3, size: number, hoof: Style, notch: Style, rim: Style?, tuft: { Style }?)
		local base = cf(pos)
		rig:prism(bone, "Hoof", base * cf(0, 0.22 * size, 0) * ang(-math.pi / 2, 0, 0), v3(size, size * 0.92, 0.44 * size), 0.28 * size, hoof)
		rig:block(bone, "HoofNotch", base * cf(0, 0.2 * size, -0.43 * size), v3(0.07, 0.4, 0.1) * size, notch)
		if rim then
			rig:ring(bone, "HoofRim", base * cf(0, 0.46 * size, 0) * ang(math.pi / 2, 0, 0), 0.47 * size, 0.09 * size, 0.09 * size, 10, rim)
		end
		if tuft then
			for i = 0, 7 do
				local a = i / 8 * math.pi * 2
				local dir = v3(math.cos(a) * 0.8, -0.35, math.sin(a) * 0.8).Unit
				rig:spike(bone, "Fetlock", A.alongUp(pos + v3(math.cos(a), 0, math.sin(a)) * 0.4 * size + v3(0, 0.62 * size, 0), dir) * ang(0, rad(90), 0), 0.22 * size, 0.38 * size, 0.06 * size, tuft[(i % #tuft) + 1])
			end
		end
	end
	
-- ---------------------------------------------------------------------------
	-- Tête
	-- ---------------------------------------------------------------------------
	
type EyeKind = "Round" | "Slit" | "Glow"
	
--- Œil : orbite sombre, iris, pupille (ronde ou fendue) et reflet. `outward` = direction du regard.
	function A.eye(rig: Rig, bone: string, pos: Vector3, outward: Vector3, size: number, kind: EyeKind, socket: Style, iris: Style, pupil: Style?)
		local o = outward.Unit
		rig:ball(bone, "EyeSocket", pos - o * size * 0.18, size * 1.32, socket)
		rig:ball(bone, "Eye", pos, size, iris)
		if kind == "Round" and pupil then
			rig:ball(bone, "Pupil", pos + o * size * 0.3, size * 0.52, pupil)
		elseif kind == "Slit" and pupil then
			rig:block(bone, "Pupil", Kit.lookAlong(pos + o * size * 0.44, o), v3(0.14, 0.78, 0.08) * size, pupil)
		end
		if kind ~= "Glow" then
			rig:ball(bone, "EyeGlint", pos + o * size * 0.42 + v3(0, size * 0.2, 0) - Vector3.zAxis * size * 0.08, size * 0.22, Kit.style(Color3.new(1, 1, 1), Enum.Material.Neon))
		end
	end
	
--- Sourcil / arcade en biseau au-dessus de l'œil (côté droit, miroité).
	function A.brow(rig: Rig, bone: string, side: number, pos: Vector3, width: number, angle: number, style: Style)
		rig:wedge(bone, "Brow", cf(A.mx(pos, side)) * ang(0, side * rad(-12), side * rad(angle)), v3(width, width * 0.32, width * 0.55), style)
	end
	
--- Oreille pointue : face externe, intérieur coloré, pointe d'une autre couleur.
	function A.ear(rig: Rig, bone: string, base: CFrame, w: number, h: number, outer: Style, inner: Style, tip: Style?)
		local t = w * 0.16
		rig:spike(bone, "Ear", base, w, h, t, outer)
		rig:spike(bone, "EarInner", base * cf(0, h * 0.08, -t * 0.6), w * 0.62, h * 0.66, t * 0.6, inner)
		if tip then
			rig:spike(bone, "EarTip", base * cf(0, h * 0.6, 0), w * 0.44, h * 0.42, t * 1.25, tip)
		end
	end
	
--- Corne / défense / bois : tube courbe effilé de r0 à r1, pointe, bagues optionnelles.
	function A.horn(
		rig: Rig,
		bone: string,
		pts: { Vector3 },
		r0: number,
		r1: number,
		style: Style,
		bandStyle: Style?,
		bandAt: { number }?
	): Spine
		local sections = {}
		for i, p in pts do
			local t = (i - 1) / math.max(#pts - 1, 1)
			local r = r0 + (r1 - r0) * t
			table.insert(sections, { pos = p, rx = r, ry = r })
		end
		local spine = Kit.spine(sections)
		rig:tube(spine, {
			name = "Horn",
			bone = function()
				return bone
			end,
			core = style,
			coreStep = math.max(r0 * 1.4, 0.08),
		})
		local last, prev = pts[#pts], pts[#pts - 1]
		rig:thorn(bone, "HornTip", A.alongUp(last, last - prev), r1 * 2.4, r1 * 4, style)
		if bandStyle and bandAt then
			for _, u in bandAt do
				local rx = spine:radii(u)
				rig:band(spine, bone, "HornBand", u, rx * 0.7, rx * 0.35, bandStyle)
			end
		end
		return spine
	end
	
--- Rangée de crocs/dents entre `a` et `b` (pointe vers le bas si `down`).
	function A.teeth(rig: Rig, bone: string, a: Vector3, b: Vector3, count: number, w: number, h: number, style: Style, down: boolean)
		for i = 1, count do
			local p = if count == 1 then a else a:Lerp(b, (i - 1) / (count - 1))
			local hh = h * (if i % 2 == 0 then 0.75 else 1)
			rig:thorn(bone, "Tooth", cf(p) * (if down then ang(math.pi, 0, 0) else CFrame.identity), w, hh, style)
		end
	end
	
--- Moustaches (côté droit, miroitées) partant de `root`.
	function A.whiskers(rig: Rig, bone: string, side: number, root: Vector3, length: number, style: Style)
		for k = -1, 1 do
			local a = A.mx(root + v3(0, k * 0.04, 0), side)
			local b = A.mx(root + v3(length, k * 0.12 + 0.03, length * 0.35 + k * 0.06), side)
			rig:strut(bone, "Whisker", a, b, 0.022, 0.022, style)
		end
	end
	
-- ---------------------------------------------------------------------------
	-- Épines, touffes, flammes
	-- ---------------------------------------------------------------------------
	
--- Crête d'épines en dents de scie le long d'une colonne (angle `deg` autour de l'axe, 0 = dessus).
	function A.crest(
		rig: Rig,
		spine: Spine,
		boneAt: (u: number) -> string,
		from: number,
		to: number,
		spacing: number,
		height: number,
		width: number,
		style: Style,
		tip: Style?,
		deg: number?,
		lean: number?
	)
		local s, sEnd, i = spine:lengthAt(from), spine:lengthAt(to), 0
		while s < sEnd do
			local u = spine:uAt(s)
			local rx, ry = spine:radii(u)
			local k = math.clamp(math.min(rx, ry) / 0.3, 0.4, 1.3)
			local h = height * k * (if i % 2 == 0 then 1 else 0.68)
			local base = spine:surface(u, deg or 0, 0.03 * k) * ang(rad(lean or 34), 0, 0) * ang(0, math.pi / 2, 0)
			rig:spike(boneAt(u), "Crest", base, width * k, h, width * 0.25 * k, style)
			if tip then
				rig:spike(boneAt(u), "CrestTip", base * cf(0, h * 0.58, 0), width * 0.5 * k, h * 0.48, width * 0.34 * k, tip)
			end
			s += spacing * k
			i += 1
		end
	end
	
--- Gerbe de mèches/épines rayonnant depuis `base` dans un cône autour de base.UpVector.
	function A.tuftBurst(
		rig: Rig,
		bone: string,
		base: CFrame,
		count: number,
		length: number,
		width: number,
		styles: { Style },
		tip: Style?,
		spread: number,
		seed: number
	)
		local rng = Random.new(seed)
		for i = 1, count do
			local yaw = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local tilt = rad(spread) * math.sqrt(rng:NextNumber(0.15, 1))
			local l = length * rng:NextNumber(0.7, 1.15)
			local c = base * ang(0, yaw, 0) * ang(0, 0, -tilt) * ang(0, rng:NextNumber(0, math.pi), 0)
			rig:spike(bone, "Tuft", c, width, l, width * 0.3, styles[(i % #styles) + 1])
			if tip then
				rig:spike(bone, "TuftTip", c * cf(0, l * 0.6, 0), width * 0.46, l * 0.44, width * 0.4, tip)
			end
		end
	end
	
--- Flamme stylisée : trois pointes en croix imbriquées (extérieur, milieu, cœur lumineux).
	function A.flame(rig: Rig, bone: string, base: CFrame, h: number, w: number, outer: Style, mid: Style, core: Style)
		rig:thorn(bone, "Flame", base, w, h, outer)
		rig:thorn(bone, "Flame", base * cf(0, h * 0.06, 0), w * 0.66, h * 0.8, mid)
		rig:thorn(bone, "FlameCore", base * cf(0, h * 0.1, 0), w * 0.36, h * 0.55, core)
	end
	
--- Triangle quelconque (2 WedgeParts) : membranes d'ailes, voiles, éclats plats.
	function A.triangle(rig: Rig, bone: string, name: string, a: Vector3, b: Vector3, c: Vector3, thickness: number, style: Style)
		-- La base est l'arête la plus longue ; on abaisse la hauteur depuis le sommet opposé.
		local pts = { { a, b, c }, { b, c, a }, { c, a, b } }
		local best = pts[1]
		for _, p in pts do
			if (p[2] - p[1]).Magnitude > (best[2] - best[1]).Magnitude then
				best = p
			end
		end
		local p0, p1, apex = best[1], best[2], best[3]
		local base = p1 - p0
		local t = (apex - p0):Dot(base) / base:Dot(base)
		local foot = p0 + base * t
		local h = (apex - foot).Magnitude
		if h < 1e-3 then
			return
		end
		local up = (apex - foot).Unit
		for _, q in { p0, p1 } do
			local leg = (q - foot).Magnitude
			if leg > 1e-3 then
				rig:wedgeTri(bone, name, foot, up, (q - foot).Unit, h, leg, thickness, style)
			end
		end
	end
	
-- ---------------------------------------------------------------------------
	-- Plumes et ailes
	-- ---------------------------------------------------------------------------
	
--- Plume en losange posée sur un repère : +Y = direction de la plume, Z = épaisseur.
	function A.feather(rig: Rig, bone: string, base: CFrame, length: number, width: number, style: Style, tip: Style?)
		rig:spike(bone, "Feather", base * ang(math.pi, 0, 0), width, length * 0.18, 0.025, style)
		rig:spike(bone, "Feather", base, width, length, 0.03, style)
		if tip then
			rig:spike(bone, "FeatherTip", base * cf(0, length * 0.62, 0), width * 0.42, length * 0.4, 0.04, tip)
		end
	end
	
type WingSpec = {
		arm: { Vector3 }, -- épaule -> coude -> poignet -> bout (côté droit)
		armRadius: number,
		feathers: number, -- nombre de rémiges
		length: { number }, -- longueur des plumes : épaule, bout
		width: number,
		sweep: number, -- angle des plumes vers l'arrière au bout de l'aile (degrés)
		rows: { { Style } }, -- rangées : { rémiges }, { couvertures }, { petites couvertures }
		tip: Style?,
		armStyle: Style,
		pose: CFrame?, -- transformation appliquée à toute l'aile (ex. aile relevée), en espace modèle
	}
	
--- Aile déployée (côté `side`) : bras en tube + 3 rangées de plumes imbriquées.
	function A.wing(rig: Rig, bone: string, side: number, spec: WingSpec)
		local pose = spec.pose or CFrame.identity
		local pts = {}
		for _, p in spec.arm do
			table.insert(pts, pose * A.mx(p, side))
		end
		local sections = {}
		for i, p in pts do
			local r = spec.armRadius * (1 - (i - 1) / #pts * 0.6)
			table.insert(sections, { pos = p, rx = r, ry = r * 0.8 })
		end
		local arm = Kit.spine(sections)
		rig:tube(arm, {
			name = "WingArm",
			bone = function()
				return bone
			end,
			core = spec.armStyle,
			coreStep = 0.2,
		})
	
	local back = Vector3.zAxis
		for r, row in spec.rows do
			local n = math.max(3, math.floor(spec.feathers * (1 - (r - 1) * 0.25)))
			local scale = 1 - (r - 1) * 0.38
			for i = 1, n do
				local t = (i - 1) / (n - 1)
				local u = 1 + t * (#pts - 1)
				local p = arm:pos(u)
				local outward = pose:VectorToWorldSpace(v3(side, 0, 0))
				local sweep = rad(spec.sweep) * t
				local dir = (pose:VectorToWorldSpace(back) * math.cos(sweep) + outward * math.sin(sweep)).Unit
				local len = (spec.length[1] + (spec.length[2] - spec.length[1]) * (t ^ 1.4)) * scale
				local normal = pose:VectorToWorldSpace(Vector3.yAxis)
				local right = dir:Cross(normal).Unit
				local base = CFrame.fromMatrix(p + normal * 0.02 * (r - 1), right, dir, right:Cross(dir))
				local style = row[(i % #row) + 1]
				A.feather(rig, bone, base, len, spec.width * (0.85 + 0.3 * scale), style, if r == 1 then spec.tip else nil)
			end
		end
	end
	
--- Éventail de plumes (queue d'oiseau) partant de `base` (+Z local = vers l'arrière).
	function A.featherFan(rig: Rig, bone: string, base: CFrame, count: number, length: number, width: number, spread: number, styles: { Style }, tip: Style?)
		for i = 1, count do
			local t = if count == 1 then 0 else (i - 1) / (count - 1) - 0.5
			local dir = (base * ang(0, -t * rad(spread), 0)):VectorToWorldSpace(Vector3.zAxis)
			local right = dir:Cross(base.UpVector).Unit
			local fb = CFrame.fromMatrix(base.Position + base.UpVector * 0.01 * i, right, dir, base.UpVector)
			A.feather(rig, bone, fb, length * (1 - math.abs(t) * 0.35), width, styles[(i % #styles) + 1], tip)
		end
	end
	
-- ---------------------------------------------------------------------------
	-- Ornements : cristaux, engrenages, runes, anneaux, orbites
	-- ---------------------------------------------------------------------------
	
--- Grappe de cristaux autour de base.UpVector (le plus grand au centre).
	function A.crystals(rig: Rig, bone: string, base: CFrame, count: number, size: number, styles: { Style }, seed: number, spread: number?)
		local rng = Random.new(seed)
		for i = 1, count do
			local h, pos, yaw, tilt
			if i == 1 then
				h, pos, yaw, tilt = size, Vector3.zero, 0, rad(rng:NextNumber(0, 10))
			else
				local a = (i - 1) / (count - 1) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
				local r = (spread or 0.35) * size * rng:NextNumber(0.6, 1)
				h = size * rng:NextNumber(0.4, 0.75)
				pos = v3(math.cos(a) * r, 0, math.sin(a) * r)
				yaw = -a
				tilt = rad(rng:NextNumber(18, 40))
			end
			local c = base * cf(pos) * ang(0, yaw, 0) * ang(0, 0, -tilt) * ang(0, rng:NextNumber(0, 1.5), 0)
			rig:shard(bone, "Crystal", c, h * 0.3, h * 0.72, h * 0.34, styles[((i - 1) % #styles) + 1])
		end
	end
	
--- Engrenage dans le plan XY de `cf` (axe = Z) : couronne, dents, rayons, moyeu.
	function A.gear(rig: Rig, bone: string, c: CFrame, radius: number, teeth: number, thickness: number, style: Style, hub: Style?)
		rig:ring(bone, "Gear", c, radius * 0.8, radius * 0.24, thickness, math.max(teeth, 10), style)
		for i = 0, teeth - 1 do
			local a = i / teeth * math.pi * 2
			rig:block(bone, "GearTooth", c * ang(0, 0, a) * cf(radius * 1.0, 0, 0), v3(radius * 0.26, radius * 0.22, thickness), style)
		end
		for i = 0, 2 do
			rig:block(bone, "GearSpoke", c * ang(0, 0, i * math.pi / 3), v3(radius * 1.5, radius * 0.13, thickness * 0.8), style)
		end
		rig:cylinder(bone, "GearHub", (c * cf(0, 0, -thickness * 0.75)).Position, (c * cf(0, 0, thickness * 0.75)).Position, radius * 0.38, hub or style)
	end
	
local RUNES: { { { number } } } = {
		{ { 0, -1, 0, 1 }, { 0, 0.3, 0.65, 0.9 }, { 0, -0.1, 0.65, 0.5 } }, -- ᚠ
		{ { -0.5, -1, -0.5, 1 }, { -0.5, 1, 0.5, 0.2 }, { 0.5, 0.2, -0.5, -0.4 } }, -- ᚦ
		{ { 0, -1, 0, 1 }, { -0.6, 0.5, 0.6, -0.5 }, { -0.6, -0.5, 0.6, 0.5 } }, -- ᛟ-like
		{ { -0.45, -1, -0.45, 1 }, { 0.45, -1, 0.45, 1 }, { -0.45, 0.6, 0.45, 0 } }, -- ᛗ
		{ { 0, -1, 0, 1 }, { 0, 1, 0.6, 0.4 }, { 0, 1, -0.6, 0.4 } }, -- ᛏ
		{ { -0.6, 1, 0.6, -1 }, { 0.6, 1, -0.6, -1 } }, -- ᚷ
	}
	
--- Rune lumineuse dans le plan XY de `c` (face visible vers -Z local). `pattern` de 1 à 6.
	function A.rune(rig: Rig, bone: string, c: CFrame, size: number, style: Style, pattern: number)
		local glyph = RUNES[((pattern - 1) % #RUNES) + 1]
		for _, st in glyph do
			local a = (c * cf(st[1] * size * 0.5, st[2] * size * 0.5, 0)).Position
			local b = (c * cf(st[3] * size * 0.5, st[4] * size * 0.5, 0)).Position
			local mid = (a + b) / 2
			local dir = (b - a)
			local up = dir.Unit
			local right = up:Cross(c.LookVector).Unit
			rig:block(bone, "Rune", CFrame.fromMatrix(mid, right, up, right:Cross(up)), v3(size * 0.13, dir.Magnitude + size * 0.1, size * 0.05), style)
		end
	end
	
--- Anneau horizontal (ex. onde au sol, halo) centré en `center`.
	function A.flatRing(rig: Rig, bone: string, center: Vector3, radius: number, width: number, height: number, segments: number, style: Style)
		rig:ring(bone, "Ring", cf(center) * ang(math.pi / 2, 0, 0), radius, width, height, segments, style)
	end
	
--- Objets en orbite : crée l'os `name` (enfant de Root, tourné par l'animateur) au centre
	--- `center`, puis appelle `builder(name, repère, index)` pour chaque objet (+X local = vers l'extérieur).
	function A.orbit(rig: Rig, name: string, center: Vector3, radius: number, count: number, wobble: number, builder: (bone: string, c: CFrame, i: number) -> ())
		rig:bone(name, "Root", cf(center))
		for i = 1, count do
			local a = (i - 1) / count * math.pi * 2
			local y = math.sin(a * 2 + i) * wobble
			builder(name, cf(center + v3(math.cos(a) * radius, y, math.sin(a) * radius)) * ang(0, -a, 0), i)
		end
	end
	
return A

end

__modules["Vfx"] = function()
	--[[
		CreatureForge.Vfx
		-----------------
		Effets visuels avancés.
	
	À la construction (dans build, si rig.effects) :
		  • Vfx.beam      — rayon d'énergie / lien lumineux entre deux points (Beam + Attachments)
		  • Vfx.pillar    — colonne de lumière verticale
		  • Vfx.trail     — traînée derrière une partie mobile (bout d'aile, queue, griffes...)
		  • Vfx.rarityAura — aura de rareté : anneaux au sol qui tournent, colonnes de lumière,
		                    particules ascendantes ; plus intense de Commun à Mythique
		  • Vfx.abilityOrigin — point d'origine (Attachment) de la capacité spéciale
	
	À l'exécution (client, via CreatureAnimator) :
		  • Vfx.playAbility(model, ability) — onde de choc (ForceField), souffle, explosion,
		    éruption, éclair de lumière. Les pièces temporaires sont créées localement et nettoyées.
	]]
	
local Debris = game:GetService("Debris")
	local TweenService = game:GetService("TweenService")
	
local Kit = __require("Kit")
	local Fx = __require("Fx")
	local Rarity = __require("Rarity")
	local Types = __require("Types")
	
type Rig = Kit.Rig
	
local Vfx = {}
	
local v3 = Vector3.new
	local cf = CFrame.new
	
type BeamDef = {
		colors: { Color3 },
		transparency: { number }?,
		width0: number,
		width1: number?,
		curve0: number?,
		curve1: number?,
		lightEmission: number?,
		faceCamera: boolean?,
		segments: number?,
		texture: string?,
		textureSpeed: number?,
	}
	
type TrailDef = {
		colors: { Color3 },
		transparency: { number }?,
		lifetime: number,
		lightEmission: number?,
		widthScale: { number }?,
	}
	
--- Boîte englobante du corps (centres des pièces visibles, hors objets en orbite), espace Root.
	local function footprint(model: Model): (Vector3, Vector3)
		local root = model.PrimaryPart
		local ref = if root then root.CFrame else CFrame.identity
		local minV, maxV = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.95 and d.Parent and string.sub(d.Parent.Name, 1, 4) ~= "Aura" then
				local p = ref:PointToObjectSpace(d.CFrame.Position)
				minV = minV:Min(p)
				maxV = maxV:Max(p)
			end
		end
		if minV.X == math.huge then
			return Vector3.zero, Vector3.one
		end
		return (minV + maxV) / 2, maxV - minV
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
	
local function numberSeq(values: { number }, mul: number?): NumberSequence
		local m = mul or 1
		if #values == 1 then
			return NumberSequence.new(values[1] * m)
		end
		local kps = {}
		for i, v in values do
			table.insert(kps, NumberSequenceKeypoint.new((i - 1) / (#values - 1), v * m))
		end
		return NumberSequence.new(kps)
	end
	
-- ---------------------------------------------------------------------------
	-- Construction
	-- ---------------------------------------------------------------------------
	
--- Attachment sur l'os `bone` au point `pos` (espace modèle). `axis` oriente l'axe X
	--- (utilisé par la courbure des Beams) ; `up` oriente l'axe Y (émission des particules).
	function Vfx.attach(rig: Rig, bone: string, name: string, pos: Vector3, axis: Vector3?, up: Vector3?): Attachment
		local b = rig.bones[bone]
		assert(b, `Vfx: os inconnu "{bone}"`)
		local local0 = cf(pos)
		if up then
			local0 = Kit.lookAlong(pos, up) * CFrame.Angles(-math.pi / 2, 0, 0)
		elseif axis then
			local0 = Kit.lookAlong(pos, axis) * CFrame.Angles(0, math.pi / 2, 0)
		end
		local a = Instance.new("Attachment")
		a.Name = name
		a.CFrame = b.CFrame:ToObjectSpace(rig:toWorld(local0))
		a.Parent = b
		return a
	end
	
--- Rayon lumineux entre deux Attachments.
	function Vfx.beamBetween(rig: Rig, a0: Attachment, a1: Attachment, def: BeamDef): Beam
		local s = rig.scale
		local b = Instance.new("Beam")
		b.Name = "Beam"
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Color = colorSeq(def.colors)
		b.Transparency = numberSeq(def.transparency or { 0.2, 0.6 })
		b.Width0 = def.width0 * s
		b.Width1 = (def.width1 or def.width0) * s
		b.CurveSize0 = (def.curve0 or 0) * s
		b.CurveSize1 = (def.curve1 or 0) * s
		b.LightEmission = def.lightEmission or 1
		b.LightInfluence = 0
		b.FaceCamera = if def.faceCamera == nil then true else def.faceCamera
		b.Segments = def.segments or (if (def.curve0 or 0) ~= 0 or (def.curve1 or 0) ~= 0 then 12 else 1)
		if def.texture then
			b.Texture = def.texture
			b.TextureSpeed = def.textureSpeed or 1
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = 1 * s
		end
		b.Parent = a0.Parent
		return b
	end
	
--- Rayon lumineux de `p0` (os `bone0`) à `p1` (os `bone1`), en espace modèle.
	function Vfx.beam(rig: Rig, bone0: string, p0: Vector3, bone1: string, p1: Vector3, def: BeamDef, axis: Vector3?): Beam
		local a0 = Vfx.attach(rig, bone0, "BeamA", p0, axis)
		local a1 = Vfx.attach(rig, bone1, "BeamB", p1, axis)
		return Vfx.beamBetween(rig, a0, a1, def)
	end
	
--- Colonne de lumière verticale (s'amincit vers le haut).
	function Vfx.pillar(rig: Rig, bone: string, base: Vector3, height: number, width: number, color: Color3): Beam
		return Vfx.beam(rig, bone, base, bone, base + v3(0, height, 0), {
			colors = { color, color:Lerp(Color3.new(1, 1, 1), 0.35) },
			transparency = { 0.3, 0.65, 1 },
			width0 = width,
			width1 = width * 0.25,
			lightEmission = 1,
		})
	end
	
--- Traînée entre deux points d'un os (visible quand l'os bouge : battements, queue...).
	function Vfx.trail(rig: Rig, bone: string, p0: Vector3, p1: Vector3, def: TrailDef): Trail
		local a0 = Vfx.attach(rig, bone, "TrailA", p0)
		local a1 = Vfx.attach(rig, bone, "TrailB", p1)
		local t = Instance.new("Trail")
		t.Name = "Trail"
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Color = colorSeq(def.colors)
		t.Transparency = numberSeq(def.transparency or { 0.2, 1 })
		t.Lifetime = def.lifetime
		t.LightEmission = def.lightEmission or 1
		t.LightInfluence = 0
		t.MinLength = 0.02 * rig.scale
		t.FaceCamera = true
		if def.widthScale then
			t.WidthScale = numberSeq(def.widthScale)
		end
		t.Parent = a0.Parent
		return t
	end
	
--- Positions des objets créés par Anatomy.orbit (même formule).
	function Vfx.orbitPoints(center: Vector3, radius: number, count: number, wobble: number): { Vector3 }
		local out = {}
		for i = 1, count do
			local a = (i - 1) / count * math.pi * 2
			table.insert(out, center + v3(math.cos(a) * radius, math.sin(a * 2 + i) * wobble, math.sin(a) * radius))
		end
		return out
	end
	
--- Liens d'énergie entre chaque objet en orbite et un point de la créature (ils suivent la rotation).
	function Vfx.orbitTethers(rig: Rig, aura: string, pts: { Vector3 }, bone: string, target: Vector3, def: BeamDef)
		local hub = Vfx.attach(rig, bone, "TetherHub", target, v3(0, 1, 0))
		for _, p in pts do
			Vfx.beamBetween(rig, Vfx.attach(rig, aura, "Tether", p, (target - p).Unit), hub, def)
		end
	end
	
--- Anneau d'énergie reliant les objets en orbite entre eux.
	function Vfx.orbitRing(rig: Rig, aura: string, pts: { Vector3 }, def: BeamDef)
		local atts = {}
		for _, p in pts do
			table.insert(atts, Vfx.attach(rig, aura, "Link", p))
		end
		for i, a in atts do
			Vfx.beamBetween(rig, a, atts[(i % #atts) + 1], def)
		end
	end
	
--- Traînées aux bouts des deux ailes (`tip` = bout de l'aile droite, `toward` = vers le bord de fuite).
	function Vfx.wingTrails(rig: Rig, tip: Vector3, toward: Vector3, def: TrailDef)
		for _, side in { 1, -1 } do
			local p = v3(side * tip.X, tip.Y, tip.Z)
			local q = p + v3(side * toward.X, toward.Y, toward.Z)
			Vfx.trail(rig, if side > 0 then "Wing_R" else "Wing_L", p, q, def)
		end
	end
	
--- Point d'origine de la capacité spéciale (souffle) : Attachment "AbilityOrigin" orienté
	--- (+Y) dans la direction du souffle.
	function Vfx.abilityOrigin(rig: Rig, ability: Types.Ability)
		local bone = ability.bone or "Head"
		if ability.origin and rig.bones[bone] then
			Vfx.attach(rig, bone, "AbilityOrigin", ability.origin, nil, ability.direction or v3(0, 0, -1))
		end
	end
	
local AURA = {
		Common = { rings = 1, pillars = 0, rate = 4 },
		Rare = { rings = 1, pillars = 2, rate = 8 },
		Epic = { rings = 2, pillars = 4, rate = 11 },
		Legendary = { rings = 2, pillars = 6, rate = 15 },
		Mythic = { rings = 3, pillars = 8, rate = 20 },
		Exotic = { rings = 3, pillars = 12, rate = 26 },
		Exclusive = { rings = 3, pillars = 12, rate = 26 },
		Chaotic = { rings = 3, pillars = 14, rate = 32 },
	}
	
--- Couleur n°i d'une rareté : arc-en-ciel (Exotique), noir et or (Exclusif), glitch (Chaotique).
	local function tierColor(tier: Rarity.Tier, i: number): Color3
		if tier.rainbow then
			return Rarity.RAINBOW[(i - 1) % #Rarity.RAINBOW + 1]
		elseif tier.glitch then
			local g = { Rarity.GLITCH[1], Rarity.GLITCH[2], Rarity.GLITCH[3], Rarity.GLITCH[4] }
			return g[(i - 1) % #g + 1]
		end
		return tier.color
	end
	
--- Aura de rareté autour des pieds de la créature (à appeler en fin de construction).
	function Vfx.rarityAura(rig: Rig, rarityId: string)
		if not rig.effects then
			return
		end
		local tier = Rarity.get(rarityId)
		local cfg = AURA[rarityId] or AURA.Common
		local center, size = footprint(rig.model)
		local s = rig.scale
		local c = v3(center.X / s, 0.04, center.Z / s)
		local r = math.max(size.X, size.Z) / s * 0.42 + 0.4
	
	-- Anneaux au sol (os "AuraGround" : tourne lentement)
		if cfg.rings > 0 then
			rig:bone("AuraGround", "Root", cf(c))
			local glow = Kit.style(tier.color, Enum.Material.Neon, { transparency = 0.35, castShadow = false })
			local soft = Kit.style(tier.light, Enum.Material.Neon, { transparency = 0.6, castShadow = false })
			if tier.gold then -- Exclusif : anneau noir serti d'or
				soft = Kit.style(tier.dark, Enum.Material.SmoothPlastic, { castShadow = false })
			end
			for k = 1, cfg.rings do
				local rr = r * (1 - (k - 1) * 0.16)
				local st = if k == 1 then glow else soft
				if tier.rainbow or tier.glitch then
					st = Kit.style(tierColor(tier, k * 2), Enum.Material.Neon, { transparency = 0.35, castShadow = false })
				end
				rig:ring("AuraGround", "AuraRing", cf(c) * CFrame.Angles(math.pi / 2, 0, 0), rr, 0.07 + 0.03 * (cfg.rings - k), 0.02, 36, st)
			end
			-- Graduations runiques
			local ticks = if cfg.rings >= 2 then 12 else 6
			for i = 1, ticks do
				local a = i / ticks * math.pi * 2
				local st = if tier.rainbow or tier.glitch then Kit.style(tierColor(tier, i), Enum.Material.Neon, { castShadow = false }) else glow
				rig:block("AuraGround", "AuraTick", cf(c) * CFrame.Angles(0, a, 0) * cf(0, 0, -r * 0.92), v3(0.05, 0.02, 0.22), st)
			end
		end
	
	-- Colonnes de lumière
		for i = 1, cfg.pillars do
			local a = i / cfg.pillars * math.pi * 2 + 0.3
			local h = (if i % 2 == 0 then 2.2 else 3.2) * (0.6 + r * 0.25)
			Vfx.pillar(rig, "Root", c + v3(math.cos(a) * r, 0, math.sin(a) * r), h, 0.22 + r * 0.04, tierColor(tier, i))
		end
	
	-- Particules ascendantes
		local disc = rig:anchor("Root", "FX_RarityAura", cf(c + v3(0, 0.1, 0)), v3(r * 2, 0.1, r * 2))
		Fx.particles(disc, {
			name = "RarityMotes",
			texture = Fx.TEXTURES.sparkle,
			colors = if tier.rainbow or tier.glitch then { tierColor(tier, 1), tierColor(tier, 2), tierColor(tier, 3) } else { tier.light, tier.color },
			sizes = { 0.16, 0.28, 0 },
			transparencies = { 0.1, 0.25, 1 },
			lifetime = NumberRange.new(1.6, 2.8),
			rate = cfg.rate,
			speed = NumberRange.new(0.6, 1.4),
			spread = Vector2.new(8, 8),
			acceleration = v3(0, 0.3, 0),
			lightEmission = 1,
			rotation = NumberRange.new(0, 360),
			volume = true,
		}, s)
		if cfg.pillars >= 6 then
			Fx.light(disc, { color = tier.color, range = r * 3, brightness = 1.2 }, s)
		end
	end
	
-- ---------------------------------------------------------------------------
	-- Exécution : capacités spéciales (client)
	-- ---------------------------------------------------------------------------
	
local TEX = {
		sparkle = Fx.TEXTURES.sparkle,
		fire = Fx.TEXTURES.fire,
		smoke = Fx.TEXTURES.smoke,
		spark = Fx.TEXTURES.spark,
	}
	
local folder: Folder? = nil
	local function vfxFolder(): Folder
		if folder and folder.Parent then
			return folder
		end
		local f = Instance.new("Folder")
		f.Name = "CreatureVfx"
		f.Parent = workspace
		folder = f
		return f
	end
	
local function tempPart(c: CFrame, size: Vector3, color: Color3, material: Enum.Material, transparency: number, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = material
		p.Color = color
		p.Transparency = transparency
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.CFrame = c
		p.Parent = vfxFolder()
		return p
	end
	
--- Onde de choc : anneau d'énergie (ForceField) qui s'étend + disque lumineux.
	local function shockwave(at: CFrame, radius: number, color: Color3, duration: number)
		local ring = tempPart(at * CFrame.Angles(0, 0, math.pi / 2), v3(0.4, 1, 1), color, Enum.Material.ForceField, 0, Enum.PartType.Cylinder)
		TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = v3(0.15, radius * 2, radius * 2),
			Transparency = 1,
		}):Play()
		local disc = tempPart(at * CFrame.Angles(0, 0, math.pi / 2), v3(0.05, 1, 1), color, Enum.Material.Neon, 0.3, Enum.PartType.Cylinder)
		TweenService:Create(disc, TweenInfo.new(duration * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = v3(0.05, radius * 1.4, radius * 1.4),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ring, duration + 0.1)
		Debris:AddItem(disc, duration + 0.1)
	end
	
--- Dôme d'énergie qui gonfle puis disparaît.
	local function dome(at: CFrame, radius: number, color: Color3, duration: number)
		local ball = tempPart(at, v3(1, 1, 1), color, Enum.Material.ForceField, 0, Enum.PartType.Ball)
		TweenService:Create(ball, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = Vector3.one * radius * 2,
			Transparency = 1,
		}):Play()
		Debris:AddItem(ball, duration + 0.1)
	end
	
--- Éclair de lumière.
	local function flash(at: CFrame, radius: number, color: Color3, duration: number)
		local p = tempPart(at, Vector3.one * 0.2, color, Enum.Material.SmoothPlastic, 1)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = radius * 3
		l.Brightness = 6
		l.Parent = p
		TweenService:Create(l, TweenInfo.new(duration, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
		Debris:AddItem(p, duration + 0.1)
	end
	
--- Gerbe de particules (Emit) depuis `at`.
	local function burst(at: CFrame, count: number, def: Fx.ParticleDef, scale: number, lifetime: number)
		local p = tempPart(at, Vector3.one * 0.5 * scale, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
		local e = Fx.particles(p, def, scale)
		e.Enabled = false
		e:Emit(count)
		Debris:AddItem(p, lifetime + 0.2)
	end
	
local function emitDef(name: string, colors: { Color3 }, texture: string, size: number, speed: number, spread: number, lifetime: number, accel: Vector3?): Fx.ParticleDef
		return {
			name = name,
			texture = texture,
			colors = colors,
			sizes = { size, size * 0.7, 0 },
			transparencies = { 0, 0.2, 1 },
			lifetime = NumberRange.new(lifetime * 0.6, lifetime),
			rate = 0,
			speed = NumberRange.new(speed * 0.6, speed),
			spread = Vector2.new(spread, spread),
			acceleration = accel,
			drag = 2,
			lightEmission = 1,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-200, 200),
		}
	end
	
--- Joue la capacité spéciale `ability` sur `model` (à appeler côté client).
	function Vfx.playAbility(model: Model, ability: Types.Ability)
		local root = model.PrimaryPart
		if not root then
			return
		end
		local scale = (model:GetAttribute("Scale") :: number?) or 1
		local duration = ability.duration or 1.6
		local c1 = ability.colors[1]
		local c2 = ability.colors[2] or c1
		local c3 = ability.colors[3] or Color3.new(1, 1, 1)
		local tex = TEX[ability.texture or "sparkle"] or Fx.TEXTURES.sparkle
		local radius = (ability.radius or 5) * scale
		local ground = root.CFrame * cf(0, 0.15 * scale, 0)
		local center = footprint(model)
		local body = root.CFrame * cf(center)
	
	if ability.kind == "Breath" then
			local origin = model:FindFirstChild("AbilityOrigin", true)
			if origin and origin:IsA("Attachment") then
				local e = Fx.particles(origin, {
					name = "Breath",
					texture = tex,
					colors = { c3, c1, c2 },
					sizes = { 0.4, 1.4, 2.2 },
					transparencies = { 0.1, 0.3, 1 },
					lifetime = NumberRange.new(0.5, 0.8),
					rate = 120,
					speed = NumberRange.new(14, 20),
					spread = Vector2.new(12, 12),
					drag = 2,
					lightEmission = 1,
					rotation = NumberRange.new(0, 360),
					rotSpeed = NumberRange.new(-180, 180),
				}, scale)
				local l = Instance.new("PointLight")
				l.Color = c1
				l.Range = 10 * scale
				l.Brightness = 3
				l.Parent = origin
				task.delay(duration, function()
					e.Enabled = false
					l:Destroy()
				end)
				Debris:AddItem(e, duration + 1)
			end
			flash(body, radius, c1, duration * 0.6)
		elseif ability.kind == "Stomp" then
			shockwave(ground, radius, c1, 0.9)
			task.delay(0.15, shockwave, ground, radius * 0.7, c2, 0.8)
			burst(ground, 40, emitDef("Debris", { c2, c1 }, Fx.TEXTURES.spark, 0.3, 14, 70, 1.2, v3(0, -18, 0)), scale, 1.2)
			burst(ground, 20, emitDef("Dust", { Color3.fromRGB(180, 170, 150), c2 }, Fx.TEXTURES.smoke, 1.6, 6, 85, 1.4), scale, 1.4)
			flash(ground, radius, c1, 0.6)
		elseif ability.kind == "Burst" then
			dome(body, radius * 0.6, c1, 0.7)
			burst(body, 60, emitDef("Shards", { c3, c1, c2 }, tex, 0.35, 16, 180, 1.0), scale, 1.0)
			shockwave(ground, radius, c2, 0.8)
			flash(body, radius, c1, 0.7)
		elseif ability.kind == "Eruption" then
			burst(body, 50, emitDef("Eruption", { c3, c1, c2 }, Fx.TEXTURES.fire, 0.9, 22, 25, 1.4, v3(0, -14, 0)), scale, 1.4)
			burst(body, 40, emitDef("Embers", { c3, c1 }, Fx.TEXTURES.spark, 0.25, 26, 35, 1.8, v3(0, -10, 0)), scale, 1.8)
			shockwave(ground, radius, c1, 1.0)
			flash(body, radius * 1.5, c1, 1.0)
		else -- "Nova"
			dome(body, radius * 0.8, c1, 0.8)
			task.delay(0.12, dome, body, radius, c2, 0.9)
			shockwave(ground, radius * 1.2, c1, 1.0)
			burst(body, 70, emitDef("Nova", { c3, c1, c2 }, tex, 0.5, 18, 180, 1.2), scale, 1.2)
			flash(body, radius * 1.5, c1, 0.9)
		end
	end
	
return Vfx

end

__modules["SphinxStellaire"] = function()
	--[[
		LE SPHINX STELLAIRE — Exclusif · Géant
		======================================
		Sphinx dont les ailes sont remplies d'étoiles (roue uniquement).
	
	• Corps de lion au pelage de sable doré, pattes cerclées de bracelets d'or et de lapis.
		• Tête de pharaon : visage serein, yeux soulignés de khôl lumineux turquoise, barbe d'or,
		  coiffe némès rayée lapis/or, cobra dressé sur le front.
		• Grandes ailes : panneaux de ciel nocturne remplis d'étoiles Neon reliées en constellations,
		  bords dorés.
		• Selle d'apparat (monture avec passager).
		• Petites pyramides d'or et étoiles en orbite ; effets : poussière d'étoiles, lueur bleue et or.
	]]
	
local Kit = __require("Kit")
	local A = __require("Anatomy")
	local Fx = __require("Fx")
	local Vfx = __require("Vfx")
	local Types = __require("Types")
	
local S = Kit.style
	local M = Enum.Material
	local rgb = Color3.fromRGB
	local rad = math.rad
	local v3 = Vector3.new
	local cf = CFrame.new
	local ang = CFrame.Angles
	
local ID = "SphinxStellaire"
	
local P = {
		core = S(rgb(150, 110, 60)),
		fur = { S(rgb(246, 210, 140)), S(rgb(226, 184, 110)), S(rgb(200, 154, 86)), S(rgb(166, 122, 64)) },
		furTip = S(rgb(255, 236, 190)),
		skin = S(rgb(214, 160, 100)),
		gold = S(rgb(255, 204, 64), M.Metal, { reflectance = 0.1 }),
		goldDark = S(rgb(200, 130, 24), M.Metal),
		lapis = S(rgb(30, 60, 170)),
		lapisDark = S(rgb(16, 30, 100)),
		kohl = S(rgb(60, 240, 230), M.Neon),
		eye = S(rgb(255, 255, 255), M.Neon),
		socket = S(rgb(20, 14, 10)),
		night = { S(rgb(16, 20, 70), M.Glass, { transparency = 0.1 }), S(rgb(30, 22, 90), M.Glass, { transparency = 0.1 }), S(rgb(10, 30, 80), M.Glass, { transparency = 0.1 }) },
		star = S(rgb(255, 255, 255), M.Neon),
		starGold = S(rgb(255, 230, 140), M.Neon),
		starBlue = S(rgb(150, 210, 255), M.Neon),
		line = S(rgb(170, 200, 255), M.Neon, { transparency = 0.45 }),
		cobra = S(rgb(255, 200, 60), M.Metal),
		ruby = S(rgb(255, 50, 70), M.Neon),
		pad = S(rgb(110, 70, 40)),
		claw = S(rgb(250, 240, 220)),
	}
	
local BODY = Kit.spine({
		{ pos = v3(0, 2.55, -1.3), rx = 0.3, ry = 0.32 },
		{ pos = v3(0, 2.2, -0.95), rx = 0.52, ry = 0.58 },
		{ pos = v3(0, 2.0, -0.35), rx = 0.56, ry = 0.58 },
		{ pos = v3(0, 2.02, 0.3), rx = 0.55, ry = 0.55 },
		{ pos = v3(0, 2.0, 0.85), rx = 0.52, ry = 0.5 },
		{ pos = v3(0, 1.85, 1.2), rx = 0.3, ry = 0.3 },
	})
	
local TAIL = Kit.spine({
		{ pos = v3(0, 1.92, 1.25), rx = 0.12, ry = 0.12 },
		{ pos = v3(0, 1.6, 1.7), rx = 0.1, ry = 0.1 },
		{ pos = v3(0.15, 1.45, 2.2), rx = 0.09, ry = 0.09 },
		{ pos = v3(0.35, 1.7, 2.6), rx = 0.07, ry = 0.07 },
		{ pos = v3(0.42, 2.0, 2.75), rx = 0.05, ry = 0.05 },
	})
	
local ABILITY: Types.Ability = {
		name = "Énigme stellaire",
		kind = "Nova",
		colors = { rgb(150, 200, 255), rgb(255, 210, 90), rgb(255, 255, 255) },
		texture = "sparkle",
		radius = 9,
	}
	
local function build(opts: Kit.BuildOptions?): Model
		local rig = Kit.newRig(ID, opts)
		local function const(name: string): (number) -> string
			return function()
				return name
			end
		end
	
	rig:bone("Body", "Root", cf(0, 2.0, 0))
		rig:bone("Head", "Body", cf(0, 2.75, -1.4))
		rig:mirrored(function(side, sfx)
			local s = string.sub(sfx, 2)
			rig:bone("Leg_F" .. s, "Body", cf(side * 0.36, 1.85, -0.8))
			rig:bone("Leg_B" .. s, "Body", cf(side * 0.38, 1.9, 0.75))
			rig:bone("Wing" .. sfx, "Body", cf(side * 0.4, 2.45, -0.5))
		end)
		local tj = {}
		for i = 1, #TAIL.sections do
			table.insert(tj, TAIL:pos(i))
		end
		local tail = rig:boneChain("Tail", "Body", tj)
	
	-- Corps de lion
		rig:tube(BODY, {
			name = "Body",
			bone = const("Body"),
			core = P.core,
			coreStep = 0.28,
			cover = { A.fur(P.fur, P.furTip, v3(0.24, 0.32, 0.32), 0.19, { arc = 170, refRadius = 0.5, seed = 1 }) },
		})
		-- Collier pectoral d'or et de lapis
		for k = 0, 2 do
			rig:band(BODY, "Body", "Pectoral", 1.55 + k * 0.18, 0.1, 0.05, if k % 2 == 0 then P.gold else P.lapis)
		end
		rig:shard("Body", "PectoralGem", BODY:surface(1.8, 180, 0.08) * ang(math.pi, 0, 0), 0.16, 0.14, 0.12, P.ruby)
		-- Selle d'apparat
		local saddle = BODY:surface(3.9, 0, 0.12)
		rig:prism("Body", "SaddleCloth", saddle * cf(0, -0.03, 0), v3(1.2, 0.06, 1.1), 0.04, P.lapis)
		rig:mirrored(function(side)
			local flap = saddle * cf(side * 0.62, -0.32, 0) * ang(0, 0, side * rad(64))
			rig:prism("Body", "SaddleFlap", flap, v3(0.6, 0.05, 1.0), 0.03, P.lapis)
			for k = -1, 1 do
				rig:block("Body", "SaddleStripe", flap * cf(0, 0.01, k * 0.3), v3(0.62, 0.06, 0.08), P.gold)
			end
		end)
		rig:prism("Body", "Saddle", saddle * cf(0, 0.08, 0), v3(0.75, 0.14, 0.8), 0.06, P.gold)
		rig:seat("Body", saddle * cf(0, 0.2, 0), v3(0.7, 0.2, 0.7))
	
	-- Tête de pharaon
		rig:ball("Head", "Face", v3(0, 2.95, -1.62), 0.62, P.skin)
		rig:prismBetween("Head", "Nose", v3(0, 3.0, -1.88), v3(0, 2.88, -1.95), 0.1, 0.08, 0.02, P.skin)
		rig:block("Head", "Mouth", cf(0, 2.78, -1.9), v3(0.14, 0.025, 0.03), P.goldDark)
		rig:prismBetween("Head", "Beard", v3(0, 2.7, -1.85), v3(0, 2.38, -1.88), 0.12, 0.1, 0.02, P.gold)
		for k = 0, 3 do
			rig:block("Head", "BeardBand", cf(0, 2.65 - k * 0.08, -1.87), v3(0.13, 0.025, 0.11), P.lapis)
		end
		rig:mirrored(function(side)
			rig:ball("Head", "Eye", A.mx(v3(0.11, 3.03, -1.88), side), 0.08, P.eye)
			rig:ball("Head", "Pupil", A.mx(v3(0.11, 3.03, -1.92), side), 0.04, P.socket)
			rig:strut("Head", "Kohl", A.mx(v3(0.05, 3.07, -1.9), side), A.mx(v3(0.24, 3.04, -1.84), side), 0.025, 0.02, P.kohl)
			rig:strut("Head", "Kohl", A.mx(v3(0.18, 3.05, -1.86), side), A.mx(v3(0.24, 2.98, -1.82), side), 0.02, 0.02, P.kohl)
			rig:wedge("Head", "Brow", cf(A.mx(v3(0.12, 3.12, -1.88), side)) * ang(0, 0, side * rad(-10)), v3(0.18, 0.03, 0.04), P.lapisDark)
		end)
		-- Coiffe némès : calotte + pans rayés tombant sur les épaules
		local nemes = Kit.spine({
			{ pos = v3(0, 3.06, -1.85), rx = 0.36, ry = 0.24 },
			{ pos = v3(0, 3.14, -1.6), rx = 0.4, ry = 0.32 },
			{ pos = v3(0, 3.0, -1.32), rx = 0.36, ry = 0.3 },
			{ pos = v3(0, 2.75, -1.18), rx = 0.18, ry = 0.14 },
		})
		rig:tube(nemes, { name = "Nemes", bone = const("Head"), core = P.lapis, coreStep = 0.1 })
		for k = 0, 5 do
			local u = 1.2 + k * 0.32
			rig:band(nemes, "Head", "NemesStripe", u, 0.05, 0.02, P.gold)
		end
		rig:mirrored(function(side)
			for k = 0, 4 do
				local top = A.mx(v3(0.32 + k * 0.02, 3.0 - k * 0.04, -1.72 + k * 0.03), side)
				local bot = A.mx(v3(0.4 + k * 0.03, 2.35, -1.62 + k * 0.03), side)
				rig:prismBetween("Head", "Lappet", top, bot, 0.08, 0.05, 0.01, if k % 2 == 0 then P.gold else P.lapis)
			end
		end)
		rig:band(nemes, "Head", "Diadem", 1.15, 0.06, 0.04, P.gold)
		-- Cobra dressé sur le front
		A.horn(rig, "Head", { v3(0, 3.2, -1.86), v3(0, 3.3, -1.95), v3(0, 3.42, -1.92) }, 0.05, 0.03, P.cobra)
		rig:prism("Head", "CobraHood", cf(0, 3.42, -1.93), v3(0.14, 0.12, 0.03), 0.03, P.cobra)
		rig:ball("Head", "CobraGem", v3(0, 3.42, -1.95), 0.05, P.ruby)
	
	-- Ailes : panneaux de ciel nocturne remplis d'étoiles
		rig:mirrored(function(side, sfx)
			local w = "Wing" .. sfx
			local arm = { v3(0.4, 2.45, -0.5), v3(1.3, 3.1, -0.35), v3(2.3, 3.45, 0.1), v3(3.2, 3.5, 0.6) }
			local mp = {}
			for _, p in arm do
				table.insert(mp, A.mx(p, side))
			end
			A.limb(rig, w, side, { { arm[1], 0.15, 0.15 }, { arm[2], 0.12, 0.12 }, { arm[3], 0.09, 0.09 } }, P.gold)
			rig:strut(w, "WingBone", mp[3], mp[4], 0.08, 0.08, P.gold)
			local tips = { mp[4], A.mx(v3(3.3, 2.6, 1.25), side), A.mx(v3(2.7, 1.95, 1.55), side), A.mx(v3(1.8, 1.9, 1.45), side), A.mx(v3(0.9, 2.2, 0.85), side) }
			local tris = {}
			for t = 1, #tips - 1 do
				table.insert(tris, { mp[3], tips[t], tips[t + 1] })
			end
			table.insert(tris, { mp[1], mp[3], tips[#tips] })
			table.insert(tris, { mp[1], mp[2], mp[3] })
			for i, tri in tris do
				A.triangle(rig, w, "StarSky", tri[1], tri[2], tri[3], 0.04, P.night[(i % 3) + 1])
			end
			-- Bord doré
			for t = 1, #tips - 1 do
				rig:strut(w, "WingEdge", tips[t], tips[t + 1], 0.05, 0.05, P.gold)
			end
			-- Étoiles dans les panneaux + constellations
			local rng = Random.new(7 + side)
			local prev: Vector3? = nil
			for i = 1, 34 do
				local tri = tris[rng:NextInteger(1, #tris)]
				local a, b = rng:NextNumber(), rng:NextNumber()
				if a + b > 1 then
					a, b = 1 - a, 1 - b
				end
				local p = tri[1] + (tri[2] - tri[1]) * a + (tri[3] - tri[1]) * b + v3(0, 0.04, 0)
				local st = if i % 5 == 0 then P.starGold elseif i % 3 == 0 then P.starBlue else P.star
				if i % 4 == 0 then
					rig:block(w, "Star", cf(p), v3(0.05, 0.28, 0.05), st)
					rig:block(w, "Star", cf(p) * ang(0, 0, math.pi / 2), v3(0.05, 0.28, 0.05), st)
				else
					rig:ball(w, "Star", p, rng:NextNumber(0.06, 0.12), st)
				end
				if prev and i % 6 ~= 0 and i <= 12 then
					rig:strut(w, "Constellation", prev, p, 0.02, 0.02, P.line)
				end
				prev = p
			end
		end)
	
	-- Pattes de lion
		rig:mirrored(function(side, sfx)
			local s = string.sub(sfx, 2)
			for key, L in { F = { v3(0.36, 1.85, -0.8), v3(0.4, 1.05, -0.88), v3(0.4, 0.3, -0.95), 0.3 }, B = { v3(0.38, 1.9, 0.75), v3(0.44, 1.15, 0.98), v3(0.42, 0.3, 0.86), 0.4 } } do
				local bone = "Leg_" .. key .. s
				A.limb(rig, bone, side, { { L[1], L[4], L[4] * 1.15 }, { L[2], 0.16, 0.16 }, { L[3], 0.12, 0.12 } }, P.core, A.fur(P.fur, P.furTip, v3(0.16, 0.24, 0.22), 0.13, { arc = 180, refRadius = 0.18, seed = 10 + side }))
				A.paw(rig, bone, A.mx((L[3] :: Vector3) - v3(0, 0.2, 0.06), side), v3(0, 0, -1), 0.36, 4, P.pad, P.fur[3], P.claw)
				local wrist = A.mx((L[2] :: Vector3):Lerp(L[3] :: Vector3, 0.6), side)
				rig:ring(bone, "Bracelet", cf(wrist) * ang(math.pi / 2, 0, 0), 0.16, 0.05, 0.1, 12, P.gold)
				rig:ring(bone, "Bracelet", cf(wrist - v3(0, 0.1, 0)) * ang(math.pi / 2, 0, 0), 0.15, 0.04, 0.06, 12, P.lapis)
			end
		end)
	
	-- Queue à touffe d'or
		rig:tube(TAIL, {
			name = "Tail",
			bone = function(u)
				return tail[math.clamp(math.floor(u), 1, #tail)]
			end,
			core = P.core,
			coreStep = 0.14,
			cover = { A.fur(P.fur, nil, v3(0.1, 0.16, 0.14), 0.09, { arc = 180, refRadius = 0.08, seed = 6 }) },
		})
		A.tuftBurst(rig, tail[#tail], A.alongUp(TAIL:pos(5), TAIL:pos(5) - TAIL:pos(4)), 9, 0.32, 0.12, { P.lapis, P.goldDark }, P.starGold, 40, 7)
	
	-- Pyramides d'or et étoiles en orbite
		A.orbit(rig, "Aura1", v3(0, 2.6, 0), 3.4, 8, 0.5, function(bone, c, i)
			if i % 2 == 0 then
				rig:thorn(bone, "Pyramid", c * cf(0, -0.2, 0), 0.5, 0.45, P.gold)
			else
				rig:block(bone, "OrbitStar", c, v3(0.08, 0.55, 0.08), P.star)
				rig:block(bone, "OrbitStar", c * ang(0, 0, math.pi / 2), v3(0.08, 0.55, 0.08), P.star)
				rig:ball(bone, "OrbitStarCore", c.Position, 0.16, P.starBlue)
			end
		end)
	
	rig:hitbox(cf(0, 2.0, 0), v3(2.4, 4, 5))
	
	if rig.effects then
			local sc = rig.scale
			local g = rig:anchor("Body", "FX_Stars", cf(0, 2.8, 0), v3(3, 1.6, 3))
			Fx.particles(g, Fx.sparkles("Stardust", { rgb(255, 255, 255), rgb(150, 200, 255), rgb(255, 220, 120) }, 14, 0.22, 0.1), sc)
			Fx.light(g, { color = rgb(140, 180, 255), range = 16, brightness = 1.5 }, sc)
			Fx.light(rig.bones.Head, { color = rgb(255, 210, 120), range = 8, brightness = 1 }, sc)
			Vfx.orbitRing(rig, "Aura1", Vfx.orbitPoints(v3(0, 2.6, 0), 3.4, 8, 0.5), { colors = { rgb(170, 210, 255), rgb(255, 220, 120) }, transparency = { 0.35, 0.7 }, width0 = 0.06, curve0 = 0.6, curve1 = -0.6 })
			Vfx.abilityOrigin(rig, ABILITY)
			Vfx.rarityAura(rig, "Exclusive")
		end
	
	return rig:finish({ Rarity = "Exclusive" })
	end
	
local Def: Types.CreatureDef = {
		Id = ID,
		DisplayName = "Sphinx stellaire",
		Rarity = "Exclusive",
		Size = "Giant",
		Income = 11000000,
		SpeedBonus = 2.2,
		Passenger = true,
		Source = "Roue",
		Scale = 2.4,
		Category = "Créature Exclusive",
		Description = "Gardien des énigmes au visage de pharaon ; ses ailes sont un morceau de ciel nocturne rempli d'étoiles.",
		Icon = { top = rgb(30, 40, 120), bottom = rgb(6, 6, 20), glow = rgb(255, 220, 120), motif = rgb(150, 200, 255), yaw = 30, pitch = 10, zoom = 1.0 },
		Animation = { gait = "Quadruped", breathe = 0.035, bob = 0.1, stride = 26, strideRate = 8, tailSway = 14, tailRate = 1.3, headLook = 14, auraSpeed = 0.45 },
		Ability = ABILITY,
		build = build,
	}
	
return Def

end

-- ============================================================================
-- Entrée
-- ============================================================================
do
	-- Réglages : mutations cumulées, ex. { "Kintsugi", "Vitrail" } (Mousse, Kintsugi, Vitrail, Horloger,
	-- Mirage, Encre, Aurore, Fossile, Constellation, Echo, Paradoxe) et échelle (nil = taille par défaut).
	local MUTATIONS = nil
	local SCALE = nil

	local def = __require("SphinxStellaire")
	if not def.Id then -- module à plusieurs créatures : on prend celle-ci
		for _, d in def do
			if d.Id == "SphinxStellaire" then
				def = d
			end
		end
	end
	local Icon = __require("Icon")
	local Mutations = __require("Mutations")

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
	local model = def.build({ cframe = CFrame.lookAt(ground, ground - look), scale = SCALE or def.Scale })
	if MUTATIONS then
		Mutations.apply(model, MUTATIONS)
	end
	model.Parent = workspace

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
	Icon.build(def, tray, { mutations = MUTATIONS })

	pcall(function()
		game:GetService("Selection"):Set({ model })
	end)
	pcall(function()
		game:GetService("ChangeHistoryService"):SetWaypoint("CreatureForge : " .. def.DisplayName)
	end)
	print(("[CreatureForge] %s créé (%d pièces) à %s"):format(def.DisplayName, model:GetAttribute("PartCount"), tostring(ground)))
end
