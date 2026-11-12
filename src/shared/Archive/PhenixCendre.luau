--!strict
--[[
	LE PHÉNIX CENDRÉ — Légendaire · Les Grottes de Cristal
	======================================================
	Grand oiseau légendaire mêlant plumes d'or, flammes intenses et traînée de particules.

	• Corps aux plumes or → orange → rouge, collerette dorée, petites couvertures cendrées.
	• Immenses ailes à 3 rangées (rémiges rouge feu, couvertures or, cendre) aux pointes Neon,
	  flammes le long du bord de fuite.
	• Longue traîne de plumes enflammées + deux rubans de feu.
	• Huppe de flammes, bec et serres dorés, yeux Neon blanc incandescent.
	• 6 plumes d'or et 4 boules de feu en orbite ; effets : traînée de feu, braises, forte lueur.
	Os : Root > Body > Head / Wing_R / Wing_L / Tail1 / Leg_R / Leg_L   (démarche "Flyer")
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

local ID = "PhenixCendre"

local P = {
	core = S(rgb(150, 40, 16)),
	plume = { S(rgb(255, 226, 96)), S(rgb(255, 176, 50)), S(rgb(244, 116, 30)), S(rgb(200, 60, 20)) },
	primary = { S(rgb(255, 90, 30)), S(rgb(230, 56, 22)) },
	covert = { S(rgb(255, 204, 64)), S(rgb(255, 170, 40)) },
	ash = { S(rgb(126, 116, 116)), S(rgb(96, 88, 90)) },
	tip = S(rgb(255, 236, 130), M.Neon),
	flameOut = S(rgb(255, 80, 20), M.Neon),
	flameMid = S(rgb(255, 170, 40), M.Neon),
	flameCore = S(rgb(255, 250, 190), M.Neon),
	gold = S(rgb(255, 204, 60)),
	goldDark = S(rgb(214, 136, 24)),
	eye = S(rgb(255, 250, 210), M.Neon),
	socket = S(rgb(120, 20, 8)),
}

local BODY = Kit.spine({
	{ pos = v3(0, 2.25, -1.1), rx = 0.3, ry = 0.3 },
	{ pos = v3(0, 2.15, -0.6), rx = 0.56, ry = 0.54 },
	{ pos = v3(0, 2.05, 0.05), rx = 0.6, ry = 0.56 },
	{ pos = v3(0, 1.95, 0.7), rx = 0.4, ry = 0.36 },
	{ pos = v3(0, 1.9, 1.1), rx = 0.18, ry = 0.16 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 2.62, -1.62), rx = 0.2, ry = 0.2 },
	{ pos = v3(0, 2.65, -1.4), rx = 0.32, ry = 0.31 },
	{ pos = v3(0, 2.58, -1.15), rx = 0.3, ry = 0.3 },
	{ pos = v3(0, 2.4, -0.95), rx = 0.27, ry = 0.27 },
})

-- Capacité spéciale (CreatureForge.playAbility)
local ABILITY: Types.Ability = {
	name = "Renaissance",
	kind = "Nova",
	colors = { rgb(255, 170, 40), rgb(255, 70, 20), rgb(255, 250, 190) },
	texture = "fire",
	radius = 8,
	duration = 2,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 2.05, 0))
	rig:bone("Head", "Body", cf(0, 2.35, -1.0))
	rig:bone("Tail1", "Body", cf(0, 1.92, 1.0))
	rig:mirrored(function(side, sfx)
		rig:bone("Wing" .. sfx, "Body", cf(side * 0.42, 2.25, -0.45))
		rig:bone("Leg" .. sfx, "Body", cf(side * 0.2, 1.65, 0.05))
	end)

	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.28,
		cover = { A.scales(P.plume, v3(0.3, 0.08, 0.42), 0.22, { arc = 180, tilt = 30, refRadius = 0.55, seed = 1 }) },
	})
	A.tuftBurst(rig, "Body", cf(0, 2.25, -1.0) * ang(rad(-35), 0, 0), 14, 0.55, 0.18, P.covert, P.tip, 70, 2)

	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.16,
		cover = { A.scales(P.plume, v3(0.18, 0.06, 0.22), 0.13, { arc = 180, from = 1.5, tilt = 24, refRadius = 0.3, seed = 2 }) },
	})
	A.horn(rig, "Head", { v3(0, 2.66, -1.6), v3(0, 2.6, -1.85), v3(0, 2.48, -1.98), v3(0, 2.34, -1.95) }, 0.13, 0.025, P.gold)
	-- Huppe de flammes
	for k = 0, 4 do
		local base = cf(0, 2.85 - k * 0.04, -1.32 + k * 0.12) * ang(rad(40 + k * 10), 0, 0)
		A.flame(rig, "Head", base, 0.7 - k * 0.06, 0.2, P.flameOut, P.flameMid, P.flameCore)
	end
	rig:mirrored(function(side, sfx)
		A.eye(rig, "Head", A.mx(v3(0.24, 2.74, -1.45), side), v3(side, 0.2, -0.5), 0.14, "Glow", P.socket, P.eye)
		A.brow(rig, "Head", side, v3(0.2, 2.86, -1.46), 0.26, 24, P.plume[4])
		for k = 0, 1 do
			A.flame(rig, "Head", cf(A.mx(v3(0.28, 2.62, -1.2 + k * 0.15), side)) * ang(rad(60), 0, -side * rad(70)), 0.42 - k * 0.08, 0.16, P.flameOut, P.flameMid, P.flameCore)
		end

		-- Ailes immenses
		local wing = "Wing" .. sfx
		local arm = { v3(0.42, 2.25, -0.48), v3(1.25, 2.55, -0.44), v3(2.15, 2.78, -0.3), v3(3.05, 2.9, -0.05) }
		A.wing(rig, wing, side, {
			arm = arm,
			armRadius = 0.18,
			feathers = 15,
			length = { 1.4, 2.1 },
			width = 0.46,
			sweep = 42,
			rows = { P.primary, P.covert, P.ash },
			tip = P.tip,
			armStyle = P.plume[2],
		})
		for k = 1, 5 do
			local t = k / 6
			local p = A.mx(arm[1]:Lerp(arm[4], t), side) + v3(0, -0.02, 1.4 + t * 0.4)
			local dir = v3(side * math.sin(rad(42) * t), 0.25, math.cos(rad(42) * t)).Unit
			A.flame(rig, wing, A.alongUp(p, dir), 0.6, 0.2, P.flameOut, P.flameMid, P.flameCore)
		end

		local leg = "Leg" .. sfx
		A.limb(rig, leg, side, { { v3(0.2, 1.65, 0.05), 0.12, 0.12 }, { v3(0.22, 1.32, 0.14), 0.08, 0.08 }, { v3(0.23, 1.08, 0.02), 0.065, 0.065 } }, P.gold)
		local foot = A.mx(v3(0.23, 1.05, 0.0), side)
		for k = -1, 1 do
			local dir = v3(side * k * 0.4, -0.3, -1).Unit
			local tipP = foot + dir * 0.26
			rig:strut(leg, "Toe", foot, tipP, 0.06, 0.06, P.gold)
			rig:wedge(leg, "Talon", Kit.lookAlong(tipP + dir * 0.06, dir), v3(0.05, 0.07, 0.13), P.goldDark)
		end
	end)

	-- Traîne de plumes enflammées + rubans de feu
	A.featherFan(rig, "Tail1", cf(0, 1.94, 1.0) * ang(rad(-12), 0, 0), 9, 2.6, 0.4, 48, { P.primary[1], P.covert[1], P.primary[2] }, P.tip)
	for k = -1, 1, 2 do
		local pts = { v3(k * 0.1, 1.95, 1.05), v3(k * 0.35, 1.6, 2.2), v3(k * 0.7, 1.35, 3.3), v3(k * 0.9, 1.5, 4.2) }
		A.horn(rig, "Tail1", pts, 0.09, 0.02, P.covert[1])
		A.flame(rig, "Tail1", A.alongUp(pts[4], pts[4] - pts[3]), 0.7, 0.26, P.flameOut, P.flameMid, P.flameCore)
	end
	for k = 0, 4 do
		local a = rad((k - 2) * 12)
		local p = v3(math.sin(a) * 2.4, 1.6, 1.0 + math.cos(a) * 2.4)
		A.flame(rig, "Tail1", A.alongUp(p, v3(math.sin(a), 0.3, math.cos(a))), 0.55, 0.2, P.flameOut, P.flameMid, P.flameCore)
	end

	-- Plumes d'or et boules de feu en orbite
	A.orbit(rig, "Aura1", v3(0, 2.3, 0), 3.0, 6, 0.5, function(bone, c)
		A.feather(rig, bone, c * ang(0, 0, rad(25)) * ang(0, math.pi / 2, 0), 0.7, 0.24, P.gold, P.tip)
	end)
	A.orbit(rig, "Aura2", v3(0, 2.6, 0), 2.0, 4, 0.3, function(bone, c)
		A.flame(rig, bone, c, 0.45, 0.22, P.flameOut, P.flameMid, P.flameCore)
		rig:ball(bone, "FireCore", (c * cf(0, 0.1, 0)).Position, 0.18, P.flameCore)
	end)

	rig:hitbox(cf(0, 2.2, 0.2), v3(6.4, 2.4, 5))

	if rig.effects then
		local sc = rig.scale
		local trail = rig:anchor("Tail1", "FX_Trail", cf(0, 1.7, 2.6), v3(1.6, 0.4, 2.4))
		Fx.particles(trail, Fx.fire("FireTrail", { rgb(255, 240, 150), rgb(255, 120, 30), rgb(120, 20, 10) }, 30, 0.7), sc)
		local wings = rig:anchor("Body", "FX_Wings", cf(0, 2.6, 0.6), v3(5.6, 0.4, 1.6))
		Fx.particles(wings, Fx.embers("Embers", { rgb(255, 230, 120), rgb(255, 100, 30) }, 20, 0.2), sc)
		Fx.particles(wings, Fx.sparkles("GoldDust", { rgb(255, 230, 140) }, 8, 0.24, 0.1), sc)
		Fx.light(rig.bones.Body, { color = rgb(255, 150, 50), range = 14, brightness = 2 }, sc)
	end


	-- Effets avancés : signature, origine de la capacité, aura de rareté
	if rig.effects then
		Vfx.wingTrails(rig, v3(3.05, 2.9, -0.05), v3(0.12, 0, 0.4), { colors = { rgb(255, 230, 120), rgb(255, 90, 20) }, transparency = { 0.15, 1 }, lifetime = 0.6 })
		for _, k in { -1, 1 } do
			local p = v3(k * 0.9, 1.5, 4.2)
			Vfx.trail(rig, "Tail1", p + v3(0, 0.07, 0), p - v3(0, 0.07, 0), { colors = { rgb(255, 220, 110), rgb(255, 80, 20) }, lifetime = 0.6 })
		end
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Legendary")
	end

	return rig:finish({ Rarity = "Legendary" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Phénix Cendré",
	Rarity = "Legendary",
	Zone = "GrottesCristal",
	Scale = 2.6,
	Category = "Créature Légendaire",
	Description = "Oiseau légendaire aux plumes d'or. Il renaît de ses cendres dans une traînée de flammes.",
	Icon = { top = rgb(180, 60, 20), bottom = rgb(40, 8, 4), glow = rgb(255, 210, 100), motif = rgb(255, 200, 60), yaw = 26, pitch = 14, zoom = 1.12 },
	Animation = { flicker = 0.35, gait = "Flyer", flap = 26, flapRate = 3.8, hover = 0.2, headLook = 20, tailSway = 6, tailRate = 1.2, auraSpeed = 0.5 },
	Ability = ABILITY,
	build = build,
}

return Def
