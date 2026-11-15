--!strict
--[[
	FAUCON SOLAIRE — Épique · Petit (style cubes + pixels)
	=====================================================
	Faucon en cubes aux plumes dorées qui laissent une traînée de lumière.

	• Plumage d'or en pixels de plumes (crème -> or -> ambre), plastron crème.
	• Ailes en plumes-planches étagées, pointes en cristaux de soleil lumineux.
	• Masque ambré, bec crochu et serres d'or, yeux blanc solaire, petite huppe.
	• Effets : traînées de lumière dorée au bout des ailes, poussière de soleil.
]]

local Kit = require(script.Parent.Parent.Kit)
local Fx = require(script.Parent.Parent.Fx)
local Vfx = require(script.Parent.Parent.Vfx)
local Types = require(script.Parent.Parent.Types)
local Cube = require(script.Parent.Parent.Cube)
local Pixel = require(script.Parent.Parent.Pixel)

local S = Kit.style
local M = Enum.Material
local rgb = Color3.fromRGB
local rad = math.rad
local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles

local ID = "FauconSolaire"

local SUN = rgb(255, 214, 90)
local P = {
	gold = Cube.skin(rgb(236, 180, 64), Cube.feathers(19), { glow = { SUN }, px = 0.05 }),
	cream = Cube.skin(rgb(250, 236, 196), Cube.feathers(), { px = 0.045 }),
	amber = Cube.skin(rgb(200, 120, 30), Cube.feathers(), { px = 0.045 }),
	beak = S(rgb(255, 200, 60), M.Metal),
	beakDark = S(rgb(170, 110, 20), M.Metal),
	talon = S(rgb(60, 40, 20)),
	sun = S(SUN, M.Neon),
	sunHot = S(rgb(255, 250, 220), M.Neon),
	eye = { S(rgb(40, 20, 6)), S(rgb(255, 255, 240), M.Neon), S(rgb(255, 230, 140), M.Neon), S(rgb(60, 30, 6)) },
}

local ABILITY: Types.Ability = {
	name = "Éclat solaire",
	kind = "Burst",
	colors = { rgb(255, 220, 110), rgb(255, 160, 40), rgb(255, 255, 230) },
	texture = "sparkle",
	radius = 6,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	rig:bone("Body", "Root", cf(0, 1.5, 0))
	rig:bone("Head", "Body", cf(0, 1.75, -0.45))
	rig:bone("Tail1", "Body", cf(0, 1.42, 0.5))
	rig:mirrored(function(side, sfx)
		rig:bone("Wing" .. sfx, "Body", cf(side * 0.3, 1.66, -0.22))
		rig:bone("Leg" .. sfx, "Body", cf(side * 0.15, 1.22, 0.05))
	end)
	-- Corps et plastron
	Cube.box(rig, "Body", "Body", cf(0, 1.5, 0), v3(0.62, 0.6, 1.0), P.gold)
	Cube.box(rig, "Body", "Chest", cf(0, 1.4, -0.51), v3(0.5, 0.46, 0.06), P.cream, { faces = { "front" }, chips = false })
	-- Tête : masque ambré, bec crochu, yeux, huppe
	local hc = v3(0, 1.98, -0.62)
	Cube.box(rig, "Head", "Head", cf(hc), v3(0.54, 0.5, 0.54), P.gold)
	Cube.box(rig, "Head", "Mask", cf(hc + v3(0, 0.04, -0.2)), v3(0.56, 0.14, 0.18), P.amber, { faces = { "front", "left", "right" }, chips = false })
	rig:block("Head", "Beak", cf(hc + v3(0, -0.06, -0.36)), v3(0.18, 0.16, 0.2), P.beak)
	rig:block("Head", "BeakTip", cf(hc + v3(0, -0.15, -0.45)), v3(0.12, 0.12, 0.1), P.beakDark)
	rig:mirrored(function(side)
		Cube.eye(rig, "Head", v3(side * 0.27, hc.Y + 0.05, hc.Z - 0.08), v3(side, 0, 0), 0.12, "square", P.eye)
	end)
	for k = -1, 1 do
		rig:block("Head", "Crest", cf(hc + v3(k * 0.1, 0.3, 0.12)) * ang(rad(-35), 0, rad(k * 15)), v3(0.08, 0.04, 0.32), if k == 0 then P.sun else P.gold.base)
	end
	-- Ailes en plumes-planches, pointes en cristaux de soleil
	rig:mirrored(function(side, sfx)
		local w = "Wing" .. sfx
		local root = v3(side * 0.3, 1.66, -0.25)
		local out = v3(side, 0.12, 0).Unit
		Cube.featherWing(rig, w, root, out, v3(0, 0, 1), 1.5, 0.72, 6, { P.cream.base, P.gold.base, P.amber.base }, P.sun)
		local tip = root + out * 1.5
		rig:block(w, "SunCrystal", cf(tip + v3(0, 0.02, 0.3)) * ang(rad(45), 0, rad(45)), v3(0.14, 0.14, 0.14), P.sunHot)
	end)
	-- Queue en éventail
	for k = -1, 1 do
		rig:block("Tail1", "TailFeather", cf(k * 0.14, 1.38, 0.85) * ang(rad(12), rad(k * 18), 0), v3(0.16, 0.05, 0.66), if k == 0 then P.amber.base else P.gold.base)
		rig:block("Tail1", "TailTip", cf(k * 0.14, 1.33, 1.17) * ang(rad(12), rad(k * 18), 0), v3(0.16, 0.06, 0.08), P.sun)
	end
	-- Pattes et serres d'or
	rig:mirrored(function(side, sfx)
		local leg = "Leg" .. sfx
		local x = side * 0.15
		rig:joint(leg, v3(x, 1.22, 0.05), v3(x, 0.98, 0.05))
		Cube.box(rig, leg, "Thigh", cf(x, 1.1, 0.05), v3(0.16, 0.26, 0.16), P.gold, { chips = false })
		rig:block(leg, "Shin", cf(x, 0.85, 0.05), v3(0.08, 0.26, 0.08), P.beak)
		for t = -1, 1 do
			rig:block(leg, "Talon", cf(x + t * 0.05, 0.71, -0.02), v3(0.04, 0.04, 0.12), P.talon)
		end
	end)
	-- Cristaux de soleil en orbite
	Cube.orbitGems(rig, "Aura1", v3(0, 1.6, 0), 2.0, 6, 0.3, { P.sun, P.sunHot }, nil, 0.14)

	rig:hitbox(cf(0, 1.5, 0.1), v3(3.4, 1.4, 2))
	if rig.effects then
		local sc = rig.scale
		local dust = rig:anchor("Body", "FX_SunDust", cf(0, 1.6, 0), v3(2.4, 0.5, 1.2))
		Fx.particles(dust, Fx.sparkles("SunDust", { rgb(255, 240, 180), SUN }, 10, 0.16, 0.1), sc)
		Fx.light(dust, { color = SUN, range = 8, brightness = 1.4 }, sc)
		rig:mirrored(function(side, sfx)
			local tip = v3(side * 1.78, 1.84, 0.05)
			Vfx.trail(rig, "Wing" .. sfx, tip + v3(0, 0, -0.2), tip + v3(0, 0, 0.3), { colors = { rgb(255, 230, 140), rgb(255, 150, 40) }, lifetime = 0.45 })
		end)
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
