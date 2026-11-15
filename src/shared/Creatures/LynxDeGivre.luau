--!strict
--[[
	LYNX DE GIVRE — Rare · Petit (style cubes + pixels)
	==================================================
	Lynx blanc en cubes, des cristaux de glace sur les oreilles.

	• Épaisse fourrure blanche en pixels, pointes givrées bleu pâle lumineuses, taches grises.
	• Collerette de joues en cubes, queue courte au bout noir.
	• Grandes oreilles en escalier à pinceaux noirs, surmontées de cristaux de glace.
	• Traînées de givre lumineuses sur les flancs, yeux bleu glacier.
	• Flocons de glace en orbite ; effets : neige qui tombe.
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

local ID = "LynxDeGivre"

local ICE = rgb(150, 220, 255)
local P = {
	fur = Cube.skin(rgb(236, 240, 246), Cube.mix(Cube.spots(), Cube.fur(9)), { glow = { ICE }, px = 0.055, dark = rgb(150, 160, 175), light = rgb(255, 255, 255) }),
	ruff = Cube.skin(rgb(246, 248, 252), Cube.fur(7), { glow = { ICE }, px = 0.05, dark = rgb(180, 190, 205) }),
	black = S(rgb(30, 32, 40)),
	inner = S(rgb(240, 200, 210)),
	ice = S(rgb(200, 236, 255), M.Glass, { transparency = 0.25 }),
	iceGlow = S(ICE, M.Neon),
	nose = S(rgb(200, 120, 140)),
	eye = { S(rgb(16, 22, 36)), S(rgb(220, 245, 255), M.Neon), S(ICE, M.Neon), S(rgb(20, 40, 70)) },
}

local ABILITY: Types.Ability = {
	name = "Souffle de givre",
	kind = "Breath",
	colors = { rgb(170, 230, 255), rgb(90, 160, 230), rgb(255, 255, 255) },
	texture = "smoke",
	radius = 5,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local q = Cube.quadruped(rig, {
		body = { c = v3(0, 1.35, 0), size = v3(0.9, 0.76, 1.55), skin = P.fur },
		neck = v3(0, 1.6, -0.72),
		head = { c = v3(0, 1.85, -1.0), size = v3(0.86, 0.74, 0.72), skin = P.fur },
		snout = { size = v3(0.42, 0.26, 0.28), y = -0.16, skin = P.ruff, nose = P.nose },
		eyes = { kind = "slit", size = 0.15, colors = P.eye, x = 0.22, y = 1.93 },
		ears = { w = 0.3, h = 0.46, outer = P.fur.base, inner = P.inner, x = 0.27, z = -0.95, tilt = 6 },
		legs = { x = 0.28, zf = -0.52, zb = 0.52, hipY = 1.05, w = 0.28, skin = P.fur, foot = "paw", footSkin = P.ruff },
		tail = { pts = { v3(0, 1.55, 0.75), v3(0, 1.6, 0.95), v3(0, 1.58, 1.22) }, sizes = { 0.3, 0.26 }, skin = P.fur },
	})
	-- Bout de queue noir, collerette de joues, pinceaux et cristaux sur les oreilles
	rig:block(q.tail[#q.tail], "TailTip", cf(0, 1.58, 1.36), v3(0.2, 0.2, 0.08), P.black)
	rig:mirrored(function(side, sfx)
		Cube.box(rig, "Head", "Ruff", cf(side * 0.48, 1.68, -0.95) * ang(0, 0, -side * rad(18)), v3(0.18, 0.42, 0.5), P.ruff, { faces = { "left", "right", "front" }, chips = false })
		local ear = "Ear" .. sfx
		local tip = cf(side * 0.27, q.headTop - 0.02, -0.95) * ang(0, 0, -side * rad(6)) * cf(0, 0.46, 0)
		rig:block(ear, "Tuft", tip * cf(0, 0.06, 0), v3(0.05, 0.16, 0.05), P.black)
		Cube.crystals(rig, ear, tip * cf(0, 0.02, 0.08), 3, 0.32, { P.ice, P.iceGlow }, 3 + side)
		-- traînées de givre sur les flancs
		Pixel.draw(rig, "Body", Pixel.face(v3(side * 0.45, 1.38, 0.05), v3(side, 0, 0)), 0.05, {
			"C...C....C",
			".C.C.C..C.",
			"..C...CC..",
		}, { C = { P.iceGlow, 0.025 } })
	end)
	-- Flocons de glace en orbite
	local snow = S(rgb(235, 248, 255), M.Neon)
	require(script.Parent.Parent.Anatomy).orbit(rig, "Aura1", v3(0, 1.6, 0.1), 1.5, 5, 0.25, function(bone, c, i)
		local f = c * ang(0, math.pi / 2, 0) * ang(0, 0, rad(i * 30))
		rig:block(bone, "Snowflake", f, v3(0.26, 0.05, 0.03), snow)
		rig:block(bone, "Snowflake", f * ang(0, 0, rad(60)), v3(0.26, 0.05, 0.03), snow)
		rig:block(bone, "Snowflake", f * ang(0, 0, rad(-60)), v3(0.26, 0.05, 0.03), snow)
	end)

	rig:hitbox(cf(0, 1.3, 0.1), v3(1.4, 2.6, 3))
	if rig.effects then
		local sc = rig.scale
		local snowFx = rig:anchor("Root", "FX_Snow", cf(0, 3, 0), v3(2.6, 0.3, 3))
		Fx.particles(snowFx, Fx.sparkles("Snow", { rgb(255, 255, 255), rgb(200, 235, 255) }, 8, 0.12, -0.6), sc)
		local glow = rig:anchor("Head", "FX_EarGlow", cf(0, 2.5, -0.95), v3(0.8, 0.4, 0.3))
		Fx.light(glow, { color = ICE, range = 6, brightness = 1 }, sc)
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Rare")
	end
	return rig:finish({ Rarity = "Rare" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Lynx de givre",
	Rarity = "Rare",
	Size = "Small",
	Income = 50,
	SpeedBonus = 0.12,
	Passenger = false,
	Scale = 1.9,
	Category = "Créature Rare",
	Description = "Lynx blanc des neiges : des cristaux de glace poussent au bout de ses oreilles.",
	Icon = { top = rgb(120, 170, 220), bottom = rgb(20, 34, 56), glow = rgb(210, 240, 255), motif = rgb(170, 230, 255), yaw = 34, pitch = 12, zoom = 1.1 },
	Animation = { flicker = 0, gait = "Quadruped", breathe = 0.025, bob = 0.08, stride = 30, strideRate = 11, tailSway = 12, tailRate = 1.4, headLook = 24, earTwitch = true, auraSpeed = 0.6 },
	Ability = ABILITY,
	build = build,
}

return Def
