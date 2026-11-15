--!strict
--[[
	CERF DES BRUMES — Commun · Grand
	================================
	Cerf aux bois translucides entourés de brume.
	
	• Robe gris-taupe nuancée, poitrail clair, pattes fines et sabots argentés.
	• Grands bois en verre translucide (Glass) aux pointes perlées, reliés par des fils de brume.
	• Effets : brume qui s'enroule autour des bois et flotte au ras du sol.
]]

local Kit = require(script.Parent.Parent.Kit)
local A = require(script.Parent.Parent.Anatomy)
local Fx = require(script.Parent.Parent.Fx)
local Vfx = require(script.Parent.Parent.Vfx)
local Types = require(script.Parent.Parent.Types)

local S = Kit.style
local M = Enum.Material
local rgb = Color3.fromRGB
local rad = math.rad
local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles

local ID = "CerfDesBrumes"

local P = {
	core = S(rgb(70, 66, 62)),
	coat = { S(rgb(178, 170, 160)), S(rgb(148, 140, 130)), S(rgb(118, 110, 102)), S(rgb(90, 84, 78)) },
	moon = { S(rgb(238, 234, 226)), S(rgb(212, 206, 196)) },
	stars = { S(rgb(240, 246, 248), M.Neon), S(rgb(200, 226, 230)), S(rgb(230, 236, 236)) },
	antler = S(rgb(206, 236, 242), M.Glass, { transparency = 0.35 }),
	constel = S(rgb(226, 240, 244), M.Neon, { transparency = 0.65 }),
	gem = { S(rgb(230, 246, 250), M.Glass, { transparency = 0.2 }), S(rgb(240, 250, 255), M.Neon) },
	gold = S(rgb(206, 210, 214)),
	eye = S(rgb(180, 236, 230), M.Neon),
	socket = S(rgb(30, 30, 34)),
	nose = S(rgb(40, 36, 36)),
	inner = S(rgb(200, 170, 160)),
}

local BODY = Kit.spine({
	{ pos = v3(0, 2.3, -1.15), rx = 0.2, ry = 0.24 },
	{ pos = v3(0, 1.95, -0.95), rx = 0.28, ry = 0.34 },
	{ pos = v3(0, 1.75, -0.6), rx = 0.4, ry = 0.46 },
	{ pos = v3(0, 1.72, -0.05), rx = 0.4, ry = 0.42 },
	{ pos = v3(0, 1.76, 0.5), rx = 0.42, ry = 0.42 },
	{ pos = v3(0, 1.66, 0.85), rx = 0.26, ry = 0.26 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 2.26, -1.88), rx = 0.07, ry = 0.07 },
	{ pos = v3(0, 2.3, -1.72), rx = 0.13, ry = 0.12 },
	{ pos = v3(0, 2.4, -1.5), rx = 0.2, ry = 0.18 },
	{ pos = v3(0, 2.48, -1.3), rx = 0.24, ry = 0.22 },
	{ pos = v3(0, 2.45, -1.12), rx = 0.2, ry = 0.21 },
})

local function star(rig: Kit.Rig, bone: string, c: CFrame, size: number, style: Kit.Style)
	rig:thorn(bone, "Star", c, size, size * 1.3, style)
	rig:thorn(bone, "Star", c * ang(math.pi, 0, 0), size, size * 0.6, style)
end

-- Capacité spéciale (CreatureForge.playAbility)
local ABILITY: Types.Ability = {
	name = "Voile de brume",
	kind = "Nova",
	colors = { rgb(230, 240, 245), rgb(170, 190, 200), rgb(255, 255, 255) },
	texture = "sparkle",
	radius = 6,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 1.72, 0))
	rig:bone("Head", "Body", cf(0, 2.3, -1.12))
	rig:bone("Tail1", "Body", cf(0, 1.75, 0.9))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.25, 1.55, -0.6))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.28, 1.6, 0.5))
		rig:bone("Ear" .. sfx, "Head", cf(side * 0.2, 2.6, -1.18))
	end)

	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.25,
		cover = {
			A.scales(P.coat, v3(0.24, 0.06, 0.26), 0.18, { arc = 125, tilt = 14, refRadius = 0.4, seed = 1 }),
			A.scales(P.moon, v3(0.24, 0.06, 0.26), 0.2, { arc = 55, center = 180, tilt = 12, refRadius = 0.4, jitter = 0.2, seed = 2 }),
		},
	})
	-- Constellation d'étoiles sur la robe
	local rng = Random.new(77)
	for i = 1, 46 do
		local u = rng:NextNumber(1.2, 5.8)
		local deg = rng:NextNumber(-125, 125)
		star(rig, "Body", BODY:surface(u, deg, 0.06), rng:NextNumber(0.05, 0.1), P.stars[(i % 3) + 1])
	end

	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.15,
		cover = { A.scales(P.coat, v3(0.14, 0.05, 0.15), 0.11, { arc = 130, from = 1.6, refRadius = 0.22, seed = 3 }) },
	})
	rig:prismBetween("Head", "Blaze", v3(0, 2.6, -1.32), v3(0, 2.36, -1.78), 0.1, 0.04, 0.02, P.moon[1])
	rig:ball("Head", "Nose", v3(0, 2.27, -1.93), 0.1, P.nose)
	star(rig, "Head", cf(0, 2.67, -1.36) * ang(rad(-25), 0, 0), 0.12, P.stars[3])
	rig:mirrored(function(side, sfx)
		A.eye(rig, "Head", A.mx(v3(0.17, 2.52, -1.48), side), v3(side, 0.2, -0.5), 0.11, "Glow", P.socket, P.eye)
		A.ear(rig, "Ear" .. sfx, cf(A.mx(v3(0.2, 2.6, -1.18), side)) * ang(rad(-10), side * rad(-30), side * rad(-62)), 0.26, 0.42, P.coat[2], P.inner, P.stars[2])

		-- Bois géométriques lumineux
		local beam = {
			A.mx(v3(0.1, 2.66, -1.2), side),
			A.mx(v3(0.22, 3.05, -1.12), side),
			A.mx(v3(0.42, 3.45, -1.0), side),
			A.mx(v3(0.55, 3.85, -0.78), side),
			A.mx(v3(0.62, 4.15, -0.5), side),
		}
		local sp = A.horn(rig, "Head", beam, 0.07, 0.025, P.antler)
		local tips = { beam[#beam] }
		for k, t in { { 2.2, v3(0.1, 0.45, -0.4) }, { 3.1, v3(0.3, 0.5, -0.3) }, { 3.8, v3(-0.05, 0.45, -0.35) } } do
			local root = sp:pos(t[1])
			local tip = root + A.mx(t[2], side)
			A.horn(rig, "Head", { root, root:Lerp(tip, 0.5) + v3(0, 0.05, 0), tip }, 0.045, 0.02, P.antler)
			table.insert(tips, tip)
			rig:shard("Head", "AntlerGem", A.alongUp(tip, tip - root), 0.07, 0.14, 0.08, P.gem[(k % 2) + 1])
		end
		-- Traits de constellation entre les pointes
		for k = 1, #tips - 1 do
			rig:strut("Head", "Constellation", tips[k], tips[k + 1], 0.025, 0.025, P.constel)
		end
	end)

	-- Pattes fines, sabots dorés
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, L in { F = { v3(0.25, 1.55, -0.6), v3(0.27, 0.8, -0.62), v3(0.27, 0.2, -0.66), 0.17 }, B = { v3(0.28, 1.6, 0.5), v3(0.32, 1.0, 0.75), v3(0.3, 0.2, 0.6), 0.27 } } do
			local bone = "Leg_" .. key .. s
			A.limb(rig, bone, side, { { L[1], L[4], L[4] * 1.15 }, { L[2], 0.09, 0.09 }, { L[3], 0.065, 0.065 } }, P.core, A.scales(P.coat, v3(0.12, 0.04, 0.14), 0.1, { arc = 180, refRadius = 0.12, seed = 10 + side }))
			A.hoof(rig, bone, A.mx((L[3] :: Vector3) - v3(0, 0.2, 0), side), 0.17, P.gold, P.nose, P.stars[3], nil)
		end
	end)
	A.tuftBurst(rig, "Tail1", cf(0, 1.78, 0.92) * ang(rad(70), 0, 0), 8, 0.3, 0.12, P.moon, nil, 30, 9)

	-- Orbite d'étoiles
	A.orbit(rig, "Aura1", v3(0, 2.4, 0), 2.2, 6, 0.4, function(bone, c, i)
		star(rig, bone, c, 0.16, P.stars[(i % 3) + 1])
	end)

	rig:hitbox(cf(0, 1.8, -0.3), v3(1.6, 3.6, 3.6))

	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Body", "FX_Stars", cf(0, 2.2, -0.2), v3(1.6, 1.6, 2.4))
		Fx.particles(g, Fx.mist("GroundMist", { rgb(230, 236, 240), rgb(190, 200, 206) }, 7, 2.2, 0), sc)
		Fx.particles(g, Fx.sparkles("Stardust", { rgb(255, 255, 255), rgb(226, 255, 255), rgb(226, 255, 255) }, 9, 0.22, 0.1), sc)
		Fx.light(rig.bones.Head, { color = rgb(224, 255, 255), range = 12, brightness = 1.6 }, sc)
	end


	-- Effets avancés : signature, origine de la capacité, aura de rareté
	if rig.effects then
		-- Constellation reliant les étoiles en orbite + arc lumineux entre les bois
		-- (brume au lieu de constellation)
		
		local antlerMist = rig:anchor("Head", "FX_AntlerMist", cf(0, 3.5, -0.9), v3(1.6, 1.2, 1.0))
		Fx.particles(antlerMist, Fx.mist("AntlerMist", { rgb(240, 246, 250), rgb(200, 220, 230) }, 10, 1.0, 0.3), sc)
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Common")
	end

	return rig:finish({ Rarity = "Common" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Cerf des brumes",
	Rarity = "Common",
	Size = "Large",
	Income = 15,
	SpeedBonus = 0.08,
	Passenger = true,
	Scale = 2.4,
	Category = "Créature Commune",
	Description = "Cerf discret aux bois de verre translucide ; une brume fraîche s'enroule autour de ses bois.",
	Icon = { top = rgb(110, 120, 124), bottom = rgb(26, 30, 34), glow = rgb(230, 240, 245), motif = rgb(210, 236, 240), yaw = 32, pitch = 10, zoom = 1.05 },
	Animation = { gait = "Quadruped", breathe = 0.03, bob = 0.1, stride = 30, strideRate = 9, tailSway = 8, tailRate = 3, headLook = 16, earTwitch = true, auraSpeed = 0.35 },
	Ability = ABILITY,
	build = build,
}

return Def
