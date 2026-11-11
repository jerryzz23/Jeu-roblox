--!strict
--[[
	CreatureForge (ReplicatedStorage.CreatureForge)
	===============================================
	Point d'entrée : registre des créatures + fabrique de modèles et d'icônes.

	    local CreatureForge = require(ReplicatedStorage.CreatureForge)
	    local rat = CreatureForge.spawn("RatDesCavernes", CFrame.new(0, 0, -10))
	    CreatureForge.setAnimState(rat, "Move")            -- "Idle" | "Move" | "Still"
	    CreatureForge.buildIcon("RatDesCavernes", someFrame) -- carte d'inventaire

	Ajouter une créature = déposer un ModuleScript dans CreatureForge/Creatures
	(voir Types.CreatureDef). Elle est enregistrée automatiquement.
]]

local Kit = require(script.Kit)
local Fx = require(script.Fx)
local Rarity = require(script.Rarity)
local Icon = require(script.Icon)
local Anatomy = require(script.Anatomy)
local Mutations = require(script.Mutations)
local Types = require(script.Types)

export type CreatureDef = Types.CreatureDef
export type AnimState = "Idle" | "Move" | "Still"

local CreatureForge = {
	Kit = Kit,
	Fx = Fx,
	Rarity = Rarity,
	Icon = Icon,
	Anatomy = Anatomy,
	Mutations = Mutations,
	TAG = Kit.TAG,
}

local registry: { [string]: Types.CreatureDef } = {}

for _, m in script.Creatures:GetChildren() do
	if m:IsA("ModuleScript") then
		local def: Types.CreatureDef = require(m) :: any
		assert(registry[def.Id] == nil, `CreatureForge: identifiant en double "{def.Id}"`)
		registry[def.Id] = def
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
		return a.DisplayName < b.DisplayName
	end)
	return out
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
	if o.mutation then
		Mutations.apply(model, o.mutation)
	end
	model.Parent = parent
	return model
end

--- Créatures d'une zone de la carte (voir Rarity.Zones).
function CreatureForge.inZone(zone: string): { Types.CreatureDef }
	local out = {}
	for _, def in CreatureForge.list() do
		if def.Zone == zone then
			table.insert(out, def)
		end
	end
	return out
end

--- Construit la carte d'icône UI de la créature `id`.
function CreatureForge.buildIcon(id: string, parent: Instance?, opts: Icon.IconOptions?): Frame
	return Icon.build(CreatureForge.get(id), parent, opts)
end

--- Change l'état d'animation lu par CreatureAnimator (client).
function CreatureForge.setAnimState(model: Model, state: AnimState)
	model:SetAttribute("AnimState", state)
end

return CreatureForge
