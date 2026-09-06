--!strict
-- "Recipes": the six Disaster Circuits, how they are made and what they do.
-- Undiscovered ones show a hint instead of the answer, so working one out
-- still feels like working it out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Types = require(ReplicatedStorage.Shared.Types)

local W = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)
local State = require(script.Parent.Parent.Parent.State)

type Snapshot = Types.Snapshot

local M = {}

local built = false
local gui: ScreenGui
local panel: any
local headerLabel: TextLabel
local scroll: ScrollingFrame
local rows: { [string]: any } = {}

local function createRow(def: any): any
	local card = W.card(scroll, 96)

	local title = W.label({
		parent = card,
		size = UDim2.new(1, -130, 0, 22),
		position = UDim2.new(0, 10, 0, 6),
		textSize = 17,
		font = Theme.fonts.title,
		xalign = Enum.TextXAlignment.Left,
	})
	local elements = W.label({
		parent = card,
		size = UDim2.new(1, -130, 0, 18),
		position = UDim2.new(0, 10, 0, 28),
		textSize = 13,
		font = Theme.fonts.bold,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
	})
	local body = W.label({
		parent = card,
		size = UDim2.new(1, -130, 0, 40),
		position = UDim2.new(0, 10, 0, 48),
		textSize = 13,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
	})
	local status = W.label({
		parent = card,
		size = UDim2.new(0, 112, 0, 40),
		position = UDim2.new(1, -10, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		textSize = 13,
		font = Theme.fonts.bold,
		color = Theme.colors.textDim,
		wrap = true,
	})

	local record = { frame = card, title = title, elements = elements, body = body, status = status, def = def }
	rows[def.id] = record
	return record
end

local function updateRow(row: any, snap: Snapshot)
	local def = row.def
	local discovered = snap.atlas.recipes[def.id] == true

	local active = 0
	for _, entry in snap.circuits do
		if entry.circuitId == def.id then
			active += 1
		end
	end

	if discovered then
		row.title.Text = def.name
		row.title.TextColor3 = def.color
		row.elements.Text = def.elements[1] .. "  +  " .. def.elements[2]
		row.body.Text = def.desc
		row.status.Text = if active > 0 then tostring(active) .. " running" else "Discovered"
		row.status.TextColor3 = if active > 0 then Theme.colors.success else Theme.colors.textDim
	else
		row.title.Text = "???"
		row.title.TextColor3 = Theme.colors.textDim
		row.elements.Text = "? + ?"
		row.body.Text = def.hint
		row.status.Text = "Undiscovered"
		row.status.TextColor3 = Theme.colors.textDim
	end
	row.frame.LayoutOrder = if discovered then 1 else 2
end

function M.update(snap: Snapshot?)
	if not built or not snap then
		return
	end
	local found = 0
	for _ in snap.atlas.recipes do
		found += 1
	end
	headerLabel.Text = "Discovered " .. tostring(found) .. " / " .. tostring(#Config.Circuits.list) .. " circuits"
	if not panel.frame.Visible then
		return
	end
	for _, def in Config.Circuits.list do
		local row = rows[def.id] or createRow(def)
		updateRow(row, snap)
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
	panel = W.panel(gui, "Recipes", "Recipe Book", UDim2.new(0, 640, 0, 440))
	local body = panel.body

	headerLabel = W.label({
		parent = body,
		text = "Discovered 0 / 6 circuits",
		size = UDim2.new(1, 0, 0, 20),
		textSize = 15,
		font = Theme.fonts.bold,
		color = Theme.colors.accent,
		xalign = Enum.TextXAlignment.Left,
	})

	W.label({
		parent = body,
		text = "Put two creatures on work pads that touch, side by side or one above the other. Diagonal pads do not connect, and each creature can be in one circuit at a time. Upgrade a circuit to raise its bonus from "
			.. Format.percent(Config.Circuits.baseBonus)
			.. " to "
			.. Format.percent(Config.Circuits.upgradedBonus)
			.. ". Overdrive doubles a pair for "
			.. tostring(Config.Circuits.overdrive.activeSeconds)
			.. "s, then it earns nothing for "
			.. tostring(Config.Circuits.overdrive.cooldownSeconds)
			.. "s unless you vent at your control booth.",
		size = UDim2.new(1, 0, 0, 66),
		position = UDim2.new(0, 0, 0, 24),
		textSize = 12,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
	})

	scroll = W.scroll(body, UDim2.new(1, 0, 1, -96), UDim2.new(0, 0, 0, 96), 6)

	built = true
	panel.refresh = refresh
	refresh()
end

return M
