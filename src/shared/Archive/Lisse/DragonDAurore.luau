--!strict
--[[
	LE DRAGON D'AURORE — Exotique · Géant
	=====================================
	Dragon aux écailles couleur aurore boréale.

	• Écailles en dégradé d'aurore le long du corps : vert -> turquoise -> bleu -> violet -> rose.
	• Grandes ailes membraneuses en verre teinté (un panneau par couleur d'aurore), doigts sombres.
	• Crête dorsale de pointes Neon changeantes, ventre nacré, griffes et cornes d'argent.
	• Tête de dragon : gueule garnie de crocs, yeux Neon blancs, double paire de cornes.
	• Selle d'argent (monture avec passager).
	• Cristaux d'aurore en orbite ; effets : rubans d'aurore au-dessus du dos, poussière d'étoiles.
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

local ID = "DragonDAurore"

local AURORA = { rgb(80, 255, 160), rgb(60, 230, 230), rgb(70, 150, 255), rgb(160, 90, 255), rgb(255, 110, 210) }

local function ramp(c: Color3): { Kit.Style }
	return { S(c:Lerp(Color3.new(1, 1, 1), 0.3)), S(c), S(c:Lerp(Color3.new(0, 0, 0), 0.3)), S(c:Lerp(Color3.new(0, 0, 0), 0.55)) }
end

local P = {
	core = S(rgb(14, 20, 40)),
	bands = { ramp(AURORA[1]), ramp(AURORA[2]), ramp(AURORA[3]), ramp(AURORA[4]), ramp(AURORA[5]) },
	neon = { S(AURORA[1], M.Neon), S(AURORA[2], M.Neon), S(AURORA[3], M.Neon), S(AURORA[4], M.Neon), S(AURORA[5], M.Neon) },
	membrane = {
		S(AURORA[1], M.Glass, { transparency = 0.35 }),
		S(AURORA[2], M.Glass, { transparency = 0.35 }),
		S(AURORA[3], M.Glass, { transparency = 0.35 }),
		S(AURORA[4], M.Glass, { transparency = 0.35 }),
		S(AURORA[5], M.Glass, { transparency = 0.35 }),
	},
	belly = { S(rgb(240, 246, 255)), S(rgb(210, 220, 240)) },
	finger = S(rgb(30, 36, 66)),
	silver = S(rgb(226, 232, 244), M.Metal, { reflectance = 0.1 }),
	silverDark = S(rgb(150, 160, 186), M.Metal),
	tooth = S(rgb(255, 255, 255)),
	mouth = S(rgb(60, 20, 80)),
	eye = S(rgb(255, 255, 255), M.Neon),
	socket = S(rgb(10, 10, 30)),
	saddle = S(rgb(40, 40, 90), M.Fabric),
}

local BODY = Kit.spine({
	{ pos = v3(0, 3.05, -1.95), rx = 0.22, ry = 0.24 },
	{ pos = v3(0, 2.75, -1.55), rx = 0.32, ry = 0.36 },
	{ pos = v3(0, 2.25, -1.05), rx = 0.5, ry = 0.56 },
	{ pos = v3(0, 2.1, -0.3), rx = 0.62, ry = 0.62 },
	{ pos = v3(0, 2.12, 0.45), rx = 0.6, ry = 0.58 },
	{ pos = v3(0, 1.95, 1.1), rx = 0.42, ry = 0.4 },
})

local TAILPTS = { v3(0, 1.85, 1.25), v3(0.2, 1.5, 1.9), v3(0.6, 1.1, 2.5), v3(1.1, 0.8, 2.95), v3(1.6, 0.7, 3.2), v3(2.0, 0.8, 3.3) }

local HEAD = Kit.spine({
	{ pos = v3(0, 3.05, -2.85), rx = 0.12, ry = 0.1 },
	{ pos = v3(0, 3.12, -2.6), rx = 0.22, ry = 0.17 },
	{ pos = v3(0, 3.2, -2.3), rx = 0.32, ry = 0.26 },
	{ pos = v3(0, 3.22, -2.02), rx = 0.3, ry = 0.3 },
})

local ABILITY: Types.Ability = {
	name = "Souffle boréal",
	kind = "Breath",
	colors = { rgb(80, 255, 170), rgb(150, 90, 255), rgb(255, 130, 220) },
	texture = "sparkle",
	bone = "Head",
	origin = v3(0, 3.0, -2.95),
	direction = v3(0, -0.15, -1),
	radius = 9,
}

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 2.1, 0))
	rig:bone("Head", "Body", cf(0, 3.1, -2.0))
	rig:bone("Jaw", "Head", cf(0, 3.0, -2.2))
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * 0.48, 1.85, -0.85))
		rig:bone("Leg_B" .. s, "Body", cf(side * 0.5, 1.9, 0.75))
		rig:bone("Wing" .. sfx, "Body", cf(side * 0.42, 2.6, -0.6))
	end)
	local tail = rig:boneChain("Tail", "Body", TAILPTS)

	-- Corps : bandes de couleurs d'aurore successives
	local covers = {}
	for k = 1, 5 do
		table.insert(covers, A.scales(P.bands[k], v3(0.3, 0.09, 0.34), 0.22, { arc = 125, from = k, to = k + 1.05, tilt = 18, refRadius = 0.5, seed = k }))
	end
	table.insert(covers, A.scales(P.belly, v3(0.34, 0.06, 0.24), 0.22, { arc = 55, center = 180, tilt = 6, refRadius = 0.5, seed = 9 }))
	rig:tube(BODY, { name = "Body", bone = const("Body"), core = P.core, coreStep = 0.3, cover = covers })

	local tsecs = {}
	for i, p in TAILPTS do
		local r = 0.38 * (1 - (i - 1) / #TAILPTS) + 0.03
		table.insert(tsecs, { pos = p, rx = r, ry = r * 0.9 })
	end
	local TAIL = Kit.spine(tsecs)
	local function tailBone(u: number): string
		return tail[math.clamp(math.floor(u), 1, #tail)]
	end
	local tcovers = {}
	for k = 1, 5 do
		table.insert(tcovers, A.scales(P.bands[6 - k], v3(0.22, 0.07, 0.26), 0.16, { arc = 180, from = k, to = k + 1.05, tilt = 16, refRadius = 0.3, seed = 20 + k }))
	end
	rig:tube(TAIL, { name = "Tail", bone = tailBone, core = P.core, coreStep = 0.22, cover = tcovers })
	-- Crête Neon changeante
	local k = 0
	local s0, s1 = BODY:lengthAt(1.2), BODY:lengthAt(5.8)
	while s0 < s1 do
		local u = BODY:uAt(s0)
		local h = (if k % 2 == 0 then 0.42 else 0.28) * math.clamp(select(1, BODY:radii(u)) / 0.4, 0.6, 1.3)
		rig:spike("Body", "Crest", BODY:surface(u, 0, 0.03) * ang(rad(34), 0, 0) * ang(0, math.pi / 2, 0), 0.22, h, 0.05, P.neon[(math.floor(u) - 1) % 5 + 1])
		s0 += 0.28
		k += 1
	end
	A.crest(rig, TAIL, tailBone, 1.2, 5.6, 0.26, 0.32, 0.16, P.finger, P.neon[5], 0, 30)
	rig:thorn(tail[#tail], "TailBlade", A.alongUp(TAILPTS[#TAILPTS], TAILPTS[#TAILPTS] - TAILPTS[#TAILPTS - 1]), 0.3, 0.6, P.neon[4])

	-- Selle d'argent
	local saddle = BODY:surface(4.15, 0, 0.14)
	rig:prism("Body", "Saddle", saddle, v3(0.8, 0.14, 1.1), 0.06, P.saddle)
	rig:prism("Body", "SaddleBack", saddle * cf(0, 0.2, 0.52) * ang(rad(-14), 0, 0), v3(0.7, 0.3, 0.1), 0.04, P.silver)
	rig:seat("Body", saddle * cf(0, 0.18, -0.1), v3(0.7, 0.2, 0.7))

	-- Tête
	rig:tube(HEAD, { name = "Head", bone = const("Head"), core = P.core, coreStep = 0.18, cover = { A.scales(P.bands[1], v3(0.16, 0.06, 0.18), 0.12, { arc = 140, refRadius = 0.3, seed = 30 }) } })
	rig:prismBetween("Jaw", "Jaw", v3(0, 2.95, -2.2), v3(0, 2.84, -2.82), 0.4, 0.1, 0.04, P.belly[2])
	rig:prismBetween("Jaw", "Mouth", v3(0, 3.0, -2.25), v3(0, 2.94, -2.78), 0.32, 0.06, 0.02, P.mouth)
	rig:mirrored(function(side)
		A.teeth(rig, "Head", A.mx(v3(0.07, 3.0, -2.84), side), A.mx(v3(0.24, 3.04, -2.3), side), 5, 0.045, 0.1, P.tooth, true)
		A.teeth(rig, "Jaw", A.mx(v3(0.07, 2.92, -2.75), side), A.mx(v3(0.2, 2.94, -2.3), side), 4, 0.04, 0.08, P.tooth, false)
		A.eye(rig, "Head", A.mx(v3(0.24, 3.34, -2.35), side), v3(side, 0.3, -0.5), 0.11, "Glow", P.socket, P.eye)
		A.brow(rig, "Head", side, v3(0.22, 3.43, -2.38), 0.24, 24, P.finger)
		A.horn(rig, "Head", { A.mx(v3(0.18, 3.42, -2.1), side), A.mx(v3(0.32, 3.7, -1.85), side), A.mx(v3(0.42, 3.82, -1.5), side), A.mx(v3(0.38, 3.75, -1.2), side) }, 0.1, 0.025, P.silver, P.neon[3], { 1.7, 2.6 })
		A.horn(rig, "Head", { A.mx(v3(0.28, 3.25, -2.0), side), A.mx(v3(0.5, 3.32, -1.8), side), A.mx(v3(0.62, 3.3, -1.55), side) }, 0.06, 0.02, P.silver)
		for f = 0, 2 do
			rig:spike("Head", "CheekFin", cf(A.mx(v3(0.3, 3.15 - f * 0.08, -2.05 + f * 0.08), side)) * ang(0, side * rad(-90), side * rad(50 + f * 12)), 0.14, 0.34 - f * 0.06, 0.03, P.neon[f + 2])
		end
	end)

	-- Ailes membraneuses en verre teinté d'aurore
	rig:mirrored(function(side, sfx)
		local w = "Wing" .. sfx
		local arm = { v3(0.42, 2.6, -0.6), v3(1.4, 3.35, -0.45), v3(2.5, 3.65, 0.05), v3(3.4, 3.4, 0.6) }
		local mp = {}
		for _, p in arm do
			table.insert(mp, A.mx(p, side))
		end
		A.limb(rig, w, side, { { arm[1], 0.17, 0.17 }, { arm[2], 0.13, 0.13 }, { arm[3], 0.09, 0.09 } }, P.finger)
		rig:strut(w, "WingFinger", mp[3], mp[4], 0.08, 0.08, P.finger)
		rig:thorn(w, "WingClaw", A.alongUp(mp[3], v3(0, 1, -0.2)), 0.08, 0.24, P.silver)
		local tips = { mp[4], A.mx(v3(3.45, 2.45, 1.3), side), A.mx(v3(2.85, 1.75, 1.6), side), A.mx(v3(1.9, 1.75, 1.45), side), A.mx(v3(0.85, 2.15, 0.9), side) }
		for t = 2, #tips - 1 do
			rig:strut(w, "WingFinger", mp[3], tips[t], 0.065, 0.065, P.finger)
			rig:thorn(w, "WingTip", A.alongUp(tips[t], tips[t] - mp[3]), 0.06, 0.18, P.silver)
		end
		for t = 1, #tips - 1 do
			A.triangle(rig, w, "Membrane", mp[3], tips[t], tips[t + 1], 0.03, P.membrane[t])
		end
		A.triangle(rig, w, "Membrane", mp[1], mp[3], tips[#tips], 0.03, P.membrane[5])
		A.triangle(rig, w, "Membrane", mp[1], mp[2], mp[3], 0.03, P.membrane[1])
	end)

	-- Pattes puissantes
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, L in { F = { v3(0.48, 1.85, -0.85), v3(0.56, 1.05, -0.95), v3(0.54, 0.3, -1.05), 0.3, 2 }, B = { v3(0.5, 1.9, 0.75), v3(0.6, 1.15, 0.98), v3(0.56, 0.3, 0.86), 0.42, 4 } } do
			local bone = "Leg_" .. key .. s
			A.limb(rig, bone, side, { { L[1], L[4], L[4] * 1.1 }, { L[2], 0.2, 0.2 }, { L[3], 0.15, 0.15 } }, P.core, A.scales(P.bands[L[5] :: number], v3(0.18, 0.06, 0.2), 0.13, { arc = 180, refRadius = 0.2, seed = 40 + side }))
			A.paw(rig, bone, A.mx((L[3] :: Vector3) - v3(0, 0.2, 0.06), side), v3(0, 0, -1), 0.4, 4, P.finger, P.bands[L[5] :: number][3], P.silver)
		end
	end)

	-- Cristaux d'aurore en orbite
	A.orbit(rig, "Aura1", v3(0, 2.6, 0.2), 3.8, 10, 0.6, function(bone, c, i)
		rig:shard(bone, "AuroraCrystal", c * ang(0, 0, rad(18)), 0.24, 0.62, 0.24, P.neon[(i - 1) % 5 + 1])
	end)

	rig:hitbox(cf(0, 2.0, 0), v3(3.2, 4.2, 6))

	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Body", "FX_Aurora", cf(0, 2.6, 0.2), v3(2.4, 1.6, 3.4))
		Fx.particles(g, Fx.sparkles("AuroraDust", { rgb(120, 255, 200), rgb(140, 120, 255), rgb(255, 140, 220) }, 12, 0.22), sc)
		Fx.light(g, { color = rgb(120, 220, 255), range = 16, brightness = 1.6 }, sc)
		-- Rubans d'aurore qui ondulent au-dessus du dos
		for i, cols in { { AURORA[1], AURORA[3] }, { AURORA[4], AURORA[5] } } do
			Vfx.beam(rig, "Body", v3(-0.3 * i, 3.6 + i * 0.25, -1.4), "Body", v3(0.3 * i, 3.3 + i * 0.25, 1.6), { colors = cols, transparency = { 0.65, 0.9 }, width0 = 0.45, width1 = 0.3, curve0 = 1.4 * (if i == 1 then 1 else -1), curve1 = -0.8 }, v3(0, 1, 0))
		end
		Vfx.orbitRing(rig, "Aura1", Vfx.orbitPoints(v3(0, 2.6, 0.2), 3.8, 10, 0.6), { colors = { rgb(120, 255, 200), rgb(200, 120, 255) }, transparency = { 0.35, 0.7 }, width0 = 0.08, curve0 = 0.7, curve1 = -0.7 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Exotic")
	end

	return rig:finish({ Rarity = "Exotic" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Dragon d'aurore",
	Rarity = "Exotic",
	Size = "Giant",
	Income = 900000,
	SpeedBonus = 1.5,
	Passenger = true,
	Scale = 2.3,
	Category = "Créature Exotique",
	Description = "Dragon aux écailles couleur aurore boréale ; ses ailes de verre teinté filtrent la lumière du ciel polaire.",
	Icon = { top = rgb(40, 120, 150), bottom = rgb(16, 8, 40), glow = rgb(140, 255, 210), motif = rgb(200, 130, 255), yaw = 30, pitch = 12, zoom = 1.0 },
	Animation = { gait = "Quadruped", breathe = 0.04, bob = 0.1, stride = 26, strideRate = 8, tailSway = 16, tailRate = 1.2, headLook = 16, auraSpeed = 0.5, flicker = 0.1 },
	Ability = ABILITY,
	build = build,
}

return Def
