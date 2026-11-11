--!strict
--[[
	CreatureShowcase (ServerScriptService)
	--------------------------------------
	Démo : fait apparaître chaque créature enregistrée devant le point d'apparition
	et la fait se promener (états "Move" / "Idle" lus par CreatureAnimator côté client).
	Désactivez ce script (Enabled = false) dans votre vrai jeu.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CreatureForge = require(ReplicatedStorage:WaitForChild("CreatureForge"))

local SPACING = 9 -- studs entre deux créatures
local DISTANCE = 16 -- distance devant le point d'apparition
local WANDER_RADIUS = 7 -- rayon de promenade autour de la position d'origine
local SPEED = 9 -- studs/s

local folder = Instance.new("Folder")
folder.Name = "Creatures"
folder.Parent = workspace

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { folder }

local function groundAt(pos: Vector3): Vector3
	local hit = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), rayParams)
	return if hit then hit.Position else Vector3.new(pos.X, 0, pos.Z)
end

local function wander(model: Model, home: Vector3)
	local root = model.PrimaryPart :: BasePart
	local rng = Random.new()
	while model.Parent do
		task.wait(rng:NextNumber(1.5, 4))
		if not model.Parent then
			break
		end
		local angle = rng:NextNumber(0, math.pi * 2)
		local target = groundAt(home + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(2, WANDER_RADIUS))
		local from = root.Position
		if (target - from).Magnitude < 0.5 then
			continue
		end
		local facing = CFrame.lookAt(from, Vector3.new(target.X, from.Y, target.Z))
		local turn = TweenService:Create(root, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { CFrame = facing })
		turn:Play()
		turn.Completed:Wait()

		CreatureForge.setAnimState(model, "Move")
		local scale = (model:GetAttribute("Scale") :: number?) or 1
		local duration = (target - from).Magnitude / (SPEED * scale)
		local move = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
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

local list = CreatureForge.list()
for i, def in list do
	local offset = (i - (#list + 1) / 2) * SPACING
	local pos = groundAt(base.Position + forward * DISTANCE + right * offset)
	-- La créature regarde vers le point d'apparition
	local cf = CFrame.lookAt(pos, Vector3.new(base.Position.X, pos.Y, base.Position.Z))
	local model = CreatureForge.spawn(def.Id, cf, { parent = folder })
	task.spawn(wander, model, pos)
end
