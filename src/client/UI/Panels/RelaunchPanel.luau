--!strict
-- "Relaunch": the rebirth screen.
--
-- The spec is emphatic that nothing here may surprise the player, so this
-- panel states the cost, the requirement, the exact reset and keep lists, the
-- anchors they picked, and every favorite they are about to lose. The
-- acknowledgement tick is sent to the server, which refuses without it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Types = require(ReplicatedStorage.Shared.Types)
local CreatureModels = require(ReplicatedStorage.Shared.Models.CreatureModels)

local W = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)
local Net = require(script.Parent.Parent.Parent.Net)
local State = require(script.Parent.Parent.Parent.State)

type Snapshot = Types.Snapshot

local M = {}

local built = false
local gui: ScreenGui
local panel: any
local levelLabel: TextLabel
local coinsBar: any
local speciesBar: any
local rewardLabel: TextLabel
local anchorHeader: TextLabel
local anchorScroll: ScrollingFrame
local warningLabel: TextLabel
local ackButton: TextButton
local relaunchButton: TextButton
local blockedLabel: TextLabel

local anchors: { [string]: boolean } = {}
local acknowledged = false
local anchorRows: { [string]: any } = {}

local function anchorCount(): number
	local n = 0
	for _ in anchors do
		n += 1
	end
	return n
end

local function lostFavorites(snap: Snapshot): { string }
	local names = {}
	for uid, entry in snap.creatures do
		if entry.favorite and not anchors[uid] then
			local def = Config.Species.byId[entry.id]
			table.insert(names, if def then def.name else entry.id)
		end
	end
	table.sort(names)
	return names
end

local function createAnchorRow(uid: string, entry: Types.CreatureEntry): any
	local card = W.card(anchorScroll, 62)
	local vp = W.viewport(card, UDim2.new(0, 52, 0, 52), UDim2.new(0, 4, 0, 5), Theme.colors.bgDeep)
	local name = W.label({
		parent = card,
		size = UDim2.new(1, -190, 0, 20),
		position = UDim2.new(0, 62, 0, 6),
		textSize = 14,
		font = Theme.fonts.bold,
		xalign = Enum.TextXAlignment.Left,
	})
	local meta = W.label({
		parent = card,
		size = UDim2.new(1, -190, 0, 32),
		position = UDim2.new(0, 62, 0, 26),
		textSize = 12,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
		wrap = true,
	})
	local button = W.button({
		parent = card,
		text = "Anchor",
		size = UDim2.new(0, 110, 0, 42),
		position = UDim2.new(1, -10, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.colors.bgAlt,
		textColor = Theme.colors.text,
		textSize = 14,
		onClick = function()
			local snap = State.get()
			if not snap then
				return
			end
			if anchors[uid] then
				anchors[uid] = nil
			elseif anchorCount() < snap.derived.anchorSlots then
				anchors[uid] = true
			end
			M.update(State.get())
		end,
	})
	local record = { frame = card, vp = vp, name = name, meta = meta, button = button, modelKey = "" }
	anchorRows[uid] = record
	local _ = entry
	return record
end

function M.update(snap: Snapshot?)
	if not built or not snap then
		return
	end

	local level = snap.relaunch
	local maxed = level >= Config.Relaunch.maxLevel
	levelLabel.Text = "Relaunch " .. tostring(level) .. " / " .. tostring(Config.Relaunch.maxLevel) .. "   ·   permanent income x" .. ("%.2f"):format(snap.relaunchMult)

	if not panel.frame.Visible then
		return
	end

	local cost = Config.Relaunch.cost(level)
	local required = Config.Relaunch.speciesRequired(level)

	if maxed then
		coinsBar.set(1, "MAX LEVEL")
		speciesBar.set(1, "MAX LEVEL")
		rewardLabel.Text = "You have relaunched as far as this city goes."
	else
		coinsBar.set(snap.coins / cost, Format.abbreviate(snap.coins) .. " / " .. Format.abbreviate(cost) .. " Coins")
		speciesBar.set(snap.atlas.discovered / required, tostring(snap.atlas.discovered) .. " / " .. tostring(required) .. " species")
		rewardLabel.Text = "Relaunch "
			.. tostring(level + 1)
			.. " gives permanent income x"
			.. ("%.2f"):format(Config.Relaunch.incomeMultiplier(level + 1))
			.. " and "
			.. tostring(Config.Relaunch.startingPads(level + 1))
			.. " starting work pads (you have "
			.. tostring(Config.Relaunch.startingPads(level))
			.. ")."
	end

	-- anchor list: everything owned, best income first
	local slots = snap.derived.anchorSlots
	anchorHeader.Text = "Anchors: keep " .. tostring(anchorCount()) .. " of " .. tostring(slots) .. " creatures through the relaunch"

	local order: { { uid: string, entry: Types.CreatureEntry } } = {}
	for uid, entry in snap.creatures do
		table.insert(order, { uid = uid, entry = entry })
	end
	table.sort(order, function(a, b)
		if a.entry.normalCps ~= b.entry.normalCps then
			return a.entry.normalCps > b.entry.normalCps
		end
		return a.uid < b.uid
	end)

	local live: { [string]: boolean } = {}
	for i, item in order do
		live[item.uid] = true
		local row = anchorRows[item.uid] or createAnchorRow(item.uid, item.entry)
		row.frame.LayoutOrder = i
		local def = Config.Species.byId[item.entry.id]
		local wantKey = item.entry.id .. "|" .. item.entry.variant
		if row.modelKey ~= wantKey then
			row.modelKey = wantKey
			task.spawn(function()
				if row.frame.Parent then
					local ok, model = pcall(CreatureModels.build, item.entry.id, item.entry.variant)
					if ok then
						row.vp.setModel(model)
					end
				end
			end)
		end
		row.name.Text = (if def then def.name else item.entry.id) .. (if item.entry.favorite then "  *" else "")
		row.name.TextColor3 = if def then Config.Rarities.color(def.rarity) else Theme.colors.text
		row.meta.Text = Format.abbreviate(item.entry.normalCps) .. "/s   ·   " .. (if item.entry.pad then "Pad " .. tostring(item.entry.pad) else "Stored")

		local picked = anchors[item.uid] == true
		row.button.Text = if picked then "Anchored" else "Anchor"
		W.setButtonColor(row.button, if picked then Theme.colors.success else Theme.colors.bgAlt, if picked then Theme.colors.ink else Theme.colors.text)
		W.setEnabled(row.button, picked or anchorCount() < slots)
	end
	for uid, row in anchorRows do
		if not live[uid] then
			row.frame:Destroy()
			anchorRows[uid] = nil
			anchors[uid] = nil
		end
	end

	-- favorites that would be lost
	local lost = lostFavorites(snap)
	if #lost > 0 then
		warningLabel.Visible = true
		warningLabel.Text = "You will lose these favorites: " .. table.concat(lost, ", ") .. ". Anchor them or accept losing them."
	else
		warningLabel.Visible = false
	end

	ackButton.Text = if acknowledged then "[x] I understand what I lose" else "[ ] I understand what I lose"
	W.setButtonColor(ackButton, if acknowledged then Theme.colors.success else Theme.colors.bgAlt, if acknowledged then Theme.colors.ink else Theme.colors.text)

	-- the button, and why it is off when it is off
	local reason: string? = nil
	if maxed then
		reason = "You are at the highest relaunch level."
	elseif snap.coins < cost then
		reason = "You need " .. Format.abbreviate(cost - snap.coins) .. " more Coins."
	elseif snap.atlas.discovered < required then
		reason = "You need " .. tostring(required - snap.atlas.discovered) .. " more discovered species."
	elseif snap.capturing then
		reason = "Finish or cancel your capture first."
	elseif not snap.dataSafe then
		reason = "Your save could not be loaded this session, so relaunching is disabled."
	elseif not acknowledged then
		reason = "Tick the box to confirm you understand."
	end
	blockedLabel.Text = reason or ""
	blockedLabel.Visible = reason ~= nil
	W.setEnabled(relaunchButton, reason == nil)
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
	panel = W.panel(gui, "Relaunch", "City Relaunch", UDim2.new(0, 640, 0, 440))
	local body = panel.body

	levelLabel = W.label({
		parent = body,
		text = "Relaunch 0 / 10",
		size = UDim2.new(1, 0, 0, 20),
		textSize = 15,
		font = Theme.fonts.bold,
		color = Theme.colors.accentAlt,
		xalign = Enum.TextXAlignment.Left,
	})
	coinsBar = W.progress(body, UDim2.new(0.5, -6, 0, 22), Theme.colors.coin, nil, UDim2.new(0, 0, 0, 24))
	speciesBar = W.progress(body, UDim2.new(0.5, -6, 0, 22), Theme.colors.accentAlt, nil, UDim2.new(0.5, 6, 0, 24))
	rewardLabel = W.label({
		parent = body,
		size = UDim2.new(1, 0, 0, 32),
		position = UDim2.new(0, 0, 0, 50),
		textSize = 12,
		color = Theme.colors.textDim,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
	})

	-- reset / keep lists, straight from config so they cannot drift from the code
	local listsFrame = W.frame({ parent = body, size = UDim2.new(1, 0, 0, 100), position = UDim2.new(0, 0, 0, 84), transparency = 1 })
	local resetText = "YOU LOSE\n"
	for _, line in Config.Relaunch.resets do
		resetText ..= "- " .. line .. "\n"
	end
	local keepText = "YOU KEEP\n"
	for _, line in Config.Relaunch.keeps do
		keepText ..= "- " .. line .. "\n"
	end
	W.label({
		parent = listsFrame,
		text = resetText,
		size = UDim2.new(0.5, -6, 1, 0),
		textSize = 11,
		color = Theme.colors.text,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
	})
	W.label({
		parent = listsFrame,
		text = keepText,
		size = UDim2.new(0.5, -6, 1, 0),
		position = UDim2.new(0.5, 6, 0, 0),
		textSize = 11,
		color = Theme.colors.text,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
	})

	anchorHeader = W.label({
		parent = body,
		text = "Anchors",
		size = UDim2.new(1, 0, 0, 18),
		position = UDim2.new(0, 0, 0, 184),
		textSize = 13,
		font = Theme.fonts.bold,
		color = Theme.colors.accent,
		xalign = Enum.TextXAlignment.Left,
	})
	anchorScroll = W.scroll(body, UDim2.new(1, 0, 0, 108), UDim2.new(0, 0, 0, 204), 5)

	warningLabel = W.label({
		parent = body,
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.new(0, 0, 0, 316),
		textSize = 12,
		color = Theme.colors.accent,
		xalign = Enum.TextXAlignment.Left,
		yalign = Enum.TextYAlignment.Top,
		wrap = true,
		visible = false,
	})

	ackButton = W.button({
		parent = body,
		text = "[ ] I understand what I lose",
		size = UDim2.new(0.55, -6, 0, 34),
		position = UDim2.new(0, 0, 1, -38),
		color = Theme.colors.bgAlt,
		textColor = Theme.colors.text,
		textSize = 14,
		onClick = function()
			acknowledged = not acknowledged
			refresh()
		end,
	})
	relaunchButton = W.button({
		parent = body,
		text = "Relaunch City",
		size = UDim2.new(0.45, 0, 0, 34),
		position = UDim2.new(1, 0, 1, -38),
		anchor = Vector2.new(1, 0),
		color = Theme.colors.danger,
		textColor = Theme.colors.text,
		textSize = 15,
		onClick = function()
			local snap = State.get()
			if not snap then
				return
			end
			local uids = {}
			for uid in anchors do
				table.insert(uids, uid)
			end
			local lost = lostFavorites(snap)
			local body_ = "Your city resets to 150 Coins and "
				.. tostring(Config.Relaunch.startingPads(snap.relaunch + 1))
				.. " work pads. "
				.. tostring(#uids)
				.. " anchored "
				.. (if #uids == 1 then "creature goes" else "creatures go")
				.. " to storage. Everything else in the list is lost."
			if #lost > 0 then
				body_ ..= "\n\nFavorites lost: " .. table.concat(lost, ", ")
			end
			W.confirm(gui, "Relaunch your city?", body_, "Relaunch", function()
				Net.fire("DoRelaunch", uids, true)
				anchors = {}
				acknowledged = false
				refresh()
			end, true)
		end,
	})
	blockedLabel = W.label({
		parent = body,
		size = UDim2.new(1, 0, 0, 18),
		position = UDim2.new(0, 0, 1, -56),
		textSize = 12,
		color = Theme.colors.accent,
		xalign = Enum.TextXAlignment.Left,
		visible = false,
	})

	built = true
	panel.refresh = refresh
	refresh()
end

return M
