--!strict
--[[
	CreatureForge.DnaMachine — la machine à ADN de chaque base
	==========================================================
	Chaque joueur a une machine à côté de sa base. On y pose l'ADN récolté (avec une seringue) :
	après une incubation, un personnage en sort. Plus l'ADN est RARE, plus on a de chances
	d'obtenir un BON personnage ; plus il y en a (meilleure seringue), plus la chance de monter
	d'une ou deux raretés augmente.

	    DnaMachine.odds("Legendary", 60)          --> { { rarity, chance }, ... }
	    local def, mutations = CreatureForge.hatch("Legendary", 60)   -- tirage (serveur)
	    DnaMachine.incubation("Legendary")        --> 60 secondes

	Règle (valeurs de départ à ajuster) : partant de la rareté de l'ADN, poids 1 pour la même
	rareté, 0,35 pour une rareté en dessous, 0,08 pour deux en dessous, 0,12 x qualité pour une
	au-dessus et 0,02 x qualité pour deux au-dessus (raretés ultimes freinées). La qualité vaut
	racine(quantité d'ADN / ADN de base de la rareté) : x1 avec une seringue basique, x4,5 avec
	celle du Néant.
]]

local Kit = require(script.Parent.Kit)
local A = require(script.Parent.Anatomy)
local Fx = require(script.Parent.Fx)
local Rarity = require(script.Parent.Rarity)
local Syringes = require(script.Parent.Syringes)

local S = Kit.style
local M = Enum.Material
local rgb = Color3.fromRGB
local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles

local DnaMachine = {}

DnaMachine.SAME = 1
DnaMachine.DOWN = { 0.35, 0.08 } -- poids d'une / deux raretés en dessous
DnaMachine.UP = { 0.12, 0.02 } -- poids d'une / deux raretés au-dessus (x qualité)
--- Frein pour atteindre les raretés ultimes depuis une rareté inférieure
DnaMachine.ULTIMATE = { Exotic = 0.15, Exclusive = 0.05, Chaotic = 0.01 } :: { [string]: number }
--- Durée d'incubation (secondes) selon la rareté de l'ADN
DnaMachine.INCUBATION = {
	Common = 10, Rare = 20, Epic = 40, Legendary = 60, Mythic = 90, Exotic = 120, Exclusive = 180, Chaotic = 300,
} :: { [string]: number }

--- Nom de l'ADN de chaque rareté (« ADN légendaire »)
DnaMachine.NAMES = {
	Common = "ADN commun", Rare = "ADN rare", Epic = "ADN épique", Legendary = "ADN légendaire",
	Mythic = "ADN mythique", Exotic = "ADN exotique", Exclusive = "ADN exclusif", Chaotic = "ADN chaotique",
} :: { [string]: string }

local function indexOf(rarity: string): number
	for i, id in Rarity.Order do
		if id == rarity then
			return i
		end
	end
	return 1
end

--- Qualité de l'ADN : racine du multiplicateur de la seringue qui l'a récolté (1 au minimum).
function DnaMachine.quality(rarity: string, amount: number?): number
	local base = Syringes.BASE_DNA[rarity] or 1
	return math.sqrt(math.max((amount or base) / base, 1))
end

--- Probabilités de chaque rareté pour un ADN de rareté `rarity` et de quantité `amount`.
function DnaMachine.odds(rarity: string, amount: number?): { { rarity: string, chance: number } }
	local r = indexOf(rarity)
	local q = DnaMachine.quality(rarity, amount)
	local weights: { [number]: number } = {}
	weights[r] = DnaMachine.SAME
	for k, w in DnaMachine.DOWN do
		if r - k >= 1 then
			weights[r - k] = w
		end
	end
	for k, w in DnaMachine.UP do
		local target = r + k
		if target <= #Rarity.Order then
			local brake = DnaMachine.ULTIMATE[Rarity.Order[target]] or 1
			weights[target] = w * q * brake
		end
	end
	local total = 0
	for _, w in weights do
		total += w
	end
	local out = {}
	for i = 1, #Rarity.Order do
		if weights[i] then
			table.insert(out, { rarity = Rarity.Order[i], chance = weights[i] / total })
		end
	end
	return out
end

--- Tire la rareté du personnage obtenu.
function DnaMachine.rollRarity(rarity: string, amount: number?, rng: Random?): string
	local r = (rng or Random.new()):NextNumber()
	for _, o in DnaMachine.odds(rarity, amount) do
		r -= o.chance
		if r <= 0 then
			return o.rarity
		end
	end
	return rarity
end

function DnaMachine.incubation(rarity: string): number
	return DnaMachine.INCUBATION[rarity] or 30
end

-- ---------------------------------------------------------------------------
-- Modèles
-- ---------------------------------------------------------------------------

local RAINBOW = { rgb(255, 70, 70), rgb(255, 170, 40), rgb(255, 240, 70), rgb(70, 230, 110), rgb(60, 170, 255), rgb(170, 90, 255) }

--- Couleur d'une rareté (arc-en-ciel / glitch : couleur n°i).
local function tint(rarity: string, i: number): Color3
	local t = Rarity.get(rarity)
	if t.rainbow then
		return RAINBOW[(i - 1) % #RAINBOW + 1]
	elseif t.glitch then
		return if i % 2 == 0 then rgb(0, 255, 230) else rgb(255, 0, 140)
	elseif t.gold then
		return if i % 2 == 0 then rgb(255, 200, 60) else rgb(30, 26, 34)
	end
	return t.color
end

--- Double hélice d'ADN verticale (bas en `base`, hauteur h, rayon r).
local function helix(rig: Kit.Rig, bone: string, base: Vector3, h: number, r: number, n: number, rarity: string, dot: number)
	for k = 0, n - 1 do
		local y = k / (n - 1) * h
		local a = k * (6.2 / n)
		local p1 = base + v3(math.cos(a) * r, y, math.sin(a) * r)
		local p2 = base + v3(-math.cos(a) * r, y, -math.sin(a) * r)
		rig:ball(bone, "Helix", p1, dot, S(tint(rarity, k), M.Neon))
		rig:ball(bone, "Helix", p2, dot, S(tint(rarity, k + 1), M.Neon))
		if k % 2 == 0 then
			rig:strut(bone, "HelixRung", p1, p2, dot * 0.3, dot * 0.3, S(rgb(255, 255, 255), M.Neon))
		end
	end
end

--- Machine à ADN (style Roblox) : socle, cuve de verre avec ADN qui tourne, entonnoir de dépôt,
--- console à écran et boutons, tuyaux, enseigne. Façade vers -Z ; `color` = couleur de la base.
function DnaMachine.build(opts: (Kit.BuildOptions & { color: Color3?, rarity: string? })?): Model
	local o: any = if opts then table.clone(opts) else {}
	local color: Color3 = o.color or rgb(60, 190, 255)
	o.color = nil
	o.outline = if o.outline == nil then false else o.outline
	local rig = Kit.newRig("MachineADN", o)
	local dark, metal, white = S(rgb(52, 56, 66)), S(rgb(170, 176, 188), M.Metal), S(rgb(245, 245, 248))
	local accent = S(color, M.Neon)
	-- Socle
	rig:block("Root", "Base", cf(0, 0.5, 0), v3(6, 1, 6), dark)
	rig:block("Root", "BaseTrim", cf(0, 1.02, 0), v3(6.1, 0.08, 6.1), accent)
	rig:block("Root", "Step", cf(0, 0.25, -3.6), v3(4, 0.5, 1.2), white)
	-- Cuve de verre
	local c = v3(0, 1, 0.4)
	rig:cylinder("Root", "TankBottom", c, c + v3(0, 0.6, 0), 4, metal)
	rig:cylinder("Root", "Tank", c + v3(0, 0.6, 0), c + v3(0, 5.6, 0), 3.4, S(rgb(200, 236, 255), M.Glass, { transparency = 0.55 }))
	rig:cylinder("Root", "Liquid", c + v3(0, 0.6, 0), c + v3(0, 4.4, 0), 3.0, S(color:Lerp(Color3.new(1, 1, 1), 0.3), M.Glass, { transparency = 0.72 }))
	for _, y in { 1.8, 3.2, 4.6 } do
		rig:cylinder("Root", "TankRing", c + v3(0, y - 0.09, 0), c + v3(0, y + 0.09, 0), 3.62, metal)
	end
	rig:cylinder("Root", "TankTop", c + v3(0, 5.6, 0), c + v3(0, 6.3, 0), 4, metal)
	rig:ball("Root", "Dome", c + v3(0, 6.3, 0), 2.6, white)
	rig:cylinder("Root", "Antenna", c + v3(0, 7.3, 0), c + v3(0, 8.2, 0), 0.2, metal)
	rig:ball("Root", "Beacon", c + v3(0, 8.3, 0), 0.5, accent)
	-- ADN qui tourne dans la cuve (os Spin1)
	rig:bone("Spin1", "Root", CFrame.fromMatrix(c + v3(0, 2.6, 0), v3(1, 0, 0), v3(0, 0, -1), v3(0, 1, 0)))
	local motor = rig.root:FindFirstChild("Spin1")
	if motor then
		motor:SetAttribute("Speed", 0.9)
	end
	helix(rig, "Spin1", c + v3(0, 1.0, 0), 3.2, 0.75, 10, o.rarity or "Rare", 0.44)
	-- Entonnoir de dépôt (avant gauche)
	local f = v3(-2.1, 1, -2.1)
	rig:cylinder("Root", "FunnelPipe", f, f + v3(0, 1.8, 0), 0.6, metal)
	rig:thorn("Root", "Funnel", cf(f + v3(0, 3.1, 0)) * ang(math.pi, 0, 0), 1.6, 1.3, S(color))
	rig:cylinder("Root", "FunnelRim", f + v3(0, 3.08, 0), f + v3(0, 3.16, 0), 1.75, accent)
	rig:cylinder("Root", "FunnelHole", f + v3(0, 3.1, 0), f + v3(0, 3.2, 0), 1.35, dark)
	-- Console (avant droite) : écran + boutons
	local k = cf(2.0, 1, -2.0)
	rig:prism("Root", "Console", k * cf(0, 1.4, 0), v3(1.8, 2.8, 1.4), 0.2, white)
	local screen = rig:block("Root", "Screen", k * cf(0, 2.1, -0.72) * ang(math.rad(-10), 0, 0), v3(1.4, 0.9, 0.06), S(rgb(14, 30, 50)))
	for i, col in { rgb(230, 50, 50), rgb(60, 210, 90), rgb(255, 210, 50) } do
		rig:ball("Root", "Button", (k * cf(-0.5 + (i - 1) * 0.5, 1.25, -0.72)).Position, 0.28, S(col, M.Neon))
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Status"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(280, 180)
	gui.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Name = "Label"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.RichText = true
	t.TextScaled = true
	t.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	t.TextColor3 = rgb(140, 255, 200)
	t.Text = "POSE TON ADN"
	t.Parent = gui
	gui.Parent = screen
	-- Tuyaux entre la console et le haut de la cuve
	local p0 = (k * cf(0, 2.9, 0.3)).Position
	local p1 = p0 + v3(0, 1.6, 0)
	local p2 = c + v3(1.6, 5.0, 0)
	rig:strut("Root", "Pipe", p0, p1, 0.3, 0.3, metal)
	rig:strut("Root", "Pipe", p1, p2, 0.3, 0.3, metal)
	rig:ball("Root", "PipeJoint", p1, 0.42, metal)
	rig:strut("Root", "PipeGlow", f + v3(0, 0.4, 0), c + v3(-1.5, 0.9, 0), 0.22, 0.22, accent)
	-- Enseigne
	local sign = rig:block("Root", "Sign", cf(0, 9.6, 0.4), v3(6, 1.6, 0.3), S(color))
	rig:block("Root", "SignFrame", cf(0, 9.6, 0.42), v3(6.3, 1.9, 0.25), dark)
	rig:block("Root", "SignPole", cf(0, 8.9, 0.6), v3(0.3, 1.2, 0.3), metal)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g2 = Instance.new("SurfaceGui")
		g2.Face = face
		g2.CanvasSize = Vector2.new(400, 110)
		g2.LightInfluence = 0
		local t2 = Instance.new("TextLabel")
		t2.Size = UDim2.fromScale(1, 1)
		t2.BackgroundTransparency = 1
		t2.TextScaled = true
		t2.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		t2.TextColor3 = Color3.new(1, 1, 1)
		t2.TextStrokeTransparency = 0.2
		t2.Text = "MACHINE À ADN"
		t2.Parent = g2
		g2.Parent = sign
	end
	-- Interaction : poser l'ADN
	local base = rig.model:FindFirstChild("Root")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DepositPrompt"
	prompt.ActionText = "Poser l'ADN"
	prompt.ObjectText = "Machine à ADN"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	-- Socle, cuve et console bloquent les joueurs (le reste est décoratif)
	local SOLID = { Base = true, Step = true, TankBottom = true, Tank = true, TankTop = true, Console = true }
	for _, d in rig.model:GetDescendants() do
		if d:IsA("BasePart") and SOLID[d.Name] then
			d.CanCollide = true
		end
	end
	if rig.effects then
		local fx = rig:anchor("Root", "FX_Tank", cf(c + v3(0, 3, 0)), v3(2.6, 3.6, 2.6))
		Fx.particles(fx, Fx.sparkles("Bubbles", { rgb(255, 255, 255), color }, 8, 0.2, 0.8), rig.scale)
		Fx.light(fx, { color = color, range = 14, brightness = 1.6 }, rig.scale)
	end
	return rig:finish({ MachineId = "MachineADN" })
end

--- Fragment d'ADN (capsule avec sa double hélice) aux couleurs de sa rareté. Posé au sol
--- (bas de la capsule au pivot), ou centré sur le pivot avec `centered` (poignée du Tool).
function DnaMachine.buildDna(rarity: string, opts: Kit.BuildOptions?, centered: boolean?): Model
	local o: Kit.BuildOptions = if opts then table.clone(opts) else {}
	o.animated = if o.animated == nil then false else o.animated
	o.outline = if o.outline == nil then false else o.outline
	local rig = Kit.newRig("ADN_" .. rarity, o)
	local y = if centered then 0 else 0.95
	local metal = S(rgb(200, 206, 218), M.Metal)
	rig:cylinder("Root", "Capsule", v3(0, y - 0.7, 0), v3(0, y + 0.7, 0), 0.9, S(tint(rarity, 1):Lerp(Color3.new(1, 1, 1), 0.6), M.Glass, { transparency = 0.5 }))
	rig:cylinder("Root", "Cap", v3(0, y + 0.7, 0), v3(0, y + 0.95, 0), 1.0, metal)
	rig:cylinder("Root", "Cap", v3(0, y - 0.95, 0), v3(0, y - 0.7, 0), 1.0, metal)
	helix(rig, "Root", v3(0, y - 0.6, 0), 1.2, 0.22, 9, rarity, 0.16)
	A.crystals(rig, "Root", cf(0, y + 0.95, 0), 3, 0.25, { S(tint(rarity, 1), M.Neon), S(tint(rarity, 2), M.Neon) }, 3, 0.2)
	if rig.effects then
		local fx = rig:anchor("Root", "FX_Dna", cf(0, y, 0), v3(1, 1.6, 1))
		Fx.particles(fx, Fx.sparkles("DnaGlow", { tint(rarity, 1), tint(rarity, 2) }, 5, 0.1), rig.scale)
		Fx.light(fx, { color = tint(rarity, 1), range = 6, brightness = 1 }, rig.scale)
	end
	return rig:finish({ DnaRarity = rarity })
end

--- Outil (Tool) « ADN » que le joueur porte (il tombe si on le frappe).
function DnaMachine.buildDnaTool(rarity: string, amount: number): Tool
	local model = DnaMachine.buildDna(rarity, { animated = false, outline = false }, true)
	local tool = Instance.new("Tool")
	local name = DnaMachine.NAMES[rarity] or "ADN"
	tool.Name = name
	tool.CanBeDropped = true
	tool.ToolTip = `{name} ({amount})`
	local root = model.PrimaryPart :: BasePart
	root.Name = "Handle"
	root.Anchored = false
	root.Size = Vector3.new(0.6, 1.2, 0.6)
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	tool:SetAttribute("DnaRarity", rarity)
	tool:SetAttribute("DnaAmount", amount)
	model:Destroy()
	return tool
end

return DnaMachine
