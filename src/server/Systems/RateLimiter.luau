--!strict
-- Token-bucket rate limiter keyed by player + action. Protects every remote
-- from spam without punishing normal play: `burst` is how many requests can
-- arrive back to back, `refill` how many tokens return per second.
--
-- Actions that spend money or change the world get tight buckets; harmless
-- reads and UI toggles get loose ones. A request over the limit is dropped
-- silently, because the honest cases (a held button, a double tap) do not need
-- an error and the dishonest ones do not deserve a reply.

local RateLimiter = {}

type Bucket = { tokens: number, last: number }
local buckets: { [Player]: { [string]: Bucket } } = {}

local LIMITS: { [string]: { burst: number, refill: number } } = {
	default = { burst = 6, refill = 3 },

	-- capture
	StartCapture = { burst = 4, refill = 2 },
	CancelCapture = { burst = 4, refill = 2 },

	-- creatures
	DeployCreature = { burst = 6, refill = 3 },
	StoreCreature = { burst = 6, refill = 3 },
	MoveCreature = { burst = 6, refill = 3 },
	SellCreature = { burst = 3, refill = 1 },
	SetFavorite = { burst = 8, refill = 4 },
	PrismaticUpgrade = { burst = 2, refill = 0.5 },

	-- circuits
	ConnectCircuit = { burst = 6, refill = 3 },
	DisconnectCircuit = { burst = 6, refill = 3 },
	UpgradeCircuit = { burst = 3, refill = 1 },
	StartOverdrive = { burst = 3, refill = 1 },

	-- money
	CollectBank = { burst = 3, refill = 1 },
	ClaimOffline = { burst = 2, refill = 0.5 },

	-- store. A purchase prompt is a window the player must dismiss, so it is
	-- deliberately tight; hatching is a button they may hold down.
	PromptPurchase = { burst = 2, refill = 0.5 },
	HatchEgg = { burst = 6, refill = 2 },
	TestGrant = { burst = 4, refill = 1 },
	EquipCosmetic = { burst = 6, refill = 3 },

	-- workshop
	BuyUpgrade = { burst = 6, refill = 3 },
	UnlockRegion = { burst = 3, refill = 1 },

	-- progression
	DoRelaunch = { burst = 1, refill = 0.2 },
	ClaimMilestone = { burst = 3, refill = 1 },
	ClaimQuest = { burst = 3, refill = 1 },
	ClaimDaily = { burst = 3, refill = 1 },
	TutorialAdvance = { burst = 4, refill = 1 },

	-- world and UI
	VisitCity = { burst = 2, refill = 0.5 },
	SetSetting = { burst = 8, refill = 4 },
	RequestState = { burst = 2, refill = 0.5 },
	GetState = { burst = 3, refill = 0.5 },
	GetCityInfo = { burst = 3, refill = 1 },
	Prompt = { burst = 8, refill = 4 },
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

-- Studio self tests read this to check every remote has a deliberate bucket.
function RateLimiter.limits(): { [string]: { burst: number, refill: number } }
	return LIMITS
end

return RateLimiter
