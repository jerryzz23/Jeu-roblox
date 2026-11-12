--!strict
--[[
	Tapis d'orage — niveau 5
	========================
	Métal bleu nuit chargé d'électricité : deux bobines Tesla à l'avant reliées par des arcs,
	nuage d'orage flottant au-dessus de la console, éclairs Neon sur la bande, étincelles.
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

local ID = "TapisOrage"

local THEME: Base.Theme = {
	frame = S(rgb(30, 38, 70), M.Metal),
	frameDark = S(rgb(16, 20, 38)),
	trim = S(rgb(196, 206, 226), M.Metal),
	neon = S(rgb(90, 180, 255), M.Neon),
	belt = S(rgb(18, 22, 40)),
	beltUnder = S(rgb(10, 12, 24)),
	accent = S(rgb(170, 225, 255), M.Neon),
	pattern = "bolts",
	screen = S(rgb(8, 18, 50)),
	glyph = "bolt",
	beltSpeed = 5,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local a = Base.build(rig, THEME)
	-- Bobines Tesla à l'avant
	local orbs = {}
	for i, c in a.frontCorners do
		local base = c + v3(0, -0.1, -0.2)
		local top = base + v3(0, 2.6, 0)
		rig:cylinder("Root", "Coil", base, top, 0.32, THEME.frame)
		for k = 1, 5 do
			rig:ring("Root", "CoilRing", cf(base + v3(0, 0.45 * k, 0)) * ang(math.pi / 2, 0, 0), 0.26 - k * 0.015, 0.05, 0.08, 12, THEME.trim)
		end
		rig:ball("Root", "CoilOrb", top + v3(0, 0.3, 0), 0.62, THEME.neon)
		rig:ring("Root", "CoilHalo", cf(top + v3(0, 0.3, 0)), 0.42, 0.04, 0.03, 16, S(rgb(200, 235, 255), M.Neon, { transparency = 0.3 }))
		table.insert(orbs, top + v3(0, 0.3, 0))
	end
	-- Nuage d'orage flottant
	local cloudAt = a.consoleTop + v3(0, 1.4, 0.6)
	rig:bone("Float1", "Root", cf(cloudAt))
	local rng = Random.new(9)
	for k = 1, 9 do
		rig:ball("Float1", "StormCloud", cloudAt + v3(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 0.25), rng:NextNumber(-0.4, 0.4)), rng:NextNumber(0.6, 1.0), if k % 3 == 0 then S(rgb(60, 66, 90)) else S(rgb(84, 92, 120)))
	end
	Base.glyph(rig, "Float1", cf(cloudAt + v3(0.2, -0.8, 0)), "bolt", 0.5, S(rgb(220, 240, 255), M.Neon))
	if rig.effects then
		local sc = rig.scale
		Vfx.beam(rig, "Root", orbs[1], "Root", orbs[2], { colors = { rgb(255, 255, 255), rgb(90, 180, 255) }, transparency = { 0.05, 0.45 }, width0 = 0.12, width1 = 0.06, curve0 = 0.6, curve1 = -0.4 }, v3(0, 1, 0))
		for i, o in orbs do
			Vfx.beam(rig, "Root", o, "Float1", cloudAt, { colors = { rgb(200, 235, 255), rgb(60, 140, 255) }, transparency = { 0.15, 0.6 }, width0 = 0.08, width1 = 0.04, curve0 = 0.4 * i }, v3(0, 1, 0))
			local fx = rig:anchor("Root", "FX_Coil" .. i, cf(o), v3(0.4, 0.4, 0.4))
			Fx.particles(fx, Fx.embers("Sparks", { rgb(255, 255, 255), rgb(120, 200, 255) }, 14, 0.1), sc)
			Fx.light(fx, { color = rgb(120, 200, 255), range = 9, brightness = 1.6 }, sc)
		end
		local c = rig:anchor("Float1", "FX_Rain", cf(cloudAt + v3(0, -0.4, 0)), v3(2, 0.2, 0.8))
		Fx.particles(c, Fx.sparkles("Rain", { rgb(170, 210, 255) }, 10, 0.08, -4), sc)
	end
	return rig:finish({ TreadmillId = ID, Tier = 5, Gain = 120 })
end

return {
	Id = ID,
	DisplayName = "Tapis d'orage",
	Tier = 5,
	Price = 500000,
	Gain = 120,
	Theme = "Orage",
	Description = "Métal bleu nuit, bobines Tesla reliées par des arcs, nuage d'orage flottant.",
	Color = rgb(90, 180, 255),
	build = build,
}
