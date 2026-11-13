--!strict
--[[
	CreatureShowcase (ServerScriptService)
	--------------------------------------
	Démo : la Vitrine (Workspace.Vitrine) expose tout le contenu du jeu — les personnages dans la
	zone de leur rareté (Communs en haut de la pente... Chaotiques tout au bout), les 10 tapis de
	course derrière le point d'apparition, les présentoirs des battes, seringues et ADN à côté des
	bases. Elle est déjà enregistrée dans dist/CreatureForge.rbxl ; sinon (Rojo) elle est
	construite au démarrage.
	Ce script fait ensuite se promener les personnages (états "Move" / "Idle" lus par
	CreatureAnimator côté client) et déclencher de temps en temps leur capacité spéciale
	(CreatureForge.playAbility : effets joués par les clients).
	Désactivez ce script (Enabled = false) et supprimez la Vitrine dans votre vrai jeu.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CreatureForge = require(ReplicatedStorage:WaitForChild("CreatureForge"))

local SPEED = 8 -- studs/s (multiplié par l'échelle)
local ABILITY_CHANCE = 0.3 -- probabilité de lancer sa capacité au lieu de se déplacer

-- La carte : celle de la place (dist/CreatureForge.rbxl), sinon construite au démarrage (Rojo)
local map = workspace:FindFirstChild("Carte") :: Model?
if not map then
	map = CreatureForge.Map.build({ parent = workspace })
end
local vitrine = workspace:FindFirstChild("Vitrine") or CreatureForge.buildVitrine(map :: Model, workspace)
local folder = vitrine:WaitForChild("Creatures")

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { vitrine }

local function groundAt(pos: Vector3): Vector3
	local hit = workspace:Raycast(pos + Vector3.new(0, 80, 0), Vector3.new(0, -300, 0), rayParams)
	return if hit then hit.Position else Vector3.new(pos.X, 0, pos.Z)
end

local function wander(model: Model, home: Vector3, radius: number)
	local root = model.PrimaryPart :: BasePart
	local rng = Random.new()
	local scale = (model:GetAttribute("Scale") :: number?) or 1
	while model.Parent do
		task.wait(rng:NextNumber(2, 5))
		if not model.Parent then
			break
		end
		if rng:NextNumber() < ABILITY_CHANCE then
			local d = CreatureForge.playAbility(model)
			if d > 0 then
				task.wait(d + 0.5)
				continue
			end
		end
		local angle = rng:NextNumber(0, math.pi * 2)
		local target = groundAt(home + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(radius * 0.3, radius))
		local from = root.Position
		if (target - from).Magnitude < 0.5 then
			continue
		end
		local facing = CFrame.lookAt(from, Vector3.new(target.X, from.Y, target.Z))
		local turn = TweenService:Create(root, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { CFrame = facing })
		turn:Play()
		turn.Completed:Wait()

		CreatureForge.setAnimState(model, "Move")
		local move = TweenService:Create(root, TweenInfo.new((target - from).Magnitude / (SPEED * scale), Enum.EasingStyle.Linear), {
			CFrame = facing.Rotation + target,
		})
		move:Play()
		move.Completed:Wait()
		CreatureForge.setAnimState(model, "Idle")
	end
end

for _, model in folder:GetChildren() do
	if model:IsA("Model") and model.PrimaryPart then
		local home = (model:GetAttribute("Home") :: Vector3?) or model:GetPivot().Position
		local scale = (model:GetAttribute("Scale") :: number?) or 1
		task.spawn(wander, model, home, 6 + scale * 3)
	end
end
