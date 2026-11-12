--!strict
--[[
	Tapis givré — niveau 3
	======================
	Acier blanc couvert de givre : grappes de cristaux de glace aux coins et sur la console,
	stalactites sous les poignées, flocons sur la bande, neige qui tombe.
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

local ID = "TapisGivre"

local THEME: Base.Theme = {
	frame = S(rgb(226, 236, 246)),
	frameDark = S(rgb(120, 140, 168)),
	trim = S(rgb(170, 220, 255), M.Glass, { transparency = 0.1 }),
	neon = S(rgb(120, 220, 255), M.Neon),
	belt = S(rgb(36, 56, 80)),
	beltUnder = S(rgb(20, 32, 48)),
	accent = S(rgb(210, 245, 255), M.Neon),
	pattern = "dots",
	screen = S(rgb(10, 30, 50)),
	glyph = "snow",
	beltSpeed = 4,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local a = Base.build(rig, THEME)
	local ice = { S(rgb(170, 230, 255), M.Glass, { transparency = 0.2 }), S(rgb(210, 245, 255), M.Neon), S(rgb(120, 200, 255), M.Glass, { transparency = 0.25 }) }
	for i, c in a.frontCorners do
		A.crystals(rig, "Root", cf(c + v3(0, -0.1, 0)), 6, 1.0, ice, 3 + i, 0.4)
	end
	for i, c in a.rearCorners do
		A.crystals(rig, "Root", cf(c + v3(0, 0, 0.1)), 5, 0.8, ice, 7 + i, 0.4)
	end
	A.crystals(rig, "Root", cf(a.consoleTop), 7, 1.1, ice, 11, 0.35)
	-- Stalactites sous les poignées et la console
	for _, p in a.posts do
		for k = 0, 4 do
			local q = p + v3(0, -0.95 - k * 0.03, 0.25 + k * 0.28)
			rig:thorn("Root", "Icicle", cf(q) * ang(math.pi, 0, 0), 0.08, 0.28 + (k % 2) * 0.18, ice[1])
		end
	end
	for k = -3, 3 do
		rig:thorn("Root", "Icicle", (a.consoleCF * cf(k * 0.4, -0.55, 0.1)) * ang(math.pi, 0, 0), 0.08, 0.22 + (k % 2) * 0.16, ice[3])
	end
	-- Congères de neige
	for _, s in { 1, -1 } do
		for k = 0, 2 do
			rig:ball("Root", "Snow", v3(s * (a.halfWidth + 0.15), 0.2, -1.5 + k * 1.6), 0.6 - k * 0.1, S(rgb(250, 252, 255)))
		end
	end
	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Root", "FX_Snow", cf(0, 3.5, 0), v3(4, 1, 7))
		Fx.particles(g, Fx.sparkles("Snow", { rgb(255, 255, 255), rgb(200, 235, 255) }, 14, 0.16, -0.8), sc)
		local m = rig:anchor("Root", "FX_Frost", cf(0, 0.8, 0), v3(3, 0.4, 6))
		Fx.particles(m, Fx.mist("FrostMist", { rgb(220, 240, 255), rgb(170, 200, 230) }, 6, 1.2, 0.2), sc)
		Fx.light(m, { color = rgb(150, 220, 255), range = 10, brightness = 1.2 }, sc)
	end
	return rig:finish({ TreadmillId = ID, Tier = 3, Gain = 10 })
end

return {
	Id = ID,
	DisplayName = "Tapis givré",
	Tier = 3,
	Price = 350000,
	Gain = 10,
	Theme = "Glace",
	Description = "Acier blanc couvert de givre, cristaux de glace et stalactites.",
	Color = rgb(150, 220, 255),
	build = build,
}
