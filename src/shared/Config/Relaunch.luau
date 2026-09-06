--!strict
-- City Relaunch (rebirth). Ten levels.
--   cost(R)            = ceil(100000 * 3^R), R = current relaunch count
--   speciesRequired(R) = min(6 + 2R, 24) permanently discovered species
--   income bonus       = +25% additive per level
--   starting pads      = 6 + R
--   anchor slots       = 1, 2 at level 3, 3 at level 6

local Relaunch = {}

Relaunch.maxLevel = 10
Relaunch.baseCost = 100000
Relaunch.costGrowth = 3
Relaunch.incomeBonusPerLevel = 0.25
Relaunch.basePads = 6
Relaunch.hardCapDeployed = 24
Relaunch.resetCoins = 150

function Relaunch.cost(current: number): number
	return math.ceil(Relaunch.baseCost * Relaunch.costGrowth ^ current)
end

function Relaunch.speciesRequired(current: number): number
	return math.min(6 + 2 * current, 24)
end

function Relaunch.incomeMultiplier(level: number): number
	return 1 + Relaunch.incomeBonusPerLevel * level
end

function Relaunch.startingPads(level: number): number
	return math.min(Relaunch.basePads + level, Relaunch.hardCapDeployed)
end

function Relaunch.anchorSlots(level: number): number
	if level >= 6 then
		return 3
	elseif level >= 3 then
		return 2
	end
	return 1
end

-- Shown verbatim on the confirmation screen.
Relaunch.resets = {
	"Coins (back to 150)",
	"Bank and any unclaimed offline Coins",
	"Workshop upgrades",
	"Region unlocks",
	"Your city layout and connected circuits",
	"Circuit upgrades",
	"Every creature that is not anchored",
}
Relaunch.keeps = {
	"Atlas discoveries and variants seen",
	"Prismatic mastery progress",
	"Collection rewards, decorations and titles",
	"Tutorial completion and daily claim records",
	"Relaunch count and permanent income bonus",
	"Your anchored creatures (stored, ready to deploy)",
}

return Relaunch
