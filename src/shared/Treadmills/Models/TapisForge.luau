--!strict
--[[
	Tapis de forge — niveau 2
	=========================
	Fer noirci et lave : la bande porte des chevrons de lave incandescente, deux pots
	d'échappement crachent des flammes, des engrenages tournent sur les flancs, braseros à l'avant.
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

local ID = "TapisForge"

local THEME: Base.Theme = {
	frame = S(rgb(52, 40, 38), M.Metal),
	frameDark = S(rgb(26, 20, 20)),
	trim = S(rgb(150, 50, 24), M.Metal),
	neon = S(rgb(255, 90, 20), M.Neon),
	belt = S(rgb(34, 22, 18)),
	beltUnder = S(rgb(18, 12, 10)),
	accent = S(rgb(255, 170, 40), M.Neon),
	pattern = "chevrons",
	screen = S(rgb(50, 10, 0)),
	glyph = "flame",
	beltSpeed = 3.5,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local a = Base.build(rig, THEME)
	local flameOut, flameMid, flameCore = S(rgb(255, 80, 20), M.Neon), S(rgb(255, 170, 40), M.Neon), S(rgb(255, 245, 180), M.Neon)
	-- Échappements à l'arrière
	local exhausts = {}
	for i, c in a.rearCorners do
		local base = c + v3(0, 0.2, 0.25)
		local top = base + v3(0, 1.6, 0.25)
		rig:cylinder("Root", "Exhaust", base, top, 0.32, THEME.frame)
		rig:cylinder("Root", "ExhaustRim", top - v3(0, 0.05, 0), top + v3(0, 0.08, 0), 0.42, THEME.trim)
		A.flame(rig, "Root", cf(top + v3(0, 0.05, 0)), 0.7, 0.28, flameOut, flameMid, flameCore)
		table.insert(exhausts, top)
	end
	-- Engrenages qui tournent sur les flancs (os SpinN)
	for i, s in { 1, -1 } do
		local c = v3(s * (a.halfWidth + 0.08), 0.62, 1.2)
		local name = "Spin" .. i
		rig:bone(name, "Root", CFrame.fromMatrix(c, v3(0, 1, 0), v3(0, 0, 1), v3(1, 0, 0)))
		local motor = rig.bones.Root:FindFirstChild(name)
		if motor then
			motor:SetAttribute("Speed", s * 1.6)
		end
		A.gear(rig, name, cf(c) * ang(0, math.pi / 2, 0), 0.55, 10, 0.1, THEME.trim, THEME.frameDark)
		rig:ball(name, "GearCore", c, 0.22, THEME.neon)
	end
	-- Braseros à l'avant
	for _, c in a.frontCorners do
		rig:cylinder("Root", "BrazierStem", c, c + v3(0, 0.5, 0), 0.16, THEME.frame)
		rig:ring("Root", "Brazier", cf(c + v3(0, 0.62, 0)) * ang(math.pi / 2, 0, 0), 0.26, 0.08, 0.14, 12, THEME.trim)
		A.flame(rig, "Root", cf(c + v3(0, 0.6, 0)), 0.55, 0.24, flameOut, flameMid, flameCore)
	end
	-- Cornes de forge sur la console
	for _, s in { 1, -1 } do
		local p0 = a.consoleTop + v3(s * 1.2, -0.05, 0)
		A.horn(rig, "Root", { p0, p0 + v3(s * 0.25, 0.45, 0.05), p0 + v3(s * 0.15, 0.9, 0.1) }, 0.1, 0.025, THEME.frameDark, THEME.neon, { 1.6 })
	end
	if rig.effects then
		local sc = rig.scale
		for i, top in exhausts do
			local fx = rig:anchor("Root", "FX_Exhaust" .. i, cf(top + v3(0, 0.3, 0)), v3(0.2, 0.2, 0.2))
			Fx.particles(fx, Fx.embers("Embers", { rgb(255, 220, 120), rgb(255, 90, 20) }, 10, 0.14), sc)
			Fx.particles(fx, Fx.mist("Smoke", { rgb(70, 60, 56), rgb(20, 16, 14) }, 4, 0.9, 0), sc)
		end
		local g = rig:anchor("Root", "FX_Lava", cf(0, 0.9, 0.3), v3(2.4, 0.3, 6))
		Fx.particles(g, Fx.embers("LavaSparks", { rgb(255, 230, 140), rgb(255, 120, 30) }, 6, 0.1), sc)
		Fx.light(g, { color = rgb(255, 120, 40), range = 10, brightness = 1.4 }, sc)
	end
	return rig:finish({ TreadmillId = ID, Tier = 2, Gain = 3 })
end

return {
	Id = ID,
	DisplayName = "Tapis de forge",
	Tier = 2,
	Price = 500,
	Gain = 3,
	Theme = "Lave",
	Description = "Fer noirci et lave : chevrons incandescents, échappements enflammés, engrenages.",
	Color = rgb(255, 110, 30),
	build = build,
}
