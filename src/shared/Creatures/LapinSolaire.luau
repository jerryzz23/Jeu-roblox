--!strict
--[[
	LE LAPIN SOLAIRE — Commun · La Surface
	======================================
	Créature vive à la fourrure dorée et aux anneaux lumineux qui s'activent le jour.

	• Fourrure dorée en mèches à pointes blanc-or, ventre crème, queue pompon.
	• Longues oreilles à intérieur orangé et pointe ardente ; grands yeux ambrés, joues duveteuses.
	• Deux anneaux Neon autour du corps + halo au-dessus de la tête + soleil frontal.
	• Trois petits soleils en orbite.
	• Effets : étincelles solaires, lumière chaude.
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

local ID = "LapinSolaire"

local P = {
	core = S(rgb(214, 140, 50)),
	fur = { S(rgb(255, 226, 120)), S(rgb(255, 200, 76)), S(rgb(242, 164, 52)), S(rgb(212, 124, 40)) },
	furTip = S(rgb(255, 238, 168)),
	cream = { S(rgb(255, 246, 214)), S(rgb(250, 228, 180)) },
	inner = S(rgb(255, 150, 110)),
	earTip = S(rgb(255, 120, 40)),
	nose = S(rgb(255, 130, 150)),
	tooth = S(rgb(255, 255, 250)),
	eye = S(rgb(255, 160, 30)),
	socket = S(rgb(120, 60, 20)),
	pupil = S(rgb(40, 20, 10)),
	pad = S(rgb(255, 214, 190)),
	sun = S(rgb(255, 226, 80), M.Neon),
	sunCore = S(rgb(255, 255, 210), M.Neon),
}

local BODY = Kit.spine({
	{ pos = v3(0, 0.92, -0.55), rx = 0.32, ry = 0.32 },
	{ pos = v3(0, 0.88, -0.25), rx = 0.46, ry = 0.45 },
	{ pos = v3(0, 0.86, 0.15), rx = 0.53, ry = 0.5 },
	{ pos = v3(0, 0.82, 0.5), rx = 0.47, ry = 0.45 },
	{ pos = v3(0, 0.72, 0.76), rx = 0.26, ry = 0.24 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 1.22, -1.07), rx = 0.1, ry = 0.09 },
	{ pos = v3(0, 1.25, -0.95), rx = 0.25, ry = 0.23 },
	{ pos = v3(0, 1.3, -0.77), rx = 0.34, ry = 0.32 },
	{ pos = v3(0, 1.3, -0.56), rx = 0.3, ry = 0.3 },
})

local function sun(rig: Kit.Rig, bone: string, c: CFrame, r: number)
	rig:ball(bone, "Sun", c.Position, r * 2, P.sun)
	rig:ball(bone, "SunCore", c.Position, r * 1.3, P.sunCore)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		rig:spike(bone, "SunRay", c * ang(0, 0, a) * cf(0, r * 1.05, 0), r * 0.7, r * (if i % 2 == 0 then 1.3 else 0.9), r * 0.3, P.sun)
	end
end

-- Capacité spéciale (CreatureForge.playAbility)
local ABILITY: Types.Ability = {
	name = "Éruption solaire",
	kind = "Nova",
	colors = { rgb(255, 220, 80), rgb(255, 150, 40), rgb(255, 255, 220) },
	texture = "sparkle",
	radius = 4.5,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 0.86, 0))
	rig:bone("Head", "Body", cf(0, 1.15, -0.55))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.28, 0.75, -0.35))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.36, 0.86, 0.4))
		rig:bone("Ear" .. sfx, "Head", cf(side * 0.14, 1.55, -0.68))
	end)

	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.25,
		cover = {
			A.fur(P.fur, P.furTip, v3(0.22, 0.36, 0.32), 0.18, { arc = 125, seed = 1 }),
			A.fur(P.cream, nil, v3(0.22, 0.26, 0.28), 0.2, { arc = 55, center = 180, seed = 2 }),
		},
	})
	-- Anneaux lumineux autour du corps
	rig:band(BODY, "Body", "SunRing", 2.2, 0.06, 0.12, P.sun)
	rig:band(BODY, "Body", "SunRing", 3.7, 0.06, 0.12, P.sun)
	-- Queue pompon
	A.tuftBurst(rig, "Body", cf(0, 0.84, 0.8) * ang(rad(90), 0, 0), 14, 0.3, 0.16, P.cream, P.furTip, 80, 3)

	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.15,
		cover = { A.fur(P.fur, P.furTip, v3(0.16, 0.22, 0.2), 0.13, { arc = 150, from = 1.6, refRadius = 0.3, seed = 4 }) },
	})
	rig:ball("Head", "Nose", v3(0, 1.25, -1.12), 0.12, P.nose)
	rig:block("Head", "Teeth", cf(0, 1.08, -1.05), v3(0.12, 0.1, 0.04), P.tooth)
	sun(rig, "Head", cf(0, 1.5, -0.95) * ang(rad(-30), 0, 0), 0.07)
	A.flatRing(rig, "Head", v3(0, 2.25, -0.62), 0.36, 0.06, 0.05, 14, P.sun)

	rig:mirrored(function(side, sfx)
		A.eye(rig, "Head", A.mx(v3(0.23, 1.37, -0.9), side), v3(side, 0.1, -0.7), 0.18, "Round", P.socket, P.eye, P.pupil)
		A.tuftBurst(rig, "Head", cf(A.mx(v3(0.3, 1.16, -0.82), side)) * ang(0, 0, -side * rad(80)), 5, 0.2, 0.12, P.cream, nil, 35, 5 + side)
		local base = cf(A.mx(v3(0.14, 1.55, -0.68), side)) * ang(rad(16), side * rad(-12), side * rad(-10))
		A.ear(rig, "Ear" .. sfx, base, 0.4, 0.92, P.fur[2], P.inner, P.earTip)
	end)

	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		A.limb(rig, "Leg_F" .. s, side, { { v3(0.28, 0.76, -0.35), 0.15, 0.15 }, { v3(0.3, 0.4, -0.4), 0.1, 0.1 }, { v3(0.31, 0.12, -0.46), 0.08, 0.08 } }, P.core, A.fur(P.fur, P.furTip, v3(0.14, 0.2, 0.18), 0.12, { arc = 180, refRadius = 0.14, seed = 7 }))
		A.paw(rig, "Leg_F" .. s, A.mx(v3(0.31, 0, -0.52), side), v3(0, 0, -1), 0.22, 3, P.pad, P.cream[1], P.cream[2])
		A.limb(rig, "Leg_B" .. s, side, { { v3(0.36, 0.88, 0.38), 0.3, 0.36 }, { v3(0.44, 0.44, 0.5), 0.16, 0.16 }, { v3(0.42, 0.1, 0.42), 0.09, 0.09 } }, P.core, A.fur(P.fur, P.furTip, v3(0.2, 0.28, 0.26), 0.16, { arc = 180, refRadius = 0.24, seed = 8 }))
		A.paw(rig, "Leg_B" .. s, A.mx(v3(0.42, 0, 0.26), side), v3(0, 0, -1), 0.26, 3, P.pad, P.cream[1], P.cream[2])
	end)

	-- Petits soleils en orbite
	A.orbit(rig, "Aura1", v3(0, 1.3, 0), 1.25, 3, 0.15, function(bone, c)
		sun(rig, bone, c, 0.07)
	end)

	rig:hitbox(cf(0, 1.0, -0.2), v3(1.4, 2.0, 2.2))

	if rig.effects then
		local sc = rig.scale
		local glow = rig:anchor("Body", "FX_Sun", cf(0, 1.2, 0), v3(1.2, 0.8, 1.6))
		Fx.particles(glow, Fx.sparkles("SunSparkles", { rgb(255, 240, 140), rgb(255, 180, 60) }, 6, 0.22), sc)
		Fx.light(glow, { color = rgb(255, 210, 110), range = 8, brightness = 1.3 }, sc)
	end


	-- Effets avancés : signature, origine de la capacité, aura de rareté
	if rig.effects then
		-- Rayons dorés reliant les petits soleils au lapin
		Vfx.orbitTethers(rig, "Aura1", Vfx.orbitPoints(v3(0, 1.3, 0), 1.25, 3, 0.15), "Body", v3(0, 1.1, 0), { colors = { rgb(255, 230, 120), rgb(255, 170, 60) }, transparency = { 0.3, 0.8 }, width0 = 0.08, width1 = 0.02 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Common")
	end

	return rig:finish({ Rarity = "Common" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Lapin Solaire",
	Rarity = "Common",
	Zone = "Surface",
	Scale = 1.1,
	Category = "Créature Commune",
	Description = "Créature vive à la fourrure dorée. Ses anneaux lumineux s'allument au soleil.",
	Icon = { top = rgb(255, 170, 70), bottom = rgb(130, 50, 20), glow = rgb(255, 240, 150), motif = rgb(255, 250, 200), yaw = 32, pitch = 14, zoom = 1.05 },
	Animation = { gait = "Quadruped", breathe = 0.03, bob = 0.3, stride = 26, strideRate = 9, tailSway = 4, tailRate = 3, headLook = 20, sniff = true, earTwitch = true, auraSpeed = 1 },
	Ability = ABILITY,
	build = build,
}

return Def
