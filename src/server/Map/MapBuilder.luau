--!strict
-- Builds the whole world at runtime: the hub plaza (spawn, Upgrade Workshop,
-- Relaunch Beacon, Atlas kiosk, company board), the Containment Crisis arena,
-- and the six wild regions with their gates.
--
-- Player plots are NOT built here; CityService builds them from `refs.plots`
-- using Map.PlotTemplate.
--
-- Layout, in studs, ground top surface at y = 0:
--   Hub plaza      radius 70 around the origin
--   Arena          radius 30 centred (0, 0, -105)
--   Plot ring      radius 140, one every 45 degrees from 22.5
--   Regions        radius 280, one every 60 degrees from 90
--   Region gates   radius 200 on the region's own angle

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

	-- edge lines in the destination's colour
	for _, side in { -1, 1 } do
		part({
			name = "PathEdge",
			size = Vector3.new(0.75, 0.12, length),
			cf = base * CFrame.new(side * (width / 2 - 0.5), 0.2, 0),
			color = trim,
			material = Enum.Material.SmoothPlastic,
			parent = parent,
		})
	end

	-- chevrons pointing at the destination
	local count = math.clamp(math.floor(length / CHEVRON_SPACING), 1, CHEVRON_MAX)
	local step = length / (count + 1)
	local arm = width * 0.52
	for i = 1, count do
		local along = -length / 2 + step * i
		for _, side in { -1, 1 } do
			part({
				name = "PathChevron",
				size = Vector3.new(2.1, 0.16, arm),
				-- each half of the ">" is rotated in from the centre line
				cf = base * CFrame.new(side * arm * 0.32, 0.21, along) * CFrame.Angles(0, side * math.rad(38), 0),
				color = rgb(210, 125, 12),
				material = Enum.Material.SmoothPlastic,
				parent = parent,
			})
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

-- ============================================================ hub

local function buildHub(parent: Instance)
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	hub.Parent = parent

	-- Floors sit slightly proud of the ground. A floor whose top face is exactly
	-- at y = 0, like the ground's, z-fights with it: the two surfaces flicker
	-- against each other, which showed up as a shimmering circle across the
	-- plaza. Every stacked layer below keeps a similar gap for the same reason.
	disc(hub, "Plaza", Vector3.new(0, 0.06, 0), 70, 1, CONCRETE, Enum.Material.Concrete)
	disc(hub, "PlazaInner", Vector3.new(0, 0.15, 0), 30, 1, rgb(206, 202, 210), Enum.Material.Concrete)
	-- company logo ring in the middle
	for i = 1, 24 do
		local a = (i / 24) * 360
		part({
			name = "LogoTile",
			size = Vector3.new(3.2, 0.16, 1.6),
			cf = CFrame.new(polar(16, a, 0.32)) * CFrame.Angles(0, math.rad(-a), 0),
			color = if i % 2 == 0 then rgb(150, 157, 166) else rgb(105, 114, 126),
			parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.5, -20)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Color = rgb(120, 220, 160)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.35
	spawn.Parent = hub

	-- ---------------------------------------------------------------- workshop
	local workshopPos = Vector3.new(-42, 0, 22)
	local workshop = Instance.new("Model")
	workshop.Name = "Workshop"
	workshop.Parent = hub
	part({ name = "Floor", size = Vector3.new(26, 1, 20), cf = CFrame.new(workshopPos + Vector3.new(0, 0.5, 0)), color = DECK, collide = true, parent = workshop })
	part({ name = "Wall", size = Vector3.new(26, 12, 1), cf = CFrame.new(workshopPos + Vector3.new(0, 6.5, 9.5)), color = rgb(96, 132, 168), collide = true, parent = workshop })
	part({ name = "WallL", size = Vector3.new(1, 12, 20), cf = CFrame.new(workshopPos + Vector3.new(-12.5, 6.5, 0)), color = rgb(96, 132, 168), collide = true, parent = workshop })
	part({ name = "WallR", size = Vector3.new(1, 12, 20), cf = CFrame.new(workshopPos + Vector3.new(12.5, 6.5, 0)), color = rgb(96, 132, 168), collide = true, parent = workshop })
	part({ name = "Roof", size = Vector3.new(28, 1, 22), cf = CFrame.new(workshopPos + Vector3.new(0, 13, 0)), color = HAZARD, parent = workshop })
	hazardStrip(workshop, CFrame.new(workshopPos + Vector3.new(0, 12.2, -11.1)), 26, 1.2, 0.2)
	-- big spanner and gear on the front wall
	local gearCentre = workshopPos + Vector3.new(-7, 7.5, -9.5)
	part({ name = "Gear", size = Vector3.new(0.6, 6, 6), cf = CFrame.new(gearCentre) * CFrame.Angles(0, math.rad(90), 0), color = STEEL, shape = Enum.PartType.Cylinder, parent = workshop })
	for i = 1, 8 do
		local a = math.rad((i / 8) * 360)
		-- teeth ring in the wall plane (XY), not the ground plane
		part({ name = "Tooth", size = Vector3.new(1.4, 1.4, 0.7), cf = CFrame.new(gearCentre + Vector3.new(math.cos(a) * 3.4, math.sin(a) * 3.4, 0)) * CFrame.Angles(0, 0, a), color = STEEL, parent = workshop })
	end
	local sign = part({ name = "Sign", size = Vector3.new(14, 3.4, 0.4), cf = CFrame.new(workshopPos + Vector3.new(0, 15.2, -8)), color = INK, parent = workshop })
	label(surface(sign, Enum.NormalId.Front, 24), "Text", "UPGRADE WORKSHOP", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), HAZARD)
	local workshopTerminal = part({ name = "Terminal", size = Vector3.new(4, 4.5, 2.4), cf = CFrame.new(workshopPos + Vector3.new(0, 2.8, -7)), color = rgb(58, 62, 82), collide = true, parent = workshop })
	workshopTerminal:SetAttribute("OpensPanel", "Workshop")
	label(surface(workshopTerminal, Enum.NormalId.Front, 22), "Text", "UPGRADES", UDim2.fromScale(1, 0.6), UDim2.fromScale(0, 0.2), rgb(190, 245, 255))

	-- ---------------------------------------------------------------- beacon
	local beaconPos = Vector3.new(42, 0, 22)
	local beacon = Instance.new("Model")
	beacon.Name = "Beacon"
	beacon.Parent = hub
	disc(beacon, "Base", beaconPos + Vector3.new(0, 0.14, 0), 12, 1.2, DECK, Enum.Material.Concrete)
	for i = 1, 3 do
		part({ name = "Buttress", size = Vector3.new(1.6, 14, 1.6), cf = CFrame.new(beaconPos + polar(5, i * 120, 7)) * CFrame.Angles(0, math.rad(-i * 120), 0), color = DECK, collide = true, parent = beacon })
	end
	part({ name = "Column", size = Vector3.new(26, 5, 5), cf = CFrame.new(beaconPos + Vector3.new(0, 13, 0)) * CFrame.Angles(0, 0, math.rad(90)), color = STEEL, shape = Enum.PartType.Cylinder, collide = true, parent = beacon })
	for i = 1, 5 do
		part({ name = "Band", size = Vector3.new(0.8, 5.6, 5.6), cf = CFrame.new(beaconPos + Vector3.new(0, 4 + (i - 1) * 5, 0)) * CFrame.Angles(0, 0, math.rad(90)), color = if i % 2 == 0 then HAZARD else INK, shape = Enum.PartType.Cylinder, parent = beacon })
	end
	local crown = part({ name = "Crown", size = Vector3.new(7, 7, 7), cf = CFrame.new(beaconPos + Vector3.new(0, 28, 0)), color = rgb(120, 235, 255), material = Enum.Material.Neon, shape = Enum.PartType.Ball, parent = beacon })
	local cl = Instance.new("PointLight")
	cl.Color = rgb(140, 235, 255)
	cl.Range = 60
	cl.Brightness = 2
	cl.Parent = crown
	local beaconSign = part({ name = "Sign", size = Vector3.new(13, 3.2, 0.4), cf = CFrame.new(beaconPos + Vector3.new(0, 34, -0.5)), color = INK, parent = beacon })
	label(surface(beaconSign, Enum.NormalId.Front, 24), "Text", "CITY RELAUNCH", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), rgb(140, 235, 255))
	local beaconTerminal = part({ name = "Terminal", size = Vector3.new(4, 4.5, 2.4), cf = CFrame.new(beaconPos + Vector3.new(0, 3.4, -8)), color = rgb(58, 62, 82), collide = true, parent = beacon })
	beaconTerminal:SetAttribute("OpensPanel", "Relaunch")
	label(surface(beaconTerminal, Enum.NormalId.Front, 22), "Text", "RELAUNCH", UDim2.fromScale(1, 0.6), UDim2.fromScale(0, 0.2), rgb(190, 245, 255))

	-- ---------------------------------------------------------------- atlas kiosk
	local atlasPos = Vector3.new(0, 0, 48)
	local kiosk = Instance.new("Model")
	kiosk.Name = "AtlasKiosk"
	kiosk.Parent = hub
	disc(kiosk, "Base", atlasPos + Vector3.new(0, 0.14, 0), 9, 1.2, DECK, Enum.Material.Concrete)
	part({ name = "Post", size = Vector3.new(1.4, 8, 1.4), cf = CFrame.new(atlasPos + Vector3.new(0, 4, 0)), color = DECK, collide = true, parent = kiosk })
	part({ name = "Canopy", size = Vector3.new(12, 0.8, 8), cf = CFrame.new(atlasPos + Vector3.new(0, 8.4, 0)), color = rgb(120, 220, 150), parent = kiosk })
	local atlasTerminal = part({ name = "Terminal", size = Vector3.new(5, 4.5, 2.2), cf = CFrame.new(atlasPos + Vector3.new(0, 3, -3)), color = rgb(58, 62, 82), collide = true, parent = kiosk })
	atlasTerminal:SetAttribute("OpensPanel", "Atlas")
	label(surface(atlasTerminal, Enum.NormalId.Front, 22), "Text", "CATASTROPHE ATLAS", UDim2.fromScale(1, 0.7), UDim2.fromScale(0, 0.15), rgb(190, 245, 255))

	-- ---------------------------------------------------------------- company board
	local boardPos = Vector3.new(0, 8, 62)
	part({ name = "BoardPostL", size = Vector3.new(0.8, 9, 0.8), cf = CFrame.new(-8, 4.5, 62), color = DECK, collide = true, parent = hub })
	part({ name = "BoardPostR", size = Vector3.new(0.8, 9, 0.8), cf = CFrame.new(8, 4.5, 62), color = DECK, collide = true, parent = hub })
	local board = part({ name = "Board", size = Vector3.new(20, 9, 1), cf = CFrame.new(boardPos) * CFrame.Angles(0, math.rad(180), 0), color = rgb(52, 58, 78), parent = hub })
	local boardText = label(surface(board, Enum.NormalId.Front, 20), "Text", Config.CompanyName, UDim2.fromScale(0.96, 0.9), UDim2.fromScale(0.02, 0.05), rgb(255, 252, 245))
	boardText.TextScaled = false
	boardText.TextSize = 26
	boardText.TextWrapped = true
	boardText.TextXAlignment = Enum.TextXAlignment.Left
	boardText.TextYAlignment = Enum.TextYAlignment.Top

	-- lamps and paths around the plaza
	for i = 1, 8 do
		lamp(hub, polar(64, 22.5 + (i - 1) * 45))
	end
	-- start outside the logo ring: four paths meeting at the exact centre would
	-- overlap each other there
	local function spoke(target: Vector3, width: number, accent: Color3?)
		local dir = target.Unit
		path(hub, dir * 20, target, width, accent)
	end
	spoke(workshopPos, 8, HAZARD)
	spoke(beaconPos, 8, rgb(120, 235, 255))
	spoke(atlasPos, 8, rgb(120, 220, 150))
	-- the route south leads to the crisis arena
	spoke(Vector3.new(0, 0, -70), 10, rgb(255, 120, 100))

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

local function buildArena(parent: Instance)
	local centre = Vector3.new(0, 0, -105)
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
	part({ name = "Stage", size = Vector3.new(40, 2, 16), cf = CFrame.new(0, 1, -128), color = DECK, collide = true, parent = arena })
	hazardStrip(arena, CFrame.new(0, 1.4, -120.1), 40, 1.4, 0.2)

	local bossSpot = part({ name = "BossSpot", size = Vector3.new(2, 1, 2), cf = CFrame.new(centre + Vector3.new(0, 0.5, 0)), transparency = 1, collide = false, query = false, parent = arena })

	-- screen
	part({ name = "ScreenPostL", size = Vector3.new(1, 13, 1), cf = CFrame.new(-8, 6.5, -134), color = DECK, collide = true, parent = arena })
	part({ name = "ScreenPostR", size = Vector3.new(1, 13, 1), cf = CFrame.new(8, 6.5, -134), color = DECK, collide = true, parent = arena })
	local screen = part({ name = "Screen", size = Vector3.new(18, 8, 1), cf = CFrame.new(0, 12, -134), color = rgb(40, 44, 62), parent = arena })
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

	path(arena, Vector3.new(0, 0, -70), centre, 10, rgb(255, 120, 100))
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
local AMBIENCE: { [string]: { texture: string, rate: number, size: number, speed: NumberRange, lifetime: NumberRange, drag: number, spread: Vector2, up: boolean, transparency: number, light: number } } = {
	Wind = { texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 26, size = 1.1, speed = NumberRange.new(3, 8), lifetime = NumberRange.new(4, 7), drag = 0.6, spread = Vector2.new(35, 35), up = false, transparency = 0.55, light = 0.35 },
	Water = { texture = "rbxasset://textures/particles/smoke_main.dds", rate = 16, size = 7, speed = NumberRange.new(1, 3), lifetime = NumberRange.new(5, 9), drag = 1.2, spread = Vector2.new(20, 20), up = true, transparency = 0.88, light = 0.25 },
	Heat = { texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 34, size = 0.9, speed = NumberRange.new(5, 11), lifetime = NumberRange.new(3, 6), drag = 0.4, spread = Vector2.new(18, 18), up = true, transparency = 0.35, light = 0.6 },
	Frost = { texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 46, size = 0.85, speed = NumberRange.new(2, 5), lifetime = NumberRange.new(6, 10), drag = 1.6, spread = Vector2.new(25, 25), up = false, transparency = 0.3, light = 0.4 },
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
	light.Brightness = 0.55
	light.Shadows = false
	light.Parent = fill
end

local function regionProps(parent: Instance, centre: Vector3, element: string, def: any, radius: number)
	local c = def.color
	local rand = Random.new(def.index * 7919)
	local function spot(minR: number, maxR: number): Vector3
		return centre + polar(rand:NextNumber(minR, maxR), rand:NextNumber(0, 360))
	end

	if element == "Wind" then
		for i = 1, 10 do
			local p = spot(12, radius - 8)
			for j = 1, 4 do
				part({ name = "Grass", size = Vector3.new(0.4, rand:NextNumber(3, 6), 0.4), cf = CFrame.new(p + Vector3.new(j * 0.5, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(rand:NextNumber(-16, 16))), color = rgb(120, 200, 110), material = Enum.Material.Grass, parent = parent })
			end
		end
		-- a big skeletal windmill
		local wm = spot(20, 30)
		part({ name = "MillTower", size = Vector3.new(3, 22, 3), cf = CFrame.new(wm + Vector3.new(0, 11, 0)), color = rgb(220, 216, 206), collide = true, parent = parent })
		part({ name = "MillCap", size = Vector3.new(5, 4, 5), cf = CFrame.new(wm + Vector3.new(0, 23, 0)), color = c, shape = Enum.PartType.Ball, parent = parent })
		for i = 1, 4 do
			part({ name = "MillBlade", size = Vector3.new(1.2, 12, 0.4), cf = CFrame.new(wm + Vector3.new(0, 23, -3)) * CFrame.Angles(0, 0, math.rad(i * 90)) * CFrame.new(0, 6, 0), color = rgb(250, 250, 252), parent = parent })
		end
		for i = 1, 6 do
			local p = spot(14, radius - 10)
			part({ name = "Bush", size = Vector3.new(4, 3, 4), cf = CFrame.new(p + Vector3.new(0, 1.5, 0)), color = rgb(110, 180, 100), material = Enum.Material.LeafyGrass, shape = Enum.PartType.Ball, parent = parent })
		end
	elseif element == "Water" then
		for i = 1, 7 do
			local p = spot(12, radius - 10)
			local r = rand:NextNumber(6, 14)
			disc(parent, "Pool", p + Vector3.new(0, 0.46, 0), r, 0.4, c, Enum.Material.Glass)
			part({ name = "PoolRim", size = Vector3.new(0.5, r * 2 + 1.6, r * 2 + 1.6), cf = CFrame.new(p + Vector3.new(0, 0.38, 0)) * CFrame.Angles(0, 0, math.rad(90)), color = rgb(214, 196, 150), shape = Enum.PartType.Cylinder, parent = parent })
		end
		for i = 1, 8 do
			local p = spot(14, radius - 8)
			part({ name = "Rock", size = Vector3.new(rand:NextNumber(2, 5), rand:NextNumber(2, 4), rand:NextNumber(2, 5)), cf = CFrame.new(p + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, rand:NextNumber(0, 6), 0), color = rgb(150, 148, 140), material = Enum.Material.Slate, collide = true, parent = parent })
		end
		-- a small dock
		local d = centre + polar(26, 200)
		part({ name = "Dock", size = Vector3.new(6, 0.7, 20), cf = CFrame.new(d + Vector3.new(0, 1.2, 0)), color = rgb(168, 124, 78), material = Enum.Material.WoodPlanks, collide = true, parent = parent })
		for i = 1, 4 do
			part({ name = "Piling", size = Vector3.new(0.9, 3.4, 0.9), cf = CFrame.new(d + Vector3.new(2.2, 0.6, -7 + (i - 1) * 5)), color = rgb(120, 88, 56), material = Enum.Material.Wood, collide = true, parent = parent })
		end
	elseif element == "Heat" then
		for i = 1, 9 do
			local p = spot(12, radius - 8)
			part({ name = "Rock", size = Vector3.new(rand:NextNumber(4, 9), rand:NextNumber(4, 11), rand:NextNumber(4, 9)), cf = CFrame.new(p + Vector3.new(0, 3, 0)) * CFrame.Angles(0, rand:NextNumber(0, 6), 0), color = rgb(138, 78, 60), material = Enum.Material.Rock, collide = true, parent = parent })
		end
		for i = 1, 10 do
			local p = spot(10, radius - 6)
			local crack = part({ name = "Crack", size = Vector3.new(rand:NextNumber(3, 9), 0.2, rand:NextNumber(0.6, 1.6)), cf = CFrame.new(p + Vector3.new(0, 0.16, 0)) * CFrame.Angles(0, rand:NextNumber(0, 6), 0), color = rgb(255, 120, 50), material = Enum.Material.Neon, parent = parent })
			local pl = Instance.new("PointLight")
			pl.Color = rgb(255, 130, 60)
			pl.Range = 16
			pl.Brightness = 0.7
			pl.Parent = crack
		end
		-- a smoking vent
		local v = centre + polar(24, 140)
		part({ name = "VentCone", size = Vector3.new(7, 9, 9), cf = CFrame.new(v + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), color = rgb(96, 58, 46), shape = Enum.PartType.Cylinder, collide = true, parent = parent })
		local mouth = part({ name = "VentMouth", size = Vector3.new(0.4, 4.4, 4.4), cf = CFrame.new(v + Vector3.new(0, 7.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color = rgb(255, 130, 50), material = Enum.Material.Neon, shape = Enum.PartType.Cylinder, parent = parent })
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Rate = 14
		emitter.Lifetime = NumberRange.new(2, 3.5)
		emitter.Speed = NumberRange.new(6, 10)
		emitter.Size = NumberSequence.new(6)
		emitter.Transparency = NumberSequence.new(0.6)
		emitter.Color = ColorSequence.new(rgb(90, 80, 76))
		emitter.Parent = mouth
	elseif element == "Frost" then
		for i = 1, 10 do
			local p = spot(12, radius - 8)
			part({ name = "SnowMound", size = Vector3.new(rand:NextNumber(6, 12), rand:NextNumber(2, 5), rand:NextNumber(6, 12)), cf = CFrame.new(p + Vector3.new(0, 1.2, 0)), color = rgb(240, 246, 252), material = Enum.Material.Snow, shape = Enum.PartType.Ball, collide = true, parent = parent })
		end
		for i = 1, 4 do
			local p = spot(16, radius - 12)
			-- an ice arch
			for j = 1, 5 do
				local a = math.rad(20 + (j - 1) * 35)
				part({ name = "ArchBlock", size = Vector3.new(3.2, 3, 3), cf = CFrame.new(p + Vector3.new(-math.cos(a) * 7, 8 + math.sin(a) * 3, 0)) * CFrame.Angles(0, 0, a), color = c, material = Enum.Material.Glass, transparency = 0.3, collide = true, parent = parent })
			end
			part({ name = "ArchLegL", size = Vector3.new(3, 9, 3), cf = CFrame.new(p + Vector3.new(-7, 4.5, 0)), color = c, material = Enum.Material.Glass, transparency = 0.3, collide = true, parent = parent })
			part({ name = "ArchLegR", size = Vector3.new(3, 9, 3), cf = CFrame.new(p + Vector3.new(7, 4.5, 0)), color = c, material = Enum.Material.Glass, transparency = 0.3, collide = true, parent = parent })
		end
		for i = 1, 8 do
			local p = spot(14, radius - 8)
			part({ name = "Icicle", size = Vector3.new(1.2, rand:NextNumber(4, 9), 1.2), cf = CFrame.new(p + Vector3.new(0, 3, 0)), color = c, material = Enum.Material.Ice, transparency = 0.18, parent = parent })
		end
	elseif element == "Storm" then
		for i = 1, 6 do
			local p = spot(14, radius - 10)
			part({ name = "Pylon", size = Vector3.new(2, 20, 2), cf = CFrame.new(p + Vector3.new(0, 10, 0)), color = DECK, collide = true, parent = parent })
			part({ name = "CrossArm", size = Vector3.new(10, 1, 1), cf = CFrame.new(p + Vector3.new(0, 18, 0)), color = DECK, parent = parent })
			for _, side in { -1, 1 } do
				local ins = part({ name = "Insulator", size = Vector3.new(1.2, 1.6, 1.2), cf = CFrame.new(p + Vector3.new(side * 4.5, 16.9, 0)), color = c, material = Enum.Material.Neon, parent = parent })
				local pl = Instance.new("PointLight")
				pl.Color = c
				pl.Range = 20
				pl.Brightness = 0.9
				pl.Parent = ins
			end
		end
		for i = 1, 8 do
			local p = spot(12, radius - 8)
			part({ name = "Panel", size = Vector3.new(5, 0.4, 4), cf = CFrame.new(p + Vector3.new(0, 2.4, 0)) * CFrame.Angles(math.rad(-28), rand:NextNumber(0, 6), 0), color = rgb(50, 58, 84), parent = parent })
			part({ name = "PanelPost", size = Vector3.new(0.6, 2.4, 0.6), cf = CFrame.new(p + Vector3.new(0, 1.2, 0)), color = DECK, collide = true, parent = parent })
		end
	else -- Cosmic
		disc(parent, "Deck", centre + Vector3.new(0, 1.4, 0), radius - 12, 1.2, rgb(66, 60, 96), Enum.Material.Metal)
		for i = 1, 18 do
			local a = (i / 18) * 360
			part({ name = "DeckRail", size = Vector3.new(6, 2.4, 0.6), cf = CFrame.new(centre + polar(radius - 12, a, 3)) * CFrame.Angles(0, math.rad(-a), 0), color = c, material = Enum.Material.Neon, transparency = 0.35, parent = parent })
		end
		for i = 1, 8 do
			local p = spot(14, radius - 16)
			part({ name = "FloatRock", size = Vector3.new(rand:NextNumber(3, 7), rand:NextNumber(2, 5), rand:NextNumber(3, 7)), cf = CFrame.new(p + Vector3.new(0, rand:NextNumber(6, 16), 0)) * CFrame.Angles(rand:NextNumber(0, 3), rand:NextNumber(0, 6), rand:NextNumber(0, 3)), color = rgb(96, 88, 128), material = Enum.Material.Rock, parent = parent })
		end
		for i = 1, 5 do
			local p = spot(16, radius - 16)
			part({ name = "Antenna", size = Vector3.new(0.8, 14, 0.8), cf = CFrame.new(p + Vector3.new(0, 8.4, 0)), color = STEEL, collide = true, parent = parent })
			local tip = part({ name = "AntennaTip", size = Vector3.new(2.4, 2.4, 2.4), cf = CFrame.new(p + Vector3.new(0, 16, 0)), color = c, material = Enum.Material.Neon, shape = Enum.PartType.Ball, parent = parent })
			local pl = Instance.new("PointLight")
			pl.Color = c
			pl.Range = 22
			pl.Brightness = 1
			pl.Parent = tip
		end
	end
end

local function buildRegion(parent: Instance, def: any)
	local angle = 90 + 60 * (def.index - 1)
	local centre = polar(280, angle)
	local radius = 75
	local spawnRadius = 55

	local model = Instance.new("Model")
	model.Name = def.id
	model:SetAttribute("RegionId", def.id)
	model:SetAttribute("Element", def.element)
	model:SetAttribute("Centre", centre)
	model:SetAttribute("SpawnRadius", spawnRadius)
	model.Parent = parent

	-- coloured ground patch
	-- each region's floor uses a material that matches what it is meant to be,
	-- which does more for how a place reads than its colour does
	local GROUND_MATERIAL: { [string]: Enum.Material } = {
		Wind = Enum.Material.Grass,
		Water = Enum.Material.Sand,
		Heat = Enum.Material.Basalt,
		Frost = Enum.Material.Snow,
		Storm = Enum.Material.Asphalt,
		Cosmic = Enum.Material.Metal,
	}
	disc(model, "Ground", centre + Vector3.new(0, 0.3, 0), radius, 1.4, def.groundColor, GROUND_MATERIAL[def.element] or Enum.Material.Ground)
	-- a rim wall all the way round, with a gap on the hub side for the gate
	local gateAngle = angle + 180 -- the side facing the origin
	for i = 1, 40 do
		local a = (i / 40) * 360
		local delta = math.abs(((a - gateAngle + 180) % 360) - 180)
		if delta > 14 then
			part({ name = "Fence", size = Vector3.new(12.4, 6, 1.4), cf = CFrame.new(centre + polar(radius, a, 3)) * CFrame.Angles(0, math.rad(-a), 0), color = DECK, collide = true, parent = model })
			part({ name = "FenceTop", size = Vector3.new(12.4, 0.6, 2.0), cf = CFrame.new(centre + polar(radius, a, 6.2)) * CFrame.Angles(0, math.rad(-a), 0), color = def.color, parent = model })
		end
	end

	regionProps(model, centre, def.element, def, radius)
	regionAmbience(model, centre, def.element, def, radius)

	local wild = Instance.new("Folder")
	wild.Name = "Wild"
	wild.Parent = model

	-- ---------------------------------------------------------------- gate
	local gatePos = polar(200, angle)
	local gateCF = CFrame.new(gatePos) * CFrame.Angles(0, math.rad(-angle + 90), 0)
	local gate = part({
		name = "Gate",
		size = Vector3.new(20, 12, 2),
		cf = gateCF * CFrame.new(0, 6, 0),
		color = def.color,
		material = Enum.Material.Neon,
		transparency = 0.45,
		collide = true,
		parent = model,
	})
	gate:SetAttribute("RegionId", def.id)
	CollectionService:AddTag(gate, "RegionGate")
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
	-- gate frame
	for _, side in { -1, 1 } do
		part({ name = "GatePost", size = Vector3.new(2.4, 15, 2.4), cf = gateCF * CFrame.new(side * 11, 7.5, 0), color = DECK, collide = true, parent = model })
	end
	part({ name = "GateLintel", size = Vector3.new(25, 2.4, 2.6), cf = gateCF * CFrame.new(0, 14, 0), color = INK, parent = model })
	hazardStrip(model, gateCF * CFrame.new(0, 14, -1.4), 24, 2.0, 0.2)

	-- sign beside the gate, facing the hub
	local signHost = part({ name = "GateSign", size = Vector3.new(13, 8, 0.6), cf = gateCF * CFrame.new(17, 7, -1.2), color = rgb(48, 52, 70), collide = true, parent = model })
	local gui = surface(signHost, Enum.NormalId.Back, 22)
	local title = label(gui, "Title", def.name, UDim2.fromScale(0.94, 0.34), UDim2.fromScale(0.03, 0.04), def.color)
	local costText = if def.unlockCost <= 0 then "OPEN" else "Unlock: " .. Format.abbreviate(def.unlockCost) .. " Coins"
	local cost = label(gui, "Cost", costText, UDim2.fromScale(0.94, 0.26), UDim2.fromScale(0.03, 0.4), rgb(255, 232, 150))
	local forecast = label(gui, "Forecast", "Legendary forecast: --", UDim2.fromScale(0.94, 0.24), UDim2.fromScale(0.03, 0.7), rgb(200, 230, 255))
	-- element name so the sign reads without colour
	local elementLabel = label(gui, "Element", def.element, UDim2.fromScale(0.3, 0.16), UDim2.fromScale(0.67, 0.04), rgb(230, 236, 250))
	elementLabel.TextXAlignment = Enum.TextXAlignment.Right

	local entrance = part({ name = "Entrance", size = Vector3.new(6, 1, 6), cf = gateCF * CFrame.new(0, 0.5, 14), transparency = 1, collide = false, query = false, parent = model })

	-- a route edged in the region's own colour, so the way to Frostbite Peaks
	-- looks different from the way to Cinder Canyon long before you can read the sign
	path(model, polar(74, angle), gatePos, 9, def.color)
	path(model, gatePos, centre, 9, def.color)
	lamp(model, gatePos + Vector3.new(0, 0, 0) + polar(16, angle + 90), def.color)
	lamp(model, gatePos + polar(16, angle - 90), def.color)

	return {
		model = model,
		centre = centre,
		spawnRadius = spawnRadius,
		gate = gate,
		gateSign = { title = title, cost = cost, forecast = forecast },
		entrance = entrance,
		wild = wild,
	}
end

-- Scenery stays outside the playable ring and region interiors. The underlying
-- ground remains continuous; hills use embedded ellipsoids with no flat seams.
-- Fixed placement avoids changing the gameplay random sequence on each boot.
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
			local color = if snowy then rgb(213, 232, 236) else rgb(67 + tier * 10, 120 + tier * 12, 76 + tier * 5)
			local material = if snowy then Enum.Material.Snow else Enum.Material.Grass
			rock(host, "Canopy", pos + Vector3.new(0, (5 + tier * 2.5) * scale, 0), Vector3.new(width, 6 * scale, width), color, material, true)
		end
	end

	-- Low banks in the empty wedges between destinations, beyond all city plots.
	for i = 1, 6 do
		local angle = 120 + (i - 1) * 60
		local centre = polar(230, angle)
		local clear = true
		for _, def in Config.Regions.list do
			if (centre - polar(280, 90 + 60 * (def.index - 1))).Magnitude < 110 then
				clear = false
			end
		end
		if clear then
			rock(scenery, "MeadowBank", centre + Vector3.new(0, -2, 0), Vector3.new(52, 17, 44), rgb(108, 150, 91), Enum.Material.Grass, true)
			rock(scenery, "MeadowShoulder", centre + polar(21, angle + 90, -1.5), Vector3.new(32, 11, 29), rgb(119, 159, 98), Enum.Material.Grass, true)
			tree(scenery, centre + polar(31, angle, 0), 0.9, false)
		end
	end

	for _, def in Config.Regions.list do
		local angle = 90 + 60 * (def.index - 1)
		local centre = polar(280, angle)
		local group = Instance.new("Folder")
		group.Name = def.id
		group.Parent = scenery
		local element = def.element
		local material = if element == "Water" then Enum.Material.Sand elseif element == "Frost" then Enum.Material.Snow elseif element == "Heat" then Enum.Material.Sandstone elseif element == "Wind" then Enum.Material.Grass else Enum.Material.Slate
		-- The semicircle faces away from the hub: entrances and signs stay open.
		for i = 1, 7 do
			local bearing = angle - 84 + (i - 1) * 28
			local at = centre + polar(119 + (i % 2) * 8, bearing)
			local height = 22 + (i % 3) * 8
			local tint = def.groundColor:Lerp(rgb(118, 130, 112), 0.18)
			if element == "Water" or element == "Wind" then
				rock(group, "Dune", at + Vector3.new(0, -3, 0), Vector3.new(57, height * 0.7, 48), tint, material, true)
			elseif element == "Heat" then
				for tier = 1, 3 do
					local width = 44 - tier * 7
					rock(group, "CanyonStratum", at + Vector3.new(0, (tier - 0.5) * height / 3 - 1, 0), Vector3.new(width, height / 3, width * 0.8),
						tint:Lerp(rgb(205, 139, 89), tier * 0.15), material)
				end
			else
				local ridge = rock(group, "Ridge", at + Vector3.new(0, height * 0.25, 0), Vector3.new(32, height, 30), tint, material)
				ridge.CFrame *= CFrame.Angles(0, math.rad(bearing), math.rad(18))
				if element == "Frost" then
					rock(group, "SnowCap", at + Vector3.new(0, height * 0.73, 0), Vector3.new(28, 9, 27), rgb(239, 246, 249), Enum.Material.Snow, true)
				elseif element == "Cosmic" then
					local floating = rock(group, "FloatingShard", at + Vector3.new(0, height + 12, 0), Vector3.new(6, 10, 6), def.color, Enum.Material.Slate)
					floating.CFrame *= CFrame.Angles(0.3, 0.6, 0.4)
					floating.CanCollide = false
					local seam = rock(group, "CrystalSeam", at + Vector3.new(0, height + 12, 0), Vector3.new(6.3, 0.5, 6.3), def.color, Enum.Material.Neon)
					seam.CFrame = floating.CFrame
					seam.CanCollide = false
				end
			end
			-- A lower apron softens the transition from plain grass to each biome.
			local shoulder = centre + polar(94, bearing)
			rock(group, "BiomeShoulder", shoulder + Vector3.new(0, -1.3, 0), Vector3.new(25, 7, 24), def.groundColor, material, true)
			if element == "Wind" or element == "Frost" then
				tree(group, centre + polar(98, bearing + 7), 0.85 + (i % 3) * 0.16, element == "Frost")
			elseif element == "Water" then
				local reeds = centre + polar(91, bearing + 7)
				for stem = 1, 3 do
					rock(group, "BeachGrass", reeds + Vector3.new(stem - 2, 1.8, 0), Vector3.new(0.35, 3.6 + stem * 0.4, 0.35), rgb(120, 145, 90), Enum.Material.Grass)
				end
			end
		end
	end
end

-- ============================================================ build

function MapBuilder.build()
	partCount = 0

	local map = Instance.new("Model")
	map.Name = "Map"
	map.Parent = workspace

	-- ground
	part({ name = "Ground", size = Vector3.new(900, 4, 900), cf = CFrame.new(0, -2, 0), color = rgb(126, 168, 104), material = Enum.Material.Grass, collide = true, parent = map })

	local hub = buildHub(map)
	local arena = buildArena(map)

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

	-- plot ring: eight CFrames whose front (local -Z) looks at the origin
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace
	local plots: { [number]: CFrame } = {}
	for i = 1, Config.MaxPlayers do
		local a = 22.5 + (i - 1) * 45
		local pos = polar(140, a)
		plots[i] = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
		path(map, polar(72, a), pos, 8, rgb(120, 200, 255))
		lamp(map, polar(104, a))
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
