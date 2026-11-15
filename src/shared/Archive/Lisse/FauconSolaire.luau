--!strict
--[[
	FAUCON SOLAIRE — Épique · Petit
	===============================
	Faucon aux plumes dorées qui laissent une traînée de lumière.
	
	• Plumage d'or (crème -> or -> ambre), rémiges incrustées de cristaux de soleil.
	• Masque ambré, bec et serres dorés, yeux Neon blanc solaire.
	• Effets : traînées de lumière dorée au bout des ailes, poussière de soleil.
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

local ID = "FauconSolaire"

local P = {
	core = S(rgb(170, 100, 20)),
	plume = { S(rgb(255, 244, 200)), S(rgb(255, 214, 110)), S(rgb(244, 172, 44)), S(rgb(206, 122, 20)) },
	crystalA = { S(rgb(255, 200, 80), M.Glass, { transparency = 0.25 }), S(rgb(255, 170, 50), M.Glass, { transparency = 0.25 }) },
	crystalB = { S(rgb(255, 230, 140), M.Glass, { transparency = 0.2 }), S(rgb(255, 200, 100), M.Glass, { transparency = 0.2 }) },
	crystalC = { S(rgb(255, 245, 200), M.Glass, { transparency = 0.15 }) },
	glow = S(rgb(255, 220, 110), M.Neon),
	shards = { S(rgb(255, 220, 110), M.Neon), S(rgb(255, 170, 50), M.Glass, { transparency = 0.2 }), S(rgb(255, 250, 210), M.Neon) },
	mask = S(rgb(120, 60, 12)),
	gold = S(rgb(255, 200, 56)),
	goldDark = S(rgb(210, 136, 24)),
	eye = S(rgb(255, 252, 220), M.Neon),
	socket = S(rgb(60, 30, 4)),
}

local BODY = Kit.spine({
	{ pos = v3(0, 1.62, -0.9), rx = 0.24, ry = 0.24 },
	{ pos = v3(0, 1.58, -0.5), rx = 0.46, ry = 0.44 },
	{ pos = v3(0, 1.5, 0.05), rx = 0.5, ry = 0.46 },
	{ pos = v3(0, 1.42, 0.6), rx = 0.34, ry = 0.3 },
	{ pos = v3(0, 1.36, 0.95), rx = 0.15, ry = 0.12 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 1.84, -1.32), rx = 0.17, ry = 0.17 },
	{ pos = v3(0, 1.86, -1.14), rx = 0.27, ry = 0.26 },
	{ pos = v3(0, 1.82, -0.92), rx = 0.26, ry = 0.25 },
	{ pos = v3(0, 1.7, -0.74), rx = 0.22, ry = 0.22 },
})

-- Capacité spéciale (CreatureForge.playAbility)
local ABILITY: Types.Ability = {
	name = "Éclat solaire",
	kind = "Burst",
	colors = { rgb(255, 220, 110), rgb(255, 160, 40), rgb(255, 255, 230) },
	texture = "sparkle",
	radius = 6,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 1.5, 0))
	rig:bone("Head", "Body", cf(0, 1.7, -0.8))
	rig:bone("Tail1", "Body", cf(0, 1.38, 0.85))
	rig:mirrored(function(side, sfx)
		rig:bone("Wing" .. sfx, "Body", cf(side * 0.34, 1.68, -0.4))
		rig:bone("Leg" .. sfx, "Body", cf(side * 0.16, 1.2, 0.05))
	end)

	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.25,
		cover = { A.scales(P.plume, v3(0.26, 0.07, 0.36), 0.2, { arc = 180, tilt = 26, refRadius = 0.45, seed = 1 }) },
	})
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.16,
		cover = { A.scales(P.plume, v3(0.16, 0.05, 0.2), 0.12, { arc = 180, from = 1.5, tilt = 22, refRadius = 0.26, seed = 2 }) },
	})
	A.horn(rig, "Head", { v3(0, 1.86, -1.3), v3(0, 1.82, -1.5), v3(0, 1.72, -1.6), v3(0, 1.62, -1.58) }, 0.11, 0.02, P.gold)
	A.crystals(rig, "Head", cf(0, 2.02, -0.86) * ang(rad(45), 0, 0), 5, 0.5, P.shards, 4, 0.4)
	rig:mirrored(function(side, sfx)
		A.eye(rig, "Head", A.mx(v3(0.2, 1.94, -1.18), side), v3(side, 0.2, -0.5), 0.13, "Glow", P.socket, P.eye)
		A.brow(rig, "Head", side, v3(0.17, 2.04, -1.2), 0.22, 22, P.mask)
		rig:strut("Head", "Mask", A.mx(v3(0.22, 1.86, -1.16), side), A.mx(v3(0.24, 1.66, -1.08), side), 0.07, 0.04, P.mask)

		A.wing(rig, "Wing" .. sfx, side, {
			arm = { v3(0.34, 1.68, -0.42), v3(1.0, 1.84, -0.4), v3(1.7, 1.94, -0.28), v3(2.45, 1.98, -0.08) },
			armRadius = 0.14,
			feathers = 13,
			length = { 1.05, 1.55 },
			width = 0.36,
			sweep = 45,
			rows = { P.crystalA, P.crystalB, P.crystalC },
			tip = P.glow,
			armStyle = P.plume[3],
		})
		for k = 1, 3 do
			local p = A.mx(v3(0.6 + k * 0.55, 1.9 + k * 0.03, -0.42 + k * 0.05), side)
			A.crystals(rig, "Wing" .. sfx, cf(p) * ang(rad(-20), 0, -side * rad(10)), 2, 0.34, P.shards, 10 * k + side, 0.3)
		end

		local leg = "Leg" .. sfx
		A.limb(rig, leg, side, { { v3(0.16, 1.2, 0.05), 0.1, 0.1 }, { v3(0.18, 0.92, 0.12), 0.07, 0.07 }, { v3(0.19, 0.7, 0.02), 0.055, 0.055 } }, P.gold)
		local foot = A.mx(v3(0.19, 0.68, 0.0), side)
		for k = -1, 1 do
			local dir = v3(side * k * 0.4, -0.3, -1).Unit
			local tip = foot + dir * 0.22
			rig:strut(leg, "Toe", foot, tip, 0.05, 0.05, P.gold)
			rig:wedge(leg, "Talon", Kit.lookAlong(tip + dir * 0.05, dir), v3(0.045, 0.06, 0.11), P.goldDark)
		end
	end)

	A.featherFan(rig, "Tail1", cf(0, 1.4, 0.88), 9, 1.25, 0.28, 60, { P.crystalA[1], P.crystalB[1], P.crystalA[2] }, P.glow)

	A.orbit(rig, "Aura1", v3(0, 1.6, 0), 2.1, 6, 0.3, function(bone, c, i)
		rig:shard(bone, "OrbitCrystal", c * ang(0, 0, rad(12)), 0.18, 0.46, 0.22, P.shards[(i % 3) + 1])
	end)

	rig:hitbox(cf(0, 1.6, -0.1), v3(5.2, 1.6, 3.2))

	if rig.effects then
		local sc = rig.scale
		local dust = rig:anchor("Body", "FX_Crystal", cf(0, 1.8, 0.2), v3(4.4, 0.3, 1.6))
		Fx.particles(dust, Fx.sparkles("CrystalDust", { rgb(255, 238, 194), rgb(255, 204, 74) }, 10, 0.24, -0.2), sc)
		Fx.light(rig.bones.Body, { color = rgb(255, 213, 106), range = 10, brightness = 1.4 }, sc)
	end


	-- Effets avancés : signature, origine de la capacité, aura de rareté
	if rig.effects then
		Vfx.wingTrails(rig, v3(2.45, 1.98, -0.08), v3(0.1, 0, 0.32), { colors = { rgb(255, 229, 162), rgb(255, 201, 62) }, transparency = { 0.2, 1 }, lifetime = 0.45 })
		Vfx.orbitRing(rig, "Aura1", Vfx.orbitPoints(v3(0, 1.6, 0), 2.1, 6, 0.3), { colors = { rgb(255, 229, 162), rgb(255, 204, 74) }, transparency = { 0.4, 0.7 }, width0 = 0.05 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Epic")
	end

	return rig:finish({ Rarity = "Epic" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Faucon solaire",
	Rarity = "Epic",
	Size = "Small",
	Income = 500,
	SpeedBonus = 0.25,
	Passenger = false,
	Scale = 1.2,
	Category = "Créature Épique",
	Description = "Faucon au plumage d'or : chaque battement d'ailes laisse une traînée de lumière solaire.",
	Icon = { top = rgb(170, 100, 20), bottom = rgb(40, 18, 4), glow = rgb(255, 230, 140), motif = rgb(255, 210, 90), yaw = 28, pitch = 16, zoom = 1.15 },
	Animation = { gait = "Flyer", flap = 30, flapRate = 5, hover = 0.14, headLook = 25, tailSway = 4, tailRate = 1.5, auraSpeed = 0.8 },
	Ability = ABILITY,
	build = build,
}

return Def
