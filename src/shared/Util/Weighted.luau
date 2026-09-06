--!strict
-- Weighted random selection helpers.

local Weighted = {}

local rng = Random.new()

-- Picks a key from { key = weight }. Returns nil when all weights are zero.
function Weighted.pick(weights: { [string]: number }, random: Random?): string?
	local r = random or rng
	local total = 0
	for _, w in weights do
		if w > 0 then
			total += w
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = r:NextNumber() * total
	local acc = 0
	local last: string? = nil
	for key, w in weights do
		if w > 0 then
			acc += w
			last = key
			if roll <= acc then
				return key
			end
		end
	end
	return last
end

-- Picks an index from an array of { weight = n } (or plain numbers).
function Weighted.pickIndex(items: { any }, getWeight: (any) -> number, random: Random?): number?
	local r = random or rng
	local total = 0
	for _, item in items do
		local w = getWeight(item)
		if w > 0 then
			total += w
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = r:NextNumber() * total
	local acc = 0
	for i, item in items do
		local w = getWeight(item)
		if w > 0 then
			acc += w
			if roll <= acc then
				return i
			end
		end
	end
	return #items
end

-- Chance-table (percent) pick: { {pet="x", chance=55}, ... }
function Weighted.pickChance(entries: { { chance: number } }, random: Random?): number?
	return Weighted.pickIndex(entries, function(e)
		return e.chance
	end, random)
end

return Weighted
