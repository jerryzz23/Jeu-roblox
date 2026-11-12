--!strict
--[[
	Tapis d'émeraude — niveau 9
	===========================
	Pierre sombre et émeraude : quatre flèches gothiques couronnées de flammes vertes, grappes
	d'émeraudes, lianes lumineuses le long des rails, vagues vertes sur la bande, éclats en orbite.
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

local ID = "TapisEmeraude"

local THEME: Base.Theme = {
	frame = S(rgb(34, 44, 38), M.Slate),
	frameDark = S(rgb(16, 22, 18), M.Slate),
	trim = S(rgb(190, 220, 140), M.Metal),
	neon = S(rgb(60, 255, 140), M.Neon),
	belt = S(rgb(12, 26, 18)),
	beltUnder = S(rgb(6, 14, 10)),
	accent = S(rgb(110, 255, 170), M.Neon),
	pattern = "waves",
	screen = S(rgb(6, 30, 16)),
	glyph = "leaf",
	beltSpeed = 7,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local a = Base.build(rig, THEME)
	local emerald = { S(rgb(60, 255, 130), M.Neon), S(rgb(30, 180, 90), M.Glass, { transparency = 0.15 }), S(rgb(170, 255, 200), M.Neon) }
	local flameOut, flameMid, flameCore = S(rgb(20, 160, 70), M.Neon), S(rgb(80, 255, 140), M.Neon), S(rgb(220, 255, 230), M.Neon)
	-- Flèches gothiques aux quatre coins
	local tops = {}
	for i, c in { a.frontCorners[1], a.frontCorners[2], a.rearCorners[1], a.rearCorners[2] } do
		local h = if i <= 2 then 3.2 else 2.2
		local base = c + v3(0, -0.2, 0)
		rig:prism("Root", "Spire", cf(base + v3(0, h / 2, 0)), v3(0.5, h, 0.5), 0.08, THEME.frame)
		for k = 1, 3 do
			rig:block("Root", "SpireNeon", cf(base + v3(0, h * k / 4, 0)), v3(0.54, 0.06, 0.54), THEME.neon)
		end
		rig:thorn("Root", "SpireRoof", cf(base + v3(0, h, 0)), 0.6, 0.9, THEME.frameDark)
		A.flame(rig, "Root", cf(base + v3(0, h + 0.9, 0)), 0.6, 0.24, flameOut, flameMid, flameCore)
		A.crystals(rig, "Root", cf(base + v3(0, 0.1, 0)), 4, 0.6, emerald, 40 + i, 0.4)
		table.insert(tops, base + v3(0, h + 1.2, 0))
	end
	-- Lianes lumineuses le long des rails
	for _, s in { 1, -1 } do
		local prev = v3(s * (a.halfWidth + 0.02), 0.6, -3.4)
		for k = 1, 12 do
			local p = v3(s * (a.halfWidth + 0.02), 0.6 + math.sin(k * 1.3) * 0.18, -3.4 + k * 0.58)
			rig:strut("Root", "Vine", prev, p, 0.06, 0.06, S(rgb(40, 140, 60)))
			if k % 3 == 0 then
				rig:ball("Root", "VineBud", p, 0.14, emerald[1])
			end
			prev = p
		end
	end
	A.crystals(rig, "Root", cf(a.consoleTop), 6, 0.9, emerald, 50, 0.35)
	-- Éclats d'émeraude en orbite
	A.orbit(rig, "Aura1", v3(0, 2.4, 0), 3.4, 7, 0.5, function(bone, c, i)
		rig:shard(bone, "Emerald", c * ang(0, 0, rad(20)), 0.2, 0.5, 0.2, emerald[(i % 3) + 1])
	end)
	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Root", "FX_Emerald", cf(0, 1.4, 0), v3(3.4, 1.4, 7))
		Fx.particles(g, Fx.sparkles("EmeraldMotes", { rgb(170, 255, 200), rgb(40, 220, 110) }, 12, 0.18), sc)
		Fx.light(g, { color = rgb(60, 255, 140), range = 14, brightness = 1.6 }, sc)
		Vfx.beam(rig, "Root", tops[1], "Root", tops[2], { colors = { rgb(170, 255, 200), rgb(30, 200, 90) }, transparency = { 0.2, 0.6 }, width0 = 0.08, curve0 = 0.8, curve1 = -0.8 }, v3(0, 1, 0))
	end
	return rig:finish({ TreadmillId = ID, Tier = 9, Gain = 20000 })
end

return {
	Id = ID,
	DisplayName = "Tapis d'émeraude",
	Tier = 9,
	Price = 25000000000000,
	Gain = 20000,
	Theme = "Émeraude",
	Description = "Pierre sombre et émeraude : flèches gothiques aux flammes vertes, lianes lumineuses.",
	Color = rgb(60, 255, 140),
	build = build,
}
