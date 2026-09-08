--!strict
-- Who owns which cosmetic, and which one they are wearing.
--
-- Ownership is stored per item rather than recomputed from the player's current
-- progress, because progress moves backwards: a relaunch closes every region
-- again, and an aura earned by opening Cinder Canyon must not vanish when the
-- city resets. `refresh` therefore only ever adds.
--
-- What is worn is published as a Player attribute rather than sent over a
-- remote: attributes replicate to every client automatically, so one player
-- putting on an aura is drawn for everyone in the server, including anyone who
-- joins afterwards, with no message of our own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Notify = require(script.Parent.Notify)
local Profiles = require(script.Parent.Profiles)
local S = require(script.Parent.Services)
local Sync = require(script.Parent.Sync)

type Profile = Profiles.Profile

local CosmeticsService = {}

local Cosmetics = Config.Cosmetics
local AURA_ATTRIBUTE = "Aura"

local function owned(profile: Profile, id: string): boolean
	return profile.data.cosmetics.owned[id] == true
end

-- Has this player met the condition? Ownership is granted from this, never read
-- from it afterwards.
local function earned(profile: Profile, item: Config.Cosmetic): boolean
	local unlock = item.unlock
	local d = profile.data
	if unlock.kind == "region" then
		return d.regions[unlock.regionId] == true
	elseif unlock.kind == "relaunch" then
		return d.relaunch >= unlock.count
	elseif unlock.kind == "crisis" then
		return d.stats.crisisWins >= unlock.wins
	end
	return false -- store items are granted by the purchase, not by playing
end

-- Publishes what the player is wearing. Called after every change and on spawn.
function CosmeticsService.apply(profile: Profile)
	local player = profile.player
	if not player.Parent then
		return
	end
	local auraId = profile.data.cosmetics.equipped.aura
	if auraId and owned(profile, auraId) and Cosmetics.byId[auraId] then
		player:SetAttribute(AURA_ATTRIBUTE, auraId)
	else
		player:SetAttribute(AURA_ATTRIBUTE, nil)
	end
end

function CosmeticsService.grant(profile: Profile, id: string, quiet: boolean?): boolean
	local item = Cosmetics.byId[id]
	if not item or owned(profile, id) then
		return false
	end
	profile.data.cosmetics.owned[id] = true
	profile.dirty = true
	if not quiet and profile.player.Parent then
		Notify.player(profile.player, "success", "New " .. item.family .. ": " .. item.name .. "! Wear it from the Store, under Style.", 7)
	end
	return true
end

-- Grants everything the player has already earned. Safe to call at any time and
-- as often as we like: it only adds, and it says nothing on a first load when
-- the player is being caught up rather than rewarded.
function CosmeticsService.refresh(profile: Profile, quiet: boolean?): number
	local granted = 0
	for _, item in Cosmetics.list do
		if not owned(profile, item.id) and earned(profile, item) then
			if CosmeticsService.grant(profile, item.id, quiet) then
				granted += 1
			end
		end
	end
	if granted > 0 then
		CosmeticsService.apply(profile)
	end
	return granted
end

-- Wearing nothing is a valid choice, so an empty id unequips rather than erroring.
function CosmeticsService.equip(profile: Profile, family: any, id: any): (boolean, string?)
	if typeof(family) ~= "string" or typeof(id) ~= "string" then
		return false, "That is not something you can wear."
	end
	if id == "" then
		profile.data.cosmetics.equipped[family] = nil
		profile.dirty = true
		CosmeticsService.apply(profile)
		Sync.push(profile)
		return true, nil
	end
	local item = Cosmetics.byId[id]
	if not item or item.family ~= family then
		return false, "That is not something you can wear."
	end
	if not owned(profile, id) then
		return false, item.name .. " is not yours yet: " .. Cosmetics.requirement(item, function(regionId)
			local region = Config.Regions.byId[regionId]
			return if region then region.name else regionId
		end) .. "."
	end
	profile.data.cosmetics.equipped[family] = id
	profile.dirty = true
	CosmeticsService.apply(profile)
	Sync.push(profile)
	return true, nil
end

function CosmeticsService.onJoin(profile: Profile)
	-- quiet: a returning player is being caught up, not congratulated
	CosmeticsService.refresh(profile, true)
	CosmeticsService.apply(profile)
end

-- Called wherever progress moves: a region opened, a relaunch, a crisis won.
function CosmeticsService.onProgress(profile: Profile)
	if CosmeticsService.refresh(profile, false) > 0 then
		Sync.push(profile)
	end
end

S.Cosmetics = CosmeticsService

return CosmeticsService
