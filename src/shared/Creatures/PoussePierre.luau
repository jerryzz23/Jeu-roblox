--!strict
--[[
	LE POUSSE-PIERRE — Commun · La Surface
	======================================
	Mammifère trapu avec une carapace de roche grise taillée et des renforts métalliques.

	• Carapace de grosses dalles de roche (Slate) facettées en 4 tons, cerclée de trois
	  bandes d'acier à rivets de laiton.
	• Fourrure brune en mèches sur les flancs et le ventre, pattes courtes de fouisseur
	  à grosses griffes ivoire.
	• Tête casquée d'un bélier de pierre cerclé d'acier, yeux ambrés, oreilles rondes,
	  museau sombre ; petite queue cuirassée.
	• Effets : éclats et poussière de roche.
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

local ID = "PoussePierre"

local P = {
	core = S(rgb(96, 66, 46)),
	fur = { S(rgb(186, 138, 96)), S(rgb(156, 110, 74)), S(rgb(124, 84, 56)), S(rgb(96, 64, 44)) },
	furTip = S(rgb(226, 196, 150)),
	rock = {
		S(rgb(176, 176, 188), M.Slate),
		S(rgb(146, 146, 160), M.Slate),
		S(rgb(118, 118, 134), M.Slate),
		S(rgb(92, 92, 108), M.Slate),
	},
	steel = S(rgb(104, 112, 128), M.Metal),
	brass = S(rgb(232, 176, 70)),
	nose = S(rgb(40, 30, 28)),
	eye = S(rgb(255, 178, 40)),
	socket = S(rgb(40, 26, 20)),
	pupil = S(rgb(20, 14, 10)),
	claw = S(rgb(246, 238, 218)),
	pad = S(rgb(72, 50, 40)),
	inner = S(rgb(230, 150, 140)),
}

local BODY = Kit.spine({
	{ pos = v3(0, 0.82, -0.85), rx = 0.4, ry = 0.36 },
	{ pos = v3(0, 0.84, -0.45), rx = 0.62, ry = 0.5 },
	{ pos = v3(0, 0.88, 0.1), rx = 0.74, ry = 0.58 },
	{ pos = v3(0, 0.84, 0.6), rx = 0.66, ry = 0.5 },
	{ pos = v3(0, 0.72, 0.95), rx = 0.4, ry = 0.32 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 0.68, -1.62), rx = 0.14, ry = 0.12 },
	{ pos = v3(0, 0.72, -1.45), rx = 0.26, ry = 0.22 },
	{ pos = v3(0, 0.78, -1.2), rx = 0.36, ry = 0.3 },
	{ pos = v3(0, 0.82, -0.92), rx = 0.36, ry = 0.32 },
})

local TAIL = Kit.spine({
	{ pos = v3(0, 0.74, 1.0), rx = 0.16, ry = 0.14 },
	{ pos = v3(0, 0.6, 1.3), rx = 0.11, ry = 0.1 },
	{ pos = v3(0, 0.45, 1.5), rx = 0.05, ry = 0.05 },
})

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 0.85, 0))
	rig:bone("Head", "Body", cf(0, 0.82, -0.9))
	rig:bone("Tail1", "Body", cf(0, 0.74, 1.0))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.5, 0.78, -0.5))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.5, 0.8, 0.55))
		rig:bone("Ear" .. sfx, "Head", cf(side * 0.26, 1.06, -0.98))
	end)

	-- Corps : fourrure sur les flancs, carapace de roche sur le dessus
	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.3,
		cover = {
			A.fur(P.fur, P.furTip, v3(0.24, 0.32, 0.34), 0.21, { arc = 80, center = 180, seed = 1 }),
			A.scales(P.rock, v3(0.5, 0.22, 0.52), 0.34, { arc = 108, tilt = 12, jitter = 0.6, refRadius = 0.6, seed = 2 }),
		},
	})
	for _, u in { 2.1, 3.0, 3.9 } do
		rig:band(BODY, "Body", "SteelBand", u, 0.13, 0.15, P.steel, P.brass)
	end

	-- Tête casquée
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.18,
		cover = { A.fur(P.fur, P.furTip, v3(0.16, 0.2, 0.2), 0.14, { arc = 150, center = 180, from = 2.2, refRadius = 0.32, seed = 3 }) },
	})
	local helm = HEAD:surface(3.0, 0, 0.04)
	rig:prism("Head", "RockHelm", helm * cf(0, 0.02, 0.04) * ang(rad(-8), 0, 0), v3(0.44, 0.14, 0.5), 0.1, P.rock[2])
	rig:prism("Head", "RockHelm", helm * cf(0, 0.08, -0.06) * ang(rad(-20), 0, 0), v3(0.3, 0.12, 0.3), 0.08, P.rock[1])
	rig:prism("Head", "RamPlate", cf(0, 0.9, -1.4) * ang(rad(-50), 0, 0), v3(0.36, 0.26, 0.1), 0.07, P.rock[3])
	rig:ring("Head", "HelmRim", cf(0, 0.91, -1.41) * ang(rad(-50), 0, 0) * ang(math.pi / 2, 0, 0), 0.16, 0.04, 0.05, 10, P.steel)
	for k = -1, 1, 2 do
		rig:ball("Head", "Rivet", v3(k * 0.18, 0.98, -1.25), 0.06, P.brass)
	end
	rig:ball("Head", "Nose", v3(0, 0.72, -1.72), 0.16, P.nose)
	rig:mirrored(function(side, sfx)
		A.eye(rig, "Head", A.mx(v3(0.25, 0.86, -1.32), side), v3(side, 0.15, -0.8), 0.13, "Round", P.socket, P.eye, P.pupil)
		A.brow(rig, "Head", side, v3(0.24, 0.97, -1.34), 0.2, 12, P.rock[4])
		A.ear(rig, "Ear" .. sfx, cf(A.mx(v3(0.26, 1.06, -0.98), side)) * ang(rad(-10), side * rad(-30), side * rad(-35)), 0.26, 0.24, P.fur[3], P.inner)
	end)

	-- Pattes de fouisseur
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, z in { F = -0.5, B = 0.55 } do
			local bone = "Leg_" .. key .. s
			A.limb(rig, bone, side, {
				{ v3(0.5, 0.78, z), 0.22, 0.24 },
				{ v3(0.58, 0.42, z - 0.04), 0.17, 0.17 },
				{ v3(0.6, 0.14, z - 0.1), 0.13, 0.13 },
			}, P.core, A.fur(P.fur, P.furTip, v3(0.18, 0.24, 0.24), 0.16, { arc = 180, refRadius = 0.22, seed = 10 + side }))
			rig:band(Kit.spine({ { pos = A.mx(v3(0.58, 0.4, z - 0.04), side), rx = 0.18, ry = 0.18 }, { pos = A.mx(v3(0.6, 0.2, z - 0.1), side), rx = 0.15, ry = 0.15 } }), bone, "Bracer", 1.4, 0.1, 0.08, P.steel)
			A.paw(rig, bone, A.mx(v3(0.61, 0, z - 0.16), side), v3(0, 0, -1), 0.38, 3, P.pad, P.core, P.claw)
		end
	end)

	-- Petite queue cuirassée
	rig:tube(TAIL, {
		name = "Tail",
		bone = const("Tail1"),
		core = P.core,
		coreStep = 0.15,
		cover = { A.scales(P.rock, v3(0.18, 0.08, 0.18), 0.14, { arc = 130, refRadius = 0.15, seed = 4 }) },
	})

	rig:hitbox(cf(0, 0.8, -0.2), v3(1.9, 1.7, 3.4))

	if rig.effects then
		local sc = rig.scale
		local dust = rig:anchor("Root", "FX_Dust", cf(0, 0.15, 0), v3(1.8, 0.25, 2.6))
		Fx.particles(dust, Fx.mist("RockDust", { rgb(170, 160, 150), rgb(120, 112, 104) }, 5, 0.6), sc)
		local chips = rig:anchor("Body", "FX_Chips", cf(0, 1.5, 0), v3(1.2, 0.2, 1.6))
		Fx.particles(chips, {
			name = "RockChips",
			texture = Fx.TEXTURES.spark,
			colors = { rgb(190, 190, 200), rgb(130, 130, 140) },
			sizes = { 0.12, 0.08 },
			lifetime = NumberRange.new(0.8, 1.2),
			rate = 2,
			speed = NumberRange.new(0.5, 1),
			spread = Vector2.new(50, 50),
			acceleration = v3(0, -6, 0),
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-200, 200),
			volume = true,
		}, sc)
	end

	return rig:finish({ Rarity = "Common" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Pousse-Pierre",
	Rarity = "Common",
	Zone = "Surface",
	Scale = 1.3,
	Category = "Créature Commune",
	Description = "Mammifère trapu à carapace de roche cerclée d'acier. Il pousse les rochers pour creuser son terrier.",
	Icon = { top = rgb(118, 96, 74), bottom = rgb(34, 26, 20), glow = rgb(255, 210, 140), motif = rgb(176, 176, 188), yaw = 38, pitch = 20, zoom = 1.15 },
	Animation = { gait = "Quadruped", breathe = 0.025, bob = 0.06, stride = 26, strideRate = 9, tailSway = 8, tailRate = 2, headLook = 14, sniff = true, earTwitch = true },
	build = build,
}

return Def
