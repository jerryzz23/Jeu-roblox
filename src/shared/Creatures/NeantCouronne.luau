--!strict
--[[
	LE NÉANT COURONNÉ — Mythique · Les Grottes de Cristal
	=====================================================
	Créature suprême mystique, entourée d'une orbite de cristaux violacés et d'une aura
	rouge sang menaçante, avec des fragments d'énergie flottants.

	• Corps spectral qui lévite et s'effiloche en mèches noir-violet aux pointes rouge sang.
	• Visage d'ombre aux yeux Neon rouges et à la bouche fendue lumineuse.
	• Couronne d'or à pointes serties de gemmes rouges ; épaules hérissées de cristaux violets.
	• Longs bras griffus aux serres rougeoyantes.
	• Orbite de 8 cristaux violets + 10 fragments d'énergie rouges (sens inverse),
	  cercle runique rouge au sol.
	• Effets : aura rouge, brume du néant, étincelles violettes, lumière rouge.
	Os : Root > Body > Head / Arm_R / Arm_L ; Aura1 / Aura2   (démarche "Hover")
]]

local Kit = require(script.Parent.Parent.Kit)
local A = require(script.Parent.Parent.Anatomy)
local Fx = require(script.Parent.Parent.Fx)
local Types = require(script.Parent.Parent.Types)

local S = Kit.style
local M = Enum.Material
local rgb = Color3.fromRGB
local rad = math.rad
local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles

local ID = "NeantCouronne"

local P = {
	core = S(rgb(10, 4, 18)),
	wisp = { S(rgb(70, 36, 110)), S(rgb(48, 22, 80)), S(rgb(28, 12, 50)), S(rgb(14, 6, 26)) },
	blood = S(rgb(230, 24, 50), M.Neon),
	bloodDark = S(rgb(120, 10, 34)),
	face = S(rgb(6, 2, 10)),
	eye = S(rgb(255, 40, 60), M.Neon),
	socket = S(rgb(40, 0, 8)),
	gold = S(rgb(255, 200, 56)),
	goldDark = S(rgb(200, 126, 20)),
	gem = S(rgb(255, 30, 60), M.Neon),
	crystals = { S(rgb(170, 80, 255), M.Neon), S(rgb(110, 40, 200), M.Glass, { transparency = 0.15 }), S(rgb(220, 160, 255), M.Neon) },
	fragment = S(rgb(255, 40, 70), M.Neon),
	rune = S(rgb(255, 30, 60), M.Neon, { transparency = 0.2 }),
	claw = S(rgb(30, 10, 20)),
}

-- Torse spectral (du haut vers la traîne qui s'effiloche)
local BODY = Kit.spine({
	{ pos = v3(0, 4.15, -0.05), rx = 0.5, ry = 0.45 },
	{ pos = v3(0, 3.55, 0.05), rx = 0.78, ry = 0.66 },
	{ pos = v3(0, 2.75, 0.15), rx = 0.72, ry = 0.62 },
	{ pos = v3(0, 2.0, 0.3), rx = 0.52, ry = 0.46 },
	{ pos = v3(0, 1.4, 0.52), rx = 0.3, ry = 0.28 },
	{ pos = v3(0, 1.0, 0.8), rx = 0.08, ry = 0.08 },
})

local HEAD = Kit.spine({
	{ pos = v3(0, 4.78, -0.42), rx = 0.24, ry = 0.24 },
	{ pos = v3(0, 4.8, -0.2), rx = 0.46, ry = 0.46 },
	{ pos = v3(0, 4.74, 0.12), rx = 0.46, ry = 0.46 },
	{ pos = v3(0, 4.55, 0.35), rx = 0.3, ry = 0.3 },
})

local function build(opts: Kit.BuildOptions?): Model
	local rig = Kit.newRig(ID, opts)
	local function const(name: string): (number) -> string
		return function()
			return name
		end
	end

	rig:bone("Body", "Root", cf(0, 3.0, 0.1))
	rig:bone("Head", "Body", cf(0, 4.35, 0))
	rig:mirrored(function(side, sfx)
		rig:bone("Arm" .. sfx, "Body", cf(side * 0.72, 3.85, 0))
	end)

	rig:tube(BODY, {
		name = "Body",
		bone = const("Body"),
		core = P.core,
		coreStep = 0.3,
		cover = { A.fur(P.wisp, P.bloodDark, v3(0.3, 0.6, 0.46), 0.24, { arc = 180, tilt = 30, refRadius = 0.6, seed = 1 }) },
	})
	-- Mèches qui pendent sous la traîne
	A.tuftBurst(rig, "Body", cf(0, 1.25, 0.6) * ang(math.pi, 0, 0), 12, 0.9, 0.22, P.wisp, P.bloodDark, 35, 2)

	-- Épaules hérissées de cristaux
	rig:mirrored(function(side)
		A.crystals(rig, "Body", cf(A.mx(v3(0.62, 4.15, 0.05), side)) * ang(rad(-10), 0, -side * rad(35)), 5, 0.9, P.crystals, 5 + side, 0.4)
	end)

	-- Tête d'ombre
	rig:tube(HEAD, {
		name = "Head",
		bone = const("Head"),
		core = P.face,
		coreStep = 0.2,
		cover = { A.fur(P.wisp, P.bloodDark, v3(0.2, 0.36, 0.3), 0.18, { arc = 150, from = 2.0, tilt = 40, refRadius = 0.4, seed = 3 }) },
	})
	rig:mirrored(function(side)
		A.eye(rig, "Head", A.mx(v3(0.2, 4.88, -0.55), side), v3(side * 0.3, 0, -1), 0.17, "Glow", P.socket, P.eye)
		rig:wedge("Head", "Brow", cf(A.mx(v3(0.2, 5.02, -0.56), side)) * ang(0, 0, side * rad(28)), v3(0.3, 0.08, 0.16), P.core)
	end)
	rig:block("Head", "Mouth", cf(0, 4.62, -0.6) * ang(0, 0, 0), v3(0.36, 0.035, 0.04), P.blood)

	-- Couronne d'or sertie de gemmes rouges
	local crown = cf(0, 5.18, -0.12)
	rig:ring("Head", "Crown", crown * ang(math.pi / 2, 0, 0), 0.5, 0.1, 0.18, 16, P.gold)
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2
		local p = crown * ang(0, a, 0) * cf(0, 0.08, -0.5)
		rig:thorn("Head", "CrownSpike", p * ang(rad(-10), 0, 0), 0.16, if i % 2 == 0 then 0.6 else 0.4, P.gold)
		rig:shard("Head", "CrownGem", p * cf(0, -0.04, -0.06) * ang(rad(-80), 0, 0), 0.1, 0.06, 0.06, P.gem)
	end

	-- Bras griffus
	rig:mirrored(function(side, sfx)
		local arm = "Arm" .. sfx
		A.limb(rig, arm, side, {
			{ v3(0.72, 3.85, 0), 0.24, 0.24 },
			{ v3(1.4, 3.35, -0.3), 0.17, 0.17 },
			{ v3(1.8, 2.75, -0.65), 0.12, 0.12 },
		}, P.core, A.fur(P.wisp, P.bloodDark, v3(0.18, 0.3, 0.26), 0.15, { arc = 180, refRadius = 0.2, seed = 10 + side }))
		local hand = A.mx(v3(1.84, 2.68, -0.7), side)
		for k = -1, 1 do
			local dir = v3(side * (0.3 + k * 0.25), -1, -0.5).Unit
			rig:thorn(arm, "Claw", A.alongUp(hand, dir), 0.1, 0.55, P.claw)
			rig:thorn(arm, "ClawGlow", A.alongUp(hand + dir * 0.32, dir), 0.06, 0.28, P.blood)
		end
	end)

	-- Orbites : cristaux violets / fragments d'énergie rouges
	A.orbit(rig, "Aura1", v3(0, 3.3, 0.1), 3.0, 8, 0.6, function(bone, c, i)
		rig:shard(bone, "OrbitCrystal", c * ang(0, 0, rad(20)), 0.3, 0.8, 0.34, P.crystals[(i % 3) + 1])
	end)
	A.orbit(rig, "Aura2", v3(0, 3.8, 0.1), 2.1, 10, 0.5, function(bone, c, i)
		rig:shard(bone, "Fragment", c * ang(rad(30 * i), 0, rad(45)), 0.12, 0.22, 0.12, P.fragment)
	end)

	-- Cercle runique au sol
	A.flatRing(rig, "Root", v3(0, 0.04, 0.1), 2.6, 0.1, 0.03, 32, P.rune)
	A.flatRing(rig, "Root", v3(0, 0.04, 0.1), 2.0, 0.06, 0.03, 28, P.rune)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		A.rune(rig, "Root", cf(math.sin(a) * 2.3, 0.05, 0.1 - math.cos(a) * 2.3) * ang(-math.pi / 2, 0, 0) * ang(0, 0, a), 0.32, P.rune, i)
	end

	rig:hitbox(cf(0, 3.0, 0), v3(3.2, 4.6, 2))

	if rig.effects then
		local sc = rig.scale
		local aura = rig:anchor("Body", "FX_Aura", cf(0, 3.0, 0.1), v3(2.2, 3.4, 1.6))
		Fx.particles(aura, Fx.mist("BloodAura", { rgb(255, 40, 60), rgb(120, 0, 20) }, 16, 2.2, 0.6), sc)
		Fx.particles(aura, Fx.mist("VoidMist", { rgb(60, 20, 110), rgb(8, 2, 16) }, 10, 1.8, 0.1), sc)
		Fx.particles(aura, Fx.sparkles("VoidSparks", { rgb(220, 140, 255), rgb(255, 60, 90) }, 10, 0.24), sc)
		Fx.light(aura, { color = rgb(255, 40, 60), range = 18, brightness = 2 }, sc)
	end

	return rig:finish({ Rarity = "Mythic" })
end

local Def: Types.CreatureDef = {
	Id = ID,
	DisplayName = "Néant Couronné",
	Rarity = "Mythic",
	Zone = "GrottesCristal",
	Scale = 2.4,
	Category = "Créature Mythique",
	Description = "Créature suprême venue du néant. Une aura rouge sang l'entoure et des cristaux gravitent autour de sa couronne.",
	Icon = { top = rgb(110, 10, 30), bottom = rgb(10, 0, 8), glow = rgb(255, 60, 90), motif = rgb(170, 80, 255), yaw = 24, pitch = 8, zoom = 1.05 },
	Animation = { gait = "Hover", hover = 0.25, headLook = 14, auraSpeed = 0.5 },
	build = build,
}

return Def
