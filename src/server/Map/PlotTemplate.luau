--!strict
-- One player's city plot: the 6 x 4 grid of work pads, the control booth, the
-- collection pad, the billboard, and the decoration tiers that make a grown
-- city look nothing like a starting one.
--
-- Local frame: the plot's front is local -Z, pointing at the hub. Everything
-- below is written in that frame and placed by the caller's CFrame.
--
-- This module does NOT use Kit.finalize: that helper is for creature models
-- and would weld every part to a root and clear CanCollide, which would drop
-- the player through the floor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local PlotTemplate = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local INK = rgb(46, 44, 52)
local HAZARD = rgb(255, 190, 50)
local CONCRETE = rgb(178, 178, 186)
local DECK = rgb(120, 126, 142)
local STEEL = rgb(150, 156, 168)

local GRID = Config.Circuits.grid
local PAD_SPAN = 8 -- studs between pad centres
local PAD_SIZE = 6
local PAD_TOP = 1.1

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
	p.Color = props.color or CONCRETE
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

-- A run of alternating yellow/dark diagonal blocks: the company's house style.
local function hazardStrip(parent: Instance, origin: CFrame, length: number, height: number, thickness: number)
	local count = math.max(2, math.floor(length / 1.6))
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

local function surfaceLabel(host: BasePart, face: Enum.NormalId, text: string, size: number, color: Color3?): TextLabel
	local gui = host:FindFirstChild("Gui") :: SurfaceGui?
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "Gui"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 26
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

export type Plot = {
	model: Model,
	index: number,
	cframe: CFrame,
	pads: { [number]: Part },
	stations: { [number]: Folder },
	machines: Folder,
	booth: { model: Model, ventButton: Part, console: TextLabel },
	collectPad: Part,
	collectLabel: TextLabel,
	billboardTitle: TextLabel,
	billboardEarnings: TextLabel,
	spawnPoint: SpawnLocation,
	visitorSpot: Part,
	decorTiers: { [number]: Model },
	rewards: Folder,
	garden: Model,
}

-- Local offset of a pad's top-surface centre.
local function padOffset(pad: number): Vector3
	local col, row = Config.Circuits.padCoords(pad)
	local x = -((GRID.cols - 1) / 2) * PAD_SPAN + (col - 1) * PAD_SPAN
	local z = -6 + (row - 1) * PAD_SPAN
	return Vector3.new(x, PAD_TOP, z)
end

function PlotTemplate.build(cframe: CFrame, index: number): Plot
	local model = Instance.new("Model")
	model.Name = "Plot_" .. tostring(index)
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")

	local at = function(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end

	-- ---------------------------------------------------------------- ground
	local platform = part({ name = "Platform", size = Vector3.new(60, 1, 60), cf = at(0, 0, 0), color = CONCRETE, material = Enum.Material.Concrete, collide = true, parent = model })
	model.PrimaryPart = platform
	-- entrance apron so the spawn point is on solid ground
	part({ name = "Apron", size = Vector3.new(22, 1, 14), cf = at(0, 0, -36), color = DECK, material = Enum.Material.Concrete, collide = true, parent = model })
	-- kerb around the platform edge
	for _, spec in
		{
			{ Vector3.new(60, 0.8, 1.2), Vector3.new(0, 0.9, 30) },
			{ Vector3.new(1.2, 0.8, 60), Vector3.new(30, 0.9, 0) },
			{ Vector3.new(1.2, 0.8, 60), Vector3.new(-30, 0.9, 0) },
			{ Vector3.new(18, 0.8, 1.2), Vector3.new(-21, 0.9, -30) },
			{ Vector3.new(18, 0.8, 1.2), Vector3.new(21, 0.9, -30) },
		}
	do
		part({ name = "Kerb", size = spec[1], cf = at(spec[2].X, spec[2].Y, spec[2].Z), color = DECK, collide = true, parent = model })
	end
	hazardStrip(model, at(0, 1.5, -30.7), 16, 0.7, 0.14)

	-- ---------------------------------------------------------------- pads
	local padFolder = Instance.new("Folder")
	padFolder.Name = "Pads"
	padFolder.Parent = model
	local stationFolder = Instance.new("Folder")
	stationFolder.Name = "Stations"
	stationFolder.Parent = model

	local pads: { [number]: Part } = {}
	local stations: { [number]: Folder } = {}
	for pad = 1, Config.Circuits.maxPads do
		local o = padOffset(pad)
		local p = part({
			name = "Pad_" .. tostring(pad),
			size = Vector3.new(PAD_SIZE, 0.6, PAD_SIZE),
			cf = at(o.X, o.Y - 0.3, o.Z),
			color = DECK,
			material = Enum.Material.Metal,
			collide = true,
			parent = padFolder,
		})
		p:SetAttribute("PadIndex", pad)
		p:SetAttribute("Unlocked", false)
		-- a rim so an empty pad still reads as a socket
		part({ name = "Rim", size = Vector3.new(PAD_SIZE + 0.5, 0.22, PAD_SIZE + 0.5), cf = at(o.X, o.Y - 0.62, o.Z), color = INK, parent = padFolder })
		-- pad number on the deck
		local num = surfaceLabel(p, Enum.NormalId.Top, tostring(pad), 22, rgb(220, 226, 240))
		num.Name = "PadNumber"
		num.Rotation = 0

		local sf = Instance.new("Folder")
		sf.Name = "Station_" .. tostring(pad)
		sf.Parent = stationFolder
		stations[pad] = sf
		pads[pad] = p
	end

	local machines = Instance.new("Folder")
	machines.Name = "Machines"
	machines.Parent = model

	-- ---------------------------------------------------------------- booth
	local booth = Instance.new("Model")
	booth.Name = "Booth"
	booth.Parent = model
	part({ name = "Floor", size = Vector3.new(7, 0.6, 6), cf = at(-24, 0.8, -22), color = DECK, collide = true, parent = booth })
	part({ name = "BackWall", size = Vector3.new(7, 4.5, 0.4), cf = at(-24, 3.3, -19.2), color = rgb(96, 132, 168), collide = true, parent = booth })
	part({ name = "SideWall", size = Vector3.new(0.4, 4.5, 6), cf = at(-27.3, 3.3, -22), color = rgb(96, 132, 168), collide = true, parent = booth })
	part({ name = "Roof", size = Vector3.new(7.6, 0.4, 6.6), cf = at(-24, 5.7, -22), color = HAZARD, parent = booth })
	part({ name = "RoofLip", size = Vector3.new(7.8, 0.5, 0.4), cf = at(-24, 5.3, -25.2), color = INK, parent = booth })
	-- console with a text screen
	local console = part({ name = "Console", size = Vector3.new(4.4, 1.6, 0.5), cf = at(-24, 2.4, -19.7) * CFrame.Angles(math.rad(-18), 0, 0), color = rgb(58, 62, 82), parent = booth })
	local consoleLabel = surfaceLabel(console, Enum.NormalId.Front, "No circuits running", 20, rgb(190, 245, 255))
	consoleLabel.Name = "Text"
	-- the vent button: a big red mushroom the player holds during Overdrive
	local ventButton = part({ name = "VentButton", size = Vector3.new(0.5, 1.6, 1.6), cf = at(-22.2, 2.0, -22.6) * CFrame.Angles(0, 0, math.rad(90)), color = rgb(220, 70, 70), material = Enum.Material.Neon, shape = Enum.PartType.Cylinder, parent = booth })
	ventButton:SetAttribute("Prompt", "Vent")
	part({ name = "VentBase", size = Vector3.new(2.0, 1.4, 2.0), cf = at(-22.2, 1.4, -22.6), color = INK, collide = true, parent = booth })
	-- pipes running from the booth toward the pads
	for i = 1, 3 do
		part({
			name = "Pipe",
			size = Vector3.new(14, 0.5, 0.5),
			cf = at(-22.5 + (i - 1) * 0.9, 1.2 + (i - 1) * 0.1, -12) * CFrame.Angles(0, math.rad(90), 0),
			color = if i == 2 then rgb(200, 140, 80) else STEEL,
			shape = Enum.PartType.Cylinder,
			parent = booth,
		})
	end

	-- ---------------------------------------------------------------- collect pad
	local collectPad = part({
		name = "CollectPad",
		size = Vector3.new(8, 0.4, 8),
		cf = at(0, 0.7, -23),
		color = rgb(255, 208, 72),
		material = Enum.Material.Neon,
		collide = false,
		touch = true,
		parent = model,
	})
	collectPad:SetAttribute("Touch", "Collect")
	part({ name = "CollectRim", size = Vector3.new(9, 0.5, 9), cf = at(0, 0.6, -23), color = INK, parent = model })
	local collectBillboard = Instance.new("BillboardGui")
	collectBillboard.Name = "Label"
	collectBillboard.Size = UDim2.fromScale(9, 2.4)
	collectBillboard.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
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

	-- ---------------------------------------------------------------- billboard
	part({ name = "BillboardPostL", size = Vector3.new(0.6, 9, 0.6), cf = at(15.5, 4.5, -27), color = DECK, collide = true, parent = model })
	part({ name = "BillboardPostR", size = Vector3.new(0.6, 9, 0.6), cf = at(28.5, 4.5, -27), color = DECK, collide = true, parent = model })
	local board = part({ name = "Billboard", size = Vector3.new(16, 8, 1), cf = at(22, 9, -27), color = rgb(52, 58, 78), parent = model })
	hazardStrip(model, at(22, 13.4, -27.6), 16, 0.8, 0.14)
	local boardGui = Instance.new("SurfaceGui")
	boardGui.Name = "Gui"
	boardGui.Face = Enum.NormalId.Front
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	boardGui.PixelsPerStud = 24
	boardGui.Parent = board
	local billboardTitle = Instance.new("TextLabel")
	billboardTitle.Name = "Title"
	billboardTitle.BackgroundTransparency = 1
	billboardTitle.Size = UDim2.fromScale(1, 0.5)
	billboardTitle.Position = UDim2.fromScale(0, 0.06)
	billboardTitle.Font = Enum.Font.FredokaOne
	billboardTitle.TextScaled = true
	billboardTitle.TextColor3 = rgb(255, 252, 245)
	billboardTitle.Text = "Vacant Lot"
	billboardTitle.Parent = boardGui
	local billboardEarnings = Instance.new("TextLabel")
	billboardEarnings.Name = "Earnings"
	billboardEarnings.BackgroundTransparency = 1
	billboardEarnings.Size = UDim2.fromScale(1, 0.4)
	billboardEarnings.Position = UDim2.fromScale(0, 0.55)
	billboardEarnings.Font = Enum.Font.FredokaOne
	billboardEarnings.TextScaled = true
	billboardEarnings.TextColor3 = rgb(255, 208, 72)
	billboardEarnings.Text = "0/s"
	billboardEarnings.Parent = boardGui

	-- ---------------------------------------------------------------- spawn
	local spawnPoint = Instance.new("SpawnLocation")
	spawnPoint.Name = "SpawnPoint"
	spawnPoint.Size = Vector3.new(8, 1, 8)
	spawnPoint.CFrame = at(0, 0.5, -34)
	spawnPoint.Anchored = true
	spawnPoint.CanCollide = true
	spawnPoint.Enabled = false
	spawnPoint.Neutral = true
	spawnPoint.Transparency = 0.4
	spawnPoint.Color = rgb(120, 220, 160)
	spawnPoint.Material = Enum.Material.Neon
	spawnPoint.Parent = model

	local visitorSpot = part({ name = "VisitorSpot", size = Vector3.new(4, 1, 4), cf = at(9, 0.5, -34), color = rgb(120, 200, 255), transparency = 0.6, parent = model })

	-- ---------------------------------------------------------------- garden + decor tiers
	local garden = Instance.new("Model")
	garden.Name = "Garden"
	garden.Parent = model
	-- planters along the back edge, present from the start
	for i = 1, 5 do
		local x = -20 + (i - 1) * 10
		part({ name = "Planter", size = Vector3.new(6, 1.2, 3), cf = at(x, 1.1, 26), color = rgb(150, 108, 74), collide = true, parent = garden })
		part({ name = "Soil", size = Vector3.new(5.4, 0.3, 2.4), cf = at(x, 1.8, 26), color = rgb(88, 66, 48), parent = garden })
		for j = 1, 3 do
			part({ name = "Shrub", size = Vector3.new(1.1, 1.3, 1.1), cf = at(x - 1.6 + (j - 1) * 1.6, 2.5, 26), color = rgb(96, 168, 92), shape = Enum.PartType.Ball, parent = garden })
		end
	end

	local decorTiers: { [number]: Model } = {}
	for tier = 1, 3 do
		local m = Instance.new("Model")
		m.Name = "Tier_" .. tostring(tier)
		m.Parent = model
		decorTiers[tier] = m
	end
	-- Tier 1: pipework and coloured drums along the sides
	for i = 1, 6 do
		local z = -18 + (i - 1) * 7
		part({ name = "Pipe", size = Vector3.new(6.6, 0.7, 0.7), cf = at(-27, 2.0, z) * CFrame.Angles(0, math.rad(90), 0), color = rgb(200, 140, 80), shape = Enum.PartType.Cylinder, parent = decorTiers[1] })
		part({ name = "Drum", size = Vector3.new(2.6, 2.2, 2.2), cf = at(26.5, 1.8, z) * CFrame.Angles(0, 0, math.rad(90)), color = if i % 2 == 0 then rgb(90, 180, 220) else HAZARD, shape = Enum.PartType.Cylinder, collide = true, parent = decorTiers[1] })
		part({ name = "DrumBand", size = Vector3.new(0.3, 2.4, 2.4), cf = at(26.5, 2.6, z) * CFrame.Angles(0, 0, math.rad(90)), color = INK, shape = Enum.PartType.Cylinder, parent = decorTiers[1] })
	end
	-- Tier 2: rooftop turbines and floodlights
	for i = 1, 4 do
		local x = -18 + (i - 1) * 12
		part({ name = "LightPost", size = Vector3.new(0.5, 10, 0.5), cf = at(x, 5.5, 28.5), color = DECK, collide = true, parent = decorTiers[2] })
		local head = part({ name = "Flood", size = Vector3.new(2.0, 0.9, 1.2), cf = at(x, 10.4, 28) * CFrame.Angles(math.rad(28), 0, 0), color = INK, parent = decorTiers[2] })
		part({ name = "Lens", size = Vector3.new(1.7, 0.15, 1.0), cf = head.CFrame * CFrame.new(0, -0.5, 0), color = rgb(255, 245, 200), material = Enum.Material.Neon, parent = decorTiers[2] })
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 244, 210)
		light.Range = 30
		light.Brightness = 1.1
		light.Parent = head
	end
	-- Tier 3: a gantry crane over the pad field and neon trim
	part({ name = "CraneRailL", size = Vector3.new(1.2, 1.2, 52), cf = at(-25, 14, 2), color = HAZARD, parent = decorTiers[3] })
	part({ name = "CraneRailR", size = Vector3.new(1.2, 1.2, 52), cf = at(25, 14, 2), color = HAZARD, parent = decorTiers[3] })
	for _, side in { -1, 1 } do
		for i = 1, 3 do
			part({ name = "CraneLeg", size = Vector3.new(1.0, 14, 1.0), cf = at(side * 25, 7, -18 + (i - 1) * 18), color = DECK, collide = true, parent = decorTiers[3] })
		end
	end
	part({ name = "CraneBridge", size = Vector3.new(52, 1.0, 3), cf = at(0, 15, 6), color = STEEL, parent = decorTiers[3] })
	part({ name = "CraneHook", size = Vector3.new(0.4, 4, 0.4), cf = at(0, 12.5, 6), color = INK, parent = decorTiers[3] })
	for i = 1, 8 do
		part({ name = "NeonTrim", size = Vector3.new(6.5, 0.25, 0.25), cf = at(-26 + (i - 1) * 7.4, 1.6, -29.4), color = rgb(120, 235, 255), material = Enum.Material.Neon, parent = decorTiers[3] })
	end

	for _, m in decorTiers do
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CanCollide = false
			elseif d:IsA("Light") then
				d.Enabled = false
			end
		end
	end

	local rewards = Instance.new("Folder")
	rewards.Name = "Rewards"
	rewards.Parent = model

	model.Parent = workspace:FindFirstChild("Plots") or workspace

	local plot: Plot = {
		model = model,
		index = index,
		cframe = cframe,
		pads = pads,
		stations = stations,
		machines = machines,
		booth = { model = booth, ventButton = ventButton, console = consoleLabel },
		collectPad = collectPad,
		collectLabel = collectLabel,
		billboardTitle = billboardTitle,
		billboardEarnings = billboardEarnings,
		spawnPoint = spawnPoint,
		visitorSpot = visitorSpot,
		decorTiers = decorTiers,
		rewards = rewards,
		garden = garden,
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
	p.Color = if unlocked then DECK else rgb(70, 74, 86)
	p.Material = if unlocked then Enum.Material.Metal else Enum.Material.SmoothPlastic
	local rim = p.Parent and p.Parent:FindFirstChild("Rim")
	local _ = rim
	local numberLabel = p:FindFirstChild("Gui") and (p:FindFirstChild("Gui") :: SurfaceGui):FindFirstChild("PadNumber")
	if numberLabel and numberLabel:IsA("TextLabel") then
		numberLabel.TextTransparency = if unlocked then 0 else 0.55
	end
end

-- tier 0..3; every tier at or below `tier` becomes visible.
function PlotTemplate.setDecorationTier(plot: Plot, tier: number)
	for i = 1, 3 do
		local shown = i <= tier
		local m = plot.decorTiers[i]
		if m then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.Transparency = if shown then (if d.Name == "Lens" or d.Name == "NeonTrim" then 0 else 0) else 1
					d.CanCollide = shown and (d.Name == "LightPost" or d.Name == "CraneLeg" or d.Name == "Drum")
				elseif d:IsA("Light") then
					d.Enabled = shown
				end
			end
		end
	end
end

-- Milestone decorations sit around the platform edge, one slot per key.
local REWARD_SPOTS: { [string]: CFrame } = {
	hazard_flags = CFrame.new(0, 1.0, -28) * CFrame.Angles(0, math.rad(180), 0),
	smiling_billboard = CFrame.new(-22, 1.0, -27),
	pipe_fountain = CFrame.new(-22, 1.0, 12) * CFrame.Angles(0, math.rad(90), 0),
	neon_company_sign = CFrame.new(22, 1.0, 12) * CFrame.Angles(0, math.rad(-90), 0),
	golden_statue = CFrame.new(0, 1.0, 22),
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
	end
	PlotTemplate.setDecorationTier(plot, 0)
	plot.collectLabel.Text = "Bank: 0"
	plot.billboardEarnings.Text = "0/s"
	plot.booth.console.Text = "No circuits running"
end

return PlotTemplate
