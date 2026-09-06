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
local beamA: Attachment? = nil
local beamB: Attachment? = nil
local beam: Beam? = nil

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
	local a = Instance.new("Attachment")
	a.Parent = holder
	local b = Instance.new("Attachment")
	b.Parent = holder
	local line = Instance.new("Beam")
	line.Attachment0 = a
	line.Attachment1 = b
	line.Width0 = 0.6
	line.Width1 = 0.6
	line.FaceCamera = true
	line.Color = ColorSequence.new(Theme.colors.accent)
	line.LightEmission = 0.9
	line.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	line.TextureSpeed = 3
	line.TextureLength = 6
	line.Transparency = NumberSequence.new(0.15)
	line.Parent = holder
	beamHolder = holder
	beamA = a
	beamB = b
	beam = line
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
		local hub = workspace:FindFirstChild("Map") and (workspace:FindFirstChild("Map") :: Instance):FindFirstChild("Hub")
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
		if done or not beam then
			if beam then
				beam.Enabled = false
			end
			return
		end
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local target = targetPosition()
		if hrp and hrp:IsA("BasePart") and target and beamA and beamB then
			beamA.WorldPosition = hrp.Position + Vector3.new(0, 2, 0)
			beamB.WorldPosition = target + Vector3.new(0, 3, 0)
			beam.Enabled = true
		else
			beam.Enabled = false
		end
	end)
end

function TutorialUI.setStep(step: number, isDone: boolean)
	currentStep = math.clamp(step, 1, Config.Quests.tutorialDoneStep)
	done = isDone or step >= Config.Quests.tutorialDoneStep
	ensureBeam()

	if not card then
		return
	end
	if done then
		card.Visible = false
		if beam then
			beam.Enabled = false
		end
		return
	end

	local def = Config.Quests.tutorial[currentStep]
	if not def then
		card.Visible = false
		return
	end
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
	if not snap or not snap.settings.reducedMotion then
		W.pop(card, 1.08)
	end
end

function TutorialUI.update(snap: any)
	if typeof(snap) == "table" and snap.quests then
		TutorialUI.setStep(snap.quests.tutorialStep, snap.quests.tutorialDone)
	end
end

return TutorialUI
