--!strict
-- The Robux catalogue: Game Passes (permanent perks), Developer Products
-- (consumables), the boost table and the Cosmic Egg.
--
-- `assetId = 0` means "created in the code, not yet on the Creator Dashboard".
-- Nothing with a 0 can be bought or can resolve a receipt: the asset-id indexes
-- below only include live entries, so a stray ProcessReceipt for id 0 finds
-- nothing and is never granted. The Store panel shows those rows as
-- "Coming soon". Paste the dashboard ids in and they go live with no other edit.
--
-- Rules this catalogue follows (owner's calls, 2026-09-07):
--   * Convenience and time only. The one power item is Quick Tether, capped in
--     Stats so upgrade x boost never exceeds 2x capture speed.
--   * Boosts EXTEND, they never stack: buying again adds seconds to the timer
--     and the multiplier stays put.
--   * The egg is the only random item, its odds are on the panel, and it is
--     hidden from players whose account policy restricts paid random items.

local Rarities = require(script.Parent.Rarities)

export type Grant =
	{ kind: "coins", amount: number }
	| { kind: "boost", boostId: string, seconds: number }
	| { kind: "eggs", eggId: string, count: number }

export type Pass = {
	id: string,
	name: string,
	desc: string,
	icon: string,
	robuxHint: number, -- what the dashboard price should be; display only
	assetId: number, -- 0 = coming soon
	includes: { string }?, -- bundle: the pass ids it grants
}

export type Product = {
	id: string,
	name: string,
	desc: string,
	icon: string,
	robuxHint: number,
	assetId: number,
	grant: Grant,
}

export type Boost = {
	id: string,
	name: string,
	stat: string, -- "income" | "tetherSpeed"
	mult: number,
	maxStackSeconds: number, -- most time that can be banked in one timer
}

export type EggOdds = { rarity: string, weight: number }

export type Egg = {
	id: string,
	name: string,
	desc: string,
	odds: { EggOdds },
	pity: { [string]: number }, -- rarity -> hatches that guarantee it
}

local Store = {}

-- ---------------------------------------------------------------- passes
Store.passes = {
	{ id = "remote_collector", name = "Remote Collector", desc = "Collect your bank from anywhere, once a minute. No more running home.", icon = "📡", robuxHint = 79, assetId = 0 },
	{ id = "storage_plus", name = "Extra Storage", desc = "+30 creature storage, forever.", icon = "📦", robuxHint = 99, assetId = 0 },
	{ id = "vip", name = "VIP", desc = "Double bank storage and a gold name tag.", icon = "👑", robuxHint = 149, assetId = 0 },
	{ id = "everything_bundle", name = "Everything Bundle", desc = "All three passes together, cheaper than buying them one at a time.", icon = "🎁", robuxHint = 299, assetId = 0, includes = { "remote_collector", "storage_plus", "vip" } },
} :: { Pass }

Store.passExtras = {
	storage_plus = 30, -- extra creature storage
	vip = 2, -- bank capacity multiplier
}

-- ---------------------------------------------------------------- boosts
Store.boosts = {
	income_2x = { id = "income_2x", name = "Double Income", stat = "income", mult = 2, maxStackSeconds = 14400 },
	tether_fast = { id = "tether_fast", name = "Quick Tether", stat = "tetherSpeed", mult = 1.25, maxStackSeconds = 14400 },
} :: { [string]: Boost }

-- Upgrade x boost may never exceed this much capture speed. Stats enforces it.
Store.tetherSpeedCap = 2.0

-- ---------------------------------------------------------------- eggs
-- Weights are percentages and must sum to 100 (a self-test pins this), so the
-- number on the panel is the number in the table.
--
-- Pity: two independent counters, one per chase tier. Each counts hatches
-- since the player last got that tier OR BETTER; hitting the threshold raises
-- the next hatch to that tier. One shared counter cannot do this job: the
-- Epic guarantee would fire constantly and reset the higher one, so the Mythic
-- tier would never arrive. Natural expectation is 40 / 200 hatches, so 50 / 200
-- gives both tiers a clear safety net.
Store.eggs = {
	cosmic_egg = {
		id = "cosmic_egg",
		name = "Cosmic Egg",
		desc = "Hatches a creature from anywhere in the known universe. Epic and Mythic creatures come from here and nowhere else.",
		odds = {
			{ rarity = "Common", weight = 40 },
			{ rarity = "Uncommon", weight = 30 },
			{ rarity = "Rare", weight = 18 },
			{ rarity = "Legendary", weight = 9 },
			{ rarity = "Epic", weight = 2.5 },
			{ rarity = "Mythic", weight = 0.5 },
		},
		pity = { Epic = 50, Mythic = 200 },
	},
} :: { [string]: Egg }

Store.hatchBatch = 10 -- the biggest single hatch the Hatch buttons offer

-- ---------------------------------------------------------------- products
Store.products = {
	{ id = "coins_s", name = "Pocket of Coins", desc = "2,500 Coins.", icon = "🪙", robuxHint = 49, assetId = 0, grant = { kind = "coins", amount = 2500 } },
	{ id = "coins_m", name = "Bag of Coins", desc = "15,000 Coins.", icon = "💰", robuxHint = 149, assetId = 0, grant = { kind = "coins", amount = 15000 } },
	{ id = "coins_l", name = "Crate of Coins", desc = "75,000 Coins.", icon = "🏦", robuxHint = 399, assetId = 0, grant = { kind = "coins", amount = 75000 } },
	{ id = "coins_xl", name = "Vault of Coins", desc = "300,000 Coins.", icon = "🏛", robuxHint = 999, assetId = 0, grant = { kind = "coins", amount = 300000 } },

	{ id = "boost_income_30m", name = "Double Income (30 min)", desc = "Your city earns twice as much for 30 minutes.", icon = "⚡", robuxHint = 49, assetId = 0, grant = { kind = "boost", boostId = "income_2x", seconds = 1800 } },
	{ id = "boost_income_2h", name = "Double Income (2 hours)", desc = "Your city earns twice as much for 2 hours.", icon = "⚡", robuxHint = 149, assetId = 0, grant = { kind = "boost", boostId = "income_2x", seconds = 7200 } },
	{ id = "boost_tether_30m", name = "Quick Tether (30 min)", desc = "Captures fill 25% faster for 30 minutes. Hazards are unchanged: you still have to dodge.", icon = "⏩", robuxHint = 49, assetId = 0, grant = { kind = "boost", boostId = "tether_fast", seconds = 1800 } },

	{ id = "egg_cosmic_1", name = "Cosmic Egg", desc = "One Cosmic Egg.", icon = "🥚", robuxHint = 49, assetId = 0, grant = { kind = "eggs", eggId = "cosmic_egg", count = 1 } },
	{ id = "egg_cosmic_10", name = "Cosmic Eggs x10", desc = "Ten Cosmic Eggs.", icon = "🥚", robuxHint = 399, assetId = 0, grant = { kind = "eggs", eggId = "cosmic_egg", count = 10 } },
	{ id = "egg_cosmic_50", name = "Cosmic Eggs x50", desc = "Fifty Cosmic Eggs.", icon = "🥚", robuxHint = 1499, assetId = 0, grant = { kind = "eggs", eggId = "cosmic_egg", count = 50 } },
	{ id = "egg_cosmic_100", name = "Cosmic Eggs x100", desc = "A hundred Cosmic Eggs.", icon = "🥚", robuxHint = 2499, assetId = 0, grant = { kind = "eggs", eggId = "cosmic_egg", count = 100 } },
} :: { Product }

Store.ledgerMax = 50 -- receipts remembered per player, oldest dropped

-- ---------------------------------------------------------------- indexes
Store.passById = {} :: { [string]: Pass }
Store.productById = {} :: { [string]: Product }
-- Live only: a 0 assetId must never resolve a receipt.
Store.passByAssetId = {} :: { [number]: Pass }
Store.productByAssetId = {} :: { [number]: Product }

for _, p in Store.passes do
	Store.passById[p.id] = p
	if p.assetId > 0 then
		Store.passByAssetId[p.assetId] = p
	end
end
for _, p in Store.products do
	Store.productById[p.id] = p
	if p.assetId > 0 then
		Store.productByAssetId[p.assetId] = p
	end
end

function Store.isLive(entry: { assetId: number }?): boolean
	return entry ~= nil and entry.assetId > 0
end

-- The odds as whole percentages for the disclosure panel, best tier first.
function Store.eggOdds(eggId: string): { { rarity: string, percent: number } }
	local egg = Store.eggs[eggId]
	local out = {}
	if not egg then
		return out
	end
	local total = 0
	for _, o in egg.odds do
		total += o.weight
	end
	for _, o in egg.odds do
		table.insert(out, { rarity = o.rarity, percent = if total > 0 then o.weight / total * 100 else 0 })
	end
	table.sort(out, function(a, b)
		return Rarities.rank(a.rarity) > Rarities.rank(b.rarity)
	end)
	return out
end

-- Hatches remaining before each active chase tier is guaranteed, given the
-- player's counters. Drives the guarantee lines in the store panel.
function Store.pityRemaining(eggId: string, counters: { [string]: number }?): { { rarity: string, remaining: number } }
	local egg = Store.eggs[eggId]
	local out = {}
	if not egg then
		return out
	end
	for _, rarity in Rarities.eggTiers do
		local threshold = egg.pity[rarity]
		if threshold then
			local done = if counters then counters[rarity] or 0 else 0
			table.insert(out, { rarity = rarity, remaining = math.max(0, threshold - done) })
		end
	end
	return out
end

return Store
