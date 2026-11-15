--!strict
--[[
	CERF DES BRUMES — Commun · Grand (style cubes + pixels)
	======================================================
	Cerf en cubes aux bois de verre translucide entourés de brume.

	• Robe gris-taupe en pixels de fourrure, poitrail et ventre clairs, petite queue blanche.
	• Longues pattes fines, sabots d'argent.
	• Grands bois en cubes de verre translucide, ramifiés, pointes perlées lumineuses.
	• Effets : brume qui s'enroule autour des bois et flotte au ras du sol.
]]

local Kit = require(script.Parent.Parent.Kit)
local Fx = require(script.Parent.Parent.Fx)
local Vfx = require(script.Parent.Parent.Vfx)
local Types = require(script.Parent.Parent.Types)
local Cube = require(script.Parent.Parent.Cube)

local S = Kit.style
local M = Enum.Material
local rgb = Color3.fromRGB
local v3 = Vector3.new
local cf = CFrame.new

local ID = "CerfDesBrumes"

local P = {
	coat = Cube.skin(rgb(150, 136, 122), Cube.fur(), { px = 0.065 }),
	pale = Cube.skin(rgb(232, 226, 216), Cube.fur(), { px = 0.055 }),
	dark = Cube.skin(rgb(94, 84, 76), Cube.fur(), { px = 0.055 }),
	antler = Cube.skin(rgb(220, 236, 248), Cube.crystal(13), { material = M.Glass, glow = { rgb(240, 250, 255) }, px = 0.045, chips = false }),
	pearl = S(rgb(245, 248, 255), M.Neon),
	silver = S(rgb(220, 226, 236), M.Metal),
	nose = S(rgb(30, 26, 26)),
	inner = S(rgb(220, 180, 170)),
	eye = { S(rgb(16, 12, 10)), S(rgb(70, 50, 40)), S(rgb(30, 20, 16)), S(rgb(240, 240, 240), M.Neon) },
}
P.antler.base = S(rgb(220, 236, 248), M.Glass, { transparency = 0.25 })

local ABILITY: Types.Ability = {
	name = "Voile de brume",
	kind = "Nova",
	colors = { rgb(230, 240, 245), rgb(170, 190, 200), rgb(255, 255, 255) },
	texture = "sparkle",
	radius = 6,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local q = Cube.quadruped(rig, {
		body = { c = v3(0, 2.05, 0), size = v3(1.0, 0.9, 2.0), skin = P.coat },
		neck = v3(0, 2.35, -0.85),
		head = { c = v3(0, 2.95, -1.25), size = v3(0.7, 0.62, 0.7), skin = P.coat },
		snout = { size = v3(0.42, 0.34, 0.42), y = -0.12, skin = P.dark, nose = P.nose },
		eyes = { kind = "square", size = 0.13, colors = P.eye, x = 0.3, y = 3.02, side = true, z = -1.35 },
		ears = { w = 0.26, h = 0.3, outer = P.coat.base, inner = P.inner, x = 0.38, z = -1.12, tilt = 55 },
		legs = { x = 0.33, zf = -0.72, zb = 0.72, hipY = 1.7, w = 0.22, skin = P.coat, foot = "hoof", toe = P.silver, footH = 0.18 },
		tail = { pts = { v3(0, 2.3, 1.0), v3(0, 2.32, 1.12), v3(0, 2.28, 1.3) }, sizes = { 0.26, 0.2 }, skin = P.pale },
	})
	-- Cou qui monte vers la tête, poitrail et ventre clairs
	Cube.boxBetween(rig, "Head", "Neck", v3(0, 2.25, -0.85), v3(0, 2.85, -1.15), 0.5, 0.5, P.coat, { chips = false })
	Cube.box(rig, "Body", "Chest", cf(0, 1.95, -1.03), v3(0.7, 0.6, 0.08), P.pale, { faces = { "front" }, chips = false })
	Cube.box(rig, "Body", "Belly", cf(0, 1.58, 0), v3(0.7, 0.06, 1.5), P.pale, { faces = { "bottom" }, chips = false })
	-- Bois de verre ramifiés, pointes perlées
	rig:mirrored(function(side)
		local base = v3(side * 0.2, q.headTop - 0.02, -1.15)
		local mid = base + v3(side * 0.3, 0.55, 0.1)
		local top = mid + v3(side * 0.25, 0.55, 0.2)
		local branches = {
			{ base, mid }, { mid, top },
			{ mid, mid + v3(side * 0.35, 0.25, -0.2) },
			{ top, top + v3(side * 0.25, 0.25, -0.15) },
			{ top, top + v3(-side * 0.08, 0.35, 0.2) },
			{ base + v3(side * 0.12, 0.25, 0), base + v3(side * 0.05, 0.5, -0.3) },
		}
		for k, br in branches do
			local w = if k <= 2 then 0.13 else 0.09
			Cube.boxBetween(rig, "Head", "Antler", br[1], br[2], w, w, P.antler, { faces = { "top", "left", "right" } })
			rig:block("Head", "AntlerTip", cf(br[2]), v3(w * 0.9, w * 0.9, w * 0.9), P.pearl)
		end
	end)
	-- Volutes de brume en orbite (cubes de verre pâle)
	Cube.orbitGems(rig, "Aura1", v3(0, 3.6, -1.1), 0.9, 5, 0.15, { S(rgb(235, 245, 250), M.Glass, { transparency = 0.5 }) }, nil, 0.16)

	rig:hitbox(cf(0, 2, 0), v3(1.6, 4, 4))
	if rig.effects then
		local sc = rig.scale
		local mist = rig:anchor("Head", "FX_AntlerMist", cf(0, 3.8, -1.1), v3(1.6, 0.8, 0.8))
		Fx.particles(mist, Fx.mist("AntlerMist", { rgb(235, 245, 250), rgb(200, 215, 225) }, 4, 0.8), sc)
		local ground = rig:anchor("Root", "FX_GroundMist", cf(0, 0.3, 0), v3(2.4, 0.3, 3.4))
		Fx.particles(ground, Fx.mist("GroundMist", { rgb(220, 232, 240), rgb(190, 205, 215) }, 4, 1.2), sc)
		Fx.light(mist, { color = rgb(220, 240, 255), range = 6, brightness = 0.8 }, sc)
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Common")
	end
	return rig:finish({ Rarity = "Common" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Cerf des brumes",
	Rarity = "Common",
	Size = "Large",
	Income = 15,
	SpeedBonus = 0.08,
	Passenger = true,
	Scale = 2.4,
	Category = "Créature Commune",
	Description = "Cerf discret aux bois de verre translucide ; une brume fraîche s'enroule autour de ses bois.",
	Icon = { top = rgb(110, 120, 124), bottom = rgb(26, 30, 34), glow = rgb(230, 240, 245), motif = rgb(210, 236, 240), yaw = 32, pitch = 10, zoom = 1.05 },
	Animation = { gait = "Quadruped", breathe = 0.03, bob = 0.1, stride = 30, strideRate = 9, tailSway = 8, tailRate = 3, headLook = 16, earTwitch = true, auraSpeed = 0.35 },
	Ability = ABILITY,
	build = build,
}

return Def
