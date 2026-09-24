--!strict
-- Thunderworks (Storm) and Orbit Outpost (Cosmic) creature builders.
-- Feet at y = 0, +Y up, face on -Z. The dispatcher calls finalize/variant/glow.

local Kit = require(script.Parent.Parent.ModelKit)
local ToyFace = require(script.Parent.Parent.ToyFace)

local B = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local UP = CFrame.Angles(0, 0, math.rad(90))

-- ---------------------------------------------------------------- Storm

-- Static Sprout: a seedling whose hair stands permanently on end.
B.static_sprout = function(model: Model, _root: BasePart, palette, def)
	-- pot-shaped root ball
	Kit.part(model, { name = "Base", shape = "Cylinder", size = Vector3.new(0.5, 1.05, 1.05), cf = CFrame.new(0, 0.25, 0) * UP, color = Kit.darken(palette.primary, 0.3), role = "secondary" })
	-- stem
	Kit.part(model, { name = "Stem", shape = "Cylinder", size = Vector3.new(0.95, 0.42, 0.42), cf = CFrame.new(0, 0.95, 0) * UP, color = palette.primary })
	-- body / head bud
	Kit.blob(model, Vector3.new(1.17, 1.06, 1.0), CFrame.new(0, 1.6, -0.05), palette.primary)
	Kit.blob(model, Vector3.new(0.85, 0.68, 0.18), CFrame.new(0, 1.57, -0.51), rgb(232, 240, 186), "fixed")

	-- two leaf arms
	for _, side in { -1, 1 } do
		Kit.part(model, {
			name = "Leaf",
			shape = "Ball",
			mesh = "Sphere",
			size = Vector3.new(0.85, 0.14, 0.42),
			cf = CFrame.new(side * 0.68, 1.3, 0.05) * CFrame.Angles(0, 0, side * math.rad(28)),
			color = palette.primary,
		})
	end

	-- electric hair: neon spikes standing straight up, flickering
	for i = 1, 7 do
		local a = (i / 7) * math.pi * 2
		local h = 0.5 + (i % 3) * 0.18
		local spike = Kit.part(model, {
			name = "Hair" .. tostring(i),
			size = Vector3.new(0.09, h, 0.09),
			cf = CFrame.new(math.sin(a) * 0.3, 2.15 + h / 2, -0.05 + math.cos(a) * 0.3) * CFrame.Angles(math.cos(a) * 0.2, 0, -math.sin(a) * 0.2),
			color = palette.secondary,
			material = Enum.Material.Neon,
			role = "accent",
		})
		Kit.flickerPart(spike, 0, 0.45)
	end
	local tip = Kit.part(model, { name = "Spark", shape = "Ball", size = Vector3.new(0.3, 0.3, 0.3), cf = CFrame.new(0, 2.75, -0.05), color = palette.accent, material = Enum.Material.Neon, role = "accent" })
	Kit.particles(tip, "lightning", palette.secondary)
	Kit.light(tip, palette.secondary, 1.1, 10)

	ToyFace.eyes(model, CFrame.new(0, 1.73, -0.6), 0.49, 0.2)
	ToyFace.smile(model, CFrame.new(0, 1.41, -0.61), 0.34)
	Kit.setAnim(model, "bob", def.animSpeed, 1.2)
end

-- Zap Raccoon: a raccoon whose tail is banded with lightning.
B.zap_raccoon = function(model: Model, _root: BasePart, palette, def)
	Kit.blob(model, Vector3.new(1.25, 1.15, 1.5), CFrame.new(0, 1.0, 0.1), palette.primary)
	Kit.blob(model, Vector3.new(1.23, 1.08, 1.02), CFrame.new(0, 1.82, -0.5), palette.primary)
	-- pointed snout
	Kit.part(model, { name = "Snout", shape = "Wedge", size = Vector3.new(0.4, 0.34, 0.45), cf = CFrame.new(0, 1.68, -1.05) * CFrame.Angles(0, math.rad(180), 0), color = Kit.lighten(palette.primary, 0.25) })
	Kit.part(model, { name = "Nose", shape = "Ball", size = Vector3.new(0.16, 0.14, 0.12), cf = CFrame.new(0, 1.74, -1.28), color = rgb(30, 30, 36), role = "fixed" })
	-- bandit mask
	Kit.part(model, { name = "Mask", shape = "Ball", mesh = "Sphere", size = Vector3.new(1.03, 0.43, 0.2), cf = CFrame.new(0, 1.96, -0.96), color = rgb(35, 35, 45), role = "fixed" })
	-- ears
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Ear", shape = "Wedge", size = Vector3.new(0.14, 0.42, 0.36), cf = CFrame.new(side * 0.42, 2.42, -0.42) * CFrame.Angles(0, side * math.rad(12), 0), color = palette.primary })
	end

	-- striped tail, arcing up behind: alternating dark and neon bands
	for i = 1, 6 do
		local a = math.rad(14 * i)
		local band = Kit.part(model, {
			name = "TailBand" .. tostring(i),
			shape = "Cylinder",
			size = Vector3.new(0.36, 0.62 - i * 0.03, 0.62 - i * 0.03),
			cf = CFrame.new(0, 1.15 + i * 0.32, 0.85 + math.sin(a) * 0.55) * CFrame.Angles(0, math.rad(90), math.rad(70 - i * 9)),
			color = if i % 2 == 0 then palette.secondary else rgb(60, 60, 78),
			material = if i % 2 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			role = if i % 2 == 0 then "accent" else "primary",
		})
		if i % 2 == 0 then
			Kit.flickerPart(band, 0, 0.4)
		end
	end
	local tailTip = Kit.part(model, { name = "TailTip", shape = "Wedge", size = Vector3.new(0.2, 0.5, 0.35), cf = CFrame.new(0, 3.2, 1.35) * CFrame.Angles(math.rad(-30), 0, 0), color = palette.secondary, material = Enum.Material.Neon, role = "accent" })
	Kit.particles(tailTip, "lightning", palette.secondary)
	Kit.light(tailTip, palette.secondary, 1.0, 11)

	-- little hands
	for _, side in { -1, 1 } do
		Kit.blob(model, Vector3.new(0.3, 0.55, 0.3), CFrame.new(side * 0.62, 1.15, -0.4), Kit.darken(palette.primary, 0.15))
	end
	Kit.legs(model, CFrame.new(0, 0.5, 0.1), Vector2.new(0.62, 0.7), 0.5, 0.28, Kit.darken(palette.primary, 0.2), "secondary")

	ToyFace.eyes(model, CFrame.new(0, 1.99, -1.07), 0.54, 0.21)
	ToyFace.smile(model, CFrame.new(0, 1.58, -1.26), 0.34)
	Kit.setAnim(model, "waddle", def.animSpeed, 1.1)
end

-- Thunder Thumper: a gorilla whose fists are thunderheads.
B.thunder_thumper = function(model: Model, _root: BasePart, palette, def)
	-- broad chest, narrow hips
	Kit.blob(model, Vector3.new(2.3, 1.9, 1.6), CFrame.new(0, 2.45, 0), palette.primary)
	Kit.blob(model, Vector3.new(1.55, 1.2, 1.3), CFrame.new(0, 1.45, 0.08), palette.primary)
	-- pale chest patch
	Kit.part(model, { name = "Chest", shape = "Ball", mesh = "Sphere", size = Vector3.new(1.3, 1.2, 0.3), cf = CFrame.new(0, 2.4, -0.78), color = Kit.lighten(palette.primary, 0.22), role = "secondary" })

	-- head, low between the shoulders
	Kit.blob(model, Vector3.new(1.49, 1.22, 1.26), CFrame.new(0, 3.6, -0.25), palette.primary)
	Kit.blob(model, Vector3.new(0.95, 0.62, 0.55), CFrame.new(0, 3.4, -0.85), Kit.lighten(palette.primary, 0.3), "secondary") -- brow/muzzle
	Kit.part(model, { name = "Brow", shape = "Ball", mesh = "Sphere", size = Vector3.new(1.16, 0.21, 0.3), cf = CFrame.new(0, 3.95, -0.82), color = Kit.darken(palette.primary, 0.2) })
	ToyFace.smile(model, CFrame.new(0, 3.19, -1.13), 0.54)
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Ear", shape = "Cylinder", size = Vector3.new(0.12, 0.34, 0.34), cf = CFrame.new(side * 0.68, 3.65, -0.2) * CFrame.Angles(0, math.rad(90), 0), color = palette.primary })
	end

	-- long arms
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Arm", shape = "Cylinder", size = Vector3.new(2.0, 0.62, 0.62), cf = CFrame.new(side * 1.35, 2.15, -0.1) * CFrame.Angles(0, 0, side * math.rad(78)), color = palette.primary })
		-- cloud fist: three white puffs clustered
		for j = 1, 3 do
			local off = Vector3.new((j - 2) * 0.28, (j == 2 and 0.2 or 0), (j - 2) * 0.18)
			Kit.blob(model, Vector3.new(0.85, 0.75, 0.8), CFrame.new(side * 1.5 + off.X, 1.05 + off.Y, -0.1 + off.Z), palette.secondary, "secondary")
		end
		local fist = Kit.part(model, { name = "FistSpark", shape = "Ball", size = Vector3.new(0.3, 0.3, 0.3), cf = CFrame.new(side * 1.5, 0.75, -0.1), color = palette.accent, material = Enum.Material.Neon, role = "accent" })
		Kit.particles(fist, "lightning", palette.accent)
		Kit.light(fist, palette.accent, 0.9, 10)
	end

	-- short legs
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Leg", shape = "Cylinder", size = Vector3.new(1.0, 0.7, 0.7), cf = CFrame.new(side * 0.6, 0.55, 0.1) * UP, color = palette.primary })
		Kit.part(model, { name = "Foot", size = Vector3.new(0.7, 0.22, 1.0), cf = CFrame.new(side * 0.6, 0.11, -0.1), color = Kit.darken(palette.primary, 0.15) })
	end

	ToyFace.eyes(model, CFrame.new(0, 3.7, -0.94), 0.64, 0.24)
	Kit.setAnim(model, "pulse", def.animSpeed, 1)
end

-- Boltjaw Behemoth: a four-legged storm beast with lightning antlers.
B.boltjaw_behemoth = function(model: Model, _root: BasePart, palette, def)
	-- long heavy body
	Kit.blob(model, Vector3.new(2.2, 2.0, 3.6), CFrame.new(0, 2.6, 0.3), palette.primary)
	-- storm-cloud mane along the spine
	for i = 1, 6 do
		Kit.blob(model, Vector3.new(1.1, 0.8, 0.9), CFrame.new(math.sin(i * 1.3) * 0.18, 3.6 + math.sin(i) * 0.1, -1.0 + (i - 1) * 0.65), palette.secondary, "secondary")
	end

	-- head, jutting forward and down
	Kit.blob(model, Vector3.new(1.62, 1.38, 1.95), CFrame.new(0, 2.85, -2.2), palette.primary)
	Kit.part(model, { name = "Snout", shape = "Ball", mesh = "Sphere", size = Vector3.new(1.18, 0.74, 0.95), cf = CFrame.new(0, 2.6, -3.05), color = Kit.lighten(palette.primary, 0.18) })
	-- glowing jaw line
	local jaw = Kit.part(model, { name = "Boltjaw", size = Vector3.new(0.95, 0.12, 0.85), cf = CFrame.new(0, 2.42, -2.95), color = palette.accent, material = Enum.Material.Neon, role = "accent" })
	Kit.flickerPart(jaw, 0, 0.3)
	-- teeth
	for i = 1, 4 do
		Kit.part(model, { name = "Fang", shape = "Wedge", size = Vector3.new(0.14, 0.3, 0.14), cf = CFrame.new(-0.36 + (i - 1) * 0.24, 2.3, -3.1) * CFrame.Angles(math.rad(180), 0, 0), color = rgb(245, 245, 235), role = "fixed" })
	end

	-- lightning antlers: a jagged zigzag each side
	for _, side in { -1, 1 } do
		local pts = { Vector3.new(side * 0.5, 3.65, -2.2), Vector3.new(side * 1.0, 4.3, -2.4), Vector3.new(side * 0.7, 4.9, -2.0), Vector3.new(side * 1.35, 5.4, -2.3) }
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local mid = (a + b) / 2
			local seg = Kit.part(model, {
				name = "Antler" .. tostring(i),
				size = Vector3.new(0.16, (b - a).Magnitude, 0.16),
				cf = CFrame.lookAt(mid, b) * CFrame.Angles(math.rad(90), 0, 0),
				color = palette.accent,
				material = Enum.Material.Neon,
				role = "accent",
			})
			Kit.flickerPart(seg, 0, 0.4)
		end
		-- side prong
		Kit.part(model, { name = "Prong", size = Vector3.new(0.13, 0.7, 0.13), cf = CFrame.new(side * 1.25, 4.7, -2.55) * CFrame.Angles(0, 0, side * math.rad(35)), color = palette.accent, material = Enum.Material.Neon, role = "accent" })
	end
	Kit.light(Kit.root(model), palette.accent, 1.5, 18)
	Kit.particles(Kit.root(model), "lightning", palette.accent)

	-- four legs with glowing hocks
	for _, sx in { -1, 1 } do
		for _, sz in { -1.2, 1.5 } do
			Kit.part(model, { name = "Leg", shape = "Cylinder", size = Vector3.new(1.55, 0.62, 0.62), cf = CFrame.new(sx * 0.85, 0.8, sz) * UP, color = palette.primary })
			Kit.part(model, { name = "Hoof", shape = "Cylinder", size = Vector3.new(0.24, 0.72, 0.72), cf = CFrame.new(sx * 0.85, 0.12, sz) * UP, color = palette.accent, material = Enum.Material.Neon, role = "accent" })
		end
	end
	-- forked tail
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Tail", size = Vector3.new(0.16, 1.3, 0.16), cf = CFrame.new(side * 0.2, 2.9, 2.2) * CFrame.Angles(math.rad(55), 0, side * math.rad(18)), color = palette.accent, material = Enum.Material.Neon, role = "accent" })
	end

	ToyFace.eyes(model, CFrame.new(0, 3.12, -3.02), 0.79, 0.27)
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Nostril", shape = "Ball", size = Vector3.new(0.13, 0.11, 0.08), cf = CFrame.new(side * 0.28, 2.66, -3.52), color = ToyFace.ink, role = "fixed" })
	end
	Kit.setAnim(model, "sway", def.animSpeed, 0.9)
end

-- ---------------------------------------------------------------- Cosmic

-- Rubble Runt: an asymmetric asteroid cluster held together by magnetism.
B.rubble_runt = function(model: Model, _root: BasePart, palette, def)
	local y = 1.2
	Kit.part(model, { name = "CoreRock", shape = "Wedge", size = Vector3.new(1.8, 1.5, 1.65), cf = CFrame.new(0, y, 0), color = palette.primary, material = Enum.Material.Rock })
	Kit.part(model, { name = "ShoulderRock", shape = "CornerWedge", size = Vector3.new(1.15, 1.05, 1.2), cf = CFrame.new(-0.72, y + 0.28, 0.18) * CFrame.Angles(0, math.rad(-20), math.rad(12)), color = palette.secondary, material = Enum.Material.Slate, role = "secondary" })
	Kit.part(model, { name = "CrownRock", shape = "Wedge", size = Vector3.new(0.9, 0.82, 0.95), cf = CFrame.new(0.42, y + 0.62, 0.1) * CFrame.Angles(0, math.rad(25), 0), color = palette.primary, material = Enum.Material.Rock })
	local craters = { Vector3.new(-0.42, 1.38, -0.82), Vector3.new(0.36, 1.05, -0.84), Vector3.new(0.18, 1.72, -0.47) }
	for i, at in craters do
		Kit.blob(model, Vector3.new(0.32, 0.22, 0.08), CFrame.new(at), palette.secondary, "secondary", Enum.Material.Slate).Name = "Crater" .. tostring(i)
	end
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Magnet", shape = "Cylinder", size = Vector3.new(0.5, 0.26, 0.26), cf = CFrame.new(side * 0.42, 0.44, -0.08) * UP, color = palette.accent, material = Enum.Material.Metal, role = "accent" })
		Kit.part(model, { name = "MagnetPole", size = Vector3.new(0.22, 0.12, 0.5), cf = CFrame.new(side * 0.42, 0.12, -0.14), color = palette.accent, material = Enum.Material.Neon, role = "accent" })
	end
	ToyFace.eyes(model, CFrame.new(0, 1.58, -0.94), 0.52, 0.18)
	ToyFace.smile(model, CFrame.new(0, 1.28, -0.94), 0.28)
	Kit.setAnim(model, "bob", def.animSpeed, 0.8)
end

-- Lagrange Loper: two unequal bodies sharing stable orbital points.
B.lagrange_loper = function(model: Model, _root: BasePart, palette, def)
	local y = 1.45
	Kit.blob(model, Vector3.new(1.45, 1.3, 1.35), CFrame.new(-0.5, y, 0), palette.primary, nil, Enum.Material.Metal)
	Kit.blob(model, Vector3.new(0.95, 0.88, 0.95), CFrame.new(0.72, y + 0.14, 0.05), palette.secondary, "secondary", Enum.Material.Rock)
	Kit.part(model, { name = "GravityBridge", shape = "Cylinder", size = Vector3.new(1.15, 0.2, 0.2), cf = CFrame.new(0.12, y, 0.02) * UP, color = palette.accent, material = Enum.Material.Neon, role = "accent" })
	for _, side in { -1, 1 } do
		for _, z in { -0.36, 0.36 } do
			Kit.part(model, { name = "Step", shape = "Cylinder", size = Vector3.new(0.55, 0.18, 0.18), cf = CFrame.new(-0.5 + side * 0.3, 0.42, z) * UP, color = palette.primary, role = "secondary" })
		end
	end
	local nearMoon = Kit.part(model, { name = "StableMoon", shape = "Ball", size = Vector3.new(0.34, 0.34, 0.34), cf = CFrame.new(1.32, y + 0.75, 0), color = palette.accent, material = Enum.Material.Neon, role = "accent" })
	local farMoon = Kit.part(model, { name = "StableMoon", shape = "Ball", size = Vector3.new(0.24, 0.24, 0.24), cf = CFrame.new(-1.5, y - 0.1, 0), color = palette.secondary, material = Enum.Material.Metal, role = "secondary" })
	Kit.orbiter(model, nearMoon, 1.45, 0.75, 0, math.rad(12), y + 0.05)
	Kit.orbiter(model, farMoon, 1.45, -0.75, math.pi, math.rad(12), y + 0.05)
	ToyFace.eyes(model, CFrame.new(-0.5, y + 0.28, -0.72), 0.5, 0.18)
	ToyFace.smile(model, CFrame.new(-0.5, y - 0.08, -0.78), 0.28)
	Kit.setAnim(model, "drift", def.animSpeed, 0.7)
end

-- Pulsar Prickle: a dense, flattened star with physical magnetic beams.
B.pulsar_prickle = function(model: Model, _root: BasePart, palette, def)
	local y = 1.58
	Kit.blob(model, Vector3.new(2.35, 1.25, 2.0), CFrame.new(0, y, 0), palette.primary, nil, Enum.Material.Metal)
	Kit.blob(model, Vector3.new(0.62, 0.42, 0.62), CFrame.new(0, y + 0.66, 0), palette.secondary, "secondary", Enum.Material.Neon)
	Kit.blob(model, Vector3.new(0.5, 0.34, 0.5), CFrame.new(0, y - 0.66, 0), palette.secondary, "secondary", Enum.Material.Neon)
	for _, side in { -1, 1 } do
		local fin = Kit.part(model, { name = "BeamFin", shape = "Wedge", size = Vector3.new(0.3, 0.86, 0.58), cf = CFrame.new(side * 1.3, y, 0) * CFrame.Angles(0, side * math.rad(90), 0), color = palette.accent, material = Enum.Material.Neon, role = "accent" })
		Kit.flickerPart(fin, 0.05, 0.35)
		local lower = Kit.part(model, { name = "PolarFin", shape = "Wedge", size = Vector3.new(0.58, 0.3, 0.52), cf = CFrame.new(side * 0.46, y + side * 0.92, 0) * CFrame.Angles(0, 0, side * math.rad(18)), color = palette.secondary, material = Enum.Material.Metal, role = "secondary" })
		Kit.flickerPart(lower, 0.08, 0.28)
	end
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "StarFoot", shape = "Cylinder", size = Vector3.new(0.42, 0.18, 0.18), cf = CFrame.new(side * 0.42, 0.3, -0.08) * UP, color = palette.secondary, role = "secondary" })
		Kit.part(model, { name = "StarPad", size = Vector3.new(0.4, 0.12, 0.45), cf = CFrame.new(side * 0.42, 0.08, -0.14), color = palette.accent, material = Enum.Material.Neon, role = "accent" })
	end
	ToyFace.eyes(model, CFrame.new(0, y + 0.2, -1.04), 0.62, 0.2)
	ToyFace.smile(model, CFrame.new(0, y - 0.16, -1.08), 0.3)
	Kit.setAnim(model, "pulse", def.animSpeed, 0.85)
end

-- Rochebreaker: a small world being pulled apart past its Roche limit.
B.rochebreaker = function(model: Model, _root: BasePart, palette, def)
	local y = 2.18
	Kit.blob(model, Vector3.new(1.55, 1.7, 2.25), CFrame.new(0, y, -0.55), palette.primary, nil, Enum.Material.Rock)
	Kit.blob(model, Vector3.new(1.08, 1.2, 1.22), CFrame.new(0.18, 1.55, 1.4), palette.secondary, "secondary", Enum.Material.Slate)
	for i = 1, 5 do
		local t = (i - 1) / 4
		local fragment = Kit.blob(model, Vector3.new(0.42 - t * 0.12, 0.35 - t * 0.1, 0.38 - t * 0.1), CFrame.new(-0.05 + t * 0.1, 1.75 - t * 0.15, 0.42 + t * 0.8), palette.secondary, "secondary", Enum.Material.Rock)
		fragment.Name = "TidalFragment" .. tostring(i)
	end
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "TidalBand", size = Vector3.new(0.12, 0.12, 0.92), cf = CFrame.new(side * 0.5, y, 0.18) * CFrame.Angles(0, side * math.rad(16), 0), color = palette.accent, material = Enum.Material.Neon, role = "accent" })
		for _, z in { -0.95, 0.05 } do
			Kit.part(model, { name = "CoreFoot", shape = "Cylinder", size = Vector3.new(0.62, 0.2, 0.2), cf = CFrame.new(side * 0.45, 0.45, z) * UP, color = palette.primary, role = "secondary" })
		end
	end
	ToyFace.eyes(model, CFrame.new(0, y + 0.28, -1.62), 0.58, 0.2)
	ToyFace.smile(model, CFrame.new(0, y - 0.12, -1.67), 0.34)
	Kit.particles(Kit.root(model), "motes", palette.accent)
	Kit.setAnim(model, "sway", def.animSpeed, 0.8)
end

-- Nebula Noodle: a thick gas filament wrapped around a dark void core.
B.nebula_noodle = function(model: Model, _root: BasePart, palette, def)
	local segments = {
		{ Vector3.new(-0.82, 1.25, 0.08), 0.9 },
		{ Vector3.new(-0.55, 1.85, 0.02), 1.02 },
		{ Vector3.new(-0.1, 2.35, 0.08), 1.08 },
		{ Vector3.new(0.48, 2.3, 0.02), 0.98 },
		{ Vector3.new(0.82, 1.78, 0.0), 0.92 },
		{ Vector3.new(0.5, 1.28, -0.08), 0.82 },
	}
	for i, data in segments do
		local segment = Kit.blob(model, Vector3.new(data[2], data[2] * 0.9, data[2] * 0.86), CFrame.new(data[1]), palette.primary, nil, Enum.Material.Neon)
		segment.Name = "NebulaFilament" .. tostring(i)
	end
	Kit.blob(model, Vector3.new(0.95, 0.95, 0.55), CFrame.new(0.02, 1.78, 0.12), palette.secondary, "secondary", Enum.Material.SmoothPlastic).Name = "VoidCore"
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2
		local filament = Kit.part(model, { name = "OrbitFilament", shape = "Cylinder", size = Vector3.new(0.12, 0.08, 0.72), cf = CFrame.new(math.sin(a) * 1.35, 1.8, math.cos(a) * 1.35) * CFrame.Angles(0, a, math.rad(22)), color = palette.accent, material = Enum.Material.Neon, role = "accent" })
		Kit.orbit(model, filament, { radius = 1.35, speed = if i % 2 == 0 then 0.7 else -0.6, phase = a, tilt = math.rad(22), centre = Vector3.new(0, 1.8, 0), rigid = true })
	end
	ToyFace.eyes(model, CFrame.new(0.45, 2.05, -0.72), 0.48, 0.18)
	ToyFace.smile(model, CFrame.new(0.45, 1.72, -0.78), 0.28)
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "CloudFoot", shape = "Cylinder", size = Vector3.new(0.48, 0.2, 0.2), cf = CFrame.new(side * 0.38, 0.38, -0.1) * UP, color = palette.secondary, role = "secondary" })
		Kit.part(model, { name = "CloudPad", size = Vector3.new(0.42, 0.12, 0.52), cf = CFrame.new(side * 0.38, 0.08, -0.18), color = palette.accent, material = Enum.Material.Neon, role = "accent" })
	end
	Kit.setAnim(model, "drift", def.animSpeed, 0.75)
end

-- Universe Seed: a faceted shell containing a small pocket universe.
B.universe_seed = function(model: Model, _root: BasePart, palette, def)
	local y = 2.55
	Kit.part(model, { name = "ShellLeft", shape = "Wedge", size = Vector3.new(1.35, 3.25, 1.5), cf = CFrame.new(-0.38, y, 0) * CFrame.Angles(0, math.rad(-8), 0), color = palette.primary, material = Enum.Material.Slate })
	Kit.part(model, { name = "ShellRight", shape = "Wedge", size = Vector3.new(1.35, 3.25, 1.5), cf = CFrame.new(0.38, y, 0) * CFrame.Angles(0, math.rad(8), 0), color = palette.primary, material = Enum.Material.Rock })
	Kit.blob(model, Vector3.new(0.78, 1.12, 0.48), CFrame.new(0, y + 0.05, -0.72), palette.secondary, "secondary", Enum.Material.SmoothPlastic).Name = "PocketUniverse"
	Kit.part(model, { name = "ShellSeam", size = Vector3.new(0.1, 2.4, 0.14), cf = CFrame.new(0, y, -0.77), color = palette.accent, material = Enum.Material.Neon, role = "accent" })
	for i, tilt in { -18, 0, 18 } do
		local band = Kit.part(model, { name = "OrbitBand", size = Vector3.new(0.12, 0.08, 1.55), cf = CFrame.new(0, y + (i - 2) * 0.15, 0) * CFrame.Angles(0, math.rad(i * 32), math.rad(tilt)), color = palette.accent, material = Enum.Material.Neon, role = "accent" })
		Kit.orbit(model, band, { radius = 1.45 + i * 0.12, speed = 0.5 + i * 0.12, phase = i * math.pi / 2, tilt = math.rad(tilt), centre = Vector3.new(0, y, 0), rigid = true })
	end
	ToyFace.eyes(model, CFrame.new(0, y + 0.25, -0.88), 0.56, 0.2)
	ToyFace.smile(model, CFrame.new(0, y - 0.12, -0.93), 0.3)
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "SeedStem", shape = "Cylinder", size = Vector3.new(0.65, 0.2, 0.2), cf = CFrame.new(side * 0.42, 0.46, -0.08) * UP, color = palette.secondary, role = "secondary" })
		Kit.part(model, { name = "SeedFoot", size = Vector3.new(0.44, 0.12, 0.54), cf = CFrame.new(side * 0.42, 0.08, -0.15), color = palette.accent, material = Enum.Material.Neon, role = "accent" })
	end
	Kit.setAnim(model, "hover", def.animSpeed, 0.9)
end

return B
