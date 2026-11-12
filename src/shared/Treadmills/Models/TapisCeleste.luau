--!strict
--[[
	Tapis céleste — niveau 4
	========================
	Marbre blanc et or : ailes de plumes blanches de part et d'autre de la console, halo d'or qui
	flotte au-dessus, nuages autour du socle, bande nocturne étoilée, plumes d'or en orbite.
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

local ID = "TapisCeleste"

local THEME: Base.Theme = {
	frame = S(rgb(242, 240, 234), M.Marble),
	frameDark = S(rgb(200, 196, 188), M.Marble),
	trim = S(rgb(255, 204, 64), M.Metal, { reflectance = 0.1 }),
	neon = S(rgb(255, 232, 150), M.Neon),
	belt = S(rgb(26, 32, 76)),
	beltUnder = S(rgb(14, 18, 44)),
	accent = S(rgb(255, 245, 210), M.Neon),
	pattern = "stars",
	screen = S(rgb(30, 40, 96)),
	glyph = "star",
	beltSpeed = 4.5,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local a = Base.build(rig, THEME)
	local gold, white = THEME.trim, S(rgb(255, 255, 255))
	-- Ailes de part et d'autre de la console
	for _, s in { 1, -1 } do
		local sfx = if s > 0 then "_R" else "_L"
		local sh = a.consoleCF * cf(s * 1.6, 0.1, 0.1)
		rig:bone("Wing" .. sfx, "Root", sh)
		local p0 = sh.Position
		A.wing(rig, "Wing" .. sfx, s, {
			arm = { v3(math.abs(p0.X), p0.Y, p0.Z), v3(math.abs(p0.X) + 0.7, p0.Y + 0.5, p0.Z + 0.2), v3(math.abs(p0.X) + 1.4, p0.Y + 0.9, p0.Z + 0.4), v3(math.abs(p0.X) + 2.0, p0.Y + 1.15, p0.Z + 0.6) },
			armRadius = 0.1,
			feathers = 10,
			length = { 0.8, 1.3 },
			width = 0.3,
			sweep = 60,
			rows = { { white, S(rgb(244, 244, 250)) }, { S(rgb(255, 236, 170)), white }, { S(rgb(255, 214, 110)), S(rgb(255, 230, 150)) } },
			tip = THEME.neon,
			armStyle = gold,
		})
	end
	-- Halo d'or qui flotte au-dessus de la console
	local haloAt = a.consoleTop + v3(0, 1.0, 0.1)
	rig:bone("Float1", "Root", cf(haloAt))
	rig:ring("Float1", "Halo", cf(haloAt) * ang(math.pi / 2, 0, 0), 0.75, 0.1, 0.06, 28, gold)
	rig:ring("Float1", "HaloGlow", cf(haloAt) * ang(math.pi / 2, 0, 0), 0.8, 0.06, 0.03, 28, S(rgb(255, 240, 180), M.Neon, { transparency = 0.4 }))
	-- Nuages autour du socle
	local rng = Random.new(4)
	for _, c in { a.frontCorners[1], a.frontCorners[2], a.rearCorners[1], a.rearCorners[2] } do
		for k = 1, 5 do
			local p = c + v3(rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.6, -0.1), rng:NextNumber(-0.4, 0.4))
			rig:ball("Root", "Cloud", p, rng:NextNumber(0.5, 0.9), if k % 2 == 0 then white else S(rgb(236, 240, 252)))
		end
	end
	-- Plumes d'or en orbite
	A.orbit(rig, "Aura1", v3(0, 2.2, 0), 3.4, 6, 0.4, function(bone, c)
		A.feather(rig, bone, c * ang(0, 0, rad(25)) * ang(0, math.pi / 2, 0), 0.6, 0.2, gold, THEME.neon)
	end)
	if rig.effects then
		local sc = rig.scale
		local h = rig:anchor("Float1", "FX_Halo", cf(haloAt), v3(1.4, 0.2, 1.4))
		Fx.particles(h, Fx.sparkles("HaloSparks", { rgb(255, 250, 220), rgb(255, 210, 100) }, 10, 0.16), sc)
		Fx.light(h, { color = rgb(255, 230, 160), range = 12, brightness = 1.6 }, sc)
		Vfx.orbitRing(rig, "Aura1", Vfx.orbitPoints(v3(0, 2.2, 0), 3.4, 6, 0.4), { colors = { rgb(255, 245, 210), rgb(255, 200, 80) }, transparency = { 0.4, 0.75 }, width0 = 0.05, curve0 = 0.6, curve1 = -0.6 })
	end
	return rig:finish({ TreadmillId = ID, Tier = 4, Gain = 35 })
end

return {
	Id = ID,
	DisplayName = "Tapis céleste",
	Tier = 4,
	Price = 50000,
	Gain = 35,
	Theme = "Céleste",
	Description = "Marbre blanc et or, ailes de plumes, halo flottant et nuages.",
	Color = rgb(255, 225, 140),
	build = build,
}
