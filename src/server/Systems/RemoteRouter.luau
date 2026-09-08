--!strict
-- Every client to server message enters the game through here.
--
-- The order is always the same: rate limit, type check, profile lookup,
-- handler, and a plain-language error back to the player if the handler says
-- no. Handlers get values that are already the right shape, so they can spend
-- their attention on game rules instead of on defending against garbage.
--
-- Nothing in this file trusts a number from the client. Prices, payouts,
-- capture results and ownership are all derived server side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Profiles = require(script.Parent.Profiles)
local Notify = require(script.Parent.Notify)
local RateLimiter = require(script.Parent.RateLimiter)
local Sync = require(script.Parent.Sync)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile

local Router = {}

local R = Remotes.get()

-- ---------------------------------------------------------------- validators

local function isId(v: any): boolean
	return typeof(v) == "string" and #v > 0 and #v <= 64
end

local function isFiniteNumber(v: any): boolean
	return typeof(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function isPad(v: any): boolean
	return isFiniteNumber(v) and v == math.floor(v) and v >= 1 and v <= Config.Circuits.maxPads
end

local function isIndex(v: any, max: number): boolean
	return isFiniteNumber(v) and v == math.floor(v) and v >= 0 and v <= max
end

local function isBool(v: any): boolean
	return typeof(v) == "boolean"
end

local function isUidList(v: any): boolean
	if typeof(v) ~= "table" then
		return false
	end
	local n = 0
	for key, value in v :: { [any]: any } do
		if typeof(key) ~= "number" or not isId(value) then
			return false
		end
		n += 1
		if n > 8 then
			return false
		end
	end
	return true
end

-- ---------------------------------------------------------------- binding

local function bind(name: string, validate: (...any) -> boolean, handler: (Profile, ...any) -> (boolean?, string?))
	local event = R.Event[name]
	if not event then
		warn("[Router] no remote named " .. name)
		return
	end
	event.OnServerEvent:Connect(function(player: Player, ...)
		if not RateLimiter.allow(player, name) then
			return
		end
		local profile = Profiles.get(player)
		if not profile or not profile.loaded then
			return
		end
		if not validate(...) then
			-- a malformed payload is either a bug or an attack; either way, silence
			return
		end
		local ok, result, message = pcall(handler, profile, ...)
		if not ok then
			warn("[Router] " .. name .. " failed for " .. player.Name .. ": " .. tostring(result))
			Notify.player(player, "error", "Something went wrong. Please try again.", 4)
			return
		end
		if result == false and typeof(message) == "string" then
			Notify.player(player, "error", message, 5)
		end
		if profile.dirty then
			Sync.push(profile)
		end
	end)
end

-- A system that failed to load answers politely rather than crashing.
local function via(systemName: string, fnName: string)
	return function(profile: Profile, ...): (boolean?, string?)
		local system = (S :: any)[systemName]
		if not system or typeof(system[fnName]) ~= "function" then
			return false, "That part of the game is still starting up. Try again in a moment."
		end
		return system[fnName](profile, ...)
	end
end

function Router.init()
	-- capture
	bind("StartCapture", isId, via("Capture", "start"))
	bind("CancelCapture", function()
		return true
	end, function(profile)
		if S.Capture then
			S.Capture.cancel(profile, nil)
		end
		return true, nil
	end)

	-- creatures
	bind("DeployCreature", function(uid, pad)
		return isId(uid) and isPad(pad)
	end, via("City", "deploy"))
	bind("StoreCreature", isId, via("City", "store"))
	bind("MoveCreature", function(uid, pad)
		return isId(uid) and isPad(pad)
	end, via("City", "move"))
	bind("SellCreature", isId, via("City", "sell"))
	bind("SetFavorite", function(uid, favorite)
		return isId(uid) and isBool(favorite)
	end, via("City", "setFavorite"))
	bind("PrismaticUpgrade", isId, via("Variants", "prismaticUpgrade"))

	-- circuits
	bind("ConnectCircuit", function(a, b)
		return isPad(a) and isPad(b)
	end, via("Circuits", "connect"))
	bind("DisconnectCircuit", isPad, via("Circuits", "disconnect"))
	bind("UpgradeCircuit", function(a, b)
		return isPad(a) and isPad(b)
	end, via("Circuits", "upgrade"))
	bind("StartOverdrive", function(a, b)
		return isPad(a) and isPad(b)
	end, via("Circuits", "startOverdrive"))

	-- money
	-- gated by the Remote Collector upgrade and its cooldown (Economy.collectRemote);
	-- the pad pays through CollectionPadService, never through this remote
	bind("CollectBank", function()
		return true
	end, via("Economy", "collectRemote"))
	bind("ClaimOffline", function()
		return true
	end, via("Economy", "claimOffline"))

	-- store
	bind("PromptPurchase", function(kind, id)
		return (kind == "pass" or kind == "product") and isId(id)
	end, via("Purchase", "prompt"))
	bind("HatchEgg", function(eggId, count)
		return isId(eggId) and isFiniteNumber(count) and (count == 1 or count == Config.Store.hatchBatch)
	end, via("Purchase", "requestHatch"))
	-- Studio only: the handler refuses anything but a test-adapter profile, so a
	-- live client firing this gets nothing.
	bind("TestGrant", isId, via("Purchase", "testGrantRemote"))
	bind("EquipCosmetic", function(family, id)
		return isId(family) and typeof(id) == "string" and #id <= 64
	end, via("Cosmetics", "equip"))
	bind("BuyCosmetic", isId, via("Cosmetics", "buy"))
	bind("PlaceDecor", function(id, slotId, rot)
		return isId(id) and isId(slotId) and isFiniteNumber(rot)
	end, via("Cosmetics", "place"))
	bind("StoreDecor", isId, via("Cosmetics", "unplace"))

	-- workshop
	bind("BuyUpgrade", isId, via("Workshop", "buyUpgrade"))
	bind("UnlockRegion", isId, via("Workshop", "unlockRegion"))

	-- progression
	bind("DoRelaunch", function(uids, acknowledged)
		return isUidList(uids) and isBool(acknowledged)
	end, via("Relaunch", "perform"))
	bind("ClaimMilestone", function(count)
		return isIndex(count, 1000)
	end, via("Atlas", "claimMilestone"))
	bind("ClaimQuest", isId, via("Quests", "claimRepeatable"))
	bind("ClaimDaily", function(index)
		return isIndex(index, Config.Quests.dailyCount)
	end, via("Quests", "claimDaily"))
	bind("TutorialAdvance", function(step)
		return isIndex(step, Config.Quests.tutorialDoneStep)
	end, via("Quests", "tutorialAdvance"))

	-- world
	bind("VisitCity", function(index)
		return isIndex(index, Config.MaxPlayers)
	end, via("Visit", "visit"))

	-- settings
	local NUMBER_SETTINGS = { music = true, sfx = true }
	local BOOL_SETTINGS = { reducedMotion = true, reducedFlashing = true, notifications = true }
	bind("SetSetting", function(key, value)
		if typeof(key) ~= "string" then
			return false
		end
		if NUMBER_SETTINGS[key] then
			return isFiniteNumber(value) and value >= 0 and value <= 1
		end
		if BOOL_SETTINGS[key] then
			return isBool(value)
		end
		return false
	end, function(profile, key, value)
		(profile.data.settings :: any)[key] = value
		profile.dirty = true
		return true, nil
	end)

	bind("RequestState", function()
		return true
	end, function(profile)
		profile.dirty = true
		return true, nil
	end)

	-- ---------------------------------------------------------------- functions
	R.Function.GetCityInfo.OnServerInvoke = function(player: Player, plotIndex: any)
		if not RateLimiter.allow(player, "GetCityInfo") then
			return nil
		end
		if not isIndex(plotIndex, Config.MaxPlayers) then
			return nil
		end
		if not S.Visit then
			return nil
		end
		local ok, info = pcall(S.Visit.cityInfo, plotIndex)
		return if ok then info else nil
	end

	-- ---------------------------------------------------------------- prompts
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if not RateLimiter.allow(player, "Prompt") then
			return
		end
		local profile = Profiles.get(player)
		if not profile then
			return
		end
		local host = prompt.Parent
		local kind = host and host:GetAttribute("Prompt")
		if kind == "Vent" and S.Circuits then
			local ok, result, message = pcall(S.Circuits.vent, profile)
			if ok and result == false and typeof(message) == "string" then
				Notify.player(player, "error", message, 4)
			end
			if profile.dirty then
				Sync.push(profile)
			end
		end
	end)

	-- Pylons are held, not tapped: accumulate work for as long as the prompt is
	-- held down, and stop the moment it is released.
	local holding: { [Player]: { index: number, since: number } } = {}
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, player)
		local host = prompt.Parent
		local index = host and host:GetAttribute("PylonIndex")
		if typeof(index) == "number" then
			holding[player] = { index = index, since = os.clock() }
		end
	end)
	local function stopHold(player: Player)
		holding[player] = nil
	end
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(_, player)
		stopHold(player)
	end)
	ProximityPromptService.PromptTriggerEnded:Connect(function(_, player)
		stopHold(player)
	end)
	Players.PlayerRemoving:Connect(stopHold)

	task.spawn(function()
		while true do
			task.wait(0.2)
			local now = os.clock()
			for player, entry in holding do
				if not player.Parent then
					holding[player] = nil
					continue
				end
				local profile = Profiles.get(player)
				if profile and S.Crisis then
					local dt = now - entry.since
					entry.since = now
					pcall(S.Crisis.onPylonHold, profile, entry.index, dt)
				end
			end
		end
	end)

end

-- Prompts for the world objects the server owns.
function Router.attachPrompts(refs: any)
	local function addPrompt(host: Instance?, actionText: string, objectText: string, holdDuration: number?, distance: number?)
		if not host or not host:IsA("BasePart") then
			return nil
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = actionText
		prompt.ObjectText = objectText
		prompt.HoldDuration = holdDuration or 0
		prompt.MaxActivationDistance = distance or 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = host
		return prompt
	end

	if refs and refs.arena then
		for i, entry in refs.arena.pylons do
			local model = entry.model
			local target = model and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart"))
			local prompt = addPrompt(target, "Hold to contain", "Containment Pylon " .. tostring(i), 0.35, 16)
			if prompt and target then
				target:SetAttribute("PylonIndex", i)
				prompt.Parent = target
				-- the hold handler reads PylonIndex from the prompt's parent
				entry.prompt = prompt
			end
		end
	end

	if S.City then
		for _, plot in S.City.allPlots() do
			-- The vent only means anything while a pair is in its active phase,
			-- so it stays disabled until CircuitService switches it on. A prompt
			-- that is always there but usually useless teaches the wrong lesson.
			local vent = addPrompt(plot.booth.ventButton, "Hold to vent", "Overdrive Vent", Config.Circuits.overdrive.ventHoldSeconds, 14)
			if vent then
				vent.Enabled = false
				plot.ventPrompt = vent
			end

		end
	end

	-- panel terminals in the hub
	if refs and refs.hub then
		addPrompt(refs.hub.workshop, "Open", "Upgrade Workshop", 0, 14)
		addPrompt(refs.hub.beacon, "Open", "City Relaunch", 0, 14)
		addPrompt(refs.hub.atlas, "Open", "Catastrophe Atlas", 0, 14)
	end
	local _ = RunService
end

S.Router = Router
return Router
