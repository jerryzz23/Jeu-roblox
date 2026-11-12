--!strict
--[[
	Tapis d'entraînement — niveau 1
	===============================
	Le tapis de départ : acier brossé, bandes Neon cyan, écran de course, porte-bouteille et
	serviette. Gain de vitesse de base.
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

local ID = "TapisEntrainement"

local THEME: Base.Theme = {
	frame = S(rgb(120, 128, 140), M.Metal),
	frameDark = S(rgb(44, 48, 56)),
	trim = S(rgb(200, 206, 216), M.Metal),
	neon = S(rgb(90, 220, 255), M.Neon),
	belt = S(rgb(30, 32, 38)),
	beltUnder = S(rgb(18, 20, 24)),
	accent = S(rgb(90, 220, 255), M.Neon),
	pattern = "edges",
	screen = S(rgb(10, 24, 36)),
	glyph = "runner",
	beltSpeed = 3,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local a = Base.build(rig, THEME)
	-- Porte-bouteille et gourde
	local post = a.posts[1]
	rig:ring("Root", "BottleHolder", cf(post + v3(0.3, -1.6, 0.1)) * ang(math.pi / 2, 0, 0), 0.14, 0.03, 0.12, 10, THEME.trim)
	rig:cylinder("Root", "Bottle", post + v3(0.3, -1.85, 0.1), post + v3(0.3, -1.35, 0.1), 0.24, S(rgb(120, 220, 255), M.Glass, { transparency = 0.3 }))
	rig:cylinder("Root", "BottleCap", post + v3(0.3, -1.35, 0.1), post + v3(0.3, -1.25, 0.1), 0.16, S(rgb(40, 44, 52)))
	-- Serviette posée sur la poignée gauche
	local h = a.posts[2] + v3(0, -1.0, 0.9)
	rig:prism("Root", "Towel", cf(h) * ang(0, 0, rad(-80)), v3(0.6, 0.06, 0.5), 0.02, S(rgb(240, 244, 250), M.Fabric))
	rig:block("Root", "TowelStripe", cf(h + v3(-0.02, -0.22, 0)) * ang(0, 0, rad(-80)), v3(0.08, 0.07, 0.52), S(rgb(90, 220, 255), M.Fabric))
	-- Haut-parleurs sur la console
	for _, s in { 1, -1 } do
		local sp = a.consoleCF * cf(s * 1.25, 0, 0.26)
		rig:cylinder("Root", "Speaker", (sp * cf(0, 0, -0.02)).Position, (sp * cf(0, 0, 0.03)).Position, 0.3, S(rgb(30, 32, 38)))
		rig:ring("Root", "SpeakerRim", sp * cf(0, 0, 0.03), 0.15, 0.03, 0.03, 10, THEME.neon)
	end
	if rig.effects then
		local g = rig:anchor("Root", "FX_Glow", cf(0, 1.0, 0), v3(3, 0.5, 6))
		Fx.light(g, { color = rgb(90, 220, 255), range = 8, brightness = 1 }, rig.scale)
	end
	return rig:finish({ TreadmillId = ID, Tier = 1, Gain = 1 })
end

return {
	Id = ID,
	DisplayName = "Tapis d'entraînement",
	Tier = 1,
	Price = 0,
	Gain = 1,
	Theme = "Néon cyan",
	Description = "Le tapis de départ, en acier brossé et néon cyan.",
	Color = rgb(90, 220, 255),
	build = build,
}
