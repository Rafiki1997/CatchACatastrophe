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

-- Orbit Orb: a cratered little moon with feet and a satellite ring.
B.orbit_orb = function(model: Model, _root: BasePart, palette, def)
	local bodyY = 1.35
	Kit.part(model, { name = "Moon", shape = "Ball", size = Vector3.new(1.7, 1.7, 1.7), cf = CFrame.new(0, bodyY, 0), color = palette.primary })
	-- craters
	local craters = { Vector3.new(0.55, 0.45, -0.5), Vector3.new(-0.6, 0.2, -0.45), Vector3.new(0.2, -0.55, -0.6), Vector3.new(-0.3, 0.6, 0.4) }
	for i, c in craters do
		Kit.part(model, { name = "Crater" .. tostring(i), shape = "Ball", size = Vector3.new(0.4, 0.4, 0.18), cf = CFrame.new(Vector3.new(0, bodyY, 0) + c * 0.92) * CFrame.Angles(0, math.atan2(c.X, c.Z), 0), color = palette.secondary, role = "secondary" })
	end

	-- satellite ring: eight segments orbiting the body
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		local seg = Kit.part(model, {
			name = "Ring" .. tostring(i),
			size = Vector3.new(0.16, 0.1, 0.85),
			cf = CFrame.new(math.sin(a) * 1.25, bodyY + 0.1, math.cos(a) * 1.25) * CFrame.Angles(0, a, math.rad(12)),
			color = palette.accent,
			material = Enum.Material.Neon,
			role = "accent",
		})
		Kit.orbit(model, seg, { radius = 1.25, speed = 1.4, phase = (i / 8) * math.pi * 2, tilt = math.rad(12), centre = Vector3.new(0, bodyY + 0.1, 0), rigid = true })
	end
	-- a little antenna dish riding the ring
	local dish = Kit.part(model, { name = "Sat", shape = "Cylinder", size = Vector3.new(0.1, 0.34, 0.34), cf = CFrame.new(1.25, bodyY + 0.35, 0) * UP, color = palette.secondary, role = "secondary" })
	Kit.orbiter(model, dish, 1.25, 1.4, 0, math.rad(12), bodyY + 0.35)

	-- stubby feet
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Leg", shape = "Cylinder", size = Vector3.new(0.4, 0.2, 0.2), cf = CFrame.new(side * 0.35, 0.32, 0) * UP, color = palette.secondary, role = "secondary" })
		Kit.part(model, { name = "Foot", size = Vector3.new(0.36, 0.14, 0.5), cf = CFrame.new(side * 0.35, 0.07, -0.1), color = palette.secondary, role = "secondary" })
	end

	ToyFace.eyes(model, CFrame.new(0, bodyY + 0.22, -0.82), 0.6, 0.24)
	ToyFace.smile(model, CFrame.new(0, bodyY - 0.27, -0.83), 0.42)
	Kit.particles(Kit.root(model), "stars", palette.accent)
	Kit.setAnim(model, "orbit", def.animSpeed, 0.8)
end

-- Comet Cat: a sleek cat with a long glowing tail.
B.comet_cat = function(model: Model, _root: BasePart, palette, def)
	local y = 1.25
	Kit.blob(model, Vector3.new(0.95, 0.85, 1.55), CFrame.new(0, y, 0.1), palette.primary)
	Kit.blob(model, Vector3.new(1.04, 0.91, 0.89), CFrame.new(0, y + 0.55, -0.85), palette.primary)
	-- muzzle
	Kit.blob(model, Vector3.new(0.58, 0.33, 0.33), CFrame.new(0, y + 0.38, -1.25), rgb(217, 210, 231), "fixed")
	Kit.part(model, { name = "Nose", shape = "Wedge", size = Vector3.new(0.14, 0.12, 0.12), cf = CFrame.new(0, y + 0.46, -1.38) * CFrame.Angles(math.rad(180), 0, 0), color = palette.accent, role = "accent" })
	-- pointed ears
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Ear", shape = "Wedge", size = Vector3.new(0.12, 0.45, 0.36), cf = CFrame.new(side * 0.34, y + 1.15, -0.8) * CFrame.Angles(0, side * math.rad(10), 0), color = palette.primary })
		Kit.part(model, { name = "EarInner", shape = "Wedge", size = Vector3.new(0.06, 0.3, 0.24), cf = CFrame.new(side * 0.34, y + 1.1, -0.88) * CFrame.Angles(0, side * math.rad(10), 0), color = palette.secondary, role = "secondary" })
	end
	-- whiskers
	for _, side in { -1, 1 } do
		for j = 1, 2 do
			Kit.part(model, { name = "Whisker", size = Vector3.new(0.5, 0.03, 0.03), cf = CFrame.new(side * 0.32, y + 0.4 + (j - 1) * 0.1, -1.28) * CFrame.Angles(0, side * math.rad(-24), side * math.rad(6 - j * 12)), color = rgb(240, 240, 250), role = "fixed" })
		end
	end

	-- comet tail: shrinking neon spheres trailing up and back
	for i = 1, 7 do
		local t = (i - 1) / 6
		local s = 0.55 - t * 0.36
		local seg = Kit.part(model, {
			name = "Comet" .. tostring(i),
			shape = "Ball",
			size = Vector3.new(s, s, s),
			cf = CFrame.new(math.sin(t * 3) * 0.3, y + 0.15 + t * 1.5, 0.95 + t * 2.1),
			color = Kit.blend(palette.secondary, palette.accent, t),
			material = Enum.Material.Neon,
			transparency = t * 0.45,
			role = "accent",
		})
		if i == 1 then
			Kit.particles(seg, "stars", palette.accent)
			Kit.light(seg, palette.secondary, 1.2, 14)
		end
	end

	-- legs
	for _, sx in { -1, 1 } do
		for _, sz in { -0.4, 0.7 } do
			Kit.part(model, { name = "Leg", shape = "Cylinder", size = Vector3.new(0.85, 0.24, 0.24), cf = CFrame.new(sx * 0.36, 0.42, sz) * UP, color = palette.primary })
			Kit.part(model, { name = "Paw", shape = "Ball", size = Vector3.new(0.3, 0.24, 0.34), cf = CFrame.new(sx * 0.36, 0.12, sz - 0.05), color = palette.secondary, role = "secondary" })
		end
	end

	ToyFace.eyes(model, CFrame.new(0, y + 0.66, -1.26), 0.49, 0.21)
	ToyFace.smile(model, CFrame.new(0, y + 0.29, -1.43), 0.28)
	Kit.setAnim(model, "drift", def.animSpeed, 1)
end

-- Gravity Gobbler: a round mouth-creature with stones caught in its pull.
B.gravity_gobbler = function(model: Model, _root: BasePart, palette, def)
	local y = 1.7
	Kit.part(model, { name = "Body", shape = "Ball", size = Vector3.new(2.4, 2.4, 2.4), cf = CFrame.new(0, y, 0), color = palette.primary })
	-- starry mouth: a dark oval with neon stars inside
	Kit.part(model, { name = "Maw", shape = "Ball", mesh = "Sphere", size = Vector3.new(1.35, 1.05, 0.2), cf = CFrame.new(0, y - 0.28, -1.28), color = rgb(30, 25, 50), role = "fixed" })
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2
		Kit.part(model, {
			name = "MawStar" .. tostring(i),
			shape = "Ball",
			size = Vector3.new(0.15, 0.15, 0.15),
			cf = CFrame.new(math.sin(a) * 0.42, y - 0.28 + math.cos(a) * 0.3, -1.4),
			color = palette.accent,
			material = Enum.Material.Neon,
			role = "accent",
		})
	end
	-- lip ring
	Kit.part(model, { name = "Lip", shape = "Ball", mesh = "Sphere", size = Vector3.new(1.65, 1.28, 0.35), cf = CFrame.new(0, y - 0.28, -1.08), color = Kit.lighten(palette.primary, 0.2), role = "secondary" })

	-- orbiting stones at two radii
	for i = 1, 5 do
		local a = (i / 5) * math.pi * 2
		local r = if i % 2 == 0 then 2.1 else 1.75
		local s = 0.3 + (i % 3) * 0.1
		local stone = Kit.part(model, {
			name = "Stone" .. tostring(i),
			shape = "Ball",
			size = Vector3.new(s, s * 0.85, s * 0.9),
			cf = CFrame.new(math.sin(a) * r, y + 0.2, math.cos(a) * r),
			color = palette.secondary,
			role = "secondary",
		})
		Kit.orbiter(model, stone, r, if i % 2 == 0 then 1.1 else -0.8, a, math.rad((i - 3) * 14), y + 0.2)
	end

	-- little legs beneath
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Leg", shape = "Cylinder", size = Vector3.new(0.5, 0.24, 0.24), cf = CFrame.new(side * 0.5, 0.35, 0.05) * UP, color = palette.secondary, role = "secondary" })
		Kit.part(model, { name = "Foot", size = Vector3.new(0.42, 0.16, 0.55), cf = CFrame.new(side * 0.5, 0.08, -0.08), color = palette.secondary, role = "secondary" })
	end

	ToyFace.eyes(model, CFrame.new(0, y + 0.69, -1.04), 0.77, 0.28)
	Kit.particles(Kit.root(model), "motes", palette.accent)
	Kit.setAnim(model, "orbit", def.animSpeed, 0.9)
end

-- The Big Whoops: a small black hole in boxing gloves, with a warning sign.
B.the_big_whoops = function(model: Model, _root: BasePart, palette, def)
	local y = 2.3
	-- event horizon: a matte black sphere
	Kit.part(model, { name = "Horizon", shape = "Ball", size = Vector3.new(2.3, 2.3, 2.3), cf = CFrame.new(0, y, 0), color = palette.primary, material = Enum.Material.SmoothPlastic })
	-- accretion disc: neon segments orbiting on a tilted plane
	for i = 1, 12 do
		local a = (i / 12) * math.pi * 2
		local seg = Kit.part(model, {
			name = "Disc" .. tostring(i),
			size = Vector3.new(0.3, 0.12, 0.92),
			cf = CFrame.new(math.sin(a) * 1.85, y, math.cos(a) * 1.85) * CFrame.Angles(0, a, math.rad(20)),
			color = Kit.blend(palette.secondary, palette.accent, (i % 4) / 4),
			material = Enum.Material.Neon,
			role = "accent",
		})
		Kit.orbit(model, seg, { radius = 1.85, speed = 2.2, phase = a, tilt = math.rad(20), centre = Vector3.new(0, y, 0), rigid = true })
	end
	Kit.light(Kit.root(model), palette.secondary, 1.8, 22)
	Kit.particles(Kit.root(model), "motes", palette.secondary)

	-- boxing gloves on stubby arms
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Arm", shape = "Cylinder", size = Vector3.new(0.55, 0.3, 0.3), cf = CFrame.new(side * 1.25, y - 0.15, -0.35) * CFrame.Angles(0, 0, side * math.rad(80)), color = rgb(60, 55, 75), role = "secondary" })
		Kit.blob(model, Vector3.new(0.95, 0.9, 1.1), CFrame.new(side * 1.55, y - 0.25, -0.6), rgb(250, 250, 255), "fixed")
		Kit.part(model, { name = "Cuff", shape = "Cylinder", size = Vector3.new(0.18, 0.75, 0.75), cf = CFrame.new(side * 1.42, y - 0.2, -0.15) * CFrame.Angles(0, math.rad(90), 0), color = palette.accent, role = "accent" })
	end

	-- A round caution placard: all three pieces share an orbit translation and
	-- retain their front-facing orientation, keeping the punctuation attached.
	local sign = Kit.part(model, { name = "SignFace", shape = "Ball", mesh = "Sphere", size = Vector3.new(0.98, 0.98, 0.12), cf = CFrame.new(0, y + 1.9, -1.7), color = palette.accent, role = "accent" })
	local bang = Kit.part(model, { name = "SignBang", size = Vector3.new(0.14, 0.39, 0.05), cf = CFrame.new(0, y + 1.98, -1.79), color = ToyFace.ink, role = "fixed" })
	local dot = Kit.part(model, { name = "SignDot", shape = "Ball", mesh = "Sphere", size = Vector3.new(0.14, 0.14, 0.05), cf = CFrame.new(0, y + 1.63, -1.79), color = ToyFace.ink, role = "fixed" })
	for _, p in { sign, bang, dot } do
		local offset = p.Position - sign.Position
		Kit.orbit(model, p, { radius = 1.7, speed = 0.75, phase = -math.pi / 2, centre = Vector3.new(0, y + 1.9, 0) + offset })
		p:SetAttribute("OrbitNoSpin", true)
	end

	-- Bright eyes and the original sheepish grin on the dark horizon.
	ToyFace.eyes(model, CFrame.new(0, y + 0.38, -1.04), 0.84, 0.25)
	for i = 1, 5 do
		local a = math.rad(-56 + (i - 1) * 28)
		Kit.part(model, { name = "Grin" .. tostring(i), size = Vector3.new(0.16, 0.08, 0.08), cf = CFrame.new(math.sin(a) * 0.5, y - 0.35 - math.cos(a) * 0.18, -1.05) * CFrame.Angles(0, 0, -a), color = rgb(255, 245, 220), material = Enum.Material.Neon, role = "fixed" })
	end

	-- tiny feet, because it still walks around
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Foot", size = Vector3.new(0.42, 0.2, 0.6), cf = CFrame.new(side * 0.42, 0.1, -0.15), color = rgb(250, 250, 255), role = "fixed" })
		Kit.part(model, { name = "Ankle", shape = "Cylinder", size = Vector3.new(0.7, 0.24, 0.24), cf = CFrame.new(side * 0.42, 0.5, 0) * UP, color = rgb(60, 55, 75), role = "secondary" })
	end

	Kit.setAnim(model, "orbit", def.animSpeed, 1.1)
end

return B
