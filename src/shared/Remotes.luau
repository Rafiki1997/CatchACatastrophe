--!strict
-- Single source of truth for every RemoteEvent / RemoteFunction name.
-- Server: `Remotes.init()` creates them under ReplicatedStorage.Remotes.
-- Client: `Remotes.get()` waits for the folder and returns the same table.
--
-- Client -> Server events carry INTENT only. They are type-checked, ownership
-- checked and rate-limited in the server's RemoteRouter; nothing here trusts
-- the client with a price, a payout, a capture completion or a hazard result.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.eventNames = {
	-- ===== Client -> Server =====
	"StartCapture", -- (encounterUid: string)  claim + start tethering the wild creature
	"CancelCapture", -- ()
	"DeployCreature", -- (uid: string, pad: number)  storage -> pad (pad must be free and unlocked)
	"StoreCreature", -- (uid: string)  pad -> storage
	"MoveCreature", -- (uid: string, pad: number)  pad -> other pad (swaps if occupied)
	"SellCreature", -- (uid: string)  client confirmed already; server refuses favorites/anchors
	"SetFavorite", -- (uid: string, favorite: boolean)
	"ConnectCircuit", -- (padA: number, padB: number)
	"DisconnectCircuit", -- (pad: number)  breaks the pair this pad belongs to
	"UpgradeCircuit", -- (padA: number, padB: number)
	"StartOverdrive", -- (padA: number, padB: number)
	"CollectBank", -- ()  also triggered by the collection pad touch
	"ClaimOffline", -- ()  once-only offline award
	"BuyUpgrade", -- (id: string)
	"UnlockRegion", -- (regionId: string)
	"DoRelaunch", -- (anchorUids: { string }, acknowledged: boolean)
	-- `acknowledged` is the player ticking "I understand I will lose my unanchored
	-- favorites". The server refuses without it, so the warning cannot be skipped
	-- by a client that simply does not draw the checkbox.
	"ClaimMilestone", -- (count: number)
	"ClaimQuest", -- (questId: string)  repeatable
	"ClaimDaily", -- (index: number)  1..3
	"PrismaticUpgrade", -- (uid: string)  species-bound transformation of ONE owned instance
	"SetSetting", -- (key: string, value: boolean | number)
	"TutorialAdvance", -- (step: number)  info-only steps
	"VisitCity", -- (plotIndex: number)  0 = return home
	"RequestState", -- ()
	"PromptPurchase", -- (kind: "pass" | "product", id: string)  opens the Roblox purchase window
	"HatchEgg", -- (eggId: string, count: number)  1 or Config.Store.hatchBatch
	"TestGrant", -- (productId: string)  STUDIO ONLY: grants with no Robux, refused elsewhere
	"EquipCosmetic", -- (family: string, id: string)  "" unequips

	-- ===== Server -> Client =====
	"State", -- (snapshot: Types.Snapshot)
	"Notify", -- (kind: "info"|"success"|"warn"|"error"|"event"|"capture", text: string, duration: number?)
	"FloatingText", -- (text: string, worldPos: Vector3, color: Color3?)
	"Broadcast", -- (text: string, color: Color3?)  Legendary spawns, crisis, server-wide
	"Effect", -- (kind: string, worldPos: Vector3, extra: any?)  capture|deploy|collect|circuit|overdrive|relaunch|hit|purchase|pylon
	"CaptureState", -- (state: Types.CaptureState?)  nil = not capturing; ~10x/s while tethering
	"Hazard", -- (hazard: Types.HazardEvent)  telegraph + active window for the client to render
	"Knockback", -- (direction: Vector3, strength: number)  cosmetic push on the local character
	"CaptureResult", -- (result: { speciesId: string, variant: string, perfect: boolean, uid: string })
	"Forecast", -- (forecast: { [regionId]: { nextLegendaryAt: number, surgeUntil: number } })  server time
	"CrisisState", -- (state: Types.CrisisState?)
	"TutorialStep", -- (step: number, done: boolean)
	"Leaderboard", -- (boards: { income: { Types.LeaderRow }, collection: { Types.LeaderRow }, relaunches: { Types.LeaderRow } })
	"HatchResult", -- (results: { { speciesId: string, rarity: string, uid: string } })  what an egg opened into
}

-- Which of the events above the SERVER fires. The rate limiter only guards what
-- a client can send, and its self-test used to keep a second copy of this list,
-- so every new server -> client remote failed the test until someone remembered
-- to update it. One list, here, next to the names it describes.
Remotes.serverToClient = {
	State = true,
	Notify = true,
	FloatingText = true,
	Broadcast = true,
	Effect = true,
	CaptureState = true,
	Hazard = true,
	Knockback = true,
	CaptureResult = true,
	Forecast = true,
	CrisisState = true,
	TutorialStep = true,
	Leaderboard = true,
	HatchResult = true,
}

Remotes.functionNames = {
	"GetState", -- () -> Types.Snapshot
	"GetCityInfo", -- (plotIndex: number) -> Types.CityInfo?  read-only view of another player's city
}

local FOLDER_NAME = "Remotes"

local cache: { Event: { [string]: RemoteEvent }, Function: { [string]: RemoteFunction } }? = nil

function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init is server-only")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	local events = {}
	local functions = {}
	for _, name in Remotes.eventNames do
		local ev = folder:FindFirstChild(name) :: RemoteEvent?
		if not ev then
			ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
		events[name] = ev
	end
	for _, name in Remotes.functionNames do
		local fn = folder:FindFirstChild(name) :: RemoteFunction?
		if not fn then
			fn = Instance.new("RemoteFunction")
			fn.Name = name
			fn.Parent = folder
		end
		functions[name] = fn
	end
	cache = { Event = events, Function = functions }
	return cache
end

function Remotes.get()
	if cache then
		return cache
	end
	if RunService:IsServer() then
		return Remotes.init()
	end
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30)
	assert(folder, "Remotes folder never replicated")
	local events = {}
	local functions = {}
	for _, name in Remotes.eventNames do
		events[name] = folder:WaitForChild(name, 10) :: RemoteEvent
	end
	for _, name in Remotes.functionNames do
		functions[name] = folder:WaitForChild(name, 10) :: RemoteFunction
	end
	cache = { Event = events, Function = functions }
	return cache
end

return Remotes
