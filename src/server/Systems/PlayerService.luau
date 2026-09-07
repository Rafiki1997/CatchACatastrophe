--!strict
-- Join and leave. Load the save, build the profile, hand out a city, work out
-- what the city earned while the player was away, and push the first snapshot.
--
-- Every cross-system call here is guarded: a system that failed to load must
-- not stop a player from joining, because a player who cannot join cannot even
-- be told what went wrong.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Profiles = require(script.Parent.Profiles)
local Stats = require(script.Parent.Stats)
local DataService = require(script.Parent.DataService)
local Sync = require(script.Parent.Sync)
local Notify = require(script.Parent.Notify)
local RateLimiter = require(script.Parent.RateLimiter)
local S = require(script.Parent.Services)

type Profile = Profiles.Profile

local PlayerService = {}

local warned: { [string]: boolean } = {}

local function try(systemName: string, fnName: string, ...): any
	local system = (S :: any)[systemName]
	if not system or typeof(system[fnName]) ~= "function" then
		local key = systemName .. "." .. fnName
		if not warned[key] then
			warned[key] = true
			warn("[Player] " .. key .. " is unavailable; continuing without it.")
		end
		return nil
	end
	local ok, result = pcall(system[fnName], ...)
	if not ok then
		warn("[Player] " .. systemName .. "." .. fnName .. " failed: " .. tostring(result))
		return nil
	end
	return result
end

-- Walk speed and respawn point follow the player's upgrades.
function PlayerService.applyCharacter(profile: Profile)
	local computed = Stats.compute(profile)
	local character = profile.player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = computed.walkSpeed
		end
	end
	local plot = profile.plot
	if plot then
		profile.player.RespawnLocation = plot.spawnPoint
	end
end

-- Zoom cap: keeps creatures clickable (Config.CameraMaxZoomDistance). Applied at
-- join AND on every character spawn: Roblox re-copies the StarterPlayer camera
-- defaults when a character loads, which undid a join-only set (read back 400).
local function applyCameraCap(player: Player)
	player.CameraMaxZoomDistance = Config.CameraMaxZoomDistance
end

local function onCharacterAdded(profile: Profile, character: Model)
	applyCameraCap(profile.player)
	-- a fresh character means the old tether is gone
	try("Capture", "onCharacterRemoved", profile)
	task.defer(function()
		if not profile.player.Parent then
			return
		end
		PlayerService.applyCharacter(profile)
		-- the backpack is rebuilt on respawn, so the tether is handed out again
		try("Tools", "give", profile)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Died:Connect(function()
				try("Capture", "onCharacterRemoved", profile)
			end)
		end
		-- put a returning player back in their own city
		local plot = profile.plot
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if plot and hrp and hrp:IsA("BasePart") and not profile.visiting then
			hrp.CFrame = plot.spawnPoint.CFrame + Vector3.new(0, 4, 0)
		end
	end)
end

function PlayerService.onJoin(player: Player)
	applyCameraCap(player)
	local data, dataSafe, usingTest = DataService.load(player)
	if not player.Parent then
		return
	end
	local profile = Profiles.create(player, data, dataSafe, usingTest)

	local plot = try("City", "assign", profile)
	if not plot then
		Notify.player(player, "error", "Every city plot in this server is taken. Please try another server.", 12)
	end

	-- what the city earned while they were away, worked out once, from the save
	try("Economy", "computeOffline", profile)
	try("Quests", "ensureDaily", profile)
	try("City", "refreshAll", profile)
	try("Circuits", "recalculate", profile)
	try("Tools", "give", profile)
	PlayerService.applyCharacter(profile)

	Sync.push(profile)
	try("Quests", "sendTutorial", profile)

	local forecast = try("Encounters", "forecast")
	if forecast then
		Notify.forecast(player, forecast)
	end
	local crisis = try("Crisis", "state")
	if crisis then
		Notify.crisis(player, crisis)
	end

	if player.Character then
		onCharacterAdded(profile, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(profile, character)
	end)

	-- tell them plainly what state their data is in
	if not dataSafe then
		Notify.player(
			player,
			"error",
			"Your save could not be loaded, so nothing will be saved this session. Your real city is safe; play here without worrying about it.",
			14
		)
	elseif usingTest then
		Notify.player(player, "warn", "Studio test data: DataStores are off, so this city lives only until the server stops.", 10)
	else
		local owned = Profiles.countCreatures(profile)
		if owned > 0 then
			Notify.player(player, "success", "Welcome back! Your " .. tostring(owned) .. " creatures are waiting.", 6)
		else
			Notify.player(player, "info", "Welcome to " .. Config.GameName .. "! Follow the arrow to Gusty Gardens and catch something.", 8)
		end
	end
end

function PlayerService.onLeave(player: Player)
	local profile = Profiles.get(player)
	if not profile then
		return
	end
	profile.leaving = true

	try("Capture", "cancel", profile, nil)
	try("Encounters", "releaseAllFor", profile.userId)

	-- last known online time, so the offline award on return is right
	profile.data.lastOnlineAt = os.time()

	if profile.dataSafe then
		profile.saving = true
		DataService.save(profile, "leave")
		DataService.releaseSession(profile)
		profile.saving = false
	end

	try("City", "release", profile)
	RateLimiter.clear(player)
	Profiles.remove(player)
end

function PlayerService.init()
	Players.PlayerAdded:Connect(function(player)
		local ok, err = pcall(PlayerService.onJoin, player)
		if not ok then
			warn("[Player] join failed for " .. player.Name .. ": " .. tostring(err))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local ok, err = pcall(PlayerService.onLeave, player)
		if not ok then
			warn("[Player] leave failed for " .. player.Name .. ": " .. tostring(err))
		end
	end)
	-- anyone who joined while the server was still booting
	for _, player in Players:GetPlayers() do
		if not Profiles.get(player) then
			task.spawn(PlayerService.onJoin, player)
		end
	end

	-- keep lastOnlineAt fresh so a crash still gives a sane offline window
	task.spawn(function()
		while true do
			task.wait(30)
			for _, profile in Profiles.all() do
				if not profile.leaving then
					profile.data.lastOnlineAt = os.time()
				end
			end
		end
	end)
end

S.Player = PlayerService
return PlayerService
