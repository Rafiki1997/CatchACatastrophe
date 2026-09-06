--!strict
-- Server leaderboards for income, collection size and relaunches, plus the
-- company board in the hub. Server-scoped only: these are the eight people in
-- this server, not a global ranking, which keeps them honest and cheap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Types = require(ReplicatedStorage.Shared.Types)

local Profiles = require(script.Parent.Profiles)
local Stats = require(script.Parent.Stats)
local Notify = require(script.Parent.Notify)
local S = require(script.Parent.Services)

local LeaderboardService = {}

local INTERVAL = 15
local MAX_ROWS = 8
local boardLabel: TextLabel? = nil

local function sorted(rows: { Types.LeaderRow }): { Types.LeaderRow }
	table.sort(rows, function(a, b)
		if a.value == b.value then
			return a.name < b.name
		end
		return a.value > b.value
	end)
	while #rows > MAX_ROWS do
		table.remove(rows)
	end
	return rows
end

function LeaderboardService.build()
	local income: { Types.LeaderRow } = {}
	local collection: { Types.LeaderRow } = {}
	local relaunches: { Types.LeaderRow } = {}
	local now = workspace:GetServerTimeNow()

	for _, profile in Profiles.all() do
		if profile.loaded then
			local name = profile.player.DisplayName
			local stats = Stats.income(profile, now)
			table.insert(income, { name = name, userId = profile.userId, value = stats.totalNormal })
			table.insert(collection, { name = name, userId = profile.userId, value = Stats.discoveredCount(profile) })
			table.insert(relaunches, { name = name, userId = profile.userId, value = profile.data.relaunch })
		end
	end

	return { income = sorted(income), collection = sorted(collection), relaunches = sorted(relaunches) }
end

local function writeBoard(boards: any)
	if not boardLabel then
		return
	end
	local lines = { Config.CompanyName, "" , "TOP EARNERS" }
	if #boards.income == 0 then
		table.insert(lines, "  nobody yet")
	end
	for i, row in boards.income do
		table.insert(lines, "  " .. tostring(i) .. ". " .. row.name .. "  " .. Format.abbreviate(row.value) .. "/s")
		if i >= 5 then
			break
		end
	end
	table.insert(lines, "")
	table.insert(lines, "BIGGEST ATLAS")
	for i, row in boards.collection do
		table.insert(lines, "  " .. tostring(i) .. ". " .. row.name .. "  " .. tostring(math.floor(row.value)) .. " / " .. tostring(Config.Species.count))
		if i >= 3 then
			break
		end
	end
	boardLabel.Text = table.concat(lines, "\n")
end

function LeaderboardService.init(refs: any)
	boardLabel = refs and refs.hub and refs.hub.board
	task.spawn(function()
		while true do
			task.wait(INTERVAL)
			local ok, boards = pcall(LeaderboardService.build)
			if ok then
				Notify.leaderboard(boards)
				pcall(writeBoard, boards)
			end
		end
	end)
end

S.Leaderboard = LeaderboardService
return LeaderboardService
