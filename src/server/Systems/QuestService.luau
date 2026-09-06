--!strict
-- The seven-step tutorial, four repeatable quests and three rotating daily
-- objectives.
--
-- Rewards are Coins scaled to the player's own normal production, clamped, so
-- a quest is worth doing at minute five and still worth doing after a
-- relaunch. Daily objectives only ever come from regions the player can
-- actually reach, and the circuit-flavoured ones stay out of the pool until a
-- circuit is possible at all.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local Profiles = require(script.Parent.Profiles)
local Stats = require(script.Parent.Stats)
local Notify = require(script.Parent.Notify)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile

local QuestService = {}

local Q = Config.Quests
local REGION_POLL = 1
local REGION_RADIUS = 90

local rng = Random.new()

-- ---------------------------------------------------------------- targets

local function repeatableTarget(profile: Profile, def: any): number
	if def.id == "producer" then
		local income = Stats.income(profile, workspace:GetServerTimeNow())
		return math.max(Q.producerMin, math.floor(income.totalNormal * Q.producerSeconds))
	end
	return def.target
end

local function rewardFor(profile: Profile, def: any): number
	return Stats.scaledReward(profile, def.rewardSeconds, def.rewardMin, def.rewardMax)
end

local function repeatableData(profile: Profile, id: string): Profiles.RepeatableData
	local r = profile.data.quests.repeatable[id]
	if not r then
		r = { progress = 0, cycle = 0 }
		profile.data.quests.repeatable[id] = r
	end
	return r
end

local function dailyDesc(def: any, regionId: string?): string
	if def.regionScoped and regionId then
		local region = Config.Regions.byId[regionId]
		return (def.desc):gsub("%%s", if region then region.name else "a region")
	end
	return def.desc
end

-- ---------------------------------------------------------------- daily roll

function QuestService.ensureDaily(profile: Profile)
	local d = profile.data
	local key = Q.dayKey(os.time())
	if d.quests.daily.dayKey == key and #d.quests.daily.items > 0 then
		return
	end

	-- only objectives the player can actually complete today
	local unlocked: { string } = {}
	for regionId in d.regions do
		if Config.Regions.byId[regionId] then
			table.insert(unlocked, regionId)
		end
	end
	table.sort(unlocked)
	local canCircuit = Stats.canBuildAnyCircuit(profile)

	local pool = {}
	for _, def in Q.dailyPool do
		if not (Q.dailyNeedsCircuit[def.id] and not canCircuit) then
			table.insert(pool, def)
		end
	end

	local items: { Profiles.DailyItemData } = {}
	local taken: { [string]: boolean } = {}
	local guard = 0
	while #items < Q.dailyCount and #pool > 0 and guard < 50 do
		guard += 1
		local pick = pool[rng:NextInteger(1, #pool)]
		if not taken[pick.id] then
			taken[pick.id] = true
			local regionId: string? = nil
			if pick.regionScoped then
				if #unlocked == 0 then
					continue
				end
				regionId = unlocked[rng:NextInteger(1, #unlocked)]
			end
			table.insert(items, { id = pick.id, regionId = regionId, progress = 0, claimed = false })
		end
	end

	d.quests.daily = { dayKey = key, items = items }
	profile.dirty = true
end

-- ---------------------------------------------------------------- progress

-- stat: captures | perfect | collects | connects | overdrives | earned |
--       rare_captures | region_captures
function QuestService.bump(profile: Profile, stat: string, amount: number, regionId: string?)
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	local changed = false

	for _, def in Config.Quests.repeatable do
		if def.stat == stat then
			local r = repeatableData(profile, def.id)
			r.progress += amount
			changed = true
		end
	end

	for _, item in profile.data.quests.daily.items do
		local def = Q.dailyById[item.id]
		if def and def.stat == stat and not item.claimed then
			-- a region-scoped objective only counts in its own region
			if not def.regionScoped or (regionId ~= nil and item.regionId == regionId) then
				item.progress += amount
				changed = true
			end
		end
	end

	if changed then
		profile.dirty = true
	end
end

function QuestService.claimRepeatable(profile: Profile, id: any): (boolean, string?)
	if typeof(id) ~= "string" then
		return false, "Unknown quest."
	end
	local def = Config.Quests.repeatableById[id]
	if not def then
		return false, "Unknown quest."
	end
	local r = repeatableData(profile, id)
	local target = repeatableTarget(profile, def)
	if r.progress < target then
		return false, "Not finished yet."
	end
	local reward = rewardFor(profile, def)
	-- carry the overshoot into the next cycle rather than discarding it
	r.progress -= target
	r.cycle += 1
	if S.Economy then
		S.Economy.addCoins(profile, reward, "quest")
	end
	profile.dirty = true
	Notify.player(profile.player, "success", def.name .. " complete! +" .. Format.abbreviate(reward) .. " Coins.", 5)
	return true, nil
end

function QuestService.claimDaily(profile: Profile, index: any): (boolean, string?)
	if typeof(index) ~= "number" then
		return false, "Unknown objective."
	end
	local item = profile.data.quests.daily.items[math.floor(index)]
	if not item then
		return false, "Unknown objective."
	end
	if item.claimed then
		return false, "You already claimed that one."
	end
	local def = Q.dailyById[item.id]
	if not def then
		return false, "Unknown objective."
	end
	if item.progress < def.target then
		return false, "Not finished yet."
	end
	item.claimed = true
	local reward = rewardFor(profile, def)
	if S.Economy then
		S.Economy.addCoins(profile, reward, "daily")
	end
	profile.dirty = true
	Notify.player(profile.player, "success", def.name .. " complete! +" .. Format.abbreviate(reward) .. " Coins.", 5)
	return true, nil
end

-- ---------------------------------------------------------------- tutorial

-- Which event finishes each step.
local STEP_EVENT: { [number]: string } = {
	[1] = "enter_region:gusty_gardens",
	[2] = "capture",
	[3] = "deploy",
	[4] = "collect",
	[5] = "upgrade",
	[6] = "unlock:splashwater_bay",
}

function QuestService.sendTutorial(profile: Profile)
	local step = profile.data.quests.tutorialStep
	Notify.tutorial(profile.player, step, step >= Q.tutorialDoneStep)
end

local function advanceTo(profile: Profile, step: number)
	profile.data.quests.tutorialStep = math.clamp(step, 1, Q.tutorialDoneStep)
	profile.dirty = true
	QuestService.sendTutorial(profile)
	local def = Q.tutorial[profile.data.quests.tutorialStep]
	if def then
		Notify.player(profile.player, "info", def.title .. ": " .. def.body, 8)
	elseif profile.data.quests.tutorialStep >= Q.tutorialDoneStep then
		Notify.player(profile.player, "success", "Tutorial complete. Your city is yours now.", 6)
	end
end

function QuestService.tutorialEvent(profile: Profile, key: string)
	local step = profile.data.quests.tutorialStep
	if step >= Q.tutorialDoneStep then
		return
	end
	if STEP_EVENT[step] == key then
		advanceTo(profile, step + 1)
	end
end

-- Info-only steps are confirmed by the client's "Got it" button.
function QuestService.tutorialAdvance(profile: Profile, step: any): (boolean, string?)
	if typeof(step) ~= "number" then
		return false, nil
	end
	local current = profile.data.quests.tutorialStep
	if math.floor(step) ~= current then
		return false, nil
	end
	local def = Q.tutorial[current]
	if not def or not def.info then
		return false, nil
	end
	advanceTo(profile, current + 1)
	return true, nil
end

-- ---------------------------------------------------------------- snapshot

function QuestService.snapshotQuests(profile: Profile)
	local d = profile.data
	local repeatable = {}
	for _, def in Config.Quests.repeatable do
		local r = repeatableData(profile, def.id)
		repeatable[def.id] = {
			progress = r.progress,
			target = repeatableTarget(profile, def),
			cycle = r.cycle,
			reward = rewardFor(profile, def),
		}
	end

	local items = {}
	for _, item in d.quests.daily.items do
		local def = Q.dailyById[item.id]
		if def then
			table.insert(items, {
				id = item.id,
				regionId = item.regionId,
				desc = dailyDesc(def, item.regionId),
				progress = item.progress,
				target = def.target,
				claimed = item.claimed,
				reward = rewardFor(profile, def),
			})
		end
	end

	return {
		tutorialStep = d.quests.tutorialStep,
		tutorialDone = d.quests.tutorialStep >= Q.tutorialDoneStep,
		repeatable = repeatable,
		daily = {
			dayKey = d.quests.daily.dayKey,
			resetsAt = workspace:GetServerTimeNow() + Q.secondsUntilReset(os.time()),
			items = items,
		},
	}
end

-- ---------------------------------------------------------------- region poll

-- Eight players against six region centres once a second is cheaper than
-- maintaining touch parts, and it cannot be defeated by jumping the fence.
local function pollRegions()
	for _, player in Players:GetPlayers() do
		local profile = Profiles.get(player)
		if profile and profile.loaded and profile.data.quests.tutorialStep < Q.tutorialDoneStep then
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				for _, def in Config.Regions.list do
					local centre = Vector3.new(math.cos(math.rad(90 + 60 * (def.index - 1))) * 280, 0, math.sin(math.rad(90 + 60 * (def.index - 1))) * 280)
					if (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - centre).Magnitude <= REGION_RADIUS then
						QuestService.tutorialEvent(profile, "enter_region:" .. def.id)
					end
				end
			end
		end
	end
end

function QuestService.init()
	task.spawn(function()
		while true do
			task.wait(REGION_POLL)
			local ok, err = pcall(pollRegions)
			if not ok then
				warn("[Quests] region poll failed: " .. tostring(err))
			end
		end
	end)
	-- roll the day over for anyone online across midnight
	task.spawn(function()
		while true do
			task.wait(30)
			for _, profile in Profiles.all() do
				pcall(QuestService.ensureDaily, profile)
			end
		end
	end)
end

S.Quests = QuestService
return QuestService
