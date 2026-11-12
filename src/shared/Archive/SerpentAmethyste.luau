--!strict
--[[
	LE SERPENT D'AMÉTHYSTE — Inhabituel · La Surface
	================================================
	Reptile aux écailles violettes/mauves avec des piques de cristal d'améthyste bruts
	le long de la colonne.

	• Corps lové en double spirale, cou dressé ; écailles en dégradé lilas → violet profond,
	  écailles ventrales lilas pâle.
	• Grappes de cristaux d'améthyste (Neon + verre) le long de l'échine, cornes de cristal.
	• Yeux Neon magenta, crochets, langue fourchue, collier doré.
	• 3 éclats d'améthyste en orbite ; effets : poussière d'améthyste scintillante.
	Os : Root > Body (spirale) > Seg1 > Seg2 > Seg3 > Seg4 > Head > Jaw / Tongue  (démarche "Serpent")
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

local ID = "SerpentAmethyste"

local P = {
	core = S(rgb(70, 30, 120)),
	scales = { S(rgb(222, 166, 255)), S(rgb(180, 112, 236)), S(rgb(136, 72, 204)), S(rgb(96, 46, 164)) },
	belly = { S(rgb(246, 222, 255)), S(rgb(224, 190, 246)) },
	crystals = { S(rgb(200, 110, 255), M.Neon), S(rgb(150, 70, 230), M.Glass, { transparency = 0.15 }), S(rgb(240, 180, 255), M.Neon) },
	eye = S(rgb(255, 90, 220), M.Neon),
	socket = S(rgb(30, 8, 50)),
	fang = S(rgb(255, 252, 240)),
	tongue = S(rgb(255, 80, 140)),
	mouth = S(rgb(110, 20, 60)),
	gold = S(rgb(255, 200, 60)),
	goldDark = S(rgb(208, 130, 24)),
}

-- De la nuque jusqu'au bout de la queue (le cou se dresse, le corps s'enroule)
local BODY = Kit.spine({
	{ pos = v3(0, 2.1, -0.9), rx = 0.2, ry = 0.18 },
	{ pos = v3(0, 1.8, -0.75), rx = 0.26, ry = 0.24 },
	{ pos = v3(0, 1.35, -0.55), rx = 0.3, ry = 0.28 },
	{ pos = v3(0.05, 0.9, -0.3), rx = 0.34, ry = 0.32 },
	{ pos = v3(0.2, 0.42, 0.05), rx = 0.36, ry = 0.32 },
	{ pos = v3(0.75, 0.34, 0.35), rx = 0.36, ry = 0.32 },
	{ pos = v3(0.95, 0.34, 0.95), rx = 0.35, ry = 0.31 },
	{ pos = v3(0.45, 0.34, 1.5), rx = 0.33, ry = 0.3 },
	{ pos = v3(-0.3, 0.34, 1.45), rx = 0.31, ry = 0.28 },
	{ pos = v3(-0.85, 0.34, 0.95), rx = 0.29, ry = 0.26 },
	{ pos = v3(-0.8, 0.36, 0.25), rx = 0.27, ry = 0.24 },
	{ pos = v3(-0.3, 0.72, 0.05), rx = 0.24, ry = 0.22 },
	{ pos = v3(0.35, 0.95, 0.45), rx = 0.2, ry = 0.18 },
	{ pos = v3(0.45, 0.95, 1.05), rx = 0.16, ry = 0.15 },
	{ pos = v3(-0.1, 0.92, 1.15), rx = 0.12, ry = 0.11 },
	{ pos = v3(-0.35, 0.92, 0.75), rx = 0.07, ry = 0.06 },
	{ pos = v3(-0.2, 1.0, 0.45), rx = 0.02, ry = 0.02 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 2.25, -1.62), rx = 0.08, ry = 0.06 },
	{ pos = v3(0, 2.25, -1.45), rx = 0.18, ry = 0.12 },
	{ pos = v3(0, 2.25, -1.2), rx = 0.3, ry = 0.18 },
	{ pos = v3(0, 2.2, -0.97), rx = 0.3, ry = 0.2 },
	{ pos = v3(0, 2.12, -0.84), rx = 0.22, ry = 0.2 },
})

local JAW = Kit.spine({
	{ pos = v3(0, 2.1, -1.55), rx = 0.07, ry = 0.03 },
	{ pos = v3(0, 2.09, -1.3), rx = 0.2, ry = 0.05 },
	{ pos = v3(0, 2.1, -1.0), rx = 0.24, ry = 0.06 },
})

local function segBone(u: number): string
	if u < 2 then
		return "Seg4"
	elseif u < 3 then
		return "Seg3"
	elseif u < 4 then
		return "Seg2"
	elseif u < 5 then
		return "Seg1"
	end
	return "Body"
end

-- Capacité spéciale (CreatureForge.playAbility)
local ABILITY: Types.Ability = {
	name = "Pluie d'améthyste",
	kind = "Burst",
	colors = { rgb(200, 110, 255), rgb(140, 60, 220), rgb(255, 220, 255) },
	texture = "sparkle",
	radius = 4,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 0.34, 0.7))
	rig:bone("Seg1", "Body", cf(BODY:pos(5)))
	rig:bone("Seg2", "Seg1", cf(BODY:pos(4)))
	rig:bone("Seg3", "Seg2", cf(BODY:pos(3)))
	rig:bone("Seg4", "Seg3", cf(BODY:pos(2)))
	rig:bone("Head", "Seg4", cf(0, 2.15, -0.88))
	rig:bone("Jaw", "Head", cf(0, 2.12, -0.98))
	rig:bone("Tongue", "Head", cf(0, 2.15, -1.2))

	rig:tube(BODY, {
		name = "Body",
		bone = segBone,
		core = P.core,
		coreStep = 0.22,
		cover = {
			A.scales(P.scales, v3(0.24, 0.09, 0.26), 0.19, { arc = 120, tilt = 20, refRadius = 0.32, seed = 1 }),
			A.scales(P.belly, v3(0.26, 0.06, 0.18), 0.17, { arc = 55, center = 180, tilt = 6, refRadius = 0.32, jitter = 0.1, seed = 2 }),
		},
	})

	-- Piques de cristal d'améthyste le long de l'échine
	do
		local s, sEnd, i = BODY:lengthAt(1.6), BODY:lengthAt(15.5), 0
		while s < sEnd do
			local u = BODY:uAt(s)
			local _, ry = BODY:radii(u)
			local k = math.clamp(ry / 0.3, 0.35, 1.1)
			A.crystals(rig, segBone(u), BODY:surface(u, 0, 0.02), if i % 2 == 0 then 3 else 2, 0.5 * k, P.crystals, 30 + i, 0.3)
			s += 0.48 * k
			i += 1
		end
	end
	rig:band(BODY, "Seg4", "GoldCollar", 1.5, 0.1, 0.06, P.gold, P.goldDark)

	-- Tête en losange, crochets, cornes de cristal
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.core,
		coreStep = 0.15,
		cover = { A.scales(P.scales, v3(0.15, 0.06, 0.15), 0.12, { arc = 120, refRadius = 0.25, tilt = 14, jitter = 0.2, seed = 3 }) },
	})
	rig:tube(JAW, { name = "Jaw", bone = const("Jaw"), core = P.belly[2], coreStep = 0.15 })
	rig:block("Head", "Mouth", cf(0, 2.135, -1.25), v3(0.36, 0.03, 0.55), P.mouth)
	rig:strut("Tongue", "Tongue", v3(0, 2.14, -1.2), v3(0, 2.14, -1.55), 0.06, 0.025, P.tongue)
	rig:mirrored(function(side, sfx)
		rig:strut("Tongue", "TongueFork", v3(0, 2.14, -1.54), v3(side * 0.05, 2.14, -1.64), 0.035, 0.02, P.tongue)
		A.eye(rig, "Head", A.mx(v3(0.24, 2.33, -1.12), side), v3(side, 0.3, -0.5), 0.12, "Glow", P.socket, P.eye)
		A.brow(rig, "Head", side, v3(0.2, 2.42, -1.12), 0.22, 22, P.scales[4])
		rig:thorn("Head", "Fang", cf(A.mx(v3(0.1, 2.14, -1.45), side)) * ang(math.pi, 0, 0), 0.05, 0.14, P.fang)
		A.crystals(rig, "Head", cf(A.mx(v3(0.17, 2.4, -0.92), side)) * ang(rad(-55), 0, side * rad(-25)), 2, 0.42, P.crystals, 40 + side, 0.2)
	end)

	A.orbit(rig, "Aura1", v3(0, 1.1, 0.5), 1.8, 3, 0.3, function(bone, c, i)
		rig:shard(bone, "OrbitShard", c * ang(0, 0, rad(15)), 0.16, 0.38, 0.18, P.crystals[(i % 2) + 1])
	end)

	rig:hitbox(cf(0, 1.0, 0.3), v3(2.5, 2.4, 3.2))

	if rig.effects then
		local sc = rig.scale
		local dust = rig:anchor("Body", "FX_Amethyst", cf(0, 0.9, 0.6), v3(2, 0.6, 2))
		Fx.particles(dust, Fx.sparkles("AmethystDust", { rgb(220, 150, 255), rgb(160, 80, 240) }, 6, 0.2), sc)
		Fx.light(dust, { color = rgb(190, 110, 255), range = 7, brightness = 1 }, sc)
	end


	-- Effets avancés : signature, origine de la capacité, aura de rareté
	if rig.effects then
		Vfx.orbitRing(rig, "Aura1", Vfx.orbitPoints(v3(0, 1.1, 0.5), 1.8, 3, 0.3), { colors = { rgb(220, 150, 255), rgb(150, 70, 230) }, transparency = { 0.3, 0.6 }, width0 = 0.06, curve0 = 0.6, curve1 = -0.6 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Uncommon")
	end

	return rig:finish({ Rarity = "Uncommon" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Serpent d'Améthyste",
	Rarity = "Uncommon",
	Zone = "Surface",
	Scale = 1.4,
	Category = "Créature Inhabituelle",
	Description = "Reptile aux écailles mauves. Des cristaux d'améthyste bruts percent le long de sa colonne.",
	Icon = { top = rgb(96, 50, 150), bottom = rgb(26, 10, 44), glow = rgb(230, 160, 255), motif = rgb(200, 110, 255), yaw = 30, pitch = 12, zoom = 1.05 },
	Animation = { gait = "Serpent", breathe = 0.02, sway = 10, tailRate = 1.6, headLook = 18, tongueFlick = true, auraSpeed = 0.7 },
	Ability = ABILITY,
	build = build,
}

return Def
