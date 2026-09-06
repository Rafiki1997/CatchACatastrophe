--!strict
-- In-memory player profiles: persisted `data` plus runtime state. Every
-- system reads/writes through here. DataService fills `data` on join.
--
-- Persisted schema is versioned (`Config.DataVersion`). `sanitize` accepts any
-- older/foreign table and returns a complete, clamped Data, dropping unknown
-- ids, so a forward-compatible load never crashes and never saves garbage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Profiles = {}

export type CreatureData = {
	id: string, -- species id
	variant: string, -- Normal | Overcharged | Prismatic
	pad: number?, -- 1..24 when deployed
	favorite: boolean,
	anchored: boolean, -- selected to survive relaunch (set during relaunch, cleared after)
	caughtAt: number, -- unix
	perfect: boolean,
}

export type AtlasSpecies = { firstAt: number, variants: { [string]: boolean }, perfect: number, caught: number }
export type Mastery = { circuitSeconds: number, perfect: number, claims: number }
export type DailyItemData = { id: string, regionId: string?, progress: number, claimed: boolean }
export type RepeatableData = { progress: number, cycle: number }

export type Data = {
	version: number,
	coins: number,
	lifetimeCoins: number,
	bank: number, -- fractional Coins waiting on the collection pad
	nextUid: number,
	relaunch: number,
	creatures: { [string]: CreatureData },
	circuits: { [string]: boolean }, -- pairKey -> connected (this run)
	circuitUpgrades: { [string]: boolean }, -- pairKey -> upgraded (this run)
	regions: { [string]: boolean }, -- unlocked region ids (gusty_gardens always true)
	upgrades: { [string]: number }, -- upgrade id -> level (this run)
	atlas: {
		species: { [string]: AtlasSpecies },
		recipes: { [string]: boolean },
		claimed: { [string]: boolean }, -- milestone counts as strings
	},
	mastery: { [string]: Mastery },
	quests: {
		tutorialStep: number,
		repeatable: { [string]: RepeatableData },
		daily: { dayKey: string, items: { DailyItemData } },
	},
	offlinePending: number, -- Coins awaiting the once-only offline claim (0 = none)
	offlinePendingSeconds: number,
	lastOnlineAt: number, -- unix, written on every save while online
	settings: { music: number, sfx: number, reducedMotion: boolean, reducedFlashing: boolean, notifications: boolean },
	stats: { captures: number, perfect: number, relaunches: number, connects: number, overdrives: number, collects: number, crisisWins: number, earned: number },
	lastSaved: number, -- unix
	sessionId: string?, -- owning server session (see DataService)
	sessionAt: number?, -- unix when the session claimed the profile
}

export type OverdriveState = { phase: string, until_: number, vented: boolean } -- server time

export type Profile = {
	player: Player,
	userId: number,
	data: Data,
	loaded: boolean,
	dataSafe: boolean, -- false = load failed, never save
	dataState: string, -- loading | loaded | unavailable | saving
	testAdapter: boolean,
	dirty: boolean,
	plotIndex: number, -- 0 until assigned
	plot: any?, -- PlotTemplate record (CONTRACTS section 6)
	capture: any?, -- CaptureService encounter state while tethering
	visiting: number?, -- plot index being visited
	overdrives: { [string]: OverdriveState }, -- pairKey -> runtime overdrive
	padModels: { [string]: Model }, -- uid -> creature model on its pad
	machineModels: { [string]: Model }, -- pairKey -> circuit machinery model
	crisisWork: number,
	crisisRewarded: boolean,
	joinedAt: number,
	leaving: boolean,
	saving: boolean,
	busy: boolean, -- a purchase / relaunch is mid-flight; blocks relaunch and double spends
	lastCollectAt: number,
}

local profiles: { [Player]: Profile } = {}
local byUserId: { [number]: Profile } = {}

function Profiles.defaultData(): Data
	return {
		version = Config.DataVersion,
		coins = Config.Economy.startingCoins,
		lifetimeCoins = 0,
		bank = 0,
		nextUid = 1,
		relaunch = 0,
		creatures = {},
		circuits = {},
		circuitUpgrades = {},
		regions = { gusty_gardens = true },
		upgrades = {},
		atlas = { species = {}, recipes = {}, claimed = {} },
		mastery = {},
		quests = { tutorialStep = 1, repeatable = {}, daily = { dayKey = "", items = {} } },
		offlinePending = 0,
		offlinePendingSeconds = 0,
		lastOnlineAt = 0,
		settings = { music = 0.6, sfx = 0.8, reducedMotion = false, reducedFlashing = false, notifications = true },
		stats = { captures = 0, perfect = 0, relaunches = 0, connects = 0, overdrives = 0, collects = 0, crisisWins = 0, earned = 0 },
		lastSaved = 0,
		sessionId = nil,
		sessionAt = nil,
	}
end

local function num(v: any, default: number, min: number?, max: number?): number
	if typeof(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return default
	end
	return math.clamp(v, min or 0, max or Config.Economy.maxCoins)
end

local function int(v: any, default: number, min: number?, max: number?): number
	return math.floor(num(v, default, min, max))
end

local function bool(v: any, default: boolean): boolean
	if typeof(v) == "boolean" then
		return v
	end
	return default
end

local function boolMap(raw: any, isValidKey: ((string) -> boolean)?): { [string]: boolean }
	local out = {}
	if typeof(raw) == "table" then
		for k, v in raw do
			if typeof(k) == "string" and v == true and (not isValidKey or isValidKey(k)) then
				out[k] = true
			end
		end
	end
	return out
end

-- Fills missing fields (forward-compatible loads) and clamps insane values.
function Profiles.sanitize(raw: any): Data
	local d = Profiles.defaultData()
	if typeof(raw) ~= "table" then
		return d
	end
	d.coins = num(raw.coins, d.coins)
	d.lifetimeCoins = num(raw.lifetimeCoins, 0)
	d.bank = num(raw.bank, 0)
	d.nextUid = int(raw.nextUid, 1, 1, 1e12)
	d.relaunch = int(raw.relaunch, 0, 0, Config.Relaunch.maxLevel)
	d.offlinePending = num(raw.offlinePending, 0)
	d.offlinePendingSeconds = num(raw.offlinePendingSeconds, 0, 0, Config.Economy.offline.capSeconds)
	d.lastOnlineAt = num(raw.lastOnlineAt, 0, 0, 1e12)
	d.lastSaved = num(raw.lastSaved, 0, 0, 1e12)
	if typeof(raw.sessionId) == "string" then
		d.sessionId = raw.sessionId
		d.sessionAt = num(raw.sessionAt, 0, 0, 1e12)
	end

	-- creatures: drop unknown species / variants; resolve duplicate pads (first wins)
	local usedPads: { [number]: boolean } = {}
	if typeof(raw.creatures) == "table" then
		for uid, c in raw.creatures do
			if typeof(uid) == "string" and typeof(c) == "table" and typeof(c.id) == "string" and Config.Species.byId[c.id] then
				local variant = if typeof(c.variant) == "string" and Config.Variants.isValid(c.variant) then c.variant else "Normal"
				local pad: number? = nil
				if typeof(c.pad) == "number" then
					local p = math.floor(c.pad)
					if p >= 1 and p <= Config.Circuits.maxPads and not usedPads[p] then
						pad = p
						usedPads[p] = true
					end
				end
				d.creatures[uid] = {
					id = c.id,
					variant = variant,
					pad = pad,
					favorite = bool(c.favorite, false),
					anchored = bool(c.anchored, false),
					caughtAt = num(c.caughtAt, 0, 0, 1e12),
					perfect = bool(c.perfect, false),
				}
			end
		end
	end

	local function validPairKey(k: string): boolean
		local a, b = Config.Circuits.parsePairKey(k)
		return a ~= nil and b ~= nil and Config.Circuits.areAdjacent(a :: number, b :: number)
	end
	d.circuits = boolMap(raw.circuits, validPairKey)
	d.circuitUpgrades = boolMap(raw.circuitUpgrades, validPairKey)
	d.regions = boolMap(raw.regions, function(k)
		return Config.Regions.byId[k] ~= nil
	end)
	d.regions.gusty_gardens = true

	if typeof(raw.upgrades) == "table" then
		for id, level in raw.upgrades do
			local def = Config.Economy.upgradeById[id]
			if def and typeof(level) == "number" then
				d.upgrades[id] = int(level, 0, 0, def.maxLevel)
			end
		end
	end

	if typeof(raw.atlas) == "table" then
		if typeof(raw.atlas.species) == "table" then
			for id, e in raw.atlas.species do
				if Config.Species.byId[id] and typeof(e) == "table" then
					d.atlas.species[id] = {
						firstAt = num(e.firstAt, 0, 0, 1e12),
						variants = boolMap(e.variants, Config.Variants.isValid),
						perfect = int(e.perfect, 0, 0, 1e9),
						caught = int(e.caught, 0, 0, 1e9),
					}
				end
			end
		end
		d.atlas.recipes = boolMap(raw.atlas.recipes, function(k)
			return Config.Circuits.byId[k] ~= nil
		end)
		d.atlas.claimed = boolMap(raw.atlas.claimed, function(k)
			return Config.Milestones.byCount[tonumber(k) or -1] ~= nil
		end)
	end

	if typeof(raw.mastery) == "table" then
		for id, m in raw.mastery do
			if Config.Species.byId[id] and typeof(m) == "table" then
				d.mastery[id] = { circuitSeconds = num(m.circuitSeconds, 0, 0, 1e9), perfect = int(m.perfect, 0, 0, 1e9), claims = int(m.claims, 0, 0, 1e9) }
			end
		end
	end

	if typeof(raw.quests) == "table" then
		d.quests.tutorialStep = int(raw.quests.tutorialStep, 1, 1, Config.Quests.tutorialDoneStep)
		if typeof(raw.quests.repeatable) == "table" then
			for id, r in raw.quests.repeatable do
				if Config.Quests.repeatableById[id] and typeof(r) == "table" then
					d.quests.repeatable[id] = { progress = num(r.progress, 0, 0, 1e15), cycle = int(r.cycle, 0, 0, 1e9) }
				end
			end
		end
		if typeof(raw.quests.daily) == "table" then
			local daily = raw.quests.daily
			d.quests.daily.dayKey = if typeof(daily.dayKey) == "string" then daily.dayKey else ""
			if typeof(daily.items) == "table" then
				for i = 1, Config.Quests.dailyCount do
					local it = daily.items[i]
					if typeof(it) == "table" and typeof(it.id) == "string" and Config.Quests.dailyById[it.id] then
						table.insert(d.quests.daily.items, {
							id = it.id,
							regionId = if typeof(it.regionId) == "string" and Config.Regions.byId[it.regionId] then it.regionId else nil,
							progress = num(it.progress, 0, 0, 1e15),
							claimed = bool(it.claimed, false),
						})
					end
				end
			end
		end
	end

	if typeof(raw.settings) == "table" then
		d.settings.music = num(raw.settings.music, d.settings.music, 0, 1)
		d.settings.sfx = num(raw.settings.sfx, d.settings.sfx, 0, 1)
		d.settings.reducedMotion = bool(raw.settings.reducedMotion, false)
		d.settings.reducedFlashing = bool(raw.settings.reducedFlashing, false)
		d.settings.notifications = bool(raw.settings.notifications, true)
	end
	if typeof(raw.stats) == "table" then
		for k, _ in d.stats do
			(d.stats :: any)[k] = num(raw.stats[k], 0, 0, 1e15)
		end
	end
	return d
end

function Profiles.create(player: Player, data: Data, dataSafe: boolean, testAdapter: boolean): Profile
	local profile: Profile = {
		player = player,
		userId = player.UserId,
		data = data,
		loaded = true,
		dataSafe = dataSafe,
		dataState = if dataSafe then "loaded" else "unavailable",
		testAdapter = testAdapter,
		dirty = true,
		plotIndex = 0,
		plot = nil,
		capture = nil,
		visiting = nil,
		overdrives = {},
		padModels = {},
		machineModels = {},
		crisisWork = 0,
		crisisRewarded = false,
		joinedAt = os.time(),
		leaving = false,
		saving = false,
		busy = false,
		lastCollectAt = 0,
	}
	profiles[player] = profile
	byUserId[player.UserId] = profile
	return profile
end

function Profiles.remove(player: Player)
	local p = profiles[player]
	if p then
		byUserId[p.userId] = nil
	end
	profiles[player] = nil
end

function Profiles.get(player: Player): Profile?
	return profiles[player]
end

function Profiles.getByUserId(userId: number): Profile?
	return byUserId[userId]
end

function Profiles.all(): { [Player]: Profile }
	return profiles
end

function Profiles.newUid(profile: Profile): string
	local n = profile.data.nextUid
	profile.data.nextUid = n + 1
	return tostring(profile.userId) .. "_" .. tostring(n)
end

function Profiles.countCreatures(profile: Profile): number
	local n = 0
	for _ in profile.data.creatures do
		n += 1
	end
	return n
end

function Profiles.markDirty(profile: Profile)
	profile.dirty = true
end

return Profiles
