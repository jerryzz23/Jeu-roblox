--!strict
--[[
	Tapis du Néant Couronné — niveau 10
	===================================
	Le tapis ultime, aux couleurs du Néant Couronné : châssis noir et or, bande arc-en-ciel,
	couronne qui flotte au-dessus de la console, étoiles en orbite, cristaux prismatiques et cubes
	glitch flottants, aura Chaotique.
]]

local Kit = require(script.Parent.Parent.Parent.Kit)
local A = require(script.Parent.Parent.Parent.Anatomy)
local Fx = require(script.Parent.Parent.Parent.Fx)
local Vfx = require(script.Parent.Parent.Parent.Vfx)
local Base = require(script.Parent.Parent.Base)

local S = Kit.style
local M = Enum.Material
local rgb = Color3.fromRGB
local rad = math.rad
local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles

local ID = "TapisCouronne"

local THEME: Base.Theme = {
	frame = S(rgb(16, 14, 24)),
	frameDark = S(rgb(8, 6, 12)),
	trim = S(rgb(255, 204, 64), M.Metal, { reflectance = 0.1 }),
	neon = S(rgb(255, 255, 255), M.Neon),
	belt = S(rgb(20, 20, 30)),
	beltUnder = S(rgb(6, 6, 10)),
	pattern = "rainbow",
	rainbow = { S(rgb(255, 70, 70), M.Neon), S(rgb(255, 170, 40), M.Neon), S(rgb(255, 240, 70), M.Neon), S(rgb(70, 230, 110), M.Neon), S(rgb(60, 170, 255), M.Neon), S(rgb(170, 90, 255), M.Neon) },
	screen = S(rgb(10, 6, 20)),
	glyph = "crown",
	glyphStyle = S(rgb(255, 214, 90), M.Neon),
	beltSpeed = 8,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local a = Base.build(rig, THEME)
	local gold, gem = THEME.trim, S(rgb(255, 30, 70), M.Neon)
	local prism = { S(rgb(255, 120, 200), M.Neon), S(rgb(120, 220, 255), M.Neon), S(rgb(255, 240, 140), M.Neon), S(rgb(140, 100, 255), M.Glass, { transparency = 0.15 }) }
	-- Couronne qui flotte (os Float9)
	local at = cf(a.consoleTop + v3(0, 1.1, 0.1))
	rig:bone("Float9", "Root", at)
	rig:ring("Float9", "Crown", at * ang(math.pi / 2, 0, 0), 0.6, 0.12, 0.2, 16, gold)
	for i = 0, 8 do
		local s = at * ang(0, i / 9 * math.pi * 2, 0) * cf(0, 0.12, -0.6)
		local h = if i % 2 == 0 then 0.75 else 0.45
		rig:thorn("Float9", "CrownSpike", s * ang(rad(-8), 0, 0), 0.12, h, gold)
		if i % 2 == 0 then
			rig:ball("Float9", "CrownOrb", (s * ang(rad(-8), 0, 0) * cf(0, h, 0)).Position, 0.12, gem)
		end
	end
	rig:ring("Float9", "CrownHalo", at * cf(0, -0.12, 0) * ang(math.pi / 2, 0, 0), 0.72, 0.04, 0.02, 24, S(rgb(255, 60, 120), M.Neon, { transparency = 0.3 }))
	-- Cristaux prismatiques aux coins
	for i, c in { a.frontCorners[1], a.frontCorners[2], a.rearCorners[1], a.rearCorners[2] } do
		A.crystals(rig, "Root", cf(c + v3(0, -0.1, 0)), 6, if i <= 2 then 1.1 else 0.8, prism, 60 + i, 0.45)
	end
	-- Cubes glitch flottants
	for i = 1, 4 do
		local s = if i % 2 == 0 then 1 else -1
		local p = v3(s * (a.halfWidth + 0.7), 2.2 + i * 0.4, -2.2 + i * 1.1)
		rig:bone("Float" .. i, "Root", cf(p))
		rig:prism("Float" .. i, "GlitchCube", cf(p) * ang(i, i * 0.7, 0), v3(0.36, 0.36, 0.36), 0.05, if i % 2 == 0 then S(rgb(255, 0, 140), M.Neon) else S(rgb(0, 255, 230), M.Neon))
	end
	-- Étoiles en orbite
	A.orbit(rig, "Aura1", v3(0, 2.6, 0), 3.6, 8, 0.6, function(bone, c, i)
		rig:block(bone, "Star", c, v3(0.08, 0.6, 0.08), S(rgb(255, 255, 255), M.Neon))
		rig:block(bone, "Star", c * ang(0, 0, math.pi / 2), v3(0.08, 0.6, 0.08), S(rgb(255, 255, 255), M.Neon))
		rig:ball(bone, "StarCore", c.Position, 0.18, prism[(i % 3) + 1])
	end)
	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Root", "FX_Chaos", cf(0, 2.0, 0), v3(3.4, 2.4, 7))
		Fx.particles(g, Fx.sparkles("RainbowDust", { rgb(255, 90, 90), rgb(255, 230, 80), rgb(80, 230, 140), rgb(80, 160, 255), rgb(200, 100, 255) }, 16, 0.22), sc)
		local c = rig:anchor("Float9", "FX_Crown", at, v3(1.2, 0.4, 1.2))
		Fx.light(c, { color = rgb(255, 210, 120), range = 12, brightness = 1.8 }, sc)
		Vfx.orbitRing(rig, "Aura1", Vfx.orbitPoints(v3(0, 2.6, 0), 3.6, 8, 0.6), { colors = { rgb(255, 255, 255), rgb(200, 140, 255) }, transparency = { 0.35, 0.7 }, width0 = 0.05, curve0 = 0.6, curve1 = -0.6 })
		Vfx.orbitTethers(rig, "Aura1", Vfx.orbitPoints(v3(0, 2.6, 0), 3.6, 8, 0.6), "Float9", at.Position + v3(0, 0.5, 0), { colors = { rgb(255, 120, 200), rgb(120, 220, 255) }, transparency = { 0.3, 0.85 }, width0 = 0.04, width1 = 0.015, curve0 = 0.6 })
		Vfx.rarityAura(rig, "Chaotic")
	end
	return rig:finish({ TreadmillId = ID, Tier = 10, Gain = 100000 })
end

return {
	Id = ID,
	DisplayName = "Tapis du Néant Couronné",
	Tier = 10,
	Price = 600000000000000,
	Gain = 100000,
	Theme = "Néant Couronné",
	Description = "Le tapis ultime : bande arc-en-ciel, couronne flottante, étoiles et aura Chaotique.",
	Color = rgb(255, 60, 160),
	build = build,
}
