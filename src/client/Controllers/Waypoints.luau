--!strict
-- Waypoint signs: an always-on-top sign in the air over every region gate,
-- every hub destination and your own city, showing its name, its colour and
-- how far away it is. A sign in the air reads from anywhere on the map, which
-- floor markings cannot do.
--
-- Gates come from the "RegionGate" tag (RegionId -> Config.Regions): an open
-- region shows its element, a locked one its unlock cost. Other destinations
-- are parts tagged "Waypoint" with WaypointName / WaypointColor / WaypointHeight
-- (MapBuilder). Your own city is found by the plot's OwnerUserId. A sign hides
-- once you are close enough to see the place itself.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local State = require(script.Parent.Parent.State)
local W = require(script.Parent.Parent.UI.Widgets)
local Theme = require(script.Parent.Parent.UI.Theme)

local Waypoints = {}

local GATE_TAG = "RegionGate"
local WAYPOINT_TAG = "Waypoint"
local HIDE_WITHIN = 28 -- studs: you are there; the sign would only cover the thing
local MAX_DISTANCE = 900
local TICK = 0.25
local player = Players.LocalPlayer

type Sign = {
	gui: BillboardGui,
	detail: TextLabel,
	regionId: string?,
}
local signs: { [BasePart]: Sign } = {}
local cityPart: BasePart? = nil

local function build(part: BasePart, name: string, color: Color3, height: number, regionId: string?): Sign
	local gui = Instance.new("BillboardGui")
	gui.Name = "WaypointSign"
	gui.Adornee = part
	gui.Size = UDim2.fromOffset(250, 62)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local card = W.frame({
		parent = gui,
		name = "Card",
		size = UDim2.new(1, 0, 1, 0),
		color = Theme.colors.bg,
		transparency = 0.1,
		radius = Theme.sizes.radius,
		stroke = Theme.colors.ink,
		strokeThickness = 3,
	})
	-- the destination's colour as a bar, never as the only cue: the name is text
	W.frame({
		parent = card,
		name = "Bar",
		size = UDim2.new(0, 8, 1, -12),
		position = UDim2.new(0, 6, 0, 6),
		color = color,
		radius = 4,
	})
	W.label({
		parent = card,
		name = "Title",
		text = name,
		size = UDim2.new(1, -30, 0, 28),
		position = UDim2.new(0, 20, 0, 5),
		textSize = 20,
		font = Theme.fonts.title,
		color = Theme.colors.text,
		xalign = Enum.TextXAlignment.Left,
	})
	local detail = W.label({
		parent = card,
		name = "Detail",
		text = "",
		size = UDim2.new(1, -30, 0, 22),
		position = UDim2.new(0, 20, 0, 33),
		textSize = 15,
		font = Theme.fonts.bold,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
	})
	return { gui = gui, detail = detail, regionId = regionId }
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
-- join and can move, so this is re-checked on every tick (eight plots).
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
			local away = tostring(math.floor(distance + 0.5)) .. " away"
			local regionId = sign.regionId
			if regionId then
				local def = Config.Regions.byId[regionId]
				local unlocked = snap ~= nil and snap.regions[regionId] == true
				if def and not unlocked then
					sign.detail.Text = "Unlock " .. Format.abbreviate(def.unlockCost) .. " Coins  ·  " .. away
				elseif def then
					sign.detail.Text = def.element .. "  ·  " .. away
				else
					sign.detail.Text = away
				end
			else
				sign.detail.Text = away
			end
		end
	end)
end

return Waypoints
