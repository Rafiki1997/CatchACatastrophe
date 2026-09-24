--!strict
-- One player's city plot, built to the "Pocket Power Town" concept
-- (docs/art/plots/2026-09-21-player-plot/plot-v2-pocket-power-town.png).
--
-- The layout is not eyeballed: the concept's pad grid was detected, a ground
-- homography fitted to it, and every landmark measured back into plot studs.
-- The concept image is cropped about 8 studs short of the plot's front kerb,
-- so the entrance strip in front of the plaza is ours, built in the concept's
-- language. Numbers and the camera that reproduces the concept view are in
-- docs/art/plots/2026-09-21-player-plot/POCKET-POWER-TOWN-ASSET-REQUEST.md.
--
-- Local frame: the plot's front is local -Z, pointing at the hub. Standing on
-- the driveway looking into the plot, local +X is on your LEFT (the camera's
-- right vector is forward x up, which is -X). So the dispatch booth and the
-- water tower are on +X, the owner sign and the workshop on -X.
--
-- Two kinds of geometry live here:
--   * permanent parts: everything gameplay reads (pads, strips, vent button,
--     console, collect pad, billboard, spawn) plus collision cores, kerbs,
--     fences and banners;
--   * PropSites/<Site>/PlaceholderArt: the built-from-parts art, which Astra
--     replaces with sculpted meshes. PlotProps.apply swaps them for native
--     MeshParts when the PlotPropTemplates library exists, as the regions do.
--
-- This module does NOT use Kit.finalize: that helper is for creature models
-- and would weld every part to a root and clear CanCollide, which would drop
-- the player through the floor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local AssetSpec = require(script.Parent.PlotAssetSpec)
local PlotProps = require(script.Parent.PlotProps)

local PlotTemplate = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Pocket Power Town palette, sampled from the concept image.
local PAVING = rgb(146, 152, 176)
local PAVING_LIGHT = rgb(170, 174, 194)
local PLAZA = rgb(182, 179, 178)
local PLAZA_LIGHT = rgb(199, 195, 190)
local PAD_INSET = rgb(104, 108, 128)
local PAD_LOCKED = rgb(74, 78, 96)
local FRAME = rgb(176, 180, 198)
local FRAME_DARK = rgb(150, 155, 176)
local KERB = rgb(214, 204, 186)
local CREAM = rgb(238, 226, 202)
local SIGNFACE = rgb(246, 241, 228)
local TEAL = rgb(42, 108, 128)
local TEAL_LIGHT = rgb(70, 150, 166)
local TEAL_DARK = rgb(30, 80, 98)
local NAVY = rgb(46, 56, 72)
local YELLOW = rgb(244, 196, 72)
local GOLD = rgb(250, 212, 88)
local GOLD_DARK = rgb(206, 156, 58)
local BRICK = rgb(152, 88, 66)
local BRICK_DARK = rgb(124, 70, 54)
local ROOF_DARK = rgb(74, 78, 92)
local GLASS = rgb(150, 196, 210)
local LAMP = rgb(255, 236, 190)
local RED = rgb(232, 64, 54)
local LEAF = rgb(96, 140, 72)
local LEAF_DARK = rgb(66, 108, 58)
local LEAF_LIGHT = rgb(128, 168, 84)
local TRUNK = rgb(110, 84, 60)
local SOIL = rgb(88, 66, 48)
local STEEL = rgb(150, 156, 168)
local STONE = rgb(196, 192, 186)
local INK = rgb(46, 44, 52)
local HAZARD = rgb(255, 190, 50)
local STRIP_IDLE = rgb(92, 98, 122)
local SCREEN = rgb(48, 54, 74)
local ROCK = rgb(136, 138, 146)

local GRID = Config.Circuits.grid
local PAD_SPAN = 8 -- studs between pad centres
local PAD_SIZE = 5.4 -- the dark socket panel; the pale frame around it is 7.6
local PLATE = 7.6
local PAD_TOP = 1.1
local DECK = 0.5 -- the platform's top surface
local K = 29.3 -- centre line of the kerb and the fence

-- Measured from the concept (see the asset request doc).
local BOOTH = Vector3.new(20.0, 0, -19)
local SIGN = Vector3.new(-21.0, 0, -19)
local TOWER = Vector3.new(11.5, 0, 25.6)
local SHOP = Vector3.new(-9.2, 0, 26.4)
local PLAZA_AT = Vector3.new(0, 0, -18)

local UP = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's X axis turned vertical
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- X axis (or a disc's normal) turned along Z
local FACE_NEG_X = CFrame.Angles(0, math.rad(90), 0) -- a part's Front (-Z) turned to face -X
local FACE_POS_X = CFrame.Angles(0, math.rad(-90), 0)
local FACE_REAR = CFrame.Angles(0, math.rad(180), 0)

export type PartProps = {
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	collide: boolean?,
	shape: Enum.PartType?,
	touch: boolean?,
	query: boolean?,
	parent: Instance,
}

local function part(props: PartProps): Part
	local p = Instance.new("Part")
	p.Name = props.name
	p.Size = props.size
	p.CFrame = props.cf
	p.Color = props.color or PAVING
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Transparency = props.transparency or 0
	p.Anchored = true
	p.CanCollide = props.collide == true
	p.CanTouch = props.touch == true
	p.CanQuery = if props.query == nil then true else props.query
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.shape then
		p.Shape = props.shape
	end
	p.Parent = props.parent
	return p
end

-- Three families: SOLID collides (kerbs, fences, collision cores), DECO is
-- permanent dressing that never collides, ART is replaceable placeholder art
-- (never collides and never answers a raycast, so PlotProps may delete it).
type Maker = {
	box: (Instance, string, CFrame, Vector3, Color3, Enum.Material?) -> Part,
	cyl: (Instance, string, CFrame, number, number, Color3, Enum.Material?) -> Part,
	rod: (Instance, string, CFrame, number, number, Color3, Enum.Material?) -> Part,
	disc: (Instance, string, CFrame, number, number, Color3, Enum.Material?) -> Part,
	ball: (Instance, string, CFrame, Vector3, Color3, Enum.Material?) -> Part,
	wedge: (Instance, string, CFrame, Vector3, Color3, Enum.Material?) -> Part,
}

local function maker(collide: boolean, query: boolean): Maker
	local function make(props: PartProps): Part
		props.collide = collide
		props.query = query
		props.touch = false
		return part(props)
	end
	local M = {}
	function M.box(parent, name, cf, size, color, material)
		return make({ name = name, size = size, cf = cf, color = color, material = material, parent = parent })
	end
	-- a vertical cylinder `height` tall, centred on cf
	function M.cyl(parent, name, cf, height, diameter, color, material)
		return make({ name = name, size = Vector3.new(height, diameter, diameter), cf = cf * UP, color = color, material = material, shape = Enum.PartType.Cylinder, parent = parent })
	end
	-- a cylinder lying along the cf's own X axis
	function M.rod(parent, name, cf, length, diameter, color, material)
		return make({ name = name, size = Vector3.new(length, diameter, diameter), cf = cf, color = color, material = material, shape = Enum.PartType.Cylinder, parent = parent })
	end
	-- a flat disc whose faces look along the cf's Z
	function M.disc(parent, name, cf, thickness, diameter, color, material)
		return make({ name = name, size = Vector3.new(thickness, diameter, diameter), cf = cf * ALONG_Z, color = color, material = material, shape = Enum.PartType.Cylinder, parent = parent })
	end
	function M.ball(parent, name, cf, size, color, material)
		return make({ name = name, size = size, cf = cf, color = color, material = material, shape = Enum.PartType.Ball, parent = parent })
	end
	function M.wedge(parent, name, cf, size, color, material)
		return make({ name = name, size = size, cf = cf, color = color, material = material, shape = Enum.PartType.Wedge, parent = parent })
	end
	return (M :: any) :: Maker
end

local SOLID = maker(true, true)
local DECO = maker(false, true)
local ART = maker(false, false)

local function hide(p: BasePart): BasePart
	p.Transparency = 1
	return p
end

-- A run of alternating yellow/dark diagonal blocks: the company's house style.
local function hazardStrip(parent: Instance, origin: CFrame, length: number, height: number, thickness: number, query: boolean?, stripes: number?)
	local count = stripes or math.max(2, math.floor(length / 1.5))
	for i = 1, count do
		local x = -length / 2 + (i - 0.5) * (length / count)
		part({
			name = "Stripe",
			size = Vector3.new(length / count * 0.66, height, thickness),
			cf = origin * CFrame.new(x, 0, 0) * CFrame.Angles(0, 0, math.rad(28)),
			color = if i % 2 == 0 then HAZARD else INK,
			query = query == true,
			parent = parent,
		})
	end
end

local function surfaceLabel(host: BasePart, face: Enum.NormalId, text: string, size: number, color: Color3?, pixelsPerStud: number?): TextLabel
	local gui = host:FindFirstChild("Gui") :: SurfaceGui?
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "Gui"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = pixelsPerStud or 26
		gui.Parent = host
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = false
	label.TextSize = size
	label.TextWrapped = true
	label.TextColor3 = color or rgb(255, 252, 245)
	label.Text = text
	label.Parent = gui
	return label
end

-- A board whose whole front face is one scaled block of text.
local function boardText(host: BasePart, text: string, color: Color3, pixelsPerStud: number): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.Parent = host
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.9, 0.82)
	label.Position = UDim2.fromScale(0.05, 0.09)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	return label
end

local function pointLight(host: BasePart, color: Color3, range: number, brightness: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = host
	return light
end

-- Decorative spin for the client's SceneryAnimator: the part revolves about
-- the pivot's Z axis, keeping its authored pose relative to that pivot.
local function spin(p: BasePart, pivot: CFrame, speed: number, phase: number)
	p:SetAttribute("SceneryPivot", pivot)
	p:SetAttribute("SceneryOffset", pivot:Inverse() * p.CFrame)
	p:SetAttribute("SceneryMode", "Spin")
	p:SetAttribute("ScenerySpeed", speed)
	p:SetAttribute("SceneryPhase", phase)
	CollectionService:AddTag(p, "SceneryMotion")
end

-- The company's cat mark, facing the frame's -Z. Three parts.
local function catMark(parent: Instance, cf: CFrame, diameter: number, color: Color3)
	ART.disc(parent, "Emblem", cf, 0.12, diameter, color)
	for _, sx in { -1, 1 } do
		ART.wedge(parent, "EmblemEar", cf * CFrame.new(sx * diameter * 0.30, diameter * 0.33, 0) * CFrame.Angles(math.rad(180), 0, math.rad(sx * 18)),
			Vector3.new(diameter * 0.30, diameter * 0.34, 0.12), color)
	end
end

-- A lamp cage: the warm glass is Neon, the light itself lives on the host so
-- it survives the art swap.
local function lantern(parent: Instance, cf: CFrame, scale: number)
	-- the warm pane is the outermost piece, or the cage swallows its own glow
	ART.box(parent, "LanternBase", cf * CFrame.new(0, 0.09 * scale, 0), Vector3.new(0.94, 0.18, 0.94) * scale, NAVY)
	ART.box(parent, "LanternGlass", cf * CFrame.new(0, 0.62 * scale, 0), Vector3.new(0.78, 0.9, 0.78) * scale, LAMP, Enum.Material.Neon)
	ART.box(parent, "LanternCap", cf * CFrame.new(0, 1.16 * scale, 0), Vector3.new(1.08, 0.2, 1.08) * scale, NAVY)
end

local function shrub(parent: Instance, cf: CFrame, scale: number)
	ART.ball(parent, "Shrub", cf * CFrame.new(0, 0.62 * scale, 0), Vector3.new(1.7, 1.28, 1.7) * scale, LEAF)
	ART.ball(parent, "Shrub", cf * CFrame.new(0.72 * scale, 0.48 * scale, 0.28 * scale), Vector3.new(1.15, 1.0, 1.15) * scale, LEAF_LIGHT)
	ART.ball(parent, "Shrub", cf * CFrame.new(-0.68 * scale, 0.44 * scale, -0.24 * scale), Vector3.new(1.1, 0.92, 1.1) * scale, LEAF_DARK)
end

-- One asset site: the Model PlotProps reads, with its PlaceholderArt child.
-- `groundCF` is plot-local and bottom-centre; `base` is that frame in world
-- space, so the placeholder pieces are authored as base * offset.
local function site(sites: Instance, plotCF: CFrame, name: string, assetName: string, groundCF: CFrame, role: string, supportPath: string): (Model, CFrame)
	local size = AssetSpec[assetName]
	assert(size, "PlotTemplate: unknown plot asset " .. assetName)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("AssetName", assetName)
	m:SetAttribute("AssetSize", size)
	m:SetAttribute("GroundCF", groundCF)
	m:SetAttribute("PivotMode", "BottomCenter")
	m:SetAttribute("CollisionRole", "none")
	m:SetAttribute("PlacementRole", role)
	m:SetAttribute("SupportPath", supportPath)
	local artModel = Instance.new("Model")
	artModel.Name = "PlaceholderArt"
	artModel.Parent = m
	m.Parent = sites
	return artModel, plotCF * groundCF
end

export type Plot = {
	model: Model,
	index: number,
	cframe: CFrame,
	pads: { [number]: Part },
	padStrips: { [number]: Part },
	stations: { [number]: Folder },
	machines: Folder,
	booth: { model: Model, ventButton: Part, console: TextLabel },
	-- filled in by RemoteRouter.attachPrompts; CircuitService toggles it so the
	-- vent only offers itself while an Overdrive is actually running
	ventPrompt: ProximityPrompt?,
	collectPad: Part,
	collectLabel: TextLabel,
	billboardTitle: TextLabel,
	billboardEarnings: TextLabel,
	spawnPoint: SpawnLocation,
	visitorSpot: Part,
	decorTiers: { [number]: Model },
	rewards: Folder,
	garden: Model,
	propSites: Model,
}

-- Local offset of a pad's top-surface centre.
local function padOffset(pad: number): Vector3
	local col, row = Config.Circuits.padCoords(pad)
	local x = -((GRID.cols - 1) / 2) * PAD_SPAN + (col - 1) * PAD_SPAN
	local z = -6 + (row - 1) * PAD_SPAN
	return Vector3.new(x, PAD_TOP, z)
end

-- ============================================================ placeholder art

-- A socket plate: the pale frame the dark pad sits in, with an L bracket at
-- each corner of the opening, exactly as the concept draws them.
local function buildPadFrameArt(art: Model, base: CFrame)
	ART.box(art, "Frame", base * CFrame.new(0, 0.225, 0), Vector3.new(PLATE, 0.45, PLATE), FRAME)
	ART.box(art, "FrameInner", base * CFrame.new(0, 0.34, 0), Vector3.new(PAD_SIZE + 0.9, 0.2, PAD_SIZE + 0.9), FRAME_DARK)
	-- L brackets at the socket corners. The two arms abut rather than
	-- overlap, and stay under y 1.05 so no work station ever sits on one.
	local arm, thick, inset = 1.4, 0.32, PAD_SIZE / 2 + 0.2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			ART.box(art, "Bracket", base * CFrame.new(sx * (inset - arm / 2), 0.44, sz * inset), Vector3.new(arm, 0.16, thick), YELLOW)
			ART.box(art, "Bracket", base * CFrame.new(sx * inset, 0.44, sz * (inset - thick - (arm - thick) / 2)), Vector3.new(thick, 0.16, arm - thick), YELLOW)
		end
	end
end

local function buildCoinArt(art: Model, base: CFrame)
	ART.cyl(art, "CoinBase", base * CFrame.new(0, 0.11, 0), 0.22, 7.2, PLAZA_LIGHT)
	ART.cyl(art, "CoinRim", base * CFrame.new(0, 0.40, 0), 0.44, 6.5, GOLD_DARK, Enum.Material.Metal)
	ART.cyl(art, "Coin", base * CFrame.new(0, 0.47, 0), 0.40, 6.1, GOLD, Enum.Material.Metal)
	ART.cyl(art, "CoinFace", base * CFrame.new(0, 0.70, 0), 0.10, 5.2, rgb(252, 222, 112), Enum.Material.Metal)
	-- the cat mark is pressed into the top face, so it lies flat
	ART.cyl(art, "CoinMark", base * CFrame.new(0, 0.77, 0.1), 0.10, 2.5, GOLD_DARK, Enum.Material.Metal)
	for _, sx in { -1, 1 } do
		ART.wedge(art, "CoinMarkEar", base * CFrame.new(sx * 0.82, 0.77, -0.95) * CFrame.Angles(math.rad(-90), math.rad(sx * 20), 0),
			Vector3.new(0.78, 0.9, 0.1), GOLD_DARK, Enum.Material.Metal)
	end
end

-- The rounded dispatch kiosk: an octagonal glazed shell under a cream cap.
local function buildBoothArt(art: Model, base: CFrame)
	local W = 7.8
	ART.cyl(art, "Plinth", base * CFrame.new(0, 0.28, 0), 0.56, 8.6, NAVY)
	ART.cyl(art, "Sill", base * CFrame.new(0, 1.55, 0), 2.0, W + 0.3, TEAL)
	ART.cyl(art, "SillTrim", base * CFrame.new(0, 2.62, 0), 0.18, W + 0.5, CREAM)
	ART.cyl(art, "HeadTrim", base * CFrame.new(0, 4.66, 0), 0.2, W + 0.45, CREAM)
	-- eight glazed bays with cream mullions between them
	local half = W / 2
	for i = 0, 7 do
		local a = i * math.pi / 4
		local face = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 3.55, -half)
		ART.box(art, "Window", face * CFrame.new(0, 0, 0.04), Vector3.new(2.9, 1.9, 0.12), GLASS, Enum.Material.Glass)
		local post = base * CFrame.Angles(0, a + math.pi / 8, 0) * CFrame.new(0, 3.55, -half)
		ART.box(art, "Mullion", post, Vector3.new(0.36, 2.2, 0.36), CREAM)
	end
	-- what you can see through the glass
	ART.box(art, "Desk", base * CFrame.new(0, 2.9, 1.2), Vector3.new(4.4, 0.3, 2.2), rgb(120, 126, 142))
	ART.box(art, "Rack", base * CFrame.new(1.5, 3.7, 2.1), Vector3.new(1.8, 1.4, 0.7), SCREEN)
	ART.box(art, "Monitor", base * CFrame.new(-1.3, 3.7, 1.6), Vector3.new(1.5, 1.0, 0.18), rgb(96, 186, 200), Enum.Material.Neon)
	-- counter shelf on the face that looks at the plaza (local -X)
	ART.box(art, "Counter", base * CFrame.new(-half - 0.35, 2.78, 0), Vector3.new(1.2, 0.26, 3.6), CREAM)
	-- cream cap: brim, step, dome
	ART.cyl(art, "RoofBrim", base * CFrame.new(0, 4.96, 0), 0.5, 9.0, CREAM)
	ART.cyl(art, "RoofStep", base * CFrame.new(0, 5.36, 0), 0.4, 7.6, CREAM)
	ART.ball(art, "RoofDome", base * CFrame.new(0, 5.5, 0), Vector3.new(6.2, 1.7, 6.2), CREAM)
	ART.ball(art, "RoofFinial", base * CFrame.new(0, 6.42, 0), Vector3.new(0.62, 0.62, 0.62), YELLOW)
	-- the DISPATCH board across the front of the brim
	ART.box(art, "SignBoard", base * CFrame.new(0, 5.9, -4.3), Vector3.new(5.4, 1.3, 0.3), TEAL)
	ART.box(art, "SignBoardTrim", base * CFrame.new(0, 5.9, -4.43), Vector3.new(5.65, 1.5, 0.12), CREAM)
	-- the grey utility cabinet bolted to the plaza side
	ART.box(art, "Cabinet", base * CFrame.new(-3.9, 1.55, -0.6), Vector3.new(2.0, 2.1, 3.0), rgb(104, 110, 124))
	ART.box(art, "CabinetLid", base * CFrame.new(-3.9, 2.72, -0.6), Vector3.new(2.2, 0.3, 3.3), rgb(84, 90, 104))
	for i = 1, 3 do
		ART.box(art, "CabinetVent", base * CFrame.new(-3.9, 1.2 + i * 0.35, -2.16), Vector3.new(1.5, 0.16, 0.1), rgb(70, 76, 90))
	end
	ART.cyl(art, "Bollard", base * CFrame.new(4.6, 0.95, -2.4), 1.9, 0.5, YELLOW)
end

-- The municipal owner sign: a brick plinth, an arched teal board with a gold
-- trim following the arch, and planting along the base.
local function buildOwnerSignArt(art: Model, base: CFrame)
	ART.box(art, "PlinthBrick", base * CFrame.new(0, 0.85, 0), Vector3.new(11.6, 1.7, 2.4), BRICK, Enum.Material.Brick)
	ART.box(art, "PlinthCourse", base * CFrame.new(0, 1.05, 0), Vector3.new(11.75, 0.16, 2.55), BRICK_DARK, Enum.Material.Brick)
	ART.box(art, "PlinthCap", base * CFrame.new(0, 1.86, 0), Vector3.new(12.2, 0.32, 2.9), KERB)
	for _, sx in { -1, 1 } do
		ART.box(art, "PlinthEnd", base * CFrame.new(sx * 5.4, 1.2, 0), Vector3.new(1.4, 2.4, 2.7), STONE)
		ART.box(art, "PlinthEndCap", base * CFrame.new(sx * 5.4, 2.48, 0), Vector3.new(1.7, 0.26, 3.0), KERB)
		ART.box(art, "SignPost", base * CFrame.new(sx * 4.6, 3.4, 0.7), Vector3.new(0.42, 3.4, 0.42), NAVY)
	end
	-- board: a rectangle crowned by an arch, each layer a little further
	-- forward so the gold reads as a rim around the cream face
	ART.box(art, "Frame", base * CFrame.new(0, 3.75, -0.12), Vector3.new(11.0, 3.4, 0.5), TEAL)
	ART.box(art, "FrameTrim", base * CFrame.new(0, 3.75, -0.4), Vector3.new(11.3, 3.5, 0.16), YELLOW)
	for i = 1, 7 do
		local x = -4.2 + (i - 1) * 1.4
		local rise = 2.1 * math.cos(x / 6.1 * (math.pi / 2))
		ART.box(art, "Arch", base * CFrame.new(x, (5.15 + 5.45 + rise) / 2, -0.12), Vector3.new(1.42, 5.45 + rise - 5.15, 0.5), TEAL)
		ART.box(art, "ArchTrim", base * CFrame.new(x, (5.25 + 5.47 + rise) / 2, -0.4), Vector3.new(1.44, 5.47 + rise - 5.25, 0.16), YELLOW)
		ART.box(art, "ArchFace", base * CFrame.new(x, (5.2 + 5.0 + rise) / 2, -0.52), Vector3.new(1.42, 5.0 + rise - 5.2, 0.14), SIGNFACE)
	end
	for _, sx in { -1, 1 } do
		ART.box(art, "TrimPost", base * CFrame.new(sx * 5.42, 4.0, -0.32), Vector3.new(0.46, 4.2, 0.36), YELLOW)
		ART.ball(art, "TrimScroll", base * CFrame.new(sx * 5.42, 6.2, -0.32), Vector3.new(0.9, 0.9, 0.5), YELLOW)
	end
	-- the shield and cat mark on the crown
	ART.box(art, "Crest", base * CFrame.new(0, 6.35, -0.58), Vector3.new(2.5, 2.1, 0.22), TEAL_DARK)
	ART.box(art, "CrestTrim", base * CFrame.new(0, 6.35, -0.52), Vector3.new(2.8, 2.35, 0.14), YELLOW)
	catMark(art, base * CFrame.new(0, 6.4, -0.72), 1.55, SIGNFACE)
	-- planting along the front of the plinth
	for i, dx in { -4.2, -1.4, 1.4, 4.2 } do
		shrub(art, base * CFrame.new(dx, 0, -2.3), if i % 2 == 0 then 0.95 else 1.15)
	end
	for i, dx in { -3.0, -0.2, 2.6, 5.0 } do
		local tint = if i % 3 == 0 then rgb(250, 130, 170) elseif i % 3 == 1 then rgb(248, 244, 236) else YELLOW
		ART.ball(art, "Bloom", base * CFrame.new(dx, 0.5, -3.0), Vector3.new(0.42, 0.42, 0.42), tint)
	end
end

-- Teal tank on splayed braced legs, yellow domed cap.
local function buildWaterTowerArt(art: Model, base: CFrame)
	local foot, head, legH = 1.85, 1.15, 7.2
	local lean = math.atan((foot - head) / legH)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local mid = base * CFrame.new(sx * (foot + head) / 2, legH / 2, sz * (foot + head) / 2)
			ART.box(art, "Leg", mid * CFrame.Angles(-sz * lean, 0, sx * lean), Vector3.new(0.52, legH + 0.3, 0.52), NAVY)
			ART.box(art, "LegFoot", base * CFrame.new(sx * foot, 0.16, sz * foot), Vector3.new(1.0, 0.32, 1.0), CREAM)
		end
	end
	for _, y in { 2.7, 5.4 } do
		local r = foot - (foot - head) * (y / legH)
		for _, sz in { -1, 1 } do
			ART.box(art, "Brace", base * CFrame.new(0, y, sz * r), Vector3.new(r * 2, 0.22, 0.22), NAVY)
			ART.box(art, "Brace", base * CFrame.new(sz * r, y + 0.26, 0), Vector3.new(0.22, 0.22, r * 2), NAVY)
		end
	end
	-- X bracing on the two faces that read against the sky
	for _, sz in { -1, 1 } do
		for _, dir in { -1, 1 } do
			ART.box(art, "XBrace", base * CFrame.new(0, 4.05, sz * (1.45 + dir * 0.1)) * CFrame.Angles(0, 0, dir * math.rad(56)),
				Vector3.new(0.16, 5.6, 0.16), NAVY)
		end
	end
	ART.cyl(art, "Tank", base * CFrame.new(0, 9.9, 0), 4.5, 5.3, TEAL)
	for i = 1, 8 do
		local a = (i - 1) * math.pi / 4
		ART.box(art, "TankRib", base * CFrame.new(math.sin(a) * 2.66, 9.9, math.cos(a) * 2.66) * CFrame.Angles(0, a, 0),
			Vector3.new(0.2, 4.3, 0.2), TEAL_LIGHT)
	end
	ART.cyl(art, "TankBand", base * CFrame.new(0, 7.85, 0), 0.34, 5.5, NAVY)
	ART.cyl(art, "TankBand", base * CFrame.new(0, 11.9, 0), 0.34, 5.5, NAVY)
	ART.ball(art, "Cap", base * CFrame.new(0, 12.1, 0), Vector3.new(5.7, 3.3, 5.7), YELLOW)
	ART.cyl(art, "CapCollar", base * CFrame.new(0, 12.25, 0), 0.3, 5.9, GOLD_DARK)
	ART.cyl(art, "Finial", base * CFrame.new(0, 14.05, 0), 0.6, 0.28, YELLOW)
	ART.ball(art, "FinialTop", base * CFrame.new(0, 14.45, 0), Vector3.new(0.6, 0.6, 0.6), YELLOW)
	catMark(art, base * CFrame.new(0, 10.1, -2.68), 2.3, CREAM)
	-- downpipe round the back into the yard main
	ART.cyl(art, "Downpipe", base * CFrame.new(0.0, 5.0, 2.5), 6.0, 0.6, TEAL_LIGHT)
	ART.ball(art, "PipeElbow", base * CFrame.new(0.0, 2.1, 2.5), Vector3.new(0.85, 0.85, 0.85), TEAL_LIGHT)
	ART.rod(art, "PipeStub", base * CFrame.new(-0.95, 2.1, 2.5), 1.9, 0.6, TEAL_LIGHT)
end

-- Brick utility workshop with a stone parapet, roller door and chimney.
local function buildWorkshopArt(art: Model, base: CFrame)
	local w, d = 15.4, 5.5
	ART.box(art, "Walls", base * CFrame.new(0, 3.05, 0), Vector3.new(w, 5.1, d), BRICK, Enum.Material.Brick)
	ART.box(art, "Plinth", base * CFrame.new(0, 0.3, 0), Vector3.new(w + 0.4, 0.6, d + 0.3), NAVY)
	for i = 1, 3 do
		ART.box(art, "Course", base * CFrame.new(0, 1.2 + (i - 1) * 1.5, 0), Vector3.new(w + 0.06, 0.12, d + 0.06), BRICK_DARK, Enum.Material.Brick)
	end
	-- the stone end block the concept puts on the -X third
	ART.box(art, "StoneEnd", base * CFrame.new(-w / 2 + 1.7, 3.2, 0), Vector3.new(3.4, 5.4, d + 0.12), STONE, Enum.Material.Concrete)
	ART.box(art, "Parapet", base * CFrame.new(0, 5.92, 0), Vector3.new(w + 0.44, 0.54, d + 0.44), STONE, Enum.Material.Concrete)
	ART.box(art, "ParapetLip", base * CFrame.new(0, 6.26, 0), Vector3.new(w + 0.7, 0.18, d + 0.7), CREAM)
	ART.box(art, "Roof", base * CFrame.new(0, 5.78, 0), Vector3.new(w - 0.2, 0.34, d - 0.2), ROOF_DARK)
	ART.box(art, "RoofUnit", base * CFrame.new(-2.6, 6.5, 0.9), Vector3.new(2.2, 1.0, 1.9), STEEL)
	ART.box(art, "RoofUnitCap", base * CFrame.new(-2.6, 7.06, 0.9), Vector3.new(2.45, 0.16, 2.15), rgb(84, 90, 104))
	ART.box(art, "Chimney", base * CFrame.new(-6.5, 7.3, 1.4), Vector3.new(1.7, 3.8, 1.7), BRICK, Enum.Material.Brick)
	ART.box(art, "ChimneyCap", base * CFrame.new(-6.5, 9.3, 1.4), Vector3.new(2.0, 0.3, 2.0), NAVY)
	-- roller door
	local front = -d / 2 - 0.02
	ART.box(art, "DoorSurround", base * CFrame.new(2.2, 2.35, front - 0.1), Vector3.new(5.4, 4.3, 0.24), CREAM)
	ART.box(art, "GarageDoor", base * CFrame.new(2.2, 2.25, front - 0.3), Vector3.new(4.6, 3.7, 0.22), ROOF_DARK)
	for i = 1, 5 do
		ART.box(art, "DoorSlat", base * CFrame.new(2.2, 0.75 + (i - 1) * 0.76, front - 0.44), Vector3.new(4.5, 0.12, 0.08), rgb(96, 100, 116))
	end
	-- side door and windows
	ART.box(art, "SideTrim", base * CFrame.new(-2.1, 2.05, front - 0.1), Vector3.new(2.0, 3.5, 0.18), CREAM)
	ART.box(art, "SideDoor", base * CFrame.new(-2.1, 1.95, front - 0.26), Vector3.new(1.5, 3.1, 0.18), NAVY)
	for _, spec in { { 6.2, LAMP, Enum.Material.Neon }, { -5.4, GLASS, Enum.Material.Glass } } do
		local x = spec[1] :: number
		ART.box(art, "WindowTrim", base * CFrame.new(x, 3.6, front - 0.08), Vector3.new(2.3, 1.9, 0.16), CREAM)
		ART.box(art, "Window", base * CFrame.new(x, 3.6, front - 0.24), Vector3.new(1.8, 1.4, 0.16), spec[2] :: Color3, spec[3] :: Enum.Material)
		ART.box(art, "WindowBar", base * CFrame.new(x, 3.6, front - 0.34), Vector3.new(0.12, 1.5, 0.08), CREAM)
	end
	catMark(art, base * CFrame.new(4.6, 4.5, front - 0.22), 1.9, CREAM)
	-- wall lanterns beside the door
	for _, dx in { 0.2, 7.0 } do
		ART.box(art, "LampBracket", base * CFrame.new(dx, 4.2, front - 0.22), Vector3.new(0.26, 0.26, 0.5), NAVY)
		ART.box(art, "LampHead", base * CFrame.new(dx, 4.12, front - 0.48), Vector3.new(0.66, 0.78, 0.66), NAVY)
		ART.box(art, "LampGlass", base * CFrame.new(dx, 4.12, front - 0.48), Vector3.new(0.46, 0.58, 0.46), LAMP, Enum.Material.Neon)
	end
	-- the yard clutter the concept parks against the wall
	ART.box(art, "Toolbox", base * CFrame.new(0.5, 1.05, front - 0.95), Vector3.new(1.5, 1.9, 1.2), rgb(58, 116, 156))
	ART.box(art, "ToolboxLid", base * CFrame.new(0.5, 2.1, front - 0.95), Vector3.new(1.7, 0.26, 1.4), rgb(44, 92, 128))
	for i, spec in { { -6.3, 1.1 }, { -5.0, 0.85 }, { 8.2, 1.0 } } do
		local s = spec[2] :: number
		ART.box(art, "Crate", base * CFrame.new(spec[1] :: number, s / 2, front - 0.75), Vector3.new(s, s, s), rgb(164, 124, 82), Enum.Material.WoodPlanks)
		ART.box(art, "CrateBand", base * CFrame.new(spec[1] :: number, s / 2, front - 0.75 - s / 2 - 0.03), Vector3.new(s * 0.94, s * 0.16, 0.06), rgb(124, 92, 60))
		local _ = i
	end
	ART.cyl(art, "YardBollard", base * CFrame.new(1.9, 0.85, front - 0.95), 1.7, 0.46, YELLOW)
end

local function buildLanternArt(art: Model, base: CFrame)
	lantern(art, base, 1.0)
end

-- A chunky yard main: pipe, two flanges and a stand.
local function buildPipeRunArt(art: Model, base: CFrame)
	ART.rod(art, "Pipe", base * CFrame.new(0, 1.9, 0), 10, 1.05, TEAL)
	for _, dx in { -3.4, 3.4 } do
		ART.rod(art, "Flange", base * CFrame.new(dx, 1.9, 0), 0.42, 1.38, YELLOW)
	end
	ART.box(art, "PipeStand", base * CFrame.new(0, 0.68, 0), Vector3.new(0.5, 1.36, 0.5), NAVY)
	ART.box(art, "PipeSaddle", base * CFrame.new(0, 1.42, 0), Vector3.new(1.1, 0.3, 1.1), NAVY)
end

local function buildPipeElbowArt(art: Model, base: CFrame)
	ART.ball(art, "ElbowJoint", base * CFrame.new(0, 1.9, 0), Vector3.new(1.4, 1.4, 1.4), TEAL)
	ART.cyl(art, "ElbowRiser", base * CFrame.new(0, 1.0, 0), 1.9, 1.05, TEAL)
	ART.rod(art, "ElbowFlange", base * CFrame.new(0, 2.66, 0), 0.4, 1.38, YELLOW)
	ART.box(art, "ElbowStand", base * CFrame.new(0, 0.28, 0), Vector3.new(1.3, 0.56, 1.3), NAVY)
end

local function buildShrubArt(art: Model, base: CFrame)
	shrub(art, base, 1.0)
end

local function buildFlowerBedArt(art: Model, base: CFrame)
	ART.box(art, "Planter", base * CFrame.new(0, 0.28, 0), Vector3.new(2.6, 0.56, 1.7), KERB)
	ART.box(art, "PlanterLip", base * CFrame.new(0, 0.6, 0), Vector3.new(2.8, 0.14, 1.9), STONE)
	ART.box(art, "Soil", base * CFrame.new(0, 0.7, 0), Vector3.new(2.2, 0.14, 1.3), SOIL)
	for i, dx in { -0.75, 0, 0.75 } do
		local tint = if i == 1 then rgb(250, 130, 170) elseif i == 2 then YELLOW else rgb(248, 244, 236)
		ART.ball(art, "Bloom", base * CFrame.new(dx, 0.96, (i - 2) * 0.32), Vector3.new(0.5, 0.5, 0.5), tint)
		ART.ball(art, "Leafage", base * CFrame.new(dx, 0.82, (i - 2) * 0.32), Vector3.new(0.7, 0.4, 0.7), LEAF)
	end
end

local function buildTreeArt(art: Model, base: CFrame)
	ART.cyl(art, "Trunk", base * CFrame.new(0, 2.1, 0), 4.2, 1.3, TRUNK, Enum.Material.Wood)
	ART.ball(art, "Canopy", base * CFrame.new(0, 6.3, 0), Vector3.new(6.6, 5.8, 6.6), LEAF_DARK)
	ART.ball(art, "Canopy", base * CFrame.new(1.7, 7.4, 1.2), Vector3.new(4.8, 4.2, 4.8), LEAF)
	ART.ball(art, "Canopy", base * CFrame.new(-1.6, 7.7, -1.1), Vector3.new(4.4, 3.8, 4.4), LEAF_LIGHT)
	ART.ball(art, "Canopy", base * CFrame.new(0.3, 8.7, -0.4), Vector3.new(3.4, 2.8, 3.4), LEAF)
end

-- ============================================================ build

function PlotTemplate.build(cframe: CFrame, index: number): Plot
	local model = Instance.new("Model")
	model.Name = "Plot_" .. tostring(index)
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")

	local at = function(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end

	local propSites = Instance.new("Model")
	propSites.Name = "PropSites"
	propSites:SetAttribute("AssetKit", "PocketPowerTown")
	propSites:SetAttribute("AssetOrigin", "bottom-centre")
	propSites.Parent = model
	local siteCount = 0
	local function addSite(name: string, assetName: string, groundCF: CFrame, role: string, supportPath: string, builder: (Model, CFrame) -> ())
		siteCount += 1
		local art, base = site(propSites, cframe, name, assetName, groundCF, role, supportPath)
		builder(art, base)
	end

	-- ---------------------------------------------------------------- ground
	local platform = part({ name = "Platform", size = Vector3.new(60, 1, 60), cf = at(0, 0, 0), color = PAVING, material = Enum.Material.Concrete, collide = true, parent = model })
	model.PrimaryPart = platform
	-- entrance apron so the spawn point is on solid ground; the driveway ends at its front edge
	part({ name = "Apron", size = Vector3.new(22, 1, 14), cf = at(0, 0, -36), color = PAVING_LIGHT, material = Enum.Material.Concrete, collide = true, parent = model })
	-- ivory kerb around the platform edge, open at the entrance
	for _, spec in
		{
			{ Vector3.new(60.0, 0.8, 1.5), Vector3.new(0, 0.85, K) },
			{ Vector3.new(1.5, 0.8, 57.1), Vector3.new(K, 0.85, 0) },
			{ Vector3.new(1.5, 0.8, 57.1), Vector3.new(-K, 0.85, 0) },
			{ Vector3.new(19.4, 0.8, 1.5), Vector3.new(20.3, 0.85, -K) },
			{ Vector3.new(19.4, 0.8, 1.5), Vector3.new(-20.3, 0.85, -K) },
		}
	do
		part({ name = "Kerb", size = spec[1], cf = at(spec[2].X, spec[2].Y, spec[2].Z), color = KERB, material = Enum.Material.Concrete, collide = true, parent = model })
	end
	-- the entrance: a broad threshold with two shallow treads down to the drive
	part({ name = "Threshold", size = Vector3.new(21.2, 0.14, 2.4), cf = at(0, 0.5, -29.6), color = KERB, material = Enum.Material.Concrete, parent = model })
	part({ name = "Threshold", size = Vector3.new(22.4, 0.1, 1.5), cf = at(0, 0.5, -31.5), color = STONE, material = Enum.Material.Concrete, parent = model })
	for _, sx in { -1, 1 } do
		hazardStrip(model, at(sx * 13.9, 0.98, -29.9), 6.4, 0.52, 0.16)
	end

	-- ---------------------------------------------------------------- pads
	local padFolder = Instance.new("Folder")
	padFolder.Name = "Pads"
	padFolder.Parent = model
	local stationFolder = Instance.new("Folder")
	stationFolder.Name = "Stations"
	stationFolder.Parent = model

	local pads: { [number]: Part } = {}
	local padStrips: { [number]: Part } = {}
	local stations: { [number]: Folder } = {}
	for pad = 1, Config.Circuits.maxPads do
		local o = padOffset(pad)
		local p = part({
			name = "Pad_" .. tostring(pad),
			size = Vector3.new(PAD_SIZE, 0.6, PAD_SIZE),
			cf = at(o.X, o.Y - 0.3, o.Z),
			color = PAD_INSET,
			material = Enum.Material.Metal,
			collide = true,
			parent = padFolder,
		})
		p:SetAttribute("PadIndex", pad)
		p:SetAttribute("Unlocked", false)
		-- Manage the creature from the pad. Disabled here; the owner's client
		-- enables and labels it (Controllers.PadPrompts). The server never reads
		-- it: the picker fires the ordinary Deploy / Move / Store remotes.
		local manage = Instance.new("ProximityPrompt")
		manage.Name = "ManagePrompt"
		manage.ActionText = "Deploy"
		manage.ObjectText = "Pad " .. tostring(pad)
		manage.KeyboardKeyCode = Enum.KeyCode.E
		manage.HoldDuration = 0
		manage.RequiresLineOfSight = false
		manage.MaxActivationDistance = 7 -- pads sit 8 apart, so only the one you stand at shows
		manage.Enabled = false
		manage.Parent = p
		-- the lit strip along the pad's front edge: dim until a creature stands
		-- here, then its element colour (CityService.refreshPad)
		padStrips[pad] = part({
			name = "Strip",
			size = Vector3.new(3.4, 0.12, 0.3),
			cf = at(o.X, 0.96, o.Z - PAD_SIZE / 2 - 0.52),
			color = STRIP_IDLE,
			query = false,
			parent = p,
		})
		-- pad number on the deck
		local num = surfaceLabel(p, Enum.NormalId.Top, tostring(pad), 22, rgb(214, 220, 238))
		num.Name = "PadNumber"
		num.Rotation = 0
		-- the pale socket plate with its yellow corner brackets is replaceable art
		addSite("PadFrame_" .. tostring(pad), "PP_Pad_Frame", CFrame.new(o.X, DECK + 0.02, o.Z), "Grounded", "Platform", buildPadFrameArt)

		local sf = Instance.new("Folder")
		sf.Name = "Station_" .. tostring(pad)
		sf.Parent = stationFolder
		stations[pad] = sf
		pads[pad] = p
	end

	local machines = Instance.new("Folder")
	machines.Name = "Machines"
	machines.Parent = model

	-- ---------------------------------------------------------------- coin plaza
	local pz = PLAZA_AT.Z
	part({ name = "Plaza", size = Vector3.new(12.4, 0.36, 11.6), cf = at(0, 0.66, pz), color = PLAZA, material = Enum.Material.Concrete, parent = model })
	part({ name = "Plaza", size = Vector3.new(13.6, 0.3, 12.8), cf = at(0, 0.49, pz), color = KERB, material = Enum.Material.Concrete, parent = model })
	part({ name = "Plaza", size = Vector3.new(10.2, 0.16, 9.4), cf = at(0, 0.88, pz), color = PLAZA_LIGHT, material = Enum.Material.Concrete, parent = model })
	-- the collection pad itself: the square inner tier the coin stands on
	local collectPad = part({
		name = "CollectPad",
		size = Vector3.new(8.4, 0.34, 8.4),
		cf = at(0, 1.05, pz),
		color = PLAZA_LIGHT,
		material = Enum.Material.Concrete,
		collide = false,
		touch = true,
		parent = model,
	})
	collectPad:SetAttribute("Touch", "Collect")
	addSite("CoinPlatform", "PP_Coin_Platform", CFrame.new(0, 1.20, pz), "Stacked", "CollectPad", buildCoinArt)
	-- warm bars let into the tier around the coin
	for _, spot in { Vector3.new(0, 0, 3.95), Vector3.new(0, 0, -3.95), Vector3.new(3.95, 0, 0), Vector3.new(-3.95, 0, 0) } do
		local along = if math.abs(spot.X) > 0 then Vector3.new(0.34, 0.1, 2.6) else Vector3.new(2.6, 0.1, 0.34)
		part({ name = "PlazaLight", size = along, cf = at(spot.X, 1.25, pz + spot.Z), color = LAMP, material = Enum.Material.Neon, query = false, parent = model })
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part({ name = "PlazaLight", size = Vector3.new(0.5, 0.1, 0.5), cf = at(sx * 3.5, 1.25, pz + sz * 3.5), color = LAMP, material = Enum.Material.Neon, query = false, parent = model })
		end
	end
	-- brick piers at the plaza's back corners, pale piers at its front corners
	local lanternIndex = 0
	for _, sx in { -1, 1 } do
		local pier = SOLID.box(model, "PlazaPier", at(sx * 6.9, 2.0, pz + 4.6), Vector3.new(2.3, 3.0, 2.3), BRICK, Enum.Material.Brick)
		local _ = pier
		local cap = DECO.box(model, "PlazaPierCap", at(sx * 6.9, 3.65, pz + 4.6), Vector3.new(2.7, 0.3, 2.7), KERB)
		pointLight(cap, rgb(255, 224, 176), 15, 0.8)
		lanternIndex += 1
		addSite("Lantern_" .. tostring(lanternIndex), "PP_Lantern", CFrame.new(sx * 6.9, 3.8, pz + 4.6), "Stacked", "PlazaPierCap", buildLanternArt)
		local front = SOLID.box(model, "PlazaPost", at(sx * 6.9, 1.6, pz - 5.0), Vector3.new(2.1, 2.2, 2.1), STONE, Enum.Material.Concrete)
		local _ = front
		local frontCap = DECO.box(model, "PlazaPostCap", at(sx * 6.9, 2.83, pz - 5.0), Vector3.new(2.4, 0.26, 2.4), KERB)
		pointLight(frontCap, rgb(255, 224, 176), 13, 0.7)
		lanternIndex += 1
		addSite("Lantern_" .. tostring(lanternIndex), "PP_Lantern", CFrame.new(sx * 6.9, 2.96, pz - 5.0), "Stacked", "PlazaPostCap", buildLanternArt)
		-- hazard chevrons down the plaza's outer flanks
		hazardStrip(model, at(sx * 7.05, 1.0, pz - 0.2) * FACE_NEG_X, 7.6, 0.62, 0.16)
	end
	-- two treads down at the plaza front
	part({ name = "PlazaStep", size = Vector3.new(11.0, 0.3, 1.4), cf = at(0, 0.62, pz - 7.2), color = PLAZA, material = Enum.Material.Concrete, collide = true, parent = model })
	part({ name = "PlazaStep", size = Vector3.new(12.0, 0.2, 1.3), cf = at(0, 0.54, pz - 8.4), color = KERB, material = Enum.Material.Concrete, collide = true, parent = model })

	local collectBillboard = Instance.new("BillboardGui")
	collectBillboard.Name = "Label"
	collectBillboard.Size = UDim2.fromScale(9, 2.4)
	collectBillboard.StudsOffsetWorldSpace = Vector3.new(0, 4.8, 0)
	collectBillboard.MaxDistance = 160
	collectBillboard.AlwaysOnTop = false
	collectBillboard.Parent = collectPad
	local collectLabel = Instance.new("TextLabel")
	collectLabel.Name = "Text"
	collectLabel.BackgroundTransparency = 1
	collectLabel.Size = UDim2.fromScale(1, 1)
	collectLabel.Font = Enum.Font.FredokaOne
	collectLabel.TextScaled = true
	collectLabel.TextColor3 = rgb(255, 252, 245)
	collectLabel.TextStrokeTransparency = 0.2
	collectLabel.TextStrokeColor3 = INK
	collectLabel.Text = "Bank: 0"
	collectLabel.Parent = collectBillboard

	-- ---------------------------------------------------------------- booth (front, +X)
	local booth = Instance.new("Model")
	booth.Name = "Booth"
	booth.Parent = model
	hide(SOLID.cyl(booth, "BoothCore", at(BOOTH.X, 2.7, BOOTH.Z), 4.4, 8.0, TEAL))
	-- console with a text screen, on the face that looks at the plaza
	local console = DECO.box(booth, "Console", at(BOOTH.X - 4.35, 3.55, BOOTH.Z), Vector3.new(0.26, 1.7, 3.4), SCREEN)
	local consoleLabel = surfaceLabel(console, Enum.NormalId.Left, "No circuits running", 14, rgb(190, 245, 255), 44)
	consoleLabel.Name = "Text"
	-- the vent: a domed red mushroom on a hazard-striped plinth at the kerbside
	local ventX, ventZ = BOOTH.X - 3.6, BOOTH.Z - 4.1
	SOLID.box(booth, "VentBase", at(ventX, 1.05, ventZ), Vector3.new(2.4, 1.1, 2.3), rgb(150, 152, 160), Enum.Material.Concrete)
	hazardStrip(booth, at(ventX, 1.02, ventZ - 1.21), 2.3, 0.86, 0.14, false, 4)
	DECO.box(booth, "VentCollar", at(ventX, 1.68, ventZ), Vector3.new(2.0, 0.26, 1.8), INK)
	local ventButton = DECO.ball(booth, "VentButton", at(ventX, 1.86, ventZ), Vector3.new(1.75, 1.2, 1.55), RED, Enum.Material.SmoothPlastic)
	ventButton:SetAttribute("Prompt", "Vent")
	-- the DISPATCH lettering survives the art swap on its own invisible board
	local dispatchLabel = hide(DECO.box(booth, "DispatchLabel", at(BOOTH.X, 6.4, BOOTH.Z - 4.52), Vector3.new(4.7, 0.95, 0.05), TEAL))
	boardText(dispatchLabel, "DISPATCH", CREAM, 44)
	addSite("DispatchBooth", "PP_Dispatch_Booth", CFrame.new(BOOTH.X, DECK, BOOTH.Z), "Grounded", "Platform", buildBoothArt)

	-- ---------------------------------------------------------------- owner sign (front, -X)
	hide(SOLID.box(model, "SignCore", at(SIGN.X, 1.6, SIGN.Z), Vector3.new(12.2, 2.2, 2.6), TEAL))
	local board = DECO.box(model, "Billboard", at(SIGN.X, 3.85, SIGN.Z - 0.52), Vector3.new(10.2, 2.9, 0.22), SIGNFACE)
	local boardGui = Instance.new("SurfaceGui")
	boardGui.Name = "Gui"
	boardGui.Face = Enum.NormalId.Front
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	boardGui.PixelsPerStud = 44
	boardGui.Parent = board
	local billboardTitle = Instance.new("TextLabel")
	billboardTitle.Name = "Title"
	billboardTitle.BackgroundTransparency = 1
	billboardTitle.Size = UDim2.fromScale(0.94, 0.6)
	billboardTitle.Position = UDim2.fromScale(0.03, 0.04)
	billboardTitle.Font = Enum.Font.FredokaOne
	billboardTitle.TextScaled = true
	billboardTitle.TextColor3 = TEAL_DARK
	billboardTitle.Text = "Vacant Lot"
	billboardTitle.Parent = boardGui
	local billboardEarnings = Instance.new("TextLabel")
	billboardEarnings.Name = "Earnings"
	billboardEarnings.BackgroundTransparency = 1
	billboardEarnings.Size = UDim2.fromScale(0.94, 0.3)
	billboardEarnings.Position = UDim2.fromScale(0.03, 0.66)
	billboardEarnings.Font = Enum.Font.FredokaOne
	billboardEarnings.TextScaled = true
	billboardEarnings.TextColor3 = GOLD_DARK
	billboardEarnings.Text = "0/s"
	billboardEarnings.Parent = boardGui
	addSite("OwnerSign", "PP_Owner_Sign", CFrame.new(SIGN.X, DECK, SIGN.Z), "Grounded", "Platform", buildOwnerSignArt)

	-- ---------------------------------------------------------------- water tower (rear, +X)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			hide(SOLID.box(model, "TowerLeg", at(TOWER.X + sx * 1.5, 4.3, TOWER.Z + sz * 1.5), Vector3.new(0.9, 7.6, 0.9), NAVY))
		end
	end
	DECO.cyl(model, "VaneAxle", at(TOWER.X, 15.1, TOWER.Z), 0.6, 0.16, NAVY)
	local vane = DECO.box(model, "Windvane", at(TOWER.X + 0.5, 15.45, TOWER.Z), Vector3.new(1.7, 0.12, 0.34), YELLOW)
	spin(vane, at(TOWER.X, 15.45, TOWER.Z) * CFrame.Angles(math.rad(90), 0, 0), 1.2, 0)
	addSite("WaterTower", "PP_Water_Tower", CFrame.new(TOWER.X, DECK, TOWER.Z), "Grounded", "Platform", buildWaterTowerArt)

	-- ---------------------------------------------------------------- workshop (rear, -X)
	hide(SOLID.box(model, "WorkshopCore", at(SHOP.X, 3.4, SHOP.Z), Vector3.new(15.4, 5.8, 5.5), BRICK))
	for _, dx in { 0.2, 7.0 } do
		local anchor = hide(DECO.box(model, "WallLampAnchor", at(SHOP.X + dx, 4.62, SHOP.Z - 3.37), Vector3.new(0.24, 0.24, 0.24), LAMP))
		pointLight(anchor, rgb(255, 220, 170), 14, 0.9)
	end
	local chimneyAnchor = hide(DECO.box(model, "ChimneyAnchor", at(SHOP.X - 6.5, 9.9, SHOP.Z + 1.4), Vector3.new(0.24, 0.24, 0.24), STEEL))
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Rate = 1.6
	smoke.Lifetime = NumberRange.new(3, 5)
	smoke.Speed = NumberRange.new(1, 1.8)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.8) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(rgb(228, 228, 234))
	smoke.Acceleration = Vector3.new(0.3, 0.5, 0)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-10, 10)
	smoke.LightEmission = 0
	smoke.Parent = chimneyAnchor
	addSite("UtilityWorkshop", "PP_Utility_Workshop", CFrame.new(SHOP.X, DECK, SHOP.Z), "Grounded", "Platform", buildWorkshopArt)

	-- ---------------------------------------------------------------- fence
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	fence.Parent = model
	local LANTERN_POSTS: { [string]: boolean } = {}
	local function key(x: number, z: number): string
		return tostring(math.round(x * 10)) .. ":" .. tostring(math.round(z * 10))
	end
	for _, spot in { { K, K }, { -K, K }, { K, -K }, { -K, -K }, { K, 0 }, { -K, 0 }, { 11, -K }, { -11, -K } } do
		LANTERN_POSTS[key(spot[1], spot[2])] = true
	end
	local posts: { { number } } = {
		{ K, K }, { -K, K }, { K, -K }, { -K, -K },
		{ K, -10 }, { K, 10 }, { -K, -10 }, { -K, 10 }, { K, 0 }, { -K, 0 },
		{ 16, K }, { 0, K }, { -16, K },
		{ 21, -K }, { 11, -K }, { -11, -K }, { -21, -K },
	}
	for _, p in posts do
		local x, z = p[1], p[2]
		SOLID.box(fence, "FencePost", at(x, 2.3, z), Vector3.new(1.5, 3.6, 1.5), BRICK, Enum.Material.Brick)
		DECO.box(fence, "FencePostCourse", at(x, 1.35, z), Vector3.new(1.6, 0.14, 1.6), BRICK_DARK, Enum.Material.Brick)
		local cap = DECO.box(fence, "PostCap", at(x, 4.26, z), Vector3.new(1.86, 0.32, 1.86), KERB)
		if LANTERN_POSTS[key(x, z)] then
			pointLight(cap, rgb(255, 224, 176), 16, 0.85)
			lanternIndex += 1
			addSite("Lantern_" .. tostring(lanternIndex), "PP_Lantern", CFrame.new(x, 4.42, z), "Stacked", "Fence/PostCap", buildLanternArt)
		end
	end
	-- railings: two bars and a set of pickets between neighbouring posts
	local function railing(x1: number, z1: number, x2: number, z2: number)
		local dx, dz = x2 - x1, z2 - z1
		local length = math.sqrt(dx * dx + dz * dz)
		if length < 1.2 then
			return
		end
		local yaw = math.atan2(-dz, dx)
		local mid = at((x1 + x2) / 2, 0, (z1 + z2) / 2) * CFrame.Angles(0, yaw, 0)
		SOLID.box(fence, "RailTop", mid * CFrame.new(0, 3.3, 0), Vector3.new(length, 0.26, 0.26), NAVY, Enum.Material.Metal)
		SOLID.box(fence, "RailMid", mid * CFrame.new(0, 1.18, 0), Vector3.new(length, 0.24, 0.24), NAVY, Enum.Material.Metal)
		local count = math.clamp(math.floor(length / 3.2), 2, 4)
		for i = 1, count do
			local t = (i / (count + 1) - 0.5) * length
			DECO.box(fence, "Picket", mid * CFrame.new(t, 2.3, 0), Vector3.new(0.16, 2.1, 0.16), NAVY, Enum.Material.Metal)
		end
	end
	local H = 0.75
	for _, side in { -1, 1 } do
		local zs = { -K, -10, 0, 10, K }
		for i = 1, #zs - 1 do
			railing(side * K, zs[i] + H, side * K, zs[i + 1] - H)
		end
	end
	local xs = { K, 16, 0, -16, -K }
	for i = 1, #xs - 1 do
		railing(xs[i] - H, K, xs[i + 1] + H, K)
	end
	for _, side in { -1, 1 } do
		railing(side * (K - H), -K, side * (21 + H), -K)
		railing(side * (21 - H), -K, side * (11 + H), -K)
	end

	-- ---------------------------------------------------------------- banners
	local garden = Instance.new("Model")
	garden.Name = "Garden"
	garden.Parent = model
	for _, spec in { { 1, "COLLECT POWER\nGROW YOUR CITY" }, { -1, "TINY DISASTERS\nMAKE A BRIGHTER DAY" } } do
		local side = spec[1] :: number
		local facing = if side > 0 then FACE_NEG_X else FACE_POS_X
		SOLID.box(garden, "BannerPost", at(side * 28.1, 4.1, -4), Vector3.new(0.42, 7.2, 0.42), NAVY, Enum.Material.Metal)
		DECO.ball(garden, "BannerFinial", at(side * 28.1, 7.9, -4), Vector3.new(0.7, 0.7, 0.7), YELLOW)
		DECO.box(garden, "BannerFrame", at(side * 27.78, 5.5, -4) * facing, Vector3.new(3.4, 4.9, 0.14), TEAL)
		local bannerBoard = DECO.box(garden, "Banner", at(side * 27.62, 5.5, -4) * facing, Vector3.new(3.05, 4.55, 0.2), CREAM)
		boardText(bannerBoard, spec[2] :: string, TEAL_DARK, 36)
	end
	DECO.box(garden, "BannerFrame", at(-23.2, 4.7, 26.4), Vector3.new(5.4, 3.4, 0.14), TEAL)
	local rearBanner = DECO.box(garden, "Banner", at(-23.2, 4.7, 26.24), Vector3.new(5.0, 3.0, 0.2), CREAM)
	boardText(rearBanner, "SMALL CREATURES\nBRIGHTER TOMORROWS", TEAL_DARK, 36)
	for _, sx in { -1, 1 } do
		DECO.box(garden, "BannerLeg", at(-23.2 + sx * 2.3, 2.6, 26.5), Vector3.new(0.32, 4.6, 0.32), NAVY, Enum.Material.Metal)
	end

	-- ---------------------------------------------------------------- yard mains
	addSite("PipeRun_1", "PP_Pipe_Run", CFrame.new(20.0, DECK, 27.6), "Grounded", "Platform", buildPipeRunArt)
	addSite("PipeRun_2", "PP_Pipe_Run", CFrame.new(3.6, DECK, 27.6), "Grounded", "Platform", buildPipeRunArt)
	addSite("PipeRun_3", "PP_Pipe_Run", CFrame.new(-22.6, DECK, 27.6), "Grounded", "Platform", buildPipeRunArt)
	addSite("PipeRun_4", "PP_Pipe_Run", CFrame.new(27.2, DECK, 6.0) * ALONG_Z, "Grounded", "Platform", buildPipeRunArt)
	addSite("PipeRun_5", "PP_Pipe_Run", CFrame.new(27.2, DECK, 16.2) * ALONG_Z, "Grounded", "Platform", buildPipeRunArt)
	addSite("PipeRun_6", "PP_Pipe_Run", CFrame.new(-27.2, DECK, 16.2) * ALONG_Z, "Grounded", "Platform", buildPipeRunArt)
	addSite("PipeElbow_1", "PP_Pipe_Elbow", CFrame.new(25.4, DECK, 27.6), "Grounded", "Platform", buildPipeElbowArt)
	addSite("PipeElbow_2", "PP_Pipe_Elbow", CFrame.new(27.2, DECK, 0.4), "Grounded", "Platform", buildPipeElbowArt)
	addSite("PipeElbow_3", "PP_Pipe_Elbow", CFrame.new(-27.2, DECK, 10.6), "Grounded", "Platform", buildPipeElbowArt)

	-- ---------------------------------------------------------------- planting
	local shrubIndex = 0
	for _, spot in {
		Vector3.new(27.0, 0, -22), Vector3.new(27.0, 0, -6), Vector3.new(27.0, 0, 22.4), Vector3.new(27.0, 0, 26.6),
		Vector3.new(-27.0, 0, -24), Vector3.new(-27.0, 0, -6), Vector3.new(-27.0, 0, 5.0), Vector3.new(-27.0, 0, 26.6),
		Vector3.new(16.2, 0, 26.6), Vector3.new(-19.4, 0, 26.6), Vector3.new(0.2, 0, 22.6),
	} do
		shrubIndex += 1
		addSite("Shrub_" .. tostring(shrubIndex), "PP_Shrub_Cluster", CFrame.new(spot.X, DECK, spot.Z), "Grounded", "Platform", buildShrubArt)
	end
	addSite("FlowerBed_1", "PP_Flower_Bed", CFrame.new(26.9, DECK, -10.0) * ALONG_Z, "Grounded", "Platform", buildFlowerBedArt)
	addSite("FlowerBed_2", "PP_Flower_Bed", CFrame.new(-26.9, DECK, -15.0) * ALONG_Z, "Grounded", "Platform", buildFlowerBedArt)
	addSite("FlowerBed_3", "PP_Flower_Bed", CFrame.new(8.2, DECK, 22.6), "Grounded", "Platform", buildFlowerBedArt)
	-- trees and boulders stand on the world grass outside the plot
	local treeIndex = 0
	for _, spot in { Vector3.new(37, 0, 30), Vector3.new(-37, 0, 30), Vector3.new(38, 0, -16), Vector3.new(-38, 0, -16) } do
		treeIndex += 1
		addSite("Tree_" .. tostring(treeIndex), "PP_Round_Tree", CFrame.new(spot.X, -DECK, spot.Z), "Grounded", "Map/Ground", buildTreeArt)
	end
	for i, spot in { Vector3.new(34, 0, 6), Vector3.new(-35, 0, 14), Vector3.new(33, 0, -27), Vector3.new(-34, 0, -25) } do
		local r = 2.1 + (i % 3) * 0.5
		DECO.ball(garden, "Boulder", at(spot.X, -0.1, spot.Z), Vector3.new(r * 1.8, r * 1.25, r * 1.6), ROCK, Enum.Material.Slate)
	end
	propSites:SetAttribute("AssetCount", siteCount)

	-- ---------------------------------------------------------------- spawn
	local spawnPoint = Instance.new("SpawnLocation")
	spawnPoint.Name = "SpawnPoint"
	spawnPoint.Size = Vector3.new(8, 1, 8)
	spawnPoint.CFrame = at(0, 0.5, -34)
	spawnPoint.Anchored = true
	spawnPoint.CanCollide = true
	spawnPoint.Enabled = false
	spawnPoint.Neutral = true
	spawnPoint.Transparency = 0
	spawnPoint.Color = PAVING_LIGHT
	spawnPoint.Material = Enum.Material.Concrete
	spawnPoint.TopSurface = Enum.SurfaceType.Smooth
	spawnPoint.BottomSurface = Enum.SurfaceType.Smooth
	spawnPoint.Parent = model

	local visitorSpot = part({ name = "VisitorSpot", size = Vector3.new(4, 1, 4), cf = at(9, 0.5, -34), color = PAVING_LIGHT, transparency = 1, parent = model })

	-- ---------------------------------------------------------------- decoration tiers
	-- Hidden until the City Decoration upgrade is bought; each tier adds more of
	-- the same town beyond what the concept shows.
	local decorTiers: { [number]: Model } = {}
	for tier = 1, 3 do
		local m = Instance.new("Model")
		m.Name = "Tier_" .. tostring(tier)
		m.Parent = model
		decorTiers[tier] = m
	end
	-- Tier 1: an upper pipe rack on the side runs, valves, crates
	for _, side in { -1, 1 } do
		for _, z in { -8, 4, 16 } do
			DECO.rod(decorTiers[1], "RackPipe", at(side * 27.2, 3.8, z) * ALONG_Z, 9, 0.8, TEAL)
			for _, dz in { -3.4, 3.4 } do
				DECO.rod(decorTiers[1], "RackFlange", at(side * 27.2, 3.8, z + dz) * ALONG_Z, 0.4, 1.1, YELLOW)
			end
		end
		DECO.disc(decorTiers[1], "Valve", at(side * (27.2 - 0.9), 3.8, 10) * (if side > 0 then FACE_NEG_X else FACE_POS_X), 0.22, 1.1, RED)
	end
	SOLID.box(decorTiers[1], "Crate", at(-16.9, 1.05, 21.9), Vector3.new(1.1, 1.1, 1.1), rgb(164, 124, 82), Enum.Material.WoodPlanks)
	SOLID.box(decorTiers[1], "Crate", at(-15.7, 0.93, 22.1), Vector3.new(0.86, 0.86, 0.86), rgb(164, 124, 82), Enum.Material.WoodPlanks)
	SOLID.cyl(decorTiers[1], "Barrel", at(15.8, 1.2, 22.2), 1.4, 1.1, TEAL)
	SOLID.cyl(decorTiers[1], "Barrel", at(17.1, 1.2, 22.0), 1.4, 1.1, YELLOW)
	-- Tier 2: strung lights along the side rails and floodlights on the workshop
	for _, side in { -1, 1 } do
		local zs = { -K, -10, 0, 10, K }
		for i = 1, #zs - 1 do
			local z1, z2 = zs[i] + H, zs[i + 1] - H
			for j = 1, 3 do
				local z = z1 + (z2 - z1) * (j / 4)
				DECO.ball(decorTiers[2], "StringLight", at(side * K, 3.7, z), Vector3.new(0.38, 0.38, 0.38), LAMP, Enum.Material.Neon)
			end
		end
	end
	for _, dx in { -5.4, 4.6 } do
		local head = DECO.box(decorTiers[2], "Flood", at(SHOP.X + dx, 7.2, SHOP.Z - 2.6) * CFrame.Angles(math.rad(34), 0, 0), Vector3.new(1.0, 0.56, 0.66), INK)
		DECO.box(decorTiers[2], "FloodLens", head.CFrame * CFrame.new(0, 0, -0.36), Vector3.new(0.78, 0.4, 0.06), LAMP, Enum.Material.Neon)
		local light = Instance.new("SpotLight")
		light.Color = rgb(255, 236, 200)
		light.Range = 24
		light.Brightness = 1.1
		light.Angle = 80
		light.Face = Enum.NormalId.Front
		light.Parent = head
	end
	-- Tier 3: a rooftop turbine, bunting across the entrance, an auxiliary tank
	DECO.box(decorTiers[3], "TurbineMast", at(SHOP.X + 2.2, 8.4, SHOP.Z + 1.0), Vector3.new(0.34, 3.6, 0.34), NAVY)
	DECO.ball(decorTiers[3], "TurbineHub", at(SHOP.X + 2.2, 10.3, SHOP.Z + 0.7), Vector3.new(0.66, 0.66, 0.66), NAVY)
	local turbinePivot = at(SHOP.X + 2.2, 10.3, SHOP.Z + 0.65)
	for i = 1, 3 do
		local blade = DECO.box(decorTiers[3], "TurbineBlade", turbinePivot * CFrame.Angles(0, 0, math.rad(120 * i)) * CFrame.new(0, 1.05, 0), Vector3.new(0.26, 2.0, 0.12), CREAM)
		spin(blade, turbinePivot, 2.0, 0)
	end
	for _, side in { -1, 1 } do
		for j = 1, 5 do
			local x = side * (11 + (21 - 11) * (j / 6))
			part({
				name = "Flag",
				size = Vector3.new(0.12, 0.68, 0.56),
				cf = at(x, 2.9, -K) * CFrame.Angles(math.rad(180), math.rad(90), 0),
				color = if j % 3 == 0 then rgb(90, 200, 255) elseif j % 3 == 1 then HAZARD else rgb(255, 120, 160),
				shape = Enum.PartType.Wedge,
				parent = decorTiers[3],
			})
		end
	end
	DECO.box(decorTiers[3], "AuxTankBase", at(16.4, 0.74, 22.2), Vector3.new(2.8, 0.44, 2.8), NAVY)
	SOLID.cyl(decorTiers[3], "AuxTank", at(16.4, 2.4, 22.2), 2.9, 2.3, TEAL)
	DECO.ball(decorTiers[3], "AuxTankCap", at(16.4, 3.9, 22.2), Vector3.new(2.3, 0.7, 2.3), YELLOW)

	for _, m in decorTiers do
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d:SetAttribute("AuthoredTransparency", d.Transparency)
				d:SetAttribute("AuthoredCollide", d.CanCollide)
				d.Transparency = 1
				d.CanCollide = false
			elseif d:IsA("Light") or d:IsA("ParticleEmitter") then
				d.Enabled = false
			end
		end
	end

	local rewards = Instance.new("Folder")
	rewards.Name = "Rewards"
	rewards.Parent = model

	-- Astra's meshes replace the placeholders when the library is synced; until
	-- then this is a no-op that leaves every stand-in where it is.
	local okProps, placed = pcall(PlotProps.apply, model, cframe)
	model:SetAttribute("PlotArt", if okProps and placed == true then "native" else "placeholder")

	model.Parent = workspace:FindFirstChild("Plots") or workspace

	local plot: Plot = {
		model = model,
		index = index,
		cframe = cframe,
		pads = pads,
		padStrips = padStrips,
		stations = stations,
		machines = machines,
		booth = { model = booth, ventButton = ventButton, console = consoleLabel },
		ventPrompt = nil,
		collectPad = collectPad,
		collectLabel = collectLabel,
		billboardTitle = billboardTitle,
		billboardEarnings = billboardEarnings,
		spawnPoint = spawnPoint,
		visitorSpot = visitorSpot,
		decorTiers = decorTiers,
		rewards = rewards,
		garden = garden,
		propSites = propSites,
	}
	return plot
end

function PlotTemplate.setOwner(plot: Plot, userId: number, name: string)
	plot.model:SetAttribute("OwnerUserId", userId)
	plot.model:SetAttribute("OwnerName", name)
	plot.billboardTitle.Text = if userId == 0 then "Vacant Lot" else name
	if userId == 0 then
		plot.billboardEarnings.Text = "0/s"
		plot.collectLabel.Text = "Bank: 0"
	end
end

function PlotTemplate.setPadUnlocked(plot: Plot, pad: number, unlocked: boolean)
	local p = plot.pads[pad]
	if not p then
		return
	end
	p:SetAttribute("Unlocked", unlocked)
	p.Transparency = if unlocked then 0 else 0.55
	p.Color = if unlocked then PAD_INSET else PAD_LOCKED
	p.Material = if unlocked then Enum.Material.Metal else Enum.Material.SmoothPlastic
	local numberLabel = p:FindFirstChild("Gui") and (p:FindFirstChild("Gui") :: SurfaceGui):FindFirstChild("PadNumber")
	if numberLabel and numberLabel:IsA("TextLabel") then
		numberLabel.TextTransparency = if unlocked then 0 else 0.55
	end
end

-- The strip along a pad's front edge glows in the deployed creature's element
-- colour; nil dims it again.
function PlotTemplate.setPadElement(plot: Plot, pad: number, color: Color3?)
	local strip = plot.padStrips[pad]
	if not strip then
		return
	end
	if color then
		strip.Color = color
		strip.Material = Enum.Material.Neon
	else
		strip.Color = STRIP_IDLE
		strip.Material = Enum.Material.SmoothPlastic
	end
end

-- tier 0..3; every tier at or below `tier` becomes visible with the look it
-- was authored with (AuthoredTransparency / AuthoredCollide attributes).
function PlotTemplate.setDecorationTier(plot: Plot, tier: number)
	for i = 1, 3 do
		local shown = i <= tier
		local m = plot.decorTiers[i]
		if m then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					local authored = d:GetAttribute("AuthoredTransparency")
					d.Transparency = if shown then (if typeof(authored) == "number" then authored else 0) else 1
					d.CanCollide = shown and d:GetAttribute("AuthoredCollide") == true
				elseif d:IsA("Light") or d:IsA("ParticleEmitter") then
					d.Enabled = shown
				end
			end
		end
	end
end

-- Milestone decorations, one slot per key, in the gaps the town leaves free:
-- bunting over the forecourt, the rear strip between tower and workshop, and
-- the two forecourt corners beside the booth and the sign.
local REWARD_SPOTS: { [string]: CFrame } = {
	hazard_flags = CFrame.new(0, 1.0, -10.5) * FACE_REAR,
	smiling_billboard = CFrame.new(3.0, 1.0, 21.0),
	pipe_fountain = CFrame.new(14.0, 1.0, -12.0),
	neon_company_sign = CFrame.new(-14.0, 1.0, -12.0),
	golden_statue = CFrame.new(-2.2, 1.0, 27.2),
}

function PlotTemplate.setRewardDecoration(plot: Plot, key: string, shown: boolean)
	local existing = plot.rewards:FindFirstChild(key)
	if not shown then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local spot = REWARD_SPOTS[key]
	if not spot then
		return
	end
	local MachineryBuilders = require(ReplicatedStorage.Shared.Models.MachineryBuilders)
	local ok, model = pcall(MachineryBuilders.buildDecoration, key)
	if not ok or typeof(model) ~= "Instance" then
		warn("[PlotTemplate] decoration failed:", key, model)
		return
	end
	local m = model :: Model
	m.Name = key
	m:PivotTo(plot.cframe * spot)
	m.Parent = plot.rewards
end

function PlotTemplate.padCFrame(plot: Plot, pad: number): CFrame
	local o = padOffset(pad)
	return plot.cframe * CFrame.new(o.X, o.Y, o.Z)
end

-- Where a circuit machine sits: the midpoint of two adjacent pads, turned so
-- it faces the front of the plot.
function PlotTemplate.pairCFrame(plot: Plot, padA: number, padB: number): CFrame
	local a, b = padOffset(padA), padOffset(padB)
	local mid = (a + b) / 2
	return plot.cframe * CFrame.new(mid.X, mid.Y - 0.05, mid.Z)
end

-- Where a work station sits: just behind its pad, so the creature stays in front.
function PlotTemplate.stationCFrame(plot: Plot, pad: number): CFrame
	local o = padOffset(pad)
	return plot.cframe * CFrame.new(o.X, o.Y - 0.05, o.Z + 3.4)
end

-- Clear everything a run put on the plot. The owner stays.
function PlotTemplate.reset(plot: Plot)
	for _, folder in plot.stations do
		folder:ClearAllChildren()
	end
	plot.machines:ClearAllChildren()
	plot.rewards:ClearAllChildren()
	for pad = 1, Config.Circuits.maxPads do
		PlotTemplate.setPadUnlocked(plot, pad, false)
		PlotTemplate.setPadElement(plot, pad, nil)
	end
	PlotTemplate.setDecorationTier(plot, 0)
	plot.collectLabel.Text = "Bank: 0"
	plot.billboardEarnings.Text = "0/s"
	plot.booth.console.Text = "No circuits running"
end

return PlotTemplate
