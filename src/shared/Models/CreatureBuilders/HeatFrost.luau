--!strict
-- Cinder Canyon (Heat) and Frostbite Peaks (Frost) creature builders.
-- Feet at y = 0, +Y up, face on -Z. The dispatcher calls finalize/variant/glow.

local Kit = require(script.Parent.Parent.ModelKit)

local B = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local UP = CFrame.Angles(0, 0, math.rad(90))

-- ---------------------------------------------------------------- Heat

-- Cinder Chick: a sooty round chick with a burning crest.
B.cinder_chick = function(model: Model, _root: BasePart, palette, def)
	Kit.blob(model, Vector3.new(1.25, 1.2, 1.15), CFrame.new(0, 0.72, 0), palette.primary) -- body
	Kit.blob(model, Vector3.new(0.95, 0.9, 0.9), CFrame.new(0, 1.5, -0.12), palette.primary) -- head

	-- ember crest: three neon flames of rising height
	for i = 1, 3 do
		local h = 0.4 + i * 0.16
		local flame = Kit.part(model, {
			name = "Crest" .. tostring(i),
			shape = "Wedge",
			size = Vector3.new(0.14, h, 0.34),
			cf = CFrame.new((i - 2) * 0.24, 1.95 + h / 2 - 0.2, -0.05) * CFrame.Angles(0, 0, (i - 2) * math.rad(-12)),
			color = if i == 2 then palette.accent else palette.secondary,
			material = Enum.Material.Neon,
			role = "accent",
		})
		Kit.flickerPart(flame, 0, 0.35)
	end
	Kit.light(Kit.root(model), palette.secondary, 0.9, 9)

	-- little beak
	Kit.part(model, { name = "Beak", shape = "Wedge", size = Vector3.new(0.26, 0.22, 0.3), cf = CFrame.new(0, 1.4, -0.62) * CFrame.Angles(0, math.rad(180), 0), color = palette.accent, role = "accent" })

	-- stubby wings
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Wing", shape = "Ball", mesh = "Sphere", size = Vector3.new(0.16, 0.5, 0.6), cf = CFrame.new(side * 0.62, 0.78, 0.05), color = Kit.lighten(palette.primary, 0.12) })
	end

	-- glowing cracks along the body
	for i = 1, 3 do
		Kit.part(model, { name = "Crack", size = Vector3.new(0.08, 0.34, 0.06), cf = CFrame.new(-0.3 + (i - 1) * 0.3, 0.7, -0.55) * CFrame.Angles(0, 0, math.rad(18 * i)), color = palette.secondary, material = Enum.Material.Neon, role = "accent" })
	end

	-- feet
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Foot", size = Vector3.new(0.3, 0.1, 0.42), cf = CFrame.new(side * 0.27, 0.05, -0.1), color = palette.accent, role = "accent" })
	end

	Kit.eyes(model, CFrame.new(0, 1.62, -0.46), 0.26, 0.16)
	Kit.particles(Kit.root(model), "smoke", rgb(90, 80, 80))
	Kit.setAnim(model, "hop", def.animSpeed, 1)
end

-- Sizzle Salamander: a low lizard with glowing vents down its spine.
B.sizzle_salamander = function(model: Model, _root: BasePart, palette, def)
	-- segmented body, low to the ground
	for i = 1, 4 do
		local w = 0.95 - (i - 1) * 0.1
		Kit.blob(model, Vector3.new(w, w * 0.75, 0.75), CFrame.new(0, 0.55, -0.45 + (i - 1) * 0.6), palette.primary)
	end
	-- head
	Kit.blob(model, Vector3.new(0.95, 0.6, 0.95), CFrame.new(0, 0.58, -1.15), palette.primary)
	Kit.part(model, { name = "Jaw", size = Vector3.new(0.7, 0.1, 0.1), cf = CFrame.new(0, 0.38, -1.6), color = rgb(50, 30, 25), role = "fixed" })

	-- tapering tail
	for i = 1, 4 do
		Kit.part(model, {
			name = "Tail" .. tostring(i),
			shape = "Cylinder",
			size = Vector3.new(0.5, 0.5 - i * 0.09, 0.5 - i * 0.09),
			cf = CFrame.new(math.sin(i * 0.9) * 0.2, 0.48, 1.9 + (i - 1) * 0.42) * CFrame.Angles(0, math.rad(90) + math.sin(i * 0.9) * 0.3, 0),
			color = palette.primary,
		})
	end

	-- back vents: neon slots that pulse
	for i = 1, 4 do
		local vent = Kit.part(model, {
			name = "Vent" .. tostring(i),
			shape = "Cylinder",
			size = Vector3.new(0.12, 0.42, 0.42),
			cf = CFrame.new(0, 0.92, -0.45 + (i - 1) * 0.6) * UP,
			color = palette.accent,
			material = Enum.Material.Neon,
			role = "accent",
		})
		Kit.flickerPart(vent, 0, 0.5)
	end
	Kit.light(Kit.root(model), palette.secondary, 1.0, 10)

	-- four splayed legs
	for _, side in { -1, 1 } do
		for _, fz in { -0.55, 0.95 } do
			Kit.part(model, { name = "Leg", shape = "Cylinder", size = Vector3.new(0.55, 0.22, 0.22), cf = CFrame.new(side * 0.55, 0.28, fz) * CFrame.Angles(0, 0, side * math.rad(60)), color = palette.secondary, role = "secondary" })
			Kit.part(model, { name = "Foot", size = Vector3.new(0.34, 0.1, 0.36), cf = CFrame.new(side * 0.75, 0.05, fz), color = palette.secondary, role = "secondary" })
		end
	end

	Kit.eyes(model, CFrame.new(0, 0.78, -1.5), 0.2, 0.12, rgb(255, 220, 90))
	Kit.particles(Kit.root(model), "fire", palette.secondary)
	Kit.setAnim(model, "sway", def.animSpeed, 0.8)
end

-- Magma Muncher: a squat lava blob that is mostly mouth.
B.magma_muncher = function(model: Model, _root: BasePart, palette, def)
	-- crusted rock shell
	Kit.blob(model, Vector3.new(2.5, 2.1, 2.2), CFrame.new(0, 1.15, 0), palette.primary)
	-- lumps of cooled crust
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2
		Kit.blob(model, Vector3.new(0.7, 0.5, 0.7), CFrame.new(math.sin(a) * 0.95, 1.85 + math.cos(a * 2) * 0.18, math.cos(a) * 0.85), Kit.darken(palette.primary, 0.18))
	end

	-- furnace jaws: a wide open mouth on -Z
	Kit.part(model, { name = "MouthBack", size = Vector3.new(1.9, 1.1, 0.3), cf = CFrame.new(0, 1.05, -0.85), color = rgb(30, 12, 10), role = "fixed" })
	local glow = Kit.part(model, { name = "MouthGlow", size = Vector3.new(1.75, 0.95, 0.14), cf = CFrame.new(0, 1.05, -0.95), color = palette.secondary, material = Enum.Material.Neon, role = "accent" })
	Kit.flickerPart(glow, 0, 0.3)
	Kit.particles(glow, "fire", palette.secondary)
	Kit.light(glow, palette.secondary, 1.6, 14)
	-- upper and lower jaw plates
	Kit.part(model, { name = "UpperJaw", shape = "Wedge", size = Vector3.new(2.0, 0.5, 0.7), cf = CFrame.new(0, 1.72, -1.05) * CFrame.Angles(math.rad(20), math.rad(180), 0), color = palette.primary })
	Kit.part(model, { name = "LowerJaw", shape = "Wedge", size = Vector3.new(2.0, 0.45, 0.7), cf = CFrame.new(0, 0.42, -1.05) * CFrame.Angles(math.rad(-155), math.rad(180), 0), color = palette.primary })
	-- teeth
	for i = 1, 5 do
		local x = -0.7 + (i - 1) * 0.35
		Kit.part(model, { name = "ToothUp", shape = "Wedge", size = Vector3.new(0.2, 0.34, 0.18), cf = CFrame.new(x, 1.42, -1.0) * CFrame.Angles(math.rad(180), 0, 0), color = rgb(245, 240, 225), role = "fixed" })
		Kit.part(model, { name = "ToothDown", shape = "Wedge", size = Vector3.new(0.2, 0.3, 0.18), cf = CFrame.new(x + 0.17, 0.66, -1.0), color = rgb(245, 240, 225), role = "fixed" })
	end

	-- lava seams
	for i = 1, 4 do
		Kit.part(model, { name = "Seam", size = Vector3.new(0.12, 0.9, 0.1), cf = CFrame.new(-0.95 + (i - 1) * 0.65, 1.3, 1.05) * CFrame.Angles(0, 0, math.rad(-20 + i * 12)), color = palette.secondary, material = Enum.Material.Neon, role = "accent" })
	end

	-- stubby legs
	Kit.legs(model, CFrame.new(0, 0.5, 0), Vector2.new(1.2, 1.0), 0.5, 0.44, Kit.darken(palette.primary, 0.1), "secondary")

	-- small angry eyes above the mouth
	Kit.eyes(model, CFrame.new(0, 2.05, -0.98), 0.46, 0.2, rgb(255, 200, 60))
	Kit.particles(Kit.root(model), "smoke", rgb(70, 60, 58))
	Kit.setAnim(model, "pulse", def.animSpeed, 1)
end

-- Mount Chomp: a giant tortoise carrying an erupting volcano.
B.mount_chomp = function(model: Model, _root: BasePart, palette, def)
	-- shell: a dome of stacked discs forming the volcano cone
	local coneWidths = { 4.2, 3.7, 3.1, 2.5, 1.9, 1.3 }
	for i, w in coneWidths do
		Kit.part(model, {
			name = "Cone" .. tostring(i),
			shape = "Cylinder",
			size = Vector3.new(0.55, w, w),
			cf = CFrame.new(0, 2.0 + (i - 1) * 0.52, 0) * UP,
			color = if i <= 2 then palette.secondary else Kit.blend(palette.secondary, rgb(60, 45, 40), 0.3),
			role = "secondary",
		})
	end
	-- crater
	local crater = Kit.part(model, { name = "Crater", shape = "Cylinder", size = Vector3.new(0.3, 1.0, 1.0), cf = CFrame.new(0, 5.05, 0) * UP, color = palette.accent, material = Enum.Material.Neon, role = "accent" })
	Kit.particles(crater, "fire", palette.accent)
	Kit.particles(crater, "smoke", rgb(80, 72, 70))
	Kit.light(crater, palette.accent, 1.8, 20)
	-- lava running down the cone
	for i = 1, 5 do
		local a = (i / 5) * math.pi * 2
		Kit.part(model, {
			name = "Lava" .. tostring(i),
			size = Vector3.new(0.22, 2.2, 0.16),
			cf = CFrame.new(math.sin(a) * 1.5, 3.5, math.cos(a) * 1.5) * CFrame.Angles(math.cos(a) * 0.35, a, -math.sin(a) * 0.35),
			color = palette.accent,
			material = Enum.Material.Neon,
			role = "accent",
		})
	end

	-- tortoise body under the shell
	Kit.blob(model, Vector3.new(4.0, 1.5, 3.4), CFrame.new(0, 1.5, 0), palette.primary)
	-- head on a thick neck
	Kit.blob(model, Vector3.new(1.1, 1.0, 1.3), CFrame.new(0, 1.6, -1.9), palette.primary)
	Kit.blob(model, Vector3.new(1.35, 1.15, 1.35), CFrame.new(0, 1.75, -2.75), palette.primary)
	Kit.part(model, { name = "Mouth", size = Vector3.new(0.85, 0.1, 0.1), cf = CFrame.new(0, 1.42, -3.36), color = rgb(45, 55, 40), role = "fixed" })
	Kit.eyes(model, CFrame.new(0, 1.98, -3.3), 0.52, 0.2)
	-- nostril smoke
	for _, side in { -1, 1 } do
		local n = Kit.part(model, { name = "Nostril", shape = "Ball", size = Vector3.new(0.14, 0.14, 0.1), cf = CFrame.new(side * 0.24, 1.66, -3.38), color = rgb(40, 50, 38), role = "fixed" })
		Kit.particles(n, "smoke", rgb(120, 110, 105))
	end

	-- four heavy legs
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.part(model, { name = "Leg", shape = "Cylinder", size = Vector3.new(1.1, 1.1, 1.1), cf = CFrame.new(sx * 1.5, 0.55, sz * 1.2) * UP, color = Kit.darken(palette.primary, 0.12) })
			Kit.part(model, { name = "Foot", shape = "Cylinder", size = Vector3.new(0.28, 1.3, 1.3), cf = CFrame.new(sx * 1.5, 0.14, sz * 1.2) * UP, color = Kit.darken(palette.primary, 0.25) })
		end
	end
	-- short tail
	Kit.part(model, { name = "Tail", shape = "Cylinder", size = Vector3.new(0.8, 0.4, 0.4), cf = CFrame.new(0, 1.4, 1.9) * CFrame.Angles(0, math.rad(90), 0), color = palette.primary })

	Kit.setAnim(model, "bob", def.animSpeed, 0.7)
end

-- ---------------------------------------------------------------- Frost

-- Flurry Ferret: a long snow ferret with a six-armed snowflake tail.
B.flurry_ferret = function(model: Model, _root: BasePart, palette, def)
	-- long low body
	for i = 1, 4 do
		Kit.blob(model, Vector3.new(0.72, 0.7, 0.85), CFrame.new(0, 0.68 + math.sin(i * 0.8) * 0.06, -0.7 + (i - 1) * 0.55), palette.primary)
	end
	-- head
	Kit.blob(model, Vector3.new(0.72, 0.66, 0.8), CFrame.new(0, 0.82, -1.32), palette.primary)
	Kit.part(model, { name = "Snout", shape = "Wedge", size = Vector3.new(0.34, 0.26, 0.36), cf = CFrame.new(0, 0.72, -1.78) * CFrame.Angles(0, math.rad(180), 0), color = palette.secondary, role = "secondary" })
	Kit.part(model, { name = "Nose", shape = "Ball", size = Vector3.new(0.16, 0.13, 0.12), cf = CFrame.new(0, 0.78, -1.95), color = rgb(70, 90, 120), role = "fixed" })
	-- mask markings
	Kit.part(model, { name = "Mask", size = Vector3.new(0.6, 0.2, 0.1), cf = CFrame.new(0, 0.95, -1.62), color = palette.accent, role = "accent" })
	-- round ears
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Ear", shape = "Cylinder", size = Vector3.new(0.1, 0.3, 0.3), cf = CFrame.new(side * 0.28, 1.14, -1.25) * CFrame.Angles(0, math.rad(90), 0), color = palette.secondary, role = "secondary" })
	end

	-- snowflake tail: hub + six arms with side spurs
	local hubY, hubZ = 1.25, 1.45
	Kit.part(model, { name = "TailStalk", shape = "Cylinder", size = Vector3.new(0.7, 0.18, 0.18), cf = CFrame.new(0, 0.95, 1.0) * CFrame.Angles(0, math.rad(90), math.rad(35)), color = palette.primary })
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2
		local arm = Kit.part(model, {
			name = "Flake" .. tostring(i),
			size = Vector3.new(0.1, 0.8, 0.1),
			cf = CFrame.new(math.sin(a) * 0.4, hubY + math.cos(a) * 0.4, hubZ) * CFrame.Angles(0, 0, -a),
			color = palette.accent,
			material = Enum.Material.Neon,
			role = "accent",
		})
		Kit.part(model, {
			name = "Spur" .. tostring(i),
			size = Vector3.new(0.08, 0.3, 0.08),
			cf = CFrame.new(math.sin(a) * 0.62, hubY + math.cos(a) * 0.62, hubZ) * CFrame.Angles(0, 0, -a + math.rad(40)),
			color = palette.accent,
			material = Enum.Material.Neon,
			role = "accent",
		})
		local _ = arm
	end
	Kit.part(model, { name = "FlakeHub", shape = "Ball", size = Vector3.new(0.3, 0.3, 0.3), cf = CFrame.new(0, hubY, hubZ), color = palette.accent, material = Enum.Material.Neon, role = "accent" })

	-- short legs
	for _, side in { -1, 1 } do
		for _, fz in { -0.85, 0.6 } do
			Kit.part(model, { name = "Leg", shape = "Cylinder", size = Vector3.new(0.42, 0.2, 0.2), cf = CFrame.new(side * 0.32, 0.22, fz) * UP, color = palette.secondary, role = "secondary" })
		end
	end

	Kit.eyes(model, CFrame.new(0, 0.95, -1.62), 0.24, 0.12, rgb(90, 150, 220))
	Kit.particles(Kit.root(model), "sparkle", palette.accent)
	Kit.setAnim(model, "waddle", def.animSpeed, 1)
end

-- Slush Sloth: a sleepy sloth hanging under its own ice arch.
B.slush_sloth = function(model: Model, _root: BasePart, palette, def)
	local ice = Enum.Material.Glass
	-- the arch: two legs and a span of ice
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "ArchLeg", shape = "Cylinder", size = Vector3.new(2.6, 0.5, 0.5), cf = CFrame.new(side * 1.25, 1.3, 0) * UP * CFrame.Angles(0, 0, side * math.rad(-8)), color = palette.accent, material = ice, transparency = 0.28, role = "accent" })
	end
	for i = 1, 5 do
		local a = math.rad(20 + (i - 1) * 35)
		Kit.part(model, {
			name = "ArchSpan" .. tostring(i),
			shape = "Cylinder",
			size = Vector3.new(0.55, 0.5, 0.5),
			cf = CFrame.new(-math.cos(a) * 1.35, 2.6 + math.sin(a) * 0.45, 0) * CFrame.Angles(0, math.rad(90), 0),
			color = palette.accent,
			material = ice,
			transparency = 0.28,
			role = "accent",
		})
	end
	-- icicles under the arch
	for i = 1, 4 do
		Kit.part(model, { name = "Icicle", shape = "Wedge", size = Vector3.new(0.12, 0.45, 0.16), cf = CFrame.new(-1.0 + (i - 1) * 0.66, 2.5, 0.22) * CFrame.Angles(math.rad(180), 0, 0), color = palette.accent, material = ice, transparency = 0.2, role = "accent" })
	end

	-- the sloth, hanging below
	local by = 1.65
	Kit.blob(model, Vector3.new(1.2, 1.5, 1.05), CFrame.new(0, by, -0.05), palette.primary)
	Kit.blob(model, Vector3.new(1.0, 0.95, 0.95), CFrame.new(0, by + 0.95, -0.15), palette.primary)
	-- shaggy chest
	Kit.blob(model, Vector3.new(0.85, 1.0, 0.5), CFrame.new(0, by - 0.05, -0.55), palette.secondary, "secondary")
	-- face mask
	Kit.part(model, { name = "Face", shape = "Ball", mesh = "Sphere", size = Vector3.new(0.75, 0.6, 0.2), cf = CFrame.new(0, by + 0.92, -0.62), color = palette.secondary, role = "secondary" })
	-- sleepy closed eyes (lines)
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Eyelid", size = Vector3.new(0.2, 0.05, 0.06), cf = CFrame.new(side * 0.2, by + 1.0, -0.7), color = rgb(45, 55, 70), role = "fixed" })
	end
	Kit.part(model, { name = "Nose", shape = "Ball", size = Vector3.new(0.16, 0.12, 0.1), cf = CFrame.new(0, by + 0.82, -0.72), color = rgb(50, 62, 80), role = "fixed" })
	Kit.part(model, { name = "Smile", size = Vector3.new(0.26, 0.05, 0.06), cf = CFrame.new(0, by + 0.68, -0.7), color = rgb(50, 62, 80), role = "fixed" })

	-- long arms reaching up to the arch
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Arm", shape = "Cylinder", size = Vector3.new(1.35, 0.28, 0.28), cf = CFrame.new(side * 0.62, by + 1.25, 0.02) * CFrame.Angles(0, 0, side * math.rad(50)), color = palette.primary })
		-- hooked claws over the arch
		for c = 1, 3 do
			Kit.part(model, { name = "Claw", shape = "Wedge", size = Vector3.new(0.08, 0.34, 0.12), cf = CFrame.new(side * 1.12 + (c - 2) * 0.12, by + 1.95, 0.06) * CFrame.Angles(math.rad(-20), 0, 0), color = rgb(230, 236, 245), role = "fixed" })
		end
	end
	-- dangling feet
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Leg", shape = "Cylinder", size = Vector3.new(0.7, 0.26, 0.26), cf = CFrame.new(side * 0.4, by - 0.95, -0.05) * CFrame.Angles(0, 0, side * math.rad(14)), color = palette.primary })
	end

	Kit.particles(Kit.root(model), "sparkle", rgb(210, 240, 255))
	Kit.setAnim(model, "sway", def.animSpeed, 0.7)
end

-- Blizzard Bison: a shaggy bison with icicle horns.
B.blizzard_bison = function(model: Model, _root: BasePart, palette, def)
	-- big shoulder hump then a lower rear
	Kit.blob(model, Vector3.new(2.1, 1.85, 2.0), CFrame.new(0, 2.05, -0.55), palette.primary)
	Kit.blob(model, Vector3.new(1.85, 1.45, 1.9), CFrame.new(0, 1.7, 1.05), palette.primary)
	-- shaggy coat: fur tufts around the shoulders
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		Kit.blob(model, Vector3.new(0.6, 0.75, 0.6), CFrame.new(math.sin(a) * 1.0, 1.55 + math.cos(a * 2) * 0.15, -0.55 + math.cos(a) * 0.9), Kit.lighten(palette.primary, 0.1))
	end
	-- snow on the back
	Kit.blob(model, Vector3.new(1.75, 0.4, 1.7), CFrame.new(0, 2.95, -0.55), palette.secondary, "secondary")

	-- low head
	Kit.blob(model, Vector3.new(1.15, 1.15, 1.3), CFrame.new(0, 1.55, -1.95), palette.primary)
	Kit.blob(model, Vector3.new(0.8, 0.6, 0.55), CFrame.new(0, 1.28, -2.55), palette.secondary, "secondary") -- muzzle
	for _, side in { -1, 1 } do
		local n = Kit.part(model, { name = "Nostril", shape = "Ball", size = Vector3.new(0.14, 0.12, 0.1), cf = CFrame.new(side * 0.2, 1.3, -2.78), color = rgb(60, 75, 95), role = "fixed" })
		Kit.particles(n, "smoke", rgb(225, 240, 255))
	end
	-- shaggy forelock
	Kit.blob(model, Vector3.new(1.05, 0.55, 0.7), CFrame.new(0, 2.15, -2.05), Kit.lighten(palette.primary, 0.15))

	-- icicle horns curving out and forward
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "HornBase", shape = "Cylinder", size = Vector3.new(0.55, 0.34, 0.34), cf = CFrame.new(side * 0.66, 2.05, -1.95) * CFrame.Angles(0, 0, side * math.rad(70)), color = palette.accent, material = Enum.Material.Glass, transparency = 0.15, role = "accent" })
		Kit.part(model, { name = "HornTip", shape = "Wedge", size = Vector3.new(0.2, 0.85, 0.28), cf = CFrame.new(side * 1.05, 2.28, -2.15) * CFrame.Angles(math.rad(-25), 0, side * math.rad(28)), color = palette.accent, material = Enum.Material.Glass, transparency = 0.1, role = "accent" })
	end

	-- four thick legs
	for _, sx in { -1, 1 } do
		for _, sz in { -1.05, 1.35 } do
			Kit.part(model, { name = "Leg", shape = "Cylinder", size = Vector3.new(1.1, 0.6, 0.6), cf = CFrame.new(sx * 0.72, 0.55, sz) * UP, color = Kit.darken(palette.primary, 0.2) })
			Kit.part(model, { name = "Hoof", shape = "Cylinder", size = Vector3.new(0.2, 0.68, 0.68), cf = CFrame.new(sx * 0.72, 0.1, sz) * UP, color = rgb(60, 60, 72), role = "fixed" })
		end
	end
	Kit.part(model, { name = "Tail", shape = "Cylinder", size = Vector3.new(0.9, 0.16, 0.16), cf = CFrame.new(0, 1.75, 2.05) * CFrame.Angles(0, math.rad(90), math.rad(-60)), color = palette.primary })

	Kit.eyes(model, CFrame.new(0, 1.78, -2.5), 0.44, 0.16, rgb(80, 140, 200))
	Kit.setAnim(model, "bob", def.animSpeed, 0.9)
end

-- King Coldsnout: a royal mammoth wearing a glacier crown.
B.king_coldsnout = function(model: Model, _root: BasePart, palette, def)
	local ice = Enum.Material.Glass
	-- huge body
	Kit.blob(model, Vector3.new(3.0, 2.7, 3.4), CFrame.new(0, 2.55, 0.35), palette.primary)
	-- shaggy skirt of fur
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2
		Kit.blob(model, Vector3.new(0.7, 1.3, 0.7), CFrame.new(math.sin(a) * 1.4, 1.75, 0.35 + math.cos(a) * 1.6), palette.secondary, "secondary")
	end
	-- domed head
	Kit.blob(model, Vector3.new(2.0, 2.0, 1.8), CFrame.new(0, 3.15, -1.75), palette.primary)
	-- big ears
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Ear", shape = "Ball", mesh = "Sphere", size = Vector3.new(0.25, 1.5, 1.2), cf = CFrame.new(side * 1.1, 3.15, -1.55) * CFrame.Angles(0, side * math.rad(-18), 0), color = Kit.darken(palette.primary, 0.1) })
	end
	-- trunk, in three segments curving down and forward
	local trunkPts = { { 2.55, -2.5, 0.42 }, { 1.85, -2.85, 0.36 }, { 1.25, -2.95, 0.3 } }
	for i, p in trunkPts do
		Kit.part(model, { name = "Trunk" .. tostring(i), shape = "Cylinder", size = Vector3.new(0.75, p[3] * 2, p[3] * 2), cf = CFrame.new(0, p[1], p[2]) * CFrame.Angles(math.rad(60 - i * 18), 0, 0) * UP, color = palette.primary })
	end
	-- tusks
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Tusk", shape = "Cylinder", size = Vector3.new(1.6, 0.3, 0.3), cf = CFrame.new(side * 0.72, 2.5, -2.5) * CFrame.Angles(math.rad(20), 0, side * math.rad(72)), color = rgb(248, 246, 235), role = "fixed" })
		Kit.part(model, { name = "TuskTip", shape = "Wedge", size = Vector3.new(0.22, 0.6, 0.26), cf = CFrame.new(side * 1.3, 2.05, -2.9) * CFrame.Angles(math.rad(160), 0, side * math.rad(-25)), color = rgb(248, 246, 235), role = "fixed" })
	end

	-- glacier crown: jagged ice blocks on a band
	Kit.part(model, { name = "CrownBand", shape = "Cylinder", size = Vector3.new(0.35, 1.9, 1.9), cf = CFrame.new(0, 4.3, -1.75) * UP, color = palette.accent, material = ice, transparency = 0.18, role = "accent" })
	for i = 1, 7 do
		local a = math.rad(-135 + (i - 1) * 45)
		local h = if i % 2 == 0 then 0.6 else 1.0
		Kit.part(model, {
			name = "Glacier" .. tostring(i),
			size = Vector3.new(0.34, h, 0.34),
			cf = CFrame.new(math.sin(a) * 0.82, 4.5 + h / 2, -1.75 - math.cos(a) * 0.82) * CFrame.Angles(math.rad(4), a, math.rad(6)),
			color = palette.accent,
			material = ice,
			transparency = 0.12,
			role = "accent",
		})
	end
	Kit.light(Kit.root(model), palette.accent, 1.2, 16)

	-- four pillar legs
	for _, sx in { -1, 1 } do
		for _, sz in { -0.75, 1.6 } do
			Kit.part(model, { name = "Leg", shape = "Cylinder", size = Vector3.new(1.4, 1.0, 1.0), cf = CFrame.new(sx * 1.05, 0.7, sz) * UP, color = palette.primary })
			Kit.part(model, { name = "Foot", shape = "Cylinder", size = Vector3.new(0.3, 1.2, 1.2), cf = CFrame.new(sx * 1.05, 0.15, sz) * UP, color = Kit.darken(palette.primary, 0.2) })
		end
	end

	Kit.eyes(model, CFrame.new(0, 3.5, -2.6), 0.72, 0.2, rgb(120, 190, 255))
	Kit.particles(Kit.root(model), "sparkle", rgb(220, 245, 255))
	Kit.setAnim(model, "bob", def.animSpeed, 0.8)
end

return B
