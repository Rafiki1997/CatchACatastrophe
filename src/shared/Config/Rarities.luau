--!strict
-- Creature rarity ladder. `weight` is the normal spawn weight (sums to 100
-- so weight == spawn percentage). `mult` is the income multiplier applied to
-- the regional base income. `captureSeconds` is tether contact needed
-- before upgrades (capped at 16); `hazardSpeed` scales hazard tempo.

export type RarityInfo = {
	rank: number,
	label: string,
	icon: string, -- text glyph so rarity never relies on colour alone
	color: Color3,
	weight: number,
	mult: number,
	captureSeconds: number,
	hazardSpeed: number,
	attackInterval: number, -- seconds between hazard attacks at hazardSpeed 1
	sellSeconds: number, -- sell value = this many seconds of the creature's normal income
	glow: number, -- model effect tier: 0 none, 1 sparkle, 2 aura + light (ModelKit.applyRarityGlow)
	broadcast: boolean,
}

local Rarities = {}

-- Ranks 5-7 are the Cosmic Egg chase tiers. They have `weight = 0`, so they can
-- never appear in a wild spawn (Weighted.pick skips non-positive weights) and
-- only hatch from an egg; a future event may spawn them deliberately. Their
-- capture fields are copied from Legendary and are unused until then; note that
-- Capture.rarityRangeMult / rarityKnockbackMult clamp to their own length, so a
-- rank above 4 inherits Legendary tuning rather than erroring.
Rarities.order = { "Common", "Uncommon", "Rare", "Legendary", "Mythic", "Celestial", "Astral" }

-- Egg-only tiers, in order. `Rarities.isEggTier(r)` is the one place that knows.
Rarities.eggTiers = { "Mythic", "Celestial", "Astral" }

Rarities.info = {
	Common = { rank = 1, label = "Common", icon = "●", color = Color3.fromRGB(180, 186, 196), weight = 60, mult = 1, captureSeconds = 8, hazardSpeed = 1.0, attackInterval = 3.2, sellSeconds = 20, glow = 0, broadcast = false },
	Uncommon = { rank = 2, label = "Uncommon", icon = "◆", color = Color3.fromRGB(96, 210, 120), weight = 28, mult = 2.5, captureSeconds = 10, hazardSpeed = 1.15, attackInterval = 2.8, sellSeconds = 25, glow = 0, broadcast = false },
	Rare = { rank = 3, label = "Rare", icon = "★", color = Color3.fromRGB(90, 150, 255), weight = 10, mult = 7, captureSeconds = 13, hazardSpeed = 1.3, attackInterval = 2.4, sellSeconds = 30, glow = 1, broadcast = false },
	Legendary = { rank = 4, label = "Legendary", icon = "♛", color = Color3.fromRGB(255, 200, 60), weight = 2, mult = 20, captureSeconds = 16, hazardSpeed = 1.5, attackInterval = 2.0, sellSeconds = 40, glow = 2, broadcast = true },
	Mythic = { rank = 5, label = "Mythic", icon = "✦", color = Color3.fromRGB(255, 120, 200), weight = 0, mult = 50, captureSeconds = 16, hazardSpeed = 1.5, attackInterval = 2.0, sellSeconds = 60, glow = 3, broadcast = true },
	Celestial = { rank = 6, label = "Celestial", icon = "✧", color = Color3.fromRGB(120, 235, 255), weight = 0, mult = 150, captureSeconds = 16, hazardSpeed = 1.5, attackInterval = 2.0, sellSeconds = 90, glow = 3, broadcast = true },
	Astral = { rank = 7, label = "Astral", icon = "✵", color = Color3.fromRGB(255, 245, 190), weight = 0, mult = 400, captureSeconds = 16, hazardSpeed = 1.5, attackInterval = 2.0, sellSeconds = 120, glow = 3, broadcast = true },
} :: { [string]: RarityInfo }

-- Egg-only chase tiers never spawn in the wild and never count toward Atlas
-- completion or the Relaunch species requirement.
function Rarities.isEggTier(rarity: string): boolean
	for _, r in Rarities.eggTiers do
		if r == rarity then
			return true
		end
	end
	return false
end

function Rarities.rank(rarity: string): number
	local info = Rarities.info[rarity]
	return if info then info.rank else 0
end

function Rarities.color(rarity: string): Color3
	local info = Rarities.info[rarity]
	return if info then info.color else Color3.new(1, 1, 1)
end

-- "★ Rare": text + glyph, never colour alone.
function Rarities.label(rarity: string): string
	local info = Rarities.info[rarity]
	return if info then info.icon .. " " .. info.label else rarity
end

return Rarities
