--!strict
-- City Relaunch: the rebirth. Ten levels, each +25% permanent income and one
-- more starting work pad.
--
-- The whole transition is one function guarded by `profile.busy`, so a second
-- request that arrives while the first is running is refused rather than
-- running the reset twice. It saves immediately afterwards: a relaunch that
-- vanished in a crash would be the worst possible bug in the game.
--
-- Anchors are the player's promise-keeping mechanism: they pick which
-- creatures survive, up to their anchor slots, and everything unanchored goes,
-- including favorites. Favorites are never deleted silently -- the client must
-- pass `acknowledged`, and the server refuses without it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local Profiles = require(script.Parent.Profiles)
local Stats = require(script.Parent.Stats)
local Notify = require(script.Parent.Notify)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile

local RelaunchService = {}

function RelaunchService.canRelaunch(profile: Profile): (boolean, string?)
	local d = profile.data
	if d.relaunch >= Config.Relaunch.maxLevel then
		return false, "You have reached the highest relaunch level."
	end
	if profile.busy then
		return false, "A purchase is still going through. Try again in a moment."
	end
	if profile.capture then
		return false, "Finish or cancel your capture first."
	end
	if profile.dataState ~= "loaded" then
		return false, "Your save is not ready. Relaunching now could lose progress."
	end
	if not profile.dataSafe then
		return false, "Your data could not be loaded this session, so relaunching is disabled to protect your city."
	end
	local cost = Config.Relaunch.cost(d.relaunch)
	if d.coins < cost then
		return false, "You need " .. Format.abbreviate(cost) .. " Coins to relaunch."
	end
	local required = Config.Relaunch.speciesRequired(d.relaunch)
	local discovered = Stats.discoveredCount(profile)
	if discovered < required then
		return false, "You need " .. tostring(required) .. " discovered species (you have " .. tostring(discovered) .. ")."
	end
	return true, nil
end

function RelaunchService.perform(profile: Profile, anchorUids: any, acknowledged: any): (boolean, string?)
	local ok, reason = RelaunchService.canRelaunch(profile)
	if not ok then
		return false, reason
	end
	if acknowledged ~= true then
		return false, "Tick the box confirming what you will lose before relaunching."
	end
	if typeof(anchorUids) ~= "table" then
		return false, "Choose which creatures to anchor."
	end

	local d = profile.data
	local computed = Stats.compute(profile)
	local slots = computed.anchorSlots

	-- validate anchors: owned, unique, within the slot count
	local anchors: { [string]: boolean } = {}
	local count = 0
	for _, uid in anchorUids :: { any } do
		if typeof(uid) ~= "string" then
			return false, "That anchor choice is not valid."
		end
		if not d.creatures[uid] then
			return false, "You do not own one of the creatures you picked to anchor."
		end
		if not anchors[uid] then
			anchors[uid] = true
			count += 1
		end
	end
	if count > slots then
		return false, "You can only anchor " .. tostring(slots) .. " " .. (if slots == 1 then "creature" else "creatures") .. "."
	end

	profile.busy = true

	local level = d.relaunch + 1

	-- ---------------------------------------------------------------- reset
	-- The cost is not deducted separately: the reset sets Coins to the fixed
	-- starting amount, and canRelaunch already proved the player could pay it.
	d.coins = Config.Relaunch.resetCoins
	d.bank = 0
	d.offlinePending = 0
	d.offlinePendingSeconds = 0
	d.upgrades = {}
	d.regions = { gusty_gardens = true }
	d.circuits = {}
	d.circuitUpgrades = {}

	local kept = 0
	for uid, entry in d.creatures do
		if anchors[uid] then
			entry.pad = nil
			entry.anchored = true
			kept += 1
		else
			d.creatures[uid] = nil
		end
	end

	-- runtime state that belonged to the old city
	profile.overdrives = {}
	for _, model in profile.padModels do
		model:Destroy()
	end
	profile.padModels = {}
	for _, model in profile.machineModels do
		model:Destroy()
	end
	profile.machineModels = {}

	-- ---------------------------------------------------------------- advance
	d.relaunch = level
	d.stats.relaunches += 1
	-- Atlas, mastery, milestone claims, tutorial, daily records, settings and
	-- lifetime coins are all deliberately untouched.

	if S.City then
		pcall(S.City.applyUpgrades, profile)
		pcall(S.City.refreshAll, profile)
	end
	if S.Player then
		pcall(S.Player.applyCharacter, profile)
	end
	profile.dirty = true
	profile.busy = false

	if S.Data then
		task.spawn(function()
			pcall(S.Data.save, profile, "relaunch")
		end)
	end

	local mult = Config.Relaunch.incomeMultiplier(level)
	Notify.player(
		profile.player,
		"success",
		"City Relaunch "
			.. tostring(level)
			.. "! Permanent income is now x"
			.. ("%.2f"):format(mult)
			.. " and you start with "
			.. tostring(Config.Relaunch.startingPads(level))
			.. " work pads."
			.. (if kept > 0 then " " .. tostring(kept) .. " anchored " .. (if kept == 1 then "creature is" else "creatures are") .. " waiting in storage." else ""),
		9
	)
	Notify.broadcast(profile.player.DisplayName .. " relaunched their city (level " .. tostring(level) .. ")!", Color3.fromRGB(140, 235, 255))
	local plot = profile.plot
	if plot then
		Notify.effect("relaunch", plot.collectPad.Position)
	end
	return true, nil
end

S.Relaunch = RelaunchService
return RelaunchService
