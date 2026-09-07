--!strict
-- Waypoint signs: the name of every region gate, every hub destination and your
-- own city, floating in the air above it in that place's colour, outlined in
-- ink. The text is sized as if it were TITLE_HEIGHT studs tall in the world, so
-- a far gate reads as a small name on the horizon and a near one as a big one,
-- the way a painted sign would. The size is set in pixels every frame from the
-- camera depth, clamped so a sign never grows past its size at NEAR studs (no
-- ballooning when you walk up) and never shrinks below its size at FAR studs
-- (far names stay legible). BillboardGui.DistanceLowerLimit / UpperLimit were
-- meant to do this natively and measurably do nothing (see RELAY traps). A sign
-- hides once you are close enough to see the place itself.
--
-- Gates come from the "RegionGate" tag (RegionId -> Config.Regions): a locked
-- one carries a gold "Unlock X Coins" line under its name. Other destinations
-- are parts tagged "Waypoint" with WaypointName / WaypointColor / WaypointHeight
-- (MapBuilder). Your own city is found by the plot's OwnerUserId.
--
-- These were 250x62 pixel cards that stayed the same size at any distance, so
-- all eleven sat on screen at full size from the plaza, two lines each.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local Waypoints = {}

local GATE_TAG = "RegionGate"
local WAYPOINT_TAG = "Waypoint"
local HIDE_WITHIN = 28 -- studs: you are there; the sign would only cover the thing
local MAX_DISTANCE = 900
local NEAR = 35 -- studs: closer than this the sign stops growing
local FAR = 200 -- studs: farther than this it stops shrinking
-- World size of one sign, in studs, before the depth scaling. The frame is
-- invisible; it is wide enough that the longest name ("Catastrophe Atlas")
-- renders at full height.
local SIGN_WIDTH = 44
local TITLE_HEIGHT = 5
local DETAIL_HEIGHT = 2.6
-- The outline is drawn in pixels; resize() keeps it at this fraction of the
-- letter height every frame: thick on a near sign, thin on a far one, never
-- swallowing the letters.
local STROKE_RATIO = 0.07
local STROKE_MIN, STROKE_MAX = 1.5, 4.5
local TICK = 0.25
local player = Players.LocalPlayer

type Sign = {
	gui: BillboardGui,
	title: TextLabel,
	detail: TextLabel,
	strokes: { UIStroke },
	regionId: string?,
}
local signs: { [BasePart]: Sign } = {}
local cityPart: BasePart? = nil

local function outlined(parent: Instance, name: string, text: string, color: Color3, size: UDim2, pos: UDim2): (TextLabel, UIStroke)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = Theme.fonts.title
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Color = Theme.colors.ink
	s.Thickness = STROKE_MAX
	s.Parent = l
	return l, s
end

local function build(part: BasePart, name: string, color: Color3, height: number, regionId: string?): Sign
	local gui = Instance.new("BillboardGui")
	gui.Name = "WaypointSign"
	gui.Adornee = part
	gui.Size = UDim2.fromOffset(0, 0) -- set every frame by resize()
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local total = TITLE_HEIGHT + DETAIL_HEIGHT
	-- the destination's colour on the name itself, never as the only cue: the name is text
	local title, titleStroke = outlined(gui, "Title", name, color, UDim2.fromScale(1, TITLE_HEIGHT / total), UDim2.fromScale(0, 0))
	local detail, detailStroke = outlined(gui, "Detail", "", Theme.colors.gold, UDim2.fromScale(1, DETAIL_HEIGHT / total), UDim2.fromScale(0, TITLE_HEIGHT / total))
	detail.Visible = false
	return { gui = gui, title = title, detail = detail, strokes = { titleStroke, detailStroke }, regionId = regionId }
end

local function addGate(inst: Instance)
	if not inst:IsA("BasePart") or signs[inst] then
		return
	end
	local regionId = inst:GetAttribute("RegionId")
	local def = if typeof(regionId) == "string" then Config.Regions.byId[regionId] else nil
	if not def then
		return
	end
	signs[inst] = build(inst, def.name, def.color, 20, def.id)
end

local function addWaypoint(inst: Instance)
	if not inst:IsA("BasePart") or signs[inst] then
		return
	end
	local name = inst:GetAttribute("WaypointName")
	if typeof(name) ~= "string" then
		return
	end
	local colorAttr = inst:GetAttribute("WaypointColor")
	local heightAttr = inst:GetAttribute("WaypointHeight")
	local color: Color3 = if typeof(colorAttr) == "Color3" then colorAttr else Theme.colors.accentAlt
	local height: number = if typeof(heightAttr) == "number" then heightAttr else 12
	signs[inst] = build(inst, name, color, height, nil)
end

local function remove(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local sign = signs[inst]
	if sign then
		sign.gui:Destroy()
		signs[inst] = nil
	end
end

-- Your own city: the plot whose OwnerUserId is you. Ownership is assigned after
-- join and can move, so this is re-checked on every tick (a handful of plots).
local function refreshCity()
	local plots = workspace:FindFirstChild("Plots")
	local mine: BasePart? = nil
	if plots then
		for _, plot in plots:GetChildren() do
			if plot:GetAttribute("OwnerUserId") == player.UserId then
				local anchor = plot:FindFirstChild("Billboard") or plot:FindFirstChild("CollectPad")
				if anchor and anchor:IsA("BasePart") then
					mine = anchor
				end
				break
			end
		end
	end
	if mine ~= cityPart then
		if cityPart then
			remove(cityPart)
		end
		cityPart = mine
		if mine then
			signs[mine] = build(mine, "Your City", Theme.colors.accent, 16, nil)
		end
	end
end

function Waypoints.count(): number
	local n = 0
	for _ in signs do
		n += 1
	end
	return n
end

-- Rendered letter height of each visible sign's name, in pixels, keyed by the
-- name. Read-only; lets a probe confirm the near/far clamps.
function Waypoints.titleHeights(): { [string]: number }
	local out: { [string]: number } = {}
	for _, sign in signs do
		if sign.gui.Enabled then
			out[sign.title.Text] = sign.title.AbsoluteSize.Y
		end
	end
	return out
end

-- Pixel size for this frame: the world size the sign would have at the camera
-- depth, clamped to [NEAR, FAR]. Depth (distance along the camera's look
-- vector) is what perspective scales by; Roblox's own stud-sized billboards
-- measured exactly studs * k / depth straight ahead. The outline is drawn in
-- pixels, so it follows the letter height here too.
local function resize()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local vp = cam.ViewportSize
	local k = (vp.Y / 2) / math.tan(math.rad(cam.FieldOfView / 2)) -- px per stud at depth 1
	for part, sign in signs do
		if not sign.gui.Enabled or not part.Parent then
			continue
		end
		local depth = cam:WorldToViewportPoint(part.Position + sign.gui.StudsOffsetWorldSpace).Z
		local pxPerStud = k / math.clamp(depth, NEAR, FAR)
		sign.gui.Size = UDim2.fromOffset(SIGN_WIDTH * pxPerStud, (TITLE_HEIGHT + DETAIL_HEIGHT) * pxPerStud)
		local thickness = math.clamp(TITLE_HEIGHT * pxPerStud * STROKE_RATIO, STROKE_MIN, STROKE_MAX)
		for _, stroke in sign.strokes do
			stroke.Thickness = thickness
		end
	end
end

function Waypoints.init()
	for _, inst in CollectionService:GetTagged(GATE_TAG) do
		addGate(inst)
	end
	for _, inst in CollectionService:GetTagged(WAYPOINT_TAG) do
		addWaypoint(inst)
	end
	CollectionService:GetInstanceAddedSignal(GATE_TAG):Connect(addGate)
	CollectionService:GetInstanceAddedSignal(WAYPOINT_TAG):Connect(addWaypoint)
	CollectionService:GetInstanceRemovedSignal(GATE_TAG):Connect(remove)
	CollectionService:GetInstanceRemovedSignal(WAYPOINT_TAG):Connect(remove)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < TICK then
			return
		end
		acc = 0
		refreshCity()

		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local snap = State.get()
		for part, sign in signs do
			if not part.Parent then
				remove(part)
				continue
			end
			if not (hrp and hrp:IsA("BasePart")) then
				sign.gui.Enabled = false
				continue
			end
			local distance = (part.Position - hrp.Position).Magnitude
			if distance < HIDE_WITHIN then
				sign.gui.Enabled = false
				continue
			end
			sign.gui.Enabled = true

			local regionId = sign.regionId
			local def = if regionId then Config.Regions.byId[regionId] else nil
			local locked = def ~= nil and def.unlockCost > 0 and not (snap ~= nil and snap.regions[def.id] == true)
			if def and locked then
				sign.detail.Text = "Unlock " .. Format.abbreviate(def.unlockCost) .. " Coins"
			end
			sign.detail.Visible = locked
		end
	end)
	RunService.RenderStepped:Connect(resize)
end

return Waypoints
