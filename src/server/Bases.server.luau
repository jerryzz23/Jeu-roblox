--!strict
--[[
	Bases (ServerScriptService)
	---------------------------
	- Attribue un enclos libre (Carte > Bases > Base1..8) à chaque joueur qui arrive : attribut
	  Owner = UserId, panneau à son nom ; l'enclos est libéré quand il part.
	- Tient à jour le tableau de la boutique de seringues (StockBoard) : stock du créneau de
	  5 minutes en cours (Syringes.stockAt, identique sur tous les serveurs) + compte à rebours.

	L'achat, l'inventaire et la sauvegarde ne sont pas gérés ici : ce script prépare la carte.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreatureForge = require(ReplicatedStorage:WaitForChild("CreatureForge"))
local Syringes = CreatureForge.Syringes
local Spawning = CreatureForge.Spawning

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

local function assign(player: Player)
	for _, plot in plots() do
		if plot:GetAttribute("Owner") == "" then
			plot:SetAttribute("Owner", tostring(player.UserId))
			setSign(plot, player.DisplayName)
			player:SetAttribute("Plot", plot:GetAttribute("PlotIndex"))
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
