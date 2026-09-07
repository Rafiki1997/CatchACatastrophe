--!strict
-- Picking pads in your own city. Click one, click a neighbour, and the editor
-- tells you what they would make before you commit.
--
-- Selection is local and costs nothing: the highlight, the valid-partner glow
-- and the income preview are all drawn from the snapshot. The server validates
-- the pair again when the Connect button is actually pressed.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local State = require(script.Parent.Parent.State)
local CircuitEditorUI = require(script.Parent.Parent.UI.CircuitEditorUI)

local CircuitEditor = {}

local player = Players.LocalPlayer
-- Never cache the camera (see CaptureController): a reference taken at load
-- goes stale when Roblox replaces the camera, and pad clicks stop landing.
local function camera(): Camera
	return workspace.CurrentCamera
end

local selectedPad: number? = nil
local highlights: { [number]: SelectionBox } = {}
local gamepadIndex = 1

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

local function padPart(pad: number): BasePart?
	local plot = ownPlot()
	local pads = plot and plot:FindFirstChild("Pads")
	local part = pads and pads:FindFirstChild("Pad_" .. tostring(pad))
	return if part and part:IsA("BasePart") then part else nil
end

local function clearHighlights()
	for _, box in highlights do
		box:Destroy()
	end
	table.clear(highlights)
end

local function highlight(pad: number, color: Color3)
	local part = padPart(pad)
	if not part then
		return
	end
	local box = highlights[pad]
	if not box then
		box = Instance.new("SelectionBox")
		box.LineThickness = 0.08
		box.SurfaceTransparency = 0.8
		box.Parent = part
		highlights[pad] = box
	end
	box.Adornee = part
	box.Color3 = color
	box.SurfaceColor3 = color
end

-- Who is standing on each pad, according to the snapshot.
local function occupants(snap: Types.Snapshot): { [number]: Types.CreatureEntry }
	local map: { [number]: Types.CreatureEntry } = {}
	for _, entry in snap.creatures do
		if entry.pad then
			map[entry.pad] = entry
		end
	end
	return map
end

local function pairKeyFor(pad: number, snap: Types.Snapshot): string?
	for key, entry in snap.circuits do
		if entry.padA == pad or entry.padB == pad then
			return key
		end
	end
	return nil
end

local function buildPreview(padA: number, padB: number, snap: Types.Snapshot): CircuitEditorUI.Preview
	local map = occupants(snap)
	local a, b = map[padA], map[padB]
	local preview: CircuitEditorUI.Preview = {
		padA = padA,
		padB = padB,
		recipeId = nil,
		reason = nil,
		beforeCps = 0,
		afterCps = 0,
		bonus = 0,
	}
	if not Config.Circuits.areAdjacent(padA, padB) then
		preview.reason = "Those pads are not side by side. Diagonal pads do not connect."
		return preview
	end
	if not a or not b then
		preview.reason = "Both pads need a working creature on them."
		return preview
	end
	local defA = Config.Species.byId[a.id]
	local defB = Config.Species.byId[b.id]
	if not defA or not defB then
		return preview
	end
	local recipe = Config.Circuits.recipe(defA.element, defB.element)
	if not recipe then
		preview.reason = defA.element .. " and " .. defB.element .. " do not make a circuit. Check the Recipe Book."
		return preview
	end
	if pairKeyFor(padA, snap) or pairKeyFor(padB, snap) then
		preview.reason = "One of those creatures is already in a circuit. Disconnect it first."
		return preview
	end

	local bonus = Config.Circuits.baseBonus + snap.derived.circuitBonusExtra
	preview.recipeId = recipe.id
	preview.bonus = bonus
	preview.beforeCps = a.normalCps + b.normalCps
	preview.afterCps = preview.beforeCps * (1 + bonus)
	return preview
end

local function selectPad(pad: number?)
	local snap = State.get()
	if not snap then
		return
	end

	if not pad then
		selectedPad = nil
		clearHighlights()
		CircuitEditorUI.hide()
		return
	end

	-- clicking a pad that is already in a circuit opens that circuit
	local key = pairKeyFor(pad, snap)
	if key and not selectedPad then
		local entry = snap.circuits[key]
		if entry then
			clearHighlights()
			highlight(entry.padA, Config.Circuits.byId[entry.circuitId] and Config.Circuits.byId[entry.circuitId].color or Color3.fromRGB(120, 255, 200))
			highlight(entry.padB, Config.Circuits.byId[entry.circuitId] and Config.Circuits.byId[entry.circuitId].color or Color3.fromRGB(120, 255, 200))
			selectedPad = nil
			CircuitEditorUI.showCircuitCard(entry)
			return
		end
	end

	if selectedPad == nil then
		selectedPad = pad
		clearHighlights()
		highlight(pad, Color3.fromRGB(255, 220, 120))
		-- glow every neighbour that would actually make something
		local map = occupants(snap)
		for _, other in { pad - 1, pad + 1, pad - Config.Circuits.grid.cols, pad + Config.Circuits.grid.cols } do
			if other >= 1 and other <= Config.Circuits.maxPads and Config.Circuits.areAdjacent(pad, other) then
				local preview = buildPreview(pad, other, snap)
				if preview.recipeId then
					highlight(other, Color3.fromRGB(120, 255, 200))
				elseif map[other] then
					highlight(other, Color3.fromRGB(120, 124, 140))
				end
			end
		end
		CircuitEditorUI.showSelection(pad, nil, nil)
		return
	end

	if selectedPad == pad then
		selectPad(nil)
		return
	end

	local preview = buildPreview(selectedPad, pad, snap)
	highlight(pad, if preview.recipeId then Color3.fromRGB(120, 255, 200) else Color3.fromRGB(255, 120, 110))
	CircuitEditorUI.showSelection(selectedPad, pad, preview)
	selectedPad = nil
end

local function padUnderPoint(x: number, y: number): number?
	local ray = camera():ViewportPointToRay(x, y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: any, workspace:FindFirstChild("ClientFX") :: any }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	if not result then
		return nil
	end
	local inst: Instance? = result.Instance
	-- the creature or its station may be what the ray hit; walk up to the pad
	while inst and inst ~= workspace do
		if inst:IsA("BasePart") then
			local index = inst:GetAttribute("PadIndex")
			if typeof(index) == "number" then
				local plot = inst:FindFirstAncestorOfClass("Model")
				while plot and plot:GetAttribute("PlotIndex") == nil do
					plot = plot:FindFirstAncestorOfClass("Model")
				end
				if plot and plot:GetAttribute("OwnerUserId") == player.UserId then
					return index
				end
				return nil
			end
		end
		inst = inst.Parent
	end
	return nil
end

function CircuitEditor.init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local position = input.Position
			local pad = padUnderPoint(position.X, position.Y)
			if pad then
				selectPad(pad)
			end
		elseif input.KeyCode == Enum.KeyCode.DPadRight or input.KeyCode == Enum.KeyCode.DPadLeft then
			-- gamepad: step through the pads without a cursor
			local snap = State.get()
			if not snap then
				return
			end
			local step = if input.KeyCode == Enum.KeyCode.DPadRight then 1 else -1
			gamepadIndex = ((gamepadIndex - 1 + step) % snap.pads.total) + 1
			local part = padPart(gamepadIndex)
			if part then
				clearHighlights()
				highlight(gamepadIndex, Color3.fromRGB(255, 220, 120))
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonA then
			local snap = State.get()
			if snap and gamepadIndex >= 1 and gamepadIndex <= snap.pads.total then
				selectPad(gamepadIndex)
			end
		end
	end)

	-- keep an open circuit card's timers live
	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		local snap = State.get()
		if snap and CircuitEditorUI.isOpen() then
			CircuitEditorUI.update(snap)
		end
	end)

	State.onChanged(function(snap)
		if CircuitEditorUI.isOpen() then
			CircuitEditorUI.update(snap)
		end
	end)
end

return CircuitEditor
