--!strict
--[[
	CreatureForge.Pixel — outils du style « cubes + pixels »
	========================================================
	Motifs gravés en pixels sur les faces des cubes (le style du Gardien lunaire) :

	    local f = Pixel.face(centreDeLaFace, normale)          -- repère : -Z local = vers l'extérieur
	    Pixel.draw(rig, "Body", f, 0.08, { "..LL..", ".L..L." }, { L = { style, 0.03 } })
	    Pixel.tiles(rig, "Wing_R", a, b, c, 0.26, 0.05, function(p) return style end)

	`draw` fusionne les pixels voisins de même couleur d'une ligne (moins de pièces).
]]

local Kit = require(script.Parent.Kit)

type Rig = Kit.Rig
type Style = Kit.Style
--- Palette : caractère -> { style, épaisseur (studs, avant échelle) }
export type Palette = { [string]: { any } }

local v3 = Vector3.new
local cf = CFrame.new

local Pixel = {}

--- Repère d'une face : centre `center`, -Z local (LookVector) = `normal` (vers l'extérieur).
function Pixel.face(center: Vector3, normal: Vector3, up: Vector3?): CFrame
	local u = up or Vector3.yAxis
	if math.abs(normal.Unit:Dot(u)) > 0.99 then
		u = v3(0, 0, -1)
	end
	return CFrame.lookAt(center, center + normal, u)
end

--- Dessine un motif (lignes de caractères, de haut en bas) centré sur la face `face`.
--- Chaque caractère de `palette` devient un pixel en relief ; les autres sont vides.
function Pixel.draw(rig: Rig, bone: string, face: CFrame, px: number, rows: { string }, palette: Palette)
	local h = #rows
	for r, row in rows do
		local w = #row
		local c = 1
		while c <= w do
			local ch = string.sub(row, c, c)
			local pal = palette[ch]
			if pal then
				local c2 = c
				while c2 < w and string.sub(row, c2 + 1, c2 + 1) == ch do
					c2 += 1
				end
				local x = ((c + c2) / 2 - (w + 1) / 2) * px
				local y = ((h + 1) / 2 - r) * px
				local depth = pal[2] :: number
				rig:block(bone, "Pixel", face * cf(x, y, -depth / 2), v3((c2 - c + 1) * px, px, depth), pal[1])
				c = c2 + 1
			else
				c += 1
			end
		end
	end
end

--- Pixels isolés semés sur une face (texture), dans un rectangle w × h.
function Pixel.speckle(rig: Rig, bone: string, face: CFrame, w: number, h: number, count: number, px: number, styles: { Style }, seed: number)
	local rng = Random.new(seed)
	for i = 1, count do
		local x, y = rng:NextNumber(-w / 2, w / 2), rng:NextNumber(-h / 2, h / 2)
		rig:block(bone, "Speck", face * cf(x, y, -0.008), v3(px, px, 0.016), styles[(i % #styles) + 1])
	end
end

--- Croissant de lune (cornes vers le haut) : disque de rayon R moins un disque de rayon r décalé
--- de d vers le haut. S = corps, C = contour extérieur, K = cratère, E = petit croissant central.
function Pixel.crescent(R: number, r: number, d: number, emblem: boolean?): { string }
	local n = math.ceil(R)
	local function inShape(x: number, y: number): boolean
		return x * x + y * y <= R * R and x * x + (y - d) * (y - d) > r * r
	end
	local function outer(x: number, y: number): boolean
		return x * x + y * y > R * R
	end
	local function inEmblem(x: number, y: number): boolean
		return (x + 0.2) ^ 2 + (y - 0.6) ^ 2 <= 2.4 ^ 2 and (x - 1.0) ^ 2 + (y - 1.1) ^ 2 > 2.0 ^ 2
	end
	local rows = {}
	for y = n, -n, -1 do
		local row = {}
		for x = -n, n do
			local ch = "."
			if inShape(x, y) then
				if outer(x + 1, y) or outer(x - 1, y) or outer(x, y + 1) or outer(x, y - 1) then
					ch = "C"
				elseif (x * 7 + y * 13 + 40) % 5 == 0 then
					ch = "K"
				else
					ch = "S"
				end
			elseif emblem and inEmblem(x, y) then
				ch = "E"
			end
			table.insert(row, ch)
		end
		table.insert(rows, table.concat(row))
	end
	return rows
end

--- Rubans ondulés (aurore, vagues) : w colonnes × h lignes ; chaque onde = { amplitude,
--- période (colonnes), phase, ligne centrale, épaisseur }. La couleur suit la colonne :
--- le caractère n° k de `chars` (dégradé de gauche à droite).
function Pixel.waves(w: number, h: number, waves: { { number } }, chars: string): { string }
	local grid = table.create(h)
	for r = 1, h do
		grid[r] = string.rep(".", w)
	end
	local function set(r: number, c: number, ch: string)
		if r >= 1 and r <= h then
			grid[r] = string.sub(grid[r], 1, c - 1) .. ch .. string.sub(grid[r], c + 1)
		end
	end
	for c = 1, w do
		local ch = string.sub(chars, 1 + math.floor((c - 1) / w * #chars), 1 + math.floor((c - 1) / w * #chars))
		for _, wv in waves do
			local y = wv[4] + wv[1] * math.sin(2 * math.pi * c / wv[2] + wv[3])
			local r0 = math.floor(y + 0.5)
			for k = 0, (wv[5] or 1) - 1 do
				set(r0 + k, c, ch)
			end
		end
	end
	return grid
end

--- Petit hachage entier stable (motifs « aléatoires » mais identiques à chaque construction).
function Pixel.hash(a: number, b: number, seed: number?): number
	local h = (a * 73856093 + b * 19349663 + (seed or 0) * 83492791) % 2147483647
	h = (h * 48271) % 2147483647
	return h
end

--- Grille de motif couvrant une face de w × h studs avec des pixels de côté `px` :
--- `fn(i, j)` (colonne de gauche à droite, ligne de haut en bas) renvoie un caractère.
function Pixel.grid(w: number, h: number, px: number, fn: (i: number, j: number) -> string): { string }
	local cols, nrows = math.max(1, math.floor(w / px)), math.max(1, math.floor(h / px))
	local rows = table.create(nrows)
	for j = 1, nrows do
		local row = table.create(cols)
		for i = 1, cols do
			row[i] = fn(i, j)
		end
		rows[j] = table.concat(row)
	end
	return rows
end

--- Motif d'écailles en quinconce (écailles de `sw` × `sr` pixels) :
--- D = contour sombre de l'écaille, L = reflet clair, "1".."5" = écaille qui brille
--- (une sur `glowEvery` environ, couleur tirée parmi 5).
function Pixel.scales(sw: number, sr: number, glowEvery: number, seed: number): (number, number) -> string
	return function(i: number, j: number): string
		local band = (j - 1) // sr
		local off = (band % 2) * (sw // 2)
		local u = (i - 1 + off) % sw
		local v = (j - 1) % sr
		local h = Pixel.hash((i - 1 + off) // sw, band, seed)
		if v == sr - 1 then
			return if u == 0 then "." else "D"
		end
		if u == 0 then
			return "D"
		end
		if glowEvery > 0 and h % glowEvery == 0 and v < sr - 1 then
			return tostring(1 + (h // glowEvery) % 5)
		end
		if u == 1 and v == 0 then
			return "L"
		end
		return "."
	end
end

--- Cratères de lune semés sur une grille de w × h studs (pixels de côté px) : anneau sombre (D),
--- fond (K), reflet en haut à gauche (L). À utiliser avec Pixel.grid(w, h, px, ...).
function Pixel.craters(w: number, h: number, px: number, count: number, rmin: number, rmax: number, seed: number): (number, number) -> string
	local cols, rows = math.max(1, math.floor(w / px)), math.max(1, math.floor(h / px))
	local list = {}
	local rng = Random.new(seed)
	for _ = 1, count do
		table.insert(list, { rng:NextNumber(0.5, cols + 0.5), rng:NextNumber(0.5, rows + 0.5), rng:NextNumber(rmin, rmax) })
	end
	return function(i: number, j: number): string
		for _, c in list do
			local dx, dy = i - c[1], j - c[2]
			local d = math.sqrt(dx * dx + dy * dy)
			if d <= c[3] then
				if d > c[3] - 1 then
					return "D"
				elseif dx < 0 and dy < 0 and d > c[3] - 2 then
					return "L"
				end
				return "K"
			end
		end
		return "."
	end
end

--- Éclats sur une arête de a à b : petits cubes qui cassent la ligne droite (style voxel).
function Pixel.chips(rig: Rig, bone: string, a: Vector3, b: Vector3, count: number, size: number, styles: { Style }, seed: number)
	local rng = Random.new(seed)
	for i = 1, count do
		local p = a:Lerp(b, (i - 0.5) / count + rng:NextNumber(-0.3, 0.3) / count)
		local s = size * rng:NextNumber(0.6, 1.2)
		rig:block(bone, "Chip", CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), v3(s, s * rng:NextNumber(0.5, 1), s), styles[rng:NextInteger(1, #styles)])
	end
end

--- Pavage d'un triangle (a, b, c) en carreaux carrés de côté `step` (grille alignée sur a -> b),
--- épaisseur `thick`. `styleAt(p)` choisit la couleur du carreau au point p (nil = pas de carreau).
--- Sert aux membranes d'ailes « en pixels ».
function Pixel.tiles(rig: Rig, bone: string, a: Vector3, b: Vector3, c: Vector3, step: number, thick: number, styleAt: (p: Vector3) -> Style?, name: string?)
	local e1, e2 = b - a, c - a
	local n = e1:Cross(e2)
	if n.Magnitude < 1e-6 then
		return
	end
	n = n.Unit
	local right = e1.Unit
	local up = n:Cross(right)
	-- bornes de la grille dans le repère (right, up)
	local xs = { 0, e1:Dot(right), e2:Dot(right) }
	local ys = { 0, e1:Dot(up), e2:Dot(up) }
	local x0, x1 = math.min(xs[1], xs[2], xs[3]), math.max(xs[1], xs[2], xs[3])
	local y0, y1 = math.min(ys[1], ys[2], ys[3]), math.max(ys[1], ys[2], ys[3])
	-- coordonnées barycentriques
	local d00, d01, d11 = e1:Dot(e1), e1:Dot(e2), e2:Dot(e2)
	local den = d00 * d11 - d01 * d01
	local x = x0 + step / 2
	while x < x1 do
		local y = y0 + step / 2
		while y < y1 do
			local p = a + right * x + up * y
			local v = p - a
			local d20, d21 = v:Dot(e1), v:Dot(e2)
			local s = (d11 * d20 - d01 * d21) / den
			local t = (d00 * d21 - d01 * d20) / den
			if s >= -0.02 and t >= -0.02 and s + t <= 1.02 then
				local st = styleAt(p)
				if st then
					rig:block(bone, name or "Tile", CFrame.fromMatrix(p, right, up), v3(step * 0.92, step * 0.92, thick), st)
				end
			end
			y += step
		end
		x += step
	end
end

return Pixel
