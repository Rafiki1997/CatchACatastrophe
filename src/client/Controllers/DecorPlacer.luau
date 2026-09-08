--!strict
-- Placing a decoration: the grid, the ghost, the turning, the confirm.
--
-- The rule the whole thing is built around is that nothing is committed until
-- the player says so. Choosing a decoration lights up every free spot in their
-- city, a see-through copy follows the one nearest their mouse, and only
-- pressing Place sends anything to the server. Cancel leaves the city exactly
-- as it was.
--
-- Slots come from the same shared module the server uses, so the ghost stands
-- where the real thing will stand, to the stud.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local DecorModels = require(ReplicatedStorage.Shared.Models.DecorModels)
local DecorSlots = require(ReplicatedStorage.Shared.Models.DecorSlots)

local W = require(script.Parent.Parent.UI.Widgets)
local Theme = require(script.Parent.Parent.UI.Theme)
local Net = require(script.Parent.Parent.Net)
local State = require(script.Parent.Parent.State)

local DecorPlacer = {}

local Cosmetics = Config.Cosmetics
local player = Players.LocalPlayer

local active: { item: any, rot: number, slot: any, ghost: Model?, markers: { [string]: BasePart }, slots: { any } }? = nil
local gui: ScreenGui? = nil
local bar: Frame? = nil
local title: TextLabel? = nil
local placeButton: TextButton? = nil
local connection: RBXScriptConnection? = nil

local function ownPlot(): Model?
	local plots = workspace:FindFirstChild("Plots")
	for _, model in if plots then plots:GetChildren() else {} do
		if model:GetAttribute("OwnerUserId") == player.UserId and model:IsA("Model") then
			return model
		end
	end
	return nil
end

-- Are they standing in their own city? The server asks the same question, so
-- the button is never offered when the answer would be no.
function DecorPlacer.canDecorate(): boolean
	local model = ownPlot()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local snap = State.get()
	if not model or not root or not root:IsA("BasePart") or (snap and snap.visiting) then
		return false
	end
	local here = model:GetPivot():PointToObjectSpace(root.Position)
	return math.abs(here.X) <= 34 and math.abs(here.Z) <= 34
end

local function clearWorld()
	local current = active
	if not current then
		return
	end
	if current.ghost then
		current.ghost:Destroy()
	end
	for _, marker in current.markers do
		marker:Destroy()
	end
	current.markers = {}
	current.ghost = nil
end

-- A flat disc on each free spot: visible from above, never in the way.
local function buildMarkers(model: Model, slots: { any }): { [string]: BasePart }
	local markers: { [string]: BasePart } = {}
	local folder = workspace:FindFirstChild("ClientFX") or workspace
	for _, slot in slots do
		local marker = Instance.new("Part")
		marker.Name = "DecorSlot"
		marker.Size = Vector3.new(3.4, 0.2, 3.4)
		marker.Shape = Enum.PartType.Cylinder
		marker.CFrame = model:GetPivot() * CFrame.new(slot.offset + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.CastShadow = false
		marker.Material = Enum.Material.Neon
		marker.Color = Theme.colors.accentAlt
		marker.Transparency = 0.55
		marker.Parent = folder
		markers[slot.id] = marker
	end
	return markers
end

local function makeGhost(item: any): Model?
	local ghost = DecorModels.build(item.preset, item.color, "Ghost")
	if not ghost then
		return nil
	end
	for _, part in ghost:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = math.max(part.Transparency, 0.55)
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Material = Enum.Material.Neon
			part.Color = item.color
		elseif part:IsA("ParticleEmitter") or part:IsA("Light") then
			part:Destroy()
		end
	end
	ghost.Parent = workspace:FindFirstChild("ClientFX") or workspace
	return ghost
end

-- The free spot nearest where the player is pointing.
local function nearestSlot(model: Model, slots: { any }): any
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local point = if hit then hit.Position else (ray.Origin + ray.Direction * 60)
	local best, bestDistance = nil, math.huge
	for _, slot in slots do
		local world = (model:GetPivot() * CFrame.new(slot.offset)).Position
		local distance = (Vector3.new(world.X, 0, world.Z) - Vector3.new(point.X, 0, point.Z)).Magnitude
		if distance < bestDistance then
			best, bestDistance = slot, distance
		end
	end
	return best
end

local function refreshGhost()
	local current = active
	local model = ownPlot()
	if not current or not model or not current.ghost then
		return
	end
	local slot = nearestSlot(model, current.slots)
	if not slot then
		return
	end
	current.slot = slot
	current.ghost:PivotTo(model:GetPivot() * CFrame.new(slot.offset + Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.rad(DecorSlots.angleOf(current.rot)), 0))
	for id, marker in current.markers do
		marker.Color = if id == slot.id then Theme.colors.success else Theme.colors.accentAlt
		marker.Transparency = if id == slot.id then 0.2 else 0.6
	end
	if title then
		title.Text = current.item.name .. "  ·  turn it, then place it"
	end
end

function DecorPlacer.stop()
	clearWorld()
	active = nil
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if bar then
		bar.Visible = false
	end
end

function DecorPlacer.rotate(direction: number)
	local current = active
	if not current then
		return
	end
	current.rot = (current.rot + direction) % DecorSlots.rotationSteps
	refreshGhost()
end

function DecorPlacer.confirm()
	local current = active
	if not current or not current.slot then
		return
	end
	Net.fire("PlaceDecor", current.item.id, current.slot.id, current.rot)
	DecorPlacer.stop()
end

-- Starts placing. `startRot` carries the angle over when a player moves
-- something that is already down.
function DecorPlacer.start(itemId: string, startRot: number?)
	local item = Cosmetics.byId[itemId]
	local model = ownPlot()
	if not item or item.family ~= "decor" or not model then
		return
	end
	DecorPlacer.stop()
	local slots = DecorSlots.compute(model)
	if #slots == 0 then
		return
	end
	active = {
		item = item,
		rot = startRot or 0,
		slot = nil,
		ghost = makeGhost(item),
		markers = buildMarkers(model, slots),
		slots = slots,
	}
	if bar then
		bar.Visible = true
	end
	W.closePanels()
	connection = RunService.RenderStepped:Connect(refreshGhost)
	refreshGhost()
end

function DecorPlacer.isActive(): boolean
	return active ~= nil
end

function DecorPlacer.init()
	local screen = W.screenGui("DecorPlacer", 30)
	gui = screen
	local frame = W.frame({
		parent = screen,
		name = "PlacerBar",
		size = UDim2.new(0, 520, 0, 92),
		position = UDim2.new(0.5, 0, 1, -18),
		anchor = Vector2.new(0.5, 1),
		color = Theme.colors.bg,
		radius = Theme.sizes.radius,
		stroke = Theme.colors.accent,
		strokeThickness = 3,
		visible = false,
	})
	bar = frame
	title = W.label({
		parent = frame,
		text = "",
		size = UDim2.new(1, -20, 0, 20),
		position = UDim2.new(0, 10, 0, 8),
		textSize = 14,
		xalign = Enum.TextXAlignment.Center,
		font = Theme.fonts.bold,
		color = Theme.colors.text,
	})
	W.button({
		parent = frame,
		text = "Turn left",
		size = UDim2.new(0, 112, 0, Theme.sizes.buttonHeight),
		position = UDim2.new(0, 12, 1, -12),
		anchor = Vector2.new(0, 1),
		color = Theme.colors.bgAlt,
		textColor = Theme.colors.text,
		textSize = 14,
		onClick = function()
			DecorPlacer.rotate(-1)
		end,
	})
	W.button({
		parent = frame,
		text = "Turn right",
		size = UDim2.new(0, 112, 0, Theme.sizes.buttonHeight),
		position = UDim2.new(0, 130, 1, -12),
		anchor = Vector2.new(0, 1),
		color = Theme.colors.bgAlt,
		textColor = Theme.colors.text,
		textSize = 14,
		onClick = function()
			DecorPlacer.rotate(1)
		end,
	})
	placeButton = W.button({
		parent = frame,
		text = "Place it",
		size = UDim2.new(0, 130, 0, Theme.sizes.buttonHeight),
		position = UDim2.new(1, -12, 1, -12),
		anchor = Vector2.new(1, 1),
		color = Theme.colors.accent,
		textColor = Theme.colors.ink,
		textSize = 15,
		onClick = DecorPlacer.confirm,
	})
	W.button({
		parent = frame,
		text = "Cancel",
		size = UDim2.new(0, 100, 0, Theme.sizes.buttonHeight),
		position = UDim2.new(1, -150, 1, -12),
		anchor = Vector2.new(1, 1),
		color = Theme.colors.bgAlt,
		textColor = Theme.colors.textDim,
		textSize = 14,
		onClick = DecorPlacer.stop,
	})

	UserInputService.InputBegan:Connect(function(input, processed)
		if not active or processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			DecorPlacer.confirm()
		elseif input.KeyCode == Enum.KeyCode.R then
			DecorPlacer.rotate(1)
		elseif input.KeyCode == Enum.KeyCode.Q then
			DecorPlacer.rotate(-1)
		elseif input.KeyCode == Enum.KeyCode.Escape then
			DecorPlacer.stop()
		end
	end)
	-- walking out of your own city ends the session rather than letting a ghost
	-- hang over ground the server would refuse
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.5 then
			elapsed = 0
			if active and not DecorPlacer.canDecorate() then
				DecorPlacer.stop()
			end
		end
	end)
end

return DecorPlacer
