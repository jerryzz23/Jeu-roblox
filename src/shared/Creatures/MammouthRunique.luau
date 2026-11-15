--!strict
--[[
	MAMMOUTH RUNIQUE — Épique · Géant (style cubes + pixels)
	=======================================================
	Mammouth en cubes aux défenses gravées de runes bleues.

	• Énorme corps en laine brune (pixels de mèches), franges de laine qui pendent sous le ventre.
	• Pattes-colonnes cerclées d'anneaux de pierre sculptée gravés de runes.
	• Immenses défenses d'ivoire courbes en cubes, gravées de runes bleues lumineuses, bandes néon.
	• Trompe en cubes qui se balance, grandes oreilles, dôme laineux.
	• Nacelle de pierre sur le dos : quatre menhirs runiques couronnés de cristaux, cristal central.
	• Pierres runiques en orbite ; effets : brume bleue au sommet des menhirs, étincelles runiques.
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

local ID = "MammouthRunique"

local RUNE = rgb(90, 190, 255)
local P = {
	wool = Cube.skin(rgb(120, 82, 56), Cube.fur(), { px = 0.09 }),
	woolDark = Cube.skin(rgb(84, 56, 38), Cube.fur(), { px = 0.08 }),
	stone = Cube.skin(rgb(140, 138, 132), Cube.runes(Cube.stone(0)), { material = M.Slate, glow = { RUNE }, px = 0.08 }),
	ivory = Cube.skin(rgb(240, 232, 208), Cube.runes(), { glow = { RUNE }, px = 0.06, chips = false }),
	rune = S(RUNE, M.Neon),
	crystal = S(rgb(170, 220, 255), M.Glass, { transparency = 0.2 }),
	brass = S(rgb(200, 160, 80), M.Metal),
	eye = { S(rgb(16, 10, 6)), S(rgb(70, 50, 30)), S(rgb(30, 20, 12)), S(rgb(230, 220, 200), M.Neon) },
}

local ABILITY: Types.Ability = {
	name = "Charge runique",
	kind = "Stomp",
	colors = { rgb(90, 190, 255), rgb(40, 90, 200), rgb(220, 240, 255) },
	texture = "spark",
	radius = 9,
	duration = 1.8,
}

local TRUNK = { v3(0, 2.75, -2.55), v3(0, 2.2, -2.7), v3(0, 1.65, -2.72), v3(0, 1.15, -2.6), v3(0, 0.75, -2.38) }

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local q = Cube.quadruped(rig, {
		body = { c = v3(0, 3.0, 0), size = v3(2.1, 1.9, 3.1), skin = P.wool },
		neck = v3(0, 3.2, -1.5),
		head = { c = v3(0, 3.45, -2.0), size = v3(1.35, 1.35, 1.0), skin = P.wool },
		eyes = { kind = "square", size = 0.16, colors = P.eye, side = true, x = 0, y = 3.55, z = -2.25 },
		legs = { x = 0.7, zf = -1.0, zb = 1.0, hipY = 2.3, w = 0.72, skin = P.woolDark, foot = "hoof", toe = P.stone.base, footH = 0.24 },
		tail = { pts = { v3(0, 3.2, 1.55), v3(0, 2.9, 1.75), v3(0, 2.5, 1.85) }, sizes = { 0.24, 0.2 }, skin = P.woolDark },
	})
	-- Dôme laineux, grandes oreilles (os Ear), franges de laine sous le ventre
	Cube.box(rig, "Head", "Dome", cf(0, 4.25, -1.85), v3(1.1, 0.4, 0.8), P.wool)
	rig:mirrored(function(side, sfx)
		rig:bone("Ear" .. sfx, "Head", cf(side * 0.68, 3.6, -1.85))
		Cube.box(rig, "Ear" .. sfx, "Ear", cf(side * 0.74, 3.5, -1.8) * ang(0, side * rad(-20), 0), v3(0.12, 0.7, 0.6), P.woolDark, { faces = { "left", "right" } })
		for k = 0, 6 do
			local z = -1.3 + k * 0.42
			local h = 0.45 + ((k * 7) % 3) * 0.12
			Cube.box(rig, "Body", "Fringe", cf(side * 0.95, 2.05 - h / 2 + 0.05, z), v3(0.22, h, 0.36), P.woolDark, { faces = { "left", "right", "front" }, chips = false })
		end
		-- Anneaux de pierre runiques sur les pattes
		local s = string.sub(sfx, 2)
		for key, z in { F = -1.0, B = 1.0 } do
			Cube.box(rig, "Leg_" .. key .. s, "StoneRing", cf(side * 0.7, 0.7, z), v3(0.86, 0.3, 0.86), P.stone, { chips = false })
		end
		-- Défenses d'ivoire courbes gravées de runes
		local pts = {}
		for k = 0, 5 do
			local t = k / 5
			table.insert(pts, v3(side * (0.42 + 0.35 * t), 2.85 - 0.75 * math.sin(t * 1.6) + 0.9 * t * t, -2.45 - 1.1 * t))
		end
		for k = 1, #pts - 1 do
			local s0 = 0.3 - k * 0.035
			Cube.boxBetween(rig, "Head", "Tusk", pts[k], pts[k + 1], s0, s0, P.ivory, { chips = false })
			if k % 2 == 0 then
				rig:block("Head", "TuskBand", Kit.lookAlong(pts[k], pts[k + 1] - pts[k]), v3(s0 * 1.12, s0 * 1.12, 0.05), P.rune)
			end
		end
	end)
	-- Trompe en cubes qui se balance (os Sway)
	local trunk = rig:boneChain("Sway", "Head", TRUNK)
	for j = 1, #trunk do
		local s0 = 0.48 - j * 0.06
		Cube.boxBetween(rig, trunk[j], "Trunk", TRUNK[j], TRUNK[j + 1], s0, s0, P.wool, { chips = false })
		rig:block(trunk[j], "TrunkRing", Kit.lookAlong(TRUNK[j + 1], TRUNK[j + 1] - TRUNK[j]), v3(s0 * 1.08, s0 * 1.08, 0.05), P.brass)
	end
	-- Nacelle de pierre et menhirs runiques couronnés de cristaux
	Cube.box(rig, "Body", "Howdah", cf(0, 4.08, 0.2), v3(1.7, 0.26, 1.9), P.stone)
	for _, c in { v3(-0.68, 0, -0.62), v3(0.68, 0, -0.62), v3(-0.68, 0, 1.02), v3(0.68, 0, 1.02) } do
		Cube.box(rig, "Body", "Menhir", cf(c.X, 4.6, c.Z) * ang(0, rad(c.X * 20), 0), v3(0.3, 0.8, 0.3), P.stone, { chips = false })
		Cube.crystals(rig, "Body", cf(c.X, 5.0, c.Z), 3, 0.4, { P.crystal, P.rune }, math.floor(c.X * 10 + c.Z * 7))
	end
	Cube.crystals(rig, "Body", cf(0, 4.2, 0.2), 4, 0.8, { P.crystal, P.rune }, 11)
	-- Pierres runiques en orbite
	A.orbit(rig, "Aura1", v3(0, 3.2, 0.2), 3.2, 6, 0.6, function(bone, c, i)
		Cube.box(rig, bone, "RuneStone", c * ang(0, 0, rad(i * 12)), v3(0.34, 0.5, 0.14), P.stone, { px = 0.05, chips = false })
	end)

	rig:hitbox(cf(0, 2.6, -0.2), v3(2.8, 5.2, 5.4))
	if rig.effects then
		local sc = rig.scale
		local mist = rig:anchor("Body", "FX_RuneMist", cf(0, 5.0, 0.2), v3(1.6, 0.4, 1.8))
		Fx.particles(mist, Fx.mist("RuneMist", { rgb(140, 210, 255), rgb(80, 150, 230) }, 5, 0.9, 0.6), sc)
		Fx.particles(mist, Fx.sparkles("RuneSparks", { rgb(220, 240, 255), RUNE }, 6, 0.16, 0.3), sc)
		Fx.light(mist, { color = RUNE, range = 12, brightness = 1.4 }, sc)
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Epic")
	end
	return rig:finish({ Rarity = "Epic" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Mammouth runique",
	Rarity = "Epic",
	Size = "Giant",
	Income = 1500,
	SpeedBonus = 0.3,
	Passenger = true,
	Scale = 2.3,
	Category = "Créature Épique",
	Description = "Mammouth ancestral aux défenses gravées de runes bleues ; il porte une nacelle de menhirs sur le dos.",
	Icon = { top = rgb(60, 70, 140), bottom = rgb(12, 14, 34), glow = rgb(110, 200, 255), motif = rgb(80, 180, 255), yaw = 34, pitch = 14, zoom = 1.05 },
	Animation = { flicker = 0.12, gait = "Quadruped", breathe = 0.05, bob = 0.08, stride = 18, strideRate = 5, tailSway = 10, tailRate = 2, headLook = 10, earTwitch = true, auraSpeed = 0.35 },
	Ability = ABILITY,
	build = build,
}

return Def
