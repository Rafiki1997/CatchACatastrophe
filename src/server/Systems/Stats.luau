--!strict
-- Derived numbers for a profile. Every formula the game "computes about a
-- player" lives here so income, the snapshot and validation agree.
--
-- Income of one deployed creature =
--   regionBase x rarityMult x variantMult x relaunchMult   (= normalCps)
--   x (1 + circuitBonus)      when its pad is in an active pair
--   x overdriveFactor         2 during Overdrive active, 0 during cooldown, else 1
-- Each factor is applied exactly once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Profiles = require(script.Parent.Profiles)

type Profile = Profiles.Profile
type CreatureData = Profiles.CreatureData

local Stats = {}

export type Computed = {
	relaunchMult: number,
	tetherRange: number,
	tetherSpeedMult: number, -- capture seconds are divided by this
	walkSpeed: number,
	circuitBonusExtra: number,
	bankCapSeconds: number,
	storageMax: number,
	padsTotal: number,
	anchorSlots: number,
	decorationTier: number,
}

export type Pair = {
	key: string,
	padA: number,
	padB: number,
	uidA: string,
	uidB: string,
	circuitId: string,
	upgraded: boolean,
	bonus: number,
}

local function level(profile: Profile, id: string): number
	return profile.data.upgrades[id] or 0
end

function Stats.compute(profile: Profile): Computed
	local d = profile.data
	local U = Config.Economy.upgradeById
	local basePads = Config.Relaunch.startingPads(d.relaunch)
	local pads = math.min(basePads + level(profile, "habitat_capacity"), Config.Economy.deploy.hardCap)
	return {
		relaunchMult = Config.Relaunch.incomeMultiplier(d.relaunch),
		tetherRange = math.min(Config.Capture.tetherRange + level(profile, "tether_range") * U.tether_range.perLevel, U.tether_range.cap or Config.Capture.tetherRangeCap),
		tetherSpeedMult = 1 + level(profile, "tether_speed") * U.tether_speed.perLevel,
		walkSpeed = math.min(24 + level(profile, "move_speed") * U.move_speed.perLevel, U.move_speed.cap or 36),
		circuitBonusExtra = level(profile, "circuit_efficiency") * U.circuit_efficiency.perLevel,
		bankCapSeconds = Config.Economy.income.bankCapSeconds + level(profile, "bank_capacity") * U.bank_capacity.perLevel,
		storageMax = math.min(Config.Economy.storage.base + level(profile, "storage") * U.storage.perLevel, Config.Economy.storage.max),
		padsTotal = pads,
		anchorSlots = Config.Relaunch.anchorSlots(d.relaunch),
		decorationTier = level(profile, "decoration"),
	}
end

-- Extra habitat_capacity levels are pointless once pads hit the hard cap.
function Stats.maxUpgradeLevel(profile: Profile, id: string): number
	local def = Config.Economy.upgradeById[id]
	if not def then
		return 0
	end
	if id == "habitat_capacity" then
		return math.max(0, Config.Economy.deploy.hardCap - Config.Relaunch.startingPads(profile.data.relaunch))
	end
	return def.maxLevel
end

-- uid of the creature on `pad`, if any.
function Stats.padOccupant(profile: Profile, pad: number): string?
	for uid, c in profile.data.creatures do
		if c.pad == pad then
			return uid
		end
	end
	return nil
end

function Stats.padMap(profile: Profile): { [number]: string }
	local map = {}
	for uid, c in profile.data.creatures do
		if c.pad then
			map[c.pad] = uid
		end
	end
	return map
end

function Stats.deployedCount(profile: Profile): number
	local n = 0
	for _, c in profile.data.creatures do
		if c.pad then
			n += 1
		end
	end
	return n
end

-- Normal income of one creature: no circuit, no overdrive. 0 when stored.
function Stats.normalCps(profile: Profile, entry: CreatureData, computed: Computed?): number
	if not entry.pad then
		return 0
	end
	local c = computed or Stats.compute(profile)
	return Config.Species.baseIncome(entry.id) * Config.Variants.mult(entry.variant) * c.relaunchMult
end

-- Same formula ignoring deployment (used for sell value, circuit upgrade cost).
function Stats.potentialCps(profile: Profile, entry: CreatureData, computed: Computed?): number
	local c = computed or Stats.compute(profile)
	return Config.Species.baseIncome(entry.id) * Config.Variants.mult(entry.variant) * c.relaunchMult
end

function Stats.pairBonus(profile: Profile, pairKey: string, computed: Computed?): number
	local c = computed or Stats.compute(profile)
	local base = if profile.data.circuitUpgrades[pairKey] then Config.Circuits.upgradedBonus else Config.Circuits.baseBonus
	return base + c.circuitBonusExtra
end

-- Validates a candidate pair. Returns (ok, reason, recipe).
function Stats.checkPair(profile: Profile, padA: number, padB: number, ignoreExisting: boolean?): (boolean, string, any?)
	if padA == padB or not Config.Circuits.areAdjacent(padA, padB) then
		return false, "Pads must be side by side (not diagonal).", nil
	end
	local uidA = Stats.padOccupant(profile, padA)
	local uidB = Stats.padOccupant(profile, padB)
	if not uidA or not uidB then
		return false, "Both pads need a working creature.", nil
	end
	local a = profile.data.creatures[uidA]
	local b = profile.data.creatures[uidB]
	local recipe = Config.Circuits.recipe(Config.Species.byId[a.id].element, Config.Species.byId[b.id].element)
	if not recipe then
		return false, "These two elements do not make a circuit. Check the Recipe Book.", nil
	end
	if not ignoreExisting then
		for key in profile.data.circuits do
			local x, y = Config.Circuits.parsePairKey(key)
			if x and y and key ~= Config.Circuits.pairKey(padA, padB) then
				if x == padA or y == padA then
					return false, "That creature is already in a circuit.", recipe
				end
				if x == padB or y == padB then
					return false, "That creature is already in a circuit.", recipe
				end
			end
		end
	end
	return true, "", recipe
end

-- All currently VALID active pairs (invalid stored pairs are ignored, and
-- CircuitService prunes them). Returns (byKey, padToKey).
function Stats.activePairs(profile: Profile, computed: Computed?): ({ [string]: Pair }, { [number]: string })
	local c = computed or Stats.compute(profile)
	local pairs: { [string]: Pair } = {}
	local padToKey: { [number]: string } = {}
	local occupant = Stats.padMap(profile)
	for key in profile.data.circuits do
		local a, b = Config.Circuits.parsePairKey(key)
		if a and b and Config.Circuits.areAdjacent(a, b) and not padToKey[a] and not padToKey[b] then
			local uidA, uidB = occupant[a], occupant[b]
			if uidA and uidB then
				local ea, eb = profile.data.creatures[uidA], profile.data.creatures[uidB]
				local recipe = Config.Circuits.recipe(Config.Species.byId[ea.id].element, Config.Species.byId[eb.id].element)
				if recipe then
					pairs[key] = {
						key = key,
						padA = a,
						padB = b,
						uidA = uidA,
						uidB = uidB,
						circuitId = recipe.id,
						upgraded = profile.data.circuitUpgrades[key] == true,
						bonus = Stats.pairBonus(profile, key, c),
					}
					padToKey[a] = key
					padToKey[b] = key
				end
			end
		end
	end
	return pairs, padToKey
end

-- 2 during Overdrive active, 0 during cooldown, 1 otherwise. `now` = server time.
function Stats.overdriveFactor(profile: Profile, pairKey: string, now: number): number
	local od = profile.overdrives[pairKey]
	if not od or od.phase == "idle" then
		return 1
	end
	if now >= od.until_ then
		return 1 -- CircuitService advances phases; treat expired as idle
	end
	if od.phase == "active" then
		return Config.Circuits.overdrive.multiplier
	elseif od.phase == "cooldown" then
		return 0
	end
	return 1
end

export type Income = {
	perCreature: { [string]: number }, -- uid -> effective cps (with overdrive)
	perCreatureNormal: { [string]: number }, -- uid -> cps with circuit bonus but no overdrive
	total: number,
	totalNormal: number,
	pairs: { [string]: Pair },
	padToKey: { [number]: string },
}

-- Full income breakdown at `now` (server time).
function Stats.income(profile: Profile, now: number, computed: Computed?): Income
	local c = computed or Stats.compute(profile)
	local pairs, padToKey = Stats.activePairs(profile, c)
	local per: { [string]: number } = {}
	local perNormal: { [string]: number } = {}
	local total, totalNormal = 0, 0
	for uid, entry in profile.data.creatures do
		if entry.pad then
			local base = Stats.normalCps(profile, entry, c)
			local key = padToKey[entry.pad]
			local withCircuit = base
			local factor = 1
			if key then
				withCircuit = base * (1 + pairs[key].bonus)
				factor = Stats.overdriveFactor(profile, key, now)
			end
			per[uid] = withCircuit * factor
			perNormal[uid] = withCircuit
			total += per[uid]
			totalNormal += withCircuit
		end
	end
	return { perCreature = per, perCreatureNormal = perNormal, total = total, totalNormal = totalNormal, pairs = pairs, padToKey = padToKey }
end

function Stats.bankCap(profile: Profile, income: Income?, computed: Computed?): number
	local c = computed or Stats.compute(profile)
	local inc = income or Stats.income(profile, workspace:GetServerTimeNow(), c)
	return inc.totalNormal * c.bankCapSeconds
end

function Stats.sellValue(profile: Profile, entry: CreatureData): number
	local def = Config.Species.byId[entry.id]
	if not def then
		return 0
	end
	local seconds = Config.Rarities.info[def.rarity].sellSeconds
	return math.max(Config.Economy.sellMin, math.floor(Stats.potentialCps(profile, entry) * seconds))
end

function Stats.circuitUpgradeCost(profile: Profile, padA: number, padB: number): number
	local uidA, uidB = Stats.padOccupant(profile, padA), Stats.padOccupant(profile, padB)
	if not uidA or not uidB then
		return math.huge
	end
	local a, b = profile.data.creatures[uidA], profile.data.creatures[uidB]
	local pairCps = Stats.potentialCps(profile, a) + Stats.potentialCps(profile, b)
	return math.max(Config.Circuits.upgradeMinCost, math.ceil(pairCps * Config.Circuits.upgradeCostSeconds))
end

-- Coins = clamp(normal production x seconds, min, max)
function Stats.scaledReward(profile: Profile, seconds: number, min: number, max: number): number
	local inc = Stats.income(profile, workspace:GetServerTimeNow())
	return math.floor(math.clamp(inc.totalNormal * seconds, min, max))
end

function Stats.discoveredCount(profile: Profile): number
	local n = 0
	for _ in profile.data.atlas.species do
		n += 1
	end
	return n
end

function Stats.storageUsed(profile: Profile): number
	return Profiles.countCreatures(profile)
end

function Stats.storageFull(profile: Profile, computed: Computed?): boolean
	local c = computed or Stats.compute(profile)
	return Stats.storageUsed(profile) >= c.storageMax
end

-- Highest claimed milestone title, if any.
function Stats.title(profile: Profile): string?
	local best: string? = nil
	local bestCount = 0
	for countStr in profile.data.atlas.claimed do
		local count = tonumber(countStr)
		local m = if count then Config.Milestones.byCount[count] else nil
		if m and count and count > bestCount then
			bestCount = count
			best = m.title
		end
	end
	return best
end

-- Two regions unlocked whose elements form a recipe (daily quest gating).
function Stats.canBuildAnyCircuit(profile: Profile): boolean
	local elements = {}
	for regionId in profile.data.regions do
		local r = Config.Regions.byId[regionId]
		if r then
			table.insert(elements, r.element)
		end
	end
	for i = 1, #elements do
		for j = i + 1, #elements do
			if Config.Circuits.recipe(elements[i], elements[j]) then
				return true
			end
		end
	end
	return false
end

return Stats
