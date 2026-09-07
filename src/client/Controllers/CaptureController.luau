--!strict
-- The player's half of a capture: pick a target, ask the server to start,
-- render what the server tells you, and get out of the way of the hazards.
--
-- This module never decides anything that matters. It does not know whether a
-- hazard hit; it draws the telegraph the server sent and waits to be told.
-- Everything it creates lives in Workspace.ClientFX, which only this client has.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local Net = require(script.Parent.Parent.Net)
local State = require(script.Parent.Parent.State)
local Input = require(script.Parent.Input)

local CaptureController = {}

local player = Players.LocalPlayer
-- Never cache the camera. Roblox replaces workspace.CurrentCamera shortly after
-- the client starts, and a reference taken at load then projects everything
-- off-screen: that is why clicking on, and pointing at, a creature silently
-- found nothing while the same maths against the live camera worked.
local function camera(): Camera
	return workspace.CurrentCamera
end

local TARGET_RANGE = 34
local TETHER_TOOL = "Containment Tether"
local LABEL_RANGE = 90

local fxFolder: Folder? = nil
local labels: { [Model]: BillboardGui } = {}
local activeHazards: { { event: Types.HazardEvent, parts: { BasePart }, cleaned: boolean } } = {}
local currentTarget: Model? = nil
local highlight: SelectionBox? = nil
local rangeRing: BasePart? = nil
local tetherBeam: { attachment0: Attachment, attachment1: Attachment, beam: Beam, holder: BasePart }? = nil
local captureState: Types.CaptureState? = nil
local pullTarget: { position: Vector3, radius: number, strength: number, until_: number }? = nil
local RING_SEGMENTS = 32
local warningGeneration = 0

local CaptureHUD: any = nil

local function hud(): any
	if not CaptureHUD then
		local ok, module = pcall(require, script.Parent.Parent.UI.CaptureHUD)
		if ok then
			CaptureHUD = module
		end
	end
	return CaptureHUD
end

local function fx(): Folder
	if not fxFolder or not fxFolder.Parent then
		local existing = workspace:FindFirstChild("ClientFX")
		if existing and existing:IsA("Folder") then
			fxFolder = existing
		else
			local folder = Instance.new("Folder")
			folder.Name = "ClientFX"
			folder.Parent = workspace
			fxFolder = folder
		end
	end
	return fxFolder :: Folder
end

local function settings()
	local snap = State.get()
	if snap then
		return snap.settings
	end
	return { music = 0.6, sfx = 0.8, reducedMotion = false, reducedFlashing = false, notifications = true }
end

local function rootPart(): BasePart?
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	return if hrp and hrp:IsA("BasePart") then hrp else nil
end

local function horizontal(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function makePart(name: string, size: Vector3, cf: CFrame, color: Color3, transparency: number, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Transparency = transparency
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Parent = fx()
	return p
end

-- ---------------------------------------------------------------- encounter labels

local function labelFor(model: Model): BillboardGui
	local existing = labels[model]
	if existing and existing.Parent then
		return existing
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EncounterLabel"
	-- Fixed pixel size: sized in studs this ballooned to fill the screen exactly
	-- when you were close enough to read it, and ran off the edge.
	billboard.Size = UDim2.fromOffset(230, 66)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, (model:GetAttribute("Height") :: number? or 3) + 2.2, 0)
	billboard.MaxDistance = LABEL_RANGE
	billboard.Parent = model

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 252, 245)
	text.TextStrokeTransparency = 0.2
	text.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
	text.Parent = billboard

	labels[model] = billboard
	return billboard
end

local function describe(model: Model): string
	local speciesId = model:GetAttribute("SpeciesId")
	local def = if typeof(speciesId) == "string" then Config.Species.byId[speciesId] else nil
	if not def then
		return "?"
	end
	local difficulty = (model:GetAttribute("Difficulty") :: number?) or 1
	local stars = string.rep("*", difficulty) .. string.rep("-", math.max(0, 5 - difficulty))
	local claimedBy = model:GetAttribute("ClaimedBy")
	local claimed = ""
	if typeof(claimedBy) == "number" and claimedBy ~= 0 then
		if claimedBy == player.UserId then
			claimed = "\nYou are catching this"
		else
			local other = Players:GetPlayerByUserId(claimedBy)
			claimed = "\nBeing caught by " .. (if other then other.DisplayName else "someone")
		end
	end
	return def.name .. "\n" .. Config.Rarities.label(def.rarity) .. "  " .. def.element .. "  " .. stars .. claimed
end

local function refreshLabels()
	local hrp = rootPart()
	for _, model in CollectionService:GetTagged("Wild") do
		if model:IsA("Model") then
			local pivot = model:GetPivot().Position
			local near = hrp ~= nil and (pivot - hrp.Position).Magnitude <= LABEL_RANGE
			if near then
				local billboard = labelFor(model)
				local text = billboard:FindFirstChild("Text")
				if text and text:IsA("TextLabel") then
					text.Text = describe(model)
					local speciesId = model:GetAttribute("SpeciesId")
					local def = if typeof(speciesId) == "string" then Config.Species.byId[speciesId] else nil
					text.TextColor3 = if def then Config.Rarities.color(def.rarity) else Color3.fromRGB(255, 255, 255)
				end
			elseif labels[model] then
				labels[model]:Destroy()
				labels[model] = nil
			end
		end
	end
	for model, billboard in labels do
		if not model.Parent then
			billboard:Destroy()
			labels[model] = nil
		end
	end
end

-- ---------------------------------------------------------------- targeting

-- Creature bodies are built with CanQuery = false (ModelKit), so the camera
-- and every other ray pass through them; only the invisible 1-stud Root can be
-- hit. A ray therefore almost never lands on the creature a player is looking
-- at. So "pointing at a creature" is judged on screen: the wild model whose
-- projected body contains the point, nearest to the camera when they overlap.
-- The Root raycast still wins when it does land.
local function wildAtScreenPoint(x: number, y: number): Model?
	local cam = camera()
	local ray = cam:ViewportPointToRay(x, y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: any, fx() }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	if result then
		local inst: Instance? = result.Instance
		while inst and inst ~= workspace do
			if inst:IsA("Model") and CollectionService:HasTag(inst, "Wild") then
				return inst
			end
			inst = inst.Parent
		end
	end

	local hrp = rootPart()
	local viewport = cam.ViewportSize
	local halfFov = math.rad(cam.FieldOfView / 2)
	local best: Model? = nil
	local bestDepth = math.huge
	for _, model in CollectionService:GetTagged("Wild") do
		if not model:IsA("Model") then
			continue
		end
		local pivot = model:GetPivot().Position
		if hrp and (pivot - hrp.Position).Magnitude > TARGET_RANGE then
			continue
		end
		local height = (model:GetAttribute("Height") :: number?) or 3
		local centre = pivot + Vector3.new(0, height / 2, 0)
		local screen, onScreen = cam:WorldToViewportPoint(centre)
		if not onScreen or screen.Z <= 0 then
			continue
		end
		-- pixels per stud at this depth; the body is roughly a sphere of height/2,
		-- plus a hand's width of slack so a child does not have to be pixel-perfect
		local pxPerStud = (viewport.Y / 2) / (screen.Z * math.tan(halfFov))
		local radiusPx = (height / 2 + 0.75) * pxPerStud
		local dx, dy = screen.X - x, screen.Y - y
		if dx * dx + dy * dy <= radiusPx * radiusPx and screen.Z < bestDepth then
			best = model
			bestDepth = screen.Z
		end
	end
	return best
end

local function candidateUnderMouse(): Model?
	if Input.isTouch() or Input.isGamepad() then
		return nil
	end
	-- GetMouseLocation includes the top-bar inset; viewport maths does not
	local mouse = UserInputService:GetMouseLocation()
	local inset = GuiService:GetGuiInset()
	return wildAtScreenPoint(mouse.X - inset.X, mouse.Y - inset.Y)
end

local function nearestWild(): Model?
	local hrp = rootPart()
	if not hrp then
		return nil
	end
	local best: Model? = nil
	local bestScore = math.huge
	local look = camera().CFrame.LookVector
	for _, model in CollectionService:GetTagged("Wild") do
		if model:IsA("Model") then
			local delta = model:GetPivot().Position - hrp.Position
			local distance = delta.Magnitude
			if distance <= TARGET_RANGE then
				-- prefer what the camera is pointed at, then what is closest
				local facing = if distance > 0.1 then delta.Unit:Dot(look) else 1
				local score = distance * (1.6 - math.clamp(facing, -1, 1) * 0.6)
				if score < bestScore then
					bestScore = score
					best = model
				end
			end
		end
	end
	return best
end

-- What the target card tells the player to do. The touch Capture button is
-- hidden on keyboards, so "tap Capture" is wrong there; and a mouse click only
-- reaches capture through the handler in init(), so say so.
local function captureHint(): string
	if Input.isTouch() then
		return "Tap Capture"
	elseif Input.isGamepad() then
		return "Press X"
	end
	return "Press E or click"
end

local function setTarget(model: Model?)
	if currentTarget == model then
		return
	end
	currentTarget = model
	if not highlight then
		local box = Instance.new("SelectionBox")
		box.Name = "TargetHighlight"
		box.LineThickness = 0.06
		box.SurfaceTransparency = 0.85
		box.Color3 = Color3.fromRGB(255, 220, 120)
		box.SurfaceColor3 = Color3.fromRGB(255, 220, 120)
		box.Parent = fx()
		highlight = box
	end
	if highlight then
		highlight.Adornee = model
	end

	local info = nil
	if model then
		local speciesId = model:GetAttribute("SpeciesId")
		local def = if typeof(speciesId) == "string" then Config.Species.byId[speciesId] else nil
		if def then
			local claimedBy = model:GetAttribute("ClaimedBy")
			info = {
				uid = model:GetAttribute("EncounterUid"),
				name = def.name,
				rarity = def.rarity,
				element = def.element,
				difficulty = (model:GetAttribute("Difficulty") :: number?) or 1,
				claimedBy = if typeof(claimedBy) == "number" and claimedBy ~= 0 and claimedBy ~= player.UserId then claimedBy else nil,
				hint = captureHint(),
			}
		end
	end
	local h = hud()
	if h and h.setTarget then
		h.setTarget(info)
	end
end

-- ---------------------------------------------------------------- tether + ring

local function ensureRangeRing(): BasePart
	if rangeRing and rangeRing.Parent then
		return rangeRing
	end
	local ring = makePart("RangeRing", Vector3.new(0.2, 1, 1), CFrame.new(), Color3.fromRGB(120, 230, 255), 0.75, Enum.PartType.Cylinder)
	rangeRing = ring
	return ring
end

local function ensureTether()
	if tetherBeam and tetherBeam.holder.Parent then
		return tetherBeam
	end
	local holder = makePart("TetherHolder", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), Color3.fromRGB(255, 220, 120), 1)
	local a0 = Instance.new("Attachment")
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Parent = holder
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.35
	beam.Width1 = 0.5
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
	beam.LightEmission = 0.8
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureSpeed = 2
	beam.TextureLength = 3
	beam.Parent = holder
	tetherBeam = { attachment0 = a0, attachment1 = a1, beam = beam, holder = holder }
	return tetherBeam
end

local function clearTether()
	if tetherBeam then
		tetherBeam.holder:Destroy()
		tetherBeam = nil
	end
	if rangeRing then
		rangeRing:Destroy()
		rangeRing = nil
	end
end

local function encounterModel(uid: string): Model?
	for _, model in CollectionService:GetTagged("Wild") do
		if model:IsA("Model") and model:GetAttribute("EncounterUid") == uid then
			return model
		end
	end
	return nil
end

-- ---------------------------------------------------------------- hazards

local function hazardColor(ev: Types.HazardEvent, active: boolean): Color3
	if ev.boss then
		return if active then Color3.fromRGB(255, 90, 80) else Color3.fromRGB(255, 150, 120)
	end
	return if active then ev.color else ev.color:Lerp(Color3.fromRGB(255, 255, 255), 0.35)
end

local function spawnHazard(ev: Types.HazardEvent)
	local s = settings()
	local parts: { BasePart } = {}
	local telegraphColor = hazardColor(ev, false)

	if ev.shape == "line" then
		-- show the whole swept path during the telegraph, then the wall itself
		local pathLength = ev.travel
		local centre = ev.origin + ev.direction * (pathLength / 2)
		local pathPart = makePart(
			"HazardPath",
			Vector3.new(ev.length * 2, 0.25, pathLength),
			CFrame.lookAt(Vector3.new(centre.X, ev.origin.Y + 0.15, centre.Z), Vector3.new(centre.X, ev.origin.Y + 0.15, centre.Z) + ev.direction),
			telegraphColor,
			0.8
		)
		table.insert(parts, pathPart)
		local wallH = Config.Capture.wallHeight
		local wall = makePart(
			"HazardWall",
			Vector3.new(ev.length * 2, wallH, ev.width * 2),
			CFrame.lookAt(ev.origin + Vector3.new(0, wallH / 2, 0), ev.origin + Vector3.new(0, wallH / 2, 0) + ev.direction),
			telegraphColor,
			0.6
		)
		table.insert(parts, wall)
	elseif ev.shape == "ring" then
		-- Hollow bands leave the safe centre visible, including the final-radius
		-- outline shown during the warning.
		for i = 1, RING_SEGMENTS do
			local a = (i - 1) * math.pi * 2 / RING_SEGMENTS
			local band = makePart("HazardRing", Vector3.new(0.1, Config.Capture.ringHeight, 0.1), CFrame.new(ev.origin), telegraphColor, 0.6)
			table.insert(parts, band)
			local outline = makePart("HazardRingOutline", Vector3.new(0.16, 0.15, ev.travel * math.pi * 2 / RING_SEGMENTS * 1.03),
				CFrame.new(ev.origin + Vector3.new(math.cos(a) * ev.travel, 0.1, math.sin(a) * ev.travel)) * CFrame.Angles(0, -a, 0), telegraphColor, 0.75)
			table.insert(parts, outline)
		end
	elseif ev.shape == "circles" then
		for _, position in ev.positions do
			local disc = makePart(
				"HazardPatch",
				Vector3.new(0.3, ev.radius * 2, ev.radius * 2),
				CFrame.new(position + Vector3.new(0, 0.16, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				telegraphColor,
				0.65,
				Enum.PartType.Cylinder
			)
			table.insert(parts, disc)
		end
	elseif ev.shape == "pull" then
		local centre = ev.positions[1]
		if centre then
			local zone = makePart(
				"HazardWell",
				Vector3.new(0.3, ev.radius * 2, ev.radius * 2),
				CFrame.new(centre + Vector3.new(0, 0.16, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				telegraphColor,
				0.6,
				Enum.PartType.Cylinder
			)
			table.insert(parts, zone)
			local column = makePart("HazardWellColumn", Vector3.new(ev.radius, 14, ev.radius), CFrame.new(centre + Vector3.new(0, 7, 0)), telegraphColor, 0.88, Enum.PartType.Ball)
			table.insert(parts, column)
			pullTarget = { position = centre, radius = ev.radius, strength = ev.pullStrength, until_ = ev.telegraphEndsAt }
		end
	end

	for _, p in parts do
		p:SetAttribute("HazardId", ev.id)
	end
	if s.reducedFlashing then
		for _, p in parts do
			p.Material = Enum.Material.SmoothPlastic
		end
	end

	table.insert(activeHazards, { event = ev, parts = parts, cleaned = false })

	local h = hud()
	if h and h.setHazardWarning then
		warningGeneration += 1
		local generation = warningGeneration
		local def = Config.Capture.hazards[ev.element]
		h.setHazardWarning(if def then def.warning else "Incoming!", ev.color)
		task.delay(math.max(0.8, ev.activeEndsAt - workspace:GetServerTimeNow()), function()
			if generation == warningGeneration and h.setHazardWarning then
				h.setHazardWarning(nil, nil)
			end
		end)
	end
end

local function stepHazards(now: number)
	for i = #activeHazards, 1, -1 do
		local entry = activeHazards[i]
		local ev = entry.event
		if now > ev.activeEndsAt + 0.35 then
			for _, p in entry.parts do
				p:Destroy()
			end
			table.remove(activeHazards, i)
			continue
		end
		local active = now >= ev.telegraphEndsAt
		local span = math.max(0.05, ev.activeEndsAt - ev.telegraphEndsAt)
		local u = math.clamp((now - ev.telegraphEndsAt) / span, 0, 1)
		local colour = hazardColor(ev, active)

		if ev.shape == "line" then
			local wall = entry.parts[2]
			if wall then
				local centre = ev.origin + ev.direction * (ev.travel * u)
				local mid = ev.origin.Y + Config.Capture.wallHeight / 2
				wall.CFrame = CFrame.lookAt(Vector3.new(centre.X, mid, centre.Z), Vector3.new(centre.X, mid, centre.Z) + ev.direction)
				wall.Color = colour
				wall.Transparency = if active then 0.35 else 0.7
			end
			local pathPart = entry.parts[1]
			if pathPart then
				pathPart.Transparency = if active then 0.9 else 0.8
			end
		elseif ev.shape == "ring" then
			local r = math.max(0.05, ev.travel * u)
			local inner = math.max(0, r - ev.radius)
			local outer = r + ev.radius
			local middle = (inner + outer) / 2
			for j = 1, RING_SEGMENTS do
				local ring = entry.parts[j * 2 - 1]
				local a = (j - 1) * math.pi * 2 / RING_SEGMENTS
				ring.Size = Vector3.new(outer - inner, Config.Capture.ringHeight, outer * math.pi * 2 / RING_SEGMENTS * 1.03)
				ring.CFrame = CFrame.new(ev.origin + Vector3.new(math.cos(a) * middle, Config.Capture.ringHeight / 2, math.sin(a) * middle)) * CFrame.Angles(0, -a, 0)
				ring.Color = colour
				ring.Transparency = if active then 0.35 else 0.6
				entry.parts[j * 2].Transparency = if active then 0.95 else 0.75
			end
		elseif ev.shape == "circles" then
			for _, disc in entry.parts do
				disc.Color = colour
				if active then
					disc.Transparency = 0.2
				else
					-- fill up as the warning runs out
					local warn = math.clamp((now - (ev.telegraphEndsAt - Config.Capture.hazards[ev.element].telegraph)) / math.max(0.1, Config.Capture.hazards[ev.element].telegraph), 0, 1)
					disc.Transparency = 0.75 - warn * 0.3
				end
			end
		elseif ev.shape == "pull" then
			for _, p in entry.parts do
				p.Color = colour
				p.Transparency = if active then 0.25 else 0.72
			end
		end
	end
end

-- The gravity well tugs the local character while it is charging. This is a
-- client-side nudge on the client's own humanoid, never a server teleport.
local function applyPull(dt: number)
	local target = pullTarget
	if not target then
		return
	end
	local now = workspace:GetServerTimeNow()
	if now >= target.until_ then
		pullTarget = nil
		return
	end
	local hrp = rootPart()
	if not hrp then
		return
	end
	local delta = horizontal(target.position - hrp.Position)
	if delta.Magnitude < 1 or delta.Magnitude > target.radius then
		return
	end
	-- Reduced motion affects presentation, not capture difficulty.
	local pull = delta.Unit * target.strength
	hrp.AssemblyLinearVelocity = Vector3.new(
		hrp.AssemblyLinearVelocity.X + pull.X * dt,
		hrp.AssemblyLinearVelocity.Y,
		hrp.AssemblyLinearVelocity.Z + pull.Z * dt
	)
end

-- ---------------------------------------------------------------- remotes

function CaptureController.onCaptureState(state: Types.CaptureState?)
	captureState = state
	local h = hud()
	if h and h.setState then
		h.setState(state)
	end
	if not state then
		warningGeneration += 1
		clearTether()
		pullTarget = nil
		for _, entry in activeHazards do
			for _, p in entry.parts do
				p:Destroy()
			end
		end
		table.clear(activeHazards)
		Input.setActionLabel("Capture", "Capture")
		Input.setActionVisible("Cancel", false)
	else
		Input.setActionLabel("Capture", "Cancel")
		Input.setActionVisible("Cancel", true)
	end
end

function CaptureController.onHazard(ev: any)
	if typeof(ev) ~= "table" or typeof(ev.shape) ~= "string" then
		return
	end
	local ok, err = pcall(spawnHazard, ev)
	if not ok then
		warn("[Capture] hazard render failed: " .. tostring(err))
	end
end

function CaptureController.onKnockback(direction: any, strength: any)
	if typeof(direction) ~= "Vector3" or typeof(strength) ~= "number" then
		return
	end
	local hrp = rootPart()
	if not hrp then
		return
	end
	local s = settings()
	local push = if s.reducedMotion then strength * 0.5 else strength
	hrp.AssemblyLinearVelocity = Vector3.new(direction.X * push, math.max(hrp.AssemblyLinearVelocity.Y, 18), direction.Z * push)
end

-- ---------------------------------------------------------------- actions

local function toggleCapture()
	if captureState then
		Net.fire("CancelCapture")
		return
	end
	local target = currentTarget
	if not target then
		target = nearestWild()
		setTarget(target)
	end
	if not target then
		return
	end
	local uid = target:GetAttribute("EncounterUid")
	if typeof(uid) == "string" then
		Net.fire("StartCapture", uid)
	end
end

-- The Containment Tether tool is the visible instrument for a capture, but it
-- is not required: E, the touch button and the tool all reach the same action,
-- so unequipping it never strands the player.
local function watchTool()
	local function hook(tool: Instance)
		if tool:IsA("Tool") and tool.Name == TETHER_TOOL then
			tool.Activated:Connect(toggleCapture)
		end
	end
	local function watch(container: Instance)
		for _, child in container:GetChildren() do
			hook(child)
		end
		container.ChildAdded:Connect(hook)
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watch(backpack)
	end
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watch(child)
		end
	end)
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

function CaptureController.init()
	Input.onAction("Capture", toggleCapture)
	watchTool()

	-- Mouse: clicking the creature you are pointing at starts the tether, the
	-- same as E. It only ever starts, never cancels, so a stray click cannot drop
	-- a capture in progress; Q and E still cancel. Skipped while the Containment
	-- Tether is equipped, because the Tool's own Activated already fires
	-- toggleCapture and the two would cancel each other out.
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if RunService:IsStudio() then
			-- Studio-only diagnostics for the "clicking a creature does nothing" report:
			-- record exactly what this handler saw, readable from PlayerGui attributes.
			local pg = player:FindFirstChildOfClass("PlayerGui")
			if pg then
				local seen = wildAtScreenPoint(input.Position.X, input.Position.Y)
				local tool = player.Character and player.Character:FindFirstChild(TETHER_TOOL)
				pg:SetAttribute("ClickDiagCount", ((pg:GetAttribute("ClickDiagCount") :: number?) or 0) + 1)
				pg:SetAttribute("ClickDiagLast", "processed=" .. tostring(processed)
					.. " capturing=" .. tostring(captureState ~= nil)
					.. " touch=" .. tostring(Input.isTouch()) .. " gamepad=" .. tostring(Input.isGamepad())
					.. " tool=" .. tostring(tool ~= nil)
					.. " pos=" .. tostring(math.floor(input.Position.X)) .. "," .. tostring(math.floor(input.Position.Y))
					.. " creatureUnderPoint=" .. tostring(seen and seen:GetAttribute("SpeciesId") or "none"))
				-- and the maths for the nearest wild creature, so a miss explains itself
				local hrpD = rootPart()
				local nearest, nearestD = nil, math.huge
				for _, m in CollectionService:GetTagged("Wild") do
					if m:IsA("Model") and hrpD then
						local d = (m:GetPivot().Position - hrpD.Position).Magnitude
						if d < nearestD then nearest, nearestD = m, d end
					end
				end
				if nearest then
					local cam = camera()
					local height = (nearest:GetAttribute("Height") :: number?) or 3
					local screen, onScreen = cam:WorldToViewportPoint(nearest:GetPivot().Position + Vector3.new(0, height / 2, 0))
					local pxPerStud = (cam.ViewportSize.Y / 2) / (math.max(screen.Z, 0.01) * math.tan(math.rad(cam.FieldOfView / 2)))
					pg:SetAttribute("ClickDiagNearest", tostring(nearest:GetAttribute("SpeciesId"))
						.. " dist=" .. tostring(math.floor(nearestD * 10) / 10) .. " range=" .. tostring(TARGET_RANGE)
						.. " height=" .. tostring(height)
						.. " screen=" .. tostring(math.floor(screen.X)) .. "," .. tostring(math.floor(screen.Y)) .. "," .. tostring(math.floor(screen.Z * 10) / 10)
						.. " onScreen=" .. tostring(onScreen)
						.. " radiusPx=" .. tostring(math.floor((height / 2 + 0.75) * pxPerStud))
						.. " viewport=" .. tostring(cam.ViewportSize) .. " camType=" .. tostring(cam.CameraType))
				end
			end
		end
		if processed or captureState then
			return
		end
		if Input.isTouch() or Input.isGamepad() then
			return
		end
		local character = player.Character
		if character and character:FindFirstChild(TETHER_TOOL) then
			return
		end
		local under = wildAtScreenPoint(input.Position.X, input.Position.Y)
		if under then
			setTarget(under)
			toggleCapture()
		end
	end)
	Input.onAction("Cancel", function()
		if captureState then
			Net.fire("CancelCapture")
		end
	end)

	Net.on("CaptureState", function(state)
		CaptureController.onCaptureState(if typeof(state) == "table" then state else nil)
	end)
	Net.on("Hazard", CaptureController.onHazard)
	Net.on("Knockback", CaptureController.onKnockback)

	local labelAccumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = workspace:GetServerTimeNow()

		labelAccumulator += dt
		if labelAccumulator >= 0.25 then
			labelAccumulator = 0
			refreshLabels()
			if not captureState then
				setTarget(candidateUnderMouse() or nearestWild())
			end
		end

		stepHazards(now)
		applyPull(dt)

		-- tether beam and range ring while capturing
		if captureState then
			local model = encounterModel(captureState.encounterUid)
			local hrp = rootPart()
			if model and hrp then
				setTarget(model)
				local snap = State.get()
				local range = if snap then snap.derived.tetherRange else Config.Capture.tetherRange
				local ring = ensureRangeRing()
				local pivot = model:GetPivot().Position
				ring.Size = Vector3.new(0.2, range * 2, range * 2)
				ring.CFrame = CFrame.new(pivot.X, 0.35, pivot.Z) * CFrame.Angles(0, 0, math.rad(90))
				ring.Color = if captureState.inRange then Color3.fromRGB(120, 230, 160) else Color3.fromRGB(255, 130, 120)

				local tether = ensureTether()
				if tether then
					tether.attachment0.WorldPosition = hrp.Position
					tether.attachment1.WorldPosition = pivot + Vector3.new(0, 1.5, 0)
					tether.beam.Color = ColorSequence.new(if captureState.inRange then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(255, 120, 110))
					tether.beam.Enabled = true
				end
			end
		end
	end)
end

return CaptureController
