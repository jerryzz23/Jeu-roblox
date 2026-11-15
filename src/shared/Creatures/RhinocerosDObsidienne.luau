--!strict
--[[
	RHINOCÉROS D'OBSIDIENNE — Légendaire · Géant (style cubes + pixels)
	==================================================================
	Rhinocéros en cubes de pierre volcanique noire et brillante.

	• Corps massif en plaques d'obsidienne (reflets violets) fendues de lave orange lumineuse.
	• Énorme corne d'obsidienne en cubes cerclée de lave, seconde corne plus petite.
	• Épaulières en lames d'obsidienne, pattes-colonnes aux sabots de basalte.
	• Petites oreilles, yeux orange ; selle de basalte pour deux cavaliers.
	• Éclats d'obsidienne et braises en orbite ; effets : fumée, braises, lueur de lave.
]]

local Kit = require(script.Parent.Parent.Kit)
local Fx = require(script.Parent.Parent.Fx)
local Vfx = require(script.Parent.Parent.Vfx)
local Types = require(script.Parent.Parent.Types)
local Cube = require(script.Parent.Parent.Cube)

local S = Kit.style
local M = Enum.Material
local rgb = Color3.fromRGB
local rad = math.rad
local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles

local ID = "RhinocerosDObsidienne"

local LAVA = { rgb(255, 120, 20), rgb(255, 210, 90) }
local P = {
	obsidian = Cube.skin(rgb(36, 30, 48), Cube.mix(Cube.lava(), Cube.plates(8, 5)), { glow = LAVA, px = 0.08, light = rgb(96, 70, 130) }),
	basalt = Cube.skin(rgb(60, 56, 62), Cube.stone(), { material = M.Basalt, glow = LAVA, px = 0.075 }),
	glass = S(rgb(50, 36, 70), M.Glass, { transparency = 0.1 }),
	lava = S(LAVA[1], M.Neon),
	lavaHot = S(LAVA[2], M.Neon),
	eye = { S(rgb(10, 6, 4)), S(rgb(255, 200, 120), M.Neon), S(LAVA[1], M.Neon), S(rgb(40, 10, 2)) },
}

local ABILITY: Types.Ability = {
	name = "Charge volcanique",
	kind = "Stomp",
	colors = { rgb(255, 130, 30), rgb(60, 20, 10), rgb(255, 220, 120) },
	texture = "fire",
	radius = 8,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local q = Cube.quadruped(rig, {
		body = { c = v3(0, 2.3, 0), size = v3(1.9, 1.6, 3.0), skin = P.obsidian },
		neck = v3(0, 2.3, -1.5),
		head = { c = v3(0, 2.15, -2.05), size = v3(1.15, 1.0, 1.2), skin = P.obsidian },
		snout = { size = v3(0.9, 0.62, 0.5), y = -0.18, skin = P.obsidian },
		eyes = { kind = "square", size = 0.15, colors = P.eye, side = true, x = 0, y = 2.3, z = -2.25 },
		ears = { w = 0.24, h = 0.24, outer = P.obsidian.base, inner = P.lava, x = 0.4, z = -1.62, tilt = 25 },
		legs = { x = 0.66, zf = -1.0, zb = 1.0, hipY = 1.6, w = 0.6, skin = P.obsidian, foot = "hoof", footSkin = P.basalt, toe = P.basalt.base, footH = 0.24 },
		tail = { pts = { v3(0, 2.6, 1.5), v3(0, 2.35, 1.62), v3(0, 2.1, 1.7) }, sizes = { 0.18, 0.16 }, skin = P.obsidian },
	})
	-- Corne principale d'obsidienne cerclée de lave, seconde corne
	local front = q.snoutFront or v3(0, 2.0, -2.9)
	Cube.horn(rig, "Head", v3(0, 2.2, front.Z + 0.25), v3(0, 0.9, -0.35), { 0.42, 0.34, 0.26, 0.18 }, P.glass, P.lava, P.lavaHot)
	Cube.horn(rig, "Head", v3(0, 2.62, -2.2), v3(0, 0.95, -0.2), { 0.26, 0.2, 0.14 }, P.glass, P.lava, nil)
	-- Épaulières en lames d'obsidienne
	rig:mirrored(function(side)
		for k = 0, 2 do
			rig:block("Body", "Blade", cf(side * 0.98, 2.6 + k * 0.15, -0.9 + k * 0.28) * ang(rad(-30), side * rad(20), side * rad(-35)), v3(0.12, 0.6 - k * 0.12, 0.36), P.glass)
		end
	end)
	-- Selle de basalte pour deux cavaliers
	Cube.box(rig, "Body", "Saddle", cf(0, 3.18, 0.2), v3(1.1, 0.18, 1.5), P.basalt, { chips = false })
	-- Éclats d'obsidienne et braises en orbite
	Cube.orbitGems(rig, "Aura1", v3(0, 2.5, 0), 3.0, 7, 0.5, { P.glass, P.lava, P.glass, P.lavaHot }, nil, 0.24)

	rig:hitbox(cf(0, 2.2, -0.3), v3(2.6, 4.4, 5.6))
	if rig.effects then
		local sc = rig.scale
		local smoke = rig:anchor("Body", "FX_Smoke", cf(0, 3.2, 0), v3(1.6, 0.4, 2.6))
		Fx.particles(smoke, Fx.mist("Smoke", { rgb(80, 70, 70), rgb(40, 34, 36) }, 4, 1.2, 0.1), sc)
		Fx.particles(smoke, Fx.embers("Embers", { rgb(255, 210, 100), LAVA[1] }, 8, 0.18), sc)
		Fx.light(smoke, { color = LAVA[1], range = 12, brightness = 1.5 }, sc)
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
