--!strict
-- Client bootstrap: load every module defensively, wire the remotes to them,
-- and never let one broken panel take the whole interface down with it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local W = require(script.Parent.UI.Widgets)

local player = Players.LocalPlayer
local UI = script.Parent.UI
local Panels = UI.Panels
local Controllers = script.Parent.Controllers

local function safeRequire(module: Instance): any?
	local ok, result = pcall(require, module)
	if not ok then
		warn("[Client] failed to load " .. module:GetFullName() .. ": " .. tostring(result))
		return nil
	end
	return result
end

local function safeCall(label: string, fn: (() -> ())?)
	if not fn then
		return
	end
	local ok, err = pcall(fn)
	if not ok then
		warn("[Client] " .. label .. " error: " .. tostring(err))
	end
end

-- ------------------------------------------------------------ modules

local Notifications = safeRequire(UI.Notifications)
local FloatingText = safeRequire(UI.FloatingText)
local HUD = safeRequire(UI.HUD)
local CaptureHUD = safeRequire(UI.CaptureHUD)
local CaptureReveal = safeRequire(UI.CaptureReveal)
local TutorialUI = safeRequire(UI.TutorialUI)
local CircuitEditorUI = safeRequire(UI.CircuitEditorUI)
local CreaturePicker = safeRequire(UI.CreaturePicker)
local CollectionPadUI = safeRequire(UI.CollectionPadUI)

local panelModules: { any } = {}
local panelByName: { [string]: any } = {}
for _, child in Panels:GetChildren() do
	if child:IsA("ModuleScript") then
		local module = safeRequire(child)
		if module then
			table.insert(panelModules, module)
			panelByName[child.Name] = module
		end
	end
end

local Input = safeRequire(Controllers.Input)
local Effects = safeRequire(Controllers.Effects)
local WorldAnimator = safeRequire(Controllers.WorldAnimator)
local SceneryAnimator = safeRequire(Controllers.SceneryAnimator)
local GustyAtmosphere = safeRequire(Controllers.GustyAtmosphere)
local RegionGates = safeRequire(Controllers.RegionGates)
local CaptureController = safeRequire(Controllers.CaptureController)
local CircuitEditor = safeRequire(Controllers.CircuitEditor)
local PadPrompts = safeRequire(Controllers.PadPrompts)
local RouteLights = safeRequire(Controllers.RouteLights)
local Waypoints = safeRequire(Controllers.Waypoints)
local CameraGuard = safeRequire(Controllers.CameraGuard)
local AuraController = safeRequire(Controllers.AuraController)
local DecorPlacer = safeRequire(Controllers.DecorPlacer)

-- init order: notifications first so anything else can complain out loud
safeCall("Notifications.init", Notifications and Notifications.init)
safeCall("FloatingText.init", FloatingText and FloatingText.init)
safeCall("Input.init", Input and Input.init)
safeCall("HUD.init", HUD and HUD.init)
for _, module in panelModules do
	safeCall("panel init", module.init)
end
safeCall("CaptureHUD.init", CaptureHUD and CaptureHUD.init)
safeCall("CaptureReveal.init", CaptureReveal and CaptureReveal.init)
safeCall("TutorialUI.init", TutorialUI and TutorialUI.init)
safeCall("CircuitEditorUI.init", CircuitEditorUI and CircuitEditorUI.init)
safeCall("CreaturePicker.init", CreaturePicker and CreaturePicker.init)
safeCall("CollectionPadUI.init", CollectionPadUI and CollectionPadUI.init)
safeCall("Effects.init", Effects and Effects.init)
safeCall("WorldAnimator.init", WorldAnimator and WorldAnimator.init)
safeCall("SceneryAnimator.init", SceneryAnimator and SceneryAnimator.init)
safeCall("GustyAtmosphere.init", GustyAtmosphere and GustyAtmosphere.init)
safeCall("RouteLights.init", RouteLights and RouteLights.init)
safeCall("Waypoints.init", Waypoints and Waypoints.init)
safeCall("CameraGuard.init", CameraGuard and CameraGuard.init)
safeCall("AuraController.init", AuraController and AuraController.init)
safeCall("DecorPlacer.init", DecorPlacer and DecorPlacer.init)
safeCall("CaptureController.init", CaptureController and CaptureController.init)
safeCall("CircuitEditor.init", CircuitEditor and CircuitEditor.init)
if RegionGates and RegionGates.init then
	safeCall("RegionGates.init", function()
		RegionGates.init(Notifications, W)
	end)
end
if PadPrompts and PadPrompts.init then
	safeCall("PadPrompts.init", function()
		PadPrompts.init(CreaturePicker)
	end)
end

-- ------------------------------------------------------------ state -> UI

State.onChanged(function(snap)
	W.sfxEnabled = snap.settings.sfx > 0
	if HUD then
		safeCall("HUD.update", function()
			HUD.update(snap)
		end)
	end
	if CaptureHUD and CaptureHUD.update then
		safeCall("CaptureHUD.update", function()
			CaptureHUD.update(snap)
		end)
	end
	if TutorialUI and TutorialUI.update then
		safeCall("TutorialUI.update", function()
			TutorialUI.update(snap)
		end)
	end
	for _, module in panelModules do
		if module.update then
			safeCall("panel update", function()
				module.update(snap)
			end)
		end
	end
end)

-- ------------------------------------------------------------ remotes

Net.on("State", function(snap)
	if typeof(snap) == "table" then
		State.set(snap)
	end
end)

Net.on("Notify", function(kind, text, duration)
	if Notifications and typeof(text) == "string" then
		local snap = State.get()
		-- errors and successes always show; chatter can be turned off
		local important = kind == "error" or kind == "success"
		if snap and not snap.settings.notifications and not important then
			return
		end
		Notifications.push(if typeof(kind) == "string" then kind else "info", text, if typeof(duration) == "number" then duration else nil)
	end
end)

Net.on("Broadcast", function(text, color)
	if Notifications and typeof(text) == "string" then
		Notifications.broadcast(text, if typeof(color) == "Color3" then color else nil)
	end
end)

Net.on("FloatingText", function(text, position, color)
	if FloatingText and typeof(text) == "string" and typeof(position) == "Vector3" then
		FloatingText.show(text, position, if typeof(color) == "Color3" then color else nil)
	end
end)

Net.on("Effect", function(kind, position, extra)
	if Effects and typeof(kind) == "string" and typeof(position) == "Vector3" then
		Effects.play(kind, position, extra)
	end
end)

Net.on("TutorialStep", function(step, done)
	if TutorialUI and typeof(step) == "number" then
		TutorialUI.setStep(step, done == true)
	end
end)

Net.on("CaptureResult", function(result)
	if CaptureReveal and typeof(result) == "table" then
		CaptureReveal.show(result)
	end
end)

Net.on("CrisisState", function(state)
	local crisis = panelByName.CrisisPanel
	if crisis and crisis.setCrisis then
		crisis.setCrisis(state)
	end
end)

Net.on("Leaderboard", function(boards)
	local cities = panelByName.CitiesPanel
	if cities and cities.setLeaderboard then
		cities.setLeaderboard(boards)
	end
end)

-- CaptureState, Hazard, Knockback and Forecast are consumed inside
-- CaptureController and RegionGates, which subscribe in their own init.

-- first snapshot: whichever of these lands first wins
task.spawn(function()
	local ok, snap = pcall(Net.invoke, "GetState")
	if ok and typeof(snap) == "table" and not State.get() then
		State.set(snap)
	end
end)

-- ------------------------------------------------------------ world prompts

ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= player then
		return
	end
	local host = prompt.Parent
	local panelName = host and host:GetAttribute("OpensPanel")
	if typeof(panelName) == "string" and W.getPanel(panelName) then
		W.openPanel(panelName)
	end
end)

-- Escape closes whatever panel is open.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		if W.currentPanel() then
			W.closePanels()
		end
	end
end)

print("[" .. Config.GameName .. "] client ready")
