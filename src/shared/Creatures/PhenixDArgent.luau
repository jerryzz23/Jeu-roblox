--!strict
--[[
	PHÉNIX D'ARGENT — Légendaire · Moyen (style cubes + pixels)
	==========================================================
	Oiseau de flammes argentées, en cubes.

	• Plumage argent -> blanc nacré en pixels de plumes, collerette argentée.
	• Immenses ailes en plumes-planches sur deux rangées, pointes blanc bleuté lumineuses,
	  flammes d'argent (cubes lumineux) le long des ailes.
	• Longue traîne de plumes enflammées ; huppe de flammes blanches ; yeux glacier.
	• Plumes d'argent et boules de feu blanc en orbite ; effets : feu argenté, forte lueur froide.
]]

local Kit = require(script.Parent.Parent.Kit)
local Fx = require(script.Parent.Parent.Fx)
local Vfx = require(script.Parent.Parent.Vfx)
local Types = require(script.Parent.Parent.Types)
local Cube = require(script.Parent.Parent.Cube)
local A = require(script.Parent.Parent.Anatomy)

local S = Kit.style
local M = Enum.Material
local rgb = Color3.fromRGB
local rad = math.rad
local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles

local ID = "PhenixDArgent"

local FLAME = rgb(170, 210, 255)
local P = {
	silver = Cube.skin(rgb(196, 204, 220), Cube.feathers(17), { material = M.Metal, glow = { FLAME }, px = 0.055 }),
	pearl = Cube.skin(rgb(242, 244, 252), Cube.feathers(), { px = 0.05 }),
	grey = S(rgb(150, 156, 172), M.Metal),
	beak = S(rgb(230, 236, 248), M.Metal),
	talon = S(rgb(70, 76, 96)),
	flame = S(FLAME, M.Neon),
	flameHot = S(rgb(240, 248, 255), M.Neon),
	flameDeep = S(rgb(110, 150, 255), M.Neon),
	eye = { S(rgb(20, 26, 44)), S(rgb(230, 245, 255), M.Neon), S(rgb(140, 210, 255), M.Neon), S(rgb(20, 30, 60)) },
}

local ABILITY: Types.Ability = {
	name = "Flamme d'argent",
	kind = "Nova",
	colors = { rgb(200, 225, 255), rgb(120, 160, 255), rgb(255, 255, 255) },
	texture = "fire",
	radius = 8,
	duration = 2,
}

local TAIL = { v3(0, 1.88, 0.6), v3(0, 1.75, 1.1), v3(0, 1.55, 1.6), v3(0, 1.35, 2.1), v3(0, 1.2, 2.55) }

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	rig:bone("Body", "Root", cf(0, 2.0, 0))
	rig:bone("Head", "Body", cf(0, 2.3, -0.55))
	rig:mirrored(function(side, sfx)
		rig:bone("Wing" .. sfx, "Body", cf(side * 0.38, 2.2, -0.25))
		rig:bone("Leg" .. sfx, "Body", cf(side * 0.18, 1.65, 0.05))
	end)
	local tail = rig:boneChain("Tail", "Body", TAIL)
	-- Corps, collerette, plastron nacré
	Cube.box(rig, "Body", "Body", cf(0, 2.0, 0), v3(0.78, 0.76, 1.25), P.silver)
	Cube.box(rig, "Body", "Chest", cf(0, 1.9, -0.64), v3(0.62, 0.58, 0.06), P.pearl, { faces = { "front" }, chips = false })
	Cube.box(rig, "Head", "Ruff", cf(0, 2.25, -0.62), v3(0.86, 0.32, 0.36), P.silver)
	-- Tête : bec d'argent, yeux glacier, huppe de flammes blanches
	local hc = v3(0, 2.55, -0.82)
	Cube.box(rig, "Head", "Head", cf(hc), v3(0.6, 0.56, 0.6), P.pearl)
	rig:block("Head", "Beak", cf(hc + v3(0, -0.06, -0.4)), v3(0.2, 0.18, 0.22), P.beak)
	rig:block("Head", "BeakTip", cf(hc + v3(0, -0.16, -0.5)), v3(0.13, 0.13, 0.1), P.grey)
	rig:mirrored(function(side)
		Cube.eye(rig, "Head", v3(side * 0.3, hc.Y + 0.06, hc.Z - 0.1), v3(side, 0, 0), 0.13, "square", P.eye)
	end)
	for k, st in { P.flame, P.flameHot, P.flameDeep, P.flameHot } do
		rig:block("Head", "CrestFlame", cf(hc + v3((k - 2.5) * 0.08, 0.36 + (k % 2) * 0.1, 0.12 + k * 0.05)) * ang(rad(-25), rad(k * 20), 0), v3(0.12, 0.26, 0.12), st)
	end
	-- Ailes : deux rangées de plumes-planches, flammes d'argent sur le bord
	rig:mirrored(function(side, sfx)
		local w = "Wing" .. sfx
		local root = v3(side * 0.38, 2.2, -0.3)
		local out = v3(side, 0.2, 0).Unit
		Cube.featherWing(rig, w, root, out, v3(0, 0, 1), 2.2, 1.05, 7, { P.silver.base, P.pearl.base, P.grey }, P.flameHot)
		Cube.featherWing(rig, w, root + v3(0, 0.07, -0.02), out, v3(0, 0, 1), 1.6, 0.6, 5, { P.pearl.base, P.silver.base }, nil)
		for k = 1, 5 do
			local p = root + out * (0.35 + k * 0.36) + v3(0, 0.1 + (k % 2) * 0.05, -0.05)
			rig:block(w, "WingFlame", cf(p) * ang(rad(k * 20), rad(45), 0), v3(0.12, 0.12, 0.12), if k % 2 == 0 then P.flame else P.flameHot)
		end
	end)
	-- Traîne de plumes enflammées
	for j = 1, #tail do
		local a, b = TAIL[j], TAIL[j + 1]
		local c = Kit.lookAlong((a + b) / 2, b - a)
		local len = (b - a).Magnitude
		for k = -1, 1 do
			rig:block(tail[j], "TailFeather", c * cf(k * 0.17, 0, 0) * ang(0, rad(k * 6), 0), v3(0.15, 0.05, len * 1.1), if k == 0 then P.silver.base else P.pearl.base)
		end
		rig:block(tail[j], "TailFlame", cf(b + v3(0, 0.06, 0)) * ang(rad(j * 30), rad(45), 0), v3(0.14, 0.14, 0.14), if j % 2 == 0 then P.flame else P.flameDeep)
	end
	-- Pattes et serres
	rig:mirrored(function(side, sfx)
		local leg = "Leg" .. sfx
		local x = side * 0.18
		rig:joint(leg, v3(x, 1.65, 0.05), v3(x, 1.35, 0.05))
		Cube.box(rig, leg, "Thigh", cf(x, 1.5, 0.05), v3(0.2, 0.3, 0.2), P.silver, { chips = false })
		rig:block(leg, "Shin", cf(x, 1.2, 0.05), v3(0.09, 0.3, 0.09), P.grey)
		for t = -1, 1 do
			rig:block(leg, "Talon", cf(x + t * 0.06, 1.04, -0.03), v3(0.05, 0.05, 0.14), P.talon)
		end
	end)
	-- Plumes d'argent et boules de feu blanc en orbite
	A.orbit(rig, "Aura1", v3(0, 2.2, 0.2), 2.6, 6, 0.4, function(bone, c, i)
		rig:block(bone, "OrbitFeather", c * ang(0, 0, rad(i * 40)), v3(0.08, 0.04, 0.5), P.silver.base)
		rig:block(bone, "OrbitFeatherTip", c * ang(0, 0, rad(i * 40)) * cf(0, 0, 0.27), v3(0.09, 0.05, 0.08), P.flame)
	end)
	Cube.orbitGems(rig, "Aura2", v3(0, 2.0, 0.2), 1.6, 4, 0.3, { P.flameHot }, { S(FLAME, M.Glass, { transparency = 0.5 }) }, 0.16)

	rig:hitbox(cf(0, 2.0, 0.6), v3(4.6, 1.6, 3.2))
	if rig.effects then
		local sc = rig.scale
		local glow = rig:anchor("Body", "FX_SilverFire", cf(0, 2.1, 0.2), v3(1.0, 0.6, 1.2))
		Fx.particles(glow, Fx.fire("SilverFire", { rgb(255, 255, 255), FLAME, rgb(90, 120, 220) }, 12, 0.35), sc)
		Fx.light(glow, { color = FLAME, range = 14, brightness = 2 }, sc)
		local tipP = TAIL[#TAIL]
		Vfx.trail(rig, tail[#tail], tipP + v3(0, 0.1, 0), tipP - v3(0, 0.1, 0), { colors = { rgb(240, 248, 255), FLAME }, lifetime = 0.6 })
		rig:mirrored(function(side, sfx)
			local tip = v3(side * 2.5, 2.65, 0.1)
			Vfx.trail(rig, "Wing" .. sfx, tip + v3(0, 0, -0.25), tip + v3(0, 0, 0.35), { colors = { rgb(240, 248, 255), FLAME }, lifetime = 0.5 })
		end)
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Legendary")
	end
	return rig:finish({ Rarity = "Legendary" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Phénix d'argent",
	Rarity = "Legendary",
	Size = "Medium",
	Income = 6000,
	SpeedBonus = 0.45,
	Passenger = false,
	Scale = 1.3,
	Category = "Créature Légendaire",
	Description = "Phénix aux flammes d'argent : son feu froid illumine la nuit d'une lueur bleutée.",
	Icon = { top = rgb(90, 104, 150), bottom = rgb(16, 20, 40), glow = rgb(210, 230, 255), motif = rgb(255, 255, 255), yaw = 26, pitch = 14, zoom = 1.12 },
	Animation = { flicker = 0.35, gait = "Flyer", flap = 26, flapRate = 3.8, hover = 0.2, headLook = 20, tailSway = 6, tailRate = 1.2, auraSpeed = 0.5 },
	Ability = ABILITY,
	build = build,
}

return Def
