--!strict
-- Managing creatures from the pad itself.
--
-- A work pad has two verbs: click or tap it to wire a circuit (CircuitEditor),
-- press E at it to deploy, swap or store (this). The prompt is built by the
-- server on every pad, disabled. Enabling it here is per player, exactly like
-- the gate's CanCollide: the server never reads it, and the remotes the picker
-- fires are the same ones the Creatures panel already uses.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.Parent.State)

local PadPrompts = {}

local PROMPT = "ManagePrompt"
local player = Players.LocalPlayer
local picker: any = nil

local function plotOwner(model: Instance): number?
	local owner = model:GetAttribute("OwnerUserId")
	return if typeof(owner) == "number" then owner else nil
end

local function speciesName(id: string): string
	local def = Config.Species.byId[id]
	return if def then def.name else id
end

local function occupantOf(snap: Types.Snapshot, pad: number): Types.CreatureEntry?
	for _, entry in snap.creatures do
		if entry.pad == pad then
			return entry
		end
	end
	return nil
end

-- Every pad on every plot: ours and usable -> enabled and labelled, anything
-- else -> disabled. Cheap enough to run on each snapshot (8 x 24 attribute reads).
local function refresh()
	local snap = State.get()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, model in plots:GetChildren() do
		local pads = model:FindFirstChild("Pads")
		if not pads then
			continue
		end
		local mine = snap ~= nil and snap.visiting == nil and plotOwner(model) == player.UserId
		for _, padPart in pads:GetChildren() do
			local prompt = padPart:FindFirstChild(PROMPT)
			local index = padPart:GetAttribute("PadIndex")
			if not (prompt and prompt:IsA("ProximityPrompt") and typeof(index) == "number") then
				continue
			end
			local usable = mine and snap ~= nil and index <= snap.pads.total
			prompt.Enabled = usable
			if usable and snap then
				local occupant = occupantOf(snap, index)
				if occupant then
					prompt.ActionText = "Swap"
					prompt.ObjectText = speciesName(occupant.id)
				else
					prompt.ActionText = "Deploy"
					prompt.ObjectText = "Pad " .. tostring(index)
				end
			end
		end
	end
end

local function watchPrompts()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player or prompt.Name ~= PROMPT or not picker then
			return
		end
		local padPart = prompt.Parent
		local index = padPart and padPart:GetAttribute("PadIndex")
		if typeof(index) ~= "number" then
			return
		end
		local plot = padPart and padPart:FindFirstAncestorOfClass("Model")
		if plot and plotOwner(plot) == player.UserId then
			picker.open(index)
		end
	end)
end

function PadPrompts.init(CreaturePicker: any?)
	picker = CreaturePicker
	refresh()
	State.onChanged(refresh)
	watchPrompts()

	-- Plots are assigned after join; re-label when ours becomes ours.
	task.spawn(function()
		local plots = workspace:WaitForChild("Plots", 15)
		if not plots then
			return
		end
		for _, model in plots:GetChildren() do
			model:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
		end
		plots.ChildAdded:Connect(function(model)
			model:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
			refresh()
		end)
		refresh()
	end)
end

return PadPrompts
