--!strict
--[[
	OURS DE GRANIT — Rare · Grand (style cubes + pixels)
	===================================================
	Ours en cubes dont le dos est couvert de roche.

	• Épaisse fourrure brun-gris en pixels, museau clair, griffes d'ivoire.
	• Dos couvert de dalles de granit moucheté empilées, hérissé de quartz bleu clair lumineux.
	• Épaulières et brassards de pierre gravés, veines de quartz.
	• Pierres levées en orbite ; selle naturelle entre les rochers pour un passager.
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

local ID = "OursDeGranit"

local QUARTZ = rgb(170, 225, 255)
local P = {
	fur = Cube.skin(rgb(112, 98, 86), Cube.fur(), { px = 0.07 }),
	muzzle = Cube.skin(rgb(200, 184, 162), Cube.fur(), { px = 0.06 }),
	granite = Cube.skin(rgb(150, 146, 142), Cube.stone(), { material = M.Slate, glow = { QUARTZ }, px = 0.075 }),
	graniteDark = Cube.skin(rgb(108, 104, 102), Cube.mix(Cube.runes(), Cube.stone(0)), { material = M.Slate, glow = { QUARTZ }, px = 0.07 }),
	ivory = S(rgb(240, 232, 210)),
	quartz = S(rgb(200, 236, 255), M.Glass, { transparency = 0.2 }),
	quartzGlow = S(QUARTZ, M.Neon),
	nose = S(rgb(28, 22, 20)),
	eye = { S(rgb(14, 10, 8)), S(rgb(60, 40, 26)), S(rgb(28, 18, 12)), S(rgb(240, 230, 210), M.Neon) },
}

local ABILITY: Types.Ability = {
	name = "Avalanche de granit",
	kind = "Stomp",
	colors = { rgb(180, 172, 166), rgb(120, 116, 112), rgb(200, 236, 255) },
	texture = "spark",
	radius = 7,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local q = Cube.quadruped(rig, {
		body = { c = v3(0, 2.0, 0), size = v3(1.6, 1.3, 2.4), skin = P.fur },
		neck = v3(0, 2.2, -1.1),
		head = { c = v3(0, 2.35, -1.55), size = v3(1.1, 0.95, 0.9), skin = P.fur },
		snout = { size = v3(0.56, 0.4, 0.42), y = -0.2, skin = P.muzzle, nose = P.nose },
		jaw = true,
		eyes = { kind = "square", size = 0.15, colors = P.eye, x = 0.28, y = 2.5 },
		ears = { w = 0.3, h = 0.24, outer = P.fur.base, inner = P.fur.dark, x = 0.42, z = -1.5, tilt = 10 },
		legs = { x = 0.52, zf = -0.8, zb = 0.8, hipY = 1.5, w = 0.5, skin = P.fur, foot = "claw", toe = P.ivory, footH = 0.2 },
		tail = { pts = { v3(0, 2.1, 1.2), v3(0, 2.05, 1.32), v3(0, 2.0, 1.45) }, sizes = { 0.26, 0.2 }, skin = P.fur },
	})
	-- Dalles de granit empilées sur le dos, hérissées de quartz (selle entre les rochers)
	local slabs = {
		{ v3(0, 2.75, -0.75), v3(1.2, 0.3, 0.7) }, { v3(0.12, 2.82, 0.75), v3(1.1, 0.36, 0.75) },
		{ v3(-0.3, 2.95, -0.85), v3(0.5, 0.3, 0.45) }, { v3(0.35, 3.0, 0.9), v3(0.45, 0.32, 0.4) },
	}
	for k, sl in slabs do
		Cube.box(rig, "Body", "Slab", cf(sl[1]) * ang(0, rad(k * 7 - 10), rad(k % 2 * 4 - 2)), sl[2], if k % 2 == 0 then P.granite else P.graniteDark)
	end
	Cube.crystals(rig, "Body", cf(-0.35, 3.1, 0.85), 4, 0.6, { P.quartz, P.quartzGlow }, 4)
	Cube.crystals(rig, "Body", cf(0.4, 2.95, -0.9), 3, 0.45, { P.quartz, P.quartzGlow }, 5)
	-- Épaulières et brassards de pierre
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		Cube.box(rig, "Leg_F" .. s, "Pauldron", cf(side * 0.6, 1.62, -0.8) * ang(0, 0, -side * rad(10)), v3(0.62, 0.36, 0.66), P.graniteDark)
		for key, z in { F = -0.8, B = 0.8 } do
			Cube.box(rig, "Leg_" .. key .. s, "Bracer", cf(side * 0.52, 0.48, z), v3(0.56, 0.3, 0.58), P.granite, { chips = false })
		end
	end)
	-- Pierres levées en orbite
	require(script.Parent.Parent.Anatomy).orbit(rig, "Aura1", v3(0, 2.3, 0.1), 2.3, 5, 0.5, function(bone, c, i)
		Cube.box(rig, bone, "Boulder", c * ang(rad(i * 31), rad(i * 17), 0), v3(0.3, 0.26, 0.28), P.granite, { px = 0.05, chips = false })
	end)

	rig:hitbox(cf(0, 1.9, 0), v3(2.2, 3.6, 4))
	if rig.effects then
		local sc = rig.scale
		local qz = rig:anchor("Body", "FX_Quartz", cf(0, 3.1, 0), v3(1.2, 0.4, 2.0))
		Fx.particles(qz, Fx.sparkles("QuartzGlint", { rgb(255, 255, 255), QUARTZ }, 4, 0.18, 0.1), sc)
		Fx.light(qz, { color = QUARTZ, range = 8, brightness = 1 }, sc)
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Rare")
	end
	return rig:finish({ Rarity = "Rare" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Ours de granit",
	Rarity = "Rare",
	Size = "Large",
	Income = 140,
	SpeedBonus = 0.16,
	Passenger = true,
	Scale = 2.75,
	Category = "Créature Rare",
	Description = "Ours massif dont le dos n'est plus qu'un amas de dalles de granit hérissé de quartz.",
	Icon = { top = rgb(90, 96, 110), bottom = rgb(20, 20, 26), glow = rgb(170, 220, 255), motif = rgb(200, 190, 180), yaw = 36, pitch = 16, zoom = 1.1 },
	Animation = { gait = "Quadruped", breathe = 0.05, bob = 0.1, stride = 24, strideRate = 7, tailSway = 4, tailRate = 2, headLook = 16, sniff = true, earTwitch = true, auraSpeed = 0.45 },
	Ability = ABILITY,
	build = build,
}

return Def
