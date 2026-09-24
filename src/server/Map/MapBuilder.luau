--!strict
-- Builds the whole world at runtime: the hub plaza (spawn, Upgrade Workshop,
-- Relaunch Beacon, Atlas kiosk, company board), the Containment Crisis arena,
-- and the six wild regions with their gates.
--
-- Player plots are NOT built here; CityService builds them from `refs.plots`
-- using Map.PlotTemplate.
--
-- Layout, in studs, ground top surface at y = 0. North is -Z.
--   Town island   grass disc radius 215, the fountain at the origin
--   Promenade     stone ring, radii 70 to 96, with four paved arms in to the
--                 fountain apron (radius 30, basin radius 20)
--   Services      Upgrade Workshop (-40, -40), Catastrophe Atlas (40, -40),
--                 City Relaunch (40, 40). The south-west quadrant is garden.
--   Plot ring     six 60 x 60 lots at radius 145, every 60 degrees from 0, each
--                 on its own 14-wide connector out to the ring
--   Regions       one straight chain north of the island: six 280 x 200 walled
--                 cells, region i centred at z = -215 - (i - 0.5) * 200
--   Region gates  a 44-wide opening in the divider wall at each cell's south
--                 edge. Gusty Gardens opens straight off the town, unwalled.
--   Arena         its own islet south of the town at (0, 0, 300)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local MapBuilder = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local INK = rgb(46, 44, 52)
local HAZARD = rgb(255, 190, 50)
local CONCRETE = rgb(186, 186, 194)
local DECK = rgb(120, 126, 142)
local STEEL = rgb(150, 156, 168)
local PATH = rgb(158, 156, 166)

-- ---------------------------------------------------------------- layout
-- Every dimension the concept board fixes, in one place. North is -Z, so the
-- region chain runs in decreasing z and the town's south entrance is at +z.
local ISLAND_R = 215
local RING_IN, RING_OUT = 70, 96
local APRON_R, BASIN_R = 30, 20
local TRUNK_W, ARM_W = 22, 16
local PLOT_R, PLOT_HALF, CONNECTOR_W = 145, 30, 14
local SERVICE_OFF = 40

-- 200 deep is the floor the art sets, not a taste call: Frostbite Peaks'
-- own approach scenery is 196 studs end to end and poked through a
-- 180-deep cell's divider wall. The concept's cells are shallower still,
-- which a circular prop ring cannot reach without being reshaped.
local CELL_W, CELL_D = 280, 200
local WALL_T, WALL_H = 3, 9
-- 45 divides 180 exactly, so a lateral wall's piers land on every divider.
local PIER_SPACING = 45
local GATE_W = 44
local CHAIN_Z0 = -ISLAND_R
local CHAIN_LEN = CELL_D * 6
local STRIP_W = CELL_W + 80
local ARENA_CENTRE = Vector3.new(0, 0, 300)

local PAVER = rgb(226, 214, 190)
local PAVER_KERB = rgb(198, 184, 158)
local GRASS_C = rgb(126, 168, 104)
local WALL_STONE = rgb(228, 216, 192)
local WALL_CAP = rgb(203, 189, 163)
local WALL_PIER = rgb(216, 203, 179)
local LANTERN = rgb(255, 214, 140)
local IRON = rgb(64, 58, 56)
local WATER_C = rgb(83, 204, 232)
local TEAL_PANEL = rgb(38, 78, 122)
local GOLD = rgb(226, 170, 58)
local GOLD_DEEP = rgb(176, 124, 36)
local NAVY = rgb(30, 52, 92)
local BRONZE = rgb(120, 82, 48)
local DIRT = rgb(226, 190, 132)
-- The bay's lane is the beach: the concept shows no change of surface at all,
-- so this matches splashwater_bay's groundColor exactly and only the geometry
-- (and the region module's flat stones) marks the route.
local SAND_TRAIL = rgb(246, 214, 152)
-- The quarry's lane is the quarry floor: the Cinder Quarry concept draws no
-- road at all either, so this matches cinder_canyon's groundColor exactly.
local QUARRY_TRAIL = rgb(238, 134, 86)
-- The Alpine Outpost's route is packed snow, a shade bluer than the meadow
-- either side of it, as the concept draws it: no paving and no kerbs.
local SNOW_TRAIL = rgb(190, 206, 228)

-- A region whose interior has been remodelled to its own concept reports its
-- own field rectangle from its scenery module. Regions still built around a
-- circular prop ring report nothing and keep this disc.
local SPAWN_RADIUS = 44
-- Those same regions lay out their own perimeter planting and do not want the
-- generic biome shoulders.
local OWN_PERIMETER: { [string]: boolean } = { Wind = true, Water = true, Heat = true, Frost = true }
-- Regions that dress the grass strip outside their own stretch of the side
-- walls; the shared treeline leaves those stretches alone.
local OWN_FLANK: { [string]: boolean } = { Frost = true }
-- Gusty's route is trodden earth in the concept; the rest are paved except
-- those below, whose concepts draw no road at all.
local TRAIL_DIRT: { [string]: boolean } = { Wind = true }
-- A lane that is the ground it crosses: same colour, same material, and only
-- the geometry either side marks the way. Paving these kerbed a beach and a
-- quarry floor with a grey runway, which is what neither concept shows.
local TRAIL_BLEND: { [string]: { color: Color3, material: Enum.Material, width: number } } = {
	Water = { color = SAND_TRAIL, material = Enum.Material.Sand, width = 22 },
	Heat = { color = QUARRY_TRAIL, material = Enum.Material.Sandstone, width = 24 },
	Frost = { color = SNOW_TRAIL, material = Enum.Material.Snow, width = 24 },
}

-- Boards built from concept art share one five-row hierarchy: a small element
-- line, a large name, a large status, then a surge footer that sets its
-- countdown above its explanation. Wind was approved on the original even rows
-- and keeps them.
local BOARD_HIERARCHY: { [string]: boolean } = {
	Water = true, Heat = true, Frost = true, Storm = true, Cosmic = true,
}

local partCount = 0

type P = {
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	collide: boolean?,
	shape: Enum.PartType?,
	query: boolean?,
	parent: Instance,
}

local function part(props: P): Part
	local p = Instance.new("Part")
	p.Name = props.name
	p.Size = props.size
	p.CFrame = props.cf
	p.Color = props.color or CONCRETE
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Transparency = props.transparency or 0
	p.Anchored = true
	p.CanCollide = props.collide == true
	p.CanTouch = false
	p.CanQuery = if props.query == nil then true else props.query
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.shape then
		p.Shape = props.shape
	end
	p.Parent = props.parent
	partCount += 1
	return p
end

local function polar(radius: number, degrees: number, y: number?): Vector3
	local a = math.rad(degrees)
	return Vector3.new(math.cos(a) * radius, y or 0, math.sin(a) * radius)
end

-- Where city i sits on the ring. Layout A: eight from 22.5 every 45. Layout B:
-- six from 60 every 60, each centred between two region roads (roads at 30 + 60k).
local function plotAngle(i: number): number
	return if Config.MapLayout == "B" then 60 + (i - 1) * 60 else 22.5 + (i - 1) * 45
end

-- A flat disc approximated by a cylinder standing on its end.
local function disc(parent: Instance, name: string, centre: Vector3, radius: number, thickness: number, color: Color3, material: Enum.Material?): Part
	return part({
		name = name,
		size = Vector3.new(thickness, radius * 2, radius * 2),
		cf = CFrame.new(centre + Vector3.new(0, -thickness / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = color,
		material = material,
		shape = Enum.PartType.Cylinder,
		collide = true,
		parent = parent,
	})
end

-- Flat stone paving. The concept's town is paved, not chevroned: the promenade,
-- its four arms, the plot connectors and both trunks are plain slabs, and the
-- directional chevrons are kept for the region trail where they earn their keep.
local function slab(parent: Instance, name: string, cx: number, cz: number, sizeX: number, sizeZ: number, y: number, color: Color3?): Part
	return part({
		name = name,
		size = Vector3.new(sizeX, 1, sizeZ),
		cf = CFrame.new(cx, y - 0.5, cz),
		color = color or PAVER,
		material = Enum.Material.Concrete,
		collide = true,
		parent = parent,
	})
end

-- A paved strip between two ground points, for the radial connectors.
local function strip(parent: Instance, name: string, from: Vector3, to: Vector3, width: number, y: number, color: Color3?): Part?
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = delta.Magnitude
	if length < 0.5 then
		return nil
	end
	local mid = Vector3.new((from.X + to.X) / 2, y - 0.5, (from.Z + to.Z) / 2)
	return part({
		name = name,
		size = Vector3.new(width, 1, length),
		cf = CFrame.lookAt(mid, mid + delta.Unit),
		color = color or PAVER,
		material = Enum.Material.Concrete,
		collide = true,
		parent = parent,
	})
end

-- A run of pale stone wall with a lantern pier every PIER_SPACING studs: the
-- enclosure the concept draws around every region. The end piers are optional
-- so a divider's two halves do not bury a pier inside the taller gate piers.
local function wall(parent: Instance, from: Vector3, to: Vector3, height: number, noStartPier: boolean?, noEndPier: boolean?)
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end
	local mid = Vector3.new((from.X + to.X) / 2, 0, (from.Z + to.Z) / 2)
	local base = CFrame.lookAt(mid, mid + delta.Unit)
	part({ name = "Wall", size = Vector3.new(WALL_T, height, length), cf = base * CFrame.new(0, height / 2, 0),
		color = WALL_STONE, material = Enum.Material.Concrete, collide = true, parent = parent })
	part({ name = "WallCap", size = Vector3.new(WALL_T + 1.0, 1.0, length), cf = base * CFrame.new(0, height + 0.5, 0),
		color = WALL_CAP, material = Enum.Material.Concrete, parent = parent })
	-- Two scored courses: a plain slab read as a slab, and the concept's wall is
	-- visibly laid in blocks.
	for _, frac in { 0.36, 0.7 } do
		part({ name = "WallCourse", size = Vector3.new(WALL_T + 0.3, 0.32, length), cf = base * CFrame.new(0, height * frac, 0),
			color = WALL_CAP:Lerp(rgb(150, 140, 122), 0.5), material = Enum.Material.Concrete, parent = parent })
	end
	local piers = math.max(1, math.round(length / PIER_SPACING))
	for i = 0, piers do
		if not ((i == 0 and noStartPier) or (i == piers and noEndPier)) then
			local at = from:Lerp(to, i / piers)
			local top = height + 3.2
			part({ name = "WallPier", size = Vector3.new(5.2, top, 5.2), cf = CFrame.new(at.X, top / 2, at.Z),
				color = WALL_PIER, material = Enum.Material.Concrete, collide = true, parent = parent })
			part({ name = "LanternBase", size = Vector3.new(3.4, 0.7, 3.4), cf = CFrame.new(at.X, top + 0.35, at.Z), color = IRON, parent = parent })
			local bulb = part({ name = "LanternBulb", size = Vector3.new(2.4, 2.4, 2.4), cf = CFrame.new(at.X, top + 1.9, at.Z),
				color = LANTERN, material = Enum.Material.Neon, parent = parent })
			part({ name = "LanternCap", size = Vector3.new(3.8, 0.8, 3.8), cf = CFrame.new(at.X, top + 3.5, at.Z), color = IRON, parent = parent })
			local light = Instance.new("PointLight")
			light.Color = LANTERN
			light.Range = 30
			light.Brightness = 0.85
			light.Parent = bulb
		end
	end
end

local function hazardStrip(parent: Instance, origin: CFrame, length: number, height: number, thickness: number)
	local count = math.max(2, math.floor(length / 2.2))
	for i = 1, count do
		local x = -length / 2 + (i - 0.5) * (length / count)
		part({
			name = "Stripe",
			size = Vector3.new(length / count * 0.7, height, thickness),
			cf = origin * CFrame.new(x, 0, 0) * CFrame.Angles(0, 0, math.rad(26)),
			color = if i % 2 == 0 then HAZARD else INK,
			parent = parent,
		})
	end
end

local function surface(host: BasePart, face: Enum.NormalId, pixelsPerStud: number?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 20
	gui.Parent = host
	return gui
end

local function label(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	return l
end

-- A guidance route from one point to another.
--
-- A plain grey strip told the player nothing: it read as scenery, not as "go
-- this way". So a route is a dark roadbed, a coloured edge line naming where it
-- leads, and a run of bright chevrons pointing at the destination. The chevrons
-- are the part that actually directs: they have a direction, they repeat, and
-- they are the only thing in the hub that is this yellow.
--
-- `accent` tints the edge lines, so a route to Frostbite Peaks is edged in that
-- region's blue and a route to a hub building is edged in company yellow.
local CHEVRON_SPACING = 11
local CHEVRON_MAX = 16
local BOLLARD_SPACING = 30
local BOLLARD_MAX = 7
local routeCounter = 0 -- every path() call is one route for Controllers.RouteLights

local function path(parent: Instance, from: Vector3, to: Vector3, width: number, accent: Color3?)
	width *= 1.5
	local delta = to - from
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if flat.Magnitude < 0.01 then
		return
	end
	local dir = flat.Unit
	local mid = (from + to) / 2
	local trim = accent or HAZARD

	-- roadbed: darker than the plaza so the chevrons read against it
	-- Region ground tops out at 0.3; keep the road and markings above it.
	local base = CFrame.lookAt(Vector3.new(mid.X, 0.4, mid.Z), Vector3.new(mid.X, 0.4, mid.Z) + dir)
	part({
		name = "Path",
		size = Vector3.new(width, 0.25, length),
		cf = base,
		color = rgb(25, 27, 32),
		material = Enum.Material.Asphalt,
		parent = parent,
	})

	-- edge lines in the destination's colour. Markings are sunk half into the
	-- slab (centre on its top plane): a marking floated a few thousandths above
	-- it shares a plane with the asphalt and shimmers from any distance.
	local slabTop = 0.125 -- half the slab's 0.25 thickness, above `base`
	for _, side in { -1, 1 } do
		part({
			name = "PathEdge",
			size = Vector3.new(1.0, 0.12, length),
			cf = base * CFrame.new(side * (width / 2 - 0.6), slabTop, 0),
			color = trim,
			material = Enum.Material.Neon,
			parent = parent,
		})
	end

	-- chevrons pointing at the destination. Neon, and tagged with their order
	-- along the route so the client can run a light down them toward `to`
	-- (Controllers.RouteLights); painted arrows alone vanish when you stand on them.
	local count = math.clamp(math.floor(length / CHEVRON_SPACING), 1, CHEVRON_MAX)
	local step = length / (count + 1)
	local arm = width * 0.6
	routeCounter += 1
	local routeId = "route" .. tostring(routeCounter)
	for i = 1, count do
		local along = -length / 2 + step * i
		for _, side in { -1, 1 } do
			local chevron = part({
				name = "PathChevron",
				size = Vector3.new(2.6, 0.16, arm),
				-- each half of the ">" is rotated in from the centre line
				cf = base * CFrame.new(side * arm * 0.32, slabTop, along) * CFrame.Angles(0, side * math.rad(38), 0),
				color = rgb(210, 125, 12),
				material = Enum.Material.Neon,
				parent = parent,
			})
			chevron:SetAttribute("RouteId", routeId)
			chevron:SetAttribute("Index", i)
			chevron:SetAttribute("Count", count)
			CollectionService:AddTag(chevron, "RouteChevron")
		end
	end

	-- Markings painted on the floor foreshorten to almost nothing when you are
	-- standing on them, which is exactly when you need them. Bollards give the
	-- route a silhouette at eye level: you can see where it goes from across the
	-- plaza, and which way, because the cap lights march toward the destination.
	local posts = math.clamp(math.floor(length / BOLLARD_SPACING), 1, BOLLARD_MAX)
	local postStep = length / (posts + 1)
	for i = 1, posts do
		local along = -length / 2 + postStep * i
		for _, side in { -1, 1 } do
			local at = base * CFrame.new(side * (width / 2 + 1.1), 0, along)
			part({
				name = "RouteBollard",
				size = Vector3.new(0.55, 3.2, 0.55),
				cf = at * CFrame.new(0, 1.5, 0),
				color = INK,
				parent = parent,
			})
			part({
				name = "RouteBollardBand",
				size = Vector3.new(0.7, 0.6, 0.7),
				cf = at * CFrame.new(0, 2.1, 0),
				color = HAZARD,
				parent = parent,
			})
			part({
				name = "RouteBollardCap",
				size = Vector3.new(0.5, 0.35, 0.5),
				cf = at * CFrame.new(0, 3.2, 0),
				color = trim,
				material = Enum.Material.Neon,
				parent = parent,
			})
		end
	end
end

local function lamp(parent: Instance, at: Vector3, color: Color3?)
	part({ name = "LampPost", size = Vector3.new(0.5, 9, 0.5), cf = CFrame.new(at + Vector3.new(0, 4.5, 0)), color = DECK, collide = true, parent = parent })
	local bulb = part({ name = "Bulb", size = Vector3.new(1.1, 1.1, 1.1), cf = CFrame.new(at + Vector3.new(0, 9.4, 0)), color = color or rgb(255, 240, 200), material = Enum.Material.Neon, shape = Enum.PartType.Ball, parent = parent })
	local light = Instance.new("PointLight")
	light.Color = color or rgb(255, 240, 200)
	light.Range = 34
	light.Brightness = 1.0
	light.Parent = bulb
end

-- ============================================================ town

-- The fountain at the centre of the park. It replaces the company logo ring,
-- which sat in the same place and competed with the paving for attention.
local function buildFountain(parent: Instance)
	local f = Instance.new("Model")
	f.Name = "Fountain"
	f.Parent = parent
	disc(f, "Apron", Vector3.new(0, 0.30, 0), APRON_R, 1, PAVER, Enum.Material.Concrete)
	disc(f, "ApronKerb", Vector3.new(0, 0.36, 0), BASIN_R + 4.4, 1, rgb(238, 230, 212), Enum.Material.Concrete)
	disc(f, "BasinFloor", Vector3.new(0, 0.62, 0), BASIN_R + 2.6, 1.2, rgb(206, 230, 238), Enum.Material.Concrete)
	disc(f, "Water", Vector3.new(0, 1.30, 0), BASIN_R, 1.6, WATER_C, Enum.Material.Neon)
	-- The rim is a ring of segments, not a disc: a disc wide enough to be a rim
	-- is also a lid, and it capped the water it was meant to hold.
	for i = 1, 36 do
		local a = (i / 36) * 360
		part({ name = "BasinRim", size = Vector3.new(4.4, 2.8, 2.6), cf = CFrame.new(polar(BASIN_R + 1.7, a, 1.4)) * CFrame.Angles(0, math.rad(-a), 0),
			color = rgb(244, 237, 220), material = Enum.Material.Concrete, collide = true, parent = f })
	end
	disc(f, "Plinth", Vector3.new(0, 2.9, 0), 4.6, 3.6, rgb(240, 233, 216), Enum.Material.Concrete)
	local body = part({ name = "StatueBody", size = Vector3.new(7.2, 7.2, 7.2), cf = CFrame.new(0, 6.2, 0),
		color = rgb(248, 244, 234), shape = Enum.PartType.Ball, collide = true, parent = f })
	for _, side in { -1, 1 } do
		part({ name = "StatueEar", size = Vector3.new(1.6, 4.6, 2.0), cf = CFrame.new(side * 2.1, 9.7, 0) * CFrame.Angles(0, 0, math.rad(side * 12)),
			color = rgb(248, 244, 234), parent = f })
		part({ name = "StatueEye", size = Vector3.new(0.9, 1.2, 0.5), cf = CFrame.new(side * 1.5, 6.6, 3.4), color = rgb(58, 54, 60), parent = f })
	end
	part({ name = "Jet", size = Vector3.new(1.1, 7.4, 1.1), cf = CFrame.new(0, 13.2, 0), color = rgb(226, 246, 255),
		material = Enum.Material.Neon, transparency = 0.45, query = false, parent = f })
	local glow = Instance.new("PointLight")
	glow.Color = WATER_C
	glow.Range = 42
	glow.Brightness = 0.8
	glow.Parent = body
end

-- A low board on a pair of posts, beside a path rather than across it.
local function groundSign(parent: Instance, at: Vector3, text: string, yaw: number)
	local frame = CFrame.new(at) * CFrame.Angles(0, math.rad(yaw), 0)
	for _, side in { -1, 1 } do
		part({ name = "SignPost", size = Vector3.new(0.9, 6, 0.9), cf = frame * CFrame.new(side * 5.2, 3, 0),
			color = rgb(122, 96, 72), material = Enum.Material.Wood, collide = true, parent = parent })
	end
	local board = part({ name = "SignBoard", size = Vector3.new(13, 3.6, 0.7), cf = frame * CFrame.new(0, 6.2, 0),
		color = rgb(240, 232, 214), material = Enum.Material.WoodPlanks, collide = true, parent = parent })
	local gui = surface(board, Enum.NormalId.Front, 26)
	local l = label(gui, "Text", text, UDim2.fromScale(0.92, 0.7), UDim2.fromScale(0.04, 0.15), rgb(64, 58, 52))
	l.TextStrokeTransparency = 1
	return board
end

local function buildHub(parent: Instance)
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	hub.Parent = parent

	-- Stacked discs, each a little proud of the one beneath it. Two surfaces at
	-- exactly the same height z-fight, which used to shimmer across the plaza.
	disc(hub, "Island", Vector3.new(0, 0.04, 0), ISLAND_R, 6, GRASS_C, Enum.Material.Grass)
	disc(hub, "Ring", Vector3.new(0, 0.10, 0), RING_OUT, 1, PAVER, Enum.Material.Concrete)
	disc(hub, "RingKerb", Vector3.new(0, 0.16, 0), RING_IN + 1.4, 1, PAVER_KERB, Enum.Material.Concrete)
	disc(hub, "Park", Vector3.new(0, 0.22, 0), RING_IN, 1, GRASS_C, Enum.Material.Grass)

	-- Four arms cross the park: the north and south trunks run all the way out
	-- to the island edge, east and west let players round the fountain either way.
	local trunkLen = ISLAND_R - 3 - APRON_R
	slab(hub, "TrunkNorth", 0, -(APRON_R + ISLAND_R - 3) / 2, TRUNK_W, trunkLen, 0.28)
	slab(hub, "TrunkSouth", 0, (APRON_R + ISLAND_R - 3) / 2, TRUNK_W, trunkLen, 0.28)
	local armLen = RING_IN + 1 - APRON_R
	slab(hub, "ArmWest", -(APRON_R + RING_IN + 1) / 2, 0, armLen, ARM_W, 0.28)
	slab(hub, "ArmEast", (APRON_R + RING_IN + 1) / 2, 0, armLen, ARM_W, 0.28)

	buildFountain(hub)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.82, 52)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Color = rgb(120, 220, 160)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.35
	spawn.Parent = hub

	-- The three public services stand in the park inside the ring, one to a
	-- quadrant, all facing south into it the way the concept draws them. The
	-- south-west quadrant is left as garden.
	local Landmarks = require(script.Parent.HubLandmarks)
	local function facingSouth(pos: Vector3): CFrame
		return CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
	end
	local workshopPos = Vector3.new(-SERVICE_OFF, 0, -SERVICE_OFF)
	local atlasPos = Vector3.new(SERVICE_OFF, 0, -SERVICE_OFF)
	local beaconPos = Vector3.new(SERVICE_OFF, 0, SERVICE_OFF)
	local workshopTerminal = Landmarks.buildWorkshop(hub, facingSouth(workshopPos), part)
	local atlasTerminal = Landmarks.buildAtlas(hub, facingSouth(atlasPos), part)
	local beaconTerminal = Landmarks.buildBeacon(hub, facingSouth(beaconPos), part)
	-- a paved forecourt in front of each, joining its own arm of the park
	for _, at in { workshopPos, atlasPos, beaconPos } do
		slab(hub, "ServiceForecourt", at.X, at.Z + 24, 34, 12, 0.29)
		strip(hub, "ServiceSpur", Vector3.new(at.X, 0, at.Z + 28), Vector3.new(at.X, 0, math.sign(at.Z) * (RING_IN - 2)), 10, 0.29)
	end

	-- garden quadrant: a bench, boulders and planting, no interaction
	local gardenAt = Vector3.new(-SERVICE_OFF, 0, SERVICE_OFF)
	part({ name = "BenchSeat", size = Vector3.new(11, 0.7, 3), cf = CFrame.new(gardenAt + Vector3.new(0, 2.6, -6)) * CFrame.Angles(0, math.rad(18), 0),
		color = rgb(150, 106, 74), material = Enum.Material.WoodPlanks, collide = true, parent = hub })
	part({ name = "BenchBack", size = Vector3.new(11, 3.2, 0.6), cf = CFrame.new(gardenAt + Vector3.new(0, 4.2, -7.4)) * CFrame.Angles(0, math.rad(18), 0),
		color = rgb(150, 106, 74), material = Enum.Material.WoodPlanks, parent = hub })
	for i = 1, 7 do
		local a = (i / 7) * 360
		part({ name = "GardenShrub", size = Vector3.new(6 + (i % 3) * 2, 4.4, 5.6), cf = CFrame.new(gardenAt + polar(13 + (i % 3) * 4, a, 1.6)),
			color = rgb(84 + (i % 3) * 14, 138 + (i % 2) * 18, 78), material = Enum.Material.Grass, shape = Enum.PartType.Ball, collide = true, parent = hub })
	end
	for _, spot in { Vector3.new(-16, 0, 12), Vector3.new(9, 0, 17) } do
		part({ name = "GardenRock", size = Vector3.new(7, 5, 6.4), cf = CFrame.new(gardenAt + spot + Vector3.new(0, 1.2, 0)),
			color = rgb(138, 140, 148), material = Enum.Material.Rock, shape = Enum.PartType.Ball, collide = true, parent = hub })
	end

	-- Lamps line the arms, a pair either side where each leaves the apron and
	-- another where it meets the ring.
	for _, a in { 0, 90, 180, 270 } do
		local half = (if a % 180 == 0 then ARM_W else TRUNK_W) / 2 + 4
		for _, side in { -1, 1 } do
			lamp(hub, polar(APRON_R + 9, a) + polar(half, a + 90) * side)
			lamp(hub, polar(RING_IN - 8, a) + polar(half, a + 90) * side)
		end
	end
	for i = 1, Config.MaxPlayers do
		lamp(hub, polar(RING_OUT + 6, plotAngle(i)))
	end

	-- The two ways out, signed beside the path rather than across it.
	groundSign(hub, Vector3.new(-21, 0, ISLAND_R - 19), "PLAYER TOWN", 180)
	groundSign(hub, Vector3.new(-21, 0, -(ISLAND_R - 19)), "TO REGIONS", 0)
	local boardPos = Vector3.new(24, 8, ISLAND_R - 19)
	part({ name = "BoardPostL", size = Vector3.new(0.8, 9, 0.8), cf = CFrame.new(boardPos + Vector3.new(-8, -3.5, 0)), color = DECK, collide = true, parent = hub })
	part({ name = "BoardPostR", size = Vector3.new(0.8, 9, 0.8), cf = CFrame.new(boardPos + Vector3.new(8, -3.5, 0)), color = DECK, collide = true, parent = hub })
	local board = part({ name = "Board", size = Vector3.new(20, 9, 1), cf = CFrame.new(boardPos), color = rgb(52, 58, 78), parent = hub })
	local boardText = label(surface(board, Enum.NormalId.Front, 20), "Text", Config.CompanyName, UDim2.fromScale(0.96, 0.9), UDim2.fromScale(0.02, 0.05), rgb(255, 252, 245))
	boardText.TextScaled = false
	boardText.TextSize = 26
	boardText.TextWrapped = true
	boardText.TextXAlignment = Enum.TextXAlignment.Left
	boardText.TextYAlignment = Enum.TextYAlignment.Top

	return {
		model = hub,
		spawn = spawn,
		workshop = workshopTerminal,
		beacon = beaconTerminal,
		atlas = atlasTerminal,
		board = boardText,
	}
end

-- ============================================================ arena

local function buildArena(parent: Instance, centre: Vector3)
	local arena = Instance.new("Model")
	arena.Name = "Arena"
	arena.Parent = parent

	disc(arena, "Floor", centre + Vector3.new(0, 0.06, 0), 30, 1, rgb(196, 192, 200), Enum.Material.Concrete)
	disc(arena, "Ring", centre + Vector3.new(0, 0.15, 0), 22, 1, rgb(172, 168, 180), Enum.Material.Concrete)
	-- containment ring markings
	for i = 1, 30 do
		local a = (i / 30) * 360
		part({
			name = "Marking",
			size = Vector3.new(3.6, 0.14, 1.2),
			cf = CFrame.new(centre + polar(27, a, 0.30)) * CFrame.Angles(0, math.rad(-a), 0),
			color = if i % 2 == 0 then HAZARD else INK,
			parent = arena,
		})
	end
	-- low wall
	for i = 1, 36 do
		local a = (i / 36) * 360
		part({ name = "Wall", size = Vector3.new(5.6, 3, 1.2), cf = CFrame.new(centre + polar(30, a, 1.5)) * CFrame.Angles(0, math.rad(-a), 0), color = DECK, collide = true, parent = arena })
	end

	-- stage behind the arena
	-- The stage, its hazard stripe and the screen stand on the arena's far side
	-- from the town, facing back into it. They used to be written as absolute
	-- coordinates tied to the arena's old home; when the arena moved to its own
	-- islet these stayed behind, and the screen ended up standing in the middle
	-- of the road to Gusty Gardens.
	local outward = Vector3.new(centre.X, 0, centre.Z)
	outward = if outward.Magnitude > 1 then outward.Unit else Vector3.new(0, 0, -1)
	local stageCF = CFrame.lookAt(centre + outward * 23 + Vector3.new(0, 1, 0), centre + Vector3.new(0, 1, 0))
	part({ name = "Stage", size = Vector3.new(40, 2, 16), cf = stageCF, color = DECK, collide = true, parent = arena })
	hazardStrip(arena, stageCF * CFrame.new(0, 0.4, -7.9), 40, 1.4, 0.2)

	local bossSpot = part({ name = "BossSpot", size = Vector3.new(2, 1, 2), cf = CFrame.new(centre + Vector3.new(0, 0.5, 0)), transparency = 1, collide = false, query = false, parent = arena })
	bossSpot:SetAttribute("WaypointName", "Crisis Arena")
	bossSpot:SetAttribute("WaypointColor", rgb(255, 120, 100))
	bossSpot:SetAttribute("WaypointHeight", 14)
	CollectionService:AddTag(bossSpot, "Waypoint")

	-- screen
	part({ name = "ScreenPostL", size = Vector3.new(1, 13, 1), cf = stageCF * CFrame.new(-8, 5.5, 6), color = DECK, collide = true, parent = arena })
	part({ name = "ScreenPostR", size = Vector3.new(1, 13, 1), cf = stageCF * CFrame.new(8, 5.5, 6), color = DECK, collide = true, parent = arena })
	-- Front is the -Z face, and stageCF looks at the arena, so the board now
	-- reads from inside the ring instead of facing out into empty grass.
	local screen = part({ name = "Screen", size = Vector3.new(18, 8, 1), cf = stageCF * CFrame.new(0, 11, 6), color = rgb(40, 44, 62), parent = arena })
	local screenText = label(surface(screen, Enum.NormalId.Front, 20), "Text", "Containment Crisis", UDim2.fromScale(0.96, 0.9), UDim2.fromScale(0.02, 0.05), rgb(255, 220, 120))
	screenText.TextScaled = false
	screenText.TextSize = 30
	screenText.TextWrapped = true

	-- pylons
	local MachineryBuilders = require(ReplicatedStorage.Shared.Models.MachineryBuilders)
	local pylonFolder = Instance.new("Folder")
	pylonFolder.Name = "Pylons"
	pylonFolder.Parent = arena
	local pylons = {}
	local angles = { 90, 210, 330 }
	for i, a in angles do
		local pos = centre + polar(20, a)
		local ok, model = pcall(MachineryBuilders.buildPylon)
		local m: Model
		if ok and typeof(model) == "Instance" then
			m = model :: Model
		else
			warn("[MapBuilder] pylon build failed:", model)
			m = Instance.new("Model")
			local fallback = part({ name = "Pylon", size = Vector3.new(3, 10, 3), cf = CFrame.new(pos + Vector3.new(0, 5, 0)), color = HAZARD, collide = true, parent = m })
			m.PrimaryPart = fallback
		end
		m.Name = "Pylon_" .. tostring(i)
		m:SetAttribute("PylonIndex", i)
		m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(-a + 90), 0))
		m.Parent = pylonFolder
		pylons[i] = { model = m, prompt = nil }
	end

	-- (no road across the floor: the hub spoke ends at the entrance, and the
	-- old one ran through the wall ring to the boss spot)
	for i = 1, 6 do
		lamp(arena, centre + polar(34, (i - 1) * 60), rgb(200, 230, 255))
	end

	return { model = arena, centre = centre, pylons = pylons, bossSpot = bossSpot, screen = screenText }
end

-- ============================================================ regions

-- Per-element scenery. Each returns after adding ~20 props inside `radius`.
-- Weather. Each region gets an ambient emitter over its whole area plus a
-- tinted fill light, so you can tell where you are from a distance and at a
-- glance: snow falling on the Peaks, embers rising over the Canyon, dust
-- drifting through the Outpost. One emitter per region, not one per prop.
local AMBIENCE: { [string]: { texture: string, rate: number, size: number, speed: NumberRange, lifetime: NumberRange, drag: number, spread: Vector2, up: boolean, transparency: number, light: number, fill: number? } } = {
	Wind = { texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 26, size = 1.1, speed = NumberRange.new(3, 8), lifetime = NumberRange.new(4, 7), drag = 0.6, spread = Vector2.new(35, 35), up = false, transparency = 0.55, light = 0.35 },
	Water = { texture = "rbxasset://textures/particles/smoke_main.dds", rate = 16, size = 7, speed = NumberRange.new(1, 3), lifetime = NumberRange.new(5, 9), drag = 1.2, spread = Vector2.new(20, 20), up = true, transparency = 0.88, light = 0.25 },
	Heat = { texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 34, size = 0.9, speed = NumberRange.new(5, 11), lifetime = NumberRange.new(3, 6), drag = 0.4, spread = Vector2.new(18, 18), up = true, transparency = 0.35, light = 0.6 },
	-- Frost was the densest, most opaque and most self-lit of the six, over a
	-- Snow-material floor that already bounces most of the light it gets. The
	-- snowfall now reads as weather rather than as a second light source.
	Frost = { texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 30, size = 0.85, speed = NumberRange.new(2, 5), lifetime = NumberRange.new(6, 10), drag = 1.6, spread = Vector2.new(25, 25), up = false, transparency = 0.58, light = 0.12, fill = 0.2 },
	Storm = { texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 20, size = 0.75, speed = NumberRange.new(4, 9), lifetime = NumberRange.new(2, 4), drag = 0.3, spread = Vector2.new(45, 45), up = true, transparency = 0.4, light = 0.5 },
	Cosmic = { texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 30, size = 1.0, speed = NumberRange.new(1, 4), lifetime = NumberRange.new(7, 12), drag = 0.8, spread = Vector2.new(60, 60), up = false, transparency = 0.25, light = 0.55 },
}

local function regionAmbience(parent: Instance, centre: Vector3, element: string, def: any, radius: number)
	local spec = AMBIENCE[element]
	if not spec then
		return
	end
	-- an invisible box the size of the region: the emitter fills its volume, so
	-- the effect follows the player around the area rather than sitting in one spot
	local volume = part({
		name = "Ambience",
		size = Vector3.new(radius * 1.9, 30, radius * 1.9),
		cf = CFrame.new(centre + Vector3.new(0, if spec.up then 6 else 26, 0)),
		transparency = 1,
		collide = false,
		query = false,
		parent = parent,
	})

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Weather"
	emitter.Texture = spec.texture
	emitter.Rate = spec.rate
	emitter.Lifetime = spec.lifetime
	emitter.Speed = spec.speed
	emitter.Drag = spec.drag
	emitter.SpreadAngle = spec.spread
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, spec.size * 0.4),
		NumberSequenceKeypoint.new(0.25, spec.size),
		NumberSequenceKeypoint.new(1, spec.size * 0.2),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, spec.transparency),
		NumberSequenceKeypoint.new(0.8, spec.transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(def.color)
	emitter.LightEmission = spec.light
	emitter.LightInfluence = 0.4
	emitter.EmissionDirection = if spec.up then Enum.NormalId.Top else Enum.NormalId.Bottom
	emitter.Acceleration = if spec.up then Vector3.new(1.5, 4, 0) else Vector3.new(2, -3, 0)
	emitter.Parent = volume

	-- a wide, dim fill light in the region's own colour ties the props together
	local fill = part({
		name = "RegionFill",
		size = Vector3.new(2, 2, 2),
		cf = CFrame.new(centre + Vector3.new(0, 26, 0)),
		transparency = 1,
		collide = false,
		query = false,
		parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = def.color
	light.Range = radius * 1.6
	light.Brightness = spec.fill or 0.55
	light.Shadows = false
	light.Parent = fill
end


-- The prop ring each scenery module lays down is a circle of radius 75 inside a
-- 280-wide cell, which leaves a wide band of bare ground either side of it.
-- These are the biome's own outcrops filling that band in three ranks all the
-- way out to the wall, so the cell reads as one place rather than a ring
-- dropped in an empty box.
local function buildShoulders(parent: Instance, def: any, centre: Vector3, radius: number)
	local group = Instance.new("Model")
	group.Name = "Shoulders"
	group.Parent = parent
	local element = def.element
	local material = if element == "Water" then Enum.Material.Sand
		elseif element == "Frost" then Enum.Material.Snow
		elseif element == "Heat" then Enum.Material.Sandstone
		elseif element == "Wind" then Enum.Material.Grass
		else Enum.Material.Slate
	local tint = def.groundColor:Lerp(rgb(118, 130, 112), 0.18)
	local wallX = CELL_W / 2
	local function blob(name: string, at: Vector3, size: Vector3, color: Color3, rounded: boolean): Part
		return part({ name = name, size = size, cf = CFrame.new(at), color = color, material = material,
			shape = if rounded then Enum.PartType.Ball else Enum.PartType.Block,
			collide = true, query = false, parent = group })
	end
	local function planting(at: Vector3, scale: number, seed: number)
		if element == "Frost" or element == "Wind" or element == "Water" then
			local snowy = element == "Frost"
			part({ name = "ShoulderTrunk", size = Vector3.new(1.5, 8, 1.5) * scale, cf = CFrame.new(at + Vector3.new(0, 4 * scale, 0)),
				color = rgb(94, 76, 59), material = Enum.Material.Wood, collide = true, query = false, parent = group })
			for tier = 1, 3 do
				local width = (11 - tier * 2) * scale
				part({ name = "ShoulderCanopy", size = Vector3.new(width, 6 * scale, width), cf = CFrame.new(at + Vector3.new(0, (5 + tier * 2.5) * scale, 0)),
					color = if snowy then rgb(178, 198, 209) else rgb(67 + tier * 10, 120 + tier * 12, 76 + tier * 5),
					material = if snowy then Enum.Material.Snow else Enum.Material.Grass,
					shape = Enum.PartType.Ball, collide = true, query = false, parent = group })
			end
		else
			-- Heat, Storm and Cosmic get standing rock rather than trees
			local rockCol = if element == "Heat" then rgb(178, 106, 74)
				elseif element == "Storm" then rgb(104, 108, 118) else rgb(122, 112, 140)
			local r = blob("ShoulderRock", at + Vector3.new(0, 4.4 * scale, 0), Vector3.new(9, 12, 8.4) * scale, rockCol, false)
			r.CFrame *= CFrame.Angles(0, seed * 0.7, math.rad(6))
		end
	end

	-- Five ranks down the cell, three columns out to the wall on each side.
	for _, side in { -1, 1 } do
		for i = 1, 5 do
			local z = centre.Z - CELL_D / 2 + 26 + (i - 1) * (CELL_D - 52) / 4
			local jog = ((i + (if side < 0 then 0 else 1)) % 3) - 1

			-- rank 1: the big biome mound just outside the prop ring
			local x1 = side * (radius + 13 + (i % 2) * 8)
			local at1 = Vector3.new(x1, 0, z)
			local height = 20 + (i % 3) * 7
			if element == "Water" or element == "Wind" then
				blob("Dune", at1 + Vector3.new(0, -4, 0), Vector3.new(46 + jog * 6, height * 0.7, 42), tint, true)
			elseif element == "Heat" then
				for tier = 1, 3 do
					local width = 38 - tier * 7
					blob("CanyonStratum", at1 + Vector3.new(0, (tier - 0.5) * height / 3 - 2, 0), Vector3.new(width, height / 3, width * 0.8),
						tint:Lerp(rgb(205, 139, 89), tier * 0.15), false)
				end
			else
				local ridge = blob("Ridge", at1 + Vector3.new(0, height * 0.2, 0), Vector3.new(28, height, 26), tint, false)
				ridge.CFrame *= CFrame.Angles(0, math.rad(i * 26 * side), math.rad(16 * side))
				if element == "Frost" then
					blob("SnowCap", at1 + Vector3.new(0, height * 0.66, 0), Vector3.new(24, 9, 23), rgb(200, 213, 222), true)
				elseif element == "Cosmic" then
					local shard = blob("FloatingShard", at1 + Vector3.new(0, height + 11, 0), Vector3.new(6, 11, 6), def.color, false)
					shard.CFrame *= CFrame.Angles(0.3, 0.6, 0.4)
					shard.CanCollide = false
				end
			end
			blob("BiomeShoulder", at1 + Vector3.new(side * -15, -2.4, 0), Vector3.new(25, 8, 24), def.groundColor, true)

			-- rank 2: lower ground between the mound and the wall
			local x2 = side * (radius + 40 + jog * 5)
			local h2 = 13 + (i % 2) * 5
			if element == "Heat" then
				blob("CanyonStep", Vector3.new(x2, h2 * 0.2, z + 4), Vector3.new(30, h2, 26), tint:Lerp(rgb(205, 139, 89), 0.28), false)
			else
				blob("ShoulderBank", Vector3.new(x2, -3, z + 4), Vector3.new(34, h2 + 8, 30), tint, true)
			end

			-- rank 3: planting hugging the wall, alternating with the ranks above
			planting(Vector3.new(side * (wallX - 9 - (i % 2) * 5), 0, z - 14), 0.8 + (i % 3) * 0.14, i * side)
			if i % 2 == 1 then
				planting(Vector3.new(side * (wallX - 22), 0, z + 16), 0.72 + (i % 2) * 0.16, i * side + 3)
			end
		end
	end
end

-- Where region i sits on the chain. The cells butt end to end running north
-- from the island edge, so the boundary between i and i+1 is a single wall.
local function regionCentre(index: number): Vector3
	return Vector3.new(0, 0, CHAIN_Z0 - (index - 0.5) * CELL_D)
end

local function regionSouthEdge(index: number): number
	return CHAIN_Z0 - (index - 1) * CELL_D
end

-- A gate pier as the concept draws it: cream block stone, a teal panel inset in
-- the face you approach, gold trim either side of it with a gold diamond, and a
-- warm amber lantern on the cap.
local function gatePier(parent: Instance, x: number, z: number, height: number)
	local south = z + 4.8
	part({ name = "GatePierBase", size = Vector3.new(10.6, 2.0, 10.6), cf = CFrame.new(x, 1.0, z), color = WALL_CAP, material = Enum.Material.Concrete, collide = true, parent = parent })
	part({ name = "GatePier", size = Vector3.new(9, height, 9), cf = CFrame.new(x, 2 + height / 2, z), color = WALL_PIER, material = Enum.Material.Concrete, collide = true, parent = parent })
	part({ name = "GatePierCap", size = Vector3.new(10.8, 1.5, 10.8), cf = CFrame.new(x, 2.75 + height, z), color = WALL_CAP, material = Enum.Material.Concrete, parent = parent })
	-- the teal face panel, its gold flanking trim and the diamond
	local panelH = height - 4
	part({ name = "GatePanel", size = Vector3.new(4.8, panelH, 0.7), cf = CFrame.new(x, 2 + height / 2, south), color = TEAL_PANEL, material = Enum.Material.Slate, parent = parent })
	for _, s in { -1, 1 } do
		part({ name = "GatePanelTrim", size = Vector3.new(1.1, panelH + 1.4, 0.8), cf = CFrame.new(x + s * 3.2, 2 + height / 2, south), color = GOLD, material = Enum.Material.Metal, parent = parent })
	end
	part({ name = "GateDiamond", size = Vector3.new(2.7, 2.7, 0.5), cf = CFrame.new(x, 2 + height * 0.42, south + 0.5) * CFrame.Angles(0, 0, math.rad(45)),
		color = GOLD, material = Enum.Material.Metal, parent = parent })
	-- amber lantern on the cap
	local lampY = 4.2 + height
	part({ name = "LanternBase", size = Vector3.new(5.4, 0.9, 5.4), cf = CFrame.new(x, lampY - 1.0, z), color = GOLD_DEEP, material = Enum.Material.Metal, parent = parent })
	local bulb = part({ name = "LanternBulb", size = Vector3.new(4.0, 3.6, 4.0), cf = CFrame.new(x, lampY + 1.0, z), color = rgb(255, 238, 196), material = Enum.Material.Neon, parent = parent })
	for _, s in { -1, 1 } do
		part({ name = "LanternPost", size = Vector3.new(0.7, 3.8, 0.7), cf = CFrame.new(x + s * 2.1, lampY + 1.0, z + 2.1), color = GOLD_DEEP, material = Enum.Material.Metal, parent = parent })
		part({ name = "LanternPost", size = Vector3.new(0.7, 3.8, 0.7), cf = CFrame.new(x + s * 2.1, lampY + 1.0, z - 2.1), color = GOLD_DEEP, material = Enum.Material.Metal, parent = parent })
	end
	part({ name = "LanternCap", size = Vector3.new(5.6, 1.1, 5.6), cf = CFrame.new(x, lampY + 3.3, z), color = GOLD_DEEP, material = Enum.Material.Metal, parent = parent })
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 226, 168)
	light.Range = 38
	light.Brightness = 1.1
	light.Parent = bulb
end

-- The enclosure: two lateral walls the length of the chain, a wall across the
-- north end, and a divider at every boundary but the town's, which the concept
-- leaves open. The gate piers and lintel belong to the divider; the barrier
-- that hangs between them belongs to the region, so it keeps its own colour,
-- prompt and tag.
local function buildChainWalls(parent: Instance)
	local walls = Instance.new("Model")
	walls.Name = "RegionWalls"
	walls.Parent = parent
	local half, gap = CELL_W / 2, GATE_W / 2
	local zEnd = CHAIN_Z0 - CHAIN_LEN
	for _, side in { -1, 1 } do
		wall(walls, Vector3.new(side * half, 0, CHAIN_Z0), Vector3.new(side * half, 0, zEnd), WALL_H)
	end
	wall(walls, Vector3.new(-half, 0, zEnd), Vector3.new(half, 0, zEnd), WALL_H, true, true)
	for index = 2, #Config.Regions.list do
		local z = regionSouthEdge(index)
		wall(walls, Vector3.new(-half, 0, z), Vector3.new(-gap, 0, z), WALL_H, true, true)
		wall(walls, Vector3.new(gap, 0, z), Vector3.new(half, 0, z), WALL_H, true, true)
		gatePier(walls, -gap, z, 19)
		gatePier(walls, gap, z, 19)
		-- A slim beam behind the banner carries it between the piers.
		part({ name = "BannerBeam", size = Vector3.new(GATE_W + 2, 1.1, 1.1), cf = CFrame.new(0, 25.6, z), color = GOLD_DEEP, material = Enum.Material.Metal, parent = walls })
	end

	-- The chain's south end is Gusty Gardens' open threshold: the same teal
	-- piers and a low wall either side of a gap, and no barrier at all.
	local zSouth = CHAIN_Z0
	wall(walls, Vector3.new(-half, 0, zSouth), Vector3.new(-gap, 0, zSouth), 6, true, true)
	wall(walls, Vector3.new(gap, 0, zSouth), Vector3.new(half, 0, zSouth), 6, true, true)
	gatePier(walls, -gap, zSouth, 13)
	gatePier(walls, gap, zSouth, 13)
	return walls
end

local function buildRegion(parent: Instance, def: any)
	local centre = regionCentre(def.index)
	local radius = 75
	local accessRadius = 78

	local model = Instance.new("Model")
	model.Name = def.id
	model:SetAttribute("RegionId", def.id)
	model:SetAttribute("Element", def.element)
	model:SetAttribute("Centre", centre)
	model:SetAttribute("AccessRadius", accessRadius)
	model:SetAttribute("AccessHalf", Vector3.new(CELL_W / 2, 0, CELL_D / 2))
	model.Parent = parent

	-- coloured ground patch
	-- each region's floor uses a material that matches what it is meant to be,
	-- which does more for how a place reads than its colour does
	local GROUND_MATERIAL: { [string]: Enum.Material } = {
		Wind = Enum.Material.Grass,
		Water = Enum.Material.Sand,
		-- the quarry floor is cut sandstone, not the old ravine's dark basalt
		Heat = Enum.Material.Sandstone,
		Frost = Enum.Material.Snow,
		Storm = Enum.Material.Asphalt,
		-- Orbit Outpost's floor is lunar soil, not station plating, and it is
		-- the only floor the region has: a raised skin would bury the Gravity
		-- Pulse telegraph, which is a 0.3-thick disc drawn 0.16 above the
		-- creature and so spans y 0.01 .. 0.31 against this disc's 0.30 top.
		Cosmic = Enum.Material.Sand,
	}
	-- The cell floor is the concept's rectangle. The scenery module still lays
	-- its props on a circle of `radius` inside it; the strips either side of that
	-- circle are the open shoulders the concept fills with trees beyond the wall.
	part({
		name = "Ground",
		size = Vector3.new(CELL_W, 1.4, CELL_D),
		cf = CFrame.new(centre.X, -0.4, centre.Z),
		color = def.groundColor,
		material = GROUND_MATERIAL[def.element] or Enum.Material.Ground,
		collide = true,
		parent = model,
	})
	local layout = require(script.Parent.RegionScenery).build(model, def, centre, radius, part)
	if not OWN_PERIMETER[def.element] then
		buildShoulders(model, def, centre, radius)
	end
	local field = if typeof(layout) == "table" then layout.field else nil
	local keepOut = if typeof(layout) == "table" then layout.keepOut else nil
	local spawnRadius = if field then math.min(field.X, field.Z) else SPAWN_RADIUS
	model:SetAttribute("SpawnRadius", spawnRadius)
	if field then
		model:SetAttribute("FieldHalf", field)
	end
	regionAmbience(model, centre, def.element, def, radius)

	local wild = Instance.new("Folder")
	wild.Name = "Wild"
	wild.Parent = model

	-- ---------------------------------------------------------------- gate
	-- The barrier hangs in the divider at this cell's south edge, facing the
	-- player walking up the chain.
	local gatePos = Vector3.new(0, 0, regionSouthEdge(def.index))
	local gateCF = CFrame.new(gatePos) * CFrame.Angles(0, math.rad(180), 0)
	local gate = part({
		name = "Gate",
		size = Vector3.new(GATE_W, 15, 1.4),
		cf = gateCF * CFrame.new(0, 8.5, 0),
		color = rgb(186, 230, 250),
		material = Enum.Material.Neon,
		transparency = 0.55,
		collide = true,
		parent = model,
	})
	gate:SetAttribute("RegionId", def.id)
	CollectionService:AddTag(gate, "RegionGate")
	-- The gold padlock the concept floats in the middle of a locked barrier.
	-- These are children of the barrier so Controllers.RegionGates fades them
	-- out with it when the region opens.
	if def.unlockCost > 0 then
		-- The concept's barrier is a pale pane inside a bright rail, crossed by
		-- two faint diagonals, with a gold lock medallion floating at its middle.
		-- All of it hangs off the barrier so Controllers.RegionGates fades the
		-- whole assembly when the region opens.
		local edge = def.color:Lerp(rgb(150, 236, 255), 0.55)
		for _, dy in { -7.2, 7.2 } do
			part({ name = "GateRail", size = Vector3.new(GATE_W + 1.2, 0.9, 1.8), cf = gateCF * CFrame.new(0, 8.5 + dy, 0),
				color = edge, material = Enum.Material.Neon, query = false, parent = gate })
		end
		for _, dx in { -GATE_W / 2, GATE_W / 2 } do
			part({ name = "GatePost", size = Vector3.new(1.1, 15.4, 1.8), cf = gateCF * CFrame.new(dx, 8.5, 0),
				color = edge, material = Enum.Material.Neon, query = false, parent = gate })
		end
		for _, tilt in { 1, -1 } do
			part({ name = "GateDiagonal", size = Vector3.new(math.sqrt(GATE_W * GATE_W + 225) - 2, 0.35, 0.5),
				cf = gateCF * CFrame.new(0, 8.5, -0.5) * CFrame.Angles(0, 0, tilt * math.atan2(15, GATE_W)),
				color = edge, material = Enum.Material.Neon, transparency = 0.5, query = false, parent = gate })
		end
		part({ name = "LockBadge", size = Vector3.new(0.9, 9.6, 9.6), cf = gateCF * CFrame.new(0, 8.5, -1.5) * CFrame.Angles(0, math.rad(90), 0),
			color = GOLD, material = Enum.Material.Neon, shape = Enum.PartType.Cylinder, query = false, parent = gate })
		part({ name = "LockRim", size = Vector3.new(0.7, 11.0, 11.0), cf = gateCF * CFrame.new(0, 8.5, -1.2) * CFrame.Angles(0, math.rad(90), 0),
			color = GOLD_DEEP, material = Enum.Material.Metal, shape = Enum.PartType.Cylinder, query = false, parent = gate })
		part({ name = "LockBody", size = Vector3.new(3.2, 2.8, 0.6), cf = gateCF * CFrame.new(0, 7.8, -2.2), color = rgb(252, 248, 238), query = false, parent = gate })
		part({ name = "LockShackle", size = Vector3.new(2.0, 2.0, 0.55), cf = gateCF * CFrame.new(0, 9.9, -2.2), color = rgb(252, 248, 238), query = false, parent = gate })
		part({ name = "LockKeyhole", size = Vector3.new(0.8, 1.1, 0.4), cf = gateCF * CFrame.new(0, 7.7, -2.6), color = GOLD_DEEP, query = false, parent = gate })
	else
		-- Gusty Gardens opens straight off the town: no wall, no barrier.
		gate.Transparency = 1
		gate.CanCollide = false
	end
	if def.unlockCost > 0 then
		local unlockPrompt = Instance.new("ProximityPrompt")
		unlockPrompt.Name = "UnlockPrompt"
		unlockPrompt.ActionText = "Unlock"
		unlockPrompt.ObjectText = def.name .. "  " .. Format.abbreviate(def.unlockCost) .. " Coins"
		unlockPrompt.KeyboardKeyCode = Enum.KeyCode.E
		unlockPrompt.HoldDuration = 0
		unlockPrompt.RequiresLineOfSight = false
		unlockPrompt.MaxActivationDistance = 16
		unlockPrompt.Parent = gate
	end
	-- gate frame. Every element except Heat builds its own entrance in its
	-- scenery module -- a harbour, a trellis, a timber expedition arch, a steel
	-- portal, a pair of research pillars -- and the industrial posts and hazard
	-- strip would read as a second gate there. Storm's portal replaces this trim
	-- outright: its piers stand at x +/-13 where these posts sat at +/-11, and
	-- its header carries the same lintel line 3.4 studs higher. Cosmic's pillars
	-- stand at the same +/-13 and carry no lintel at all, which is the concept.
	-- The divider wall now supplies the piers and lintel for every gate, so the
	-- industrial trim Heat used to grow for itself would read as a second frame.

	-- The destination sign is a banner over the opening, which is where the
	-- region concepts put it. It is still the part named GateSign carrying a Gui
	-- with Title / Cost / Forecast, which is the whole contract
	-- Controllers.RegionGates relies on, so the live rows keep working.
	--
	-- RegionSign still builds the older freestanding board and is one flag away
	-- if it is wanted back; the concepts do not show one beside the gate.
	local signCF = gateCF * CFrame.new(0, 26.5, 0)
	local signHost = part({ name = "GateSign", size = Vector3.new(30, 13, 0.9), cf = signCF, color = NAVY, collide = true, parent = model })
	-- a gold frame and a diamond finial, as drawn
	for _, spec in { { 31.4, 1.0, 0, 6.5 }, { 31.4, 1.0, 0, -6.5 }, { 1.0, 14.4, 15.2, 0 }, { 1.0, 14.4, -15.2, 0 } } do
		part({ name = "SignFrame", size = Vector3.new(spec[1], spec[2], 1.3), cf = signCF * CFrame.new(spec[3], spec[4], 0),
			color = GOLD, material = Enum.Material.Metal, parent = model })
	end
	part({ name = "SignFinial", size = Vector3.new(2.6, 2.6, 0.9), cf = signCF * CFrame.new(0, 7.6, 0) * CFrame.Angles(0, 0, math.rad(45)),
		color = GOLD, material = Enum.Material.Metal, parent = model })
	local gui = surface(signHost, Enum.NormalId.Front, 26)
	-- The two tiers are drawn in the Gui so the plaque reads as one surface with
	-- the banner rather than a second board floating in front of it.
	local topPanel = Instance.new("Frame")
	topPanel.Name = "TopPanel"
	topPanel.Size = UDim2.fromScale(0.96, 0.52)
	topPanel.Position = UDim2.fromScale(0.02, 0.03)
	topPanel.BackgroundColor3 = NAVY
	topPanel.BorderSizePixel = 0
	topPanel.Parent = gui
	local plaque = Instance.new("Frame")
	plaque.Name = "Plaque"
	plaque.Size = UDim2.fromScale(0.74, 0.36)
	plaque.Position = UDim2.fromScale(0.13, 0.58)
	plaque.BackgroundColor3 = BRONZE
	plaque.BorderSizePixel = 0
	plaque.Parent = gui
	for _, frame in { topPanel, plaque } do
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color = GOLD
		stroke.Thickness = 4
		stroke.Parent = frame
	end
	local elementLabel = label(gui, "Element", string.upper(def.element), UDim2.fromScale(0.3, 0.1), UDim2.fromScale(0.02, 0.9), def.color)
	elementLabel.TextTransparency = 0.45
	local title = label(topPanel, "Title", string.upper(def.name), UDim2.fromScale(0.92, 0.66), UDim2.fromScale(0.04, 0.16), rgb(255, 253, 246))
	local costText = if def.unlockCost <= 0 then "OPEN" else Format.abbreviate(def.unlockCost) .. " COINS"
	local cost = label(plaque, "Cost", costText, UDim2.fromScale(0.92, 0.6), UDim2.fromScale(0.04, 0.1), rgb(255, 238, 198))
	local forecast = label(gui, "Forecast", "Legendary forecast: --", UDim2.fromScale(0.9, 0.09), UDim2.fromScale(0.05, 0.905), rgb(206, 232, 255))
	forecast.TextWrapped = true
	if BOARD_HIERARCHY[def.element] then
		forecast.RichText = true
	end

	local entrance = part({ name = "Entrance", size = Vector3.new(6, 1, 6), cf = gateCF * CFrame.new(0, 0.5, 14), transparency = 1, collide = false, query = false, parent = model })

	-- A paved trail straight up the axis, kerbed in this region's own colour.
	-- The concept paves the chain in the same pale stone as the town; the
	-- chevron roadbed the hub uses read as a runway at this length.
	local zMid = regionSouthEdge(def.index) - CELL_D / 2 + 1.5
	if TRAIL_DIRT[def.element] then
		-- trodden earth, and the region module scatters its flat stones on top
		local trail = slab(model, "Trail", 0, zMid, 24, CELL_D + 3, 0.42, DIRT)
		trail.Material = Enum.Material.Ground
	elseif TRAIL_BLEND[def.element] then
		-- Tropical Tidepools shows firmer pale sand down the middle of the bay
		-- and Cinder Quarry shows bare quarry floor; both are the ground either
		-- side of them, only walked flatter.
		local blend = TRAIL_BLEND[def.element]
		local trail = slab(model, "Trail", 0, zMid, blend.width, CELL_D + 3, 0.42, blend.color)
		trail.Material = blend.material
	else
		slab(model, "Trail", 0, zMid, 18, CELL_D + 3, 0.42)
		for _, side in { -1, 1 } do
			slab(model, "TrailKerb", side * 9.4, zMid, 1.8, CELL_D + 3, 0.46, def.color)
		end
	end
	lamp(model, gatePos + Vector3.new(GATE_W / 2 + 12, 0, -9), def.color)
	lamp(model, gatePos + Vector3.new(-(GATE_W / 2 + 12), 0, -9), def.color)

	return {
		model = model,
		centre = centre,
		spawnRadius = spawnRadius,
		accessRadius = accessRadius,
		fieldHalf = field,
		keepOut = keepOut,
		accessHalf = Vector3.new(CELL_W / 2, 0, CELL_D / 2),
		gate = gate,
		gateSign = { title = title, cost = cost, forecast = forecast },
		entrance = entrance,
		wild = wild,
	}
end

-- Trees and boulders rim the island and flank the chain, so the ground reads as
-- an edge rather than running off flat -- which is how the concept board frames
-- both. Fixed placement keeps the gameplay random sequence untouched.
local function buildLandscape(parent: Instance)
	local scenery = Instance.new("Folder")
	scenery.Name = "Landscape"
	scenery.Parent = parent
	local function rock(host: Instance, name: string, pos: Vector3, size: Vector3, color: Color3, material: Enum.Material, rounded: boolean?): Part
		return part({ name = name, size = size, cf = CFrame.new(pos), color = color,
			material = material, shape = if rounded then Enum.PartType.Ball else Enum.PartType.Block,
			collide = true, query = false, parent = host })
	end
	local function tree(host: Instance, pos: Vector3, scale: number, snowy: boolean)
		rock(host, "Trunk", pos + Vector3.new(0, 4 * scale, 0), Vector3.new(1.6, 8, 1.6) * scale, rgb(94, 76, 59), Enum.Material.Wood)
		for tier = 1, 3 do
			local width = (12 - tier * 2) * scale
			local color = if snowy then rgb(178, 198, 209) else rgb(67 + tier * 10, 120 + tier * 12, 76 + tier * 5)
			local material = if snowy then Enum.Material.Snow else Enum.Material.Grass
			rock(host, "Canopy", pos + Vector3.new(0, (5 + tier * 2.5) * scale, 0), Vector3.new(width, 6 * scale, width), color, material, true)
		end
	end

	-- island rim, both trunk mouths left clear
	local rim = Instance.new("Folder")
	rim.Name = "IslandRim"
	rim.Parent = scenery
	for i = 1, 54 do
		local a = (i / 54) * 360
		local at = polar(ISLAND_R - 7 - (i % 3) * 4, a)
		if math.abs(at.X) > TRUNK_W then
			if i % 4 == 0 then
				rock(rim, "ShoreRock", at + Vector3.new(0, 1.2, 0), Vector3.new(9 + (i % 3) * 3, 8, 8.4), rgb(138, 140, 148), Enum.Material.Rock, true)
			else
				tree(rim, at, 0.85 + (i % 4) * 0.12, false)
			end
		end
	end

	-- the treeline outside both chain walls
	local flanks = Instance.new("Folder")
	flanks.Name = "ChainFlanks"
	flanks.Parent = scenery
	local ownFlank: { { number } } = {}
	for _, def in Config.Regions.list do
		if OWN_FLANK[def.element] then
			local c = regionCentre(def.index).Z
			table.insert(ownFlank, { c - CELL_D / 2, c + CELL_D / 2 })
		end
	end
	local rows = math.floor(CHAIN_LEN / 26)
	for i = 0, rows do
		local z = CHAIN_Z0 - i * (CHAIN_LEN / rows)
		local skip = false
		for _, span in ownFlank do
			skip = skip or (z >= span[1] and z <= span[2])
		end
		for _, side in (if skip then {} else { -1, 1 }) do
			local x = side * (CELL_W / 2 + 11 + (i % 3) * 8)
			if (i + (if side < 0 then 0 else 2)) % 5 == 0 then
				rock(flanks, "RidgeRock", Vector3.new(x + side * 11, 1.5, z), Vector3.new(13, 11, 12), rgb(132, 134, 142), Enum.Material.Rock, true)
			else
				tree(flanks, Vector3.new(x, 0, z), 0.85 + (i % 4) * 0.14, false)
			end
		end
	end
end

-- ============================================================ build

function MapBuilder.build()
	local staging, storage = require(script.Parent.ImportStaging), game:GetService("ServerStorage")
	staging.move(workspace, storage)
	staging.quarantine(workspace, storage)
	partCount = 0

	local map = Instance.new("Model")
	map.Name = "Map"
	map.Parent = workspace

	-- The world is the round island plus the strip the chain sits on, which
	-- together give the concept board's silhouette. The island disc itself is
	-- laid by buildHub; this is the ground under the regions and the causeway
	-- south to the arena.
	part({ name = "Ground", size = Vector3.new(STRIP_W, 6, CHAIN_LEN + 24), cf = CFrame.new(0, -3, CHAIN_Z0 - CHAIN_LEN / 2 + 12),
		color = GRASS_C, material = Enum.Material.Grass, collide = true, parent = map })
	-- The strip is a rectangle and the island a circle; butted together they met
	-- on a corner that read as a seam from above. This disc rounds the junction.
	disc(map, "ChainApron", Vector3.new(0, 0.03, CHAIN_Z0 + 30), STRIP_W / 2, 6, GRASS_C, Enum.Material.Grass)
	part({ name = "Causeway", size = Vector3.new(30, 6, 56), cf = CFrame.new(0, -3, ISLAND_R + 18),
		color = GRASS_C, material = Enum.Material.Grass, collide = true, parent = map })

	local hub = buildHub(map)

	-- The Containment Crisis arena keeps its own islet south of the town, which
	-- is where the crisis copy sends players, and off the concept's north view.
	disc(map, "ArenaIslet", ARENA_CENTRE + Vector3.new(0, 0.04, 0), 62, 6, GRASS_C, Enum.Material.Grass)
	local arena = buildArena(map, ARENA_CENTRE)
	strip(map, "ArenaCauseway", Vector3.new(0, 0, ISLAND_R - 6), ARENA_CENTRE - Vector3.new(0, 0, 44), 14, 0.3, PAVER)

	buildChainWalls(map)

	local regionsFolder = Instance.new("Folder")
	regionsFolder.Name = "Regions"
	regionsFolder.Parent = workspace

	local regions: { [string]: any } = {}
	for _, def in Config.Regions.list do
		local ok, result = pcall(buildRegion, regionsFolder, def)
		if ok then
			regions[def.id] = result
		else
			warn("[MapBuilder] region failed:", def.id, result)
		end
	end

	-- plot ring: six CFrames whose front (local -Z) looks at the fountain, each
	-- on its own connector from the promenade to its front gate
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace
	local plots: { [number]: CFrame } = {}
	for i = 1, Config.MaxPlayers do
		local a = plotAngle(i)
		local pos = polar(PLOT_R, a)
		plots[i] = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
		strip(map, "PlotConnector", polar(RING_OUT - 2, a), polar(PLOT_R - PLOT_HALF, a), CONNECTOR_W, 0.26)
	end

	buildLandscape(map)

	local effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = workspace

	print(("[%s] map built: %d parts"):format(Config.GameName, partCount))

	return {
		spawn = hub.spawn,
		plots = plots,
		regions = regions,
		hub = { workshop = hub.workshop, beacon = hub.beacon, atlas = hub.atlas, board = hub.board },
		arena = arena,
		partCount = partCount,
	}
end

return MapBuilder
