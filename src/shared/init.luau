--!strict
--[[
	CreatureForge (ReplicatedStorage.CreatureForge)
	===============================================
	Point d'entrée : registre des créatures + fabrique de modèles et d'icônes.

	    local CreatureForge = require(ReplicatedStorage.CreatureForge)
	    local renard = CreatureForge.spawn("RenardDesCendres", CFrame.new(0, 0, -10), { mutations = { "Kintsugi" } })
	    CreatureForge.setAnimState(renard, "Move")             -- "Idle" | "Move" | "Still"
	    CreatureForge.buildIcon("RenardDesCendres", someFrame) -- carte d'inventaire
	    local def, mutations = CreatureForge.rollSpawn(0.8)    -- apparition dans le canyon

	Ajouter une créature = déposer un ModuleScript dans CreatureForge/Creatures
	(voir Types.CreatureDef ; un module peut aussi renvoyer une liste de définitions).
	Elle est enregistrée automatiquement.
]]

local Kit = require(script.Kit)
local Fx = require(script.Fx)
local Rarity = require(script.Rarity)
local Icon = require(script.Icon)
local Anatomy = require(script.Anatomy)
local Mutations = require(script.Mutations)
local Vfx = require(script.Vfx)
local Types = require(script.Types)
local Spawning = require(script.Spawning)
local Treadmills = require(script.Treadmills)
local Map = require(script.Map)
local Weapons = require(script.Weapons)
local Syringes = require(script.Syringes)
local DnaMachine = require(script.DnaMachine)

export type CreatureDef = Types.CreatureDef
export type AnimState = "Idle" | "Move" | "Still" | "Ability"

local CreatureForge = {
	Kit = Kit,
	Fx = Fx,
	Rarity = Rarity,
	Icon = Icon,
	Anatomy = Anatomy,
	Mutations = Mutations,
	Vfx = Vfx,
	Spawning = Spawning,
	Treadmills = Treadmills,
	Map = Map,
	Weapons = Weapons,
	Syringes = Syringes,
	DnaMachine = DnaMachine,
	TAG = Kit.TAG,
}

local registry: { [string]: Types.CreatureDef } = {}

for _, m in script.Creatures:GetChildren() do
	if m:IsA("ModuleScript") then
		-- Un module renvoie une définition, ou une liste de définitions (ex. les 10 variétés du Néant)
		local result: any = require(m)
		local defs: { Types.CreatureDef } = if result.Id then { result } else result
		for _, def in defs do
			assert(registry[def.Id] == nil, `CreatureForge: identifiant en double "{def.Id}"`)
			registry[def.Id] = def
		end
	end
end

function CreatureForge.get(id: string): Types.CreatureDef
	local def = registry[id]
	assert(def, `CreatureForge: créature inconnue "{id}"`)
	return def
end

function CreatureForge.has(id: string): boolean
	return registry[id] ~= nil
end

--- Toutes les créatures, triées par rareté puis par nom.
function CreatureForge.list(): { Types.CreatureDef }
	local out = {}
	for _, def in registry do
		table.insert(out, def)
	end
	table.sort(out, function(a, b)
		local ra, rb = Rarity.get(a.Rarity).order, Rarity.get(b.Rarity).order
		if ra ~= rb then
			return ra < rb
		end
		if (a.Order or 0) ~= (b.Order or 0) then
			return (a.Order or 0) < (b.Order or 0)
		end
		return a.DisplayName < b.DisplayName
	end)
	return out
end

--- Selles : chaque créature est une monture ("Saddle") ; les grandes ont une selle passager
--- ("PassengerSeat") juste derrière (débloquée en jeu par la selle passager).
local function ensureSeats(model: Model, def: Types.CreatureDef)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local scale = (model:GetAttribute("Scale") :: number?) or 1
	local saddle = model:FindFirstChild("Saddle")
	if not (saddle and saddle:IsA("Seat")) then
		-- Point le plus haut du dos, près de l'axe du corps
		local bones = model:FindFirstChild("Bones")
		local body = if bones then bones:FindFirstChild("Body") else nil
		local bodyFolder = model:FindFirstChild("Body")
		if not (body and body:IsA("BasePart")) then
			return
		end
		local top = (body :: BasePart).CFrame.Position.Y
		if bodyFolder then
			for _, d in bodyFolder:GetChildren() do
				if d:IsA("BasePart") and d.Transparency < 0.95 then
					local lp = root.CFrame:PointToObjectSpace(d.CFrame.Position)
					local bp = root.CFrame:PointToObjectSpace((body :: BasePart).CFrame.Position)
					if math.abs(lp.X) < 0.35 * scale and math.abs(lp.Z - bp.Z) < 0.6 * scale then
						top = math.max(top, d.CFrame.Position.Y + d.Size.Y * 0.3)
					end
				end
			end
		end
		local bpos = (body :: BasePart).CFrame.Position
		local seat = Instance.new("Seat")
		seat.Name = "Saddle"
		seat.Size = Vector3.new(0.8, 0.2, 0.8) * scale
		seat.Transparency = 1
		seat.CanCollide = false
		seat.Massless = true
		seat.CFrame = (root.CFrame - root.CFrame.Position) + Vector3.new(bpos.X, top, bpos.Z)
		local w = Instance.new("Weld")
		w.Part0 = body :: BasePart
		w.Part1 = seat
		w.C0 = (body :: BasePart).CFrame:ToObjectSpace(seat.CFrame)
		w.Parent = seat
		seat.Parent = model
		saddle = seat
	end
	if def.Passenger and not model:FindFirstChild("PassengerSeat") then
		local s = saddle :: Seat
		local weld = s:FindFirstChildOfClass("Weld")
		local p = s:Clone()
		p.Name = "PassengerSeat"
		for _, c in p:GetChildren() do
			c:Destroy()
		end
		p.CFrame = s.CFrame * CFrame.new(0, 0, s.Size.Z * 1.1)
		if weld and weld.Part0 then
			local w = Instance.new("Weld")
			w.Part0 = weld.Part0
			w.Part1 = p
			w.C0 = weld.Part0.CFrame:ToObjectSpace(p.CFrame)
			w.Parent = p
		end
		p.Parent = model
	end
end

--- Construit la créature `id` au pivot `cframe` (au sol) et la parente à Workspace par défaut.
--- opts.scale (défaut : def.Scale), opts.mutation (ex. "Gold"), voir Kit.BuildOptions.
function CreatureForge.spawn(id: string, cframe: CFrame?, opts: Kit.BuildOptions?): Model
	local def = CreatureForge.get(id)
	local o: Kit.BuildOptions = if opts then table.clone(opts) else {}
	o.cframe = cframe or o.cframe
	o.scale = o.scale or def.Scale
	local parent = if o.parent == nil then workspace else o.parent
	o.parent = nil
	local model = def.build(o)
	local muts = o.mutations or (if o.mutation then { o.mutation } else nil)
	if muts and #muts > 0 then
		Mutations.apply(model, muts)
	end
	ensureSeats(model, def)
	model:SetAttribute("Income", CreatureForge.income(id, muts))
	model:SetAttribute("SpeedBonus", def.SpeedBonus)
	model:SetAttribute("Passenger", def.Passenger)
	model.Parent = parent
	return model
end

--- Créatures d'une rareté (voir Rarity.Order).
function CreatureForge.ofRarity(rarity: string): { Types.CreatureDef }
	local out = {}
	for _, def in CreatureForge.list() do
		if def.Rarity == rarity then
			table.insert(out, def)
		end
	end
	return out
end

--- Revenu par seconde d'une créature : base × (somme des multiplicateurs de mutation).
function CreatureForge.income(id: string, mutations: { string }?): number
	return CreatureForge.get(id).Income * Mutations.multiplier(mutations)
end

--- Tirage d'une apparition dans le canyon à la distance `distance` (0 = en haut de la pente,
--- 1 = tout au bout ; voir Map.distanceOf).
--- Renvoie la créature et ses mutations. `luck` = 2 pendant le boost « Chance x2 ».
function CreatureForge.rollSpawn(distance: number, rng: Random?, luck: number?): (Types.CreatureDef?, { string })
	local r = rng or Random.new()
	local rarity = Spawning.rollRarity(distance, r, luck)
	local pool = {}
	for _, def in CreatureForge.ofRarity(rarity) do
		if (def.Source or "Tapis") ~= "Roue" then
			table.insert(pool, def)
		end
	end
	if #pool == 0 then
		return nil, {}
	end
	return pool[r:NextInteger(1, #pool)], Mutations.roll(r)
end

--- Tirage d'un personnage dans la machine à ADN : la rareté de l'ADN posé fixe les chances
--- (voir DnaMachine.odds) ; plus il y a d'ADN (meilleure seringue), plus on peut monter de rareté.
function CreatureForge.hatch(dnaRarity: string, amount: number?, rng: Random?): (Types.CreatureDef?, { string })
	local r = rng or Random.new()
	local rarity = DnaMachine.rollRarity(dnaRarity, amount, r)
	local pool = {}
	for _, def in CreatureForge.ofRarity(rarity) do
		if (def.Source or "Tapis") ~= "Roue" then
			table.insert(pool, def)
		end
	end
	if #pool == 0 then
		return nil, {}
	end
	return pool[r:NextInteger(1, #pool)], Mutations.roll(r)
end

--- Construit la carte d'icône UI de la créature `id`.
function CreatureForge.buildIcon(id: string, parent: Instance?, opts: Icon.IconOptions?): Frame
	return Icon.build(CreatureForge.get(id), parent, opts)
end

--- Change l'état d'animation lu par CreatureAnimator (client).
function CreatureForge.setAnimState(model: Model, state: AnimState)
	model:SetAttribute("AnimState", state)
end

--- Déclenche la capacité spéciale de la créature (serveur ou client) : les clients jouent
--- les effets (Vfx.playAbility) et la pose, puis la créature revient à son état précédent.
--- Renvoie la durée de la capacité (0 si la créature n'en a pas).
function CreatureForge.playAbility(model: Model): number
	local id = model:GetAttribute("CreatureId")
	local def = if typeof(id) == "string" and registry[id] then registry[id] else nil
	if not def or not def.Ability then
		return 0
	end
	local duration = def.Ability.duration or 1.6
	local previous = model:GetAttribute("AnimState")
	model:SetAttribute("AbilitySeq", ((model:GetAttribute("AbilitySeq") :: number?) or 0) + 1)
	model:SetAttribute("AnimState", "Ability")
	task.delay(duration, function()
		if model.Parent and model:GetAttribute("AnimState") == "Ability" then
			model:SetAttribute("AnimState", if previous == "Move" then "Move" else "Idle")
		end
	end)
	return duration
end

return CreatureForge
