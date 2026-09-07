--!strict
-- Coins: the income tick, the city bank, collection, spending and the
-- once-only offline award.
--
-- One shared loop serves every player. There is no per-creature loop and no
-- per-frame work: production is a closed-form sum over deployed creatures
-- (Stats.income) evaluated once a second.
--
-- Money rules that matter:
--   * The client never supplies an amount. Every function here derives its
--     own number from the profile.
--   * The bank holds fractional Coins and is clamped to one hour of NORMAL
--     production (Overdrive can never inflate the cap).
--   * Collecting pays floor(bank) and leaves the remainder, so repeated
--     collection cannot round fractions into free money.
--   * Offline is computed once at load from the SAVED layout, is capped, and
--     is zeroed before the Coins are added so a double claim pays nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local Profiles = require(script.Parent.Profiles)
local Stats = require(script.Parent.Stats)
local Notify = require(script.Parent.Notify)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile

local EconomyService = {}

local TICK = Config.Economy.income.tickInterval
local LABEL_INTERVAL = 1
local COLLECT_DEBOUNCE = 0.75

local function isFinitePositive(n: any): boolean
	return typeof(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge and n >= 0
end

local function safeCall(systemName: string, fnName: string, ...)
	local system = (S :: any)[systemName]
	if system and typeof(system[fnName]) == "function" then
		local ok, err = pcall(system[fnName], ...)
		if not ok then
			warn("[Economy] " .. systemName .. "." .. fnName .. " failed: " .. tostring(err))
		end
	end
end

-- ---------------------------------------------------------------- wallet

function EconomyService.addCoins(profile: Profile, amount: number, reason: string?): number
	if not isFinitePositive(amount) or amount <= 0 then
		return 0
	end
	local d = profile.data
	local granted = math.min(amount, Config.Economy.maxCoins - d.coins)
	if granted <= 0 then
		return 0
	end
	d.coins += granted
	d.lifetimeCoins += granted
	profile.dirty = true
	local _ = reason
	return granted
end

-- Atomic check-and-deduct. Returns false and changes nothing when short.
function EconomyService.spend(profile: Profile, amount: number): boolean
	if not isFinitePositive(amount) then
		return false
	end
	local d = profile.data
	if d.coins < amount then
		return false
	end
	d.coins -= amount
	profile.dirty = true
	return true
end

function EconomyService.canAfford(profile: Profile, amount: number): boolean
	return isFinitePositive(amount) and profile.data.coins >= amount
end

-- ---------------------------------------------------------------- bank

function EconomyService.collect(profile: Profile, quiet: boolean?): (boolean, string?)
	if profile.visiting then
		return false, "You can only collect in your own city."
	end
	local now = os.clock()
	if now - profile.lastCollectAt < COLLECT_DEBOUNCE then
		return false, nil
	end
	local d = profile.data
	local payout = math.floor(d.bank)
	if payout <= 0 then
		return false, "Nothing to collect yet. Deploy a creature to start earning."
	end
	profile.lastCollectAt = now
	d.bank -= payout
	EconomyService.addCoins(profile, payout, "collect")
	d.stats.collects += 1
	profile.dirty = true

	safeCall("Quests", "bump", profile, "collects", 1)
	safeCall("Quests", "tutorialEvent", profile, "collect")

	local plot = profile.plot
	if plot and not quiet then
		local pos = plot.collectPad.Position + Vector3.new(0, 3, 0)
		Notify.floating(profile.player, "+" .. Format.abbreviate(payout), pos, Color3.fromRGB(255, 208, 72))
		Notify.effectFor(profile.player, "collect", pos)
	end
	safeCall("City", "refreshLabels", profile)
	return true, nil
end

-- Remote Collector upgrade: the gate, without side effects, so the self-test
-- can pin it. `now` is workspace:GetServerTimeNow().
function EconomyService.remoteCollectGate(profile: Profile, now: number): (boolean, string?)
	if (profile.data.upgrades.remote_collector or 0) < 1 then
		return false, "Remote Collector needed: buy it at the Workshop to collect from anywhere."
	end
	local readyAt = profile.remoteCollectReadyAt or 0
	if now < readyAt then
		return false, "Remote Collector is recharging (" .. tostring(math.ceil(readyAt - now)) .. " s)."
	end
	if math.floor(profile.data.bank) <= 0 then
		return false, "Nothing to collect yet."
	end
	return true, nil
end

-- What the HUD Collect button fires. The pad path (collect) checks neither the
-- upgrade nor the cooldown; this one checks both, server-side, so a client
-- without the upgrade cannot replay the old remote.
function EconomyService.collectRemote(profile: Profile): (boolean, string?)
	local now = workspace:GetServerTimeNow()
	local ok, reason = EconomyService.remoteCollectGate(profile, now)
	if not ok then
		return false, reason
	end
	local before = profile.data.coins
	local paid, err = EconomyService.collect(profile, true)
	if not paid then
		return false, err
	end
	profile.remoteCollectReadyAt = now + Config.Economy.remoteCollectCooldown
	profile.dirty = true
	Notify.player(profile.player, "success", Format.abbreviate(profile.data.coins - before) .. " Coins collected remotely!", 3)
	return true, nil
end

-- ---------------------------------------------------------------- offline

-- Called once, at load, before the profile goes live. Fills data.offlinePending.
function EconomyService.computeOffline(profile: Profile)
	local d = profile.data
	if d.offlinePending > 0 then
		-- an award from a previous session was never claimed; leave it alone
		return
	end
	local last = d.lastOnlineAt
	if not isFinitePositive(last) or last <= 0 then
		return
	end
	local elapsed = os.time() - last
	-- a clock that ran backwards, or a session that only just ended, pays nothing
	if elapsed < Config.Economy.offline.minAwaySeconds then
		return
	end
	local seconds = math.min(elapsed, Config.Economy.offline.capSeconds)
	-- production of the layout as it was saved; Overdrive never earns offline
	local income = Stats.income(profile, workspace:GetServerTimeNow())
	local amount = income.totalNormal * seconds * Config.Economy.offline.efficiency
	if amount < 1 then
		return
	end
	d.offlinePending = math.floor(amount)
	d.offlinePendingSeconds = seconds
	profile.dirty = true
end

function EconomyService.claimOffline(profile: Profile): (boolean, string?)
	local d = profile.data
	local amount = d.offlinePending
	if amount <= 0 then
		return false, "Nothing to claim."
	end
	-- zero first: a second request that arrives mid-call finds nothing
	d.offlinePending = 0
	d.offlinePendingSeconds = 0
	EconomyService.addCoins(profile, amount, "offline")
	profile.dirty = true
	Notify.player(profile.player, "success", "Welcome back! Your city earned " .. Format.abbreviate(amount) .. " Coins while you were away.", 7)
	return true, nil
end

-- ---------------------------------------------------------------- tick

local function tickProfile(profile: Profile, dt: number, now: number)
	if not profile.loaded or profile.leaving then
		return
	end
	local d = profile.data
	local computed = Stats.compute(profile)
	local income = Stats.income(profile, now, computed)

	-- bank accrual, clamped to the cap
	if income.total > 0 then
		local cap = income.totalNormal * computed.bankCapSeconds
		local before = d.bank
		d.bank = math.min(d.bank + income.total * dt, cap)
		local earned = d.bank - before
		if earned > 0 then
			d.stats.earned += earned
			safeCall("Quests", "bump", profile, "earned", earned)
		end
	end

	-- Prismatic mastery: cumulative ONLINE seconds each species spends
	-- producing inside an active circuit.
	for uid, entry in d.creatures do
		if entry.pad and income.padToKey[entry.pad] then
			local m = d.mastery[entry.id]
			if not m then
				m = { circuitSeconds = 0, perfect = 0, claims = 0 }
				d.mastery[entry.id] = m
			end
			m.circuitSeconds += dt
		end
		local _ = uid
	end

	profile.dirty = true
end

function EconomyService.init()
	task.spawn(function()
		local last = os.clock()
		local lastLabels = 0
		while true do
			task.wait(TICK)
			local nowClock = os.clock()
			local dt = math.clamp(nowClock - last, 0, 5)
			last = nowClock
			local serverNow = workspace:GetServerTimeNow()
			for _, profile in Profiles.all() do
				local ok, err = pcall(tickProfile, profile, dt, serverNow)
				if not ok then
					warn("[Economy] tick failed for " .. profile.player.Name .. ": " .. tostring(err))
				end
			end
			if nowClock - lastLabels >= LABEL_INTERVAL then
				lastLabels = nowClock
				for _, profile in Profiles.all() do
					safeCall("City", "refreshLabels", profile)
				end
			end
		end
	end)
end

S.Economy = EconomyService
return EconomyService
