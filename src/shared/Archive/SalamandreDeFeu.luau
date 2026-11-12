--!strict
--[[
	LA SALAMANDRE DE FEU — Rare · La Pente Brumeuse
	===============================================
	Amphibien de lave orange fluo aux plaques dorsales qui brûlent et à la queue enflammée.

	• Peau orange fluo en fines écailles (jaune → rouge), taches sombres, ventre jaune.
	• Rangée de plaques dorsales de basalte coiffées de flammes Neon.
	• Queue qui s'embrase sur son dernier tiers, grande flamme au bout.
	• Tête large et plate, branchies-flammes (3 de chaque côté), yeux Neon jaunes.
	• 4 boules de feu en orbite ; effets : feu, braises, chaleur lumineuse.
	Os : Root > Body > Chest > Head ; Body > Tail1..5 ; pattes   (démarche "Sprawler")
]]

local Kit = require(script.Parent.Parent.Kit)
local A = require(script.Parent.Parent.Anatomy)
local Fx = require(script.Parent.Parent.Fx)
local Vfx = require(script.Parent.Parent.Vfx)
local Types = require(script.Parent.Parent.Types)

local S = Kit.style
local M = Enum.Material
local rgb = Color3.fromRGB
local rad = math.rad
local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles

local ID = "SalamandreDeFeu"

local P = {
	core = S(rgb(230, 80, 16)),
	skin = { S(rgb(255, 196, 50)), S(rgb(255, 150, 30)), S(rgb(250, 108, 24)), S(rgb(214, 70, 20)) },
	belly = { S(rgb(255, 236, 120)), S(rgb(255, 210, 80)) },
	spot = S(rgb(60, 14, 10)),
	basalt = S(rgb(56, 40, 40), M.Slate),
	flameOut = S(rgb(255, 80, 20), M.Neon),
	flameMid = S(rgb(255, 170, 40), M.Neon),
	flameCore = S(rgb(255, 245, 170), M.Neon),
	eye = S(rgb(255, 236, 60), M.Neon),
	socket = S(rgb(50, 10, 6)),
	mouth = S(rgb(130, 20, 20)),
	claw = S(rgb(60, 20, 16)),
}

local SPINE = Kit.spine({
	{ pos = v3(0, 0.6, -1.4), rx = 0.3, ry = 0.2 },
	{ pos = v3(0, 0.6, -1.0), rx = 0.42, ry = 0.26 },
	{ pos = v3(0, 0.58, -0.45), rx = 0.52, ry = 0.3 },
	{ pos = v3(0, 0.56, 0.15), rx = 0.56, ry = 0.31 },
	{ pos = v3(0, 0.54, 0.75), rx = 0.46, ry = 0.28 },
	{ pos = v3(0, 0.48, 1.3), rx = 0.32, ry = 0.22 },
	{ pos = v3(0.1, 0.4, 1.95), rx = 0.24, ry = 0.17 },
	{ pos = v3(0.32, 0.32, 2.6), rx = 0.16, ry = 0.12 },
	{ pos = v3(0.4, 0.28, 3.2), rx = 0.09, ry = 0.08 },
	{ pos = v3(0.25, 0.27, 3.65), rx = 0.03, ry = 0.03 },
})
local TAIL_START = 6

local HEAD = Kit.spine({
	{ pos = v3(0, 0.55, -2.25), rx = 0.16, ry = 0.07 },
	{ pos = v3(0, 0.58, -2.05), rx = 0.36, ry = 0.13 },
	{ pos = v3(0, 0.62, -1.75), rx = 0.42, ry = 0.18 },
	{ pos = v3(0, 0.62, -1.42), rx = 0.32, ry = 0.2 },
})

local function boneAt(u: number): string
	if u < 2.8 then
		return "Chest"
	elseif u < TAIL_START then
		return "Body"
	end
	return "Tail" .. math.clamp(math.floor(u - TAIL_START) + 1, 1, 4)
end

-- Capacité spéciale (CreatureForge.playAbility)
local ABILITY: Types.Ability = {
	name = "Souffle de lave",
	kind = "Breath",
	colors = { rgb(255, 150, 40), rgb(255, 60, 20), rgb(255, 250, 180) },
	texture = "fire",
	origin = v3(0, 0.6, -2.3),
	direction = v3(0, 0.05, -1),
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 0.56, 0.3))
	rig:bone("Chest", "Body", cf(0, 0.58, -0.4))
	rig:bone("Head", "Chest", cf(0, 0.62, -1.42))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Chest", cf(side * 0.38, 0.55, -0.75))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.36, 0.55, 0.7))
	end)
	local tj = {}
	for i = TAIL_START, #SPINE.sections do
		table.insert(tj, SPINE:pos(i))
	end
	rig:boneChain("Tail", "Body", tj)

	rig:tube(SPINE, {
		name = "Body",
		bone = boneAt,
		core = P.core,
		coreStep = 0.28,
		cover = {
			A.scales(P.skin, v3(0.2, 0.06, 0.2), 0.16, { arc = 120, tilt = 12, refRadius = 0.4, jitter = 0.4, seed = 1 }),
			A.scales(P.belly, v3(0.24, 0.05, 0.2), 0.18, { arc = 55, center = 180, to = 8, tilt = 6, refRadius = 0.4, jitter = 0.1, seed = 2 }),
		},
	})
	-- Taches sombres
	local rng = Random.new(5)
	for _ = 1, 26 do
		local u = rng:NextNumber(1.3, 8.5)
		local deg = rng:NextNumber(-100, 100)
		local _, ry = SPINE:radii(u)
		local d = math.clamp(ry / 0.3, 0.4, 1) * rng:NextNumber(0.12, 0.2)
		rig:prism(boneAt(u), "Spot", SPINE:surface(u, deg, 0.06) * ang(-math.pi / 2, 0, 0), v3(d, d, 0.03), d * 0.3, P.spot)
	end

	-- Plaques dorsales en feu
	do
		local s, sEnd, i = SPINE:lengthAt(1.4), SPINE:lengthAt(7.5), 0
		while s < sEnd do
			local u = SPINE:uAt(s)
			local _, ry = SPINE:radii(u)
			local k = math.clamp(ry / 0.3, 0.4, 1.1)
			local base = SPINE:surface(u, 0, 0.02 * k) * ang(rad(20), 0, 0)
			rig:wedge(boneAt(u), "DorsalPlate", base * cf(0, 0.08 * k, 0), v3(0.32, 0.18, 0.3) * k, P.basalt)
			A.flame(rig, boneAt(u), base * cf(0, 0.14 * k, 0.04), (if i % 2 == 0 then 0.42 else 0.3) * k, 0.18 * k, P.flameOut, P.flameMid, P.flameCore)
			s += 0.3 * k
			i += 1
		end
	end
	-- Queue enflammée
	for u = 7.6, 9.6, 0.4 do
		local _, ry = SPINE:radii(u)
		A.flame(rig, boneAt(u), SPINE:surface(u, 0, 0), 0.45 * math.max(ry / 0.12, 0.5), 0.2, P.flameOut, P.flameMid, P.flameCore)
	end
	A.flame(rig, "Tail4", A.alongUp(SPINE:pos(10), SPINE:pos(10) - SPINE:pos(9) + v3(0, 0.4, 0)), 0.8, 0.32, P.flameOut, P.flameMid, P.flameCore)

	-- Tête plate, branchies-flammes
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.18,
		cover = { A.scales(P.skin, v3(0.16, 0.05, 0.16), 0.12, { arc = 110, from = 1.5, refRadius = 0.3, jitter = 0.2, seed = 3 }) },
	})
	rig:prismBetween("Head", "Mouth", v3(0, 0.53, -1.5), v3(0, 0.53, -2.2), 0.6, 0.03, 0.01, P.mouth)
	rig:mirrored(function(side)
		A.eye(rig, "Head", A.mx(v3(0.3, 0.76, -1.85), side), v3(side, 0.6, -0.4), 0.13, "Glow", P.socket, P.eye)
		for k = 0, 2 do
			local base = cf(A.mx(v3(0.34, 0.66 + k * 0.05, -1.5 + k * 0.08), side)) * ang(rad(20 + k * 10), 0, -side * rad(70 - k * 20))
			A.flame(rig, "Head", base, 0.42 - k * 0.06, 0.16, P.flameOut, P.flameMid, P.flameCore)
		end
	end)

	-- Pattes
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, L in { F = { v3(0.38, 0.55, -0.75), v3(0.8, 0.48, -0.9), v3(0.88, 0.12, -1.0), 0.14 }, B = { v3(0.36, 0.55, 0.7), v3(0.82, 0.5, 0.6), v3(0.92, 0.12, 0.76), 0.18 } } do
			local bone = "Leg_" .. key .. s
			A.limb(rig, bone, side, { { L[1], L[4], L[4] }, { L[2], 0.11, 0.1 }, { L[3], 0.08, 0.08 } }, P.core, A.scales(P.skin, v3(0.14, 0.05, 0.13), 0.12, { arc = 180, refRadius = 0.13, seed = 10 + side }))
			A.paw(rig, bone, A.mx((L[3] :: Vector3) - v3(0, 0.12, 0.04), side), v3(side * 0.4, 0, -1), 0.26, 4, P.skin[3], P.skin[1], P.claw)
		end
	end)

	A.orbit(rig, "Aura1", v3(0, 1.0, 0.4), 2.3, 4, 0.3, function(bone, c)
		A.flame(rig, bone, c, 0.4, 0.2, P.flameOut, P.flameMid, P.flameCore)
		rig:ball(bone, "FireballCore", (c * cf(0, 0.08, 0)).Position, 0.16, P.flameCore)
	end)

	rig:hitbox(cf(0, 0.6, 0.4), v3(2.2, 1.4, 6))

	if rig.effects then
		local sc = rig.scale
		local tail = rig:anchor("Tail4", "FX_TailFire", cf(SPINE:pos(9.5)), v3(0.4, 0.3, 0.6))
		Fx.particles(tail, Fx.fire("TailFire", { rgb(255, 240, 140), rgb(255, 120, 30), rgb(120, 20, 10) }, 22, 0.6), sc)
		local back = rig:anchor("Body", "FX_Back", cf(0, 0.95, -0.3), v3(0.5, 0.3, 2.6))
		Fx.particles(back, Fx.embers("Embers", { rgb(255, 230, 120), rgb(255, 90, 20) }, 10, 0.16), sc)
		Fx.light(back, { color = rgb(255, 130, 40), range = 10, brightness = 1.5 }, sc)
	end


	-- Effets avancés : signature, origine de la capacité, aura de rareté
	if rig.effects then
		local tip = SPINE:pos(10)
		Vfx.trail(rig, "Tail4", tip + v3(0, 0.1, 0), tip - v3(0, 0.1, 0), { colors = { rgb(255, 220, 100), rgb(255, 80, 20) }, lifetime = 0.5 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Rare")
	end

	return rig:finish({ Rarity = "Rare" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Salamandre de Feu",
	Rarity = "Rare",
	Zone = "PenteBrumeuse",
	Scale = 2.0,
	Category = "Créature Rare",
	Description = "Amphibien de lave orange fluo. Ses plaques dorsales brûlent et sa queue s'embrase.",
	Icon = { top = rgb(170, 40, 20), bottom = rgb(40, 8, 6), glow = rgb(255, 190, 80), motif = rgb(255, 120, 30), yaw = 36, pitch = 24, zoom = 1.15 },
	Animation = { flicker = 0.35, gait = "Sprawler", breathe = 0.02, sway = 12, stride = 30, strideRate = 9, tailSway = 14, tailRate = 1.8, headLook = 18, auraSpeed = 1 },
	Ability = ABILITY,
	build = build,
}

return Def
