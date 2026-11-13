--!strict
--[[
	Bases (ServerScriptService)
	---------------------------
	- Attribue un enclos libre (Carte > Bases > Base1..8) à chaque joueur qui arrive : attribut
	  Owner = UserId, panneau à son nom ; l'enclos est libéré quand il part.
	- Tient à jour le tableau de la boutique de seringues (StockBoard) : stock du créneau de
	  5 minutes en cours (Syringes.stockAt, identique sur tous les serveurs) + compte à rebours.
	- Machine à ADN de chaque base (une par joueur) : le propriétaire y pose un ADN (Tool avec
	  les attributs DnaRarity / DnaAmount, voir DnaMachine.buildDnaTool). Après l'incubation,
	  CreatureForge.hatch tire le personnage (plus l'ADN est rare, meilleures sont les chances)
	  et il apparaît sur une place libre de la base.
	  En Studio, chaque joueur reçoit 3 ADN de test pour essayer la machine.

	L'achat, l'inventaire et la sauvegarde ne sont pas gérés ici : ce script prépare la carte.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CreatureForge = require(ReplicatedStorage:WaitForChild("CreatureForge"))
local Syringes = CreatureForge.Syringes
local Spawning = CreatureForge.Spawning
local DnaMachine = CreatureForge.DnaMachine
local Rarity = CreatureForge.Rarity

local map = workspace:WaitForChild("Carte", 30) :: Model?
if not map then
	warn("[Bases] aucune carte « Carte » dans Workspace")
	return
end

local function plots(): { Model }
	local out = {}
	for _, d in (map :: Model):GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("PlotIndex") then
			table.insert(out, d)
		end
	end
	table.sort(out, function(a, b)
		return (a:GetAttribute("PlotIndex") :: number) < (b:GetAttribute("PlotIndex") :: number)
	end)
	return out
end

local function setSign(plot: Model, text: string)
	local sign = plot:FindFirstChild("OwnerSign", true)
	local label = sign and sign:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		label.Text = `<b>{text}</b>`
	end
end

-- ---------------------------------------------------------------------------
-- Machine à ADN
-- ---------------------------------------------------------------------------

local PLACE_SPAN = 9 -- taille max (studs) d'un personnage posé sur une place de la base
local IDLE_TEXT = "POSE TON ADN"
local tokens: { [Model]: number } = {} -- invalide une incubation en cours (départ du joueur)

local function screen(plot: Model, text: string)
	local machine = plot:FindFirstChild("MachineADN")
	local status = machine and machine:FindFirstChild("Status", true)
	local label = status and status:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function colored(rarity: string, text: string): string
	return `<font color="#{Rarity.get(rarity).color:ToHex()}">{text}</font>`
end

--- Colore l'hélice d'ADN de la cuve (couleur de la rareté posée, ou celle de départ).
local helixColors: { [BasePart]: Color3 } = {}
local function paintHelix(plot: Model, rarity: string?)
	local machine = plot:FindFirstChild("MachineADN")
	if not machine then
		return
	end
	local k = 0
	for _, d in machine:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Helix" then
			k += 1
			helixColors[d] = helixColors[d] or d.Color
			d.Color = if rarity then Rarity.colorAt(rarity, k * 0.15) else helixColors[d]
		end
	end
end

local function ownerOf(plot: Model): Player?
	local id = tonumber(plot:GetAttribute("Owner") :: string?)
	return if id then Players:GetPlayerByUserId(id) else nil
end

--- L'ADN tenu en main, sinon le plus rare du sac.
local function findDna(player: Player): Tool?
	local char = player.Character
	if char then
		local held = char:FindFirstChildOfClass("Tool")
		if held and held:GetAttribute("DnaRarity") then
			return held
		end
	end
	local best: Tool?, bestOrder = nil, 0
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, t in backpack:GetChildren() do
			local r = t:GetAttribute("DnaRarity")
			if t:IsA("Tool") and typeof(r) == "string" and Rarity.get(r).order > bestOrder then
				best, bestOrder = t, Rarity.get(r).order
			end
		end
	end
	return best
end

local function creaturesFolder(plot: Model): Folder
	local f = plot:FindFirstChild("Personnages")
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "Personnages"
	nf.Parent = plot
	return nf
end

--- Places (pastilles) de la base, dans l'ordre, et la première libre.
local function freeSlot(plot: Model): (BasePart?, number)
	local slots = {}
	for _, d in plot:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "CreatureSlot" then
			table.insert(slots, d)
		end
	end
	table.sort(slots, function(a, b)
		local pa, pb = a.Position, b.Position
		return if math.abs(pa.Z - pb.Z) > 0.5 then pa.Z < pb.Z else pa.X < pb.X
	end)
	local used = {}
	for _, m in creaturesFolder(plot):GetChildren() do
		used[m:GetAttribute("Slot") :: number? or 0] = true
	end
	for i, slot in slots do
		if not used[i] then
			return slot, i
		end
	end
	return nil, 0
end

local function placeCreature(plot: Model, slot: BasePart, index: number, def: any, mutations: { string })
	local span = (Rarity.Sizes[def.Size] or Rarity.Sizes.Medium).span
	local pos = slot.Position + Vector3.new(0, slot.Size.Y / 2, 0)
	local path = plot:FindFirstChild("PlotPath", true)
	local look = if path and path:IsA("BasePart") then Vector3.new(path.Position.X, pos.Y, path.Position.Z) else pos + Vector3.new(0, 0, -1)
	local model = CreatureForge.spawn(def.Id, CFrame.lookAt(pos, look), {
		scale = def.Scale * math.min(1, PLACE_SPAN / span),
		mutations = mutations,
		parent = creaturesFolder(plot),
	})
	model:SetAttribute("Slot", index)
	CreatureForge.setAnimState(model, "Idle")
end

local function deposit(plot: Model, prompt: ProximityPrompt, player: Player)
	if ownerOf(plot) ~= player then
		screen(plot, "PAS TA MACHINE !")
		task.delay(2, function()
			if prompt.Enabled then
				screen(plot, if ownerOf(plot) then IDLE_TEXT else "BASE LIBRE")
			end
		end)
		return
	end
	local tool = findDna(player)
	if not tool then
		screen(plot, "IL TE FAUT DE L'ADN !<br/><font size=\"40\">Récolte-le dans le canyon</font>")
		return
	end
	local slot = freeSlot(plot)
	if not slot then
		screen(plot, "BASE PLEINE !")
		return
	end
	local rarity = tool:GetAttribute("DnaRarity") :: string
	local amount = (tool:GetAttribute("DnaAmount") :: number?) or 1
	tool:Destroy()
	prompt.Enabled = false
	paintHelix(plot, rarity)
	local token = (tokens[plot] or 0) + 1
	tokens[plot] = token
	-- Incubation : compte à rebours + chance de monter d'une rareté
	local lines = `{colored(rarity, "ADN " .. Rarity.get(rarity).label)}`
	local up = Rarity.Order[Rarity.get(rarity).order + 1]
	for _, o in DnaMachine.odds(rarity, amount) do
		if o.rarity == up then
			lines ..= `<br/><font size="34">{string.format("%.1f", o.chance * 100)} % {colored(up, Rarity.get(up).label)}</font>`
		end
	end
	local left = DnaMachine.incubation(rarity)
	while left > 0 do
		if tokens[plot] ~= token then
			return
		end
		screen(plot, `{lines}<br/>{string.format("%d:%02d", left // 60, left % 60)}`)
		task.wait(1)
		left -= 1
	end
	if tokens[plot] ~= token then
		return
	end
	-- Éclosion : la place a pu être prise entre-temps → on en reprend une libre
	local def, mutations = CreatureForge.hatch(rarity, amount)
	local freeNow, index = freeSlot(plot)
	if def and freeNow then
		placeCreature(plot, freeNow, index, def, mutations)
		local muts = if #mutations > 0 then `<br/><font size="30">+ {table.concat(mutations, ", ")}</font>` else ""
		screen(plot, `{colored(def.Rarity, def.DisplayName)}{muts}`)
	else
		screen(plot, "BASE PLEINE !")
	end
	task.wait(6)
	if tokens[plot] == token then
		paintHelix(plot, nil)
		prompt.Enabled = true
		screen(plot, if ownerOf(plot) then IDLE_TEXT else "BASE LIBRE")
	end
end

local function resetPlot(plot: Model)
	tokens[plot] = (tokens[plot] or 0) + 1
	creaturesFolder(plot):ClearAllChildren()
	paintHelix(plot, nil)
	local machine = plot:FindFirstChild("MachineADN")
	local prompt = machine and machine:FindFirstChild("DepositPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = true
	end
end

for _, plot in plots() do
	local machine = plot:FindFirstChild("MachineADN")
	local prompt = machine and machine:FindFirstChild("DepositPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player)
			deposit(plot, prompt, player)
		end)
	end
	screen(plot, "BASE LIBRE")
end

--- ADN de test (Studio uniquement) pour essayer la machine sans le reste du jeu.
local function giveTestDna(player: Player)
	if not RunService:IsStudio() then
		return
	end
	local backpack = player:WaitForChild("Backpack", 10)
	if backpack then
		for _, r in { "Common", "Epic", "Legendary" } do
			DnaMachine.buildDnaTool(r, CreatureForge.Syringes.BASE_DNA[r]).Parent = backpack
		end
	end
end

local function assign(player: Player)
	for _, plot in plots() do
		if plot:GetAttribute("Owner") == "" then
			plot:SetAttribute("Owner", tostring(player.UserId))
			setSign(plot, player.DisplayName)
			resetPlot(plot)
			screen(plot, IDLE_TEXT)
			player:SetAttribute("Plot", plot:GetAttribute("PlotIndex"))
			task.spawn(giveTestDna, player)
			return
		end
	end
	warn(`[Bases] plus d'enclos libre pour {player.Name}`)
end

local function release(player: Player)
	for _, plot in plots() do
		if plot:GetAttribute("Owner") == tostring(player.UserId) then
			plot:SetAttribute("Owner", "")
			setSign(plot, "BASE LIBRE")
			resetPlot(plot)
			screen(plot, "BASE LIBRE")
		end
	end
end

for _, p in Players:GetPlayers() do
	assign(p)
end
Players.PlayerAdded:Connect(assign)
Players.PlayerRemoving:Connect(release)

-- Tableau du stock de seringues
local board = (map :: Model):FindFirstChild("StockBoard", true)
local boardLabel = board and board:FindFirstChild("Label", true)
while boardLabel and boardLabel:IsA("TextLabel") do
	local now = os.time()
	local lines = {}
	for _, e in Syringes.stockAt(now) do
		local def = Syringes.get(e.id)
		table.insert(lines, `{def.DisplayName} x{e.quantity} · {Spawning.formatMoney(e.price)} $`)
	end
	local left = Syringes.timeUntilRestock(now)
	table.insert(lines, string.format("Réassort dans %d:%02d", left // 60, left % 60))
	boardLabel.Text = table.concat(lines, "<br/>")
	task.wait(1)
end
