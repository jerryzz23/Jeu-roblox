--!strict
--[[
	CreatureForge.Anatomy
	---------------------
	Pièces anatomiques et ornements réutilisables, construits avec le Kit :
	membres (tubes), pattes griffues, sabots, yeux, oreilles, cornes/défenses, dents,
	crêtes d'épines, touffes, flammes, plumes et ailes, cristaux, engrenages, runes,
	anneaux au sol et objets en orbite (aura).

	Conventions : espace modèle (la créature regarde vers -Z, +X = droite, sol à Y = 0).
	Les fonctions "côté droit" prennent `side` (+1 droite / -1 gauche) et miroitent X.
]]

local Kit = require(script.Parent.Kit)

type Rig = Kit.Rig
type Style = Kit.Style
type Spine = Kit.Spine

local A = {}

local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles
local rad = math.rad

--- Miroir d'un point selon le côté (+1 droite, -1 gauche).
function A.mx(v: Vector3, side: number): Vector3
	return v3(side * v.X, v.Y, v.Z)
end

--- Repère dont +Y pointe le long de `dir` (pour pointes, plumes, flammes).
function A.alongUp(pos: Vector3, dir: Vector3): CFrame
	return Kit.lookAlong(pos, dir) * ang(-math.pi / 2, 0, 0)
end

-- ---------------------------------------------------------------------------
-- Revêtements prêts à l'emploi
-- ---------------------------------------------------------------------------

--- Fourrure en mèches pointues (style "mammouth / loup") avec pointes colorées.
function A.fur(shades: { Style }, tip: Style?, size: Vector3?, spacing: number?, extra: { [string]: any }?): Kit.Cover
	local c: Kit.Cover = {
		kind = "Tuft",
		size = size or v3(0.22, 0.4, 0.36),
		spacing = spacing or 0.2,
		arc = 125,
		shades = shades,
		tip = tip,
		tilt = 50,
		refRadius = 0.5,
		jitter = 0.75,
	}
	if extra then
		for k, v in extra do
			(c :: any)[k] = v
		end
	end
	return c
end

--- Écailles plates imbriquées.
function A.scales(shades: { Style }, size: Vector3?, spacing: number?, extra: { [string]: any }?): Kit.Cover
	local c: Kit.Cover = {
		kind = "Scale",
		size = size or v3(0.26, 0.1, 0.28),
		spacing = spacing or 0.21,
		arc = 115,
		shades = shades,
		tilt = 20,
		refRadius = 0.45,
		jitter = 0.35,
	}
	if extra then
		for k, v in extra do
			(c :: any)[k] = v
		end
	end
	return c
end

-- ---------------------------------------------------------------------------
-- Membres et extrémités
-- ---------------------------------------------------------------------------

export type LimbPoint = { Vector3 | number }

--- Membre en tube : `path` = { {position, rx, ry}, ... } du haut (hanche) vers le bas (cheville),
--- coordonnées du côté DROIT (miroitées si side = -1).
function A.limb(rig: Rig, bone: string, side: number, path: { { any } }, core: Style, cover: Kit.Cover?): Spine
	local sections = {}
	for _, p in path do
		table.insert(sections, { pos = A.mx(p[1] :: Vector3, side), rx = p[2] :: number, ry = p[3] :: number })
	end
	-- Genou / coude : les pattes ("Leg…") et les bras ("Arm…") à 3 points ou plus reçoivent une
	-- articulation au 2e point (os "<os>_Knee"). Tout ce qui est construit ensuite sur cet os
	-- au-delà de l'articulation (bas de la patte, pied, griffes, bracelets) s'y rattache tout seul.
	if #sections >= 3 and (string.sub(bone, 1, 3) == "Leg" or string.sub(bone, 1, 3) == "Arm") then
		rig:joint(bone, sections[1].pos, sections[2].pos)
	end
	local spine = Kit.spine(sections)
	rig:tube(spine, {
		name = "Limb",
		bone = function()
			return bone
		end,
		core = core,
		coreStep = 0.22,
		cover = if cover then { cover } else nil,
	})
	return spine
end

--- Patte griffue posée au sol en `pos`, orientée vers `fwd`.
function A.paw(rig: Rig, bone: string, pos: Vector3, fwd: Vector3, size: number, toes: number, pad: Style, toe: Style, claw: Style)
	local f = v3(fwd.X, 0, fwd.Z).Unit
	local right = f:Cross(Vector3.yAxis).Unit
	local base = CFrame.fromMatrix(pos, right, Vector3.yAxis, -f)
	rig:prism(bone, "Paw", base * cf(0, 0.2 * size, 0.05 * size), v3(size, 0.4 * size, 1.05 * size), 0.15 * size, pad)
	for i = 1, toes do
		local x = if toes == 1 then 0 else ((i - 1) / (toes - 1) - 0.5) * size * 0.78
		rig:ball(bone, "Toe", (base * cf(x, 0.18 * size, -0.48 * size)).Position, 0.36 * size, toe)
		rig:wedge(bone, "Claw", base * cf(x, 0.1 * size, -0.74 * size), v3(0.12, 0.18, 0.3) * size, claw)
	end
end

--- Sabot (octogonal) avec fente avant, cerclage et touffe de fanon optionnelle.
function A.hoof(rig: Rig, bone: string, pos: Vector3, size: number, hoof: Style, notch: Style, rim: Style?, tuft: { Style }?)
	local base = cf(pos)
	rig:prism(bone, "Hoof", base * cf(0, 0.22 * size, 0) * ang(-math.pi / 2, 0, 0), v3(size, size * 0.92, 0.44 * size), 0.28 * size, hoof)
	rig:block(bone, "HoofNotch", base * cf(0, 0.2 * size, -0.43 * size), v3(0.07, 0.4, 0.1) * size, notch)
	if rim then
		rig:ring(bone, "HoofRim", base * cf(0, 0.46 * size, 0) * ang(math.pi / 2, 0, 0), 0.47 * size, 0.09 * size, 0.09 * size, 10, rim)
	end
	if tuft then
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local dir = v3(math.cos(a) * 0.8, -0.35, math.sin(a) * 0.8).Unit
			rig:spike(bone, "Fetlock", A.alongUp(pos + v3(math.cos(a), 0, math.sin(a)) * 0.4 * size + v3(0, 0.62 * size, 0), dir) * ang(0, rad(90), 0), 0.22 * size, 0.38 * size, 0.06 * size, tuft[(i % #tuft) + 1])
		end
	end
end

-- ---------------------------------------------------------------------------
-- Tête
-- ---------------------------------------------------------------------------

export type EyeKind = "Round" | "Slit" | "Glow"

--- Œil : orbite sombre, iris, pupille (ronde ou fendue) et reflet. `outward` = direction du regard.
function A.eye(rig: Rig, bone: string, pos: Vector3, outward: Vector3, size: number, kind: EyeKind, socket: Style, iris: Style, pupil: Style?)
	local o = outward.Unit
	rig:ball(bone, "EyeSocket", pos - o * size * 0.18, size * 1.32, socket)
	rig:ball(bone, "Eye", pos, size, iris)
	if kind == "Round" and pupil then
		rig:ball(bone, "Pupil", pos + o * size * 0.3, size * 0.52, pupil)
	elseif kind == "Slit" and pupil then
		rig:block(bone, "Pupil", Kit.lookAlong(pos + o * size * 0.44, o), v3(0.14, 0.78, 0.08) * size, pupil)
	end
	if kind ~= "Glow" then
		rig:ball(bone, "EyeGlint", pos + o * size * 0.42 + v3(0, size * 0.2, 0) - Vector3.zAxis * size * 0.08, size * 0.22, Kit.style(Color3.new(1, 1, 1), Enum.Material.Neon))
	end
end

--- Sourcil / arcade en biseau au-dessus de l'œil (côté droit, miroité).
function A.brow(rig: Rig, bone: string, side: number, pos: Vector3, width: number, angle: number, style: Style)
	rig:wedge(bone, "Brow", cf(A.mx(pos, side)) * ang(0, side * rad(-12), side * rad(angle)), v3(width, width * 0.32, width * 0.55), style)
end

--- Oreille pointue : face externe, intérieur coloré, pointe d'une autre couleur.
function A.ear(rig: Rig, bone: string, base: CFrame, w: number, h: number, outer: Style, inner: Style, tip: Style?)
	local t = w * 0.16
	rig:spike(bone, "Ear", base, w, h, t, outer)
	rig:spike(bone, "EarInner", base * cf(0, h * 0.08, -t * 0.6), w * 0.62, h * 0.66, t * 0.6, inner)
	if tip then
		rig:spike(bone, "EarTip", base * cf(0, h * 0.6, 0), w * 0.44, h * 0.42, t * 1.25, tip)
	end
end

--- Corne / défense / bois : tube courbe effilé de r0 à r1, pointe, bagues optionnelles.
function A.horn(
	rig: Rig,
	bone: string,
	pts: { Vector3 },
	r0: number,
	r1: number,
	style: Style,
	bandStyle: Style?,
	bandAt: { number }?
): Spine
	local sections = {}
	for i, p in pts do
		local t = (i - 1) / math.max(#pts - 1, 1)
		local r = r0 + (r1 - r0) * t
		table.insert(sections, { pos = p, rx = r, ry = r })
	end
	local spine = Kit.spine(sections)
	rig:tube(spine, {
		name = "Horn",
		bone = function()
			return bone
		end,
		core = style,
		coreStep = math.max(r0 * 1.4, 0.08),
	})
	local last, prev = pts[#pts], pts[#pts - 1]
	rig:thorn(bone, "HornTip", A.alongUp(last, last - prev), r1 * 2.4, r1 * 4, style)
	if bandStyle and bandAt then
		for _, u in bandAt do
			local rx = spine:radii(u)
			rig:band(spine, bone, "HornBand", u, rx * 0.7, rx * 0.35, bandStyle)
		end
	end
	return spine
end

--- Rangée de crocs/dents entre `a` et `b` (pointe vers le bas si `down`).
function A.teeth(rig: Rig, bone: string, a: Vector3, b: Vector3, count: number, w: number, h: number, style: Style, down: boolean)
	for i = 1, count do
		local p = if count == 1 then a else a:Lerp(b, (i - 1) / (count - 1))
		local hh = h * (if i % 2 == 0 then 0.75 else 1)
		rig:thorn(bone, "Tooth", cf(p) * (if down then ang(math.pi, 0, 0) else CFrame.identity), w, hh, style)
	end
end

--- Moustaches (côté droit, miroitées) partant de `root`.
function A.whiskers(rig: Rig, bone: string, side: number, root: Vector3, length: number, style: Style)
	for k = -1, 1 do
		local a = A.mx(root + v3(0, k * 0.04, 0), side)
		local b = A.mx(root + v3(length, k * 0.12 + 0.03, length * 0.35 + k * 0.06), side)
		rig:strut(bone, "Whisker", a, b, 0.022, 0.022, style)
	end
end

-- ---------------------------------------------------------------------------
-- Épines, touffes, flammes
-- ---------------------------------------------------------------------------

--- Crête d'épines en dents de scie le long d'une colonne (angle `deg` autour de l'axe, 0 = dessus).
function A.crest(
	rig: Rig,
	spine: Spine,
	boneAt: (u: number) -> string,
	from: number,
	to: number,
	spacing: number,
	height: number,
	width: number,
	style: Style,
	tip: Style?,
	deg: number?,
	lean: number?
)
	local s, sEnd, i = spine:lengthAt(from), spine:lengthAt(to), 0
	while s < sEnd do
		local u = spine:uAt(s)
		local rx, ry = spine:radii(u)
		local k = math.clamp(math.min(rx, ry) / 0.3, 0.4, 1.3)
		local h = height * k * (if i % 2 == 0 then 1 else 0.68)
		local base = spine:surface(u, deg or 0, 0.03 * k) * ang(rad(lean or 34), 0, 0) * ang(0, math.pi / 2, 0)
		rig:spike(boneAt(u), "Crest", base, width * k, h, width * 0.25 * k, style)
		if tip then
			rig:spike(boneAt(u), "CrestTip", base * cf(0, h * 0.58, 0), width * 0.5 * k, h * 0.48, width * 0.34 * k, tip)
		end
		s += spacing * k
		i += 1
	end
end

--- Gerbe de mèches/épines rayonnant depuis `base` dans un cône autour de base.UpVector.
function A.tuftBurst(
	rig: Rig,
	bone: string,
	base: CFrame,
	count: number,
	length: number,
	width: number,
	styles: { Style },
	tip: Style?,
	spread: number,
	seed: number
)
	local rng = Random.new(seed)
	for i = 1, count do
		local yaw = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local tilt = rad(spread) * math.sqrt(rng:NextNumber(0.15, 1))
		local l = length * rng:NextNumber(0.7, 1.15)
		local c = base * ang(0, yaw, 0) * ang(0, 0, -tilt) * ang(0, rng:NextNumber(0, math.pi), 0)
		rig:spike(bone, "Tuft", c, width, l, width * 0.3, styles[(i % #styles) + 1])
		if tip then
			rig:spike(bone, "TuftTip", c * cf(0, l * 0.6, 0), width * 0.46, l * 0.44, width * 0.4, tip)
		end
	end
end

--- Flamme stylisée : trois pointes en croix imbriquées (extérieur, milieu, cœur lumineux).
function A.flame(rig: Rig, bone: string, base: CFrame, h: number, w: number, outer: Style, mid: Style, core: Style)
	rig:thorn(bone, "Flame", base, w, h, outer)
	rig:thorn(bone, "Flame", base * cf(0, h * 0.06, 0), w * 0.66, h * 0.8, mid)
	rig:thorn(bone, "FlameCore", base * cf(0, h * 0.1, 0), w * 0.36, h * 0.55, core)
end

--- Triangle quelconque (2 WedgeParts) : membranes d'ailes, voiles, éclats plats.
function A.triangle(rig: Rig, bone: string, name: string, a: Vector3, b: Vector3, c: Vector3, thickness: number, style: Style)
	-- La base est l'arête la plus longue ; on abaisse la hauteur depuis le sommet opposé.
	local pts = { { a, b, c }, { b, c, a }, { c, a, b } }
	local best = pts[1]
	for _, p in pts do
		if (p[2] - p[1]).Magnitude > (best[2] - best[1]).Magnitude then
			best = p
		end
	end
	local p0, p1, apex = best[1], best[2], best[3]
	local base = p1 - p0
	local t = (apex - p0):Dot(base) / base:Dot(base)
	local foot = p0 + base * t
	local h = (apex - foot).Magnitude
	if h < 1e-3 then
		return
	end
	local up = (apex - foot).Unit
	for _, q in { p0, p1 } do
		local leg = (q - foot).Magnitude
		if leg > 1e-3 then
			rig:wedgeTri(bone, name, foot, up, (q - foot).Unit, h, leg, thickness, style)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Plumes et ailes
-- ---------------------------------------------------------------------------

--- Plume en losange posée sur un repère : +Y = direction de la plume, Z = épaisseur.
function A.feather(rig: Rig, bone: string, base: CFrame, length: number, width: number, style: Style, tip: Style?)
	rig:spike(bone, "Feather", base * ang(math.pi, 0, 0), width, length * 0.18, 0.025, style)
	rig:spike(bone, "Feather", base, width, length, 0.03, style)
	if tip then
		rig:spike(bone, "FeatherTip", base * cf(0, length * 0.62, 0), width * 0.42, length * 0.4, 0.04, tip)
	end
end

export type WingSpec = {
	arm: { Vector3 }, -- épaule -> coude -> poignet -> bout (côté droit)
	armRadius: number,
	feathers: number, -- nombre de rémiges
	length: { number }, -- longueur des plumes : épaule, bout
	width: number,
	sweep: number, -- angle des plumes vers l'arrière au bout de l'aile (degrés)
	rows: { { Style } }, -- rangées : { rémiges }, { couvertures }, { petites couvertures }
	tip: Style?,
	armStyle: Style,
	pose: CFrame?, -- transformation appliquée à toute l'aile (ex. aile relevée), en espace modèle
}

--- Aile déployée (côté `side`) : bras en tube + 3 rangées de plumes imbriquées.
function A.wing(rig: Rig, bone: string, side: number, spec: WingSpec)
	local pose = spec.pose or CFrame.identity
	local pts = {}
	for _, p in spec.arm do
		table.insert(pts, pose * A.mx(p, side))
	end
	local sections = {}
	for i, p in pts do
		local r = spec.armRadius * (1 - (i - 1) / #pts * 0.6)
		table.insert(sections, { pos = p, rx = r, ry = r * 0.8 })
	end
	local arm = Kit.spine(sections)
	rig:tube(arm, {
		name = "WingArm",
		bone = function()
			return bone
		end,
		core = spec.armStyle,
		coreStep = 0.2,
	})

	local back = Vector3.zAxis
	for r, row in spec.rows do
		local n = math.max(3, math.floor(spec.feathers * (1 - (r - 1) * 0.25)))
		local scale = 1 - (r - 1) * 0.38
		for i = 1, n do
			local t = (i - 1) / (n - 1)
			local u = 1 + t * (#pts - 1)
			local p = arm:pos(u)
			local outward = pose:VectorToWorldSpace(v3(side, 0, 0))
			local sweep = rad(spec.sweep) * t
			local dir = (pose:VectorToWorldSpace(back) * math.cos(sweep) + outward * math.sin(sweep)).Unit
			local len = (spec.length[1] + (spec.length[2] - spec.length[1]) * (t ^ 1.4)) * scale
			local normal = pose:VectorToWorldSpace(Vector3.yAxis)
			local right = dir:Cross(normal).Unit
			local base = CFrame.fromMatrix(p + normal * 0.02 * (r - 1), right, dir, right:Cross(dir))
			local style = row[(i % #row) + 1]
			A.feather(rig, bone, base, len, spec.width * (0.85 + 0.3 * scale), style, if r == 1 then spec.tip else nil)
		end
	end
end

--- Éventail de plumes (queue d'oiseau) partant de `base` (+Z local = vers l'arrière).
function A.featherFan(rig: Rig, bone: string, base: CFrame, count: number, length: number, width: number, spread: number, styles: { Style }, tip: Style?)
	for i = 1, count do
		local t = if count == 1 then 0 else (i - 1) / (count - 1) - 0.5
		local dir = (base * ang(0, -t * rad(spread), 0)):VectorToWorldSpace(Vector3.zAxis)
		local right = dir:Cross(base.UpVector).Unit
		local fb = CFrame.fromMatrix(base.Position + base.UpVector * 0.01 * i, right, dir, base.UpVector)
		A.feather(rig, bone, fb, length * (1 - math.abs(t) * 0.35), width, styles[(i % #styles) + 1], tip)
	end
end

-- ---------------------------------------------------------------------------
-- Ornements : cristaux, engrenages, runes, anneaux, orbites
-- ---------------------------------------------------------------------------

--- Grappe de cristaux autour de base.UpVector (le plus grand au centre).
function A.crystals(rig: Rig, bone: string, base: CFrame, count: number, size: number, styles: { Style }, seed: number, spread: number?)
	local rng = Random.new(seed)
	for i = 1, count do
		local h, pos, yaw, tilt
		if i == 1 then
			h, pos, yaw, tilt = size, Vector3.zero, 0, rad(rng:NextNumber(0, 10))
		else
			local a = (i - 1) / (count - 1) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
			local r = (spread or 0.35) * size * rng:NextNumber(0.6, 1)
			h = size * rng:NextNumber(0.4, 0.75)
			pos = v3(math.cos(a) * r, 0, math.sin(a) * r)
			yaw = -a
			tilt = rad(rng:NextNumber(18, 40))
		end
		local c = base * cf(pos) * ang(0, yaw, 0) * ang(0, 0, -tilt) * ang(0, rng:NextNumber(0, 1.5), 0)
		rig:shard(bone, "Crystal", c, h * 0.3, h * 0.72, h * 0.34, styles[((i - 1) % #styles) + 1])
	end
end

--- Engrenage dans le plan XY de `cf` (axe = Z) : couronne, dents, rayons, moyeu.
function A.gear(rig: Rig, bone: string, c: CFrame, radius: number, teeth: number, thickness: number, style: Style, hub: Style?)
	rig:ring(bone, "Gear", c, radius * 0.8, radius * 0.24, thickness, math.max(teeth, 10), style)
	for i = 0, teeth - 1 do
		local a = i / teeth * math.pi * 2
		rig:block(bone, "GearTooth", c * ang(0, 0, a) * cf(radius * 1.0, 0, 0), v3(radius * 0.26, radius * 0.22, thickness), style)
	end
	for i = 0, 2 do
		rig:block(bone, "GearSpoke", c * ang(0, 0, i * math.pi / 3), v3(radius * 1.5, radius * 0.13, thickness * 0.8), style)
	end
	rig:cylinder(bone, "GearHub", (c * cf(0, 0, -thickness * 0.75)).Position, (c * cf(0, 0, thickness * 0.75)).Position, radius * 0.38, hub or style)
end

local RUNES: { { { number } } } = {
	{ { 0, -1, 0, 1 }, { 0, 0.3, 0.65, 0.9 }, { 0, -0.1, 0.65, 0.5 } }, -- ᚠ
	{ { -0.5, -1, -0.5, 1 }, { -0.5, 1, 0.5, 0.2 }, { 0.5, 0.2, -0.5, -0.4 } }, -- ᚦ
	{ { 0, -1, 0, 1 }, { -0.6, 0.5, 0.6, -0.5 }, { -0.6, -0.5, 0.6, 0.5 } }, -- ᛟ-like
	{ { -0.45, -1, -0.45, 1 }, { 0.45, -1, 0.45, 1 }, { -0.45, 0.6, 0.45, 0 } }, -- ᛗ
	{ { 0, -1, 0, 1 }, { 0, 1, 0.6, 0.4 }, { 0, 1, -0.6, 0.4 } }, -- ᛏ
	{ { -0.6, 1, 0.6, -1 }, { 0.6, 1, -0.6, -1 } }, -- ᚷ
}

--- Rune lumineuse dans le plan XY de `c` (face visible vers -Z local). `pattern` de 1 à 6.
function A.rune(rig: Rig, bone: string, c: CFrame, size: number, style: Style, pattern: number)
	local glyph = RUNES[((pattern - 1) % #RUNES) + 1]
	for _, st in glyph do
		local a = (c * cf(st[1] * size * 0.5, st[2] * size * 0.5, 0)).Position
		local b = (c * cf(st[3] * size * 0.5, st[4] * size * 0.5, 0)).Position
		local mid = (a + b) / 2
		local dir = (b - a)
		local up = dir.Unit
		local right = up:Cross(c.LookVector).Unit
		rig:block(bone, "Rune", CFrame.fromMatrix(mid, right, up, right:Cross(up)), v3(size * 0.13, dir.Magnitude + size * 0.1, size * 0.05), style)
	end
end

--- Anneau horizontal (ex. onde au sol, halo) centré en `center`.
function A.flatRing(rig: Rig, bone: string, center: Vector3, radius: number, width: number, height: number, segments: number, style: Style)
	rig:ring(bone, "Ring", cf(center) * ang(math.pi / 2, 0, 0), radius, width, height, segments, style)
end

--- Objets en orbite : crée l'os `name` (enfant de Root, tourné par l'animateur) au centre
--- `center`, puis appelle `builder(name, repère, index)` pour chaque objet (+X local = vers l'extérieur).
function A.orbit(rig: Rig, name: string, center: Vector3, radius: number, count: number, wobble: number, builder: (bone: string, c: CFrame, i: number) -> ())
	rig:bone(name, "Root", cf(center))
	for i = 1, count do
		local a = (i - 1) / count * math.pi * 2
		local y = math.sin(a * 2 + i) * wobble
		builder(name, cf(center + v3(math.cos(a) * radius, y, math.sin(a) * radius)) * ang(0, -a, 0), i)
	end
end

return A
