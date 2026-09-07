--!strict
-- Builds Types.Snapshot for a profile and pushes it to the owning client when
-- dirty. Nothing else sends the State remote.
--
-- The snapshot is the client's entire view of its own progress. Everything in
-- it comes from Stats (one formula, one place) so what the HUD shows and what
-- the economy pays can never disagree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local Profiles = require(script.Parent.Profiles)
local Stats = require(script.Parent.Stats)
local BuildInfo = require(ReplicatedStorage.Shared.Util.BuildInfo)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile
type Snapshot = Types.Snapshot

local Sync = {}

local R = Remotes.get()
local PUSH_INTERVAL = Config.Economy.income.stateSyncInterval

local function call(systemName: string, fnName: string, ...): any
	local system = (S :: any)[systemName]
	if system and typeof(system[fnName]) == "function" then
		local ok, result = pcall(system[fnName], ...)
		if ok then
			return result
		end
		warn("[Sync] " .. systemName .. "." .. fnName .. " failed: " .. tostring(result))
	end
	return nil
end

-- Fallback quest block for the window before QuestService is loaded.
local function questsFrom(profile: Profile)
	local resolved = call("Quests", "snapshotQuests", profile)
	if resolved then
		return resolved
	end
	local d = profile.data
	local repeatable = {}
	for _, q in Config.Quests.repeatable do
		local saved = d.quests.repeatable[q.id]
		repeatable[q.id] = {
			progress = if saved then saved.progress else 0,
			target = q.target,
			cycle = if saved then saved.cycle else 0,
			reward = q.rewardMin,
		}
	end
	return {
		tutorialStep = d.quests.tutorialStep,
		tutorialDone = d.quests.tutorialStep >= Config.Quests.tutorialDoneStep,
		repeatable = repeatable,
		daily = { dayKey = d.quests.daily.dayKey, resetsAt = workspace:GetServerTimeNow(), items = {} },
	}
end

function Sync.build(profile: Profile): Snapshot
	local d = profile.data
	local now = workspace:GetServerTimeNow()
	local computed = Stats.compute(profile)
	local income = Stats.income(profile, now, computed)
	local placeVersion = game.PlaceVersion
	local build = BuildInfo.get()

	-- Boost expiry is stored as unix time but the snapshot speaks server time,
	-- so it is converted here rather than in the client's head.
	local unixNow = os.time()
	local storeBoosts: { [string]: { expiresAt: number, mult: number } } = {}
	for id, expiresAt in d.boosts do
		local boost = Config.Store.boosts[id]
		if boost and expiresAt > unixNow then
			storeBoosts[id] = { expiresAt = now + (expiresAt - unixNow), mult = boost.mult }
		end
	end
	local storePity: { [string]: { [string]: number } } = {}
	for eggId, counters in d.eggs.pity do
		storePity[eggId] = table.clone(counters)
	end
	local storeState = {
		passes = table.clone(profile.passes),
		cosmetics = table.clone(d.purchases.cosmetics),
		eggAllowed = profile.eggAllowed,
		boosts = storeBoosts,
		eggs = { counts = table.clone(d.eggs.counts), pity = storePity },
		stats = {
			coinsBought = d.purchases.coinsBought,
			robuxSpent = d.purchases.robuxSpent,
			boostsBought = d.purchases.boostsBought,
			eggsOpened = d.purchases.eggsOpened,
		},
	}

	-- creatures
	local creatures: { [string]: Types.CreatureEntry } = {}
	for uid, c in d.creatures do
		local key = if c.pad then income.padToKey[c.pad] else nil
		creatures[uid] = {
			id = c.id,
			variant = c.variant,
			pad = c.pad,
			favorite = c.favorite,
			anchored = c.anchored,
			cps = income.perCreature[uid] or 0,
			normalCps = Stats.normalCps(profile, c, computed),
			potentialCps = Stats.potentialCps(profile, c, computed),
			circuitId = if key then income.pairs[key].circuitId else nil,
			caughtAt = c.caughtAt,
			perfect = c.perfect,
		}
	end

	-- circuits
	local circuits: { [string]: Types.CircuitEntry } = {}
	for key, pair in income.pairs do
		local od = profile.overdrives[key]
		circuits[key] = {
			padA = pair.padA,
			padB = pair.padB,
			circuitId = pair.circuitId,
			upgraded = pair.upgraded,
			bonus = pair.bonus,
			overdrive = {
				phase = if od then od.phase else "idle",
				until_ = if od then od.until_ else 0,
				vented = if od then od.vented else false,
			},
			upgradeCost = if pair.upgraded then 0 else Stats.circuitUpgradeCost(profile, pair.padA, pair.padB),
		}
	end

	local bankCap = income.totalNormal * computed.bankCapSeconds

	local offline: { amount: number, seconds: number }? = nil
	if d.offlinePending > 0 then
		offline = { amount = d.offlinePending, seconds = d.offlinePendingSeconds }
	end

	local dataState = profile.dataState
	if profile.saving and dataState == "loaded" then
		dataState = "saving"
	end

	return {
		coins = d.coins,
		lifetimeCoins = d.lifetimeCoins,
		bank = d.bank,
		bankCap = bankCap,
		bankFull = bankCap > 0 and d.bank >= bankCap - 0.5,
		cps = income.total,
		normalCps = income.totalNormal,
		relaunch = d.relaunch,
		relaunchMult = computed.relaunchMult,
		plotIndex = profile.plotIndex,
		title = Stats.title(profile),

		creatures = creatures,
		storage = { used = Stats.storageUsed(profile), max = computed.storageMax },
		pads = { total = computed.padsTotal, used = Stats.deployedCount(profile), hardCap = Config.Economy.deploy.hardCap },
		circuits = circuits,
		circuitUpgrades = d.circuitUpgrades,
		regions = d.regions,
		upgrades = d.upgrades,
		remoteCollectReadyAt = profile.remoteCollectReadyAt,
		store = storeState,
		derived = {
			tetherRange = computed.tetherRange,
			tetherSpeedMult = computed.tetherSpeedMult,
			walkSpeed = computed.walkSpeed,
			circuitBonusExtra = computed.circuitBonusExtra,
			bankCapSeconds = computed.bankCapSeconds,
			anchorSlots = computed.anchorSlots,
		},

		atlas = {
			species = d.atlas.species,
			recipes = d.atlas.recipes,
			claimed = d.atlas.claimed,
			discovered = Stats.discoveredCount(profile),
		},
		mastery = d.mastery,
		quests = questsFrom(profile),
		offline = offline,
		settings = d.settings,
		build = {
			placeVersion = placeVersion,
			environment = if RunService:IsStudio() then "Studio" else "Live",
			hash = build.hash,
			dirty = build.dirty,
			commitTime = build.commitTime,
			stampedAt = build.stampedAt,
		},
		stats = {
			captures = d.stats.captures,
			perfect = d.stats.perfect,
			relaunches = d.stats.relaunches,
			connects = d.stats.connects,
			overdrives = d.stats.overdrives,
			collects = d.stats.collects,
			crisisWins = d.stats.crisisWins,
		},

		capturing = call("Capture", "isCapturing", profile) == true,
		visiting = profile.visiting,
		dataState = dataState,
		dataSafe = profile.dataSafe,
		testAdapter = profile.testAdapter,
		serverTime = now,
	}
end

function Sync.push(profile: Profile)
	profile.dirty = false
	if profile.player.Parent and profile.loaded then
		local ok, snapshot = pcall(Sync.build, profile)
		if ok then
			R.Event.State:FireClient(profile.player, snapshot)
		else
			warn("[Sync] build failed for " .. profile.player.Name .. ": " .. tostring(snapshot))
		end
	end
end

function Sync.markAllDirty()
	for _, profile in Profiles.all() do
		profile.dirty = true
	end
end

function Sync.init()
	R.Function.GetState.OnServerInvoke = function(player: Player)
		local profile = Profiles.get(player)
		if not profile then
			return nil
		end
		return Sync.build(profile)
	end

	task.spawn(function()
		while true do
			task.wait(PUSH_INTERVAL)
			for _, profile in Profiles.all() do
				if profile.dirty and profile.loaded then
					Sync.push(profile)
				end
			end
		end
	end)
end

S.Sync = Sync
return Sync
