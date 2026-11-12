--!strict
--[[
	LE CERF CÉLESTE — Épique · La Pente Brumeuse
	============================================
	Cerf majestueux aux bois géométriques lumineux et au corps parsemé d'étoiles Neon.

	• Robe bleu nuit à poil ras, plastron et ventre blanc lunaire, constellation d'étoiles
	  Neon (blanches, cyan, or) semées sur tout le corps.
	• Bois en tubes Neon cyan à andouillers, reliés par des traits de constellation,
	  pointes de cristal.
	• Yeux Neon cyan, liste blanche, grandes oreilles, sabots dorés.
	• Anneau d'étoiles en orbite + halo ; effets : poussière d'étoiles, lueur.
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

local ID = "CerfCeleste"

local P = {
	core = S(rgb(24, 26, 80)),
	coat = { S(rgb(86, 102, 210)), S(rgb(60, 70, 170)), S(rgb(40, 46, 130)), S(rgb(26, 28, 92)) },
	moon = { S(rgb(236, 242, 255)), S(rgb(196, 210, 250)) },
	stars = { S(rgb(255, 255, 255), M.Neon), S(rgb(130, 240, 255), M.Neon), S(rgb(255, 220, 120), M.Neon) },
	antler = S(rgb(120, 236, 255), M.Neon),
	constel = S(rgb(200, 250, 255), M.Neon, { transparency = 0.3 }),
	gem = { S(rgb(160, 240, 255), M.Glass, { transparency = 0.15 }), S(rgb(255, 255, 255), M.Neon) },
	gold = S(rgb(255, 206, 70)),
	eye = S(rgb(140, 245, 255), M.Neon),
	socket = S(rgb(10, 10, 40)),
	nose = S(rgb(20, 20, 50)),
	inner = S(rgb(140, 150, 230)),
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
	name = "Pluie d'étoiles",
	kind = "Nova",
	colors = { rgb(140, 240, 255), rgb(80, 100, 220), rgb(255, 255, 255) },
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
		Fx.particles(g, Fx.sparkles("Stardust", { rgb(255, 255, 255), rgb(140, 240, 255), rgb(255, 220, 140) }, 9, 0.22, 0.1), sc)
		Fx.light(rig.bones.Head, { color = rgb(130, 230, 255), range = 12, brightness = 1.6 }, sc)
	end


	-- Effets avancés : signature, origine de la capacité, aura de rareté
	if rig.effects then
		-- Constellation reliant les étoiles en orbite + arc lumineux entre les bois
		Vfx.orbitRing(rig, "Aura1", Vfx.orbitPoints(v3(0, 2.4, 0), 2.2, 6, 0.4), { colors = { rgb(200, 250, 255), rgb(120, 200, 255) }, transparency = { 0.35, 0.7 }, width0 = 0.04 })
		Vfx.beam(rig, "Head", v3(0.62, 4.15, -0.5), "Head", v3(-0.62, 4.15, -0.5), { colors = { rgb(160, 245, 255), rgb(255, 255, 255) }, transparency = { 0.2, 0.5 }, width0 = 0.08, curve0 = 0.6, curve1 = -0.6 }, v3(0, 1, 0))
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Epic")
	end

	return rig:finish({ Rarity = "Epic" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Cerf Céleste",
	Rarity = "Epic",
	Zone = "PenteBrumeuse",
	Scale = 2.2,
	Category = "Créature Épique",
	Description = "Cerf majestueux aux bois géométriques lumineux. Des étoiles brillent dans sa robe.",
	Icon = { top = rgb(40, 40, 120), bottom = rgb(8, 8, 30), glow = rgb(160, 230, 255), motif = rgb(255, 255, 255), yaw = 32, pitch = 10, zoom = 1.05 },
	Animation = { gait = "Quadruped", breathe = 0.03, bob = 0.1, stride = 30, strideRate = 9, tailSway = 8, tailRate = 3, headLook = 16, earTwitch = true, auraSpeed = 0.35 },
	Ability = ABILITY,
	build = build,
}

return Def
