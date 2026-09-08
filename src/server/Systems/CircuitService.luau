--!strict
-- Disaster Circuits: connecting two orthogonally adjacent occupied pads whose
-- elements match a recipe, upgrading a pair, and Overdrive.
--
-- Overdrive is deliberately keyed by PAD PAIR and lives in `profile.overdrives`,
-- not in the connection record. That is what stops the obvious abuse: breaking
-- and remaking a circuit, or swapping the creatures on it, leaves the timer
-- exactly where it was, so a cooldown can never be skipped by reconnecting.
-- `recalculate` therefore never clears an overdrive entry.
--
-- Circuit upgrades belong to the pad pair for the current run
-- (`data.circuitUpgrades`), so changing which creatures stand there does not
-- charge the player twice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local Profiles = require(script.Parent.Profiles)
local Stats = require(script.Parent.Stats)
local Notify = require(script.Parent.Notify)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile

local CircuitService = {}

local OD = Config.Circuits.overdrive
local TICK = 0.25
local VENT_RANGE = 14

local MachineryBuilders: any = nil
local PlotTemplate: any = nil

local function machinery(): any
	if not MachineryBuilders then
		local ok, m = pcall(require, ReplicatedStorage.Shared.Models.MachineryBuilders)
		if ok then
			MachineryBuilders = m
		end
	end
	return MachineryBuilders
end

local function plotTemplate(): any
	if not PlotTemplate then
		local ok, m = pcall(require, script.Parent.Parent.Map.PlotTemplate)
		if ok then
			PlotTemplate = m
		end
	end
	return PlotTemplate
end

local function safeCall(systemName: string, fnName: string, ...)
	local system = (S :: any)[systemName]
	if system and typeof(system[fnName]) == "function" then
		local ok, err = pcall(system[fnName], ...)
		if not ok then
			warn("[Circuits] " .. systemName .. "." .. fnName .. " failed: " .. tostring(err))
		end
	end
end

local function isPad(v: any): boolean
	return typeof(v) == "number" and v == math.floor(v) and v >= 1 and v <= Config.Circuits.maxPads
end

local function atHome(profile: Profile): (boolean, string?)
	if profile.visiting then
		return false, "You are visiting another city. Go home to change your circuits."
	end
	if not profile.plot then
		return false, "Your city is still loading."
	end
	return true, nil
end

-- ---------------------------------------------------------------- connect

function CircuitService.connect(profile: Profile, padA: number, padB: number): (boolean, string?)
	local home, homeMsg = atHome(profile)
	if not home then
		return false, homeMsg
	end
	if not isPad(padA) or not isPad(padB) then
		return false, "Pick two work pads."
	end
	local key = Config.Circuits.pairKey(padA, padB)
	if profile.data.circuits[key] then
		return false, "Those pads are already connected."
	end
	local ok, reason, recipe = Stats.checkPair(profile, padA, padB)
	if not ok then
		return false, reason
	end
	profile.data.circuits[key] = true
	profile.data.stats.connects += 1
	profile.dirty = true
	CircuitService.recalculate(profile)
	safeCall("Quests", "bump", profile, "connects", 1)
	safeCall("Quests", "tutorialEvent", profile, "connect")
	if recipe then
		safeCall("Atlas", "recordRecipe", profile, recipe.id)
		Notify.player(profile.player, "success", recipe.name .. " online! Both creatures earn +" .. Format.percent(Stats.pairBonus(profile, key)) .. ".", 5)
		local pt = plotTemplate()
		if pt then
			Notify.effectFor(profile.player, "circuit", pt.pairCFrame(profile.plot, padA, padB).Position)
		end
	end
	return true, nil
end

function CircuitService.disconnect(profile: Profile, pad: number): (boolean, string?)
	local home, homeMsg = atHome(profile)
	if not home then
		return false, homeMsg
	end
	if not isPad(pad) then
		return false, "Pick a work pad."
	end
	local removed = false
	for key in profile.data.circuits do
		local a, b = Config.Circuits.parsePairKey(key)
		if a == pad or b == pad then
			profile.data.circuits[key] = nil
			removed = true
		end
	end
	if not removed then
		return false, "That pad is not part of a circuit."
	end
	profile.dirty = true
	CircuitService.recalculate(profile)
	return true, nil
end

function CircuitService.upgrade(profile: Profile, padA: number, padB: number): (boolean, string?)
	local home, homeMsg = atHome(profile)
	if not home then
		return false, homeMsg
	end
	if not isPad(padA) or not isPad(padB) then
		return false, "Pick two connected pads."
	end
	local key = Config.Circuits.pairKey(padA, padB)
	if not profile.data.circuits[key] then
		return false, "Connect those pads first."
	end
	if profile.data.circuitUpgrades[key] then
		return false, "That circuit is already upgraded."
	end
	local ok = Stats.checkPair(profile, padA, padB, true)
	if not ok then
		return false, "That circuit is not running."
	end
	local cost = Stats.circuitUpgradeCost(profile, padA, padB)
	if not S.Economy or not S.Economy.spend(profile, cost) then
		return false, "You need " .. Format.abbreviate(cost) .. " Coins to upgrade this circuit."
	end
	profile.data.circuitUpgrades[key] = true
	profile.dirty = true
	CircuitService.recalculate(profile)
	Notify.player(profile.player, "success", "Circuit upgraded. Both creatures now earn +" .. Format.percent(Config.Circuits.upgradedBonus + Stats.compute(profile).circuitBonusExtra) .. ".", 5)
	return true, nil
end

-- ---------------------------------------------------------------- overdrive

function CircuitService.startOverdrive(profile: Profile, padA: number, padB: number): (boolean, string?)
	local home, homeMsg = atHome(profile)
	if not home then
		return false, homeMsg
	end
	if not isPad(padA) or not isPad(padB) then
		return false, "Pick two connected pads."
	end
	local key = Config.Circuits.pairKey(padA, padB)
	if not profile.data.circuits[key] then
		return false, "Connect those pads first."
	end
	local pairs_ = Stats.activePairs(profile)
	if not pairs_[key] then
		return false, "That circuit is not running."
	end
	local now = workspace:GetServerTimeNow()
	local od = profile.overdrives[key]
	if od and od.phase ~= "idle" and now < od.until_ then
		local left = math.ceil(od.until_ - now)
		if od.phase == "active" then
			return false, "Overdrive is already running (" .. tostring(left) .. "s left)."
		end
		return false, "That circuit is cooling down for another " .. tostring(left) .. "s."
	end
	profile.overdrives[key] = { phase = "active", until_ = now + OD.activeSeconds, vented = false }
	profile.data.stats.overdrives += 1
	profile.dirty = true
	CircuitService.applyMachineState(profile)
	safeCall("Quests", "bump", profile, "overdrives", 1)
	safeCall("Quests", "tutorialEvent", profile, "overdrive")
	Notify.player(
		profile.player,
		"warn",
		"Overdrive! Double output for "
			.. tostring(OD.activeSeconds)
			.. "s. Hold the vent at your control booth before it ends to skip the "
			.. tostring(OD.cooldownSeconds)
			.. "s of zero output.",
		6
	)
	return true, nil
end

-- The optional vent at the control booth. Succeeds only while a pair of this
-- player's is in its active phase and has not been vented yet.
function CircuitService.vent(profile: Profile): (boolean, string?)
	local plot = profile.plot
	if not plot or profile.visiting then
		return false, "Use the vent in your own control booth."
	end
	local character = profile.player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return false, nil
	end
	if (hrp.Position - plot.booth.ventButton.Position).Magnitude > VENT_RANGE then
		return false, "Stand at your control booth to vent."
	end
	local now = workspace:GetServerTimeNow()
	local vented = 0
	for key, od in profile.overdrives do
		if od.phase == "active" and now < od.until_ and not od.vented then
			od.vented = true
			vented += 1
		end
	end
	if vented == 0 then
		return false, "Nothing to vent. Start Overdrive on a circuit first."
	end
	profile.dirty = true
	-- nothing left to vent, so the prompt goes away again
	CircuitService.applyMachineState(profile)
	Notify.player(profile.player, "success", "Vented! No cooldown on " .. tostring(vented) .. (if vented == 1 then " circuit." else " circuits."), 4)
	Notify.effectFor(profile.player, "overdrive", plot.booth.ventButton.Position)
	return true, nil
end

-- Advance overdrive phases. Called on a slow loop; also safe to call directly.
function CircuitService.tickProfile(profile: Profile, now: number)
	local changed = false
	for key, od in profile.overdrives do
		if od.phase ~= "idle" and now >= od.until_ then
			if od.phase == "active" then
				if od.vented then
					profile.overdrives[key] = nil
				else
					od.phase = "cooldown"
					od.until_ = now + OD.cooldownSeconds
				end
			else
				profile.overdrives[key] = nil
			end
			changed = true
		end
	end
	if changed then
		profile.dirty = true
		CircuitService.applyMachineState(profile)
	end
end

-- ---------------------------------------------------------------- machines

-- Write Working / Overdrive / Cooling onto the machine and its two workers,
-- and show the vent prompt only while it can actually be used.
function CircuitService.applyMachineState(profile: Profile)
	local now = workspace:GetServerTimeNow()
	local pairs_ = Stats.activePairs(profile)

	local ventable = false
	for _, od in profile.overdrives do
		if od.phase == "active" and now < od.until_ and not od.vented then
			ventable = true
			break
		end
	end
	local plot = profile.plot
	if plot and plot.ventPrompt then
		plot.ventPrompt.Enabled = ventable
	end

	for key, model in profile.machineModels do
		local pair = pairs_[key]
		local od = profile.overdrives[key]
		local phase = if od and now < od.until_ then od.phase else "idle"
		model:SetAttribute("Working", pair ~= nil and phase ~= "cooldown")
		model:SetAttribute("Overdrive", phase == "active")
		model:SetAttribute("Cooling", phase == "cooldown")
		if pair then
			for _, pad in { pair.padA, pair.padB } do
				local worker = profile.padModels[tostring(pad)]
				if worker then
					worker:SetAttribute("Overdrive", phase == "active")
					worker:SetAttribute("Cooling", phase == "cooldown")
				end
			end
		end
	end
end

-- Prune connections that no longer form a valid circuit, then rebuild the
-- machine models. Overdrive entries are never touched here.
function CircuitService.recalculate(profile: Profile)
	local plot = profile.plot
	if not plot then
		return
	end
	local pt = plotTemplate()
	local mb = machinery()

	-- prune: a stored connection whose pads are no longer a valid pair goes away
	for key in profile.data.circuits do
		local a, b = Config.Circuits.parsePairKey(key)
		if not a or not b then
			profile.data.circuits[key] = nil
		else
			local ok = Stats.checkPair(profile, a, b, true)
			if not ok then
				profile.data.circuits[key] = nil
			end
		end
	end

	local pairs_ = Stats.activePairs(profile)

	-- remove machines whose pair is gone
	for key, model in profile.machineModels do
		if not pairs_[key] then
			model:Destroy()
			profile.machineModels[key] = nil
		end
	end

	-- add machines for new pairs
	for key, pair in pairs_ do
		if not profile.machineModels[key] and mb and pt then
			local ok, model = pcall(mb.buildMachine, pair.circuitId)
			if ok and typeof(model) == "Instance" then
				local m = model :: Model
				local cf = pt.pairCFrame(plot, pair.padA, pair.padB)
				m:PivotTo(cf)
				m:SetAttribute("BasePivot", cf)
				m:SetAttribute("PairKey", key)
				CollectionService:AddTag(m, "Animated")
				m.Parent = plot.machines

				local circuit = Config.Circuits.byId[pair.circuitId]
				local billboard = Instance.new("BillboardGui")
				billboard.Name = "MachineLabel"
				billboard.Size = UDim2.fromScale(11, 2)
				billboard.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
				billboard.MaxDistance = 130
				billboard.Parent = m
				local label = Instance.new("TextLabel")
				label.Name = "Text"
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromScale(1, 1)
				label.Font = Enum.Font.FredokaOne
				label.TextScaled = true
				label.TextColor3 = if circuit then circuit.color else Color3.fromRGB(255, 255, 255)
				label.TextStrokeTransparency = 0.25
				label.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
				label.Text = (if circuit then circuit.name else key) .. "  +" .. Format.percent(pair.bonus)
				label.Parent = billboard

				profile.machineModels[key] = m
			end
		end
		-- keep the bonus text current (an efficiency upgrade changes it)
		local m = profile.machineModels[key]
		if m then
			local billboard = m:FindFirstChild("MachineLabel")
			local label = billboard and billboard:FindFirstChild("Text")
			if label and label:IsA("TextLabel") then
				local circuit = Config.Circuits.byId[pair.circuitId]
				label.Text = (if circuit then circuit.name else key) .. "  +" .. Format.percent(pair.bonus)
			end
		end
		-- first time this recipe ran counts as a discovery
		safeCall("Atlas", "recordRecipe", profile, pair.circuitId)
	end

	CircuitService.applyMachineState(profile)
	profile.dirty = true
end

function CircuitService.init()
	task.spawn(function()
		while true do
			task.wait(TICK)
			local now = workspace:GetServerTimeNow()
			for _, profile in Profiles.all() do
				local ok, err = pcall(CircuitService.tickProfile, profile, now)
				if not ok then
					warn("[Circuits] tick failed: " .. tostring(err))
				end
			end
		end
	end)
end

S.Circuits = CircuitService
return CircuitService
