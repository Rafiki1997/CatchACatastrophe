--!strict
-- Robux: receipts, Game Passes, boosts and the Cosmic Egg.
--
-- The one rule that matters here is that a player must never pay and get
-- nothing. Roblox retries a receipt until it is told PurchaseGranted, so every
-- doubtful path returns NotProcessedYet and the receipt comes back later:
-- next tick, next join, or on another server. That makes double-granting the
-- real danger instead, so every granted receipt is written into a per-player
-- ledger (`data.purchases.ledger`) and a PurchaseId already in the ledger is
-- acknowledged without granting anything a second time.
--
-- Order inside a grant is therefore: apply -> record -> SAVE -> acknowledge.
-- If the save fails the grant is undone and the receipt is left unacknowledged,
-- because a granted-but-unsaved purchase disappears on the next join and the
-- player has paid for nothing.

local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local StoreConfig = require(ReplicatedStorage.Shared.Config.Store)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Weighted = require(ReplicatedStorage.Shared.Util.Weighted)

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Notify)
local Profiles = require(script.Parent.Profiles)
local S = require(script.Parent.Services)
local Stats = require(script.Parent.Stats)
local Sync = require(script.Parent.Sync)

type Profile = Profiles.Profile
type Product = StoreConfig.Product
type Egg = StoreConfig.Egg

local PurchaseService = {}

local Store = Config.Store
local Rarities = Config.Rarities
local Species = Config.Species

local R = Remotes.get()
local rng = Random.new()
local started = false
-- One warning per player per session when their save is offline, so a retrying
-- receipt cannot spam them.
local warnedOffline: { [number]: boolean } = {}

local function safeCall(systemName: string, fnName: string, ...)
	local system = (S :: any)[systemName]
	if system and typeof(system[fnName]) == "function" then
		local ok, err = pcall(system[fnName], ...)
		if not ok then
			warn("[Purchase] " .. systemName .. "." .. fnName .. ": " .. tostring(err))
		end
	end
end

-- ---------------------------------------------------------------- boosts

-- Seconds left on a boost, 0 when it is not running.
function PurchaseService.boostSecondsLeft(profile: Profile, boostId: string, now: number?): number
	local expiresAt = profile.data.boosts[boostId]
	if not expiresAt then
		return 0
	end
	return math.max(0, expiresAt - (now or os.time()))
end

-- A boost never stacks: buying again adds time and the multiplier stays put.
-- Time banked is capped so a player cannot buy a week of Double Income at once.
local function extendBoost(profile: Profile, boostId: string, seconds: number): number?
	local boost = Store.boosts[boostId]
	if not boost then
		return nil
	end
	local now = os.time()
	local current = math.max(profile.data.boosts[boostId] or now, now)
	local expiresAt = math.min(current + seconds, now + boost.maxStackSeconds)
	profile.data.boosts[boostId] = expiresAt
	return expiresAt
end

-- Drops finished boosts and tells the player once. Called from the income tick.
function PurchaseService.pruneBoosts(profile: Profile)
	local now = os.time()
	for id, expiresAt in profile.data.boosts do
		if expiresAt <= now then
			profile.data.boosts[id] = nil
			profile.dirty = true
			local boost = Store.boosts[id]
			if boost and profile.player.Parent then
				Notify.player(profile.player, "info", boost.name .. " has ended.", 4)
			end
		end
	end
end

-- ---------------------------------------------------------------- passes

function PurchaseService.ownsPass(profile: Profile, passId: string): boolean
	return profile.passes[passId] == true
end

-- Bundles own everything they include.
local function setPassOwned(profile: Profile, passId: string)
	local pass = Store.passById[passId]
	if not pass then
		return
	end
	profile.passes[passId] = true
	profile.data.purchases.passes[passId] = true
	for _, includedId in pass.includes or {} do
		profile.passes[includedId] = true
	end
end

-- Perks that live in save data have to be re-applied, not granted once: a
-- relaunch wipes `data.upgrades`, so the Remote Collector pass would silently
-- disappear without this running again afterwards.
function PurchaseService.applyPassPerks(profile: Profile)
	if PurchaseService.ownsPass(profile, "remote_collector") then
		local level = profile.data.upgrades.remote_collector or 0
		if level < 1 then
			profile.data.upgrades.remote_collector = 1
			profile.dirty = true
		end
	end
	safeCall("City", "applyUpgrades", profile)
end

-- Asks Roblox what the player owns. On an API failure the last verified answer
-- from their save is kept, so an outage never takes a paid perk away.
function PurchaseService.refreshPasses(profile: Profile)
	for id, owned in profile.data.purchases.passes do
		if owned and Store.passById[id] then
			setPassOwned(profile, id)
		end
	end
	for _, pass in Store.passes do
		if Store.isLive(pass) then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(profile.userId, pass.assetId)
			end)
			if ok then
				if owns then
					setPassOwned(profile, pass.id)
				else
					profile.passes[pass.id] = nil
					profile.data.purchases.passes[pass.id] = nil
				end
			else
				warn("[Purchase] pass check failed for " .. pass.id .. ": " .. tostring(owns))
			end
		end
	end
	PurchaseService.applyPassPerks(profile)
end

-- ---------------------------------------------------------------- eggs

-- The rarity of one hatch. Pity first: each chase tier counts hatches since the
-- player last got that tier or better, and reaching a threshold forces the
-- result up. Three counters, not one, so the Mythic guarantee cannot keep
-- resetting the Celestial and Astral ones and hide them forever.
local function rollRarity(profile: Profile, egg: Egg): string
	local counters = profile.data.eggs.pity[egg.id]
	local forced: string? = nil
	if counters then
		for _, tier in Rarities.eggTiers do
			local threshold = egg.pity[tier]
			if threshold and (counters[tier] or 0) + 1 >= threshold then
				forced = tier -- eggTiers ascends, so the last match is the best one
			end
		end
	end
	if forced then
		return forced
	end
	local index = Weighted.pickIndex(egg.odds, function(entry)
		return entry.weight
	end, rng)
	return if index then egg.odds[index].rarity else "Common"
end

local function bumpPity(profile: Profile, egg: Egg, rarity: string)
	local counters = profile.data.eggs.pity[egg.id] or {}
	local rank = Rarities.rank(rarity)
	for _, tier in Rarities.eggTiers do
		if Rarities.rank(tier) <= rank then
			counters[tier] = 0
		else
			counters[tier] = (counters[tier] or 0) + 1
		end
	end
	profile.data.eggs.pity[egg.id] = counters
end

-- Which creature of that rarity. Chase tiers have their own roster; the ordinary
-- tiers draw from the regions the player has opened plus the one they are saving
-- for, so an egg is never a creature they cannot use or place.
local function pickSpecies(profile: Profile, rarity: string): string?
	if Rarities.isEggTier(rarity) then
		local pool = Species.eggSpecies(rarity)
		if #pool == 0 then
			return nil
		end
		return pool[rng:NextInteger(1, #pool)].id
	end
	local pool: { string } = {}
	local nextLocked: string? = nil
	for _, region in Config.Regions.list do
		if profile.data.regions[region.id] then
			local def = Species.find(region.id, rarity)
			if def then
				table.insert(pool, def.id)
			end
		elseif not nextLocked then
			nextLocked = region.id
		end
	end
	if nextLocked then
		local def = Species.find(nextLocked, rarity)
		if def then
			table.insert(pool, def.id)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[rng:NextInteger(1, #pool)]
end

export type HatchResult = { speciesId: string, rarity: string, uid: string }

-- Hatches `count` eggs the player already owns. Storage is checked up front so a
-- ten-hatch never half-fails, and the eggs are only spent once the creatures are
-- in hand.
function PurchaseService.hatch(profile: Profile, eggId: string, count: number): (boolean, string?, { HatchResult }?)
	local egg = Store.eggs[eggId]
	if not egg then
		return false, "Unknown egg."
	end
	count = math.floor(count)
	if count ~= 1 and count ~= Store.hatchBatch then
		return false, "You can hatch 1 or " .. tostring(Store.hatchBatch) .. " at a time."
	end
	local owned = profile.data.eggs.counts[eggId] or 0
	if owned < count then
		return false, "You do not have " .. tostring(count) .. " " .. egg.name .. (if count == 1 then "" else "s") .. " yet."
	end
	local computed = Stats.compute(profile)
	local room = computed.storageMax - Stats.storageUsed(profile)
	if room < count then
		return false, "Not enough creature storage: you need " .. tostring(count - room) .. " more space."
	end
	if not S.City then
		return false, "That part of the game is still starting up. Try again in a moment."
	end
	local results: { HatchResult } = {}
	for _ = 1, count do
		local rarity = rollRarity(profile, egg)
		local speciesId = pickSpecies(profile, rarity)
		if not speciesId then
			break
		end
		local uid = S.City.grantCreature(profile, speciesId, "Normal", false)
		if not uid then
			break
		end
		bumpPity(profile, egg, rarity)
		profile.data.eggs.counts[eggId] = (profile.data.eggs.counts[eggId] or 0) - 1
		profile.data.purchases.eggsOpened += 1
		table.insert(results, { speciesId = speciesId, rarity = rarity, uid = uid })
	end
	if #results == 0 then
		return false, "The egg would not hatch. Try again in a moment."
	end
	profile.dirty = true
	for _, result in results do
		if Rarities.isEggTier(result.rarity) then
			local def = Species.byId[result.speciesId]
			Notify.broadcast((profile.player.DisplayName or profile.player.Name) .. " hatched " .. Rarities.label(result.rarity) .. " " .. (if def then def.name else result.speciesId) .. "!", Rarities.color(result.rarity))
		end
	end
	Sync.push(profile)
	return true, nil, results
end

-- ---------------------------------------------------------------- grants

-- Applies one product and returns a function that puts everything back, so a
-- failed save can be rolled back cleanly.
local function applyGrant(profile: Profile, product: Product): (boolean, () -> ())
	local grant = product.grant
	if grant.kind == "coins" then
		local before = profile.data.coins
		if not S.Economy then
			return false, function() end
		end
		S.Economy.addCoins(profile, grant.amount, "robux")
		profile.data.purchases.coinsBought += grant.amount
		return true, function()
			profile.data.coins = before
			profile.data.purchases.coinsBought -= grant.amount
		end
	elseif grant.kind == "boost" then
		local before = profile.data.boosts[grant.boostId]
		if not extendBoost(profile, grant.boostId, grant.seconds) then
			return false, function() end
		end
		profile.data.purchases.boostsBought += 1
		return true, function()
			profile.data.boosts[grant.boostId] = before
			profile.data.purchases.boostsBought -= 1
		end
	elseif grant.kind == "eggs" then
		local before = profile.data.eggs.counts[grant.eggId] or 0
		profile.data.eggs.counts[grant.eggId] = before + grant.count
		return true, function()
			profile.data.eggs.counts[grant.eggId] = before
		end
	end
	return false, function() end
end

local function grantedText(product: Product): string
	local grant = product.grant
	if grant.kind == "coins" then
		return Format.abbreviate(grant.amount) .. " Coins added!"
	elseif grant.kind == "boost" then
		local boost = Store.boosts[grant.boostId]
		return (if boost then boost.name else "Boost") .. " is running!"
	elseif grant.kind == "eggs" then
		return tostring(grant.count) .. " " .. product.name .. " added. Open the Store to hatch."
	end
	return product.name .. " added!"
end

local function ledgerHas(profile: Profile, purchaseId: string): boolean
	for _, row in profile.data.purchases.ledger do
		if row.id == purchaseId then
			return true
		end
	end
	return false
end

-- Grant, record, save, then acknowledge. `save` is injectable so the self-tests
-- can prove the rollback path without touching a DataStore.
--
-- The duplicate check lives here as well as in processReceipt on purpose: the
-- promise "one receipt grants once" belongs to whatever writes the ledger, so
-- it holds for every caller (a retry, a test grant, anything added later)
-- rather than only for the path that remembers to look first.
function PurchaseService.settle(profile: Profile, product: Product, receipt: any, save: ((Profile, string) -> boolean)?): Enum.ProductPurchaseDecision
	local purchaseId = tostring(receipt.PurchaseId)
	if ledgerHas(profile, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	profile.busy = true
	local ok, undo = applyGrant(profile, product)
	if not ok then
		profile.busy = false
		warn("[Purchase] could not apply " .. product.id .. " for " .. profile.player.Name)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local row = { id = purchaseId, productId = receipt.ProductId or 0, at = os.time() }
	table.insert(profile.data.purchases.ledger, row)
	while #profile.data.purchases.ledger > Store.ledgerMax do
		table.remove(profile.data.purchases.ledger, 1)
	end
	profile.data.purchases.robuxSpent += receipt.CurrencySpent or 0
	profile.dirty = true

	local saved = (save or DataService.save)(profile, "purchase:" .. product.id)
	profile.busy = false
	if not saved then
		undo()
		for i = #profile.data.purchases.ledger, 1, -1 do
			if profile.data.purchases.ledger[i] == row then
				table.remove(profile.data.purchases.ledger, i)
				break
			end
		end
		profile.data.purchases.robuxSpent -= receipt.CurrencySpent or 0
		warn("[Purchase] save failed, rolled back " .. product.id .. " for " .. profile.player.Name)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if profile.player.Parent then
		Notify.player(profile.player, "success", grantedText(product), 6)
		local plot = profile.plot
		if plot and plot.collectPad then
			Notify.effectFor(profile.player, "purchase", plot.collectPad.Position)
		end
	end
	Sync.push(profile)
	print("[Purchase] granted " .. product.id .. " to " .. profile.player.Name)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Every uncertain answer is NotProcessedYet: Roblox will offer the receipt
-- again rather than the player losing what they paid for.
function PurchaseService.processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = Profiles.get(player)
	if not profile or not profile.loaded then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not profile.dataSafe then
		if not warnedOffline[profile.userId] then
			warnedOffline[profile.userId] = true
			Notify.player(player, "warn", "Your save is offline right now, so your purchase is waiting. It will arrive as soon as saving works again.", 8)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = Store.productByAssetId[receipt.ProductId]
	if not product then
		warn("[Purchase] no product for asset id " .. tostring(receipt.ProductId) .. " (receipt left unacknowledged)")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if ledgerHas(profile, tostring(receipt.PurchaseId)) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if product.grant.kind == "eggs" and not profile.eggAllowed then
		warn("[Purchase] egg purchase blocked by policy for " .. player.Name)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local waited = 0
	while (profile.busy or profile.saving) and waited < 8 do
		task.wait(0.25)
		waited += 0.25
	end
	if profile.busy or profile.saving then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return PurchaseService.settle(profile, product, receipt)
end

-- ---------------------------------------------------------------- prompts

function PurchaseService.prompt(profile: Profile, kind: string, id: string): (boolean, string?)
	local entry: any = if kind == "pass" then Store.passById[id] else Store.productById[id]
	if not entry then
		return false, "That item is not in the Store."
	end
	if not Store.isLive(entry) then
		return false, entry.name .. " is coming soon!"
	end
	if kind == "pass" then
		if PurchaseService.ownsPass(profile, id) then
			return false, "You already own " .. entry.name .. "."
		end
		MarketplaceService:PromptGamePassPurchase(profile.player, entry.assetId)
	else
		if entry.grant.kind == "eggs" and not profile.eggAllowed then
			return false, "Eggs are not available on your account."
		end
		MarketplaceService:PromptProductPurchase(profile.player, entry.assetId)
	end
	return true, nil
end

-- What the Hatch buttons fire. The results go back on their own remote so the
-- panel can play the reveal; the router only needs to know whether it worked.
function PurchaseService.requestHatch(profile: Profile, eggId: string, count: number): (boolean, string?)
	local ok, reason, results = PurchaseService.hatch(profile, eggId, count)
	if not ok then
		return false, reason
	end
	if profile.player.Parent and results then
		R.Event.HatchResult:FireClient(profile.player, results)
	end
	return true, nil
end

-- The remote behind testGrant. Studio and test profiles only; on a live server
-- this refuses every caller.
function PurchaseService.testGrantRemote(profile: Profile, id: string): (boolean, string?)
	return PurchaseService.testGrant(profile, id)
end

-- Studio only: grants a product with no Robux and no asset id, so the whole
-- pipeline is testable before anything exists on the Creator Dashboard.
function PurchaseService.testGrant(profile: Profile, id: string): (boolean, string?)
	if not RunService:IsStudio() or not profile.testAdapter then
		return false, "Test grants are Studio only."
	end
	local product = Store.productById[id]
	if not product then
		return false, "Unknown product " .. id .. "."
	end
	local receipt = {
		PurchaseId = "studio_" .. tostring(os.clock()) .. "_" .. tostring(rng:NextInteger(1, 1e9)),
		ProductId = product.assetId,
		PlayerId = profile.userId,
		CurrencySpent = 0,
	}
	local decision = PurchaseService.settle(profile, product, receipt)
	if decision == Enum.ProductPurchaseDecision.PurchaseGranted then
		return true, nil
	end
	return false, "The test grant did not go through."
end

-- ---------------------------------------------------------------- lifecycle

function PurchaseService.onJoin(profile: Profile)
	-- Paid random items are restricted for some accounts and regions; a failed
	-- lookup counts as restricted, so the egg is hidden rather than mis-sold.
	local ok, policy = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(profile.player)
	end)
	profile.eggAllowed = ok and policy ~= nil and policy.ArePaidRandomItemsRestricted == false
	if not ok then
		warn("[Purchase] policy lookup failed for " .. profile.player.Name .. ": " .. tostring(policy))
	end
	PurchaseService.refreshPasses(profile)
	Sync.push(profile)
end

function PurchaseService.onLeave(profile: Profile)
	warnedOffline[profile.userId] = nil
end

function PurchaseService.init()
	if started then
		return
	end
	started = true
	MarketplaceService.ProcessReceipt = function(receipt)
		local ok, decision = pcall(PurchaseService.processReceipt, receipt)
		if not ok then
			warn("[Purchase] receipt error: " .. tostring(decision))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return decision
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, assetId, purchased)
		if not purchased then
			return
		end
		local pass = Store.passByAssetId[assetId]
		local profile = Profiles.get(player)
		if not pass or not profile or not profile.loaded then
			return
		end
		setPassOwned(profile, pass.id)
		PurchaseService.applyPassPerks(profile)
		profile.dirty = true
		if profile.dataSafe then
			DataService.save(profile, "gamepass:" .. pass.id)
		end
		Notify.player(player, "success", pass.name .. " is yours!", 6)
		Sync.push(profile)
		print("[Purchase] pass " .. pass.id .. " granted to " .. player.Name)
	end)
end

S.Purchase = PurchaseService

return PurchaseService
