--!strict
--[[
	Tapis lune de sang — niveau 8
	=============================
	Fer noirci et cramoisi : immense lune de sang cratérisée derrière la console, cerclée de pics,
	qui tourne lentement ; chaînes entre les montants, cierges rouges, runes sanglantes sur la bande.
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

local ID = "TapisLuneDeSang"

local THEME: Base.Theme = {
	frame = S(rgb(40, 28, 30), M.Slate),
	frameDark = S(rgb(20, 12, 14)),
	trim = S(rgb(130, 20, 34), M.Metal),
	neon = S(rgb(255, 40, 60), M.Neon),
	belt = S(rgb(26, 12, 14)),
	beltUnder = S(rgb(12, 4, 6)),
	accent = S(rgb(255, 70, 80), M.Neon),
	pattern = "runes",
	screen = S(rgb(40, 0, 8)),
	glyph = "eye",
	beltSpeed = 6.5,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local a = Base.build(rig, THEME)
	-- Lune de sang (os Spin1 : rotation lente)
	local moon = a.consoleTop + v3(0, 1.5, 0.5)
	rig:bone("Spin1", "Root", cf(moon))
	local motor = rig.bones.Root:FindFirstChild("Spin1")
	if motor then
		motor:SetAttribute("Speed", 0.25)
	end
	rig:cylinder("Spin1", "BloodMoon", moon + v3(0, 0, -0.08), moon + v3(0, 0, 0.08), 2.6, S(rgb(220, 30, 40), M.Neon))
	local rng = Random.new(5)
	for k = 1, 9 do
		local a0 = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.2, 1.0)
		rig:cylinder("Spin1", "Crater", moon + v3(math.cos(a0) * r, math.sin(a0) * r, -0.1), moon + v3(math.cos(a0) * r, math.sin(a0) * r, -0.12), rng:NextNumber(0.2, 0.45), S(rgb(150, 10, 20), M.Neon))
	end
	rig:ring("Spin1", "MoonRim", cf(moon), 1.35, 0.1, 0.12, 32, THEME.frameDark)
	for k = 0, 15 do
		rig:thorn("Spin1", "MoonSpike", cf(moon) * ang(0, 0, k / 16 * math.pi * 2) * cf(0, 1.38, 0), 0.14, if k % 2 == 0 then 0.5 else 0.3, THEME.frameDark)
	end
	-- Chaînes entre les montants et vers l'arrière
	local function chain(p0: Vector3, p1: Vector3, sag: number)
		local n = 9
		for k = 0, n - 1 do
			local t0, t1 = k / n, (k + 1) / n
			local q0 = p0:Lerp(p1, t0) - v3(0, math.sin(t0 * math.pi) * sag, 0)
			local q1 = p0:Lerp(p1, t1) - v3(0, math.sin(t1 * math.pi) * sag, 0)
			local mid = (q0 + q1) / 2
			rig:ring("Root", "ChainLink", CFrame.lookAt(mid, q1) * ang(0, math.pi / 2, if k % 2 == 0 then 0 else math.pi / 2), 0.12, 0.04, 0.04, 8, THEME.trim)
		end
	end
	chain(a.posts[1] + v3(0, -0.4, 0), a.posts[2] + v3(0, -0.4, 0), 0.5)
	for _, p in a.posts do
		chain(p + v3(0, -0.9, 0.3), a.rearCorners[if p.X > 0 then 1 else 2] + v3(0, 0.6, 0), 0.6)
	end
	-- Cierges rouges
	for _, c in { a.frontCorners[1], a.frontCorners[2], a.rearCorners[1], a.rearCorners[2] } do
		for k = 0, 2 do
			local p = c + v3((k - 1) * 0.18, 0, (k % 2) * 0.15)
			local h = 0.4 + k * 0.15
			rig:cylinder("Root", "Candle", p, p + v3(0, h, 0), 0.14, S(rgb(160, 20, 30)))
			A.flame(rig, "Root", cf(p + v3(0, h, 0)), 0.22, 0.08, S(rgb(255, 40, 40), M.Neon), S(rgb(255, 120, 80), M.Neon), S(rgb(255, 230, 200), M.Neon))
		end
	end
	if rig.effects then
		local sc = rig.scale
		local m = rig:anchor("Spin1", "FX_Moon", cf(moon), v3(2.4, 2.4, 0.2))
		Fx.light(m, { color = rgb(255, 40, 50), range = 16, brightness = 2 }, sc)
		local g = rig:anchor("Root", "FX_Blood", cf(0, 0.8, 0), v3(3.4, 0.5, 7))
		Fx.particles(g, Fx.mist("BloodMist", { rgb(180, 10, 30), rgb(30, 0, 6) }, 10, 1.5, 0.3), sc)
		Fx.particles(g, Fx.embers("BloodSparks", { rgb(255, 90, 90), rgb(200, 0, 20) }, 6, 0.1), sc)
	end
	return rig:finish({ TreadmillId = ID, Tier = 8, Gain = 5000 })
end

return {
	Id = ID,
	DisplayName = "Tapis lune de sang",
	Tier = 8,
	Price = 500000000,
	Gain = 5000,
	Theme = "Lune de sang",
	Description = "Fer noirci et cramoisi : lune de sang qui tourne, chaînes, cierges, runes.",
	Color = rgb(255, 40, 60),
	build = build,
}
