--!strict
--[[
	TIGRE DE JADE — Épique · Moyen (style cubes + pixels)
	====================================================
	Tigre sculpté en cubes de jade, aux rayures lumineuses.

	• Corps en cubes de jade (matériau Marble) gravés de facettes, vert profond -> vert d'eau.
	• Rayures vert lumineux ondulées en pixels sur les flancs, la tête, les pattes et la queue.
	• Museau et ventre vert d'eau, collier d'or impérial serti de jade, yeux d'or.
	• Pièces de jade cerclées d'or en orbite ; effets : lueurs vertes, poussière d'or.
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

local ID = "TigreDeJade"

local GLOW = rgb(110, 255, 160)
local P = {
	jade = Cube.skin(rgb(40, 132, 86), Cube.mix(Cube.stripes(6, true), Cube.crystal(0)), { material = M.Marble, glow = { GLOW }, px = 0.06 }),
	pale = Cube.skin(rgb(150, 214, 180), Cube.crystal(0), { material = M.Marble, px = 0.05 }),
	gold = Cube.skin(rgb(240, 196, 70), Cube.plates(5, 3), { material = M.Metal, px = 0.04 }),
	jadeGem = S(rgb(60, 200, 120), M.Glass, { transparency = 0.1 }),
	glow = S(GLOW, M.Neon),
	nose = S(rgb(20, 60, 40)),
	eye = { S(rgb(10, 30, 18)), S(rgb(255, 236, 150), M.Neon), S(rgb(255, 200, 40), M.Neon), S(rgb(30, 20, 4)) },
}

local ABILITY: Types.Ability = {
	name = "Rugissement de jade",
	kind = "Nova",
	colors = { rgb(120, 255, 170), rgb(30, 120, 70), rgb(255, 220, 100) },
	texture = "smoke",
	radius = 5,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local tail = { v3(0, 1.75, 1.05), v3(0, 1.72, 1.45), v3(0, 1.62, 1.9), v3(0.05, 1.6, 2.35), v3(0.1, 1.72, 2.75), v3(0.12, 1.95, 3.05) }
	local q = Cube.quadruped(rig, {
		body = { c = v3(0, 1.65, 0), size = v3(1.0, 0.82, 2.1), skin = P.jade },
		neck = v3(0, 1.9, -0.95),
		head = { c = v3(0, 2.08, -1.32), size = v3(0.9, 0.76, 0.78), skin = P.jade },
		snout = { size = v3(0.52, 0.3, 0.3), y = -0.18, skin = P.pale, nose = P.nose },
		jaw = true,
		eyes = { kind = "slit", size = 0.16, colors = P.eye, x = 0.24, y = 2.18 },
		ears = { w = 0.26, h = 0.22, outer = P.jade.base, inner = P.pale.base, x = 0.33, z = -1.25, tilt = 8 },
		legs = { x = 0.33, zf = -0.72, zb = 0.72, hipY = 1.3, w = 0.3, skin = P.jade, foot = "paw", footSkin = P.pale },
		tail = { pts = tail, sizes = { 0.26, 0.26, 0.24, 0.22, 0.2 }, skin = P.jade },
	})
	Cube.box(rig, "Body", "Belly", cf(0, 1.22, 0), v3(0.76, 0.06, 1.6), P.pale, { faces = { "bottom" }, chips = false })
	-- Collier d'or serti de jade
	Cube.box(rig, "Head", "Collar", cf(0, 1.78, -0.98) * ang(rad(-18), 0, 0), v3(0.92, 0.16, 0.62), P.gold, { faces = { "front", "left", "right" }, chips = false })
	for k = -1, 1 do
		rig:block("Head", "CollarJade", cf(k * 0.28, 1.72, -1.3) * ang(0, 0, rad(45)), v3(0.12, 0.12, 0.06), P.jadeGem)
	end
	rig:block(q.tail[#q.tail], "TailTip", cf(tail[#tail]), v3(0.2, 0.2, 0.2), P.glow)
	-- Pièces de jade cerclées d'or en orbite
	A.orbit(rig, "Aura1", v3(0, 1.9, 0.2), 1.9, 5, 0.3, function(bone, c, i)
		local f = c * ang(0, math.pi / 2, 0)
		rig:cylinder(bone, "CoinRim", (f * cf(0, 0, -0.03)).Position, (f * cf(0, 0, 0.03)).Position, 0.34, P.gold.base)
		rig:cylinder(bone, "Coin", (f * cf(0, 0, -0.04)).Position, (f * cf(0, 0, 0.04)).Position, 0.24, P.jadeGem)
		rig:block(bone, "CoinHole", f, v3(0.07, 0.07, 0.1), P.glow)
	end)

	rig:hitbox(cf(0, 1.5, 0.5), v3(1.6, 3, 4.6))
	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Body", "FX_JadeGlow", cf(0, 1.8, 0), v3(1.1, 0.8, 2.0))
		Fx.particles(g, Fx.sparkles("GoldDust", { rgb(255, 230, 140), GLOW }, 6, 0.16, 0.15), sc)
		Fx.light(g, { color = GLOW, range = 9, brightness = 1.2 }, sc)
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Epic")
	end
	return rig:finish({ Rarity = "Epic" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Tigre de jade",
	Rarity = "Epic",
	Size = "Medium",
	Income = 900,
	SpeedBonus = 0.28,
	Passenger = false,
	Scale = 2.5,
	Category = "Créature Épique",
	Description = "Tigre sculpté dans le jade : ses rayures s'illuminent d'un vert profond quand il rugit.",
	Icon = { top = rgb(30, 110, 70), bottom = rgb(6, 26, 16), glow = rgb(140, 255, 180), motif = rgb(255, 210, 80), yaw = 34, pitch = 12, zoom = 1.1 },
	Animation = { flicker = 0, gait = "Quadruped", breathe = 0.025, bob = 0.08, stride = 30, strideRate = 11, tailSway = 12, tailRate = 1.4, headLook = 24, earTwitch = true, auraSpeed = 0.6 },
	Ability = ABILITY,
	build = build,
}

return Def
