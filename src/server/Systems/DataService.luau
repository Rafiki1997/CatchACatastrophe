--!strict
-- Versioned, retrying persistence with single-session ownership.
--
-- Rules that protect a player's collection:
--   * A load that never succeeds marks the profile `dataSafe = false` and the
--     session NEVER saves, so a transient DataStore outage cannot wipe a save.
--   * Every read and write goes through UpdateAsync so the session claim and
--     the payload move atomically.
--   * The claim is `data.sessionId` (unique per server) + `data.sessionAt`
--     (unix). A stored claim from ANOTHER server that is younger than
--     `SESSION_STALE` seconds means the profile is still open elsewhere: we
--     retry, then fall back to a read-only load (`dataSafe = false`).
--   * `releaseSession` clears the claim inside the SAME UpdateAsync that
--     writes the final payload, so the next server can take over immediately.
--   * Autosave every 90 s, a release-save on leave, and BindToClose flushes
--     everyone still online.
--
-- Studio without API access (and any PlaceId == 0 build) transparently swaps
-- in an in-memory adapter keyed `Config.TestNamespace .. userId`. It survives
-- rejoins for as long as the server instance lives and never touches a
-- production key. Test profiles are `testAdapter = true`, `dataSafe = true`.
-- The adapter grants nothing: it only stores what the game already produced.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Profiles = require(script.Parent.Profiles)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile
type Data = Profiles.Data

local DataService = {}

local AUTOSAVE_INTERVAL = 90
local SESSION_STALE = 90 -- a claim older than this is considered abandoned
local LOAD_RETRIES = 3 -- extra attempts against a live claim before read-only
local IO_RETRIES = 4 -- transport retries for one read or write
local BACKOFF_BASE = 1.0
local BACKOFF_MAX = 8.0
local SHUTDOWN_BUDGET = 25

-- One id per server process. JobId is empty in Studio, hence the GUID half.
local SESSION_ID = tostring(game.JobId) .. ":" .. HttpService:GenerateGUID(false)

local store: DataStore? = nil
local storeAvailable = false
local useTestAdapter = false
local resolved = false

-- In-memory adapter: namespaced key -> plain Data table.
local testStore: { [string]: any } = {}

local saving: { [number]: boolean } = {}

local function key(userId: number): string
	return "player_" .. tostring(userId)
end

local function testKey(userId: number): string
	return Config.TestNamespace .. tostring(userId)
end

local function looksLikeStudioBlock(message: string): boolean
	return message:find("StudioAccessToApisNotAllowed") ~= nil
		or message:find("403") ~= nil
		or message:find("not allowed") ~= nil
		or message:find("Studio") ~= nil
end

local function backoff(attempt: number)
	local wait = math.min(BACKOFF_BASE * 2 ^ (attempt - 1), BACKOFF_MAX)
	task.wait(wait + math.random() * 0.25)
end

-- Resolves the backing store exactly once. A first call that fails the way
-- Studio-without-API-access fails switches the whole service to the adapter.
local function resolveStore()
	if resolved then
		return
	end
	resolved = true

	if game.PlaceId == 0 then
		useTestAdapter = true
		warn("[DataService] PlaceId is 0; using the in-memory test adapter.")
		return
	end

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if not ok then
		if RunService:IsStudio() then
			useTestAdapter = true
			warn("[DataService] DataStore unavailable in Studio; using the in-memory test adapter.")
		else
			warn("[DataService] DataStore unavailable:", result)
		end
		return
	end
	store = result :: DataStore

	-- Probe: in Studio without API access the failure surfaces on the first
	-- call, not on GetDataStore.
	local probeOk, probeErr = pcall(function()
		return (store :: DataStore):GetAsync("__probe")
	end)
	if probeOk then
		storeAvailable = true
		return
	end
	local message = tostring(probeErr)
	if RunService:IsStudio() and looksLikeStudioBlock(message) then
		useTestAdapter = true
		store = nil
		warn("[DataService] DataStore API access is off in Studio; using the in-memory test adapter.")
		return
	end
	-- A transport hiccup on the probe is not fatal; treat the store as live
	-- and let per-call retries deal with it.
	storeAvailable = true
	warn("[DataService] DataStore probe failed (continuing):", message)
end

function DataService.isAvailable(): boolean
	return storeAvailable or useTestAdapter
end

function DataService.usingTestAdapter(): boolean
	return useTestAdapter
end

function DataService.sessionId(): string
	return SESSION_ID
end

--=========================================================================--
-- Session-aware read / write primitives
--=========================================================================--

-- Returns (ok, value, contested). `contested` is true when the transform
-- refused because another live server owns the profile.
local function updateOnce(userId: number, transform: (any) -> any?): (boolean, any, boolean)
	local contested = false
	local captured: any = nil
	local wrapped = function(old: any)
		local result = transform(old)
		if result == nil then
			contested = true
			return nil
		end
		captured = result
		return result
	end

	if useTestAdapter then
		local slot = testStore[testKey(userId)]
		local result = wrapped(slot)
		if result ~= nil then
			testStore[testKey(userId)] = result
		end
		return true, captured, contested
	end

	if not storeAvailable or not store then
		return false, nil, false
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(userId), wrapped)
	end)
	if not ok then
		return false, err, false
	end
	return true, captured, contested
end

--=========================================================================--
-- Load
--=========================================================================--

-- Returns (data, dataSafe, usingTest).
-- dataSafe = false means "play, but never write" (the client shows the
-- 'Not saving' pill and the player loses nothing that was already stored).
function DataService.load(player: Player): (Data, boolean, boolean)
	resolveStore()
	local userId = player.UserId

	if not DataService.isAvailable() then
		return Profiles.defaultData(), false, false
	end

	local lastErr: any = nil
	for attempt = 1, LOAD_RETRIES + 1 do
		local now = os.time()
		local claimed: Data? = nil
		local ok, err, contested = updateOnce(userId, function(old)
			local blockedBy: string? = nil
			if typeof(old) == "table" and typeof(old.sessionId) == "string" and old.sessionId ~= SESSION_ID then
				local at = if typeof(old.sessionAt) == "number" then old.sessionAt else 0
				if now - at < SESSION_STALE then
					blockedBy = old.sessionId
				end
			end
			if blockedBy then
				return nil -- abort: someone else owns this profile right now
			end
			local data = Profiles.sanitize(old)
			data.sessionId = SESSION_ID
			data.sessionAt = now
			claimed = data
			return data
		end)

		if ok and not contested and claimed then
			return claimed :: Data, true, useTestAdapter
		end
		if ok and contested then
			if attempt > LOAD_RETRIES then
				break
			end
			backoff(attempt)
		else
			lastErr = err
			if attempt > LOAD_RETRIES then
				break
			end
			backoff(attempt)
		end
		if not player.Parent then
			return Profiles.defaultData(), false, useTestAdapter
		end
	end

	-- Could not claim. Load read-only so the player still sees their city.
	local readOnly: Data = Profiles.defaultData()
	if storeAvailable and store then
		for attempt = 1, IO_RETRIES do
			local ok, result = pcall(function()
				return (store :: DataStore):GetAsync(key(userId))
			end)
			if ok then
				readOnly = Profiles.sanitize(result)
				break
			end
			lastErr = result
			if attempt < IO_RETRIES then
				backoff(attempt)
			end
		end
	elseif useTestAdapter then
		readOnly = Profiles.sanitize(testStore[testKey(userId)])
	end
	readOnly.sessionId = nil
	readOnly.sessionAt = nil
	if lastErr then
		warn("[DataService] read-only load for", player.Name, lastErr)
	else
		warn("[DataService] read-only load for", player.Name, "(profile open on another server)")
	end
	return readOnly, false, useTestAdapter
end

--=========================================================================--
-- Save
--=========================================================================--

-- Shallow-clones every mutable sub-table so a mutation during the UpdateAsync
-- yield cannot half-write the payload.
local function serialize(profile: Profile): Data
	local d = profile.data
	d.version = Config.DataVersion
	d.lastSaved = os.time()
	d.lastOnlineAt = os.time()

	local copy = table.clone(d)
	copy.creatures = {}
	for uid, c in d.creatures do
		copy.creatures[uid] = table.clone(c)
	end
	copy.circuits = table.clone(d.circuits)
	copy.circuitUpgrades = table.clone(d.circuitUpgrades)
	copy.regions = table.clone(d.regions)
	copy.upgrades = table.clone(d.upgrades)
	copy.atlas = {
		species = {},
		recipes = table.clone(d.atlas.recipes),
		claimed = table.clone(d.atlas.claimed),
	}
	for id, e in d.atlas.species do
		copy.atlas.species[id] = {
			firstAt = e.firstAt,
			variants = table.clone(e.variants),
			perfect = e.perfect,
			caught = e.caught,
		}
	end
	copy.mastery = {}
	for id, m in d.mastery do
		copy.mastery[id] = table.clone(m)
	end
	local items = {}
	for i, it in d.quests.daily.items do
		items[i] = table.clone(it)
	end
	copy.quests = {
		tutorialStep = d.quests.tutorialStep,
		repeatable = {},
		daily = { dayKey = d.quests.daily.dayKey, items = items },
	}
	for id, r in d.quests.repeatable do
		copy.quests.repeatable[id] = table.clone(r)
	end
	copy.settings = table.clone(d.settings)
	copy.stats = table.clone(d.stats)
	copy.purchases = {
		ledger = {},
		passes = table.clone(d.purchases.passes),
		coinsBought = d.purchases.coinsBought,
		robuxSpent = d.purchases.robuxSpent,
		boostsBought = d.purchases.boostsBought,
		eggsOpened = d.purchases.eggsOpened,
	}
	for i, row in d.purchases.ledger do
		copy.purchases.ledger[i] = table.clone(row)
	end
	copy.boosts = table.clone(d.boosts)
	copy.cosmetics = { owned = table.clone(d.cosmetics.owned), equipped = table.clone(d.cosmetics.equipped) }
	copy.eggs = { counts = table.clone(d.eggs.counts), pity = {} }
	for id, counters in d.eggs.pity do
		copy.eggs.pity[id] = table.clone(counters)
	end
	return copy
end

-- `release = true` clears the session claim inside the same UpdateAsync as
-- the payload, which is what makes a fast rejoin on another server work.
local function write(profile: Profile, reason: string, release: boolean): boolean
	if not profile.dataSafe or not profile.loaded then
		return false
	end
	if not DataService.isAvailable() then
		return false
	end
	if saving[profile.userId] then
		return false
	end
	saving[profile.userId] = true
	profile.saving = true
	local previousState = profile.dataState
	profile.dataState = "saving"
	profile.dirty = true

	local payload = serialize(profile)
	if release then
		payload.sessionId = nil
		payload.sessionAt = nil
	else
		payload.sessionId = SESSION_ID
		payload.sessionAt = os.time()
	end

	local success = false
	local stolen = false
	local lastErr: any = nil
	for attempt = 1, IO_RETRIES do
		local ok, err, contested = updateOnce(profile.userId, function(old)
			if typeof(old) == "table" and typeof(old.sessionId) == "string" and old.sessionId ~= SESSION_ID then
				local at = if typeof(old.sessionAt) == "number" then old.sessionAt else 0
				if os.time() - at < SESSION_STALE then
					return nil -- another live server owns it; never clobber
				end
			end
			return payload
		end)
		if ok and not contested then
			success = true
			break
		end
		if ok and contested then
			stolen = true
			break
		end
		lastErr = err
		if attempt < IO_RETRIES then
			backoff(attempt)
		end
	end

	saving[profile.userId] = nil
	profile.saving = false
	if stolen then
		-- Somebody else claimed this profile. Stop writing so the owning
		-- server's data wins; the player keeps playing, unsaved.
		profile.dataSafe = false
		profile.dataState = "unavailable"
		warn("[DataService] save aborted (", reason, ") for", profile.player.Name, "- profile claimed by another server")
	elseif success then
		profile.dataState = if previousState == "saving" then "loaded" else previousState
	else
		profile.dataState = if previousState == "saving" then "loaded" else previousState
		warn("[DataService] save failed (", reason, ") for", profile.player.Name, lastErr)
	end
	profile.dirty = true
	return success
end

function DataService.save(profile: Profile, reason: string?): boolean
	return write(profile, reason or "manual", false)
end

-- Final write for this server: payload + cleared claim, in one UpdateAsync.
function DataService.releaseSession(profile: Profile): boolean
	return write(profile, "release", true)
end

--=========================================================================--
-- Lifecycle
--=========================================================================--

function DataService.init()
	resolveStore()

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, profile in Profiles.all() do
				if profile.dataSafe and profile.loaded and not profile.leaving and not profile.saving then
					task.spawn(DataService.save, profile, "autosave")
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, profile in Profiles.all() do
			if profile.dataSafe and profile.loaded then
				pending += 1
				task.spawn(function()
					profile.leaving = true
					DataService.releaseSession(profile)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + SHUTDOWN_BUDGET
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

-- Test helper only: JSON round-trip through sanitize, exactly what a real
-- save/load pair does to the shape. Grants nothing.
function DataService.roundTrip(data: Data): Data
	local encoded = HttpService:JSONEncode(data)
	return Profiles.sanitize(HttpService:JSONDecode(encoded))
end

S.Data = DataService
return DataService
