--!strict
-- Gusty Gardens (Wind) and Splashwater Bay (Water) creature builders.
-- Each function adds parts relative to the model root: feet at y = 0, +Y up,
-- face on -Z. The dispatcher (CreatureModels) calls finalize/variant/glow.

local Kit = require(script.Parent.Parent.ModelKit)

local B = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- A cylinder stood upright (Kit cylinders are long along X).
local UP = CFrame.Angles(0, 0, math.rad(90))

-- ---------------------------------------------------------------- Wind

-- Breeze Bean: a floating kidney bean with two leaf ears and a sprout.
B.breeze_bean = function(model: Model, _root: BasePart, palette, def)
	Kit.blob(model, Vector3.new(1.5, 1.9, 1.4), CFrame.new(0, 1.25, 0), palette.primary)
	-- the bean's curve: a second smaller lobe offset to one side
	Kit.blob(model, Vector3.new(1.1, 1.2, 1.1), CFrame.new(0.42, 1.85, 0.1), palette.primary)
	Kit.blob(model, Vector3.new(0.95, 1.0, 0.95), CFrame.new(-0.4, 0.75, 0.05), palette.primary)

	-- leaf ears, angled out and back
	for _, side in { -1, 1 } do
		local leafCF = CFrame.new(side * 1.05, 2.0, 0.1) * CFrame.Angles(0, side * math.rad(-25), side * math.rad(35))
		Kit.part(model, {
			name = "Leaf",
			shape = "Ball",
			mesh = "Sphere",
			size = Vector3.new(1.5, 0.16, 0.75),
			cf = leafCF,
			color = palette.secondary,
			role = "secondary",
		})
		-- leaf vein, sitting just proud of the leaf's face
		Kit.part(model, {
			name = "Vein",
			size = Vector3.new(1.3, 0.06, 0.06),
			cf = leafCF * CFrame.new(0, 0.05, 0),
			color = Kit.lighten(palette.secondary, 0.3),
			role = "secondary",
		})
	end

	-- sprout on top
	Kit.part(model, { name = "Stem", shape = "Cylinder", size = Vector3.new(0.45, 0.14, 0.14), cf = CFrame.new(0.2, 2.5, 0.05) * UP, color = palette.secondary, role = "secondary" })
	Kit.blob(model, Vector3.new(0.4, 0.4, 0.4), CFrame.new(0.2, 2.75, 0.05), palette.accent, "accent")

	Kit.eyes(model, CFrame.new(0.1, 1.6, -0.62), 0.42, 0.2)
	-- little smile
	Kit.part(model, { name = "Smile", size = Vector3.new(0.42, 0.08, 0.08), cf = CFrame.new(0.1, 1.28, -0.68), color = rgb(60, 50, 40), role = "fixed" })

	-- breeze swirl underneath (it floats)
	local swirl = Kit.part(model, { name = "Breeze", shape = "Cylinder", size = Vector3.new(0.1, 0.9, 0.9), cf = CFrame.new(0, 0.28, 0) * UP, color = palette.accent, material = Enum.Material.Neon, transparency = 0.55, role = "accent" })
	Kit.flickerPart(swirl, 0.4, 0.75)

	Kit.setAnim(model, "hover", def.animSpeed, 1.1)
end

-- Gust Bunny: upright rabbit standing on two little cyclones.
B.gust_bunny = function(model: Model, root: BasePart, palette, def)
	local _ = root
	Kit.blob(model, Vector3.new(1.3, 1.5, 1.1), CFrame.new(0, 1.55, 0), palette.primary) -- torso
	Kit.blob(model, Vector3.new(1.15, 1.05, 1.05), CFrame.new(0, 2.5, -0.08), palette.primary) -- head

	-- long ears
	for _, side in { -1, 1 } do
		Kit.part(model, {
			name = "Ear",
			shape = "Ball",
			mesh = "Sphere",
			size = Vector3.new(0.32, 1.25, 0.22),
			cf = CFrame.new(side * 0.32, 3.35, -0.05) * CFrame.Angles(0, 0, side * math.rad(11)),
			color = palette.primary,
		})
		Kit.part(model, {
			name = "EarInner",
			shape = "Ball",
			mesh = "Sphere",
			size = Vector3.new(0.17, 0.95, 0.12),
			cf = CFrame.new(side * 0.32, 3.35, -0.14) * CFrame.Angles(0, 0, side * math.rad(11)),
			color = palette.accent,
			role = "accent",
		})
	end

	-- arms
	for _, side in { -1, 1 } do
		Kit.blob(model, Vector3.new(0.34, 0.8, 0.34), CFrame.new(side * 0.75, 1.7, -0.05) * CFrame.Angles(0, 0, side * math.rad(-14)), palette.primary)
	end

	-- cyclone feet: three stacked cones per foot, marked as orbiters so they spin
	for _, side in { -1, 1 } do
		local x = side * 0.36
		local widths = { 0.75, 0.55, 0.34 }
		for i, w in widths do
			local p = Kit.part(model, {
				name = "Cyclone",
				shape = "Cylinder",
				size = Vector3.new(0.24, w, w),
				cf = CFrame.new(x, 0.16 + (i - 1) * 0.26, 0) * UP,
				color = palette.secondary,
				material = Enum.Material.Neon,
				transparency = 0.35 + i * 0.05,
				role = "secondary",
			})
			Kit.orbiter(model, p, 0.09 * i, 6 - i, i * 2, 0, 0.16 + (i - 1) * 0.26)
		end
	end

	Kit.eyes(model, CFrame.new(0, 2.62, -0.55), 0.3, 0.18)
	Kit.part(model, { name = "Nose", shape = "Ball", size = Vector3.new(0.18, 0.14, 0.14), cf = CFrame.new(0, 2.4, -0.6), color = palette.accent, role = "accent" })
	-- puffy tail
	Kit.blob(model, Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 1.35, 0.6), rgb(255, 255, 255), "fixed")

	Kit.setAnim(model, "hop", def.animSpeed, 1)
end

-- Twister Terrier: a dog whose middle is a corkscrew, wearing flight goggles.
B.twister_terrier = function(model: Model, root: BasePart, palette, def)
	local _ = root
	-- spiral body: six discs of shrinking radius, each rotated a bit
	for i = 1, 6 do
		local t = (i - 1) / 5
		local w = 1.35 - t * 0.55
		Kit.part(model, {
			name = "Spiral" .. tostring(i),
			shape = "Cylinder",
			size = Vector3.new(0.34, w, w),
			cf = CFrame.new(math.sin(t * 6) * 0.14, 0.55 + (i - 1) * 0.33, math.cos(t * 6) * 0.1) * UP * CFrame.Angles(t * 2.6, 0, 0),
			color = if i % 2 == 0 then palette.secondary else palette.primary,
			role = if i % 2 == 0 then "secondary" else "primary",
		})
	end

	-- head at the top of the corkscrew
	Kit.blob(model, Vector3.new(1.05, 0.95, 1.15), CFrame.new(0, 2.85, -0.15), palette.primary)
	Kit.blob(model, Vector3.new(0.5, 0.4, 0.55), CFrame.new(0, 2.68, -0.78), palette.secondary, "secondary") -- snout
	Kit.part(model, { name = "Nose", shape = "Ball", size = Vector3.new(0.22, 0.18, 0.18), cf = CFrame.new(0, 2.76, -1.02), color = rgb(45, 40, 40), role = "fixed" })

	-- floppy ears
	for _, side in { -1, 1 } do
		Kit.part(model, {
			name = "Ear",
			shape = "Ball",
			mesh = "Sphere",
			size = Vector3.new(0.22, 0.8, 0.45),
			cf = CFrame.new(side * 0.52, 2.8, 0.02) * CFrame.Angles(0, 0, side * math.rad(24)),
			color = palette.secondary,
			role = "secondary",
		})
	end

	-- goggles: strap + two lenses
	Kit.part(model, { name = "Strap", size = Vector3.new(1.15, 0.2, 1.15), cf = CFrame.new(0, 3.05, -0.15), color = rgb(60, 50, 45), role = "fixed" })
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "LensRim", shape = "Cylinder", size = Vector3.new(0.12, 0.46, 0.46), cf = CFrame.new(side * 0.27, 3.05, -0.66) * CFrame.Angles(0, math.rad(90), 0), color = rgb(70, 60, 52), role = "fixed" })
		Kit.part(model, { name = "Lens", shape = "Cylinder", size = Vector3.new(0.06, 0.36, 0.36), cf = CFrame.new(side * 0.27, 3.05, -0.72) * CFrame.Angles(0, math.rad(90), 0), color = palette.accent, material = Enum.Material.Glass, transparency = 0.25, reflectance = 0.3, role = "fixed" })
	end

	-- tail, curled
	Kit.part(model, { name = "Tail", shape = "Cylinder", size = Vector3.new(0.7, 0.2, 0.2), cf = CFrame.new(0, 2.15, 0.7) * CFrame.Angles(math.rad(35), 0, 0), color = palette.secondary, role = "secondary" })

	-- four little paws at the base
	Kit.legs(model, CFrame.new(0, 0.45, 0), Vector2.new(0.62, 0.5), 0.45, 0.26, palette.secondary, "secondary")

	Kit.setAnim(model, "spin", def.animSpeed, 1)
end

-- Sir Spins-a-Lot: a tornado knight. Cone-stack body, helmet, lance, sneakers.
B.sir_spins_a_lot = function(model: Model, root: BasePart, palette, def)
	local _ = root
	-- tornado funnel: stacked cylinders, wide at the top
	local widths = { 0.8, 1.05, 1.35, 1.7, 2.05, 2.3 }
	for i, w in widths do
		local p = Kit.part(model, {
			name = "Funnel" .. tostring(i),
			shape = "Cylinder",
			size = Vector3.new(0.62, w, w),
			cf = CFrame.new(math.sin(i * 1.1) * 0.1, 0.55 + (i - 1) * 0.62, math.cos(i * 1.1) * 0.08) * UP,
			color = if i % 2 == 0 then palette.secondary else palette.primary,
			material = Enum.Material.SmoothPlastic,
			transparency = 0.12,
			role = if i % 2 == 0 then "secondary" else "primary",
		})
		Kit.orbiter(model, p, 0.12, 2.4, i, 0, 0.55 + (i - 1) * 0.62)
	end

	-- knight helmet on top
	Kit.blob(model, Vector3.new(1.5, 1.3, 1.5), CFrame.new(0, 4.5, -0.05), palette.secondary, "secondary", Enum.Material.Metal)
	Kit.part(model, { name = "Visor", size = Vector3.new(1.15, 0.34, 0.2), cf = CFrame.new(0, 4.5, -0.78), color = rgb(30, 32, 42), role = "fixed" })
	Kit.part(model, { name = "VisorSlot", size = Vector3.new(0.9, 0.12, 0.1), cf = CFrame.new(0, 4.5, -0.86), color = palette.accent, material = Enum.Material.Neon, role = "accent" })
	-- plume
	Kit.blob(model, Vector3.new(0.4, 0.75, 0.4), CFrame.new(0, 5.3, 0.1), palette.accent, "accent")
	Kit.blob(model, Vector3.new(0.3, 0.55, 0.3), CFrame.new(0, 5.6, 0.28), palette.accent, "accent")

	-- weather-vane lance held out to the right
	local shaft = Kit.part(model, { name = "Lance", shape = "Cylinder", size = Vector3.new(3.1, 0.18, 0.18), cf = CFrame.new(1.7, 3.3, -0.6) * CFrame.Angles(0, math.rad(12), math.rad(18)), color = rgb(120, 92, 60), role = "fixed" })
	Kit.part(model, { name = "VaneN", size = Vector3.new(0.5, 0.5, 0.08), cf = CFrame.new(2.95, 3.75, -0.85), color = palette.accent, material = Enum.Material.Metal, role = "accent" })
	Kit.part(model, { name = "VaneArrow", shape = "Wedge", size = Vector3.new(0.1, 0.45, 0.55), cf = CFrame.new(3.25, 3.6, -0.85) * CFrame.Angles(0, math.rad(90), math.rad(-90)), color = palette.accent, material = Enum.Material.Metal, role = "accent" })
	local _ = shaft

	-- gauntlet holding it
	Kit.blob(model, Vector3.new(0.5, 0.5, 0.5), CFrame.new(1.15, 3.05, -0.5), palette.secondary, "secondary", Enum.Material.Metal)

	-- sneakers poking out of the bottom of the funnel
	for _, side in { -1, 1 } do
		Kit.blob(model, Vector3.new(0.5, 0.34, 0.95), CFrame.new(side * 0.42, 0.18, -0.28), rgb(250, 250, 255), "fixed")
		Kit.part(model, { name = "Sole", size = Vector3.new(0.52, 0.12, 0.98), cf = CFrame.new(side * 0.42, 0.06, -0.28), color = rgb(240, 90, 110), role = "fixed" })
		Kit.part(model, { name = "Stripe", size = Vector3.new(0.54, 0.1, 0.3), cf = CFrame.new(side * 0.42, 0.24, -0.5), color = rgb(90, 190, 255), role = "fixed" })
	end

	Kit.particles(Kit.root(model), "sparkle", palette.accent)
	Kit.setAnim(model, "sway", def.animSpeed, 1.2)
end

-- ---------------------------------------------------------------- Water

-- Drizzle Duck: round duck wearing its own little raincloud.
B.drizzle_duck = function(model: Model, root: BasePart, palette, def)
	local _ = root
	Kit.blob(model, Vector3.new(1.45, 1.3, 1.65), CFrame.new(0, 0.85, 0), palette.primary) -- body
	Kit.blob(model, Vector3.new(0.95, 0.95, 0.95), CFrame.new(0, 1.72, -0.42), palette.primary) -- head

	-- bill
	Kit.part(model, { name = "Bill", size = Vector3.new(0.55, 0.18, 0.62), cf = CFrame.new(0, 1.6, -0.98), color = palette.secondary, role = "secondary" })
	Kit.part(model, { name = "BillTip", shape = "Ball", mesh = "Sphere", size = Vector3.new(0.55, 0.16, 0.3), cf = CFrame.new(0, 1.6, -1.24), color = palette.secondary, role = "secondary" })

	-- wings
	for _, side in { -1, 1 } do
		Kit.part(model, {
			name = "Wing",
			shape = "Ball",
			mesh = "Sphere",
			size = Vector3.new(0.2, 0.7, 1.15),
			cf = CFrame.new(side * 0.72, 0.9, 0.05) * CFrame.Angles(0, 0, side * math.rad(-8)),
			color = Kit.darken(palette.primary, 0.12),
		})
	end
	-- tail feathers
	Kit.part(model, { name = "Tail", shape = "Wedge", size = Vector3.new(0.6, 0.4, 0.6), cf = CFrame.new(0, 1.1, 0.82) * CFrame.Angles(math.rad(-20), math.rad(180), 0), color = Kit.darken(palette.primary, 0.15) })

	-- webbed feet
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Foot", size = Vector3.new(0.42, 0.12, 0.6), cf = CFrame.new(side * 0.3, 0.06, -0.2), color = palette.secondary, role = "secondary" })
	end

	-- the raincloud hat, with a rain emitter
	local cloud = Kit.blob(model, Vector3.new(1.5, 0.62, 1.1), CFrame.new(0, 2.5, -0.35), palette.accent, "accent")
	Kit.blob(model, Vector3.new(0.85, 0.55, 0.8), CFrame.new(-0.52, 2.62, -0.3), palette.accent, "accent")
	Kit.blob(model, Vector3.new(0.75, 0.5, 0.75), CFrame.new(0.55, 2.58, -0.42), palette.accent, "accent")
	Kit.particles(cloud, "rain", rgb(150, 200, 255))

	Kit.eyes(model, CFrame.new(0, 1.88, -0.75), 0.3, 0.16)
	Kit.setAnim(model, "waddle", def.animSpeed, 1)
end

-- Puddle Pug: a glossy, low, wrinkled dog made of water with splash paws.
B.puddle_pug = function(model: Model, root: BasePart, palette, def)
	local _ = root
	local glass = Enum.Material.Glass
	-- squat body
	local body = Kit.blob(model, Vector3.new(1.6, 1.15, 1.9), CFrame.new(0, 0.78, 0.1), palette.primary, "primary", glass)
	body.Reflectance = 0.25
	-- big head
	local head = Kit.blob(model, Vector3.new(1.35, 1.2, 1.15), CFrame.new(0, 1.42, -0.85), palette.primary, "primary", glass)
	head.Reflectance = 0.25
	-- wrinkle rolls
	for i = 1, 3 do
		Kit.part(model, {
			name = "Wrinkle" .. tostring(i),
			shape = "Cylinder",
			size = Vector3.new(0.1, 1.1 - i * 0.08, 1.1 - i * 0.08),
			cf = CFrame.new(0, 1.62 - i * 0.16, -1.34) * CFrame.Angles(0, math.rad(90), math.rad(90)),
			color = Kit.lighten(palette.primary, 0.18),
			material = glass,
			transparency = 0.15,
			role = "secondary",
		})
	end
	-- flat pug muzzle
	Kit.blob(model, Vector3.new(0.7, 0.5, 0.35), CFrame.new(0, 1.24, -1.45), palette.secondary, "secondary")
	Kit.part(model, { name = "Nose", shape = "Ball", size = Vector3.new(0.26, 0.2, 0.16), cf = CFrame.new(0, 1.34, -1.62), color = rgb(40, 50, 70), role = "fixed" })

	-- folded ears
	for _, side in { -1, 1 } do
		Kit.part(model, {
			name = "Ear",
			shape = "Ball",
			mesh = "Sphere",
			size = Vector3.new(0.22, 0.55, 0.42),
			cf = CFrame.new(side * 0.62, 1.78, -0.72) * CFrame.Angles(math.rad(15), 0, side * math.rad(18)),
			color = palette.secondary,
			role = "secondary",
		})
	end

	-- curly tail
	Kit.part(model, { name = "Tail", shape = "Cylinder", size = Vector3.new(0.12, 0.5, 0.5), cf = CFrame.new(0, 1.2, 1.0) * CFrame.Angles(0, math.rad(90), 0), color = palette.primary, material = glass, transparency = 0.1 })

	-- splash paws: a flat disc of water under each foot
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.blob(model, Vector3.new(0.42, 0.5, 0.42), CFrame.new(sx * 0.55, 0.3, sz * 0.6 + 0.1), palette.secondary, "secondary", glass)
			local splash = Kit.part(model, {
				name = "Splash",
				shape = "Cylinder",
				size = Vector3.new(0.08, 0.9, 0.9),
				cf = CFrame.new(sx * 0.55, 0.05, sz * 0.6 + 0.1) * UP,
				color = palette.accent,
				material = Enum.Material.Neon,
				transparency = 0.5,
				role = "accent",
			})
			Kit.flickerPart(splash, 0.4, 0.7)
		end
	end

	Kit.eyes(model, CFrame.new(0, 1.6, -1.32), 0.34, 0.2)
	Kit.setAnim(model, "waddle", def.animSpeed, 0.9)
end

-- Monsoon Manta: a wide hovering ray trailing rain.
B.monsoon_manta = function(model: Model, root: BasePart, palette, def)
	local _ = root
	local y = 2.0
	-- central body
	Kit.blob(model, Vector3.new(1.15, 0.55, 2.0), CFrame.new(0, y, 0), palette.primary)

	-- wings: three tapering slabs each side, swept back and tilted
	for _, side in { -1, 1 } do
		for i = 1, 3 do
			local t = i / 3
			Kit.part(model, {
				name = "Wing" .. tostring(i),
				shape = "Ball",
				mesh = "Sphere",
				size = Vector3.new(1.05, 0.3 - t * 0.16, 1.75 - t * 0.5),
				cf = CFrame.new(side * (0.75 + (i - 1) * 0.9), y + t * 0.22, t * 0.32) * CFrame.Angles(0, 0, side * math.rad(-9 * i)),
				color = if i == 3 then palette.accent else palette.primary,
				role = if i == 3 then "accent" else "primary",
			})
		end
	end

	-- pale underside stripe
	Kit.part(model, { name = "Belly", shape = "Ball", mesh = "Sphere", size = Vector3.new(0.9, 0.16, 1.6), cf = CFrame.new(0, y - 0.26, 0), color = palette.secondary, role = "secondary" })

	-- head fins (cephalic lobes) pointing forward
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Lobe", size = Vector3.new(0.2, 0.18, 0.6), cf = CFrame.new(side * 0.34, y - 0.05, -1.15) * CFrame.Angles(0, side * math.rad(9), 0), color = palette.primary })
	end

	-- long trailing tail
	for i = 1, 4 do
		Kit.part(model, {
			name = "Tail" .. tostring(i),
			shape = "Cylinder",
			size = Vector3.new(0.6, 0.22 - i * 0.035, 0.22 - i * 0.035),
			cf = CFrame.new(0, y - i * 0.06, 1.2 + i * 0.55) * CFrame.Angles(0, math.rad(90), 0),
			color = palette.primary,
		})
	end

	-- rain curtain under the wings
	local curtain = Kit.part(model, { name = "RainZone", shape = "Cylinder", size = Vector3.new(0.1, 3.4, 3.4), cf = CFrame.new(0, y - 0.5, 0) * UP, color = palette.accent, material = Enum.Material.Neon, transparency = 0.85, role = "accent" })
	Kit.particles(curtain, "rain", palette.accent)

	Kit.eyes(model, CFrame.new(0, y + 0.12, -0.85), 0.5, 0.2)
	Kit.setAnim(model, "hover", def.animSpeed, 1.3)
end

-- Tsunami Toad: a crowned toad riding a curling wave.
B.tsunami_toad = function(model: Model, root: BasePart, palette, def)
	local _ = root
	local water = palette.secondary
	local glass = Enum.Material.Glass

	-- the wave: a rising ramp that curls over at the top
	Kit.blob(model, Vector3.new(3.6, 1.5, 2.6), CFrame.new(0, 0.7, 0.5), water, "secondary", glass)
	Kit.blob(model, Vector3.new(3.1, 1.5, 1.8), CFrame.new(0, 1.65, 0.85), water, "secondary", glass)
	Kit.blob(model, Vector3.new(2.6, 1.3, 1.3), CFrame.new(0, 2.5, 1.05), water, "secondary", glass)
	-- the curl: a torus-ish lip leaning forward over the toad
	for i = 1, 5 do
		local a = math.rad(-30 + i * 26)
		Kit.part(model, {
			name = "Curl" .. tostring(i),
			shape = "Cylinder",
			size = Vector3.new(2.4, 0.85, 0.85),
			cf = CFrame.new(0, 3.15 + math.sin(a) * 0.75, 0.9 - math.cos(a) * 0.95) * CFrame.Angles(0, math.rad(90), 0),
			color = Kit.lighten(water, 0.15),
			material = glass,
			transparency = 0.22,
			role = "secondary",
		})
	end
	-- foam crest
	for i = 1, 4 do
		Kit.blob(model, Vector3.new(0.7, 0.5, 0.7), CFrame.new(-1.0 + (i - 1) * 0.7, 3.9, 0.1), rgb(245, 250, 255), "fixed")
	end

	-- the toad, sitting on the wave face
	local ty = 2.35
	Kit.blob(model, Vector3.new(2.0, 1.35, 1.8), CFrame.new(0, ty, -0.55), palette.primary)
	Kit.blob(model, Vector3.new(1.75, 1.05, 1.35), CFrame.new(0, ty + 0.75, -0.85), palette.primary) -- head
	-- wide toad mouth
	Kit.part(model, { name = "Mouth", size = Vector3.new(1.35, 0.12, 0.12), cf = CFrame.new(0, ty + 0.5, -1.5), color = rgb(50, 70, 55), role = "fixed" })
	-- bulging eyes on top
	for _, side in { -1, 1 } do
		Kit.blob(model, Vector3.new(0.55, 0.55, 0.55), CFrame.new(side * 0.5, ty + 1.28, -0.95), palette.primary)
		Kit.part(model, { name = "Eye", shape = "Ball", size = Vector3.new(0.4, 0.4, 0.4), cf = CFrame.new(side * 0.5, ty + 1.38, -1.05), color = rgb(255, 255, 255), role = "fixed" })
		Kit.part(model, { name = "Iris", shape = "Ball", size = Vector3.new(0.2, 0.2, 0.2), cf = CFrame.new(side * 0.5, ty + 1.38, -1.22), color = rgb(30, 30, 40), role = "fixed" })
	end
	-- warty spots
	for i = 1, 5 do
		Kit.blob(model, Vector3.new(0.28, 0.2, 0.28), CFrame.new(-0.7 + (i - 1) * 0.35, ty + 0.6, -0.1), Kit.darken(palette.primary, 0.22))
	end
	-- front legs
	for _, side in { -1, 1 } do
		Kit.blob(model, Vector3.new(0.4, 0.7, 0.4), CFrame.new(side * 0.85, ty - 0.55, -1.05), palette.primary)
		Kit.part(model, { name = "Toes", size = Vector3.new(0.55, 0.16, 0.5), cf = CFrame.new(side * 0.85, ty - 0.9, -1.2), color = Kit.darken(palette.primary, 0.15) })
	end

	-- crown
	Kit.part(model, { name = "CrownBand", shape = "Cylinder", size = Vector3.new(0.22, 1.1, 1.1), cf = CFrame.new(0, ty + 1.62, -0.85) * UP, color = palette.accent, material = Enum.Material.Metal, role = "accent" })
	for i = 1, 5 do
		local a = math.rad(-90 + (i - 1) * 45)
		Kit.part(model, {
			name = "Spike" .. tostring(i),
			shape = "Wedge",
			size = Vector3.new(0.16, 0.42, 0.3),
			cf = CFrame.new(math.sin(a) * 0.48, ty + 1.88, -0.85 - math.cos(a) * 0.48) * CFrame.Angles(0, a, 0),
			color = palette.accent,
			material = Enum.Material.Metal,
			role = "accent",
		})
	end

	Kit.particles(Kit.root(model), "sparkle", rgb(200, 235, 255))
	Kit.setAnim(model, "bob", def.animSpeed, 1.1)
end

return B
