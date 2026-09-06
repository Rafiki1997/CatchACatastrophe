--!strict
-- The two rare appearances, both earned by play rather than bought or rolled:
--
--   Overcharged (1.5x) -- a perfect capture made while that region is surging.
--                         The surge is announced and visible on the gate sign,
--                         so it is a skill window, not a hidden dice roll.
--   Prismatic   (2.0x) -- a species-bound upgrade unlocked by 30 cumulative
--                         ONLINE minutes of that species producing inside an
--                         active circuit, plus 3 perfect captures of it. It
--                         transforms one owned instance and never duplicates.
--                         Claiming resets both counters so it can be earned again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local Profiles = require(script.Parent.Profiles)
local Notify = require(script.Parent.Notify)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile

local VariantService = {}

local P = Config.Variants.prismatic

function VariantService.rollVariant(profile: Profile, regionId: string, perfect: boolean): string
	if not perfect then
		return "Normal"
	end
	if S.Encounters and S.Encounters.isSurge(regionId) then
		return "Overcharged"
	end
	return "Normal"
end

local function masteryFor(profile: Profile, speciesId: string): Profiles.Mastery
	local m = profile.data.mastery[speciesId]
	if not m then
		m = { circuitSeconds = 0, perfect = 0, claims = 0 }
		profile.data.mastery[speciesId] = m
	end
	return m
end

-- (ok, reason) -- reason names what is still missing.
function VariantService.canPrismatic(profile: Profile, speciesId: string): (boolean, string?)
	local def = Config.Species.byId[speciesId]
	if not def then
		return false, "Unknown creature."
	end
	local m = masteryFor(profile, speciesId)
	local minutes = m.circuitSeconds / 60
	if minutes < P.circuitMinutes or m.perfect < P.perfectCaptures then
		local needMinutes = math.max(0, P.circuitMinutes - minutes)
		local needPerfect = math.max(0, P.perfectCaptures - m.perfect)
		local parts = {}
		if needMinutes > 0 then
			table.insert(parts, ("%d more minutes in a circuit"):format(math.ceil(needMinutes)))
		end
		if needPerfect > 0 then
			table.insert(parts, tostring(needPerfect) .. " more perfect " .. (if needPerfect == 1 then "capture" else "captures"))
		end
		return false, def.name .. " needs " .. table.concat(parts, " and ") .. "."
	end
	return true, nil
end

function VariantService.prismaticUpgrade(profile: Profile, uid: any): (boolean, string?)
	if typeof(uid) ~= "string" then
		return false, "Pick a creature."
	end
	local entry = profile.data.creatures[uid]
	if not entry then
		return false, "You do not own that creature."
	end
	if entry.variant == "Prismatic" then
		return false, "That one is already Prismatic."
	end
	local ok, reason = VariantService.canPrismatic(profile, entry.id)
	if not ok then
		return false, reason
	end
	if profile.busy then
		return false, "Finish what you are doing first."
	end

	profile.busy = true
	entry.variant = "Prismatic"
	local m = masteryFor(profile, entry.id)
	-- the recipe is repeatable: both counters start again from zero
	m.circuitSeconds = 0
	m.perfect = 0
	m.claims += 1
	profile.busy = false
	profile.dirty = true

	if S.Atlas then
		pcall(S.Atlas.recordVariant, profile, entry.id, "Prismatic")
	end
	if entry.pad and S.City then
		pcall(S.City.refreshPad, profile, entry.pad)
		pcall(S.Circuits.recalculate, profile)
	end

	local def = Config.Species.byId[entry.id]
	Notify.player(
		profile.player,
		"success",
		(if def then def.name else "Your creature") .. " is now Prismatic! Income x" .. Format.abbreviate(Config.Variants.mult("Prismatic")) .. ".",
		7
	)
	return true, nil
end

S.Variants = VariantService
return VariantService
