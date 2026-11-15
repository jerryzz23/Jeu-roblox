--!strict
--[[
	GARDIEN LUNAIRE — installation du modèle Blender dans Roblox Studio
	===================================================================
	1. Studio : onglet Avatar (ou Accueil) > « Importer 3D » > choisir GardienLunaire.fbx
	   > « Importer ». Le modèle arrive dans Workspace.
	2. Clique sur le modèle importé pour le sélectionner.
	3. Affichage > Command Bar : colle TOUT ce script et appuie sur Entrée.

	Ce script :
	• remet le Gardien debout et à la bonne taille (TAILLE, en studs) ;
	• donne les matériaux : Neon (yeux, anneaux de la queue, lunes), Glass (cristaux) ;
	• articule les pièces (Motor6D) : 4 pattes avec genoux, tête, oreilles, couronne qui flotte,
	  10 cubes de queue, deux ronds de lunes en orbite ;
	• ajoute les VFX : poussière de lune, paillettes au sol, étoiles de la couronne, éclats des
	  cristaux, lumières cyan, traînée au bout de la queue ;
	• ajoute le script d'animation (Play pour le voir bouger).

	On peut le relancer sans risque : il refait tout proprement.
]]

-- Taille voulue (hauteur en studs, de la patte au haut de la couronne)
local TAILLE = 22.7
-- Si la texture n'est pas arrivée avec l'import : téléverse GardienLunaire_texture.png
-- (Gestionnaire de ressources > Importer), puis colle ici son ID (ex. "rbxassetid://123456").
local TEXTURE_ID = ""

type Art = { nom: string, parent: string, sorte: string, pivot: Vector3, centre: Vector3 }

-- Données du squelette, écrites par blender/gardien_lunaire.py (repère Roblox, en studs,
-- par rapport au centre de la pièce « Corps », Gardien regardant vers -Z).
local ARTICULATIONS: { Art } = {
	{ nom = "Corps", parent = "Racine", sorte = "corps", pivot = Vector3.new(0.0, -1.52, 0.0), centre = Vector3.new(0.0, 0.0, -0.0) },
	{ nom = "PatteAvGHaut", parent = "Corps", sorte = "hanche", pivot = Vector3.new(-1.85, -1.42, -2.8), centre = Vector3.new(-2.005, -2.885, -2.8) },
	{ nom = "PatteAvGBas", parent = "PatteAvGHaut", sorte = "genou", pivot = Vector3.new(-1.85, -4.72, -2.8), centre = Vector3.new(-1.85, -6.77, -3.215) },
	{ nom = "PatteAvDHaut", parent = "Corps", sorte = "hanche", pivot = Vector3.new(1.85, -1.42, -2.8), centre = Vector3.new(2.005, -2.885, -2.8) },
	{ nom = "PatteAvDBas", parent = "PatteAvDHaut", sorte = "genou", pivot = Vector3.new(1.85, -4.72, -2.8), centre = Vector3.new(1.85, -6.77, -3.215) },
	{ nom = "PatteArGHaut", parent = "Corps", sorte = "hanche", pivot = Vector3.new(-1.85, -1.42, 3.2), centre = Vector3.new(-2.005, -2.885, 3.2) },
	{ nom = "PatteArGBas", parent = "PatteArGHaut", sorte = "genou", pivot = Vector3.new(-1.85, -4.72, 3.2), centre = Vector3.new(-1.85, -6.77, 2.785) },
	{ nom = "PatteArDHaut", parent = "Corps", sorte = "hanche", pivot = Vector3.new(1.85, -1.42, 3.2), centre = Vector3.new(2.005, -2.885, 3.2) },
	{ nom = "PatteArDBas", parent = "PatteArDHaut", sorte = "genou", pivot = Vector3.new(1.85, -4.72, 3.2), centre = Vector3.new(1.85, -6.77, 2.785) },
	{ nom = "Tete", parent = "Corps", sorte = "cou", pivot = Vector3.new(0.0, 1.48, -4.2), centre = Vector3.new(0.0, 2.95, -6.605) },
	{ nom = "OreilleG", parent = "Tete", sorte = "oreille", pivot = Vector3.new(-2.2, 5.78, -7.1), centre = Vector3.new(-2.4049, 7.78, -7.25) },
	{ nom = "OreilleD", parent = "Tete", sorte = "oreille", pivot = Vector3.new(2.2, 5.78, -7.1), centre = Vector3.new(2.4049, 7.78, -7.25) },
	{ nom = "Couronne", parent = "Tete", sorte = "flotte", pivot = Vector3.new(0.0, 8.38, -5.6), centre = Vector3.new(0.0, 9.38, -5.6) },
	{ nom = "Queue01", parent = "Corps", sorte = "queue", pivot = Vector3.new(0.0, 1.18, 5.0), centre = Vector3.new(0.0, 1.18, 6.28) },
	{ nom = "Queue02", parent = "Queue01", sorte = "queue", pivot = Vector3.new(0.0, 1.18, 7.56), centre = Vector3.new(0.0, 1.1362, 8.8107) },
	{ nom = "Queue03", parent = "Queue02", sorte = "queue", pivot = Vector3.new(0.0, 1.0924, 10.0685), centre = Vector3.new(0.0, 1.0495, 11.2977) },
	{ nom = "Queue04", parent = "Queue03", sorte = "queue", pivot = Vector3.new(0.0, 1.0065, 12.527), centre = Vector3.new(0.0, 1.0065, 13.732) },
	{ nom = "Queue05", parent = "Queue04", sorte = "queue", pivot = Vector3.new(0.0, 1.0065, 14.937), centre = Vector3.new(0.0, 1.0683, 16.1141) },
	{ nom = "Queue06", parent = "Queue05", sorte = "queue", pivot = Vector3.new(0.0, 1.1301, 17.2937), centre = Vector3.new(0.0, 1.2708, 18.4401) },
	{ nom = "Queue07", parent = "Queue06", sorte = "queue", pivot = Vector3.new(0.0, 1.4116, 19.5865), centre = Vector3.new(0.0, 1.6658, 20.6876) },
	{ nom = "Queue08", parent = "Queue07", sorte = "queue", pivot = Vector3.new(0.0, 1.92, 21.7886), centre = Vector3.new(0.0, 2.3473, 22.8131) },
	{ nom = "Queue09", parent = "Queue08", sorte = "queue", pivot = Vector3.new(0.0, 2.7479, 23.8377), centre = Vector3.new(0.0, 3.3518, 24.733) },
	{ nom = "Queue10", parent = "Queue09", sorte = "queue", pivot = Vector3.new(0.0, 3.9557, 25.6284), centre = Vector3.new(0.0, 4.8941, 26.4514) },
	{ nom = "OrbiteQueue", parent = "Corps", sorte = "orbite_queue", pivot = Vector3.new(0.0, 3.28, 15.3), centre = Vector3.new(0.0742, 3.351, 15.9643) },
	{ nom = "OrbiteTete", parent = "Corps", sorte = "orbite_tete", pivot = Vector3.new(0.0, 4.28, -6.2), centre = Vector3.new(0.0017, 4.9895, -7.3545) },
}
local POINTS: { [string]: Vector3 } = {
	CristalG = Vector3.new(-5.4, 8.08, -4.1),
	CristalD = Vector3.new(5.4, 8.08, -4.1),
	Yeux = Vector3.new(0.0, 3.23, -9.4),
	QueueBout = Vector3.new(0.0, 4.8698, 26.4514),
}
local SOL = -8.72
local REF_HAUTEUR = 22.7
local ANIMATION = [==[
--!strict
--[[
	ANIMATION DU GARDIEN LUNAIRE (modèle Blender)
	=============================================
	Script placé dans le modèle par le script d'installation, avec RunContext = Client : il tourne
	chez chaque joueur (les animations faites par Motor6D.Transform ne passent pas du serveur aux
	joueurs). Il anime tout le corps :

	• repos : respiration, tête qui regarde autour, oreilles qui frémissent ;
	• marche (quand le Gardien se déplace, ou si l'attribut « Marche » vaut 1) : trot en diagonale,
	  genoux qui plient, corps qui rebondit, tête qui hoche ;
	• queue de cubes de lune qui ondule, couronne qui flotte, lunes en orbite qui tournent ;
	• halos de la queue et lumières qui « respirent ».

	Attribut « Marche » du modèle : -1 = automatique (selon la vitesse), 0 = repos, 1 = marche sur
	place.
]]

local RunService = game:GetService("RunService")

local modele = script.Parent :: Model
local racine = modele:WaitForChild("Racine") :: BasePart
local echelle = (modele:GetAttribute("Echelle") :: number?) or 1

type Joint = { motor: Motor6D, sorte: string, index: number, phase: number, cote: number }

local joints: { Joint } = {}
for _, d in modele:GetDescendants() do
	if d:IsA("Motor6D") then
		local nom = d.Name
		local sorte = (d:GetAttribute("Sorte") :: string?) or ""
		-- trot : avant gauche + arrière droit ensemble, puis les deux autres
		local diagonale = string.find(nom, "AvG") ~= nil or string.find(nom, "ArD") ~= nil
		table.insert(joints, {
			motor = d,
			sorte = sorte,
			index = tonumber(string.match(nom, "(%d+)$")) or 0,
			phase = if diagonale then 0 else math.pi,
			cote = if string.sub(nom, -1) == "G" then -1 else 1,
		})
	end
end

local halos: { BasePart } = {}
local lumieres: { [PointLight]: number } = {}
for _, d in modele:GetDescendants() do
	if d:IsA("BasePart") and string.sub(d.Name, -5) == "_Halo" then
		table.insert(halos, d)
	elseif d:IsA("PointLight") then
		lumieres[d] = d.Brightness
	end
end
local transparenceHalo = if halos[1] then halos[1].Transparency else 0.82

local rad = math.rad
local sin = math.sin
local debut = os.clock()
local marche = 0
local pas = 0
local derniere = racine.CFrame.Position

RunService.PreSimulation:Connect(function(dt: number)
	if not racine.Parent then
		return
	end
	-- Inutile d'animer un Gardien trop loin de la caméra
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - racine.CFrame.Position).Magnitude > 400 * echelle then
		return
	end

	local t = os.clock() - debut
	local pos = racine.CFrame.Position
	local vitesse = Vector3.new(pos.X - derniere.X, 0, pos.Z - derniere.Z).Magnitude / math.max(dt, 1e-3) / echelle
	derniere = pos
	local voulu = (modele:GetAttribute("Marche") :: number?) or -1
	local cible = if voulu >= 0 then math.clamp(voulu, 0, 1) else math.clamp(vitesse / 6, 0, 1)
	marche += (cible - marche) * math.min(1, dt * 5)
	local cadence = if voulu >= 0 then 1 else math.clamp(vitesse / 8, 0.6, 1.6)
	pas += dt * 7 * math.max(marche, 0.25) * cadence

	for _, j in joints do
		local s = j.sorte
		local tr: CFrame
		if s == "corps" then
			local saut = (sin(t * 2) * 0.08 + math.abs(sin(pas)) * 0.35 * marche) * echelle
			tr = CFrame.new(0, saut, 0) * CFrame.Angles(rad(sin(pas * 2) * 1.2 * marche), 0, rad(sin(pas) * 1.8 * marche))
		elseif s == "hanche" then
			local repos = sin(t * 1.3 + j.phase) * 1.5 * (1 - marche)
			tr = CFrame.Angles(rad(sin(pas + j.phase) * 26 * marche + repos), 0, 0)
		elseif s == "genou" then
			tr = CFrame.Angles(rad(-math.max(0, sin(pas + j.phase + 1.2)) * 34 * marche), 0, 0)
		elseif s == "cou" then
			local regard = sin(t * 0.5) * 10 + sin(t * 1.7) * 2
			tr = CFrame.Angles(rad(sin(t * 0.8) * 3 + sin(pas * 2) * 2.5 * marche), rad(regard * (1 - marche * 0.7)), 0)
		elseif s == "oreille" then
			-- petit frémissement toutes les 4 secondes environ
			local cycle = (t + j.cote * 1.3) % 4.2
			local f = if cycle < 0.3 then sin(cycle / 0.3 * math.pi) * 14 else 0
			tr = CFrame.Angles(rad(f * 0.4), 0, rad(-j.cote * (f + sin(t * 1.1) * 2)))
		elseif s == "flotte" then
			tr = CFrame.new(0, sin(t * 1.6) * 0.35 * echelle, 0) * CFrame.Angles(0, rad(sin(t * 0.7) * 8), rad(sin(t * 1.1) * 3))
		elseif s == "queue" then
			local i = j.index
			local monte = sin(t * 1.1 - i * 0.5) * 2.2 + sin(pas * 2 - i * 0.6) * 1.6 * marche
			local cote = sin(t * 1.4 - i * 0.45) * 4.5 * (1 + marche * 0.6)
			tr = CFrame.Angles(rad(monte), rad(cote), 0)
		elseif s == "orbite_queue" then
			tr = CFrame.Angles(0, 0, -rad(t * 22))
		elseif s == "orbite_tete" then
			tr = CFrame.Angles(0, rad(t * 16), 0)
		else
			tr = CFrame.identity
		end
		j.motor.Transform = tr
	end

	-- Halos et lumières qui respirent
	for i, h in halos do
		h.LocalTransparencyModifier = 0
		h.Transparency = math.clamp(transparenceHalo + sin(t * 2.2 - i * 0.6) * 0.06, 0, 1)
	end
	for l, b in lumieres do
		l.Brightness = b * (0.85 + 0.15 * sin(t * 2.2))
	end
end)
]==]

local COULEURS: { [string]: Color3 } = {
	NeonCyan = Color3.fromRGB(110, 236, 255),
	NeonBlanc = Color3.fromRGB(232, 252, 255),
	NeonPale = Color3.fromRGB(178, 244, 255),
	NeonMagenta = Color3.fromRGB(255, 140, 214),
	Cristal = Color3.fromRGB(214, 244, 255),
	CristalCoeur = Color3.fromRGB(150, 236, 255),
	Halo = Color3.fromRGB(110, 236, 255),
}
local ETINCELLE = "rbxasset://textures/particles/sparkles_main.dds"

local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- ---------------------------------------------------------------------------------------------
-- 1. Trouver le modèle importé
-- ---------------------------------------------------------------------------------------------
--- Le Model le plus haut (sous Workspace, jamais Workspace lui-même) qui contient « Corps ».
local function modeleDe(obj: Instance): Model?
	local trouve: Model? = nil
	local m: Instance? = obj
	while m and m ~= workspace and m.Parent ~= nil do
		if m:IsA("Model") and m:FindFirstChild("Corps", true) then
			trouve = m
		end
		m = m.Parent
	end
	return trouve
end

local function trouverModele(): Model?
	for _, obj in Selection:Get() do
		local m = modeleDe(obj)
		if m then
			return m
		end
	end
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d.Name == "GardienLunaire" and d:FindFirstChild("Corps", true) then
			return d
		end
	end
	local corps = workspace:FindFirstChild("Corps", true)
	return if corps then modeleDe(corps) else nil
end

local modele = trouverModele()
assert(modele, "Gardien lunaire introuvable : importe d'abord GardienLunaire.fbx (Importer 3D), sélectionne-le, puis relance ce script.")
ChangeHistoryService:SetWaypoint("Avant installation du Gardien lunaire")
modele.Name = "GardienLunaire"

-- Nettoyage (si le script a déjà été lancé) et pièces rangées directement dans le modèle
for _, d in modele:GetDescendants() do
	if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("ParticleEmitter") or d:IsA("Light")
		or d:IsA("Trail") or d:IsA("Attachment") or (d:IsA("Script") and d.Name == "AnimationGardien") then
		d:Destroy()
	end
end
for _, nom in { "Racine", "ZoneVFX" } do
	local ancien = modele:FindFirstChild(nom)
	if ancien then
		ancien:Destroy()
	end
end
local parts: { [string]: BasePart } = {}
for _, d in modele:GetDescendants() do
	if d:IsA("BasePart") then
		d.Anchored = true
		d.Parent = modele
		parts[d.Name] = d
	end
end
for _, d in modele:GetChildren() do
	if d:IsA("Model") or d:IsA("Folder") then
		if #d:GetDescendants() == 0 then
			d:Destroy()
		end
	end
end
local manquantes = {}
for _, a in ARTICULATIONS do
	if not parts[a.nom] then
		table.insert(manquantes, a.nom)
	end
end
assert(#manquantes == 0, "Pièces introuvables dans le modèle : " .. table.concat(manquantes, ", "))
local corps = parts.Corps

-- ---------------------------------------------------------------------------------------------
-- 2. Orientation et taille : on compare la position réelle de la tête et de la couronne à celle
--    du fichier Blender (l'import peut tourner ou agrandir le modèle)
-- ---------------------------------------------------------------------------------------------
local REF: { [string]: Art } = {}
for _, a in ARTICULATIONS do
	REF[a.nom] = a
end

local function repere(a: Vector3, b: Vector3): CFrame
	local x = a.Unit
	local y = (b - x * b:Dot(x)).Unit
	return CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y))
end

local function mesurer(): (CFrame, number)
	local e1, e2 = REF.Couronne.centre, REF.Tete.centre
	local m1 = parts.Couronne.CFrame.Position - corps.CFrame.Position
	local m2 = parts.Tete.CFrame.Position - corps.CFrame.Position
	return repere(m1, m2) * repere(e1, e2):Inverse(), m1.Magnitude / e1.Magnitude
end

local R, s = mesurer()
local haut = R:VectorToWorldSpace(Vector3.yAxis)
if haut.Y < 0.98 then
	-- le modèle est couché ou penché : on le remet debout
	local axe = if haut.Y < -0.999 then Vector3.xAxis else haut:Cross(Vector3.yAxis).Unit
	local angle = math.acos(math.clamp(haut.Y, -1, 1))
	local c = corps.CFrame.Position
	modele:PivotTo(CFrame.new(c) * CFrame.fromAxisAngle(axe, angle) * CFrame.new(-c) * modele:GetPivot())
	R, s = mesurer()
end
local facteur = TAILLE / (REF_HAUTEUR * s)
if math.abs(facteur - 1) > 0.01 then
	modele:ScaleTo(modele:GetScale() * facteur)
	R, s = mesurer()
end
-- R ne garde que la rotation autour de la verticale (le Gardien est debout)
local avant = R:VectorToWorldSpace(-Vector3.zAxis)
R = CFrame.lookAlong(Vector3.zero, Vector3.new(avant.X, 0, avant.Z).Unit)

local function point(v: Vector3): Vector3
	return corps.CFrame.Position + R:VectorToWorldSpace(v * s)
end
local function cadre(v: Vector3): CFrame
	return CFrame.new(point(v)) * R
end

-- ---------------------------------------------------------------------------------------------
-- 3. Matériaux
-- ---------------------------------------------------------------------------------------------
for nom, p in parts do
	local sorte = string.match(nom, "^[^_]+_(.+)$")
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = nom == "Corps" or nom == "Tete"
	p.Massless = true
	p.CastShadow = true
	if sorte and COULEURS[sorte] then
		p.Color = COULEURS[sorte]
		if p:IsA("MeshPart") then
			p.TextureID = ""
		end
		if sorte == "Cristal" then
			p.Material = Enum.Material.Glass
			p.Transparency = 0.25
			p.Reflectance = 0.15
		elseif sorte == "Halo" then
			p.Material = Enum.Material.Neon
			p.Transparency = 0.82
			p.CastShadow = false
		else
			p.Material = Enum.Material.Neon
			p.Transparency = 0
		end
	else
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.new(1, 1, 1)
		if p:IsA("MeshPart") then
			if TEXTURE_ID ~= "" then
				p.TextureID = TEXTURE_ID
			elseif p.TextureID == "" then
				p.Color = Color3.fromRGB(58, 48, 118)
			end
		end
	end
end
local sansTexture = parts.Corps:IsA("MeshPart") and (parts.Corps :: MeshPart).TextureID == ""
if sansTexture then
	warn("La texture n'est pas arrivée avec l'import : le Gardien est tout bleu nuit. Téléverse GardienLunaire_texture.png, colle son ID dans TEXTURE_ID (en haut du script) et relance.")
end

-- ---------------------------------------------------------------------------------------------
-- 4. Squelette : une racine invisible au sol, des Motor6D aux articulations
-- ---------------------------------------------------------------------------------------------
local racine = Instance.new("Part")
racine.Name = "Racine"
racine.Size = Vector3.new(4, 0.2, 4) * s
racine.Transparency = 1
racine.CanCollide = false
racine.CanTouch = false
racine.CanQuery = false
racine.Anchored = true
racine.CFrame = cadre(Vector3.new(0, SOL, 0)) * CFrame.new(0, 0.1 * s, 0)
racine.Parent = modele
modele.PrimaryPart = racine
parts.Racine = racine

for _, a in ARTICULATIONS do
	local p0 = parts[a.parent]
	local p1 = parts[a.nom]
	local c = cadre(a.pivot)
	local m = Instance.new("Motor6D")
	m.Name = a.nom
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = p0.CFrame:ToObjectSpace(c)
	m.C1 = p1.CFrame:ToObjectSpace(c)
	m:SetAttribute("Sorte", a.sorte)
	m.Parent = p0
end
-- Pièces lumineuses, cristaux et halos : soudées à leur pièce de base
for nom, p in parts do
	local base = string.match(nom, "^([^_]+)_")
	if base and parts[base] and p ~= racine then
		local w = Instance.new("WeldConstraint")
		w.Name = "Soudure"
		w.Part0 = parts[base]
		w.Part1 = p
		w.Parent = p
	end
end
for _, p in parts do
	p.Anchored = p == racine
end

-- ---------------------------------------------------------------------------------------------
-- 5. VFX
-- ---------------------------------------------------------------------------------------------
local function attache(partie: BasePart, nom: string, v: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = nom
	a.Parent = partie
	a.WorldCFrame = cadre(v)
	return a
end

local function sequence(couleurs: { Color3 }): ColorSequence
	local k = {}
	for i, c in couleurs do
		table.insert(k, ColorSequenceKeypoint.new((i - 1) / math.max(1, #couleurs - 1), c))
	end
	return ColorSequence.new(k)
end

type Particules = {
	couleurs: { Color3 }, taille: number, duree: NumberRange, debit: number, vitesse: NumberRange,
	monte: number?, scintille: boolean?,
}
local function particules(parent: Instance, nom: string, d: Particules): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = nom
	e.Texture = ETINCELLE
	e.Color = sequence(d.couleurs)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Lifetime = d.duree
	e.Rate = d.debit
	e.Speed = NumberRange.new(d.vitesse.Min * s, d.vitesse.Max * s)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 1.5
	e.Acceleration = Vector3.new(0, (d.monte or 0) * s, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	local t = d.taille * s
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, t),
		NumberSequenceKeypoint.new(1, 0),
	})
	if d.scintille then
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0),
			NumberSequenceKeypoint.new(0.6, 0.5),
			NumberSequenceKeypoint.new(0.8, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
	else
		e.Transparency = NumberSequence.new(0, 1)
	end
	e.Parent = parent
	return e
end

local function lumiere(parent: Instance, couleur: Color3, portee: number, eclat: number)
	local l = Instance.new("PointLight")
	l.Color = couleur
	l.Range = math.min(60, portee * s)
	l.Brightness = eclat
	l.Shadows = false
	l.Parent = parent
end

local CYAN = COULEURS.NeonCyan
local BLANC = Color3.new(1, 1, 1)
local LAVANDE = Color3.fromRGB(200, 190, 255)

-- Poussière de lune autour de la queue, lumière cyan
for _, nom in { "Queue03", "Queue06", "Queue09" } do
	local p = parts[nom]
	if p then
		local a = attache(p, "FX_Poussiere", REF[nom].centre)
		particules(a, "PoussiereLunaire", {
			couleurs = { CYAN, BLANC, LAVANDE }, taille = 0.35, duree = NumberRange.new(1.5, 3),
			debit = 9, vitesse = NumberRange.new(0.4, 1.6), monte = 0.6,
		})
	end
end
lumiere(attache(parts.Queue04, "FX_Lumiere", REF.Queue04.centre), CYAN, 22, 1.6)
lumiere(attache(parts.Queue08, "FX_Lumiere", REF.Queue08.centre), CYAN, 18, 1.3)

-- Yeux et couronne
lumiere(attache(parts.Tete, "FX_Yeux", POINTS.Yeux), CYAN, 12, 1.2)
local couronne = attache(parts.Couronne, "FX_Couronne", REF.Couronne.centre)
lumiere(couronne, Color3.fromRGB(200, 240, 255), 12, 0.9)
particules(couronne, "EtoilesCouronne", {
	couleurs = { BLANC, CYAN }, taille = 0.45, duree = NumberRange.new(1, 2), debit = 5,
	vitesse = NumberRange.new(0.3, 1), scintille = true,
})

-- Éclats des cristaux
for _, nom in { "CristalG", "CristalD" } do
	particules(attache(parts.Tete, "FX_" .. nom, POINTS[nom]), "EclatsCristal", {
		couleurs = { BLANC, CYAN }, taille = 0.4, duree = NumberRange.new(0.8, 1.6), debit = 4,
		vitesse = NumberRange.new(0.5, 1.5), monte = 0.8, scintille = true,
	})
end

-- Paillettes au sol, sous le Gardien et sa queue
local zone = Instance.new("Part")
zone.Name = "ZoneVFX"
zone.Size = Vector3.new(11, 0.2, 36) * s
zone.Transparency = 1
zone.CanCollide = false
zone.CanTouch = false
zone.CanQuery = false
zone.Massless = true
zone.Anchored = false
zone.CFrame = cadre(Vector3.new(0, SOL, 10)) * CFrame.new(0, 0.1 * s, 0)
zone.Parent = modele
local wz = Instance.new("WeldConstraint")
wz.Part0 = racine
wz.Part1 = zone
wz.Parent = zone
local pa = particules(zone, "PaillettesAuSol", {
	couleurs = { CYAN, BLANC }, taille = 0.22, duree = NumberRange.new(1, 2), debit = 40,
	vitesse = NumberRange.new(0, 0), scintille = true,
})
pa.Shape = Enum.ParticleEmitterShape.Box
pa.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
pa.Drag = 0

-- Traînée au bout de la queue
do
	local bout = POINTS.QueueBout
	local a0 = attache(parts.Queue10, "FX_TraineeHaut", bout + Vector3.new(0, 0.9, 0))
	local a1 = attache(parts.Queue10, "FX_TraineeBas", bout - Vector3.new(0, 0.9, 0))
	local tr = Instance.new("Trail")
	tr.Name = "TraineeLunaire"
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Color = sequence({ Color3.fromRGB(170, 240, 255), Color3.fromRGB(120, 90, 255) })
	tr.Transparency = NumberSequence.new(0.35, 1)
	tr.Lifetime = 0.5
	tr.LightEmission = 1
	tr.FaceCamera = true
	tr.Parent = parts.Queue10
end

-- ---------------------------------------------------------------------------------------------
-- 6. Animation (s'exécute chez les joueurs, en Play)
-- ---------------------------------------------------------------------------------------------
modele:SetAttribute("Echelle", s)
modele:SetAttribute("Marche", -1)
local anim = Instance.new("Script")
anim.Name = "AnimationGardien"
anim.RunContext = Enum.RunContext.Client
anim.Source = ANIMATION
anim.Parent = modele

ChangeHistoryService:SetWaypoint("Gardien lunaire installé")
Selection:Set({ modele })
print("Gardien lunaire prêt ! Lance Play pour le voir bouger. Attribut « Marche » : 1 = il marche sur place, -1 = automatique.")
