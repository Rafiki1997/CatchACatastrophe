--!strict
-- The seven-step tutorial card, plus a beam from the player to whatever the
-- current step is talking about. The beam matters more than the words: a
-- six-year-old will follow a line without reading anything.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local W = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local Net = require(script.Parent.Parent.Net)
local State = require(script.Parent.Parent.State)

local TutorialUI = {}

local player = Players.LocalPlayer

local card: Frame? = nil
local titleLabel: TextLabel? = nil
local bodyLabel: TextLabel? = nil
local stepLabel: TextLabel? = nil
local gotItButton: TextButton? = nil

local currentStep = 1
local done = false
local beamHolder: BasePart? = nil
-- The guide is a chain of beams along the roads, not one straight line through
-- whatever stands between the player and the target.
type Segment = { a: Attachment, b: Attachment, beam: Beam }
local segments: { Segment } = {}
local MAX_SEGMENTS = 20
local GUIDE_HEIGHT = 1.6

-- ---------------------------------------------------------------- road graph
-- Roads are the navigation graph: their ends are nodes, each road an edge.
type Road = { a: Vector3, b: Vector3, ia: number, ib: number }
local graphNodes: { Vector3 } = {}
local graphAdj: { [number]: { { to: number, w: number } } } = {}
local graphRoads: { Road } = {}
local graphCount = -1
-- The hub plaza (radius 70) is open ground: every road end on it connects to
-- every other, since the spokes stop at the kiosks and the region and plot
-- roads only begin at its rim.
local PLAZA_RADIUS = 78

local function nodeFor(p: Vector3): number
	for i, n in graphNodes do
		if (n - p).Magnitude < 4 then
			return i
		end
	end
	table.insert(graphNodes, p)
	graphAdj[#graphNodes] = {}
	return #graphNodes
end

local function link(i: number, j: number, w: number)
	table.insert(graphAdj[i], { to = j, w = w })
	table.insert(graphAdj[j], { to = i, w = w })
end

local function buildGraph()
	local parts: { BasePart } = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Path" then
			table.insert(parts, d)
		end
	end
	if #parts == graphCount then
		return
	end
	graphCount = #parts
	graphNodes, graphAdj, graphRoads = {}, {}, {}
	for _, p in parts do
		local half = p.CFrame.LookVector * (p.Size.Z / 2)
		local a, b = p.Position + half, p.Position - half
		local ia, ib = nodeFor(a), nodeFor(b)
		link(ia, ib, (a - b).Magnitude)
		table.insert(graphRoads, { a = a, b = b, ia = ia, ib = ib })
	end
	local onPlaza: { number } = {}
	for i, n in graphNodes do
		if Vector3.new(n.X, 0, n.Z).Magnitude <= PLAZA_RADIUS then
			table.insert(onPlaza, i)
		end
	end
	for x = 1, #onPlaza do
		for y = x + 1, #onPlaza do
			link(onPlaza[x], onPlaza[y], (graphNodes[onPlaza[x]] - graphNodes[onPlaza[y]]).Magnitude)
		end
	end
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function nearestOnRoads(p: Vector3): (Vector3?, Road?, number)
	local best: Vector3? = nil
	local bestRoad: Road? = nil
	local bestD = math.huge
	for _, road in graphRoads do
		local ab = road.b - road.a
		local t = math.clamp((p - road.a):Dot(ab) / math.max(ab:Dot(ab), 0.001), 0, 1)
		local q = road.a + ab * t
		local d = (flat(q) - flat(p)).Magnitude
		if d < bestD then
			best, bestRoad, bestD = q, road, d
		end
	end
	return best, bestRoad, bestD
end

-- Where a point joins the graph: on the plaza it reaches every plaza node
-- directly (open ground); elsewhere it enters at the nearest point of the
-- nearest road, within `limit` studs. Returns seed distances per node and the
-- entry point on the road (nil on the plaza), or nil when nothing is near.
local function seeds(p: Vector3, limit: number): ({ [number]: number }?, Vector3?)
	local out: { [number]: number } = {}
	if flat(p).Magnitude <= PLAZA_RADIUS then
		for i, n in graphNodes do
			if flat(n).Magnitude <= PLAZA_RADIUS then
				out[i] = (n - p).Magnitude
			end
		end
		return out, nil
	end
	local q, road, d = nearestOnRoads(p)
	if not q or not road or d > limit then
		return nil, nil
	end
	out[road.ia] = (q - road.a).Magnitude
	out[road.ib] = (q - road.b).Magnitude
	return out, q
end

-- Points from `from` to `to` along the roads; a straight line when an end is
-- nowhere near a road (a creature deep in the wild), when both are on the open
-- plaza, or when the roads would be a real detour.
local function route(from: Vector3, to: Vector3): { Vector3 }
	buildGraph()
	local seedIn, pIn = seeds(from, 60)
	local seedOut, pOut = seeds(to, 90)
	if not seedIn or not seedOut or (pIn == nil and pOut == nil) then
		return { from, to }
	end
	local n = #graphNodes
	local dist: { number } = table.create(n, math.huge)
	local prev: { number? } = {}
	local visited: { boolean } = {}
	for i, d in seedIn do
		dist[i] = d
	end
	for _ = 1, n do
		local u: number? = nil
		local best = math.huge
		for i = 1, n do
			if not visited[i] and dist[i] < best then
				u, best = i, dist[i]
			end
		end
		if not u then
			break
		end
		visited[u] = true
		for _, e in graphAdj[u] do
			local nd = best + e.w
			if nd < dist[e.to] then
				dist[e.to] = nd
				prev[e.to] = u
			end
		end
	end
	local last: number? = nil
	local bestTotal = math.huge
	for i, d in seedOut do
		if dist[i] + d < bestTotal then
			last, bestTotal = i, dist[i] + d
		end
	end
	if not last then
		return { from, to }
	end
	local chain: { Vector3 } = {}
	local cur: number? = last
	while cur do
		table.insert(chain, 1, graphNodes[cur])
		cur = prev[cur]
	end
	local points = { from }
	if pIn then
		table.insert(points, pIn)
	end
	for _, p in chain do
		table.insert(points, p)
	end
	if pOut then
		table.insert(points, pOut)
	end
	table.insert(points, to)
	-- Drop repeated points (entry and exit on the same road end) and give up on
	-- the roads when they are a real detour: a target a few studs away across
	-- open ground should not send the player down to the road and back.
	local cleaned = { points[1] }
	local length = 0
	for i = 2, #points do
		local lastPoint = cleaned[#cleaned]
		if (flat(points[i]) - flat(lastPoint)).Magnitude > 1 then
			length += (flat(points[i]) - flat(lastPoint)).Magnitude
			table.insert(cleaned, points[i])
		end
	end
	-- Ground distances only: a player mid-jump must not flip the choice.
	local direct = (flat(to) - flat(from)).Magnitude
	if direct <= 30 or length > direct * 1.5 + 12 then
		return { from, to }
	end
	return cleaned
end

local function ensureBeam()
	if beamHolder and beamHolder.Parent then
		return
	end
	local holder = Instance.new("Part")
	holder.Name = "TutorialBeam"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Parent = workspace
	segments = {}
	for _ = 1, MAX_SEGMENTS do
		local a = Instance.new("Attachment")
		a.Parent = holder
		local b = Instance.new("Attachment")
		b.Parent = holder
		local line = Instance.new("Beam")
		line.Attachment0 = a
		line.Attachment1 = b
		line.Width0 = 1.4
		line.Width1 = 1.4
		line.FaceCamera = true
		line.Color = ColorSequence.new(Theme.colors.accent)
		line.LightEmission = 0.9
		line.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		-- Wrap repeats the texture every TextureLength studs on every segment, so
		-- the guide is a row of dots whatever the segment length (Stretch spread a
		-- fixed count over each beam: lines on long legs, dots on short ones).
		line.TextureMode = Enum.TextureMode.Wrap
		line.TextureLength = 3
		line.TextureSpeed = 2
		line.Transparency = NumberSequence.new(0.1)
		line.Enabled = false
		line.Parent = holder
		table.insert(segments, { a = a, b = b, beam = line })
	end
	beamHolder = holder
end

local function hideRoute()
	for _, s in segments do
		s.beam.Enabled = false
	end
end

local function showRoute(points: { Vector3 })
	local needed = #points - 1
	for i, s in segments do
		if i <= needed then
			local p, q = points[i], points[i + 1]
			s.a.WorldPosition = Vector3.new(p.X, p.Y + GUIDE_HEIGHT, p.Z)
			s.b.WorldPosition = Vector3.new(q.X, q.Y + GUIDE_HEIGHT, q.Z)
			s.beam.Enabled = true
		else
			s.beam.Enabled = false
		end
	end
end

local function ownPlot(): Model?
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

-- Resolve the step's target key into a world position.
local function targetPosition(): Vector3?
	local def = Config.Quests.tutorial[currentStep]
	if not def or def.target == "none" then
		return nil
	end
	local key = def.target
	local kind, value = string.match(key, "^(%a+):(.+)$")

	if kind == "region" then
		local regions = workspace:FindFirstChild("Regions")
		local region = regions and regions:FindFirstChild(value)
		local entrance = region and region:FindFirstChild("Entrance")
		if entrance and entrance:IsA("BasePart") then
			return entrance.Position
		end
	elseif kind == "species" then
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local best: Vector3? = nil
		local bestDistance = math.huge
		for _, model in CollectionService:GetTagged("Wild") do
			if model:IsA("Model") and model:GetAttribute("SpeciesId") == value then
				local pivot = model:GetPivot().Position
				local distance = if hrp and hrp:IsA("BasePart") then (pivot - hrp.Position).Magnitude else 0
				if distance < bestDistance then
					bestDistance = distance
					best = pivot
				end
			end
		end
		if best then
			return best
		end
		-- none in sight: point at the region instead
		local regions = workspace:FindFirstChild("Regions")
		local speciesDef = Config.Species.byId[value]
		local region = regions and speciesDef and regions:FindFirstChild(speciesDef.region)
		local entrance = region and region:FindFirstChild("Entrance")
		if entrance and entrance:IsA("BasePart") then
			return entrance.Position
		end
	elseif kind == "plot" then
		local plot = ownPlot()
		if plot then
			if value == "collect" then
				local pad = plot:FindFirstChild("CollectPad")
				if pad and pad:IsA("BasePart") then
					return pad.Position
				end
			else
				local pads = plot:FindFirstChild("Pads")
				local pad = pads and pads:FindFirstChild("Pad_1")
				if pad and pad:IsA("BasePart") then
					return pad.Position
				end
			end
		end
	elseif kind == "hub" then
		local map = workspace:FindFirstChild("Map")
		-- the arena is its own model beside the hub, not a kiosk inside it
		if value == "arena" then
			local arena = map and map:FindFirstChild("Arena")
			local floor = arena and arena:FindFirstChild("Floor")
			if floor and floor:IsA("BasePart") then
				return floor.Position
			end
		end
		local hub = map and (map :: Instance):FindFirstChild("Hub")
		local building = hub and hub:FindFirstChild(if value == "workshop" then "Workshop" else "AtlasKiosk")
		local terminal = building and building:FindFirstChild("Terminal")
		if terminal and terminal:IsA("BasePart") then
			return terminal.Position
		end
	end
	return nil
end

function TutorialUI.init()
	local gui = W.screenGui("CatchTutorial", 3)
	W.attachScale(gui)
	local safe = W.safeArea(gui)

	card = W.frame({
		parent = safe,
		name = "TutorialCard",
		size = UDim2.new(0, 300, 0, 132),
		position = UDim2.new(1, -14, 1, -160),
		anchor = Vector2.new(1, 1),
		color = Theme.colors.bg,
		radius = Theme.sizes.radius,
		stroke = Theme.colors.accent,
		strokeThickness = 3,
		visible = false,
	})
	stepLabel = W.label({
		parent = card,
		text = "",
		size = UDim2.new(0, 90, 0, 18),
		position = UDim2.new(0, 12, 0, 8),
		textSize = 13,
		font = Theme.fonts.bold,
		color = Theme.colors.accent,
		xalign = Enum.TextXAlignment.Left,
	})
	titleLabel = W.label({
		parent = card,
		text = "",
		size = UDim2.new(1, -24, 0, 26),
		position = UDim2.new(0, 12, 0, 26),
		textSize = 19,
		font = Theme.fonts.title,
		color = Theme.colors.text,
		xalign = Enum.TextXAlignment.Left,
	})
	bodyLabel = W.label({
		parent = card,
		text = "",
		size = UDim2.new(1, -24, 0, 56),
		position = UDim2.new(0, 12, 0, 52),
		textSize = 14,
		font = Theme.fonts.body,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
	})
	gotItButton = W.button({
		parent = card,
		text = "Got it",
		size = UDim2.new(0, 96, 0, 28),
		position = UDim2.new(1, -12, 1, -8),
		anchor = Vector2.new(1, 1),
		color = Theme.colors.accent,
		textColor = Theme.colors.ink,
		textSize = 15,
		onClick = function()
			Net.fire("TutorialAdvance", currentStep)
		end,
	})

	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.2 then
			return
		end
		accumulator = 0
		if done or #segments == 0 then
			hideRoute()
			return
		end
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local target = targetPosition()
		if hrp and hrp:IsA("BasePart") and target then
			showRoute(route(hrp.Position, target))
		else
			hideRoute()
		end
	end)
end

function TutorialUI.setStep(step: number, isDone: boolean)
	local previousStep = currentStep
	currentStep = math.clamp(step, 1, Config.Quests.tutorialDoneStep)
	done = isDone or step >= Config.Quests.tutorialDoneStep
	ensureBeam()

	if not card then
		return
	end
	if done then
		card.Visible = false
		hideRoute()
		return
	end

	local def = Config.Quests.tutorial[currentStep]
	if not def then
		card.Visible = false
		return
	end
	local shouldAnimate = not card.Visible or currentStep ~= previousStep
	card.Visible = true
	if stepLabel then
		stepLabel.Text = "STEP " .. tostring(def.step) .. " / " .. tostring(#Config.Quests.tutorial)
	end
	if titleLabel then
		titleLabel.Text = def.title
	end
	if bodyLabel then
		bodyLabel.Text = def.body
	end
	if gotItButton then
		gotItButton.Visible = def.info
	end
	local snap = State.get()
	if shouldAnimate and (not snap or not snap.settings.reducedMotion) then
		W.pop(card, 1.08)
	end
end

function TutorialUI.update(snap: any)
	if typeof(snap) == "table" and snap.quests then
		TutorialUI.setStep(snap.quests.tutorialStep, snap.quests.tutorialDone)
	end
end

return TutorialUI
