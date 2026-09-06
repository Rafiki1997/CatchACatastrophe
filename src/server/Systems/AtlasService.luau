--!strict
-- The Catastrophe Atlas: permanent species discoveries, variants seen, perfect
-- capture counts, discovered circuit recipes, and the collection milestones.
--
-- Everything here survives selling the creature and survives a relaunch. That
-- is the point of the Atlas: it is the record of what you have ever caught,
-- not what you currently own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Profiles = require(script.Parent.Profiles)
local Stats = require(script.Parent.Stats)
local Notify = require(script.Parent.Notify)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile

local AtlasService = {}

local function entryFor(profile: Profile, speciesId: string): Profiles.AtlasSpecies
	local atlas = profile.data.atlas.species
	local e = atlas[speciesId]
	if not e then
		e = { firstAt = os.time(), variants = {}, perfect = 0, caught = 0 }
		atlas[speciesId] = e
	end
	return e
end

local function masteryFor(profile: Profile, speciesId: string): Profiles.Mastery
	local m = profile.data.mastery[speciesId]
	if not m then
		m = { circuitSeconds = 0, perfect = 0, claims = 0 }
		profile.data.mastery[speciesId] = m
	end
	return m
end

function AtlasService.recordCapture(profile: Profile, speciesId: string, variant: string, perfect: boolean)
	local def = Config.Species.byId[speciesId]
	if not def then
		return
	end
	local before = Stats.discoveredCount(profile)
	local isNew = profile.data.atlas.species[speciesId] == nil

	local e = entryFor(profile, speciesId)
	e.caught += 1
	e.variants[variant] = true
	if perfect then
		e.perfect += 1
		masteryFor(profile, speciesId).perfect += 1
	end
	profile.dirty = true

	if isNew then
		local after = Stats.discoveredCount(profile)
		Notify.player(profile.player, "success", "New Atlas entry: " .. def.name .. "! (" .. tostring(after) .. " / " .. tostring(Config.Species.count) .. ")", 6)
		local _ = before
		-- tell them when a milestone just became claimable
		for _, milestone in Config.Milestones.list do
			if after == milestone.count and not profile.data.atlas.claimed[tostring(milestone.count)] then
				Notify.player(profile.player, "success", "Collection milestone reached! Claim " .. milestone.decorationName .. " in the Atlas.", 7)
			end
		end
	end
end

function AtlasService.recordVariant(profile: Profile, speciesId: string, variant: string)
	if not Config.Species.byId[speciesId] or not Config.Variants.isValid(variant) then
		return
	end
	entryFor(profile, speciesId).variants[variant] = true
	profile.dirty = true
end

function AtlasService.recordRecipe(profile: Profile, circuitId: string)
	local def = Config.Circuits.byId[circuitId]
	if not def then
		return
	end
	if profile.data.atlas.recipes[circuitId] then
		return
	end
	profile.data.atlas.recipes[circuitId] = true
	profile.dirty = true
	Notify.player(profile.player, "success", "Recipe discovered: " .. def.name .. ". " .. def.desc, 6)
end

function AtlasService.claimMilestone(profile: Profile, count: any): (boolean, string?)
	if typeof(count) ~= "number" then
		return false, "Unknown milestone."
	end
	local milestone = Config.Milestones.byCount[math.floor(count)]
	if not milestone then
		return false, "Unknown milestone."
	end
	local key = tostring(milestone.count)
	if profile.data.atlas.claimed[key] then
		return false, "You already claimed that reward."
	end
	local discovered = Stats.discoveredCount(profile)
	if discovered < milestone.count then
		return false, "Discover " .. tostring(milestone.count - discovered) .. " more species to claim this."
	end
	profile.data.atlas.claimed[key] = true
	profile.dirty = true

	if S.City then
		pcall(S.City.applyUpgrades, profile)
		pcall(S.City.refreshLabels, profile)
	end
	Notify.player(profile.player, "success", "Unlocked " .. milestone.decorationName .. " and the title \"" .. milestone.title .. "\".", 7)
	return true, nil
end

S.Atlas = AtlasService
return AtlasService
