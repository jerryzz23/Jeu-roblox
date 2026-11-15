--!strict
--[[
	CreatureForge.Cube — briques du style « cubes + pixels »
	=======================================================
	Tous les personnages sont faits de gros cubes dont **chaque face est couverte de texture**
	(écailles, fourrure, plumes, pierre, lave, cristal, rayures, taches, armure, cratères, étoiles…)
	en pixels plaqués, comme le Gardien lunaire.

	    local fur = Cube.skin(rgb(150, 150, 160), Cube.fur(), { glow = { rgb(255, 120, 40) } })
	    Cube.box(rig, "Body", "Body", CFrame.new(0, 1.5, 0), Vector3.new(1.2, 1, 2), fur)
	    Cube.leg(rig, "Leg_FR", Vector3.new(0.4, 1.1, -0.6), { skin = fur, foot = "paw" })

	Une texture (« pattern ») est une fonction (w, h, px, graine) -> (i, j) -> caractère :
	D = gravure sombre, L = reflet clair, K = teinte intermédiaire, "1".."5" = pixels lumineux
	(couleurs `glow` de la peau), "." = rien.
]]

local Kit = require(script.Parent.Kit)
local A = require(script.Parent.Anatomy)
local Pixel = require(script.Parent.Pixel)

type Rig = Kit.Rig
type Style = Kit.Style
export type Pattern = (w: number, h: number, px: number, seed: number) -> (i: number, j: number) -> string
export type Skin = {
	base: Style,
	dark: Style,
	light: Style,
	mid: Style,
	glow: { Style },
	pattern: Pattern?,
	px: number,
	chips: boolean,
}

local S = Kit.style
local M = Enum.Material
local v3 = Vector3.new
local cf = CFrame.new
local ang = CFrame.Angles
local rad = math.rad
local hash = Pixel.hash
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)

local Cube = {}

-- ===========================================================================
-- Peaux
-- ===========================================================================

--- Peau d'un cube : couleur de base, texture et options.
--- opts.material, opts.glow (couleurs Néon des pixels lumineux), opts.px (taille des pixels),
--- opts.dark / opts.light / opts.mid (couleurs des gravures), opts.chips (éclats sur les arêtes).
function Cube.skin(color: Color3, pattern: Pattern?, opts: { [string]: any }?): Skin
	local o = opts or {}
	local mat = o.material
	local glow = {}
	for i, c in (o.glow or {}) :: { Color3 } do
		glow[i] = S(c, M.Neon)
	end
	return {
		base = S(color, mat),
		dark = S(o.dark or color:Lerp(BLACK, o.darkK or 0.27), mat),
		light = S(o.light or color:Lerp(WHITE, o.lightK or 0.25), mat),
		mid = S(o.mid or color:Lerp(BLACK, 0.14), mat),
		glow = glow,
		pattern = pattern,
		px = o.px or 0.07,
		chips = o.chips ~= false,
	}
end

--- Même peau, autre couleur / texture.
function Cube.variant(skin: Skin, pattern: Pattern?, px: number?): Skin
	local s = table.clone(skin)
	s.pattern = pattern
	s.px = px or skin.px
	return s
end

-- ===========================================================================
-- Textures
-- ===========================================================================

--- Écailles en quinconce (une sur `glowEvery` brille, 0 = aucune).
function Cube.scales(glowEvery: number?, sw: number?, sr: number?): Pattern
	return function(_w, _h, _px, seed)
		return Pixel.scales(sw or 4, sr or 3, glowEvery or 0, seed)
	end
end

--- Fourrure : petites mèches verticales sombres et claires (+ quelques pixels lumineux).
function Cube.fur(glowEvery: number?): Pattern
	return function(_w, _h, _px, seed)
		return function(i, j)
			local o = hash(i, 0, seed) % 5
			local k = (j + o) % 5
			if k <= 1 then
				local h = hash(i, (j + o) // 5, seed)
				if glowEvery and glowEvery > 0 and h % glowEvery == 0 then
					return tostring(1 + (h // glowEvery) % 3)
				end
				local r = h % 4
				if r == 0 then
					return "D"
				elseif r == 1 then
					return "L"
				end
			end
			return "."
		end
	end
end

--- Plumes : rangées de plumes qui se chevauchent, nervure centrale.
function Cube.feathers(glowEvery: number?): Pattern
	return function(_w, _h, _px, seed)
		local scale = Pixel.scales(5, 4, glowEvery or 0, seed)
		return function(i, j)
			local band = (j - 1) // 4
			local u = (i - 1 + (band % 2) * 2) % 5
			if u == 2 and (j - 1) % 4 < 2 then
				return "K"
			end
			return scale(i, j)
		end
	end
end

--- Pierre / granit : grain en trois teintes et quelques fissures.
function Cube.stone(cracks: number?): Pattern
	return function(w, h, px, seed)
		local cols, rows = math.floor(w / px), math.floor(h / px)
		local crack: { [number]: boolean } = {}
		local rng = Random.new(seed)
		for _ = 1, cracks or math.max(1, (cols * rows) // 90) do
			local x, y = rng:NextInteger(1, math.max(cols, 1)), rng:NextInteger(1, math.max(rows, 1))
			for _ = 1, rng:NextInteger(3, 7) do
				crack[y * 1000 + x] = true
				x += rng:NextInteger(-1, 1)
				y += 1
			end
		end
		return function(i, j)
			if crack[j * 1000 + i] then
				return "D"
			end
			local r = hash(i, j, seed) % 100
			if r < 9 then
				return "D"
			elseif r < 15 then
				return "L"
			elseif r < 25 then
				return "K"
			end
			return "."
		end
	end
end

--- Lave : pierre sombre traversée de fissures lumineuses ("1" orange, "2" jaune au cœur).
function Cube.lava(): Pattern
	return function(w, h, px, seed)
		local cols, rows = math.floor(w / px), math.floor(h / px)
		local crack: { [number]: string } = {}
		local rng = Random.new(seed)
		for _ = 1, math.max(1, (cols * rows) // 70) do
			local x, y = rng:NextInteger(1, math.max(cols, 1)), rng:NextInteger(1, math.max(rows, 1))
			for k = 1, rng:NextInteger(4, 9) do
				crack[y * 1000 + x] = if k % 3 == 0 then "2" else "1"
				if rng:NextNumber() < 0.5 then
					x += rng:NextInteger(-1, 1)
				else
					y += rng:NextInteger(-1, 1)
				end
			end
		end
		local stone = Cube.stone(0)(w, h, px, seed)
		return function(i, j)
			return crack[j * 1000 + i] or stone(i, j)
		end
	end
end

--- Cristal : facettes en diagonale et éclats lumineux.
function Cube.crystal(glowEvery: number?): Pattern
	return function(_w, _h, _px, seed)
		local g = glowEvery or 29
		return function(i, j)
			if (i + j + seed) % 6 == 0 then
				return "L"
			elseif (i - j + 90 + seed) % 9 == 0 then
				return "D"
			elseif hash(i, j, seed) % g == 0 then
				return "1"
			end
			return "."
		end
	end
end

--- Rayures ondulées (tigre, zèbre) sur fond de fourrure.
function Cube.stripes(period: number?, glow: boolean?): Pattern
	return function(w, h, px, seed)
		local fur = Cube.fur()(w, h, px, seed)
		local p = period or 6
		return function(i, j)
			local x = i + 1.6 * math.sin(j * 0.55 + seed)
			if math.floor(x) % p < 2 then
				return if glow then "1" else "D"
			end
			return fur(i, j)
		end
	end
end

--- Taches en rosettes (panthère, lynx) sur fond de fourrure.
function Cube.spots(glow: boolean?): Pattern
	return function(w, h, px, seed)
		local fur = Cube.fur()(w, h, px, seed)
		return function(i, j)
			local ci, cj = (i - 1) // 6, (j - 1) // 6
			local hx = hash(ci, cj, seed)
			local cx, cy = ci * 6 + 2 + hx % 3, cj * 6 + 2 + (hx // 3) % 3
			local d = math.sqrt((i - cx) ^ 2 + (j - cy) ^ 2)
			if d >= 1.2 and d <= 2.2 and hash(i, j, seed) % 4 ~= 0 then
				return "D"
			elseif d < 1.2 then
				return if glow then "1" else "K"
			end
			return fur(i, j)
		end
	end
end

--- Armure : panneaux bordés, rivets, rayures d'usure.
function Cube.plates(pw: number?, ph: number?): Pattern
	return function(_w, _h, _px, seed)
		local a, b = pw or 7, ph or 5
		return function(i, j)
			local u, v = (i - 1) % a, (j - 1) % b
			if u == 0 or v == 0 then
				return "D"
			elseif (u == 1 or u == a - 1) and (v == 1 or v == b - 1) then
				return "L"
			elseif hash(i, j, seed) % 31 == 0 then
				return "K"
			end
			return "."
		end
	end
end

--- Cratères de lune / roche volcanique.
function Cube.craters(density: number?): Pattern
	return function(w, h, px, seed)
		local cells = (w / px) * (h / px)
		return Pixel.craters(w, h, px, math.max(1, math.floor(cells / (density or 55))), 1.4, 3.2, seed)
	end
end

--- Ciel étoilé (Néant, Sphinx) : étoiles lumineuses et poussière.
function Cube.stars(): Pattern
	return function(_w, _h, _px, seed)
		return function(i, j)
			local r = hash(i, j, seed)
			if r % 41 == 0 then
				return "1"
			elseif r % 67 == 0 then
				return "2"
			elseif r % 13 == 0 then
				return "K"
			elseif r % 29 == 0 then
				return "L"
			end
			return "."
		end
	end
end

local GLYPHS = {
	{ "L.L", ".L.", "L.L" }, { "LLL", "L..", "LLL" }, { ".L.", "LLL", ".L." }, { "L..", "LLL", "..L" },
	{ "LL.", ".L.", ".LL" }, { "L.L", "LLL", "L.L" },
}
--- Runes gravées (et lumineuses une fois sur trois) semées sur la face.
function Cube.runes(base: Pattern?): Pattern
	return function(w, h, px, seed)
		local under = if base then base(w, h, px, seed) else nil
		return function(i, j)
			local bi, bj = (i - 1) // 5, (j - 1) // 5
			local u, v = (i - 1) % 5, (j - 1) % 5
			local hb = hash(bi, bj, seed)
			if hb % 3 == 0 and u >= 1 and u <= 3 and v >= 1 and v <= 3 then
				local g = GLYPHS[(hb // 3) % #GLYPHS + 1]
				if string.sub(g[v], u, u) == "L" then
					return if hb % 2 == 0 then "1" else "L"
				end
			end
			return if under then under(i, j) else "."
		end
	end
end

--- Superpose deux textures (la première l'emporte).
function Cube.mix(a: Pattern, b: Pattern): Pattern
	return function(w, h, px, seed)
		local fa, fb = a(w, h, px, seed), b(w, h, px, seed + 7)
		return function(i, j)
			local c = fa(i, j)
			return if c ~= "." then c else fb(i, j)
		end
	end
end

-- ===========================================================================
-- Cubes texturés
-- ===========================================================================

local FACES = { "top", "front", "back", "left", "right", "bottom" }

--- Plaque la texture de `skin` sur la face définie par `f` (repère Pixel.face) de w × h.
function Cube.texture(rig: Rig, bone: string, f: CFrame, w: number, h: number, skin: Skin, seed: number, px: number?)
	local p = px or skin.px
	if not skin.pattern or w < p * 3 or h < p * 3 then
		return
	end
	local pal: Pixel.Palette = {
		D = { skin.dark, 0.014 }, L = { skin.light, 0.022 }, K = { skin.mid, 0.016 },
	}
	for k = 1, 5 do
		pal[tostring(k)] = { skin.glow[k] or skin.glow[1] or skin.light, 0.02 }
	end
	local fn = (skin.pattern :: Pattern)(w - p, h - p, p, seed)
	Pixel.draw(rig, bone, f, p, Pixel.grid(w - p, h - p, p, fn), pal)
end

local function nameSeed(name: string): number
	local h = 0
	for k = 1, #name do
		h = (h * 31 + string.byte(name, k)) % 100003
	end
	return h
end

--- Cube texturé : un bloc `size` au repère `c`, chaque face (sauf le dessous par défaut) est
--- couverte de la texture de `skin`, avec des éclats sur les arêtes du dessus.
--- opts.faces = liste parmi top/front/back/left/right/bottom ; opts.seed ; opts.px ; opts.chips.
function Cube.box(rig: Rig, bone: string, name: string, c: CFrame, size: Vector3, skin: Skin, opts: { [string]: any }?): BasePart
	local o = opts or {}
	local part = rig:block(bone, name, c, size, skin.base)
	local R, U, B = c.RightVector, c.UpVector, -c.LookVector
	local function ext(d: Vector3): number
		return math.abs(R:Dot(d)) * size.X + math.abs(U:Dot(d)) * size.Y + math.abs(B:Dot(d)) * size.Z
	end
	local faces = o.faces or { "top", "front", "back", "left", "right" }
	local seed = (o.seed or 0) + nameSeed(name) + math.floor(c.Position.X * 13 + c.Position.Y * 7 + c.Position.Z * 3)
	for k, fname in faces do
		local n, up
		if fname == "top" then
			n, up = U, -B
		elseif fname == "bottom" then
			n, up = -U, -B
		elseif fname == "front" then
			n, up = -B, U
		elseif fname == "back" then
			n, up = B, U
		elseif fname == "left" then
			n, up = -R, U
		else
			n, up = R, U
		end
		local f = Pixel.face(c.Position + n * (ext(n) / 2), n, up)
		Cube.texture(rig, bone, f, ext(f.RightVector), ext(f.UpVector), skin, seed + k * 101, o.px)
	end
	-- éclats sur les deux longues arêtes du dessus
	local chips = if o.chips == nil then skin.chips else o.chips
	if chips then
		local long = if size.X > size.Z then R else B
		local across = if size.X > size.Z then B else R
		local len = if size.X > size.Z then size.X else size.Z
		local wid = if size.X > size.Z then size.Z else size.X
		local count = math.floor(len / 0.4)
		if count >= 2 and wid > 0.3 then
			local top = c.Position + U * (size.Y / 2)
			for _, sgn in { 1, -1 } do
				local edge = top + across * (sgn * wid / 2)
				Pixel.chips(rig, bone, edge - long * (len / 2 - 0.08), edge + long * (len / 2 - 0.08), count, math.min(0.14, skin.px * 1.7), { skin.dark, skin.light, skin.base }, seed + sgn * 7)
			end
		end
	end
	return part
end

--- Cube texturé tendu entre deux points (cou, os, segments) : section w × h, axe a -> b.
function Cube.boxBetween(rig: Rig, bone: string, name: string, a: Vector3, b: Vector3, w: number, h: number, skin: Skin, opts: { [string]: any }?): BasePart
	return Cube.box(rig, bone, name, Kit.lookAlong((a + b) / 2, b - a), v3(w, h, (b - a).Magnitude), skin, opts)
end

-- ===========================================================================
-- Membres et têtes
-- ===========================================================================

--- Patte droite verticale de la hanche `hip` au sol, avec genou (articulation) :
--- opts.skin, opts.w (largeur), opts.d (profondeur), opts.foot ("paw" | "hoof" | "claw" | "talon"),
--- opts.footSkin, opts.toe (style des griffes/sabot), opts.knee (hauteur relative, 0.5), opts.band.
function Cube.leg(rig: Rig, bone: string, hip: Vector3, opts: { [string]: any })
	local skin: Skin = opts.skin
	local w, d = opts.w or 0.4, opts.d or (opts.w or 0.4) * 1.08
	local footH = opts.footH or 0.16
	local kneeY = footH + (hip.Y - footH) * (opts.knee or 0.48)
	local knee = v3(hip.X, kneeY, hip.Z)
	rig:joint(bone, hip, knee)
	local upTop = hip.Y + (opts.overlap or 0.05)
	Cube.box(rig, bone, "UpperLeg", cf(hip.X, (upTop + kneeY) / 2, hip.Z), v3(w * 1.06, upTop - kneeY, d * 1.06), skin, { chips = false })
	if opts.band ~= false then
		rig:block(bone, "KneeBand", cf(hip.X, kneeY, hip.Z), v3(w * 1.16, 0.07, d * 1.16), opts.band or skin.light)
	end
	local low = (kneeY + footH) / 2
	Cube.box(rig, bone, "LowerLeg", cf(hip.X, low - 0.01, hip.Z + 0.005), v3(w, kneeY - footH, d), skin, { chips = false })
	local fs: Skin = opts.footSkin or skin
	local toe: Style = opts.toe or fs.dark
	local foot = opts.foot or "paw"
	local fz = hip.Z - d * 0.12
	if foot == "hoof" then
		rig:block(bone, "Hoof", cf(hip.X, footH / 2, hip.Z), v3(w * 1.08, footH, d * 1.08), toe)
		rig:block(bone, "HoofNotch", cf(hip.X, footH / 2, hip.Z - d * 0.545), v3(w * 0.12, footH * 0.9, 0.02), fs.dark)
		rig:block(bone, "HoofRim", cf(hip.X, footH + 0.02, hip.Z), v3(w * 1.14, 0.05, d * 1.14), fs.light)
	else
		Cube.box(rig, bone, "Foot", cf(hip.X, footH / 2, fz), v3(w * 1.08, footH, d * 1.25), fs, { faces = { "top", "front" }, chips = false })
		local n = if foot == "talon" then 3 else 3
		for t = 1, n do
			local x = hip.X + (t - (n + 1) / 2) * w * 0.33
			local z = fz - d * 0.65
			if foot == "paw" then
				rig:block(bone, "Toe", cf(x, footH * 0.55, z + 0.03), v3(w * 0.24, footH * 0.6, 0.07), fs.dark)
			else
				rig:block(bone, "Claw", cf(x, footH * 0.5, z) * ang(rad(45), 0, 0), v3(w * 0.2, footH * 0.7, footH * 0.7), toe)
			end
		end
	end
end

--- Œil plaqué sur une face (normale `n`) : "round" (rond lumineux, style Gardien),
--- "square" (pixel carré), "slit" (pupille fendue). colors = { rim, white, iris, pupil? }.
function Cube.eye(rig: Rig, bone: string, at: Vector3, n: Vector3, size: number, kind: string, colors: { Style })
	local rim, white, iris, pupil = colors[1], colors[2], colors[3], colors[4]
	local out = n.Unit
	if kind == "round" then
		rig:cylinder(bone, "EyeRim", at, at + out * 0.015, size * 1.18, rim)
		rig:cylinder(bone, "EyeRing", at + out * 0.015, at + out * 0.03, size, white)
		rig:cylinder(bone, "Eye", at + out * 0.03, at + out * 0.045, size * 0.82, iris)
		if pupil then
			rig:cylinder(bone, "EyeCore", at + out * 0.045, at + out * 0.055, size * 0.38, pupil)
		end
	else
		local f = Pixel.face(at, out)
		rig:block(bone, "EyeRim", f * cf(0, 0, -0.008), v3(size * 1.25, size * 1.0, 0.016), rim)
		rig:block(bone, "Eye", f * cf(0, 0, -0.022), v3(size, size * 0.75, 0.014), white)
		if kind == "slit" then
			rig:block(bone, "Pupil", f * cf(0, 0, -0.032), v3(size * 0.2, size * 0.7, 0.012), pupil or iris)
		else
			rig:block(bone, "Iris", f * cf(size * 0.15, 0, -0.032), v3(size * 0.42, size * 0.55, 0.012), iris)
			if pupil then
				rig:block(bone, "Pupil", f * cf(size * 0.2, 0, -0.04), v3(size * 0.18, size * 0.28, 0.01), pupil)
			end
		end
	end
	-- petit reflet
	local f = Pixel.face(at, out)
	rig:block(bone, "EyeShine", f * cf(-size * 0.28, size * 0.22, -0.06), v3(size * 0.16, size * 0.16, 0.01), S(WHITE, M.Neon))
end

--- Oreille en escalier de voxels (triangle) : base au centre `base`, pointe vers `up`.
--- outer / inner = styles ; side = +1 / -1 (inclinaison vers l'extérieur).
function Cube.ear(rig: Rig, bone: string, base: Vector3, side: number, w: number, h: number, outer: Style, inner: Style, tilt: number?)
	local c = cf(base) * ang(0, 0, -side * rad(tilt or 12))
	local steps = 3
	for k = 0, steps - 1 do
		local f = 1 - k / steps
		local y = (k + 0.5) * h / steps
		rig:block(bone, "Ear", c * cf(0, y, 0), v3(w * f, h / steps, w * 0.32), outer)
		if k < steps - 1 then
			rig:block(bone, "EarInner", c * cf(0, y, -w * 0.165), v3(w * f * 0.55, h / steps, 0.02), inner)
		end
	end
end

--- Corne en cubes empilés le long de `dir`, avec anneaux et pointe.
function Cube.horn(rig: Rig, bone: string, base: Vector3, dir: Vector3, sizes: { number }, style: Style, ring: Style?, tip: Style?)
	local d = dir.Unit
	local p = base
	for k, s in sizes do
		local c = Kit.lookAlong(p + d * s * 0.5, d)
		rig:block(bone, "Horn", c, v3(s, s, s * 1.1), style)
		if ring then
			rig:block(bone, "HornRing", Kit.lookAlong(p + d * 0.02, d), v3(s * 1.1, s * 1.1, 0.04), ring)
		end
		p += d * s * 1.0
		if k == #sizes and tip then
			rig:block(bone, "HornTip", Kit.lookAlong(p + d * s * 0.3, d) * ang(0, 0, rad(45)), v3(s * 0.5, s * 0.5, s * 0.7), tip)
		end
	end
end

--- Pointe en losange (cube tourné de 45°) — crêtes, épines.
function Cube.spike(rig: Rig, bone: string, at: Vector3, size: number, style: Style, axis: Vector3?)
	local c = if axis then Kit.lookAlong(at, axis) else cf(at)
	rig:block(bone, "Spike", c * ang(rad(45), 0, 0), v3(size * 0.6, size, size), style)
end

--- Queue en cubes texturés le long d'une chaîne d'os (names = rig:boneChain, pts = ses points) :
--- le cube j est centré sur pts[j + 1], de taille sizes[j]. opts.spike (style), opts.belly (style),
--- opts.skins (une peau par cube, sinon `skin`).
function Cube.tail(rig: Rig, names: { string }, pts: { Vector3 }, sizes: { number }, skin: Skin, opts: { [string]: any }?)
	local o = opts or {}
	for j = 1, math.min(#names, #sizes) do
		local p = pts[j + 1]
		local nxt = pts[math.min(j + 2, #pts)]
		local dir = (nxt - pts[j]).Unit
		local c = Kit.lookAlong(p, dir)
		local s = sizes[j]
		local sk: Skin = if o.skins then o.skins[math.min(j, #o.skins)] else skin
		Cube.box(rig, names[j], "TailCube", c, v3(s, s * (o.flat or 0.9), s * 1.05), sk, { px = math.max(0.04, s / 8), chips = s > 0.3 })
		if o.belly then
			rig:block(names[j], "TailBelly", c * cf(0, -s * (o.flat or 0.9) / 2 - 0.015, 0), v3(s * 0.7, 0.03, s * 0.85), o.belly)
		end
		if o.spike then
			Cube.spike(rig, names[j], (c * cf(0, s * (o.flat or 0.9) / 2 + s * 0.14, 0)).Position, s * 0.42, o.spike, dir)
		end
	end
end

--- Aile « pixels » : bras S0 -> E, doigts E -> tips, membrane en carreaux (styleAt(p, t) avec
--- t = distance relative à l'épaule). Les carreaux couvrent les triangles entre les doigts.
function Cube.wing(rig: Rig, bone: string, S0: Vector3, E: Vector3, tips: { Vector3 }, R: Vector3, finger: Style, joint: Style, styleAt: (p: Vector3, t: number) -> Style?, step: number?)
	rig:strut(bone, "WingArm", S0, E, 0.18, 0.18, finger)
	rig:block(bone, "WingElbow", cf(E) * ang(rad(45), 0, rad(45)), v3(0.22, 0.22, 0.22), joint)
	for _, T in tips do
		rig:strut(bone, "WingFinger", E, T, 0.1, 0.1, finger)
		rig:block(bone, "WingJoint", Kit.lookAlong(E:Lerp(T, 0.5), T - E), v3(0.14, 0.14, 0.07), joint)
		rig:block(bone, "WingTip", Kit.lookAlong(T, T - E) * ang(0, 0, rad(45)), v3(0.11, 0.11, 0.2), joint)
	end
	local maxd = (tips[1] - S0).Magnitude
	local function at(p: Vector3): Style?
		return styleAt(p, (p - S0).Magnitude / maxd)
	end
	local tris = {}
	for k = 1, #tips - 1 do
		table.insert(tris, { E, tips[k], tips[k + 1] })
	end
	table.insert(tris, { E, tips[#tips], R })
	table.insert(tris, { S0, E, R })
	for _, t in tris do
		Pixel.tiles(rig, bone, t[1], t[2], t[3], step or 0.28, 0.05, at, "WingTile")
	end
end

--- Aile d'oiseau en plumes-planches : racine `root`, envergure vers `outward` (unitaire),
--- vers l'arrière `back`. rows = { { styles }, ... } (rangées de plumes, la 1re sur le dessus).
function Cube.featherWing(rig: Rig, bone: string, root: Vector3, outward: Vector3, back: Vector3, span: number, chord: number, count: number, styles: { Style }, accent: Style?)
	local up = outward:Cross(back).Unit
	if up.Y < 0 then
		up = -up
	end
	rig:strut(bone, "WingBone", root, root + outward * span, 0.16, 0.14, styles[1])
	for k = 1, count do
		local t = (k - 0.5) / count
		local len = chord * (0.55 + 0.75 * math.sin(math.pi * (0.25 + t * 0.6))) * (if k == count then 1.15 else 1)
		local p = root + outward * (span * t) + back * (len / 2) - up * (0.02 * k)
		local c = CFrame.fromMatrix(p, outward, up, -back)
		local st = styles[math.clamp(1 + math.floor(t * #styles), 1, #styles)]
		rig:block(bone, "Feather", c, v3(span / count * 1.08, 0.06, len), st)
		-- plume de couverture plus courte au-dessus, nervure claire
		rig:block(bone, "Covert", c * cf(0, 0.045, -len * 0.28), v3(span / count * 0.9, 0.04, len * 0.4), styles[1])
		if accent then
			rig:block(bone, "FeatherTip", c * cf(0, 0.012, len / 2 - 0.06), v3(span / count * 1.0, 0.07, 0.12), accent)
		end
	end
end

--- Grappe de cristaux (prismes) — réutilise Anatomy.crystals.
function Cube.crystals(rig: Rig, bone: string, base: CFrame, count: number, size: number, styles: { Style }, seed: number)
	A.crystals(rig, bone, base, count, size, styles, seed, 0.4)
end

--- Gemmes en losange en orbite (os `name`).
function Cube.orbitGems(rig: Rig, name: string, center: Vector3, radius: number, count: number, wobble: number, core: { Style }, shell: { Style }?, size: number?)
	local s = size or 0.2
	A.orbit(rig, name, center, radius, count, wobble, function(bone, c, i)
		local k = ((i - 1) % #core) + 1
		rig:block(bone, "Gem", c * ang(rad(45), 0, rad(45)), v3(s, s, s), core[k])
		if shell then
			rig:block(bone, "GemShell", c * ang(rad(45), 0, rad(45)), v3(s * 1.5, s * 1.5, s * 1.5), shell[((i - 1) % #shell) + 1])
		end
	end)
end

-- ===========================================================================
-- Gabarit de quadrupède
-- ===========================================================================

--- Construit les os et le corps d'un quadrupède en cubes texturés :
---   spec.body  = { c, size, skin, belly? }            (os Body)
---   spec.neck  = pivot de la tête (os Head)
---   spec.head  = { c, size, skin }
---   spec.snout = { size, y?, skin?, nose? }            (museau devant la tête)
---   spec.jaw   = true (os Jaw sous le museau)
---   spec.eyes  = { kind, size, colors, x, y, side? }  (side = sur les côtés de la tête)
---   spec.ears  = { w, h, outer, inner, x, z?, tilt? } (os Ear_R / Ear_L)
---   spec.legs  = { x, zf, zb, hipY, w, d?, skin, foot, footSkin?, toe?, knee? }
---   spec.tail  = { pts, sizes, skin, skins?, spike?, belly?, flat? }
--- Renvoie des repères utiles : snoutFront, headTop, headFront, tail (noms des os).
function Cube.quadruped(rig: Rig, spec: { [string]: any }): { [string]: any }
	local out: { [string]: any } = {}
	local b = spec.body
	rig:bone("Body", "Root", cf(b.c))
	rig:bone("Head", "Body", cf(spec.neck))
	local h = spec.head
	local headFront = h.c.Z - h.size.Z / 2
	local headTop = h.c.Y + h.size.Y / 2
	out.headFront, out.headTop = headFront, headTop
	local L = spec.legs
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		rig:bone("Leg_F" .. s, "Body", cf(side * L.x, L.hipY, L.zf))
		rig:bone("Leg_B" .. s, "Body", cf(side * L.x, L.hipY, L.zb))
		if spec.ears then
			rig:bone("Ear" .. sfx, "Head", cf(side * spec.ears.x, headTop, spec.ears.z or h.c.Z))
		end
	end)
	-- Corps
	Cube.box(rig, "Body", "Body", cf(b.c), b.size, b.skin)
	if b.belly then
		rig:block("Body", "Belly", cf(b.c - v3(0, b.size.Y / 2 + 0.015, 0)), v3(b.size.X * 0.8, 0.03, b.size.Z * 0.85), b.belly)
	end
	-- Tête et museau
	Cube.box(rig, "Head", "Head", cf(h.c), h.size, h.skin)
	local sn = spec.snout
	if sn then
		local sc = v3(0, h.c.Y + (sn.y or -h.size.Y * 0.2), headFront - sn.size.Z / 2 + 0.02)
		Cube.box(rig, "Head", "Snout", cf(sc), sn.size, sn.skin or h.skin, { chips = false })
		out.snoutCenter = sc
		out.snoutFront = sc - v3(0, 0, sn.size.Z / 2)
		if sn.nose then
			rig:block("Head", "Nose", cf(sc + v3(0, sn.size.Y / 2 - 0.05, -sn.size.Z / 2 - 0.02)), v3(sn.size.X * 0.36, 0.1, 0.06), sn.nose)
		end
		if spec.jaw then
			local jy = sc.Y - sn.size.Y / 2
			rig:bone("Jaw", "Head", cf(0, jy, headFront))
			Cube.box(rig, "Jaw", "Jaw", cf(sc.X, jy - 0.06, sc.Z + 0.02), v3(sn.size.X * 0.9, 0.12, sn.size.Z * 0.95), sn.skin or h.skin, { faces = { "front", "left", "right" }, chips = false })
		end
	else
		out.snoutFront = v3(0, h.c.Y, headFront)
	end
	-- Yeux
	local e = spec.eyes
	if e then
		rig:mirrored(function(side)
			if e.side then
				Cube.eye(rig, "Head", v3(side * h.size.X / 2, e.y, e.z or (h.c.Z - h.size.Z * 0.2)), v3(side, 0, 0), e.size, e.kind, e.colors)
			else
				Cube.eye(rig, "Head", v3(side * e.x, e.y, headFront), v3(0, 0, -1), e.size, e.kind, e.colors)
			end
		end)
	end
	-- Oreilles
	local ea = spec.ears
	if ea then
		rig:mirrored(function(side, sfx)
			Cube.ear(rig, "Ear" .. sfx, v3(side * ea.x, headTop - 0.02, ea.z or h.c.Z), side, ea.w, ea.h, ea.outer, ea.inner, ea.tilt)
		end)
	end
	-- Pattes
	rig:mirrored(function(side, sfx)
		local s = string.sub(sfx, 2)
		for key, z in { F = L.zf, B = L.zb } do
			Cube.leg(rig, "Leg_" .. key .. s, v3(side * L.x, L.hipY, z), {
				skin = L.skin, w = L.w, d = L.d, foot = L.foot, footSkin = L.footSkin, toe = L.toe,
				knee = L.knee, footH = L.footH, band = L.band,
			})
		end
	end)
	-- Queue
	local t = spec.tail
	if t then
		local names = rig:boneChain("Tail", "Body", t.pts)
		Cube.tail(rig, names, t.pts, t.sizes, t.skin, { skins = t.skins, spike = t.spike, belly = t.belly, flat = t.flat })
		out.tail = names
	end
	return out
end

return Cube
