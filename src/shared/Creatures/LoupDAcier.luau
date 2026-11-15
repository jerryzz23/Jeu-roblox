--!strict
--[[
	LOUP D'ACIER — Commun · Moyen (style cubes + pixels)
	===================================================
	Loup en cubes au pelage d'acier poli qui brille au soleil.

	• Pelage en lames d'acier (matériau Metal) : mèches en pixels sombres et argent clair.
	• Crinière d'épines métalliques sur la nuque et le dos, plaques d'acier bleui rivetées sur le
	  ventre et les pattes.
	• Collier d'acier riveté gravé de runes cyan lumineuses ; yeux bleu glacier ; crocs d'acier.
	• Effets : éclats de lumière (reflets du soleil) qui scintillent sur le pelage.
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

local ID = "LoupDAcier"

local CYAN = rgb(110, 225, 255)
local P = {
	steel = Cube.skin(rgb(150, 158, 172), Cube.fur(23), { material = M.Metal, glow = { rgb(235, 250, 255) }, px = 0.06 }),
	steelDark = Cube.skin(rgb(96, 104, 120), Cube.fur(), { material = M.Metal, px = 0.06 }),
	blue = Cube.skin(rgb(70, 96, 140), Cube.plates(6, 4), { material = M.Metal, px = 0.055 }),
	collar = Cube.skin(rgb(60, 66, 80), Cube.runes(), { material = M.Metal, glow = { CYAN }, px = 0.045 }),
	silver = S(rgb(226, 232, 244), M.Metal),
	nose = S(rgb(24, 26, 34)),
	cyan = S(CYAN, M.Neon),
	eye = { S(rgb(14, 20, 34)), S(rgb(200, 240, 255), M.Neon), S(CYAN, M.Neon), S(rgb(240, 255, 255), M.Neon) },
}

local ABILITY: Types.Ability = {
	name = "Hurlement d'acier",
	kind = "Nova",
	colors = { rgb(162, 227, 255), rgb(100, 142, 160), rgb(222, 245, 255) },
	texture = "smoke",
	radius = 5,
}

local TAIL = { v3(0, 1.75, 1.0), v3(0, 1.72, 1.35), v3(0, 1.62, 1.85), v3(0, 1.5, 2.32), v3(0, 1.42, 2.72) }

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local q = Cube.quadruped(rig, {
		body = { c = v3(0, 1.6, 0), size = v3(1.0, 0.86, 1.9), skin = P.steel },
		neck = v3(0, 1.9, -0.9),
		head = { c = v3(0, 2.15, -1.25), size = v3(0.86, 0.74, 0.8), skin = P.steel },
		snout = { size = v3(0.46, 0.3, 0.5), y = -0.16, skin = P.steelDark, nose = P.nose },
		jaw = true,
		eyes = { kind = "square", size = 0.15, colors = P.eye, x = 0.22, y = 2.25 },
		ears = { w = 0.3, h = 0.4, outer = P.steel.base, inner = P.steelDark.dark, x = 0.27, z = -1.18, tilt = 6 },
		legs = { x = 0.32, zf = -0.66, zb = 0.66, hipY = 1.25, w = 0.29, skin = P.steel, foot = "claw", footSkin = P.steelDark, toe = P.silver },
		tail = { pts = TAIL, sizes = { 0.36, 0.4, 0.36, 0.28 }, skin = P.steel, spike = P.silver },
	})
	-- Ventre et brassards d'acier bleui rivetés
	Cube.box(rig, "Body", "BellyPlate", cf(0, 1.14, 0), v3(0.76, 0.08, 1.4), P.blue, { faces = { "bottom", "left", "right" }, chips = false })
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, z in { F = -0.66, B = 0.66 } do
			Cube.box(rig, "Leg_" .. key .. s, "Bracer", cf(side * 0.32, 0.5, z), v3(0.33, 0.3, 0.35), P.blue, { chips = false })
		end
	end)
	-- Crinière d'épines métalliques
	for k = 0, 5 do
		local z = -0.95 + k * 0.28
		local h = 0.34 - k * 0.035
		Cube.spike(rig, "Body", v3(0, 2.03 + h * 0.3, z), h, if k % 2 == 0 then P.silver else P.steelDark.base, v3(0, 0, 1))
	end
	Cube.spike(rig, "Head", v3(0, 2.6, -1.0), 0.3, P.silver, v3(0, 0, 1))
	-- Collier riveté gravé de runes cyan
	Cube.box(rig, "Head", "Collar", cf(0, 1.85, -0.95) * ang(rad(-20), 0, 0), v3(0.96, 0.18, 0.66), P.collar, { faces = { "front", "left", "right", "top" }, chips = false })
	-- Crocs d'acier
	if q.snoutFront then
		for k = -1, 1, 2 do
			rig:block("Jaw", "Fang", cf(k * 0.13, q.snoutCenter.Y - 0.12, q.snoutFront.Z + 0.04), v3(0.06, 0.1, 0.06), P.silver)
		end
	end
	-- Éclats d'acier en orbite
	Cube.orbitGems(rig, "Aura1", v3(0, 1.8, 0.2), 1.9, 5, 0.3, { P.silver, P.cyan }, nil, 0.14)

	rig:hitbox(cf(0, 1.5, 0.4), v3(1.6, 3, 4.6))
	if rig.effects then
		local sc = rig.scale
		local glints = rig:anchor("Body", "FX_Glints", cf(0, 1.9, 0.1), v3(1.1, 0.8, 2.0))
		Fx.particles(glints, Fx.sparkles("Glints", { rgb(255, 255, 255), rgb(200, 240, 255) }, 6, 0.2, 0.1), sc)
		local collar = rig:anchor("Head", "FX_Runes", cf(0, 1.9, -1.1), v3(0.8, 0.3, 0.4))
		Fx.light(collar, { color = CYAN, range = 6, brightness = 1 }, sc)
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Common")
	end
	return rig:finish({ Rarity = "Common" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Loup d'acier",
	Rarity = "Common",
	Size = "Medium",
	Income = 9,
	SpeedBonus = 0.07,
	Passenger = false,
	Scale = 1.75,
	Category = "Créature Commune",
	Description = "Loup au pelage d'acier poli : au soleil, chaque mèche renvoie un éclat de lumière.",
	Icon = { top = rgb(80, 100, 130), bottom = rgb(14, 18, 26), glow = rgb(200, 230, 255), motif = rgb(120, 220, 255), yaw = 34, pitch = 12, zoom = 1.1 },
	Animation = { flicker = 0.15, gait = "Quadruped", breathe = 0.035, bob = 0.12, stride = 34, strideRate = 12, tailSway = 10, tailRate = 1.6, headLook = 18, sniff = true, earTwitch = true, auraSpeed = 0.5 },
	Ability = ABILITY,
	build = build,
}

return Def
