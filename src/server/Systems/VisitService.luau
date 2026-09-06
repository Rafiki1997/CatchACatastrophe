--!strict
-- Visiting other players' cities, and the read-only summary the Cities panel
-- shows before you travel.
--
-- A visitor is a tourist: `profile.visiting` is set, and every mutating call in
-- CityService and CircuitService refuses while it is. The collection pad also
-- ignores anyone who is not the owner, so a visitor cannot take money,
-- rearrange creatures or start someone else's Overdrive.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local Profiles = require(script.Parent.Profiles)
local Stats = require(script.Parent.Stats)
local Notify = require(script.Parent.Notify)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile

local VisitService = {}

local function teleport(profile: Profile, cf: CFrame): boolean
	local character = profile.player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return false
	end
	hrp.CFrame = cf + Vector3.new(0, 4, 0)
	return true
end

function VisitService.home(profile: Profile): (boolean, string?)
	profile.visiting = nil
	profile.dirty = true
	local plot = profile.plot
	if plot and teleport(profile, plot.spawnPoint.CFrame) then
		return true, nil
	end
	return true, nil
end

function VisitService.visit(profile: Profile, plotIndex: any): (boolean, string?)
	if typeof(plotIndex) ~= "number" then
		return false, "Pick a city."
	end
	local index = math.floor(plotIndex)
	if index == 0 then
		return VisitService.home(profile)
	end
	if index < 1 or index > Config.MaxPlayers then
		return false, "That city does not exist."
	end
	if profile.capture then
		return false, "Finish or cancel your capture first."
	end
	if index == profile.plotIndex then
		return VisitService.home(profile)
	end
	if not S.City then
		return false, "Cities are still loading."
	end
	local plot = S.City.plotOf(index)
	if not plot then
		return false, "That city does not exist."
	end
	local ownerId = plot.model:GetAttribute("OwnerUserId")
	if typeof(ownerId) ~= "number" or ownerId == 0 then
		return false, "Nobody lives there yet."
	end
	if not teleport(profile, plot.visitorSpot.CFrame) then
		return false, "Wait until you have respawned."
	end
	profile.visiting = index
	profile.dirty = true
	Notify.player(profile.player, "info", "Visiting " .. tostring(plot.model:GetAttribute("OwnerName")) .. "'s city. You can look, but not touch.", 6)
	return true, nil
end

-- Read-only view for the Cities panel. Safe to hand to any player.
function VisitService.cityInfo(plotIndex: any): Types.CityInfo?
	if typeof(plotIndex) ~= "number" then
		return nil
	end
	local index = math.floor(plotIndex)
	if not S.City then
		return nil
	end
	local plot = S.City.plotOf(index)
	if not plot then
		return nil
	end
	local ownerId = plot.model:GetAttribute("OwnerUserId")
	if typeof(ownerId) ~= "number" or ownerId == 0 then
		return nil
	end
	local owner = Profiles.getByUserId(ownerId)
	if not owner then
		return nil
	end

	local now = workspace:GetServerTimeNow()
	local income = Stats.income(owner, now)
	local creatures = {}
	for uid, entry in owner.data.creatures do
		if entry.pad then
			table.insert(creatures, { id = entry.id, variant = entry.variant, pad = entry.pad, cps = income.perCreature[uid] or 0 })
		end
	end
	table.sort(creatures, function(a, b)
		return a.pad < b.pad
	end)

	local circuits = {}
	for _, pair in income.pairs do
		table.insert(circuits, { circuitId = pair.circuitId, padA = pair.padA, padB = pair.padB, upgraded = pair.upgraded })
	end
	table.sort(circuits, function(a, b)
		return a.padA < b.padA
	end)

	local recipes = {}
	for id in owner.data.atlas.recipes do
		table.insert(recipes, id)
	end
	table.sort(recipes)

	return {
		ownerName = owner.player.DisplayName,
		plotIndex = index,
		relaunch = owner.data.relaunch,
		cps = income.total,
		creatures = creatures,
		circuits = circuits,
		recipes = recipes,
	}
end

S.Visit = VisitService
return VisitService
