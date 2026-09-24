--!strict
-- Hub architecture. Local -Z is the entrance; MapBuilder supplies a frame
-- looking at the plaza center. All geometry, signage and terminals share it.
local CollectionService = game:GetService("CollectionService")
local Landmarks = {}
local rgb = Color3.fromRGB
local INK = rgb(35, 44, 57)
local STEEL = rgb(111, 133, 149)
local CREAM = rgb(214, 212, 193)
local AMBER = rgb(235, 165, 48)
local CYAN = rgb(66, 184, 207)
local METAL = Enum.Material.Metal

type MakePart = (any) -> Part

local function builder(parent: Instance, name: string, frame: CFrame, makePart: MakePart)
	local model = Instance.new("Model")
	model.Name = name
	model.WorldPivot = frame
	model:SetAttribute("EntrancePosition", frame:PointToWorldSpace(Vector3.new(0, 0, -14)))
	model:SetAttribute("HubFacing", true)
	model.Parent = parent
	local function block(id: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?): Part
		return makePart({ name = id, size = size, cf = frame * cf, color = color,
			material = material or METAL, collide = solid == true, parent = model })
	end
	local function cylinder(id: string, position: Vector3, diameter: number, length: number, color: Color3, vertical: boolean, material: Enum.Material?): Part
		local rotation = if vertical then CFrame.Angles(0, 0, math.pi / 2) else CFrame.Angles(0, math.pi / 2, 0)
		local p = block(id, Vector3.new(length, diameter, diameter), CFrame.new(position) * rotation, color, material)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	return model, block, cylinder
end

local function sign(host: BasePart, title: string, subtitle: string, accent: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.15
	gui.Brightness = 1
	gui.Parent = host
	local function text(name: string, value: string, y: number, height: number, color: Color3, font: Enum.Font)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.04, y)
		label.Size = UDim2.fromScale(0.92, height)
		label.Font = font
		label.Text = value
		label.TextScaled = true
		label.TextColor3 = color
		label.Parent = gui
	end
	text("Text", title, 0.08, 0.55, accent, Enum.Font.FredokaOne)
	text("Subtitle", subtitle, 0.69, 0.21, CREAM, Enum.Font.GothamMedium)
end

local function light(host: BasePart, color: Color3, brightness: number, range: number)
	local fill = Instance.new("PointLight")
	fill.Color = color
	fill.Brightness = brightness
	fill.Range = range
	fill.Shadows = false
	fill.Parent = host
end

local function terminal(host: Part, panel: string, name: string, accent: Color3)
	host:SetAttribute("OpensPanel", panel)
	host:SetAttribute("WaypointName", name)
	host:SetAttribute("WaypointColor", accent)
	host:SetAttribute("WaypointHeight", 12)
	CollectionService:AddTag(host, "Waypoint")
end

function Landmarks.buildWorkshop(parent: Instance, frame: CFrame, makePart: MakePart): Part
	local _, block, cylinder = builder(parent, "Workshop", frame, makePart)
	local blue = rgb(53, 88, 105)
	local concrete = rgb(133, 143, 145)
	-- Low thresholds can be walked across. Side props leave a 10-stud approach.
	block("Floor", Vector3.new(28, 0.6, 22), CFrame.new(0, 0.3, 0), concrete, Enum.Material.Concrete, true)
	block("Apron", Vector3.new(20, 0.3, 6), CFrame.new(0, 0.15, -13), concrete, Enum.Material.Concrete, true)
	block("EntryTread", Vector3.new(10, 0.12, 3), CFrame.new(0, 0.42, -10.8), STEEL, Enum.Material.DiamondPlate)
	block("Wall", Vector3.new(28, 12, 1), CFrame.new(0, 6.6, 10.5), blue, Enum.Material.Brick, true)
	for _, side in { -1, 1 } do
		block("SideWall", Vector3.new(0.8, 12, 22), CFrame.new(side * 13.6, 6.6, 0), blue, Enum.Material.Concrete, true)
		block("WallSkirt", Vector3.new(1, 2, 22.2), CFrame.new(side * 13.6, 1.6, 0), INK, Enum.Material.DiamondPlate)
		for i = 0, 4 do
			block("WallRib", Vector3.new(1, 10, 0.28), CFrame.new(side * 13.6, 7.4, -9.5 + i * 4.8), STEEL)
		end
		block("EntryColumn", Vector3.new(1.3, 12.2, 1.3), CFrame.new(side * 11.8, 6.7, -10.3), INK, METAL, true)
		block("ColumnFoot", Vector3.new(1.65, 2.5, 1.65), CFrame.new(side * 11.8, 1.85, -10.3), AMBER, Enum.Material.DiamondPlate)
		block("EntryWing", Vector3.new(4.4, 9, 0.65), CFrame.new(side * 9, 5.1, -10.4), blue, METAL, true)
		block("WindowFrame", Vector3.new(3.4, 2.7, 0.32), CFrame.new(side * 9, 7, -10.82), INK)
		block("Window", Vector3.new(2.9, 2.2, 0.12), CFrame.new(side * 9, 7, -11.06), rgb(85, 139, 155), Enum.Material.Glass)
		block("WindowMullion", Vector3.new(0.15, 2.4, 0.18), CFrame.new(side * 9, 7, -11.2), STEEL)
		for i = 1, 4 do
			block("IntakeLouvre", Vector3.new(3, 0.16, 0.3), CFrame.new(side * 9, 2.5 + i * 0.48, -10.85), INK)
		end
		block("SafetyBollard", Vector3.new(0.7, 2.8, 0.7), CFrame.new(side * 8.2, 1.7, -14), INK, METAL, true)
		block("BollardBand", Vector3.new(0.76, 0.55, 0.76), CFrame.new(side * 8.2, 2.5, -14), AMBER)
	end
	-- A ribbed standing-seam roof and deep canopy give the building a silhouette.
	block("Roof", Vector3.new(30, 0.8, 24), CFrame.new(0, 13, 0), INK, METAL, true)
	for i = -5, 5 do
		block("RoofSeam", Vector3.new(0.12, 0.22, 23.6), CFrame.new(i * 2.7, 13.51, 0), STEEL)
	end
	block("Canopy", Vector3.new(29, 0.65, 4), CFrame.new(0, 10.8, -12.2), INK)
	block("CanopyFascia", Vector3.new(29.2, 0.75, 0.35), CFrame.new(0, 10.65, -14.25), AMBER)
	local taskLight = block("TaskLight", Vector3.new(9, 0.12, 0.5), CFrame.new(0, 10.4, -12.5), rgb(241, 209, 149), Enum.Material.Neon)
	light(taskLight, rgb(255, 215, 159), 0.75, 20)
	local benchLight = block("BenchLight", Vector3.new(12, 0.15, 0.5), CFrame.new(0, 10, 8.4), rgb(228, 204, 160), Enum.Material.Neon)
	light(benchLight, rgb(255, 223, 175), 0.8, 15)
	for _, side in { -1, 1 } do
		block("SignPost", Vector3.new(0.45, 3.5, 0.45), CFrame.new(side * 8.5, 14.3, -9.8), STEEL)
	end
	block("SignFrame", Vector3.new(24, 4.8, 0.75), CFrame.new(0, 15.8, -10.4), AMBER)
	local header = block("Sign", Vector3.new(23.3, 4.1, 0.25), CFrame.new(0, 15.8, -10.95), INK)
	sign(header, "UPGRADE WORKSHOP", "TUNE UP YOUR CATASTROPHE CREW", AMBER)
	-- Workbench, tool board and storage give the open bay a believable interior.
	block("Workbench", Vector3.new(21, 0.6, 3), CFrame.new(0, 3.7, 8), rgb(137, 100, 63), Enum.Material.WoodPlanks, true)
	for _, x in { -8, 8 } do
		block("Cabinet", Vector3.new(4.5, 2.8, 2.5), CFrame.new(x, 2.1, 8), STEEL, Enum.Material.DiamondPlate, true)
		for i = 1, 3 do
			block("DrawerPull", Vector3.new(2.7, 0.15, 0.2), CFrame.new(x, 1.2 + i * 0.65, 6.6), INK)
		end
	end
	block("ToolBoard", Vector3.new(17, 5, 0.3), CFrame.new(0, 7, 9.8), INK, Enum.Material.DiamondPlate)
	cylinder("Gear", Vector3.new(-4.5, 7, 9.45), 3.2, 0.4, AMBER, false)
	for i = 1, 8 do
		local a = i * math.pi / 4
		block("GearTooth", Vector3.new(0.7, 0.7, 0.5), CFrame.new(-4.5 + math.cos(a) * 1.8, 7 + math.sin(a) * 1.8, 9.4) * CFrame.Angles(0, 0, a), AMBER)
	end
	cylinder("GearHub", Vector3.new(-4.5, 7, 9.14), 1.1, 0.15, INK, false)
	for i = 1, 3 do
		local x = 0.7 + i * 1.9
		block("ToolHandle", Vector3.new(0.35, 2.5, 0.35), CFrame.new(x, 6.7, 9.3) * CFrame.Angles(0, 0, -0.2), STEEL)
		block("ToolHead", Vector3.new(1.15, 0.45, 0.45), CFrame.new(x + 0.25, 8, 9.3), AMBER)
	end
	block("VentHousing", Vector3.new(5, 2, 5), CFrame.new(8, 14.4, 5), STEEL, Enum.Material.DiamondPlate)
	for i = 1, 5 do
		block("RoofVent", Vector3.new(4.2, 0.15, 0.3), CFrame.new(8, 15.48, 3.4 + i * 0.55), INK)
	end
	local console = block("Terminal", Vector3.new(4.8, 4.2, 2.5), CFrame.new(0, 2.7, -8.2), INK, METAL, true)
	terminal(console, "Workshop", "Upgrade Workshop", AMBER)
	local screen = block("ConsoleScreen", Vector3.new(4.1, 2.4, 0.15), CFrame.new(0, 3.3, -9.55), rgb(23, 54, 63), Enum.Material.SmoothPlastic)
	sign(screen, "UPGRADES", "GEAR  /  SPEED  /  CAPACITY", rgb(124, 221, 206))
	block("ConsoleTrim", Vector3.new(4.4, 0.14, 0.14), CFrame.new(0, 1.5, -9.6), AMBER)
	return console
end

function Landmarks.buildBeacon(parent: Instance, frame: CFrame, makePart: MakePart): Part
	local _, block, cylinder = builder(parent, "Beacon", frame, makePart)
	local slate = rgb(66, 87, 105)
	local function ring(name: string, radius: number, y: number, thickness: number, color: Color3, material: Enum.Material)
		for i = 1, 24 do
			local a = i * math.pi / 12
			block(name, Vector3.new(2 * radius * math.tan(math.pi / 24) + 0.04, thickness, 0.4), CFrame.new(math.sin(a) * radius, y, math.cos(a) * radius) * CFrame.Angles(0, a, 0), color, material)
		end
	end
	local base = cylinder("Base", Vector3.new(0, 0.25, 0), 26, 0.5, rgb(141, 153, 158), true, Enum.Material.Concrete)
	base.CanCollide = true
	block("Apron", Vector3.new(10, 0.3, 5), CFrame.new(0, 0.15, -13), STEEL, Enum.Material.DiamondPlate, true)
	ring("BaseRim", 12.1, 0.58, 0.18, slate, METAL)
	local pedestal = cylinder("Pedestal", Vector3.new(0, 1.1, 1), 11, 1.2, slate, true, Enum.Material.DiamondPlate)
	pedestal.CanCollide = true
	-- Twin gantries frame a contained energy core; the front remains approachable.
	for _, side in { -1, 1 } do
		block("GantryFoot", Vector3.new(4, 1.5, 5), CFrame.new(side * 7.5, 1.25, 2), INK, Enum.Material.Concrete, true)
		block("Gantry", Vector3.new(2.6, 22, 3), CFrame.new(side * 7.5, 12.5, 2), slate, METAL, true)
		block("GantryInset", Vector3.new(1.7, 18, 0.25), CFrame.new(side * 7.5, 12.5, 0.32), INK, Enum.Material.DiamondPlate)
		block("PowerStrip", Vector3.new(0.3, 16, 0.16), CFrame.new(side * 7.5, 12.5, 0.1), CYAN, Enum.Material.Neon)
		for i = 1, 4 do
			block("GantryCollar", Vector3.new(3.1, 0.7, 3.5), CFrame.new(side * 7.5, 3 + i * 4.2, 2), STEEL)
		end
		block("SignSupport", Vector3.new(0.7, 10, 0.7), CFrame.new(side * 7.5, 5.5, -8.8), slate, METAL, true)
		block("ApproachLight", Vector3.new(0.3, 0.16, 5), CFrame.new(side * 4.3, 0.56, -11), CYAN, Enum.Material.Neon)
	end
	block("GantryBridge", Vector3.new(18, 2.2, 3.5), CFrame.new(0, 23.5, 2), INK)
	block("BridgeTrim", Vector3.new(15.5, 0.35, 0.25), CFrame.new(0, 23.5, 0.1), CYAN, Enum.Material.Neon)
	local core = cylinder("Core", Vector3.new(0, 12.5, 1), 3.2, 20, rgb(58, 162, 191), true, Enum.Material.Neon)
	light(core, CYAN, 0.9, 27)
	for _, y in { 3, 8, 17, 22 } do
		cylinder("CoreCollar", Vector3.new(0, y, 1), 5.5, 0.85, STEEL, true)
	end
	for _, y in { 6, 19 } do
		-- Rings remain hollow, keeping the central core visible through them.
		for i = 1, 20 do
			local a = i * math.pi / 10
			block("ContainmentRing", Vector3.new(1.55, 0.55, 0.65), CFrame.new(math.sin(a) * 4.6, y, 1 + math.cos(a) * 4.6) * CFrame.Angles(0, a, 0), STEEL)
		end
	end
	local crown = block("Crown", Vector3.new(4, 4, 4), CFrame.new(0, 27.5, 1) * CFrame.Angles(0, math.pi / 4, math.pi / 4), CYAN, Enum.Material.Neon)
	light(crown, CYAN, 0.6, 24)
	cylinder("CrownSeat", Vector3.new(0, 25.1, 1), 5.5, 0.65, INK, true)
	block("SignFrame", Vector3.new(18, 4.2, 0.8), CFrame.new(0, 11, -8.8), STEEL)
	local header = block("Sign", Vector3.new(17.4, 3.6, 0.25), CFrame.new(0, 11, -9.4), INK)
	sign(header, "CITY RELAUNCH", "A FRESH START. A STRONGER CITY.", CYAN)
	local console = block("Terminal", Vector3.new(4.8, 4.2, 2.5), CFrame.new(0, 2.6, -9.2), INK, METAL, true)
	terminal(console, "Relaunch", "City Relaunch", CYAN)
	local screen = block("ConsoleScreen", Vector3.new(4.1, 2.4, 0.15), CFrame.new(0, 3.2, -10.55), rgb(22, 49, 66), Enum.Material.SmoothPlastic)
	sign(screen, "RELAUNCH", "REVIEW YOUR NEXT CHAPTER", CYAN)
	block("ConsoleTrim", Vector3.new(4.4, 0.14, 0.14), CFrame.new(0, 1.4, -10.6), CYAN, Enum.Material.Neon)
	return console
end

function Landmarks.buildAtlas(parent: Instance, frame: CFrame, makePart: MakePart): Part
	local _, block, cylinder = builder(parent, "AtlasKiosk", frame, makePart)
	local green = rgb(87, 176, 123)
	local darkGreen = rgb(44, 81, 73)
	block("Foundation", Vector3.new(23, 0.5, 18), CFrame.new(0, 0.25, 0), rgb(152, 163, 155), Enum.Material.Concrete, true)
	block("Apron", Vector3.new(12, 0.3, 5), CFrame.new(0, 0.15, -11), STEEL, Enum.Material.DiamondPlate, true)
	block("ArchiveWall", Vector3.new(22, 8.5, 0.8), CFrame.new(0, 4.75, 8.2), darkGreen, Enum.Material.Brick, true)
	for _, side in { -1, 1 } do
		block("PavilionPost", Vector3.new(1, 11, 1), CFrame.new(side * 10.2, 6, -7.6), INK, METAL, true)
		block("PostBase", Vector3.new(1.5, 1.5, 1.5), CFrame.new(side * 10.2, 1.25, -7.6), green)
		block("ArchiveCabinet", Vector3.new(4.4, 5.8, 0.3), CFrame.new(side * 8, 3.4, 7.05), INK, METAL, true)
		for _, edge in { -1, 1 } do
			block("CabinetSide", Vector3.new(0.25, 5.8, 3), CFrame.new(side * 8 + edge * 2.08, 3.4, 5.7), INK, METAL, true)
		end
		block("CabinetTop", Vector3.new(4.4, 0.25, 3), CFrame.new(side * 8, 6.2, 5.7), INK, METAL)
		for shelf = 1, 3 do
			block("ArchiveShelf", Vector3.new(4.6, 0.18, 3.2), CFrame.new(side * 8, shelf * 1.4, 5.6), rgb(157, 122, 77), Enum.Material.WoodPlanks)
			for book = 1, 4 do
				local tint = if book % 2 == 0 then green else CREAM
				block("FieldGuide", Vector3.new(0.65, 1.05, 1.8), CFrame.new(side * 8 - 1.5 + book * 0.7, 0.615 + shelf * 1.4, 5.3), tint, Enum.Material.SmoothPlastic)
			end
		end
		block("Planter", Vector3.new(3, 1.6, 3), CFrame.new(side * 9.2, 1, -10.6), darkGreen, Enum.Material.Concrete, true)
		local plant = block("Shrub", Vector3.new(3.6, 2.4, 3.6), CFrame.new(side * 9.2, 2.7, -10.6), green, Enum.Material.Grass)
		plant.Shape = Enum.PartType.Ball
	end
	block("Canopy", Vector3.new(25, 0.8, 20), CFrame.new(0, 11.6, -0.5), darkGreen)
	for i = -4, 4 do
		block("CanopySeam", Vector3.new(0.16, 0.2, 19.6), CFrame.new(i * 2.8, 12.1, -0.5), STEEL)
	end
	block("CanopyFascia", Vector3.new(25.2, 0.55, 0.35), CFrame.new(0, 11.55, -10.65), green)
	local warm = block("ReadingLight", Vector3.new(9, 0.14, 0.45), CFrame.new(0, 11.1, 2), rgb(229, 219, 171), Enum.Material.Neon)
	light(warm, rgb(242, 226, 187), 0.7, 18)
	-- A six-element specimen display behind the interaction lectern.
	block("SpecimenDesk", Vector3.new(13, 0.5, 3.4), CFrame.new(0, 3.2, 4.6), rgb(146, 112, 71), Enum.Material.WoodPlanks, true)
	block("DeskBase", Vector3.new(10, 2.4, 2.2), CFrame.new(0, 1.7, 4.6), darkGreen, METAL, true)
	local colors = { rgb(136, 201, 142), rgb(78, 153, 209), rgb(213, 119, 63), rgb(141, 183, 202), rgb(222, 185, 71), rgb(164, 116, 207) }
	for i, color in colors do
		local x = -5.25 + (i - 1) * 2.1
		cylinder("SpecimenStand", Vector3.new(x, 3.7, 4.6), 1.55, 0.35, STEEL, true)
		local sample = block("ElementSpecimen", Vector3.new(1, 1.25, 1), CFrame.new(x, 4.5, 4.6) * CFrame.Angles(0, math.pi / 4, 0.3), color, Enum.Material.Glass)
		sample.Transparency = 0.12
	end
	block("SignFrame", Vector3.new(23, 3.8, 0.65), CFrame.new(0, 13.4, -8.6), green)
	local header = block("Sign", Vector3.new(22.4, 3.2, 0.22), CFrame.new(0, 13.4, -9.08), INK)
	sign(header, "CATASTROPHE ATLAS", "DISCOVER  /  COLLECT  /  MASTER", green)
	local console = block("Terminal", Vector3.new(5, 3.8, 2.4), CFrame.new(0, 2.4, -6.8), INK, METAL, true)
	terminal(console, "Atlas", "Catastrophe Atlas", green)
	local screen = block("ConsoleScreen", Vector3.new(4.3, 2.2, 0.15), CFrame.new(0, 3, -8.15), darkGreen, Enum.Material.SmoothPlastic)
	sign(screen, "YOUR DISCOVERIES", "OPEN THE FIELD GUIDE", green)
	-- An open book silhouette makes the kiosk recognizable without reading a sign.
	for _, side in { -1, 1 } do
		block("BookCover", Vector3.new(2.6, 0.24, 2.4), CFrame.new(side * 1.25, 4.45, -6.8) * CFrame.Angles(0, 0, side * -0.14), green)
		block("BookPages", Vector3.new(2.35, 0.18, 2.15), CFrame.new(side * 1.25, 4.66, -6.8) * CFrame.Angles(0, 0, side * -0.14), CREAM, Enum.Material.SmoothPlastic)
	end
	return console
end

return Landmarks
