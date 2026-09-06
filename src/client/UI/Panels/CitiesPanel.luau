--!strict
-- "Cities": the server leaderboards, and the list of the eight plots with
-- Visit and Inspect. Inspect is a read-only summary fetched from the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Types = require(ReplicatedStorage.Shared.Types)

local W = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)
local Net = require(script.Parent.Parent.Parent.Net)
local State = require(script.Parent.Parent.Parent.State)

type Snapshot = Types.Snapshot

local M = {}

local built = false
local gui: ScreenGui
local panel: any
local activeTab = "Leaderboards"
local boardScroll: ScrollingFrame
local cityScroll: ScrollingFrame
local detailFrame: Frame
local detailText: TextLabel
local boards: any = nil
local boardRows: { [string]: any } = {}
local cityRows: { [number]: any } = {}

local BOARDS = {
	{ key = "income", title = "Top earners", suffix = "/s", abbreviate = true },
	{ key = "collection", title = "Biggest Atlas", suffix = " species", abbreviate = false },
	{ key = "relaunches", title = "Most relaunches", suffix = "", abbreviate = false },
}

local function createBoardSection(spec: any): any
	local card = W.card(boardScroll, 150)
	card.LayoutOrder = 1
	W.label({
		parent = card,
		text = spec.title,
		size = UDim2.new(1, -20, 0, 22),
		position = UDim2.new(0, 10, 0, 6),
		textSize = 15,
		font = Theme.fonts.bold,
		color = Theme.colors.accent,
		xalign = Enum.TextXAlignment.Left,
	})
	local list = W.label({
		parent = card,
		size = UDim2.new(1, -20, 1, -34),
		position = UDim2.new(0, 10, 0, 30),
		textSize = 13,
		color = Theme.colors.text,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
	})
	local record = { frame = card, list = list, spec = spec }
	boardRows[spec.key] = record
	return record
end

local function updateBoards()
	for i, spec in BOARDS do
		local row = boardRows[spec.key] or createBoardSection(spec)
		row.frame.LayoutOrder = i
		local rows = if boards then boards[spec.key] else nil
		if not rows or #rows == 0 then
			row.list.Text = "Nobody yet."
			row.list.TextColor3 = Theme.colors.textDim
		else
			local lines = {}
			for rank, entry in rows do
				local value = if spec.abbreviate then Format.abbreviate(entry.value) else tostring(math.floor(entry.value))
				table.insert(lines, tostring(rank) .. ". " .. entry.name .. "   " .. value .. spec.suffix)
			end
			row.list.Text = table.concat(lines, "\n")
			row.list.TextColor3 = Theme.colors.text
		end
	end
end

local function showDetail(info: any)
	if not info then
		detailFrame.Visible = true
		detailText.Text = "That city is empty."
		return
	end
	local lines = {
		info.ownerName .. "'s city",
		"Relaunch " .. tostring(info.relaunch) .. "   ·   " .. Format.abbreviate(info.cps) .. "/s",
		"",
		"Working creatures:",
	}
	if #info.creatures == 0 then
		table.insert(lines, "  none yet")
	end
	for _, c in info.creatures do
		local def = Config.Species.byId[c.id]
		local variant = if c.variant ~= "Normal" then " (" .. c.variant .. ")" else ""
		table.insert(lines, "  Pad " .. tostring(c.pad) .. ": " .. (if def then def.name else c.id) .. variant .. "  " .. Format.abbreviate(c.cps) .. "/s")
	end
	table.insert(lines, "")
	table.insert(lines, "Circuits:")
	if #info.circuits == 0 then
		table.insert(lines, "  none")
	end
	for _, circuit in info.circuits do
		local def = Config.Circuits.byId[circuit.circuitId]
		table.insert(
			lines,
			"  " .. (if def then def.name else circuit.circuitId) .. " on pads " .. tostring(circuit.padA) .. " + " .. tostring(circuit.padB) .. (if circuit.upgraded then " (upgraded)" else "")
		)
	end
	detailFrame.Visible = true
	detailText.Text = table.concat(lines, "\n")
end

local function createCityRow(index: number): any
	local card = W.card(cityScroll, 62)
	card.LayoutOrder = index
	local title = W.label({
		parent = card,
		size = UDim2.new(1, -230, 0, 22),
		position = UDim2.new(0, 10, 0, 6),
		textSize = 15,
		font = Theme.fonts.bold,
		xalign = Enum.TextXAlignment.Left,
	})
	local meta = W.label({
		parent = card,
		size = UDim2.new(1, -230, 0, 22),
		position = UDim2.new(0, 10, 0, 28),
		textSize = 12,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
	})
	local inspect = W.button({
		parent = card,
		text = "Inspect",
		size = UDim2.new(0, 100, 0, 42),
		position = UDim2.new(1, -118, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.colors.bgAlt,
		textColor = Theme.colors.text,
		textSize = 14,
		onClick = function()
			task.spawn(function()
				local ok, info = pcall(Net.invoke, "GetCityInfo", index)
				showDetail(if ok then info else nil)
			end)
		end,
	})
	local visit = W.button({
		parent = card,
		text = "Visit",
		size = UDim2.new(0, 100, 0, 42),
		position = UDim2.new(1, -10, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.colors.accentAlt,
		textColor = Theme.colors.ink,
		textSize = 14,
		onClick = function()
			Net.fire("VisitCity", index)
		end,
	})
	local record = { frame = card, title = title, meta = meta, inspect = inspect, visit = visit }
	cityRows[index] = record
	return record
end

local function updateCities(snap: Snapshot)
	local plots = workspace:FindFirstChild("Plots")
	for index = 1, Config.MaxPlayers do
		local row = cityRows[index] or createCityRow(index)
		local plot = plots and plots:FindFirstChild("Plot_" .. tostring(index))
		local ownerId = plot and plot:GetAttribute("OwnerUserId")
		local ownerName = plot and plot:GetAttribute("OwnerName")
		local taken = typeof(ownerId) == "number" and ownerId ~= 0

		if taken then
			local mine = ownerId == Players.LocalPlayer.UserId
			row.title.Text = tostring(ownerName) .. (if mine then "  (you)" else "")
			row.title.TextColor3 = if mine then Theme.colors.accent else Theme.colors.text
			row.meta.Text = "Plot " .. tostring(index)
			W.setEnabled(row.inspect, true)
			W.setEnabled(row.visit, true)
			row.visit.Text = if mine then "Go home" else "Visit"
		else
			row.title.Text = "Empty plot"
			row.title.TextColor3 = Theme.colors.textDim
			row.meta.Text = "Plot " .. tostring(index)
			W.setEnabled(row.inspect, false)
			W.setEnabled(row.visit, false)
			row.visit.Text = "Visit"
		end
	end
	local _ = snap
end

function M.setLeaderboard(data: any)
	if typeof(data) == "table" then
		boards = data
		if built and panel.frame.Visible then
			updateBoards()
		end
	end
end

function M.update(snap: Snapshot?)
	if not built or not snap then
		return
	end
	if not panel.frame.Visible then
		return
	end
	boardScroll.Visible = activeTab == "Leaderboards"
	cityScroll.Visible = activeTab == "Visit"
	detailFrame.Visible = activeTab == "Visit" and detailFrame.Visible
	if activeTab == "Leaderboards" then
		updateBoards()
	else
		updateCities(snap)
	end
end

local function refresh()
	M.update(State.get())
end

function M.init()
	if built then
		return
	end
	gui = W.screenGui("Panels", 10)
	if not gui:FindFirstChildOfClass("UIScale") then
		W.attachScale(gui)
	end
	panel = W.panel(gui, "Cities", "Cities", UDim2.new(0, 640, 0, 440))
	local body = panel.body

	local tabBar = W.frame({ parent = body, size = UDim2.new(1, 0, 0, 34), transparency = 1 })
	W.tabs(tabBar, { "Leaderboards", "Visit" }, function(name)
		activeTab = name
		detailFrame.Visible = false
		refresh()
	end, 34)

	boardScroll = W.scroll(body, UDim2.new(1, 0, 1, -42), UDim2.new(0, 0, 0, 42), 6)
	cityScroll = W.scroll(body, UDim2.new(0.52, -4, 1, -42), UDim2.new(0, 0, 0, 42), 6)
	cityScroll.Visible = false

	detailFrame = W.frame({
		parent = body,
		size = UDim2.new(0.48, -4, 1, -42),
		position = UDim2.new(0.52, 4, 0, 42),
		color = Theme.colors.bgDeep,
		radius = Theme.sizes.radiusSmall,
		stroke = Theme.colors.ink,
		strokeThickness = 2,
		visible = false,
	})
	detailText = W.label({
		parent = detailFrame,
		size = UDim2.new(1, -16, 1, -16),
		position = UDim2.new(0, 8, 0, 8),
		textSize = 12,
		color = Theme.colors.text,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
	})

	built = true
	panel.refresh = refresh
	refresh()
end

return M
