--!strict
-- Coin upgrades and region unlocks. Both are simple purchases, and both are
-- validated here rather than trusted from the client: the level, the price and
-- the cap all come from Config, never from the request.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local Profiles = require(script.Parent.Profiles)
local Stats = require(script.Parent.Stats)
local Notify = require(script.Parent.Notify)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile

local WorkshopService = {}

local function safeCall(systemName: string, fnName: string, ...)
	local system = (S :: any)[systemName]
	if system and typeof(system[fnName]) == "function" then
		local ok, err = pcall(system[fnName], ...)
		if not ok then
			warn("[Workshop] " .. systemName .. "." .. fnName .. " failed: " .. tostring(err))
		end
	end
end

function WorkshopService.canAccess(profile: Profile, regionId: string): boolean
	return profile.data.regions[regionId] == true
end

function WorkshopService.buyUpgrade(profile: Profile, id: any): (boolean, string?)
	if typeof(id) ~= "string" then
		return false, "Unknown upgrade."
	end
	local def = Config.Economy.upgradeById[id]
	if not def then
		return false, "Unknown upgrade."
	end
	if profile.busy then
		return false, "Finish what you are doing first."
	end
	local level = profile.data.upgrades[id] or 0
	local maxLevel = Stats.maxUpgradeLevel(profile, id)
	if level >= maxLevel then
		if id == "habitat_capacity" then
			return false, "Your city is at the maximum of " .. tostring(Config.Economy.deploy.hardCap) .. " work pads. Relaunch to raise your starting pads."
		end
		return false, def.name .. " is already at its maximum level."
	end
	local cost = Config.Economy.upgradeCost(id, level)
	profile.busy = true
	local paid = S.Economy ~= nil and S.Economy.spend(profile, cost)
	if not paid then
		profile.busy = false
		return false, "You need " .. Format.abbreviate(cost) .. " Coins for " .. def.name .. "."
	end
	profile.data.upgrades[id] = level + 1
	profile.busy = false
	profile.dirty = true

	safeCall("City", "applyUpgrades", profile)
	safeCall("Player", "applyCharacter", profile)
	safeCall("Quests", "tutorialEvent", profile, "upgrade")
	if id == "circuit_efficiency" then
		safeCall("Circuits", "recalculate", profile)
	end

	Notify.player(profile.player, "success", def.name .. " is now level " .. tostring(level + 1) .. ".", 4)
	local plot = profile.plot
	if plot then
		Notify.effectFor(profile.player, "purchase", plot.collectPad.Position)
	end
	return true, nil
end

function WorkshopService.unlockRegion(profile: Profile, regionId: any): (boolean, string?)
	if typeof(regionId) ~= "string" then
		return false, "Unknown region."
	end
	local def = Config.Regions.byId[regionId]
	if not def then
		return false, "Unknown region."
	end
	if profile.data.regions[regionId] then
		return false, def.name .. " is already open."
	end
	if profile.busy then
		return false, "Finish what you are doing first."
	end
	profile.busy = true
	local paid = def.unlockCost <= 0 or (S.Economy ~= nil and S.Economy.spend(profile, def.unlockCost))
	if not paid then
		profile.busy = false
		return false, "You need " .. Format.abbreviate(def.unlockCost) .. " Coins to open " .. def.name .. "."
	end
	profile.data.regions[regionId] = true
	profile.busy = false
	profile.dirty = true

	safeCall("Cosmetics", "onProgress", profile) -- the region's aura
	safeCall("Quests", "tutorialEvent", profile, "unlock:" .. regionId)
	safeCall("Quests", "ensureDaily", profile)
	Notify.player(profile.player, "success", def.name .. " is open! " .. def.desc, 6)
	Notify.broadcast(profile.player.DisplayName .. " opened " .. def.name .. ".", def.color)
	return true, nil
end

S.Workshop = WorkshopService
return WorkshopService
