--!strict
--[[
	CreatureShowcase (ServerScriptService)
	--------------------------------------
	Démo : fait apparaître toutes les créatures devant le point d'apparition, une rangée par
	rareté (Commun, Rare, Épique... Chaotique), puis les fait se promener
	(états "Move" / "Idle" lus par CreatureAnimator côté client) et déclencher de temps en
	temps leur capacité spéciale (CreatureForge.playAbility : effets joués par les clients).
	Environ une créature sur trois reçoit une ou deux mutations au hasard pour la démonstration.
	Les 10 tapis de course sont alignés derrière le point d'apparition.
	Désactivez ce script (Enabled = false) dans votre vrai jeu.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CreatureForge = require(ReplicatedStorage:WaitForChild("CreatureForge"))

local GAP = 4 -- studs entre deux créatures d'une même rangée
local ROW_GAP = 10 -- studs entre deux rangées (raretés)
local DISTANCE = 18 -- distance de la première rangée devant le point d'apparition
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

local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local base = if spawnLocation then spawnLocation.CFrame else CFrame.new(0, 0, 0)
local forward = base.LookVector * Vector3.new(1, 0, 1)
forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.new(0, 0, -1)
local right = forward:Cross(Vector3.yAxis)
local rng = Random.new()

local rowOffset = DISTANCE
for _, rarity in CreatureForge.Rarity.Order do
	local defs = CreatureForge.ofRarity(rarity)
	if #defs == 0 then
		continue
	end
	-- Construit la rangée hors de Workspace pour mesurer les tailles, puis la centre
	local models, widths, depth, total = {}, {}, 0, 0
	for _, def in defs do
		local mutations = {}
		if MUTATION_DEMO and rng:NextNumber() < 0.3 then
			local list = CreatureForge.Mutations.List
			for _ = 1, rng:NextInteger(1, 2) do
				table.insert(mutations, list[rng:NextInteger(1, #list)].id)
			end
		end
		local model = CreatureForge.spawn(def.Id, CFrame.identity, { parent = folder, mutations = mutations })
		local size = model:GetExtentsSize()
		table.insert(models, model)
		table.insert(widths, size.X)
		depth = math.max(depth, size.Z)
		total += size.X + GAP
	end
	local x = -total / 2
	for i, model in models do
		x += widths[i] / 2
		local pos = groundAt(base.Position + forward * (rowOffset + depth / 2) + right * x)
		-- La créature regarde vers le point d'apparition
		model:PivotTo(CFrame.lookAt(pos, Vector3.new(base.Position.X, pos.Y, base.Position.Z)))
		task.spawn(wander, model, pos, math.max(widths[i] * 0.6, 4))
		x += widths[i] / 2 + GAP
	end
	rowOffset += depth + ROW_GAP
end

-- Rangée des 10 tapis de course derrière le point d'apparition (du niveau 1 au niveau 10) :
-- on monte par l'arrière, la console est face au coureur et la bande le fait courir sur place.
do
	local list = CreatureForge.Treadmills.list()
	local spacing = 6
	local away = -forward
	for i, def in list do
		local x = (i - (#list + 1) / 2) * spacing
		local pos = groundAt(base.Position + away * 16 + right * x)
		CreatureForge.Treadmills.spawn(def.Id, CFrame.lookAt(pos, pos + away), { parent = folder })
	end
end
