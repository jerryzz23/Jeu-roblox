--!strict
--[[
	CreatureForge.Fx
	----------------
	Fabriques de particules et de lumières. Utilise uniquement les textures
	intégrées au moteur (rbxasset://) : aucun asset à téléverser.
	Les tailles, vitesses et accélérations sont multipliées par `scale`.
]]

local Fx = {}

Fx.TEXTURES = {
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	spark = "rbxasset://textures/particles/fire_sparks_main.dds",
}

export type ParticleDef = {
	name: string,
	texture: string?,
	colors: { Color3 }, -- répartis uniformément sur la durée de vie
	sizes: { number }, -- idem (studs, avant échelle)
	transparencies: { number }?, -- idem
	lifetime: NumberRange,
	rate: number,
	speed: NumberRange?,
	spread: Vector2?, -- SpreadAngle en degrés
	acceleration: Vector3?,
	drag: number?,
	lightEmission: number?,
	lightInfluence: number?,
	brightness: number?,
	rotation: NumberRange?,
	rotSpeed: NumberRange?,
	lockedToPart: boolean?,
	direction: Enum.NormalId?,
	volume: boolean?, -- émettre dans tout le volume de la pièce
	zOffset: number?,
}

export type LightDef = {
	color: Color3,
	range: number,
	brightness: number?,
	shadows: boolean?,
}

local function numberSeq(values: { number }, mul: number): NumberSequence
	if #values == 1 then
		return NumberSequence.new(values[1] * mul)
	end
	local kps = {}
	for i, v in values do
		table.insert(kps, NumberSequenceKeypoint.new((i - 1) / (#values - 1), v * mul))
	end
	return NumberSequence.new(kps)
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

function Fx.particles(parent: Instance, def: ParticleDef, scale: number?): ParticleEmitter
	local s = scale or 1
	local e = Instance.new("ParticleEmitter")
	e.Name = def.name
	e.Texture = def.texture or Fx.TEXTURES.sparkle
	e.Color = colorSeq(def.colors)
	e.Size = numberSeq(def.sizes, s)
	e.Transparency = numberSeq(def.transparencies or { 0 }, 1)
	e.Lifetime = def.lifetime
	e.Rate = def.rate
	local speed = def.speed or NumberRange.new(0)
	e.Speed = NumberRange.new(speed.Min * s, speed.Max * s)
	e.SpreadAngle = def.spread or Vector2.zero
	e.Acceleration = (def.acceleration or Vector3.zero) * s
	e.Drag = def.drag or 0
	e.LightEmission = def.lightEmission or 0
	e.LightInfluence = def.lightInfluence or 1
	e.Brightness = def.brightness or 1
	e.Rotation = def.rotation or NumberRange.new(0)
	e.RotSpeed = def.rotSpeed or NumberRange.new(0)
	e.LockedToPart = def.lockedToPart or false
	e.EmissionDirection = def.direction or Enum.NormalId.Top
	e.ZOffset = (def.zOffset or 0) * s
	if def.volume then
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	end
	e.Parent = parent
	return e
end

function Fx.light(parent: Instance, def: LightDef, scale: number?): PointLight
	local l = Instance.new("PointLight")
	l.Color = def.color
	l.Range = def.range * (scale or 1)
	l.Brightness = def.brightness or 1
	l.Shadows = def.shadows or false
	l.Parent = parent
	return l
end

return Fx
