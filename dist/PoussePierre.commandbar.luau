-- CreatureForge — PoussePierre
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
		mutation: string?, -- id de mutation (appliquée par CreatureForge.spawn / Icon.build)
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
		Exotic = tier("Exotic", "EXOTIQUE", 7, Color3.fromRGB(255, 120, 40), Color3.fromRGB(255, 220, 150), Color3.fromRGB(150, 30, 10)),
		Exclusive = tier("Exclusive", "EXCLUSIF", 8, Color3.fromRGB(40, 240, 220), Color3.fromRGB(200, 255, 250), Color3.fromRGB(10, 110, 120)),
	}
	
--- Zones de la carte (canyon) : du haut vers le fond.
	Rarity.Zones = {
		{ id = "Surface", label = "1. LA SURFACE", rarities = { "Common", "Uncommon" } },
		{ id = "PenteBrumeuse", label = "2. LA PENTE BRUMEUSE", rarities = { "Rare", "Epic" } },
		{ id = "GrottesCristal", label = "3. LES GROTTES DE CRISTAL", rarities = { "Legendary", "Mythic" } },
		{ id = "Abysse", label = "4. L'ABYSSE PROFOND", rarities = { "Exotic", "Exclusive" } },
	}
	
function Rarity.get(id: string): Tier
		return Rarity.Tiers[id] or Rarity.Tiers.Common
	end
	
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
		Variantes rares applicables à N'IMPORTE QUELLE créature après sa construction :
		recoloration (dégradé selon la luminosité de chaque pièce), matériau, lueur des parties
		Neon, particules et lumière dédiées, multiplicateur de valeur.
	
	    local rat = CreatureForge.spawn("RatDesCavernes", cf, { mutation = "Gold" })
		    Mutations.apply(model, "Rainbow")      -- sur un modèle déjà construit
		    Mutations.roll(rng)                    -- tirage aléatoire selon les chances (nil = aucune)
	]]
	
local Kit = __require("Kit")
	local Fx = __require("Fx")
	
type Mutation = {
		id: string,
		label: string,
		chance: number, -- en % (tirage indépendant de la rareté)
		multiplier: number, -- bonus de valeur / de gains
		ramp: { Color3 }, -- couleurs du sombre au clair (nil si `rainbow`)
		glow: Color3, -- couleur des parties Neon + lumière
		material: Enum.Material?, -- matériau imposé aux pièces non-Neon
		rainbow: boolean?, -- teinte selon la position le long du corps
		transparency: number?, -- transparence ajoutée aux pièces claires (cristal)
		badge: { Color3 }, -- dégradé de la pastille d'icône
		particle: Fx.ParticleDef,
	}
	
local rgb = Color3.fromRGB
	
local function sparkle(name: string, colors: { Color3 }, rate: number, size: number): Fx.ParticleDef
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
			acceleration = Vector3.new(0, 0.4, 0),
			drag = 1,
			lightEmission = 1,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-90, 90),
			volume = true,
		}
	end
	
local Mutations = {}
	
Mutations.List = {
		{
			id = "Gold",
			label = "DORÉ",
			chance = 8,
			multiplier = 2,
			ramp = { rgb(110, 58, 8), rgb(196, 120, 20), rgb(255, 196, 54), rgb(255, 238, 150) },
			glow = rgb(255, 214, 90),
			badge = { rgb(255, 240, 150), rgb(230, 150, 20) },
			particle = sparkle("GoldSparkle", { rgb(255, 230, 120), rgb(255, 180, 40) }, 8, 0.35),
		},
		{
			id = "Diamond",
			label = "DIAMANT",
			chance = 4,
			multiplier = 3,
			ramp = { rgb(40, 90, 150), rgb(90, 180, 230), rgb(170, 236, 255), rgb(240, 252, 255) },
			glow = rgb(160, 240, 255),
			material = Enum.Material.Glass,
			transparency = 0.15,
			badge = { rgb(230, 252, 255), rgb(70, 170, 240) },
			particle = sparkle("DiamondSparkle", { rgb(255, 255, 255), rgb(150, 230, 255) }, 10, 0.4),
		},
		{
			id = "Toxic",
			label = "TOXIQUE",
			chance = 3,
			multiplier = 4,
			ramp = { rgb(20, 40, 10), rgb(46, 110, 24), rgb(120, 220, 40), rgb(210, 255, 120) },
			glow = rgb(150, 255, 40),
			badge = { rgb(210, 255, 120), rgb(60, 160, 20) },
			particle = {
				name = "ToxicBubbles",
				texture = Fx.TEXTURES.sparkle,
				colors = { rgb(170, 255, 60), rgb(90, 200, 30) },
				sizes = { 0.15, 0.35, 0 },
				transparencies = { 0.2, 0.3, 1 },
				lifetime = NumberRange.new(1.2, 2.2),
				rate = 9,
				speed = NumberRange.new(0.4, 1),
				spread = Vector2.new(30, 30),
				acceleration = Vector3.new(0, 0.6, 0),
				lightEmission = 0.8,
				volume = true,
			},
		},
		{
			id = "Infernal",
			label = "INFERNAL",
			chance = 2,
			multiplier = 5,
			ramp = { rgb(30, 8, 6), rgb(110, 20, 8), rgb(230, 80, 20), rgb(255, 200, 70) },
			glow = rgb(255, 110, 30),
			badge = { rgb(255, 210, 90), rgb(200, 30, 10) },
			particle = {
				name = "InfernalEmbers",
				texture = Fx.TEXTURES.spark,
				colors = { rgb(255, 220, 120), rgb(255, 90, 20), rgb(140, 20, 10) },
				sizes = { 0.25, 0.15, 0 },
				lifetime = NumberRange.new(0.8, 1.6),
				rate = 14,
				speed = NumberRange.new(0.8, 2),
				spread = Vector2.new(25, 25),
				acceleration = Vector3.new(0, 1.2, 0),
				lightEmission = 1,
				volume = true,
			},
		},
		{
			id = "Void",
			label = "OMBRE",
			chance = 1,
			multiplier = 7,
			ramp = { rgb(8, 4, 16), rgb(30, 14, 56), rgb(72, 30, 128), rgb(150, 80, 230) },
			glow = rgb(200, 70, 255),
			badge = { rgb(220, 150, 255), rgb(60, 10, 120) },
			particle = {
				name = "VoidMist",
				texture = Fx.TEXTURES.smoke,
				colors = { rgb(120, 40, 200), rgb(20, 6, 40) },
				sizes = { 0.6, 1.4 },
				transparencies = { 1, 0.5, 1 },
				lifetime = NumberRange.new(1.5, 2.5),
				rate = 10,
				speed = NumberRange.new(0.1, 0.4),
				spread = Vector2.new(180, 180),
				lightEmission = 0.3,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-30, 30),
				volume = true,
			},
		},
		{
			id = "Rainbow",
			label = "ARC-EN-CIEL",
			chance = 0.5,
			multiplier = 10,
			ramp = {},
			rainbow = true,
			glow = rgb(255, 255, 255),
			badge = { rgb(255, 90, 90), rgb(255, 220, 60), rgb(80, 220, 120), rgb(70, 150, 255), rgb(190, 90, 255) },
			particle = sparkle(
				"RainbowSparkle",
				{ rgb(255, 80, 80), rgb(255, 220, 60), rgb(80, 230, 120), rgb(70, 150, 255), rgb(200, 90, 255) },
				12,
				0.4
			),
		},
	} :: { Mutation }
	
local byId: { [string]: Mutation } = {}
	for _, m in Mutations.List do
		byId[m.id] = m
	end
	
function Mutations.get(id: string): Mutation?
		return byId[id]
	end
	
--- Tirage : renvoie une mutation selon les chances (en %), ou nil.
	function Mutations.roll(rng: Random?): Mutation?
		local r = (rng or Random.new()):NextNumber(0, 100)
		local acc = 0
		for i = #Mutations.List, 1, -1 do -- des plus rares aux plus communes
			local m = Mutations.List[i]
			acc += m.chance
			if r < acc then
				return m
			end
		end
		return nil
	end
	
local function sampleRamp(ramp: { Color3 }, x: number): Color3
		local f = math.clamp(x, 0, 1) * (#ramp - 1)
		local i = math.min(math.floor(f) + 1, #ramp - 1)
		return ramp[i]:Lerp(ramp[i + 1], f - (i - 1))
	end
	
--- Nouvelle couleur d'une pièce (luminosité d'origine -> dégradé de la mutation).
	--- `along` = position relative le long du corps (0 = avant, 1 = arrière), pour l'arc-en-ciel.
	function Mutations.recolor(m: Mutation, c: Color3, isNeon: boolean, along: number): Color3
		local lum = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
		if m.rainbow then
			local h = (along * 0.85 + lum * 0.15) % 1
			return Color3.fromHSV(h, if isNeon then 0.45 else 0.78, 0.45 + 0.55 * math.sqrt(lum))
		end
		if isNeon then
			return m.glow
		end
		return sampleRamp(m.ramp, lum ^ 0.85)
	end
	
--- Applique la mutation `id` au modèle (une seule fois). Renvoie le modèle.
	function Mutations.apply(model: Model, id: string): Model
		local m = byId[id]
		assert(m, `CreatureForge: mutation inconnue "{id}"`)
		if model:GetAttribute("Mutation") then
			return model
		end
		local root = model.PrimaryPart
		local ref = if root then root.CFrame else CFrame.identity
		local center, size = Kit.visibleBounds(model)
		local zMin = center.Z - size.Z / 2
	
	for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.95 then
				local isNeon = d.Material == Enum.Material.Neon
				local along = (ref:PointToObjectSpace(d.CFrame.Position).Z - zMin) / math.max(size.Z, 0.01)
				d.Color = Mutations.recolor(m, d.Color, isNeon, along)
				if m.material and not isNeon then
					d.Material = m.material
					local lum = 0.299 * d.Color.R + 0.587 * d.Color.G + 0.114 * d.Color.B
					if m.transparency and lum > 0.55 then
						d.Transparency = math.max(d.Transparency, m.transparency)
					end
				end
			elseif d:IsA("PointLight") then
				d.Color = m.glow
			elseif d:IsA("ParticleEmitter") and m.rainbow then
				-- les effets d'origine gardent leur forme, l'arc-en-ciel les colore
				d.Color = ColorSequence.new(Color3.fromRGB(255, 120, 200), Color3.fromRGB(120, 200, 255))
			end
		end
	
	-- Halo de particules + lumière autour du corps
		if root then
			local scale = (model:GetAttribute("Scale") :: number?) or 1
			local aura = Instance.new("Part")
			aura.Name = "FX_Mutation"
			aura.Size = size * 0.9
			aura.Transparency = 1
			aura.Anchored = false
			aura.CanCollide = false
			aura.CanTouch = false
			aura.CanQuery = false
			aura.Massless = true
			aura.CastShadow = false
			aura.CFrame = ref * CFrame.new(center)
			local w = Instance.new("Weld")
			w.Part0 = root
			w.Part1 = aura
			w.C0 = CFrame.new(center)
			w.Parent = aura
			aura.Parent = model
			Fx.particles(aura, m.particle, scale)
			Fx.light(aura, { color = m.glow, range = math.max(size.X, size.Z) * 0.8 / scale, brightness = 1.2 }, scale)
		end
	
	model:SetAttribute("Mutation", m.id)
		model:SetAttribute("Multiplier", m.multiplier)
		return model
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
	}
	
--- Zones de la carte (du haut du canyon vers le fond).
	type Zone = "Surface" | "PenteBrumeuse" | "GrottesCristal" | "Abysse"
	
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
		Zone: Zone, -- zone de la carte où la créature apparaît
		Scale: number?, -- échelle par défaut à l'apparition (taille en jeu)
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
		local mutation = if o.mutation then Mutations.get(o.mutation) else nil
		if mutation then
			Mutations.apply(model, mutation.id)
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
			local t = label("Label", tag, `{mutation.label} x{mutation.multiplier}`, WHITE, 14)
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
	}
	
--- Aile déployée (côté `side`) : bras en tube + 3 rangées de plumes imbriquées.
	function A.wing(rig: Rig, bone: string, side: number, spec: WingSpec)
		local pts = {}
		for _, p in spec.arm do
			table.insert(pts, A.mx(p, side))
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
				local p = arm:pos(u) + v3(0, 0.02 * (r - 1), 0)
				local outward = v3(side, 0, 0)
				local sweep = rad(spec.sweep) * t
				local dir = (back * math.cos(sweep) + outward * math.sin(sweep)).Unit
				local len = (spec.length[1] + (spec.length[2] - spec.length[1]) * (t ^ 1.4)) * scale
				local right = dir:Cross(Vector3.yAxis).Unit
				local base = CFrame.fromMatrix(p, right, dir, Vector3.yAxis) * ang(0, 0, 0)
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

__modules["PoussePierre"] = function()
	--[[
		LE POUSSE-PIERRE — Commun · La Surface
		======================================
		Mammifère trapu avec une carapace de roche grise taillée et des renforts métalliques.
	
	• Carapace de grosses dalles de roche (Slate) facettées en 4 tons, cerclée de trois
		  bandes d'acier à rivets de laiton.
		• Fourrure brune en mèches sur les flancs et le ventre, pattes courtes de fouisseur
		  à grosses griffes ivoire.
		• Tête casquée d'un bélier de pierre cerclé d'acier, yeux ambrés, oreilles rondes,
		  museau sombre ; petite queue cuirassée.
		• Effets : éclats et poussière de roche.
	]]
	
local Kit = __require("Kit")
	local A = __require("Anatomy")
	local Fx = __require("Fx")
	local Types = __require("Types")
	
local S = Kit.style
	local M = Enum.Material
	local rgb = Color3.fromRGB
	local rad = math.rad
	local v3 = Vector3.new
	local cf = CFrame.new
	local ang = CFrame.Angles
	
local ID = "PoussePierre"
	
local P = {
		core = S(rgb(96, 66, 46)),
		fur = { S(rgb(186, 138, 96)), S(rgb(156, 110, 74)), S(rgb(124, 84, 56)), S(rgb(96, 64, 44)) },
		furTip = S(rgb(226, 196, 150)),
		rock = {
			S(rgb(176, 176, 188), M.Slate),
			S(rgb(146, 146, 160), M.Slate),
			S(rgb(118, 118, 134), M.Slate),
			S(rgb(92, 92, 108), M.Slate),
		},
		steel = S(rgb(104, 112, 128), M.Metal),
		brass = S(rgb(232, 176, 70)),
		nose = S(rgb(40, 30, 28)),
		eye = S(rgb(255, 178, 40)),
		socket = S(rgb(40, 26, 20)),
		pupil = S(rgb(20, 14, 10)),
		claw = S(rgb(246, 238, 218)),
		pad = S(rgb(72, 50, 40)),
		inner = S(rgb(230, 150, 140)),
	}
	
local BODY = Kit.spine({
		{ pos = v3(0, 0.82, -0.85), rx = 0.4, ry = 0.36 },
		{ pos = v3(0, 0.84, -0.45), rx = 0.62, ry = 0.5 },
		{ pos = v3(0, 0.88, 0.1), rx = 0.74, ry = 0.58 },
		{ pos = v3(0, 0.84, 0.6), rx = 0.66, ry = 0.5 },
		{ pos = v3(0, 0.72, 0.95), rx = 0.4, ry = 0.32 },
	})
	
local HEAD = Kit.spine({
		{ pos = v3(0, 0.68, -1.62), rx = 0.14, ry = 0.12 },
		{ pos = v3(0, 0.72, -1.45), rx = 0.26, ry = 0.22 },
		{ pos = v3(0, 0.78, -1.2), rx = 0.36, ry = 0.3 },
		{ pos = v3(0, 0.82, -0.92), rx = 0.36, ry = 0.32 },
	})
	
local TAIL = Kit.spine({
		{ pos = v3(0, 0.74, 1.0), rx = 0.16, ry = 0.14 },
		{ pos = v3(0, 0.6, 1.3), rx = 0.11, ry = 0.1 },
		{ pos = v3(0, 0.45, 1.5), rx = 0.05, ry = 0.05 },
	})
	
local function build(opts: Kit.BuildOptions?): Model
		local rig = Kit.newRig(ID, opts)
		local function const(name: string): (number) -> string
			return function()
				return name
			end
		end
	
	rig:bone("Body", "Root", cf(0, 0.85, 0))
		rig:bone("Head", "Body", cf(0, 0.82, -0.9))
		rig:bone("Tail1", "Body", cf(0, 0.74, 1.0))
		rig:mirrored(function(side, sfx)
			local s = string.sub(sfx, 2)
			rig:bone("Leg_F" .. s, "Body", cf(side * 0.5, 0.78, -0.5))
			rig:bone("Leg_B" .. s, "Body", cf(side * 0.5, 0.8, 0.55))
			rig:bone("Ear" .. sfx, "Head", cf(side * 0.26, 1.06, -0.98))
		end)
	
	-- Corps : fourrure sur les flancs, carapace de roche sur le dessus
		rig:tube(BODY, {
			name = "Body",
			bone = const("Body"),
			core = P.core,
			coreStep = 0.3,
			cover = {
				A.fur(P.fur, P.furTip, v3(0.24, 0.32, 0.34), 0.21, { arc = 80, center = 180, seed = 1 }),
				A.scales(P.rock, v3(0.5, 0.22, 0.52), 0.34, { arc = 108, tilt = 12, jitter = 0.6, refRadius = 0.6, seed = 2 }),
			},
		})
		for _, u in { 2.1, 3.0, 3.9 } do
			rig:band(BODY, "Body", "SteelBand", u, 0.13, 0.15, P.steel, P.brass)
		end
	
	-- Tête casquée
		rig:tube(HEAD, {
			name = "Head",
			bone = const("Head"),
			core = P.core,
			coreStep = 0.18,
			cover = { A.fur(P.fur, P.furTip, v3(0.16, 0.2, 0.2), 0.14, { arc = 150, center = 180, from = 2.2, refRadius = 0.32, seed = 3 }) },
		})
		local helm = HEAD:surface(3.0, 0, 0.04)
		rig:prism("Head", "RockHelm", helm * cf(0, 0.02, 0.04) * ang(rad(-8), 0, 0), v3(0.44, 0.14, 0.5), 0.1, P.rock[2])
		rig:prism("Head", "RockHelm", helm * cf(0, 0.08, -0.06) * ang(rad(-20), 0, 0), v3(0.3, 0.12, 0.3), 0.08, P.rock[1])
		rig:prism("Head", "RamPlate", cf(0, 0.9, -1.4) * ang(rad(-50), 0, 0), v3(0.36, 0.26, 0.1), 0.07, P.rock[3])
		rig:ring("Head", "HelmRim", cf(0, 0.91, -1.41) * ang(rad(-50), 0, 0) * ang(math.pi / 2, 0, 0), 0.16, 0.04, 0.05, 10, P.steel)
		for k = -1, 1, 2 do
			rig:ball("Head", "Rivet", v3(k * 0.18, 0.98, -1.25), 0.06, P.brass)
		end
		rig:ball("Head", "Nose", v3(0, 0.72, -1.72), 0.16, P.nose)
		rig:mirrored(function(side, sfx)
			A.eye(rig, "Head", A.mx(v3(0.25, 0.86, -1.32), side), v3(side, 0.15, -0.8), 0.13, "Round", P.socket, P.eye, P.pupil)
			A.brow(rig, "Head", side, v3(0.24, 0.97, -1.34), 0.2, 12, P.rock[4])
			A.ear(rig, "Ear" .. sfx, cf(A.mx(v3(0.26, 1.06, -0.98), side)) * ang(rad(-10), side * rad(-30), side * rad(-35)), 0.26, 0.24, P.fur[3], P.inner)
		end)
	
	-- Pattes de fouisseur
		rig:mirrored(function(side, sfx)
			local s = string.sub(sfx, 2)
			for key, z in { F = -0.5, B = 0.55 } do
				local bone = "Leg_" .. key .. s
				A.limb(rig, bone, side, {
					{ v3(0.5, 0.78, z), 0.22, 0.24 },
					{ v3(0.58, 0.42, z - 0.04), 0.17, 0.17 },
					{ v3(0.6, 0.14, z - 0.1), 0.13, 0.13 },
				}, P.core, A.fur(P.fur, P.furTip, v3(0.18, 0.24, 0.24), 0.16, { arc = 180, refRadius = 0.22, seed = 10 + side }))
				rig:band(Kit.spine({ { pos = A.mx(v3(0.58, 0.4, z - 0.04), side), rx = 0.18, ry = 0.18 }, { pos = A.mx(v3(0.6, 0.2, z - 0.1), side), rx = 0.15, ry = 0.15 } }), bone, "Bracer", 1.4, 0.1, 0.08, P.steel)
				A.paw(rig, bone, A.mx(v3(0.61, 0, z - 0.16), side), v3(0, 0, -1), 0.38, 3, P.pad, P.core, P.claw)
			end
		end)
	
	-- Petite queue cuirassée
		rig:tube(TAIL, {
			name = "Tail",
			bone = const("Tail1"),
			core = P.core,
			coreStep = 0.15,
			cover = { A.scales(P.rock, v3(0.18, 0.08, 0.18), 0.14, { arc = 130, refRadius = 0.15, seed = 4 }) },
		})
	
	rig:hitbox(cf(0, 0.8, -0.2), v3(1.9, 1.7, 3.4))
	
	if rig.effects then
			local sc = rig.scale
			local dust = rig:anchor("Root", "FX_Dust", cf(0, 0.15, 0), v3(1.8, 0.25, 2.6))
			Fx.particles(dust, Fx.mist("RockDust", { rgb(170, 160, 150), rgb(120, 112, 104) }, 5, 0.6), sc)
			local chips = rig:anchor("Body", "FX_Chips", cf(0, 1.5, 0), v3(1.2, 0.2, 1.6))
			Fx.particles(chips, {
				name = "RockChips",
				texture = Fx.TEXTURES.spark,
				colors = { rgb(190, 190, 200), rgb(130, 130, 140) },
				sizes = { 0.12, 0.08 },
				lifetime = NumberRange.new(0.8, 1.2),
				rate = 2,
				speed = NumberRange.new(0.5, 1),
				spread = Vector2.new(50, 50),
				acceleration = v3(0, -6, 0),
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-200, 200),
				volume = true,
			}, sc)
		end
	
	return rig:finish({ Rarity = "Common" })
	end
	
local Def: Types.CreatureDef = {
		Id = ID,
		DisplayName = "Pousse-Pierre",
		Rarity = "Common",
		Zone = "Surface",
		Scale = 1.3,
		Category = "Créature Commune",
		Description = "Mammifère trapu à carapace de roche cerclée d'acier. Il pousse les rochers pour creuser son terrier.",
		Icon = { top = rgb(118, 96, 74), bottom = rgb(34, 26, 20), glow = rgb(255, 210, 140), motif = rgb(176, 176, 188), yaw = 38, pitch = 20, zoom = 1.15 },
		Animation = { gait = "Quadruped", breathe = 0.025, bob = 0.06, stride = 26, strideRate = 9, tailSway = 8, tailRate = 2, headLook = 14, sniff = true, earTwitch = true },
		build = build,
	}
	
return Def

end

-- ============================================================================
-- Entrée
-- ============================================================================
do
	-- Réglages : mutation éventuelle ("Gold", "Diamond", "Toxic", "Infernal", "Void", "Rainbow")
	-- et échelle (nil = taille par défaut de la créature).
	local MUTATION = nil
	local SCALE = nil

	local def = __require("PoussePierre")
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
	if MUTATION then
		Mutations.apply(model, MUTATION)
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
	Icon.build(def, tray, { mutation = MUTATION })

	pcall(function()
		game:GetService("Selection"):Set({ model })
	end)
	pcall(function()
		game:GetService("ChangeHistoryService"):SetWaypoint("CreatureForge : " .. def.DisplayName)
	end)
	print(("[CreatureForge] %s créé (%d pièces) à %s"):format(def.DisplayName, model:GetAttribute("PartCount"), tostring(ground)))
end
