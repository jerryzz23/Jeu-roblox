--!strict
--[[
	CreatureShowcase (ServerScriptService)
	--------------------------------------
	Démo : fait apparaître toutes les créatures dans la carte, chacune dans la zone de sa rareté
	(Communs en haut de la pente... Chaotiques tout au bout de l'Abysse), puis les fait se promener
	(états "Move" / "Idle" lus par CreatureAnimator côté client) et déclencher de temps en
	temps leur capacité spéciale (CreatureForge.playAbility : effets joués par les clients).
	Environ une créature sur trois reçoit une ou deux mutations au hasard pour la démonstration.
	Les 10 tapis de course sont exposés sur la place des bases, derrière le point d'apparition.
	Désactivez ce script (Enabled = false) dans votre vrai jeu.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CreatureForge = require(ReplicatedStorage:WaitForChild("CreatureForge"))

local SPEED = 8 -- studs/s (multiplié par l'échelle)
local MUTATION_DEMO = true
local ABILITY_CHANCE = 0.3 -- probabilité de lancer sa capacité au lieu de se déplacer

local folder = Instance.new("Folder")
folder.Name = "Creatures"
folder.Parent = workspace

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { folder }

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

-- La carte : celle de la place (dist/CreatureForge.rbxl), sinon construite au démarrage (Rojo)
local Map = CreatureForge.Map
local map = workspace:FindFirstChild("Carte") :: Model?
if not map then
	map = Map.build({ parent = workspace })
end
local pivot = (map :: Model):GetPivot()
local uphill = pivot:VectorToWorldSpace(Vector3.new(0, 0, 1))
local rng = Random.new()

-- Chaque créature se promène dans la zone de sa rareté (distance relative le long de la pente)
local ZONE_D = {
	Common = { 0.03, 0.12 },
	Rare = { 0.14, 0.24 },
	Epic = { 0.3, 0.45 },
	Legendary = { 0.52, 0.64 },
	Mythic = { 0.66, 0.76 },
	Exotic = { 0.8, 0.85 },
	Exclusive = { 0.86, 0.91 },
	Chaotic = { 0.92, 0.99 },
}
for _, def in CreatureForge.list() do
	local mutations = {}
	if MUTATION_DEMO and rng:NextNumber() < 0.3 then
		local list = CreatureForge.Mutations.List
		for _ = 1, rng:NextInteger(1, 2) do
			table.insert(mutations, list[rng:NextInteger(1, #list)].id)
		end
	end
	local band = ZONE_D[def.Rarity] or { 0.05, 0.2 }
	local d = rng:NextNumber(band[1], band[2])
	local p = groundAt((pivot * Map.pathCFrame(d, rng:NextNumber(-12, 12))).Position)
	local model = CreatureForge.spawn(def.Id, CFrame.identity, { parent = folder, mutations = mutations })
	-- Tournée vers le haut de la pente (vers les bases)
	model:PivotTo(CFrame.lookAt(p, p + uphill))
	local scale = (model:GetAttribute("Scale") :: number?) or 1
	task.spawn(wander, model, p, 6 + scale * 3)
end

-- Exposition des 10 tapis de course sur la place des bases, derrière le point d'apparition
do
	local list = CreatureForge.Treadmills.list()
	for i, def in list do
		local pos = pivot * Vector3.new((i - (#list + 1) / 2) * 6, 0.1, 218)
		CreatureForge.Treadmills.spawn(def.Id, CFrame.lookAt(pos, pos - uphill), { parent = folder })
	end
end
