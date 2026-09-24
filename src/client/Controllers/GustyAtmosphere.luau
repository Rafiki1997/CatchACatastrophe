--!strict
-- Local, bounded meadow ambience; no forces, camera changes or global weather.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Atmosphere = {}
local V = Vector3.new
local rgb = Color3.fromRGB
local TAU = math.pi * 2
local LEAF_COUNT = 18
local GUST_COUNT = 3
local started = false
local heartbeat: RBXScriptConnection? = nil
local captureListener: RBXScriptConnection? = nil
local capturing = false
local active: any = nil

local function decor(name: string, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = V(0.1, 0.1, 0.1)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Parent = parent
	return p
end

-- Separate lifecycle keeps streaming/rebuilds from leaving effects behind.
function Atmosphere.create(region: Model)
	local centre = region:GetAttribute("Centre")
	assert(typeof(centre) == "Vector3", "Gusty atmosphere needs the region centre")
	local frame = CFrame.lookAt(centre, V(0, centre.Y, 0))
	local root = Instance.new("Folder")
	root.Name = "GustyAtmosphereFX"
	root.Parent = workspace
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "GustyMeadowGrade"
	grade.Enabled = false
	grade.Parent = Lighting
	local leaves: { Part } = {}
	for i = 1, LEAF_COUNT do
		local leaf = decor("DriftingLeaf", root)
		leaf.Shape = Enum.PartType.Ball
		leaf.Size = V(0.28 + (i % 3) * 0.04, 0.07, 0.62 + (i % 4) * 0.06)
		leaf.Material = Enum.Material.SmoothPlastic
		leaf.Color = if i % 4 == 0 then rgb(178, 168, 83) else rgb(114 + i % 3 * 12, 157, 76)
		table.insert(leaves, leaf)
	end
	local gusts: { { anchor: Part, beam: Beam } } = {}
	for i = 1, GUST_COUNT do
		local anchor = decor("GustAnchor", root)
		local a, b = Instance.new("Attachment"), Instance.new("Attachment")
		a.CFrame = CFrame.new(-5, 0, 0)
		b.CFrame = CFrame.new(5, 0.7, -1.5)
		a.Parent, b.Parent = anchor, anchor
		local beam = Instance.new("Beam")
		beam.Name = "BreezeRibbon"
		beam.Attachment0, beam.Attachment1 = a, b
		beam.CurveSize0, beam.CurveSize1 = 4, 4
		beam.Width0, beam.Width1 = 0.09, 0.025
		beam.Color = ColorSequence.new(rgb(234, 239, 204))
		beam.LightEmission = 0
		beam.LightInfluence = 1
		beam.FaceCamera = true
		beam.Segments = 10
		beam.Enabled = false
		beam.Parent = anchor
		table.insert(gusts, { anchor = anchor, beam = beam })
	end
	local clock, warmth = 0, 0
	local destroyed = false
	local controller = { region = region, root = root }
	function controller.step(dt: number, observer: Vector3?, settings: any, capturing: boolean)
		if destroyed then return end
		local distance = if observer then (observer - centre).Magnitude else math.huge
		local visibility = math.clamp((180 - distance) / 70, 0, 1)
		local reduced = settings.reducedMotion == true
		local targetWarmth = if observer then math.clamp((84 - distance) / 18, 0, 1) else 0
		warmth += (targetWarmth - warmth) * (1 - math.exp(-dt * 2))
		if warmth < 0.001 and targetWarmth == 0 then warmth = 0 end
		grade.Enabled = warmth > 0
		grade.TintColor = Color3.new(1, 1, 1):Lerp(rgb(255, 252, 241), warmth)
		grade.Saturation = 0.035 * warmth
		-- Continuous slow fades only; reduced-flashing players also lose ribbons.
		local weight = visibility * (if capturing then 0.2 else 1)
		local moving = not reduced and weight > 0.001
		if moving then clock += dt end
		root:SetAttribute("Active", moving)
		root:SetAttribute("Visibility", if moving then weight else 0)
		for i, leaf in leaves do
			if not moving then leaf.Transparency = 1 continue end
			local phase = (clock / (13 + i % 4) + i / LEAF_COUNT) % 1
			-- Travel around small arcs on the planted rim, always outside radius 48.
			local angle = i * TAU / LEAF_COUNT + phase * 0.42
			local radius = 54 + i % 4 * 2 + math.sin(clock * 0.45 + i) * 1.5
			local height = 4 + i % 3 * 2 + math.sin(phase * math.pi) * 1.8
			local position = V(math.sin(angle) * radius, height, -math.cos(angle) * radius)
			leaf.CFrame = frame * CFrame.new(position) * CFrame.Angles(
				math.sin(clock * 1.2 + i) * 0.5, -angle + clock * 0.4, math.sin(clock + i) * 0.6)
			leaf.Transparency = 1 - math.sin(phase * math.pi) ^ 2 * 0.78 * weight
		end
		for i, gust in gusts do
			local enabled = moving and not settings.reducedFlashing and not capturing
			gust.beam.Enabled = enabled
			if not enabled then continue end
			local phase = (clock / 17 + (i - 1) / GUST_COUNT) % 1
			local angle = (i - 1) * TAU / GUST_COUNT + 0.8 + phase * 0.4
			gust.anchor.CFrame = frame * CFrame.new(math.sin(angle) * 55, 6 + i * 1.3, -math.cos(angle) * 55)
				* CFrame.Angles(0, -angle, 0)
			local opacity = math.sin(phase * math.pi) ^ 4 * 0.18 * weight
			gust.beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 1 - opacity),
				NumberSequenceKeypoint.new(0.7, 1 - opacity),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
	end
	function controller.destroy()
		if destroyed then return end
		destroyed = true
		root:Destroy()
		grade:Destroy()
	end
	return controller
end

function Atmosphere.init()
	if started then return end
	started = true
	captureListener = Net.on("CaptureState", function(state)
		capturing = typeof(state) == "table"
	end)
	local elapsed = 0
	heartbeat = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / 30 then return end
		local step = math.min(elapsed, 0.1)
		elapsed = 0
		local regions = workspace:FindFirstChild("Regions")
		local region = if regions then regions:FindFirstChild("gusty_gardens") else nil
		if active and active.region ~= region then active.destroy() active = nil end
		if not active and region and region:IsA("Model") and typeof(region:GetAttribute("Centre")) == "Vector3" then
			active = Atmosphere.create(region)
		end
		if not active then return end
		local character = Players.LocalPlayer.Character
		local hrp = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local observer = if hrp and hrp:IsA("BasePart") then hrp.Position else nil
		local snapshot = State.get()
		local settings = if snapshot then snapshot.settings else { reducedMotion = false, reducedFlashing = false }
		active.step(step, observer, settings, capturing)
	end)
end

function Atmosphere.destroy()
	if heartbeat then heartbeat:Disconnect() heartbeat = nil end
	if captureListener then captureListener:Disconnect() captureListener = nil end
	if active then active.destroy() active = nil end
	capturing = false
	started = false
end

return Atmosphere
