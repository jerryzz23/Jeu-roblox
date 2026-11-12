--!strict
--[[
	CreatureForge.Vfx
	-----------------
	Effets visuels avancés.

	À la construction (dans build, si rig.effects) :
	  • Vfx.beam      — rayon d'énergie / lien lumineux entre deux points (Beam + Attachments)
	  • Vfx.pillar    — colonne de lumière verticale
	  • Vfx.trail     — traînée derrière une partie mobile (bout d'aile, queue, griffes...)
	  • Vfx.rarityAura — aura de rareté : anneaux au sol qui tournent, colonnes de lumière,
	                    particules ascendantes ; plus intense de Commun à Mythique
	  • Vfx.abilityOrigin — point d'origine (Attachment) de la capacité spéciale

	À l'exécution (client, via CreatureAnimator) :
	  • Vfx.playAbility(model, ability) — onde de choc (ForceField), souffle, explosion,
	    éruption, éclair de lumière. Les pièces temporaires sont créées localement et nettoyées.
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.Kit)
local Fx = require(script.Parent.Fx)
local Rarity = require(script.Parent.Rarity)
local Types = require(script.Parent.Types)

type Rig = Kit.Rig

local Vfx = {}

local v3 = Vector3.new
local cf = CFrame.new

export type BeamDef = {
	colors: { Color3 },
	transparency: { number }?,
	width0: number,
	width1: number?,
	curve0: number?,
	curve1: number?,
	lightEmission: number?,
	faceCamera: boolean?,
	segments: number?,
	texture: string?,
	textureSpeed: number?,
}

export type TrailDef = {
	colors: { Color3 },
	transparency: { number }?,
	lifetime: number,
	lightEmission: number?,
	widthScale: { number }?,
}

--- Boîte englobante du corps (centres des pièces visibles, hors objets en orbite), espace Root.
local function footprint(model: Model): (Vector3, Vector3)
	local root = model.PrimaryPart
	local ref = if root then root.CFrame else CFrame.identity
	local minV, maxV = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Parent and string.sub(d.Parent.Name, 1, 4) ~= "Aura" then
			local p = ref:PointToObjectSpace(d.CFrame.Position)
			minV = minV:Min(p)
			maxV = maxV:Max(p)
		end
	end
	if minV.X == math.huge then
		return Vector3.zero, Vector3.one
	end
	return (minV + maxV) / 2, maxV - minV
end

local function colorSeq(values: { Color3 }): ColorSequence
	if #values == 1 then
		return ColorSequence.new(values[1])
	end
	local kps = {}
	for i, c in values do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#values - 1), c))
	end
	return ColorSequence.new(kps)
end

local function numberSeq(values: { number }, mul: number?): NumberSequence
	local m = mul or 1
	if #values == 1 then
		return NumberSequence.new(values[1] * m)
	end
	local kps = {}
	for i, v in values do
		table.insert(kps, NumberSequenceKeypoint.new((i - 1) / (#values - 1), v * m))
	end
	return NumberSequence.new(kps)
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

--- Attachment sur l'os `bone` au point `pos` (espace modèle). `axis` oriente l'axe X
--- (utilisé par la courbure des Beams) ; `up` oriente l'axe Y (émission des particules).
function Vfx.attach(rig: Rig, bone: string, name: string, pos: Vector3, axis: Vector3?, up: Vector3?): Attachment
	local b = rig.bones[bone]
	assert(b, `Vfx: os inconnu "{bone}"`)
	local local0 = cf(pos)
	if up then
		local0 = Kit.lookAlong(pos, up) * CFrame.Angles(-math.pi / 2, 0, 0)
	elseif axis then
		local0 = Kit.lookAlong(pos, axis) * CFrame.Angles(0, math.pi / 2, 0)
	end
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = b.CFrame:ToObjectSpace(rig:toWorld(local0))
	a.Parent = b
	return a
end

--- Rayon lumineux entre deux Attachments.
function Vfx.beamBetween(rig: Rig, a0: Attachment, a1: Attachment, def: BeamDef): Beam
	local s = rig.scale
	local b = Instance.new("Beam")
	b.Name = "Beam"
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = colorSeq(def.colors)
	b.Transparency = numberSeq(def.transparency or { 0.2, 0.6 })
	b.Width0 = def.width0 * s
	b.Width1 = (def.width1 or def.width0) * s
	b.CurveSize0 = (def.curve0 or 0) * s
	b.CurveSize1 = (def.curve1 or 0) * s
	b.LightEmission = def.lightEmission or 1
	b.LightInfluence = 0
	b.FaceCamera = if def.faceCamera == nil then true else def.faceCamera
	b.Segments = def.segments or (if (def.curve0 or 0) ~= 0 or (def.curve1 or 0) ~= 0 then 12 else 1)
	if def.texture then
		b.Texture = def.texture
		b.TextureSpeed = def.textureSpeed or 1
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 1 * s
	end
	b.Parent = a0.Parent
	return b
end

--- Rayon lumineux de `p0` (os `bone0`) à `p1` (os `bone1`), en espace modèle.
function Vfx.beam(rig: Rig, bone0: string, p0: Vector3, bone1: string, p1: Vector3, def: BeamDef, axis: Vector3?): Beam
	local a0 = Vfx.attach(rig, bone0, "BeamA", p0, axis)
	local a1 = Vfx.attach(rig, bone1, "BeamB", p1, axis)
	return Vfx.beamBetween(rig, a0, a1, def)
end

--- Colonne de lumière verticale (s'amincit vers le haut).
function Vfx.pillar(rig: Rig, bone: string, base: Vector3, height: number, width: number, color: Color3): Beam
	return Vfx.beam(rig, bone, base, bone, base + v3(0, height, 0), {
		colors = { color, color:Lerp(Color3.new(1, 1, 1), 0.35) },
		transparency = { 0.3, 0.65, 1 },
		width0 = width,
		width1 = width * 0.25,
		lightEmission = 1,
	})
end

--- Traînée entre deux points d'un os (visible quand l'os bouge : battements, queue...).
function Vfx.trail(rig: Rig, bone: string, p0: Vector3, p1: Vector3, def: TrailDef): Trail
	local a0 = Vfx.attach(rig, bone, "TrailA", p0)
	local a1 = Vfx.attach(rig, bone, "TrailB", p1)
	local t = Instance.new("Trail")
	t.Name = "Trail"
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Color = colorSeq(def.colors)
	t.Transparency = numberSeq(def.transparency or { 0.2, 1 })
	t.Lifetime = def.lifetime
	t.LightEmission = def.lightEmission or 1
	t.LightInfluence = 0
	t.MinLength = 0.02 * rig.scale
	t.FaceCamera = true
	if def.widthScale then
		t.WidthScale = numberSeq(def.widthScale)
	end
	t.Parent = a0.Parent
	return t
end

--- Positions des objets créés par Anatomy.orbit (même formule).
function Vfx.orbitPoints(center: Vector3, radius: number, count: number, wobble: number): { Vector3 }
	local out = {}
	for i = 1, count do
		local a = (i - 1) / count * math.pi * 2
		table.insert(out, center + v3(math.cos(a) * radius, math.sin(a * 2 + i) * wobble, math.sin(a) * radius))
	end
	return out
end

--- Liens d'énergie entre chaque objet en orbite et un point de la créature (ils suivent la rotation).
function Vfx.orbitTethers(rig: Rig, aura: string, pts: { Vector3 }, bone: string, target: Vector3, def: BeamDef)
	local hub = Vfx.attach(rig, bone, "TetherHub", target, v3(0, 1, 0))
	for _, p in pts do
		Vfx.beamBetween(rig, Vfx.attach(rig, aura, "Tether", p, (target - p).Unit), hub, def)
	end
end

--- Anneau d'énergie reliant les objets en orbite entre eux.
function Vfx.orbitRing(rig: Rig, aura: string, pts: { Vector3 }, def: BeamDef)
	local atts = {}
	for _, p in pts do
		table.insert(atts, Vfx.attach(rig, aura, "Link", p))
	end
	for i, a in atts do
		Vfx.beamBetween(rig, a, atts[(i % #atts) + 1], def)
	end
end

--- Traînées aux bouts des deux ailes (`tip` = bout de l'aile droite, `toward` = vers le bord de fuite).
function Vfx.wingTrails(rig: Rig, tip: Vector3, toward: Vector3, def: TrailDef)
	for _, side in { 1, -1 } do
		local p = v3(side * tip.X, tip.Y, tip.Z)
		local q = p + v3(side * toward.X, toward.Y, toward.Z)
		Vfx.trail(rig, if side > 0 then "Wing_R" else "Wing_L", p, q, def)
	end
end

--- Point d'origine de la capacité spéciale (souffle) : Attachment "AbilityOrigin" orienté
--- (+Y) dans la direction du souffle.
function Vfx.abilityOrigin(rig: Rig, ability: Types.Ability)
	local bone = ability.bone or "Head"
	if ability.origin and rig.bones[bone] then
		Vfx.attach(rig, bone, "AbilityOrigin", ability.origin, nil, ability.direction or v3(0, 0, -1))
	end
end

local AURA = {
	Common = { rings = 1, pillars = 0, rate = 4 },
	Rare = { rings = 1, pillars = 2, rate = 8 },
	Epic = { rings = 2, pillars = 4, rate = 11 },
	Legendary = { rings = 2, pillars = 6, rate = 15 },
	Mythic = { rings = 3, pillars = 8, rate = 20 },
	Exotic = { rings = 3, pillars = 12, rate = 26 },
	Exclusive = { rings = 3, pillars = 12, rate = 26 },
	Chaotic = { rings = 3, pillars = 14, rate = 32 },
}

--- Couleur n°i d'une rareté : arc-en-ciel (Exotique), noir et or (Exclusif), glitch (Chaotique).
local function tierColor(tier: Rarity.Tier, i: number): Color3
	if tier.rainbow then
		return Rarity.RAINBOW[(i - 1) % #Rarity.RAINBOW + 1]
	elseif tier.glitch then
		local g = { Rarity.GLITCH[1], Rarity.GLITCH[2], Rarity.GLITCH[3], Rarity.GLITCH[4] }
		return g[(i - 1) % #g + 1]
	end
	return tier.color
end

--- Aura de rareté autour des pieds de la créature (à appeler en fin de construction).
function Vfx.rarityAura(rig: Rig, rarityId: string)
	if not rig.effects then
		return
	end
	local tier = Rarity.get(rarityId)
	local cfg = AURA[rarityId] or AURA.Common
	local center, size = footprint(rig.model)
	local s = rig.scale
	local c = v3(center.X / s, 0.04, center.Z / s)
	local r = math.max(size.X, size.Z) / s * 0.42 + 0.4

	-- Anneaux au sol (os "AuraGround" : tourne lentement)
	if cfg.rings > 0 then
		rig:bone("AuraGround", "Root", cf(c))
		local glow = Kit.style(tier.color, Enum.Material.Neon, { transparency = 0.35, castShadow = false })
		local soft = Kit.style(tier.light, Enum.Material.Neon, { transparency = 0.6, castShadow = false })
		if tier.gold then -- Exclusif : anneau noir serti d'or
			soft = Kit.style(tier.dark, Enum.Material.SmoothPlastic, { castShadow = false })
		end
		for k = 1, cfg.rings do
			local rr = r * (1 - (k - 1) * 0.16)
			local st = if k == 1 then glow else soft
			if tier.rainbow or tier.glitch then
				st = Kit.style(tierColor(tier, k * 2), Enum.Material.Neon, { transparency = 0.35, castShadow = false })
			end
			rig:ring("AuraGround", "AuraRing", cf(c) * CFrame.Angles(math.pi / 2, 0, 0), rr, 0.07 + 0.03 * (cfg.rings - k), 0.02, 36, st)
		end
		-- Graduations runiques
		local ticks = if cfg.rings >= 2 then 12 else 6
		for i = 1, ticks do
			local a = i / ticks * math.pi * 2
			local st = if tier.rainbow or tier.glitch then Kit.style(tierColor(tier, i), Enum.Material.Neon, { castShadow = false }) else glow
			rig:block("AuraGround", "AuraTick", cf(c) * CFrame.Angles(0, a, 0) * cf(0, 0, -r * 0.92), v3(0.05, 0.02, 0.22), st)
		end
	end

	-- Colonnes de lumière
	for i = 1, cfg.pillars do
		local a = i / cfg.pillars * math.pi * 2 + 0.3
		local h = (if i % 2 == 0 then 2.2 else 3.2) * (0.6 + r * 0.25)
		Vfx.pillar(rig, "Root", c + v3(math.cos(a) * r, 0, math.sin(a) * r), h, 0.22 + r * 0.04, tierColor(tier, i))
	end

	-- Particules ascendantes
	local disc = rig:anchor("Root", "FX_RarityAura", cf(c + v3(0, 0.1, 0)), v3(r * 2, 0.1, r * 2))
	Fx.particles(disc, {
		name = "RarityMotes",
		texture = Fx.TEXTURES.sparkle,
		colors = if tier.rainbow or tier.glitch then { tierColor(tier, 1), tierColor(tier, 2), tierColor(tier, 3) } else { tier.light, tier.color },
		sizes = { 0.16, 0.28, 0 },
		transparencies = { 0.1, 0.25, 1 },
		lifetime = NumberRange.new(1.6, 2.8),
		rate = cfg.rate,
		speed = NumberRange.new(0.6, 1.4),
		spread = Vector2.new(8, 8),
		acceleration = v3(0, 0.3, 0),
		lightEmission = 1,
		rotation = NumberRange.new(0, 360),
		volume = true,
	}, s)
	if cfg.pillars >= 6 then
		Fx.light(disc, { color = tier.color, range = r * 3, brightness = 1.2 }, s)
	end
end

-- ---------------------------------------------------------------------------
-- Exécution : capacités spéciales (client)
-- ---------------------------------------------------------------------------

local TEX = {
	sparkle = Fx.TEXTURES.sparkle,
	fire = Fx.TEXTURES.fire,
	smoke = Fx.TEXTURES.smoke,
	spark = Fx.TEXTURES.spark,
}

local folder: Folder? = nil
local function vfxFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "CreatureVfx"
	f.Parent = workspace
	folder = f
	return f
end

local function tempPart(c: CFrame, size: Vector3, color: Color3, material: Enum.Material, transparency: number, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material
	p.Color = color
	p.Transparency = transparency
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = c
	p.Parent = vfxFolder()
	return p
end

--- Onde de choc : anneau d'énergie (ForceField) qui s'étend + disque lumineux.
local function shockwave(at: CFrame, radius: number, color: Color3, duration: number)
	local ring = tempPart(at * CFrame.Angles(0, 0, math.pi / 2), v3(0.4, 1, 1), color, Enum.Material.ForceField, 0, Enum.PartType.Cylinder)
	TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = v3(0.15, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	local disc = tempPart(at * CFrame.Angles(0, 0, math.pi / 2), v3(0.05, 1, 1), color, Enum.Material.Neon, 0.3, Enum.PartType.Cylinder)
	TweenService:Create(disc, TweenInfo.new(duration * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = v3(0.05, radius * 1.4, radius * 1.4),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, duration + 0.1)
	Debris:AddItem(disc, duration + 0.1)
end

--- Dôme d'énergie qui gonfle puis disparaît.
local function dome(at: CFrame, radius: number, color: Color3, duration: number)
	local ball = tempPart(at, v3(1, 1, 1), color, Enum.Material.ForceField, 0, Enum.PartType.Ball)
	TweenService:Create(ball, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.one * radius * 2,
		Transparency = 1,
	}):Play()
	Debris:AddItem(ball, duration + 0.1)
end

--- Éclair de lumière.
local function flash(at: CFrame, radius: number, color: Color3, duration: number)
	local p = tempPart(at, Vector3.one * 0.2, color, Enum.Material.SmoothPlastic, 1)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = radius * 3
	l.Brightness = 6
	l.Parent = p
	TweenService:Create(l, TweenInfo.new(duration, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
	Debris:AddItem(p, duration + 0.1)
end

--- Gerbe de particules (Emit) depuis `at`.
local function burst(at: CFrame, count: number, def: Fx.ParticleDef, scale: number, lifetime: number)
	local p = tempPart(at, Vector3.one * 0.5 * scale, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	local e = Fx.particles(p, def, scale)
	e.Enabled = false
	e:Emit(count)
	Debris:AddItem(p, lifetime + 0.2)
end

local function emitDef(name: string, colors: { Color3 }, texture: string, size: number, speed: number, spread: number, lifetime: number, accel: Vector3?): Fx.ParticleDef
	return {
		name = name,
		texture = texture,
		colors = colors,
		sizes = { size, size * 0.7, 0 },
		transparencies = { 0, 0.2, 1 },
		lifetime = NumberRange.new(lifetime * 0.6, lifetime),
		rate = 0,
		speed = NumberRange.new(speed * 0.6, speed),
		spread = Vector2.new(spread, spread),
		acceleration = accel,
		drag = 2,
		lightEmission = 1,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-200, 200),
	}
end

--- Joue la capacité spéciale `ability` sur `model` (à appeler côté client).
function Vfx.playAbility(model: Model, ability: Types.Ability)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local scale = (model:GetAttribute("Scale") :: number?) or 1
	local duration = ability.duration or 1.6
	local c1 = ability.colors[1]
	local c2 = ability.colors[2] or c1
	local c3 = ability.colors[3] or Color3.new(1, 1, 1)
	local tex = TEX[ability.texture or "sparkle"] or Fx.TEXTURES.sparkle
	local radius = (ability.radius or 5) * scale
	local ground = root.CFrame * cf(0, 0.15 * scale, 0)
	local center = footprint(model)
	local body = root.CFrame * cf(center)

	if ability.kind == "Breath" then
		local origin = model:FindFirstChild("AbilityOrigin", true)
		if origin and origin:IsA("Attachment") then
			local e = Fx.particles(origin, {
				name = "Breath",
				texture = tex,
				colors = { c3, c1, c2 },
				sizes = { 0.4, 1.4, 2.2 },
				transparencies = { 0.1, 0.3, 1 },
				lifetime = NumberRange.new(0.5, 0.8),
				rate = 120,
				speed = NumberRange.new(14, 20),
				spread = Vector2.new(12, 12),
				drag = 2,
				lightEmission = 1,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-180, 180),
			}, scale)
			local l = Instance.new("PointLight")
			l.Color = c1
			l.Range = 10 * scale
			l.Brightness = 3
			l.Parent = origin
			task.delay(duration, function()
				e.Enabled = false
				l:Destroy()
			end)
			Debris:AddItem(e, duration + 1)
		end
		flash(body, radius, c1, duration * 0.6)
	elseif ability.kind == "Stomp" then
		shockwave(ground, radius, c1, 0.9)
		task.delay(0.15, shockwave, ground, radius * 0.7, c2, 0.8)
		burst(ground, 40, emitDef("Debris", { c2, c1 }, Fx.TEXTURES.spark, 0.3, 14, 70, 1.2, v3(0, -18, 0)), scale, 1.2)
		burst(ground, 20, emitDef("Dust", { Color3.fromRGB(180, 170, 150), c2 }, Fx.TEXTURES.smoke, 1.6, 6, 85, 1.4), scale, 1.4)
		flash(ground, radius, c1, 0.6)
	elseif ability.kind == "Burst" then
		dome(body, radius * 0.6, c1, 0.7)
		burst(body, 60, emitDef("Shards", { c3, c1, c2 }, tex, 0.35, 16, 180, 1.0), scale, 1.0)
		shockwave(ground, radius, c2, 0.8)
		flash(body, radius, c1, 0.7)
	elseif ability.kind == "Eruption" then
		burst(body, 50, emitDef("Eruption", { c3, c1, c2 }, Fx.TEXTURES.fire, 0.9, 22, 25, 1.4, v3(0, -14, 0)), scale, 1.4)
		burst(body, 40, emitDef("Embers", { c3, c1 }, Fx.TEXTURES.spark, 0.25, 26, 35, 1.8, v3(0, -10, 0)), scale, 1.8)
		shockwave(ground, radius, c1, 1.0)
		flash(body, radius * 1.5, c1, 1.0)
	else -- "Nova"
		dome(body, radius * 0.8, c1, 0.8)
		task.delay(0.12, dome, body, radius, c2, 0.9)
		shockwave(ground, radius * 1.2, c1, 1.0)
		burst(body, 70, emitDef("Nova", { c3, c1, c2 }, tex, 0.5, 18, 180, 1.2), scale, 1.2)
		flash(body, radius * 1.5, c1, 0.9)
	end
end

return Vfx
