--!strict
--[[
	LE HIBOU DES GLACES — Inhabituel · La Surface
	============================================
	Rapace blanc et bleu givre aux yeux étincelants et aux serres métalliques.

	• Corps rond couvert de plumes blanc → bleu givre, disque facial blanc.
	• Immenses yeux Neon bleu glacier, aigrettes de plumes, petit bec crochu argenté.
	• Ailes déployées à pointes bleu glace, éclats de glace (verre) sur les épaules.
	• Serres en métal argenté aux griffes d'acier.
	• 3 cristaux de glace en orbite ; effets : flocons et brume givrée.
	Os : Root > Body > Head / Wing_R / Wing_L / Tail1 / Leg_R / Leg_L   (démarche "Flyer")
]]

local Kit = require(script.Parent.Parent.Kit)
local A = require(script.Parent.Parent.Anatomy)
local Fx = require(script.Parent.Parent.Fx)
local Types = require(script.Parent.Parent.Types)

local S = Kit.style
local M = Enum.Material
local rgb = Color3.fromRGB
local rad = math.rad
local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles

local ID = "HibouDesGlaces"

local P = {
	core = S(rgb(150, 186, 226)),
	plume = { S(rgb(255, 255, 255)), S(rgb(226, 240, 252)), S(rgb(186, 214, 244)), S(rgb(136, 178, 230)) },
	wingA = { S(rgb(206, 228, 250)), S(rgb(160, 200, 240)) },
	wingB = { S(rgb(240, 248, 255)), S(rgb(214, 232, 250)) },
	wingC = { S(rgb(255, 255, 255)), S(rgb(232, 242, 252)) },
	tip = S(rgb(80, 170, 255)),
	disc = S(rgb(255, 255, 255)),
	eye = S(rgb(140, 230, 255), M.Neon),
	socket = S(rgb(30, 60, 110)),
	pupil = S(rgb(10, 20, 50)),
	beak = S(rgb(190, 196, 210), M.Metal),
	steel = S(rgb(200, 206, 220), M.Metal),
	claw = S(rgb(70, 80, 100), M.Metal),
	ice = { S(rgb(170, 236, 255), M.Glass, { transparency = 0.2 }), S(rgb(120, 210, 255), M.Neon), S(rgb(220, 250, 255), M.Glass, { transparency = 0.1 }) },
}

local BODY = Kit.spine({
	{ pos = v3(0, 1.78, -0.32), rx = 0.4, ry = 0.38 },
	{ pos = v3(0, 1.62, -0.1), rx = 0.52, ry = 0.5 },
	{ pos = v3(0, 1.46, 0.18), rx = 0.5, ry = 0.48 },
	{ pos = v3(0, 1.3, 0.44), rx = 0.32, ry = 0.3 },
	{ pos = v3(0, 1.2, 0.58), rx = 0.12, ry = 0.1 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 2.15, -0.56), rx = 0.32, ry = 0.3 },
	{ pos = v3(0, 2.2, -0.36), rx = 0.5, ry = 0.46 },
	{ pos = v3(0, 2.18, -0.1), rx = 0.48, ry = 0.46 },
	{ pos = v3(0, 2.04, 0.08), rx = 0.3, ry = 0.3 },
})

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 1.5, 0))
	rig:bone("Head", "Body", cf(0, 1.92, -0.2))
	rig:bone("Tail1", "Body", cf(0, 1.25, 0.5))
	rig:mirrored(function(side, sfx)
		rig:bone("Wing" .. sfx, "Body", cf(side * 0.42, 1.75, -0.15))
		rig:bone("Leg" .. sfx, "Body", cf(side * 0.2, 1.15, 0.0))
	end)

	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.22,
		cover = { A.scales(P.plume, v3(0.24, 0.08, 0.28), 0.18, { arc = 180, tilt = 28, refRadius = 0.45, seed = 1 }) },
	})
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.16,
		cover = { A.scales(P.plume, v3(0.2, 0.07, 0.22), 0.15, { arc = 180, tilt = 24, refRadius = 0.45, seed = 2 }) },
	})

	-- Disque facial, yeux, bec, aigrettes
	rig:mirrored(function(side, sfx)
		local discCF = cf(A.mx(v3(0.2, 2.22, -0.6), side)) * ang(0, side * rad(-18), 0)
		rig:cylinder("Head", "FacialDisc", (discCF * cf(0, 0, 0.04)).Position, (discCF * cf(0, 0, -0.04)).Position, 0.42, P.disc)
		A.eye(rig, "Head", A.mx(v3(0.2, 2.24, -0.68), side), v3(side * 0.3, 0.05, -1), 0.22, "Round", P.socket, P.eye, P.pupil)
		A.brow(rig, "Head", side, v3(0.2, 2.42, -0.64), 0.32, 18, P.plume[4])
		A.tuftBurst(rig, "Head", cf(A.mx(v3(0.3, 2.55, -0.25), side)) * ang(rad(20), 0, -side * rad(25)), 4, 0.42, 0.14, P.wingA, P.tip, 12, 3 + side)
		A.crystals(rig, "Body", cf(A.mx(v3(0.45, 1.95, 0.0), side)) * ang(rad(20), 0, -side * rad(40)), 3, 0.36, P.ice, 10 + side, 0.3)
	end)
	A.horn(rig, "Head", { v3(0, 2.14, -0.68), v3(0, 2.06, -0.8), v3(0, 1.94, -0.8) }, 0.07, 0.02, P.beak)

	rig:mirrored(function(side, sfx)
		A.wing(rig, "Wing" .. sfx, side, {
			arm = { v3(0.42, 1.75, -0.2), v3(0.95, 1.9, -0.18), v3(1.5, 1.98, -0.08), v3(2.0, 2.0, 0.08) },
			armRadius = 0.14,
			feathers = 12,
			length = { 0.95, 1.3 },
			width = 0.34,
			sweep = 40,
			rows = { P.wingA, P.wingB, P.wingC },
			tip = P.tip,
			armStyle = P.plume[2],
		})

		-- Pattes emplumées, serres métalliques
		local leg = "Leg" .. sfx
		A.limb(rig, leg, side, { { v3(0.2, 1.15, 0.0), 0.12, 0.12 }, { v3(0.22, 0.86, 0.02), 0.1, 0.1 } }, P.plume[2], A.scales(P.plume, v3(0.12, 0.05, 0.12), 0.09, { arc = 180, refRadius = 0.12, seed = 20 + side }))
		local foot = A.mx(v3(0.22, 0.78, 0.0), side)
		for k = -1, 1 do
			local dir = v3(side * k * 0.4, -0.3, -1).Unit
			local tip = foot + dir * 0.22
			rig:strut(leg, "Toe", foot, tip, 0.05, 0.05, P.steel)
			rig:wedge(leg, "Talon", Kit.lookAlong(tip + dir * 0.05, dir), v3(0.045, 0.06, 0.11), P.claw)
		end
	end)

	A.featherFan(rig, "Tail1", cf(0, 1.26, 0.5), 7, 0.75, 0.26, 50, { P.wingA[1], P.wingB[1] }, P.tip)

	A.orbit(rig, "Aura1", v3(0, 1.7, 0), 1.6, 3, 0.25, function(bone, c, i)
		A.crystals(rig, bone, c * ang(0, 0, rad(10)), 2, 0.4, P.ice, 50 + i, 0.25)
	end)

	rig:hitbox(cf(0, 1.7, -0.1), v3(4.4, 2.0, 2.4))

	if rig.effects then
		local sc = rig.scale
		local snow = rig:anchor("Body", "FX_Snow", cf(0, 2.4, 0), v3(3.6, 0.3, 1.6))
		Fx.particles(snow, {
			name = "Snowflakes",
			texture = Fx.TEXTURES.sparkle,
			colors = { rgb(255, 255, 255), rgb(190, 230, 255) },
			sizes = { 0.14, 0.1 },
			transparencies = { 0.1, 0.4, 1 },
			lifetime = NumberRange.new(2, 3),
			rate = 8,
			speed = NumberRange.new(0.2, 0.5),
			spread = Vector2.new(40, 40),
			acceleration = v3(0, -0.6, 0),
			lightEmission = 0.6,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-90, 90),
			direction = Enum.NormalId.Bottom,
			volume = true,
		}, sc)
		Fx.particles(snow, Fx.mist("FrostMist", { rgb(210, 240, 255), rgb(150, 200, 240) }, 3, 1.0, 0.2), sc)
		Fx.light(rig.bones.Head, { color = rgb(140, 220, 255), range = 7, brightness = 1.1 }, sc)
	end

	return rig:finish({ Rarity = "Uncommon" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Hibou des Glaces",
	Rarity = "Uncommon",
	Zone = "Surface",
	Scale = 1.3,
	Category = "Créature Inhabituelle",
	Description = "Rapace blanc et bleu givre. Ses yeux étincellent et ses serres sont d'acier.",
	Icon = { top = rgb(70, 130, 200), bottom = rgb(16, 30, 60), glow = rgb(190, 240, 255), motif = rgb(170, 236, 255), yaw = 26, pitch = 10, zoom = 1.1 },
	Animation = { gait = "Flyer", flap = 26, flapRate = 4.5, hover = 0.12, headLook = 35, tailSway = 4, tailRate = 1.4, auraSpeed = 0.6 },
	build = build,
}

return Def
