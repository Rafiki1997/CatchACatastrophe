--!strict
-- "Quests": the tutorial step you are on, today's three objectives with their
-- reset countdown, and the four repeatable quests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local scroll: ScrollingFrame
local tutorialCard: Frame
local tutorialTitle: TextLabel
local tutorialBody: TextLabel
local dailyHeader: TextLabel
local dailyRows: { [number]: any } = {}
local repeatRows: { [string]: any } = {}
local lastResetsAt = 0

local function createQuestRow(parent: Instance, order: number): any
	local card = W.card(parent, 78)
	card.LayoutOrder = order
	local title = W.label({
		parent = card,
		size = UDim2.new(1, -140, 0, 20),
		position = UDim2.new(0, 10, 0, 6),
		textSize = 15,
		font = Theme.fonts.bold,
		xalign = Enum.TextXAlignment.Left,
	})
	local body = W.label({
		parent = card,
		size = UDim2.new(1, -140, 0, 18),
		position = UDim2.new(0, 10, 0, 26),
		textSize = 12,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
	})
	local bar = W.progress(card, UDim2.new(1, -150, 0, 18), Theme.colors.success, nil, UDim2.new(0, 10, 0, 50))
	local button = W.button({
		parent = card,
		text = "Claim",
		size = UDim2.new(0, 120, 0, 52),
		position = UDim2.new(1, -10, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.colors.accent,
		textColor = Theme.colors.ink,
		textSize = 14,
		wrap = true,
	})
	return { frame = card, title = title, body = body, bar = bar, button = button }
end

function M.update(snap: Snapshot?)
	if not built or not snap then
		return
	end
	local quests = snap.quests
	lastResetsAt = quests.daily.resetsAt

	-- tutorial
	if quests.tutorialDone then
		tutorialCard.Visible = false
	else
		tutorialCard.Visible = true
		local def = Config.Quests.tutorial[quests.tutorialStep]
		if def then
			tutorialTitle.Text = "Step " .. tostring(def.step) .. " / " .. tostring(#Config.Quests.tutorial) .. ": " .. def.title
			tutorialBody.Text = def.body
		end
	end

	if not panel.frame.Visible then
		return
	end

	-- daily
	dailyHeader.Text = "Today's objectives  ·  resets in " .. Format.clock(math.max(0, quests.daily.resetsAt - State.now()))
	for i = 1, Config.Quests.dailyCount do
		local item = quests.daily.items[i]
		-- every daily row is created and wired once in init, by index
		local row = dailyRows[i]
		if not row then
			continue
		end
		if not item then
			row.frame.Visible = false
		else
			row.frame.Visible = true
			local def = Config.Quests.dailyById[item.id]
			row.title.Text = if def then def.name else item.id
			row.body.Text = item.desc .. "   ·   " .. Format.abbreviate(item.reward) .. " Coins"
			local fraction = if item.target > 0 then item.progress / item.target else 0
			row.bar.set(fraction, math.floor(item.progress) .. " / " .. tostring(item.target))
			if item.claimed then
				row.button.Text = "Claimed"
				W.setEnabled(row.button, false)
			elseif item.progress >= item.target then
				row.button.Text = "Claim\n" .. Format.abbreviate(item.reward)
				W.setEnabled(row.button, true)
			else
				row.button.Text = "In progress"
				W.setEnabled(row.button, false)
			end
		end
	end

	-- repeatable
	for i, def in Config.Quests.repeatable do
		local item = quests.repeatable[def.id]
		local row = repeatRows[def.id]
		if not row then
			row = createQuestRow(scroll, 30 + i)
			repeatRows[def.id] = row
			row.button.Activated:Connect(function()
				Net.fire("ClaimQuest", def.id)
			end)
		end
		if not item then
			row.frame.Visible = false
		else
			row.frame.Visible = true
			row.title.Text = def.name .. (if item.cycle > 0 then "  (done " .. tostring(item.cycle) .. "x)" else "")
			local desc = if def.id == "producer" then "Earn " .. Format.abbreviate(item.target) .. " Coins from your city." else def.desc
			row.body.Text = desc .. "   ·   " .. Format.abbreviate(item.reward) .. " Coins"
			local fraction = if item.target > 0 then item.progress / item.target else 0
			row.bar.set(fraction, Format.abbreviate(item.progress) .. " / " .. Format.abbreviate(item.target))
			if item.progress >= item.target then
				row.button.Text = "Claim\n" .. Format.abbreviate(item.reward)
				W.setEnabled(row.button, true)
			else
				row.button.Text = "In progress"
				W.setEnabled(row.button, false)
			end
		end
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
	panel = W.panel(gui, "Quests", "Quests", UDim2.new(0, 640, 0, 440))
	local body = panel.body

	tutorialCard = W.frame({
		parent = body,
		size = UDim2.new(1, 0, 0, 62),
		color = Theme.colors.bgAlt,
		radius = Theme.sizes.radiusSmall,
		stroke = Theme.colors.accent,
		strokeThickness = 2,
	})
	tutorialTitle = W.label({
		parent = tutorialCard,
		size = UDim2.new(1, -20, 0, 22),
		position = UDim2.new(0, 10, 0, 6),
		textSize = 15,
		font = Theme.fonts.bold,
		color = Theme.colors.accent,
		xalign = Enum.TextXAlignment.Left,
	})
	tutorialBody = W.label({
		parent = tutorialCard,
		size = UDim2.new(1, -20, 0, 30),
		position = UDim2.new(0, 10, 0, 28),
		textSize = 12,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
	})

	dailyHeader = W.label({
		parent = body,
		text = "Today's objectives",
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.new(0, 0, 0, 70),
		textSize = 14,
		font = Theme.fonts.bold,
		color = Theme.colors.accent,
		xalign = Enum.TextXAlignment.Left,
	})

	scroll = W.scroll(body, UDim2.new(1, 0, 1, -94), UDim2.new(0, 0, 0, 94), 6)

	-- wire the daily claim buttons once, by index
	for i = 1, Config.Quests.dailyCount do
		local row = createQuestRow(scroll, 10 + i)
		dailyRows[i] = row
		row.button.Activated:Connect(function()
			Net.fire("ClaimDaily", i)
		end)
	end

	-- live countdown between snapshots
	task.spawn(function()
		while true do
			task.wait(1)
			if built and panel.frame.Visible and lastResetsAt > 0 then
				dailyHeader.Text = "Today's objectives  ·  resets in " .. Format.clock(math.max(0, lastResetsAt - State.now()))
			end
		end
	end)

	built = true
	panel.refresh = refresh
	refresh()
end

return M
