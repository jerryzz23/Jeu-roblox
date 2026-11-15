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
	• queue de dalles de lune qui ondule, couronne qui flotte, lunes qui flottent autour de la
	  queue et tournent autour de la tête ;
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
			-- le nuage de lunes autour de la queue se balance doucement et monte/descend
			tr = CFrame.new(0, sin(t * 0.9) * 0.25 * echelle, 0) * CFrame.Angles(0, 0, -rad(sin(t * 0.4) * 8))
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
