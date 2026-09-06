--!strict
-- Containment Crisis: every 8 minutes a 90-second cooperative event in the
-- hub arena. An enlarged roster Legendary is the labelled boss; players hold
-- three containment pylons while dodging its element hazard.

local Events = {}

Events.crisis = {
	interval = 480, -- seconds between event starts (measured start to start)
	warning = 20, -- seconds of "Crisis incoming" banner before it begins
	duration = 90,
	pylons = 3,
	-- Work (hold-seconds) needed per pylon: base + perExtraPlayer x (participants - 1).
	pylonBaseWork = 5,
	pylonWorkPerExtraPlayer = 3,
	holdRate = 1, -- hold-seconds gained per second per player holding
	-- A player qualifies for the reward with at least this much total hold work.
	qualifyWork = 4,
	bossScale = 2.6,
	bossHazardSpeed = 1.3,
	bossAttackInterval = 2.6,
	-- Reward Coins = clamp(cps x rewardSeconds, rewardMin, rewardMax), once per event per player.
	rewardSeconds = 120,
	rewardMin = 300,
	rewardMax = 150000,
	fallbackBoss = "sir_spins_a_lot", -- when no region beyond the first is unlocked by anyone online
}

return Events
