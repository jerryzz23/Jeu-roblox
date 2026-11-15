--!strict
--[[
	GRIFFON IMPÉRIAL — Légendaire · Grand (style cubes + pixels)
	===========================================================
	Mi-aigle mi-lion en cubes, avec une armure dorée.

	• Avant d'aigle : tête et poitrail en pixels de plumes blanches, bec d'or crochu, huppe,
	  pattes d'aigle aux écailles jaunes et serres noires.
	• Arrière de lion : pelage fauve en pixels de fourrure, pattes à coussinets, queue à touffe sombre.
	• Grandes ailes en plumes-planches sur deux rangées (blanc, or, bronze), pointes or lumineuses.
	• Armure impériale : casque à crête, plastron serti d'un rubis, ceinture et épaulières d'or,
	  selle de velours pourpre (monture avec passager).
	• Plumes d'or en orbite ; effets : poussière d'or, traînées dorées au bout des ailes.
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

local ID = "GriffonImperial"

local GOLD = rgb(255, 210, 80)
local P = {
	fawn = Cube.skin(rgb(206, 152, 82), Cube.fur(), { px = 0.065 }),
	white = Cube.skin(rgb(246, 244, 238), Cube.feathers(), { px = 0.06 }),
	scaleY = Cube.skin(rgb(240, 196, 60), Cube.scales(0, 3, 2), { px = 0.045 }),
	gold = Cube.skin(rgb(236, 188, 60), Cube.plates(6, 4), { material = M.Metal, px = 0.05 }),
	velvet = Cube.skin(rgb(110, 30, 90), Cube.plates(5, 5), { material = M.Fabric, px = 0.06 }),
	tuft = S(rgb(80, 50, 30)),
	beak = S(rgb(255, 200, 50), M.Metal),
	talon = S(rgb(24, 20, 20)),
	ruby = S(rgb(230, 30, 60), M.Neon),
	glow = S(GOLD, M.Neon),
	bronze = S(rgb(170, 110, 50), M.Metal),
	crest = S(rgb(200, 40, 40)),
	eye = { S(rgb(30, 18, 6)), S(rgb(255, 240, 180), M.Neon), S(rgb(255, 170, 30), M.Neon), S(rgb(20, 10, 4)) },
}

local ABILITY: Types.Ability = {
	name = "Charge impériale",
	kind = "Burst",
	colors = { rgb(255, 214, 90), rgb(200, 120, 20), rgb(255, 255, 255) },
	texture = "sparkle",
	radius = 7,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local tail = { v3(0, 2.0, 1.15), v3(0, 1.9, 1.55), v3(0, 1.7, 2.0), v3(0, 1.55, 2.45), v3(0, 1.55, 2.85) }
	local q = Cube.quadruped(rig, {
		body = { c = v3(0, 1.8, 0.05), size = v3(1.1, 0.95, 2.2), skin = P.fawn },
		neck = v3(0, 2.15, -0.95),
		head = { c = v3(0, 2.62, -1.3), size = v3(0.78, 0.74, 0.8), skin = P.white },
		eyes = { kind = "square", size = 0.14, colors = P.eye, side = true, x = 0, y = 2.7, z = -1.42 },
		legs = { x = 0.36, zf = -0.75, zb = 0.8, hipY = 1.4, w = 0.33, skin = P.fawn, foot = "paw" },
		tail = { pts = tail, sizes = { 0.2, 0.2, 0.18, 0.18 }, skin = P.fawn },
	})
	-- Avant d'aigle : poitrail de plumes blanches, cou, pattes jaunes aux serres noires
	Cube.box(rig, "Body", "EagleChest", cf(0, 1.9, -0.6), v3(1.16, 1.02, 0.95), P.white)
	Cube.boxBetween(rig, "Head", "Neck", v3(0, 2.0, -0.9), v3(0, 2.45, -1.2), 0.6, 0.6, P.white, { chips = false })
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		local leg = "Leg_F" .. s
		Cube.box(rig, leg, "EagleShin", cf(side * 0.36, 0.42, -0.75), v3(0.36, 0.56, 0.38), P.scaleY, { chips = false })
		for t = -1, 1 do
			rig:block(leg, "Talon", cf(side * 0.36 + t * 0.11, 0.08, -1.0) * ang(rad(-30), 0, 0), v3(0.07, 0.16, 0.12), P.talon)
		end
	end)
	-- Bec d'or crochu, huppe, casque à crête
	local hc = v3(0, 2.62, -1.3)
	rig:block("Head", "Beak", cf(hc + v3(0, -0.1, -0.5)), v3(0.3, 0.26, 0.26), P.beak)
	rig:block("Head", "BeakHook", cf(hc + v3(0, -0.24, -0.62)), v3(0.18, 0.18, 0.12), P.beak)
	Cube.box(rig, "Head", "Helmet", cf(hc + v3(0, 0.38, 0.05)), v3(0.84, 0.12, 0.86), P.gold, { chips = false })
	for k = 0, 4 do
		rig:block("Head", "HelmetCrest", cf(hc + v3(0, 0.55 + math.sin(k / 4 * math.pi) * 0.12, -0.35 + k * 0.2)), v3(0.08, 0.22, 0.18), P.crest)
	end
	-- Armure : plastron au rubis, ceinture, épaulières, selle de velours
	Cube.box(rig, "Body", "Breastplate", cf(0, 1.85, -1.08), v3(0.86, 0.66, 0.08), P.gold, { faces = { "front" }, chips = false })
	rig:block("Body", "Ruby", cf(0, 1.92, -1.14) * ang(0, 0, rad(45)), v3(0.18, 0.18, 0.08), P.ruby)
	Cube.box(rig, "Body", "Belt", cf(0, 1.8, 0.2), v3(1.16, 1.0, 0.2), P.gold, { faces = { "left", "right", "top" }, chips = false })
	rig:mirrored(function(side, sfx)
		Cube.box(rig, "Leg_F" .. string.sub(sfx, 2), "Pauldron", cf(side * 0.48, 1.62, -0.75) * ang(0, 0, -side * rad(12)), v3(0.42, 0.26, 0.5), P.gold)
	end)
	Cube.box(rig, "Body", "Saddle", cf(0, 2.33, 0.45), v3(0.9, 0.14, 0.85), P.velvet, { chips = false })
	-- Ailes : deux rangées de plumes-planches, pointes or lumineuses
	rig:mirrored(function(side, sfx)
		rig:bone("Wing" .. sfx, "Body", cf(side * 0.55, 2.25, -0.45))
		local w = "Wing" .. sfx
		local root = v3(side * 0.55, 2.25, -0.45)
		local out = v3(side * 0.78, 0.6, 0.18).Unit
		Cube.featherWing(rig, w, root, out, v3(0, -0.1, 1).Unit, 1.9, 1.0, 7, { P.white.base, P.gold.base, P.bronze }, P.glow)
		Cube.featherWing(rig, w, root + v3(0, 0.06, -0.02), out, v3(0, -0.1, 1).Unit, 1.3, 0.55, 5, { P.white.base, P.gold.base }, nil)
	end)
	-- Touffe sombre au bout de la queue
	rig:block(q.tail[#q.tail], "Tuft", cf(tail[#tail]) * ang(rad(20), 0, 0), v3(0.3, 0.3, 0.32), P.tuft)
	-- Plumes d'or en orbite
	A.orbit(rig, "Aura1", v3(0, 2.2, 0.1), 2.4, 6, 0.4, function(bone, c, i)
		rig:block(bone, "GoldFeather", c * ang(0, 0, rad(i * 30)), v3(0.08, 0.04, 0.46), P.gold.base)
		rig:block(bone, "GoldFeatherTip", c * ang(0, 0, rad(i * 30)) * cf(0, 0, 0.25), v3(0.09, 0.05, 0.07), P.glow)
	end)

	rig:hitbox(cf(0, 1.9, 0.3), v3(3.4, 4, 4.6))
	if rig.effects then
		local sc = rig.scale
		local dust = rig:anchor("Body", "FX_GoldDust", cf(0, 2.2, 0), v3(1.4, 0.8, 2.0))
		Fx.particles(dust, Fx.sparkles("GoldDust", { rgb(255, 240, 180), GOLD }, 8, 0.16, 0.15), sc)
		Fx.light(dust, { color = GOLD, range = 10, brightness = 1.2 }, sc)
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Legendary")
	end
	return rig:finish({ Rarity = "Legendary" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Griffon impérial",
	Rarity = "Legendary",
	Size = "Large",
	Income = 10000,
	SpeedBonus = 0.55,
	Passenger = true,
	Scale = 2.0,
	Category = "Créature Légendaire",
	Description = "Mi-aigle mi-lion, harnaché d'une armure d'or impériale : la monture des souverains.",
	Icon = { top = rgb(170, 110, 30), bottom = rgb(40, 20, 6), glow = rgb(255, 220, 120), motif = rgb(255, 200, 60), yaw = 32, pitch = 12, zoom = 1.05 },
	Animation = { gait = "Quadruped", breathe = 0.035, bob = 0.12, stride = 30, strideRate = 10, tailSway = 16, tailRate = 1.5, headLook = 20, auraSpeed = 0.5 },
	Ability = ABILITY,
	build = build,
}

return Def
