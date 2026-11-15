--!strict
--[[
	RENARD DES CENDRES — Commun · Petit (style cubes + pixels)
	=========================================================
	Renard gris en cubes, des braises rougeoient au fond de sa fourrure.

	• Fourrure grise en pixels (mèches sombres et claires) semée de braises lumineuses orange.
	• Plastron et joues gris clair, chaussettes anthracite, marque de braise au front.
	• Grandes oreilles en escalier de voxels, intérieur rose, pointes noires.
	• Grande queue de cubes : gris, puis cendre, puis bout en flammes de cubes lumineux.
	• Effets : braises qui s'envolent, lueur chaude au bout de la queue.
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

local ID = "RenardDesCendres"

local EMBER = { rgb(255, 120, 30), rgb(255, 190, 70), rgb(255, 80, 20) }
local P = {
	fur = Cube.skin(rgb(150, 146, 154), Cube.fur(12), { glow = EMBER, px = 0.06 }),
	pale = Cube.skin(rgb(226, 224, 230), Cube.fur(), { px = 0.05 }),
	ash = Cube.skin(rgb(96, 90, 98), Cube.mix(Cube.fur(7), Cube.stone(0)), { glow = EMBER, px = 0.06 }),
	sock = Cube.skin(rgb(58, 54, 62), Cube.fur(), { px = 0.05 }),
	black = S(rgb(26, 24, 28)),
	inner = S(rgb(232, 168, 160)),
	ember = S(EMBER[1], M.Neon),
	emberHot = S(EMBER[2], M.Neon),
	flameCore = S(rgb(255, 245, 190), M.Neon),
	eye = { S(rgb(30, 14, 10)), S(rgb(255, 230, 160), M.Neon), S(rgb(255, 150, 40), M.Neon), S(rgb(30, 10, 6)) },
}

local ABILITY: Types.Ability = {
	name = "Souffle de cendres",
	kind = "Breath",
	colors = { rgb(255, 140, 40), rgb(255, 60, 20), rgb(255, 240, 160) },
	texture = "fire",
	origin = v3(0, 1.6, -1.82),
	direction = v3(0, -0.05, -1),
}
ABILITY.origin = v3(0, 1.62, -1.85)

local TAIL = {
	v3(0, 1.45, 0.78),
	v3(0, 1.4, 1.05), v3(0, 1.45, 1.5), v3(0.05, 1.6, 1.95), v3(0.1, 1.85, 2.3), v3(0.12, 2.15, 2.5),
	v3(0.12, 2.45, 2.58),
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local q = Cube.quadruped(rig, {
		body = { c = v3(0, 1.3, 0), size = v3(0.86, 0.72, 1.6), skin = P.fur },
		neck = v3(0, 1.55, -0.75),
		head = { c = v3(0, 1.75, -1.05), size = v3(0.84, 0.7, 0.72), skin = P.fur },
		snout = { size = v3(0.4, 0.26, 0.4), y = -0.14, skin = P.pale, nose = P.black },
		eyes = { kind = "slit", size = 0.15, colors = P.eye, x = 0.22, y = 1.84 },
		ears = { w = 0.3, h = 0.44, outer = P.fur.base, inner = P.inner, x = 0.26, z = -1.0, tilt = 10 },
		legs = { x = 0.27, zf = -0.55, zb = 0.55, hipY = 1.0, w = 0.25, skin = P.fur, foot = "paw", footSkin = P.sock },
		tail = { pts = TAIL, sizes = { 0.4, 0.54, 0.6, 0.56, 0.46, 0.36 }, skin = P.fur, skins = { P.fur, P.fur, P.fur, P.ash, P.ash, P.ash } },
	})
	-- Plastron et joues clairs, chaussettes sombres
	Cube.box(rig, "Body", "Chest", cf(0, 1.18, -0.78), v3(0.62, 0.5, 0.08), P.pale, { faces = { "front" }, chips = false })
	Cube.box(rig, "Body", "Belly", cf(0, 0.95, 0), v3(0.6, 0.06, 1.2), P.pale, { faces = {}, chips = false })
	rig:mirrored(function(side, sfx)
		Cube.box(rig, "Head", "Cheek", cf(side * 0.45, 1.6, -1.18), v3(0.12, 0.3, 0.34), P.pale, { faces = { "left", "right", "front" }, chips = false })
		rig:block("Ear" .. sfx, "EarTip", cf(side * 0.26, q.headTop - 0.02, -1.0) * ang(0, 0, -side * rad(10)) * cf(0, 0.39, 0), v3(0.12, 0.1, 0.11), P.black)
		local s = string.sub(sfx, 2)
		for _, key in { "F", "B" } do
			local z = if key == "F" then -0.55 else 0.55
			Cube.box(rig, "Leg_" .. key .. s, "Sock", cf(side * 0.27, 0.3, z), v3(0.27, 0.26, 0.29), P.sock, { chips = false })
		end
	end)
	-- Marque de braise au front
	Pixel.draw(rig, "Head", Pixel.face(v3(0, 2.0, -1.41), v3(0, 0, -1)), 0.045, { ".C.", "CCC", ".C." }, { C = { P.ember, 0.025 } })
	-- Flammes de cubes au bout de la queue
	local tip = TAIL[#TAIL]
	local last = q.tail[#q.tail]
	for k, st in { P.ember, P.emberHot, P.flameCore } do
		local s = 0.3 - k * 0.07
		rig:block(last, "Flame", cf(tip + v3(0, 0.08 + k * 0.14, 0)) * ang(0, rad(k * 25), 0), v3(s, s, s), st)
	end
	-- Braises en orbite
	Cube.orbitGems(rig, "Aura1", v3(0, 1.5, 0.3), 1.5, 4, 0.2, { P.ember, P.emberHot }, nil, 0.1)

	rig:hitbox(cf(0, 1.2, 0.4), v3(1.4, 2.4, 4.4))
	if rig.effects then
		local sc = rig.scale
		local tipFx = rig:anchor(last, "FX_TailFire", cf(tip + v3(0, 0.25, 0)), v3(0.3, 0.3, 0.3))
		Fx.particles(tipFx, Fx.fire("TailFire", { rgb(255, 230, 120), rgb(255, 110, 30), rgb(120, 20, 10) }, 18, 0.4), sc)
		Fx.light(tipFx, { color = rgb(255, 140, 50), range = 7, brightness = 1.4 }, sc)
		local body = rig:anchor("Body", "FX_Embers", cf(0, 1.5, 0.2), v3(0.9, 0.6, 1.8))
		Fx.particles(body, Fx.embers("Embers", { rgb(255, 220, 120), rgb(255, 100, 30) }, 6, 0.16), sc)
		Vfx.trail(rig, last, tip + v3(0, 0.3, 0), tip + v3(0, 0.05, 0), { colors = { rgb(255, 210, 90), rgb(255, 70, 20) }, lifetime = 0.5 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Common")
	end
	return rig:finish({ Rarity = "Common" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Renard des cendres",
	Rarity = "Common",
	Size = "Small",
	Income = 5,
	SpeedBonus = 0.05,
	Passenger = false,
	Scale = 1.35,
	Category = "Créature Commune",
	Description = "Renard gris des cendres : des braises rougeoient au fond de sa fourrure et le bout de sa queue brûle encore.",
	Icon = { top = rgb(90, 70, 70), bottom = rgb(24, 18, 20), glow = rgb(255, 140, 60), motif = rgb(255, 120, 40), yaw = 34, pitch = 14, zoom = 1.1 },
	Animation = { flicker = 0.3, gait = "Quadruped", breathe = 0.03, bob = 0.12, stride = 32, strideRate = 12, tailSway = 14, tailRate = 1.8, headLook = 22, sniff = true, earTwitch = true },
	Ability = ABILITY,
	build = build,
}

return Def
