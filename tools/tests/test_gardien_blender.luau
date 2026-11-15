--[[
	Test du Gardien lunaire fait avec Blender (dist/blender/GardienLunaire).
	On simule ce que fait l'« Importer 3D » de Studio (une MeshPart par pièce, centrée sur sa
	géométrie, déplacée et tournée), on lance le script d'installation, puis l'animation.

	lune run tools/tests/test_gardien_blender.luau
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local DOSSIER = "dist/blender/GardienLunaire/"
local donnees = serde.decode("json", fs.readFile(DOSSIER .. "squelette.json"))
local source = fs.readFile(DOSSIER .. "GardienLunaire.installer.luau")

local erreurs = 0
local function verifier(ok: boolean, message: string)
	if not ok then
		erreurs += 1
		print("ÉCHEC : " .. message)
	end
end

local function essai(nomEssai: string, decalage: CFrame)
	print("--- " .. nomEssai)
	local jeu = Instance.new("DataModel")
	local ws = jeu:GetService("Workspace")
	local modele = Instance.new("Model")
	modele.Name = "GardienLunaire"
	modele.Parent = ws
	-- Comme l'import : une MeshPart par pièce, au centre de sa géométrie
	for _, p in donnees.pieces do
		local mp = Instance.new("MeshPart")
		mp.Name = p.nom
		mp.Anchored = true
		mp.CFrame = decalage * CFrame.new(p.centre[1], p.centre[2], p.centre[3])
		mp.TextureID = if p.sorte == "Palette" then "rbxassetid://1" else ""
		mp.Parent = modele
	end

	local selection = { modele }
	local env = {
		game = {
			GetService = function(_, nom: string)
				if nom == "Selection" then
					return { Get = function() return selection end, Set = function(_, t) selection = t end }
				elseif nom == "ChangeHistoryService" then
					return { SetWaypoint = function() end }
				end
				return jeu:GetService(nom)
			end,
		},
		workspace = ws,
		Instance = Instance,
		CFrame = setmetatable({
			-- comme Roblox : LookVector = dir (CFrame.lookAt de Lune vise +Z, pas -Z)
			lookAlong = function(pos, dir)
				local look = dir.Unit
				local droite = look:Cross(Vector3.yAxis).Unit
				return CFrame.fromMatrix(pos, droite, droite:Cross(look), -look)
			end,
		}, { __index = CFrame }),
	}
	for _, nom in { "Vector3", "Vector2", "Color3", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence",
		"NumberSequenceKeypoint", "NumberRange", "Enum" } do
		env[nom] = roblox[nom]
	end
	setmetatable(env, { __index = _G })
	local ok, err = pcall(luau.load(source, { debugName = "installer", environment = env }))
	verifier(ok, "le script d'installation plante : " .. tostring(err))
	if not ok then
		return
	end

	local motors, soudures, emetteurs = {}, 0, 0
	verifier(ws.Name == "Workspace" and modele.Parent == ws, "le Workspace ne doit pas être touché")
	for _, d in modele:GetDescendants() do
		if d.ClassName == "Motor6D" then
			table.insert(motors, d)
		elseif d.ClassName == "WeldConstraint" then
			soudures += 1
		elseif d.ClassName == "ParticleEmitter" then
			emetteurs += 1
		end
	end
	verifier(#motors == #donnees.articulations, "nombre de Motor6D")
	local nbSous = 0
	for _, p in donnees.pieces do
		if p.nom ~= p.base then
			nbSous += 1
		end
	end
	verifier(soudures == nbSous + 1, "soudures " .. soudures .. " au lieu de " .. (nbSous + 1))
	verifier(emetteurs == 7, "émetteurs de particules : " .. emetteurs)
	verifier(modele.PrimaryPart and modele.PrimaryPart.Name == "Racine", "PrimaryPart = Racine")

	-- Au repos, chaque articulation doit garder les pièces où elles sont, et son pivot doit être
	-- au bon endroit
	local corps = modele:FindFirstChild("Corps")
	local pire = 0
	for _, m in motors do
		local a = (m.Part0.CFrame * m.C0).Position
		local b = (m.Part1.CFrame * m.C1).Position
		pire = math.max(pire, (a - b).Magnitude)
	end
	verifier(pire < 1e-3, "Motor6D incohérent au repos (écart " .. pire .. ")")
	for _, art in donnees.articulations do
		local m = modele:FindFirstChild(art.nom, true)
		local attendu = corps.CFrame.Position + decalage:VectorToWorldSpace(Vector3.new(art.pivot[1], art.pivot[2], art.pivot[3]))
		local m6
		for _, x in motors do
			if x.Name == art.nom then
				m6 = x
			end
		end
		verifier(m ~= nil and m6 ~= nil, "articulation " .. art.nom)
		if m6 then
			local ecart = ((m6.Part0.CFrame * m6.C0).Position - attendu).Magnitude
			verifier(ecart < 1e-3, "pivot de " .. art.nom .. " décalé de " .. ecart)
		end
	end
	-- Ancrage, matériaux
	for _, p in modele:GetChildren() do
		if p:IsA("BasePart") then
			verifier(p.Anchored == (p.Name == "Racine"), "ancrage de " .. p.Name)
		end
	end
	verifier(modele:FindFirstChild("Tete_NeonCyan").Material == roblox.Enum.Material.Neon, "yeux en Neon")
	verifier(modele:FindFirstChild("Tete_Lune").TextureID == "rbxassetid://1", "cristaux en pierre de lune texturée")
	verifier(modele:FindFirstChild("Corps").TextureID == "rbxassetid://1", "texture gardée")
	local racine = modele:FindFirstChild("Racine")
	verifier(math.abs(racine.CFrame.UpVector.Y - 1) < 1e-4, "racine debout")
	local avant = decalage:VectorToWorldSpace(Vector3.new(0, 0, -1))
	verifier((racine.CFrame.LookVector - avant).Magnitude < 1e-3, "racine tournée comme le Gardien")

	-- Animation : on la fait tourner quelques images en marche
	local script = modele:FindFirstChild("AnimationGardien")
	verifier(script ~= nil and script.RunContext == roblox.Enum.RunContext.Client, "script d'animation (Client)")
	local animSource = string.gsub(script.Source, 'modele:WaitForChild%("Racine"%)', 'modele:FindFirstChild("Racine")')
	local rappel
	local horloge = 0
	local envAnim = {
		os = setmetatable({ clock = function() return horloge end }, { __index = os }),
		game = {
			GetService = function(_, nom: string)
				if nom == "RunService" then
					return { PreSimulation = { Connect = function(_, f) rappel = f end } }
				end
				return jeu:GetService(nom)
			end,
		},
		workspace = ws,
		script = script,
		Vector3 = Vector3,
		CFrame = CFrame,
	}
	setmetatable(envAnim, { __index = _G })
	local okA, errA = pcall(luau.load(animSource, { debugName = "animation", environment = envAnim }))
	verifier(okA, "le script d'animation plante : " .. tostring(errA))
	verifier(rappel ~= nil, "animation branchée sur PreSimulation")
	if rappel then
		modele:SetAttribute("Marche", 1)
		for _ = 1, 40 do
			horloge += 1 / 60
			local okR, errR = pcall(rappel, 1 / 60)
			if not okR then
				verifier(false, "animation : " .. tostring(errR))
				break
			end
		end
		-- au cours d'un pas, chaque articulation doit bouger (un genou est droit la moitié du temps)
		local bouge = {}
		for _ = 1, 30 do
			horloge += 1 / 60
			rappel(1 / 60)
			for _, m in motors do
				if m.Transform ~= CFrame.identity then
					bouge[m.Name] = true
				end
			end
		end
		local immobiles = {}
		for _, m in motors do
			if not bouge[m.Name] then
				table.insert(immobiles, m.Name)
			end
		end
		verifier(#immobiles == 0, "articulations immobiles : " .. table.concat(immobiles, ", "))
	end
	print(string.format("Motor6D %d, soudures %d, particules %d", #motors, soudures, emetteurs))
end

essai("import droit", CFrame.new(100, 30, -40))
essai("import tourné de 180° (axe vertical)", CFrame.new(-20, 5, 60) * CFrame.Angles(0, math.pi, 0))
essai("import tourné de 37°", CFrame.new(3, 8, 1) * CFrame.Angles(0, math.rad(37), 0))

print(if erreurs == 0 then "Gardien Blender : tout est bon" else erreurs .. " erreur(s)")
if erreurs > 0 then
	error("test raté")
end
