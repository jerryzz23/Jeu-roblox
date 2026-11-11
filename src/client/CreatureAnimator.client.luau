--!strict
--[[
	CreatureAnimator (StarterPlayerScripts)
	---------------------------------------
	Anime de façon procédurale, côté client, toutes les créatures taguées "CreatureForge"
	présentes dans Workspace, en pilotant Motor6D.Transform (non répliqué : zéro trafic réseau).

	L'état est lu dans l'attribut "AnimState" du modèle (posé par le serveur) :
	  "Idle"  : respiration, reniflements, regard, oreilles qui frémissent, queue qui ondule,
	            coups de langue (reptiles)
	  "Move"  : Quadruped -> trot diagonal + rebond du corps
	            Sprawler  -> pattes écartées qui balaient + ondulation du corps (lézards)
	  "Still" : pose figée (vitrines, captures d'écran)

	Les paramètres viennent de CreatureDef.Animation (voir Types.AnimProfile).
	Les créatures à plus de MAX_DISTANCE studs de la caméra ne sont pas animées.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CreatureForge = require(ReplicatedStorage:WaitForChild("CreatureForge"))

local MAX_DISTANCE = 150
local FLICK_TIME = 0.6
local TAG = CreatureForge.TAG

-- Côté de chaque patte (+1 = droite / +X, -1 = gauche) et phase du pas (paires diagonales)
local LEGS = {
	{ name = "Leg_FR", side = 1, phase = 0 },
	{ name = "Leg_BL", side = -1, phase = 0 },
	{ name = "Leg_FL", side = -1, phase = math.pi },
	{ name = "Leg_BR", side = 1, phase = math.pi },
}

type Profile = {
	gait: string,
	breathe: number,
	sway: number,
	tongueFlick: boolean,
	bob: number,
	stride: number,
	strideRate: number,
	tailSway: number,
	tailRate: number,
	headLook: number,
	sniff: boolean,
	earTwitch: boolean,
}

type State = {
	model: Model,
	root: BasePart,
	profile: Profile,
	scale: number,
	motors: { [string]: Motor6D },
	tail: { Motor6D },
	t: number,
	move: number,
	rng: Random,
	earTimer: number,
	earSide: number,
	sniffTimer: number,
	tongueTimer: number,
	frozen: boolean,
	connections: { RBXScriptConnection },
}

local states: { [Model]: State } = {}

local function readProfile(id: string?): Profile
	local a = if id and CreatureForge.has(id) then CreatureForge.get(id).Animation else nil
	local p: { [string]: any } = (a or {}) :: any
	return {
		gait = p.gait or "Quadruped",
		breathe = p.breathe or 0.03,
		sway = p.sway or 8,
		tongueFlick = p.tongueFlick == true,
		bob = p.bob or 0.08,
		stride = p.stride or 30,
		strideRate = p.strideRate or 10,
		tailSway = p.tailSway or 12,
		tailRate = p.tailRate or 2,
		headLook = p.headLook or 15,
		sniff = p.sniff == true,
		earTwitch = p.earTwitch == true,
	}
end

local function untrack(model: Model)
	local st = states[model]
	if not st then
		return
	end
	for _, c in st.connections do
		c:Disconnect()
	end
	for _, m in st.motors do
		m.Transform = CFrame.identity
	end
	states[model] = nil
end

local function track(inst: Instance)
	if not inst:IsA("Model") or states[inst] or not inst:IsDescendantOf(workspace) then
		return
	end
	local model = inst
	local root = model.PrimaryPart
	if not root then
		return
	end

	local motors: { [string]: Motor6D } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	local tail = {}
	local i = 1
	while motors["Tail" .. i] do
		table.insert(tail, motors["Tail" .. i])
		i += 1
	end

	local id = model:GetAttribute("CreatureId")
	local seed = math.floor((root.Position.X * 73 + root.Position.Z * 19) % 100000)
	local st: State = {
		model = model,
		root = root,
		profile = readProfile(if typeof(id) == "string" then id else nil),
		scale = (model:GetAttribute("Scale") :: number?) or 1,
		motors = motors,
		tail = tail,
		t = seed % 100,
		move = 0,
		rng = Random.new(seed),
		earTimer = 1,
		earSide = 1,
		sniffTimer = 2,
		tongueTimer = 1.5,
		frozen = false,
		connections = {},
	}
	table.insert(
		st.connections,
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(workspace) then
				untrack(model)
			end
		end)
	)
	states[model] = st
end

local function set(st: State, name: string, cf: CFrame)
	local m = st.motors[name]
	if m then
		m.Transform = cf
	end
end

local function step(st: State, dt: number)
	local p = st.profile
	local state = st.model:GetAttribute("AnimState")

	if state == "Still" then
		if not st.frozen then
			for _, m in st.motors do
				m.Transform = CFrame.identity
			end
			st.frozen = true
		end
		return
	end
	st.frozen = false

	st.t += dt
	st.move += ((if state == "Move" then 1 else 0) - st.move) * math.min(1, dt * 8)
	local t, mv, idle = st.t, st.move, 1 - st.move
	local sc = st.scale
	local rad = math.rad

	local gait = t * p.strideRate
	local breathe = math.sin(t * 2.4) * p.breathe * idle
	local swing = rad(p.stride) * mv
	local headYaw = 0

	if p.gait == "Sprawler" then
		-- Reptile : le corps ondule en S, les pattes écartées balaient à l'horizontale
		-- et se soulèvent pendant le retour vers l'avant.
		local sway = math.sin(gait) * rad(p.sway) * mv + math.sin(t * 0.7) * rad(2) * idle
		set(st, "Body", CFrame.new(0, breathe * sc, 0) * CFrame.Angles(0, sway, 0))
		set(st, "Chest", CFrame.Angles(0, -sway * 1.6, 0))
		headYaw = sway * 0.6
		for _, leg in LEGS do
			local ph = gait + leg.phase
			local lift = math.max(0, math.cos(ph)) * rad(22) * mv
			set(st, leg.name, CFrame.Angles(0, leg.side * math.sin(ph) * swing, leg.side * lift))
		end
	else
		-- Quadrupède : rebond au trot, pattes en balancier (avant-droite avec arrière-gauche)
		local bob = math.abs(math.sin(gait)) * p.bob * mv
		set(st, "Body", CFrame.new(0, (breathe + bob) * sc, 0) * CFrame.Angles(math.sin(gait * 2) * 0.035 * mv, 0, 0))
		for _, leg in LEGS do
			set(st, leg.name, CFrame.Angles(math.sin(gait + leg.phase) * swing, 0, 0))
		end
	end

	-- Tête : regard lent + reniflements par salves
	st.sniffTimer -= dt
	if st.sniffTimer < -0.9 then
		st.sniffTimer = st.rng:NextNumber(1.5, 4)
	end
	local sniff = if p.sniff and st.sniffTimer < 0 then math.sin(t * 38) * rad(2.5) else 0
	local look = math.sin(t * 0.55) * math.sin(t * 0.23 + 1) * rad(p.headLook) * idle
	local nod = math.sin(gait * 2) * rad(3) * mv
	set(st, "Head", CFrame.Angles(sniff + nod - math.sin(t * 2.4) * rad(1.5) * idle, look + headYaw, 0))

	-- Langue fourchue : double coup de langue occasionnel, mâchoire entrouverte
	if p.tongueFlick then
		st.tongueTimer -= dt
		if st.tongueTimer < -FLICK_TIME then
			st.tongueTimer = st.rng:NextNumber(1.8, 4.5)
		end
		local out, open = 0, 0
		if st.tongueTimer < 0 then
			local u = -st.tongueTimer / FLICK_TIME
			out = math.sin(u * math.pi * 2) ^ 2
			open = math.sin(u * math.pi)
		end
		set(st, "Tongue", CFrame.new(0, 0, -0.4 * out * sc))
		set(st, "Jaw", CFrame.Angles(-rad(9) * open, 0, 0))
	end

	-- Oreilles : frémissement occasionnel d'un côté
	if p.earTwitch then
		st.earTimer -= dt
		if st.earTimer < -0.25 then
			st.earTimer = st.rng:NextNumber(1.2, 3.5)
			st.earSide = if st.rng:NextNumber() < 0.5 then 1 else -1
		end
		local tw = if st.earTimer < 0 then math.sin(-st.earTimer / 0.25 * math.pi) * rad(18) else 0
		set(st, "Ear_R", CFrame.Angles(if st.earSide > 0 then -tw else 0, 0, 0))
		set(st, "Ear_L", CFrame.Angles(if st.earSide < 0 then -tw else 0, 0, 0))
	end

	-- Queue : onde qui se propage de la base vers la pointe
	local amp = rad(p.tailSway) * (1 + mv * 0.6)
	local rate = p.tailRate * (1 + mv * 1.5)
	for i, m in st.tail do
		local k = i / #st.tail
		m.Transform = CFrame.Angles(math.sin(t * rate * 0.7 - i * 0.5) * rad(3), math.sin(t * rate - i * 0.6) * amp * (0.4 + k), 0)
	end
end

for _, inst in CollectionService:GetTagged(TAG) do
	track(inst)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
	if inst:IsA("Model") then
		untrack(inst)
	end
end)
-- Un modèle tagué peut être créé hors de Workspace puis y être déplacé
workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("Model") and inst:HasTag(TAG) then
		track(inst)
	end
end)

RunService.PreSimulation:Connect(function(dt)
	local camera = workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else Vector3.zero
	for _, st in states do
		if (st.root.Position - camPos).Magnitude <= MAX_DISTANCE * math.max(st.scale, 1) then
			step(st, dt)
		end
	end
end)
