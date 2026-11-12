--!strict
--[[
	LE CORBEAU DES BRUMES — Commun · La Surface
	===========================================
	Oiseau aux plumes sombres, yeux violets brumeux et grande envergure (vol stationnaire).

	• Corps et tête couverts de plumes imbriquées noir-violet irisé.
	• Ailes déployées à 3 rangées de plumes (rémiges à pointe violette), queue en éventail.
	• Bec crochu anthracite, yeux Neon violets, huppe de plumes, bague dorée à la patte.
	• Effets : brume violette qui s'échappe des ailes, plumes scintillantes.
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

local ID = "CorbeauDesBrumes"

local P = {
	core = S(rgb(26, 24, 44)),
	plume = { S(rgb(96, 88, 150)), S(rgb(68, 62, 112)), S(rgb(46, 42, 80)), S(rgb(30, 28, 56)) },
	wingA = { S(rgb(40, 36, 70)), S(rgb(30, 28, 56)) },
	wingB = { S(rgb(70, 62, 116)), S(rgb(54, 48, 92)) },
	wingC = { S(rgb(110, 90, 170)), S(rgb(88, 72, 140)) },
	tip = S(rgb(186, 130, 255)),
	beak = S(rgb(52, 50, 62)),
	beakDark = S(rgb(30, 28, 36)),
	eye = S(rgb(206, 140, 255), M.Neon),
	socket = S(rgb(14, 10, 24)),
	leg = S(rgb(58, 56, 70)),
	claw = S(rgb(236, 230, 214)),
	gold = S(rgb(255, 198, 54)),
}

local BODY = Kit.spine({
	{ pos = v3(0, 1.45, -0.75), rx = 0.22, ry = 0.22 },
	{ pos = v3(0, 1.42, -0.4), rx = 0.4, ry = 0.38 },
	{ pos = v3(0, 1.36, 0.05), rx = 0.44, ry = 0.42 },
	{ pos = v3(0, 1.3, 0.5), rx = 0.32, ry = 0.3 },
	{ pos = v3(0, 1.24, 0.8), rx = 0.16, ry = 0.14 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 1.62, -1.08), rx = 0.17, ry = 0.17 },
	{ pos = v3(0, 1.64, -0.92), rx = 0.25, ry = 0.24 },
	{ pos = v3(0, 1.6, -0.72), rx = 0.24, ry = 0.23 },
	{ pos = v3(0, 1.5, -0.55), rx = 0.21, ry = 0.21 },
})

-- Capacité spéciale (CreatureForge.playAbility)
local ABILITY: Types.Ability = {
	name = "Bourrasque des brumes",
	kind = "Nova",
	colors = { rgb(190, 130, 255), rgb(90, 60, 150), rgb(255, 255, 255) },
	texture = "smoke",
	radius = 4,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 1.36, 0))
	rig:bone("Head", "Body", cf(0, 1.5, -0.62))
	rig:bone("Tail1", "Body", cf(0, 1.26, 0.72))
	rig:mirrored(function(side, sfx)
		rig:bone("Wing" .. sfx, "Body", cf(side * 0.3, 1.5, -0.32))
		rig:bone("Leg" .. sfx, "Body", cf(side * 0.14, 1.12, 0.05))
	end)

	-- Corps et tête emplumés
	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.25,
		cover = { A.scales(P.plume, v3(0.24, 0.07, 0.34), 0.19, { arc = 180, tilt = 26, refRadius = 0.4, seed = 1 }) },
	})
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.16,
		cover = { A.scales(P.plume, v3(0.15, 0.05, 0.18), 0.12, { arc = 180, from = 1.5, tilt = 22, refRadius = 0.24, seed = 2 }) },
	})
	A.tuftBurst(rig, "Head", cf(0, 1.8, -0.72) * ang(rad(55), 0, 0), 6, 0.42, 0.13, P.wingA, P.tip, 28, 3)

	-- Bec crochu
	A.horn(rig, "Head", { v3(0, 1.64, -1.06), v3(0, 1.62, -1.3), v3(0, 1.55, -1.47), v3(0, 1.46, -1.55) }, 0.11, 0.02, P.beak)
	A.horn(rig, "Head", { v3(0, 1.55, -1.06), v3(0, 1.53, -1.28), v3(0, 1.52, -1.38) }, 0.075, 0.02, P.beakDark)

	rig:mirrored(function(side, sfx)
		A.eye(rig, "Head", A.mx(v3(0.19, 1.7, -0.97), side), v3(side, 0.2, -0.5), 0.13, "Glow", P.socket, P.eye)
		A.brow(rig, "Head", side, v3(0.16, 1.8, -0.98), 0.22, 18, P.plume[4])

		-- Aile
		A.wing(rig, "Wing" .. sfx, side, {
			arm = { v3(0.3, 1.5, -0.36), v3(0.85, 1.64, -0.34), v3(1.4, 1.72, -0.24), v3(1.95, 1.76, -0.08) },
			armRadius = 0.13,
			feathers = 12,
			length = { 0.95, 1.35 },
			width = 0.34,
			sweep = 42,
			rows = { P.wingA, P.wingB, P.wingC },
			tip = P.tip,
			armStyle = P.plume[3],
		})

		-- Patte repliée et serres
		local leg = "Leg" .. sfx
		A.limb(rig, leg, side, { { v3(0.14, 1.12, 0.05), 0.08, 0.08 }, { v3(0.16, 0.86, 0.12), 0.055, 0.055 }, { v3(0.17, 0.64, 0.02), 0.045, 0.045 } }, P.leg)
		local foot = A.mx(v3(0.17, 0.62, 0.0), side)
		for k = -1, 1 do
			local dir = v3(side * k * 0.35, -0.25, -1).Unit
			local tip = foot + dir * 0.2
			rig:strut(leg, "Toe", foot, tip, 0.04, 0.04, P.leg)
			rig:wedge(leg, "Talon", Kit.lookAlong(tip + dir * 0.04, dir), v3(0.035, 0.05, 0.08), P.claw)
		end
		rig:strut(leg, "Toe", foot, foot + v3(0, -0.04, 0.14), 0.04, 0.04, P.leg)
		if side > 0 then
			rig:ring(leg, "LegBand", cf(A.mx(v3(0.16, 0.8, 0.1), side)) * ang(math.pi / 2, 0, 0), 0.06, 0.025, 0.05, 8, P.gold)
		end
	end)

	A.featherFan(rig, "Tail1", cf(0, 1.27, 0.72), 7, 1.0, 0.24, 55, { P.wingA[1], P.wingB[1], P.wingA[2] }, P.tip)

	rig:hitbox(cf(0, 1.35, -0.1), v3(4.4, 1.2, 3.0))

	if rig.effects then
		local sc = rig.scale
		local mist = rig:anchor("Body", "FX_Mist", cf(0, 1.4, 0), v3(3.6, 0.3, 1.2))
		Fx.particles(mist, Fx.mist("WingMist", { rgb(170, 120, 230), rgb(80, 60, 130) }, 6, 0.9, 0.2), sc)
		Fx.particles(mist, Fx.sparkles("FeatherGlint", { rgb(210, 160, 255) }, 3, 0.18, -0.2), sc)
		Fx.light(rig.bones.Head, { color = rgb(200, 130, 255), range = 5, brightness = 1 }, sc)
	end


	-- Effets avancés : signature, origine de la capacité, aura de rareté
	if rig.effects then
		Vfx.wingTrails(rig, v3(1.95, 1.76, -0.08), v3(0.08, 0, 0.28), { colors = { rgb(200, 150, 255), rgb(90, 60, 160) }, transparency = { 0.3, 1 }, lifetime = 0.35 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Common")
	end

	return rig:finish({ Rarity = "Common" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Corbeau des Brumes",
	Rarity = "Common",
	Zone = "Surface",
	Scale = 1.2,
	Category = "Créature Commune",
	Description = "Oiseau aux plumes sombres et aux yeux violets brumeux. Plane sans bruit au-dessus du canyon.",
	Icon = { top = rgb(70, 54, 110), bottom = rgb(18, 14, 34), glow = rgb(200, 140, 255), motif = rgb(170, 120, 240), yaw = 30, pitch = 18, zoom = 1.15 },
	Animation = { gait = "Flyer", flap = 32, flapRate = 6.5, hover = 0.12, headLook = 25, tailSway = 6, tailRate = 1.5 },
	Ability = ABILITY,
	build = build,
}

return Def
