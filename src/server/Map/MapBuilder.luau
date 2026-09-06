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

-- A path strip from one point to another, drawn just above the ground.
local function path(parent: Instance, from: Vector3, to: Vector3, width: number)
	local delta = to - from
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local mid = (from + to) / 2
	part({
		name = "Path",
		size = Vector3.new(width, 0.25, length),
		cf = CFrame.lookAt(Vector3.new(mid.X, 0.12, mid.Z), Vector3.new(to.X, 0.12, to.Z)),
		color = PATH,
		material = Enum.Material.Slate,
		parent = parent,
	})
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

	disc(hub, "Plaza", Vector3.new(0, 0, 0), 70, 1, CONCRETE, Enum.Material.Concrete)
	disc(hub, "PlazaInner", Vector3.new(0, 0.05, 0), 30, 1, rgb(206, 202, 210), Enum.Material.Concrete)
	-- company logo ring in the middle
	for i = 1, 24 do
		local a = (i / 24) * 360
		part({
			name = "LogoTile",
			size = Vector3.new(3.2, 0.16, 1.6),
			cf = CFrame.new(polar(16, a, 0.14)) * CFrame.Angles(0, math.rad(-a), 0),
			color = if i % 2 == 0 then HAZARD else INK,
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
	disc(beacon, "Base", beaconPos, 12, 1.2, DECK, Enum.Material.Concrete)
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
	disc(kiosk, "Base", atlasPos, 9, 1.2, DECK, Enum.Material.Concrete)
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
	path(hub, Vector3.new(0, 0, 0), workshopPos, 8)
	path(hub, Vector3.new(0, 0, 0), beaconPos, 8)
	path(hub, Vector3.new(0, 0, 0), atlasPos, 8)
	path(hub, Vector3.new(0, 0, 0), Vector3.new(0, 0, -70), 10)

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

	disc(arena, "Floor", centre, 30, 1, rgb(196, 192, 200), Enum.Material.Concrete)
	disc(arena, "Ring", centre + Vector3.new(0, 0.06, 0), 22, 1, rgb(172, 168, 180), Enum.Material.Concrete)
	-- containment ring markings
	for i = 1, 30 do
		local a = (i / 30) * 360
		part({
			name = "Marking",
			size = Vector3.new(3.6, 0.14, 1.2),
			cf = CFrame.new(centre + polar(27, a, 0.14)) * CFrame.Angles(0, math.rad(-a), 0),
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

	path(arena, Vector3.new(0, 0, -70), centre, 10)
	for i = 1, 6 do
		lamp(arena, centre + polar(34, (i - 1) * 60), rgb(200, 230, 255))
	end

	return { model = arena, centre = centre, pylons = pylons, bossSpot = bossSpot, screen = screenText }
end

-- ============================================================ regions

-- Per-element scenery. Each returns after adding ~20 props inside `radius`.
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
				part({ name = "Grass", size = Vector3.new(0.4, rand:NextNumber(3, 6), 0.4), cf = CFrame.new(p + Vector3.new(j * 0.5, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(rand:NextNumber(-16, 16))), color = rgb(120, 200, 110), parent = parent })
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
			part({ name = "Bush", size = Vector3.new(4, 3, 4), cf = CFrame.new(p + Vector3.new(0, 1.5, 0)), color = rgb(110, 180, 100), shape = Enum.PartType.Ball, parent = parent })
		end
	elseif element == "Water" then
		for i = 1, 7 do
			local p = spot(12, radius - 10)
			local r = rand:NextNumber(6, 14)
			disc(parent, "Pool", p + Vector3.new(0, 0.2, 0), r, 0.4, c, Enum.Material.Glass)
			part({ name = "PoolRim", size = Vector3.new(0.5, r * 2 + 1.6, r * 2 + 1.6), cf = CFrame.new(p + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), color = rgb(214, 196, 150), shape = Enum.PartType.Cylinder, parent = parent })
		end
		for i = 1, 8 do
			local p = spot(14, radius - 8)
			part({ name = "Rock", size = Vector3.new(rand:NextNumber(2, 5), rand:NextNumber(2, 4), rand:NextNumber(2, 5)), cf = CFrame.new(p + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, rand:NextNumber(0, 6), 0), color = rgb(150, 148, 140), collide = true, parent = parent })
		end
		-- a small dock
		local d = centre + polar(26, 200)
		part({ name = "Dock", size = Vector3.new(6, 0.7, 20), cf = CFrame.new(d + Vector3.new(0, 1.2, 0)), color = rgb(168, 124, 78), collide = true, parent = parent })
		for i = 1, 4 do
			part({ name = "Piling", size = Vector3.new(0.9, 3.4, 0.9), cf = CFrame.new(d + Vector3.new(2.2, 0.6, -7 + (i - 1) * 5)), color = rgb(120, 88, 56), collide = true, parent = parent })
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
			part({ name = "SnowMound", size = Vector3.new(rand:NextNumber(6, 12), rand:NextNumber(2, 5), rand:NextNumber(6, 12)), cf = CFrame.new(p + Vector3.new(0, 1.2, 0)), color = rgb(240, 246, 252), shape = Enum.PartType.Ball, collide = true, parent = parent })
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
			part({ name = "Icicle", size = Vector3.new(1.2, rand:NextNumber(4, 9), 1.2), cf = CFrame.new(p + Vector3.new(0, 3, 0)), color = c, material = Enum.Material.Glass, transparency = 0.22, parent = parent })
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
			part({ name = "FloatRock", size = Vector3.new(rand:NextNumber(3, 7), rand:NextNumber(2, 5), rand:NextNumber(3, 7)), cf = CFrame.new(p + Vector3.new(0, rand:NextNumber(6, 16), 0)) * CFrame.Angles(rand:NextNumber(0, 3), rand:NextNumber(0, 6), rand:NextNumber(0, 3)), color = rgb(96, 88, 128), parent = parent })
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
	disc(model, "Ground", centre + Vector3.new(0, 0.3, 0), radius, 1.4, def.groundColor, Enum.Material.Ground)
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

	path(model, Vector3.new(0, 0, 0), gatePos, 9)
	path(model, gatePos, centre, 9)
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
		path(map, polar(72, a), pos, 8)
		lamp(map, polar(104, a))
	end

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
