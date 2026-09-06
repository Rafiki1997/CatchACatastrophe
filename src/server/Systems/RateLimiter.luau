--!strict
-- Token-bucket rate limiter keyed by player + action. Protects every remote
-- from spam without punishing normal play.

local RateLimiter = {}

type Bucket = { tokens: number, last: number }
local buckets: { [Player]: { [string]: Bucket } } = {}

-- Per-action limits: burst (max tokens) and refill per second.
local LIMITS: { [string]: { burst: number, refill: number } } = {
	default = { burst = 6, refill = 3 },
	CollectAll = { burst = 3, refill = 1 },
	ToggleLock = { burst = 2, refill = 0.5 },
	UseTool = { burst = 4, refill = 2 },
	PlaceOddity = { burst = 6, refill = 3 },
	StoreOddity = { burst = 6, refill = 3 },
	ReleaseOddity = { burst = 3, refill = 1 },
	PlaceEgg = { burst = 4, refill = 2 },
	HatchEgg = { burst = 4, refill = 2 },
	EquipPet = { burst = 6, refill = 3 },
	UnequipPet = { burst = 6, refill = 3 },
	ReleasePet = { burst = 3, refill = 1 },
	BuyCoinUpgrade = { burst = 6, refill = 3 },
	BuyTokenUpgrade = { burst = 4, refill = 2 },
	DoRebirth = { burst = 1, refill = 0.2 },
	SetSetting = { burst = 8, refill = 4 },
	TutorialAdvance = { burst = 4, refill = 1 },
	ClaimIndexReward = { burst = 3, refill = 1 },
	DropCarry = { burst = 2, refill = 1 },
	RequestState = { burst = 2, refill = 0.5 },
	GetState = { burst = 3, refill = 0.5 },
	Prompt = { burst = 8, refill = 4 }, -- ProximityPrompt triggers (buy / snatch / pick up)
}

function RateLimiter.allow(player: Player, action: string): boolean
	local limit = LIMITS[action] or LIMITS.default
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local now = os.clock()
	local bucket = playerBuckets[action]
	if not bucket then
		bucket = { tokens = limit.burst, last = now }
		playerBuckets[action] = bucket
	end
	local elapsed = now - bucket.last
	bucket.last = now
	bucket.tokens = math.min(limit.burst, bucket.tokens + elapsed * limit.refill)
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

function RateLimiter.clear(player: Player)
	buckets[player] = nil
end

return RateLimiter
