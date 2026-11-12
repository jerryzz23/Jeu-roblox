--!strict
--[[
	CreatureForge.Treadmills — tapis de course de la base
	====================================================
	Le joueur gagne de la vitesse en courant sur le mini tapis de sa base ; un meilleur tapis
	fait gagner plus vite. 10 niveaux, du Tapis d'entraînement au Tapis du Néant Couronné.

	    local Treadmills = CreatureForge.Treadmills
	    local tapis = Treadmills.spawn("TapisForge", baseCFrame)      -- modèle animé
	    Treadmills.setRunning(tapis, true)                             -- la bande repousse le joueur
	    Treadmills.get("TapisForge").Gain                              -- vitesse gagnée par seconde
	    Treadmills.nextOf("TapisForge")                                -- niveau suivant (prix, gain)

	Chaque modèle contient une pièce "RunSurface" (collidable, ancrée) : le serveur vérifie que
	le joueur est dessus et bouge avant d'accorder le gain (anti-triche), et sa vitesse de convoyeur
	fait courir le joueur sur place. Les décors (bande qui défile, engrenages, objets en orbite,
	couronnes flottantes) sont animés par CreatureAnimator côté client.
]]

local Kit = require(script.Parent.Kit)

export type TreadmillDef = {
	Id: string,
	DisplayName: string,
	Tier: number, -- 1 (départ) -> 10
	Price: number, -- prix en argent du jeu (0 = offert)
	Gain: number, -- vitesse gagnée par seconde de course
	Theme: string, -- thème affiché
	Description: string,
	Color: Color3, -- couleur d'interface
	build: (opts: Kit.BuildOptions?) -> Model,
}

local Treadmills = {}

local registry: { [string]: TreadmillDef } = {}
local ordered: { TreadmillDef } = {}

for _, m in script.Models:GetChildren() do
	if m:IsA("ModuleScript") then
		local def: TreadmillDef = require(m) :: any
		assert(registry[def.Id] == nil, `Treadmills: identifiant en double "{def.Id}"`)
		registry[def.Id] = def
		table.insert(ordered, def)
	end
end
table.sort(ordered, function(a, b)
	return a.Tier < b.Tier
end)

--- Vitesse du convoyeur (studs/s) : la bande ramène le joueur vers l'arrière.
Treadmills.CONVEYOR_SPEED = 10

function Treadmills.list(): { TreadmillDef }
	return ordered
end

function Treadmills.get(id: string): TreadmillDef
	local def = registry[id]
	assert(def, `Treadmills: tapis inconnu "{id}"`)
	return def
end

function Treadmills.has(id: string): boolean
	return registry[id] ~= nil
end

--- Niveau suivant (nil si c'est déjà le meilleur tapis).
function Treadmills.nextOf(id: string): TreadmillDef?
	return ordered[Treadmills.get(id).Tier + 1]
end

--- Active / coupe le convoyeur de la surface de course.
function Treadmills.setRunning(model: Model, on: boolean)
	local run = model:FindFirstChild("RunSurface", true)
	if run and run:IsA("BasePart") then
		local back = run.CFrame.LookVector * -1
		run.AssemblyLinearVelocity = if on then back * Treadmills.CONVEYOR_SPEED else Vector3.zero
		model:SetAttribute("Running", on)
	end
end

--- Construit le tapis `id` au pivot `cframe` (posé au sol, le coureur regarde vers -Z).
function Treadmills.spawn(id: string, cframe: CFrame?, opts: Kit.BuildOptions?): Model
	local def = Treadmills.get(id)
	local o: Kit.BuildOptions = if opts then table.clone(opts) else {}
	o.cframe = cframe or o.cframe
	local parent = if o.parent == nil then workspace else o.parent
	o.parent = nil
	local model = def.build(o)
	model:SetAttribute("TreadmillId", def.Id)
	model:SetAttribute("Tier", def.Tier)
	model:SetAttribute("Gain", def.Gain)
	model.Parent = parent
	Treadmills.setRunning(model, true)
	return model
end

return Treadmills
