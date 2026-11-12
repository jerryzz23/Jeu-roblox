--!strict
--[[
	Tapis royal — niveau 7
	======================
	Pourpre et or : couronne sur la console, éventails de plumes de paon de part et d'autre,
	bannières de velours aux montants, bande en tapis rouge liseré d'or, pièces d'or en orbite.
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

local ID = "TapisRoyal"

local THEME: Base.Theme = {
	frame = S(rgb(76, 22, 96)),
	frameDark = S(rgb(38, 10, 50)),
	trim = S(rgb(255, 200, 60), M.Metal, { reflectance = 0.1 }),
	neon = S(rgb(255, 90, 220), M.Neon),
	belt = S(rgb(150, 18, 40), M.Fabric),
	beltUnder = S(rgb(70, 8, 20)),
	accent = S(rgb(255, 214, 90), M.Neon),
	pattern = "edges",
	screen = S(rgb(40, 8, 52)),
	glyph = "crown",
	glyphStyle = S(rgb(255, 214, 90), M.Neon),
	beltSpeed = 6,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local a = Base.build(rig, THEME)
	local gold, gem = THEME.trim, S(rgb(255, 40, 120), M.Neon)
	-- Couronne sur la console
	local base = cf(a.consoleTop + v3(0, 0.12, 0))
	rig:ring("Root", "Crown", base * ang(math.pi / 2, 0, 0), 0.55, 0.12, 0.2, 16, gold)
	for i = 0, 6 do
		local at = base * ang(0, i / 7 * math.pi * 2, 0) * cf(0, 0.12, -0.55)
		rig:thorn("Root", "CrownSpike", at, 0.16, if i % 2 == 0 then 0.6 else 0.4, gold)
		if i % 2 == 0 then
			rig:ball("Root", "CrownGem", (at * cf(0, 0.6, 0)).Position, 0.12, gem)
		end
	end
	-- Éventails de plumes de paon
	for _, s in { 1, -1 } do
		local at = a.consoleCF * cf(s * 1.5, 0.2, 0.15) * ang(0, 0, s * rad(-35)) * ang(rad(-90), 0, 0)
		A.featherFan(rig, "Root", at, 9, 1.5, 0.3, 80, { S(rgb(150, 30, 160)), S(rgb(90, 20, 130)), S(rgb(200, 60, 200)) }, THEME.neon)
	end
	-- Bannières de velours aux montants
	for _, p in a.posts do
		local top = p + v3(0, -0.3, 0.25)
		rig:prism("Root", "Banner", cf(top + v3(0, -0.8, 0)), v3(0.06, 1.6, 0.7), 0.02, S(rgb(110, 20, 140), M.Fabric))
		rig:block("Root", "BannerTrim", cf(top + v3(0, -1.62, 0)), v3(0.08, 0.08, 0.72), gold)
		Base.glyph(rig, "Root", cf(top + v3(math.sign(p.X) * 0.05, -0.8, 0)) * ang(0, math.sign(p.X) * math.pi / 2, 0), "crown", 0.28, gold)
	end
	-- Pièces d'or en orbite
	A.orbit(rig, "Aura1", v3(0, 2.0, 0), 3.4, 8, 0.4, function(bone, c)
		rig:cylinder(bone, "Coin", c.Position - c.LookVector * 0.04, c.Position + c.LookVector * 0.04, 0.4, gold)
		rig:ball(bone, "CoinGem", c.Position, 0.12, gem)
	end)
	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Root", "FX_Royal", cf(0, 2.0, 0), v3(3, 2, 6))
		Fx.particles(g, Fx.sparkles("GoldDust", { rgb(255, 236, 140), rgb(255, 90, 220) }, 12, 0.2), sc)
		Fx.light(g, { color = rgb(255, 120, 230), range = 12, brightness = 1.4 }, sc)
	end
	return rig:finish({ TreadmillId = ID, Tier = 7, Gain = 1500 })
end

return {
	Id = ID,
	DisplayName = "Tapis royal",
	Tier = 7,
	Price = 50000000000,
	Gain = 1500,
	Theme = "Royal",
	Description = "Pourpre et or : couronne, éventails de plumes de paon, bannières de velours.",
	Color = rgb(255, 90, 220),
	build = build,
}
