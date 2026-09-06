--!strict
-- ModelKit: the toolbox every procedural Oddity / pet / egg builder uses.
--
-- Conventions
--   * `Kit.newModel(name)` returns a Model plus an invisible 1x1x1 `Root`
--     part at the origin. Build everything RELATIVE to the root with +Y up
--     and the creature FACING -Z (Roblox "front"). The root sits at ground
--     level, so a 3-stud-tall body is centred at y = 1.5.
--   * Every `Kit.part` gets a `Role` attribute: "primary" | "secondary" |
--     "accent" | "fixed". Variants tint primary/secondary/accent parts and
--     leave "fixed" parts (eyes, teeth, glass) alone.
--   * Call `Kit.finalize(model)` last. It anchors, disables collisions,
--     weld-constrains all parts to the root and measures the model.
--   * Client-side idle animation is data-driven: `Kit.setAnim` writes the
--     AnimStyle/AnimSpeed/AnimAmp attributes and `Kit.orbiter` marks parts
--     that revolve around the root. The Animate module does the moving.

local Kit = {}

export type PartProps = {
	name: string?,
	shape: string?, -- "Block" (default) | "Ball" | "Cylinder" | "Wedge" | "CornerWedge"
	size: Vector3,
	cf: CFrame?, -- relative to root, default identity
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	mesh: string?, -- "Sphere" | "Head" | "Cylinder" | "Brick" | "Wedge" -> SpecialMesh
	meshScale: Vector3?, -- SpecialMesh.Scale (lets a Sphere become an ellipsoid)
	role: string?, -- "primary" | "secondary" | "accent" | "fixed"  (default "primary")
	castShadow: boolean?,
}

local SHAPES = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Cylinder = Enum.PartType.Cylinder,
	Wedge = Enum.PartType.Wedge,
	CornerWedge = Enum.PartType.CornerWedge,
}

local MESHES = {
	Sphere = Enum.MeshType.Sphere,
	Head = Enum.MeshType.Head,
	Cylinder = Enum.MeshType.Cylinder,
	Brick = Enum.MeshType.Brick,
	Wedge = Enum.MeshType.Wedge,
}

-- ---------------------------------------------------------------- colours

function Kit.blend(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, math.clamp(t, 0, 1))
end

function Kit.darken(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), math.clamp(amount, 0, 1))
end

function Kit.lighten(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), math.clamp(amount, 0, 1))
end

-- ---------------------------------------------------------------- building

function Kit.newModel(name: string): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = true
	root.CanTouch = false
	root.Anchored = true
	root.CastShadow = false
	root.CFrame = CFrame.new()
	root:SetAttribute("Role", "root")
	root.Parent = model
	model.PrimaryPart = root
	return model, root
end

function Kit.root(model: Model): BasePart
	local root = model.PrimaryPart or model:FindFirstChild("Root") :: BasePart?
	assert(root, "model has no Root")
	return root
end

function Kit.part(model: Model, props: PartProps): BasePart
	local root = Kit.root(model)
	local shape = SHAPES[props.shape or "Block"] or Enum.PartType.Block
	local part: BasePart
	if shape == Enum.PartType.Wedge then
		part = Instance.new("WedgePart")
	elseif shape == Enum.PartType.CornerWedge then
		part = Instance.new("CornerWedgePart")
	else
		local p = Instance.new("Part")
		p.Shape = shape
		part = p
	end
	part.Name = props.name or "Part"
	part.Size = props.size
	part.CFrame = root.CFrame * (props.cf or CFrame.new())
	part.Color = props.color or Color3.fromRGB(200, 200, 200)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Reflectance = props.reflectance or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = if props.castShadow == nil then true else props.castShadow
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("Role", props.role or "primary")
	if props.mesh and part:IsA("Part") then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = MESHES[props.mesh] or Enum.MeshType.Sphere
		mesh.Scale = props.meshScale or Vector3.new(1, 1, 1)
		mesh.Parent = part
	end
	part.Parent = model
	return part
end

-- Convenience: an ellipsoid (Sphere mesh scaled to `size`).
function Kit.blob(model: Model, size: Vector3, cf: CFrame, color: Color3, role: string?, material: Enum.Material?): BasePart
	local maxDim = math.max(size.X, size.Y, size.Z)
	return Kit.part(model, {
		size = Vector3.new(maxDim, maxDim, maxDim),
		cf = cf,
		color = color,
		material = material,
		mesh = "Sphere",
		meshScale = Vector3.new(size.X / maxDim, size.Y / maxDim, size.Z / maxDim),
		role = role or "primary",
	})
end

-- A round eye with a pupil. `cf` is the centre of the eyeball; the eye looks along -Z of cf.
function Kit.eye(model: Model, cf: CFrame, radius: number, irisColor: Color3?): (BasePart, BasePart)
	local white = Kit.part(model, {
		name = "Eye",
		shape = "Ball",
		size = Vector3.new(radius * 2, radius * 2, radius * 2),
		cf = cf,
		color = Color3.fromRGB(245, 245, 245),
		material = Enum.Material.SmoothPlastic,
		role = "fixed",
		castShadow = false,
	})
	local pupil = Kit.part(model, {
		name = "Pupil",
		shape = "Ball",
		size = Vector3.new(radius, radius, radius),
		cf = cf * CFrame.new(0, 0, -radius * 0.6),
		color = irisColor or Color3.fromRGB(25, 25, 30),
		material = Enum.Material.SmoothPlastic,
		role = "fixed",
		castShadow = false,
	})
	return white, pupil
end

-- Two eyes symmetric about X. `centre` is between them, `spacing` is the X distance between eye centres.
function Kit.eyes(model: Model, centre: CFrame, spacing: number, radius: number, irisColor: Color3?)
	Kit.eye(model, centre * CFrame.new(-spacing / 2, 0, 0), radius, irisColor)
	Kit.eye(model, centre * CFrame.new(spacing / 2, 0, 0), radius, irisColor)
end

-- Four simple legs under a body. `bodyCF` is the body centre, `spread` = (x, z) half-extents, `length` = leg height.
function Kit.legs(model: Model, bodyCF: CFrame, spread: Vector2, length: number, thickness: number, color: Color3, role: string?)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.part(model, {
				name = "Leg",
				shape = "Cylinder",
				size = Vector3.new(length, thickness, thickness),
				cf = bodyCF * CFrame.new(sx * spread.X, -length / 2, sz * spread.Y) * CFrame.Angles(0, 0, math.rad(90)),
				color = color,
				role = role or "secondary",
			})
		end
	end
end

function Kit.light(part: BasePart, color: Color3, brightness: number?, range: number?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness or 1
	light.Range = range or 10
	light.Shadows = false
	light.Parent = part
	return light
end

-- ---------------------------------------------------------------- particles

local PARTICLE_PRESETS: { [string]: (ParticleEmitter, Color3) -> () } = {
	sparkle = function(e, c)
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = 6
		e.Lifetime = NumberRange.new(0.6, 1.2)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 0) })
		e.Color = ColorSequence.new(c)
		e.LightEmission = 1
		e.SpreadAngle = Vector2.new(180, 180)
	end,
	fire = function(e, c)
		e.Texture = "rbxasset://textures/particles/fire_main.dds"
		e.Rate = 14
		e.Lifetime = NumberRange.new(0.4, 0.8)
		e.Speed = NumberRange.new(1, 2.5)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
		e.Color = ColorSequence.new(c, Kit.darken(c, 0.5))
		e.LightEmission = 0.8
		e.Acceleration = Vector3.new(0, 4, 0)
		e.SpreadAngle = Vector2.new(25, 25)
	end,
	smoke = function(e, c)
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Rate = 5
		e.Lifetime = NumberRange.new(1, 2)
		e.Speed = NumberRange.new(0.5, 1)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(c)
		e.Acceleration = Vector3.new(0, 1.5, 0)
	end,
	stars = function(e, c)
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = 10
		e.Lifetime = NumberRange.new(1.2, 2.2)
		e.Speed = NumberRange.new(0.2, 0.6)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.5), NumberSequenceKeypoint.new(1, 0) })
		e.Color = ColorSequence.new(c, Color3.new(1, 1, 1))
		e.LightEmission = 1
		e.SpreadAngle = Vector2.new(180, 180)
		e.RotSpeed = NumberRange.new(-90, 90)
	end,
	motes = function(e, c)
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Rate = 8
		e.Lifetime = NumberRange.new(1, 1.8)
		e.Speed = NumberRange.new(0.3, 0.9)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
		e.Color = ColorSequence.new(c)
		e.LightEmission = 0.6
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, 1, 0)
	end,
	glint = function(e, c)
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = 2
		e.Lifetime = NumberRange.new(0.4, 0.7)
		e.Speed = NumberRange.new(0, 0.2)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.9), NumberSequenceKeypoint.new(1, 0) })
		e.Color = ColorSequence.new(c)
		e.LightEmission = 1
		e.SpreadAngle = Vector2.new(180, 180)
	end,
	confetti = function(e, c)
		e.Texture = "rbxasset://textures/particles/explosion01_implosion_main.dds"
		e.Rate = 20
		e.Lifetime = NumberRange.new(1, 1.8)
		e.Speed = NumberRange.new(3, 6)
		e.Size = NumberSequence.new(0.25)
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 200, 255)),
		})
		e.Acceleration = Vector3.new(0, -8, 0)
		e.SpreadAngle = Vector2.new(60, 60)
		e.RotSpeed = NumberRange.new(-360, 360)
	end,
	aura = function(e, c)
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Rate = 4
		e.Lifetime = NumberRange.new(1.5, 2.5)
		e.Speed = NumberRange.new(0.1, 0.3)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 3) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(c)
		e.LightEmission = 0.5
		e.SpreadAngle = Vector2.new(180, 180)
	end,
	lightning = function(e, c)
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = 3
		e.Lifetime = NumberRange.new(0.1, 0.25)
		e.Speed = NumberRange.new(4, 8)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
		e.Color = ColorSequence.new(c)
		e.LightEmission = 1
		e.SpreadAngle = Vector2.new(180, 180)
	end,
	rain = function(e, c)
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = 12
		e.Lifetime = NumberRange.new(0.5, 0.8)
		e.Speed = NumberRange.new(3, 5)
		e.Size = NumberSequence.new(0.12)
		e.Color = ColorSequence.new(c)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.SpreadAngle = Vector2.new(15, 15)
	end,
}

-- Variant particle presets map onto the base presets above with a colour.
local VARIANT_PARTICLES: { [string]: { preset: string, color: Color3 } } = {
	chromeGlint = { preset = "glint", color = Color3.fromRGB(235, 240, 255) },
	prismSparkle = { preset = "sparkle", color = Color3.fromRGB(255, 170, 240) },
	emberFire = { preset = "fire", color = Color3.fromRGB(255, 120, 40) },
	voidMotes = { preset = "motes", color = Color3.fromRGB(120, 40, 200) },
	celestialStars = { preset = "stars", color = Color3.fromRGB(255, 240, 170) },
}

function Kit.particles(part: BasePart, preset: string, color: Color3?): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "FX_" .. preset
	local variantPreset = VARIANT_PARTICLES[preset]
	local fn = PARTICLE_PRESETS[preset]
	if variantPreset then
		fn = PARTICLE_PRESETS[variantPreset.preset]
		color = color or variantPreset.color
	end
	if fn then
		fn(emitter, color or Color3.new(1, 1, 1))
	end
	emitter.Parent = part
	return emitter
end

-- ---------------------------------------------------------------- animation data

-- style: bob | waddle | hop | flutter | sway | spin | hover | orbit | pulse | flicker | drift | shift
function Kit.setAnim(model: Model, style: string, speed: number?, amp: number?)
	model:SetAttribute("AnimStyle", style)
	model:SetAttribute("AnimSpeed", speed or 1)
	model:SetAttribute("AnimAmp", amp or 1)
end

-- Marks `part` as revolving around the root. Angle advances `speed` rad/s.
function Kit.orbiter(model: Model, part: BasePart, radius: number, speed: number, phase: number?, tilt: number?, height: number?)
	part:SetAttribute("OrbitRadius", radius)
	part:SetAttribute("OrbitSpeed", speed)
	part:SetAttribute("OrbitPhase", phase or 0)
	part:SetAttribute("OrbitTilt", tilt or 0)
	part:SetAttribute("OrbitHeight", height or (part.Position - Kit.root(model).Position).Y)
	model:SetAttribute("HasOrbiters", true)
end

-- Parts tagged as "flicker" pulse their transparency (used by Neon glows).
function Kit.flickerPart(part: BasePart, minT: number?, maxT: number?)
	part:SetAttribute("FlickerMin", minT or 0)
	part:SetAttribute("FlickerMax", maxT or 0.5)
end

-- Parts tagged for the "shift" style cycle visibility in groups (0,1,2...).
function Kit.shiftGroup(part: BasePart, group: number)
	part:SetAttribute("ShiftGroup", group)
end

-- ---------------------------------------------------------------- finalize

-- Visual axis-aligned bounds of a model. Unlike Model:GetBoundingBox this
-- honours SpecialMesh.Scale (Kit.blob parts are cubes shrunk by a mesh), so
-- ellipsoid-heavy models are not measured as boxes. Returns (centre, size).
function Kit.bounds(model: Model): (Vector3, Vector3)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	local any = false
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") and inst.Transparency < 1 then
			local size = inst.Size
			local mesh = inst:FindFirstChildOfClass("SpecialMesh")
			if mesh then
				size = size * mesh.Scale
			end
			local half = size / 2
			local cf = inst.CFrame
			-- world-space half extents of a rotated box: |R| * half
			local r = cf.Rotation
			local ex = math.abs(r.XVector.X) * half.X + math.abs(r.YVector.X) * half.Y + math.abs(r.ZVector.X) * half.Z
			local ey = math.abs(r.XVector.Y) * half.X + math.abs(r.YVector.Y) * half.Y + math.abs(r.ZVector.Y) * half.Z
			local ez = math.abs(r.XVector.Z) * half.X + math.abs(r.YVector.Z) * half.Y + math.abs(r.ZVector.Z) * half.Z
			local e = Vector3.new(ex, ey, ez)
			minV = minV:Min(cf.Position - e)
			maxV = maxV:Max(cf.Position + e)
			any = true
		end
	end
	if not any then
		local cf, size = model:GetBoundingBox()
		return cf.Position, size
	end
	return (minV + maxV) / 2, maxV - minV
end

-- Anchors and weld-constrains everything to the root, measures the model.
function Kit.finalize(model: Model): Model
	local root = Kit.root(model)
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") and inst ~= root then
			inst.Anchored = true
			inst.CanCollide = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = inst
			weld.Parent = inst
		end
	end
	local _, size = Kit.bounds(model)
	model:SetAttribute("Height", size.Y)
	model:SetAttribute("Width", math.max(size.X, size.Z))
	return model
end

-- Sets / clears anchoring on every part (carrying unanchors so the weld to a character works).
function Kit.setAnchored(model: Model, anchored: boolean)
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			inst.Anchored = anchored
			if not anchored then
				inst.Massless = true
			end
		end
	end
end

-- ---------------------------------------------------------------- variants & rarity glow

local Variants = require(script.Parent.Parent.Config.Variants)
local Rarities = require(script.Parent.Parent.Config.Rarities)

local TINTABLE = { primary = true, secondary = true, accent = true }

function Kit.applyVariant(model: Model, variantId: string)
	local info = Variants.info[variantId]
	if not info or variantId == "Normal" then
		return
	end
	model:SetAttribute("Variant", variantId)
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") and TINTABLE[inst:GetAttribute("Role")] then
			if info.tint then
				inst.Color = Kit.blend(inst.Color, info.tint, info.tintAmount)
			end
			if variantId == "Overcharged" then
				-- electric accents + glowing markings: accents go Neon, body keeps its material
				if inst:GetAttribute("Role") == "accent" then
					inst.Color = info.color
					inst.Material = Enum.Material.Neon
				end
			elseif variantId == "Prismatic" then
				-- coherent multicolour treatment: glassy body, hue-cycled by Animate (Rainbow)
				if inst:GetAttribute("Role") ~= "accent" and info.material then
					inst.Material = info.material
				end
				inst.Transparency = math.max(inst.Transparency, 0.15)
				inst.Reflectance = 0.2
			end
		end
	end
	if info.particles then
		Kit.particles(Kit.root(model), info.particles, info.color)
	end
	if info.rainbow then
		model:SetAttribute("Rainbow", true)
	end
	if info.glow then
		Kit.light(Kit.root(model), info.color, 1.0, 12)
	end
end

-- Rare gets a soft sparkle, Legendary an aura + light; Common / Uncommon stay clean.
function Kit.applyRarityGlow(model: Model, rarity: string)
	local info = Rarities.info[rarity]
	if not info or info.glow == 0 then
		return
	end
	local root = Kit.root(model)
	if info.glow == 1 then
		Kit.particles(root, "stars", info.color)
		Kit.light(root, info.color, 0.9, 12)
	elseif info.glow == 2 then
		Kit.particles(root, "aura", info.color)
		Kit.particles(root, "sparkle", Color3.fromRGB(255, 240, 180))
		Kit.light(root, info.color, 1.4, 16)
	else
		Kit.particles(root, "motes", Color3.fromRGB(60, 0, 20))
		Kit.particles(root, "aura", info.color)
		Kit.light(root, info.color, 1.8, 20)
	end
end

return Kit
