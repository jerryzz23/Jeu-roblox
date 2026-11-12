--!strict
--[[
	Tapis du néant — niveau 6
	=========================
	Obsidienne et lueurs violettes : portail en spirale qui tourne au-dessus de la console,
	croissants de lune en orbite, grappes de cristaux sombres, bande étoilée, brume du néant.
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

local ID = "TapisNeant"

local THEME: Base.Theme = {
	frame = S(rgb(34, 26, 50)),
	frameDark = S(rgb(16, 12, 24)),
	trim = S(rgb(130, 80, 210), M.Metal),
	neon = S(rgb(180, 90, 255), M.Neon),
	belt = S(rgb(16, 10, 26)),
	beltUnder = S(rgb(8, 6, 14)),
	accent = S(rgb(230, 190, 255), M.Neon),
	pattern = "stars",
	screen = S(rgb(20, 8, 40)),
	glyph = "moon",
	beltSpeed = 5.5,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local a = Base.build(rig, THEME)
	local crystals = { S(rgb(170, 80, 255), M.Neon), S(rgb(60, 30, 100), M.Glass, { transparency = 0.1 }), S(rgb(24, 16, 36)), S(rgb(220, 160, 255), M.Neon) }
	-- Portail en spirale (os Spin1)
	local portal = a.consoleTop + v3(0, 1.3, 0.2)
	rig:bone("Spin1", "Root", cf(portal))
	local motor = rig.bones.Root:FindFirstChild("Spin1")
	if motor then
		motor:SetAttribute("Speed", 1.2)
	end
	rig:cylinder("Spin1", "PortalDisc", portal + v3(0, 0, -0.03), portal + v3(0, 0, 0.03), 1.7, S(rgb(30, 10, 60), M.Neon))
	rig:ring("Spin1", "PortalRim", cf(portal), 0.9, 0.12, 0.1, 28, THEME.trim)
	Base.glyph(rig, "Spin1", cf(portal) * cf(0, 0, -0.06), "swirl", 1.6, S(rgb(220, 160, 255), M.Neon))
	Base.glyph(rig, "Spin1", cf(portal) * ang(0, math.pi, 0) * cf(0, 0, -0.06), "swirl", 1.6, S(rgb(220, 160, 255), M.Neon))
	for _, p in a.posts do
		rig:strut("Root", "PortalArm", p, portal + (p - portal).Unit * 0.9, 0.12, 0.12, THEME.frame)
	end
	-- Grappes de cristaux sombres
	for i, c in a.frontCorners do
		A.crystals(rig, "Root", cf(c + v3(0, -0.2, 0)), 7, 1.0, crystals, 20 + i, 0.5)
	end
	for i, c in a.rearCorners do
		A.crystals(rig, "Root", cf(c), 6, 0.8, crystals, 30 + i, 0.5)
	end
	-- Croissants de lune en orbite
	A.orbit(rig, "Aura1", v3(0, 2.4, 0), 3.2, 5, 0.5, function(bone, c, i)
		Base.glyph(rig, bone, c, "moon", 0.45, crystals[(i % 2) * 3 + 1])
	end)
	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Root", "FX_Void", cf(0, 0.8, 0), v3(3.4, 0.6, 7))
		Fx.particles(g, Fx.mist("VoidMist", { rgb(80, 30, 140), rgb(10, 4, 20) }, 12, 1.6, 0.15), sc)
		Fx.particles(g, Fx.sparkles("VoidSparks", { rgb(230, 190, 255), rgb(150, 70, 255) }, 8, 0.16), sc)
		local p = rig:anchor("Spin1", "FX_Portal", cf(portal), v3(1.4, 1.4, 0.2))
		Fx.light(p, { color = rgb(170, 80, 255), range = 12, brightness = 1.8 }, sc)
		Vfx.orbitTethers(rig, "Aura1", Vfx.orbitPoints(v3(0, 2.4, 0), 3.2, 5, 0.5), "Spin1", portal, { colors = { rgb(220, 160, 255), rgb(90, 30, 180) }, transparency = { 0.35, 0.85 }, width0 = 0.05, width1 = 0.02, curve0 = 0.6 })
	end
	return rig:finish({ TreadmillId = ID, Tier = 6, Gain = 400 })
end

return {
	Id = ID,
	DisplayName = "Tapis du néant",
	Tier = 6,
	Price = 5000000,
	Gain = 400,
	Theme = "Néant",
	Description = "Obsidienne et lueurs violettes, portail en spirale, croissants de lune en orbite.",
	Color = rgb(180, 90, 255),
	build = build,
}
