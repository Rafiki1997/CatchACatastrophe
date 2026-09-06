--!strict
-- Every piece of city hardware: the work station that sits behind a deployed
-- creature, the six Disaster Circuit machines, the containment pylon and the
-- milestone decorations.
--
-- Unlike creature builders these are complete: each function calls
-- Kit.finalize itself and returns a ready model whose base sits at y = 0 and
-- whose front faces -Z.
--
-- Motion is client-side and data driven (see Animate):
--   * Kit.orbit(..., axis = "X" | "Z", rigid = true) turns a vertical wheel.
--   * Kit.setAnim(model, style) moves the whole model.
--   * Attribute Working = false freezes the model; Overdrive doubles its
--     tempo; Cooling slows it to a crawl. The server writes all three.

local Kit = require(script.Parent.ModelKit)
local Config = require(script.Parent.Parent.Config)

local M = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local UP = CFrame.Angles(0, 0, math.rad(90))

local INK = rgb(46, 44, 52)
local STEEL = rgb(150, 156, 168)
local DARK_STEEL = rgb(96, 100, 112)
local HAZARD = rgb(255, 190, 50)

-- A chunky hazard-striped plinth every machine stands on.
local function plinth(model: Model, width: number, depth: number, height: number, color: Color3?)
	Kit.part(model, { name = "Plinth", size = Vector3.new(width, height, depth), cf = CFrame.new(0, height / 2, 0), color = color or DARK_STEEL, role = "secondary" })
	-- stripes around the rim
	local stripes = math.max(3, math.floor(width / 0.6))
	for i = 1, stripes do
		local x = -width / 2 + (i - 0.5) * (width / stripes)
		Kit.part(model, {
			name = "Stripe",
			size = Vector3.new(width / stripes * 0.55, height * 0.5, 0.08),
			cf = CFrame.new(x, height * 0.5, -depth / 2 - 0.02) * CFrame.Angles(0, 0, math.rad(28)),
			color = if i % 2 == 0 then HAZARD else INK,
			role = "fixed",
		})
	end
end

local function bolts(model: Model, cf: CFrame, radius: number, count: number)
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		Kit.part(model, {
			name = "Bolt",
			shape = "Cylinder",
			size = Vector3.new(0.08, 0.16, 0.16),
			cf = cf * CFrame.new(math.sin(a) * radius, math.cos(a) * radius, 0) * CFrame.Angles(0, math.rad(90), 0),
			color = INK,
			role = "fixed",
		})
	end
end

-- ============================================================ work stations

local stations: { [string]: (Model, Color3) -> () } = {}

-- Windmill: a tower with four blades turning in a vertical wheel.
stations.windmill = function(model: Model, tint: Color3)
	plinth(model, 2.6, 2.6, 0.4)
	Kit.part(model, { name = "Tower", shape = "Cylinder", size = Vector3.new(3.6, 1.1, 1.1), cf = CFrame.new(0, 2.2, 0) * UP, color = STEEL, role = "secondary" })
	Kit.part(model, { name = "Cap", shape = "Ball", size = Vector3.new(1.3, 1.3, 1.3), cf = CFrame.new(0, 4.0, 0), color = tint, role = "accent" })
	-- hub sticking out the front
	Kit.part(model, { name = "Hub", shape = "Cylinder", size = Vector3.new(0.5, 0.5, 0.5), cf = CFrame.new(0, 4.0, -0.75) * CFrame.Angles(0, math.rad(90), 0), color = INK, role = "fixed" })
	for i = 1, 4 do
		local blade = Kit.part(model, {
			name = "Blade" .. tostring(i),
			size = Vector3.new(0.35, 1.9, 0.12),
			cf = CFrame.new(0, 4.0, -0.95),
			color = if i % 2 == 0 then tint else rgb(248, 248, 252),
			role = if i % 2 == 0 then "accent" else "fixed",
		})
		-- blades revolve about the model's Z axis: a vertical wheel facing -Z
		Kit.orbit(model, blade, { radius = 1.05, speed = 2.2, phase = (i / 4) * math.pi * 2, axis = "Z", centre = Vector3.new(0, 4.0, -0.95), rigid = true })
	end
	bolts(model, CFrame.new(0, 2.2, -0.58), 0.42, 6)
end

-- Water wheel: a paddle wheel in a trough.
stations.waterwheel = function(model: Model, tint: Color3)
	plinth(model, 3.0, 2.4, 0.4)
	-- trough
	Kit.part(model, { name = "Trough", size = Vector3.new(3.0, 0.5, 1.0), cf = CFrame.new(0, 0.65, 0.7), color = DARK_STEEL, role = "secondary" })
	Kit.part(model, { name = "Water", size = Vector3.new(2.8, 0.16, 0.8), cf = CFrame.new(0, 0.88, 0.7), color = tint, material = Enum.Material.Glass, transparency = 0.35, role = "accent" })
	-- axle across the front
	Kit.part(model, { name = "Axle", shape = "Cylinder", size = Vector3.new(1.6, 0.22, 0.22), cf = CFrame.new(0, 1.9, -0.3), color = INK, role = "fixed" })
	-- side rims
	for _, side in { -1, 1 } do
		-- the wheel turns about X, so its rims are discs whose axis is X (no rotation)
		Kit.part(model, { name = "Rim", shape = "Cylinder", size = Vector3.new(0.14, 2.5, 2.5), cf = CFrame.new(side * 0.7, 1.9, -0.3), color = STEEL, transparency = 0.35, role = "secondary" })
	end
	for i = 1, 8 do
		local paddle = Kit.part(model, {
			name = "Paddle" .. tostring(i),
			size = Vector3.new(1.5, 0.55, 0.12),
			cf = CFrame.new(0, 1.9, -0.3),
			color = if i % 2 == 0 then tint else rgb(200, 206, 216),
			role = if i % 2 == 0 then "accent" else "secondary",
		})
		-- paddles revolve about X: a vertical wheel seen from the side
		Kit.orbit(model, paddle, { radius = 1.1, speed = 1.5, phase = (i / 8) * math.pi * 2, axis = "X", centre = Vector3.new(0, 1.9, -0.3), rigid = true })
	end
end

-- Furnace: a brick box with a fire door and a smoking chimney.
stations.furnace = function(model: Model, tint: Color3)
	plinth(model, 2.8, 2.4, 0.4)
	Kit.part(model, { name = "Body", size = Vector3.new(2.3, 2.2, 1.9), cf = CFrame.new(0, 1.5, 0), color = rgb(140, 74, 58), material = Enum.Material.Brick, role = "secondary" })
	-- banding
	for i = 1, 2 do
		Kit.part(model, { name = "Band", size = Vector3.new(2.4, 0.16, 2.0), cf = CFrame.new(0, 0.85 + (i - 1) * 1.15, 0), color = DARK_STEEL, role = "secondary" })
	end
	-- fire door
	Kit.part(model, { name = "Door", size = Vector3.new(1.3, 1.0, 0.14), cf = CFrame.new(0, 1.35, -0.99), color = INK, role = "fixed" })
	local fire = Kit.part(model, { name = "Fire", size = Vector3.new(1.05, 0.78, 0.1), cf = CFrame.new(0, 1.35, -1.06), color = tint, material = Enum.Material.Neon, role = "accent" })
	Kit.flickerPart(fire, 0, 0.35)
	Kit.particles(fire, "fire", tint)
	Kit.light(fire, tint, 1.4, 12)
	-- chimney
	Kit.part(model, { name = "Chimney", shape = "Cylinder", size = Vector3.new(1.6, 0.7, 0.7), cf = CFrame.new(0.62, 3.35, 0.35) * UP, color = DARK_STEEL, role = "secondary" })
	local smoke = Kit.part(model, { name = "SmokeTop", shape = "Cylinder", size = Vector3.new(0.12, 0.78, 0.78), cf = CFrame.new(0.62, 4.15, 0.35) * UP, color = INK, role = "fixed" })
	Kit.particles(smoke, "smoke", rgb(120, 112, 108))
	-- pressure gauge
	Kit.part(model, { name = "Gauge", shape = "Cylinder", size = Vector3.new(0.1, 0.44, 0.44), cf = CFrame.new(-0.75, 2.2, -1.0) * CFrame.Angles(0, math.rad(90), 0), color = rgb(240, 240, 230), role = "fixed" })
end

-- Freezer: a cabinet with two spinning fans and frost.
stations.freezer = function(model: Model, tint: Color3)
	plinth(model, 2.6, 2.2, 0.4)
	Kit.part(model, { name = "Cabinet", size = Vector3.new(2.2, 2.8, 1.7), cf = CFrame.new(0, 1.8, 0), color = rgb(214, 226, 238), role = "secondary" })
	Kit.part(model, { name = "Seal", size = Vector3.new(2.3, 0.12, 1.8), cf = CFrame.new(0, 1.85, 0), color = tint, role = "accent" })
	-- two fan grilles on the front
	for i = 1, 2 do
		local y = 1.15 + (i - 1) * 1.3
		Kit.part(model, { name = "Grille" .. tostring(i), shape = "Cylinder", size = Vector3.new(0.12, 0.95, 0.95), cf = CFrame.new(0, y, -0.88) * CFrame.Angles(0, math.rad(90), 0), color = INK, role = "fixed" })
		for b = 1, 3 do
			local blade = Kit.part(model, {
				name = "Fan" .. tostring(i) .. "_" .. tostring(b),
				size = Vector3.new(0.22, 0.66, 0.06),
				cf = CFrame.new(0, y, -0.94),
				color = tint,
				material = Enum.Material.SmoothPlastic,
				role = "accent",
			})
			Kit.orbit(model, blade, { radius = 0.3, speed = 7, phase = (b / 3) * math.pi * 2, axis = "Z", centre = Vector3.new(0, y, -0.94), rigid = true })
		end
	end
	-- frost breath from a vent
	local vent = Kit.part(model, { name = "Vent", size = Vector3.new(0.9, 0.2, 0.12), cf = CFrame.new(0, 0.75, -0.9), color = INK, role = "fixed" })
	Kit.particles(vent, "sparkle", rgb(215, 240, 255))
	-- icicles on the lip
	for i = 1, 4 do
		Kit.part(model, { name = "Icicle", shape = "Wedge", size = Vector3.new(0.12, 0.36, 0.14), cf = CFrame.new(-0.75 + (i - 1) * 0.5, 3.05, -0.85) * CFrame.Angles(math.rad(180), 0, 0), color = tint, material = Enum.Material.Glass, transparency = 0.2, role = "accent" })
	end
end

-- Tesla coil: stacked rings and a crackling neon ball.
stations.coil = function(model: Model, tint: Color3)
	plinth(model, 2.4, 2.4, 0.4)
	Kit.part(model, { name = "Column", shape = "Cylinder", size = Vector3.new(2.6, 0.75, 0.75), cf = CFrame.new(0, 1.7, 0) * UP, color = DARK_STEEL, role = "secondary" })
	for i = 1, 5 do
		local w = 1.5 - (i - 1) * 0.14
		local ring = Kit.part(model, {
			name = "Ring" .. tostring(i),
			shape = "Cylinder",
			size = Vector3.new(0.14, w, w),
			cf = CFrame.new(0, 1.0 + (i - 1) * 0.42, 0) * UP,
			color = if i % 2 == 0 then tint else rgb(190, 150, 90),
			material = if i % 2 == 0 then Enum.Material.Neon else Enum.Material.Metal,
			role = if i % 2 == 0 then "accent" else "secondary",
		})
		if i % 2 == 0 then
			Kit.flickerPart(ring, 0, 0.4)
		end
	end
	local ball = Kit.part(model, { name = "Ball", shape = "Ball", size = Vector3.new(1.1, 1.1, 1.1), cf = CFrame.new(0, 3.5, 0), color = tint, material = Enum.Material.Neon, role = "accent" })
	Kit.particles(ball, "lightning", tint)
	Kit.light(ball, tint, 1.6, 16)
	-- arcs jumping to three grounding rods
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2
		Kit.part(model, { name = "Rod", shape = "Cylinder", size = Vector3.new(1.6, 0.14, 0.14), cf = CFrame.new(math.sin(a) * 0.95, 1.2, math.cos(a) * 0.95) * UP, color = rgb(190, 150, 90), material = Enum.Material.Metal, role = "secondary" })
		local arc = Kit.part(model, { name = "Arc", size = Vector3.new(0.08, 1.5, 0.08), cf = CFrame.new(math.sin(a) * 0.5, 2.75, math.cos(a) * 0.5) * CFrame.Angles(math.cos(a) * 0.35, 0, -math.sin(a) * 0.35), color = tint, material = Enum.Material.Neon, role = "accent" })
		Kit.flickerPart(arc, 0.1, 0.85)
	end
end

-- Satellite dish: a slowly sweeping dish with a blinking beacon.
stations.dish = function(model: Model, tint: Color3)
	plinth(model, 2.6, 2.6, 0.4)
	Kit.part(model, { name = "Mast", shape = "Cylinder", size = Vector3.new(2.2, 0.5, 0.5), cf = CFrame.new(0, 1.5, 0) * UP, color = STEEL, role = "secondary" })
	Kit.part(model, { name = "Yoke", size = Vector3.new(1.2, 0.24, 0.24), cf = CFrame.new(0, 2.6, 0), color = DARK_STEEL, role = "secondary" })
	-- the dish itself, tipped up and back
	local tilt = CFrame.new(0, 3.0, -0.35) * CFrame.Angles(math.rad(-32), 0, 0)
	Kit.part(model, { name = "Dish", shape = "Ball", mesh = "Sphere", size = Vector3.new(2.6, 0.5, 2.6), cf = tilt, color = rgb(238, 240, 248), role = "secondary" })
	Kit.part(model, { name = "DishFace", shape = "Ball", mesh = "Sphere", size = Vector3.new(2.3, 0.2, 2.3), cf = tilt * CFrame.new(0, 0.2, 0), color = tint, role = "accent" })
	Kit.part(model, { name = "Feed", shape = "Cylinder", size = Vector3.new(1.0, 0.14, 0.14), cf = tilt * CFrame.new(0, 0.6, 0) * UP, color = INK, role = "fixed" })
	local beacon = Kit.part(model, { name = "Beacon", shape = "Ball", size = Vector3.new(0.3, 0.3, 0.3), cf = tilt * CFrame.new(0, 1.05, 0), color = rgb(255, 90, 90), material = Enum.Material.Neon, role = "fixed" })
	Kit.flickerPart(beacon, 0, 0.9)
	Kit.light(beacon, rgb(255, 120, 120), 0.8, 10)
	-- three signal rings drifting out in front, on the horizontal plane
	for i = 1, 3 do
		local ring = Kit.part(model, { name = "Signal" .. tostring(i), shape = "Cylinder", size = Vector3.new(0.08, 0.5 + i * 0.3, 0.5 + i * 0.3), cf = CFrame.new(0, 3.4 + i * 0.3, -1.2) * CFrame.Angles(math.rad(58), 0, 0), color = tint, material = Enum.Material.Neon, transparency = 0.3 + i * 0.15, role = "accent" })
		Kit.flickerPart(ring, 0.25 + i * 0.15, 0.9)
	end
	-- the whole station sweeps slowly
	Kit.setAnim(model, "sway", 0.35, 1.2)
end

function M.buildWorkStation(job: string, elementColor: Color3): Model
	local model = Kit.newModel("Station_" .. job)
	local builder = stations[job] or stations.windmill
	builder(model, elementColor)
	model:SetAttribute("Kind", "station")
	model:SetAttribute("Key", job)
	model:SetAttribute("Working", false)
	Kit.finalize(model)
	return model
end

function M.stationJobs(): { string }
	local out = {}
	for job in stations do
		table.insert(out, job)
	end
	table.sort(out)
	return out
end

-- ============================================================ circuit machines

local machines: { [string]: (Model, Color3) -> () } = {}

-- Thunder Turbine: a big turbine with lamp posts that light up.
machines.thunder_turbine = function(model: Model, tint: Color3)
	plinth(model, 4.6, 3.4, 0.5)
	Kit.part(model, { name = "Housing", shape = "Cylinder", size = Vector3.new(1.6, 2.6, 2.6), cf = CFrame.new(0, 2.2, 0.35) * CFrame.Angles(0, math.rad(90), 0), color = DARK_STEEL, role = "secondary" })
	Kit.part(model, { name = "Nose", shape = "Ball", size = Vector3.new(0.8, 0.8, 0.8), cf = CFrame.new(0, 2.2, -0.55), color = HAZARD, role = "fixed" })
	-- six turbine blades in a vertical wheel
	for i = 1, 6 do
		local blade = Kit.part(model, {
			name = "Blade" .. tostring(i),
			size = Vector3.new(0.4, 2.0, 0.14),
			cf = CFrame.new(0, 2.2, -0.7),
			color = if i % 2 == 0 then tint else rgb(240, 242, 250),
			role = if i % 2 == 0 then "accent" else "secondary",
		})
		Kit.orbit(model, blade, { radius = 1.1, speed = 4.5, phase = (i / 6) * math.pi * 2, axis = "Z", centre = Vector3.new(0, 2.2, -0.7), rigid = true })
	end
	-- lamp posts either side, lit by the turbine
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Post", shape = "Cylinder", size = Vector3.new(3.2, 0.24, 0.24), cf = CFrame.new(side * 2.5, 1.85, 0.9) * UP, color = INK, role = "fixed" })
		local lamp = Kit.part(model, { name = "Lamp", shape = "Ball", size = Vector3.new(0.62, 0.62, 0.62), cf = CFrame.new(side * 2.5, 3.6, 0.9), color = tint, material = Enum.Material.Neon, role = "accent" })
		Kit.light(lamp, tint, 1.3, 14)
		Kit.flickerPart(lamp, 0, 0.2)
		-- cable back to the housing
		Kit.part(model, { name = "Cable", shape = "Cylinder", size = Vector3.new(2.3, 0.08, 0.08), cf = CFrame.new(side * 1.35, 3.2, 0.75) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, math.rad(14) * side, 0), color = INK, role = "fixed" })
	end
end

-- Steamworks: a boiler puffing steam that drives a piston.
machines.steamworks = function(model: Model, tint: Color3)
	plinth(model, 4.6, 3.4, 0.5)
	-- boiler drum lying on its side
	Kit.part(model, { name = "Boiler", shape = "Cylinder", size = Vector3.new(3.0, 2.0, 2.0), cf = CFrame.new(-0.7, 1.6, 0.2) * CFrame.Angles(0, math.rad(90), 0), color = rgb(168, 92, 66), material = Enum.Material.Metal, role = "secondary" })
	bolts(model, CFrame.new(-2.2, 1.6, 0.2) * CFrame.Angles(0, math.rad(90), 0), 0.85, 8)
	-- firebox glow
	local fire = Kit.part(model, { name = "Firebox", size = Vector3.new(1.0, 0.6, 0.12), cf = CFrame.new(-0.7, 0.85, -0.85), color = rgb(255, 140, 60), material = Enum.Material.Neon, role = "accent" })
	Kit.flickerPart(fire, 0, 0.3)
	Kit.light(fire, rgb(255, 140, 60), 1.2, 10)
	-- steam stack
	Kit.part(model, { name = "Stack", shape = "Cylinder", size = Vector3.new(1.5, 0.6, 0.6), cf = CFrame.new(-1.5, 3.35, 0.2) * UP, color = DARK_STEEL, role = "secondary" })
	local steam = Kit.part(model, { name = "SteamTop", shape = "Cylinder", size = Vector3.new(0.12, 0.7, 0.7), cf = CFrame.new(-1.5, 4.1, 0.2) * UP, color = INK, role = "fixed" })
	Kit.particles(steam, "smoke", tint)
	-- piston assembly on the right, driven by a crank wheel
	Kit.part(model, { name = "PistonBody", shape = "Cylinder", size = Vector3.new(1.8, 0.7, 0.7), cf = CFrame.new(1.5, 2.0, 0.2) * CFrame.Angles(0, math.rad(90), 0), color = STEEL, role = "secondary" })
	local crank = Kit.part(model, { name = "CrankPin", shape = "Cylinder", size = Vector3.new(0.5, 0.24, 0.24), cf = CFrame.new(2.5, 1.2, 0.2) * CFrame.Angles(0, math.rad(90), 0), color = HAZARD, role = "accent" })
	Kit.orbit(model, crank, { radius = 0.55, speed = 3.2, axis = "X", centre = Vector3.new(2.5, 1.2, 0.2), rigid = false })
	Kit.part(model, { name = "CrankWheel", shape = "Cylinder", size = Vector3.new(0.2, 1.5, 1.5), cf = CFrame.new(2.5, 1.2, 0.2) * CFrame.Angles(0, math.rad(90), 0), color = DARK_STEEL, role = "secondary" })
	-- a rod that slides in and out with the model's pulse
	Kit.part(model, { name = "Rod", shape = "Cylinder", size = Vector3.new(1.4, 0.2, 0.2), cf = CFrame.new(0.6, 2.0, 0.2) * CFrame.Angles(0, math.rad(90), 0), color = rgb(230, 232, 240), role = "fixed" })
	Kit.part(model, { name = "Gauge", shape = "Cylinder", size = Vector3.new(0.1, 0.5, 0.5), cf = CFrame.new(0.2, 2.9, -0.7) * CFrame.Angles(0, math.rad(90), 0), color = rgb(245, 245, 235), role = "fixed" })
	Kit.setAnim(model, "pulse", 1.4, 0.6)
end

-- Ice Cream Emergency: a dispenser filling three enormous cones.
machines.ice_cream_emergency = function(model: Model, tint: Color3)
	plinth(model, 4.6, 3.4, 0.5)
	-- machine body
	Kit.part(model, { name = "Body", size = Vector3.new(2.4, 2.6, 1.8), cf = CFrame.new(0, 1.8, 0.6), color = rgb(250, 246, 240), role = "secondary" })
	Kit.part(model, { name = "Trim", size = Vector3.new(2.5, 0.2, 1.9), cf = CFrame.new(0, 2.6, 0.6), color = tint, role = "accent" })
	Kit.part(model, { name = "Screen", size = Vector3.new(1.1, 0.6, 0.1), cf = CFrame.new(0, 2.85, -0.31), color = rgb(90, 200, 220), material = Enum.Material.Neon, role = "fixed" })
	-- three nozzles
	for i = 1, 3 do
		local x = -1.3 + (i - 1) * 1.3
		Kit.part(model, { name = "Nozzle" .. tostring(i), shape = "Cylinder", size = Vector3.new(0.5, 0.34, 0.34), cf = CFrame.new(x, 1.15, -0.15) * UP, color = STEEL, role = "secondary" })
		-- absurdly oversized cone below
		Kit.part(model, { name = "Cone" .. tostring(i), shape = "Cylinder", size = Vector3.new(1.3, 0.95, 0.95), cf = CFrame.new(x, 1.05, -0.9) * UP * CFrame.Angles(0, 0, math.rad(180)), color = rgb(226, 176, 106), role = "fixed" })
		-- three scoops
		local flavours = { tint, rgb(255, 190, 220), rgb(250, 250, 245) }
		for s = 1, 3 do
			Kit.blob(model, Vector3.new(1.1 - s * 0.13, 0.95 - s * 0.1, 1.1 - s * 0.13), CFrame.new(x, 1.7 + (s - 1) * 0.55, -0.9), flavours[s], if s == 1 then "accent" else "fixed")
		end
		-- cherry on top
		Kit.part(model, { name = "Cherry", shape = "Ball", size = Vector3.new(0.28, 0.28, 0.28), cf = CFrame.new(x, 3.05, -0.9), color = rgb(230, 60, 80), role = "fixed" })
	end
	Kit.particles(Kit.part(model, { name = "Chill", size = Vector3.new(2.2, 0.1, 1.6), cf = CFrame.new(0, 0.55, -0.5), color = tint, transparency = 1, role = "fixed" }), "sparkle", rgb(215, 240, 255))
	Kit.setAnim(model, "bob", 0.8, 0.4)
end

-- Thermal Foundry: a forge with a hot side and a cold side stamping blocks.
machines.thermal_foundry = function(model: Model, tint: Color3)
	plinth(model, 4.6, 3.4, 0.5)
	-- hot half
	Kit.part(model, { name = "HotSide", size = Vector3.new(2.0, 2.2, 2.0), cf = CFrame.new(-1.25, 1.6, 0.3), color = rgb(150, 70, 52), material = Enum.Material.Brick, role = "secondary" })
	local coals = Kit.part(model, { name = "Coals", size = Vector3.new(1.5, 0.14, 1.5), cf = CFrame.new(-1.25, 2.75, 0.3), color = rgb(255, 120, 50), material = Enum.Material.Neon, role = "accent" })
	Kit.flickerPart(coals, 0, 0.3)
	Kit.particles(coals, "fire", rgb(255, 130, 50))
	Kit.light(coals, rgb(255, 130, 50), 1.4, 12)
	-- cold half
	Kit.part(model, { name = "ColdSide", size = Vector3.new(2.0, 2.2, 2.0), cf = CFrame.new(1.25, 1.6, 0.3), color = rgb(196, 218, 235), role = "secondary" })
	local frost = Kit.part(model, { name = "Frost", size = Vector3.new(1.5, 0.14, 1.5), cf = CFrame.new(1.25, 2.75, 0.3), color = rgb(180, 235, 255), material = Enum.Material.Neon, role = "accent" })
	Kit.flickerPart(frost, 0, 0.3)
	Kit.particles(frost, "sparkle", rgb(215, 245, 255))
	-- the stamp: a hammer head on a gantry between the halves
	Kit.part(model, { name = "Gantry", size = Vector3.new(3.4, 0.3, 0.5), cf = CFrame.new(0, 3.6, 0.3), color = DARK_STEEL, role = "secondary" })
	Kit.part(model, { name = "Ram", shape = "Cylinder", size = Vector3.new(1.1, 0.36, 0.36), cf = CFrame.new(0, 3.05, 0.3) * UP, color = STEEL, role = "secondary" })
	Kit.part(model, { name = "Hammer", size = Vector3.new(1.2, 0.7, 1.2), cf = CFrame.new(0, 2.3, 0.3), color = INK, role = "fixed" })
	-- anvil and a stamped block
	Kit.part(model, { name = "Anvil", size = Vector3.new(1.5, 0.55, 1.4), cf = CFrame.new(0, 1.05, 0.3), color = DARK_STEEL, role = "secondary" })
	Kit.part(model, { name = "Ingot", size = Vector3.new(0.9, 0.34, 0.8), cf = CFrame.new(0, 1.5, 0.3), color = tint, material = Enum.Material.Neon, role = "accent" })
	-- the whole thing thumps
	Kit.setAnim(model, "pulse", 1.6, 0.7)
end

-- Orbital Express: two towers with delivery pods orbiting between them.
machines.orbital_express = function(model: Model, tint: Color3)
	plinth(model, 5.0, 3.0, 0.5)
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Tower", shape = "Cylinder", size = Vector3.new(3.4, 0.8, 0.8), cf = CFrame.new(side * 1.9, 2.2, 0.2) * UP, color = STEEL, role = "secondary" })
		Kit.part(model, { name = "Ring", shape = "Cylinder", size = Vector3.new(0.16, 1.5, 1.5), cf = CFrame.new(side * 1.9, 3.7, 0.2) * UP, color = tint, material = Enum.Material.Neon, role = "accent" })
		Kit.part(model, { name = "Pad", shape = "Cylinder", size = Vector3.new(0.22, 1.7, 1.7), cf = CFrame.new(side * 1.9, 0.6, 0.2) * UP, color = HAZARD, role = "fixed" })
	end
	-- pods orbiting the whole machine horizontally, tilted so they arc between the towers
	for i = 1, 3 do
		local pod = Kit.blob(model, Vector3.new(0.7, 0.55, 0.9), CFrame.new(0, 2.8, 0.2), tint, "accent")
		Kit.orbit(model, pod, { radius = 1.9, speed = 1.8, phase = (i / 3) * math.pi * 2, axis = "Y", tilt = math.rad(22), centre = Vector3.new(0, 2.8, 0.2) })
		local fin = Kit.part(model, { name = "PodFin", size = Vector3.new(0.12, 0.3, 0.5), cf = CFrame.new(0, 2.8, 0.2), color = rgb(250, 250, 255), role = "fixed" })
		Kit.orbit(model, fin, { radius = 1.9, speed = 1.8, phase = (i / 3) * math.pi * 2, axis = "Y", tilt = math.rad(22), centre = Vector3.new(0, 3.05, 0.2) })
	end
	Kit.particles(Kit.root(model), "stars", tint)
	Kit.light(Kit.root(model), tint, 0.9, 14)
end

-- Neon Grid: floating signs and arcade cabinets.
machines.neon_grid = function(model: Model, tint: Color3)
	plinth(model, 4.8, 3.2, 0.5)
	-- two arcade cabinets
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Cabinet", size = Vector3.new(1.2, 2.2, 1.0), cf = CFrame.new(side * 1.6, 1.6, 0.5), color = rgb(48, 44, 70), role = "secondary" })
		local scr = Kit.part(model, { name = "Screen", size = Vector3.new(0.9, 0.8, 0.1), cf = CFrame.new(side * 1.6, 2.2, -0.02), color = tint, material = Enum.Material.Neon, role = "accent" })
		Kit.flickerPart(scr, 0, 0.25)
		Kit.light(scr, tint, 0.9, 9)
		-- joystick and buttons
		Kit.part(model, { name = "Stick", shape = "Cylinder", size = Vector3.new(0.3, 0.1, 0.1), cf = CFrame.new(side * 1.6 - 0.2, 1.55, -0.15) * CFrame.Angles(0, 0, math.rad(70)), color = INK, role = "fixed" })
		Kit.part(model, { name = "Knob", shape = "Ball", size = Vector3.new(0.2, 0.2, 0.2), cf = CFrame.new(side * 1.6 - 0.2, 1.72, -0.2), color = rgb(240, 70, 90), role = "fixed" })
		for b = 1, 2 do
			Kit.part(model, { name = "Button", shape = "Cylinder", size = Vector3.new(0.08, 0.18, 0.18), cf = CFrame.new(side * 1.6 + 0.1 + b * 0.22, 1.6, -0.16) * CFrame.Angles(math.rad(70), 0, 0), color = if b == 1 then rgb(90, 220, 255) else rgb(255, 220, 90), role = "fixed" })
		end
	end
	-- floating neon signs above, drifting
	local words = { "OPEN", "PLAY", "WOW" }
	for i, w in words do
		local sign = Kit.part(model, {
			name = "Sign_" .. w,
			size = Vector3.new(1.5, 0.55, 0.1),
			cf = CFrame.new((i - 2) * 1.5, 3.5 + (i % 2) * 0.5, -0.3) * CFrame.Angles(0, (i - 2) * math.rad(-12), 0),
			color = if i == 2 then tint else rgb(255, 120, 200),
			material = Enum.Material.Neon,
			role = "accent",
		})
		Kit.flickerPart(sign, 0, 0.35)
		Kit.light(sign, sign.Color, 0.7, 10)
	end
	-- grid floor lines
	for i = 1, 5 do
		Kit.part(model, { name = "GridLine", size = Vector3.new(4.4, 0.06, 0.08), cf = CFrame.new(0, 0.52, -1.2 + (i - 1) * 0.6), color = tint, material = Enum.Material.Neon, transparency = 0.3, role = "accent" })
	end
	Kit.setAnim(model, "drift", 0.6, 0.5)
end

function M.buildMachine(circuitId: string): Model
	local def = Config.Circuits.byId[circuitId]
	local model = Kit.newModel("Machine_" .. circuitId)
	local builder = machines[circuitId] or machines.thunder_turbine
	builder(model, if def then def.color else HAZARD)
	model:SetAttribute("Kind", "machine")
	model:SetAttribute("Key", circuitId)
	model:SetAttribute("Working", false)
	model:SetAttribute("Overdrive", false)
	model:SetAttribute("Cooling", false)
	Kit.finalize(model)
	return model
end

function M.machineIds(): { string }
	local out = {}
	for id in machines do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

-- ============================================================ pylon

-- Containment pylon for the hub crisis. `Charge` (0..1) is written by the
-- server; the client tints the crystal from it.
function M.buildPylon(): Model
	local model = Kit.newModel("ContainmentPylon")
	plinth(model, 3.0, 3.0, 0.6)
	-- three legs leaning into a column
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2
		Kit.part(model, {
			name = "Leg" .. tostring(i),
			shape = "Cylinder",
			size = Vector3.new(4.0, 0.4, 0.4),
			cf = CFrame.new(math.sin(a) * 0.75, 2.3, math.cos(a) * 0.75) * CFrame.Angles(math.cos(a) * 0.16, 0, math.rad(90) - math.sin(a) * 0.16),
			color = DARK_STEEL,
			role = "secondary",
		})
	end
	Kit.part(model, { name = "Collar", shape = "Cylinder", size = Vector3.new(0.5, 1.5, 1.5), cf = CFrame.new(0, 4.4, 0) * UP, color = HAZARD, role = "accent" })
	Kit.part(model, { name = "Column", shape = "Cylinder", size = Vector3.new(3.4, 0.9, 0.9), cf = CFrame.new(0, 6.3, 0) * UP, color = STEEL, role = "secondary" })
	-- hazard bands up the column
	for i = 1, 4 do
		Kit.part(model, { name = "Band", shape = "Cylinder", size = Vector3.new(0.3, 1.0, 1.0), cf = CFrame.new(0, 5.2 + (i - 1) * 0.75, 0) * UP, color = if i % 2 == 0 then INK else HAZARD, role = "fixed" })
	end
	-- crystal
	local crystal = Kit.part(model, { name = "Crystal", shape = "Ball", size = Vector3.new(1.5, 2.2, 1.5), cf = CFrame.new(0, 8.6, 0), color = rgb(120, 230, 255), material = Enum.Material.Neon, role = "accent" })
	Kit.light(crystal, rgb(120, 230, 255), 1.6, 22)
	Kit.particles(crystal, "sparkle", rgb(160, 240, 255))
	-- guard ring orbiting the crystal
	for i = 1, 4 do
		local a = (i / 4) * math.pi * 2
		local seg = Kit.part(model, { name = "Guard" .. tostring(i), size = Vector3.new(0.5, 0.14, 0.2), cf = CFrame.new(0, 8.6, 0), color = HAZARD, material = Enum.Material.Neon, role = "accent" })
		Kit.orbit(model, seg, { radius = 1.2, speed = 1.6, phase = a, axis = "Y", centre = Vector3.new(0, 8.6, 0), rigid = true })
	end
	-- warning sign on the collar
	Kit.part(model, { name = "SignFace", shape = "CornerWedge", size = Vector3.new(0.9, 0.8, 0.12), cf = CFrame.new(0, 4.9, -0.85), color = HAZARD, role = "fixed" })
	Kit.part(model, { name = "SignBang", size = Vector3.new(0.1, 0.34, 0.14), cf = CFrame.new(0, 4.9, -0.93), color = INK, role = "fixed" })

	model:SetAttribute("Kind", "pylon")
	model:SetAttribute("Key", "pylon")
	model:SetAttribute("Charge", 0)
	Kit.finalize(model)
	return model
end

-- ============================================================ decorations

local decorations: { [string]: (Model) -> () } = {}

decorations.hazard_flags = function(model: Model)
	-- two poles with a sagging line of triangular bunting
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Pole", shape = "Cylinder", size = Vector3.new(5.0, 0.24, 0.24), cf = CFrame.new(side * 5.0, 2.5, 0) * UP, color = DARK_STEEL, role = "secondary" })
		Kit.part(model, { name = "Cap", shape = "Ball", size = Vector3.new(0.36, 0.36, 0.36), cf = CFrame.new(side * 5.0, 5.05, 0), color = HAZARD, role = "accent" })
	end
	for i = 1, 13 do
		local t = (i - 1) / 12
		local x = -5.0 + t * 10.0
		local sag = math.sin(t * math.pi) * 1.0
		Kit.part(model, { name = "Line", size = Vector3.new(0.9, 0.06, 0.06), cf = CFrame.new(x, 4.9 - sag, 0) * CFrame.Angles(0, 0, math.rad(math.cos(t * math.pi) * -12)), color = INK, role = "fixed" })
		Kit.part(model, {
			name = "Flag" .. tostring(i),
			shape = "Wedge",
			size = Vector3.new(0.1, 0.6, 0.5),
			cf = CFrame.new(x, 4.55 - sag, 0) * CFrame.Angles(math.rad(180), 0, math.rad(6 * math.sin(i * 1.7))),
			color = if i % 3 == 0 then rgb(90, 200, 255) elseif i % 3 == 1 then HAZARD else rgb(255, 120, 160),
			role = "accent",
		})
	end
end

decorations.smiling_billboard = function(model: Model)
	Kit.part(model, { name = "PostL", shape = "Cylinder", size = Vector3.new(3.5, 0.3, 0.3), cf = CFrame.new(-2.0, 1.75, 0.3) * UP, color = DARK_STEEL, role = "secondary" })
	Kit.part(model, { name = "PostR", shape = "Cylinder", size = Vector3.new(3.5, 0.3, 0.3), cf = CFrame.new(2.0, 1.75, 0.3) * UP, color = DARK_STEEL, role = "secondary" })
	Kit.part(model, { name = "Board", size = Vector3.new(6.0, 3.6, 0.3), cf = CFrame.new(0, 5.2, 0.3), color = rgb(250, 246, 236), role = "secondary" })
	Kit.part(model, { name = "Frame", size = Vector3.new(6.4, 4.0, 0.18), cf = CFrame.new(0, 5.2, 0.42), color = HAZARD, role = "accent" })
	-- a big smiling monster face
	Kit.part(model, { name = "Face", shape = "Ball", size = Vector3.new(2.6, 2.4, 0.3), cf = CFrame.new(0, 5.3, 0.12), color = rgb(120, 220, 150), role = "accent" })
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Eye", shape = "Ball", size = Vector3.new(0.6, 0.6, 0.2), cf = CFrame.new(side * 0.55, 5.85, -0.02), color = rgb(255, 255, 255), role = "fixed" })
		Kit.part(model, { name = "Iris", shape = "Ball", size = Vector3.new(0.26, 0.26, 0.16), cf = CFrame.new(side * 0.55, 5.85, -0.08), color = INK, role = "fixed" })
		-- horn
		Kit.part(model, { name = "Horn", shape = "Wedge", size = Vector3.new(0.16, 0.6, 0.35), cf = CFrame.new(side * 0.9, 6.65, 0.05) * CFrame.Angles(0, 0, side * math.rad(14)), color = rgb(255, 200, 90), role = "fixed" })
	end
	for i = 1, 7 do
		local a = math.rad(-60 + (i - 1) * 20)
		Kit.part(model, { name = "Grin", size = Vector3.new(0.22, 0.12, 0.14), cf = CFrame.new(math.sin(a) * 0.85, 4.85 - math.cos(a) * 0.25, -0.02) * CFrame.Angles(0, 0, -a), color = INK, role = "fixed" })
	end
	-- teeth
	for i = 1, 4 do
		Kit.part(model, { name = "Tooth", size = Vector3.new(0.2, 0.22, 0.12), cf = CFrame.new(-0.5 + (i - 1) * 0.34, 4.92, -0.06), color = rgb(255, 255, 255), role = "fixed" })
	end
end

decorations.pipe_fountain = function(model: Model)
	Kit.part(model, { name = "Basin", shape = "Cylinder", size = Vector3.new(0.7, 5.0, 5.0), cf = CFrame.new(0, 0.35, 0) * UP, color = rgb(180, 186, 196), role = "secondary" })
	Kit.part(model, { name = "Water", shape = "Cylinder", size = Vector3.new(0.2, 4.4, 4.4), cf = CFrame.new(0, 0.68, 0) * UP, color = rgb(110, 200, 255), material = Enum.Material.Glass, transparency = 0.35, role = "accent" })
	-- a tangle of pipes rising from the middle
	Kit.part(model, { name = "Riser", shape = "Cylinder", size = Vector3.new(3.0, 0.6, 0.6), cf = CFrame.new(0, 2.0, 0) * UP, color = rgb(180, 120, 70), material = Enum.Material.Metal, role = "secondary" })
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2
		Kit.part(model, { name = "Elbow" .. tostring(i), shape = "Cylinder", size = Vector3.new(1.5, 0.4, 0.4), cf = CFrame.new(math.sin(a) * 0.75, 3.4, math.cos(a) * 0.75) * CFrame.Angles(0, a, math.rad(65)), color = rgb(180, 120, 70), material = Enum.Material.Metal, role = "secondary" })
		local spout = Kit.part(model, { name = "Spout" .. tostring(i), shape = "Cylinder", size = Vector3.new(0.3, 0.44, 0.44), cf = CFrame.new(math.sin(a) * 1.5, 4.0, math.cos(a) * 1.5) * UP, color = DARK_STEEL, role = "fixed" })
		-- falling water column
		Kit.part(model, { name = "Fall" .. tostring(i), shape = "Cylinder", size = Vector3.new(3.2, 0.28, 0.28), cf = CFrame.new(math.sin(a) * 1.5, 2.3, math.cos(a) * 1.5) * UP, color = rgb(140, 215, 255), material = Enum.Material.Glass, transparency = 0.4, role = "accent" })
		Kit.particles(spout, "rain", rgb(150, 210, 255))
	end
	Kit.part(model, { name = "Valve", shape = "Cylinder", size = Vector3.new(0.16, 1.0, 1.0), cf = CFrame.new(0, 3.0, -0.5) * CFrame.Angles(0, math.rad(90), 0), color = rgb(220, 80, 70), role = "accent" })
	Kit.part(model, { name = "Cap", shape = "Ball", size = Vector3.new(0.8, 0.8, 0.8), cf = CFrame.new(0, 3.9, 0), color = HAZARD, role = "accent" })
end

decorations.neon_company_sign = function(model: Model)
	Kit.part(model, { name = "Base", size = Vector3.new(6.0, 0.5, 1.2), cf = CFrame.new(0, 0.25, 0), color = DARK_STEEL, role = "secondary" })
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Strut", shape = "Cylinder", size = Vector3.new(3.0, 0.22, 0.22), cf = CFrame.new(side * 2.4, 1.5, 0) * UP, color = DARK_STEEL, role = "secondary" })
	end
	-- three big neon letters: C C C
	for i = 1, 3 do
		local x = (i - 2) * 1.9
		-- a C made from an arc of blocks
		for j = 1, 7 do
			local a = math.rad(38 + (j - 1) * 41)
			Kit.part(model, {
				name = "Letter" .. tostring(i) .. "_" .. tostring(j),
				size = Vector3.new(0.3, 0.3, 0.2),
				cf = CFrame.new(x + math.sin(a) * 0.72, 3.6 + math.cos(a) * 0.72, 0),
				color = if i == 2 then rgb(120, 255, 220) else rgb(255, 150, 220),
				material = Enum.Material.Neon,
				role = "accent",
			})
		end
	end
	local halo = Kit.part(model, { name = "Halo", size = Vector3.new(6.2, 0.14, 0.16), cf = CFrame.new(0, 2.45, 0), color = rgb(120, 200, 255), material = Enum.Material.Neon, role = "accent" })
	Kit.flickerPart(halo, 0, 0.3)
	Kit.light(halo, rgb(140, 220, 255), 1.2, 18)
	Kit.part(model, { name = "Tagline", size = Vector3.new(5.0, 0.4, 0.14), cf = CFrame.new(0, 2.1, 0), color = HAZARD, material = Enum.Material.Neon, role = "accent" })
end

decorations.golden_statue = function(model: Model)
	local gold = rgb(255, 205, 85)
	-- plinth
	Kit.part(model, { name = "Plinth", size = Vector3.new(3.0, 1.2, 3.0), cf = CFrame.new(0, 0.6, 0), color = rgb(220, 214, 200), role = "secondary" })
	Kit.part(model, { name = "PlinthTop", size = Vector3.new(3.4, 0.25, 3.4), cf = CFrame.new(0, 1.32, 0), color = rgb(240, 236, 226), role = "secondary" })
	Kit.part(model, { name = "Plaque", size = Vector3.new(1.8, 0.5, 0.1), cf = CFrame.new(0, 0.75, -1.52), color = gold, material = Enum.Material.Metal, role = "accent" })
	-- a golden Breeze Bean, the first creature anyone catches
	local m = Enum.Material.Metal
	Kit.blob(model, Vector3.new(1.9, 2.4, 1.8), CFrame.new(0, 3.0, 0), gold, "accent", m)
	Kit.blob(model, Vector3.new(1.4, 1.5, 1.4), CFrame.new(0.5, 3.8, 0.12), gold, "accent", m)
	Kit.blob(model, Vector3.new(1.2, 1.25, 1.2), CFrame.new(-0.5, 2.2, 0.06), gold, "accent", m)
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Leaf", shape = "Ball", mesh = "Sphere", size = Vector3.new(1.9, 0.2, 0.95), cf = CFrame.new(side * 1.35, 3.9, 0.12) * CFrame.Angles(0, side * math.rad(-25), side * math.rad(35)), color = gold, material = m, role = "accent" })
	end
	Kit.part(model, { name = "Stem", shape = "Cylinder", size = Vector3.new(0.6, 0.18, 0.18), cf = CFrame.new(0.25, 4.65, 0.06) * UP, color = gold, material = m, role = "accent" })
	Kit.blob(model, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0.25, 4.95, 0.06), gold, "accent", m)
	-- carved face
	for _, side in { -1, 1 } do
		Kit.part(model, { name = "Eye", shape = "Ball", size = Vector3.new(0.3, 0.3, 0.16), cf = CFrame.new(side * 0.28 + 0.12, 3.35, -0.82), color = rgb(120, 96, 30), role = "fixed" })
	end
	Kit.part(model, { name = "Smile", size = Vector3.new(0.5, 0.1, 0.1), cf = CFrame.new(0.12, 2.95, -0.86), color = rgb(120, 96, 30), role = "fixed" })
	Kit.particles(Kit.root(model), "glint", rgb(255, 240, 190))
	Kit.light(Kit.root(model), gold, 0.9, 14)
end

function M.buildDecoration(key: string): Model
	local model = Kit.newModel("Decor_" .. key)
	local builder = decorations[key]
	if builder then
		builder(model)
	else
		-- a plain marker rather than nothing, so a bad key is visible in game
		Kit.part(model, { name = "Marker", size = Vector3.new(1, 2, 1), cf = CFrame.new(0, 1, 0), color = HAZARD, role = "accent" })
	end
	model:SetAttribute("Kind", "decoration")
	model:SetAttribute("Key", key)
	Kit.finalize(model)
	return model
end

function M.decorationKeys(): { string }
	local out = {}
	for key in decorations do
		table.insert(out, key)
	end
	table.sort(out)
	return out
end

return M
