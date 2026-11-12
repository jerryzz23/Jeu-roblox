--!strict
--[[
	CreatureAnimator (StarterPlayerScripts)
	---------------------------------------
	Anime de façon procédurale, côté client, toutes les créatures taguées "CreatureForge"
	présentes dans Workspace, en pilotant Motor6D.Transform (non répliqué : zéro trafic réseau).

	L'état est lu dans l'attribut "AnimState" du modèle (posé par le serveur) :
	  "Idle"  : respiration, regard, oreilles, queue, langue, orbites qui tournent
	  "Move"  : déplacement selon la démarche (Types.AnimProfile.gait) :
	            Quadruped -> trot diagonal + rebond          Sprawler -> pattes écartées + ondulation
	            Flyer     -> battements d'ailes rapides      Serpent  -> ondulation de tout le corps
	            Hover     -> lévitation inclinée vers l'avant
	  "Still" : pose figée (vitrines, captures d'écran)
	  "Ability" : capacité spéciale (CreatureForge.playAbility) — effets Vfx.playAbility + pose
	              de rugissement / battements puissants, déclenchée à chaque incrément de
	              l'attribut "AbilitySeq"

	Conventions de nommage des os (Motor6D) : Body, Chest, Head, Jaw, Tongue, Ear_R/L,
	Leg_FR/FL/BR/BL, Leg_R/L (oiseaux), Wing_R/L, Tail1..n, Seg1..n (serpents), Aura1..n (orbites).
	Les créatures à plus de MAX_DISTANCE studs de la caméra ne sont pas animées.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CreatureForge = require(ReplicatedStorage:WaitForChild("CreatureForge"))

local MAX_DISTANCE = 160
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
	flap: number,
	flapRate: number,
	hover: number,
	auraSpeed: number,
	flicker: number,
}

type State = {
	model: Model,
	root: BasePart,
	profile: Profile,
	scale: number,
	motors: { [string]: Motor6D },
	tail: { Motor6D },
	segs: { Motor6D },
	auras: { Motor6D },
	lights: { { light: Light, base: number } },
	ability: any,
	abilitySeq: any,
	abilityT: number,
	t: number,
	move: number,
	rng: Random,
	earTimer: number,
	earSide: number,
	sniffTimer: number,
	tongueTimer: number,
	frozen: boolean,
	mutations: any,
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
		flap = p.flap or 35,
		flapRate = p.flapRate or 6,
		hover = p.hover or 0.15,
		auraSpeed = p.auraSpeed or 0.6,
		flicker = p.flicker or 0,
	}
end

local function chain(motors: { [string]: Motor6D }, prefix: string): { Motor6D }
	local out = {}
	local i = 1
	while motors[prefix .. i] do
		table.insert(out, motors[prefix .. i])
		i += 1
	end
	return out
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
	if st.mutations then
		st.mutations:destroy()
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

	local id = model:GetAttribute("CreatureId")
	local def = if typeof(id) == "string" and CreatureForge.has(id) then CreatureForge.get(id) else nil
	local auras = {}
	for name, m in motors do
		if string.sub(name, 1, 4) == "Aura" then
			table.insert(auras, m)
		end
	end
	table.sort(auras, function(a, b)
		return a.Name < b.Name
	end)
	local lights = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Light") then
			table.insert(lights, { light = d, base = d.Brightness })
		end
	end
	local seed = math.floor((root.Position.X * 73 + root.Position.Z * 19) % 100000)
	local ok, rt = pcall(CreatureForge.Mutations.runtime, model, motors)
	if not ok then
		warn("[CreatureAnimator] mutations :", rt)
		rt = nil
	end
	local st: State = {
		model = model,
		root = root,
		profile = readProfile(if typeof(id) == "string" then id else nil),
		scale = (model:GetAttribute("Scale") :: number?) or 1,
		motors = motors,
		tail = chain(motors, "Tail"),
		segs = chain(motors, "Seg"),
		auras = auras,
		lights = lights,
		ability = if def then def.Ability else nil,
		abilitySeq = model:GetAttribute("AbilitySeq"),
		abilityT = -1,
		t = seed % 100,
		move = 0,
		rng = Random.new(seed),
		earTimer = 1,
		earSide = 1,
		sniffTimer = 2,
		tongueTimer = 1.5,
		frozen = false,
		mutations = rt,
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

local function set(st: State, name: string, c: CFrame)
	local m = st.motors[name]
	if m then
		m.Transform = c
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
		local sway = math.sin(gait) * rad(p.sway) * mv + math.sin(t * 0.7) * rad(2) * idle
		set(st, "Body", CFrame.new(0, breathe * sc, 0) * CFrame.Angles(0, sway, 0))
		set(st, "Chest", CFrame.Angles(0, -sway * 1.6, 0))
		headYaw = sway * 0.6
		for _, leg in LEGS do
			local ph = gait + leg.phase
			local lift = math.max(0, math.cos(ph)) * rad(22) * mv
			set(st, leg.name, CFrame.Angles(0, leg.side * math.sin(ph) * swing, leg.side * lift))
		end
	elseif p.gait == "Flyer" then
		-- Oiseau en vol stationnaire : battements d'ailes, corps qui monte et descend
		local rate = p.flapRate * (1 + mv * 0.6)
		local beat = math.sin(t * rate)
		local flap = beat * rad(p.flap) * (0.7 + mv * 0.4)
		set(st, "Body", CFrame.new(0, (-beat * p.hover + breathe) * sc, 0) * CFrame.Angles(-rad(14) * mv, 0, 0))
		set(st, "Wing_R", CFrame.Angles(0, 0, flap))
		set(st, "Wing_L", CFrame.Angles(0, 0, -flap))
		set(st, "WingTip_R", CFrame.Angles(0, 0, math.sin(t * rate - 0.8) * rad(p.flap) * 0.5))
		set(st, "WingTip_L", CFrame.Angles(0, 0, -math.sin(t * rate - 0.8) * rad(p.flap) * 0.5))
		set(st, "Leg_R", CFrame.Angles(rad(25) * mv + math.sin(t * 1.3) * rad(4), 0, 0))
		set(st, "Leg_L", CFrame.Angles(rad(25) * mv + math.sin(t * 1.3 + 1) * rad(4), 0, 0))
	elseif p.gait == "Serpent" then
		-- Serpent : une onde parcourt les segments de la tête vers la queue
		local amp = rad(p.sway) * (0.5 + mv)
		local rate = p.tailRate * (1 + mv * 1.5)
		set(st, "Body", CFrame.new(0, breathe * sc, 0))
		for i, m in st.segs do
			local k = i / math.max(#st.segs, 1)
			m.Transform = CFrame.Angles(math.sin(t * rate * 0.6 - i * 0.4) * rad(2), math.sin(t * rate - i * 0.55) * amp * (0.3 + k), 0)
		end
	elseif p.gait == "Biped" then
		-- Géant debout : pas lourds, balancier des bras, buste qui roule
		local ph = gait
		local step = math.abs(math.sin(ph)) * p.bob * mv
		set(st, "Body", CFrame.new(0, (breathe + step) * sc, 0) * CFrame.Angles(0, math.sin(ph) * rad(4) * mv + math.sin(t * 0.5) * rad(3) * idle, math.sin(ph) * rad(3) * mv))
		set(st, "Leg_R", CFrame.Angles(math.sin(ph) * swing, 0, 0))
		set(st, "Leg_L", CFrame.Angles(-math.sin(ph) * swing, 0, 0))
		set(st, "Arm_R", CFrame.Angles(-math.sin(ph) * swing * 0.7 + math.sin(t * 1.1) * rad(4) * idle, 0, math.sin(t * 0.8) * rad(3)))
		set(st, "Arm_L", CFrame.Angles(math.sin(ph) * swing * 0.7 + math.sin(t * 1.1 + 1) * rad(4) * idle, 0, -math.sin(t * 0.8) * rad(3)))
	elseif p.gait == "Hover" then
		-- Lévitation : flottement lent, légère inclinaison en mouvement
		local float = math.sin(t * 1.3) * p.hover
		set(st, "Body", CFrame.new(0, float * sc, 0) * CFrame.Angles(-rad(10) * mv + math.sin(t * 0.9) * rad(2), math.sin(t * 0.5) * rad(4), 0))
		set(st, "Arm_R", CFrame.Angles(math.sin(t * 1.1) * rad(8), 0, math.sin(t * 0.8) * rad(6)))
		set(st, "Arm_L", CFrame.Angles(math.sin(t * 1.1 + 1.4) * rad(8), 0, -math.sin(t * 0.8 + 1) * rad(6)))
		-- Ailes éventuelles : battements lents et majestueux (deux paires possibles)
		local w = math.sin(t * 2.2) * rad(16) * (1 + mv * 0.5)
		local w2 = math.sin(t * 2.2 - 0.8) * rad(12) * (1 + mv * 0.5)
		set(st, "Wing_R", CFrame.Angles(0, 0, w))
		set(st, "Wing_L", CFrame.Angles(0, 0, -w))
		set(st, "Wing2_R", CFrame.Angles(0, 0, w2))
		set(st, "Wing2_L", CFrame.Angles(0, 0, -w2))
	else
		-- Quadrupède : rebond au trot, pattes en balancier (avant-droite avec arrière-gauche)
		local bob = math.abs(math.sin(gait)) * p.bob * mv
		set(st, "Body", CFrame.new(0, (breathe + bob) * sc, 0) * CFrame.Angles(math.sin(gait * 2) * 0.035 * mv, 0, 0))
		for _, leg in LEGS do
			set(st, leg.name, CFrame.Angles(math.sin(gait + leg.phase) * swing, 0, 0))
		end
		-- Ailes repliées éventuelles (ex. créatures ailées terrestres)
		set(st, "Wing_R", CFrame.Angles(0, 0, math.sin(t * 1.6) * rad(6)))
		set(st, "Wing_L", CFrame.Angles(0, 0, -math.sin(t * 1.6) * rad(6)))
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
	elseif st.motors.Jaw then
		-- Mâchoire qui respire légèrement
		set(st, "Jaw", CFrame.Angles(-rad(3) * (0.5 + 0.5 * math.sin(t * 1.7)), 0, 0))
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

	-- Os "SwayN" (tentacules, voiles) : ondulation douce, cumulée le long des chaînes ;
	-- os "FloatN" (mains, poings flottants) : flottement et légère rotation ;
	-- os "Belt" (bande des tapis de course) et "SpinN" (rotations continues)
	for name, m in st.motors do
		local prefix = string.sub(name, 1, 4)
		if prefix == "Sway" then
			local k = tonumber(string.sub(name, 5)) or 0
			m.Transform = CFrame.Angles(math.sin(t * 1.4 + k * 0.9) * rad(9), 0, math.sin(t * 1.1 + k * 0.7) * rad(9))
		elseif prefix == "Belt" then
			-- Bande d'un tapis de course : les lattes défilent vers l'arrière (boucle sur l'espacement)
			local speed = (m:GetAttribute("BeltSpeed") :: number?) or 3
			local spacing = (m:GetAttribute("BeltSpacing") :: number?) or 0.5
			m.Transform = CFrame.new(0, 0, ((t * speed) % spacing) * sc)
		elseif prefix == "Spin" then
			-- Engrenages, portails, lunes : rotation continue autour de l'axe Z de l'os
			m.Transform = CFrame.Angles(0, 0, t * ((m:GetAttribute("Speed") :: number?) or 1))
		elseif prefix == "Floa" then
			local k = tonumber(string.sub(name, 6)) or 0
			m.Transform = CFrame.new(0, math.sin(t * 1.6 + k * 2) * 0.15 * sc, 0)
				* CFrame.Angles(math.sin(t * 0.9 + k) * rad(8), math.sin(t * 0.7 + k) * rad(12), 0)
		end
	end

	-- Orbites : chaque anneau tourne (sens alterné) et ondule doucement ; l'aura au sol tourne lentement
	for i, m in st.auras do
		if m.Name == "AuraGround" then
			m.Transform = CFrame.Angles(0, t * 0.25, 0)
		else
			local dir = if i % 2 == 0 then -1 else 1
			m.Transform = CFrame.new(0, math.sin(t * 1.1 + i) * 0.08 * sc, 0) * CFrame.Angles(0, t * p.auraSpeed * dir * (1 + i * 0.25), 0)
		end
	end

	-- Capacité spéciale : effets (une fois par déclenchement) + pose
	local seq = st.model:GetAttribute("AbilitySeq")
	if seq ~= st.abilitySeq then
		st.abilitySeq = seq
		if st.ability then
			st.abilityT = 0
			local ok, err = pcall(CreatureForge.Vfx.playAbility, st.model, st.ability)
			if not ok then
				warn("[CreatureAnimator] capacité :", err)
			end
		end
	end
	if st.abilityT >= 0 and st.ability then
		local dur = st.ability.duration or 1.6
		st.abilityT += dt
		local k = math.sin(math.pi * math.min(1, st.abilityT / dur))
		local function add(name: string, extra: CFrame)
			local m = st.motors[name]
			if m then
				m.Transform = m.Transform * extra
			end
		end
		if p.gait == "Flyer" then
			local f = math.sin(st.abilityT * 22) * rad(p.flap) * 0.6 * k
			add("Wing_R", CFrame.Angles(0, 0, f))
			add("Wing_L", CFrame.Angles(0, 0, -f))
			add("Body", CFrame.Angles(rad(18) * k, 0, 0))
		elseif p.gait == "Quadruped" then
			add("Body", CFrame.new(0, 0.1 * k * sc, 0) * CFrame.Angles(rad(12) * k, 0, 0))
		elseif p.gait == "Hover" then
			add("Body", CFrame.new(0, 0.3 * k * sc, 0))
			add("Arm_R", CFrame.Angles(0, 0, rad(35) * k))
			add("Arm_L", CFrame.Angles(0, 0, -rad(35) * k))
		end
		add("Head", CFrame.Angles(rad(22) * k, 0, 0))
		add("Jaw", CFrame.Angles(-rad(22) * k, 0, 0))
		if st.abilityT >= dur then
			st.abilityT = -1
		end
	end

	-- Mutations animées (engrenages, mirage, aurore, écho, paradoxe)
	if st.mutations then
		st.mutations:step(t, dt)
	end

	-- Lumières : vacillement (feu) ou légère pulsation
	if #st.lights > 0 then
		local amp = if p.flicker > 0 then p.flicker else 0.08
		for i, L in st.lights do
			L.light.Brightness = L.base * (1 + amp * 2 * math.noise(t * (if p.flicker > 0 then 7 else 1.5), i * 1.7))
		end
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
