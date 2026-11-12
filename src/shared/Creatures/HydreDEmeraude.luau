--!strict
--[[
	L'HYDRE D'ÉMERAUDE — Mythique · Géant
	=====================================
	Serpent à trois têtes aux écailles vertes.

	• Corps de serpent massif enroulé au sol, écailles émeraude -> vert sombre, ventre crème annelé.
	• Trois longs cous qui ondulent chacun à leur rythme (os "Sway"), cerclés d'anneaux d'or.
	• Trois têtes de serpent-dragon : gueules ouvertes, crocs, yeux Neon jaunes fendus,
	  cornes noires, collerette d'épines, émeraude incrustée sur le front.
	• Selle sur le haut des anneaux (monture avec passager).
	• Émeraudes en orbite ; effets : brume verte, éclats d'émeraude, lueur.
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

local ID = "HydreDEmeraude"

local P = {
	core = S(rgb(10, 60, 30)),
	scales = { S(rgb(120, 240, 150)), S(rgb(60, 196, 104)), S(rgb(30, 146, 72)), S(rgb(16, 96, 48)) },
	belly = { S(rgb(255, 246, 200)), S(rgb(236, 220, 160)) },
	gold = S(rgb(255, 200, 56)),
	goldDark = S(rgb(206, 130, 24)),
	emerald = S(rgb(60, 255, 130), M.Neon),
	emeraldGlass = S(rgb(40, 220, 110), M.Glass, { transparency = 0.15 }),
	horn = S(rgb(24, 30, 26)),
	frill = S(rgb(30, 120, 70)),
	tooth = S(rgb(255, 250, 240)),
	mouth = S(rgb(120, 20, 40)),
	eye = S(rgb(255, 230, 40), M.Neon),
	socket = S(rgb(6, 30, 14)),
	pupil = S(rgb(8, 8, 8)),
	tongue = S(rgb(200, 30, 60)),
	saddle = S(rgb(110, 30, 40), M.Fabric),
}

-- Corps enroulé : de la pointe de la queue jusqu'au poitrail d'où partent les cous
local COIL = Kit.spine({
	{ pos = v3(1.7, 0.2, 2.2), rx = 0.06, ry = 0.06 },
	{ pos = v3(2.0, 0.3, 1.2), rx = 0.22, ry = 0.2 },
	{ pos = v3(1.6, 0.4, 0.1), rx = 0.36, ry = 0.32 },
	{ pos = v3(0.5, 0.5, -0.45), rx = 0.46, ry = 0.42 },
	{ pos = v3(-0.9, 0.55, -0.1), rx = 0.54, ry = 0.5 },
	{ pos = v3(-1.55, 0.6, 0.95), rx = 0.6, ry = 0.55 },
	{ pos = v3(-0.9, 0.7, 1.85), rx = 0.64, ry = 0.6 },
	{ pos = v3(0.3, 0.85, 1.95), rx = 0.68, ry = 0.64 },
	{ pos = v3(0.95, 1.1, 1.25), rx = 0.7, ry = 0.66 },
	{ pos = v3(0.6, 1.55, 0.55), rx = 0.7, ry = 0.66 },
	{ pos = v3(0.05, 1.95, 0.1), rx = 0.62, ry = 0.58 },
})

local NECKS = {
	{ id = 1, pts = { v3(-0.35, 2.0, -0.05), v3(-0.85, 2.55, -0.35), v3(-1.2, 3.0, -0.65), v3(-1.3, 3.35, -1.0), v3(-1.25, 3.45, -1.3) } },
	{ id = 2, pts = { v3(0, 2.15, -0.1), v3(0, 2.85, -0.4), v3(0, 3.45, -0.75), v3(0, 3.85, -1.1), v3(0, 3.95, -1.4) } },
	{ id = 3, pts = { v3(0.35, 2.0, -0.05), v3(0.85, 2.55, -0.35), v3(1.2, 3.0, -0.65), v3(1.3, 3.35, -1.0), v3(1.25, 3.45, -1.3) } },
}

local ABILITY: Types.Ability = {
	name = "Triple souffle",
	kind = "Breath",
	colors = { rgb(90, 255, 140), rgb(20, 120, 60), rgb(230, 255, 200) },
	texture = "smoke",
	bone = "Head",
	origin = v3(0, 3.9, -2.2),
	direction = v3(0, -0.2, -1),
	radius = 8,
}

--- Tête de serpent-dragon posée au bout d'un cou (base = jonction, dir = vers l'avant).
local function serpentHead(rig: Kit.Rig, bone: string, base: Vector3, dir: Vector3)
	local f = dir.Unit
	local right = f:Cross(Vector3.yAxis).Unit
	local up = right:Cross(f).Unit
	local function at(x: number, y: number, z: number): Vector3
		return base + right * x + up * y + f * z
	end
	local head = Kit.spine({
		{ pos = at(0, 0, 0), rx = 0.24, ry = 0.24 },
		{ pos = at(0, 0.04, 0.3), rx = 0.3, ry = 0.26 },
		{ pos = at(0, 0.02, 0.6), rx = 0.24, ry = 0.18 },
		{ pos = at(0, -0.02, 0.82), rx = 0.12, ry = 0.1 },
	})
	rig:tube(head, {
		name = "Head",
		bone = function()
			return bone
		end,
		core = P.core,
		coreStep = 0.16,
		cover = {
			A.scales(P.scales, v3(0.14, 0.05, 0.16), 0.1, { arc = 140, refRadius = 0.24, seed = 3 }),
		},
	})
	-- Gueule ouverte
	rig:prismBetween(bone, "Jaw", at(0, -0.2, 0.1), at(0, -0.34, 0.72), 0.34, 0.08, 0.03, P.belly[2])
	rig:prismBetween(bone, "Mouth", at(0, -0.12, 0.12), at(0, -0.2, 0.68), 0.28, 0.06, 0.02, P.mouth)
	for _, s in { 1, -1 } do
		A.teeth(rig, bone, at(s * 0.06, -0.12, 0.8), at(s * 0.2, -0.1, 0.35), 4, 0.04, 0.09, P.tooth, true)
		A.teeth(rig, bone, at(s * 0.06, -0.3, 0.68), at(s * 0.18, -0.26, 0.3), 3, 0.035, 0.07, P.tooth, false)
		A.eye(rig, bone, at(s * 0.2, 0.14, 0.4), right * s + up * 0.4, 0.1, "Slit", P.socket, P.eye, P.pupil)
		rig:wedge(bone, "Brow", CFrame.lookAt(at(s * 0.18, 0.24, 0.42), at(s * 0.18, 0.24, 0.42) + f, up) * ang(0, 0, s * rad(20)), v3(0.2, 0.06, 0.12), P.scales[4])
		A.horn(rig, bone, { at(s * 0.16, 0.22, 0.15), at(s * 0.26, 0.4, -0.1), at(s * 0.3, 0.5, -0.4) }, 0.06, 0.015, P.horn, P.gold, { 1.6 })
		for k = 0, 3 do
			local p = at(s * (0.22 + k * 0.02), 0.05 - k * 0.06, -0.08 - k * 0.04)
			rig:spike(bone, "Frill", CFrame.lookAt(p, p - f, up) * ang(0, 0, s * rad(70 + k * 10)), 0.14, 0.32 - k * 0.04, 0.03, P.frill)
		end
	end
	rig:shard(bone, "Gem", CFrame.lookAt(at(0, 0.27, 0.32), at(0, 0.27, 0.32) + up, f), 0.1, 0.12, 0.08, P.emerald)
	rig:prismBetween(bone, "Tongue", at(0, -0.22, 0.6), at(0, -0.28, 0.98), 0.05, 0.02, 0.01, P.tongue)
end

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 1.4, 0.6))

	rig:tube(COIL, {
		name = "Coil",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.3,
		cover = {
			A.scales(P.scales, v3(0.3, 0.1, 0.34), 0.24, { arc = 125, tilt = 14, refRadius = 0.5, seed = 1 }),
			A.scales(P.belly, v3(0.34, 0.06, 0.24), 0.22, { arc = 55, center = 180, tilt = 4, refRadius = 0.5, seed = 2 }),
		},
	})
	A.crest(rig, COIL, const("Body"), 2.0, 10.6, 0.36, 0.3, 0.2, P.scales[4], P.emerald, 0, 30)
	for _, u in { 5.0, 7.0, 9.0 } do
		rig:band(COIL, "Body", "GoldBand", u, 0.12, 0.07, P.gold, P.goldDark)
	end
	rig:prism("Body", "Saddle", COIL:surface(8.3, 0, 0.12), v3(0.8, 0.14, 0.8), 0.06, P.saddle)
	rig:seat("Body", COIL:surface(8.3, 0, 0.3), v3(0.7, 0.2, 0.7))

	-- Trois cous ondulants
	for _, n in NECKS do
		local names = {}
		for i = 1, #n.pts - 1 do
			local name = "Sway" .. (n.id * 10 + i)
			rig:bone(name, if i == 1 then "Body" else names[i - 1], Kit.lookAlong(n.pts[i], n.pts[i + 1] - n.pts[i]))
			names[i] = name
		end
		local last = names[#names]
		local headBone = last
		local tipPos = n.pts[#n.pts]
		if n.id == 2 then
			rig:bone("Head", last, cf(tipPos))
			headBone = "Head"
		end
		local secs = {}
		for i, p in n.pts do
			local r = 0.32 - (i - 1) * 0.03
			table.insert(secs, { pos = p, rx = r, ry = r })
		end
		local neck = Kit.spine(secs)
		rig:tube(neck, {
			name = "Neck",
			bone = function(u)
				return names[math.clamp(math.floor(u), 1, #names)]
			end,
			core = P.core,
			coreStep = 0.22,
			cover = {
				A.scales(P.scales, v3(0.2, 0.07, 0.22), 0.15, { arc = 130, tilt = 14, refRadius = 0.3, seed = 10 + n.id }),
				A.scales(P.belly, v3(0.22, 0.05, 0.16), 0.15, { arc = 50, center = 180, refRadius = 0.3, seed = 20 + n.id }),
			},
		})
		A.crest(rig, neck, function(u)
			return names[math.clamp(math.floor(u), 1, #names)]
		end, 1.3, 4.6, 0.26, 0.24, 0.14, P.scales[4], P.emerald, 0, 30)
		rig:band(neck, names[2], "NeckRing", 2.5, 0.08, 0.05, P.gold)
		local dir = (n.pts[#n.pts] - n.pts[#n.pts - 1]).Unit
		serpentHead(rig, headBone, tipPos, v3(dir.X * 0.6, -0.1, -1))
	end

	-- Émeraudes en orbite
	A.orbit(rig, "Aura1", v3(0, 2.2, 0.6), 3.4, 7, 0.5, function(bone, c, i)
		rig:shard(bone, "Emerald", c * ang(0, 0, rad(20)), 0.26, 0.6, 0.26, if i % 2 == 0 then P.emerald else P.emeraldGlass)
	end)

	rig:hitbox(cf(0, 1.8, 0.4), v3(4, 3.8, 4.6))

	if rig.effects then
		local sc = rig.scale
		local g = rig:anchor("Body", "FX_Venom", cf(0, 1.4, 0.8), v3(3, 1.2, 3))
		Fx.particles(g, Fx.mist("VenomMist", { rgb(80, 220, 120), rgb(10, 60, 30) }, 10, 1.6, 0.25), sc)
		Fx.particles(g, Fx.sparkles("EmeraldSparks", { rgb(160, 255, 190), rgb(60, 220, 120) }, 8, 0.22), sc)
		Fx.light(g, { color = rgb(90, 255, 140), range = 14, brightness = 1.4 }, sc)
		Vfx.orbitTethers(rig, "Aura1", Vfx.orbitPoints(v3(0, 2.2, 0.6), 3.4, 7, 0.5), "Body", v3(0, 2.3, 0.1), { colors = { rgb(120, 255, 170), rgb(20, 120, 60) }, transparency = { 0.35, 0.85 }, width0 = 0.06, width1 = 0.02, curve0 = 0.6 })
		Vfx.abilityOrigin(rig, ABILITY)
		Vfx.rarityAura(rig, "Mythic")
	end

	return rig:finish({ Rarity = "Mythic" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Hydre d'émeraude",
	Rarity = "Mythic",
	Size = "Giant",
	Income = 100000,
	SpeedBonus = 0.95,
	Passenger = true,
	Scale = 3.0,
	Category = "Créature Mythique",
	Description = "Serpent colossal à trois têtes aux écailles d'émeraude ; chaque cou ondule à son propre rythme.",
	Icon = { top = rgb(20, 110, 60), bottom = rgb(4, 24, 12), glow = rgb(120, 255, 170), motif = rgb(255, 210, 80), yaw = 28, pitch = 10, zoom = 1.0 },
	Animation = { gait = "Quadruped", breathe = 0.05, headLook = 16, auraSpeed = 0.45, flicker = 0.1 },
	Ability = ABILITY,
	build = build,
}

return Def
