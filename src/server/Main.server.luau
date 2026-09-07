--!strict
-- Server bootstrap.
--
-- Order matters twice: the map must exist before any system that places things
-- in it, and PlayerService must come last so every system is registered before
-- the first player can join. Everything else registers itself in the Services
-- table and reaches its neighbours through that at call time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Systems = script.Parent.Systems
local Map = script.Parent.Map

local startedAt = os.clock()
print("[" .. Config.GameName .. "] booting...")

Remotes.init()

-- ---------------------------------------------------------------- world

local MapBuilder = require(Map.MapBuilder)
local PlotTemplate = require(Map.PlotTemplate)

local okMap, refsOrErr = pcall(MapBuilder.build)
local refs: any = if okMap then refsOrErr else nil
if not okMap or typeof(refs) ~= "table" then
	warn("[Main] MapBuilder.build failed: " .. tostring(refsOrErr))
	-- A world the player can still stand in beats a black void, and it keeps
	-- the rest of the systems testable while the map is being fixed.
	local ground = Instance.new("Part")
	ground.Name = "FallbackGround"
	ground.Size = Vector3.new(900, 4, 900)
	ground.Position = Vector3.new(0, -2, 0)
	ground.Anchored = true
	ground.Color = Color3.fromRGB(126, 168, 104)
	ground.Parent = workspace

	local plots: { [number]: CFrame } = {}
	for i = 1, Config.MaxPlayers do
		local a = math.rad(22.5 + (i - 1) * 45)
		plots[i] = CFrame.lookAt(Vector3.new(math.cos(a) * 140, 0, math.sin(a) * 140), Vector3.new(0, 0, 0))
	end
	refs = { plots = plots, regions = {}, hub = {}, arena = { centre = Vector3.new(0, 0, -105), pylons = {}, bossSpot = ground, screen = nil } }
end

-- ---------------------------------------------------------------- systems

require(Systems.Profiles)
require(Systems.Stats)
local DataService = require(Systems.DataService)
local Sync = require(Systems.Sync)
local Economy = require(Systems.EconomyService)
local City = require(Systems.CityService)
local Circuits = require(Systems.CircuitService)
local Encounters = require(Systems.EncounterService)
local Capture = require(Systems.CaptureService)
local Tools = require(Systems.ToolService)
local Crisis = require(Systems.CrisisService)
require(Systems.WorkshopService)
require(Systems.AtlasService)
require(Systems.VariantService)
local Quests = require(Systems.QuestService)
require(Systems.RelaunchService)
require(Systems.VisitService)
local Leaderboard = require(Systems.LeaderboardService)
local Router = require(Systems.RemoteRouter)
local PlayerService = require(Systems.PlayerService)

DataService.init()
Sync.init()
City.init(refs, PlotTemplate)
Economy.init()
Circuits.init()
Encounters.init(refs)
Capture.init()
Tools.init()
Crisis.init(refs)
Quests.init()
Leaderboard.init(refs)
Router.init()
Router.attachPrompts(refs)
PlayerService.init()

print(("[%s] server ready in %d ms"):format(Config.GameName, math.floor((os.clock() - startedAt) * 1000)))

-- ---------------------------------------------------------------- live tests

-- Studio only. The unit suite runs against mock profiles and cannot reach the
-- code that builds world instances, so once a real player has a real plot the
-- live suite runs too and prints its results to Output. Nothing here exists in
-- a published game.
if RunService:IsStudio() then
	task.spawn(function()
		local Players = game:GetService("Players")
		local Profiles = require(Systems.Profiles)
		local harness = Systems:FindFirstChild("TestHarness")
		if not harness then
			return
		end
		local ok, module = pcall(require, harness)
		if not ok or typeof(module) ~= "table" or typeof(module.runLive) ~= "function" then
			return
		end
		-- wait for someone to join and be given a plot
		local deadline = os.clock() + 45
		while os.clock() < deadline do
			for _, player in Players:GetPlayers() do
				local profile = Profiles.get(player)
				if profile and profile.loaded and profile.plot then
					task.wait(1)
					local ranOk, err = pcall(module.runLive, profile)
					if not ranOk then
						warn("[LiveTest] crashed: " .. tostring(err))
					end
					return
				end
			end
			task.wait(1)
		end
	end)
end

-- ---------------------------------------------------------------- self tests

if RunService:IsStudio() then
	require(Systems.HazardTestHarness).install()
end

if RunService:IsStudio() then
	task.delay(3, function()
		local harness = Systems:FindFirstChild("TestHarness")
		if not harness then
			return
		end
		local ok, module = pcall(require, harness)
		if ok and typeof(module) == "table" and typeof(module.run) == "function" then
			local ranOk, err = pcall(module.run)
			if not ranOk then
				warn("[SelfTest] harness crashed: " .. tostring(err))
			end
		end
	end)
end
