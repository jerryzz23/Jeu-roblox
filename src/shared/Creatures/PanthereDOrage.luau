--!strict
--[[
	PANTHÈRE D'ORAGE — Rare · Moyen (style cubes + pixels)
	=====================================================
	Panthère noire en cubes parcourue de petits éclairs.

	• Pelage noir lustré en fines écailles de pixels, reflets bleu nuit.
	• Éclairs bleu électrique en zigzag (pixels lumineux) sur les flancs et les pattes.
	• Yeux jaune orage, collier d'argent à gemme bleue, bout de queue chargé d'électricité.
	• Orbes d'orage en orbite ; effets : étincelles, lueur bleue.
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

local ID = "PanthereDOrage"

local BOLT = rgb(110, 190, 255)
local P = {
	coat = Cube.skin(rgb(30, 30, 44), Cube.scales(17, 3, 2), { glow = { BOLT }, px = 0.055, dark = rgb(16, 16, 26), light = rgb(64, 76, 120) }),
	silver = S(rgb(220, 226, 238), M.Metal),
	gem = S(rgb(60, 140, 255), M.Neon),
	bolt = S(BOLT, M.Neon),
	boltHot = S(rgb(230, 245, 255), M.Neon),
	nose = S(rgb(12, 12, 18)),
	inner = S(rgb(70, 50, 80)),
	eye = { S(rgb(10, 10, 14)), S(rgb(255, 240, 120), M.Neon), S(rgb(255, 210, 40), M.Neon), S(rgb(20, 16, 6)) },
}

local ABILITY: Types.Ability = {
	name = "Bond foudroyant",
	kind = "Burst",
	colors = { rgb(140, 210, 255), rgb(40, 80, 200), rgb(255, 255, 255) },
	texture = "smoke",
	radius = 5,
}

local BOLT_ROWS = {
	"...CC.......CC....",
	"..CC.......CC.....",
	".CCCCC....CCCCC...",
	"....CC.......CC...",
	"...CC.......CC....",
	"..C........C......",
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local tail = {
		v3(0, 1.62, 1.0), v3(0, 1.58, 1.35), v3(0, 1.45, 1.8), v3(0.05, 1.35, 2.25), v3(0.1, 1.38, 2.7), v3(0.12, 1.55, 3.05),
	}
	local q = Cube.quadruped(rig, {
		body = { c = v3(0, 1.55, 0), size = v3(0.92, 0.76, 2.0), skin = P.coat },
		neck = v3(0, 1.8, -0.9),
		head = { c = v3(0, 1.98, -1.22), size = v3(0.8, 0.66, 0.72), skin = P.coat },
		snout = { size = v3(0.44, 0.26, 0.3), y = -0.14, skin = P.coat, nose = P.nose },
		eyes = { kind = "slit", size = 0.15, colors = P.eye, x = 0.21, y = 2.06 },
		ears = { w = 0.26, h = 0.26, outer = P.coat.base, inner = P.inner, x = 0.27, z = -1.15, tilt = 14 },
		legs = { x = 0.3, zf = -0.7, zb = 0.7, hipY = 1.22, w = 0.27, skin = P.coat, foot = "paw" },
		tail = { pts = tail, sizes = { 0.24, 0.24, 0.22, 0.2, 0.18 }, skin = P.coat },
	})
	-- Éclairs sur les flancs et les pattes
	rig:mirrored(function(side, sfx)
		local rows = BOLT_ROWS
		if side < 0 then
			rows = {}
			for _, r in BOLT_ROWS do
				table.insert(rows, string.reverse(r))
			end
		end
		Pixel.draw(rig, "Body", Pixel.face(v3(side * 0.46, 1.55, 0.05), v3(side, 0, 0)), 0.07, rows, { C = { P.bolt, 0.028 } })
		local s = string.sub(sfx, 2)
		for key, z in { F = -0.7, B = 0.7 } do
			Pixel.draw(rig, "Leg_" .. key .. s, Pixel.face(v3(side * 0.3 + side * 0.136, 0.45, z), v3(side, 0, 0)), 0.045, { ".C", "C.", ".C", "C." }, { C = { P.bolt, 0.025 } })
		end
	end)
	-- Collier d'argent à gemme bleue
	Cube.box(rig, "Head", "Collar", cf(0, 1.68, -0.92) * ang(rad(-15), 0, 0), v3(0.86, 0.12, 0.6), Cube.skin(rgb(200, 206, 220), Cube.plates(5, 3), { material = M.Metal, px = 0.04 }), { faces = { "front", "left", "right" }, chips = false })
	rig:block("Head", "CollarGem", cf(0, 1.62, -1.24) * ang(0, 0, rad(45)), v3(0.13, 0.13, 0.08), P.gem)
	-- Bout de queue chargé d'électricité
	local tipP = tail[#tail]
	rig:block(q.tail[#q.tail], "TailCharge", cf(tipP) * ang(rad(45), rad(45), 0), v3(0.24, 0.24, 0.24), P.boltHot)
	-- Orbes d'orage en orbite
	Cube.orbitGems(rig, "Aura1", v3(0, 1.8, 0.2), 1.8, 4, 0.3, { P.bolt }, { S(BOLT, M.Glass, { transparency = 0.5 }) }, 0.16)

	rig:hitbox(cf(0, 1.4, 0.5), v3(1.5, 2.8, 4.6))
	if rig.effects then
		local sc = rig.scale
		local spark = rig:anchor("Body", "FX_Sparks", cf(0, 1.6, 0), v3(1.0, 0.8, 2.0))
		Fx.particles(spark, Fx.sparkles("Sparks", { rgb(230, 245, 255), BOLT }, 8, 0.16, 0.2), sc)
		Fx.light(spark, { color = BOLT, range = 8, brightness = 1.2 }, sc)
		local tipFx = rig:anchor(q.tail[#q.tail], "FX_TailCharge", cf(tipP), v3(0.3, 0.3, 0.3))
		Fx.particles(tipFx, Fx.sparkles("Charge", { rgb(255, 255, 255), BOLT }, 10, 0.2, 0), sc)
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Rare")
	end
	return rig:finish({ Rarity = "Rare" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Panthère d'orage",
	Rarity = "Rare",
	Size = "Medium",
	Income = 90,
	SpeedBonus = 0.15,
	Passenger = false,
	Scale = 1.75,
	Category = "Créature Rare",
	Description = "Panthère noire chargée d'orage : de petits éclairs courent sur son pelage quand elle bondit.",
	Icon = { top = rgb(30, 50, 100), bottom = rgb(6, 8, 16), glow = rgb(140, 210, 255), motif = rgb(255, 230, 60), yaw = 34, pitch = 12, zoom = 1.1 },
	Animation = { flicker = 0.35, gait = "Quadruped", breathe = 0.025, bob = 0.08, stride = 30, strideRate = 11, tailSway = 12, tailRate = 1.4, headLook = 24, earTwitch = true, auraSpeed = 0.6 },
	Ability = ABILITY,
	build = build,
}

return Def
