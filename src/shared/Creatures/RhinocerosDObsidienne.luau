--!strict
--[[
	LE RHINOCÉROS D'OBSIDIENNE — Légendaire · Géant
	===============================================
	Rhinocéros en pierre volcanique noire et brillante.

	• Corps massif en plaques d'obsidienne polie (reflets violets), fissures de lave orange.
	• Énorme corne principale en obsidienne vitreuse cerclée de lave, seconde corne plus petite.
	• Épaulières en lames d'obsidienne, pattes-colonnes aux sabots de basalte.
	• Petites oreilles, yeux Neon orange ; selle de basalte pour deux cavaliers.
	• Éclats d'obsidienne et braises en orbite ; effets : fumée, braises, lueur de lave.
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

local ID = "RhinocerosDObsidienne"

local P = {
	core = S(rgb(24, 18, 22)),
	plates = {
		S(rgb(78, 70, 96), M.SmoothPlastic, { reflectance = 0.2 }),
		S(rgb(52, 46, 66), M.SmoothPlastic, { reflectance = 0.2 }),
		S(rgb(34, 30, 44), M.SmoothPlastic, { reflectance = 0.15 }),
		S(rgb(20, 18, 28), M.SmoothPlastic, { reflectance = 0.15 }),
	},
	glass = S(rgb(40, 30, 60), M.Glass, { transparency = 0.05, reflectance = 0.3 }),
	basalt = S(rgb(46, 42, 46), M.Basalt),
	basaltDark = S(rgb(30, 28, 32), M.Basalt),
	lava = S(rgb(255, 120, 20), M.Neon),
	lavaHot = S(rgb(255, 210, 90), M.Neon),
	eye = S(rgb(255, 150, 30), M.Neon),
	socket = S(rgb(20, 10, 6)),
	inner = S(rgb(90, 60, 70)),
}

local BODY = Kit.spine({
	{ pos = v3(0, 2.25, -1.75), rx = 0.5, ry = 0.55 },
	{ pos = v3(0, 2.3, -1.2), rx = 0.85, ry = 0.95 },
	{ pos = v3(0, 2.25, -0.4), rx = 0.98, ry = 1.02 },
	{ pos = v3(0, 2.3, 0.45), rx = 0.98, ry = 1.0 },
	{ pos = v3(0, 2.2, 1.15), rx = 0.78, ry = 0.82 },
	{ pos = v3(0, 2.0, 1.6), rx = 0.3, ry = 0.32 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 1.75, -3.05), rx = 0.24, ry = 0.22 },
	{ pos = v3(0, 1.88, -2.75), rx = 0.38, ry = 0.34 },
	{ pos = v3(0, 2.05, -2.35), rx = 0.48, ry = 0.46 },
	{ pos = v3(0, 2.2, -1.95), rx = 0.5, ry = 0.52 },
})

local ABILITY: Types.Ability = {
	name = "Charge volcanique",
	kind = "Stomp",
	colors = { rgb(255, 130, 30), rgb(60, 20, 10), rgb(255, 220, 120) },
	texture = "fire",
	radius = 8,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 2.25, 0))
	rig:bone("Head", "Body", cf(0, 2.2, -1.85))
	rig:bone("Tail1", "Body", cf(0, 2.1, 1.6))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.62, 1.8, -0.95))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.62, 1.8, 0.85))
		rig:bone("Ear" .. sfx, "Head", cf(side * 0.32, 2.62, -1.95))
	end)

	-- Plaques d'obsidienne polie
	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.45,
		cover = { A.scales(P.plates, v3(0.62, 0.2, 0.56), 0.5, { arc = 180, tilt = 8, jitter = 0.45, refRadius = 0.9, seed = 1 }) },
	})
	-- Fissures de lave sur les flancs
	rig:mirrored(function(side)
		for k, u in { 1.8, 2.6, 3.4, 4.2 } do
			local a = BODY:surface(u, side * 70, 0.16).Position
			local b = BODY:surface(u + 0.25, side * 100, 0.16).Position
			local c = BODY:surface(u + 0.1, side * 128, 0.12).Position
			rig:strut("Body", "LavaCrack", a, b, 0.07, 0.04, P.lava)
			rig:strut("Body", "LavaCrack", b, c, 0.05, 0.04, if k % 2 == 0 then P.lavaHot else P.lava)
		end
	end)
	-- Lames d'obsidienne sur les épaules et l'échine
	rig:mirrored(function(side)
		for k = 0, 2 do
			local sh = BODY:surface(1.9 + k * 0.22, side * (48 + k * 6), 0.12)
			rig:spike("Body", "ShoulderBlade", sh * ang(rad(-40), 0, -side * rad(20)), 0.36 - k * 0.06, 0.7 - k * 0.12, 0.08, P.glass)
		end
	end)
	A.crest(rig, BODY, const("Body"), 1.6, 5.4, 0.42, 0.36, 0.26, P.plates[4], P.lava, 0, 30)

	-- Selle de basalte (deux places)
	local saddle = BODY:surface(3.2, 0, 0.18)
	rig:prism("Body", "Saddle", saddle, v3(1.2, 0.16, 1.5), 0.1, P.basalt)
	rig:prism("Body", "SaddleBack", saddle * cf(0, 0.22, 0.72) * ang(rad(-12), 0, 0), v3(1.0, 0.36, 0.14), 0.06, P.basaltDark)
	rig:block("Body", "SaddleLava", saddle * cf(0, 0.09, 0), v3(1.22, 0.04, 0.06), P.lava)
	rig:seat("Body", saddle * cf(0, 0.18, -0.3), v3(0.8, 0.2, 0.7))

	-- Tête et cornes
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.24,
		cover = { A.scales(P.plates, v3(0.32, 0.12, 0.3), 0.24, { arc = 180, tilt = 10, jitter = 0.3, refRadius = 0.45, seed = 3 }) },
	})
	A.horn(rig, "Head", { v3(0, 2.08, -2.85), v3(0, 2.35, -3.05), v3(0, 2.75, -3.15), v3(0, 3.15, -3.05), v3(0, 3.35, -2.9) }, 0.26, 0.04, P.glass, P.lava, { 1.6, 2.8 })
	A.horn(rig, "Head", { v3(0, 2.4, -2.45), v3(0, 2.62, -2.5), v3(0, 2.82, -2.42) }, 0.14, 0.03, P.glass)
	rig:mirrored(function(side, sfx)
		A.eye(rig, "Head", A.mx(v3(0.38, 2.28, -2.3), side), v3(side, 0.2, -0.4), 0.11, "Glow", P.socket, P.eye)
		A.brow(rig, "Head", side, v3(0.34, 2.38, -2.32), 0.24, 18, P.plates[4])
		rig:ball("Head", "Nostril", A.mx(v3(0.15, 1.78, -3.04), side), 0.08, P.lava)
		A.ear(rig, "Ear" .. sfx, cf(A.mx(v3(0.32, 2.62, -1.95), side)) * ang(rad(-10), side * rad(-20), side * rad(-24)), 0.24, 0.36, P.plates[2], P.inner, P.lava)
	end)

	-- Pattes-colonnes
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, z in { F = -0.95, B = 0.85 } do
			local bone = "Leg_" .. key .. s
			local leg = A.limb(rig, bone, side, { { v3(0.62, 1.8, z), 0.42, 0.46 }, { v3(0.66, 1.0, z - 0.05), 0.32, 0.32 }, { v3(0.66, 0.28, z), 0.3, 0.3 } }, P.core, A.scales(P.plates, v3(0.32, 0.12, 0.3), 0.26, { arc = 180, tilt = 8, refRadius = 0.32, seed = 10 + side }))
			rig:band(leg, bone, "LavaBand", 2.55, 0.08, 0.06, P.lava)
			A.hoof(rig, bone, A.mx(v3(0.66, 0, z), side), 0.62, P.basaltDark, P.lava, P.basalt)
		end
	end)

	-- Petite queue
	rig:prismBetween("Tail1", "Tail", v3(0, 2.1, 1.65), v3(0, 1.5, 1.95), 0.12, 0.12, 0.04, P.plates[3])
	A.tuftBurst(rig, "Tail1", A.alongUp(v3(0, 1.5, 1.95), v3(0, -1, 0.4)), 6, 0.3, 0.1, { P.plates[4] }, P.lava, 25, 7)

	-- Éclats d'obsidienne et braises en orbite
	A.orbit(rig, "Aura1", v3(0, 2.6, 0), 3.4, 7, 0.5, function(bone, c, i)
		rig:shard(bone, "ObsidianShard", c * ang(rad(20 * i), 0, rad(25)), 0.3, 0.7, 0.3, P.glass)
		rig:shard(bone, "LavaCore", c * ang(rad(20 * i), 0, rad(25)), 0.14, 0.4, 0.14, P.lava)
	end)

	rig:hitbox(cf(0, 2.0, -0.4), v3(2.6, 4, 5.8))

	if rig.effects then
		local sc = rig.scale
		local body = rig:anchor("Body", "FX_Volcano", cf(0, 2.6, 0), v3(2, 1, 3.2))
		Fx.particles(body, Fx.embers("Embers", { rgb(255, 210, 100), rgb(255, 90, 20) }, 10, 0.16), sc)
		Fx.particles(body, Fx.mist("Smoke", { rgb(70, 60, 60), rgb(20, 16, 16) }, 6, 1.6, 0), sc)
		Fx.light(body, { color = rgb(255, 120, 30), range = 14, brightness = 1.6 }, sc)
		local nose = rig:anchor("Head", "FX_Nostrils", cf(0, 1.75, -3.1), v3(0.4, 0.2, 0.2))
		Fx.particles(nose, Fx.mist("Snort", { rgb(120, 100, 100), rgb(40, 30, 30) }, 3, 0.6, 0), sc)
		Vfx.orbitTethers(rig, "Aura1", Vfx.orbitPoints(v3(0, 2.6, 0), 3.4, 7, 0.5), "Head", v3(0, 3.35, -2.9), { colors = { rgb(255, 160, 50), rgb(160, 40, 10) }, transparency = { 0.35, 0.85 }, width0 = 0.06, width1 = 0.02, curve0 = 0.6 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Legendary")
	end

	return rig:finish({ Rarity = "Legendary" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Rhinocéros d'obsidienne",
	Rarity = "Legendary",
	Size = "Giant",
	Income = 14000,
	SpeedBonus = 0.55,
	Passenger = true,
	Scale = 2.8,
	Category = "Créature Légendaire",
	Description = "Rhinocéros de pierre volcanique noire et brillante ; la lave luit entre ses plaques.",
	Icon = { top = rgb(90, 40, 20), bottom = rgb(12, 8, 10), glow = rgb(255, 140, 40), motif = rgb(255, 120, 30), yaw = 34, pitch = 10, zoom = 1.05 },
	Animation = { gait = "Quadruped", breathe = 0.04, bob = 0.08, stride = 22, strideRate = 7, tailSway = 10, tailRate = 1.4, headLook = 12, earTwitch = true, flicker = 0.25, auraSpeed = 0.4 },
	Ability = ABILITY,
	build = build,
}

return Def
