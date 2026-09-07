--!strict
-- Coins are the only spendable currency. Every price, cap and rate lives here.

export type UpgradeDef = {
	id: string,
	name: string,
	desc: string, -- per-level effect, shown in the Workshop
	icon: string,
	maxLevel: number, -- habitat_capacity is additionally clamped to the deploy cap at runtime
	baseCost: number,
	costMult: number,
	perLevel: number, -- effect per level (see Stats for how each id is applied)
	cap: number?, -- absolute cap for the derived stat, where the spec asks for one
}

local Economy = {}

Economy.startingCoins = 150
-- Seconds a player stands on their Collection Pad before the bank moves to the
-- wallet. 0 = the moment you step on (it pays on the next server tick). Read by
-- CollectionPadService and CollectionPadUI so the server and the indicator agree.
Economy.collectHoldSeconds = 0
Economy.maxCoins = 1e15

Economy.income = {
	tickInterval = 1, -- seconds between bank accruals (fractional amounts kept)
	stateSyncInterval = 0.25,
	bankCapSeconds = 3600, -- online bank holds one hour of current normal production
	bankCapPerLevel = 1800, -- bank_capacity upgrade adds this many seconds per level
}

Economy.offline = {
	efficiency = 0.25,
	capSeconds = 4 * 3600,
	minAwaySeconds = 60, -- shorter absences award nothing (avoids rejoin farming)
}

Economy.storage = {
	base = 60,
	max = 120,
}

Economy.deploy = {
	startingPads = 6, -- + 1 per relaunch level (Config.Relaunch)
	hardCap = 24,
}

-- Sell value = Rarities.info[rarity].sellSeconds x the creature's normal income.
Economy.sellMin = 5

-- seconds between remote collections (Remote Collector upgrade)
Economy.remoteCollectCooldown = 60

Economy.upgrades = {
	{ id = "tether_speed", name = "Tether Speed", desc = "+10% capture speed per level", icon = "⏩", maxLevel = 8, baseCost = 120, costMult = 1.8, perLevel = 0.10 },
	{ id = "tether_range", name = "Tether Range", desc = "+2 studs tether range per level (max 30)", icon = "📡", maxLevel = 6, baseCost = 200, costMult = 1.9, perLevel = 2, cap = 30 },
	{ id = "move_speed", name = "Running Shoes", desc = "+1.5 walk speed per level (max 36)", icon = "👟", maxLevel = 8, baseCost = 150, costMult = 1.7, perLevel = 1.5, cap = 36 },
	{ id = "habitat_capacity", name = "Extra Work Pad", desc = "+1 work pad per level (city max 24)", icon = "🏗", maxLevel = 18, baseCost = 400, costMult = 1.6, perLevel = 1, cap = 24 },
	{ id = "circuit_efficiency", name = "Circuit Efficiency", desc = "+2% circuit bonus per level", icon = "🔌", maxLevel = 5, baseCost = 2000, costMult = 2.0, perLevel = 0.02 },
	{ id = "bank_capacity", name = "Bigger Bank", desc = "+30 minutes of bank storage per level", icon = "🏦", maxLevel = 6, baseCost = 500, costMult = 2.0, perLevel = 1800 },
	{ id = "storage", name = "Creature Storage", desc = "+10 creature storage per level (max 120)", icon = "📦", maxLevel = 6, baseCost = 800, costMult = 1.7, perLevel = 10, cap = 120 },
	{ id = "decoration", name = "City Decoration", desc = "Next decoration tier: more machinery, pipes and lights", icon = "🎨", maxLevel = 3, baseCost = 1500, costMult = 8, perLevel = 1 },
	-- The HUD Collect button used to bank from anywhere, which made the collection
	-- pad pointless. It is now this upgrade: one level, priced between the
	-- Splashwater and Cinder Canyon unlocks, and on a cooldown so the pad stays
	-- the normal path and remote is the rescue when the bank fills far from home.
	{ id = "remote_collector", name = "Remote Collector", desc = "Collect your bank from anywhere, once a minute", icon = "📡", maxLevel = 1, baseCost = 20000, costMult = 1, perLevel = 1 },
} :: { UpgradeDef }

Economy.upgradeById = {} :: { [string]: UpgradeDef }
for _, u in Economy.upgrades do
	Economy.upgradeById[u.id] = u
end

function Economy.upgradeCost(id: string, currentLevel: number): number
	local u = Economy.upgradeById[id]
	if not u then
		return math.huge
	end
	return math.ceil(u.baseCost * u.costMult ^ currentLevel)
end

return Economy
